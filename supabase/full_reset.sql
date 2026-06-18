-- =============================================
-- Auto Baby Diary - 전체 리셋 스크립트
-- Supabase SQL Editor에 통째로 붙여넣고 실행
-- =============================================
-- 주의: 이 스크립트는 기존 데이터를 모두 삭제합니다.
-- =============================================

-- =============================================
-- 0. 기존 객체 삭제 (CASCADE로 의존 객체까지)
-- =============================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

DROP TABLE IF EXISTS vaccination_records CASCADE;
DROP TABLE IF EXISTS milestone_records CASCADE;
DROP TABLE IF EXISTS daily_records CASCADE;
DROP TABLE IF EXISTS growth_records CASCADE;
DROP TABLE IF EXISTS diary_entries CASCADE;
DROP TABLE IF EXISTS child_profiles CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at() CASCADE;

-- =============================================
-- 1. 사용자 프로필 테이블
-- =============================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT,
  nickname TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- =============================================
-- 2. 아이 프로필 테이블 (gender 컬럼 포함)
-- =============================================
CREATE TABLE child_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  birth_date DATE NOT NULL,
  gender TEXT NOT NULL DEFAULT '남아',
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- =============================================
-- 3. 육아일기 항목 테이블
-- =============================================
CREATE TABLE diary_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  vision_data JSONB,
  stt_transcript TEXT,
  llm_draft TEXT,
  final_text TEXT,
  media_urls TEXT[] DEFAULT '{}',
  tags TEXT[] DEFAULT '{}',
  is_edited BOOLEAN DEFAULT false,
  emotion_summary TEXT,
  milestone_detected TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- =============================================
-- 4. 성장 기록 테이블
-- =============================================
CREATE TABLE growth_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  height DOUBLE PRECISION,
  weight DOUBLE PRECISION,
  head_circumference DOUBLE PRECISION,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- =============================================
-- 5. 일상 기록 테이블
-- =============================================
CREATE TABLE daily_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  duration_minutes INTEGER,
  sub_type TEXT,
  amount DOUBLE PRECISION,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- =============================================
-- 6. 발달 마일스톤 테이블
-- =============================================
CREATE TABLE milestone_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  expected_month INTEGER NOT NULL,
  achieved_at TIMESTAMPTZ,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- =============================================
-- 7. 예방접종 기록 테이블
-- =============================================
CREATE TABLE vaccination_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  recommended_month INTEGER NOT NULL,
  dose_number INTEGER NOT NULL,
  completed_at TIMESTAMPTZ,
  hospital TEXT,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- =============================================
-- 인덱스
-- =============================================
CREATE INDEX idx_child_profiles_user_id ON child_profiles(user_id);
CREATE INDEX idx_diary_entries_user_id ON diary_entries(user_id);
CREATE INDEX idx_diary_entries_child_id ON diary_entries(child_id);
CREATE INDEX idx_diary_entries_recorded_at ON diary_entries(recorded_at);
CREATE INDEX idx_growth_records_child_id ON growth_records(child_id);
CREATE INDEX idx_growth_records_recorded_at ON growth_records(recorded_at);
CREATE INDEX idx_daily_records_child_id ON daily_records(child_id);
CREATE INDEX idx_daily_records_start_time ON daily_records(start_time);
CREATE INDEX idx_milestone_records_child_id ON milestone_records(child_id);
CREATE INDEX idx_vaccination_records_child_id ON vaccination_records(child_id);

-- =============================================
-- Row Level Security (RLS)
-- =============================================

-- profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- child_profiles
ALTER TABLE child_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own children"
  ON child_profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own children"
  ON child_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own children"
  ON child_profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own children"
  ON child_profiles FOR DELETE
  USING (auth.uid() = user_id);

-- diary_entries
ALTER TABLE diary_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own diary entries"
  ON diary_entries FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own diary entries"
  ON diary_entries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own diary entries"
  ON diary_entries FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own diary entries"
  ON diary_entries FOR DELETE
  USING (auth.uid() = user_id);

-- growth_records
ALTER TABLE growth_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own growth records"
  ON growth_records FOR SELECT
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert own growth records"
  ON growth_records FOR INSERT
  WITH CHECK (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update own growth records"
  ON growth_records FOR UPDATE
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete own growth records"
  ON growth_records FOR DELETE
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

-- daily_records
ALTER TABLE daily_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own daily records"
  ON daily_records FOR SELECT
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert own daily records"
  ON daily_records FOR INSERT
  WITH CHECK (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update own daily records"
  ON daily_records FOR UPDATE
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete own daily records"
  ON daily_records FOR DELETE
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

-- milestone_records
ALTER TABLE milestone_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own milestone records"
  ON milestone_records FOR SELECT
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert own milestone records"
  ON milestone_records FOR INSERT
  WITH CHECK (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update own milestone records"
  ON milestone_records FOR UPDATE
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete own milestone records"
  ON milestone_records FOR DELETE
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

-- vaccination_records
ALTER TABLE vaccination_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own vaccination records"
  ON vaccination_records FOR SELECT
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert own vaccination records"
  ON vaccination_records FOR INSERT
  WITH CHECK (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can update own vaccination records"
  ON vaccination_records FOR UPDATE
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

CREATE POLICY "Users can delete own vaccination records"
  ON vaccination_records FOR DELETE
  USING (child_id IN (SELECT id FROM child_profiles WHERE user_id = auth.uid()));

-- =============================================
-- 함수 & 트리거
-- =============================================

-- 신규 가입자에 대한 profiles 행 자동 생성
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER child_profiles_updated_at
  BEFORE UPDATE ON child_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER diary_entries_updated_at
  BEFORE UPDATE ON diary_entries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER growth_records_updated_at
  BEFORE UPDATE ON growth_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER daily_records_updated_at
  BEFORE UPDATE ON daily_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER milestone_records_updated_at
  BEFORE UPDATE ON milestone_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER vaccination_records_updated_at
  BEFORE UPDATE ON vaccination_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================
-- 기존 가입자 백필 (auth.users에는 있는데 profiles에 없는 경우)
-- =============================================
INSERT INTO profiles (id, email)
SELECT id, email FROM auth.users
WHERE id NOT IN (SELECT id FROM profiles);

-- =============================================
-- Storage 버킷 & 정책
-- =============================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('diary-media', 'diary-media', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('diary-audio', 'diary-audio', true)
ON CONFLICT (id) DO NOTHING;

-- 기존 정책이 있을 수 있으니 먼저 제거
DROP POLICY IF EXISTS "diary_media_insert" ON storage.objects;
DROP POLICY IF EXISTS "diary_media_select" ON storage.objects;
DROP POLICY IF EXISTS "diary_media_delete" ON storage.objects;
DROP POLICY IF EXISTS "diary_audio_insert" ON storage.objects;
DROP POLICY IF EXISTS "diary_audio_select" ON storage.objects;
DROP POLICY IF EXISTS "diary_audio_delete" ON storage.objects;

-- diary-media: 본인 폴더에만 업로드 가능, 누구나 조회
CREATE POLICY "diary_media_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'diary-media'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "diary_media_select"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'diary-media');

CREATE POLICY "diary_media_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'diary-media'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- diary-audio: 동일
CREATE POLICY "diary_audio_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'diary-audio'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "diary_audio_select"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'diary-audio');

CREATE POLICY "diary_audio_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'diary-audio'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- =============================================
-- 끝. PostgREST 스키마 캐시 새로고침
-- =============================================
NOTIFY pgrst, 'reload schema';
