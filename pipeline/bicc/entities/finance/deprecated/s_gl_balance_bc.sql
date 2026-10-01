-- =============================================================================
-- STAGING TABLE: S_GL_BALANCE_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.GlBiccExtractAM.BalanceExtractPVO
-- Curated subset of L_GL_BALANCE_BC with proper Oracle types.
-- FK to FBX_GL_CODE_COMB via CODE_COMBINATION_ID.
--
-- Composite key: (LEDGER_ID, CODE_COMBINATION_ID, CURRENCY_CODE,
--                 ACTUAL_FLAG, PERIOD_NAME)
--
-- BEQ columns = Base EQuivalent (functional/base currency amounts).
-- =============================================================================

CREATE TABLE S_GL_BALANCE_BC (
    JOB_ID                      NUMBER          NOT NULL,
    LEDGER_ID                   NUMBER          NOT NULL,
    CODE_COMBINATION_ID         NUMBER          NOT NULL,
    CURRENCY_CODE               VARCHAR2(15)    NOT NULL,
    ACTUAL_FLAG                 VARCHAR2(1)     NOT NULL,
    ENCUMBRANCE_TYPE_ID         NUMBER,
    PERIOD_NAME                 VARCHAR2(15)    NOT NULL,
    PERIOD_NUM                  NUMBER,
    PERIOD_YEAR                 NUMBER,
    BEGIN_BALANCE_CR            NUMBER,
    BEGIN_BALANCE_DR            NUMBER,
    BEGIN_BALANCE_CR_BEQ        NUMBER,
    BEGIN_BALANCE_DR_BEQ        NUMBER,
    PERIOD_NET_CR               NUMBER,
    PERIOD_NET_DR               NUMBER,
    PERIOD_NET_CR_BEQ           NUMBER,
    PERIOD_NET_DR_BEQ           NUMBER,
    QUARTER_TO_DATE_CR          NUMBER,
    QUARTER_TO_DATE_DR          NUMBER,
    QUARTER_TO_DATE_CR_BEQ      NUMBER,
    QUARTER_TO_DATE_DR_BEQ      NUMBER,
    PROJECT_TO_DATE_CR          NUMBER,
    PROJECT_TO_DATE_DR          NUMBER,
    PROJECT_TO_DATE_CR_BEQ      NUMBER,
    PROJECT_TO_DATE_DR_BEQ      NUMBER,
    LAST_UPDATE_DATE_RAW        VARCHAR2(50),
    LAST_UPDATE_DATE_TS         TIMESTAMP(6),
    LAST_EXTRACT_RUN_ID         VARCHAR2(64),
    LAST_EXTRACT_RUN_TS         TIMESTAMP(6)
);

CREATE INDEX S_GL_BALANCE_BC_N1 ON S_GL_BALANCE_BC (JOB_ID, CODE_COMBINATION_ID, PERIOD_NAME);
CREATE INDEX S_GL_BALANCE_BC_N2 ON S_GL_BALANCE_BC (JOB_ID, PERIOD_YEAR, PERIOD_NUM);
