-- =============================================
-- 003_fix_schema.sql
-- 누락된 컬럼/스키마 수정 (safe: IF NOT EXISTS)
-- Supabase Dashboard > SQL Editor 에서 실행
-- =============================================

-- 1. child_profiles에 gender 컬럼 추가 (아이 등록 실패 원인)
ALTER TABLE public.child_profiles
  ADD COLUMN IF NOT EXISTS gender TEXT NOT NULL DEFAULT '남아';

-- 2. vaccination_records: dose_number 컬럼이 없는 경우를 위한 보완
--    (앱 코드는 dose_number 컬럼을 사용)
ALTER TABLE public.vaccination_records
  ADD COLUMN IF NOT EXISTS dose_number INTEGER NOT NULL DEFAULT 1;

-- 3. diary_entries 누락 컬럼 보완
ALTER TABLE public.diary_entries
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';
ALTER TABLE public.diary_entries
  ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT false;

-- 4. growth_records user_id 참조가 없는 경우를 위한 RLS 보완
--    (child_id → child_profiles.user_id 로 체크하는 방식이므로 OK)

-- 5. profiles 테이블 nickname 컬럼 보완
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS nickname TEXT;

-- 6. Storage 버킷 생성 (SQL로는 불가 - 아래 Dashboard 안내 참고)
-- Dashboard > Storage > New bucket
--   이름: diary-media  (Public: ON)
--   이름: diary-audio  (Public: ON)

-- 7. 현재 상태 확인용 쿼리 (실행 후 결과 확인)
SELECT
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'child_profiles', 'diary_entries', 'growth_records',
    'milestone_records', 'vaccination_records', 'daily_records', 'profiles'
  )
ORDER BY table_name, ordinal_position;
