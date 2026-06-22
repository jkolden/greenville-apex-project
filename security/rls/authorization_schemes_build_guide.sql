-- =============================================================================
-- Authorization Schemes Build Guide — APEX App 121
-- =============================================================================
-- Role-based access control driven by Fusion roles (via REST at login)
-- with local app_user_roles overrides.
--
-- PREREQUISITES:
--   1. Run app_user_roles.sql       (creates the local role table)
--   2. Run pkg_app_security.sql     (creates the package — spec + body)
--   3. Run seed_user_roles.sql      (inserts initial ADMIN grants)
--   4. Set Post-Authentication Procedure to: pkg_app_security.login_role_check
--   5. Create Application Item: G_ROLE_COUNT (scope: Application)
--
-- How it works:
--   At login, login_role_check calls Fusion REST to get the user's roles
--   and caches them in an APEX collection (FUSION_USER_ROLES).
--   Authorization schemes call pkg_app_security functions which check
--   both the collection (real-time) and app_user_roles (manual overrides).
--
-- Available functions (all default to APP_USER — no arguments needed):
--   is_admin          → local ADMIN role only
--   is_recruiting_mgr → ADMIN or Fusion recruiting role (3 roles)
--   is_hiring_manager → ADMIN or ORA_IRC_HIRING_MANAGER_ABSTRACT
-- =============================================================================


-- =============================================================================
-- PART 1: CREATE AUTHORIZATION SCHEMES
-- =============================================================================
-- Shared Components > Authorization Schemes > Create

-- SCHEME 1: IS_ADMIN
-- ──────────────────
--   Name:             IS_ADMIN
--   Scheme Type:      PL/SQL Function Returning Boolean
--   PL/SQL Function Body:
--
--     return pkg_app_security.is_admin;
--
--   Error message:    You are not authorized to access this page.
--                     Contact your administrator for access.
--   Evaluation Point: Once per session


-- SCHEME 2: IS_RECRUITING_MGR
-- ───────────────────────────
--   Name:             IS_RECRUITING_MGR
--   Scheme Type:      PL/SQL Function Returning Boolean
--   PL/SQL Function Body:
--
--     return pkg_app_security.is_recruiting_mgr;
--
--   Error message:    You are not authorized to access this page.
--                     Contact your administrator for access.
--   Evaluation Point: Once per page view
--
--   NOTE: "Once per page view" (not per session) so that Fusion role
--   changes take effect without requiring logout/login.


-- SCHEME 3: IS_HIRING_MANAGER
-- ───────────────────────────
--   Name:             IS_HIRING_MANAGER
--   Scheme Type:      PL/SQL Function Returning Boolean
--   PL/SQL Function Body:
--
--     return pkg_app_security.is_hiring_manager;
--
--   Error message:    You are not authorized to access this page.
--                     Contact your administrator for access.
--   Evaluation Point: Once per page view


-- =============================================================================
-- PART 2: ASSIGN SCHEMES TO PAGES
-- =============================================================================
-- Page Designer > Page Properties > Security > Authorization Scheme

-- ADMIN-ONLY PAGES (IS_ADMIN):
-- ─────────────────────────────
--   Page 9003  BICC File Loader        → Authorization Scheme: IS_ADMIN
--   Page 20    Email Notifications     → Authorization Scheme: IS_ADMIN

-- RECRUITING PAGES (IS_RECRUITING_MGR — ADMIN or Fusion recruiting role):
-- ───────────────────────────────────────────────────────────────────────
--   Page 12    Questionnaires          → Authorization Scheme: IS_RECRUITING_MGR
--   Page 15    Move Applicant          → Authorization Scheme: IS_RECRUITING_MGR
--   Page 18    Teacher Report          → Authorization Scheme: IS_RECRUITING_MGR
--   Page 22    Non-Teacher Report      → Authorization Scheme: IS_RECRUITING_MGR
--   Page 24    Management Report       → Authorization Scheme: IS_RECRUITING_MGR
--   Page 27    Non-Teacher Report      → Authorization Scheme: IS_RECRUITING_MGR
--   Page 29    Management Report       → Authorization Scheme: IS_RECRUITING_MGR
--   Page 30    Download Attachment     → Authorization Scheme: IS_RECRUITING_MGR
--   Page 31    Teacher Report          → Authorization Scheme: IS_RECRUITING_MGR
--   Page 33    Management Report       → Authorization Scheme: IS_RECRUITING_MGR

-- PUBLIC PAGES (no scheme — token-based access):
-- ──────────────────────────────────────────────
--   Page 100   Reference Correction    → (no authorization scheme)
--   Page 101   Confirm Corrections     → (no authorization scheme)

-- NOTE: Pages 100/101 use Page Is Public + token-based validation
-- via pkg_ref_correction. No authorization scheme needed.


-- =============================================================================
-- PART 3: NAV BAR VISIBILITY
-- =============================================================================
-- Shared Components > Navigation Menu > List Entries
--
-- For each menu entry pointing to an admin page:
--   Authorization Scheme: IS_ADMIN
--
-- For each menu entry pointing to a recruiting page:
--   Authorization Scheme: IS_RECRUITING_MGR
--
-- Users only see links to pages they can access.


-- =============================================================================
-- PART 4: COMPONENT-LEVEL AUTHORIZATION
-- =============================================================================
-- Beyond page-level, you can protect individual components:
--
-- Example: Hide the "Move Applicant" button for non-recruiting-mgr users
--   Button > Authorization Scheme: IS_RECRUITING_MGR
--
-- Example: Hide the "Delete" column in an IR for non-admins
--   Column > Authorization Scheme: IS_ADMIN


-- =============================================================================
-- TESTING CHECKLIST
-- =============================================================================
--
-- 1. Log in as a user with ADMIN role (in app_user_roles):
--    [x] Can access page 9003 (BICC Loader)
--    [x] Can access page 20 (Email Config)
--    [x] Can access all recruiting pages
--
-- 2. Log in as a user with a Fusion recruiting role (no app_user_roles entry):
--    [x] Can access all recruiting pages (is_recruiting_mgr passes via Fusion role)
--    [ ] CANNOT access page 9003 — sees "Access Denied" message
--    [ ] CANNOT access page 20 — sees "Access Denied" message
--    [x] Nav bar shows "My Fusion Roles" with badge count
--
-- 3. Log in as a user with ORA_IRC_HIRING_MANAGER_ABSTRACT only:
--    [x] is_hiring_manager passes
--    [ ] is_recruiting_mgr fails (hiring manager role is separate)
--
-- 4. Log in as a user with NO role (no app_user_roles, no Fusion recruiting role):
--    [ ] CANNOT access any protected page
--    [ ] Sees "Access Denied" message
--
-- 5. Open page 100 (Reference Correction) without logging in:
--    [x] Still works — public token-based access unaffected
--
-- 6. Revoke a Fusion recruiting role in Fusion:
--    [ ] User loses access at their next APEX login
