create or replace package pkg_bicc_hcm_employee as
-- =============================================================================
-- HCM Employee entity package.
-- Uses DBMS_CLOUD.COPY_DATA via pkg_bicc_common.extract_and_stage_csv.
--
-- Requires:
--   pkg_bicc_common        (shared utilities)
--   l_hcm_employee_bc      (landing table, all VARCHAR2)
--   s_hcm_employee_bc      (staging table, typed columns)
--   hcm_employee_bc        (final table)
--   bicc_load_job           (job tracking)
--   bicc_load_log           (load logging)
--
-- APEX usage:
--   l_job_id := pkg_bicc_hcm_employee.load_and_preview(:P_FILE_NAME);
--   pkg_bicc_hcm_employee.merge(p_job_id => :P_JOB_ID);
-- =============================================================================

    function load_and_preview(p_file_name in varchar2) return number;

    procedure merge(p_job_id in number);

end pkg_bicc_hcm_employee;
/
