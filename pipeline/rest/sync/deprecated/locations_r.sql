-- =============================================================================
-- LOCATIONS_R
-- APEX REST Data Source sync table — module static ID: rest_sync_locations
-- Module code: HCM  |  Sync type: FULL_ONLY
-- APEX$ columns (APEX$RESOURCEKEY, APEX$SYNC_STEP_STATIC_ID,
--   APEX$ROW_SYNC_TIMESTAMP) are managed by APEX REST Data Sync
-- =============================================================================
CREATE TABLE LOCATIONS_R (
    LOCATIONID                     NUMBER,
    SETID                          NUMBER,
    ACTIVESTATUS                   VARCHAR2(30),
    EMPLOYEELOCATIONFLAG           VARCHAR2(5),
    TELEPHONENUMBER1               VARCHAR2(240),
    TELEPHONENUMBER2               VARCHAR2(240),
    TELEPHONENUMBER3               VARCHAR2(240),
    EMAILADDRESS                   VARCHAR2(240),
    SHIPTOSITEFLAG                 VARCHAR2(5),
    RECEIVINGSITEFLAG              VARCHAR2(5),
    BILLTOSITEFLAG                 VARCHAR2(5),
    OFFICESITEFLAG                 VARCHAR2(5),
    STANDARDWORKINGHOURS           NUMBER,
    STANDARDWORKINGFREQUENCY       VARCHAR2(30),
    STANDARDANNUALWORKINGDURATION  NUMBER,
    ANNUALWORKINGDURATIONUNITS     VARCHAR2(10),
    LOCATIONCODE                   VARCHAR2(120),
    LOCATIONNAME                   VARCHAR2(60),
    DESCRIPTION                    VARCHAR2(240),
    MAINADDRESSID                  NUMBER,
    ADDRESSLINE1                   VARCHAR2(240),
    ADDRESSLINE2                   VARCHAR2(240),
    ADDRESSLINE3                   VARCHAR2(240),
    ADDRESSLINE4                   VARCHAR2(240),
    COUNTRY                        VARCHAR2(60),
    POSTALCODE                     VARCHAR2(30),
    REGION1                        VARCHAR2(120),
    REGION2                        VARCHAR2(120),
    REGION3                        VARCHAR2(120),
    TOWNORCITY                     VARCHAR2(60),
    EFFECTIVESTARTDATE             DATE,
    EFFECTIVEENDDATE               DATE,
    CREATIONDATE                   TIMESTAMP(6) WITH TIME ZONE,
    LASTUPDATEDATE                 TIMESTAMP(6) WITH TIME ZONE,
    LONGITUDE                      NUMBER,
    LATITUDE                       NUMBER,
    VALIDATIONSTATUSCODE           VARCHAR2(120),
    PROVIDER                       VARCHAR2(150),
    CONSTRAINT REST_LOCATIONS_PK PRIMARY KEY (APEX$RESOURCEKEY)
);
