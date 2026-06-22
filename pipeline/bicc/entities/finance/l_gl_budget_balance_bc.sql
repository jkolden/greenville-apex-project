-- =============================================================================
-- LANDING TABLE: L_GL_BUDGET_BALANCE_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.GlBiccExtractAM.BudgetBalanceExtractPVO
-- COPY_DATA loads the raw CSV into this table.
-- The load procedure then cherry-picks columns into S_GL_BUDGET_BALANCE_BC.
--
-- SETUP (three steps):
--   0. Extract CSV from the BICC ZIP (pkg_bicc_common.extract_and_stage_csv)
--   1. Create the external table (defines the CSV structure)
--   2. Create the landing table as a copy of the external table structure
--
-- IF BICC SCHEMA CHANGES:
--   DROP TABLE L_GL_BUDGET_BALANCE_BC;
--   DROP TABLE EXT_GL_BUDGET_BALANCE_BC;
--   Re-run Step 1 with updated column_list, then re-run Step 2.
-- =============================================================================


-- Step 0: Extract CSV from ZIP and upload to Object Storage
-- Replace the file name below with the actual BICC ZIP from your extract.
BEGIN
  pkg_bicc_common.extract_and_stage_csv(
      p_file_name    => 'file_fscmtopmodelam_finextractam_glbiccextractam_budgetbalanceextractpvo-batch729898742-20260414_170251.zip',
      p_staging_name => 'staging/gl_budget_balance_current.csv'
  );
END;
/


-- Step 1: Create external table (one-time, defines CSV structure)
-- Column order matches the BICC CSV header (alphabetical).
-- 43 columns: BUDGETNAME, CURRENCYCODE, CURRENCYTYPE, audit cols,
-- PERIODNETCR/DR, SEGMENT1-30 (alphabetical), LEDGERID, PERIODNAME
BEGIN
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'EXT_GL_BUDGET_BALANCE_BC',
    credential_name => '<OCI_CREDENTIAL_NAME>',
    file_uri_list   => 'https://objectstorage.us-ashburn-1.oraclecloud.com/n/<OCI_NAMESPACE>/b/<OCI_BUCKET_NAME>/o/staging/gl_budget_balance_current.csv',
    format          => json_object(
                         'type' value 'csv',
                         'skipheaders' value '1'
                       ),
    column_list     => 'BUDGETNAME VARCHAR2(4000),CURRENCYCODE VARCHAR2(4000),CURRENCYTYPE VARCHAR2(4000),GLBUDBALCREATEDBY VARCHAR2(4000),GLBUDBALCREATIONDATE VARCHAR2(4000),GLBUDBALLASTUPDATEDATE VARCHAR2(4000),GLBUDBALLASTUPDATELOGIN VARCHAR2(4000),GLBUDBALLASTUPDATEDBY VARCHAR2(4000),GLBUDBALOBJECTVERSIONNUMBER VARCHAR2(4000),GLBUDBALPERIODNETCR VARCHAR2(4000),GLBUDBALPERIODNETDR VARCHAR2(4000),GLBUDBALSEGMENT1 VARCHAR2(4000),GLBUDBALSEGMENT10 VARCHAR2(4000),GLBUDBALSEGMENT11 VARCHAR2(4000),GLBUDBALSEGMENT12 VARCHAR2(4000),GLBUDBALSEGMENT13 VARCHAR2(4000),GLBUDBALSEGMENT14 VARCHAR2(4000),GLBUDBALSEGMENT15 VARCHAR2(4000),GLBUDBALSEGMENT16 VARCHAR2(4000),GLBUDBALSEGMENT17 VARCHAR2(4000),GLBUDBALSEGMENT18 VARCHAR2(4000),GLBUDBALSEGMENT19 VARCHAR2(4000),GLBUDBALSEGMENT2 VARCHAR2(4000),GLBUDBALSEGMENT20 VARCHAR2(4000),GLBUDBALSEGMENT21 VARCHAR2(4000),GLBUDBALSEGMENT22 VARCHAR2(4000),GLBUDBALSEGMENT23 VARCHAR2(4000),GLBUDBALSEGMENT24 VARCHAR2(4000),GLBUDBALSEGMENT25 VARCHAR2(4000),GLBUDBALSEGMENT26 VARCHAR2(4000),GLBUDBALSEGMENT27 VARCHAR2(4000),GLBUDBALSEGMENT28 VARCHAR2(4000),GLBUDBALSEGMENT29 VARCHAR2(4000),GLBUDBALSEGMENT3 VARCHAR2(4000),GLBUDBALSEGMENT30 VARCHAR2(4000),GLBUDBALSEGMENT4 VARCHAR2(4000),GLBUDBALSEGMENT5 VARCHAR2(4000),GLBUDBALSEGMENT6 VARCHAR2(4000),GLBUDBALSEGMENT7 VARCHAR2(4000),GLBUDBALSEGMENT8 VARCHAR2(4000),GLBUDBALSEGMENT9 VARCHAR2(4000),LEDGERID VARCHAR2(4000),PERIODNAME VARCHAR2(4000)'
  );
END;
/

-- Step 2: Create landing table from the external table structure
CREATE TABLE L_GL_BUDGET_BALANCE_BC AS SELECT * FROM EXT_GL_BUDGET_BALANCE_BC WHERE 1=0;
