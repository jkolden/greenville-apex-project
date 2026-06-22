create or replace package body pkg_bicc_po_hdr as

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
        delete from s_po_hdr_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/po_hdr_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_po_hdr_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/po_hdr_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_PO_HDR_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_po_hdr_bc (
            job_id,
            poheaderid,
            po_number,
            revisionnum,
            po_type,
            documentstatus,
            approvedflag,
            prcbuid,
            vendorid,
            vendorsiteid,
            vendor_order_num,
            currencycode,
            amountlimit,
            amountreleased,
            blankettotalamount,
            startdate_raw,
            creationdate_raw,
            lastupdatedate_raw,
            closeddate_raw,
            startdate_ts,
            creationdate_ts,
            lastupdatedate_ts,
            closeddate_ts,
            lastupdatedby,
            objectversionnumber,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,
            pkg_bicc_common.safe_to_number(l.POHEADERID),
            l.SEGMENT1,
            pkg_bicc_common.safe_to_number(l.REVISIONNUM),
            l.TYPELOOKUPCODE,
            l.DOCUMENTSTATUS,
            l.APPROVEDFLAG,
            pkg_bicc_common.safe_to_number(l.PRCBUID),
            pkg_bicc_common.safe_to_number(l.VENDORID),
            pkg_bicc_common.safe_to_number(l.VENDORSITEID),
            l.VENDORORDERNUM,
            l.CURRENCYCODE,
            pkg_bicc_common.safe_to_number(l.AMOUNTLIMIT),
            pkg_bicc_common.safe_to_number(l.MINRELEASEAMOUNT),
            pkg_bicc_common.safe_to_number(l.BLANKETTOTALAMOUNT),
            l.STARTDATE,
            l.CREATIONDATE,
            l.LASTUPDATEDATE,
            l.CLOSEDDATE,
            pkg_bicc_common.safe_to_timestamp(l.STARTDATE),
            pkg_bicc_common.safe_to_timestamp(l.CREATIONDATE),
            pkg_bicc_common.safe_to_timestamp(l.LASTUPDATEDATE),
            pkg_bicc_common.safe_to_timestamp(l.CLOSEDDATE),
            l.LASTUPDATEDBY,
            pkg_bicc_common.safe_to_number(l.OBJECTVERSIONNUMBER),
            l_run_id,
            systimestamp
        from l_po_hdr_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'PO_HDR', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'PO_HDR', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct poheaderid
            from s_po_hdr_bc
            where job_id = p_job_id
        ) s
        where not exists (
            select 1 from po_hdr_bc f where f.poheaderid = s.poheaderid
        );

        select count(*) into l_matched
        from (
            select distinct poheaderid
            from s_po_hdr_bc
            where job_id = p_job_id
        ) s
        where exists (
            select 1 from po_hdr_bc f where f.poheaderid = s.poheaderid
        );

        select count(*) into p_unchanged_count
        from (
            select
                poheaderid,
                po_number,
                revisionnum,
                po_type,
                documentstatus,
                approvedflag,
                prcbuid,
                vendorid,
                vendorsiteid,
                vendor_order_num,
                currencycode,
                amountlimit,
                amountreleased,
                blankettotalamount
            from (
                select
                    s.*,
                    row_number() over (partition by poheaderid order by rowid) rn
                from s_po_hdr_bc s
                where job_id = p_job_id
            )
            where rn = 1
            intersect
            select
                poheaderid,
                po_number,
                revisionnum,
                po_type,
                documentstatus,
                approvedflag,
                prcbuid,
                vendorid,
                vendorsiteid,
                vendor_order_num,
                currencycode,
                amountlimit,
                amountreleased,
                blankettotalamount
            from po_hdr_bc
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
            'PO_HDR', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct poheaderid) into l_rows_loaded
        from s_po_hdr_bc
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
        merge into po_hdr_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by poheaderid
                        order by rowid
                    ) rn
                from s_po_hdr_bc s
                where job_id = p_job_id
            )
            where rn = 1
        ) s
        on (f.poheaderid = s.poheaderid)
        when matched then update set
            f.po_number                = s.po_number,
            f.revisionnum              = s.revisionnum,
            f.po_type                  = s.po_type,
            f.documentstatus           = s.documentstatus,
            f.approvedflag             = s.approvedflag,
            f.prcbuid                  = s.prcbuid,
            f.vendorid                 = s.vendorid,
            f.vendorsiteid             = s.vendorsiteid,
            f.vendor_order_num         = s.vendor_order_num,
            f.currencycode             = s.currencycode,
            f.amountlimit              = s.amountlimit,
            f.amountreleased           = s.amountreleased,
            f.blankettotalamount       = s.blankettotalamount,
            f.startdate_raw            = s.startdate_raw,
            f.creationdate_raw         = s.creationdate_raw,
            f.lastupdatedate_raw       = s.lastupdatedate_raw,
            f.closeddate_raw           = s.closeddate_raw,
            f.startdate_ts             = s.startdate_ts,
            f.creationdate_ts          = s.creationdate_ts,
            f.lastupdatedate_ts        = s.lastupdatedate_ts,
            f.closeddate_ts            = s.closeddate_ts,
            f.lastupdatedby            = s.lastupdatedby,
            f.objectversionnumber      = s.objectversionnumber,
            f.last_extract_run_id      = s.last_extract_run_id,
            f.last_extract_run_ts      = s.last_extract_run_ts
        when not matched then insert (
            poheaderid,
            po_number,
            revisionnum,
            po_type,
            documentstatus,
            approvedflag,
            prcbuid,
            vendorid,
            vendorsiteid,
            vendor_order_num,
            currencycode,
            amountlimit,
            amountreleased,
            blankettotalamount,
            startdate_raw,
            creationdate_raw,
            lastupdatedate_raw,
            closeddate_raw,
            startdate_ts,
            creationdate_ts,
            lastupdatedate_ts,
            closeddate_ts,
            lastupdatedby,
            objectversionnumber,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.poheaderid,
            s.po_number,
            s.revisionnum,
            s.po_type,
            s.documentstatus,
            s.approvedflag,
            s.prcbuid,
            s.vendorid,
            s.vendorsiteid,
            s.vendor_order_num,
            s.currencycode,
            s.amountlimit,
            s.amountreleased,
            s.blankettotalamount,
            s.startdate_raw,
            s.creationdate_raw,
            s.lastupdatedate_raw,
            s.closeddate_raw,
            s.startdate_ts,
            s.creationdate_ts,
            s.lastupdatedate_ts,
            s.closeddate_ts,
            s.lastupdatedby,
            s.objectversionnumber,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_po_hdr_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'PO_HDR', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'PO_HDR', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_po_hdr;
/
