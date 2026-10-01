create or replace package pkg_bicc_ap_invoice_hdr as
-- =============================================================================
-- AP Invoice Header entity package.
-- Uses DBMS_CLOUD.COPY_DATA via pkg_bicc_common.extract_and_stage_csv.
--
-- Requires:
--   pkg_bicc_common            (shared utilities)
--   l_ap_invoice_hdr_bc        (landing table, all VARCHAR2)
--   s_ap_invoice_hdr_bc        (staging table, typed columns)
--   ap_invoice_hdr_bc          (final table)
--   bicc_load_job              (job tracking)
--   bicc_load_log              (load logging)
--
-- APEX usage:
--   l_job_id := pkg_bicc_ap_invoice_hdr.load_and_preview(:P_FILE_NAME);
--   pkg_bicc_ap_invoice_hdr.merge(p_job_id => :P_JOB_ID);
-- =============================================================================

    function load_and_preview(p_file_name in varchar2) return number;

    procedure merge(p_job_id in number);

end pkg_bicc_ap_invoice_hdr;
/
