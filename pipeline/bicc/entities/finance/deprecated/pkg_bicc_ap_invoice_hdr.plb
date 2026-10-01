create or replace package body pkg_bicc_ap_invoice_hdr as

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
        delete from s_ap_invoice_hdr_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/ap_invoice_hdr_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_ap_invoice_hdr_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/ap_invoice_hdr_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_AP_INVOICE_HDR_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_ap_invoice_hdr_bc (
            job_id,
            invoiceid,
            invoiceheaderinvoicenum,
            invoiceheadervouchernum,
            partypartyname,
            partysitepartysitename,
            invoiceheaderinvoicedate,
            invoiceheadergldate,
            invoiceheadercreationdate,
            invoiceheaderinvoiceamount,
            invoiceheaderinvoicecurrencycode,
            invoiceheaderpaymentcurrencycode,
            invoiceheaderamountpaid,
            invoicehdrvalidationstatuscode,
            invoiceheaderapprovalstatus,
            invoiceheaderpaymentstatusflag,
            invoicehdraccountingstatuscode,
            invoiceheaderinvoicetypelookupcode,
            invoiceheaderpaygrouplookupcode,
            invoiceheadertermsdate,
            invoiceheaderdescription,
            purchaseordersegment1,
            invoiceheadercreatedby,
            invoiceheaderlastupdatedate,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,
            pkg_bicc_common.safe_to_number(l.INVOICEID),
            l.INVOICEHEADERINVOICENUM,
            nullif(trim(l.INVOICEHEADERVOUCHERNUM), ''),
            l.PARTYPARTYNAME,
            l.PARTYSITEPARTYSITENAME,
            cast(pkg_bicc_common.safe_to_timestamp(l.INVOICEHEADERINVOICEDATE) as date),
            cast(pkg_bicc_common.safe_to_timestamp(l.INVOICEHEADERGLDATE) as date),
            pkg_bicc_common.safe_to_timestamp(l.INVOICEHEADERCREATIONDATE),
            pkg_bicc_common.safe_to_number(l.INVOICEHEADERINVOICEAMOUNT),
            l.INVOICEHEADERINVOICECURRENCYCODE,
            l.INVOICEHEADERPAYMENTCURRENCYCODE,
            pkg_bicc_common.safe_to_number(l.INVOICEHEADERAMOUNTPAID),
            l.INVOICEHDRVALIDATIONSTATUSCODE,
            l.INVOICEHEADERAPPROVALSTATUS,
            l.INVOICEHEADERPAYMENTSTATUSFLAG,
            l.INVOICEHDRACCOUNTINGSTATUSCODE,
            l.INVOICEHEADERINVOICETYPELOOKUPCODE,
            nullif(trim(l.INVOICEHEADERPAYGROUPLOOKUPCODE), ''),
            cast(pkg_bicc_common.safe_to_timestamp(l.INVOICEHEADERTERMSDATE) as date),
            nullif(trim(l.INVOICEHEADERDESCRIPTION), ''),
            nullif(trim(l.PURCHASEORDERSEGMENT1), ''),
            l.INVOICEHEADERCREATEDBY,
            pkg_bicc_common.safe_to_timestamp(l.INVOICEHEADERLASTUPDATEDATE),
            l_run_id,
            systimestamp
        from l_ap_invoice_hdr_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'AP_INVOICE_HDR', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'AP_INVOICE_HDR', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct invoiceid
            from s_ap_invoice_hdr_bc
            where job_id = p_job_id
        ) s
        where not exists (
            select 1 from ap_invoice_hdr_bc f where f.invoiceid = s.invoiceid
        );

        select count(*) into l_matched
        from (
            select distinct invoiceid
            from s_ap_invoice_hdr_bc
            where job_id = p_job_id
        ) s
        where exists (
            select 1 from ap_invoice_hdr_bc f where f.invoiceid = s.invoiceid
        );

        select count(*) into p_unchanged_count
        from (
            select
                invoiceid,
                invoiceheaderinvoicenum,
                invoiceheadervouchernum,
                partypartyname,
                partysitepartysitename,
                invoiceheaderinvoicedate,
                invoiceheadergldate,
                invoiceheaderinvoiceamount,
                invoiceheaderinvoicecurrencycode,
                invoiceheaderpaymentcurrencycode,
                invoiceheaderamountpaid,
                invoicehdrvalidationstatuscode,
                invoiceheaderapprovalstatus,
                invoiceheaderpaymentstatusflag,
                invoicehdraccountingstatuscode,
                invoiceheaderinvoicetypelookupcode,
                invoiceheaderpaygrouplookupcode,
                invoiceheadertermsdate,
                invoiceheaderdescription,
                purchaseordersegment1,
                invoiceheadercreatedby
            from (
                select
                    s.*,
                    row_number() over (partition by invoiceid order by rowid) rn
                from s_ap_invoice_hdr_bc s
                where job_id = p_job_id
            )
            where rn = 1
            intersect
            select
                invoiceid,
                invoiceheaderinvoicenum,
                invoiceheadervouchernum,
                partypartyname,
                partysitepartysitename,
                invoiceheaderinvoicedate,
                invoiceheadergldate,
                invoiceheaderinvoiceamount,
                invoiceheaderinvoicecurrencycode,
                invoiceheaderpaymentcurrencycode,
                invoiceheaderamountpaid,
                invoicehdrvalidationstatuscode,
                invoiceheaderapprovalstatus,
                invoiceheaderpaymentstatusflag,
                invoicehdraccountingstatuscode,
                invoiceheaderinvoicetypelookupcode,
                invoiceheaderpaygrouplookupcode,
                invoiceheadertermsdate,
                invoiceheaderdescription,
                purchaseordersegment1,
                invoiceheadercreatedby
            from ap_invoice_hdr_bc
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
            'AP_INVOICE_HDR', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct invoiceid) into l_rows_loaded
        from s_ap_invoice_hdr_bc
        where job_id = l_job_id;

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
        merge into ap_invoice_hdr_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by invoiceid
                        order by rowid
                    ) rn
                from s_ap_invoice_hdr_bc s
                where job_id = p_job_id
            )
            where rn = 1
        ) s
        on (f.invoiceid = s.invoiceid)
        when matched then update set
            f.invoiceheaderinvoicenum          = s.invoiceheaderinvoicenum,
            f.invoiceheadervouchernum          = s.invoiceheadervouchernum,
            f.partypartyname                   = s.partypartyname,
            f.partysitepartysitename           = s.partysitepartysitename,
            f.invoiceheaderinvoicedate         = s.invoiceheaderinvoicedate,
            f.invoiceheadergldate              = s.invoiceheadergldate,
            f.invoiceheadercreationdate        = s.invoiceheadercreationdate,
            f.invoiceheaderinvoiceamount       = s.invoiceheaderinvoiceamount,
            f.invoiceheaderinvoicecurrencycode = s.invoiceheaderinvoicecurrencycode,
            f.invoiceheaderpaymentcurrencycode = s.invoiceheaderpaymentcurrencycode,
            f.invoiceheaderamountpaid          = s.invoiceheaderamountpaid,
            f.invoicehdrvalidationstatuscode   = s.invoicehdrvalidationstatuscode,
            f.invoiceheaderapprovalstatus      = s.invoiceheaderapprovalstatus,
            f.invoiceheaderpaymentstatusflag   = s.invoiceheaderpaymentstatusflag,
            f.invoicehdraccountingstatuscode   = s.invoicehdraccountingstatuscode,
            f.invoiceheaderinvoicetypelookupcode = s.invoiceheaderinvoicetypelookupcode,
            f.invoiceheaderpaygrouplookupcode  = s.invoiceheaderpaygrouplookupcode,
            f.invoiceheadertermsdate           = s.invoiceheadertermsdate,
            f.invoiceheaderdescription         = s.invoiceheaderdescription,
            f.purchaseordersegment1            = s.purchaseordersegment1,
            f.invoiceheadercreatedby           = s.invoiceheadercreatedby,
            f.invoiceheaderlastupdatedate      = s.invoiceheaderlastupdatedate,
            f.last_extract_run_id              = s.last_extract_run_id,
            f.last_extract_run_ts              = s.last_extract_run_ts
        when not matched then insert (
            invoiceid,
            invoiceheaderinvoicenum,
            invoiceheadervouchernum,
            partypartyname,
            partysitepartysitename,
            invoiceheaderinvoicedate,
            invoiceheadergldate,
            invoiceheadercreationdate,
            invoiceheaderinvoiceamount,
            invoiceheaderinvoicecurrencycode,
            invoiceheaderpaymentcurrencycode,
            invoiceheaderamountpaid,
            invoicehdrvalidationstatuscode,
            invoiceheaderapprovalstatus,
            invoiceheaderpaymentstatusflag,
            invoicehdraccountingstatuscode,
            invoiceheaderinvoicetypelookupcode,
            invoiceheaderpaygrouplookupcode,
            invoiceheadertermsdate,
            invoiceheaderdescription,
            purchaseordersegment1,
            invoiceheadercreatedby,
            invoiceheaderlastupdatedate,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.invoiceid,
            s.invoiceheaderinvoicenum,
            s.invoiceheadervouchernum,
            s.partypartyname,
            s.partysitepartysitename,
            s.invoiceheaderinvoicedate,
            s.invoiceheadergldate,
            s.invoiceheadercreationdate,
            s.invoiceheaderinvoiceamount,
            s.invoiceheaderinvoicecurrencycode,
            s.invoiceheaderpaymentcurrencycode,
            s.invoiceheaderamountpaid,
            s.invoicehdrvalidationstatuscode,
            s.invoiceheaderapprovalstatus,
            s.invoiceheaderpaymentstatusflag,
            s.invoicehdraccountingstatuscode,
            s.invoiceheaderinvoicetypelookupcode,
            s.invoiceheaderpaygrouplookupcode,
            s.invoiceheadertermsdate,
            s.invoiceheaderdescription,
            s.purchaseordersegment1,
            s.invoiceheadercreatedby,
            s.invoiceheaderlastupdatedate,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_ap_invoice_hdr_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'AP_INVOICE_HDR', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'AP_INVOICE_HDR', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_ap_invoice_hdr;
/
