class BloodPressureRecord {
  final String id;
  final int systolic;
  final int diastolic;
  final int? pulse;
  final String? timing;
  final DateTime measuredAt;
  final String date; // "yyyy-MM-dd"
  final String? note;

  const BloodPressureRecord({
    required this.id,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    this.timing,
    required this.measuredAt,
    required this.date,
    this.note,
  });

  BloodPressureRecord copyWith({
    String? id,
    int? systolic,
    int? diastolic,
    int? pulse,
    String? timing,
    DateTime? measuredAt,
    String? date,
    String? note,
  }) {
    return BloodPressureRecord(
      id: id ?? this.id,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulse: pulse ?? this.pulse,
      timing: timing ?? this.timing,
      measuredAt: measuredAt ?? this.measuredAt,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': pulse,
        'timing': timing,
        'measuredAt': measuredAt.toIso8601String(),
        'date': date,
        'note': note,
      };

  factory BloodPressureRecord.fromJson(Map<String, dynamic> json) =>
      BloodPressureRecord(
        id: json['id'] as String,
        systolic: (json['systolic'] as num).toInt(),
        diastolic: (json['diastolic'] as num).toInt(),
        pulse: (json['pulse'] as num?)?.toInt(),
        timing: json['timing'] as String?,
        measuredAt: DateTime.parse(json['measuredAt'] as String),
        date: json['date'] as String,
        note: json['note'] as String?,
      );
}
