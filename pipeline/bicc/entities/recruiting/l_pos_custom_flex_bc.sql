-- =============================================================================
-- LANDING TABLE: L_POS_CUSTOM_FLEX_BC
-- =============================================================================
-- Source: FLEX_BI_POSITIONCUSTOMERFLEX_VI (Position Customer Flex DFF)
-- COPY_DATA loads the raw CSV into this table.
-- The load procedure then cherry-picks columns into stg_fbx_pos_custom_flex.
--
-- SETUP (three steps):
--   0. Extract CSV from ZIP and upload to Object Storage
--   1. Create the external table (defines the CSV structure)
--   2. Create the landing table as a copy of the external table structure
--
-- IF BICC SCHEMA CHANGES:
--   DROP TABLE L_POS_CUSTOM_FLEX_BC;
--   DROP TABLE EXT_POS_CUSTOM_FLEX_BC;
--   Re-run Step 0 (with new ZIP), then Step 1 with updated column_list, then Step 2.
-- =============================================================================


-- Step 0: Extract CSV from ZIP and upload to Object Storage
-- The external table needs a CSV file to exist at the URI below.
-- This one-time call pulls the CSV out of the BICC ZIP and stages it.
BEGIN
  pkg_bicc_common.extract_and_stage_csv(
      p_file_name    => 'file_hcmtopmodelanalyticsglobalam_positioncustomerflexbiam_flex_bi_positioncustomerflex_vi-batch1676076138-20260224_155911.zip',
      p_staging_name => 'pos_custom_flex_unzipped.csv'
  );
END;
/


-- Step 1: Create external table (one-time, defines CSV structure)
-- This is the source of truth for column names and order.
-- Column order MUST match BICC CSV header exactly.
-- NOTE: This extract is NOT alphabetical — order matches actual CSV layout.
BEGIN
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'EXT_POS_CUSTOM_FLEX_BC',
    credential_name => '<OCI_CREDENTIAL_NAME>',
    file_uri_list   => 'https://objectstorage.us-ashburn-1.oraclecloud.com/n/<OCI_NAMESPACE>/b/<OCI_BUCKET_NAME>/o/pos_custom_flex_unzipped.csv',
    format          => json_object(
                         'type' value 'csv',
                         'skipheaders' value '1'
                       ),
    column_list     => 'LASTUPDATEDATE VARCHAR2(4000),WORK_SCHEDULE_ VARCHAR2(4000),DESC_STATE_POSITION_CODE_ VARCHAR2(4000),STNTRT_CPTN_CT_ VARCHAR2(4000),DESC_STNTRT_CPTN_CT_ VARCHAR2(4000),FLEXFIELDCODE VARCHAR2(4000),DESC_WORK_SCHEDULE_ VARCHAR2(4000),PAYMENT_SCHEDULE_ VARCHAR2(4000),POSITION_CATEGORY_C VARCHAR2(4000),WORK_SCHEDULE_C VARCHAR2(4000),SHORT_DESCRIPTION_ VARCHAR2(4000),CREATEDBY VARCHAR2(4000),CREATIONDATE VARCHAR2(4000),STNTRT_CPTN_CT_C VARCHAR2(4000),POSITION_CATEGORY_ VARCHAR2(4000),SHORT_DESCRIPTION_C VARCHAR2(4000),STATE_POSITION_CODE_ VARCHAR2(4000),PAYMENT_SCHEDULE_C VARCHAR2(4000),DESC_POSITION_CATEGORY_ VARCHAR2(4000),DESC_PAYMENT_SCHEDULE_ VARCHAR2(4000),STATE_POSITION_CODE_C VARCHAR2(4000),LASTUPDATEDBY VARCHAR2(4000),S_K_5000 VARCHAR2(4000),S_K_5001 VARCHAR2(4000),APPLICATIONID VARCHAR2(4000),S_K_5002 VARCHAR2(4000)'
  );
END;
/

-- Step 2: Create landing table from the external table structure
CREATE TABLE L_POS_CUSTOM_FLEX_BC AS SELECT * FROM EXT_POS_CUSTOM_FLEX_BC WHERE 1=0;
