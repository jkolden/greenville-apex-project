-- =============================================================================
-- PKG_APP_SECURITY: Authorization helper functions for APEX App 121
-- =============================================================================
-- Called by APEX Authorization Schemes (PL/SQL Function Body returning Boolean).
--
-- Five sources of security data:
--   1. app_user_roles          — manual local grants (ADMIN)
--   2. FUSION_USER_ROLES       — APEX collection populated at login via REST,
--                                falls back to fa_user_roles (BIP daily snapshot)
--   3. FUSION_USER_ASSIGNMENTS — APEX collection populated at login via REST
--                                (publicWorkers → assignments with position,
--                                location, department names/codes).
--   4. BICC tables             — HCM_EMPLOYEE_BC + HCM_ASSIGNMENT_BC + LOCATIONS_R
--                                fallback for assignments when REST is unavailable.
--   5. rec_school_grant        — manual location overrides for users who need
--                                access to schools beyond their current Fusion
--                                assignment (e.g., during transfers). Active
--                                grants are injected into FUSION_USER_ASSIGNMENTS
--                                at login, after REST/BICC population.
--
-- Function hierarchy:
--   is_admin          → local ADMIN only
--   is_recruiting_mgr → local ADMIN  OR  Fusion recruiting role
--   is_hiring_manager → local ADMIN  OR  ORA_IRC_HIRING_MANAGER_ABSTRACT
--
-- REST vs BIP role coverage (diagnosed 2026-06-17):
--   REST userAccountRoles returns 25 roles for <FUSION_CREDENTIAL>.
--   BIP  fa_user_roles    returns 43 roles (strict superset of REST).
--   The 18 extra BIP roles are:
--     - Custom data security roles (GCS_*_VIEW_ALL_DATA, GCS_*_VIEW_ONLY_DATA)
--     - Custom admin roles (BICC_ADMIN, DATA_EXTRACT_CUSTOM_ROLE, GCS_ESS_MONITOR_PROCESS)
--     - Two seeded job roles (ORA_FUN_FINANCIAL_INTEGRATION_SPECIALIST_JOB,
--       ORA_GL_GENERAL_ACCOUNTANT_JOB)
--   Root cause: REST returns only directly provisioned role memberships.
--   BIP queries a broader Fusion view that also includes data security roles
--   and roles assigned via provisioning rules.
--   Impact: The BIP fallback (cache_roles_from_bip) provides MORE complete
--   role coverage than the primary REST path. The 3 recruiting roles we
--   check (ORA_IRC_RECRUITER_JOB, ORA_IRC_RECRUITING_MANAGER_JOB,
--   ORA_PER_RECRUITING_ADMINISTRATOR_JOB) are present in both sources.
-- =============================================================================

CREATE OR REPLACE PACKAGE pkg_app_security AS

    FUNCTION is_admin (p_username IN VARCHAR2 DEFAULT v('APP_USER')) RETURN BOOLEAN;

    FUNCTION is_recruiting_mgr (p_username IN VARCHAR2 DEFAULT v('APP_USER')) RETURN BOOLEAN;

    FUNCTION is_hiring_manager (p_username IN VARCHAR2 DEFAULT v('APP_USER')) RETURN BOOLEAN;

    -- POST-AUTHENTICATION: Call Fusion REST to cache the user's roles
    -- AND assignments for the duration of the APEX session.
    PROCEDURE login_role_check (
        p_username IN VARCHAR2 DEFAULT v('APP_USER')
    );

END pkg_app_security;
/

CREATE OR REPLACE PACKAGE BODY pkg_app_security AS

    -- =====================================================================
    -- Constants
    -- =====================================================================
    gc_role_collection CONSTANT VARCHAR2(30)  := 'FUSION_USER_ROLES';
    gc_asgt_collection CONSTANT VARCHAR2(30)  := 'FUSION_USER_ASSIGNMENTS';
    gc_fa_base_url     CONSTANT VARCHAR2(200) := 'https://<FUSION_HOST_DEV>';
    gc_fa_credential   CONSTANT VARCHAR2(60)  := '<FUSION_CREDENTIAL>';

    -- =====================================================================
    -- Private: does this user have one of the 3 Fusion recruiting roles?
    --   Priority 1 — APEX collection (populated at login via REST)
    --   Priority 2 — fa_user_roles table (BIP daily snapshot)
    -- =====================================================================
    FUNCTION has_fusion_rec_role (p_username IN VARCHAR2 DEFAULT v('APP_USER')) RETURN BOOLEAN IS
        v_cnt NUMBER;
    BEGIN
        -- Real-time: APEX collection (populated by login_role_check)
        IF APEX_COLLECTION.COLLECTION_EXISTS(gc_role_collection) THEN
            SELECT COUNT(*)
              INTO v_cnt
              FROM apex_collections
             WHERE collection_name = gc_role_collection
               AND c001 IN (
                    'ORA_IRC_RECRUITER_JOB',
                    'ORA_IRC_RECRUITING_MANAGER_JOB',
                    'ORA_PER_RECRUITING_ADMINISTRATOR_JOB'
                   );
            RETURN (v_cnt > 0);
        END IF;

        -- Fallback: BIP-loaded data (no APEX session or REST failed)
        SELECT COUNT(*)
          INTO v_cnt
          FROM fa_user_accounts a
          JOIN fa_user_roles    r ON r.user_guid = a.user_guid
         WHERE UPPER(a.username) = UPPER(p_username)
           AND r.role_common_name IN (
                'ORA_IRC_RECRUITER_JOB',
                'ORA_IRC_RECRUITING_MANAGER_JOB',
                'ORA_PER_RECRUITING_ADMINISTRATOR_JOB'
               )
           AND (r.effective_end_date IS NULL
                OR r.effective_end_date > SYSTIMESTAMP);
        RETURN (v_cnt > 0);
    END has_fusion_rec_role;

    -- -------------------------------------------------------------------------
    -- ADMIN: local app_user_roles only
    -- -------------------------------------------------------------------------
    FUNCTION is_admin (p_username IN VARCHAR2 DEFAULT v('APP_USER')) RETURN BOOLEAN IS
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM app_user_roles
         WHERE UPPER(username) = UPPER(p_username)
           AND role_code       = 'ADMIN'
           AND is_active       = 'Y';
        RETURN (v_cnt > 0);
    END is_admin;

    -- -------------------------------------------------------------------------
    -- RECRUITING_MGR: local ADMIN  OR  Fusion recruiting role
    -- -------------------------------------------------------------------------
    FUNCTION is_recruiting_mgr (p_username IN VARCHAR2 DEFAULT v('APP_USER')) RETURN BOOLEAN IS
    BEGIN
        IF is_admin(p_username) THEN
            RETURN TRUE;
        END IF;

        RETURN has_fusion_rec_role(p_username);
    END is_recruiting_mgr;

    -- -------------------------------------------------------------------------
    -- HIRING_MANAGER: local ADMIN  OR  ORA_IRC_HIRING_MANAGER_ABSTRACT
    -- -------------------------------------------------------------------------
    FUNCTION is_hiring_manager (p_username IN VARCHAR2 DEFAULT v('APP_USER')) RETURN BOOLEAN IS
        v_cnt NUMBER;
    BEGIN
        IF is_admin(p_username) THEN
            RETURN TRUE;
        END IF;

        IF APEX_COLLECTION.COLLECTION_EXISTS(gc_role_collection) THEN
            SELECT COUNT(*)
              INTO v_cnt
              FROM apex_collections
             WHERE collection_name = gc_role_collection
               AND c001 = 'ORA_IRC_HIRING_MANAGER_ABSTRACT';
            RETURN (v_cnt > 0);
        END IF;

        -- Fallback: BIP data
        SELECT COUNT(*)
          INTO v_cnt
          FROM fa_user_accounts a
          JOIN fa_user_roles    r ON r.user_guid = a.user_guid
         WHERE UPPER(a.username) = UPPER(p_username)
           AND r.role_common_name = 'ORA_IRC_HIRING_MANAGER_ABSTRACT'
           AND (r.effective_end_date IS NULL
                OR r.effective_end_date > SYSTIMESTAMP);
        RETURN (v_cnt > 0);
    END is_hiring_manager;

    -- -------------------------------------------------------------------------
    -- Private: BIP fallback for role cache.
    -- Populates FUSION_USER_ROLES collection from fa_user_roles when the
    -- REST userAccounts call fails or returns no data.
    -- -------------------------------------------------------------------------
    PROCEDURE cache_roles_from_bip (
        p_username IN VARCHAR2
    )
    IS
        l_role_count PLS_INTEGER := 0;
    BEGIN
        IF APEX_COLLECTION.COLLECTION_EXISTS(gc_role_collection) THEN
            APEX_COLLECTION.TRUNCATE_COLLECTION(gc_role_collection);
        ELSE
            APEX_COLLECTION.CREATE_COLLECTION(gc_role_collection);
        END IF;

        FOR rec IN (
            SELECT DISTINCT r.role_common_name
              FROM fa_user_accounts a
              JOIN fa_user_roles    r ON r.user_guid = a.user_guid
             WHERE UPPER(a.username) = UPPER(p_username)
               AND (r.effective_end_date IS NULL
                    OR r.effective_end_date > SYSTIMESTAMP)
        ) LOOP
            APEX_COLLECTION.ADD_MEMBER(
                p_collection_name => gc_role_collection,
                p_c001            => rec.role_common_name
            );
            l_role_count := l_role_count + 1;
        END LOOP;

        APEX_UTIL.SET_SESSION_STATE('G_ROLE_COUNT', l_role_count);

    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END cache_roles_from_bip;

    -- -------------------------------------------------------------------------
    -- Private: BICC fallback for assignment cache.
    -- Populates the same FUSION_USER_ASSIGNMENTS collection from local BICC
    -- tables when the REST publicWorkers call fails or returns no data.
    -- Joins through LOCATIONS_R (same source as recruiting_report_v) so
    -- location_code values match exactly for VPD filtering.
    -- -------------------------------------------------------------------------
    PROCEDURE cache_assignments_from_bicc (
        p_username IN VARCHAR2
    )
    IS
        l_asgt_count PLS_INTEGER := 0;
        l_loc_count  PLS_INTEGER := 0;
    BEGIN
        IF APEX_COLLECTION.COLLECTION_EXISTS(gc_asgt_collection) THEN
            APEX_COLLECTION.TRUNCATE_COLLECTION(gc_asgt_collection);
        ELSE
            APEX_COLLECTION.CREATE_COLLECTION(gc_asgt_collection);
        END IF;

        FOR rec IN (
            SELECT DISTINCT a.ASSIGNMENT_ID,
                   e.POSITION_NAME,
                   loc.LOCATIONNAME    AS LOCATION_NAME,
                   e.ORG_NAME          AS DEPARTMENT_NAME,
                   e.POSITION_CODE,
                   loc.LOCATIONCODE    AS LOCATION_CODE
              FROM HCM_EMPLOYEE_BC e
              JOIN HCM_ASSIGNMENT_BC a
                ON a.PERSON_ID = e.PERSON_ID
               AND a.EFFECTIVE_START_TS <= SYSTIMESTAMP
               AND (a.EFFECTIVE_END_TS IS NULL OR a.EFFECTIVE_END_TS > SYSTIMESTAMP)
              LEFT JOIN LOCATIONS_R loc
                ON loc.LOCATIONID = a.LOCATION_ID
             WHERE UPPER(e.USER_NAME) = UPPER(p_username)
        ) LOOP
            APEX_COLLECTION.ADD_MEMBER(
                p_collection_name => gc_asgt_collection,
                p_c001            => TO_CHAR(rec.ASSIGNMENT_ID),
                p_c002            => rec.POSITION_NAME,
                p_c003            => rec.LOCATION_NAME,
                p_c004            => rec.DEPARTMENT_NAME,
                p_c005            => rec.POSITION_CODE,
                p_c006            => rec.LOCATION_CODE,
                p_c007            => NULL
            );
            l_asgt_count := l_asgt_count + 1;
            IF rec.LOCATION_CODE IS NOT NULL THEN
                l_loc_count := l_loc_count + 1;
            END IF;
        END LOOP;

        APEX_UTIL.SET_SESSION_STATE('G_ASSIGNMENT_COUNT', l_asgt_count);
        APEX_UTIL.SET_SESSION_STATE('G_LOCATION_COUNT', l_loc_count);

    EXCEPTION
        WHEN OTHERS THEN
            -- Never block login
            NULL;
    END cache_assignments_from_bicc;

    -- -------------------------------------------------------------------------
    -- Private: Append manual location overrides from rec_school_grant.
    -- Called AFTER the collection is populated by REST or BICC fallback.
    -- Handles the scenario where a user transfers schools but still needs
    -- access to the old school's job requisitions.
    -- Skips location_codes already in the collection to avoid duplicates.
    -- -------------------------------------------------------------------------
    PROCEDURE apply_school_grant_overrides (
        p_username IN VARCHAR2
    )
    IS
        l_added PLS_INTEGER := 0;
    BEGIN
        IF NOT APEX_COLLECTION.COLLECTION_EXISTS(gc_asgt_collection) THEN
            RETURN;
        END IF;

        FOR rec IN (
            SELECT g.location_code,
                   loc.LOCATIONNAME AS location_name
              FROM rec_school_grant g
              LEFT JOIN LOCATIONS_R loc
                ON loc.LOCATIONCODE = g.location_code
             WHERE UPPER(g.app_user) = UPPER(p_username)
               AND g.is_active = 'Y'
               AND g.location_code NOT IN (
                   SELECT c006
                     FROM apex_collections
                    WHERE collection_name = gc_asgt_collection
                      AND c006 IS NOT NULL
               )
        ) LOOP
            APEX_COLLECTION.ADD_MEMBER(
                p_collection_name => gc_asgt_collection,
                p_c001 => NULL,
                p_c002 => NULL,
                p_c003 => rec.location_name,
                p_c004 => NULL,
                p_c005 => NULL,
                p_c006 => rec.location_code,
                p_c007 => NULL
            );
            l_added := l_added + 1;
        END LOOP;

        IF l_added > 0 THEN
            APEX_UTIL.SET_SESSION_STATE(
                'G_LOCATION_COUNT',
                NVL(v('G_LOCATION_COUNT'), 0) + l_added
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN NULL;  -- Never block login
    END apply_school_grant_overrides;

    -- -------------------------------------------------------------------------
    -- Private: Cache the user's assignments from publicWorkers REST API.
    -- Called from login_role_check after the role collection is populated.
    --
    -- REST endpoint:
    --   GET /hcmRestApi/resources/11.13.18.05/publicWorkers
    --       ?q=Username='{username}'
    --       &expand=assignments
    --       &fields=assignments
    --       &onlyData=true
    --
    -- Assignment JSON provides names and codes but NOT IDs.
    -- IDs are derived at query time by joining to dim_location_r / dim_department_r.
    --
    -- Collection FUSION_USER_ASSIGNMENTS:
    --   c001 = assignment_id (as string)
    --   c002 = position_name
    --   c003 = location_name
    --   c004 = department_name
    --   c005 = position_code
    --   c006 = location_code
    --   c007 = job_name
    -- -------------------------------------------------------------------------
    PROCEDURE cache_user_assignments (
        p_username IN VARCHAR2
    )
    IS
        l_url           VARCHAR2(2000);
        l_clob          CLOB;
        l_asgt_count    PLS_INTEGER := 0;
        l_loc_count     PLS_INTEGER := 0;
    BEGIN
        -- Default to zero so nav bar never shows NULL
        APEX_UTIL.SET_SESSION_STATE('G_ASSIGNMENT_COUNT', 0);
        APEX_UTIL.SET_SESSION_STATE('G_LOCATION_COUNT', 0);

        l_url := gc_fa_base_url
              || '/hcmRestApi/resources/11.13.18.05/publicWorkers'
              || '?q=Username%3D''' || utl_url.escape(p_username) || ''''
              || '&expand=assignments'
              || '&fields=assignments'
              || '&onlyData=true';

        apex_web_service.clear_request_headers;
        l_clob := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_fa_credential
        );

        IF apex_web_service.g_status_code != 200 THEN
            -- REST unavailable — fall back to BICC tables
            cache_assignments_from_bicc(p_username);
            RETURN;
        END IF;

        -- Create or reset session-scoped collection
        IF APEX_COLLECTION.COLLECTION_EXISTS(gc_asgt_collection) THEN
            APEX_COLLECTION.TRUNCATE_COLLECTION(gc_asgt_collection);
        ELSE
            APEX_COLLECTION.CREATE_COLLECTION(gc_asgt_collection);
        END IF;

        -- Parse assignments from the first (and only) worker record
        FOR rec IN (
            SELECT jt.assignment_id,
                   jt.position_name,
                   jt.position_code,
                   jt.location_name,
                   jt.location_code,
                   jt.department_name,
                   jt.job_name
              FROM JSON_TABLE(
                       l_clob,
                       '$.items[0].assignments[*]'
                       COLUMNS (
                           assignment_id   NUMBER        PATH '$.AssignmentId',
                           position_name   VARCHAR2(240) PATH '$.PositionName',
                           position_code   VARCHAR2(60)  PATH '$.PositionCode',
                           location_name   VARCHAR2(240) PATH '$.LocationName',
                           location_code   VARCHAR2(60)  PATH '$.LocationCode',
                           department_name VARCHAR2(240) PATH '$.DepartmentName',
                           job_name        VARCHAR2(240) PATH '$.JobName'
                       )
                   ) jt
             WHERE jt.assignment_id IS NOT NULL
        ) LOOP
            APEX_COLLECTION.ADD_MEMBER(
                p_collection_name => gc_asgt_collection,
                p_c001            => TO_CHAR(rec.assignment_id),
                p_c002            => rec.position_name,
                p_c003            => rec.location_name,
                p_c004            => rec.department_name,
                p_c005            => rec.position_code,
                p_c006            => rec.location_code,
                p_c007            => rec.job_name
            );
            l_asgt_count := l_asgt_count + 1;
            IF rec.location_code IS NOT NULL THEN
                l_loc_count := l_loc_count + 1;
            END IF;
        END LOOP;

        -- Set application items for nav bar badges
        APEX_UTIL.SET_SESSION_STATE('G_ASSIGNMENT_COUNT', l_asgt_count);
        APEX_UTIL.SET_SESSION_STATE('G_LOCATION_COUNT', l_loc_count);

        -- REST succeeded but returned no assignments — try BICC tables
        IF l_asgt_count = 0 THEN
            cache_assignments_from_bicc(p_username);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            -- REST call raised — fall back to BICC tables
            cache_assignments_from_bicc(p_username);
    END cache_user_assignments;

    -- -------------------------------------------------------------------------
    -- POST-AUTHENTICATION: Call Fusion REST to get the current user's roles
    -- AND assignments, cache them in APEX collections for the session.
    --
    -- REST endpoints:
    --   1. userAccounts?expand=userAccountRoles   → FUSION_USER_ROLES
    --   2. publicWorkers?expand=assignments        → FUSION_USER_ASSIGNMENTS
    --
    -- Also sets application items G_ROLE_COUNT and G_ASSIGNMENT_COUNT.
    -- -------------------------------------------------------------------------
    PROCEDURE login_role_check (
        p_username IN VARCHAR2 DEFAULT v('APP_USER')
    )
    IS
        l_url        VARCHAR2(2000);
        l_clob       CLOB;
        l_role_count PLS_INTEGER := 0;
    BEGIN
        -- =====================================================================
        -- STEP 1: Cache user roles (existing logic)
        -- =====================================================================
        l_url := gc_fa_base_url
              || '/hcmRestApi/resources/11.13.18.05/userAccounts'
              || '?q=Username%3D''' || utl_url.escape(p_username) || ''''
              || '&expand=userAccountRoles';

        apex_web_service.clear_request_headers;
        l_clob := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_fa_credential
        );

        IF apex_web_service.g_status_code != 200 THEN
            -- REST unavailable — fall back to BIP tables
            cache_roles_from_bip(p_username);
        ELSE
            -- Create or reset session-scoped collection
            IF APEX_COLLECTION.COLLECTION_EXISTS(gc_role_collection) THEN
                APEX_COLLECTION.TRUNCATE_COLLECTION(gc_role_collection);
            ELSE
                APEX_COLLECTION.CREATE_COLLECTION(gc_role_collection);
            END IF;

            -- Store every role code the user holds
            FOR rec IN (
                SELECT jt.role_code
                  FROM JSON_TABLE(
                           l_clob,
                           '$.items[0].userAccountRoles[*]'
                           COLUMNS (
                               role_code VARCHAR2(255) PATH '$.RoleCode'
                           )
                       ) jt
                 WHERE jt.role_code IS NOT NULL
            ) LOOP
                APEX_COLLECTION.ADD_MEMBER(
                    p_collection_name => gc_role_collection,
                    p_c001            => rec.role_code
                );
                l_role_count := l_role_count + 1;
            END LOOP;

            -- Set application item for nav bar badge
            APEX_UTIL.SET_SESSION_STATE('G_ROLE_COUNT', l_role_count);

            -- REST succeeded but returned no roles — try BIP tables
            IF l_role_count = 0 THEN
                cache_roles_from_bip(p_username);
            END IF;
        END IF;

        -- =====================================================================
        -- STEP 2: Cache user assignments (location_id, department_id)
        -- =====================================================================
        cache_user_assignments(p_username);

        -- =====================================================================
        -- STEP 3: Apply manual location overrides from rec_school_grant
        -- =====================================================================
        apply_school_grant_overrides(p_username);

    EXCEPTION
        WHEN OTHERS THEN
            -- REST call raised — fall back to BIP tables for both
            cache_roles_from_bip(p_username);
            cache_assignments_from_bicc(p_username);
            apply_school_grant_overrides(p_username);
    END login_role_check;

END pkg_app_security;
/

-- =============================================================================
-- APEX WIRING: Post-Authentication Procedure
-- =============================================================================
-- Shared Components > Authentication Schemes > [your scheme]
--   > Post-Authentication Procedure Name:
--
--       pkg_app_security.login_role_check
--
-- Because p_username defaults to APP_USER,
-- APEX calls it with no arguments and it just works.
--
-- The collections are session-scoped — auto-cleaned when the session ends.
-- If Fusion is unreachable at login, the user still gets in and
-- authorization falls back to BIP-loaded tables (fa_user_roles).
-- =============================================================================

-- =============================================================================
-- PREREQUISITE: Application Items
-- =============================================================================
-- Shared Components > Application Items > Create
--
-- 1. G_ROLE_COUNT
--      Scope:           Application
--      Session State:   Per Session (Disk)
--
-- 2. G_ASSIGNMENT_COUNT
--      Scope:           Application
--      Session State:   Per Session (Disk)
--
-- 3. G_LOCATION_COUNT
--      Scope:           Application
--      Session State:   Per Session (Disk)
-- =============================================================================
