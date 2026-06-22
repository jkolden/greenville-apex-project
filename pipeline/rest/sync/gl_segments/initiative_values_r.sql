-- =============================================================================
-- Initiative GL Segment Values
-- APEX REST Sync table: GL valueSets/Initiative/child/values
-- Module static ID: rest_sync_initiative_values
-- Sync type: INCREMENTAL (LastUpdateDate filter)
-- Created by APEX REST Data Source sync; APEX$ columns managed by APEX
-- =============================================================================
CREATE TABLE INITIATIVE_VALUES_R (
    APEX$RESOURCEKEY            VARCHAR2(32767)  NOT NULL,
    VALUEID                     NUMBER,
    INDEPENDENTVALUE            VARCHAR2(150),
    INDEPENDENTVALUENUMBER      NUMBER,
    INDEPENDENTVALUEDATE        DATE,
    INDEPENDENTVALUETIMESTAMP   TIMESTAMP(6) WITH TIME ZONE,
    VALUE                       VARCHAR2(150),
    VALUENUMBER                 NUMBER,
    VALUEDATE                   DATE,
    VALUETIMESTAMP              TIMESTAMP(6) WITH TIME ZONE,
    TRANSLATEDVALUE             VARCHAR2(150),
    DESCRIPTION                 VARCHAR2(240),
    ENABLEDFLAG                 VARCHAR2(1),
    STARTDATEACTIVE             DATE,
    ENDDATEACTIVE               DATE,
    SORTORDER                   NUMBER,
    CREATIONDATE                TIMESTAMP(6) WITH TIME ZONE,
    CREATEDBY                   VARCHAR2(64),
    LASTUPDATEDATE              TIMESTAMP(6) WITH TIME ZONE,
    LASTUPDATEDBY               VARCHAR2(64),
    APEX$SYNC_STEP_STATIC_ID    VARCHAR2(255),
    APEX$ROW_SYNC_TIMESTAMP     TIMESTAMP(6) WITH TIME ZONE,
    CONSTRAINT INITIATIVE_VALUES_R_PK PRIMARY KEY (APEX$RESOURCEKEY)
);
