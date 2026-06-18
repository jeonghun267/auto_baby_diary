/// 가족 멤버 모델
class FamilyMember {
  final String id;
  final String childId;
  final String userId;
  final String role; // 'parent', 'family', 'viewer'
  final String? inviteCode;
  final String? nickname;
  final DateTime createdAt;

  FamilyMember({
    required this.id,
    required this.childId,
    required this.userId,
    required this.role,
    this.inviteCode,
    this.nickname,
    required this.createdAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'viewer',
      inviteCode: json['invite_code'] as String?,
      nickname: json['nickname'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'user_id': userId,
      'role': role,
      'invite_code': inviteCode,
      'nickname': nickname,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
