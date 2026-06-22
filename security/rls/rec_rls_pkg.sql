-- =============================================================================
-- REC_RLS_PKG: VPD policy function for RECRUITING_REPORT_V
-- =============================================================================
-- Pattern follows ot_rls_pkg (App 110 overtime RDS demo).
-- Returns a WHERE-clause predicate that Oracle appends to every SELECT
-- against RECRUITING_REPORT_V.
--
-- Bypass rules:
--   1. No APEX session (schema owner / SQL Developer) → NULL (no filter)
--   2. ADMIN role in app_user_roles                   → NULL (see everything)
--   3. Otherwise → LOCATION_CODE IN (user's Fusion assignment location codes)
--
-- Location codes come from the FUSION_USER_ASSIGNMENTS APEX collection
-- (c006 = location_code), populated at login by pkg_app_security.login_role_check.
-- =============================================================================

CREATE OR REPLACE PACKAGE rec_rls_pkg AS

    FUNCTION read_policy (
        p_schema  IN VARCHAR2,
        p_object  IN VARCHAR2
    ) RETURN VARCHAR2;

END rec_rls_pkg;
/

CREATE OR REPLACE PACKAGE BODY rec_rls_pkg AS

    FUNCTION read_policy (
        p_schema  IN VARCHAR2,
        p_object  IN VARCHAR2
    ) RETURN VARCHAR2
    IS
        l_user         VARCHAR2(255);
        l_is_admin     NUMBER;
        l_has_locations NUMBER;
    BEGIN
        -- Bypass 1: No APEX session (schema owner, SQL Developer, scheduler)
        l_user := SYS_CONTEXT('APEX$SESSION', 'APP_USER');

        IF l_user IS NULL THEN
            RETURN NULL;
        END IF;

        -- Bypass 2: ADMIN role → see everything
        SELECT COUNT(*)
          INTO l_is_admin
          FROM app_user_roles
         WHERE UPPER(username) = UPPER(l_user)
           AND role_code       = 'ADMIN'
           AND is_active       = 'Y';

        IF l_is_admin > 0 THEN
            RETURN NULL;
        END IF;

        -- Check if user has any assignment location codes
        SELECT COUNT(*)
          INTO l_has_locations
          FROM apex_collections
         WHERE collection_name = 'FUSION_USER_ASSIGNMENTS'
           AND c006 IS NOT NULL
           AND ROWNUM = 1;

        -- No assignments with locations → see nothing
        IF l_has_locations = 0 THEN
            RETURN '1=0';
        END IF;

        -- Has locations: show only rows matching user's assignment locations
        RETURN 'LOCATION_CODE IN ('
            || 'SELECT c006 FROM apex_collections'
            || ' WHERE collection_name = ''FUSION_USER_ASSIGNMENTS'''
            || ' AND c006 IS NOT NULL'
            || ')';

    END read_policy;

END rec_rls_pkg;
/
