create or replace package body pkg_bicc_qstnr_response as

    -- =========================================================================
    -- LOAD (private)
    -- =========================================================================
    -- Flow: extract_and_stage_csv -> COPY_DATA -> INSERT...SELECT
    -- NOTE: QUESTIONNAIREPARTCIPANT (missing 'I') is Oracle's actual spelling.
    -- =========================================================================

    procedure load(
        p_file_name  in varchar2,
        p_job_id     in number
    ) is
        l_error_msg     varchar2(4000);
        l_rows_inserted number := 0;
        l_run_id        varchar2(64) := sys_guid();
        l_staging_uri   varchar2(500);
    begin
        delete from s_qstnr_response_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/qstnr_response_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_qstnr_response_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/qstnr_response_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_QSTNR_RESPONSE_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_qstnr_response_bc (
            job_id,
            qstnr_response_id,
            qstnr_participant_id,
            response_status,
            attempt_num,
            submitted_date_raw,
            submitted_date_ts,
            qstnr_question_id,
            qstn_response_id,
            answer_clob,
            answer_id,
            answer_type,
            subject_id,
            last_update_date_raw,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,

            -- Questionnaire response header
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIRERESPONSEPEOQSTNRRESPONSEID),
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIRERESPONSEPEOQSTNRPARTICIPANTID),
            l.QUESTIONNAIRERESPONSEPEOSTATUS,
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIRERESPONSEPEOATTEMPTNUM),
            l.QUESTIONNAIRERESPONSEPEOSUBMITTEDDATETIME,
            pkg_bicc_common.safe_to_timestamp(l.QUESTIONNAIRERESPONSEPEOSUBMITTEDDATETIME),

            -- Question-level response
            pkg_bicc_common.safe_to_number(l.QUESTIONRESPONSEPEOQSTNRQUESTIONID),
            pkg_bicc_common.safe_to_number(l.QUESTIONRESPONSEPEOQSTNRESPONSEID),
            l.QUESTIONRESPONSEPEOANSWERCLOB,
            pkg_bicc_common.safe_to_number(l.QUESTIONRESPONSEPEOANSWERID),
            l.QUESTIONRESPONSEPEOANSWERTYPE,

            -- Participant (embedded)
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIREPARTCIPANTPEOSUBJECTID),

            -- Dates (raw + timestamp)
            l.QSTNRESPONSEPEOLASTUPDATEDATE,
            pkg_bicc_common.safe_to_timestamp(l.QSTNRESPONSEPEOLASTUPDATEDATE),

            -- Run metadata
            l_run_id,
            systimestamp

        from l_qstnr_response_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'QSTNR_RESPONSE', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'QSTNR_RESPONSE', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end load;


    -- =========================================================================
    -- PREVIEW (private)
    -- =========================================================================

    procedure preview(
        p_job_id          in  number,
        p_new_count       out number,
        p_changed_count   out number,
        p_unchanged_count out number
    ) is
        l_matched number;
    begin
        select count(*) into p_new_count
        from (
            select distinct qstn_response_id
            from s_qstnr_response_bc
            where job_id = p_job_id
              and qstn_response_id is not null
        ) s
        where not exists (
            select 1 from qstnr_response_bc f
            where f.qstn_response_id = s.qstn_response_id
        );

        select count(*) into l_matched
        from (
            select distinct qstn_response_id
            from s_qstnr_response_bc
            where job_id = p_job_id
              and qstn_response_id is not null
        ) s
        where exists (
            select 1 from qstnr_response_bc f
            where f.qstn_response_id = s.qstn_response_id
        );

        select count(*) into p_unchanged_count
        from (
            select
                qstn_response_id,
                qstnr_response_id,
                qstnr_participant_id,
                response_status,
                attempt_num,
                submitted_date_ts,
                qstnr_question_id,
                answer_clob,
                answer_id,
                answer_type,
                subject_id,
                last_update_date_ts
            from (
                select s.*,
                       row_number() over (
                         partition by qstn_response_id
                         order by last_update_date_ts desc nulls last, rowid
                       ) rn
                from s_qstnr_response_bc s
                where job_id = p_job_id
                  and qstn_response_id is not null
            )
            where rn = 1
            intersect
            select
                qstn_response_id,
                qstnr_response_id,
                qstnr_participant_id,
                response_status,
                attempt_num,
                submitted_date_ts,
                qstnr_question_id,
                answer_clob,
                answer_id,
                answer_type,
                subject_id,
                last_update_date_ts
            from qstnr_response_bc
        );

        p_changed_count := l_matched - p_unchanged_count;
    end preview;


    -- =========================================================================
    -- LOAD AND PREVIEW (public)
    -- =========================================================================

    function load_and_preview(p_file_name in varchar2) return number is
        l_job_id      number;
        l_rows_loaded number;
        l_new         number;
        l_changed     number;
        l_unchanged   number;
        l_error_msg   varchar2(4000);
    begin
        insert into bicc_load_job (
            load_type, file_name, status, loaded_by, loaded_ts
        ) values (
            'QSTNR_RESPONSE', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct qstn_response_id) into l_rows_loaded
        from s_qstnr_response_bc
        where job_id = l_job_id
          and qstn_response_id is not null;

        preview(
            p_job_id          => l_job_id,
            p_new_count       => l_new,
            p_changed_count   => l_changed,
            p_unchanged_count => l_unchanged
        );

        update bicc_load_job
        set rows_loaded     = l_rows_loaded,
            new_count       = l_new,
            changed_count   = l_changed,
            unchanged_count = l_unchanged,
            status          = 'STAGED'
        where job_id = l_job_id;

        commit;
        return l_job_id;

    exception
        when others then
            l_error_msg := sqlerrm;
            update bicc_load_job
            set status        = 'ERROR',
                error_message = l_error_msg
            where job_id = l_job_id;
            commit;
            raise;
    end load_and_preview;


    -- =========================================================================
    -- MERGE (public)
    -- =========================================================================

    procedure merge(p_job_id in number) is
        l_rowcount  number := 0;
        l_error_msg varchar2(4000);
    begin
        merge into qstnr_response_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by qstn_response_id
                        order by last_update_date_ts desc nulls last, rowid
                    ) rn
                from s_qstnr_response_bc s
                where job_id = p_job_id
                  and qstn_response_id is not null
            )
            where rn = 1
        ) s
        on (f.qstn_response_id = s.qstn_response_id)
        when matched then update set
            f.qstnr_response_id      = s.qstnr_response_id,
            f.qstnr_participant_id   = s.qstnr_participant_id,
            f.response_status         = s.response_status,
            f.attempt_num             = s.attempt_num,
            f.submitted_date_ts       = s.submitted_date_ts,
            f.qstnr_question_id      = s.qstnr_question_id,
            f.answer_clob             = s.answer_clob,
            f.answer_id               = s.answer_id,
            f.answer_type             = s.answer_type,
            f.subject_id              = s.subject_id,
            f.last_update_date_ts     = s.last_update_date_ts,
            f.last_extract_run_id     = s.last_extract_run_id,
            f.last_extract_run_ts     = s.last_extract_run_ts
        when not matched then insert (
            qstnr_response_id,
            qstnr_participant_id,
            response_status,
            attempt_num,
            submitted_date_ts,
            qstnr_question_id,
            qstn_response_id,
            answer_clob,
            answer_id,
            answer_type,
            subject_id,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.qstnr_response_id,
            s.qstnr_participant_id,
            s.response_status,
            s.attempt_num,
            s.submitted_date_ts,
            s.qstnr_question_id,
            s.qstn_response_id,
            s.answer_clob,
            s.answer_id,
            s.answer_type,
            s.subject_id,
            s.last_update_date_ts,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_qstnr_response_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'QSTNR_RESPONSE', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'QSTNR_RESPONSE', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_qstnr_response;
/
