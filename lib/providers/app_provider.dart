import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/pd_session.dart';
import '../models/daily_record.dart';
import '../models/weight_record.dart';
import '../models/blood_pressure_record.dart';
import '../models/urine_record.dart';
import '../models/bowel_record.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/firestore_service.dart';
import '../services/google_drive_service.dart';

class AppProvider extends ChangeNotifier {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _driveService = GoogleDriveService();
  final _backupService = BackupService();

  User? _user;
  List<PDSession> _sessions = [];
  List<DailyRecord> _dailyRecords = [];
  List<WeightRecord> _weightRecords = [];
  List<BloodPressureRecord> _bloodPressureRecords = [];
  List<UrineRecord> _urineRecords = [];
  List<BowelRecord> _bowelRecords = [];
  bool _isLoading = false;

  // ─── Drive バックアップ ────────────────────────────────────
  bool _driveBackupEnabled = false;
  String? _lastDriveBackupDate;
  bool _isDriveBackupRunning = false;

  bool get driveBackupEnabled => _driveBackupEnabled;
  String? get lastDriveBackupDate => _lastDriveBackupDate;
  bool get isDriveBackupRunning => _isDriveBackupRunning;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<PDSession>>? _sessionsSub;
  StreamSubscription<List<DailyRecord>>? _dailySub;
  StreamSubscription<List<WeightRecord>>? _weightsSub;
  StreamSubscription<List<BloodPressureRecord>>? _bpSub;
  StreamSubscription<List<UrineRecord>>? _urineSub;
  StreamSubscription<List<BowelRecord>>? _bowelSub;

  AppProvider() {
    _authSub = _auth.userStream.listen((user) {
      _user = user;
      if (user != null) {
        _subscribeToFirestore(user.uid);
      } else {
        _cancelFirestoreSubscriptions();
        _sessions = [];
        _dailyRecords = [];
        _weightRecords = [];
        _bloodPressureRecords = [];
        _urineRecords = [];
        _bowelRecords = [];
      }
      notifyListeners();
    });
  }

  // ─── ゲッター ─────────────────────────────────────────────

  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get userId => _user?.uid;
  String? get userName => _user?.displayName;
  String? get userEmail => _user?.email;
  String? get userPhotoUrl => _user?.photoURL;

  List<PDSession> get sessions => _sessions;
  List<DailyRecord> get dailyRecords => _dailyRecords;
  List<WeightRecord> get weightRecords => _weightRecords;
  List<BloodPressureRecord> get bloodPressureRecords => _bloodPressureRecords;
  List<UrineRecord> get urineRecords => _urineRecords;
  List<BowelRecord> get bowelRecords => _bowelRecords;
  String get todayDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

  List<PDSession> sessionsForDate(String date) =>
      _sessions.where((s) => s.date == date).toList()
        ..sort((a, b) => a.fillStartTime.compareTo(b.fillStartTime));

  DailyRecord? dailyRecordForDate(String date) =>
      _dailyRecords.where((r) => r.date == date).firstOrNull;

  int totalUltrafiltrationForDate(String date) =>
      sessionsForDate(date).fold(0, (sum, s) => sum + (s.ultrafiltration ?? 0));

  List<WeightRecord> weightRecordsForDate(String date) =>
      _weightRecords.where((r) => r.date == date).toList()
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

  WeightRecord? latestWeightForDate(String date) {
    final list = weightRecordsForDate(date);
    return list.isEmpty ? null : list.last;
  }

  List<BloodPressureRecord> bloodPressureRecordsForDate(String date) =>
      _bloodPressureRecords.where((r) => r.date == date).toList()
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

  BloodPressureRecord? latestBloodPressureForDate(String date) {
    final list = bloodPressureRecordsForDate(date);
    return list.isEmpty ? null : list.last;
  }

  List<UrineRecord> urineRecordsForDate(String date) =>
      _urineRecords.where((r) => r.date == date).toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  int urineCountForDate(String date) => urineRecordsForDate(date).length;

  int urineTotalForDate(String date) =>
      urineRecordsForDate(date).fold(0, (sum, r) => sum + r.urineVolumeMl);

  List<BowelRecord> bowelRecordsForDate(String date) =>
      _bowelRecords.where((r) => r.date == date).toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  int bowelCountForDate(String date) => bowelRecordsForDate(date).length;

  // ─── 認証 ─────────────────────────────────────────────────

  Future<void> login() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithGoogle();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  // ─── CRUD ─────────────────────────────────────────────────

  Future<void> addSession(PDSession session) async {
    if (_user == null) return;
    await _firestore.addSession(_user!.uid, session);
  }

  Future<void> updateSession(PDSession updated) async {
    if (_user == null) return;
    await _firestore.updateSession(_user!.uid, updated);
  }

  Future<void> deleteSession(String id) async {
    if (_user == null) return;
    await _firestore.deleteSession(_user!.uid, id);
  }

  Future<void> saveExitSite(DailyRecord record) async {
    if (_user == null) return;
    await _firestore.saveExitSite(_user!.uid, record);
  }

  Future<void> addWeightRecord(WeightRecord record) async {
    if (_user == null) return;
    await _firestore.addWeightRecord(_user!.uid, record);
  }

  Future<void> updateWeightRecord(WeightRecord record) async {
    if (_user == null) return;
    await _firestore.updateWeightRecord(_user!.uid, record);
  }

  Future<void> deleteWeightRecord(String id) async {
    if (_user == null) return;
    await _firestore.deleteWeightRecord(_user!.uid, id);
  }

  Future<void> addBloodPressureRecord(BloodPressureRecord record) async {
    if (_user == null) return;
    await _firestore.addBloodPressureRecord(_user!.uid, record);
  }

  Future<void> updateBloodPressureRecord(BloodPressureRecord record) async {
    if (_user == null) return;
    await _firestore.updateBloodPressureRecord(_user!.uid, record);
  }

  Future<void> deleteBloodPressureRecord(String id) async {
    if (_user == null) return;
    await _firestore.deleteBloodPressureRecord(_user!.uid, id);
  }

  Future<void> addUrineRecord(UrineRecord record) async {
    if (_user == null) return;
    await _firestore.addUrineRecord(_user!.uid, record);
  }

  Future<void> updateUrineRecord(UrineRecord record) async {
    if (_user == null) return;
    await _firestore.updateUrineRecord(_user!.uid, record);
  }

  Future<void> deleteUrineRecord(String id) async {
    if (_user == null) return;
    await _firestore.deleteUrineRecord(_user!.uid, id);
  }

  Future<void> addBowelRecord(BowelRecord record) async {
    if (_user == null) return;
    await _firestore.addBowelRecord(_user!.uid, record);
  }

  Future<void> updateBowelRecord(BowelRecord record) async {
    if (_user == null) return;
    await _firestore.updateBowelRecord(_user!.uid, record);
  }

  Future<void> deleteBowelRecord(String id) async {
    if (_user == null) return;
    await _firestore.deleteBowelRecord(_user!.uid, id);
  }

  Future<void> restoreBackup(
      List<PDSession> sessions,
      List<DailyRecord> dailyRecords,
      List<WeightRecord> weightRecords,
      List<BloodPressureRecord> bloodPressureRecords,
      List<UrineRecord> urineRecords,
      List<BowelRecord> bowelRecords) async {
    if (_user == null) return;
    await _firestore.restoreBackup(_user!.uid, sessions, dailyRecords,
        weightRecords, bloodPressureRecords, urineRecords, bowelRecords);
  }

  // ─── Drive バックアップ操作 ───────────────────────────────

  /// Drive連携を有効にする（同意ダイアログを表示）
  Future<bool> enableDriveBackup() async {
    if (_user == null) return false;
    _isDriveBackupRunning = true;
    notifyListeners();
    try {
      final token = await _driveService.getAccessToken(forceConsent: true);
      if (token == null) return false;
      _driveBackupEnabled = true;
      await _firestore.updateBackupSettings(_user!.uid, {'driveEnabled': true});
      notifyListeners();
      // 有効化直後に即バックアップ
      await _runDriveBackupNow(silent: true);
      return true;
    } finally {
      _isDriveBackupRunning = false;
      notifyListeners();
    }
  }

  /// Drive連携を無効にする
  Future<void> disableDriveBackup() async {
    if (_user == null) return;
    _driveBackupEnabled = false;
    await _firestore.updateBackupSettings(_user!.uid, {'driveEnabled': false});
    notifyListeners();
  }

  /// 手動で今すぐバックアップ（設定画面のボタン用）
  Future<void> manualDriveBackup() async {
    _isDriveBackupRunning = true;
    notifyListeners();
    try {
      await _runDriveBackupNow(silent: false);
    } finally {
      _isDriveBackupRunning = false;
      notifyListeners();
    }
  }

  Future<void> _runDriveBackupNow({required bool silent}) async {
    if (_user == null) return;
    final dateKey = todayDate;
    final zipBytes = _backupService.createZipBytes(
        _sessions, _dailyRecords, _weightRecords, _bloodPressureRecords, _urineRecords, _bowelRecords);
    final ok = await _driveService.runBackup(zipBytes, dateKey, silent: silent);
    if (ok) {
      _lastDriveBackupDate = dateKey;
      await _firestore.updateBackupSettings(
          _user!.uid, {'lastBackupDate': dateKey});
      notifyListeners();
    }
  }

  // ─── 内部 ─────────────────────────────────────────────────

  void _subscribeToFirestore(String uid) {
    _cancelFirestoreSubscriptions();
    _sessionsSub = _firestore.sessionsStream(uid).listen((sessions) {
      _sessions = sessions;
      notifyListeners();
    });
    _dailySub = _firestore.dailyRecordsStream(uid).listen((records) {
      _dailyRecords = records;
      notifyListeners();
    });
    _weightsSub = _firestore.weightRecordsStream(uid).listen((records) {
      _weightRecords = records;
      notifyListeners();
    });
    _bpSub = _firestore.bloodPressureRecordsStream(uid).listen((records) {
      _bloodPressureRecords = records;
      notifyListeners();
    });
    _urineSub = _firestore.urineRecordsStream(uid).listen((records) {
      _urineRecords = records;
      notifyListeners();
    });
    _bowelSub = _firestore.bowelRecordsStream(uid).listen((records) {
      _bowelRecords = records;
      notifyListeners();
    });
    // バックアップ設定を読み込み、必要なら自動バックアップを実行
    _initBackupSettings(uid);
  }

  Future<void> _initBackupSettings(String uid) async {
    final settings = await _firestore.getBackupSettings(uid);
    _driveBackupEnabled = (settings?['driveEnabled'] as bool?) ?? false;
    _lastDriveBackupDate = settings?['lastBackupDate'] as String?;
    notifyListeners();

    if (_driveBackupEnabled && _lastDriveBackupDate != todayDate) {
      // 今日のバックアップがまだ → サイレントで自動実行
      _isDriveBackupRunning = true;
      notifyListeners();
      await _runDriveBackupNow(silent: true);
      _isDriveBackupRunning = false;
      notifyListeners();
    }
  }

  void _cancelFirestoreSubscriptions() {
    _sessionsSub?.cancel();
    _dailySub?.cancel();
    _weightsSub?.cancel();
    _bpSub?.cancel();
    _urineSub?.cancel();
    _bowelSub?.cancel();
    _sessionsSub = null;
    _dailySub = null;
    _weightsSub = null;
    _bpSub = null;
    _urineSub = null;
    _bowelSub = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelFirestoreSubscriptions();
    super.dispose();
  }
}
