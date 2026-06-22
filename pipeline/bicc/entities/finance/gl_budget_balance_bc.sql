-- =============================================================================
-- FINAL TABLE: GL_BUDGET_BALANCE_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.GlBiccExtractAM.BudgetBalanceExtractPVO
-- Published GL budget balance data. Same as staging minus JOB_ID and _RAW cols.
--
-- Composite PK: (LEDGER_ID, BUDGET_NAME, CURRENCY_CODE, PERIOD_NAME,
--                SEGMENT_STRING)
--
-- Join to GL_CODE_COMB_BC on matching segments to get CODE_COMBINATION_ID
-- and ACCOUNT_TYPE.
-- =============================================================================

CREATE TABLE GL_BUDGET_BALANCE_BC (
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
    SEGMENT_STRING              VARCHAR2(50)    NOT NULL,
    PERIOD_NET_CR               NUMBER,
    PERIOD_NET_DR               NUMBER,
    LAST_UPDATE_DATE_TS         TIMESTAMP(6),
    LAST_EXTRACT_RUN_ID         VARCHAR2(64),
    LAST_EXTRACT_RUN_TS         TIMESTAMP(6),
    CONSTRAINT GL_BUDGET_BALANCE_BC_PK PRIMARY KEY (LEDGER_ID, BUDGET_NAME, CURRENCY_CODE, PERIOD_NAME, SEGMENT_STRING)
);

CREATE INDEX GL_BUDGET_BALANCE_BC_N1 ON GL_BUDGET_BALANCE_BC (SEGMENT_STRING);
CREATE INDEX GL_BUDGET_BALANCE_BC_N2 ON GL_BUDGET_BALANCE_BC (ACCOUNT);
CREATE INDEX GL_BUDGET_BALANCE_BC_N3 ON GL_BUDGET_BALANCE_BC (BUDGET_NAME, PERIOD_NAME);
