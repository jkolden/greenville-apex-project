create or replace package pkg_bicc_common as
-- =============================================================================
-- Shared utilities for BICC COPY_DATA pipeline.
-- Used by all entity packages (pkg_bicc_hcm_employee, pkg_bicc_ap_invoice, etc.)
-- =============================================================================

    -- Constants
    gc_credential  constant varchar2(30)  := 'OBJ_STORE_CRED_JK';
    gc_bucket_uri  constant varchar2(200) := 'https://objectstorage.us-ashburn-1.oraclecloud.com/n/idlhcuqzdx2c/b/SCI_Conversion/o/';

    -- Fusion Cloud instance base URL (single source of truth for all packages)
    gc_fa_base_url constant varchar2(200) := 'https://ibzsjb-dev4.fa.ocs.oraclecloud.com';

    -- Type conversion (tolerant of bad data)
    function safe_to_number(p_str varchar2) return number;
    function safe_to_timestamp(p_str varchar2) return timestamp;

    -- Extract CSV from ZIP and upload to Object Storage staging location
    procedure extract_and_stage_csv(
        p_file_name    in varchar2,
        p_credential   in varchar2 default gc_credential,
        p_bucket_uri   in varchar2 default gc_bucket_uri,
        p_staging_name in varchar2
    );

    -- File management
    procedure refresh_bicc_files;

    procedure purge_bicc_objectstore(
        p_retention_days in number default 60
    );

    -- Housekeeping
    procedure purge_copy_tables;

    -- Orchestration
    procedure run_bicc_daily_today;

end pkg_bicc_common;
/
