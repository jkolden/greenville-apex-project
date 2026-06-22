create or replace package body pkg_bicc_hcm_assignment as

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
        delete from s_hcm_assignment_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/hcm_assignment_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_hcm_assignment_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/hcm_assignment_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_HCM_ASSIGNMENT_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_hcm_assignment_bc (
            job_id,
            assignment_id,
            person_id,
            position_id,
            assignment_name,
            assignment_number,
            assignment_status_type,
            assignment_type,
            system_person_type,
            normal_hours,
            primary_assignment_flag,
            primary_flag,
            manager_flag,
            business_unit_id,
            organization_id,
            location_id,
            hourly_salaried_code,
            employee_category,
            effective_start_raw,
            effective_start_ts,
            effective_end_raw,
            effective_end_ts,
            effective_sequence,
            effective_latest_change,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,

            -- Assignment identity
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTID),
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTPEOPERSONID),
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTPEOPOSITIONID),

            -- Assignment descriptors
            l.ASSIGNMENTPEOASSIGNMENTNAME,
            l.ASSIGNMENTPEOASSIGNMENTNUMBER,
            l.ASSIGNMENTPEOASSIGNMENTSTATUSTYPE,
            l.ASSIGNMENTPEOASSIGNMENTTYPE,
            l.ASSIGNMENTPEOSYSTEMPERSONTYPE,
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTPEONORMALHOURS),

            -- Flags
            l.ASSIGNMENTPEOPRIMARYASSIGNMENTFLAG,
            l.ASSIGNMENTPEOPRIMARYFLAG,
            l.ASSIGNMENTPEOMANAGERFLAG,

            -- Organization / Location
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTPEOBUSINESSUNITID),
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTPEOORGANIZATIONID),
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTPEOLOCATIONID),

            -- Employment classification
            l.ASSIGNMENTPEOHOURLYSALARIEDCODE,
            l.ASSIGNMENTPEOEMPLOYEECATEGORY,

            -- Effective dates (keep raw + convert)
            l.EFFECTIVESTARTDATE,
            pkg_bicc_common.safe_to_timestamp(l.EFFECTIVESTARTDATE),
            l.EFFECTIVEENDDATE,
            pkg_bicc_common.safe_to_timestamp(l.EFFECTIVEENDDATE),
            pkg_bicc_common.safe_to_number(l.EFFECTIVESEQUENCE),
            l.EFFECTIVELATESTCHANGE,

            -- Run metadata
            l_run_id,
            systimestamp

        from l_hcm_assignment_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'HCM_ASSIGNMENT', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'HCM_ASSIGNMENT', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
        -- New assignments (not in final table)
        select count(*) into p_new_count
        from (
            select distinct assignment_id
            from s_hcm_assignment_bc
            where job_id = p_job_id
              and nvl(effective_latest_change,'N') = 'Y'
              and assignment_id is not null
        ) s
        where not exists (
            select 1 from hcm_assignment_bc f where f.assignment_id = s.assignment_id
        );

        -- Matched assignments (exist in final table)
        select count(*) into l_matched
        from (
            select distinct assignment_id
            from s_hcm_assignment_bc
            where job_id = p_job_id
              and nvl(effective_latest_change,'N') = 'Y'
              and assignment_id is not null
        ) s
        where exists (
            select 1 from hcm_assignment_bc f where f.assignment_id = s.assignment_id
        );

        -- Unchanged (identical rows via INTERSECT)
        select count(*) into p_unchanged_count
        from (
            select
                assignment_id,
                person_id,
                position_id,
                assignment_number,
                assignment_status_type,
                assignment_type,
                normal_hours,
                primary_assignment_flag,
                organization_id,
                location_id,
                employee_category
            from (
                select s.*,
                       row_number() over (
                         partition by assignment_id
                         order by effective_start_ts desc nulls last,
                                  effective_sequence desc nulls last,
                                  rowid
                       ) rn
                from s_hcm_assignment_bc s
                where job_id = p_job_id
                  and nvl(effective_latest_change,'N') = 'Y'
                  and assignment_id is not null
            )
            where rn = 1
            intersect
            select
                assignment_id,
                person_id,
                position_id,
                assignment_number,
                assignment_status_type,
                assignment_type,
                normal_hours,
                primary_assignment_flag,
                organization_id,
                location_id,
                employee_category
            from hcm_assignment_bc
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
            'HCM_ASSIGNMENT', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct assignment_id) into l_rows_loaded
        from s_hcm_assignment_bc
        where job_id = l_job_id
          and assignment_id is not null;

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
        merge into hcm_assignment_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by assignment_id
                        order by effective_start_ts desc nulls last,
                                 effective_sequence desc nulls last,
                                 rowid
                    ) rn
                from s_hcm_assignment_bc s
                where job_id = p_job_id
                  and nvl(effective_latest_change,'N') = 'Y'
                  and assignment_id is not null
            )
            where rn = 1
        ) s
        on (f.assignment_id = s.assignment_id)
        when matched then update set
            f.person_id                = s.person_id,
            f.position_id              = s.position_id,
            f.assignment_name          = s.assignment_name,
            f.assignment_number        = s.assignment_number,
            f.assignment_status_type   = s.assignment_status_type,
            f.assignment_type          = s.assignment_type,
            f.system_person_type       = s.system_person_type,
            f.normal_hours             = s.normal_hours,
            f.primary_assignment_flag  = s.primary_assignment_flag,
            f.primary_flag             = s.primary_flag,
            f.manager_flag             = s.manager_flag,
            f.business_unit_id         = s.business_unit_id,
            f.organization_id          = s.organization_id,
            f.location_id              = s.location_id,
            f.hourly_salaried_code     = s.hourly_salaried_code,
            f.employee_category        = s.employee_category,
            f.effective_start_ts       = s.effective_start_ts,
            f.effective_end_ts         = s.effective_end_ts,
            f.last_extract_run_id      = s.last_extract_run_id,
            f.last_extract_run_ts      = s.last_extract_run_ts
        when not matched then insert (
            assignment_id,
            person_id,
            position_id,
            assignment_name,
            assignment_number,
            assignment_status_type,
            assignment_type,
            system_person_type,
            normal_hours,
            primary_assignment_flag,
            primary_flag,
            manager_flag,
            business_unit_id,
            organization_id,
            location_id,
            hourly_salaried_code,
            employee_category,
            effective_start_ts,
            effective_end_ts,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.assignment_id,
            s.person_id,
            s.position_id,
            s.assignment_name,
            s.assignment_number,
            s.assignment_status_type,
            s.assignment_type,
            s.system_person_type,
            s.normal_hours,
            s.primary_assignment_flag,
            s.primary_flag,
            s.manager_flag,
            s.business_unit_id,
            s.organization_id,
            s.location_id,
            s.hourly_salaried_code,
            s.employee_category,
            s.effective_start_ts,
            s.effective_end_ts,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_hcm_assignment_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'HCM_ASSIGNMENT', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'HCM_ASSIGNMENT', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_hcm_assignment;
/
