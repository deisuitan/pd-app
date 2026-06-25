import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pd_session.dart';
import '../models/daily_record.dart';
import '../models/weight_record.dart';
import '../models/blood_pressure_record.dart';
import '../models/urine_record.dart';
import '../models/bowel_record.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sessions(String uid) =>
      _db.collection('users').doc(uid).collection('sessions');

  CollectionReference<Map<String, dynamic>> _daily(String uid) =>
      _db.collection('users').doc(uid).collection('dailyRecords');

  CollectionReference<Map<String, dynamic>> _weights(String uid) =>
      _db.collection('users').doc(uid).collection('weightRecords');

  CollectionReference<Map<String, dynamic>> _bloodPressures(String uid) =>
      _db.collection('users').doc(uid).collection('bloodPressureRecords');

  CollectionReference<Map<String, dynamic>> _urineRecords(String uid) =>
      _db.collection('users').doc(uid).collection('urineRecords');

  CollectionReference<Map<String, dynamic>> _bowelRecords(String uid) =>
      _db.collection('users').doc(uid).collection('bowelRecords');

  // ─── ストリーム ───────────────────────────────────────────

  Stream<List<PDSession>> sessionsStream(String uid) {
    return _sessions(uid)
        .orderBy('fillStartTime')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => _docToSession(doc)).toList());
  }

  Stream<List<DailyRecord>> dailyRecordsStream(String uid) {
    return _daily(uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return DailyRecord(
                date: d['date'] as String,
                exitSiteCondition: d['exitSiteCondition'] as String,
                recordedAt: (d['recordedAt'] as Timestamp).toDate(),
              );
            }).toList());
  }

  Stream<List<WeightRecord>> weightRecordsStream(String uid) {
    return _weights(uid)
        .orderBy('measuredAt')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return WeightRecord(
                id: doc.id,
                weightKg: (d['weightKg'] as num).toDouble(),
                measuredAt: (d['measuredAt'] as Timestamp).toDate(),
                date: d['date'] as String,
                note: d['note'] as String?,
              );
            }).toList());
  }

  Stream<List<BloodPressureRecord>> bloodPressureRecordsStream(String uid) {
    return _bloodPressures(uid)
        .orderBy('measuredAt')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return BloodPressureRecord(
                id: doc.id,
                systolic: (d['systolic'] as num).toInt(),
                diastolic: (d['diastolic'] as num).toInt(),
                pulse: (d['pulse'] as num?)?.toInt(),
                timing: d['timing'] as String?,
                measuredAt: (d['measuredAt'] as Timestamp).toDate(),
                date: d['date'] as String,
                note: d['note'] as String?,
              );
            }).toList());
  }

  Stream<List<UrineRecord>> urineRecordsStream(String uid) {
    return _urineRecords(uid)
        .orderBy('recordedAt')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return UrineRecord(
                id: doc.id,
                urineVolumeMl: (d['urineVolumeMl'] as num).toInt(),
                recordedAt: (d['recordedAt'] as Timestamp).toDate(),
                date: d['date'] as String,
                note: d['note'] as String?,
              );
            }).toList());
  }

  Stream<List<BowelRecord>> bowelRecordsStream(String uid) {
    return _bowelRecords(uid)
        .orderBy('recordedAt')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return BowelRecord(
                id: doc.id,
                recordedAt: (d['recordedAt'] as Timestamp).toDate(),
                date: d['date'] as String,
                consistency: BowelConsistency.values.firstWhere(
                  (e) => e.name == (d['consistency'] as String? ?? 'normal'),
                  orElse: () => BowelConsistency.normal,
                ),
                note: d['note'] as String?,
              );
            }).toList());
  }

  // ─── CRUD ────────────────────────────────────────────────

  Future<void> addSession(String uid, PDSession session) async {
    await _sessions(uid).doc(session.id).set(_sessionToMap(session));
    await _updatePrevDrainDuration(uid, session);
  }

  Future<void> updateSession(String uid, PDSession session) async {
    await _sessions(uid).doc(session.id).update(_sessionToMap(session));
    await _recalcAdjacentDrainDurations(uid, session);
  }

  Future<void> deleteSession(String uid, String sessionId) async {
    // 削除するセッションの情報を先に取得
    final doc = await _sessions(uid).doc(sessionId).get();
    if (!doc.exists) return;
    final deleted = _docToSession(doc);

    await _sessions(uid).doc(sessionId).delete();

    // 直前セッションの廃液時間を、削除後の次セッションを基に再計算（なければnullに）
    await _recalcPrevAfterDelete(uid, deleted);
  }

  // ─── バックアップ設定 ─────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _backupDoc(String uid) =>
      _db.collection('users').doc(uid).collection('settings').doc('backup');

  Future<Map<String, dynamic>?> getBackupSettings(String uid) async {
    final doc = await _backupDoc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> updateBackupSettings(String uid, Map<String, dynamic> data) async {
    await _backupDoc(uid).set(data, SetOptions(merge: true));
  }

  // ─── バックアップ復元（バッチ書き込み）─────────────────────
  Future<void> restoreBackup(
      String uid,
      List<PDSession> sessions,
      List<DailyRecord> dailyRecords,
      List<WeightRecord> weightRecords,
      List<BloodPressureRecord> bloodPressureRecords,
      List<UrineRecord> urineRecords,
      List<BowelRecord> bowelRecords) async {
    var batch = _db.batch();
    var count = 0;

    Future<void> flush() async {
      if (count > 0) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }

    for (final s in sessions) {
      batch.set(_sessions(uid).doc(s.id), _sessionToMap(s));
      if (++count >= 499) await flush();
    }
    for (final r in dailyRecords) {
      batch.set(_daily(uid).doc(r.date), {
        'date': r.date,
        'exitSiteCondition': r.exitSiteCondition,
        'recordedAt': Timestamp.fromDate(r.recordedAt),
      });
      if (++count >= 499) await flush();
    }
    for (final w in weightRecords) {
      batch.set(_weights(uid).doc(w.id), {
        'weightKg': w.weightKg,
        'measuredAt': Timestamp.fromDate(w.measuredAt),
        'date': w.date,
        'note': w.note,
      });
      if (++count >= 499) await flush();
    }
    for (final bp in bloodPressureRecords) {
      batch.set(_bloodPressures(uid).doc(bp.id), {
        'systolic': bp.systolic,
        'diastolic': bp.diastolic,
        'pulse': bp.pulse,
        'timing': bp.timing,
        'measuredAt': Timestamp.fromDate(bp.measuredAt),
        'date': bp.date,
        'note': bp.note,
      });
      if (++count >= 499) await flush();
    }
    for (final u in urineRecords) {
      batch.set(_urineRecords(uid).doc(u.id), {
        'urineVolumeMl': u.urineVolumeMl,
        'recordedAt': Timestamp.fromDate(u.recordedAt),
        'date': u.date,
        'note': u.note,
      });
      if (++count >= 499) await flush();
    }
    for (final b in bowelRecords) {
      batch.set(_bowelRecords(uid).doc(b.id), {
        'recordedAt': Timestamp.fromDate(b.recordedAt),
        'date': b.date,
        'consistency': b.consistency.name,
        'note': b.note,
      });
      if (++count >= 499) await flush();
    }
    await flush();
  }

  Future<void> addWeightRecord(String uid, WeightRecord record) async {
    await _weights(uid).doc(record.id).set({
      'weightKg': record.weightKg,
      'measuredAt': Timestamp.fromDate(record.measuredAt),
      'date': record.date,
      'note': record.note,
    });
  }

  Future<void> updateWeightRecord(String uid, WeightRecord record) async {
    await _weights(uid).doc(record.id).update({
      'weightKg': record.weightKg,
      'measuredAt': Timestamp.fromDate(record.measuredAt),
      'date': record.date,
      'note': record.note,
    });
  }

  Future<void> deleteWeightRecord(String uid, String id) async {
    await _weights(uid).doc(id).delete();
  }

  Future<void> addBloodPressureRecord(String uid, BloodPressureRecord record) async {
    await _bloodPressures(uid).doc(record.id).set({
      'systolic': record.systolic,
      'diastolic': record.diastolic,
      'pulse': record.pulse,
      'timing': record.timing,
      'measuredAt': Timestamp.fromDate(record.measuredAt),
      'date': record.date,
      'note': record.note,
    });
  }

  Future<void> updateBloodPressureRecord(String uid, BloodPressureRecord record) async {
    await _bloodPressures(uid).doc(record.id).update({
      'systolic': record.systolic,
      'diastolic': record.diastolic,
      'pulse': record.pulse,
      'timing': record.timing,
      'measuredAt': Timestamp.fromDate(record.measuredAt),
      'date': record.date,
      'note': record.note,
    });
  }

  Future<void> deleteBloodPressureRecord(String uid, String id) async {
    await _bloodPressures(uid).doc(id).delete();
  }

  Future<void> addUrineRecord(String uid, UrineRecord record) async {
    await _urineRecords(uid).doc(record.id).set({
      'urineVolumeMl': record.urineVolumeMl,
      'recordedAt': Timestamp.fromDate(record.recordedAt),
      'date': record.date,
      'note': record.note,
    });
  }

  Future<void> updateUrineRecord(String uid, UrineRecord record) async {
    await _urineRecords(uid).doc(record.id).update({
      'urineVolumeMl': record.urineVolumeMl,
      'recordedAt': Timestamp.fromDate(record.recordedAt),
      'date': record.date,
      'note': record.note,
    });
  }

  Future<void> deleteUrineRecord(String uid, String id) async {
    await _urineRecords(uid).doc(id).delete();
  }

  Future<void> addBowelRecord(String uid, BowelRecord record) async {
    await _bowelRecords(uid).doc(record.id).set({
      'recordedAt': Timestamp.fromDate(record.recordedAt),
      'date': record.date,
      'consistency': record.consistency.name,
      'note': record.note,
    });
  }

  Future<void> updateBowelRecord(String uid, BowelRecord record) async {
    await _bowelRecords(uid).doc(record.id).update({
      'recordedAt': Timestamp.fromDate(record.recordedAt),
      'date': record.date,
      'consistency': record.consistency.name,
      'note': record.note,
    });
  }

  Future<void> deleteBowelRecord(String uid, String id) async {
    await _bowelRecords(uid).doc(id).delete();
  }

  Future<void> saveExitSite(String uid, DailyRecord record) async {
    await _daily(uid).doc(record.date).set({
      'date': record.date,
      'exitSiteCondition': record.exitSiteCondition,
      'recordedAt': Timestamp.fromDate(record.recordedAt),
    });
  }

  // ─── 廃液時間の自動計算 ────────────────────────────────────

  // セッション削除後：直前セッションの廃液時間を再計算する
  // 削除後に次セッション（C）があれば A→C で再計算、なければ null にする
  Future<void> _recalcPrevAfterDelete(String uid, PDSession deleted) async {
    // 直前セッション（A）を取得
    final prevSnap = await _sessions(uid)
        .where('drainStartTime',
            isLessThan: Timestamp.fromDate(deleted.fillStartTime))
        .orderBy('drainStartTime', descending: true)
        .limit(1)
        .get();

    if (prevSnap.docs.isEmpty) return;
    final prevDoc = prevSnap.docs.first;

    // 削除後の次セッション（C）を取得
    final nextSnap = await _sessions(uid)
        .where('fillStartTime',
            isGreaterThan: Timestamp.fromDate(deleted.fillStartTime))
        .orderBy('fillStartTime')
        .limit(1)
        .get();

    if (nextSnap.docs.isEmpty) {
      // 次セッションなし → 廃液時間をリセット（「次のセッション…」表示に）
      await _sessions(uid)
          .doc(prevDoc.id)
          .update({'drainDurationMinutes': null});
    } else {
      // 次セッション（C）あり → A の廃液開始 → C の貯留開始で再計算
      final prevDrainStart =
          (prevDoc.data()['drainStartTime'] as Timestamp).toDate();
      final nextFillStart =
          (nextSnap.docs.first.data()['fillStartTime'] as Timestamp).toDate();
      final minutes = nextFillStart.difference(prevDrainStart).inMinutes;
      await _sessions(uid)
          .doc(prevDoc.id)
          .update({'drainDurationMinutes': minutes});
    }
  }

  // 新しいセッション追加後：直前セッションの廃液時間を更新する
  Future<void> _updatePrevDrainDuration(
      String uid, PDSession anchor) async {
    final snap = await _sessions(uid)
        .where('drainStartTime',
            isLessThan: Timestamp.fromDate(anchor.fillStartTime))
        .orderBy('drainStartTime', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return;

    final prevDoc = snap.docs.first;
    final prevDrainStart =
        (prevDoc.data()['drainStartTime'] as Timestamp).toDate();
    final minutes =
        anchor.fillStartTime.difference(prevDrainStart).inMinutes;

    await _sessions(uid)
        .doc(prevDoc.id)
        .update({'drainDurationMinutes': minutes});
  }

  // セッション更新後：前後のセッションの廃液時間を再計算する
  Future<void> _recalcAdjacentDrainDurations(
      String uid, PDSession updated) async {
    // 更新セッション自体の廃液時間（直後セッションの開始 - 自分の廃液開始）
    final nextSnap = await _sessions(uid)
        .where('fillStartTime',
            isGreaterThan: Timestamp.fromDate(updated.fillStartTime))
        .orderBy('fillStartTime')
        .limit(1)
        .get();

    if (nextSnap.docs.isNotEmpty) {
      final nextFill =
          (nextSnap.docs.first.data()['fillStartTime'] as Timestamp).toDate();
      final minutes =
          nextFill.difference(updated.drainStartTime).inMinutes;
      await _sessions(uid)
          .doc(updated.id)
          .update({'drainDurationMinutes': minutes});
    } else {
      await _sessions(uid)
          .doc(updated.id)
          .update({'drainDurationMinutes': null});
    }

    // 直前セッションの廃液時間も更新
    await _updatePrevDrainDuration(uid, updated);
  }

  // ─── 変換ヘルパー ─────────────────────────────────────────

  PDSession _docToSession(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return PDSession(
      id: doc.id,
      date: d['date'] as String,
      fillStartTime: (d['fillStartTime'] as Timestamp).toDate(),
      drainStartTime: (d['drainStartTime'] as Timestamp).toDate(),
      dialysateType: d['dialysateType'] as String,
      drainVolume: (d['drainVolume'] as num?)?.toInt(),
      fillVolume: (d['fillVolume'] as num?)?.toInt() ?? 2000,
      drainDurationMinutes: (d['drainDurationMinutes'] as num?)?.toInt(),
      drainAppearance: DrainAppearance.values.firstWhere(
        (e) => e.name == (d['drainAppearance'] as String? ?? 'normal'),
        orElse: () => DrainAppearance.normal,
      ),
      appearanceNote: d['appearanceNote'] as String?,
      photoStoragePaths:
          List<String>.from(d['photoStoragePaths'] as List? ?? []),
    );
  }

  Map<String, dynamic> _sessionToMap(PDSession s) => {
        'date': s.date,
        'fillStartTime': Timestamp.fromDate(s.fillStartTime),
        'drainStartTime': Timestamp.fromDate(s.drainStartTime),
        'dialysateType': s.dialysateType,
        'drainVolume': s.drainVolume,
        'fillVolume': s.fillVolume,
        'drainDurationMinutes': s.drainDurationMinutes,
        'drainAppearance': s.drainAppearance.name,
        'appearanceNote': s.appearanceNote,
        'photoStoragePaths': s.photoStoragePaths,
      };
}
