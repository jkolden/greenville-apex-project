-- =============================================================================
-- FINAL TABLE: AP_INV_APPLICATION_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.ApBiccExtractAM.PaidDisbursementScheduleExtractPVO
-- Underlying table: AP_INVOICE_PAYMENTS_ALL
-- Published AP invoice-disbursement bridge data.
-- Same as staging minus JOB_ID and _RAW cols.
--
-- PK on INVOICE_PAYMENT_ID.
-- FK: INVOICE_ID -> FBX_AP_INVOICE_HDR.INVOICEID
-- FK: CHECK_ID   -> AP_DISBURSEMENT_BC.CHECK_ID
-- =============================================================================

CREATE TABLE AP_INV_APPLICATION_BC (
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
    ACCOUNTING_DATE_TS          TIMESTAMP(6),
    PERIOD_NAME                 VARCHAR2(15),
    POSTED_FLAG                 VARCHAR2(1),
    REVERSAL_FLAG               VARCHAR2(1),
    REVERSAL_INV_PMT_ID         NUMBER,
    ORG_ID                      NUMBER,
    EXCHANGE_RATE               NUMBER,
    EXCHANGE_DATE_TS            TIMESTAMP(6),
    EXCHANGE_RATE_TYPE          VARCHAR2(30),
    ACCTS_PAY_CCID              NUMBER,
    REMIT_TO_SUPPLIER_NAME      VARCHAR2(360),
    CREATION_DATE_TS            TIMESTAMP(6),
    LAST_UPDATE_DATE_TS         TIMESTAMP(6),
    LAST_EXTRACT_RUN_ID         VARCHAR2(64),
    LAST_EXTRACT_RUN_TS         TIMESTAMP(6),
    CONSTRAINT AP_INV_APPLICATION_BC_PK PRIMARY KEY (INVOICE_PAYMENT_ID)
);

CREATE INDEX AP_INV_APPLICATION_BC_N1 ON AP_INV_APPLICATION_BC (INVOICE_ID);
CREATE INDEX AP_INV_APPLICATION_BC_N2 ON AP_INV_APPLICATION_BC (CHECK_ID);
CREATE INDEX AP_INV_APPLICATION_BC_N3 ON AP_INV_APPLICATION_BC (INVOICE_ID, CHECK_ID);
