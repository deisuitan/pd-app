import 'package:intl/intl.dart';

enum DrainAppearance {
  normal('正常'),
  fibrin('フィブリン'),
  cloudy('混濁'),
  other('その他');

  const DrainAppearance(this.label);
  final String label;

  static DrainAppearance fromLabel(String label) =>
      DrainAppearance.values.firstWhere((e) => e.label == label,
          orElse: () => DrainAppearance.normal);
}

class PDSession {
  final String id;
  final String date; // "2026-06-21" — 貯留開始時刻の日付
  final DateTime fillStartTime; // ①貯留開始時刻
  final DateTime drainStartTime; // ②廃液開始時刻
  final String dialysateType; // ③透析液種類
  final int? drainVolume; // ④廃液量 (mL) — 未入力のときは null
  final int fillVolume; // ⑤注液量 (固定 2000)
  final int? drainDurationMinutes; // ⑦廃液時間（次セッション入力後に設定）
  final DrainAppearance drainAppearance; // ⑧廃液の状態
  final String? appearanceNote; // 正常以外のメモ
  final List<String> photoStoragePaths; // 廃液写真のStorageパス（複数枚）

  const PDSession({
    required this.id,
    required this.date,
    required this.fillStartTime,
    required this.drainStartTime,
    required this.dialysateType,
    required this.drainVolume,
    this.fillVolume = 2000,
    this.drainDurationMinutes,
    required this.drainAppearance,
    this.appearanceNote,
    this.photoStoragePaths = const [],
  });

  // ⑥除水量 = 廃液量 - 注液量（廃液量未入力の場合は null）
  int? get ultrafiltration =>
      drainVolume == null ? null : drainVolume! - fillVolume;

  bool get isUltrafiltrationNegative => (ultrafiltration ?? 0) < 0;

  String get dialysateShortName =>
      dialysateType == 'レギュニールLCA2.5' ? 'LCA2.5' : 'EXT';

  String get fillTimeLabel => DateFormat('HH:mm').format(fillStartTime);
  String get drainTimeLabel => DateFormat('HH:mm').format(drainStartTime);

  // ⑦廃液時間のラベル（次セッションの①と自セッションの②の差）
  String get drainDurationLabel {
    if (drainDurationMinutes == null) return null.toString();
    final h = drainDurationMinutes! ~/ 60;
    final m = drainDurationMinutes! % 60;
    if (h > 0) return '$h時間$m分';
    return '$m分';
  }

  // 貯留時間 = 廃液開始時刻 - 貯留開始時刻（同セッション内で計算可能）
  int get dwellDurationMinutes =>
      drainStartTime.difference(fillStartTime).inMinutes;

  String get dwellDurationLabel {
    final h = dwellDurationMinutes ~/ 60;
    final m = dwellDurationMinutes % 60;
    if (h > 0) return '$h時間$m分';
    return '$m分';
  }

  PDSession copyWith({
    String? id,
    String? date,
    DateTime? fillStartTime,
    DateTime? drainStartTime,
    String? dialysateType,
    int? drainVolume,
    int? fillVolume,
    int? drainDurationMinutes,
    DrainAppearance? drainAppearance,
    String? appearanceNote,
    List<String>? photoStoragePaths,
  }) {
    return PDSession(
      id: id ?? this.id,
      date: date ?? this.date,
      fillStartTime: fillStartTime ?? this.fillStartTime,
      drainStartTime: drainStartTime ?? this.drainStartTime,
      dialysateType: dialysateType ?? this.dialysateType,
      drainVolume: drainVolume ?? this.drainVolume,
      fillVolume: fillVolume ?? this.fillVolume,
      drainDurationMinutes: drainDurationMinutes ?? this.drainDurationMinutes,
      drainAppearance: drainAppearance ?? this.drainAppearance,
      appearanceNote: appearanceNote ?? this.appearanceNote,
      photoStoragePaths: photoStoragePaths ?? this.photoStoragePaths,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'fillStartTime': fillStartTime.toIso8601String(),
        'drainStartTime': drainStartTime.toIso8601String(),
        'dialysateType': dialysateType,
        'drainVolume': drainVolume,
        'fillVolume': fillVolume,
        'drainDurationMinutes': drainDurationMinutes,
        'drainAppearance': drainAppearance.label,
        'appearanceNote': appearanceNote,
        'photoStoragePaths': photoStoragePaths,
      };

  factory PDSession.fromJson(Map<String, dynamic> json) => PDSession(
        id: json['id'] as String,
        date: json['date'] as String,
        fillStartTime: DateTime.parse(json['fillStartTime'] as String),
        drainStartTime: DateTime.parse(json['drainStartTime'] as String),
        dialysateType: json['dialysateType'] as String,
        drainVolume: json['drainVolume'] as int?,
        fillVolume: (json['fillVolume'] as int?) ?? 2000,
        drainDurationMinutes: json['drainDurationMinutes'] as int?,
        drainAppearance:
            DrainAppearance.fromLabel(json['drainAppearance'] as String),
        appearanceNote: json['appearanceNote'] as String?,
        photoStoragePaths:
            List<String>.from(json['photoStoragePaths'] as List? ?? []),
      );
}

const kDialysateTypes = ['レギュニールLCA2.5', 'エクストラニール'];
