-- Migration: Fix recursive RLS policies on profiles table
-- The original policies queried profiles from within profiles policies, causing infinite recursion.
-- Fix: use SECURITY DEFINER helper functions.
-- Date: 2026-06-29

-- Helper function: check if current user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Helper function: check if current user is maintainer (or admin)
CREATE OR REPLACE FUNCTION is_maintainer()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('maintainer', 'admin'));
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Helper function: check if current user is volunteer
CREATE OR REPLACE FUNCTION is_volunteer()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'volunteer');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================
-- Drop and recreate profiles policies (fix recursion)
-- ============================================================

-- Drop all existing profiles policies
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
DROP POLICY IF EXISTS "profiles_select_maintainers" ON profiles;
DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_admin_manage" ON profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_delete_admin" ON profiles;

-- Recreate with helper functions (no recursion)
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_select_maintainers" ON profiles
  FOR SELECT USING (is_maintainer());

CREATE POLICY "profiles_select_admin" ON profiles
  FOR SELECT USING (is_admin());

CREATE POLICY "profiles_insert_admin" ON profiles
  FOR INSERT WITH CHECK (true);

CREATE POLICY "profiles_insert_admin_manage" ON profiles
  FOR INSERT WITH CHECK (is_admin());

CREATE POLICY "profiles_update_admin" ON profiles
  FOR UPDATE USING (is_admin());

CREATE POLICY "profiles_update_maintainers" ON profiles
  FOR UPDATE USING (is_maintainer());

CREATE POLICY "profiles_delete_admin" ON profiles
  FOR DELETE USING (is_admin());

-- ============================================================
-- Fix pending_advisories policies (use helper functions)
-- ============================================================

DROP POLICY IF EXISTS "pending_select_own" ON pending_advisories;
DROP POLICY IF EXISTS "pending_select_maintainers" ON pending_advisories;
DROP POLICY IF EXISTS "pending_select_admin" ON pending_advisories;
DROP POLICY IF EXISTS "pending_insert_volunteers" ON pending_advisories;
DROP POLICY IF EXISTS "pending_update_maintainers" ON pending_advisories;
DROP POLICY IF EXISTS "pending_update_admin" ON pending_advisories;

CREATE POLICY "pending_select_own" ON pending_advisories
  FOR SELECT USING (auth.uid() = submitted_by);

CREATE POLICY "pending_select_maintainers" ON pending_advisories
  FOR SELECT USING (is_maintainer());

CREATE POLICY "pending_select_admin" ON pending_advisories
  FOR SELECT USING (is_admin());

CREATE POLICY "pending_insert_volunteers" ON pending_advisories
  FOR INSERT WITH CHECK (is_volunteer());

CREATE POLICY "pending_update_maintainers" ON pending_advisories
  FOR UPDATE USING (is_maintainer());

CREATE POLICY "pending_update_admin" ON pending_advisories
  FOR UPDATE USING (is_admin());
