/// 일상 기록 (수유/수면/기저귀/이유식)
enum DailyRecordType { feeding, sleep, diaper, babyFood }

/// DailyRecordType 문자열 변환 헬퍼
DailyRecordType dailyRecordTypeFromString(String value) {
  switch (value) {
    case 'feeding':
      return DailyRecordType.feeding;
    case 'sleep':
      return DailyRecordType.sleep;
    case 'diaper':
      return DailyRecordType.diaper;
    case 'babyFood':
    case 'baby_food':
      return DailyRecordType.babyFood;
    default:
      throw ArgumentError('Unknown DailyRecordType: $value');
  }
}

String dailyRecordTypeToString(DailyRecordType type) {
  switch (type) {
    case DailyRecordType.feeding:
      return 'feeding';
    case DailyRecordType.sleep:
      return 'sleep';
    case DailyRecordType.diaper:
      return 'diaper';
    case DailyRecordType.babyFood:
      return 'baby_food';
  }
}

class DailyRecord {
  final String id;
  final String childId;
  final DailyRecordType type;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final String?
      subType; // feeding: breast/bottle/formula, diaper: wet/dirty/both, babyFood: name
  final double? amount; // ml for feeding
  final String? note;
  final DateTime createdAt;

  DailyRecord({
    required this.id,
    required this.childId,
    required this.type,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    this.subType,
    this.amount,
    this.note,
    required this.createdAt,
  });

  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      type: dailyRecordTypeFromString(json['type'] as String),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      durationMinutes: json['duration_minutes'] as int?,
      subType: json['sub_type'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'type': dailyRecordTypeToString(type),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_minutes': durationMinutes,
      'sub_type': subType,
      'amount': amount,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
