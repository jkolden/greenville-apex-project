-- =============================================================================
-- DIMENSION TABLE: DIM_LOCATION_R
-- =============================================================================
-- Loaded from Oracle Fusion REST API: /hcmRestApi/resources/11.13.18.05/locationsV2
-- Refreshed by PKG_BICC_DIMENSIONS.LOAD_LOCATIONS
-- =============================================================================

CREATE TABLE DIM_LOCATION_R (
    LOCATION_ID   NUMBER        PRIMARY KEY,
    LOCATION_NAME VARCHAR2(240) NOT NULL,
    LOCATION_CODE VARCHAR2(60),
    REFRESHED_TS  TIMESTAMP(6)
);
