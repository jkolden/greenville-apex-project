-- =============================================================================
-- DIM_DEPARTMENT_R: Department dimension loaded from Fusion REST API
-- =============================================================================
-- Loaded by pkg_bicc_dimensions.load_departments via REST.
-- Endpoint: /hcmRestApi/resources/11.13.18.05/departments
-- =============================================================================

CREATE TABLE dim_department_r (
    department_id   NUMBER        PRIMARY KEY,
    department_name VARCHAR2(240) NOT NULL,
    active_status   VARCHAR2(30),
    location_id     NUMBER,
    location_code   VARCHAR2(60),
    location_name   VARCHAR2(240),
    refreshed_ts    TIMESTAMP(6)
);

CREATE INDEX dim_department_r_n1 ON dim_department_r (location_id);

COMMENT ON TABLE  dim_department_r                 IS 'Fusion department dimension (REST-loaded)';
COMMENT ON COLUMN dim_department_r.department_id   IS 'Fusion OrganizationId';
COMMENT ON COLUMN dim_department_r.department_name IS 'Department display name (e.g. FANS-188 - Food and Nutrition Services-Gateway ES)';
COMMENT ON COLUMN dim_department_r.active_status   IS 'A = Active, I = Inactive';
COMMENT ON COLUMN dim_department_r.location_id     IS 'FK to dim_location_r.location_id';
COMMENT ON COLUMN dim_department_r.location_code   IS 'Location code (e.g. 188)';
COMMENT ON COLUMN dim_department_r.location_name   IS 'Location name (e.g. Gateway Elementary School)';
COMMENT ON COLUMN dim_department_r.refreshed_ts    IS 'Last refresh timestamp';
