-- =============================================================================
-- FINAL TABLE: HCM_SALARY_BC
-- =============================================================================
-- Published salary data from Fusion HCM Compensation.
-- Same as staging minus JOB_ID and _RAW date columns.
-- =============================================================================

CREATE TABLE HCM_SALARY_BC (
    SALARY_ID                      NUMBER,
    PERSON_ID                      NUMBER,
    ASSIGNMENT_ID                  NUMBER,
    ASSIGNMENT_TYPE                VARCHAR2(10),
    BUSINESS_UNIT_ID               NUMBER,
    LEGAL_ENTITY_ID                NUMBER,
    HCM_JOB_ID                    NUMBER,
    GRADE_ID                       NUMBER,
    ELEMENT_ENTRY_ID               NUMBER,
    ELEMENT_TYPE_ID                NUMBER,
    INPUT_VALUE_ID                 NUMBER,
    SALARY_AMOUNT                  NUMBER,
    ANNUAL_SALARY                  NUMBER,
    ANNUAL_FT_SALARY               NUMBER,
    CURRENCY_CODE                  VARCHAR2(10),
    SALARY_BASIS_CODE              VARCHAR2(60),
    SALARY_BASIS_ID                NUMBER,
    SALARY_BASIS_TYPE              VARCHAR2(10),
    SALARY_APPROVED                VARCHAR2(1),
    SALARY_FACTOR                  NUMBER,
    PAYROLL_FACTOR                 NUMBER,
    PAYROLL_FREQUENCY_CODE         VARCHAR2(30),
    FTE_VALUE                      NUMBER,
    SALARY_TRANSACTION_STATUS      VARCHAR2(30),
    SALARY_REASON_CODE             VARCHAR2(60),
    COMPONENT_USAGE                VARCHAR2(60),
    MULTIPLE_COMPONENTS            VARCHAR2(1),
    ACTION_ID                      NUMBER,
    ACTION_OCCURRENCE_ID           NUMBER,
    ACTION_REASON_ID               NUMBER,
    ADJUSTMENT_AMOUNT              NUMBER,
    ADJUSTMENT_PERCENT             NUMBER,
    RATE_ID                        NUMBER,
    RATE_FACTOR                    NUMBER,
    RATE_MAX_AMOUNT                NUMBER,
    RATE_MID_AMOUNT                NUMBER,
    RATE_MIN_AMOUNT                NUMBER,
    RATE_DEFAULT_AMOUNT            NUMBER,
    RANGE_POSITION                 NUMBER,
    COMPARATIO                     NUMBER,
    QUARTILE                       NUMBER,
    QUINTILE                       NUMBER,
    TOTAL_BASE_PAY                 NUMBER,
    TOTAL_COMPONENT_ADJ_AMT        NUMBER,
    TOTAL_COMPONENT_ADJ_PERCENT    NUMBER,
    DATE_FROM_TS                   TIMESTAMP(6),
    DATE_TO_TS                     TIMESTAMP(6),
    SALARY_EFFECTIVE_START_TS      TIMESTAMP(6),
    SALARY_EFFECTIVE_END_TS        TIMESTAMP(6),
    REVIEW_DATE_TS                 TIMESTAMP(6),
    NEXT_SAL_REVIEW_TS             TIMESTAMP(6),
    WORK_AT_HOME                   VARCHAR2(1),
    OBJECT_VERSION_NUMBER          NUMBER,
    LAST_EXTRACT_RUN_ID            VARCHAR2(64),
    LAST_EXTRACT_RUN_TS            TIMESTAMP(6),
    PRIMARY KEY (SALARY_ID)
);

CREATE INDEX FBX_HCM_SALARY_N1 ON HCM_SALARY_BC (PERSON_ID);

CREATE INDEX FBX_HCM_SALARY_N2 ON HCM_SALARY_BC (ASSIGNMENT_ID);
