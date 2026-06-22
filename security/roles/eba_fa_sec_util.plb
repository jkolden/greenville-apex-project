create or replace package body eba_fa_sec_util

as

function build_bip_path (
    p_report_file in varchar2
) return varchar2
is
begin
    return rtrim(g_bip_base_folder, '/') || '/' || ltrim(p_report_file, '/');
end build_bip_path;


function parse_bip_response(p_clob in out nocopy clob)
    return clob
    is

   l_xml XMLTYPE;
   l_data CLOB;
   l_xml_data BLOB;

   begin

   --make the clob an xmltype so we can parse as usual
    l_xml := XMLTYPE.createXML(p_clob);

    select data into l_data
       from
       XMLTable(
             XMLNamespaces(
                 'http://www.w3.org/2003/05/soap-envelope'  AS "SOAP-ENV"
                ,'http://xmlns.oracle.com/oxp/service/PublicReportService' AS  "ns2"

              ), 'SOAP-ENV:Envelope/SOAP-ENV:Body/ns2:runReportResponse/ns2:runReportReturn/ns2:reportBytes'
              passing   l_xml
              columns data clob path '.'
           ) ;

           return l_data;

end parse_bip_response;

function run_bip_report_via_soapapi (
    p_report_path      in varchar2,              -- /Custom/.../MyReport.xdo
    p_attribute_format in varchar2 default 'xml',   
    p_bypass_cache     in boolean  default true,
    p_flatten_xml      in boolean  default true,
    p_parameter_xml    in clob     default null,
    p_instance_id      in number   default v('G_INSTANCE_ID')
) return xmltype
is
    l_fusion_host    fusion_instance_cfg.fusion_host%type;
    l_cred_static_id fusion_instance_cfg.cred_static_id%type;

    l_bip_url        varchar2(4000);

    c_soap_action       constant varchar2(4000) := 'http://xmlns.oracle.com/oxp/service/PublicReportService';
    c_soap_content_type constant varchar2(200)  := 'application/soap+xml; charset=UTF-8';

    l_soap_payload   clob;
    l_status_code    number;
    l_decoded_base64 blob;
    l_base64         clob;
    l_soap_response  clob;
    l_xml            xmltype;

    function bool_to_tf (p_flag boolean) return varchar2 is
    begin
        if p_flag then
            return 'true';
        else
            return 'false';
        end if;
    end bool_to_tf;

begin
    -- look up instance configuration
    select fusion_host, cred_static_id
      into l_fusion_host, l_cred_static_id
      from fusion_instance_cfg
     where instance_id = p_instance_id;

    l_bip_url := 'https://' || l_fusion_host || '/xmlpserver/services/ExternalReportWSSService';

    -- build soap payload (parameterized)
    l_soap_payload :=
          '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" '
        || 'xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">'
        || '  <soap:Header/>'
        || '  <soap:Body>'
        || '    <pub:runReport>'
        || '      <pub:reportRequest>'
        || '        <pub:attributeFormat>' || p_attribute_format || '</pub:attributeFormat>'
        || '        <pub:byPassCache>'     || bool_to_tf(p_bypass_cache) || '</pub:byPassCache>'
        || '        <pub:flattenXML>'      || bool_to_tf(p_flatten_xml)  || '</pub:flattenXML>'
        || '        <pub:reportAbsolutePath>' || p_report_path || '</pub:reportAbsolutePath>'
        || '        <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>'
        || case
               when p_parameter_xml is not null then
                   p_parameter_xml   
               else
                   null
           end
        || '      </pub:reportRequest>'
        || '      <pub:appParams></pub:appParams>'
        || '    </pub:runReport>'
        || '  </soap:Body>'
        || '</soap:Envelope>';

    -- clean slate for headers in case this session made other calls
    apex_web_service.clear_request_headers;

    apex_web_service.g_request_headers(1).name  := 'SOAPAction';
    apex_web_service.g_request_headers(1).value := c_soap_action;
    apex_web_service.g_request_headers(2).name  := 'Content-Type';
    apex_web_service.g_request_headers(2).value := c_soap_content_type;

    -- call soap endpoint
    l_soap_response := apex_web_service.make_rest_request(
        p_url                  => l_bip_url,
        p_http_method          => 'POST',
        p_body                 => l_soap_payload,
        p_credential_static_id => l_cred_static_id
    );

    l_status_code := apex_web_service.g_status_code;

    -- basic http error handling
    if l_status_code <> 200 then
        raise_application_error(
            -20010,
            'BIP SOAP call failed. HTTP status code = ' || l_status_code ||
            case
                when l_soap_response is not null
                then ' Response snippet: ' || substr(l_soap_response, 1, 1000)
            end
        );
    end if;

    -- extract base64 from soap response
    l_base64 := parse_bip_response(l_soap_response);

    if l_base64 is null then
        raise_application_error(
            -20011,
            'BIP SOAP response did not contain a base64 payload.'
        );
    end if;

    -- decode base64 into blob
    l_decoded_base64 := apex_web_service.clobbase642blob(l_base64);

    if l_decoded_base64 is null then
        raise_application_error(
            -20012,
            'unable to decode base64 bip payload into blob.'
        );
    end if;

    -- convert blob to xmltype
    if lower(p_attribute_format) = 'xml' then
        -- 873 = AL32UTF8 character set
        l_xml := xmltype(l_decoded_base64, 873);
    else
        raise_application_error(
            -20013,
            'run_bip_report_via_soapapi currently supports only xml format.'
        );
    end if;

    -- free temporary blob if needed
    if l_decoded_base64 is not null
       and dbms_lob.istemporary(l_decoded_base64) = 1
    then
        dbms_lob.freetemporary(l_decoded_base64);
    end if;

    apex_web_service.clear_request_headers;

    return l_xml;

exception
    when others then
        apex_debug.error(
            p_message => 'run_bip_report_via_soapapi (xml) failed: %s',
            p0        => sqlerrm
        );

        apex_web_service.clear_request_headers;

        if l_decoded_base64 is not null
           and dbms_lob.istemporary(l_decoded_base64) = 1
        then
            dbms_lob.freetemporary(l_decoded_base64);
        end if;

        raise;

end run_bip_report_via_soapapi;



PROCEDURE refresh_fa_user_account (p_instance_id in number default v('G_INSTANCE_ID'))
IS
    l_xml XMLTYPE;
BEGIN
    l_xml := run_bip_report_via_soapapi(
                 p_report_path   => build_bip_path('User Account_XML_v2.xdo'),
                 p_instance_id   => p_instance_id
             );

    MERGE INTO fa_user_account_bk t
    USING (
        SELECT
            x.username,
            x.user_id,
            x.user_guid,
            x.person_id,
            x.active_flag,
            x.hr_terminated,
            x.suspended,
            x.credentials_email_sent,
            x.user_first_name,
            x.user_last_name,
            x.user_email,
            x.user_category,
            x.ase_user_id,
            x.person_number
        FROM XMLTABLE(
                 '/ROWSET/ROW'
                 PASSING l_xml
                 COLUMNS
                     username                VARCHAR2(255) PATH 'USERNAME',
                     user_id                 NUMBER        PATH 'USER_ID',
                     user_guid               VARCHAR2(64)  PATH 'USER_GUID',
                     person_id               NUMBER        PATH 'PERSON_ID',
                     active_flag             VARCHAR2(30)  PATH 'ACTIVE_FLAG',
                     hr_terminated           VARCHAR2(30)  PATH 'HR_TERMINATED',
                     suspended               VARCHAR2(30)  PATH 'SUSPENDED',
                     credentials_email_sent  VARCHAR2(30)  PATH 'CREDENTIALS_EMAIL_SENT',
                     user_first_name         VARCHAR2(255) PATH 'USER_FIRST_NAME',
                     user_last_name          VARCHAR2(255) PATH 'USER_LAST_NAME',
                     user_email              VARCHAR2(255) PATH 'USER_EMAIL',
                     user_category           VARCHAR2(30)  PATH 'USER_CATEGORY',
                     ase_user_id             NUMBER        PATH 'ASE_USER_ID',
                     person_number           VARCHAR2(10)  PATH 'PERSON_NUMBER'
             ) x
    ) s
on (t.user_guid = s.user_guid and t.instance_id = p_instance_id)
    WHEN MATCHED THEN
        UPDATE SET
            t.username               = s.username,
           -- t.user_guid              = s.user_guid,
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
            t.person_number          = s.person_number
    WHEN NOT MATCHED THEN
        INSERT (
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
            instance_id
        )
        VALUES (
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
            p_instance_id
        );

    COMMIT;
END;

procedure refresh_fa_role_list (p_instance_id in number default v('G_INSTANCE_ID'))
is
    l_xml xmltype;
begin
    -- run the bip report and get xml
    l_xml := run_bip_report_via_soapapi(
                 p_report_path => build_bip_path('Role List_XML.xdo'),
                 p_instance_id => p_instance_id
             );

    merge into fa_role_list_bk t
    using (
        select *
        from (
            select
                x.ase_role_id,
                x.seeded_flag,
                x.ase_code,
                x.role_id,
                x.role_guid,
                x.role_common_name,
                x.abstract_role,
                x.job_role,
                x.data_role,
                x.role_name,
                x.description,
                row_number() over (
                    partition by x.ase_role_id
                    order by x.ase_role_id
                ) rn
            from xmltable(
                     '/ROWSET/ROW'
                     passing l_xml
                     columns
                         ase_role_id      number         path 'ASE_ROLE_ID',
                         seeded_flag      varchar2(30)   path 'SEEDED_FLAG',
                         ase_code         varchar2(4000) path 'ASE_CODE',
                         role_id          number         path 'ROLE_ID',
                         role_guid        varchar2(64)   path 'ROLE_GUID',
                         role_common_name varchar2(4000) path 'ROLE_COMMON_NAME',
                         abstract_role    varchar2(30)   path 'ABSTRACT_ROLE',
                         job_role         varchar2(30)   path 'JOB_ROLE',
                         data_role        varchar2(30)   path 'DATA_ROLE',
                         role_name        varchar2(4000) path 'ROLE_NAME',
                         description      varchar2(4000) path 'DESCRIPTION'
                 ) x
        )
        where rn = 1
    ) s
    on (t.ase_role_id = s.ase_role_id and t.instance_id = p_instance_id)
    when matched then
        update set
            t.seeded_flag      = s.seeded_flag,
            t.ase_code         = s.ase_code,
            t.role_id          = s.role_id,
            t.role_guid        = s.role_guid,
            t.role_common_name = s.role_common_name,
            t.abstract_role    = s.abstract_role,
            t.job_role         = s.job_role,
            t.data_role        = s.data_role,
            t.role_name        = s.role_name,
            t.description      = s.description
    when not matched then
        insert (
            ase_role_id,
            seeded_flag,
            ase_code,
            role_id,
            role_guid,
            role_common_name,
            abstract_role,
            job_role,
            data_role,
            role_name,
            description,
            instance_id
        )
        values (
            s.ase_role_id,
            s.seeded_flag,
            s.ase_code,
            s.role_id,
            s.role_guid,
            s.role_common_name,
            s.abstract_role,
            s.job_role,
            s.data_role,
            s.role_name,
            s.description,
            p_instance_id
        );

    commit;
end refresh_fa_role_list;

procedure refresh_fa_inherited_role (p_instance_id in number default v('G_INSTANCE_ID'))
is
    l_xml xmltype;
begin
    -- run the bip report and get xml
    l_xml := run_bip_report_via_soapapi(
                 p_report_path => build_bip_path('Inherited Roles_XML.xdo'),
                 p_instance_id => p_instance_id
             );

    merge into fa_inherited_role_bk t
    using (
        select *
        from (
            select
                x.role_id,
                x.top_role_code,
                x.top_role_name,
                x.child_role_id,
                x.child_role_code,
                x.child_role_name,
                row_number() over (
                    partition by x.role_id, x.child_role_id
                    order by x.role_id, x.child_role_id
                ) rn
            from xmltable(
                     '/ROWSET/ROW'
                     passing l_xml
                     columns
                         role_id         number         path 'ROLE_ID',
                         top_role_code   varchar2(4000) path 'TOP_ROLE_CODE',
                         top_role_name   varchar2(4000) path 'TOP_ROLE_NAME',
                         child_role_id   number         path 'CHILD_ROLE_ID',
                         child_role_code varchar2(4000) path 'CHILD_ROLE_CODE',
                         child_role_name varchar2(4000) path 'CHILD_ROLE_NAME'
                 ) x
        )
        where rn = 1
    ) s
    on (t.role_id = s.role_id
        and t.child_role_id = s.child_role_id
        and t.instance_id = p_instance_id)
    when matched then
        update set
            t.top_role_code   = s.top_role_code,
            t.top_role_name   = s.top_role_name,
            t.child_role_code = s.child_role_code,
            t.child_role_name = s.child_role_name
    when not matched then
        insert (
            role_id,
            top_role_code,
            top_role_name,
            child_role_id,
            child_role_code,
            child_role_name,
            instance_id
        )
        values (
            s.role_id,
            s.top_role_code,
            s.top_role_name,
            s.child_role_id,
            s.child_role_code,
            s.child_role_name,
            p_instance_id
        );

    commit;
end refresh_fa_inherited_role;

procedure refresh_fa_role_privileges (p_instance_id in number default v('G_INSTANCE_ID'))
is
    l_xml xmltype;
begin
    -- run the bip report and get xml
    l_xml := run_bip_report_via_soapapi(
                 p_report_path => build_bip_path('Role Privileges_XML.xdo'),
                 p_instance_id => p_instance_id
             );

    merge into fa_role_privileges_bk t
    using (
        select *
        from (
            select
                x.role_id,
                x.top_role_code,
                x.top_role_name,
                x.child_role_id,
                x.child_role_code,
                x.child_role_name,
                x.privilege_id,
                x.privilege_code,
                x.privilege_name,
                row_number() over (
                    partition by x.role_id, x.child_role_id, x.privilege_id
                    order by x.role_id, x.child_role_id, x.privilege_id
                ) rn
            from xmltable(
                     '/ROWSET/ROW'
                     passing l_xml
                     columns
                         role_id         number         path 'ROLE_ID',
                         top_role_code   varchar2(4000) path 'TOP_ROLE_CODE',
                         top_role_name   varchar2(4000) path 'TOP_ROLE_NAME',
                         child_role_id   number         path 'CHILD_ROLE_ID',
                         child_role_code varchar2(4000) path 'CHILD_ROLE_CODE',
                         child_role_name varchar2(4000) path 'CHILD_ROLE_NAME',
                         privilege_id    number         path 'PRIVILEGE_ID',
                         privilege_code  varchar2(4000) path 'PRIVILEGE_CODE',
                         privilege_name  varchar2(4000) path 'PRIVILEGE_NAME'
                 ) x
        )
        where rn = 1
    ) s
    on (    t.role_id       = s.role_id
        and t.child_role_id = s.child_role_id
        and t.privilege_id  = s.privilege_id
        and t.instance_id   = p_instance_id)
    when matched then
        update set
            t.top_role_code   = s.top_role_code,
            t.top_role_name   = s.top_role_name,
            t.child_role_code = s.child_role_code,
            t.child_role_name = s.child_role_name,
            t.privilege_code  = s.privilege_code,
            t.privilege_name  = s.privilege_name
    when not matched then
        insert (
            role_id,
            top_role_code,
            top_role_name,
            child_role_id,
            child_role_code,
            child_role_name,
            privilege_id,
            privilege_code,
            privilege_name,
            instance_id
        )
        values (
            s.role_id,
            s.top_role_code,
            s.top_role_name,
            s.child_role_id,
            s.child_role_code,
            s.child_role_name,
            s.privilege_id,
            s.privilege_code,
            s.privilege_name,
            p_instance_id
        );

    commit;
end refresh_fa_role_privileges;

procedure refresh_fa_user_role (p_instance_id in number default v('G_INSTANCE_ID'))
is
    l_xml xmltype;
begin

     delete from fa_user_role_bk where instance_id = p_instance_id;

    -- run the bip report and get xml
    l_xml := run_bip_report_via_soapapi(
                 p_report_path => build_bip_path('User Role_XML.xdo'),
                 p_instance_id => p_instance_id
             );


    MERGE INTO fa_user_role_bk t
USING (
    SELECT
        x.user_id,
        x.user_guid,
        x.ase_role_id,
        x.role_common_name,
        x.type_code,
        x.role_name,
        TO_TIMESTAMP_TZ(
            x.effective_end_date,
            'YYYY-MM-DD"T"HH24:MI:SS.FF TZH:TZM'
        ) AS effective_end_date
    FROM XMLTABLE(
             '/ROWSET/ROW'
             PASSING l_xml
             COLUMNS
                 user_id            NUMBER(18,0)   PATH 'USER_ID',
                 user_guid          VARCHAR2(64)   PATH 'USER_GUID',
                 ase_role_id        NUMBER(18,0)   PATH 'ASE_ROLE_ID',
                 role_common_name   VARCHAR2(4000) PATH 'ROLE_COMMON_NAME',
                 type_code          VARCHAR2(30)   PATH 'TYPE_CODE',
                 role_name          VARCHAR2(4000) PATH 'ROLE_NAME',
                 effective_end_date VARCHAR2(50)   PATH 'EFFECTIVE_END_DATE'
         ) x
) s
ON (t.user_id = s.user_id AND t.ase_role_id = s.ase_role_id AND t.instance_id = p_instance_id)
WHEN MATCHED THEN
    UPDATE SET
        t.user_guid          = s.user_guid,
        t.role_common_name   = s.role_common_name,
        t.type_code          = s.type_code,
        t.role_name          = s.role_name,
        t.effective_end_date = s.effective_end_date
WHEN NOT MATCHED THEN
    INSERT (
        user_id,
        user_guid,
        ase_role_id,
        role_common_name,
        type_code,
        role_name,
        effective_end_date,
        instance_id
    )
    VALUES (
        s.user_id,
        s.user_guid,
        s.ase_role_id,
        s.role_common_name,
        s.type_code,
        s.role_name,
        s.effective_end_date,
        p_instance_id
    );


    commit;
end refresh_fa_user_role;

procedure refresh_data_securities (
    p_merge_mode  in varchar2 default 'MERGE',
    p_instance_id in number   default v('G_INSTANCE_ID')
)
is
    c_endpoint    constant varchar2(500) :=
        '/fscmRestApi/resources/11.13.18.05/dataSecurities';
    c_limit       constant pls_integer := 500;

    l_fusion_host    fusion_instance_cfg.fusion_host%type;
    l_cred_static_id fusion_instance_cfg.cred_static_id%type;

    l_url         varchar2(2000);
    l_base_url    varchar2(500);
    l_offset      pls_integer := 0;
    l_has_more    boolean     := true;
    l_clob        clob;
    l_json        json_object_t;
    l_items       json_array_t;
    l_count       pls_integer;
    l_rows_loaded pls_integer := 0;
begin
    -- look up instance configuration
    select fusion_host, cred_static_id
      into l_fusion_host, l_cred_static_id
      from fusion_instance_cfg
     where instance_id = p_instance_id;

    -- prepend protocol if not already present
    if l_fusion_host not like 'https://%' then
        l_base_url := 'https://' || l_fusion_host;
    else
        l_base_url := l_fusion_host;
    end if;

    -- REPLACE mode: delete existing rows for this instance
    if upper(p_merge_mode) = 'REPLACE' then
        delete from eba_data_securities where instance_id = p_instance_id;
        apex_debug.info('refresh_data_securities: deleted existing rows for instance %s (REPLACE mode)', p_instance_id);
    end if;

    -- pagination loop
    while l_has_more
    loop
        l_url := l_base_url
              || c_endpoint
              || '?totalResults=true'
              || '&limit='  || c_limit
              || '&offset=' || l_offset;

        apex_web_service.clear_request_headers;
        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';

        l_clob := apex_web_service.make_rest_request(
            p_url                  => l_url,
            p_http_method          => 'GET',
            p_credential_static_id => l_cred_static_id
        );

        if apex_web_service.g_status_code != 200 then
            raise_application_error(-20001,
                'Data Securities API returned HTTP ' || apex_web_service.g_status_code);
        end if;

        -- get item count for pagination control
        l_json  := json_object_t.parse(l_clob);
        l_items := l_json.get_array('items');
        l_count := l_items.get_size;

        apex_debug.info('refresh_data_securities: offset=%s, items=%s', l_offset, l_count);

        -- MERGE using JSON_TABLE
        merge into eba_data_securities dst
        using (
            select
                jt.user_role_data_assignment_id,
                jt.active_flag,
                jt.created_by,
                jt.creation_date,
                jt.last_update_date,
                jt.last_update_login,
                jt.last_updated_by,
                jt.role_common_name,
                jt.role_rf,
                jt.user_rf,
                jt.security_context,
                jt.security_context_value,
                jt.security_context_value2,
                jt.security_context_value3,
                jt.user_name,
                jt.role_name_cr
            from json_table(
                l_clob,
                '$.items[*]'
                columns (
                    user_role_data_assignment_id    number          path '$.UserRoleDataAssignmentId',
                    active_flag                     varchar2(5)     path '$.ActiveFlag',
                    created_by                      varchar2(240)   path '$.CreatedBy',
                    creation_date                   timestamp with time zone path '$.CreationDate',
                    last_update_date                timestamp with time zone path '$.LastUpdateDate',
                    last_update_login               varchar2(100)   path '$.LastUpdateLogin',
                    last_updated_by                 varchar2(240)   path '$.LastUpdatedBy',
                    role_common_name                varchar2(240)   path '$.RoleCommonName',
                    role_rf                         varchar2(240)   path '$.Rolerf',
                    user_rf                         varchar2(240)   path '$.Userrf',
                    security_context                varchar2(240)   path '$.SecurityContext',
                    security_context_value          varchar2(240)   path '$.SecurityContextValue',
                    security_context_value2         varchar2(240)   path '$.SecurityContextValue2',
                    security_context_value3         varchar2(240)   path '$.SecurityContextValue3',
                    user_name                       varchar2(240)   path '$.UserName',
                    role_name_cr                    varchar2(240)   path '$.RoleNameCr'
                )
            ) jt
        ) src
        on (dst.user_role_data_assignment_id = src.user_role_data_assignment_id
            and dst.instance_id = p_instance_id)
        when matched then update set
            dst.active_flag             = src.active_flag,
            dst.created_by              = src.created_by,
            dst.creation_date           = src.creation_date,
            dst.last_update_date        = src.last_update_date,
            dst.last_update_login       = src.last_update_login,
            dst.last_updated_by         = src.last_updated_by,
            dst.role_common_name        = src.role_common_name,
            dst.role_rf                 = src.role_rf,
            dst.user_rf                 = src.user_rf,
            dst.security_context        = src.security_context,
            dst.security_context_value  = src.security_context_value,
            dst.security_context_value2 = src.security_context_value2,
            dst.security_context_value3 = src.security_context_value3,
            dst.user_name               = src.user_name,
            dst.role_name_cr            = src.role_name_cr,
            dst.load_date               = sysdate
        when not matched then insert (
            user_role_data_assignment_id,
            active_flag,
            created_by,
            creation_date,
            last_update_date,
            last_update_login,
            last_updated_by,
            role_common_name,
            role_rf,
            user_rf,
            security_context,
            security_context_value,
            security_context_value2,
            security_context_value3,
            user_name,
            role_name_cr,
            load_date,
            instance_id
        ) values (
            src.user_role_data_assignment_id,
            src.active_flag,
            src.created_by,
            src.creation_date,
            src.last_update_date,
            src.last_update_login,
            src.last_updated_by,
            src.role_common_name,
            src.role_rf,
            src.user_rf,
            src.security_context,
            src.security_context_value,
            src.security_context_value2,
            src.security_context_value3,
            src.user_name,
            src.role_name_cr,
            sysdate,
            p_instance_id
        );

        l_rows_loaded := l_rows_loaded + sql%rowcount;

        commit;

        -- advance pagination
        l_offset   := l_offset + c_limit;
        l_has_more := (l_count = c_limit);

    end loop;

    apex_debug.info('refresh_data_securities: total rows loaded/updated=%s', l_rows_loaded);

    apex_web_service.clear_request_headers;

exception
    when others then
        apex_debug.error('refresh_data_securities failed: %s', sqlerrm);
        apex_web_service.clear_request_headers;
        raise;
end refresh_data_securities;

procedure refresh_fa_erp_data_context (p_instance_id in number default v('G_INSTANCE_ID'))
is
    l_xml xmltype;
begin
    l_xml := run_bip_report_via_soapapi(
                 p_report_path => build_bip_path('ERP Data Context_XML.xdo'),
                 p_instance_id => p_instance_id
             );

    merge into fa_erp_data_context_bk t
    using (
        select *
        from (
            select
                x.common_role_name,
                x.role_name,
                x.context,
                row_number() over (
                    partition by x.common_role_name, x.context
                    order by x.common_role_name, x.context
                ) rn
            from xmltable(
                     '/ROWSET/ROW'
                     passing l_xml
                     columns
                         common_role_name varchar2(4000) path 'COMMON_ROLE_NAME',
                         role_name        varchar2(4000) path 'ROLE_NAME',
                         context          varchar2(4000) path 'CONTEXT'
                 ) x
        )
        where rn = 1
    ) s
    on (t.common_role_name = s.common_role_name
        and t.context = s.context
        and t.instance_id = p_instance_id)
    when matched then
        update set
            t.role_name = s.role_name
    when not matched then
        insert (
            common_role_name,
            role_name,
            context,
            instance_id
        )
        values (
            s.common_role_name,
            s.role_name,
            s.context,
            p_instance_id
        );

    commit;
end refresh_fa_erp_data_context;

procedure refresh_user_positions (p_instance_id in number default v('G_INSTANCE_ID'))
is
    l_xml xmltype;
begin
    l_xml := run_bip_report_via_soapapi(
                 p_report_path => build_bip_path('Position Assignments_XML.xdo'),
                 p_instance_id => p_instance_id
             );

    -- DELETE + INSERT pattern (like refresh_fa_user_role)
    -- because positions can have 0, 1, or many incumbents
    delete from fa_user_positions_bk where instance_id = p_instance_id;

    insert into fa_user_positions_bk (
        position_id,
        position_code,
        position_name,
        job_id,
        job_name,
        business_unit_id,
        business_unit_name,
        department_id,
        department_name,
        location_id,
        active_status,
        effective_start_date,
        assignment_id,
        person_id,
        person_number,
        first_name,
        last_name,
        assignment_status_type,
        primary_flag,
        instance_id
    )
    select
        x.position_id,
        x.position_code,
        x.position_name,
        x.job_id,
        x.job_name,
        x.business_unit_id,
        x.business_unit_name,
        x.department_id,
        x.department_name,
        x.location_id,
        x.active_status,
        to_date(x.effective_start_date, 'YYYY-MM-DD'),
        x.assignment_id,
        x.person_id,
        x.person_number,
        x.first_name,
        x.last_name,
        x.assignment_status_type,
        x.primary_flag,
        p_instance_id
    from xmltable(
             '/ROWSET/ROW'
             passing l_xml
             columns
                 position_id            NUMBER        PATH 'POSITION_ID',
                 position_code          VARCHAR2(60)  PATH 'POSITION_CODE',
                 position_name          VARCHAR2(240) PATH 'POSITION_NAME',
                 job_id                 NUMBER        PATH 'JOB_ID',
                 job_name               VARCHAR2(240) PATH 'JOB_NAME',
                 business_unit_id       NUMBER        PATH 'BUSINESS_UNIT_ID',
                 business_unit_name     VARCHAR2(240) PATH 'BUSINESS_UNIT_NAME',
                 department_id          NUMBER        PATH 'DEPARTMENT_ID',
                 department_name        VARCHAR2(240) PATH 'DEPARTMENT_NAME',
                 location_id            NUMBER        PATH 'LOCATION_ID',
                 active_status          VARCHAR2(30)  PATH 'ACTIVE_STATUS',
                 effective_start_date   VARCHAR2(10)  PATH 'EFFECTIVE_START_DATE',
                 assignment_id          NUMBER        PATH 'ASSIGNMENT_ID',
                 person_id              NUMBER        PATH 'PERSON_ID',
                 person_number          VARCHAR2(30)  PATH 'PERSON_NUMBER',
                 first_name             VARCHAR2(255) PATH 'FIRST_NAME',
                 last_name              VARCHAR2(255) PATH 'LAST_NAME',
                 assignment_status_type VARCHAR2(30)  PATH 'ASSIGNMENT_STATUS_TYPE',
                 primary_flag           VARCHAR2(1)   PATH 'PRIMARY_FLAG'
         ) x;

    apex_debug.info('refresh_user_positions: %s rows loaded for instance %s', sql%rowcount, p_instance_id);

    commit;
end refresh_user_positions;



end;
/