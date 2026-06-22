-- =============================================================================
-- HCM_POSITION_R
-- APEX REST Data Source sync table — module static ID: rest_sync_positions
-- Module code: HCM  |  Sync type: INCREMENTAL
-- APEX$ columns (APEX$RESOURCEKEY, APEX$SYNC_STEP_STATIC_ID,
--   APEX$ROW_SYNC_TIMESTAMP) are managed by APEX REST Data Sync
-- =============================================================================
CREATE TABLE HCM_POSITION_R (
    POSITIONID                    NUMBER,
    EFFECTIVESTARTDATE            DATE,
    EFFECTIVEENDDATE              DATE,
    BUSINESSUNITID                NUMBER,
    POSITIONCODE                  VARCHAR2(30),
    NAME                          VARCHAR2(240),
    DEPARTMENTID                  NUMBER,
    JOBID                         NUMBER,
    LOCATIONID                    NUMBER,
    ENTRYGRADEID                  NUMBER,
    ENTRYSTEPID                   NUMBER,
    ACTIVESTATUS                  VARCHAR2(30),
    REGULARTEMPORARY              VARCHAR2(30),
    FTE                           NUMBER,
    CALCULATEFTE                  VARCHAR2(1),
    HIRINGSTATUS                  VARCHAR2(30),
    FULLPARTTIME                  VARCHAR2(30),
    POSITIONTYPE                  VARCHAR2(30),
    HEADCOUNT                     NUMBER,
    OVERLAPALLOWEDFLAG            VARCHAR2(5),
    SEASONALFLAG                  VARCHAR2(5),
    SEASONALSTARTDATE             DATE,
    SEASONALENDDATE               DATE,
    PROBATIONPERIOD               NUMBER,
    SECURITYCLEARANCE             VARCHAR2(30),
    GRADELADDERID                 NUMBER,
    CREATIONDATE                  TIMESTAMP(6) WITH TIME ZONE,
    LASTUPDATEDATE                TIMESTAMP(6) WITH TIME ZONE,
    BUDGETAMOUNT                  NUMBER,
    BUDGETAMOUNTCURRENCY          VARCHAR2(20),
    BUDGETEDPOSITIONFLAG          VARCHAR2(5),
    COSTCENTER                    VARCHAR2(30),
    DELEGATEPOSITIONID            NUMBER,
    FUNDEDBYEXISTINGPOSITIONFLAG  VARCHAR2(5),
    CONSTRAINT REST_HCM_POSITION_PK PRIMARY KEY (APEX$RESOURCEKEY)
);
