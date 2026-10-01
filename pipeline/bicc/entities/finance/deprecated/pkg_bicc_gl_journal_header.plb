create or replace package body pkg_bicc_gl_journal_header as

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
        delete from stg_fbx_gl_journal_header where job_id = p_job_id;

        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'gl_journal_header_unzipped.csv'
        );

        execute immediate 'TRUNCATE TABLE l_gl_journal_header_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'gl_journal_header_unzipped.csv';

        dbms_cloud.copy_data(
            table_name      => 'l_gl_journal_header_bc',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object('type' value 'csv', 'skipheaders' value '1')
        );

        insert into stg_fbx_gl_journal_header (
            job_id,
            gljeheadersaccrualrevchangesignflag,
            gljeheadersaccrualrevchangesignflagtransient,
            gljeheadersaccrualreveffectivedate_raw,
            gljeheadersaccrualreveffectivedate_ts,
            gljeheadersaccrualrevjeheaderid,
            gljeheadersaccrualrevperiodname,
            gljeheadersaccrualrevstatus,
            gljeheadersactualflag,
            gljeheadersbalancedjeflag,
            gljeheaderscloseacctseqassignid,
            gljeheaderscloseacctseqversionid,
            gljeheaderscreationdate_raw,
            gljeheaderscreationdate_ts,
            gljeheaderscurrencycode,
            gljeheaderscurrencyconversiondate_raw,
            gljeheaderscurrencyconversiondate_ts,
            gljeheaderscurrencyconversionrate,
            gljeheaderscurrencyconversiontype,
            gljeheadersdatecreated_raw,
            gljeheadersdatecreated_ts,
            gljeheadersdefaulteffectivedate_raw,
            gljeheadersdefaulteffectivedate_ts,
            gljeheadersdescription,
            gljeheadersdisplayalcjournalflag,
            gljeheadersencumbrancetypeid,
            gljeheadersjebatchid,
            gljeheadersjefromslaflag,
            gljeheaderslastupdatedate_raw,
            gljeheaderslastupdatedate_ts,
            gljeheaderslastupdatelogin_raw,
            gljeheaderslastupdatelogin_ts,
            gljeheaderslastupdatedby_raw,
            gljeheaderslastupdatedby_ts,
            gljeheadersledgerid,
            gljeheaderslegalentityid,
            gljeheadersmultibalsegflag,
            gljeheadersmulticurrencyflag,
            gljeheadersname,
            gljeheadersobjectversionnumber,
            gljeheadersparentjeheaderid,
            gljeheadersperiodname,
            gljeheaderspostcurrencycode,
            gljeheaderspostmulticurrencyflag,
            gljeheadersposteddate_raw,
            gljeheadersposteddate_ts,
            gljeheadersposteddatetime_raw,
            gljeheadersposteddatetime_ts,
            gljeheaderspostingacctseqassignid,
            gljeheaderspostingacctseqversionid,
            gljeheadersreferencedate_raw,
            gljeheadersreferencedate_ts,
            gljeheadersreversedjeheaderid,
            gljeheadersstatus,
            jeheaderid,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,
            l.gljeheadersaccrualrevchangesignflag,
            l.gljeheadersaccrualrevchangesignflagtransient,
            l.gljeheadersaccrualreveffectivedate,
            pkg_bicc_common.safe_to_timestamp(l.gljeheadersaccrualreveffectivedate),
            pkg_bicc_common.safe_to_number(l.gljeheadersaccrualrevjeheaderid),
            l.gljeheadersaccrualrevperiodname,
            l.gljeheadersaccrualrevstatus,
            l.gljeheadersactualflag,
            l.gljeheadersbalancedjeflag,
            pkg_bicc_common.safe_to_number(l.gljeheaderscloseacctseqassignid),
            pkg_bicc_common.safe_to_number(l.gljeheaderscloseacctseqversionid),
            l.gljeheaderscreationdate,
            pkg_bicc_common.safe_to_timestamp(l.gljeheaderscreationdate),
            l.gljeheaderscurrencycode,
            l.gljeheaderscurrencyconversiondate,
            pkg_bicc_common.safe_to_timestamp(l.gljeheaderscurrencyconversiondate),
            pkg_bicc_common.safe_to_number(l.gljeheaderscurrencyconversionrate),
            l.gljeheaderscurrencyconversiontype,
            l.gljeheadersdatecreated,
            pkg_bicc_common.safe_to_timestamp(l.gljeheadersdatecreated),
            l.gljeheadersdefaulteffectivedate,
            pkg_bicc_common.safe_to_timestamp(l.gljeheadersdefaulteffectivedate),
            l.gljeheadersdescription,
            l.gljeheadersdisplayalcjournalflag,
            pkg_bicc_common.safe_to_number(l.gljeheadersencumbrancetypeid),
            pkg_bicc_common.safe_to_number(l.gljeheadersjebatchid),
            l.gljeheadersjefromslaflag,
            l.gljeheaderslastupdatedate,
            pkg_bicc_common.safe_to_timestamp(l.gljeheaderslastupdatedate),
            l.gljeheaderslastupdatelogin,
            pkg_bicc_common.safe_to_timestamp(l.gljeheaderslastupdatelogin),
            l.gljeheaderslastupdatedby,
            pkg_bicc_common.safe_to_timestamp(l.gljeheaderslastupdatedby),
            pkg_bicc_common.safe_to_number(l.gljeheadersledgerid),
            pkg_bicc_common.safe_to_number(l.gljeheaderslegalentityid),
            l.gljeheadersmultibalsegflag,
            l.gljeheadersmulticurrencyflag,
            l.gljeheadersname,
            l.gljeheadersobjectversionnumber,
            pkg_bicc_common.safe_to_number(l.gljeheadersparentjeheaderid),
            l.gljeheadersperiodname,
            l.gljeheaderspostcurrencycode,
            l.gljeheaderspostmulticurrencyflag,
            l.gljeheadersposteddate,
            pkg_bicc_common.safe_to_timestamp(l.gljeheadersposteddate),
            l.gljeheadersposteddatetime,
            pkg_bicc_common.safe_to_timestamp(l.gljeheadersposteddatetime),
            pkg_bicc_common.safe_to_number(l.gljeheaderspostingacctseqassignid),
            pkg_bicc_common.safe_to_number(l.gljeheaderspostingacctseqversionid),
            l.gljeheadersreferencedate,
            pkg_bicc_common.safe_to_timestamp(l.gljeheadersreferencedate),
            pkg_bicc_common.safe_to_number(l.gljeheadersreversedjeheaderid),
            l.gljeheadersstatus,
            pkg_bicc_common.safe_to_number(l.jeheaderid),
            l_run_id,
            systimestamp
        from l_gl_journal_header_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'GL_JOURNAL_HEADER', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'GL_JOURNAL_HEADER', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct jeheaderid
            from stg_fbx_gl_journal_header
            where job_id = p_job_id
              and jeheaderid is not null
        ) s
        where not exists (
            select 1 from fbx_gl_journal_header f where f.jeheaderid = s.jeheaderid
        );

        -- MATCHED: existing records
        select count(*) into l_matched
        from (
            select distinct jeheaderid
            from stg_fbx_gl_journal_header
            where job_id = p_job_id
              and jeheaderid is not null
        ) s
        where exists (
            select 1 from fbx_gl_journal_header f where f.jeheaderid = s.jeheaderid
        );

        -- UNCHANGED: use INTERSECT pattern (all meaningful final columns, excluding audit)
        select count(*) into p_unchanged_count
        from (
            select
                jeheaderid,
                gljeheadersaccrualrevchangesignflag,
                gljeheadersaccrualrevchangesignflagtransient,
                gljeheadersaccrualreveffectivedate_ts,
                gljeheadersaccrualrevjeheaderid,
                gljeheadersaccrualrevperiodname,
                gljeheadersaccrualrevstatus,
                gljeheadersactualflag,
                gljeheadersbalancedjeflag,
                gljeheaderscloseacctseqassignid,
                gljeheaderscloseacctseqversionid,
                gljeheaderscreationdate_ts,
                gljeheaderscurrencycode,
                gljeheaderscurrencyconversiondate_ts,
                gljeheaderscurrencyconversionrate,
                gljeheaderscurrencyconversiontype,
                gljeheadersdatecreated_ts,
                gljeheadersdefaulteffectivedate_ts,
                gljeheadersdescription,
                gljeheadersdisplayalcjournalflag,
                gljeheadersencumbrancetypeid,
                gljeheadersjebatchid,
                gljeheadersjefromslaflag,
                gljeheaderslastupdatedate_ts,
                gljeheaderslastupdatelogin_ts,
                gljeheaderslastupdatedby_ts,
                gljeheadersledgerid,
                gljeheaderslegalentityid,
                gljeheadersmultibalsegflag,
                gljeheadersmulticurrencyflag,
                gljeheadersname,
                gljeheadersobjectversionnumber,
                gljeheadersparentjeheaderid,
                gljeheadersperiodname,
                gljeheaderspostcurrencycode,
                gljeheaderspostmulticurrencyflag,
                gljeheadersposteddate_ts,
                gljeheadersposteddatetime_ts,
                gljeheaderspostingacctseqassignid,
                gljeheaderspostingacctseqversionid,
                gljeheadersreferencedate_ts,
                gljeheadersreversedjeheaderid,
                gljeheadersstatus
            from (
                select s.*,
                       row_number() over (
                         partition by jeheaderid
                         order by gljeheaderslastupdatedate_ts desc nulls last, rowid
                       ) rn
                from stg_fbx_gl_journal_header s
                where job_id = p_job_id
                  and jeheaderid is not null
            )
            where rn = 1
            intersect
            select
                jeheaderid,
                gljeheadersaccrualrevchangesignflag,
                gljeheadersaccrualrevchangesignflagtransient,
                gljeheadersaccrualreveffectivedate_ts,
                gljeheadersaccrualrevjeheaderid,
                gljeheadersaccrualrevperiodname,
                gljeheadersaccrualrevstatus,
                gljeheadersactualflag,
                gljeheadersbalancedjeflag,
                gljeheaderscloseacctseqassignid,
                gljeheaderscloseacctseqversionid,
                gljeheaderscreationdate_ts,
                gljeheaderscurrencycode,
                gljeheaderscurrencyconversiondate_ts,
                gljeheaderscurrencyconversionrate,
                gljeheaderscurrencyconversiontype,
                gljeheadersdatecreated_ts,
                gljeheadersdefaulteffectivedate_ts,
                gljeheadersdescription,
                gljeheadersdisplayalcjournalflag,
                gljeheadersencumbrancetypeid,
                gljeheadersjebatchid,
                gljeheadersjefromslaflag,
                gljeheaderslastupdatedate_ts,
                gljeheaderslastupdatelogin_ts,
                gljeheaderslastupdatedby_ts,
                gljeheadersledgerid,
                gljeheaderslegalentityid,
                gljeheadersmultibalsegflag,
                gljeheadersmulticurrencyflag,
                gljeheadersname,
                gljeheadersobjectversionnumber,
                gljeheadersparentjeheaderid,
                gljeheadersperiodname,
                gljeheaderspostcurrencycode,
                gljeheaderspostmulticurrencyflag,
                gljeheadersposteddate_ts,
                gljeheadersposteddatetime_ts,
                gljeheaderspostingacctseqassignid,
                gljeheaderspostingacctseqversionid,
                gljeheadersreferencedate_ts,
                gljeheadersreversedjeheaderid,
                gljeheadersstatus
            from fbx_gl_journal_header
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
            'GL_JOURNAL_HEADER', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct jeheaderid) into l_rows_loaded
        from stg_fbx_gl_journal_header
        where job_id = l_job_id
          and jeheaderid is not null;

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
        merge into fbx_gl_journal_header f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by jeheaderid
                        order by gljeheaderslastupdatedate_ts desc nulls last, rowid
                    ) rn
                from stg_fbx_gl_journal_header s
                where job_id = p_job_id
                  and jeheaderid is not null
            )
            where rn = 1
        ) s
        on (f.jeheaderid = s.jeheaderid)
        when matched then update set
            f.gljeheadersaccrualrevchangesignflag          = s.gljeheadersaccrualrevchangesignflag,
            f.gljeheadersaccrualrevchangesignflagtransient = s.gljeheadersaccrualrevchangesignflagtransient,
            f.gljeheadersaccrualreveffectivedate_ts        = s.gljeheadersaccrualreveffectivedate_ts,
            f.gljeheadersaccrualrevjeheaderid              = s.gljeheadersaccrualrevjeheaderid,
            f.gljeheadersaccrualrevperiodname              = s.gljeheadersaccrualrevperiodname,
            f.gljeheadersaccrualrevstatus                  = s.gljeheadersaccrualrevstatus,
            f.gljeheadersactualflag                        = s.gljeheadersactualflag,
            f.gljeheadersbalancedjeflag                    = s.gljeheadersbalancedjeflag,
            f.gljeheaderscloseacctseqassignid              = s.gljeheaderscloseacctseqassignid,
            f.gljeheaderscloseacctseqversionid             = s.gljeheaderscloseacctseqversionid,
            f.gljeheaderscreationdate_ts                   = s.gljeheaderscreationdate_ts,
            f.gljeheaderscurrencycode                      = s.gljeheaderscurrencycode,
            f.gljeheaderscurrencyconversiondate_ts         = s.gljeheaderscurrencyconversiondate_ts,
            f.gljeheaderscurrencyconversionrate            = s.gljeheaderscurrencyconversionrate,
            f.gljeheaderscurrencyconversiontype            = s.gljeheaderscurrencyconversiontype,
            f.gljeheadersdatecreated_ts                    = s.gljeheadersdatecreated_ts,
            f.gljeheadersdefaulteffectivedate_ts           = s.gljeheadersdefaulteffectivedate_ts,
            f.gljeheadersdescription                       = s.gljeheadersdescription,
            f.gljeheadersdisplayalcjournalflag             = s.gljeheadersdisplayalcjournalflag,
            f.gljeheadersencumbrancetypeid                 = s.gljeheadersencumbrancetypeid,
            f.gljeheadersjebatchid                         = s.gljeheadersjebatchid,
            f.gljeheadersjefromslaflag                     = s.gljeheadersjefromslaflag,
            f.gljeheaderslastupdatedate_ts                 = s.gljeheaderslastupdatedate_ts,
            f.gljeheaderslastupdatelogin_ts                = s.gljeheaderslastupdatelogin_ts,
            f.gljeheaderslastupdatedby_ts                  = s.gljeheaderslastupdatedby_ts,
            f.gljeheadersledgerid                          = s.gljeheadersledgerid,
            f.gljeheaderslegalentityid                     = s.gljeheaderslegalentityid,
            f.gljeheadersmultibalsegflag                   = s.gljeheadersmultibalsegflag,
            f.gljeheadersmulticurrencyflag                 = s.gljeheadersmulticurrencyflag,
            f.gljeheadersname                              = s.gljeheadersname,
            f.gljeheadersobjectversionnumber               = s.gljeheadersobjectversionnumber,
            f.gljeheadersparentjeheaderid                  = s.gljeheadersparentjeheaderid,
            f.gljeheadersperiodname                        = s.gljeheadersperiodname,
            f.gljeheaderspostcurrencycode                  = s.gljeheaderspostcurrencycode,
            f.gljeheaderspostmulticurrencyflag             = s.gljeheaderspostmulticurrencyflag,
            f.gljeheadersposteddate_ts                     = s.gljeheadersposteddate_ts,
            f.gljeheadersposteddatetime_ts                 = s.gljeheadersposteddatetime_ts,
            f.gljeheaderspostingacctseqassignid            = s.gljeheaderspostingacctseqassignid,
            f.gljeheaderspostingacctseqversionid           = s.gljeheaderspostingacctseqversionid,
            f.gljeheadersreferencedate_ts                  = s.gljeheadersreferencedate_ts,
            f.gljeheadersreversedjeheaderid                = s.gljeheadersreversedjeheaderid,
            f.gljeheadersstatus                            = s.gljeheadersstatus,
            f.last_extract_run_id                          = s.last_extract_run_id,
            f.last_extract_run_ts                          = s.last_extract_run_ts
        when not matched then insert (
            jeheaderid,
            gljeheadersaccrualrevchangesignflag,
            gljeheadersaccrualrevchangesignflagtransient,
            gljeheadersaccrualreveffectivedate_ts,
            gljeheadersaccrualrevjeheaderid,
            gljeheadersaccrualrevperiodname,
            gljeheadersaccrualrevstatus,
            gljeheadersactualflag,
            gljeheadersbalancedjeflag,
            gljeheaderscloseacctseqassignid,
            gljeheaderscloseacctseqversionid,
            gljeheaderscreationdate_ts,
            gljeheaderscurrencycode,
            gljeheaderscurrencyconversiondate_ts,
            gljeheaderscurrencyconversionrate,
            gljeheaderscurrencyconversiontype,
            gljeheadersdatecreated_ts,
            gljeheadersdefaulteffectivedate_ts,
            gljeheadersdescription,
            gljeheadersdisplayalcjournalflag,
            gljeheadersencumbrancetypeid,
            gljeheadersjebatchid,
            gljeheadersjefromslaflag,
            gljeheaderslastupdatedate_ts,
            gljeheaderslastupdatelogin_ts,
            gljeheaderslastupdatedby_ts,
            gljeheadersledgerid,
            gljeheaderslegalentityid,
            gljeheadersmultibalsegflag,
            gljeheadersmulticurrencyflag,
            gljeheadersname,
            gljeheadersobjectversionnumber,
            gljeheadersparentjeheaderid,
            gljeheadersperiodname,
            gljeheaderspostcurrencycode,
            gljeheaderspostmulticurrencyflag,
            gljeheadersposteddate_ts,
            gljeheadersposteddatetime_ts,
            gljeheaderspostingacctseqassignid,
            gljeheaderspostingacctseqversionid,
            gljeheadersreferencedate_ts,
            gljeheadersreversedjeheaderid,
            gljeheadersstatus,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.jeheaderid,
            s.gljeheadersaccrualrevchangesignflag,
            s.gljeheadersaccrualrevchangesignflagtransient,
            s.gljeheadersaccrualreveffectivedate_ts,
            s.gljeheadersaccrualrevjeheaderid,
            s.gljeheadersaccrualrevperiodname,
            s.gljeheadersaccrualrevstatus,
            s.gljeheadersactualflag,
            s.gljeheadersbalancedjeflag,
            s.gljeheaderscloseacctseqassignid,
            s.gljeheaderscloseacctseqversionid,
            s.gljeheaderscreationdate_ts,
            s.gljeheaderscurrencycode,
            s.gljeheaderscurrencyconversiondate_ts,
            s.gljeheaderscurrencyconversionrate,
            s.gljeheaderscurrencyconversiontype,
            s.gljeheadersdatecreated_ts,
            s.gljeheadersdefaulteffectivedate_ts,
            s.gljeheadersdescription,
            s.gljeheadersdisplayalcjournalflag,
            s.gljeheadersencumbrancetypeid,
            s.gljeheadersjebatchid,
            s.gljeheadersjefromslaflag,
            s.gljeheaderslastupdatedate_ts,
            s.gljeheaderslastupdatelogin_ts,
            s.gljeheaderslastupdatedby_ts,
            s.gljeheadersledgerid,
            s.gljeheaderslegalentityid,
            s.gljeheadersmultibalsegflag,
            s.gljeheadersmulticurrencyflag,
            s.gljeheadersname,
            s.gljeheadersobjectversionnumber,
            s.gljeheadersparentjeheaderid,
            s.gljeheadersperiodname,
            s.gljeheaderspostcurrencycode,
            s.gljeheaderspostmulticurrencyflag,
            s.gljeheadersposteddate_ts,
            s.gljeheadersposteddatetime_ts,
            s.gljeheaderspostingacctseqassignid,
            s.gljeheaderspostingacctseqversionid,
            s.gljeheadersreferencedate_ts,
            s.gljeheadersreversedjeheaderid,
            s.gljeheadersstatus,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from stg_fbx_gl_journal_header where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'GL_JOURNAL_HEADER', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'GL_JOURNAL_HEADER', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_gl_journal_header;
/