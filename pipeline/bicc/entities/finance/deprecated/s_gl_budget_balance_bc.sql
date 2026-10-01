-- =============================================================================
-- STAGING TABLE: S_GL_BUDGET_BALANCE_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.GlBiccExtractAM.BudgetBalanceExtractPVO
-- Curated subset of L_GL_BUDGET_BALANCE_BC with proper Oracle types.
--
-- No CODE_COMBINATION_ID in this extract — segments stored directly.
-- SEGMENT_STRING is computed during INSERT for PK and join convenience.
--
-- Segment mapping (same as GL_CODE_COMB):
--   SEGMENT1 = Fund        (max 4)
--   SEGMENT2 = Location    (max 3)
--   SEGMENT3 = Function1   (max 4)
--   SEGMENT4 = Grant       (max 3)
--   SEGMENT5 = Initiative  (max 3)
--   SEGMENT6 = Account     (max 7)
--   SEGMENT7 = Activity    (max 4)
--   SEGMENT8 = InterFund   (max 4)
--   SEGMENT9 = Future1     (max 5)
--
-- Composite key: (LEDGER_ID, BUDGET_NAME, CURRENCY_CODE, PERIOD_NAME,
--                 SEGMENT_STRING)
-- =============================================================================

CREATE TABLE S_GL_BUDGET_BALANCE_BC (
    JOB_ID                      NUMBER          NOT NULL,
    LEDGER_ID                   NUMBER          NOT NULL,
    BUDGET_NAME                 VARCHAR2(100)   NOT NULL,
    CURRENCY_CODE               VARCHAR2(15)    NOT NULL,
    CURRENCY_TYPE               VARCHAR2(1),
    PERIOD_NAME                 VARCHAR2(15)    NOT NULL,
    FUND                        VARCHAR2(4),
    LOCATION                    VARCHAR2(3),
    FUNCTION1                   VARCHAR2(4),
    GRANT_CODE                  VARCHAR2(3),
    INITIATIVE                  VARCHAR2(3),
    ACCOUNT                     VARCHAR2(7),
    ACTIVITY                    VARCHAR2(4),
    INTERFUND                   VARCHAR2(4),
    FUTURE1                     VARCHAR2(5),
    SEGMENT_STRING              VARCHAR2(50),
    PERIOD_NET_CR               NUMBER,
    PERIOD_NET_DR               NUMBER,
    LAST_UPDATE_DATE_RAW        VARCHAR2(50),
    LAST_UPDATE_DATE_TS         TIMESTAMP(6),
    LAST_EXTRACT_RUN_ID         VARCHAR2(64),
    LAST_EXTRACT_RUN_TS         TIMESTAMP(6)
);

CREATE INDEX S_GL_BUDGET_BALANCE_BC_N1 ON S_GL_BUDGET_BALANCE_BC (JOB_ID, SEGMENT_STRING, PERIOD_NAME);
CREATE INDEX S_GL_BUDGET_BALANCE_BC_N2 ON S_GL_BUDGET_BALANCE_BC (JOB_ID, BUDGET_NAME, PERIOD_NAME);
