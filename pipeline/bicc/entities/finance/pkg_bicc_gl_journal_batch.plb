create or replace package body pkg_bicc_gl_journal_batch as

    -- =========================================================================
    -- LOAD (private)
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
        delete from stg_fbx_gl_journal_batch where job_id = p_job_id;

        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'gl_journal_batch_unzipped.csv'
        );

        execute immediate 'TRUNCATE TABLE L_GL_JOURNAL_BATCH_BC';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'gl_journal_batch_unzipped.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_GL_JOURNAL_BATCH_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object('type' value 'csv', 'skipheaders' value '1')
        );

        -- INSERT SELECT: cherry-pick and transform columns
        insert into stg_fbx_gl_journal_batch (
            job_id,
            journalbatchjebatchid,
            journalbatchaccountedperiodtype,
            journalbatchactualflag,
            journalbatchapprovalstatuscode,
            journalbatchapproveremployeeid,
            journalbatchaveragejournalflag,
            journalbatchchartofaccountsid,
            journalbatchcreationdate_raw,
            journalbatchcreationdate_ts,
            journalbatchdatecreated_raw,
            journalbatchdatecreated_ts,
            journalbatchdefaulteffectivedate_raw,
            journalbatchdefaulteffectivedate_ts,
            journalbatchdefaultperiodname,
            journalbatchdescription,
            journalbatchfundsstatuscode,
            journalbatchgroupid,
            journalbatchlastupdatedate_raw,
            journalbatchlastupdatedate_ts,
            journalbatchlastupdatelogin_raw,
            journalbatchlastupdatelogin_ts,
            journalbatchlastupdatedby_raw,
            journalbatchlastupdatedby_ts,
            journalbatchname,
            journalbatchobjectversionnumber,
            journalbatchparentjebatchid,
            journalbatchperiodsetname,
            journalbatchposteddate_raw,
            journalbatchposteddate_ts,
            journalbatchpostingrunid,
            journalbatchrequestid,
            journalbatchstatus,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,
            pkg_bicc_common.safe_to_number(l.journalbatchjebatchid),
            l.journalbatchaccountedperiodtype,
            l.journalbatchactualflag,
            l.journalbatchapprovalstatuscode,
            pkg_bicc_common.safe_to_number(l.journalbatchapproveremployeeid),
            l.journalbatchaveragejournalflag,
            pkg_bicc_common.safe_to_number(l.journalbatchchartofaccountsid),
            l.journalbatchcreationdate,
            pkg_bicc_common.safe_to_timestamp(l.journalbatchcreationdate),
            l.journalbatchdatecreated,
            pkg_bicc_common.safe_to_timestamp(l.journalbatchdatecreated),
            l.journalbatchdefaulteffectivedate,
            pkg_bicc_common.safe_to_timestamp(l.journalbatchdefaulteffectivedate),
            l.journalbatchdefaultperiodname,
            l.journalbatchdescription,
            l.journalbatchfundsstatuscode,
            pkg_bicc_common.safe_to_number(l.journalbatchgroupid),
            l.journalbatchlastupdatedate,
            pkg_bicc_common.safe_to_timestamp(l.journalbatchlastupdatedate),
            l.journalbatchlastupdatelogin,
            pkg_bicc_common.safe_to_timestamp(l.journalbatchlastupdatelogin),
            l.journalbatchlastupdatedby,
            pkg_bicc_common.safe_to_timestamp(l.journalbatchlastupdatedby),
            l.journalbatchname,
            l.journalbatchobjectversionnumber,
            pkg_bicc_common.safe_to_number(l.journalbatchparentjebatchid),
            l.journalbatchperiodsetname,
            l.journalbatchposteddate,
            pkg_bicc_common.safe_to_timestamp(l.journalbatchposteddate),
            pkg_bicc_common.safe_to_number(l.journalbatchpostingrunid),
            pkg_bicc_common.safe_to_number(l.journalbatchrequestid),
            l.journalbatchstatus,
            l_run_id,
            systimestamp
        from L_GL_JOURNAL_BATCH_BC l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'GL_JOURNAL_BATCH', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'GL_JOURNAL_BATCH', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
        -- NEW: in staging but not in final
        select count(*) into p_new_count
        from (
            select distinct journalbatchjebatchid
            from stg_fbx_gl_journal_batch
            where job_id = p_job_id
              and journalbatchjebatchid is not null
        ) s
        where not exists (
            select 1 from fbx_gl_journal_batch f
            where f.journalbatchjebatchid = s.journalbatchjebatchid
        );

        -- MATCHED: existing records
        select count(*) into l_matched
        from (
            select distinct journalbatchjebatchid
            from stg_fbx_gl_journal_batch
            where job_id = p_job_id
              and journalbatchjebatchid is not null
        ) s
        where exists (
            select 1 from fbx_gl_journal_batch f
            where f.journalbatchjebatchid = s.journalbatchjebatchid
        );

        -- UNCHANGED: use INTERSECT pattern
        select count(*) into p_unchanged_count
        from (
            select
                journalbatchjebatchid,
                journalbatchaccountedperiodtype,
                journalbatchactualflag,
                journalbatchapprovalstatuscode,
                journalbatchapproveremployeeid,
                journalbatchaveragejournalflag,
                journalbatchchartofaccountsid,
                journalbatchcreationdate_ts,
                journalbatchdatecreated_ts,
                journalbatchdefaulteffectivedate_ts,
                journalbatchdefaultperiodname,
                journalbatchdescription,
                journalbatchfundsstatuscode,
                journalbatchgroupid,
                journalbatchlastupdatedate_ts,
                journalbatchlastupdatelogin_ts,
                journalbatchlastupdatedby_ts,
                journalbatchname,
                journalbatchobjectversionnumber,
                journalbatchparentjebatchid,
                journalbatchperiodsetname,
                journalbatchposteddate_ts,
                journalbatchpostingrunid,
                journalbatchrequestid,
                journalbatchstatus
            from (
                select s.*,
                       row_number() over (
                         partition by journalbatchjebatchid
                         order by journalbatchlastupdatedate_ts desc nulls last, rowid
                       ) rn
                from stg_fbx_gl_journal_batch s
                where job_id = p_job_id
                  and journalbatchjebatchid is not null
            )
            where rn = 1
            intersect
            select
                journalbatchjebatchid,
                journalbatchaccountedperiodtype,
                journalbatchactualflag,
                journalbatchapprovalstatuscode,
                journalbatchapproveremployeeid,
                journalbatchaveragejournalflag,
                journalbatchchartofaccountsid,
                journalbatchcreationdate_ts,
                journalbatchdatecreated_ts,
                journalbatchdefaulteffectivedate_ts,
                journalbatchdefaultperiodname,
                journalbatchdescription,
                journalbatchfundsstatuscode,
                journalbatchgroupid,
                journalbatchlastupdatedate_ts,
                journalbatchlastupdatelogin_ts,
                journalbatchlastupdatedby_ts,
                journalbatchname,
                journalbatchobjectversionnumber,
                journalbatchparentjebatchid,
                journalbatchperiodsetname,
                journalbatchposteddate_ts,
                journalbatchpostingrunid,
                journalbatchrequestid,
                journalbatchstatus
            from fbx_gl_journal_batch
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
            'GL_JOURNAL_BATCH', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct journalbatchjebatchid) into l_rows_loaded
        from stg_fbx_gl_journal_batch
        where job_id = l_job_id
          and journalbatchjebatchid is not null;

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
        merge into fbx_gl_journal_batch f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by journalbatchjebatchid
                        order by journalbatchlastupdatedate_ts desc nulls last, rowid
                    ) rn
                from stg_fbx_gl_journal_batch s
                where job_id = p_job_id
                  and journalbatchjebatchid is not null
            )
            where rn = 1
        ) s
        on (f.journalbatchjebatchid = s.journalbatchjebatchid)
        when matched then update set
            f.journalbatchaccountedperiodtype       = s.journalbatchaccountedperiodtype,
            f.journalbatchactualflag                = s.journalbatchactualflag,
            f.journalbatchapprovalstatuscode        = s.journalbatchapprovalstatuscode,
            f.journalbatchapproveremployeeid        = s.journalbatchapproveremployeeid,
            f.journalbatchaveragejournalflag        = s.journalbatchaveragejournalflag,
            f.journalbatchchartofaccountsid         = s.journalbatchchartofaccountsid,
            f.journalbatchcreationdate_ts           = s.journalbatchcreationdate_ts,
            f.journalbatchdatecreated_ts            = s.journalbatchdatecreated_ts,
            f.journalbatchdefaulteffectivedate_ts   = s.journalbatchdefaulteffectivedate_ts,
            f.journalbatchdefaultperiodname         = s.journalbatchdefaultperiodname,
            f.journalbatchdescription               = s.journalbatchdescription,
            f.journalbatchfundsstatuscode           = s.journalbatchfundsstatuscode,
            f.journalbatchgroupid                   = s.journalbatchgroupid,
            f.journalbatchlastupdatedate_ts         = s.journalbatchlastupdatedate_ts,
            f.journalbatchlastupdatelogin_ts        = s.journalbatchlastupdatelogin_ts,
            f.journalbatchlastupdatedby_ts          = s.journalbatchlastupdatedby_ts,
            f.journalbatchname                      = s.journalbatchname,
            f.journalbatchobjectversionnumber       = s.journalbatchobjectversionnumber,
            f.journalbatchparentjebatchid           = s.journalbatchparentjebatchid,
            f.journalbatchperiodsetname             = s.journalbatchperiodsetname,
            f.journalbatchposteddate_ts             = s.journalbatchposteddate_ts,
            f.journalbatchpostingrunid              = s.journalbatchpostingrunid,
            f.journalbatchrequestid                 = s.journalbatchrequestid,
            f.journalbatchstatus                    = s.journalbatchstatus,
            f.last_extract_run_id                   = s.last_extract_run_id,
            f.last_extract_run_ts                   = s.last_extract_run_ts
        when not matched then insert (
            journalbatchjebatchid,
            journalbatchaccountedperiodtype,
            journalbatchactualflag,
            journalbatchapprovalstatuscode,
            journalbatchapproveremployeeid,
            journalbatchaveragejournalflag,
            journalbatchchartofaccountsid,
            journalbatchcreationdate_ts,
            journalbatchdatecreated_ts,
            journalbatchdefaulteffectivedate_ts,
            journalbatchdefaultperiodname,
            journalbatchdescription,
            journalbatchfundsstatuscode,
            journalbatchgroupid,
            journalbatchlastupdatedate_ts,
            journalbatchlastupdatelogin_ts,
            journalbatchlastupdatedby_ts,
            journalbatchname,
            journalbatchobjectversionnumber,
            journalbatchparentjebatchid,
            journalbatchperiodsetname,
            journalbatchposteddate_ts,
            journalbatchpostingrunid,
            journalbatchrequestid,
            journalbatchstatus,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.journalbatchjebatchid,
            s.journalbatchaccountedperiodtype,
            s.journalbatchactualflag,
            s.journalbatchapprovalstatuscode,
            s.journalbatchapproveremployeeid,
            s.journalbatchaveragejournalflag,
            s.journalbatchchartofaccountsid,
            s.journalbatchcreationdate_ts,
            s.journalbatchdatecreated_ts,
            s.journalbatchdefaulteffectivedate_ts,
            s.journalbatchdefaultperiodname,
            s.journalbatchdescription,
            s.journalbatchfundsstatuscode,
            s.journalbatchgroupid,
            s.journalbatchlastupdatedate_ts,
            s.journalbatchlastupdatelogin_ts,
            s.journalbatchlastupdatedby_ts,
            s.journalbatchname,
            s.journalbatchobjectversionnumber,
            s.journalbatchparentjebatchid,
            s.journalbatchperiodsetname,
            s.journalbatchposteddate_ts,
            s.journalbatchpostingrunid,
            s.journalbatchrequestid,
            s.journalbatchstatus,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from stg_fbx_gl_journal_batch where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'GL_JOURNAL_BATCH', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'GL_JOURNAL_BATCH', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_gl_journal_batch;
/