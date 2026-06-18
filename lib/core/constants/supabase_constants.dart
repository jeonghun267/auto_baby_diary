class SupabaseConstants {
  SupabaseConstants._();

  // 테이블 이름
  static const String tableProfiles = 'profiles';
  static const String tableChildProfiles = 'child_profiles';
  static const String tableDiaryEntries = 'diary_entries';
  static const String tableGrowthRecords = 'growth_records';
  static const String tableDailyRecords = 'daily_records';
  static const String tableMilestoneRecords = 'milestone_records';
  static const String tableVaccinationRecords = 'vaccination_records';

  // Storage 버킷
  static const String bucketMedia = 'diary-media';
  static const String bucketAudio = 'diary-audio';

  // Edge Function
  static const String functionProcessDiary = 'process-diary';

  // 컬럼 이름
  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colChildId = 'child_id';
  static const String colRecordedAt = 'recorded_at';
  static const String colVisionData = 'vision_data';
  static const String colSttTranscript = 'stt_transcript';
  static const String colLlmDraft = 'llm_draft';
  static const String colFinalText = 'final_text';
  static const String colMediaUrls = 'media_urls';
  static const String colEmotionSummary = 'emotion_summary';
  static const String colMilestoneDetected = 'milestone_detected';
  static const String colCreatedAt = 'created_at';
}
