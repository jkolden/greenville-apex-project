-- =============================================================================
-- RECRUITING_CANDIDATES_R
-- APEX REST Data Source sync table — module static ID: rest_sync_recruitingcandidates
-- Module code: HCM  |  Sync type: INCREMENTAL
-- APEX$ columns (APEX$RESOURCEKEY, APEX$SYNC_STEP_STATIC_ID,
--   APEX$ROW_SYNC_TIMESTAMP) are managed by APEX REST Data Sync
-- =============================================================================
CREATE TABLE RECRUITING_CANDIDATES_R (
    CANDIDATENUMBER               VARCHAR2(32767),
    PREFERREDLANGUAGE             VARCHAR2(4),
    LASTNAME                      VARCHAR2(150),
    MIDDLENAMES                   VARCHAR2(80),
    FIRSTNAME                     VARCHAR2(150),
    TITLE                         VARCHAR2(30),
    SUFFIX                        VARCHAR2(80),
    PRENAMEADJUNCT                VARCHAR2(150),
    KNOWNAS                       VARCHAR2(80),
    PREVIOUSLASTNAME              VARCHAR2(150),
    HONORS                        VARCHAR2(80),
    MILITARYRANK                  VARCHAR2(80),
    FULLNAME                      VARCHAR2(32767),
    DISPLAYNAME                   VARCHAR2(32767),
    LISTNAME                      VARCHAR2(32767),
    EMAIL                         VARCHAR2(240),
    CAMPAIGNOPTIN                 VARCHAR2(1),
    SOURCEMEDIUM                  VARCHAR2(32),
    SOURCENAME                    VARCHAR2(2000),
    CANDIDATETYPE                 VARCHAR2(32767),
    PERSONID                      NUMBER,
    CREATEDBY                     VARCHAR2(32767),
    CREATIONDATE                  TIMESTAMP(6) WITH TIME ZONE,
    LASTUPDATEDBY                 VARCHAR2(32767),
    LASTUPDATEDATE                TIMESTAMP(6) WITH TIME ZONE,
    CANDLASTMODIFIEDDATE          TIMESTAMP(6) WITH TIME ZONE,
    PREFERREDTIMEZONE             VARCHAR2(255),
    CONSTRAINT RECRUITING_CANDIDATES_R_PK PRIMARY KEY (APEX$RESOURCEKEY)
);
