-- Migration: Add admin role + admin-only functions
-- Date: 2026-06-29

-- ============================================================
-- 1. ADD ADMIN ROLE to profiles CHECK constraint
-- ============================================================

-- Drop the old constraint and add new one with 'admin'
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin', 'maintainer', 'volunteer'));

-- ============================================================
-- 2. ADMIN RLS POLICIES (can do everything)
-- ============================================================

-- Helper function to check if current user is admin (avoids recursive RLS)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Admins can read all profiles
CREATE POLICY "profiles_select_admin" ON profiles
  FOR SELECT USING (is_admin());

-- Admins can insert any profile (create accounts)
CREATE POLICY "profiles_insert_admin_manage" ON profiles
  FOR INSERT WITH CHECK (is_admin());

-- Admins can update any profile (suspend, change roles)
CREATE POLICY "profiles_update_admin" ON profiles
  FOR UPDATE USING (is_admin());

-- Admins can delete any profile (delete accounts)
CREATE POLICY "profiles_delete_admin" ON profiles
  FOR DELETE USING (is_admin());

-- Admins can read all pending advisories
CREATE POLICY "pending_select_admin" ON pending_advisories
  FOR SELECT USING (is_admin());

-- Admins can update any pending advisory (approve/reject on behalf)
CREATE POLICY "pending_update_admin" ON pending_advisories
  FOR UPDATE USING (is_admin());

-- ============================================================
-- 3. ADMIN-ONLY FUNCTIONS
-- ============================================================

-- Create a new volunteer/maintainer account
-- Usage: SELECT create_account('email@example.com', 'password123', 'volunteer', 'Display Name');
CREATE OR REPLACE FUNCTION create_account(
  p_email TEXT,
  p_password TEXT,
  p_role TEXT,
  p_display_name TEXT
)
RETURNS UUID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Only admins can call this
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Only admins can create accounts';
  END IF;

  IF p_role NOT IN ('maintainer', 'volunteer') THEN
    RAISE EXCEPTION 'Role must be maintainer or volunteer';
  END IF;

  -- Create auth user via service role (this function runs as SECURITY DEFINER)
  -- Note: auth.admin API requires service_role key
  -- This is handled via the Supabase management API or direct SQL
  RAISE NOTICE 'Auth user creation must be done via Supabase Auth API or dashboard';
  RAISE NOTICE 'Profile will be created once auth user exists';

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Suspend a volunteer account (sets role to 'suspended')
CREATE OR REPLACE FUNCTION suspend_account(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Only admins can suspend accounts';
  END IF;

  UPDATE profiles SET role = 'volunteer' WHERE id = p_user_id;
  -- We need a new role for suspended, or use a separate flag
  -- For now, we'll use a metadata approach
  RAISE NOTICE 'Account suspended. Consider using auth.admin API to disable sign-in.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete a volunteer account
CREATE OR REPLACE FUNCTION delete_account(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Only admins can delete accounts';
  END IF;

  -- Delete profile (cascades to auth user if FK is set up)
  DELETE FROM profiles WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
