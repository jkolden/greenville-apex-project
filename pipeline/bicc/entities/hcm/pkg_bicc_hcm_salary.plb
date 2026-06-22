create or replace package body pkg_bicc_hcm_salary as

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
        delete from s_hcm_salary_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'hcm_salary_unzipped.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_hcm_salary_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'hcm_salary_unzipped.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_HCM_SALARY_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_hcm_salary_bc (
            job_id,
            salary_id,
            person_id,
            assignment_id,
            assignment_type,
            business_unit_id,
            legal_entity_id,
            hcm_job_id,
            grade_id,
            element_entry_id,
            element_type_id,
            input_value_id,
            salary_amount,
            annual_salary,
            annual_ft_salary,
            currency_code,
            salary_basis_code,
            salary_basis_id,
            salary_basis_type,
            salary_approved,
            salary_factor,
            payroll_factor,
            payroll_frequency_code,
            fte_value,
            salary_transaction_status,
            salary_reason_code,
            component_usage,
            multiple_components,
            action_id,
            action_occurrence_id,
            action_reason_id,
            adjustment_amount,
            adjustment_percent,
            rate_id,
            rate_factor,
            rate_max_amount,
            rate_mid_amount,
            rate_min_amount,
            rate_default_amount,
            range_position,
            comparatio,
            quartile,
            quintile,
            total_base_pay,
            total_component_adj_amt,
            total_component_adj_percent,
            date_from_raw,
            date_from_ts,
            date_to_raw,
            date_to_ts,
            salary_effective_start_raw,
            salary_effective_start_ts,
            salary_effective_end_raw,
            salary_effective_end_ts,
            review_date_raw,
            review_date_ts,
            next_sal_review_raw,
            next_sal_review_ts,
            work_at_home,
            object_version_number,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,

            -- Core IDs
            pkg_bicc_common.safe_to_number(l.SALARYID),
            pkg_bicc_common.safe_to_number(l.PERSONID),
            pkg_bicc_common.safe_to_number(l.ASSIGNMENTID),
            l.ASSIGNMENTTYPE,
            pkg_bicc_common.safe_to_number(l.BUSINESSUNITID),
            pkg_bicc_common.safe_to_number(l.LEGALENTITYID),
            pkg_bicc_common.safe_to_number(l.JOBID),
            pkg_bicc_common.safe_to_number(l.GRADEID),
            pkg_bicc_common.safe_to_number(l.ELEMENTENTRYID),
            pkg_bicc_common.safe_to_number(l.ELEMENTTYPEID),
            pkg_bicc_common.safe_to_number(l.INPUTVALUEID),

            -- Salary amounts
            pkg_bicc_common.safe_to_number(l.SALARYAMOUNT),
            pkg_bicc_common.safe_to_number(l.ANNUALSALARY),
            pkg_bicc_common.safe_to_number(l.ANNUALFTSALARY),
            l.CURRENCYCODE,
            l.SALARYBASISCODE,
            pkg_bicc_common.safe_to_number(l.SALARYBASISID),
            l.SALARYBASISTYPE,
            l.SALARYAPPROVED,
            pkg_bicc_common.safe_to_number(l.SALARYFACTOR),
            pkg_bicc_common.safe_to_number(l.PAYROLLFACTOR),
            l.PAYROLLFREQUENCYCODE,
            pkg_bicc_common.safe_to_number(l.FTEVALUE),
            l.SALARYTRANSACTIONSTATUS,
            l.SALARYREASONCODE,
            l.COMPONENTUSAGE,
            l.MULTIPLECOMPONENTS,

            -- Action
            pkg_bicc_common.safe_to_number(l.ACTIONID),
            pkg_bicc_common.safe_to_number(l.ACTIONOCCURRENCEID),
            pkg_bicc_common.safe_to_number(l.ACTIONREASONID),

            -- Adjustments
            pkg_bicc_common.safe_to_number(l.ADJUSTMENTAMOUNT),
            pkg_bicc_common.safe_to_number(l.ADJUSTMENTPERCENT),

            -- Rate / Range
            pkg_bicc_common.safe_to_number(l.RATEID),
            pkg_bicc_common.safe_to_number(l.RATEFACTOR),
            pkg_bicc_common.safe_to_number(l.RATEMAXAMOUNT),
            pkg_bicc_common.safe_to_number(l.RATEMIDAMOUNT),
            pkg_bicc_common.safe_to_number(l.RATEMINAMOUNT),
            pkg_bicc_common.safe_to_number(l.RATEDEFAULTAMOUNT),
            pkg_bicc_common.safe_to_number(l.RANGEPOSITION),
            pkg_bicc_common.safe_to_number(l.COMPARATIO),
            pkg_bicc_common.safe_to_number(l.QUARTILE),
            pkg_bicc_common.safe_to_number(l.QUINTILE),
            pkg_bicc_common.safe_to_number(l.TOTALBASEPAY),
            pkg_bicc_common.safe_to_number(l.TOTALCOMPONENTADJAMT),
            pkg_bicc_common.safe_to_number(l.TOTALCOMPONENTADJPERCENT),

            -- Dates (raw + converted)
            l.DATEFROM,
            pkg_bicc_common.safe_to_timestamp(l.DATEFROM),
            l.DATETO,
            pkg_bicc_common.safe_to_timestamp(l.DATETO),
            l.SALARYEFFECTIVESTARTDATE,
            pkg_bicc_common.safe_to_timestamp(l.SALARYEFFECTIVESTARTDATE),
            l.SALARYEFFECTIVEENDDATE,
            pkg_bicc_common.safe_to_timestamp(l.SALARYEFFECTIVEENDDATE),
            l.REVIEWDATE,
            pkg_bicc_common.safe_to_timestamp(l.REVIEWDATE),
            l.NEXTSALREVIEWDATE,
            pkg_bicc_common.safe_to_timestamp(l.NEXTSALREVIEWDATE),

            -- Other
            l.WORKATHOME,
            pkg_bicc_common.safe_to_number(l.OBJECTVERSIONNUMBER),

            -- Run metadata
            l_run_id,
            systimestamp

        from l_hcm_salary_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'HCM_SALARY', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'HCM_SALARY', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
        -- New: salary IDs in staging but not in final
        select count(*) into p_new_count
        from (
            select distinct salary_id
            from s_hcm_salary_bc
            where job_id = p_job_id
              and salary_id is not null
        ) s
        where not exists (
            select 1 from hcm_salary_bc f where f.salary_id = s.salary_id
        );

        -- Matched: salary IDs in both staging and final
        select count(*) into l_matched
        from (
            select distinct salary_id
            from s_hcm_salary_bc
            where job_id = p_job_id
              and salary_id is not null
        ) s
        where exists (
            select 1 from hcm_salary_bc f where f.salary_id = s.salary_id
        );

        -- Unchanged: matched rows where key columns are identical
        select count(*) into p_unchanged_count
        from (
            select
                salary_id,
                person_id,
                assignment_id,
                salary_amount,
                annual_salary,
                currency_code,
                salary_basis_code,
                salary_approved,
                salary_transaction_status,
                date_from_ts,
                date_to_ts,
                salary_effective_start_ts,
                salary_effective_end_ts,
                comparatio,
                quartile,
                quintile,
                rate_max_amount,
                rate_mid_amount,
                rate_min_amount
            from (
                select s.*,
                       row_number() over (
                         partition by salary_id
                         order by salary_effective_start_ts desc nulls last, rowid
                       ) rn
                from s_hcm_salary_bc s
                where job_id = p_job_id
                  and salary_id is not null
            )
            where rn = 1
            intersect
            select
                salary_id,
                person_id,
                assignment_id,
                salary_amount,
                annual_salary,
                currency_code,
                salary_basis_code,
                salary_approved,
                salary_transaction_status,
                date_from_ts,
                date_to_ts,
                salary_effective_start_ts,
                salary_effective_end_ts,
                comparatio,
                quartile,
                quintile,
                rate_max_amount,
                rate_mid_amount,
                rate_min_amount
            from hcm_salary_bc
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
            'HCM_SALARY', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct salary_id) into l_rows_loaded
        from s_hcm_salary_bc
        where job_id = l_job_id
          and salary_id is not null;

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
        merge into hcm_salary_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by salary_id
                        order by salary_effective_start_ts desc nulls last, rowid
                    ) rn
                from s_hcm_salary_bc s
                where job_id = p_job_id
                  and salary_id is not null
            )
            where rn = 1
        ) s
        on (f.salary_id = s.salary_id)
        when matched then update set
            f.person_id                    = s.person_id,
            f.assignment_id                = s.assignment_id,
            f.assignment_type              = s.assignment_type,
            f.business_unit_id             = s.business_unit_id,
            f.legal_entity_id              = s.legal_entity_id,
            f.hcm_job_id                   = s.hcm_job_id,
            f.grade_id                     = s.grade_id,
            f.element_entry_id             = s.element_entry_id,
            f.element_type_id              = s.element_type_id,
            f.input_value_id               = s.input_value_id,
            f.salary_amount                = s.salary_amount,
            f.annual_salary                = s.annual_salary,
            f.annual_ft_salary             = s.annual_ft_salary,
            f.currency_code                = s.currency_code,
            f.salary_basis_code            = s.salary_basis_code,
            f.salary_basis_id              = s.salary_basis_id,
            f.salary_basis_type            = s.salary_basis_type,
            f.salary_approved              = s.salary_approved,
            f.salary_factor                = s.salary_factor,
            f.payroll_factor               = s.payroll_factor,
            f.payroll_frequency_code       = s.payroll_frequency_code,
            f.fte_value                    = s.fte_value,
            f.salary_transaction_status    = s.salary_transaction_status,
            f.salary_reason_code           = s.salary_reason_code,
            f.component_usage              = s.component_usage,
            f.multiple_components          = s.multiple_components,
            f.action_id                    = s.action_id,
            f.action_occurrence_id         = s.action_occurrence_id,
            f.action_reason_id             = s.action_reason_id,
            f.adjustment_amount            = s.adjustment_amount,
            f.adjustment_percent           = s.adjustment_percent,
            f.rate_id                      = s.rate_id,
            f.rate_factor                  = s.rate_factor,
            f.rate_max_amount              = s.rate_max_amount,
            f.rate_mid_amount              = s.rate_mid_amount,
            f.rate_min_amount              = s.rate_min_amount,
            f.rate_default_amount          = s.rate_default_amount,
            f.range_position               = s.range_position,
            f.comparatio                   = s.comparatio,
            f.quartile                     = s.quartile,
            f.quintile                     = s.quintile,
            f.total_base_pay               = s.total_base_pay,
            f.total_component_adj_amt      = s.total_component_adj_amt,
            f.total_component_adj_percent  = s.total_component_adj_percent,
            f.date_from_ts                 = s.date_from_ts,
            f.date_to_ts                   = s.date_to_ts,
            f.salary_effective_start_ts    = s.salary_effective_start_ts,
            f.salary_effective_end_ts      = s.salary_effective_end_ts,
            f.review_date_ts               = s.review_date_ts,
            f.next_sal_review_ts           = s.next_sal_review_ts,
            f.work_at_home                 = s.work_at_home,
            f.object_version_number        = s.object_version_number,
            f.last_extract_run_id          = s.last_extract_run_id,
            f.last_extract_run_ts          = s.last_extract_run_ts
        when not matched then insert (
            salary_id,
            person_id,
            assignment_id,
            assignment_type,
            business_unit_id,
            legal_entity_id,
            hcm_job_id,
            grade_id,
            element_entry_id,
            element_type_id,
            input_value_id,
            salary_amount,
            annual_salary,
            annual_ft_salary,
            currency_code,
            salary_basis_code,
            salary_basis_id,
            salary_basis_type,
            salary_approved,
            salary_factor,
            payroll_factor,
            payroll_frequency_code,
            fte_value,
            salary_transaction_status,
            salary_reason_code,
            component_usage,
            multiple_components,
            action_id,
            action_occurrence_id,
            action_reason_id,
            adjustment_amount,
            adjustment_percent,
            rate_id,
            rate_factor,
            rate_max_amount,
            rate_mid_amount,
            rate_min_amount,
            rate_default_amount,
            range_position,
            comparatio,
            quartile,
            quintile,
            total_base_pay,
            total_component_adj_amt,
            total_component_adj_percent,
            date_from_ts,
            date_to_ts,
            salary_effective_start_ts,
            salary_effective_end_ts,
            review_date_ts,
            next_sal_review_ts,
            work_at_home,
            object_version_number,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.salary_id,
            s.person_id,
            s.assignment_id,
            s.assignment_type,
            s.business_unit_id,
            s.legal_entity_id,
            s.hcm_job_id,
            s.grade_id,
            s.element_entry_id,
            s.element_type_id,
            s.input_value_id,
            s.salary_amount,
            s.annual_salary,
            s.annual_ft_salary,
            s.currency_code,
            s.salary_basis_code,
            s.salary_basis_id,
            s.salary_basis_type,
            s.salary_approved,
            s.salary_factor,
            s.payroll_factor,
            s.payroll_frequency_code,
            s.fte_value,
            s.salary_transaction_status,
            s.salary_reason_code,
            s.component_usage,
            s.multiple_components,
            s.action_id,
            s.action_occurrence_id,
            s.action_reason_id,
            s.adjustment_amount,
            s.adjustment_percent,
            s.rate_id,
            s.rate_factor,
            s.rate_max_amount,
            s.rate_mid_amount,
            s.rate_min_amount,
            s.rate_default_amount,
            s.range_position,
            s.comparatio,
            s.quartile,
            s.quintile,
            s.total_base_pay,
            s.total_component_adj_amt,
            s.total_component_adj_percent,
            s.date_from_ts,
            s.date_to_ts,
            s.salary_effective_start_ts,
            s.salary_effective_end_ts,
            s.review_date_ts,
            s.next_sal_review_ts,
            s.work_at_home,
            s.object_version_number,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_hcm_salary_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'HCM_SALARY', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'HCM_SALARY', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_hcm_salary;
/
