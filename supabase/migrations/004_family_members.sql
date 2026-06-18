-- =============================================
-- 004_family_members.sql
-- 가족 공유 테이블 + RLS
-- =============================================

-- 1. 가족 멤버 테이블
CREATE TABLE IF NOT EXISTS family_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'family' CHECK (role IN ('parent', 'family', 'viewer')),
  nickname TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (child_id, user_id)
);

-- 2. 가족 초대 코드 테이블 (만료 가능한 일회성 코드)
CREATE TABLE IF NOT EXISTS family_invites (
  code TEXT PRIMARY KEY,
  child_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'family' CHECK (role IN ('family', 'viewer')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  used_at TIMESTAMPTZ
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_family_members_child_id ON family_members(child_id);
CREATE INDEX IF NOT EXISTS idx_family_members_user_id ON family_members(user_id);
CREATE INDEX IF NOT EXISTS idx_family_invites_child_id ON family_invites(child_id);

-- =============================================
-- RLS
-- =============================================
ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_invites ENABLE ROW LEVEL SECURITY;

-- family_members: 같은 child를 공유하는 사람만 조회 가능
DROP POLICY IF EXISTS "Members can view own family" ON family_members;
CREATE POLICY "Members can view own family"
  ON family_members FOR SELECT
  USING (
    user_id = auth.uid()
    OR child_id IN (
      SELECT id FROM child_profiles WHERE user_id = auth.uid()
    )
    OR child_id IN (
      SELECT child_id FROM family_members WHERE user_id = auth.uid()
    )
  );

-- family_members: child 소유자만 추가/수정/삭제 가능
DROP POLICY IF EXISTS "Owners can insert family" ON family_members;
CREATE POLICY "Owners can insert family"
  ON family_members FOR INSERT
  WITH CHECK (
    child_id IN (
      SELECT id FROM child_profiles WHERE user_id = auth.uid()
    )
    OR user_id = auth.uid()
  );

DROP POLICY IF EXISTS "Owners can update family" ON family_members;
CREATE POLICY "Owners can update family"
  ON family_members FOR UPDATE
  USING (
    child_id IN (
      SELECT id FROM child_profiles WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Owners can delete family" ON family_members;
CREATE POLICY "Owners can delete family"
  ON family_members FOR DELETE
  USING (
    child_id IN (
      SELECT id FROM child_profiles WHERE user_id = auth.uid()
    )
    OR user_id = auth.uid()
  );

-- family_invites: 자기 코드는 조회 가능, 코드 자체로도 조회 가능
DROP POLICY IF EXISTS "Inviter or anyone with code can read" ON family_invites;
CREATE POLICY "Inviter or anyone with code can read"
  ON family_invites FOR SELECT
  USING (true);  -- 코드를 알면 누구나 조회 가능 (입장용)

DROP POLICY IF EXISTS "Owners can create invites" ON family_invites;
CREATE POLICY "Owners can create invites"
  ON family_invites FOR INSERT
  WITH CHECK (
    inviter_id = auth.uid()
    AND child_id IN (
      SELECT id FROM child_profiles WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Used or expired updates" ON family_invites;
CREATE POLICY "Used or expired updates"
  ON family_invites FOR UPDATE
  USING (true);

DROP POLICY IF EXISTS "Inviter can delete" ON family_invites;
CREATE POLICY "Inviter can delete"
  ON family_invites FOR DELETE
  USING (inviter_id = auth.uid());

-- =============================================
-- diary_entries / growth_records 등에 가족 멤버도 SELECT 가능하도록 RLS 보강
-- =============================================
DROP POLICY IF EXISTS "Family can view shared diary" ON diary_entries;
CREATE POLICY "Family can view shared diary"
  ON diary_entries FOR SELECT
  USING (
    user_id = auth.uid()
    OR child_id IN (
      SELECT child_id FROM family_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Family can view shared growth" ON growth_records;
CREATE POLICY "Family can view shared growth"
  ON growth_records FOR SELECT
  USING (
    child_id IN (
      SELECT id FROM child_profiles WHERE user_id = auth.uid()
    )
    OR child_id IN (
      SELECT child_id FROM family_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Family can view shared milestones" ON milestone_records;
CREATE POLICY "Family can view shared milestones"
  ON milestone_records FOR SELECT
  USING (
    child_id IN (
      SELECT id FROM child_profiles WHERE user_id = auth.uid()
    )
    OR child_id IN (
      SELECT child_id FROM family_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Family can view shared vaccinations" ON vaccination_records;
CREATE POLICY "Family can view shared vaccinations"
  ON vaccination_records FOR SELECT
  USING (
    child_id IN (
      SELECT id FROM child_profiles WHERE user_id = auth.uid()
    )
    OR child_id IN (
      SELECT child_id FROM family_members WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Family can view shared daily" ON daily_records;
CREATE POLICY "Family can view shared daily"
  ON daily_records FOR SELECT
  USING (
    child_id IN (
      SELECT id FROM child_profiles WHERE user_id = auth.uid()
    )
    OR child_id IN (
      SELECT child_id FROM family_members WHERE user_id = auth.uid()
    )
  );

-- =============================================
-- 가족 멤버 자동 등록: child_profiles 생성 시 owner를 'parent' 역할로 추가
-- =============================================
CREATE OR REPLACE FUNCTION add_owner_as_parent()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO family_members (child_id, user_id, role, nickname)
  VALUES (NEW.id, NEW.user_id, 'parent', NULL)
  ON CONFLICT (child_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_child_profile_created ON child_profiles;
CREATE TRIGGER on_child_profile_created
  AFTER INSERT ON child_profiles
  FOR EACH ROW
  EXECUTE FUNCTION add_owner_as_parent();
