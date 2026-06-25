enum BowelConsistency {
  pellet,
  hard,
  normal,
  soft,
  watery;

  String get label => const {
        BowelConsistency.pellet: 'コロコロ',
        BowelConsistency.hard: '硬め',
        BowelConsistency.normal: 'ふつう',
        BowelConsistency.soft: '軟らかめ',
        BowelConsistency.watery: '水っぽい',
      }[this]!;
}

class BowelRecord {
  final String id;
  final DateTime recordedAt;
  final String date; // "yyyy-MM-dd"
  final BowelConsistency consistency;
  final String? note;

  const BowelRecord({
    required this.id,
    required this.recordedAt,
    required this.date,
    required this.consistency,
    this.note,
  });

  BowelRecord copyWith({
    String? id,
    DateTime? recordedAt,
    String? date,
    BowelConsistency? consistency,
    String? note,
  }) {
    return BowelRecord(
      id: id ?? this.id,
      recordedAt: recordedAt ?? this.recordedAt,
      date: date ?? this.date,
      consistency: consistency ?? this.consistency,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': recordedAt.toIso8601String(),
        'date': date,
        'consistency': consistency.name,
        'note': note,
      };

  factory BowelRecord.fromJson(Map<String, dynamic> json) => BowelRecord(
        id: json['id'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        date: json['date'] as String,
        consistency: BowelConsistency.values.firstWhere(
          (e) => e.name == (json['consistency'] as String? ?? 'normal'),
          orElse: () => BowelConsistency.normal,
        ),
        note: json['note'] as String?,
      );
}
