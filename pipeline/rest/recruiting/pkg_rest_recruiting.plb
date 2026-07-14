create or replace package body pkg_rest_recruiting as

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
    -- LOAD_REQUISITIONS
    -- =========================================================================
    -- Consolidated loader: paginates recruitingJobRequisitions with
    -- ?expand=requisitionDFF,publishedJobs and MERGEs three tables per page:
    --   1. Parent requisition data  -> JOB_REQUISITIONS_R
    --   2. DFF child resources      -> REQ_DFF_R
    --   3. Published jobs children   -> REQ_PUBLISHED_JOBS_R
    -- Replaces APEX declarative sync + load_requisition_dffs + load_published_jobs.
    -- =========================================================================

    procedure load_requisitions(p_full_refresh in boolean default true) is
        l_url          varchar2(2000);
        l_body         clob;
        l_offset       number := 0;
        l_limit        number := 500;
        l_req_merged   number := 0;
        l_dff_merged   number := 0;
        l_pub_merged   number := 0;
        l_error_msg    varchar2(4000);
        l_date_filter  varchar2(200) := null;
    begin
        -- Incremental: filter by RequisitionLastModifiedDate minus 2-day overlap.
        -- MERGE handles re-processing of overlap records.
        if not p_full_refresh then
            begin
                select to_char(
                           cast(max(requisitionlastmodifieddate) as timestamp) - interval '2' day,
                           'YYYY-MM-DD"T"HH24:MI:SS".000Z"'
                       )
                  into l_date_filter
                  from job_requisitions_r;
            exception
                when others then
                    l_date_filter := null;  -- fall back to full if table empty
            end;
        end if;

        loop
            l_url := pkg_bicc_common.gc_fa_base_url
                || '/hcmRestApi/resources/latest/recruitingJobRequisitions'
                || '?onlyData=true'
                || '&expand=requisitionDFF,publishedJobs'
                || '&limit=' || l_limit
                || '&offset=' || l_offset;

            -- Apply incremental date filter if set
            if l_date_filter is not null then
                l_url := l_url || '&q=RequisitionLastModifiedDate+%3E+%27'
                    || utl_url.escape(
                           replace(l_date_filter, '+00:00', 'Z'),
                           true, 'AL32UTF8')
                    || '%27';
            end if;

            l_body := fetch_json(l_url);

            if apex_web_service.g_status_code < 200
               or apex_web_service.g_status_code >= 300
            then
                raise_application_error(
                    -20001,
                    'REST call failed. HTTP status: ' || apex_web_service.g_status_code
                );
            end if;

            ---------------------------------------------------------
            -- 1. MERGE parent requisitions into JOB_REQUISITIONS_R
            ---------------------------------------------------------
            merge into job_requisitions_r t
            using (
                select
                    jt.requisition_id,
                    jt.requisition_number,
                    jt.title,
                    jt.phase_name,
                    jt.state_name,
                    jt.job_function,
                    jt.internal_published_job_status,
                    jt.external_published_job_status,
                    jt.number_of_openings,
                    jt.hired_count,
                    jt.recruiting_type,
                    jt.full_time_or_part_time,
                    jt.regular_or_temporary,
                    jt.minimum_salary,
                    jt.maximum_salary,
                    jt.compensation_currency,
                    jt.position_id,
                    jt.job_id,
                    jt.grade_id,
                    jt.department_id,
                    jt.primary_work_location_id,
                    jt.primary_location_id,
                    jt.hiring_manager_id,
                    jt.recruiter_id,
                    jt.creation_date,
                    jt.last_update_date,
                    jt.req_last_modified_date,
                    jt.created_by,
                    jt.last_updated_by
                from json_table(l_body, '$.items[*]' columns (
                    requisition_id               number          path '$.RequisitionId',
                    requisition_number           varchar2(240)   path '$.RequisitionNumber',
                    title                        varchar2(240)   path '$.Title',
                    phase_name                   varchar2(240)   path '$.PhaseName',
                    state_name                   varchar2(240)   path '$.StateName',
                    job_function                 varchar2(240)   path '$.JobFunction',
                    internal_published_job_status varchar2(60)   path '$.InternalPublishedJobStatus',
                    external_published_job_status varchar2(60)   path '$.ExternalPublishedJobStatus',
                    number_of_openings           number          path '$.NumberOfOpenings',
                    hired_count                  number          path '$.HiredCount',
                    recruiting_type              varchar2(60)    path '$.RecruitingType',
                    full_time_or_part_time       varchar2(60)    path '$.FullTimeOrPartTime',
                    regular_or_temporary         varchar2(30)    path '$.RegularOrTemporary',
                    minimum_salary               number          path '$.MinimumSalary',
                    maximum_salary               number          path '$.MaximumSalary',
                    compensation_currency        varchar2(30)    path '$.CompensationCurrency',
                    position_id                  number          path '$.PositionId',
                    job_id                       number          path '$.JobId',
                    grade_id                     number          path '$.GradeId',
                    department_id                number          path '$.DepartmentId',
                    primary_work_location_id     number          path '$.PrimaryWorkLocationId',
                    primary_location_id          number          path '$.PrimaryLocationId',
                    hiring_manager_id            number          path '$.HiringManagerId',
                    recruiter_id                 number          path '$.RecruiterId',
                    creation_date                timestamp       path '$.CreationDate',
                    last_update_date             timestamp       path '$.LastUpdateDate',
                    req_last_modified_date       timestamp       path '$.RequisitionLastModifiedDate',
                    created_by                   varchar2(100)   path '$.CreatedBy',
                    last_updated_by              varchar2(100)   path '$.LastUpdatedBy'
                )) jt
                where jt.requisition_id is not null
            ) s on (t.requisitionid = s.requisition_id)
            when matched then update set
                t.requisitionnumber            = s.requisition_number,
                t.title                        = s.title,
                t.phasename                    = s.phase_name,
                t.statename                    = s.state_name,
                t.jobfunction                  = s.job_function,
                t.internalpublishedjobstatus   = s.internal_published_job_status,
                t.externalpublishedjobstatus   = s.external_published_job_status,
                t.numberofopenings             = s.number_of_openings,
                t.hiredcount                   = s.hired_count,
                t.recruitingtype               = s.recruiting_type,
                t.fulltimeorparttime           = s.full_time_or_part_time,
                t.regularortemporary           = s.regular_or_temporary,
                t.minimumsalary                = s.minimum_salary,
                t.maximumsalary                = s.maximum_salary,
                t.compensationcurrency         = s.compensation_currency,
                t.positionid                   = s.position_id,
                t.jobid                        = s.job_id,
                t.gradeid                      = s.grade_id,
                t.departmentid                 = s.department_id,
                t.primaryworklocationid        = s.primary_work_location_id,
                t.primarylocationid            = s.primary_location_id,
                t.hiringmanagerid              = s.hiring_manager_id,
                t.recruiterid                  = s.recruiter_id,
                t.creationdate                 = s.creation_date,
                t.lastupdatedate               = s.last_update_date,
                t.requisitionlastmodifieddate  = s.req_last_modified_date,
                t.createdby                    = s.created_by,
                t.lastupdatedby                = s.last_updated_by,
                t."APEX$ROW_SYNC_TIMESTAMP"    = systimestamp
            when not matched then insert (
                "APEX$RESOURCEKEY",
                requisitionid, requisitionnumber, title,
                phasename, statename, jobfunction,
                internalpublishedjobstatus, externalpublishedjobstatus,
                numberofopenings, hiredcount,
                recruitingtype, fulltimeorparttime, regularortemporary,
                minimumsalary, maximumsalary, compensationcurrency,
                positionid, jobid, gradeid, departmentid,
                primaryworklocationid, primarylocationid,
                hiringmanagerid, recruiterid,
                creationdate, lastupdatedate, requisitionlastmodifieddate,
                createdby, lastupdatedby,
                "APEX$ROW_SYNC_TIMESTAMP"
            ) values (
                to_char(s.requisition_id),
                s.requisition_id, s.requisition_number, s.title,
                s.phase_name, s.state_name, s.job_function,
                s.internal_published_job_status, s.external_published_job_status,
                s.number_of_openings, s.hired_count,
                s.recruiting_type, s.full_time_or_part_time, s.regular_or_temporary,
                s.minimum_salary, s.maximum_salary, s.compensation_currency,
                s.position_id, s.job_id, s.grade_id, s.department_id,
                s.primary_work_location_id, s.primary_location_id,
                s.hiring_manager_id, s.recruiter_id,
                s.creation_date, s.last_update_date, s.req_last_modified_date,
                s.created_by, s.last_updated_by,
                systimestamp
            );

            l_req_merged := l_req_merged + sql%rowcount;

            ---------------------------------------------------------
            -- 2. MERGE DFF child resources into REQ_DFF_R
            ---------------------------------------------------------
            merge into req_dff_r t
            using (
                select
                    jt.requisition_id,
                    jt.transfer_coordinated,
                    jt.vacancy_term_submitted,
                    jt.flex_context
                from json_table(l_body, '$.items[*]' columns (
                    requisition_id        number        path '$.RequisitionId',
                    nested path '$.requisitionDFF[*]' columns (
                        transfer_coordinated  varchar2(10)  path '$.transferCoordinatedWithReceivi',
                        vacancy_term_submitted varchar2(10) path '$.vacancyTerminationFormSubmitte',
                        flex_context          varchar2(240) path '$.__FLEX_Context'
                    )
                )) jt
                where jt.requisition_id is not null
            ) s on (t.requisition_id = s.requisition_id)
            when matched then update set
                t.transfer_coordinated   = nvl(s.transfer_coordinated, t.transfer_coordinated),
                t.vacancy_term_submitted = nvl(s.vacancy_term_submitted, t.vacancy_term_submitted),
                t.flex_context           = nvl(s.flex_context, t.flex_context),
                t.refreshed_ts           = systimestamp
            when not matched then insert (
                requisition_id, transfer_coordinated, vacancy_term_submitted,
                flex_context, refreshed_ts
            ) values (
                s.requisition_id, s.transfer_coordinated, s.vacancy_term_submitted,
                s.flex_context, systimestamp
            );

            l_dff_merged := l_dff_merged + sql%rowcount;

            ---------------------------------------------------------
            -- 3. MERGE published jobs into REQ_PUBLISHED_JOBS_R
            ---------------------------------------------------------
            merge into req_published_jobs_r t
            using (
                select
                    jt.requisition_id,
                    jt.published_visibility,
                    jt.published_posting_status,
                    jt.published_start_date,
                    jt.published_end_date,
                    jt.published_time_zone,
                    jt.published_created_by
                from json_table(l_body, '$.items[*]' columns (
                    requisition_id          number        path '$.RequisitionId',
                    nested path '$.publishedJobs[*]' columns (
                        published_visibility      varchar2(60)  path '$.Visibility',
                        published_posting_status  varchar2(60)  path '$.PostingStatus',
                        published_start_date      timestamp     path '$.StartDate',
                        published_end_date        timestamp     path '$.EndDate',
                        published_time_zone       varchar2(60)  path '$.TimeZone',
                        published_created_by      varchar2(240) path '$.CreatedBy'
                    )
                )) jt
                where jt.requisition_id is not null
                  and jt.published_visibility is not null
            ) s on (t.requisition_id = s.requisition_id
                and t.published_visibility = s.published_visibility)
            when matched then update set
                t.published_posting_status = s.published_posting_status,
                t.published_start_date     = s.published_start_date,
                t.published_end_date       = s.published_end_date,
                t.published_time_zone      = s.published_time_zone,
                t.published_created_by     = s.published_created_by,
                t.refreshed_ts             = systimestamp
            when not matched then insert (
                requisition_id, published_visibility, published_posting_status,
                published_start_date, published_end_date,
                published_time_zone, published_created_by, refreshed_ts
            ) values (
                s.requisition_id, s.published_visibility, s.published_posting_status,
                s.published_start_date, s.published_end_date,
                s.published_time_zone, s.published_created_by, systimestamp
            );

            l_pub_merged := l_pub_merged + sql%rowcount;

            -- Commit after each page to release row locks promptly.
            -- MERGEs are idempotent, so partial progress is safe.
            commit;

            exit when not has_more(l_body);
            l_offset := l_offset + l_limit;
        end loop;

        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'REST_REQUISITIONS', 'REFRESH', l_req_merged, l_req_merged, 'SUCCESS'
        );
        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'REST_REQ_DFF', 'REFRESH', l_dff_merged, l_dff_merged, 'SUCCESS'
        );
        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'REST_PUBLISHED_JOBS', 'REFRESH', l_pub_merged, l_pub_merged, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'REST_REQUISITIONS', 'REFRESH', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end load_requisitions;


    -- =========================================================================
    -- LOAD_CANDIDATES
    -- =========================================================================
    -- Consolidated loader: paginates through recruitingCandidates with
    -- ?expand=candidatePhones and MERGEs both the parent candidate rows
    -- and child phone rows in one pass.
    -- Replaces APEX REST sync + backfill_missing_candidates.
    --
    -- Uses cursor-based pagination to bypass the 10K offset cap:
    --   Outer loop: advances CandLastModifiedDate filter when offset nears cap
    --   Inner loop: standard offset pagination within each date window
    -- Timestamps read as varchar2 and converted explicitly (Fusion REST
    -- timestamps may or may not include fractional seconds).
    -- =========================================================================

    procedure load_candidates(p_full_refresh in boolean default false) is
        l_url          varchar2(2000);
        l_body         clob;
        l_offset       number;
        l_limit        number := 200;
        l_cand_merged  number := 0;
        l_phone_merged number := 0;
        l_pass_rows    number;                  -- rows fetched in current pass
        l_error_msg    varchar2(4000);
        l_date_filter  varchar2(200) := null;   -- CandLastModifiedDate cursor
        l_max_date_txt varchar2(100);            -- max date seen in current pass
        l_page_max     varchar2(100);            -- max date on current page
        l_page_count   number;                   -- rows on current page
        l_pass         number := 0;
    begin
        -- Incremental: start from max CandLastModifiedDate minus 2-day overlap.
        -- NULL = full refresh (first run, empty table, or explicit full refresh).
        -- MERGE handles re-processing of overlap records.
        if not p_full_refresh then
            begin
                select to_char(
                           cast(max(candlastmodifieddate) as timestamp) - interval '2' day,
                           'YYYY-MM-DD"T"HH24:MI:SS".000Z"'
                       )
                  into l_date_filter
                  from recruiting_candidates_r;
            exception
                when others then
                    l_date_filter := null;
            end;
        end if;

        -- Outer loop: each pass covers a date window.
        -- Oracle REST silently returns hasMore=false at 10K offset cap,
        -- so we detect the cap by checking if a pass fetched exactly
        -- limit * 50 (10,000) rows = full cap hit.
        loop
            l_pass      := l_pass + 1;
            l_offset    := 0;
            l_pass_rows := 0;
            l_max_date_txt := null;

            -- Inner loop: offset pagination within the date window
            loop
                l_url := pkg_bicc_common.gc_fa_base_url
                    || '/hcmRestApi/resources/11.13.18.05/recruitingCandidates'
                    || '?expand=candidatePhones'
                    || '&orderBy=CandLastModifiedDate:asc'
                    || '&limit=' || l_limit
                    || '&offset=' || l_offset;

                -- Add date filter (incremental from last run, or cursor advance).
                -- Oracle REST uses > operator (not SCIM "gt").
                -- Replace +00:00 with Z to avoid URL encoding mangling the +.
                if l_date_filter is not null then
                    l_url := l_url || '&q=CandLastModifiedDate+%3E+%27'
                          || utl_url.escape(
                                 replace(l_date_filter, '+00:00', 'Z'),
                                 true
                             ) || '%27';
                end if;

                l_body := fetch_json(l_url);

            if apex_web_service.g_status_code < 200
               or apex_web_service.g_status_code >= 300
            then
                raise_application_error(
                    -20001,
                    'REST call failed. HTTP status: ' || apex_web_service.g_status_code
                );
            end if;

            ---------------------------------------------------------
            -- 1. MERGE parent candidates into RECRUITING_CANDIDATES_R
            ---------------------------------------------------------
            merge into recruiting_candidates_r t
            using (
                select
                    candidate_number,
                    preferred_language,
                    last_name,
                    middle_names,
                    first_name,
                    title,
                    suffix,
                    pre_name_adjunct,
                    known_as,
                    previous_last_name,
                    honors,
                    military_rank,
                    full_name,
                    display_name,
                    list_name,
                    email,
                    campaign_opt_in,
                    source_medium,
                    source_name,
                    candidate_type,
                    person_id,
                    created_by,
                    case
                        when creation_date_txt is null then null
                        when regexp_like(creation_date_txt, '\.\d+') then
                            to_timestamp_tz(creation_date_txt, 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM')
                        else
                            to_timestamp_tz(creation_date_txt, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
                    end creation_date,
                    last_updated_by,
                    case
                        when last_update_date_txt is null then null
                        when regexp_like(last_update_date_txt, '\.\d+') then
                            to_timestamp_tz(last_update_date_txt, 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM')
                        else
                            to_timestamp_tz(last_update_date_txt, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
                    end last_update_date,
                    case
                        when cand_modified_date_txt is null then null
                        when regexp_like(cand_modified_date_txt, '\.\d+') then
                            to_timestamp_tz(cand_modified_date_txt, 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM')
                        else
                            to_timestamp_tz(cand_modified_date_txt, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
                    end cand_last_modified_date,
                    preferred_timezone
                from json_table(l_body, '$.items[*]' columns (
                    candidate_number        varchar2(30)    path '$.CandidateNumber',
                    preferred_language      varchar2(10)    path '$.PreferredLanguage',
                    last_name               varchar2(150)   path '$.LastName',
                    middle_names            varchar2(150)   path '$.MiddleNames',
                    first_name              varchar2(150)   path '$.FirstName',
                    title                   varchar2(30)    path '$.Title',
                    suffix                  varchar2(30)    path '$.Suffix',
                    pre_name_adjunct        varchar2(30)    path '$.PreNameAdjunct',
                    known_as                varchar2(150)   path '$.KnownAs',
                    previous_last_name      varchar2(150)   path '$.PreviousLastName',
                    honors                  varchar2(30)    path '$.Honors',
                    military_rank           varchar2(30)    path '$.MilitaryRank',
                    full_name               varchar2(360)   path '$.FullName',
                    display_name            varchar2(360)   path '$.DisplayName',
                    list_name               varchar2(360)   path '$.ListName',
                    email                   varchar2(240)   path '$.Email',
                    campaign_opt_in         varchar2(10)    path '$.CampaignOptIn',
                    source_medium           varchar2(100)   path '$.SourceMedium',
                    source_name             varchar2(200)   path '$.SourceName',
                    candidate_type          varchar2(60)    path '$.CandidateType',
                    person_id               number          path '$.PersonId',
                    created_by              varchar2(100)   path '$.CreatedBy',
                    creation_date_txt       varchar2(100)   path '$.CreationDate',
                    last_updated_by         varchar2(100)   path '$.LastUpdatedBy',
                    last_update_date_txt    varchar2(100)   path '$.LastUpdateDate',
                    cand_modified_date_txt  varchar2(100)   path '$.CandLastModifiedDate',
                    preferred_timezone      varchar2(60)    path '$.PreferredTimezone'
                ))
                where person_id is not null
            ) s on (t."APEX$RESOURCEKEY" = s.candidate_number)
            when matched then update set
                t.candidatenumber       = s.candidate_number,
                t.preferredlanguage     = s.preferred_language,
                t.lastname              = s.last_name,
                t.middlenames           = s.middle_names,
                t.firstname             = s.first_name,
                t.title                 = s.title,
                t.suffix                = s.suffix,
                t.prenameadjunct        = s.pre_name_adjunct,
                t.knownas               = s.known_as,
                t.previouslastname      = s.previous_last_name,
                t.honors                = s.honors,
                t.militaryrank          = s.military_rank,
                t.fullname              = s.full_name,
                t.displayname           = s.display_name,
                t.listname              = s.list_name,
                t.email                 = s.email,
                t.campaignoptin         = s.campaign_opt_in,
                t.sourcemedium          = s.source_medium,
                t.sourcename            = s.source_name,
                t.candidatetype         = s.candidate_type,
                t.personid              = s.person_id,
                t.createdby             = s.created_by,
                t.creationdate          = s.creation_date,
                t.lastupdatedby         = s.last_updated_by,
                t.lastupdatedate        = s.last_update_date,
                t.candlastmodifieddate  = s.cand_last_modified_date,
                t.preferredtimezone     = s.preferred_timezone,
                t."APEX$ROW_SYNC_TIMESTAMP" = systimestamp
            when not matched then insert (
                "APEX$RESOURCEKEY",
                candidatenumber, preferredlanguage,
                lastname, middlenames, firstname, title, suffix,
                prenameadjunct, knownas, previouslastname, honors,
                militaryrank, fullname, displayname, listname,
                email, campaignoptin, sourcemedium, sourcename,
                candidatetype, personid, createdby, creationdate,
                lastupdatedby, lastupdatedate, candlastmodifieddate,
                preferredtimezone, "APEX$ROW_SYNC_TIMESTAMP"
            ) values (
                s.candidate_number,
                s.candidate_number, s.preferred_language,
                s.last_name, s.middle_names, s.first_name, s.title, s.suffix,
                s.pre_name_adjunct, s.known_as, s.previous_last_name, s.honors,
                s.military_rank, s.full_name, s.display_name, s.list_name,
                s.email, s.campaign_opt_in, s.source_medium, s.source_name,
                s.candidate_type, s.person_id, s.created_by, s.creation_date,
                s.last_updated_by, s.last_update_date, s.cand_last_modified_date,
                s.preferred_timezone, systimestamp
            );

            l_page_count   := sql%rowcount;
            l_cand_merged  := l_cand_merged + l_page_count;
            l_pass_rows    := l_pass_rows + l_page_count;

            ---------------------------------------------------------
            -- 2. MERGE child phones into CANDIDATE_PHONES_R
            ---------------------------------------------------------
            merge into candidate_phones_r t
            using (
                select
                    phone_id,
                    person_id,
                    phone_type,
                    country_code_number,
                    area_code,
                    phone_number,
                    extension,
                    legislation_code,
                    primary_flag,
                    created_by,
                    cast(
                        case
                            when creation_date_txt is null then null
                            when regexp_like(creation_date_txt, '\.\d+') then
                                to_timestamp_tz(creation_date_txt, 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM')
                            else
                                to_timestamp_tz(creation_date_txt, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
                        end
                        as timestamp
                    ) creation_date,
                    last_updated_by,
                    cast(
                        case
                            when last_update_date_txt is null then null
                            when regexp_like(last_update_date_txt, '\.\d+') then
                                to_timestamp_tz(last_update_date_txt, 'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM')
                            else
                                to_timestamp_tz(last_update_date_txt, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
                        end
                        as timestamp
                    ) last_update_date
                from json_table(l_body, '$.items[*]' columns (
                    person_id  number  path '$.PersonId',
                    nested path '$.candidatePhones[*]' columns (
                        phone_id             number        path '$.PhoneId',
                        phone_type           varchar2(30)  path '$.PhoneType',
                        country_code_number  varchar2(10)  path '$.CountryCodeNumber',
                        area_code            varchar2(30)  path '$.AreaCode',
                        phone_number         varchar2(60)  path '$.PhoneNumber',
                        extension            varchar2(30)  path '$.Extension',
                        legislation_code     varchar2(10)  path '$.LegislationCode',
                        primary_flag         varchar2(1)   path '$.PrimaryFlag',
                        created_by           varchar2(240) path '$.CreatedBy',
                        creation_date_txt    varchar2(100) path '$.CreationDate',
                        last_updated_by      varchar2(240) path '$.LastUpdatedBy',
                        last_update_date_txt varchar2(100) path '$.LastUpdateDate'
                    )
                ))
                where phone_id is not null
            ) s on (t.phone_id = s.phone_id)
            when matched then update set
                t.person_id           = s.person_id,
                t.phone_type          = s.phone_type,
                t.country_code_number = s.country_code_number,
                t.area_code           = s.area_code,
                t.phone_number        = s.phone_number,
                t.extension           = s.extension,
                t.legislation_code    = s.legislation_code,
                t.primary_flag        = s.primary_flag,
                t.created_by          = s.created_by,
                t.creation_date       = s.creation_date,
                t.last_updated_by     = s.last_updated_by,
                t.last_update_date    = s.last_update_date,
                t.refreshed_ts        = systimestamp
            when not matched then insert (
                phone_id, person_id, phone_type, country_code_number,
                area_code, phone_number, extension, legislation_code,
                primary_flag, created_by, creation_date,
                last_updated_by, last_update_date, refreshed_ts
            ) values (
                s.phone_id, s.person_id, s.phone_type, s.country_code_number,
                s.area_code, s.phone_number, s.extension, s.legislation_code,
                s.primary_flag, s.created_by, s.creation_date,
                s.last_updated_by, s.last_update_date, systimestamp
            );

            l_phone_merged := l_phone_merged + sql%rowcount;

            -- Commit after each page to release row locks promptly.
            -- MERGEs are idempotent, so partial progress is safe.
            commit;

            -- Track max CandLastModifiedDate on this page for cursor advancement
            begin
                select max(jt.cand_mod)
                  into l_page_max
                  from json_table(l_body, '$.items[*]' columns (
                      cand_mod varchar2(100) path '$.CandLastModifiedDate'
                  )) jt;

                if l_page_max is not null then
                    if l_max_date_txt is null or l_page_max > l_max_date_txt then
                        l_max_date_txt := l_page_max;
                    end if;
                end if;
            exception
                when others then null;  -- non-fatal
            end;

            -- Exit inner loop when API says no more pages
            exit when not has_more(l_body);

            l_offset := l_offset + l_limit;

            end loop;  -- inner (offset) loop

            -- Did this pass hit the 10K cap?
            -- Oracle REST returns hasMore=false at the cap, so we detect it
            -- by checking if we fetched a round 10K rows in this pass.
            if l_pass_rows >= 10000 and l_max_date_txt is not null then
                -- Advance date cursor for next pass
                l_date_filter := l_max_date_txt;
            else
                -- Finished naturally — exit outer loop
                exit;
            end if;

        end loop;  -- outer (date cursor) loop

        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'REST_CANDIDATES', 'REFRESH', l_cand_merged, l_cand_merged, 'SUCCESS'
        );
        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'REST_CAND_PHONES', 'REFRESH', l_phone_merged, l_phone_merged, 'SUCCESS'
        );
        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'REST_CAND_PASSES', 'REFRESH', l_pass, l_pass, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'REST_CANDIDATES', 'REFRESH', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end load_candidates;


    -- =========================================================================
    -- REFRESH ALL
    -- =========================================================================

    procedure refresh_all is
    begin
        load_requisitions;
        load_candidates;
    end refresh_all;

end pkg_rest_recruiting;
/
