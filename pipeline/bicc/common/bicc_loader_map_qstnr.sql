-- =============================================================================
-- BICC_LOADER_MAP inserts for Questionnaire entities
-- =============================================================================
-- Run these INSERTs to register the 3 new load types in the orchestration map.
-- Adjust MAP_ID values to the next available in your environment.
-- Priority: Answer (80) loads first, then Question (81), then Response (82)
--   because the view needs all three but Answer is the smallest lookup.
-- =============================================================================

INSERT INTO BICC_LOADER_MAP (MAP_ID, PRIORITY, MODULE_CODE, OBJECT_CODE, FILE_LIKE, LOAD_TYPE, LOADER_AVAILABLE, IS_ACTIVE)
VALUES (80, 80, 'HCM', 'QSTNR_ANSWER', '%questionanswerpvo%', 'QSTNR_ANSWER', 'Y', 'Y');

INSERT INTO BICC_LOADER_MAP (MAP_ID, PRIORITY, MODULE_CODE, OBJECT_CODE, FILE_LIKE, LOAD_TYPE, LOADER_AVAILABLE, IS_ACTIVE)
VALUES (81, 81, 'HCM', 'QSTNR_QUESTION', '%participantquestionnairequestionpvo%', 'QSTNR_QUESTION', 'Y', 'Y');

INSERT INTO BICC_LOADER_MAP (MAP_ID, PRIORITY, MODULE_CODE, OBJECT_CODE, FILE_LIKE, LOAD_TYPE, LOADER_AVAILABLE, IS_ACTIVE)
VALUES (82, 82, 'HCM', 'QSTNR_RESPONSE', '%questionnairequestionresponsepvo%', 'QSTNR_RESPONSE', 'Y', 'Y');

COMMIT;


-- =============================================================================
-- pkg_bicc_common.plb updates needed:
-- =============================================================================
-- 1. IN-list filter (line ~225): Add 'QSTNR_ANSWER','QSTNR_QUESTION','QSTNR_RESPONSE'
--
-- 2. Stage CASE statement (line ~264): Add:
--      WHEN 'QSTNR_ANSWER'   THEN l_job_id := pkg_bicc_qstnr_answer.load_and_preview(l_file_name);
--      WHEN 'QSTNR_QUESTION' THEN l_job_id := pkg_bicc_qstnr_question.load_and_preview(l_file_name);
--      WHEN 'QSTNR_RESPONSE' THEN l_job_id := pkg_bicc_qstnr_response.load_and_preview(l_file_name);
--
-- 3. Merge CASE statement (line ~277): Add:
--      WHEN 'QSTNR_ANSWER'   THEN pkg_bicc_qstnr_answer.merge(l_job_id);
--      WHEN 'QSTNR_QUESTION' THEN pkg_bicc_qstnr_question.merge(l_job_id);
--      WHEN 'QSTNR_RESPONSE' THEN pkg_bicc_qstnr_response.merge(l_job_id);
--
-- 4. APEX Ajax callback: Add WHEN clauses for the 3 new load types.
-- =============================================================================
