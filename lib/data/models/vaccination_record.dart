/// 예방접종 기록
class VaccinationRecord {
  final String id;
  final String childId;
  final String name;
  final String? description;
  final int recommendedMonth; // 권장 월령
  final int doseNumber; // 1차, 2차 등
  final DateTime? completedAt;
  final String? hospital;
  final String? note;
  final DateTime createdAt;

  VaccinationRecord({
    required this.id,
    required this.childId,
    required this.name,
    this.description,
    required this.recommendedMonth,
    required this.doseNumber,
    this.completedAt,
    this.hospital,
    this.note,
    required this.createdAt,
  });

  bool get isCompleted => completedAt != null;

  factory VaccinationRecord.fromJson(Map<String, dynamic> json) {
    return VaccinationRecord(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      recommendedMonth: json['recommended_month'] as int,
      doseNumber: json['dose_number'] as int,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      hospital: json['hospital'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'name': name,
      'description': description,
      'recommended_month': recommendedMonth,
      'dose_number': doseNumber,
      'completed_at': completedAt?.toIso8601String(),
      'hospital': hospital,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// 한국 기본 예방접종 일정
class DefaultVaccinations {
  static List<Map<String, dynamic>> getDefaults() {
    return [
      {'name': 'BCG (결핵)', 'recommended_month': 0, 'dose_number': 1},
      {'name': 'B형간염', 'recommended_month': 0, 'dose_number': 1},
      {'name': 'B형간염', 'recommended_month': 1, 'dose_number': 2},
      {'name': 'B형간염', 'recommended_month': 6, 'dose_number': 3},
      {
        'name': 'DTaP (디프테리아/파상풍/백일해)',
        'recommended_month': 2,
        'dose_number': 1
      },
      {'name': 'DTaP', 'recommended_month': 4, 'dose_number': 2},
      {'name': 'DTaP', 'recommended_month': 6, 'dose_number': 3},
      {'name': 'DTaP', 'recommended_month': 15, 'dose_number': 4},
      {'name': 'IPV (폴리오)', 'recommended_month': 2, 'dose_number': 1},
      {'name': 'IPV', 'recommended_month': 4, 'dose_number': 2},
      {'name': 'IPV', 'recommended_month': 6, 'dose_number': 3},
      {
        'name': 'MMR (홍역/유행성이하선염/풍진)',
        'recommended_month': 12,
        'dose_number': 1
      },
      {'name': '수두', 'recommended_month': 12, 'dose_number': 1},
      {'name': '일본뇌염 (사백신)', 'recommended_month': 12, 'dose_number': 1},
      {'name': '일본뇌염 (사백신)', 'recommended_month': 13, 'dose_number': 2},
      {'name': 'A형간염', 'recommended_month': 12, 'dose_number': 1},
      {'name': 'A형간염', 'recommended_month': 18, 'dose_number': 2},
      {
        'name': '인플루엔자',
        'recommended_month': 6,
        'dose_number': 1,
        'description': '매년 접종'
      },
    ];
  }
}
