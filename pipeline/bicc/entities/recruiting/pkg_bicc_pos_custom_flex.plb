create or replace package body pkg_bicc_pos_custom_flex as

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
        delete from s_pos_custom_flex_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'pos_custom_flex_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_pos_custom_flex_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'pos_custom_flex_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_POS_CUSTOM_FLEX_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_pos_custom_flex_bc (
            job_id,
            pos_dff_id,
            state_position_code,
            desc_state_position_code,
            position_category,
            desc_position_category,
            work_schedule,
            desc_work_schedule,
            payment_schedule,
            desc_payment_schedule,
            stntrt_cptn_ct,
            desc_stntrt_cptn_ct,
            short_description,
            effective_start_raw,
            effective_start_ts,
            effective_end_raw,
            effective_end_ts,
            last_update_date_raw,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,

            -- Position DFF surrogate key
            pkg_bicc_common.safe_to_number(l.S_K_5000),

            -- State Position Code
            l.STATE_POSITION_CODE_,
            l.DESC_STATE_POSITION_CODE_,

            -- Position Category
            l.POSITION_CATEGORY_,
            l.DESC_POSITION_CATEGORY_,

            -- Work Schedule
            l.WORK_SCHEDULE_,
            l.DESC_WORK_SCHEDULE_,

            -- Payment Schedule
            l.PAYMENT_SCHEDULE_,
            l.DESC_PAYMENT_SCHEDULE_,

            -- SOC / Seniority Configuration
            l.STNTRT_CPTN_CT_,
            l.DESC_STNTRT_CPTN_CT_,

            -- Short Description
            l.SHORT_DESCRIPTION_,

            -- Effective dates (keep raw + convert)
            l.S_K_5001,
            pkg_bicc_common.safe_to_timestamp(l.S_K_5001),
            l.S_K_5002,
            pkg_bicc_common.safe_to_timestamp(l.S_K_5002),

            -- Last update date (keep raw + convert)
            l.LASTUPDATEDATE,
            pkg_bicc_common.safe_to_timestamp(l.LASTUPDATEDATE),

            -- Run metadata
            l_run_id,
            systimestamp

        from l_pos_custom_flex_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'POS_CUSTOM_FLEX', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'POS_CUSTOM_FLEX', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct pos_dff_id
            from s_pos_custom_flex_bc
            where job_id = p_job_id
              and pos_dff_id is not null
        ) s
        where not exists (
            select 1 from pos_custom_flex_bc f where f.pos_dff_id = s.pos_dff_id
        );

        select count(*) into l_matched
        from (
            select distinct pos_dff_id
            from s_pos_custom_flex_bc
            where job_id = p_job_id
              and pos_dff_id is not null
        ) s
        where exists (
            select 1 from pos_custom_flex_bc f where f.pos_dff_id = s.pos_dff_id
        );

        select count(*) into p_unchanged_count
        from (
            select
                pos_dff_id,
                state_position_code,
                desc_state_position_code,
                position_category,
                desc_position_category,
                work_schedule,
                desc_work_schedule,
                payment_schedule,
                desc_payment_schedule,
                stntrt_cptn_ct,
                desc_stntrt_cptn_ct,
                short_description
            from (
                select s.*,
                       row_number() over (
                         partition by pos_dff_id
                         order by last_update_date_ts desc nulls last, rowid
                       ) rn
                from s_pos_custom_flex_bc s
                where job_id = p_job_id
                  and pos_dff_id is not null
            )
            where rn = 1
            intersect
            select
                pos_dff_id,
                state_position_code,
                desc_state_position_code,
                position_category,
                desc_position_category,
                work_schedule,
                desc_work_schedule,
                payment_schedule,
                desc_payment_schedule,
                stntrt_cptn_ct,
                desc_stntrt_cptn_ct,
                short_description
            from pos_custom_flex_bc
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
            'POS_CUSTOM_FLEX', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct pos_dff_id) into l_rows_loaded
        from s_pos_custom_flex_bc
        where job_id = l_job_id
          and pos_dff_id is not null;

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
        merge into pos_custom_flex_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by pos_dff_id
                        order by last_update_date_ts desc nulls last, rowid
                    ) rn
                from s_pos_custom_flex_bc s
                where job_id = p_job_id
                  and pos_dff_id is not null
            )
            where rn = 1
        ) s
        on (f.pos_dff_id = s.pos_dff_id)
        when matched then update set
            f.state_position_code      = s.state_position_code,
            f.desc_state_position_code = s.desc_state_position_code,
            f.position_category        = s.position_category,
            f.desc_position_category   = s.desc_position_category,
            f.work_schedule            = s.work_schedule,
            f.desc_work_schedule       = s.desc_work_schedule,
            f.payment_schedule         = s.payment_schedule,
            f.desc_payment_schedule    = s.desc_payment_schedule,
            f.stntrt_cptn_ct           = s.stntrt_cptn_ct,
            f.desc_stntrt_cptn_ct      = s.desc_stntrt_cptn_ct,
            f.short_description        = s.short_description,
            f.effective_start_ts       = s.effective_start_ts,
            f.effective_end_ts         = s.effective_end_ts,
            f.last_update_date_ts      = s.last_update_date_ts,
            f.last_extract_run_id      = s.last_extract_run_id,
            f.last_extract_run_ts      = s.last_extract_run_ts
        when not matched then insert (
            pos_dff_id,
            state_position_code,
            desc_state_position_code,
            position_category,
            desc_position_category,
            work_schedule,
            desc_work_schedule,
            payment_schedule,
            desc_payment_schedule,
            stntrt_cptn_ct,
            desc_stntrt_cptn_ct,
            short_description,
            effective_start_ts,
            effective_end_ts,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.pos_dff_id,
            s.state_position_code,
            s.desc_state_position_code,
            s.position_category,
            s.desc_position_category,
            s.work_schedule,
            s.desc_work_schedule,
            s.payment_schedule,
            s.desc_payment_schedule,
            s.stntrt_cptn_ct,
            s.desc_stntrt_cptn_ct,
            s.short_description,
            s.effective_start_ts,
            s.effective_end_ts,
            s.last_update_date_ts,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_pos_custom_flex_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'POS_CUSTOM_FLEX', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'POS_CUSTOM_FLEX', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_pos_custom_flex;
/
