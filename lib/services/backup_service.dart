import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import '../models/blood_pressure_record.dart';
import '../models/bowel_record.dart';
import '../models/daily_record.dart';
import '../models/pd_session.dart';
import '../models/urine_record.dart';
import '../models/weight_record.dart';

class BackupService {
  // ─── ZIP バイト生成（ダウンロードもDriveアップロードも共用）──
  Uint8List createZipBytes(
      List<PDSession> sessions,
      List<DailyRecord> dailyRecords,
      List<WeightRecord> weightRecords,
      List<BloodPressureRecord> bloodPressureRecords,
      List<UrineRecord> urineRecords,
      List<BowelRecord> bowelRecords) {
    final archive = Archive();
    _addJson(archive, 'sessions.json', sessions.map((s) => s.toJson()).toList());
    _addJson(archive, 'daily_records.json', dailyRecords.map((r) => r.toJson()).toList());
    _addJson(archive, 'weight_records.json', weightRecords.map((r) => r.toJson()).toList());
    _addJson(archive, 'blood_pressure_records.json',
        bloodPressureRecords.map((r) => r.toJson()).toList());
    _addJson(archive, 'urine_records.json',
        urineRecords.map((r) => r.toJson()).toList());
    _addJson(archive, 'bowel_records.json',
        bowelRecords.map((r) => r.toJson()).toList());
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // ─── ZIP ダウンロード ─────────────────────────────────────
  void downloadZip(
      List<PDSession> sessions,
      List<DailyRecord> dailyRecords,
      List<WeightRecord> weightRecords,
      List<BloodPressureRecord> bloodPressureRecords,
      List<UrineRecord> urineRecords,
      List<BowelRecord> bowelRecords) {
    final zipBytes = createZipBytes(sessions, dailyRecords, weightRecords,
        bloodPressureRecords, urineRecords, bowelRecords);
    final tag = DateFormat('yyyyMMdd').format(DateTime.now());
    _download(zipBytes, 'pd_backup_$tag.zip', 'application/zip');
  }

  // ─── CSV ダウンロード ─────────────────────────────────────
  void downloadCsv(List<PDSession> sessions) {
    final sorted = List<PDSession>.from(sessions)
      ..sort((a, b) => a.fillStartTime.compareTo(b.fillStartTime));

    final buf = StringBuffer();
    buf.writeln('日付,貯留開始,廃液開始,透析液,廃液量(mL),注液量(mL),除水量(mL),貯留時間(分),廃液時間(分),廃液外観,メモ');
    for (final s in sorted) {
      final row = [
        s.date,
        DateFormat('HH:mm').format(s.fillStartTime),
        DateFormat('HH:mm').format(s.drainStartTime),
        s.dialysateType,
        '${s.drainVolume}',
        '${s.fillVolume}',
        '${s.ultrafiltration}',
        '${s.dwellDurationMinutes}',
        s.drainDurationMinutes != null ? '${s.drainDurationMinutes}' : '',
        s.drainAppearance.label,
        s.appearanceNote ?? '',
      ].map((c) => '"${c.replaceAll('"', '""')}"').join(',');
      buf.writeln(row);
    }

    final tag = DateFormat('yyyyMMdd').format(DateTime.now());
    // BOM付きUTF-8 → Excelで文字化けしない
    final bom = [0xEF, 0xBB, 0xBF];
    _download(
      Uint8List.fromList([...bom, ...utf8.encode(buf.toString())]),
      'pd_records_$tag.csv',
      'text/csv;charset=utf-8',
    );
  }

  // ─── ZIP 選択 → パース ──────────────────────────────────
  Future<(List<PDSession>, List<DailyRecord>, List<WeightRecord>, List<BloodPressureRecord>, List<UrineRecord>, List<BowelRecord>)>
      pickAndReadZip() async {
    final bytes = await _pickFile('.zip');
    if (bytes == null) throw Exception('ファイルが選択されませんでした');

    final archive = ZipDecoder().decodeBytes(bytes);
    List<PDSession> sessions = [];
    List<DailyRecord> dailyRecords = [];
    List<WeightRecord> weightRecords = [];
    List<BloodPressureRecord> bloodPressureRecords = [];
    List<UrineRecord> urineRecords = [];
    List<BowelRecord> bowelRecords = [];

    for (final file in archive) {
      if (!file.isFile) continue;
      final text = utf8.decode(file.content as List<int>);
      if (file.name == 'sessions.json') {
        final list = jsonDecode(text) as List;
        sessions = list.map((e) => PDSession.fromJson(e as Map<String, dynamic>)).toList();
      } else if (file.name == 'daily_records.json') {
        final list = jsonDecode(text) as List;
        dailyRecords = list.map((e) => DailyRecord.fromJson(e as Map<String, dynamic>)).toList();
      } else if (file.name == 'weight_records.json') {
        final list = jsonDecode(text) as List;
        weightRecords =
            list.map((e) => WeightRecord.fromJson(e as Map<String, dynamic>)).toList();
      } else if (file.name == 'blood_pressure_records.json') {
        final list = jsonDecode(text) as List;
        bloodPressureRecords =
            list.map((e) => BloodPressureRecord.fromJson(e as Map<String, dynamic>)).toList();
      } else if (file.name == 'urine_records.json') {
        final list = jsonDecode(text) as List;
        urineRecords =
            list.map((e) => UrineRecord.fromJson(e as Map<String, dynamic>)).toList();
      } else if (file.name == 'bowel_records.json') {
        final list = jsonDecode(text) as List;
        bowelRecords =
            list.map((e) => BowelRecord.fromJson(e as Map<String, dynamic>)).toList();
      }
    }

    return (sessions, dailyRecords, weightRecords, bloodPressureRecords, urineRecords, bowelRecords);
  }

  // ─── 血圧CSV ダウンロード ──────────────────────────────────
  void downloadBloodPressureCsv(List<BloodPressureRecord> records) {
    final sorted = List<BloodPressureRecord>.from(records)
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final buf = StringBuffer();
    buf.writeln('日付,時刻,測定タイミング,収縮期(mmHg),拡張期(mmHg),脈拍(bpm),メモ');
    for (final r in sorted) {
      final row = [
        r.date,
        DateFormat('HH:mm').format(r.measuredAt),
        r.timing ?? '',
        '${r.systolic}',
        '${r.diastolic}',
        r.pulse != null ? '${r.pulse}' : '',
        r.note ?? '',
      ].map((c) => '"${c.replaceAll('"', '""')}"').join(',');
      buf.writeln(row);
    }

    // 期間平均行（記録が1件以上あるとき）
    if (sorted.isNotEmpty) {
      final avgSys = sorted.map((r) => r.systolic).reduce((a, b) => a + b) / sorted.length;
      final avgDia = sorted.map((r) => r.diastolic).reduce((a, b) => a + b) / sorted.length;
      buf.writeln('"期間平均","","","${avgSys.toStringAsFixed(1)}","${avgDia.toStringAsFixed(1)}","",""');
    }

    final tag = DateFormat('yyyyMMdd').format(DateTime.now());
    final bom = [0xEF, 0xBB, 0xBF];
    _download(
      Uint8List.fromList([...bom, ...utf8.encode(buf.toString())]),
      'pd_bp_$tag.csv',
      'text/csv;charset=utf-8',
    );
  }

  // ─── 体重CSV ダウンロード ──────────────────────────────────
  void downloadWeightCsv(List<WeightRecord> weightRecords) {
    final sorted = List<WeightRecord>.from(weightRecords)
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    final buf = StringBuffer();
    buf.writeln('日付,時刻,体重(kg),メモ');
    for (final r in sorted) {
      final row = [
        r.date,
        DateFormat('HH:mm').format(r.measuredAt),
        '${r.weightKg}',
        r.note ?? '',
      ].map((c) => '"${c.replaceAll('"', '""')}"').join(',');
      buf.writeln(row);
    }

    final tag = DateFormat('yyyyMMdd').format(DateTime.now());
    final bom = [0xEF, 0xBB, 0xBF];
    _download(
      Uint8List.fromList([...bom, ...utf8.encode(buf.toString())]),
      'pd_weight_$tag.csv',
      'text/csv;charset=utf-8',
    );
  }

  // ─── private ──────────────────────────────────────────────

  void _addJson(Archive archive, String name, Object data) {
    final bytes = utf8.encode(jsonEncode(data));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  void _download(Uint8List bytes, String filename, String mime) {
    // Uint8List.toJS → JSUint8Array。Blob の BlobPart として渡せる型
    final blob = web.Blob(
      [bytes.toJS as JSAny].toJS,
      web.BlobPropertyBag(type: mime),
    );
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = url;
    a.setAttribute('download', filename);
    web.document.body!.append(a);
    a.click();
    a.remove();
    web.URL.revokeObjectURL(url);
  }

  Future<Uint8List?> _pickFile(String accept) {
    final completer = Completer<Uint8List?>();
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = accept;
    web.document.body!.append(input);

    input.onchange = ((web.Event _) {
      final files = input.files;
      if (files == null || files.length == 0) {
        input.remove();
        completer.complete(null);
        return;
      }
      final reader = web.FileReader();
      reader.readAsArrayBuffer(files.item(0)!);

      reader.onload = ((web.Event _) {
        input.remove();
        // readAsArrayBuffer の結果は JSArrayBuffer
        final buffer = reader.result as JSArrayBuffer;
        completer.complete(buffer.toDart.asUint8List());
      }).toJS;

      reader.onerror = ((web.Event _) {
        input.remove();
        completer.complete(null);
      }).toJS;
    }).toJS;

    input.click();
    return completer.future;
  }
}
