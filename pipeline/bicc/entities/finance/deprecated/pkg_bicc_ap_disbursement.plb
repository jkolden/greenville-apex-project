create or replace package body pkg_bicc_ap_disbursement as

    -- =========================================================================
    -- LOAD (private)
    -- =========================================================================
    -- Flow: extract_and_stage_csv -> COPY_DATA -> INSERT...SELECT
    -- PK: CHECK_ID
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
        delete from s_ap_disbursement_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/ap_disbursement_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_ap_disbursement_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/ap_disbursement_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_AP_DISBURSEMENT_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_ap_disbursement_bc (
            job_id,
            check_id,
            check_number,
            check_date_raw,
            check_date_ts,
            amount,
            base_amount,
            currency_code,
            status_lookup_code,
            payment_method_code,
            payment_type_flag,
            vendor_id,
            vendor_name,
            vendor_site_id,
            vendor_site_code,
            remit_to_supplier_id,
            remit_to_supplier_name,
            org_id,
            legal_entity_id,
            bank_account_name,
            ce_bank_acct_use_id,
            external_bank_account_id,
            check_run_name,
            cleared_amount,
            cleared_base_amount,
            cleared_date_raw,
            cleared_date_ts,
            void_date_raw,
            void_date_ts,
            released_date_raw,
            released_date_ts,
            exchange_rate,
            exchange_date_raw,
            exchange_date_ts,
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
            pkg_bicc_common.safe_to_number(l.APCHECKSALLCHECKID),
            pkg_bicc_common.safe_to_number(l.APCHECKSALLCHECKNUMBER),

            -- Check date
            l.APCHECKSALLCHECKDATE,
            pkg_bicc_common.safe_to_timestamp(l.APCHECKSALLCHECKDATE),

            -- Amounts
            pkg_bicc_common.safe_to_number(l.APCHECKSALLAMOUNT),
            pkg_bicc_common.safe_to_number(l.APCHECKSALLBASEAMOUNT),
            l.APCHECKSALLCURRENCYCODE,

            -- Status / method
            l.APCHECKSALLSTATUSLOOKUPCODE,
            l.APCHECKSALLPAYMENTMETHODCODE,
            l.APCHECKSALLPAYMENTTYPEFLAG,

            -- Vendor
            pkg_bicc_common.safe_to_number(l.APCHECKSALLVENDORID),
            l.APCHECKSALLVENDORNAME,
            pkg_bicc_common.safe_to_number(l.APCHECKSALLVENDORSITEID),
            l.APCHECKSALLVENDORSITECODE,

            -- Remit-to
            pkg_bicc_common.safe_to_number(l.APCHECKSALLREMITTOSUPPLIERID),
            l.APCHECKSALLREMITTOSUPPLIERNAME,

            -- Org
            pkg_bicc_common.safe_to_number(l.APCHECKSALLORGID),
            pkg_bicc_common.safe_to_number(l.APCHECKSALLLEGALENTITYID),

            -- Bank
            l.APCHECKSALLBANKACCOUNTNAME,
            pkg_bicc_common.safe_to_number(l.APCHECKSALLCEBANKACCTUSEID),
            pkg_bicc_common.safe_to_number(l.APCHECKSALLEXTERNALBANKACCOUNTID),

            -- Check run
            l.APCHECKSALLCHECKRUNNAME,

            -- Cleared
            pkg_bicc_common.safe_to_number(l.APCHECKSALLCLEAREDAMOUNT),
            pkg_bicc_common.safe_to_number(l.APCHECKSALLCLEAREDBASEAMOUNT),
            l.APCHECKSALLCLEAREDDATE,
            pkg_bicc_common.safe_to_timestamp(l.APCHECKSALLCLEAREDDATE),

            -- Void
            l.APCHECKSALLVOIDDATE,
            pkg_bicc_common.safe_to_timestamp(l.APCHECKSALLVOIDDATE),

            -- Released
            l.APCHECKSALLRELEASEDDATE,
            pkg_bicc_common.safe_to_timestamp(l.APCHECKSALLRELEASEDDATE),

            -- Exchange
            pkg_bicc_common.safe_to_number(l.APCHECKSALLEXCHANGERATE),
            l.APCHECKSALLEXCHANGEDATE,
            pkg_bicc_common.safe_to_timestamp(l.APCHECKSALLEXCHANGEDATE),

            -- Creation date
            l.APCHECKSALLCREATIONDATE,
            pkg_bicc_common.safe_to_timestamp(l.APCHECKSALLCREATIONDATE),

            -- Last update date
            l.APCHECKSALLLASTUPDATEDATE,
            pkg_bicc_common.safe_to_timestamp(l.APCHECKSALLLASTUPDATEDATE),

            -- Run metadata
            l_run_id,
            systimestamp

        from l_ap_disbursement_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'AP_DISBURSEMENT', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'AP_DISBURSEMENT', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct check_id
            from s_ap_disbursement_bc
            where job_id = p_job_id
              and check_id is not null
        ) s
        where not exists (
            select 1 from ap_disbursement_bc f
            where f.check_id = s.check_id
        );

        select count(*) into l_matched
        from (
            select distinct check_id
            from s_ap_disbursement_bc
            where job_id = p_job_id
              and check_id is not null
        ) s
        where exists (
            select 1 from ap_disbursement_bc f
            where f.check_id = s.check_id
        );

        select count(*) into p_unchanged_count
        from (
            select
                check_id,
                check_number,
                check_date_ts,
                amount,
                base_amount,
                currency_code,
                status_lookup_code,
                payment_method_code,
                payment_type_flag,
                vendor_id,
                vendor_name,
                vendor_site_id,
                vendor_site_code,
                remit_to_supplier_id,
                remit_to_supplier_name,
                org_id,
                legal_entity_id,
                bank_account_name,
                ce_bank_acct_use_id,
                external_bank_account_id,
                check_run_name,
                cleared_amount,
                cleared_base_amount,
                cleared_date_ts,
                void_date_ts,
                released_date_ts,
                exchange_rate,
                exchange_date_ts,
                creation_date_ts,
                last_update_date_ts
            from (
                select s.*,
                       row_number() over (
                         partition by check_id
                         order by last_update_date_ts desc nulls last, rowid
                       ) rn
                from s_ap_disbursement_bc s
                where job_id = p_job_id
                  and check_id is not null
            )
            where rn = 1
            intersect
            select
                check_id,
                check_number,
                check_date_ts,
                amount,
                base_amount,
                currency_code,
                status_lookup_code,
                payment_method_code,
                payment_type_flag,
                vendor_id,
                vendor_name,
                vendor_site_id,
                vendor_site_code,
                remit_to_supplier_id,
                remit_to_supplier_name,
                org_id,
                legal_entity_id,
                bank_account_name,
                ce_bank_acct_use_id,
                external_bank_account_id,
                check_run_name,
                cleared_amount,
                cleared_base_amount,
                cleared_date_ts,
                void_date_ts,
                released_date_ts,
                exchange_rate,
                exchange_date_ts,
                creation_date_ts,
                last_update_date_ts
            from ap_disbursement_bc
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
            'AP_DISBURSEMENT', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(*) into l_rows_loaded
        from (
            select distinct check_id
            from s_ap_disbursement_bc
            where job_id = l_job_id
              and check_id is not null
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
        merge into ap_disbursement_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by check_id
                        order by last_update_date_ts desc nulls last, rowid
                    ) rn
                from s_ap_disbursement_bc s
                where job_id = p_job_id
                  and check_id is not null
            )
            where rn = 1
        ) s
        on (f.check_id = s.check_id)
        when matched then update set
            f.check_number             = s.check_number,
            f.check_date_ts            = s.check_date_ts,
            f.amount                   = s.amount,
            f.base_amount              = s.base_amount,
            f.currency_code            = s.currency_code,
            f.status_lookup_code       = s.status_lookup_code,
            f.payment_method_code      = s.payment_method_code,
            f.payment_type_flag        = s.payment_type_flag,
            f.vendor_id                = s.vendor_id,
            f.vendor_name              = s.vendor_name,
            f.vendor_site_id           = s.vendor_site_id,
            f.vendor_site_code         = s.vendor_site_code,
            f.remit_to_supplier_id     = s.remit_to_supplier_id,
            f.remit_to_supplier_name   = s.remit_to_supplier_name,
            f.org_id                   = s.org_id,
            f.legal_entity_id          = s.legal_entity_id,
            f.bank_account_name        = s.bank_account_name,
            f.ce_bank_acct_use_id      = s.ce_bank_acct_use_id,
            f.external_bank_account_id = s.external_bank_account_id,
            f.check_run_name           = s.check_run_name,
            f.cleared_amount           = s.cleared_amount,
            f.cleared_base_amount      = s.cleared_base_amount,
            f.cleared_date_ts          = s.cleared_date_ts,
            f.void_date_ts             = s.void_date_ts,
            f.released_date_ts         = s.released_date_ts,
            f.exchange_rate            = s.exchange_rate,
            f.exchange_date_ts         = s.exchange_date_ts,
            f.creation_date_ts         = s.creation_date_ts,
            f.last_update_date_ts      = s.last_update_date_ts,
            f.last_extract_run_id      = s.last_extract_run_id,
            f.last_extract_run_ts      = s.last_extract_run_ts
        when not matched then insert (
            check_id,
            check_number,
            check_date_ts,
            amount,
            base_amount,
            currency_code,
            status_lookup_code,
            payment_method_code,
            payment_type_flag,
            vendor_id,
            vendor_name,
            vendor_site_id,
            vendor_site_code,
            remit_to_supplier_id,
            remit_to_supplier_name,
            org_id,
            legal_entity_id,
            bank_account_name,
            ce_bank_acct_use_id,
            external_bank_account_id,
            check_run_name,
            cleared_amount,
            cleared_base_amount,
            cleared_date_ts,
            void_date_ts,
            released_date_ts,
            exchange_rate,
            exchange_date_ts,
            creation_date_ts,
            last_update_date_ts,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.check_id,
            s.check_number,
            s.check_date_ts,
            s.amount,
            s.base_amount,
            s.currency_code,
            s.status_lookup_code,
            s.payment_method_code,
            s.payment_type_flag,
            s.vendor_id,
            s.vendor_name,
            s.vendor_site_id,
            s.vendor_site_code,
            s.remit_to_supplier_id,
            s.remit_to_supplier_name,
            s.org_id,
            s.legal_entity_id,
            s.bank_account_name,
            s.ce_bank_acct_use_id,
            s.external_bank_account_id,
            s.check_run_name,
            s.cleared_amount,
            s.cleared_base_amount,
            s.cleared_date_ts,
            s.void_date_ts,
            s.released_date_ts,
            s.exchange_rate,
            s.exchange_date_ts,
            s.creation_date_ts,
            s.last_update_date_ts,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_ap_disbursement_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'AP_DISBURSEMENT', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'AP_DISBURSEMENT', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_ap_disbursement;
/
