CREATE OR REPLACE PACKAGE BODY pkg_rec_move AS

    -- =========================================================================
    -- Private: REFRESH_APPLICANT
    -- =========================================================================
    -- GET a single job application from Fusion REST and MERGE it into
    -- JOB_APPLICANTS_R so the local table reflects the move immediately.
    -- =========================================================================
    PROCEDURE refresh_applicant (p_job_application_id IN NUMBER)
    IS
        l_url      VARCHAR2(2000);
        l_response CLOB;
        l_status   NUMBER;
    BEGIN
        l_url := pkg_bicc_common.gc_fa_base_url
            || '/hcmRestApi/resources/11.13.18.05/recruitingJobApplications/'
            || p_job_application_id;

        -- Clear any custom headers left from the POST (e.g. ADF action Content-Type)
        apex_web_service.g_request_headers.DELETE;

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_username             => apex_app_setting.get_value('REC_MOVE_USERNAME'),
            p_password             => apex_app_setting.get_value('REC_MOVE_PASSWORD')
        );

        l_status := apex_web_service.g_status_code;

        IF l_status NOT BETWEEN 200 AND 299 THEN
            -- Log but don't raise — the move itself already succeeded
            INSERT INTO bicc_load_log (
                load_type, step, rows_processed, status, error_message
            ) VALUES (
                'REC_MOVE', 'REFRESH_' || p_job_application_id, 0, 'WARN',
                'Refresh GET failed (HTTP ' || l_status || '): '
                    || DBMS_LOB.SUBSTR(l_response, 2000, 1)
            );
            COMMIT;
            RETURN;
        END IF;

        MERGE INTO job_applicants_r tgt
        USING (
            SELECT *
              FROM json_table(l_response, '$'
                COLUMNS (
                    jobapplicationid           NUMBER          PATH '$.JobApplicationId',
                    candidatepersonid          NUMBER          PATH '$.CandidatePersonId',
                    candidatename              VARCHAR2(240)   PATH '$.CandidateName',
                    requisitionid              NUMBER          PATH '$.RequisitionId',
                    phaseid                    NUMBER          PATH '$.PhaseId',
                    phasename                  VARCHAR2(240)   PATH '$.PhaseName',
                    stateid                    NUMBER          PATH '$.StateId',
                    statename                  VARCHAR2(240)   PATH '$.StateName',
                    appliedtootherjobs         VARCHAR2(255)   PATH '$.AppliedToOtherJobs',
                    confirmedflag              VARCHAR2(5)     PATH '$.ConfirmedFlag',
                    disqualifiedflag           VARCHAR2(5)     PATH '$.DisqualifiedFlag',
                    jobapplicationdate         TIMESTAMP       PATH '$.JobApplicationDate',
                    creationdate               TIMESTAMP       PATH '$.CreationDate',
                    createdby                  VARCHAR2(64)    PATH '$.CreatedBy',
                    lastupdatedate             TIMESTAMP       PATH '$.LastUpdateDate',
                    lastupdatedby              VARCHAR2(64)    PATH '$.LastUpdatedBy',
                    profileid                  NUMBER          PATH '$.ProfileId',
                    applyflowversionid         NUMBER          PATH '$.ApplyFlowVersionId',
                    confirmedbypersonid        NUMBER          PATH '$.ConfirmedByPersonId',
                    esigndescriptionversionid  NUMBER          PATH '$.EsignDescriptionVersionId',
                    internalflag               VARCHAR2(5)     PATH '$.InternalFlag',
                    legaldescriptionversionid  NUMBER          PATH '$.LegalDescriptionVersionId',
                    processid                  NUMBER          PATH '$.ProcessId',
                    lastmodifieddate           TIMESTAMP       PATH '$.LastModifiedDate',
                    confirmeddate              TIMESTAMP       PATH '$.ConfirmedDate',
                    languagecode               VARCHAR2(4)     PATH '$.LanguageCode',
                    publicstateid              NUMBER          PATH '$.PublicStateId',
                    publicstatename            VARCHAR2(240)   PATH '$.PublicStateName',
                    sitenumber                 VARCHAR2(240)   PATH '$.SiteNumber',
                    hiringmanagerid            NUMBER          PATH '$.HiringManagerId',
                    requisitionidrest          NUMBER          PATH '$.RequisitionIdRest',
                    requisitionusagecode       VARCHAR2(30)    PATH '$.RequisitionUsageCode',
                    recruiterid                NUMBER          PATH '$.RecruiterId',
                    requisitionnumber          VARCHAR2(240)   PATH '$.RequisitionNumber'
                )
              )
        ) src ON (tgt."JOBAPPLICATIONID" = src.jobapplicationid)
        WHEN MATCHED THEN UPDATE SET
            tgt."CANDIDATEPERSONID"         = src.candidatepersonid,
            tgt."CANDIDATENAME"             = src.candidatename,
            tgt."REQUISITIONID"             = src.requisitionid,
            tgt."PHASEID"                   = src.phaseid,
            tgt."PHASENAME"                 = src.phasename,
            tgt."STATEID"                   = src.stateid,
            tgt."STATENAME"                 = src.statename,
            tgt."APPLIEDTOOTHERJOBS"        = src.appliedtootherjobs,
            tgt."CONFIRMEDFLAG"             = src.confirmedflag,
            tgt."DISQUALIFIEDFLAG"          = src.disqualifiedflag,
            tgt."JOBAPPLICATIONDATE"        = src.jobapplicationdate,
            tgt."CREATIONDATE"              = src.creationdate,
            tgt."CREATEDBY"                 = src.createdby,
            tgt."LASTUPDATEDATE"            = src.lastupdatedate,
            tgt."LASTUPDATEDBY"             = src.lastupdatedby,
            tgt."PROFILEID"                 = src.profileid,
            tgt."APPLYFLOWVERSIONID"        = src.applyflowversionid,
            tgt."CONFIRMEDBYPERSONID"       = src.confirmedbypersonid,
            tgt."ESIGNDESCRIPTIONVERSIONID" = src.esigndescriptionversionid,
            tgt."INTERNALFLAG"              = src.internalflag,
            tgt."LEGALDESCRIPTIONVERSIONID" = src.legaldescriptionversionid,
            tgt."PROCESSID"                 = src.processid,
            tgt."LASTMODIFIEDDATE"          = src.lastmodifieddate,
            tgt."CONFIRMEDDATE"             = src.confirmeddate,
            tgt."LANGUAGECODE"              = src.languagecode,
            tgt."PUBLICSTATEID"             = src.publicstateid,
            tgt."PUBLICSTATENAME"           = src.publicstatename,
            tgt."SITENUMBER"                = src.sitenumber,
            tgt."HIRINGMANAGERID"           = src.hiringmanagerid,
            tgt."REQUISITIONIDREST"         = src.requisitionidrest,
            tgt."REQUISITIONUSAGECODE"      = src.requisitionusagecode,
            tgt."RECRUITERID"               = src.recruiterid,
            tgt."REQUISITIONNUMBER"         = src.requisitionnumber,
            tgt."APEX$ROW_SYNC_TIMESTAMP"   = SYSTIMESTAMP
        WHEN NOT MATCHED THEN INSERT (
            "APEX$RESOURCEKEY",
            "JOBAPPLICATIONID",
            "CANDIDATEPERSONID",
            "CANDIDATENAME",
            "REQUISITIONID",
            "PHASEID",
            "PHASENAME",
            "STATEID",
            "STATENAME",
            "APPLIEDTOOTHERJOBS",
            "CONFIRMEDFLAG",
            "DISQUALIFIEDFLAG",
            "JOBAPPLICATIONDATE",
            "CREATIONDATE",
            "CREATEDBY",
            "LASTUPDATEDATE",
            "LASTUPDATEDBY",
            "PROFILEID",
            "APPLYFLOWVERSIONID",
            "CONFIRMEDBYPERSONID",
            "ESIGNDESCRIPTIONVERSIONID",
            "INTERNALFLAG",
            "LEGALDESCRIPTIONVERSIONID",
            "PROCESSID",
            "LASTMODIFIEDDATE",
            "CONFIRMEDDATE",
            "LANGUAGECODE",
            "PUBLICSTATEID",
            "PUBLICSTATENAME",
            "SITENUMBER",
            "HIRINGMANAGERID",
            "REQUISITIONIDREST",
            "REQUISITIONUSAGECODE",
            "RECRUITERID",
            "REQUISITIONNUMBER",
            "APEX$SYNC_STEP_STATIC_ID",
            "APEX$ROW_SYNC_TIMESTAMP"
        ) VALUES (
            TO_CHAR(src.jobapplicationid),
            src.jobapplicationid,
            src.candidatepersonid,
            src.candidatename,
            src.requisitionid,
            src.phaseid,
            src.phasename,
            src.stateid,
            src.statename,
            src.appliedtootherjobs,
            src.confirmedflag,
            src.disqualifiedflag,
            src.jobapplicationdate,
            src.creationdate,
            src.createdby,
            src.lastupdatedate,
            src.lastupdatedby,
            src.profileid,
            src.applyflowversionid,
            src.confirmedbypersonid,
            src.esigndescriptionversionid,
            src.internalflag,
            src.legaldescriptionversionid,
            src.processid,
            src.lastmodifieddate,
            src.confirmeddate,
            src.languagecode,
            src.publicstateid,
            src.publicstatename,
            src.sitenumber,
            src.hiringmanagerid,
            src.requisitionidrest,
            src.requisitionusagecode,
            src.recruiterid,
            src.requisitionnumber,
            'Synchronization Step 1',
            SYSTIMESTAMP
        );

        COMMIT;

    END refresh_applicant;

    -- =========================================================================
    -- MOVE_APPLICATION
    -- =========================================================================
    -- POST /hcmRestApi/resources/11.13.18.05/recruitingJobApplications
    --      /{JobApplicationId}/action/move
    --
    -- Payload: {"phaseId": <n>, "stateId": <n>, "comments": "..."}
    -- On success, immediately GETs the updated record and merges it into
    -- JOB_APPLICANTS_R so the local table reflects the change.
    -- =========================================================================

    FUNCTION move_application (
        p_job_application_id  IN NUMBER,
        p_phase_id            IN NUMBER,
        p_state_id            IN NUMBER,
        p_comments            IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB
    IS
        l_url      VARCHAR2(2000);
        l_payload  CLOB;
        l_response CLOB;
        l_status   NUMBER;
    BEGIN
        -- Build endpoint URL
        l_url := pkg_bicc_common.gc_fa_base_url
            || '/hcmRestApi/resources/11.13.18.05/recruitingJobApplications/'
            || p_job_application_id
            || '/action/move';

        -- Build JSON payload using json_object for safe escaping
        SELECT json_object(
                   'phaseId'  VALUE p_phase_id,
                   'stateId'  VALUE p_state_id,
                   'comments' VALUE p_comments ABSENT ON NULL
                   RETURNING CLOB
               )
          INTO l_payload
          FROM dual;

        -- Set required Content-Type for Fusion action endpoints
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/vnd.oracle.adf.action+json';

        -- Call the REST endpoint using Basic Auth
        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'POST',
            p_body                 => l_payload,
            p_username             => apex_app_setting.get_value('REC_MOVE_USERNAME'),
            p_password             => apex_app_setting.get_value('REC_MOVE_PASSWORD')
        );

        l_status := apex_web_service.g_status_code;

        -- Log the attempt
        INSERT INTO bicc_load_log (
            load_type, step, rows_processed, status, error_message
        ) VALUES (
            'REC_MOVE',
            'APP_' || p_job_application_id,
            1,
            CASE WHEN l_status BETWEEN 200 AND 299 THEN 'SUCCESS' ELSE 'ERROR' END,
            CASE WHEN l_status NOT BETWEEN 200 AND 299
                 THEN 'HTTP ' || l_status || ': ' || DBMS_LOB.SUBSTR(l_response, 2000, 1)
            END
        );
        COMMIT;

        -- Raise if not 2xx
        IF l_status NOT BETWEEN 200 AND 299 THEN
            raise_application_error(
                -20100,
                'Move failed (HTTP ' || l_status || '): '
                    || DBMS_LOB.SUBSTR(l_response, 500, 1)
            );
        END IF;

        -- Immediately refresh the local JOB_APPLICANTS_R row
        refresh_applicant(p_job_application_id);

        RETURN l_response;

    END move_application;

END pkg_rec_move;
/
