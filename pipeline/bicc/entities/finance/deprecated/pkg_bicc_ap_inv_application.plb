create or replace package body pkg_bicc_ap_inv_application as

    -- =========================================================================
    -- LOAD (private)
    -- =========================================================================
    -- Flow: extract_and_stage_csv -> COPY_DATA -> INSERT...SELECT
    -- PK: INVOICE_PAYMENT_ID
    -- Bridge: INVOICE_ID <-> CHECK_ID (disbursement)
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
        delete from s_ap_inv_application_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/ap_inv_application_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_ap_inv_application_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/ap_inv_application_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_AP_INV_APPLICATION_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_ap_inv_application_bc (
            job_id,
            invoice_payment_id,
            invoice_id,
            check_id,
            payment_num,
            amount,
            amount_inv_curr,
            invoice_base_amount,
            payment_base_amount,
            invoice_currency_code,
            payment_currency_code,
            invoice_payment_type,
            discount_taken,
            discount_lost,
            accounting_date_raw,
            accounting_date_ts,
            period_name,
            posted_flag,
            reversal_flag,
            reversal_inv_pmt_id,
            org_id,
            exchange_rate,
            exchange_date_raw,
            exchange_date_ts,
            exchange_rate_type,
            accts_pay_ccid,
            remit_to_supplier_name,
            creation_date_raw,
            creation_date_ts,
            last_update_date_raw,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,

            -- Keys
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLINVOICEPAYMENTID),
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLINVOICEID),
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLCHECKID),
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLPAYMENTNUM),

            -- Amounts
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLAMOUNT),
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLAMOUNTINVCURR),
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLINVOICEBASEAMOUNT),
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLPAYMENTBASEAMOUNT),

            -- Currency
            l.APINVOICEPAYMENTSALLINVOICECURRENCYCODE,
            l.APINVOICEPAYMENTSALLPAYMENTCURRENCYCODE,
            l.APINVOICEPAYMENTSALLINVOICEPAYMENTTYPE,

            -- Discounts
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLDISCOUNTTAKEN),
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLDISCOUNTLOST),

            -- Accounting
            l.APINVOICEPAYMENTSALLACCOUNTINGDATE,
            pkg_bicc_common.safe_to_timestamp(l.APINVOICEPAYMENTSALLACCOUNTINGDATE),
            l.APINVOICEPAYMENTSALLPERIODNAME,
            l.APINVOICEPAYMENTSALLPOSTEDFLAG,

            -- Reversal
            l.APINVOICEPAYMENTSALLREVERSALFLAG,
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLREVERSALINVPMTID),

            -- Org
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLORGID),

            -- Exchange
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLEXCHANGERATE),
            l.APINVOICEPAYMENTSALLEXCHANGEDATE,
            pkg_bicc_common.safe_to_timestamp(l.APINVOICEPAYMENTSALLEXCHANGEDATE),
            l.APINVOICEPAYMENTSALLEXCHANGERATETYPE,

            -- Code combination
            pkg_bicc_common.safe_to_number(l.APINVOICEPAYMENTSALLACCTSPAYCODECOMBINATIONID),

            -- Remit-to
            l.APINVOICEPAYMENTSALLREMITTOSUPPLIERNAME,

            -- Creation date
            l.APINVOICEPAYMENTSALLCREATIONDATE,
            pkg_bicc_common.safe_to_timestamp(l.APINVOICEPAYMENTSALLCREATIONDATE),

            -- Last update date
            l.APINVOICEPAYMENTSALLLASTUPDATEDATE,
            pkg_bicc_common.safe_to_timestamp(l.APINVOICEPAYMENTSALLLASTUPDATEDATE),

            -- Run metadata
            l_run_id,
            systimestamp

        from l_ap_inv_application_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'AP_INV_APPLICATION', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'AP_INV_APPLICATION', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct invoice_payment_id
            from s_ap_inv_application_bc
            where job_id = p_job_id
              and invoice_payment_id is not null
        ) s
        where not exists (
            select 1 from ap_inv_application_bc f
            where f.invoice_payment_id = s.invoice_payment_id
        );

        select count(*) into l_matched
        from (
            select distinct invoice_payment_id
            from s_ap_inv_application_bc
            where job_id = p_job_id
              and invoice_payment_id is not null
        ) s
        where exists (
            select 1 from ap_inv_application_bc f
            where f.invoice_payment_id = s.invoice_payment_id
        );

        select count(*) into p_unchanged_count
        from (
            select
                invoice_payment_id,
                invoice_id,
                check_id,
                payment_num,
                amount,
                amount_inv_curr,
                invoice_base_amount,
                payment_base_amount,
                invoice_currency_code,
                payment_currency_code,
                invoice_payment_type,
                discount_taken,
                discount_lost,
                accounting_date_ts,
                period_name,
                posted_flag,
                reversal_flag,
                reversal_inv_pmt_id,
                org_id,
                exchange_rate,
                exchange_date_ts,
                exchange_rate_type,
                accts_pay_ccid,
                remit_to_supplier_name,
                last_update_date_ts
            from (
                select s.*,
                       row_number() over (
                         partition by invoice_payment_id
                         order by last_update_date_ts desc nulls last, rowid
                       ) rn
                from s_ap_inv_application_bc s
                where job_id = p_job_id
                  and invoice_payment_id is not null
            )
            where rn = 1
            intersect
            select
                invoice_payment_id,
                invoice_id,
                check_id,
                payment_num,
                amount,
                amount_inv_curr,
                invoice_base_amount,
                payment_base_amount,
                invoice_currency_code,
                payment_currency_code,
                invoice_payment_type,
                discount_taken,
                discount_lost,
                accounting_date_ts,
                period_name,
                posted_flag,
                reversal_flag,
                reversal_inv_pmt_id,
                org_id,
                exchange_rate,
                exchange_date_ts,
                exchange_rate_type,
                accts_pay_ccid,
                remit_to_supplier_name,
                last_update_date_ts
            from ap_inv_application_bc
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
            'AP_INV_APPLICATION', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(*) into l_rows_loaded
        from (
            select distinct invoice_payment_id
            from s_ap_inv_application_bc
            where job_id = l_job_id
              and invoice_payment_id is not null
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
        merge into ap_inv_application_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by invoice_payment_id
                        order by last_update_date_ts desc nulls last, rowid
                    ) rn
                from s_ap_inv_application_bc s
                where job_id = p_job_id
                  and invoice_payment_id is not null
            )
            where rn = 1
        ) s
        on (f.invoice_payment_id = s.invoice_payment_id)
        when matched then update set
            f.invoice_id               = s.invoice_id,
            f.check_id                 = s.check_id,
            f.payment_num              = s.payment_num,
            f.amount                   = s.amount,
            f.amount_inv_curr          = s.amount_inv_curr,
            f.invoice_base_amount      = s.invoice_base_amount,
            f.payment_base_amount      = s.payment_base_amount,
            f.invoice_currency_code    = s.invoice_currency_code,
            f.payment_currency_code    = s.payment_currency_code,
            f.invoice_payment_type     = s.invoice_payment_type,
            f.discount_taken           = s.discount_taken,
            f.discount_lost            = s.discount_lost,
            f.accounting_date_ts       = s.accounting_date_ts,
            f.period_name              = s.period_name,
            f.posted_flag              = s.posted_flag,
            f.reversal_flag            = s.reversal_flag,
            f.reversal_inv_pmt_id      = s.reversal_inv_pmt_id,
            f.org_id                   = s.org_id,
            f.exchange_rate            = s.exchange_rate,
            f.exchange_date_ts         = s.exchange_date_ts,
            f.exchange_rate_type       = s.exchange_rate_type,
            f.accts_pay_ccid           = s.accts_pay_ccid,
            f.remit_to_supplier_name   = s.remit_to_supplier_name,
            f.creation_date_ts         = s.creation_date_ts,
            f.last_update_date_ts      = s.last_update_date_ts,
            f.last_extract_run_id      = s.last_extract_run_id,
            f.last_extract_run_ts      = s.last_extract_run_ts
        when not matched then insert (
            invoice_payment_id,
            invoice_id,
            check_id,
            payment_num,
            amount,
            amount_inv_curr,
            invoice_base_amount,
            payment_base_amount,
            invoice_currency_code,
            payment_currency_code,
            invoice_payment_type,
            discount_taken,
            discount_lost,
            accounting_date_ts,
            period_name,
            posted_flag,
            reversal_flag,
            reversal_inv_pmt_id,
            org_id,
            exchange_rate,
            exchange_date_ts,
            exchange_rate_type,
            accts_pay_ccid,
            remit_to_supplier_name,
            creation_date_ts,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.invoice_payment_id,
            s.invoice_id,
            s.check_id,
            s.payment_num,
            s.amount,
            s.amount_inv_curr,
            s.invoice_base_amount,
            s.payment_base_amount,
            s.invoice_currency_code,
            s.payment_currency_code,
            s.invoice_payment_type,
            s.discount_taken,
            s.discount_lost,
            s.accounting_date_ts,
            s.period_name,
            s.posted_flag,
            s.reversal_flag,
            s.reversal_inv_pmt_id,
            s.org_id,
            s.exchange_rate,
            s.exchange_date_ts,
            s.exchange_rate_type,
            s.accts_pay_ccid,
            s.remit_to_supplier_name,
            s.creation_date_ts,
            s.last_update_date_ts,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_ap_inv_application_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'AP_INV_APPLICATION', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'AP_INV_APPLICATION', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_ap_inv_application;
/
