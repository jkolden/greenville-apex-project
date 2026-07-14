create or replace package pkg_recon as

    ---------------------------------------------------------------------------
    -- Record-count reconciliation: compares local table counts against
    -- Fusion Cloud via REST totalResults and BIP count report.
    --
    -- Usage:
    --   DECLARE l_run_id NUMBER;
    --   BEGIN l_run_id := pkg_recon.run_recon; END;
    --
    -- Or from APEX Ajax callback:
    --   l_run_id := pkg_recon.run_recon;
    ---------------------------------------------------------------------------

    -- Fusion REST API credential
    gc_fa_credential constant varchar2(60)  := 'gcs_reports';

    -- Run reconciliation for all active sources. Returns run_id.
    function run_recon return number;

    -- Get Fusion-side record count via REST ?totalResults=true
    function get_rest_count (
        p_url_path in varchar2
    ) return number;

    -- Get local table record count via dynamic SQL
    function get_local_count (
        p_table_name in varchar2
    ) return number;

end pkg_recon;
/
