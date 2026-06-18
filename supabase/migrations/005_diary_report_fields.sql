-- =============================================
-- 005_diary_report_fields.sql
-- Gemini 생성 부가 정보(development_report, parenting_tips) 영속화
-- =============================================

ALTER TABLE public.diary_entries
  ADD COLUMN IF NOT EXISTS development_report TEXT,
  ADD COLUMN IF NOT EXISTS parenting_tips TEXT[] DEFAULT '{}';
