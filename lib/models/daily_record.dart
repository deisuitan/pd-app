class DailyRecord {
  final String date; // "2026-06-21"
  final String exitSiteCondition; // "正常" or 自由記載
  final DateTime recordedAt;

  const DailyRecord({
    required this.date,
    required this.exitSiteCondition,
    required this.recordedAt,
  });

  bool get isNormal => exitSiteCondition == '正常';

  DailyRecord copyWith({
    String? date,
    String? exitSiteCondition,
    DateTime? recordedAt,
  }) {
    return DailyRecord(
      date: date ?? this.date,
      exitSiteCondition: exitSiteCondition ?? this.exitSiteCondition,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'exitSiteCondition': exitSiteCondition,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
        date: json['date'] as String,
        exitSiteCondition: json['exitSiteCondition'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      );
}
