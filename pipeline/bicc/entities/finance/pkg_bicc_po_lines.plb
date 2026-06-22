create or replace package body pkg_bicc_po_lines as

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
        l_staging_uri   varchar2(500);
    begin
        delete from s_po_lines_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/po_lines_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_po_lines_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/po_lines_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_PO_LINES_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_po_lines_bc (
            job_id,
            poheaderid,
            polineid,
            linenum,
            createdby,
            creationdate,
            fundsstatus,
            itemdescription,
            lastupdatedby,
            linestatus,
            listprice,
            matchingbasis,
            purchasebasis,
            shippinguomcode,
            unitprice,
            uomcode
        )
        select
            p_job_id,
            pkg_bicc_common.safe_to_number(l.POHEADERID),
            pkg_bicc_common.safe_to_number(l.POLINEID),
            pkg_bicc_common.safe_to_number(l.LINENUM),
            l.CREATEDBY,
            pkg_bicc_common.safe_to_timestamp(l.CREATIONDATE),
            l.FUNDSSTATUS,
            l.ITEMDESCRIPTION,
            l.LASTUPDATEDBY,
            l.LINESTATUS,
            pkg_bicc_common.safe_to_number(l.LISTPRICE),
            l.MATCHINGBASIS,
            l.PURCHASEBASIS,
            l.SHIPPINGUOMCODE,
            pkg_bicc_common.safe_to_number(l.UNITPRICE),
            l.UOMCODE
        from l_po_lines_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'PO_LINES', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'PO_LINES', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct polineid
            from s_po_lines_bc
            where job_id = p_job_id
        ) s
        where not exists (
            select 1 from po_lines_bc f where f.polineid = s.polineid
        );

        select count(*) into l_matched
        from (
            select distinct polineid
            from s_po_lines_bc
            where job_id = p_job_id
        ) s
        where exists (
            select 1 from po_lines_bc f where f.polineid = s.polineid
        );

        select count(*) into p_unchanged_count
        from (
            select
                polineid,
                poheaderid,
                linenum,
                itemdescription,
                linestatus,
                unitprice,
                listprice,
                uomcode
            from (
                select
                    s.*,
                    row_number() over (partition by polineid order by rowid) rn
                from s_po_lines_bc s
                where job_id = p_job_id
            )
            where rn = 1
            intersect
            select
                polineid,
                poheaderid,
                linenum,
                itemdescription,
                linestatus,
                unitprice,
                listprice,
                uomcode
            from po_lines_bc
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
            'PO_LINES', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct polineid) into l_rows_loaded
        from s_po_lines_bc
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
        merge into po_lines_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by polineid
                        order by rowid
                    ) rn
                from s_po_lines_bc s
                where job_id = p_job_id
            )
            where rn = 1
        ) s
        on (f.polineid = s.polineid)
        when matched then update set
            f.poheaderid       = s.poheaderid,
            f.linenum          = s.linenum,
            f.createdby        = s.createdby,
            f.creationdate     = s.creationdate,
            f.fundsstatus      = s.fundsstatus,
            f.itemdescription  = s.itemdescription,
            f.lastupdatedby    = s.lastupdatedby,
            f.linestatus       = s.linestatus,
            f.listprice        = s.listprice,
            f.matchingbasis    = s.matchingbasis,
            f.purchasebasis    = s.purchasebasis,
            f.shippinguomcode  = s.shippinguomcode,
            f.unitprice        = s.unitprice,
            f.uomcode          = s.uomcode
        when not matched then insert (
            poheaderid,
            polineid,
            linenum,
            createdby,
            creationdate,
            fundsstatus,
            itemdescription,
            lastupdatedby,
            linestatus,
            listprice,
            matchingbasis,
            purchasebasis,
            shippinguomcode,
            unitprice,
            uomcode
        ) values (
            s.poheaderid,
            s.polineid,
            s.linenum,
            s.createdby,
            s.creationdate,
            s.fundsstatus,
            s.itemdescription,
            s.lastupdatedby,
            s.linestatus,
            s.listprice,
            s.matchingbasis,
            s.purchasebasis,
            s.shippinguomcode,
            s.unitprice,
            s.uomcode
        );

        l_rowcount := sql%rowcount;

        delete from s_po_lines_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'PO_LINES', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'PO_LINES', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_po_lines;
/
