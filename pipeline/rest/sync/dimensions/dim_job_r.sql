-- =============================================================================
-- DIMENSION TABLE: DIM_JOB_R
-- =============================================================================
-- Loaded from Oracle Fusion REST API: /hcmRestApi/resources/11.13.18.05/jobs
-- Refreshed by PKG_BICC_DIMENSIONS.LOAD_JOBS
-- =============================================================================

CREATE TABLE DIM_JOB_R (
    JOB_ID        NUMBER        PRIMARY KEY,
    JOB_NAME      VARCHAR2(240) NOT NULL,
    JOB_CODE      VARCHAR2(60),
    REFRESHED_TS  TIMESTAMP(6)
);
