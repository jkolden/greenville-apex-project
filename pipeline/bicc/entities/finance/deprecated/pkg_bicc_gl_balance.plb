create or replace package body pkg_bicc_gl_balance as

    -- =========================================================================
    -- LOAD (private)
    -- =========================================================================
    -- Flow: extract_and_stage_csv -> COPY_DATA -> INSERT...SELECT
    -- Composite key: LEDGER_ID + CODE_COMBINATION_ID + CURRENCY_CODE
    --                + ACTUAL_FLAG + PERIOD_NAME
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
        delete from s_gl_balance_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/gl_balance_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_gl_balance_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/gl_balance_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_GL_BALANCE_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_gl_balance_bc (
            job_id,
            ledger_id,
            code_combination_id,
            currency_code,
            actual_flag,
            encumbrance_type_id,
            period_name,
            period_num,
            period_year,
            begin_balance_cr,
            begin_balance_dr,
            begin_balance_cr_beq,
            begin_balance_dr_beq,
            period_net_cr,
            period_net_dr,
            period_net_cr_beq,
            period_net_dr_beq,
            quarter_to_date_cr,
            quarter_to_date_dr,
            quarter_to_date_cr_beq,
            quarter_to_date_dr_beq,
            project_to_date_cr,
            project_to_date_dr,
            project_to_date_cr_beq,
            project_to_date_dr_beq,
            last_update_date_raw,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,

            -- Keys
            pkg_bicc_common.safe_to_number(l.BALANCELEDGERID),
            pkg_bicc_common.safe_to_number(l.BALANCECODECOMBINATIONID),
            l.BALANCECURRENCYCODE,
            l.BALANCEACTUALFLAG,
            pkg_bicc_common.safe_to_number(l.BALANCEENCUMBRANCETYPEID),

            -- Period
            l.BALANCEPERIODNAME,
            pkg_bicc_common.safe_to_number(l.BALANCEPERIODNUM),
            pkg_bicc_common.safe_to_number(l.BALANCEPERIODYEAR),

            -- Begin balances (entered + base equivalent)
            pkg_bicc_common.safe_to_number(l.BALANCEBEGINBALANCECR),
            pkg_bicc_common.safe_to_number(l.BALANCEBEGINBALANCEDR),
            pkg_bicc_common.safe_to_number(l.BALANCEBEGINBALANCECRBEQ),
            pkg_bicc_common.safe_to_number(l.BALANCEBEGINBALANCEDRBEQ),

            -- Period net (entered + base equivalent)
            pkg_bicc_common.safe_to_number(l.BALANCEPERIODNETCR),
            pkg_bicc_common.safe_to_number(l.BALANCEPERIODNETDR),
            pkg_bicc_common.safe_to_number(l.BALANCEPERIODNETCRBEQ),
            pkg_bicc_common.safe_to_number(l.BALANCEPERIODNETDRBEQ),

            -- Quarter to date (entered + base equivalent)
            pkg_bicc_common.safe_to_number(l.BALANCEQUARTERTODATECR),
            pkg_bicc_common.safe_to_number(l.BALANCEQUARTERTODATEDR),
            pkg_bicc_common.safe_to_number(l.BALANCEQUARTERTODATECRBEQ),
            pkg_bicc_common.safe_to_number(l.BALANCEQUARTERTODATEDRBEQ),

            -- Project to date (entered + base equivalent)
            pkg_bicc_common.safe_to_number(l.BALANCEPROJECTTODATECR),
            pkg_bicc_common.safe_to_number(l.BALANCEPROJECTTODATEDR),
            pkg_bicc_common.safe_to_number(l.BALANCEPROJECTTODATECRBEQ),
            pkg_bicc_common.safe_to_number(l.BALANCEPROJECTTODATEDRBEQ),

            -- Dates (raw + timestamp)
            l.BALANCELASTUPDATEDATE,
            pkg_bicc_common.safe_to_timestamp(l.BALANCELASTUPDATEDATE),

            -- Run metadata
            l_run_id,
            systimestamp

        from l_gl_balance_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'GL_BALANCE', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'GL_BALANCE', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct ledger_id, code_combination_id, currency_code,
                   actual_flag, period_name
            from s_gl_balance_bc
            where job_id = p_job_id
              and code_combination_id is not null
        ) s
        where not exists (
            select 1 from gl_balance_bc f
            where f.ledger_id           = s.ledger_id
              and f.code_combination_id = s.code_combination_id
              and f.currency_code       = s.currency_code
              and f.actual_flag         = s.actual_flag
              and f.period_name         = s.period_name
        );

        select count(*) into l_matched
        from (
            select distinct ledger_id, code_combination_id, currency_code,
                   actual_flag, period_name
            from s_gl_balance_bc
            where job_id = p_job_id
              and code_combination_id is not null
        ) s
        where exists (
            select 1 from gl_balance_bc f
            where f.ledger_id           = s.ledger_id
              and f.code_combination_id = s.code_combination_id
              and f.currency_code       = s.currency_code
              and f.actual_flag         = s.actual_flag
              and f.period_name         = s.period_name
        );

        select count(*) into p_unchanged_count
        from (
            select
                ledger_id,
                code_combination_id,
                currency_code,
                actual_flag,
                encumbrance_type_id,
                period_name,
                period_num,
                period_year,
                begin_balance_cr,
                begin_balance_dr,
                begin_balance_cr_beq,
                begin_balance_dr_beq,
                period_net_cr,
                period_net_dr,
                period_net_cr_beq,
                period_net_dr_beq,
                quarter_to_date_cr,
                quarter_to_date_dr,
                quarter_to_date_cr_beq,
                quarter_to_date_dr_beq,
                project_to_date_cr,
                project_to_date_dr,
                project_to_date_cr_beq,
                project_to_date_dr_beq,
                last_update_date_ts
            from (
                select s.*,
                       row_number() over (
                         partition by ledger_id, code_combination_id,
                                      currency_code, actual_flag, period_name
                         order by last_update_date_ts desc nulls last, rowid
                       ) rn
                from s_gl_balance_bc s
                where job_id = p_job_id
                  and code_combination_id is not null
            )
            where rn = 1
            intersect
            select
                ledger_id,
                code_combination_id,
                currency_code,
                actual_flag,
                encumbrance_type_id,
                period_name,
                period_num,
                period_year,
                begin_balance_cr,
                begin_balance_dr,
                begin_balance_cr_beq,
                begin_balance_dr_beq,
                period_net_cr,
                period_net_dr,
                period_net_cr_beq,
                period_net_dr_beq,
                quarter_to_date_cr,
                quarter_to_date_dr,
                quarter_to_date_cr_beq,
                quarter_to_date_dr_beq,
                project_to_date_cr,
                project_to_date_dr,
                project_to_date_cr_beq,
                project_to_date_dr_beq,
                last_update_date_ts
            from gl_balance_bc
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
            'GL_BALANCE', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(*) into l_rows_loaded
        from (
            select distinct ledger_id, code_combination_id, currency_code,
                   actual_flag, period_name
            from s_gl_balance_bc
            where job_id = l_job_id
              and code_combination_id is not null
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
        merge into gl_balance_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by ledger_id, code_combination_id,
                                     currency_code, actual_flag, period_name
                        order by last_update_date_ts desc nulls last, rowid
                    ) rn
                from s_gl_balance_bc s
                where job_id = p_job_id
                  and code_combination_id is not null
            )
            where rn = 1
        ) s
        on (    f.ledger_id           = s.ledger_id
            and f.code_combination_id = s.code_combination_id
            and f.currency_code       = s.currency_code
            and f.actual_flag         = s.actual_flag
            and f.period_name         = s.period_name)
        when matched then update set
            f.encumbrance_type_id      = s.encumbrance_type_id,
            f.period_num               = s.period_num,
            f.period_year              = s.period_year,
            f.begin_balance_cr         = s.begin_balance_cr,
            f.begin_balance_dr         = s.begin_balance_dr,
            f.begin_balance_cr_beq     = s.begin_balance_cr_beq,
            f.begin_balance_dr_beq     = s.begin_balance_dr_beq,
            f.period_net_cr            = s.period_net_cr,
            f.period_net_dr            = s.period_net_dr,
            f.period_net_cr_beq        = s.period_net_cr_beq,
            f.period_net_dr_beq        = s.period_net_dr_beq,
            f.quarter_to_date_cr       = s.quarter_to_date_cr,
            f.quarter_to_date_dr       = s.quarter_to_date_dr,
            f.quarter_to_date_cr_beq   = s.quarter_to_date_cr_beq,
            f.quarter_to_date_dr_beq   = s.quarter_to_date_dr_beq,
            f.project_to_date_cr       = s.project_to_date_cr,
            f.project_to_date_dr       = s.project_to_date_dr,
            f.project_to_date_cr_beq   = s.project_to_date_cr_beq,
            f.project_to_date_dr_beq   = s.project_to_date_dr_beq,
            f.last_update_date_ts      = s.last_update_date_ts,
            f.last_extract_run_id      = s.last_extract_run_id,
            f.last_extract_run_ts      = s.last_extract_run_ts
        when not matched then insert (
            ledger_id,
            code_combination_id,
            currency_code,
            actual_flag,
            encumbrance_type_id,
            period_name,
            period_num,
            period_year,
            begin_balance_cr,
            begin_balance_dr,
            begin_balance_cr_beq,
            begin_balance_dr_beq,
            period_net_cr,
            period_net_dr,
            period_net_cr_beq,
            period_net_dr_beq,
            quarter_to_date_cr,
            quarter_to_date_dr,
            quarter_to_date_cr_beq,
            quarter_to_date_dr_beq,
            project_to_date_cr,
            project_to_date_dr,
            project_to_date_cr_beq,
            project_to_date_dr_beq,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.ledger_id,
            s.code_combination_id,
            s.currency_code,
            s.actual_flag,
            s.encumbrance_type_id,
            s.period_name,
            s.period_num,
            s.period_year,
            s.begin_balance_cr,
            s.begin_balance_dr,
            s.begin_balance_cr_beq,
            s.begin_balance_dr_beq,
            s.period_net_cr,
            s.period_net_dr,
            s.period_net_cr_beq,
            s.period_net_dr_beq,
            s.quarter_to_date_cr,
            s.quarter_to_date_dr,
            s.quarter_to_date_cr_beq,
            s.quarter_to_date_dr_beq,
            s.project_to_date_cr,
            s.project_to_date_dr,
            s.project_to_date_cr_beq,
            s.project_to_date_dr_beq,
            s.last_update_date_ts,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_gl_balance_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'GL_BALANCE', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'GL_BALANCE', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_gl_balance;
/
