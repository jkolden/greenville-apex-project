-- =============================================================================
-- LANDING TABLE: L_QSTNR_RESPONSE_BC
-- =============================================================================
-- Source: HcmTopModelAnalyticsGlobalAM.QuestionnaireAM.QuestionnaireQuestionResponsePVO
-- COPY_DATA loads the raw CSV into this table.
-- The load procedure then cherry-picks columns into S_QSTNR_RESPONSE_BC.
--
-- SETUP (three steps):
--   0. Extract CSV from the BICC ZIP (pkg_bicc_common.extract_and_stage_csv)
--   1. Create the external table (defines the CSV structure)
--   2. Create the landing table as a copy of the external table structure
--
-- IF BICC SCHEMA CHANGES:
--   DROP TABLE L_QSTNR_RESPONSE_BC;
--   DROP TABLE EXT_QSTNR_RESPONSE_BC;
--   Re-run Step 1 with updated column_list, then re-run Step 2.
-- =============================================================================


-- Step 0: Extract CSV from ZIP and upload to Object Storage
-- Replace the file name below with the actual BICC ZIP from your extract.
BEGIN
  pkg_bicc_common.extract_and_stage_csv(
      p_file_name    => 'file_hcmtopmodelanalyticsglobalam_questionnaream_questionnairequestionresponsepvo-batch_REPLACE_ME.zip',
      p_staging_name => 'staging/qstnr_response_current.csv'
  );
END;
/


-- Step 1: Create external table (one-time, defines CSV structure)
-- Column order matches the BICC CSV as-is (NOT alphabetical for PVO extracts).
-- NOTE: QUESTIONNAIREPARTCIPANT is NOT a typo -- Oracle spells it without the 'I'.
BEGIN
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'EXT_QSTNR_RESPONSE_BC',
    credential_name => '<OCI_CREDENTIAL_NAME>',
    file_uri_list   => 'https://objectstorage.us-ashburn-1.oraclecloud.com/n/<OCI_NAMESPACE>/b/<OCI_BUCKET_NAME>/o/staging/qstnr_response_current.csv',
    format          => json_object(
                         'type' value 'csv',
                         'skipheaders' value '1'
                       ),
    column_list     => 'QSTNRESPONSEPEOLASTUPDATEDATE VARCHAR2(4000),QSTNRESPONSEPEOQSTNRESPONSEID VARCHAR2(4000),QUESTIONRESPONSEPEOANSWERCLOB VARCHAR2(4000),QUESTIONRESPONSEPEOANSWERID VARCHAR2(4000),QUESTIONRESPONSEPEOANSWERTYPE VARCHAR2(4000),QUESTIONRESPONSEPEOBUSINESSGROUPID VARCHAR2(4000),QUESTIONRESPONSEPEOQSTNRESPONSEID VARCHAR2(4000),QUESTIONRESPONSEPEOQSTNRQUESTIONID VARCHAR2(4000),QUESTIONNAIREPARTCIPANTPEOBUSINESSGROUPID VARCHAR2(4000),QUESTIONNAIREPARTCIPANTPEOQSTNRPARTICIPANTID VARCHAR2(4000),QUESTIONNAIREPARTCIPANTPEOSUBJECTID VARCHAR2(4000),QUESTIONNAIREPARTICIPANTPEOLASTUPDATEDATE VARCHAR2(4000),QUESTIONNAIRERESPONSEPEOATTEMPTNUM VARCHAR2(4000),QUESTIONNAIRERESPONSEPEOBUSINESSGROUPID VARCHAR2(4000),QUESTIONNAIRERESPONSEPEOLASTUPDATEDATE VARCHAR2(4000),QUESTIONNAIRERESPONSEPEOQSTNRPARTICIPANTID VARCHAR2(4000),QUESTIONNAIRERESPONSEPEOQSTNRRESPONSEID VARCHAR2(4000),QUESTIONNAIRERESPONSEPEOSTATUS VARCHAR2(4000),QUESTIONNAIRERESPONSEPEOSUBMITTEDDATETIME VARCHAR2(4000)'
  );
END;
/

-- Step 2: Create landing table from the external table structure
CREATE TABLE L_QSTNR_RESPONSE_BC AS SELECT * FROM EXT_QSTNR_RESPONSE_BC WHERE 1=0;
