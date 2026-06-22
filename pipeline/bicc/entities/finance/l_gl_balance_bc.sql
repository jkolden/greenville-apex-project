-- =============================================================================
-- LANDING TABLE: L_GL_BALANCE_BC
-- =============================================================================
-- Source: FscmTopModelAM.FinExtractAM.GlBiccExtractAM.BalanceExtractPVO
-- COPY_DATA loads the raw CSV into this table.
-- The load procedure then cherry-picks columns into stg_fbx_gl_balance.
--
-- SETUP (three steps):
--   0. Extract CSV from the BICC ZIP (pkg_bicc_common.extract_and_stage_csv)
--   1. Create the external table (defines the CSV structure)
--   2. Create the landing table as a copy of the external table structure
--
-- IF BICC SCHEMA CHANGES:
--   DROP TABLE L_GL_BALANCE_BC;
--   DROP TABLE EXT_GL_BALANCE_BC;
--   Re-run Step 1 with updated column_list, then re-run Step 2.
-- =============================================================================


-- Step 0: Extract CSV from ZIP and upload to Object Storage
-- Replace the file name below with the actual BICC ZIP from your extract.
BEGIN
  pkg_bicc_common.extract_and_stage_csv(
      p_file_name    => 'file_fscmtopmodelam_finextractam_glbiccextractam_balanceextractpvo-batch2108794473-20260309_183143.zip',
      p_staging_name => 'staging/gl_balance_current.csv'
  );
END;
/


-- Step 1: Create external table (one-time, defines CSV structure)
-- Column order is alphabetical (standard BICC Fusion extract).
BEGIN
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'EXT_GL_BALANCE_BC',
    credential_name => '<OCI_CREDENTIAL_NAME>',
    file_uri_list   => 'https://objectstorage.us-ashburn-1.oraclecloud.com/n/<OCI_NAMESPACE>/b/<OCI_BUCKET_NAME>/o/staging/gl_balance_current.csv',
    format          => json_object(
                         'type' value 'csv',
                         'skipheaders' value '1'
                       ),
    column_list     => 'BALANCEACTUALFLAG VARCHAR2(4000),BALANCEBEGINBALANCECR VARCHAR2(4000),BALANCEBEGINBALANCECRBEQ VARCHAR2(4000),BALANCEBEGINBALANCEDR VARCHAR2(4000),BALANCEBEGINBALANCEDRBEQ VARCHAR2(4000),BALANCECODECOMBINATIONID VARCHAR2(4000),BALANCECURRENCYCODE VARCHAR2(4000),BALANCEENCUMBRANCETYPEID VARCHAR2(4000),BALANCELASTUPDATEDATE VARCHAR2(4000),BALANCELASTUPDATEDBY VARCHAR2(4000),BALANCELEDGERID VARCHAR2(4000),BALANCEOBJECTVERSIONNUMBER VARCHAR2(4000),BALANCEPERIODNAME VARCHAR2(4000),BALANCEPERIODNETCR VARCHAR2(4000),BALANCEPERIODNETCRBEQ VARCHAR2(4000),BALANCEPERIODNETDR VARCHAR2(4000),BALANCEPERIODNETDRBEQ VARCHAR2(4000),BALANCEPERIODNUM VARCHAR2(4000),BALANCEPERIODYEAR VARCHAR2(4000),BALANCEPROJECTTODATECR VARCHAR2(4000),BALANCEPROJECTTODATECRBEQ VARCHAR2(4000),BALANCEPROJECTTODATEDR VARCHAR2(4000),BALANCEPROJECTTODATEDRBEQ VARCHAR2(4000),BALANCEQUARTERTODATECR VARCHAR2(4000),BALANCEQUARTERTODATECRBEQ VARCHAR2(4000),BALANCEQUARTERTODATEDR VARCHAR2(4000),BALANCEQUARTERTODATEDRBEQ VARCHAR2(4000)'
  );
END;
/

-- Step 2: Create landing table from the external table structure
CREATE TABLE L_GL_BALANCE_BC AS SELECT * FROM EXT_GL_BALANCE_BC WHERE 1=0;
