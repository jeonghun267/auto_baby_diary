/// 아이 프로필 모델
class ChildProfile {
  final String id;
  final String userId;
  final String name;
  final DateTime birthDate;
  final String gender;
  final String? photoUrl;
  final DateTime createdAt;

  ChildProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.birthDate,
    this.gender = '남아',
    this.photoUrl,
    required this.createdAt,
  });

  /// 현재 개월 수 계산
  int get ageInMonths {
    final now = DateTime.now();
    return (now.year - birthDate.year) * 12 + now.month - birthDate.month;
  }

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      birthDate: DateTime.parse(json['birth_date'] as String),
      gender: json['gender'] as String? ?? '남아',
      photoUrl: json['photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'birth_date': birthDate.toIso8601String(),
      'gender': gender,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
