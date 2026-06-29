-- Migration: Add INSERT policies for maintainers and admins on pending_advisories
-- Admins and maintainers should be able to submit advisories directly (bypassing volunteer queue)

-- Drop existing insert policy to recreate with OR logic
DROP POLICY IF EXISTS "pending_insert_volunteers" ON pending_advisories;

-- Volunteers can insert (with daily limit check via trigger)
CREATE POLICY "pending_insert_volunteers" ON pending_advisories
  FOR INSERT WITH CHECK (is_volunteer());

-- Maintainers can insert directly
CREATE POLICY "pending_insert_maintainers" ON pending_advisories
  FOR INSERT WITH CHECK (is_maintainer());

-- Admins can insert directly
CREATE POLICY "pending_insert_admin" ON pending_advisories
  FOR INSERT WITH CHECK (is_admin());
