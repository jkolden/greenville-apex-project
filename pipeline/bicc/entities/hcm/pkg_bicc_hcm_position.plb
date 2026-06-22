create or replace package body pkg_bicc_hcm_position as

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
        delete from s_hcm_position_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/hcm_position_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_hcm_position_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/hcm_position_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_HCM_POSITION_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_hcm_position_bc (
            job_id,
            position_id,
            position_code,
            position_name,
            active_status,
            position_type,
            fte,
            full_part_time,
            standard_working_hours,
            organization_id,
            location_id,
            position_job_id,
            business_unit_id,
            max_persons,
            budgeted_flag,
            hiring_status,
            assignment_category,
            parent_position_code,
            parent_position_name,
            parent_org_name,
            effective_start_raw,
            effective_start_ts,
            effective_end_raw,
            effective_end_ts,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,

            -- Position identity
            pkg_bicc_common.safe_to_number(l.POSITIONID),
            l.POSITIONPEOPOSITIONCODE,
            l.POSITIONTRANSLATIONPEONAME,

            -- Status / Classification
            l.POSITIONPEOACTIVESTATUS,
            l.POSITIONPEOPOSITIONTYPE,
            pkg_bicc_common.safe_to_number(l.POSITIONPEOFTE),
            l.POSITIONPEOFULLPARTTIME,
            pkg_bicc_common.safe_to_number(l.POSITIONPEOSTANDARDWORKINGHOURS),

            -- Organization / Location / Job
            pkg_bicc_common.safe_to_number(l.POSITIONPEOORGANIZATIONID),
            pkg_bicc_common.safe_to_number(l.POSITIONPEOLOCATIONID),
            pkg_bicc_common.safe_to_number(l.POSITIONPEOJOBID),
            pkg_bicc_common.safe_to_number(l.POSITIONPEOBUSINESSUNITID),

            -- Capacity / Budget
            pkg_bicc_common.safe_to_number(l.POSITIONPEOMAXPERSONS),
            l.POSITIONPEOBUDGETEDPOSITIONFLAG,
            l.POSITIONPEOHIRINGSTATUS,
            l.POSITIONPEOASSIGNMENTCATEGORY,

            -- Parent position hierarchy
            l.PARENTPOSITIONPEOPOSITIONCODE,
            l.PARENTPOSITIONTRANSLATIONPEONAME,
            l.PARENTPOSITIONORGUNITTLPEONAME,

            -- Effective dates (keep raw + convert)
            l.EFFECTIVESTARTDATE,
            pkg_bicc_common.safe_to_timestamp(l.EFFECTIVESTARTDATE),
            l.EFFECTIVEENDDATE,
            pkg_bicc_common.safe_to_timestamp(l.EFFECTIVEENDDATE),

            -- Run metadata
            l_run_id,
            systimestamp

        from l_hcm_position_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'HCM_POSITION', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'HCM_POSITION', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
        -- New positions (not in final table)
        select count(*) into p_new_count
        from (
            select distinct position_id
            from s_hcm_position_bc
            where job_id = p_job_id
              and position_id is not null
        ) s
        where not exists (
            select 1 from hcm_position_bc f where f.position_id = s.position_id
        );

        -- Matched positions (exist in final table)
        select count(*) into l_matched
        from (
            select distinct position_id
            from s_hcm_position_bc
            where job_id = p_job_id
              and position_id is not null
        ) s
        where exists (
            select 1 from hcm_position_bc f where f.position_id = s.position_id
        );

        -- Unchanged (identical rows via INTERSECT)
        select count(*) into p_unchanged_count
        from (
            select
                position_id,
                position_code,
                position_name,
                active_status,
                position_type,
                fte,
                full_part_time,
                standard_working_hours,
                organization_id,
                location_id,
                hiring_status,
                assignment_category,
                parent_position_code
            from (
                select s.*,
                       row_number() over (
                         partition by position_id
                         order by effective_start_ts desc nulls last, rowid
                       ) rn
                from s_hcm_position_bc s
                where job_id = p_job_id
                  and position_id is not null
            )
            where rn = 1
            intersect
            select
                position_id,
                position_code,
                position_name,
                active_status,
                position_type,
                fte,
                full_part_time,
                standard_working_hours,
                organization_id,
                location_id,
                hiring_status,
                assignment_category,
                parent_position_code
            from hcm_position_bc
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
            'HCM_POSITION', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct position_id) into l_rows_loaded
        from s_hcm_position_bc
        where job_id = l_job_id
          and position_id is not null;

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
        merge into hcm_position_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by position_id
                        order by effective_start_ts desc nulls last, rowid
                    ) rn
                from s_hcm_position_bc s
                where job_id = p_job_id
                  and position_id is not null
            )
            where rn = 1
        ) s
        on (f.position_id = s.position_id)
        when matched then update set
            f.position_code            = s.position_code,
            f.position_name            = s.position_name,
            f.active_status            = s.active_status,
            f.position_type            = s.position_type,
            f.fte                      = s.fte,
            f.full_part_time           = s.full_part_time,
            f.standard_working_hours   = s.standard_working_hours,
            f.organization_id          = s.organization_id,
            f.location_id              = s.location_id,
            f.position_job_id          = s.position_job_id,
            f.business_unit_id         = s.business_unit_id,
            f.max_persons              = s.max_persons,
            f.budgeted_flag            = s.budgeted_flag,
            f.hiring_status            = s.hiring_status,
            f.assignment_category      = s.assignment_category,
            f.parent_position_code     = s.parent_position_code,
            f.parent_position_name     = s.parent_position_name,
            f.parent_org_name          = s.parent_org_name,
            f.effective_start_ts       = s.effective_start_ts,
            f.effective_end_ts         = s.effective_end_ts,
            f.last_extract_run_id      = s.last_extract_run_id,
            f.last_extract_run_ts      = s.last_extract_run_ts
        when not matched then insert (
            position_id,
            position_code,
            position_name,
            active_status,
            position_type,
            fte,
            full_part_time,
            standard_working_hours,
            organization_id,
            location_id,
            position_job_id,
            business_unit_id,
            max_persons,
            budgeted_flag,
            hiring_status,
            assignment_category,
            parent_position_code,
            parent_position_name,
            parent_org_name,
            effective_start_ts,
            effective_end_ts,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.position_id,
            s.position_code,
            s.position_name,
            s.active_status,
            s.position_type,
            s.fte,
            s.full_part_time,
            s.standard_working_hours,
            s.organization_id,
            s.location_id,
            s.position_job_id,
            s.business_unit_id,
            s.max_persons,
            s.budgeted_flag,
            s.hiring_status,
            s.assignment_category,
            s.parent_position_code,
            s.parent_position_name,
            s.parent_org_name,
            s.effective_start_ts,
            s.effective_end_ts,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_hcm_position_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'HCM_POSITION', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'HCM_POSITION', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_hcm_position;
/
