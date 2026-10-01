-- =============================================================================
-- STAGING TABLE: S_AP_INV_APPLICATION_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.ApBiccExtractAM.PaidDisbursementScheduleExtractPVO
-- Curated subset of L_AP_INV_APPLICATION_BC with proper Oracle types.
-- Underlying table: AP_INVOICE_PAYMENTS_ALL
-- Bridge: INVOICE_ID <-> CHECK_ID (disbursement)
--
-- PK: INVOICE_PAYMENT_ID
-- =============================================================================

CREATE TABLE S_AP_INV_APPLICATION_BC (
    JOB_ID                      NUMBER          NOT NULL,
    INVOICE_PAYMENT_ID          NUMBER          NOT NULL,
    INVOICE_ID                  NUMBER          NOT NULL,
    CHECK_ID                    NUMBER          NOT NULL,
    PAYMENT_NUM                 NUMBER,
    AMOUNT                      NUMBER,
    AMOUNT_INV_CURR             NUMBER,
    INVOICE_BASE_AMOUNT         NUMBER,
    PAYMENT_BASE_AMOUNT         NUMBER,
    INVOICE_CURRENCY_CODE       VARCHAR2(15),
    PAYMENT_CURRENCY_CODE       VARCHAR2(15),
    INVOICE_PAYMENT_TYPE        VARCHAR2(30),
    DISCOUNT_TAKEN              NUMBER,
    DISCOUNT_LOST               NUMBER,
    ACCOUNTING_DATE_RAW         VARCHAR2(50),
    ACCOUNTING_DATE_TS          TIMESTAMP(6),
    PERIOD_NAME                 VARCHAR2(15),
    POSTED_FLAG                 VARCHAR2(1),
    REVERSAL_FLAG               VARCHAR2(1),
    REVERSAL_INV_PMT_ID         NUMBER,
    ORG_ID                      NUMBER,
    EXCHANGE_RATE               NUMBER,
    EXCHANGE_DATE_RAW           VARCHAR2(50),
    EXCHANGE_DATE_TS            TIMESTAMP(6),
    EXCHANGE_RATE_TYPE          VARCHAR2(30),
    ACCTS_PAY_CCID              NUMBER,
    REMIT_TO_SUPPLIER_NAME      VARCHAR2(360),
    CREATION_DATE_RAW           VARCHAR2(50),
    CREATION_DATE_TS            TIMESTAMP(6),
    LAST_UPDATE_DATE_RAW        VARCHAR2(50),
    LAST_UPDATE_DATE_TS         TIMESTAMP(6),
    LAST_EXTRACT_RUN_ID         VARCHAR2(64),
    LAST_EXTRACT_RUN_TS         TIMESTAMP(6)
);

CREATE INDEX S_AP_INV_APPLICATION_BC_N1 ON S_AP_INV_APPLICATION_BC (JOB_ID, INVOICE_PAYMENT_ID);
CREATE INDEX S_AP_INV_APPLICATION_BC_N2 ON S_AP_INV_APPLICATION_BC (JOB_ID, INVOICE_ID, CHECK_ID);
