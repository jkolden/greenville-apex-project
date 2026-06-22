-- =============================================================================
-- RECRUITING_REPORT_SECURE_V: Row-level security wrapper for recruiting reports
-- =============================================================================
-- Wraps RECRUITING_REPORT_V with location-code-level filtering.
-- Same logic as rec_rls_pkg.read_policy but without DBMS_RLS.
--
-- Location codes come from the FUSION_USER_ASSIGNMENTS APEX collection
-- (c006 = location_code), populated at login by pkg_app_security.login_role_check.
--
-- Bypass rules:
--   1. No APEX session (schema owner / SQL Developer) → all rows
--   2. ADMIN role in app_user_roles                   → all rows
--   3. Otherwise → only rows matching the user's assignment location codes
--
-- Usage: Point APEX IR regions at this view instead of RECRUITING_REPORT_V.
-- =============================================================================

CREATE OR REPLACE VIEW recruiting_report_secure_v AS
SELECT r.*
  FROM recruiting_report_v r
 WHERE (
    -- Bypass: no APEX session (schema owner, SQL Developer, scheduler)
    SYS_CONTEXT('APEX$SESSION', 'APP_USER') IS NULL
  )
  OR (
    -- Bypass: ADMIN role
    EXISTS (
        SELECT 1
          FROM app_user_roles
         WHERE UPPER(username) = SYS_CONTEXT('APEX$SESSION', 'APP_USER')
           AND role_code       = 'ADMIN'
           AND is_active       = 'Y'
    )
  )
  OR (
    -- Normal users: location code must be in their Fusion assignments
    r.location_code IN (
        SELECT c006
          FROM apex_collections
         WHERE collection_name = 'FUSION_USER_ASSIGNMENTS'
           AND c006 IS NOT NULL
    )
  )
  OR (
    -- Include rows with no location code assigned (if user has any assignments)
    r.location_code IS NULL
    AND SYS_CONTEXT('APEX$SESSION', 'APP_USER') IS NOT NULL
    AND EXISTS (
        SELECT 1
          FROM apex_collections
         WHERE collection_name = 'FUSION_USER_ASSIGNMENTS'
    )
  );
