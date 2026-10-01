create or replace package body pkg_bicc_supplier_hdr as

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
        delete from s_supplier_hdr_bc where job_id = p_job_id;

        -- Step 1: Extract CSV from ZIP, upload to Object Storage
        pkg_bicc_common.extract_and_stage_csv(
            p_file_name    => p_file_name,
            p_staging_name => 'staging/supplier_hdr_current.csv'
        );

        -- Step 2: Load CSV into landing table via COPY_DATA
        execute immediate 'TRUNCATE TABLE l_supplier_hdr_bc';

        l_staging_uri := pkg_bicc_common.gc_bucket_uri || 'staging/supplier_hdr_current.csv';

        dbms_cloud.copy_data(
            table_name      => 'L_SUPPLIER_HDR_BC',
            credential_name => pkg_bicc_common.gc_credential,
            file_uri_list   => l_staging_uri,
            format          => json_object(
                                 'type' value 'csv',
                                 'skipheaders' value '1'
                               )
        );

        -- Step 3: Cherry-pick columns from landing into staging
        insert into s_supplier_hdr_bc (
            job_id,
            vendorid,
            partyid,
            segment1,
            alternatenamepartyname,
            alternatenamepartynameid,
            aliaspartyname,
            aliaspartynameid,
            businessrelationship,
            bcnotapplicableflag,
            federalreportableflag,
            incometaxid,
            incometaxidflag,
            organizationtypelookupcode,
            type1099,
            vendortypelookupcode,
            createdby,
            creationdate_raw,
            creationdate_ts,
            creationsource,
            lastupdatedby,
            lastupdatedate_raw,
            lastupdatedate_ts,
            lastupdatelogin,
            objectversionnumber,
            last_extract_run_id,
            last_extract_run_ts
        )
        select
            p_job_id,
            pkg_bicc_common.safe_to_number(l.VENDORID),
            pkg_bicc_common.safe_to_number(l.PARTYID),
            l.SEGMENT1,
            l.ALTERNATENAMEPARTYNAME,
            pkg_bicc_common.safe_to_number(l.ALTERNATENAMEPARTYNAMEID),
            l.ALIASPARTYNAME,
            pkg_bicc_common.safe_to_number(l.ALIASPARTYNAMEID),
            l.BUSINESSRELATIONSHIP,
            l.BCNOTAPPLICABLEFLAG,
            l.FEDERALREPORTABLEFLAG,
            l.INCOMETAXID,
            l.INCOMETAXIDFLAG,
            l.ORGANIZATIONTYPELOOKUPCODE,
            l.TYPE1099,
            l.VENDORTYPELOOKUPCODE,
            l.CREATEDBY,
            l.CREATIONDATE,
            pkg_bicc_common.safe_to_timestamp(l.CREATIONDATE),
            l.CREATIONSOURCE,
            l.LASTUPDATEDBY,
            l.LASTUPDATEDATE,
            pkg_bicc_common.safe_to_timestamp(l.LASTUPDATEDATE),
            l.LASTUPDATELOGIN,
            pkg_bicc_common.safe_to_number(l.OBJECTVERSIONNUMBER),
            l_run_id,
            systimestamp
        from l_supplier_hdr_bc l;

        l_rows_inserted := sql%rowcount;
        commit;

        insert into bicc_load_log (
            load_type, file_name, step, rows_processed, rows_inserted, status
        ) values (
            'SUPPLIER_HDR', p_file_name, 'LOAD_STG', l_rows_inserted, l_rows_inserted, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, file_name, step, status, error_message
            ) values (
                'SUPPLIER_HDR', p_file_name, 'LOAD_STG', 'ERROR', l_error_msg
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
            select distinct vendorid
            from s_supplier_hdr_bc
            where job_id = p_job_id
        ) s
        where not exists (
            select 1 from supplier_hdr_bc f where f.vendorid = s.vendorid
        );

        select count(*) into l_matched
        from (
            select distinct vendorid
            from s_supplier_hdr_bc
            where job_id = p_job_id
        ) s
        where exists (
            select 1 from supplier_hdr_bc f where f.vendorid = s.vendorid
        );

        select count(*) into p_unchanged_count
        from (
            select
                vendorid,
                partyid,
                segment1,
                alternatenamepartyname,
                businessrelationship,
                incometaxid,
                organizationtypelookupcode,
                type1099,
                vendortypelookupcode
            from (
                select
                    s.*,
                    row_number() over (partition by vendorid order by rowid) rn
                from s_supplier_hdr_bc s
                where job_id = p_job_id
            )
            where rn = 1
            intersect
            select
                vendorid,
                partyid,
                segment1,
                alternatenamepartyname,
                businessrelationship,
                incometaxid,
                organizationtypelookupcode,
                type1099,
                vendortypelookupcode
            from supplier_hdr_bc
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
            'SUPPLIER_HDR', p_file_name, 'LOADING', coalesce(v('APP_USER'), user), systimestamp
        )
        returning job_id into l_job_id;

        load(p_file_name => p_file_name, p_job_id => l_job_id);

        select count(distinct vendorid) into l_rows_loaded
        from s_supplier_hdr_bc
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
        merge into supplier_hdr_bc f
        using (
            select * from (
                select
                    s.*,
                    row_number() over (
                        partition by vendorid
                        order by rowid
                    ) rn
                from s_supplier_hdr_bc s
                where job_id = p_job_id
            )
            where rn = 1
        ) s
        on (f.vendorid = s.vendorid)
        when matched then update set
            f.partyid                    = s.partyid,
            f.segment1                   = s.segment1,
            f.alternatenamepartyname     = s.alternatenamepartyname,
            f.alternatenamepartynameid   = s.alternatenamepartynameid,
            f.aliaspartyname             = s.aliaspartyname,
            f.aliaspartynameid           = s.aliaspartynameid,
            f.businessrelationship       = s.businessrelationship,
            f.bcnotapplicableflag        = s.bcnotapplicableflag,
            f.federalreportableflag      = s.federalreportableflag,
            f.incometaxid                = s.incometaxid,
            f.incometaxidflag            = s.incometaxidflag,
            f.organizationtypelookupcode = s.organizationtypelookupcode,
            f.type1099                   = s.type1099,
            f.vendortypelookupcode       = s.vendortypelookupcode,
            f.createdby                  = s.createdby,
            f.creationdate               = s.creationdate_ts,
            f.creationsource             = s.creationsource,
            f.lastupdatedby              = s.lastupdatedby,
            f.lastupdatedate             = s.lastupdatedate_ts,
            f.lastupdatelogin            = s.lastupdatelogin,
            f.objectversionnumber        = s.objectversionnumber,
            f.last_extract_run_id        = s.last_extract_run_id,
            f.last_extract_run_ts        = s.last_extract_run_ts
        when not matched then insert (
            vendorid,
            partyid,
            segment1,
            alternatenamepartyname,
            alternatenamepartynameid,
            aliaspartyname,
            aliaspartynameid,
            businessrelationship,
            bcnotapplicableflag,
            federalreportableflag,
            incometaxid,
            incometaxidflag,
            organizationtypelookupcode,
            type1099,
            vendortypelookupcode,
            createdby,
            creationdate,
            creationsource,
            lastupdatedby,
            lastupdatedate,
            lastupdatelogin,
            objectversionnumber,
            last_extract_run_id,
            last_extract_run_ts
        ) values (
            s.vendorid,
            s.partyid,
            s.segment1,
            s.alternatenamepartyname,
            s.alternatenamepartynameid,
            s.aliaspartyname,
            s.aliaspartynameid,
            s.businessrelationship,
            s.bcnotapplicableflag,
            s.federalreportableflag,
            s.incometaxid,
            s.incometaxidflag,
            s.organizationtypelookupcode,
            s.type1099,
            s.vendortypelookupcode,
            s.createdby,
            s.creationdate_ts,
            s.creationsource,
            s.lastupdatedby,
            s.lastupdatedate_ts,
            s.lastupdatelogin,
            s.objectversionnumber,
            s.last_extract_run_id,
            s.last_extract_run_ts
        );

        l_rowcount := sql%rowcount;

        delete from s_supplier_hdr_bc where job_id = p_job_id;

        update bicc_load_job
        set status    = 'MERGED',
            merged_by = coalesce(v('APP_USER'), user),
            merged_ts = systimestamp
        where job_id = p_job_id;

        insert into bicc_load_log (
            load_type, step, rows_updated, status
        ) values (
            'SUPPLIER_HDR', 'MERGE_FBX', l_rowcount, 'SUCCESS'
        );

        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'SUPPLIER_HDR', 'MERGE_FBX', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end merge;

end pkg_bicc_supplier_hdr;
/
