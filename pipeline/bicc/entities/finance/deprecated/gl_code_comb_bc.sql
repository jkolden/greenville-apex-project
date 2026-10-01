-- =============================================================================
-- FINAL TABLE: GL_CODE_COMB_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.GlBiccExtractAM.CodeCombinationExtractPVO
-- Published GL code combination data. Same as staging minus JOB_ID and _RAW cols.
-- PK on CODE_COMBINATION_ID.
-- GL Balance records will reference this table via CODE_COMBINATION_ID.
-- =============================================================================

CREATE TABLE GL_CODE_COMB_BC (
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
    START_DATE_ACTIVE_TS        TIMESTAMP(6),
    END_DATE_ACTIVE_TS          TIMESTAMP(6),
    LAST_UPDATE_DATE_TS         TIMESTAMP(6),
    LAST_EXTRACT_RUN_ID         VARCHAR2(64),
    LAST_EXTRACT_RUN_TS         TIMESTAMP(6),
    CONSTRAINT FBX_GL_CODE_COMB_PK PRIMARY KEY (CODE_COMBINATION_ID)
);

CREATE INDEX FBX_GL_CODE_COMB_N1 ON GL_CODE_COMB_BC (ACCOUNT);
CREATE INDEX FBX_GL_CODE_COMB_N2 ON GL_CODE_COMB_BC (FUND, LOCATION, FUNCTION1, ACCOUNT);
