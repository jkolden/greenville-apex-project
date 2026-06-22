create or replace package body pkg_bicc_qstnr_question as

    -- =========================================================================
    -- LOAD (private)
    -- =========================================================================
    -- Flow: extract_and_stage_csv -> COPY_DATA -> INSERT...SELECT
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
        delete from s_qstnr_question_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/qstnr_question_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_qstnr_question_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/qstnr_question_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_QSTNR_QUESTION_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_qstnr_question_bc (
            job_id,
            questionnaire_id,
            questionnaire_code,
            qstnr_version_num,
            questionnaire_status,
            questionnaire_name,
            questionnaire_created_by,
            questionnaire_creation_date_raw,
            questionnaire_creation_date_ts,
            qstnr_section_id,
            section_seq_num,
            section_question_order,
            section_name,
            question_id,
            question_code,
            question_type,
            classification_code,
            qstn_version_num,
            question_status,
            question_text,
            qstnr_question_id,
            question_seq_num,
            mandatory_flag,
            adhoc_question_flag,
            qstnr_participant_id,
            subject_id,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,

            -- Questionnaire definition
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIREBPEOQUESTIONNAIREID),
            l.QUESTIONNAIREBPEOQUESTIONNAIRECODE,
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIREBPEOQSTNRVERSIONNUM),
            l.QUESTIONNAIREBPEOSTATUS,
            l.QUESTIONNAIRETLPEONAME,
            l.QUESTIONNAIRETRANSLATIONPEOCREATEDBY,
            l.QUESTIONNAIRETRANSLATIONPEOCREATIONDATE,
            pkg_bicc_common.safe_to_timestamp(l.QUESTIONNAIRETRANSLATIONPEOCREATIONDATE),

            -- Section
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIRESECTIONBPEOQSTNRSECTIONID),
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIRESECTIONBPEOSECTIONSEQNUM),
            l.QUESTIONNAIRESECTIONBPEOQUESTIONORDER,
            l.QUESTIONSECTIONTRANSLATIONPEONAME,

            -- Question definition
            pkg_bicc_common.safe_to_number(l.QUESTIONBPEOQUESTIONID),
            l.QUESTIONBPEOQUESTIONCODE,
            l.QUESTIONBPEOQUESTIONTYPE,
            l.QUESTIONBPEOCLASSIFICATIONCODE,
            pkg_bicc_common.safe_to_number(l.QUESTIONBPEOQSTNVERSIONNUM),
            l.QUESTIONBPEOSTATUS,
            l.QUESTIONTRANSLATIONPEOQUESTIONTEXT,

            -- Questionnaire-question link
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIREQUESTIONPEOQSTNRQUESTIONID),
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIREQUESTIONPEOSEQNUM),
            l.QUESTIONNAIREQUESTIONPEOMANDATORY,
            l.QUESTIONNAIREQUESTIONPEOADHOCQSTN,

            -- Participant
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIREPARTICIPANTPEOQSTNRPARTICIPANTID),
            pkg_bicc_common.safe_to_number(l.QUESTIONNAIREPARTICIPANTPEOSUBJECTID),

            -- Run metadata
            l_run_id,
            systimestamp

        from l_qstnr_question_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'QSTNR_QUESTION', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'QSTNR_QUESTION', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct qstnr_participant_id, qstnr_question_id
            from s_qstnr_question_bc
            where job_id = p_job_id
              and qstnr_participant_id is not null
              and qstnr_question_id is not null
        ) s
        where not exists (
            select 1 from qstnr_question_bc f
            where f.qstnr_participant_id = s.qstnr_participant_id
              and f.qstnr_question_id    = s.qstnr_question_id
        );

        select count(*) into l_matched
        from (
            select distinct qstnr_participant_id, qstnr_question_id
            from s_qstnr_question_bc
            where job_id = p_job_id
              and qstnr_participant_id is not null
              and qstnr_question_id is not null
        ) s
        where exists (
            select 1 from qstnr_question_bc f
            where f.qstnr_participant_id = s.qstnr_participant_id
              and f.qstnr_question_id    = s.qstnr_question_id
        );

        select count(*) into p_unchanged_count
        from (
            select
                qstnr_participant_id,
                qstnr_question_id,
                questionnaire_id,
                questionnaire_code,
                questionnaire_name,
                questionnaire_status,
                section_seq_num,
                section_name,
                question_code,
                question_type,
                question_text,
                question_seq_num,
                mandatory_flag,
                subject_id
            from (
                select s.*,
                       row_number() over (
                         partition by qstnr_participant_id, qstnr_question_id
                         order by last_extract_run_ts desc nulls last, rowid
                       ) rn
                from s_qstnr_question_bc s
                where job_id = p_job_id
                  and qstnr_participant_id is not null
                  and qstnr_question_id is not null
            )
            where rn = 1
            intersect
            select
                qstnr_participant_id,
                qstnr_question_id,
                questionnaire_id,
                questionnaire_code,
                questionnaire_name,
                questionnaire_status,
                section_seq_num,
                section_name,
                question_code,
                question_type,
                question_text,
                question_seq_num,
                mandatory_flag,
                subject_id
            from qstnr_question_bc
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
            'QSTNR_QUESTION', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(*) into l_rows_loaded
        from (
            select distinct qstnr_participant_id, qstnr_question_id
            from s_qstnr_question_bc
            where job_id = l_job_id
              and qstnr_participant_id is not null
              and qstnr_question_id is not null
        );

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
        merge into qstnr_question_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by qstnr_participant_id, qstnr_question_id
                        order by last_extract_run_ts desc nulls last, rowid
                    ) rn
                from s_qstnr_question_bc s
                where job_id = p_job_id
                  and qstnr_participant_id is not null
                  and qstnr_question_id is not null
            )
            where rn = 1
        ) s
        on (f.qstnr_participant_id = s.qstnr_participant_id
            and f.qstnr_question_id = s.qstnr_question_id)
        when matched then update set
            f.questionnaire_id              = s.questionnaire_id,
            f.questionnaire_code            = s.questionnaire_code,
            f.qstnr_version_num             = s.qstnr_version_num,
            f.questionnaire_status          = s.questionnaire_status,
            f.questionnaire_name            = s.questionnaire_name,
            f.questionnaire_created_by      = s.questionnaire_created_by,
            f.questionnaire_creation_date_ts = s.questionnaire_creation_date_ts,
            f.qstnr_section_id             = s.qstnr_section_id,
            f.section_seq_num               = s.section_seq_num,
            f.section_question_order        = s.section_question_order,
            f.section_name                  = s.section_name,
            f.question_id                   = s.question_id,
            f.question_code                 = s.question_code,
            f.question_type                 = s.question_type,
            f.classification_code           = s.classification_code,
            f.qstn_version_num              = s.qstn_version_num,
            f.question_status               = s.question_status,
            f.question_text                 = s.question_text,
            f.question_seq_num              = s.question_seq_num,
            f.mandatory_flag                = s.mandatory_flag,
            f.adhoc_question_flag           = s.adhoc_question_flag,
            f.subject_id                    = s.subject_id,
            f.last_extract_run_id           = s.last_extract_run_id,
            f.last_extract_run_ts           = s.last_extract_run_ts
        when not matched then insert (
            questionnaire_id,
            questionnaire_code,
            qstnr_version_num,
            questionnaire_status,
            questionnaire_name,
            questionnaire_created_by,
            questionnaire_creation_date_ts,
            qstnr_section_id,
            section_seq_num,
            section_question_order,
            section_name,
            question_id,
            question_code,
            question_type,
            classification_code,
            qstn_version_num,
            question_status,
            question_text,
            qstnr_question_id,
            question_seq_num,
            mandatory_flag,
            adhoc_question_flag,
            qstnr_participant_id,
            subject_id,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.questionnaire_id,
            s.questionnaire_code,
            s.qstnr_version_num,
            s.questionnaire_status,
            s.questionnaire_name,
            s.questionnaire_created_by,
            s.questionnaire_creation_date_ts,
            s.qstnr_section_id,
            s.section_seq_num,
            s.section_question_order,
            s.section_name,
            s.question_id,
            s.question_code,
            s.question_type,
            s.classification_code,
            s.qstn_version_num,
            s.question_status,
            s.question_text,
            s.qstnr_question_id,
            s.question_seq_num,
            s.mandatory_flag,
            s.adhoc_question_flag,
            s.qstnr_participant_id,
            s.subject_id,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_qstnr_question_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'QSTNR_QUESTION', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'QSTNR_QUESTION', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_qstnr_question;
/
