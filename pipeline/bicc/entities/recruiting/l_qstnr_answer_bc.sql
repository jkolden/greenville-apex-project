-- =============================================================================
-- LANDING TABLE: L_QSTNR_ANSWER_BC
-- =============================================================================
-- Source: HcmTopModelAnalyticsGlobalAM.QuestionnaireLibraryAM.QuestionAnswerPVO
-- COPY_DATA loads the raw CSV into this table.
-- The load procedure then cherry-picks columns into S_QSTNR_ANSWER_BC.
--
-- SETUP (three steps):
--   0. Extract CSV from the BICC ZIP (pkg_bicc_common.extract_and_stage_csv)
--   1. Create the external table (defines the CSV structure)
--   2. Create the landing table as a copy of the external table structure
--
-- IF BICC SCHEMA CHANGES:
--   DROP TABLE L_QSTNR_ANSWER_BC;
--   DROP TABLE EXT_QSTNR_ANSWER_BC;
--   Re-run Step 1 with updated column_list, then re-run Step 2.
-- =============================================================================


-- Step 0: Extract CSV from ZIP and upload to Object Storage
-- Replace the file name below with the actual BICC ZIP from your extract.
BEGIN
  pkg_bicc_common.extract_and_stage_csv(
      p_file_name    => 'file_hcmtopmodelanalyticsglobalam_questionnairelibraryam_questionanswerpvo-batch_REPLACE_ME.zip',
      p_staging_name => 'staging/qstnr_answer_current.csv'
  );
END;
/


-- Step 1: Create external table (one-time, defines CSV structure)
-- Column order matches the BICC CSV as-is.
BEGIN
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'EXT_QSTNR_ANSWER_BC',
    credential_name => '<OCI_CREDENTIAL_NAME>',
    file_uri_list   => 'https://objectstorage.us-ashburn-1.oraclecloud.com/n/<OCI_NAMESPACE>/b/<OCI_BUCKET_NAME>/o/staging/qstnr_answer_current.csv',
    format          => json_object(
                         'type' value 'csv',
                         'skipheaders' value '1'
                       ),
    column_list     => 'QUESTIONANSWERBPEOBUSINESSGROUPID VARCHAR2(4000),QUESTIONANSWERBPEOLASTUPDATEDATE VARCHAR2(4000),QUESTIONANSWERBPEOQSTNANSWERID VARCHAR2(4000),QUESTIONANSWERBPEOSCORE VARCHAR2(4000),QUESTIONANSWERBPEOSEQNUM VARCHAR2(4000),QUESTIONANSWERTRANSLATIONPEOBUSINESSGROUPID VARCHAR2(4000),QUESTIONANSWERTRANSLATIONPEOLANGUAGE VARCHAR2(4000),QUESTIONANSWERTRANSLATIONPEOLASTUPDATEDATE VARCHAR2(4000),QUESTIONANSWERTRANSLATIONPEOLONGTEXT VARCHAR2(4000),QUESTIONANSWERTRANSLATIONPEOQSTNANSWERID VARCHAR2(4000),QUESTIONANSWERTRANSLATIONPEORESPONSEFEEDBACK VARCHAR2(4000),QUESTIONANSWERTRANSLATIONPEOSHORTTEXT VARCHAR2(4000)'
  );
END;
/

-- Step 2: Create landing table from the external table structure
CREATE TABLE L_QSTNR_ANSWER_BC AS SELECT * FROM EXT_QSTNR_ANSWER_BC WHERE 1=0;
