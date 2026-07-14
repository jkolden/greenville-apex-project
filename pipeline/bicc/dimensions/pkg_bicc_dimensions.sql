create or replace package pkg_bicc_dimensions as
-- =============================================================================
-- REST-loaded dimension tables from Oracle Fusion Cloud.
-- Uses DBMS_CLOUD.send_request() to call Fusion REST APIs and
-- MERGE results into DIM_*_R lookup tables.
-- =============================================================================

    -- Fusion REST API credential
    gc_fa_credential constant varchar2(60)  := 'gcs_reports';

    -- Individual dimension loaders
    procedure load_jobs;
    procedure load_grades;
    procedure load_locations;
    procedure load_departments;

    -- Refresh all dimensions (called from pkg_bicc_common.run_bicc_daily_today)
    procedure refresh_all;

end pkg_bicc_dimensions;
/
