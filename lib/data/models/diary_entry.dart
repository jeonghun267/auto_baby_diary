/// 육아일기 항목 모델
class DiaryEntry {
  final String id;
  final String userId;
  final String childId;
  final DateTime recordedAt;
  final Map<String, dynamic>? visionData;
  final String? sttTranscript;
  final String? llmDraft;
  final String? finalText;
  final List<String> mediaUrls;
  final String? audioUrl;
  final String? emotionSummary;
  final String? milestoneDetected;
  final String? developmentReport;
  final List<String> parentingTips;
  final List<String> tags;
  final bool isEdited;
  final DateTime createdAt;

  DiaryEntry({
    required this.id,
    required this.userId,
    required this.childId,
    required this.recordedAt,
    this.visionData,
    this.sttTranscript,
    this.llmDraft,
    this.finalText,
    this.mediaUrls = const [],
    this.audioUrl,
    this.emotionSummary,
    this.milestoneDetected,
    this.developmentReport,
    this.parentingTips = const [],
    this.tags = const [],
    this.isEdited = false,
    required this.createdAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      childId: json['child_id'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      visionData: json['vision_data'] as Map<String, dynamic>?,
      sttTranscript: json['stt_transcript'] as String?,
      llmDraft: json['llm_draft'] as String?,
      finalText: json['final_text'] as String?,
      mediaUrls: (json['media_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      audioUrl: json['audio_url'] as String?,
      emotionSummary: json['emotion_summary'] as String?,
      milestoneDetected: json['milestone_detected'] as String?,
      developmentReport: json['development_report'] as String?,
      parentingTips: (json['parenting_tips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      isEdited: json['is_edited'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'child_id': childId,
      'recorded_at': recordedAt.toIso8601String(),
      'vision_data': visionData,
      'stt_transcript': sttTranscript,
      'llm_draft': llmDraft,
      'final_text': finalText,
      'media_urls': mediaUrls,
      'audio_url': audioUrl,
      'emotion_summary': emotionSummary,
      'milestone_detected': milestoneDetected,
      'development_report': developmentReport,
      'parenting_tips': parentingTips,
      'tags': tags,
      'is_edited': isEdited,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DiaryEntry copyWith({
    String? finalText,
    String? llmDraft,
    String? emotionSummary,
    String? milestoneDetected,
    String? developmentReport,
    List<String>? parentingTips,
    List<String>? tags,
    bool? isEdited,
  }) {
    return DiaryEntry(
      id: id,
      userId: userId,
      childId: childId,
      recordedAt: recordedAt,
      visionData: visionData,
      sttTranscript: sttTranscript,
      llmDraft: llmDraft ?? this.llmDraft,
      finalText: finalText ?? this.finalText,
      mediaUrls: mediaUrls,
      audioUrl: audioUrl,
      emotionSummary: emotionSummary ?? this.emotionSummary,
      milestoneDetected: milestoneDetected ?? this.milestoneDetected,
      developmentReport: developmentReport ?? this.developmentReport,
      parentingTips: parentingTips ?? this.parentingTips,
      tags: tags ?? this.tags,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt,
    );
  }
}
