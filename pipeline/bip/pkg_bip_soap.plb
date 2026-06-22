create or replace package body pkg_bip_soap as

    c_bip_url       constant varchar2(4000) :=
    'https://<FUSION_HOST_DEV>/xmlpserver/services/ExternalReportWSSService';

    c_credential_id constant varchar2(255) :=
    '<FUSION_CREDENTIAL>';

    c_soap_action   constant varchar2(4000) :=
        'http://xmlns.oracle.com/oxp/service/PublicReportService';

    c_content_type  constant varchar2(200) :=
        'application/soap+xml; charset=UTF-8';

    c_report_folder constant varchar2(4000) :=
        '/Custom/SCI/BIP';


    -- =========================================================================
    -- Private: autonomous logger for bip_load_log
    -- =========================================================================
    -- First call (p_log_id IS NULL): INSERTs a RUNNING row, returns log_id.
    -- Subsequent calls: UPDATEs with final status, counts, error message.
    -- Autonomous so the row persists even if the caller rolls back.
    -- =========================================================================
    procedure log_bip_load (
        p_log_id        in out number,
        p_report_key    in     varchar2,
        p_report_path   in     varchar2 default null,
        p_status        in     varchar2 default 'RUNNING',
        p_source_rows   in     number   default null,
        p_rows_merged   in     number   default null,
        p_error_message in     varchar2 default null
    )
    is
        pragma autonomous_transaction;
        l_triggered_by varchar2(100);
    begin
        if p_log_id is null then
            -- Determine caller context
            if apex_application.g_flow_id is not null then
                l_triggered_by := 'MANUAL';
            else
                l_triggered_by := 'SCHEDULER';
            end if;

            insert into bip_load_log (
                report_key, report_path, status, triggered_by, started_ts
            ) values (
                p_report_key, p_report_path, p_status, l_triggered_by, systimestamp
            ) returning log_id into p_log_id;
        else
            update bip_load_log
               set status        = p_status,
                   source_rows   = nvl(p_source_rows, source_rows),
                   rows_merged   = nvl(p_rows_merged, rows_merged),
                   error_message = p_error_message,
                   completed_ts  = systimestamp
             where log_id = p_log_id;
        end if;

        commit;
    end log_bip_load;


    function normalize_report_path (
        p_report_name in varchar2
    ) return varchar2
    is
        l_report_name varchar2(4000);
    begin
        l_report_name := trim(p_report_name);

        if instr(l_report_name, '/') > 0 then
            if lower(l_report_name) not like '%.xdo' then
                l_report_name := l_report_name || '.xdo';
            end if;
            return l_report_name;
        end if;

        if lower(l_report_name) not like '%.xdo' then
            l_report_name := l_report_name || '.xdo';
        end if;

        return c_report_folder || '/' || l_report_name;
    end normalize_report_path;


    function parse_report_bytes (
        p_soap_response in clob
    ) return clob
    is
        l_report_bytes clob;
    begin
        select x.report_bytes
          into l_report_bytes
          from xmltable(
                   xmlnamespaces(
                       'http://www.w3.org/2003/05/soap-envelope' as "soap",
                       'http://xmlns.oracle.com/oxp/service/PublicReportService' as "pub"
                   ),
                   '/soap:Envelope/soap:Body/pub:runReportResponse/pub:runReportReturn'
                   passing xmltype(p_soap_response)
                   columns
                       report_bytes clob path 'pub:reportBytes'
               ) x;

        return l_report_bytes;

    exception
        when no_data_found then
            return null;
    end parse_report_bytes;


    function build_days_back_param_xml (
        p_days_back in number
    ) return clob
    is
    begin
        if p_days_back is null then
            return null;
        end if;

        return
               '<pub:parameterNameValues>'
            || '  <pub:item>'
            || '    <pub:name>P_DAYS_BACK</pub:name>'
            || '    <pub:values>'
            || '      <pub:item>' || trim(to_char(p_days_back)) || '</pub:item>'
            || '    </pub:values>'
            || '  </pub:item>'
            || '</pub:parameterNameValues>';
    end build_days_back_param_xml;


    function run_report_xml (
        p_report_name   in varchar2 default 'Extensible_Flex.xdo',
        p_parameter_xml in clob     default null
    ) return xmltype
    is
        l_report_path   varchar2(4000);
        l_soap_payload  clob;
        l_soap_response clob;
        l_base64        clob;
        l_blob          blob;
        l_xml           xmltype;
        l_status_code   number;
    begin
        l_report_path := normalize_report_path(p_report_name);

        l_soap_payload :=
              '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" '
           || 'xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">'
           || '  <soap:Header/>'
           || '  <soap:Body>'
           || '    <pub:runReport>'
           || '      <pub:reportRequest>'
           || '        <pub:attributeFormat>xml</pub:attributeFormat>'
           || '        <pub:byPassCache>true</pub:byPassCache>'
           || '        <pub:flattenXML>true</pub:flattenXML>'
           || '        <pub:reportAbsolutePath>' || l_report_path || '</pub:reportAbsolutePath>'
           || '        <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>'
           ||            nvl(p_parameter_xml, '')
           || '      </pub:reportRequest>'
           || '      <pub:appParams/>'
           || '    </pub:runReport>'
           || '  </soap:Body>'
           || '</soap:Envelope>';

        apex_web_service.clear_request_headers;

        apex_web_service.g_request_headers(1).name  := 'SOAPAction';
        apex_web_service.g_request_headers(1).value := c_soap_action;

        apex_web_service.g_request_headers(2).name  := 'Content-Type';
        apex_web_service.g_request_headers(2).value := c_content_type;

        l_soap_response := apex_web_service.make_rest_request(
            p_url                  => c_bip_url,
            p_http_method          => 'POST',
            p_body                 => l_soap_payload,
            p_credential_static_id => c_credential_id
        );

        l_status_code := apex_web_service.g_status_code;

        if l_status_code <> 200 then
            if l_soap_response like '%Data Model definition not found:%' then
                raise_application_error(
                    -20001,
                    'BIP report was found, but its internal data model reference is stale. ' ||
                    'Report path used: ' || l_report_path || '. Response: ' ||
                    substr(l_soap_response, 1, 2000)
                );
            else
                raise_application_error(
                    -20002,
                    'BIP SOAP call failed. HTTP status = ' || l_status_code ||
                    '. Report path used: ' || l_report_path ||
                    '. Response: ' || substr(l_soap_response, 1, 2000)
                );
            end if;
        end if;

        l_base64 := parse_report_bytes(l_soap_response);

        if l_base64 is null then
            raise_application_error(
                -20003,
                'No reportBytes found in SOAP response for report path ' || l_report_path
            );
        end if;

        l_blob := apex_web_service.clobbase642blob(l_base64);

        if l_blob is null then
            raise_application_error(
                -20004,
                'Unable to decode reportBytes for report path ' || l_report_path
            );
        end if;

        l_xml := xmltype(l_blob, 873); -- AL32UTF8

        if dbms_lob.istemporary(l_blob) = 1 then
            dbms_lob.freetemporary(l_blob);
        end if;

        apex_web_service.clear_request_headers;

        return l_xml;

    exception
        when others then
            apex_web_service.clear_request_headers;

            if l_blob is not null and dbms_lob.istemporary(l_blob) = 1 then
                dbms_lob.freetemporary(l_blob);
            end if;

            raise;
    end run_report_xml;


    procedure load_extensible_flex (
        p_report_name   in varchar2 default 'Extensible_Flex.xdo',
        p_parameter_xml in clob     default null
    )
    is
        l_xml          xmltype;
        l_source_rows  number;
        l_rows_merged  number;
        l_log_id       number;
        l_report_path  varchar2(4000);
        l_need_session boolean := false;
    begin
        l_report_path := normalize_report_path(p_report_name);

        -- Log: RUNNING
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'EXT_FLEX',
            p_report_path => l_report_path
        );

        if apex_application.g_flow_id is null then
            apex_session.create_session(
                p_app_id   => 121,
                p_page_id  => 1,
                p_username => 'ADMIN'
            );
            l_need_session := true;
        end if;

        l_xml := run_report_xml(
                     p_report_name   => p_report_name,
                     p_parameter_xml => p_parameter_xml
                 );

        select count(*)
          into l_source_rows
          from xmltable(
                   '//ROW'
                   passing l_xml
                   columns
                       person_extra_info_id number path 'PERSON_EXTRA_INFO_ID'
               );

        if l_source_rows = 0 then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'EXT_FLEX',
                p_status        => 'ERROR',
                p_source_rows   => 0,
                p_error_message => 'Report returned XML but no ROW nodes were found.'
            );
            raise_application_error(
                -20005,
                'Report returned XML but no ROW nodes were found. Check the XML structure.'
            );
        end if;

        merge into ext_flex_stg t
        using (
            select *
              from (
                select x.*,
                       row_number() over (
                           partition by x.person_extra_info_id
                           order by rownum
                       ) as rn
                  from xmltable(
                           '//ROW'
                           passing l_xml
                           columns
                               candidate_number         varchar2(100)  path 'CANDIDATE_NUMBER',
                               person_id                number         path 'PERSON_ID',
                               person_extra_info_id     number         path 'PERSON_EXTRA_INFO_ID',
                               information_type         varchar2(100)  path 'INFORMATION_TYPE',
                               pei_information_category varchar2(200)  path 'PEI_INFORMATION_CATEGORY',
                               effective_start_date     varchar2(50)   path 'EFFECTIVE_START_DATE',
                               effective_end_date       varchar2(50)   path 'EFFECTIVE_END_DATE',
                               pei_info1                varchar2(4000) path 'PEI_INFO1',
                               pei_info2                varchar2(4000) path 'PEI_INFO2',
                               pei_info3                varchar2(4000) path 'PEI_INFO3',
                               pei_info4                varchar2(4000) path 'PEI_INFO4',
                               pei_info5                varchar2(4000) path 'PEI_INFO5',
                               pei_info6                varchar2(4000) path 'PEI_INFO6',
                               pei_info7                varchar2(4000) path 'PEI_INFO7',
                               pei_info8                varchar2(4000) path 'PEI_INFO8',
                               pei_info9                varchar2(4000) path 'PEI_INFO9',
                               pei_info10               varchar2(4000) path 'PEI_INFO10',
                               pei_info11               varchar2(4000) path 'PEI_INFO11',
                               pei_info12               varchar2(4000) path 'PEI_INFO12',
                               pei_info13               varchar2(4000) path 'PEI_INFO13',
                               pei_info14               varchar2(4000) path 'PEI_INFO14',
                               pei_info15               varchar2(4000) path 'PEI_INFO15',
                               pei_info16               varchar2(4000) path 'PEI_INFO16',
                               pei_date1                varchar2(50)   path 'PEI_DATE1',
                               pei_date2                varchar2(50)   path 'PEI_DATE2',
                               pei_num1                 varchar2(50)   path 'PEI_NUM1',
                               pei_num2                 varchar2(50)   path 'PEI_NUM2',
                               pei_num3                 varchar2(50)   path 'PEI_NUM3',
                               pei_num4                 varchar2(50)   path 'PEI_NUM4',
                               pei_num5                 varchar2(50)   path 'PEI_NUM5',
                               pei_num6                 varchar2(50)   path 'PEI_NUM6'
                       ) x
                 where x.person_extra_info_id is not null
              )
             where rn = 1
        ) s
        on (t.person_extra_info_id = s.person_extra_info_id)
        when matched then update set
            t.person_id                = s.person_id,
            t.candidate_number         = s.candidate_number,
            t.information_type         = s.information_type,
            t.pei_information_category = s.pei_information_category,
            t.effective_start_date     = s.effective_start_date,
            t.effective_end_date       = s.effective_end_date,
            t.pei_info1                = s.pei_info1,
            t.pei_info2                = s.pei_info2,
            t.pei_info3                = s.pei_info3,
            t.pei_info4                = s.pei_info4,
            t.pei_info5                = s.pei_info5,
            t.pei_info6                = s.pei_info6,
            t.pei_info7                = s.pei_info7,
            t.pei_info8                = s.pei_info8,
            t.pei_info9                = s.pei_info9,
            t.pei_info10               = s.pei_info10,
            t.pei_info11               = s.pei_info11,
            t.pei_info12               = s.pei_info12,
            t.pei_info13               = s.pei_info13,
            t.pei_info14               = s.pei_info14,
            t.pei_info15               = s.pei_info15,
            t.pei_info16               = s.pei_info16,
            t.pei_date1                = s.pei_date1,
            t.pei_date2                = s.pei_date2,
            t.pei_num1                 = s.pei_num1,
            t.pei_num2                 = s.pei_num2,
            t.pei_num3                 = s.pei_num3,
            t.pei_num4                 = s.pei_num4,
            t.pei_num5                 = s.pei_num5,
            t.pei_num6                 = s.pei_num6,
            t.load_ts                  = systimestamp
        when not matched then insert (
            person_extra_info_id,
            person_id,
            candidate_number,
            information_type,
            pei_information_category,
            effective_start_date,
            effective_end_date,
            pei_info1,  pei_info2,  pei_info3,  pei_info4,
            pei_info5,  pei_info6,  pei_info7,  pei_info8,
            pei_info9,  pei_info10, pei_info11, pei_info12,
            pei_info13, pei_info14, pei_info15, pei_info16,
            pei_date1,
            pei_date2,
            pei_num1, pei_num2, pei_num3, pei_num4, pei_num5, pei_num6,
            load_ts
        ) values (
            s.person_extra_info_id,
            s.person_id,
            s.candidate_number,
            s.information_type,
            s.pei_information_category,
            s.effective_start_date,
            s.effective_end_date,
            s.pei_info1,  s.pei_info2,  s.pei_info3,  s.pei_info4,
            s.pei_info5,  s.pei_info6,  s.pei_info7,  s.pei_info8,
            s.pei_info9,  s.pei_info10, s.pei_info11, s.pei_info12,
            s.pei_info13, s.pei_info14, s.pei_info15, s.pei_info16,
            s.pei_date1,
            s.pei_date2,
            s.pei_num1, s.pei_num2, s.pei_num3, s.pei_num4, s.pei_num5, s.pei_num6,
            systimestamp
        );

        l_rows_merged := sql%rowcount;

        commit;

        -- Log: SUCCESS
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'EXT_FLEX',
            p_status      => 'SUCCESS',
            p_source_rows => l_source_rows,
            p_rows_merged => l_rows_merged
        );

        if l_need_session then
            apex_session.delete_session;
        end if;
    exception
        when others then
            -- Log: ERROR (autonomous, so persists after rollback)
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'EXT_FLEX',
                p_status        => 'ERROR',
                p_error_message => substr(sqlerrm, 1, 4000)
            );

            if l_need_session then
                apex_session.delete_session;
            end if;
            raise;
    end load_extensible_flex;


    procedure load_bip_dff (
        p_report_name   in varchar2 default '/Custom/SCI/BIP/DFF_XML.xdo',
        p_parameter_xml in clob     default null
    )
    is
        l_xml          xmltype;
        l_source_rows  number;
        l_rows_merged  number;
        l_log_id       number;
        l_report_path  varchar2(4000);
    begin
        l_report_path := normalize_report_path(p_report_name);

        -- Log: RUNNING
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'DFF',
            p_report_path => l_report_path
        );

        l_xml := run_report_xml(
                     p_report_name   => p_report_name,
                     p_parameter_xml => p_parameter_xml
                 );

        select count(*)
          into l_source_rows
          from xmltable(
                   '//ROW'
                   passing l_xml
                   columns
                       dff_code varchar2(80) path 'DFF_CODE'
               );

        if l_source_rows = 0 then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'DFF',
                p_status        => 'ERROR',
                p_source_rows   => 0,
                p_error_message => 'Report returned XML but no ROW nodes were found.'
            );
            raise_application_error(
                -20005,
                'Report returned XML but no ROW nodes were found. Check the XML structure.'
            );
        end if;

        merge into bip_dff t
        using (
            select x.*
              from xmltable(
                       '//ROW'
                       passing l_xml
                       columns
                           dff_code             varchar2(80)    path 'DFF_CODE',
                           dff_name             varchar2(4000)  path 'DFF_NAME',
                           context_code         varchar2(80)    path 'CONTEXT_CODE',
                           segment_code         varchar2(80)    path 'SEGMENT_CODE',
                           segment_identifier   varchar2(4000)  path 'SEGMENT_IDENTIFIER',
                           required_flag        varchar2(80)    path 'REQUIRED_FLAG',
                           data_type            varchar2(80)    path 'DATA_TYPE',
                           table_name           varchar2(4000)  path 'TABLE_NAME',
                           column_name          varchar2(4000)  path 'COLUMN_NAME',
                           value_set_code       varchar2(80)    path 'VALUE_SET_CODE',
                           last_update_date     varchar2(64)    path 'LAST_UPDATE_DATE',
                           deployment_status    varchar2(80)    path 'DEPLOYMENT_STATUS',
                           module_name          varchar2(4000)  path 'MODULE_NAME'
                   ) x
             where x.dff_code           is not null
               and x.context_code       is not null
               and x.segment_identifier is not null
        ) s
        on (
            t.dff_code             = s.dff_code
            and t.context_code     = s.context_code
            and t.segment_identifier = s.segment_identifier
        )
        when matched then update set
            t.dff_name           = s.dff_name,
            t.segment_code       = s.segment_code,
            t.required_flag      = s.required_flag,
            t.data_type          = s.data_type,
            t.table_name         = s.table_name,
            t.column_name        = s.column_name,
            t.value_set_code     = s.value_set_code,
            t.last_update_date   = case
                                       when s.last_update_date is not null
                                       then to_timestamp_tz(
                                                s.last_update_date,
                                                'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                                            )
                                   end,
            t.deployment_status  = s.deployment_status,
            t.module_name        = s.module_name,
            t.load_ts            = systimestamp
        when not matched then insert (
            dff_code,
            dff_name,
            context_code,
            segment_code,
            segment_identifier,
            required_flag,
            data_type,
            table_name,
            column_name,
            value_set_code,
            last_update_date,
            deployment_status,
            module_name,
            load_ts
        ) values (
            s.dff_code,
            s.dff_name,
            s.context_code,
            s.segment_code,
            s.segment_identifier,
            s.required_flag,
            s.data_type,
            s.table_name,
            s.column_name,
            s.value_set_code,
            case
                when s.last_update_date is not null
                then to_timestamp_tz(
                         s.last_update_date,
                         'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                     )
            end,
            s.deployment_status,
            s.module_name,
            systimestamp
        );

        l_rows_merged := sql%rowcount;

        commit;

        -- Log: SUCCESS
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'DFF',
            p_status      => 'SUCCESS',
            p_source_rows => l_source_rows,
            p_rows_merged => l_rows_merged
        );

    exception
        when others then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'DFF',
                p_status        => 'ERROR',
                p_error_message => substr(sqlerrm, 1, 4000)
            );
            raise;
    end load_bip_dff;


    procedure load_bip_questionnaires (
        p_report_name   in varchar2 default '/Custom/SCI/BIP/Questionnaires.xdo',
        p_parameter_xml in clob     default null,
        p_days_back     in number   default 30
    )
    is
        l_xml            xmltype;
        l_source_rows    number;
        l_rows_merged    number;
        l_log_id         number;
        l_report_path    varchar2(4000);
        l_parameter_xml  clob;
    begin
        l_report_path := normalize_report_path(p_report_name);

        -- Log: RUNNING
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'QUESTIONNAIRES',
            p_report_path => l_report_path
        );

        if p_parameter_xml is not null then
            l_parameter_xml := p_parameter_xml;
        else
            l_parameter_xml := build_days_back_param_xml(p_days_back);
        end if;

        l_xml := run_report_xml(
                     p_report_name   => p_report_name,
                     p_parameter_xml => l_parameter_xml
                 );

        select count(*)
          into l_source_rows
          from xmltable(
                   '//ROW'
                   passing l_xml
                   columns
                       questionnaire_code varchar2(80) path 'QUESTIONNAIRE_CODE'
               );

        if l_source_rows = 0 then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'QUESTIONNAIRES',
                p_status        => 'ERROR',
                p_source_rows   => 0,
                p_error_message => 'Report returned XML but no ROW nodes were found.'
            );
            raise_application_error(
                -20005,
                'Report returned XML but no ROW nodes were found. Check the XML structure.'
            );
        end if;

        merge into bip_questionnaires t
        using (
            select
                x.questionnaire_code,
                x.question_code,

                case
                    when regexp_like(trim(x.qstnr_participant_id), '^\d+$')
                    then to_number(trim(x.qstnr_participant_id))
                end as qstnr_participant_id_num,

                case
                    when regexp_like(trim(x.requisition_id), '^\d+$')
                    then to_number(trim(x.requisition_id))
                end as requisition_id_num,

                case
                    when regexp_like(trim(x.qstn_response_id), '^\d+$')
                    then to_number(trim(x.qstn_response_id))
                end as qstn_response_id_num,

                x.qstnr_version_num,
                x.questionnaire_name,
                x.section_seq_num,
                x.question_seq_num,
                x.question_text,
                x.question_type,
                x.participant_type,
                x.participant_id as participant_id_txt,
                x.subject_code,

                case
                    when regexp_like(trim(x.subject_id), '^\d+$')
                    then to_number(trim(x.subject_id))
                end as subject_id_num,

                case
                    when regexp_like(trim(x.qstnr_response_id), '^\d+$')
                    then to_number(trim(x.qstnr_response_id))
                end as qstnr_response_id_num,

                x.attempt_num,

                case
                    when regexp_like(trim(x.submission_id), '^\d+$')
                    then to_number(trim(x.submission_id))
                end as submission_id_num,

                x.answer_text,

                case
                    when regexp_like(trim(x.candidate_person_id), '^\d+$')
                    then to_number(trim(x.candidate_person_id))
                end as candidate_person_id_num,

                x.candidate_number,
                x.candidate_name,
                x.recruiting_type,
                x.requisition_title,
                x.answer_mode,

                case
                    when x.questionnaire_def_creation_date is not null
                    then to_timestamp_tz(
                             x.questionnaire_def_creation_date,
                             'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                         )
                end as questionnaire_def_creation_date_tstz,

                case
                    when x.questionnaire_def_last_update_date is not null
                    then to_timestamp_tz(
                             x.questionnaire_def_last_update_date,
                             'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                         )
                end as questionnaire_def_last_update_date_tstz,

                case
                    when x.questionnaire_issued_date is not null
                    then to_timestamp_tz(
                             x.questionnaire_issued_date,
                             'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                         )
                end as questionnaire_issued_date_tstz,

                case
                    when x.response_creation_date is not null
                    then to_timestamp_tz(
                             x.response_creation_date,
                             'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                         )
                end as response_creation_date_tstz,

                case
                    when x.response_last_update_date is not null
                    then to_timestamp_tz(
                             x.response_last_update_date,
                             'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                         )
                end as response_last_update_date_tstz,

                case
                    when x.response_submitted_date is not null
                    then to_timestamp_tz(
                             x.response_submitted_date,
                             'YYYY-MM-DD"T"HH24:MI:SS.FFTZH:TZM'
                         )
                end as response_submitted_date_tstz

            from xmltable(
                     '//ROW'
                     passing l_xml
                     columns
                         questionnaire_code                 varchar2(80)   path 'QUESTIONNAIRE_CODE',
                         question_code                      varchar2(80)   path 'QUESTION_CODE',
                         qstnr_participant_id               varchar2(80)   path 'QSTNR_PARTICIPANT_ID',
                         requisition_id                     varchar2(80)   path 'REQUISITION_ID',
                         qstn_response_id                   varchar2(80)   path 'QSTN_RESPONSE_ID',
                         qstnr_version_num                  varchar2(4000) path 'QSTNR_VERSION_NUM',
                         questionnaire_name                 varchar2(400)  path 'QUESTIONNAIRE_NAME',
                         section_seq_num                    varchar2(4000) path 'SECTION_SEQ_NUM',
                         question_seq_num                   varchar2(4000) path 'QUESTION_SEQ_NUM',
                         question_text                      varchar2(4000) path 'QUESTION_TEXT',
                         question_type                      varchar2(80)   path 'QUESTION_TYPE',
                         participant_type                   varchar2(80)   path 'PARTICIPANT_TYPE',
                         participant_id                     varchar2(255)  path 'PARTICIPANT_ID',
                         subject_code                       varchar2(80)   path 'SUBJECT_CODE',
                         subject_id                         varchar2(80)   path 'SUBJECT_ID',
                         qstnr_response_id                  varchar2(80)   path 'QSTNR_RESPONSE_ID',
                         attempt_num                        varchar2(4000) path 'ATTEMPT_NUM',
                         submission_id                      varchar2(80)   path 'SUBMISSION_ID',
                         answer_text                        varchar2(4000) path 'ANSWER_TEXT',
                         candidate_person_id                varchar2(80)   path 'CANDIDATE_PERSON_ID',
                         candidate_number                   varchar2(80)   path 'CANDIDATE_NUMBER',
                         candidate_name                     varchar2(400)  path 'CANDIDATE_NAME',
                         recruiting_type                    varchar2(80)   path 'RECRUITING_TYPE',
                         requisition_title                  varchar2(400)  path 'REQUISITION_TITLE',
                         answer_mode                        varchar2(4000) path 'ANSWER_MODE',
                         questionnaire_def_creation_date    varchar2(64)   path 'QUESTIONNAIRE_DEF_CREATION_DATE',
                         questionnaire_def_last_update_date varchar2(64)   path 'QUESTIONNAIRE_DEF_LAST_UPDATE_DATE',
                         questionnaire_issued_date          varchar2(64)   path 'QUESTIONNAIRE_ISSUED_DATE',
                         response_creation_date             varchar2(64)   path 'RESPONSE_CREATION_DATE',
                         response_last_update_date          varchar2(64)   path 'RESPONSE_LAST_UPDATE_DATE',
                         response_submitted_date            varchar2(64)   path 'RESPONSE_SUBMITTED_DATE'
                 ) x
            where x.questionnaire_code is not null
              and x.question_code      is not null
              and regexp_like(trim(x.qstnr_participant_id), '^\d+$')
              and regexp_like(trim(x.requisition_id), '^\d+$')
        ) s
        on (
               t.questionnaire_code   = s.questionnaire_code
           and t.question_code        = s.question_code
           and t.qstnr_participant_id = s.qstnr_participant_id_num
           and t.requisition_id       = s.requisition_id_num
        )
        when matched then update set
            t.qstn_response_id                    = s.qstn_response_id_num,
            t.qstnr_version_num                   = s.qstnr_version_num,
            t.questionnaire_name                  = s.questionnaire_name,
            t.section_seq_num                     = s.section_seq_num,
            t.question_seq_num                    = s.question_seq_num,
            t.question_text                       = s.question_text,
            t.question_type                       = s.question_type,
            t.participant_type                    = s.participant_type,
            t.participant_id                      = s.participant_id_txt,
            t.subject_code                        = s.subject_code,
            t.subject_id                          = s.subject_id_num,
            t.qstnr_response_id                   = s.qstnr_response_id_num,
            t.attempt_num                         = s.attempt_num,
            t.submission_id                       = s.submission_id_num,
            t.answer_text                         = s.answer_text,
            t.candidate_person_id                 = s.candidate_person_id_num,
            t.candidate_number                    = s.candidate_number,
            t.candidate_name                      = s.candidate_name,
            t.recruiting_type                     = s.recruiting_type,
            t.requisition_title                   = s.requisition_title,
            t.response_submitted_date             = s.response_submitted_date_tstz,
            t.answer_mode                         = s.answer_mode,
            t.questionnaire_def_creation_date     = s.questionnaire_def_creation_date_tstz,
            t.questionnaire_def_last_update_date  = s.questionnaire_def_last_update_date_tstz,
            t.questionnaire_issued_date           = s.questionnaire_issued_date_tstz,
            t.response_creation_date              = s.response_creation_date_tstz,
            t.response_last_update_date           = s.response_last_update_date_tstz,
            t.load_ts                             = systimestamp
        when not matched then insert (
            questionnaire_code,
            question_code,
            qstnr_participant_id,
            requisition_id,
            qstn_response_id,
            qstnr_version_num,
            questionnaire_name,
            section_seq_num,
            question_seq_num,
            question_text,
            question_type,
            participant_type,
            participant_id,
            subject_code,
            subject_id,
            qstnr_response_id,
            attempt_num,
            submission_id,
            answer_text,
            candidate_person_id,
            candidate_number,
            candidate_name,
            recruiting_type,
            requisition_title,
            response_submitted_date,
            answer_mode,
            load_ts,
            questionnaire_def_creation_date,
            questionnaire_def_last_update_date,
            questionnaire_issued_date,
            response_creation_date,
            response_last_update_date
        ) values (
            s.questionnaire_code,
            s.question_code,
            s.qstnr_participant_id_num,
            s.requisition_id_num,
            s.qstn_response_id_num,
            s.qstnr_version_num,
            s.questionnaire_name,
            s.section_seq_num,
            s.question_seq_num,
            s.question_text,
            s.question_type,
            s.participant_type,
            s.participant_id_txt,
            s.subject_code,
            s.subject_id_num,
            s.qstnr_response_id_num,
            s.attempt_num,
            s.submission_id_num,
            s.answer_text,
            s.candidate_person_id_num,
            s.candidate_number,
            s.candidate_name,
            s.recruiting_type,
            s.requisition_title,
            s.response_submitted_date_tstz,
            s.answer_mode,
            systimestamp,
            s.questionnaire_def_creation_date_tstz,
            s.questionnaire_def_last_update_date_tstz,
            s.questionnaire_issued_date_tstz,
            s.response_creation_date_tstz,
            s.response_last_update_date_tstz
        );

        l_rows_merged := sql%rowcount;

        commit;

        -- Log: SUCCESS
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'QUESTIONNAIRES',
            p_status      => 'SUCCESS',
            p_source_rows => l_source_rows,
            p_rows_merged => l_rows_merged
        );

    exception
        when others then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'QUESTIONNAIRES',
                p_status        => 'ERROR',
                p_error_message => substr(sqlerrm, 1, 4000)
            );
            raise;
    end load_bip_questionnaires;


    procedure load_gallup_assessments (
        p_report_name   in varchar2 default '/Custom/SCI/BIP/Gallup_XML.xdo',
        p_parameter_xml in clob     default null
    )
    is
        l_xml          xmltype;
        l_source_rows  number;
        l_rows_merged  number;
        l_log_id       number;
        l_report_path  varchar2(4000);
        l_need_session boolean := false;
    begin
        l_report_path := normalize_report_path(p_report_name);

        -- Log: RUNNING
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'GALLUP',
            p_report_path => l_report_path
        );

        if apex_application.g_flow_id is null then
            apex_session.create_session(
                p_app_id   => 121,
                p_page_id  => 1,
                p_username => 'ADMIN'
            );
            l_need_session := true;
        end if;

        l_xml := run_report_xml(
                     p_report_name   => p_report_name,
                     p_parameter_xml => p_parameter_xml
                 );

        select count(*)
          into l_source_rows
          from xmltable(
                   '//ROW'
                   passing l_xml
                   columns
                       submission_id number path 'SUBMISSION_ID'
               );

        if l_source_rows = 0 then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'GALLUP',
                p_status        => 'ERROR',
                p_source_rows   => 0,
                p_error_message => 'Gallup_XML report returned XML but no ROW nodes were found.'
            );
            raise_application_error(
                -20005,
                'Gallup_XML report returned XML but no ROW nodes were found. Check the XML structure.'
            );
        end if;

        merge into bip_gallup_assessments t
        using (
            select *
              from (
                select x.*,
                       row_number() over (
                           partition by x.submission_id
                           order by rownum
                       ) as rn
                  from xmltable(
                           '//ROW'
                           passing l_xml
                           columns
                               submission_id       number         path 'SUBMISSION_ID',
                               package_status_code varchar2(80)   path 'PACKAGE_STATUS_CODE',
                               band                varchar2(400)  path 'BAND',
                               score               number         path 'SCORE',
                               requisition_id      number         path 'REQUISITION_ID',
                               requisition_title   varchar2(400)  path 'REQUISITION_TITLE',
                               person_id           number         path 'PERSON_ID',
                               candidate_name      varchar2(400)  path 'CANDIDATE_NAME',
                               gallup_result_url   varchar2(4000) path 'GALLUP_RESULT_URL'
                       ) x
                 where x.submission_id is not null
              )
             where rn = 1
        ) s
        on (t.submission_id = s.submission_id)
        when matched then update set
            t.package_status_code = s.package_status_code,
            t.band                = s.band,
            t.score               = s.score,
            t.requisition_id      = s.requisition_id,
            t.requisition_title   = s.requisition_title,
            t.person_id           = s.person_id,
            t.candidate_name      = s.candidate_name,
            t.gallup_result_url   = s.gallup_result_url,
            t.load_ts             = systimestamp
        when not matched then insert (
            submission_id,
            package_status_code,
            band,
            score,
            requisition_id,
            requisition_title,
            person_id,
            candidate_name,
            gallup_result_url,
            load_ts
        ) values (
            s.submission_id,
            s.package_status_code,
            s.band,
            s.score,
            s.requisition_id,
            s.requisition_title,
            s.person_id,
            s.candidate_name,
            s.gallup_result_url,
            systimestamp
        );

        l_rows_merged := sql%rowcount;

        commit;

        -- Log: SUCCESS
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'GALLUP',
            p_status      => 'SUCCESS',
            p_source_rows => l_source_rows,
            p_rows_merged => l_rows_merged
        );

        if l_need_session then
            apex_session.delete_session;
        end if;
    exception
        when others then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'GALLUP',
                p_status        => 'ERROR',
                p_error_message => substr(sqlerrm, 1, 4000)
            );

            if l_need_session then
                apex_session.delete_session;
            end if;
            raise;
    end load_gallup_assessments;


    -- =========================================================================
    -- load_fa_user_accounts
    -- =========================================================================
    -- Loads Fusion user accounts from BIP report into FA_USER_ACCOUNTS.
    -- MERGE on USER_GUID (natural key for Fusion users).
    -- =========================================================================
    procedure load_fa_user_accounts (
        p_report_name   in varchar2 default '/Custom/SCI/BIP/User Account_XML.xdo',
        p_parameter_xml in clob     default null
    )
    is
        l_xml          xmltype;
        l_source_rows  number;
        l_rows_merged  number;
        l_log_id       number;
        l_report_path  varchar2(4000);
        l_need_session boolean := false;
    begin
        l_report_path := normalize_report_path(p_report_name);

        -- Log: RUNNING
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'USER_ACCOUNTS',
            p_report_path => l_report_path
        );

        if apex_application.g_flow_id is null then
            apex_session.create_session(
                p_app_id   => 121,
                p_page_id  => 1,
                p_username => 'ADMIN'
            );
            l_need_session := true;
        end if;

        l_xml := run_report_xml(
                     p_report_name   => p_report_name,
                     p_parameter_xml => p_parameter_xml
                 );

        select count(*)
          into l_source_rows
          from xmltable(
                   '//ROW'
                   passing l_xml
                   columns
                       user_guid varchar2(64) path 'USER_GUID'
               );

        if l_source_rows = 0 then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'USER_ACCOUNTS',
                p_status        => 'ERROR',
                p_source_rows   => 0,
                p_error_message => 'User_Account_XML report returned XML but no ROW nodes were found.'
            );
            raise_application_error(
                -20005,
                'User_Account_XML report returned XML but no ROW nodes were found.'
            );
        end if;

        merge into fa_user_accounts t
        using (
            select *
              from (
                select x.*,
                       row_number() over (
                           partition by x.user_guid
                           order by rownum
                       ) as rn
                  from xmltable(
                           '//ROW'
                           passing l_xml
                           columns
                               username                varchar2(255) path 'USERNAME',
                               user_id                 number        path 'USER_ID',
                               user_guid               varchar2(64)  path 'USER_GUID',
                               person_id               number        path 'PERSON_ID',
                               active_flag             varchar2(30)  path 'ACTIVE_FLAG',
                               hr_terminated           varchar2(30)  path 'HR_TERMINATED',
                               suspended               varchar2(30)  path 'SUSPENDED',
                               credentials_email_sent  varchar2(30)  path 'CREDENTIALS_EMAIL_SENT',
                               user_first_name         varchar2(255) path 'USER_FIRST_NAME',
                               user_last_name          varchar2(255) path 'USER_LAST_NAME',
                               user_email              varchar2(255) path 'USER_EMAIL',
                               user_category           varchar2(30)  path 'USER_CATEGORY',
                               ase_user_id             number        path 'ASE_USER_ID',
                               person_number           varchar2(10)  path 'PERSON_NUMBER'
                       ) x
                 where x.user_guid is not null
              )
             where rn = 1
        ) s
        on (t.user_guid = s.user_guid)
        when matched then update set
            t.username               = s.username,
            t.user_id                = s.user_id,
            t.person_id              = s.person_id,
            t.active_flag            = s.active_flag,
            t.hr_terminated          = s.hr_terminated,
            t.suspended              = s.suspended,
            t.credentials_email_sent = s.credentials_email_sent,
            t.user_first_name        = s.user_first_name,
            t.user_last_name         = s.user_last_name,
            t.user_email             = s.user_email,
            t.user_category          = s.user_category,
            t.ase_user_id            = s.ase_user_id,
            t.person_number          = s.person_number,
            t.load_ts                = systimestamp
        when not matched then insert (
            username,
            user_id,
            user_guid,
            person_id,
            active_flag,
            hr_terminated,
            suspended,
            credentials_email_sent,
            user_first_name,
            user_last_name,
            user_email,
            user_category,
            ase_user_id,
            person_number,
            load_ts
        ) values (
            s.username,
            s.user_id,
            s.user_guid,
            s.person_id,
            s.active_flag,
            s.hr_terminated,
            s.suspended,
            s.credentials_email_sent,
            s.user_first_name,
            s.user_last_name,
            s.user_email,
            s.user_category,
            s.ase_user_id,
            s.person_number,
            systimestamp
        );

        l_rows_merged := sql%rowcount;

        commit;

        -- Log: SUCCESS
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'USER_ACCOUNTS',
            p_status      => 'SUCCESS',
            p_source_rows => l_source_rows,
            p_rows_merged => l_rows_merged
        );

        if l_need_session then
            apex_session.delete_session;
        end if;
    exception
        when others then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'USER_ACCOUNTS',
                p_status        => 'ERROR',
                p_error_message => substr(sqlerrm, 1, 4000)
            );

            if l_need_session then
                apex_session.delete_session;
            end if;
            raise;
    end load_fa_user_accounts;


    -- =========================================================================
    -- load_fa_user_roles
    -- =========================================================================
    -- Loads Fusion user-to-role assignments from BIP report into FA_USER_ROLES.
    -- DELETE + INSERT pattern — roles can be added or removed, so a full
    -- refresh is the safest approach (same as source client pattern).
    -- =========================================================================
    procedure load_fa_user_roles (
        p_report_name   in varchar2 default '/Custom/SCI/BIP/user_roles_XML.xdo',
        p_parameter_xml in clob     default null
    )
    is
        l_xml          xmltype;
        l_source_rows  number;
        l_rows_merged  number;
        l_log_id       number;
        l_report_path  varchar2(4000);
        l_need_session boolean := false;
    begin
        l_report_path := normalize_report_path(p_report_name);

        -- Log: RUNNING
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'USER_ROLES',
            p_report_path => l_report_path
        );

        if apex_application.g_flow_id is null then
            apex_session.create_session(
                p_app_id   => 121,
                p_page_id  => 1,
                p_username => 'ADMIN'
            );
            l_need_session := true;
        end if;

        l_xml := run_report_xml(
                     p_report_name   => p_report_name,
                     p_parameter_xml => p_parameter_xml
                 );

        select count(*)
          into l_source_rows
          from xmltable(
                   '//ROW'
                   passing l_xml
                   columns
                       user_id number path 'USER_ID'
               );

        if l_source_rows = 0 then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'USER_ROLES',
                p_status        => 'ERROR',
                p_source_rows   => 0,
                p_error_message => 'User_Role_XML report returned XML but no ROW nodes were found.'
            );
            raise_application_error(
                -20005,
                'User_Role_XML report returned XML but no ROW nodes were found.'
            );
        end if;

        -- Full refresh: delete all existing rows then insert fresh data
        delete from fa_user_roles;

        insert into fa_user_roles (
            user_id,
            user_guid,
            ase_role_id,
            role_common_name,
            type_code,
            role_name,
            effective_end_date,
            load_ts
        )
        select
            x.user_id,
            x.user_guid,
            x.ase_role_id,
            x.role_common_name,
            x.type_code,
            x.role_name,
            to_timestamp_tz(
                x.effective_end_date,
                'YYYY-MM-DD"T"HH24:MI:SS.FF TZH:TZM'
            ),
            systimestamp
        from xmltable(
                 '//ROW'
                 passing l_xml
                 columns
                     user_id            number         path 'USER_ID',
                     user_guid          varchar2(64)   path 'USER_GUID',
                     ase_role_id        number         path 'ASE_ROLE_ID',
                     role_common_name   varchar2(4000) path 'ROLE_COMMON_NAME',
                     type_code          varchar2(30)   path 'TYPE_CODE',
                     role_name          varchar2(4000) path 'ROLE_NAME',
                     effective_end_date varchar2(50)   path 'EFFECTIVE_END_DATE'
             ) x;

        l_rows_merged := sql%rowcount;

        commit;

        -- Log: SUCCESS
        log_bip_load(
            p_log_id      => l_log_id,
            p_report_key  => 'USER_ROLES',
            p_status      => 'SUCCESS',
            p_source_rows => l_source_rows,
            p_rows_merged => l_rows_merged
        );

        if l_need_session then
            apex_session.delete_session;
        end if;
    exception
        when others then
            log_bip_load(
                p_log_id        => l_log_id,
                p_report_key    => 'USER_ROLES',
                p_status        => 'ERROR',
                p_error_message => substr(sqlerrm, 1, 4000)
            );

            if l_need_session then
                apex_session.delete_session;
            end if;
            raise;
    end load_fa_user_roles;


end pkg_bip_soap;
/
