-- =============================================
-- 006_diary_audio_url.sql
-- 음성 메모 원본 파일 URL 저장 (Storage diary-audio 버킷)
-- =============================================

ALTER TABLE public.diary_entries
  ADD COLUMN IF NOT EXISTS audio_url TEXT;
