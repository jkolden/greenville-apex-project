-- =============================================================================
-- FINAL TABLE: GL_BALANCE_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.GlBiccExtractAM.BalanceExtractPVO
-- Published GL balance data. Same as staging minus JOB_ID and _RAW cols.
-- FK to FBX_GL_CODE_COMB via CODE_COMBINATION_ID.
--
-- Composite PK: (LEDGER_ID, CODE_COMBINATION_ID, CURRENCY_CODE,
--                ACTUAL_FLAG, PERIOD_NAME)
--
-- Note: ENCUMBRANCE_TYPE_ID is nullable and excluded from PK.
-- If encumbrance balance tracking is needed, replace PK with a unique index
-- that includes NVL(ENCUMBRANCE_TYPE_ID, -1).
-- =============================================================================

CREATE TABLE GL_BALANCE_BC (
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
    LAST_UPDATE_DATE_TS         TIMESTAMP(6),
    LAST_EXTRACT_RUN_ID         VARCHAR2(64),
    LAST_EXTRACT_RUN_TS         TIMESTAMP(6),
    CONSTRAINT FBX_GL_BALANCE_PK PRIMARY KEY (LEDGER_ID, CODE_COMBINATION_ID, CURRENCY_CODE, ACTUAL_FLAG, PERIOD_NAME)
);

CREATE INDEX FBX_GL_BALANCE_N1 ON GL_BALANCE_BC (CODE_COMBINATION_ID);
CREATE INDEX FBX_GL_BALANCE_N2 ON GL_BALANCE_BC (PERIOD_YEAR, PERIOD_NUM);
