-- =============================================================================
-- Add RECRUITING_MGR role to app_user_roles
-- =============================================================================
-- Enables gating Management Report pages (24, 29, 33) to managers only.
-- HR_USER still accesses Teacher/Non-Teacher pages; ADMIN accesses everything.
-- =============================================================================

-- Step 1: Widen the CHECK constraint
ALTER TABLE app_user_roles DROP CONSTRAINT app_user_roles_ck1;
ALTER TABLE app_user_roles ADD CONSTRAINT app_user_roles_ck1
    CHECK (role_code IN ('ADMIN', 'HR_USER', 'SUPPORT_DEV', 'RECRUITING_MGR'));
