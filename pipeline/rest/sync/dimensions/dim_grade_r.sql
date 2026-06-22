-- =============================================================================
-- DIMENSION TABLE: DIM_GRADE_R
-- =============================================================================
-- Loaded from Oracle Fusion REST API: /hcmRestApi/resources/11.13.18.05/gradesLov
-- Refreshed by PKG_BICC_DIMENSIONS.LOAD_GRADES
-- =============================================================================

CREATE TABLE DIM_GRADE_R (
    GRADE_ID      NUMBER        PRIMARY KEY,
    GRADE_NAME    VARCHAR2(240) NOT NULL,
    GRADE_CODE    VARCHAR2(60),
    REFRESHED_TS  TIMESTAMP(6)
);
