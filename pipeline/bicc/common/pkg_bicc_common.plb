create or replace package body pkg_bicc_common as

    -- =========================================================================
    -- SAFE TYPE CONVERSIONS
    -- =========================================================================

    function safe_to_number(p_str varchar2) return number is
    begin
        if p_str is null or trim(p_str) is null then
            return null;
        end if;
        return to_number(trim(p_str));
    exception
        when others then
            return null;
    end safe_to_number;

    function safe_to_timestamp(p_str varchar2) return timestamp is
        v varchar2(200) := trim(p_str);
    begin
        if v is null then
            return null;
        end if;

        -- 6/14/2025
        if regexp_like(v, '^\d{1,2}/\d{1,2}/\d{4}$') then
            return to_timestamp(v, 'MM/DD/YYYY');
        end if;

        -- 2025-06-14
        if regexp_like(v, '^\d{4}-\d{2}-\d{2}$') then
            return to_timestamp(v, 'YYYY-MM-DD');
        end if;

        -- 2025-06-14 12:30:44.123
        if regexp_like(v, '^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}(\.\d+)?$') then
            return to_timestamp(v, 'YYYY-MM-DD HH24:MI:SS.FF');
        end if;

        -- 2025-06-14T12:30:44.123Z (or without Z)
        if instr(v, 'T') > 0 then
            v := replace(v, 'T', ' ');
            v := rtrim(v, 'Z');
            if regexp_like(v, '^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}(\.\d+)?$') then
                return to_timestamp(v, 'YYYY-MM-DD HH24:MI:SS.FF');
            end if;
        end if;

        return null;
    exception
        when others then
            return null;
    end safe_to_timestamp;

    -- =========================================================================
    -- EXTRACT CSV FROM ZIP AND UPLOAD TO OBJECT STORAGE
    -- =========================================================================
    -- Reusable across all entities. Each entity passes a different
    -- p_staging_name (e.g., 'staging/hcm_employee_current.csv').
    -- =========================================================================

    procedure extract_and_stage_csv(
        p_file_name    in varchar2,
        p_credential   in varchar2 default gc_credential,
        p_bucket_uri   in varchar2 default gc_bucket_uri,
        p_staging_name in varchar2
    ) is
        l_zip_blob  blob;
        l_csv_blob  blob;
        l_file_list apex_zip.t_files;
        l_csv_name  varchar2(32767);
    begin
        -- Download ZIP from Object Storage
        l_zip_blob := dbms_cloud.get_object(
            credential_name => p_credential,
            object_uri      => p_bucket_uri || p_file_name
        );

        -- Find first CSV in the ZIP
        l_file_list := apex_zip.get_files(p_zipped_blob => l_zip_blob);
        for i in 1 .. l_file_list.count loop
            if lower(l_file_list(i)) like '%.csv' then
                l_csv_name := l_file_list(i);
                exit;
            end if;
        end loop;
        if l_csv_name is null then
            l_csv_name := l_file_list(1);
        end if;

        -- Extract CSV content
        l_csv_blob := apex_zip.get_file_content(
            p_zipped_blob => l_zip_blob,
            p_file_name   => l_csv_name
        );

        -- Upload CSV to staging location so COPY_DATA can read it
        dbms_cloud.put_object(
            credential_name => p_credential,
            object_uri      => p_bucket_uri || p_staging_name,
            contents        => l_csv_blob
        );
    end extract_and_stage_csv;


    -- =========================================================================
    -- REFRESH FILE LIST
    -- =========================================================================
    -- Syncs bicc_files table with files currently in Object Storage
    -- =========================================================================

    procedure refresh_bicc_files is
    begin
        merge into bicc_files t
        using (
            select file_name, load_type
            from bicc_files_v
        ) s
        on (t.file_name = s.file_name)

        when matched then update set
            t.load_type    = s.load_type,
            t.refreshed_ts = systimestamp

        when not matched then insert (
            file_name,
            load_type,
            refreshed_ts
        ) values (
            s.file_name,
            s.load_type,
            systimestamp
        );

        -- Optional cleanup: remove rows for files that no longer exist in Object Storage
        -- delete from bicc_files bf
        -- where not exists (select 1 from bicc_files_v v where v.file_name = bf.file_name);

    end refresh_bicc_files;


    -- =========================================================================
    -- PURGE OLD FILES FROM OBJECT STORAGE
    -- =========================================================================
    -- Deletes ZIP files older than p_retention_days from Object Storage
    -- =========================================================================

    procedure purge_bicc_objectstore(
        p_retention_days in number default 60
    ) is
        l_cutoff   timestamp := systimestamp - numtodsinterval(p_retention_days, 'DAY');
        l_ts_text  varchar2(32);
        l_file_ts  timestamp;
    begin
        for r in (
            select object_name
            from table(dbms_cloud.list_objects(
                credential_name => gc_credential,
                location_uri    => gc_bucket_uri
            ))
            where object_name like '%.zip'
        )
        loop
            -- Parse the timestamp from the filename: -YYYYMMDD_HH24MISS.zip
            l_ts_text := regexp_substr(r.object_name, '-(\d{8}_\d{6})\.zip', 1, 1, 'i', 1);

            -- Safety: only delete objects that match the expected naming pattern.
            if l_ts_text is not null then
                l_file_ts := to_timestamp(l_ts_text, 'YYYYMMDD_HH24MISS');

                if l_file_ts < l_cutoff then
                    dbms_cloud.delete_object(
                        credential_name => gc_credential,
                        object_uri      => gc_bucket_uri || r.object_name
                    );
                end if;
            end if;
        end loop;
    end purge_bicc_objectstore;


    -- =========================================================================
    -- PURGE COPY$ HOUSEKEEPING TABLES
    -- =========================================================================
    -- DBMS_CLOUD.COPY_DATA leaves behind COPY$<id>_LOG and COPY$<id>_BAD
    -- tables after every load. Drop them to prevent schema clutter.
    -- =========================================================================

    procedure purge_copy_tables is
    begin
        for r in (
            select table_name
              from user_tables
             where table_name like 'COPY$%'
        ) loop
            execute immediate 'DROP TABLE "' || r.table_name || '" PURGE';
        end loop;
    end purge_copy_tables;


    -- =========================================================================
    -- DAILY BICC LOAD ORCHESTRATION
    -- =========================================================================
    -- Automatically loads and merges the latest BICC files from "today" (Pacific time)
    -- Called by DBMS_SCHEDULER job
    -- =========================================================================

    procedure run_bicc_daily_today is
        c_pt_tz constant varchar2(64) := 'America/Los_Angeles';

        l_pt_today_date   date;
        l_utc_start_tstz  timestamp with time zone;
        l_utc_end_tstz    timestamp with time zone;
        l_utc_start_ts    timestamp;
        l_utc_end_ts      timestamp;
        l_job_id          number;

    begin
        -- Compute the UTC window that corresponds to "today" in Pacific
        l_pt_today_date  := trunc(cast(systimestamp at time zone c_pt_tz as date));

        l_utc_start_tstz := from_tz(cast(l_pt_today_date as timestamp), c_pt_tz) at time zone 'UTC';
        l_utc_end_tstz   := l_utc_start_tstz + interval '1' day;

        l_utc_start_ts   := cast(l_utc_start_tstz as timestamp); -- UTC timestamp (no tz)
        l_utc_end_ts     := cast(l_utc_end_tstz   as timestamp);

        -- 1) Refresh the file list
        refresh_bicc_files;

        -- 2) Refresh REST-loaded recruiting data (Requisitions, Applications)
        pkg_rest_recruiting.refresh_all;

        -- 3) For each load_type, pick the latest file from "today PT", but only if not already processed
        for r in (
            with candidates as (
                select
                    f.file_name,
                    f.load_type,
                    f.file_timestamp,
                    row_number() over (
                        partition by f.load_type
                        order by f.file_timestamp desc nulls last, f.file_name desc
                    ) rn
                from bicc_files f
                where f.loader_available = 'Y'
                    and f.load_type in ('AP_INVOICE_HDR','PO_HDR','PO_LINES','SUPPLIER_HDR','HCM_EMPLOYEE','HCM_POSITION','HCM_ASSIGNMENT','HCM_SALARY','POS_CUSTOM_FLEX','GL_CODE_COMB','GL_BALANCE','QSTNR_ANSWER','QSTNR_QUESTION','QSTNR_RESPONSE','AP_DISBURSEMENT','AP_INV_APPLICATION')

                    -- look back 1 extra day so the 7 AM job catches files that
                    -- arrived after yesterday's run; dedup checks below prevent
                    -- reprocessing anything already merged/in-flight
                    and f.file_timestamp >= l_utc_start_ts - interval '1' day
                    and f.file_timestamp <  l_utc_end_ts

                    --  exclusions
                    and lower(f.file_name) not like '%poheaderdffpublic%'
                    and lower(f.file_name) not like '%suppliersiteextract%'
                    and lower(f.file_name) not like '%invoiceheaderextract%'
            )
            select c.file_name, c.load_type, c.file_timestamp
            from candidates c
            where c.rn = 1

                -- skip if already merged for this exact file+type
                and not exists (
                    select 1
                    from bicc_load_job j
                    where j.file_name = c.file_name
                        and j.load_type = c.load_type
                        and j.status    = 'MERGED'
                )

                -- skip if already staged/loading/loaded for this exact file+type (avoid duplicate job rows)
                and not exists (
                    select 1
                    from bicc_load_job j
                    where j.file_name = c.file_name
                        and j.load_type = c.load_type
                        and j.status in ('LOADING','STAGED','LOADED')
                )

            order by c.file_timestamp
        )
        loop
            l_job_id := null;

            -- Stage (your functions insert into BICC_LOAD_JOB)
            case r.load_type
                when 'AP_INVOICE_HDR' then l_job_id := pkg_bicc_ap_invoice_hdr.load_and_preview(r.file_name);
                when 'PO_HDR'         then l_job_id := pkg_bicc_po_hdr.load_and_preview(r.file_name);
                when 'PO_LINES'       then l_job_id := pkg_bicc_po_lines.load_and_preview(r.file_name);
                when 'SUPPLIER_HDR'   then l_job_id := pkg_bicc_supplier_hdr.load_and_preview(r.file_name);
                when 'HCM_EMPLOYEE'   then l_job_id := pkg_bicc_hcm_employee.load_and_preview(r.file_name);
                when 'HCM_POSITION'   then l_job_id := pkg_bicc_hcm_position.load_and_preview(r.file_name);
                when 'HCM_ASSIGNMENT'  then l_job_id := pkg_bicc_hcm_assignment.load_and_preview(r.file_name);
                when 'HCM_SALARY'      then l_job_id := pkg_bicc_hcm_salary.load_and_preview(r.file_name);
                when 'POS_CUSTOM_FLEX' then l_job_id := pkg_bicc_pos_custom_flex.load_and_preview(r.file_name);
                when 'GL_CODE_COMB'    then l_job_id := pkg_bicc_gl_code_comb.load_and_preview(r.file_name);
                when 'GL_BALANCE'      then l_job_id := pkg_bicc_gl_balance.load_and_preview(r.file_name);
                when 'QSTNR_ANSWER'   then l_job_id := pkg_bicc_qstnr_answer.load_and_preview(r.file_name);
                when 'QSTNR_QUESTION' then l_job_id := pkg_bicc_qstnr_question.load_and_preview(r.file_name);
                when 'QSTNR_RESPONSE'      then l_job_id := pkg_bicc_qstnr_response.load_and_preview(r.file_name);
                when 'AP_DISBURSEMENT'     then l_job_id := pkg_bicc_ap_disbursement.load_and_preview(r.file_name);
                when 'AP_INV_APPLICATION'  then l_job_id := pkg_bicc_ap_inv_application.load_and_preview(r.file_name);
                else
                    raise_application_error(-20001, 'Unsupported load_type: ' || r.load_type);
            end case;

            -- Merge
            case r.load_type
                when 'AP_INVOICE_HDR' then pkg_bicc_ap_invoice_hdr.merge(p_job_id => l_job_id);
                when 'PO_HDR'         then pkg_bicc_po_hdr.merge(p_job_id => l_job_id);
                when 'PO_LINES'       then pkg_bicc_po_lines.merge(p_job_id => l_job_id);
                when 'SUPPLIER_HDR'   then pkg_bicc_supplier_hdr.merge(p_job_id => l_job_id);
                when 'HCM_EMPLOYEE'   then pkg_bicc_hcm_employee.merge(p_job_id => l_job_id);
                when 'HCM_POSITION'   then pkg_bicc_hcm_position.merge(p_job_id => l_job_id);
                when 'HCM_ASSIGNMENT'  then pkg_bicc_hcm_assignment.merge(p_job_id => l_job_id);
                when 'HCM_SALARY'      then pkg_bicc_hcm_salary.merge(p_job_id => l_job_id);
                when 'POS_CUSTOM_FLEX' then pkg_bicc_pos_custom_flex.merge(p_job_id => l_job_id);
                when 'GL_CODE_COMB'    then pkg_bicc_gl_code_comb.merge(p_job_id => l_job_id);
                when 'GL_BALANCE'      then pkg_bicc_gl_balance.merge(p_job_id => l_job_id);
                when 'QSTNR_ANSWER'   then pkg_bicc_qstnr_answer.merge(p_job_id => l_job_id);
                when 'QSTNR_QUESTION' then pkg_bicc_qstnr_question.merge(p_job_id => l_job_id);
                when 'QSTNR_RESPONSE'     then pkg_bicc_qstnr_response.merge(p_job_id => l_job_id);
                when 'AP_DISBURSEMENT'    then pkg_bicc_ap_disbursement.merge(p_job_id => l_job_id);
                when 'AP_INV_APPLICATION' then pkg_bicc_ap_inv_application.merge(p_job_id => l_job_id);
            end case;

            commit;
        end loop;

        -- Clean up COPY$ housekeeping tables left by DBMS_CLOUD.COPY_DATA
        purge_copy_tables;

    exception
        when others then
            rollback;
            raise;
    end run_bicc_daily_today;

end pkg_bicc_common;
/
