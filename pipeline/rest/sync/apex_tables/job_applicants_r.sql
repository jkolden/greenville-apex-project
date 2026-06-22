-- =============================================================================
-- JOB_APPLICANTS_R
-- APEX REST Data Source sync table — module static ID: rest_sync_job_applications
-- Module code: HCM  |  Sync type: INCREMENTAL
-- APEX$ columns (APEX$RESOURCEKEY, APEX$SYNC_STEP_STATIC_ID,
--   APEX$ROW_SYNC_TIMESTAMP) are managed by APEX REST Data Sync
-- =============================================================================
CREATE TABLE JOB_APPLICANTS_R (
    JOBAPPLICATIONID              NUMBER,
    CANDIDATEPERSONID             NUMBER,
    CANDIDATENAME                 VARCHAR2(240),
    REQUISITIONID                 NUMBER,
    PHASEID                       NUMBER,
    PHASENAME                     VARCHAR2(240),
    STATEID                       NUMBER,
    STATENAME                     VARCHAR2(240),
    APPLIEDTOOTHERJOBS            VARCHAR2(255),
    CONFIRMEDFLAG                 VARCHAR2(5),
    DISQUALIFIEDFLAG              VARCHAR2(5),
    JOBAPPLICATIONDATE            TIMESTAMP(6) WITH TIME ZONE,
    CREATIONDATE                  TIMESTAMP(6) WITH TIME ZONE,
    CREATEDBY                     VARCHAR2(64),
    LASTUPDATEDATE                TIMESTAMP(6) WITH TIME ZONE,
    LASTUPDATEDBY                 VARCHAR2(64),
    PROFILEID                     NUMBER,
    APPLYFLOWVERSIONID            NUMBER,
    CONFIRMEDBYPERSONID           NUMBER,
    ESIGNDESCRIPTIONVERSIONID     NUMBER,
    INTERNALFLAG                  VARCHAR2(5),
    LEGALDESCRIPTIONVERSIONID     NUMBER,
    PROCESSID                     NUMBER,
    LASTMODIFIEDDATE              TIMESTAMP(6) WITH TIME ZONE,
    CONFIRMEDDATE                 TIMESTAMP(6) WITH TIME ZONE,
    LANGUAGECODE                  VARCHAR2(4),
    PUBLICSTATEID                 NUMBER,
    PUBLICSTATENAME               VARCHAR2(240),
    SITENUMBER                    VARCHAR2(240),
    HIRINGMANAGERID               NUMBER,
    REQUISITIONIDREST             NUMBER,
    REQUISITIONUSAGECODE          VARCHAR2(30),
    RECRUITERID                   NUMBER,
    REQUISITIONNUMBER             VARCHAR2(240),
    CONSTRAINT REST_JOB_APPLICANTS_PK PRIMARY KEY (APEX$RESOURCEKEY)
);
