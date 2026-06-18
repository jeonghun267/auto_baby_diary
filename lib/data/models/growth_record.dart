/// 성장 기록 모델 (키/몸무게)
class GrowthRecord {
  final String id;
  final String childId;
  final DateTime recordedAt;
  final double? height; // cm
  final double? weight; // kg
  final double? headCircumference; // cm
  final String? note;
  final DateTime createdAt;

  GrowthRecord({
    required this.id,
    required this.childId,
    required this.recordedAt,
    this.height,
    this.weight,
    this.headCircumference,
    this.note,
    required this.createdAt,
  });

  factory GrowthRecord.fromJson(Map<String, dynamic> json) {
    return GrowthRecord(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      headCircumference: (json['head_circumference'] as num?)?.toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'recorded_at': recordedAt.toIso8601String(),
      'height': height,
      'weight': weight,
      'head_circumference': headCircumference,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
