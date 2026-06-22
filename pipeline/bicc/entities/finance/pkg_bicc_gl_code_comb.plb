create or replace package body pkg_bicc_gl_code_comb as

    -- =========================================================================
    -- LOAD (private)
    -- =========================================================================
    -- Flow: extract_and_stage_csv -> COPY_DATA -> INSERT...SELECT
    -- Segment columns are LPAD'd to preserve leading zeros.
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
        delete from s_gl_code_comb_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/gl_code_comb_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_gl_code_comb_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/gl_code_comb_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_GL_CODE_COMB_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_gl_code_comb_bc (
            job_id,
            code_combination_id,
            chart_of_accounts_id,
            account_type,
            enabled_flag,
            detail_budgeting_allowed,
            detail_posting_allowed,
            summary_flag,
            fund,
            location,
            function1,
            grant_code,
            initiative,
            account,
            activity,
            interfund,
            future1,
            start_date_active_raw,
            start_date_active_ts,
            end_date_active_raw,
            end_date_active_ts,
            last_update_date_raw,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,

            -- Keys
            pkg_bicc_common.safe_to_number(l.CODECOMBINATIONCODECOMBINATIONID),
            pkg_bicc_common.safe_to_number(l.CODECOMBINATIONCHARTOFACCOUNTSID),

            -- Flags
            l.CODECOMBINATIONACCOUNTTYPE,
            l.CODECOMBINATIONENABLEDFLAG,
            l.CODECOMBINATIONDETAILBUDGETINGALLOWEDFLAG,
            l.CODECOMBINATIONDETAILPOSTINGALLOWEDFLAG,
            l.CODECOMBINATIONSUMMARYFLAG,

            -- Segments (LPAD to preserve leading zeros)
            LPAD(l.CODECOMBINATIONSEGMENT1, 4, '0'),   -- Fund
            LPAD(l.CODECOMBINATIONSEGMENT2, 3, '0'),   -- Location
            LPAD(l.CODECOMBINATIONSEGMENT3, 4, '0'),   -- Function1
            LPAD(l.CODECOMBINATIONSEGMENT4, 3, '0'),   -- Grant
            LPAD(l.CODECOMBINATIONSEGMENT5, 3, '0'),   -- Initiative
            LPAD(l.CODECOMBINATIONSEGMENT6, 7, '0'),   -- Account
            LPAD(l.CODECOMBINATIONSEGMENT7, 4, '0'),   -- Activity
            LPAD(l.CODECOMBINATIONSEGMENT8, 4, '0'),   -- InterFund
            LPAD(l.CODECOMBINATIONSEGMENT9, 5, '0'),   -- Future1

            -- Dates (raw + timestamp)
            l.CODECOMBINATIONSTARTDATEACTIVE,
            pkg_bicc_common.safe_to_timestamp(l.CODECOMBINATIONSTARTDATEACTIVE),
            l.CODECOMBINATIONENDDATEACTIVE,
            pkg_bicc_common.safe_to_timestamp(l.CODECOMBINATIONENDDATEACTIVE),
            l.CODECOMBINATIONLASTUPDATEDATE,
            pkg_bicc_common.safe_to_timestamp(l.CODECOMBINATIONLASTUPDATEDATE),

            -- Run metadata
            l_run_id,
            systimestamp

        from l_gl_code_comb_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'GL_CODE_COMB', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'GL_CODE_COMB', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct code_combination_id
            from s_gl_code_comb_bc
            where job_id = p_job_id
              and code_combination_id is not null
        ) s
        where not exists (
            select 1 from gl_code_comb_bc f
            where f.code_combination_id = s.code_combination_id
        );

        select count(*) into l_matched
        from (
            select distinct code_combination_id
            from s_gl_code_comb_bc
            where job_id = p_job_id
              and code_combination_id is not null
        ) s
        where exists (
            select 1 from gl_code_comb_bc f
            where f.code_combination_id = s.code_combination_id
        );

        select count(*) into p_unchanged_count
        from (
            select
                code_combination_id,
                chart_of_accounts_id,
                account_type,
                enabled_flag,
                detail_budgeting_allowed,
                detail_posting_allowed,
                summary_flag,
                fund,
                location,
                function1,
                grant_code,
                initiative,
                account,
                activity,
                interfund,
                future1,
                start_date_active_ts,
                end_date_active_ts,
                last_update_date_ts
            from (
                select s.*,
                       row_number() over (
                         partition by code_combination_id
                         order by last_update_date_ts desc nulls last, rowid
                       ) rn
                from s_gl_code_comb_bc s
                where job_id = p_job_id
                  and code_combination_id is not null
            )
            where rn = 1
            intersect
            select
                code_combination_id,
                chart_of_accounts_id,
                account_type,
                enabled_flag,
                detail_budgeting_allowed,
                detail_posting_allowed,
                summary_flag,
                fund,
                location,
                function1,
                grant_code,
                initiative,
                account,
                activity,
                interfund,
                future1,
                start_date_active_ts,
                end_date_active_ts,
                last_update_date_ts
            from gl_code_comb_bc
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
            'GL_CODE_COMB', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct code_combination_id) into l_rows_loaded
        from s_gl_code_comb_bc
        where job_id = l_job_id
          and code_combination_id is not null;

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
        merge into gl_code_comb_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by code_combination_id
                        order by last_update_date_ts desc nulls last, rowid
                    ) rn
                from s_gl_code_comb_bc s
                where job_id = p_job_id
                  and code_combination_id is not null
            )
            where rn = 1
        ) s
        on (f.code_combination_id = s.code_combination_id)
        when matched then update set
            f.chart_of_accounts_id      = s.chart_of_accounts_id,
            f.account_type              = s.account_type,
            f.enabled_flag              = s.enabled_flag,
            f.detail_budgeting_allowed  = s.detail_budgeting_allowed,
            f.detail_posting_allowed    = s.detail_posting_allowed,
            f.summary_flag              = s.summary_flag,
            f.fund                      = s.fund,
            f.location                  = s.location,
            f.function1                 = s.function1,
            f.grant_code                = s.grant_code,
            f.initiative                = s.initiative,
            f.account                   = s.account,
            f.activity                  = s.activity,
            f.interfund                 = s.interfund,
            f.future1                   = s.future1,
            f.start_date_active_ts      = s.start_date_active_ts,
            f.end_date_active_ts        = s.end_date_active_ts,
            f.last_update_date_ts       = s.last_update_date_ts,
            f.last_extract_run_id       = s.last_extract_run_id,
            f.last_extract_run_ts       = s.last_extract_run_ts
        when not matched then insert (
            code_combination_id,
            chart_of_accounts_id,
            account_type,
            enabled_flag,
            detail_budgeting_allowed,
            detail_posting_allowed,
            summary_flag,
            fund,
            location,
            function1,
            grant_code,
            initiative,
            account,
            activity,
            interfund,
            future1,
            start_date_active_ts,
            end_date_active_ts,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.code_combination_id,
            s.chart_of_accounts_id,
            s.account_type,
            s.enabled_flag,
            s.detail_budgeting_allowed,
            s.detail_posting_allowed,
            s.summary_flag,
            s.fund,
            s.location,
            s.function1,
            s.grant_code,
            s.initiative,
            s.account,
            s.activity,
            s.interfund,
            s.future1,
            s.start_date_active_ts,
            s.end_date_active_ts,
            s.last_update_date_ts,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_gl_code_comb_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'GL_CODE_COMB', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'GL_CODE_COMB', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_gl_code_comb;
/
