/// 발달 마일스톤
enum MilestoneCategory { physical, cognitive, social, language }

/// MilestoneCategory 문자열 변환 헬퍼
MilestoneCategory milestoneCategoryFromString(String value) {
  switch (value) {
    case 'physical':
    case '신체':
      return MilestoneCategory.physical;
    case 'cognitive':
    case '인지':
      return MilestoneCategory.cognitive;
    case 'social':
    case '사회성':
      return MilestoneCategory.social;
    case 'language':
    case '언어':
      return MilestoneCategory.language;
    default:
      return MilestoneCategory.physical;
  }
}

String milestoneCategoryToString(MilestoneCategory category) {
  switch (category) {
    case MilestoneCategory.physical:
      return '신체';
    case MilestoneCategory.cognitive:
      return '인지';
    case MilestoneCategory.social:
      return '사회성';
    case MilestoneCategory.language:
      return '언어';
  }
}

class MilestoneRecord {
  final String id;
  final String childId;
  final String title;
  final MilestoneCategory category;
  final int expectedMonth; // 예상 월령
  final DateTime? achievedAt;
  final String? note;
  final DateTime createdAt;

  MilestoneRecord({
    required this.id,
    required this.childId,
    required this.title,
    required this.category,
    required this.expectedMonth,
    this.achievedAt,
    this.note,
    required this.createdAt,
  });

  bool get isAchieved => achievedAt != null;

  factory MilestoneRecord.fromJson(Map<String, dynamic> json) {
    return MilestoneRecord(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      title: json['title'] as String,
      category: milestoneCategoryFromString(json['category'] as String),
      expectedMonth: json['expected_month'] as int,
      achievedAt: json['achieved_at'] != null
          ? DateTime.parse(json['achieved_at'] as String)
          : null,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'title': title,
      'category': milestoneCategoryToString(category),
      'expected_month': expectedMonth,
      'achieved_at': achievedAt?.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// 기본 마일스톤 목록 (한국어)
class DefaultMilestones {
  static List<Map<String, dynamic>> getDefaults() {
    return [
      // Physical milestones
      {'title': '목 가누기', 'category': 'physical', 'expected_month': 3},
      {'title': '뒤집기', 'category': 'physical', 'expected_month': 4},
      {'title': '혼자 앉기', 'category': 'physical', 'expected_month': 6},
      {'title': '기어다니기', 'category': 'physical', 'expected_month': 8},
      {'title': '잡고 서기', 'category': 'physical', 'expected_month': 9},
      {'title': '혼자 걷기', 'category': 'physical', 'expected_month': 12},
      {'title': '계단 오르기', 'category': 'physical', 'expected_month': 18},
      {'title': '달리기', 'category': 'physical', 'expected_month': 24},
      // Cognitive
      {'title': '물체 추적하기', 'category': 'cognitive', 'expected_month': 2},
      {'title': '물건 잡기', 'category': 'cognitive', 'expected_month': 4},
      {'title': '까꿍 놀이 이해', 'category': 'cognitive', 'expected_month': 6},
      {'title': '이름에 반응', 'category': 'cognitive', 'expected_month': 7},
      {'title': '간단한 지시 이해', 'category': 'cognitive', 'expected_month': 12},
      {'title': '모양 맞추기', 'category': 'cognitive', 'expected_month': 18},
      // Social
      {'title': '사회적 미소', 'category': 'social', 'expected_month': 2},
      {'title': '소리 내어 웃기', 'category': 'social', 'expected_month': 4},
      {'title': '낯가림', 'category': 'social', 'expected_month': 8},
      {'title': '손 흔들어 인사', 'category': 'social', 'expected_month': 10},
      {'title': '또래 관심 보이기', 'category': 'social', 'expected_month': 18},
      // Language
      {'title': '옹알이', 'category': 'language', 'expected_month': 3},
      {'title': '자음 소리 내기', 'category': 'language', 'expected_month': 6},
      {'title': '엄마/아빠 말하기', 'category': 'language', 'expected_month': 10},
      {'title': '2-3 단어 사용', 'category': 'language', 'expected_month': 14},
      {'title': '두 단어 조합', 'category': 'language', 'expected_month': 24},
    ];
  }
}
