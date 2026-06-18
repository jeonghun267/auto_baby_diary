-- =============================================
-- Auto Baby Diary - 추가 테이블 (성장/일상/마일스톤/예방접종)
-- =============================================

-- 1. 성장 기록 테이블
CREATE TABLE IF NOT EXISTS growth_records (
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

-- 2. 일상 기록 테이블
CREATE TABLE IF NOT EXISTS daily_records (
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

-- 3. 발달 마일스톤 테이블
CREATE TABLE IF NOT EXISTS milestone_records (
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

-- 4. 예방접종 기록 테이블
CREATE TABLE IF NOT EXISTS vaccination_records (
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
CREATE INDEX idx_growth_records_child_id ON growth_records(child_id);
CREATE INDEX idx_growth_records_recorded_at ON growth_records(recorded_at);
CREATE INDEX idx_daily_records_child_id ON daily_records(child_id);
CREATE INDEX idx_daily_records_start_time ON daily_records(start_time);
CREATE INDEX idx_milestone_records_child_id ON milestone_records(child_id);
CREATE INDEX idx_vaccination_records_child_id ON vaccination_records(child_id);

-- =============================================
-- Row Level Security (RLS)
-- =============================================

-- growth_records RLS
ALTER TABLE growth_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own growth records"
  ON growth_records FOR SELECT
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can insert own growth records"
  ON growth_records FOR INSERT
  WITH CHECK (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update own growth records"
  ON growth_records FOR UPDATE
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete own growth records"
  ON growth_records FOR DELETE
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

-- daily_records RLS
ALTER TABLE daily_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own daily records"
  ON daily_records FOR SELECT
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can insert own daily records"
  ON daily_records FOR INSERT
  WITH CHECK (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update own daily records"
  ON daily_records FOR UPDATE
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete own daily records"
  ON daily_records FOR DELETE
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

-- milestone_records RLS
ALTER TABLE milestone_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own milestone records"
  ON milestone_records FOR SELECT
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can insert own milestone records"
  ON milestone_records FOR INSERT
  WITH CHECK (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update own milestone records"
  ON milestone_records FOR UPDATE
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete own milestone records"
  ON milestone_records FOR DELETE
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

-- vaccination_records RLS
ALTER TABLE vaccination_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own vaccination records"
  ON vaccination_records FOR SELECT
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can insert own vaccination records"
  ON vaccination_records FOR INSERT
  WITH CHECK (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can update own vaccination records"
  ON vaccination_records FOR UPDATE
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

CREATE POLICY "Users can delete own vaccination records"
  ON vaccination_records FOR DELETE
  USING (child_id IN (
    SELECT id FROM child_profiles WHERE user_id = auth.uid()
  ));

-- =============================================
-- updated_at 자동 갱신 트리거
-- =============================================

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
