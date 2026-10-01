create or replace package pkg_bicc_gl_journal_lines as
-- =============================================================================
-- GL_JOURNAL_LINES entity package.
-- Uses DBMS_CLOUD.COPY_DATA via pkg_bicc_common.extract_and_stage_csv.
--
-- Requires:
--   pkg_bicc_common                  (shared utilities)
--   landing_gl_journal_lines         (landing table, all VARCHAR2)
--   stg_fbx_gl_journal_lines         (staging table, typed columns)
--   fbx_gl_journal_lines             (final table)
--   bicc_load_job                    (job tracking)
--   bicc_load_log                    (load logging)
--
-- APEX usage:
--   l_job_id := pkg_bicc_gl_journal_lines.load_and_preview(:P_FILE_NAME);
--   pkg_bicc_gl_journal_lines.merge(p_job_id => :P_JOB_ID);
-- =============================================================================

    function load_and_preview(p_file_name in varchar2) return number;

    procedure merge(p_job_id in number);

end pkg_bicc_gl_journal_lines;
/