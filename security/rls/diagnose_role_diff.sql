-- =============================================================================
-- DIAGNOSTIC: Compare REST roles vs BIP roles for a specific user
-- =============================================================================
-- Run this AFTER logging in to APEX App 121 (so the FUSION_USER_ROLES
-- collection exists from the REST call), OR run each section independently.
--
-- Goal: Identify exactly which roles BIP has that REST does not, and why.
-- =============================================================================

-- =====================================================================
-- 1. How many roles in each source?
-- =====================================================================
SELECT 'REST (APEX collection)' AS source,
       COUNT(*)                 AS role_count
  FROM apex_collections
 WHERE collection_name = 'FUSION_USER_ROLES'
UNION ALL
SELECT 'BIP (fa_user_roles)'   AS source,
       COUNT(*)                 AS role_count
  FROM fa_user_accounts a
  JOIN fa_user_roles    r ON r.user_guid = a.user_guid
 WHERE UPPER(a.username) = '<FUSION_CREDENTIAL>'
   AND (r.effective_end_date IS NULL OR r.effective_end_date > SYSTIMESTAMP)
ORDER BY 1;


-- =====================================================================
-- 2. TYPE_CODE distribution for this user's BIP roles
--    This is the key diagnostic — if the "extra" roles have a different
--    TYPE_CODE than the REST roles, that explains the filtering.
-- =====================================================================
SELECT r.type_code,
       COUNT(*) AS cnt
  FROM fa_user_accounts a
  JOIN fa_user_roles    r ON r.user_guid = a.user_guid
 WHERE UPPER(a.username) = '<FUSION_CREDENTIAL>'
   AND (r.effective_end_date IS NULL OR r.effective_end_date > SYSTIMESTAMP)
 GROUP BY r.type_code
 ORDER BY r.type_code;


-- =====================================================================
-- 3. Roles in BIP but NOT in REST  (the "extra" ones)
--    Shows role_common_name, role_name, and type_code so we can see
--    what kind of roles REST is omitting.
-- =====================================================================
SELECT r.role_common_name,
       r.role_name,
       r.type_code,
       r.ase_role_id
  FROM fa_user_accounts a
  JOIN fa_user_roles    r ON r.user_guid = a.user_guid
 WHERE UPPER(a.username) = '<FUSION_CREDENTIAL>'
   AND (r.effective_end_date IS NULL OR r.effective_end_date > SYSTIMESTAMP)
   AND r.role_common_name NOT IN (
       SELECT c001
         FROM apex_collections
        WHERE collection_name = 'FUSION_USER_ROLES'
   )
 ORDER BY r.type_code, r.role_common_name;


-- =====================================================================
-- 4. Roles in REST but NOT in BIP  (should be empty or very few)
--    If roles exist here, the BIP report is missing data.
-- =====================================================================
SELECT c.c001 AS role_code
  FROM apex_collections c
 WHERE c.collection_name = 'FUSION_USER_ROLES'
   AND c.c001 NOT IN (
       SELECT r.role_common_name
         FROM fa_user_accounts a
         JOIN fa_user_roles    r ON r.user_guid = a.user_guid
        WHERE UPPER(a.username) = '<FUSION_CREDENTIAL>'
          AND (r.effective_end_date IS NULL OR r.effective_end_date > SYSTIMESTAMP)
   )
 ORDER BY c.c001;


-- =====================================================================
-- 5. Side-by-side: ALL roles from both sources
--    IN_REST / IN_BIP flags show where each role exists.
-- =====================================================================
SELECT COALESCE(rest.role_code, bip.role_common_name) AS role_code,
       bip.role_name,
       bip.type_code,
       CASE WHEN rest.role_code IS NOT NULL THEN 'Y' ELSE 'N' END AS in_rest,
       CASE WHEN bip.role_common_name IS NOT NULL THEN 'Y' ELSE 'N' END AS in_bip
  FROM (
       SELECT c001 AS role_code
         FROM apex_collections
        WHERE collection_name = 'FUSION_USER_ROLES'
  ) rest
  FULL OUTER JOIN (
       SELECT DISTINCT r.role_common_name, r.role_name, r.type_code
         FROM fa_user_accounts a
         JOIN fa_user_roles    r ON r.user_guid = a.user_guid
        WHERE UPPER(a.username) = '<FUSION_CREDENTIAL>'
          AND (r.effective_end_date IS NULL OR r.effective_end_date > SYSTIMESTAMP)
  ) bip
    ON rest.role_code = bip.role_common_name
 ORDER BY COALESCE(rest.role_code, bip.role_common_name);


-- =====================================================================
-- 6. Check: Does the BIP report have a TYPE_CODE that might explain
--    the difference?  Common Fusion role types:
--      ENTERPRISE  = Job/Enterprise roles (top-level, directly assignable)
--      DUTY        = Duty roles (inherited inside a job role)
--      ABSTRACT    = Abstract roles (behavior-defining, not assignable directly)
--      DATA        = Data roles (data security context)
--
--    If REST returns only ENTERPRISE roles and BIP includes DUTY/ABSTRACT,
--    that's the root cause.
-- =====================================================================
-- (This query repeats #3 but grouped by type_code for summary)
SELECT r.type_code,
       COUNT(*) AS extra_roles_count
  FROM fa_user_accounts a
  JOIN fa_user_roles    r ON r.user_guid = a.user_guid
 WHERE UPPER(a.username) = '<FUSION_CREDENTIAL>'
   AND (r.effective_end_date IS NULL OR r.effective_end_date > SYSTIMESTAMP)
   AND r.role_common_name NOT IN (
       SELECT c001
         FROM apex_collections
        WHERE collection_name = 'FUSION_USER_ROLES'
   )
 GROUP BY r.type_code
 ORDER BY r.type_code;


-- =====================================================================
-- 7. Sanity check: What does the raw REST JSON return?
--    Re-fetch the REST response and show the full role list.
--    (Run this from APEX SQL Commands or as anonymous PL/SQL)
-- =====================================================================
/*
DECLARE
    l_url   VARCHAR2(2000);
    l_clob  CLOB;
BEGIN
    l_url := 'https://<FUSION_HOST_DEV>'
          || '/hcmRestApi/resources/11.13.18.05/userAccounts'
          || '?q=Username%3D''<FUSION_CREDENTIAL>'''
          || '&expand=userAccountRoles'
          || '&onlyData=true';

    apex_web_service.clear_request_headers;
    l_clob := apex_web_service.make_rest_request(
        p_url                  => l_url,
        p_http_method          => 'GET',
        p_credential_static_id => '<FUSION_CREDENTIAL>'
    );

    -- Print full response for inspection
    DBMS_OUTPUT.PUT_LINE('HTTP Status: ' || apex_web_service.g_status_code);
    DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(l_clob));
    DBMS_OUTPUT.PUT_LINE(SUBSTR(l_clob, 1, 4000));
    -- If response > 4000 chars:
    -- DBMS_OUTPUT.PUT_LINE(SUBSTR(l_clob, 4001, 4000));
END;
/
*/
