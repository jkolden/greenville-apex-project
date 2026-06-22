create or replace package pkg_bicc_qstnr_answer as
-- =============================================================================
-- Questionnaire Answer lookup entity package.
-- Uses DBMS_CLOUD.COPY_DATA via pkg_bicc_common.extract_and_stage_csv.
--
-- Source: HcmTopModelAnalyticsGlobalAM.QuestionnaireLibraryAM.QuestionAnswerPVO
--
-- Requires:
--   pkg_bicc_common        (shared utilities)
--   l_qstnr_answer_bc      (landing table, all VARCHAR2)
--   s_qstnr_answer_bc      (staging table, typed columns)
--   qstnr_answer_bc        (final table)
--   bicc_load_job           (job tracking)
--   bicc_load_log           (load logging)
--
-- APEX usage:
--   l_job_id := pkg_bicc_qstnr_answer.load_and_preview(:P_FILE_NAME);
--   pkg_bicc_qstnr_answer.merge(p_job_id => :P_JOB_ID);
-- =============================================================================

    function load_and_preview(p_file_name in varchar2) return number;

    procedure merge(p_job_id in number);

end pkg_bicc_qstnr_answer;
/
