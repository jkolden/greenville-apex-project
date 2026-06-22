create or replace package body pkg_bicc_hcm_employee as

    -- =========================================================================
    -- LOAD (private)
    -- =========================================================================
    -- Flow: extract_and_stage_csv → COPY_DATA → INSERT...SELECT
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
        delete from s_hcm_employee_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/hcm_employee_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_hcm_employee_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/hcm_employee_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_HCM_EMPLOYEE_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_hcm_employee_bc (
            job_id,
            person_id,
            person_number,
            display_name,
            first_name,
            last_name,
            known_as,
            legislation_code,
            user_name,
            user_suspended_flag,
            work_email,
            person_type,
            hire_date_raw,
            hire_date_ts,
            termination_date_raw,
            termination_date_ts,
            assignment_id,
            assignment_number,
            assignment_name,
            assignment_status_type,
            assignment_type,
            employment_category,
            full_part_time,
            hourly_salaried_code,
            normal_hours,
            asg_effective_start_raw,
            asg_effective_start_ts,
            asg_effective_end_raw,
            asg_effective_end_ts,
            effective_latest_change_flag,
            primary_assignment_flag,
            primary_work_rel_flag,
            position_code,
            position_name,
            org_id,
            org_name,
            location_name,
            addr_city,
            addr_state,
            addr_postal_code,
            addr_country,
            manager_person_id,
            manager_display_name,
            manager_email,
            manager_user_name,
            manager_type,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,

            -- Person / Name
            pkg_bicc_common.safe_to_number(l.PERSONID),
            coalesce(l.PERSONDETAILSPEOPERSONNUMBER, l.PERSONDETAILSPEO1PERSONNUMBER),
            coalesce(l.PERSONNAMEPEODISPLAYNAME, l.PERSONNAMEPEOFULLNAME),
            l.PERSONNAMEPEOFIRSTNAME,
            l.PERSONNAMEPEOLASTNAME,
            l.PERSONNAMEPEOKNOWNAS,
            l.PERSONNAMEPEOLEGISLATIONCODE,

            -- User / Email
            l.USERPEOUSERNAME,
            l.USERPEOSUSPENDED,
            coalesce(l.WORKEMAILADDRESSESPEOEMAILADDRESS, l.EMAILADDRESSESPEOEMAILADDRESS),

            -- Person Type
            l.PERSONTYPESTRANSLATIONPEOUSERPERSONTYPE,

            -- Hire / Termination (keep raw + convert)
            l.PERIODOFSERVICEPEODATESTART,
            pkg_bicc_common.safe_to_timestamp(l.PERIODOFSERVICEPEODATESTART),
            l.PERIODOFSERVICEPEOACTUALTERMINATIONDATE,
            pkg_bicc_common.safe_to_timestamp(l.PERIODOFSERVICEPEOACTUALTERMINATIONDATE),

            -- Assignment
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTPEOASSIGNMENTID),
            l.ASSIGNMENTPEOASSIGNMENTNUMBER,
            l.ASSIGNMENTPEOASSIGNMENTNAME,
            l.ASSIGNMENTPEOASSIGNMENTSTATUSTYPE,
            l.ASSIGNMENTPEOASSIGNMENTTYPE,
            l.ASSIGNMENTPEOEMPLOYMENTCATEGORY,
            l.ASSIGNMENTPEOFULLPARTTIME,
            l.ASSIGNMENTPEOHOURLYSALARIEDCODE,
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTPEONORMALHOURS),

            l.ASSIGNMENTPEOEFFECTIVESTARTDATE,
            pkg_bicc_common.safe_to_timestamp(l.ASSIGNMENTPEOEFFECTIVESTARTDATE),
            l.ASSIGNMENTPEOEFFECTIVEENDDATE,
            pkg_bicc_common.safe_to_timestamp(l.ASSIGNMENTPEOEFFECTIVEENDDATE),

            l.ASSIGNMENTPEOEFFECTIVELATESTCHANGE,
            l.ASSIGNMENTPEOPRIMARYASSIGNMENTFLAG,
            l.ASSIGNMENTPEOPRIMARYWORKRELATIONFLAG,

            -- Position / Org / Location
            l.POSITIONMGRPEOPOSITIONCODE,
            l.POSITIONTRANSLATIONMGRPEONAME,
            pkg_bicc_common.safe_to_number(l.ORGANIZATIONUNITPEOORGANIZATIONID),
            l.ORGUNITTRANSLATIONMGRPEONAME,
            l.LOCATIONDETAILSMGRPEOLOCATIONNAME,

            -- Address
            l.ADDRESSESPEOTOWNORCITY,
            l.ADDRESSESPEOREGION2,
            l.ADDRESSESPEOPOSTALCODE,
            l.ADDRESSESPEOCOUNTRY,

            -- Manager
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTSUPERVISORPEOMANAGERID),
            l.SUPERVISORNAMEPEODISPLAYNAME,
            l.SUPERVISOREMAILADDRESSPEOEMAILADDRESS,
            l.SUPERVISORUSERPEOUSERNAME,
            l.ASSIGNMENTSUPERVISORPEOMANAGERTYPE,

            -- Run metadata
            l_run_id,
            systimestamp

        from l_hcm_employee_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'HCM_EMPLOYEE', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'HCM_EMPLOYEE', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct person_id
            from s_hcm_employee_bc
            where job_id = p_job_id
              and nvl(primary_assignment_flag,'N') = 'Y'
              and nvl(effective_latest_change_flag,'N') = 'Y'
              and person_id is not null
        ) s
        where not exists (
            select 1 from hcm_employee_bc f where f.person_id = s.person_id
        );

        select count(*) into l_matched
        from (
            select distinct person_id
            from s_hcm_employee_bc
            where job_id = p_job_id
              and nvl(primary_assignment_flag,'N') = 'Y'
              and nvl(effective_latest_change_flag,'N') = 'Y'
              and person_id is not null
        ) s
        where exists (
            select 1 from hcm_employee_bc f where f.person_id = s.person_id
        );

        select count(*) into p_unchanged_count
        from (
            select
                person_id,
                person_number,
                display_name,
                work_email,
                user_name,
                user_suspended_flag,
                person_type,
                hire_date_ts,
                termination_date_ts,
                assignment_id,
                assignment_number,
                assignment_name,
                assignment_status_type,
                employment_category,
                full_part_time,
                hourly_salaried_code,
                normal_hours,
                position_code,
                position_name,
                org_name,
                location_name,
                manager_display_name,
                manager_email,
                manager_type
            from (
                select s.*,
                       row_number() over (
                         partition by person_id
                         order by asg_effective_start_ts desc nulls last, rowid
                       ) rn
                from s_hcm_employee_bc s
                where job_id = p_job_id
                  and nvl(primary_assignment_flag,'N') = 'Y'
                  and nvl(effective_latest_change_flag,'N') = 'Y'
                  and person_id is not null
            )
            where rn = 1
            intersect
            select
                person_id,
                person_number,
                display_name,
                work_email,
                user_name,
                user_suspended_flag,
                person_type,
                hire_date_ts,
                termination_date_ts,
                assignment_id,
                assignment_number,
                assignment_name,
                assignment_status_type,
                employment_category,
                full_part_time,
                hourly_salaried_code,
                normal_hours,
                position_code,
                position_name,
                org_name,
                location_name,
                manager_display_name,
                manager_email,
                manager_type
            from hcm_employee_bc
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
            'HCM_EMPLOYEE', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct person_id) into l_rows_loaded
        from s_hcm_employee_bc
        where job_id = l_job_id
          and person_id is not null;

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
        merge into hcm_employee_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by person_id
                        order by asg_effective_start_ts desc nulls last, rowid
                    ) rn
                from s_hcm_employee_bc s
                where job_id = p_job_id
                  and nvl(primary_assignment_flag,'N') = 'Y'
                  and nvl(effective_latest_change_flag,'N') = 'Y'
                  and person_id is not null
            )
            where rn = 1
        ) s
        on (f.person_id = s.person_id)
        when matched then update set
            f.person_number            = s.person_number,
            f.display_name             = s.display_name,
            f.first_name               = s.first_name,
            f.last_name                = s.last_name,
            f.known_as                 = s.known_as,
            f.legislation_code         = s.legislation_code,
            f.user_name                = s.user_name,
            f.user_suspended_flag      = s.user_suspended_flag,
            f.work_email               = s.work_email,
            f.person_type              = s.person_type,
            f.hire_date_ts             = s.hire_date_ts,
            f.termination_date_ts      = s.termination_date_ts,
            f.assignment_id            = s.assignment_id,
            f.assignment_number        = s.assignment_number,
            f.assignment_name          = s.assignment_name,
            f.assignment_status_type   = s.assignment_status_type,
            f.assignment_type          = s.assignment_type,
            f.employment_category      = s.employment_category,
            f.full_part_time           = s.full_part_time,
            f.hourly_salaried_code     = s.hourly_salaried_code,
            f.normal_hours             = s.normal_hours,
            f.asg_effective_start_ts   = s.asg_effective_start_ts,
            f.asg_effective_end_ts     = s.asg_effective_end_ts,
            f.position_code            = s.position_code,
            f.position_name            = s.position_name,
            f.org_id                   = s.org_id,
            f.org_name                 = s.org_name,
            f.location_name            = s.location_name,
            f.addr_city                = s.addr_city,
            f.addr_state               = s.addr_state,
            f.addr_postal_code         = s.addr_postal_code,
            f.addr_country             = s.addr_country,
            f.manager_person_id        = s.manager_person_id,
            f.manager_display_name     = s.manager_display_name,
            f.manager_email            = s.manager_email,
            f.manager_user_name        = s.manager_user_name,
            f.manager_type             = s.manager_type,
            f.last_extract_run_id      = s.last_extract_run_id,
            f.last_extract_run_ts      = s.last_extract_run_ts
        when not matched then insert (
            person_id,
            person_number,
            display_name,
            first_name,
            last_name,
            known_as,
            legislation_code,
            user_name,
            user_suspended_flag,
            work_email,
            person_type,
            hire_date_ts,
            termination_date_ts,
            assignment_id,
            assignment_number,
            assignment_name,
            assignment_status_type,
            assignment_type,
            employment_category,
            full_part_time,
            hourly_salaried_code,
            normal_hours,
            asg_effective_start_ts,
            asg_effective_end_ts,
            position_code,
            position_name,
            org_id,
            org_name,
            location_name,
            addr_city,
            addr_state,
            addr_postal_code,
            addr_country,
            manager_person_id,
            manager_display_name,
            manager_email,
            manager_user_name,
            manager_type,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.person_id,
            s.person_number,
            s.display_name,
            s.first_name,
            s.last_name,
            s.known_as,
            s.legislation_code,
            s.user_name,
            s.user_suspended_flag,
            s.work_email,
            s.person_type,
            s.hire_date_ts,
            s.termination_date_ts,
            s.assignment_id,
            s.assignment_number,
            s.assignment_name,
            s.assignment_status_type,
            s.assignment_type,
            s.employment_category,
            s.full_part_time,
            s.hourly_salaried_code,
            s.normal_hours,
            s.asg_effective_start_ts,
            s.asg_effective_end_ts,
            s.position_code,
            s.position_name,
            s.org_id,
            s.org_name,
            s.location_name,
            s.addr_city,
            s.addr_state,
            s.addr_postal_code,
            s.addr_country,
            s.manager_person_id,
            s.manager_display_name,
            s.manager_email,
            s.manager_user_name,
            s.manager_type,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_hcm_employee_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'HCM_EMPLOYEE', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'HCM_EMPLOYEE', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_hcm_employee;
/
