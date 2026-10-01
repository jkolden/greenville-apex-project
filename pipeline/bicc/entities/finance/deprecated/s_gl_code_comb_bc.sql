-- =============================================================================
-- STAGING TABLE: S_GL_CODE_COMB_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.GlBiccExtractAM.CodeCombinationExtractPVO
-- Curated subset of L_GL_CODE_COMB_BC with proper Oracle types.
-- Segment columns stored as VARCHAR2 with LPAD to preserve leading zeros.
--
-- Segment mapping:
--   SEGMENT1 = Fund        (max 4)
--   SEGMENT2 = Location    (max 3)
--   SEGMENT3 = Function1   (max 4)
--   SEGMENT4 = Grant       (max 3)
--   SEGMENT5 = Initiative  (max 3)
--   SEGMENT6 = Account     (max 7)
--   SEGMENT7 = Activity    (max 4)
--   SEGMENT8 = InterFund   (max 4)
--   SEGMENT9 = Future1     (max 5)
-- =============================================================================

CREATE TABLE S_GL_CODE_COMB_BC (
    JOB_ID                      NUMBER          NOT NULL,
    CODE_COMBINATION_ID         NUMBER          NOT NULL,
    CHART_OF_ACCOUNTS_ID        NUMBER,
    ACCOUNT_TYPE                VARCHAR2(1),
    ENABLED_FLAG                VARCHAR2(1),
    DETAIL_BUDGETING_ALLOWED    VARCHAR2(1),
    DETAIL_POSTING_ALLOWED      VARCHAR2(1),
    SUMMARY_FLAG                VARCHAR2(1),
    FUND                        VARCHAR2(4),
    LOCATION                    VARCHAR2(3),
    FUNCTION1                   VARCHAR2(4),
    GRANT_CODE                  VARCHAR2(3),
    INITIATIVE                  VARCHAR2(3),
    ACCOUNT                     VARCHAR2(7),
    ACTIVITY                    VARCHAR2(4),
    INTERFUND                   VARCHAR2(4),
    FUTURE1                     VARCHAR2(5),
    START_DATE_ACTIVE_RAW       VARCHAR2(50),
    START_DATE_ACTIVE_TS        TIMESTAMP(6),
    END_DATE_ACTIVE_RAW         VARCHAR2(50),
    END_DATE_ACTIVE_TS          TIMESTAMP(6),
    LAST_UPDATE_DATE_RAW        VARCHAR2(50),
    LAST_UPDATE_DATE_TS         TIMESTAMP(6),
    LAST_EXTRACT_RUN_ID         VARCHAR2(64),
    LAST_EXTRACT_RUN_TS         TIMESTAMP(6)
);

CREATE INDEX S_GL_CODE_COMB_BC_N1 ON S_GL_CODE_COMB_BC (JOB_ID, CODE_COMBINATION_ID);
CREATE INDEX S_GL_CODE_COMB_BC_N2 ON S_GL_CODE_COMB_BC (JOB_ID, ACCOUNT);
