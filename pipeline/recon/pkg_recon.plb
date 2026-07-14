create or replace package body pkg_recon as

    gc_app_id constant number := 121;

    ---------------------------------------------------------------------------
    -- get_rest_count: call Fusion REST endpoint with ?totalResults=true
    -- and parse the count from the JSON response.
    ---------------------------------------------------------------------------
    function get_rest_count (
        p_url_path in varchar2
    ) return number
    is
        l_url      varchar2(2000);
        l_response clob;
        l_count    number;
    begin
        l_url := pkg_bicc_common.gc_fa_base_url
              || p_url_path
              || '?totalResults=true&limit=1&onlyData=true';

        apex_web_service.clear_request_headers;

        l_response := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_fa_credential
        );

        if apex_web_service.g_status_code <> 200 then
            raise_application_error(-20010,
                'REST count failed for ' || p_url_path
                || ' — HTTP ' || apex_web_service.g_status_code);
        end if;

        -- Parse totalResults from JSON response
        apex_json.parse(l_response);
        l_count := apex_json.get_number(p_path => 'totalResults');

        if l_count is null then
            raise_application_error(-20011,
                'No totalResults in response for ' || p_url_path);
        end if;

        return l_count;
    end get_rest_count;


    ---------------------------------------------------------------------------
    -- get_local_count: dynamic COUNT(*) on a local table.
    -- Table name is validated against recon_source_config to prevent injection.
    ---------------------------------------------------------------------------
    function get_local_count (
        p_table_name     in varchar2,
        p_local_count_sql in varchar2 default null
    ) return number
    is
        l_count      number;
        l_table_name varchar2(128);
    begin
        -- Validate table name exists in config (injection prevention)
        select local_table_name
          into l_table_name
          from recon_source_config
         where local_table_name = upper(p_table_name)
           and rownum = 1;

        if p_local_count_sql is not null then
            -- Custom SQL override (e.g. COUNT(DISTINCT col))
            execute immediate p_local_count_sql into l_count;
        else
            execute immediate
                'select count(*) from ' || dbms_assert.simple_sql_name(l_table_name)
                into l_count;
        end if;

        return l_count;

    exception
        when no_data_found then
            raise_application_error(-20012,
                'Table ' || p_table_name || ' not found in recon_source_config');
    end get_local_count;


    ---------------------------------------------------------------------------
    -- run_recon: main entry point. Loops through all active sources,
    -- gets Fusion + local counts, stores results.
    ---------------------------------------------------------------------------
    function run_recon return number
    is
        l_run_id       number;
        l_need_session boolean := false;
        l_local_count  number;
        l_fusion_count number;
        l_delta        number;
        l_pct_delta    number;
        l_status       varchar2(20);
        l_err_msg      varchar2(4000);
        -- BIP XML cache: keyed by report name to avoid re-calling same report
        type t_xml_cache is table of xmltype index by varchar2(200);
        l_bip_cache    t_xml_cache;
        l_bip_xml      xmltype;
        l_ok           number := 0;
        l_variance     number := 0;
        l_error        number := 0;
        l_total        number := 0;
    begin
        -----------------------------------------------------------------------
        -- Create APEX session when called from DBMS_SCHEDULER (no session).
        -----------------------------------------------------------------------
        if apex_application.g_flow_id is null then
            apex_session.create_session(
                p_app_id   => gc_app_id,
                p_page_id  => 1,
                p_username => 'ADMIN'
            );
            l_need_session := true;
        end if;

        -----------------------------------------------------------------------
        -- Create run header
        -----------------------------------------------------------------------
        insert into recon_run (started_ts)
        values (systimestamp)
        returning run_id into l_run_id;

        -----------------------------------------------------------------------
        -- Loop through all active sources
        -----------------------------------------------------------------------
        for r in (
            select entity_name, source_type, local_table_name, local_count_sql,
                   count_method, rest_url_path, bip_report_name, bip_entity_key
              from recon_source_config
             where is_active = 'Y'
             order by source_type, entity_name
        ) loop
            l_local_count  := null;
            l_fusion_count := null;
            l_delta        := null;
            l_pct_delta    := null;
            l_status       := null;
            l_err_msg      := null;
            l_total        := l_total + 1;

            begin
                -----------------------------------------------------------
                -- Local count
                -----------------------------------------------------------
                l_local_count := get_local_count(r.local_table_name, r.local_count_sql);

                -----------------------------------------------------------
                -- Fusion count
                -----------------------------------------------------------
                if r.count_method = 'REST_TOTAL' then
                    if r.rest_url_path is null then
                        l_err_msg := 'No rest_url_path configured';
                        l_status  := 'ERROR';
                    else
                        l_fusion_count := get_rest_count(r.rest_url_path);
                    end if;

                elsif r.count_method = 'BIP_COUNT' then
                    if r.bip_report_name is null then
                        l_err_msg := 'No bip_report_name configured';
                        l_status  := 'ERROR';
                    else
                        -- Call each distinct BIP report once, cache the XML
                        if not l_bip_cache.exists(r.bip_report_name) then
                            l_bip_cache(r.bip_report_name) :=
                                pkg_bip_soap.run_report_xml(
                                    p_report_name => r.bip_report_name
                                );
                        end if;

                        l_bip_xml := l_bip_cache(r.bip_report_name);

                        -- Extract count for this entity from the cached XML
                        begin
                            select x.rec_count
                              into l_fusion_count
                              from xmltable(
                                       '//ROW'
                                       passing l_bip_xml
                                       columns
                                           entity_name varchar2(100) path 'ENTITY_NAME',
                                           rec_count   number        path 'REC_COUNT'
                                   ) x
                             where x.entity_name = r.bip_entity_key;
                        exception
                            when no_data_found then
                                l_err_msg := 'Entity ' || r.bip_entity_key
                                          || ' not found in BIP report '
                                          || r.bip_report_name;
                                l_status  := 'ERROR';
                        end;
                    end if;
                end if;

                -----------------------------------------------------------
                -- Compute delta and status
                -----------------------------------------------------------
                if l_status is null then
                    l_delta := l_fusion_count - l_local_count;
                    if l_fusion_count > 0 then
                        l_pct_delta := round(abs(l_delta) / l_fusion_count * 100, 2);
                    else
                        l_pct_delta := 0;
                    end if;

                    if l_delta = 0 then
                        l_status := 'OK';
                        l_ok     := l_ok + 1;
                    else
                        l_status := 'VARIANCE';
                        l_variance := l_variance + 1;
                    end if;
                end if;

            exception
                when others then
                    l_err_msg := sqlerrm;
                    l_status  := 'ERROR';
            end;

            if l_status = 'ERROR' then
                l_error := l_error + 1;
            end if;

            -----------------------------------------------------------
            -- Store result
            -----------------------------------------------------------
            insert into recon_result (
                run_id, entity_name, source_type,
                local_table_name, fusion_source,
                local_count, fusion_count, delta, pct_delta,
                status, error_message
            ) values (
                l_run_id, r.entity_name, r.source_type,
                r.local_table_name,
                case r.count_method
                    when 'REST_TOTAL' then r.rest_url_path
                    when 'BIP_COUNT'  then r.bip_entity_key
                end,
                l_local_count, l_fusion_count, l_delta, l_pct_delta,
                l_status, l_err_msg
            );

        end loop;

        -----------------------------------------------------------------------
        -- Update run header with summary
        -----------------------------------------------------------------------
        update recon_run
           set completed_ts  = systimestamp,
               total_sources    = l_total,
               sources_ok       = l_ok,
               sources_variance = l_variance,
               sources_error    = l_error
         where run_id = l_run_id;

        commit;

        if l_need_session then
            apex_session.delete_session;
        end if;

        return l_run_id;

    exception
        when others then
            -- Ensure partial results are saved
            if l_run_id is not null then
                update recon_run
                   set completed_ts  = systimestamp,
                       total_sources    = l_total,
                       sources_ok       = l_ok,
                       sources_variance = l_variance,
                       sources_error    = l_error
                 where run_id = l_run_id;
                commit;
            end if;

            if l_need_session then
                apex_session.delete_session;
            end if;

            raise;
    end run_recon;

end pkg_recon;
/
