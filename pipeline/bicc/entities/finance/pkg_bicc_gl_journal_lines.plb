create or replace package body pkg_bicc_gl_journal_lines as

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
        delete from stg_fbx_gl_journal_lines where job_id = p_job_id;

        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'gl_journal_lines_unzipped.csv'
        );

        execute immediate 'TRUNCATE TABLE l_gl_journal_lines_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'gl_journal_lines_unzipped.csv';

        dbms_cloud.copy_data(
            table_name      => 'l_gl_journal_lines_bc',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object('type' value 'csv', 'skipheaders' value '1')
        );

        -- INSERT SELECT: cherry-pick and transform columns from landing
        insert into stg_fbx_gl_journal_lines (
            job_id,
            jeheaderid,
            jelinenum,
            gljelinescodecombinationid,
            gljelinescreationdate_raw,
            gljelinescreationdate_ts,
            gljelinescurrencycode,
            gljelinescurrencyconversiondate_raw,
            gljelinescurrencyconversiondate_ts,
            gljelinescurrencyconversionrate,
            gljelinescurrencyconversiontype,
            gljelinesdescription,
            gljelineseffectivedate_raw,
            gljelineseffectivedate_ts,
            gljelinesenteredcr,
            gljelinesentereddr,
            gljelinesglsllinkid,
            gljelinesignorerateflag,
            gljelineslastupdatedate_raw,
            gljelineslastupdatedate_ts,
            gljelineslastupdatelogin_raw,
            gljelineslastupdatelogin_ts,
            gljelineslastupdatedby_raw,
            gljelineslastupdatedby_ts,
            gljelinesledgerid,
            gljelineslinetypecode,
            gljelinesobjectversionnumber,
            gljelinesperiodname,
            gljelinesstatamount,
            gljelinesstatus,
            gljelinessubledgerdocsequenceid,
            gljelinessubledgerdocsequencevalue,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,
            pkg_bicc_common.safe_to_number(l.jeheaderid),
            pkg_bicc_common.safe_to_number(l.jelinenum),
            pkg_bicc_common.safe_to_number(l.gljelinescodecombinationid),
            l.gljelinescreationdate,
            pkg_bicc_common.safe_to_timestamp(l.gljelinescreationdate),
            l.gljelinescurrencycode,
            l.gljelinescurrencyconversiondate,
            pkg_bicc_common.safe_to_timestamp(l.gljelinescurrencyconversiondate),
            pkg_bicc_common.safe_to_number(l.gljelinescurrencyconversionrate),
            l.gljelinescurrencyconversiontype,
            l.gljelinesdescription,
            l.gljelineseffectivedate,
            pkg_bicc_common.safe_to_timestamp(l.gljelineseffectivedate),
            pkg_bicc_common.safe_to_number(l.gljelinesenteredcr),
            pkg_bicc_common.safe_to_number(l.gljelinesentereddr),
            pkg_bicc_common.safe_to_number(l.gljelinesglsllinkid),
            l.gljelinesignorerateflag,
            l.gljelineslastupdatedate,
            pkg_bicc_common.safe_to_timestamp(l.gljelineslastupdatedate),
            l.gljelineslastupdatelogin,
            pkg_bicc_common.safe_to_timestamp(l.gljelineslastupdatelogin),
            l.gljelineslastupdatedby,
            pkg_bicc_common.safe_to_timestamp(l.gljelineslastupdatedby),
            pkg_bicc_common.safe_to_number(l.gljelinesledgerid),
            l.gljelineslinetypecode,
            l.gljelinesobjectversionnumber,
            l.gljelinesperiodname,
            pkg_bicc_common.safe_to_number(l.gljelinesstatamount),
            l.gljelinesstatus,
            pkg_bicc_common.safe_to_number(l.gljelinessubledgerdocsequenceid),
            pkg_bicc_common.safe_to_number(l.gljelinessubledgerdocsequencevalue),
            l_run_id,
            systimestamp
        from l_gl_journal_lines_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'GL_JOURNAL_LINES', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'GL_JOURNAL_LINES', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct jeheaderid, jelinenum
            from stg_fbx_gl_journal_lines
            where job_id = p_job_id
              and jeheaderid is not null
              and jelinenum  is not null
        ) s
        where not exists (
            select 1
            from fbx_gl_journal_lines f
            where f.jeheaderid = s.jeheaderid
              and f.jelinenum  = s.jelinenum
        );

        -- MATCHED: existing records
        select count(*) into l_matched
        from (
            select distinct jeheaderid, jelinenum
            from stg_fbx_gl_journal_lines
            where job_id = p_job_id
              and jeheaderid is not null
              and jelinenum  is not null
        ) s
        where exists (
            select 1
            from fbx_gl_journal_lines f
            where f.jeheaderid = s.jeheaderid
              and f.jelinenum  = s.jelinenum
        );

        -- UNCHANGED: use INTERSECT pattern over all meaningful final columns
        select count(*) into p_unchanged_count
        from (
            select
                jeheaderid,
                jelinenum,
                gljelinescodecombinationid,
                gljelinescreationdate_ts,
                gljelinescurrencycode,
                gljelinescurrencyconversiondate_ts,
                gljelinescurrencyconversionrate,
                gljelinescurrencyconversiontype,
                gljelinesdescription,
                gljelineseffectivedate_ts,
                gljelinesenteredcr,
                gljelinesentereddr,
                gljelinesglsllinkid,
                gljelinesignorerateflag,
                gljelineslastupdatedate_ts,
                gljelineslastupdatelogin_ts,
                gljelineslastupdatedby_ts,
                gljelinesledgerid,
                gljelineslinetypecode,
                gljelinesobjectversionnumber,
                gljelinesperiodname,
                gljelinesstatamount,
                gljelinesstatus,
                gljelinessubledgerdocsequenceid,
                gljelinessubledgerdocsequencevalue
            from (
                select s.*,
                       row_number() over (
                         partition by jeheaderid, jelinenum
                         order by gljelineslastupdatedate_ts desc nulls last, rowid
                       ) rn
                from stg_fbx_gl_journal_lines s
                where job_id = p_job_id
                  and jeheaderid is not null
                  and jelinenum  is not null
            )
            where rn = 1
            intersect
            select
                jeheaderid,
                jelinenum,
                gljelinescodecombinationid,
                gljelinescreationdate_ts,
                gljelinescurrencycode,
                gljelinescurrencyconversiondate_ts,
                gljelinescurrencyconversionrate,
                gljelinescurrencyconversiontype,
                gljelinesdescription,
                gljelineseffectivedate_ts,
                gljelinesenteredcr,
                gljelinesentereddr,
                gljelinesglsllinkid,
                gljelinesignorerateflag,
                gljelineslastupdatedate_ts,
                gljelineslastupdatelogin_ts,
                gljelineslastupdatedby_ts,
                gljelinesledgerid,
                gljelineslinetypecode,
                gljelinesobjectversionnumber,
                gljelinesperiodname,
                gljelinesstatamount,
                gljelinesstatus,
                gljelinessubledgerdocsequenceid,
                gljelinessubledgerdocsequencevalue
            from fbx_gl_journal_lines
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
            'GL_JOURNAL_LINES', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct jeheaderid || '|' || jelinenum) into l_rows_loaded
        from stg_fbx_gl_journal_lines
        where job_id    = l_job_id
          and jeheaderid is not null
          and jelinenum  is not null;

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
        merge into fbx_gl_journal_lines f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by jeheaderid, jelinenum
                        order by gljelineslastupdatedate_ts desc nulls last, rowid
                    ) rn
                from stg_fbx_gl_journal_lines s
                where job_id = p_job_id
                  and jeheaderid is not null
                  and jelinenum  is not null
            )
            where rn = 1
        ) s
        on (
            f.jeheaderid = s.jeheaderid
            and f.jelinenum = s.jelinenum
        )
        when matched then update set
            f.gljelinescodecombinationid         = s.gljelinescodecombinationid,
            f.gljelinescreationdate_ts           = s.gljelinescreationdate_ts,
            f.gljelinescurrencycode              = s.gljelinescurrencycode,
            f.gljelinescurrencyconversiondate_ts = s.gljelinescurrencyconversiondate_ts,
            f.gljelinescurrencyconversionrate    = s.gljelinescurrencyconversionrate,
            f.gljelinescurrencyconversiontype    = s.gljelinescurrencyconversiontype,
            f.gljelinesdescription               = s.gljelinesdescription,
            f.gljelineseffectivedate_ts          = s.gljelineseffectivedate_ts,
            f.gljelinesenteredcr                 = s.gljelinesenteredcr,
            f.gljelinesentereddr                 = s.gljelinesentereddr,
            f.gljelinesglsllinkid                = s.gljelinesglsllinkid,
            f.gljelinesignorerateflag            = s.gljelinesignorerateflag,
            f.gljelineslastupdatedate_ts         = s.gljelineslastupdatedate_ts,
            f.gljelineslastupdatelogin_ts        = s.gljelineslastupdatelogin_ts,
            f.gljelineslastupdatedby_ts          = s.gljelineslastupdatedby_ts,
            f.gljelinesledgerid                  = s.gljelinesledgerid,
            f.gljelineslinetypecode              = s.gljelineslinetypecode,
            f.gljelinesobjectversionnumber       = s.gljelinesobjectversionnumber,
            f.gljelinesperiodname                = s.gljelinesperiodname,
            f.gljelinesstatamount                = s.gljelinesstatamount,
            f.gljelinesstatus                    = s.gljelinesstatus,
            f.gljelinessubledgerdocsequenceid    = s.gljelinessubledgerdocsequenceid,
            f.gljelinessubledgerdocsequencevalue = s.gljelinessubledgerdocsequencevalue,
            f.last_extract_run_id                = s.last_extract_run_id,
            f.last_extract_run_ts                = s.last_extract_run_ts
        when not matched then insert (
            jeheaderid,
            jelinenum,
            gljelinescodecombinationid,
            gljelinescreationdate_ts,
            gljelinescurrencycode,
            gljelinescurrencyconversiondate_ts,
            gljelinescurrencyconversionrate,
            gljelinescurrencyconversiontype,
            gljelinesdescription,
            gljelineseffectivedate_ts,
            gljelinesenteredcr,
            gljelinesentereddr,
            gljelinesglsllinkid,
            gljelinesignorerateflag,
            gljelineslastupdatedate_ts,
            gljelineslastupdatelogin_ts,
            gljelineslastupdatedby_ts,
            gljelinesledgerid,
            gljelineslinetypecode,
            gljelinesobjectversionnumber,
            gljelinesperiodname,
            gljelinesstatamount,
            gljelinesstatus,
            gljelinessubledgerdocsequenceid,
            gljelinessubledgerdocsequencevalue,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.jeheaderid,
            s.jelinenum,
            s.gljelinescodecombinationid,
            s.gljelinescreationdate_ts,
            s.gljelinescurrencycode,
            s.gljelinescurrencyconversiondate_ts,
            s.gljelinescurrencyconversionrate,
            s.gljelinescurrencyconversiontype,
            s.gljelinesdescription,
            s.gljelineseffectivedate_ts,
            s.gljelinesenteredcr,
            s.gljelinesentereddr,
            s.gljelinesglsllinkid,
            s.gljelinesignorerateflag,
            s.gljelineslastupdatedate_ts,
            s.gljelineslastupdatelogin_ts,
            s.gljelineslastupdatedby_ts,
            s.gljelinesledgerid,
            s.gljelineslinetypecode,
            s.gljelinesobjectversionnumber,
            s.gljelinesperiodname,
            s.gljelinesstatamount,
            s.gljelinesstatus,
            s.gljelinessubledgerdocsequenceid,
            s.gljelinessubledgerdocsequencevalue,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from stg_fbx_gl_journal_lines where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'GL_JOURNAL_LINES', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'GL_JOURNAL_LINES', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_gl_journal_lines;
/