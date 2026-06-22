-- =============================================================================
-- TEST DATA: Give <FUSION_CREDENTIAL> two assignment locations for fallback testing
-- =============================================================================

-- Verify your person exists
SELECT PERSON_ID, DISPLAY_NAME, ASSIGNMENT_ID, LOCATION_NAME
  FROM HCM_EMPLOYEE_BC
 WHERE UPPER(USER_NAME) = '<FUSION_CREDENTIAL>';

-- Verify location codes
SELECT DISTINCT LOCATIONID, LOCATIONCODE, LOCATIONNAME
  FROM LOCATIONS_R
 WHERE LOCATIONNAME IN ('Donaldson Career Center', 'Wade Hampton High School');

-- Insert two test assignments
INSERT INTO HCM_ASSIGNMENT_BC (
    ASSIGNMENT_ID, PERSON_ID, LOCATION_ID,
    ASSIGNMENT_STATUS_TYPE, ASSIGNMENT_TYPE,
    EFFECTIVE_START_TS, EFFECTIVE_END_TS
)
SELECT -1,
       e.PERSON_ID,
       (SELECT LOCATIONID FROM LOCATIONS_R WHERE LOCATIONNAME = 'Donaldson Career Center' AND ROWNUM = 1),
       'ACTIVE', 'E',
       TIMESTAMP '2020-01-01 00:00:00', NULL
  FROM HCM_EMPLOYEE_BC e
 WHERE UPPER(e.USER_NAME) = '<FUSION_CREDENTIAL>';

INSERT INTO HCM_ASSIGNMENT_BC (
    ASSIGNMENT_ID, PERSON_ID, LOCATION_ID,
    ASSIGNMENT_STATUS_TYPE, ASSIGNMENT_TYPE,
    EFFECTIVE_START_TS, EFFECTIVE_END_TS
)
SELECT -2,
       e.PERSON_ID,
       (SELECT LOCATIONID FROM LOCATIONS_R WHERE LOCATIONNAME = 'Wade Hampton High School' AND ROWNUM = 1),
       'ACTIVE', 'E',
       TIMESTAMP '2020-01-01 00:00:00', NULL
  FROM HCM_EMPLOYEE_BC e
 WHERE UPPER(e.USER_NAME) = '<FUSION_CREDENTIAL>';

COMMIT;

-- Verify — should return 2 rows with location codes
SELECT a.ASSIGNMENT_ID, loc.LOCATIONNAME, loc.LOCATIONCODE
  FROM HCM_EMPLOYEE_BC e
  JOIN HCM_ASSIGNMENT_BC a
    ON a.PERSON_ID = e.PERSON_ID
   AND a.EFFECTIVE_START_TS <= SYSTIMESTAMP
   AND (a.EFFECTIVE_END_TS IS NULL OR a.EFFECTIVE_END_TS > SYSTIMESTAMP)
  LEFT JOIN LOCATIONS_R loc
    ON loc.LOCATIONID = a.LOCATION_ID
 WHERE UPPER(e.USER_NAME) = '<FUSION_CREDENTIAL>';

-- =============================================================================
-- CLEANUP
-- =============================================================================
-- DELETE FROM HCM_ASSIGNMENT_BC WHERE ASSIGNMENT_ID IN (-1, -2);
-- COMMIT;
-- =============================================================================
