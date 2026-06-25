class UrineRecord {
  final String id;
  final int urineVolumeMl;
  final DateTime recordedAt;
  final String date; // "yyyy-MM-dd"
  final String? note;

  const UrineRecord({
    required this.id,
    required this.urineVolumeMl,
    required this.recordedAt,
    required this.date,
    this.note,
  });

  UrineRecord copyWith({
    String? id,
    int? urineVolumeMl,
    DateTime? recordedAt,
    String? date,
    String? note,
  }) {
    return UrineRecord(
      id: id ?? this.id,
      urineVolumeMl: urineVolumeMl ?? this.urineVolumeMl,
      recordedAt: recordedAt ?? this.recordedAt,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'urineVolumeMl': urineVolumeMl,
        'recordedAt': recordedAt.toIso8601String(),
        'date': date,
        'note': note,
      };

  factory UrineRecord.fromJson(Map<String, dynamic> json) => UrineRecord(
        id: json['id'] as String,
        urineVolumeMl: (json['urineVolumeMl'] as num).toInt(),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        date: json['date'] as String,
        note: json['note'] as String?,
      );
}
