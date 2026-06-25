class WeightRecord {
  final String id;
  final double weightKg;
  final DateTime measuredAt;
  final String date; // "yyyy-MM-dd"
  final String? note;

  const WeightRecord({
    required this.id,
    required this.weightKg,
    required this.measuredAt,
    required this.date,
    this.note,
  });

  WeightRecord copyWith({
    String? id,
    double? weightKg,
    DateTime? measuredAt,
    String? date,
    String? note,
  }) {
    return WeightRecord(
      id: id ?? this.id,
      weightKg: weightKg ?? this.weightKg,
      measuredAt: measuredAt ?? this.measuredAt,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'weightKg': weightKg,
        'measuredAt': measuredAt.toIso8601String(),
        'date': date,
        'note': note,
      };

  factory WeightRecord.fromJson(Map<String, dynamic> json) => WeightRecord(
        id: json['id'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        measuredAt: DateTime.parse(json['measuredAt'] as String),
        date: json['date'] as String,
        note: json['note'] as String?,
      );
}
