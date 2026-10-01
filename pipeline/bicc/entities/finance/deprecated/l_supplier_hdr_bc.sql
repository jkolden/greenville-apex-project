-- =============================================================================
-- LANDING TABLE: L_SUPPLIER_HDR_BC
-- =============================================================================
-- COPY_DATA loads the raw CSV into this table.
-- The load procedure then cherry-picks columns into stg_fbx_supplier_hdr.
--
-- SETUP (two steps):
--   1. Create the external table (defines the CSV structure)
--   2. Create the landing table as a copy of the external table structure
--
-- IF BICC SCHEMA CHANGES:
--   DROP TABLE L_SUPPLIER_HDR_BC;
--   DROP TABLE EXT_SUPPLIER_HDR_BC;
--   Re-run Step 1 with updated column_list, then re-run Step 2.
-- =============================================================================


-- Step 1: Create external table (one-time, defines CSV structure)
-- This is the source of truth for column names and order.
-- UPDATE the file_uri_list to point at an existing extracted CSV before running.
BEGIN
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'EXT_SUPPLIER_HDR_BC',
    credential_name => '<OCI_CREDENTIAL_NAME>',
    file_uri_list   => 'https://objectstorage.us-ashburn-1.oraclecloud.com/n/<OCI_NAMESPACE>/b/<OCI_BUCKET_NAME>/o/supplier_hdr_extracted.csv',
    format          => json_object(
                         'type' value 'csv',
                         'skipheaders' value '1'
                       ),
    column_list     => 'ALIASPARTYNAME VARCHAR2(4000),ALIASPARTYNAMEID VARCHAR2(4000),ALLOWAWTFLAG VARCHAR2(4000),ALTERNATENAMEPARTYNAME VARCHAR2(4000),ALTERNATENAMEPARTYNAMEID VARCHAR2(4000),ATTRIBUTE13 VARCHAR2(4000),AWTGROUPID VARCHAR2(4000),BCNOTAPPLICABLEFLAG VARCHAR2(4000),BUSINESSRELATIONSHIP VARCHAR2(4000),CORPORATEWEBSITE VARCHAR2(4000),CREATEDBY VARCHAR2(4000),CREATIONDATE VARCHAR2(4000),CREATIONSOURCE VARCHAR2(4000),CUSTOMERNUM VARCHAR2(4000),ENDDATEACTIVE VARCHAR2(4000),FEDERALREPORTABLEFLAG VARCHAR2(4000),INCOMETAXID VARCHAR2(4000),INCOMETAXIDFLAG VARCHAR2(4000),LASTUPDATEDATE VARCHAR2(4000),LASTUPDATELOGIN VARCHAR2(4000),LASTUPDATEDBY VARCHAR2(4000),NAMECONTROL VARCHAR2(4000),NINUMBER VARCHAR2(4000),NINUMBERFLAG VARCHAR2(4000),OBJECTVERSIONNUMBER VARCHAR2(4000),ONETIMEFLAG VARCHAR2(4000),ORGANIZATIONTYPELOOKUPCODE VARCHAR2(4000),PARENTPARTYID VARCHAR2(4000),PARENTVENDORID VARCHAR2(4000),PARTYID VARCHAR2(4000),SEGMENT1 VARCHAR2(4000),SPENDAUTHREVIEWSTATUS VARCHAR2(4000),STANDARDINDUSTRYCLASS VARCHAR2(4000),STARTDATEACTIVE VARCHAR2(4000),STATEREPORTABLEFLAG VARCHAR2(4000),TAXREPORTINGNAME VARCHAR2(4000),TAXVERIFICATIONDATE VARCHAR2(4000),TAXPAYERCOUNTRY VARCHAR2(4000),TYPE1099 VARCHAR2(4000),VENDORID VARCHAR2(4000),VENDORID1 VARCHAR2(4000),VENDORTYPELOOKUPCODE VARCHAR2(4000)'
  );
END;
/

-- Step 2: Create landing table from external table structure (empty copy)
CREATE TABLE L_SUPPLIER_HDR_BC AS
SELECT * FROM EXT_SUPPLIER_HDR_BC WHERE 1=0;
