create or replace package body pkg_rec_email as

    gc_lov_path constant varchar2(200) :=
        '/hcmRestApi/resources/11.13.18.05/recruitingContentLibraryItemsLOV';

    -- =========================================================================
    -- PRIVATE: GENERIC REST FETCH
    -- =========================================================================

    function fetch_url(p_url in varchar2) return clob is
    begin
        return apex_web_service.make_rest_request(
            p_url                  => p_url,
            p_http_method          => 'GET',
            p_credential_static_id => gc_fa_credential
        );
    end fetch_url;


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
    -- EXTRACT_TOKENS — Find all ${...} token names in template text
    -- =========================================================================

    function extract_tokens(p_template in clob) return apex_t_varchar2 is
        l_tokens apex_t_varchar2 := apex_t_varchar2();
        l_pos    number := 1;
        l_start  number;
        l_end    number;
        l_token  varchar2(200);
    begin
        if p_template is null then
            return l_tokens;
        end if;

        loop
            l_start := instr(p_template, '${', l_pos);
            exit when l_start = 0 or l_start is null;

            l_end := instr(p_template, '}', l_start + 2);
            exit when l_end = 0 or l_end is null;

            l_token := substr(p_template, l_start + 2, l_end - l_start - 2);

            -- Deduplicate within this template
            if l_token is not null and l_token not member of l_tokens then
                l_tokens.extend;
                l_tokens(l_tokens.count) := l_token;
            end if;

            l_pos := l_end + 1;
        end loop;

        return l_tokens;
    end extract_tokens;


    -- =========================================================================
    -- SUBSTITUTE — Replace ${TokenName} placeholders with values
    -- =========================================================================

    function substitute(
        p_template     in clob,
        p_token_names  in apex_t_varchar2,
        p_token_values in apex_t_varchar2
    ) return clob is
        l_result clob := p_template;
    begin
        if p_token_names is null or p_token_names.count = 0 then
            return l_result;
        end if;

        for i in 1 .. p_token_names.count loop
            -- Only replace if we have a non-null value;
            -- NULL would cause REPLACE to remove the token entirely
            if i <= p_token_values.count and p_token_values(i) is not null then
                l_result := replace(
                    l_result,
                    '${' || p_token_names(i) || '}',
                    p_token_values(i)
                );
            end if;
        end loop;

        return l_result;
    end substitute;


    -- =========================================================================
    -- DISCOVER_TOKENS — Scan all templates, populate rec_email_token
    -- =========================================================================

    procedure discover_tokens is
        type t_token_count is table of number index by varchar2(200);
        l_counts  t_token_count;
        l_tokens  apex_t_varchar2;
        l_name    varchar2(200);
        l_total   number := 0;
    begin
        -- Count how many templates reference each token
        for r in (
            select txt_description
            from   rec_content_library
            where  txt_description is not null
        ) loop
            l_tokens := extract_tokens(r.txt_description);
            for i in 1 .. l_tokens.count loop
                l_name := l_tokens(i);
                if l_counts.exists(l_name) then
                    l_counts(l_name) := l_counts(l_name) + 1;
                else
                    l_counts(l_name) := 1;
                end if;
            end loop;
        end loop;

        -- MERGE into token registry
        l_name := l_counts.first;
        while l_name is not null loop
            merge into rec_email_token t
            using (select l_name as token_name, l_counts(l_name) as cnt from dual) s
            on (t.token_name = s.token_name)
            when matched then update set
                t.template_count = s.cnt
            when not matched then insert (token_name, template_count)
            values (s.token_name, s.cnt);

            l_total := l_total + 1;
            l_name  := l_counts.next(l_name);
        end loop;

        commit;
        dbms_output.put_line('Unique tokens discovered: ' || l_total);
    end discover_tokens;


    -- =========================================================================
    -- PREVIEW_EMAIL — Return substituted template text (no send)
    -- =========================================================================

    function preview_email(
        p_item_description_id in number,
        p_token_names         in apex_t_varchar2 default apex_t_varchar2(),
        p_token_values        in apex_t_varchar2 default apex_t_varchar2()
    ) return clob is
        l_template clob;
    begin
        select txt_description
        into   l_template
        from   rec_content_library
        where  item_description_id = p_item_description_id;

        if l_template is null then
            raise_application_error(-20001,
                'No template text for item_description_id=' || p_item_description_id);
        end if;

        return substitute(l_template, p_token_names, p_token_values);
    end preview_email;


    -- =========================================================================
    -- SEND_EMAIL — Compose and send via APEX_MAIL
    -- =========================================================================

    procedure send_email(
        p_to                  in varchar2,
        p_from                in varchar2 default 'noreply@greenville.k12.sc.us',
        p_subject             in varchar2,
        p_item_description_id in number,
        p_token_names         in apex_t_varchar2 default apex_t_varchar2(),
        p_token_values        in apex_t_varchar2 default apex_t_varchar2()
    ) is
        l_body    clob;
        l_mail_id number;
    begin
        l_body := preview_email(p_item_description_id, p_token_names, p_token_values);

        l_mail_id := apex_mail.send(
            p_to   => p_to,
            p_from => p_from,
            p_subj => p_subject,
            p_body => l_body
        );

        apex_mail.push_queue;

        dbms_output.put_line('Email queued, mail_id=' || l_mail_id
            || ', to=' || p_to
            || ', subject=' || p_subject);
    end send_email;


    -- =========================================================================
    -- RESOLVE_TOKENS — Auto-map tokens from database context
    -- =========================================================================
    -- Extracts all ${...} tokens from the template, resolves each one it can
    -- from the supplied requisition/candidate context, and returns the
    -- substituted text.  Unresolved tokens stay as ${TokenName}.
    -- =========================================================================

    function resolve_tokens(
        p_item_description_id in number,
        p_requisition_id      in number   default null,
        p_candidate_name      in varchar2 default null,
        p_site_name           in varchar2 default 'Greenville County Schools'
    ) return clob is
        l_template   clob;
        l_tokens     apex_t_varchar2;
        l_names      apex_t_varchar2 := apex_t_varchar2();
        l_values     apex_t_varchar2 := apex_t_varchar2();
        l_req_title  varchar2(240);
        l_req_num    varchar2(240);
        l_val        varchar2(4000);
    begin
        -- Get template text
        select txt_description
        into   l_template
        from   rec_content_library
        where  item_description_id = p_item_description_id;

        if l_template is null then
            raise_application_error(-20001,
                'No template text for item_description_id=' || p_item_description_id);
        end if;

        -- Look up requisition context
        if p_requisition_id is not null then
            begin
                select title, requisitionnumber
                into   l_req_title, l_req_num
                from   job_requisitions_r
                where  requisitionid = p_requisition_id;
            exception
                when no_data_found then null;
            end;
        end if;

        -- Extract tokens and resolve each one
        l_tokens := extract_tokens(l_template);

        for i in 1 .. l_tokens.count loop
            l_names.extend;
            l_values.extend;
            l_names(i) := l_tokens(i);

            l_val := case l_tokens(i)
                -- Requisition context
                when 'RequisitionTitle'        then l_req_title
                when 'RequisitionNumber'       then l_req_num
                when 'JobOfferTitle'           then l_req_title

                -- Candidate context
                when 'CandidateFirstName'      then p_candidate_name

                -- Site / config
                when 'CEConfigurationSiteName' then p_site_name

                -- Deep links (construct from Fusion base URL)
                when 'CandidateSelfServiceDeepLinkURL'
                    then gc_fa_base_url || '/hcmUI/CandidateExperience'
                when 'AllJobsDeepLinkURL'
                    then gc_fa_base_url || '/hcmUI/CandidateExperience/en/sites/CX_1/requisitions'

                -- Check rec_email_token for a default_value
                else null
            end;

            -- Fall back to default_value in rec_email_token
            if l_val is null then
                begin
                    select default_value
                    into   l_val
                    from   rec_email_token
                    where  token_name = l_tokens(i)
                      and  default_value is not null;
                exception
                    when no_data_found then null;
                end;
            end if;

            l_values(i) := l_val;
        end loop;

        return substitute(l_template, l_names, l_values);
    end resolve_tokens;


    -- =========================================================================
    -- SEND_EMAIL_RESOLVED — Send using resolve_tokens (simpler API)
    -- =========================================================================

    procedure send_email_resolved(
        p_to                  in varchar2,
        p_from                in varchar2 default 'noreply@greenville.k12.sc.us',
        p_subject             in varchar2,
        p_item_description_id in number,
        p_requisition_id      in number   default null,
        p_candidate_name      in varchar2 default null,
        p_site_name           in varchar2 default 'Greenville County Schools'
    ) is
        l_body    clob;
        l_mail_id number;
    begin
        l_body := resolve_tokens(
            p_item_description_id, p_requisition_id, p_candidate_name, p_site_name
        );

        l_mail_id := apex_mail.send(
            p_to   => p_to,
            p_from => p_from,
            p_subj => p_subject,
            p_body => l_body
        );

        apex_mail.push_queue;

        dbms_output.put_line('Email queued, mail_id=' || l_mail_id
            || ', to=' || p_to);
    end send_email_resolved;


    -- =========================================================================
    -- LOAD_CONTENT_ITEMS — Fetch LOV list (metadata only)
    -- =========================================================================
    -- Paginates through recruitingContentLibraryItemsLOV and MERGEs into
    -- rec_content_library.  Fast — no child enclosure fetches.
    --
    -- NOTE: JSON field names below are best-guess based on Oracle REST
    -- conventions.  If the MERGE inserts 0 rows, check dbms_output for the
    -- actual JSON structure and adjust the PATH expressions.
    -- =========================================================================

    procedure load_content_items is
        l_url       varchar2(4000);
        l_body      clob;
        l_offset    number := 0;
        l_limit     number := 500;
        l_merged    number := 0;
        l_page_rows number := 0;
        l_error_msg varchar2(4000);
    begin
        loop
            -- No onlyData — we need the links array to extract the resource key
            l_url := gc_fa_base_url || gc_lov_path
                || '?limit=' || l_limit
                || '&offset=' || l_offset;

            l_body := fetch_url(l_url);

            -- Debug: show first item's canonical link
            if l_offset = 0 then
                dbms_output.put_line('First canonical: '
                    || json_value(l_body, '$.items[0].links[1].href'));
            end if;

            -- Extract content_item_id from the canonical link URL
            -- (last path segment, e.g. .../recruitingContentLibraryItemsLOV/300000054027794)
            merge into rec_content_library t
            using (
                select jt.item_description_id,
                       jt.name,
                       jt.description_code,
                       jt.description_type,
                       jt.visibility_code,
                       to_number(substr(jt.link_href,
                           instr(jt.link_href, '/', -1) + 1)) as content_item_id
                from json_table(l_body, '$.items[*]' columns (
                    item_description_id  number          path '$.ItemDescriptionId',
                    name                 varchar2(1000)  path '$.Name',
                    description_code     varchar2(240)   path '$.DescriptionCode',
                    description_type     varchar2(240)   path '$.DescriptionTypeCode',
                    visibility_code      varchar2(60)    path '$.VisibilityCode',
                    nested path '$.links[*]' columns (
                        link_rel   varchar2(60)    path '$.rel',
                        link_href  varchar2(2000)  path '$.href'
                    )
                )) jt
                where jt.link_rel = 'canonical'
                  and jt.item_description_id is not null
            ) s on (t.item_description_id = s.item_description_id)
            when matched then update set
                t.name             = s.name,
                t.description_code = s.description_code,
                t.description_type = s.description_type,
                t.visibility_code  = s.visibility_code,
                t.content_item_id  = s.content_item_id,
                t.refreshed_ts     = systimestamp
            when not matched then insert (
                item_description_id, content_item_id, name, description_code,
                description_type, visibility_code, refreshed_ts
            ) values (
                s.item_description_id, s.content_item_id, s.name, s.description_code,
                s.description_type, s.visibility_code, systimestamp
            );

            l_page_rows := sql%rowcount;
            l_merged    := l_merged + l_page_rows;

            exit when not has_more(l_body);
            l_offset := l_offset + l_limit;
        end loop;

        commit;

        dbms_output.put_line('Content library items loaded: ' || l_merged);

        -- If MERGE returned 0 rows, the JSON field names may be wrong.
        -- Check dbms_output above for the actual structure and adjust PATH.
        if l_merged = 0 then
            dbms_output.put_line('WARNING: 0 rows merged — verify JSON PATH expressions match actual field names');
            insert into bicc_load_log (
                load_type, step, rows_processed, rows_inserted, status, error_message
            ) values (
                'REC_CONTENT_LIB', 'LOAD_ITEMS', 0, 0, 'WARNING',
                'No rows merged. Check JSON field names. First 4000 chars: ' || substr(l_body, 1, 3800)
            );
        else
            insert into bicc_load_log (
                load_type, step, rows_processed, rows_inserted, status
            ) values (
                'REC_CONTENT_LIB', 'LOAD_ITEMS', l_merged, l_merged, 'SUCCESS'
            );
        end if;
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'REC_CONTENT_LIB', 'LOAD_ITEMS', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end load_content_items;


    -- =========================================================================
    -- LOAD_CONTENT_TEXT — Fetch TxtDescription + HtmlDescription enclosures
    -- =========================================================================
    -- For each item in rec_content_library, GETs the enclosure child resources
    -- and records the response body + HTTP status.
    --
    -- Pass p_item_description_id to fetch a single item, or NULL for all items.
    -- =========================================================================

    procedure load_content_text(p_item_description_id in number default null) is
        l_url        varchar2(4000);
        l_body       clob;
        l_status     number;
        l_count      number := 0;
        l_txt_found  number := 0;
        l_html_found number := 0;
        l_error_msg  varchar2(4000);
    begin
        for r in (
            select item_description_id, content_item_id
            from   rec_content_library
            where  item_description_id = nvl(p_item_description_id, item_description_id)
              and  content_item_id is not null
            order  by item_description_id
        ) loop
            l_count := l_count + 1;

            -- ---- TxtDescription ----
            begin
                l_url := gc_fa_base_url || gc_lov_path
                    || '/' || ltrim(to_char(r.content_item_id))
                    || '/enclosure/TxtDescription';

                l_body   := fetch_url(l_url);
                l_status := apex_web_service.g_status_code;

                -- Debug first 3 items
                if l_count <= 3 then
                    dbms_output.put_line('TXT #' || l_count
                        || ' cid=' || r.content_item_id
                        || ' status=' || l_status
                        || ' len=' || length(l_body));
                end if;

                update rec_content_library
                set    txt_description = case
                           when l_status between 200 and 299 then l_body
                           when l_status = 406               then l_body
                           else null
                       end,
                       txt_http_status = l_status
                where  item_description_id = r.item_description_id;

                if l_status in (200, 406) then
                    l_txt_found := l_txt_found + 1;
                end if;
            exception
                when others then
                    update rec_content_library
                    set    txt_http_status = -1
                    where  item_description_id = r.item_description_id;
            end;

            -- ---- HtmlDescription ----
            begin
                l_url := gc_fa_base_url || gc_lov_path
                    || '/' || ltrim(to_char(r.content_item_id))
                    || '/enclosure/HtmlDescription';

                l_body   := fetch_url(l_url);
                l_status := apex_web_service.g_status_code;

                update rec_content_library
                set    html_description = case
                           when l_status between 200 and 299 then l_body
                           when l_status = 406               then l_body
                           else null
                       end,
                       html_http_status = l_status
                where  item_description_id = r.item_description_id;

                if l_status in (200, 406) then
                    l_html_found := l_html_found + 1;
                end if;
            exception
                when others then
                    update rec_content_library
                    set    html_http_status = -1
                    where  item_description_id = r.item_description_id;
            end;

            -- Commit every 50 items to avoid long transactions
            if mod(l_count, 50) = 0 then
                commit;
                dbms_output.put_line('Processed ' || l_count || ' items...');
            end if;
        end loop;

        commit;

        dbms_output.put_line('Total items probed: ' || l_count);
        dbms_output.put_line('TxtDescription found: ' || l_txt_found);
        dbms_output.put_line('HtmlDescription found: ' || l_html_found);

        insert into bicc_load_log (
            load_type, step, rows_processed, rows_inserted, status
        ) values (
            'REC_CONTENT_LIB', 'LOAD_TEXT', l_count, l_txt_found + l_html_found, 'SUCCESS'
        );
        commit;

    exception
        when others then
            l_error_msg := sqlerrm;
            rollback;
            insert into bicc_load_log (
                load_type, step, status, error_message
            ) values (
                'REC_CONTENT_LIB', 'LOAD_TEXT', 'ERROR', l_error_msg
            );
            commit;
            raise;
    end load_content_text;


end pkg_rec_email;
/
