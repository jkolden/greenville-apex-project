create or replace package body pkg_bicc_dimensions as

    -- =========================================================================
    -- PRIVATE: FETCH JSON FROM FUSION REST API
    -- =========================================================================

    function fetch_json(p_url in varchar2) return clob is
    begin
        return apex_web_service.make_rest_request(
            p_url                  => p_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_fa_credential
        );
    end fetch_json;


    -- =========================================================================
    -- PRIVATE: CHECK hasMore FROM JSON RESPONSE
    -- =========================================================================

    function has_more(p_body in clob) return boolean is
        l_val varchar2(10);
    begin
        select jt.has_more
        into l_val
        from json_table(p_body, '$' columns (
            has_more varchar2(10) path '$.hasMore'
        )) jt;

        return l_val = 'true';
    exception
        when no_data_found then
            return false;
    end has_more;


    -- =========================================================================
    -- LOAD_JOBS
    -- =========================================================================

    procedure load_jobs is
        l_url       varchar2(1000);
        l_body      clob;
        l_offset    number := 0;
        l_limit     number := 500;
        l_merged    number := 0;
        l_page_rows number := 0;
        l_error_msg varchar2(4000);
    begin
        loop
            l_url := pkg_bicc_common.gc_fa_base_url
                || '/hcmRestApi/resources/11.13.18.05/jobsV2'
                || '?onlyData=true'
                || '&fields=JobId,JobName,JobCode'
                || '&limit=' || l_limit
                || '&offset=' || l_offset;

            l_body := fetch_json(l_url);

            merge into dim_job_r t
            using (
                select jt.job_id, jt.job_name, jt.job_code
                from json_table(l_body, '$.items[*]' columns (
                    job_id   number        path '$.JobId',
                    job_name varchar2(240) path '$.JobName',
                    job_code varchar2(60)  path '$.JobCode'
                )) jt
                where jt.job_id is not null
            ) s on (t.job_id = s.job_id)
            when matched then update set
                t.job_name     = s.job_name,
                t.job_code     = s.job_code,
                t.refreshed_ts = systimestamp
            when not matched then insert (
                job_id, job_name, job_code, refreshed_ts
            ) values (
                s.job_id, s.job_name, s.job_code, systimestamp
            );

            l_page_rows := sql%rowcount;
            l_merged    := l_merged + l_page_rows;

            exit when not has_more(l_body);
            l_offset := l_offset + l_limit;
        end loop;

        commit;

        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'DIM_JOB', 'REFRESH', l_merged, l_merged, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'DIM_JOB', 'REFRESH', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end load_jobs;


    -- =========================================================================
    -- LOAD_GRADES
    -- =========================================================================

    procedure load_grades is
        l_url       varchar2(1000);
        l_body      clob;
        l_offset    number := 0;
        l_limit     number := 500;
        l_merged    number := 0;
        l_page_rows number := 0;
        l_error_msg varchar2(4000);
    begin
        loop
            l_url := pkg_bicc_common.gc_fa_base_url
                || '/hcmRestApi/resources/11.13.18.05/gradesLov'
                || '?onlyData=true'
                || '&fields=GradeId,Name,GradeCode'
                || '&limit=' || l_limit
                || '&offset=' || l_offset;

            l_body := fetch_json(l_url);

            merge into dim_grade_r t
            using (
                select jt.grade_id, jt.grade_name, jt.grade_code
                from json_table(l_body, '$.items[*]' columns (
                    grade_id   number        path '$.GradeId',
                    grade_name varchar2(240) path '$.Name',
                    grade_code varchar2(60)  path '$.GradeCode'
                )) jt
                where jt.grade_id is not null
            ) s on (t.grade_id = s.grade_id)
            when matched then update set
                t.grade_name   = s.grade_name,
                t.grade_code   = s.grade_code,
                t.refreshed_ts = systimestamp
            when not matched then insert (
                grade_id, grade_name, grade_code, refreshed_ts
            ) values (
                s.grade_id, s.grade_name, s.grade_code, systimestamp
            );

            l_page_rows := sql%rowcount;
            l_merged    := l_merged + l_page_rows;

            exit when not has_more(l_body);
            l_offset := l_offset + l_limit;
        end loop;

        commit;

        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'DIM_GRADE', 'REFRESH', l_merged, l_merged, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'DIM_GRADE', 'REFRESH', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end load_grades;


    -- =========================================================================
    -- LOAD_LOCATIONS
    -- =========================================================================

    procedure load_locations is
        l_url       varchar2(1000);
        l_body      clob;
        l_offset    number := 0;
        l_limit     number := 500;
        l_merged    number := 0;
        l_page_rows number := 0;
        l_error_msg varchar2(4000);
    begin
        loop
            l_url := pkg_bicc_common.gc_fa_base_url
                || '/hcmRestApi/resources/11.13.18.05/locationsV2'
                || '?onlyData=true'
                || '&fields=LocationId,LocationName,LocationCode'
                || '&limit=' || l_limit
                || '&offset=' || l_offset;

            l_body := fetch_json(l_url);

            merge into dim_location_r t
            using (
                select jt.location_id, jt.location_name, jt.location_code
                from json_table(l_body, '$.items[*]' columns (
                    location_id   number        path '$.LocationId',
                    location_name varchar2(240) path '$.LocationName',
                    location_code varchar2(60)  path '$.LocationCode'
                )) jt
                where jt.location_id is not null
            ) s on (t.location_id = s.location_id)
            when matched then update set
                t.location_name = s.location_name,
                t.location_code = s.location_code,
                t.refreshed_ts  = systimestamp
            when not matched then insert (
                location_id, location_name, location_code, refreshed_ts
            ) values (
                s.location_id, s.location_name, s.location_code, systimestamp
            );

            l_page_rows := sql%rowcount;
            l_merged    := l_merged + l_page_rows;

            exit when not has_more(l_body);
            l_offset := l_offset + l_limit;
        end loop;

        commit;

        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'DIM_LOCATION', 'REFRESH', l_merged, l_merged, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'DIM_LOCATION', 'REFRESH', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end load_locations;


    -- =========================================================================
    -- LOAD_DEPARTMENTS
    -- =========================================================================
    -- REST endpoint: /hcmRestApi/resources/11.13.18.05/departments
    -- JSON fields: OrganizationId, Name, ActiveStatus, LocationId,
    --              LocationCode, LocationName
    -- =========================================================================

    procedure load_departments is
        l_url       varchar2(1000);
        l_body      clob;
        l_offset    number := 0;
        l_limit     number := 500;
        l_merged    number := 0;
        l_page_rows number := 0;
        l_error_msg varchar2(4000);
    begin
        loop
            l_url := pkg_bicc_common.gc_fa_base_url
                || '/hcmRestApi/resources/11.13.18.05/departments'
                || '?onlyData=true'
                || '&fields=OrganizationId,Name,ActiveStatus,LocationId,LocationCode,LocationName'
                || '&limit=' || l_limit
                || '&offset=' || l_offset;

            l_body := fetch_json(l_url);

            merge into dim_department_r t
            using (
                select jt.department_id, jt.department_name,
                       jt.active_status, jt.location_id,
                       jt.location_code, jt.location_name
                from json_table(l_body, '$.items[*]' columns (
                    department_id   number        path '$.OrganizationId',
                    department_name varchar2(240) path '$.Name',
                    active_status   varchar2(30)  path '$.ActiveStatus',
                    location_id     number        path '$.LocationId',
                    location_code   varchar2(60)  path '$.LocationCode',
                    location_name   varchar2(240) path '$.LocationName'
                )) jt
                where jt.department_id is not null
            ) s on (t.department_id = s.department_id)
            when matched then update set
                t.department_name = s.department_name,
                t.active_status   = s.active_status,
                t.location_id     = s.location_id,
                t.location_code   = s.location_code,
                t.location_name   = s.location_name,
                t.refreshed_ts    = systimestamp
            when not matched then insert (
                department_id, department_name, active_status,
                location_id, location_code, location_name, refreshed_ts
            ) values (
                s.department_id, s.department_name, s.active_status,
                s.location_id, s.location_code, s.location_name, systimestamp
            );

            l_page_rows := sql%rowcount;
            l_merged    := l_merged + l_page_rows;

            exit when not has_more(l_body);
            l_offset := l_offset + l_limit;
        end loop;

        commit;

        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'DIM_DEPARTMENT', 'REFRESH', l_merged, l_merged, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'DIM_DEPARTMENT', 'REFRESH', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end load_departments;


    -- =========================================================================
    -- REFRESH ALL DIMENSIONS
    -- =========================================================================

    procedure refresh_all is
    begin
        load_jobs;
        load_grades;
        load_locations;
        load_departments;
    end refresh_all;

end pkg_bicc_dimensions;
/
