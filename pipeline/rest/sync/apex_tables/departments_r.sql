-- =============================================================================
-- DEPARTMENTS_R
-- APEX REST Data Source sync table — module static ID: rest_sync_departments
-- Module code: HCM  |  Sync type: INCREMENTAL
-- APEX$ columns (APEX$RESOURCEKEY, APEX$SYNC_STEP_STATIC_ID,
--   APEX$ROW_SYNC_TIMESTAMP) are managed by APEX REST Data Sync
-- =============================================================================
CREATE TABLE DEPARTMENTS_R (
    ORGANIZATIONID                NUMBER,
    NAME                          VARCHAR2(240),
    TITLE                         VARCHAR2(240),
    EFFECTIVESTARTDATE            DATE,
    EFFECTIVEENDDATE              DATE,
    ACTIONREASONID                NUMBER,
    ACTIONREASONCODE              VARCHAR2(30),
    ACTIONREASON                  VARCHAR2(80),
    ACTIVESTATUS                  VARCHAR2(30),
    ACTIVESTATUSMEANING           VARCHAR2(80),
    SETID                         NUMBER,
    SETCODE                       VARCHAR2(30),
    SETNAME                       VARCHAR2(80),
    INTERNALADDRESSLINE           VARCHAR2(80),
    LOCATIONID                    NUMBER,
    LOCATIONCODE                  VARCHAR2(150),
    LOCATIONNAME                  VARCHAR2(60),
    LOCATIONSETCODE               VARCHAR2(30),
    LOCATIONSETNAME               VARCHAR2(80),
    CREATEDBY                     VARCHAR2(64),
    CREATIONDATE                  TIMESTAMP(6) WITH TIME ZONE,
    LASTUPDATEDATE                TIMESTAMP(6) WITH TIME ZONE,
    LASTUPDATEDBY                 VARCHAR2(64),
    ACTIONID                      NUMBER,
    CONSTRAINT DEPARTMENTS_R_PK PRIMARY KEY (APEX$RESOURCEKEY)
);
