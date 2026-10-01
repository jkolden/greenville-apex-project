-- =============================================================================
-- FINAL TABLE: AP_DISBURSEMENT_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.ApBiccExtractAM.DisbursementHeaderExtractPVO
-- Underlying table: AP_CHECKS_ALL
-- One row per physical payment (check or EFT disbursement).
-- Same as staging minus JOB_ID and _RAW cols.
-- PK on CHECK_ID.
-- =============================================================================

CREATE TABLE AP_DISBURSEMENT_BC (
    CHECK_ID                    NUMBER          NOT NULL,
    CHECK_NUMBER                NUMBER,
    CHECK_DATE_TS               TIMESTAMP(6),
    AMOUNT                      NUMBER,
    BASE_AMOUNT                 NUMBER,
    CURRENCY_CODE               VARCHAR2(15),
    STATUS_LOOKUP_CODE          VARCHAR2(30),
    PAYMENT_METHOD_CODE         VARCHAR2(30),
    PAYMENT_TYPE_FLAG           VARCHAR2(1),
    VENDOR_ID                   NUMBER,
    VENDOR_NAME                 VARCHAR2(360),
    VENDOR_SITE_ID              NUMBER,
    VENDOR_SITE_CODE            VARCHAR2(100),
    REMIT_TO_SUPPLIER_ID        NUMBER,
    REMIT_TO_SUPPLIER_NAME      VARCHAR2(360),
    ORG_ID                      NUMBER,
    LEGAL_ENTITY_ID             NUMBER,
    BANK_ACCOUNT_NAME           VARCHAR2(100),
    CE_BANK_ACCT_USE_ID         NUMBER,
    EXTERNAL_BANK_ACCOUNT_ID    NUMBER,
    CHECK_RUN_NAME              VARCHAR2(200),
    CLEARED_AMOUNT              NUMBER,
    CLEARED_BASE_AMOUNT         NUMBER,
    CLEARED_DATE_TS             TIMESTAMP(6),
    VOID_DATE_TS                TIMESTAMP(6),
    RELEASED_DATE_TS            TIMESTAMP(6),
    EXCHANGE_RATE               NUMBER,
    EXCHANGE_DATE_TS            TIMESTAMP(6),
    CREATION_DATE_TS            TIMESTAMP(6),
    LAST_UPDATE_DATE_TS         TIMESTAMP(6),
    LAST_EXTRACT_RUN_ID         VARCHAR2(64),
    LAST_EXTRACT_RUN_TS         TIMESTAMP(6),
    CONSTRAINT AP_DISBURSEMENT_BC_PK PRIMARY KEY (CHECK_ID)
);

CREATE INDEX AP_DISBURSEMENT_BC_N1 ON AP_DISBURSEMENT_BC (VENDOR_ID);
CREATE INDEX AP_DISBURSEMENT_BC_N2 ON AP_DISBURSEMENT_BC (CHECK_DATE_TS);
CREATE INDEX AP_DISBURSEMENT_BC_N3 ON AP_DISBURSEMENT_BC (STATUS_LOOKUP_CODE);
