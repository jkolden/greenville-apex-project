CREATE OR REPLACE PACKAGE BODY pkg_bicc_trigger AS
-- =============================================================================
-- PKG_BICC_TRIGGER body
-- =============================================================================

    -----------------------------------------------------------------------
    -- Private: build the SOAP envelope for submitRequest
    -----------------------------------------------------------------------
    FUNCTION build_submit_envelope(
        p_datastore_list IN VARCHAR2,
        p_extract_type   IN VARCHAR2,
        p_description    IN VARCHAR2
    ) RETURN CLOB
    IS
    BEGIN
        RETURN '<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:sch="http://xmlns.oracle.com/scheduler"
                  xmlns:typ="http://xmlns.oracle.com/scheduler/types"
                  xmlns:wsa="http://www.w3.org/2005/08/addressing">
    <soapenv:Header>
        <wsa:Action>http://xmlns.oracle.com/scheduler/submitRequest</wsa:Action>
        <wsa:MessageID>uuid:' || SYS_GUID() || '</wsa:MessageID>
    </soapenv:Header>
    <soapenv:Body>
        <sch:submitRequest>
            <sch:description>' || DBMS_XMLGEN.CONVERT(p_description) || '</sch:description>
            <sch:jobDefinitionId>
                <typ:name>BICloudConnectorJobDefinition</typ:name>
                <typ:packageName>oracle.apps.ess.biccc</typ:packageName>
                <typ:type>JOB_DEFINITION</typ:type>
            </sch:jobDefinitionId>
            <sch:application>oracle.biacm</sch:application>
            <sch:requestedStartTime/>
            <sch:requestParameters>
                <typ:parameter>
                    <typ:dataType>STRING</typ:dataType>
                    <typ:name>SYS_className</typ:name>
                    <typ:value>oracle.esshost.impl.CloudAdaptorJobImpl</typ:value>
                </typ:parameter>
                <typ:parameter>
                    <typ:dataType>STRING</typ:dataType>
                    <typ:name>SYS_application</typ:name>
                    <typ:value>BI Cloud Adaptor</typ:value>
                </typ:parameter>
                <typ:parameter>
                    <typ:dataType>STRING</typ:dataType>
                    <typ:name>EXTRACT_JOB_TYPE</typ:name>
                    <typ:value>' || p_extract_type || '</typ:value>
                </typ:parameter>
                <typ:parameter>
                    <typ:dataType>STRING</typ:dataType>
                    <typ:name>DATA_STORE_LIST</typ:name>
                    <typ:value>' || DBMS_XMLGEN.CONVERT(p_datastore_list) || '</typ:value>
                </typ:parameter>
                <typ:parameter>
                    <typ:dataType>STRING</typ:dataType>
                    <typ:name>EXTERNAL_STORAGE_LIST</typ:name>
                    <typ:value>' || gc_storage_name || '</typ:value>
                </typ:parameter>
            </sch:requestParameters>
        </sch:submitRequest>
    </soapenv:Body>
</soapenv:Envelope>';
    END build_submit_envelope;


    -----------------------------------------------------------------------
    -- Private: build the SOAP envelope for getRequestState
    -----------------------------------------------------------------------
    FUNCTION build_status_envelope(
        p_request_id IN NUMBER
    ) RETURN CLOB
    IS
    BEGIN
        RETURN '<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:sch="http://xmlns.oracle.com/scheduler"
                  xmlns:wsa="http://www.w3.org/2005/08/addressing">
    <soapenv:Header>
        <wsa:Action>http://xmlns.oracle.com/scheduler/getRequestState</wsa:Action>
        <wsa:MessageID>uuid:' || SYS_GUID() || '</wsa:MessageID>
    </soapenv:Header>
    <soapenv:Body>
        <sch:getRequestState>
            <sch:requestId>' || p_request_id || '</sch:requestId>
        </sch:getRequestState>
    </soapenv:Body>
</soapenv:Envelope>';
    END build_status_envelope;


    -----------------------------------------------------------------------
    -- Private: POST a SOAP envelope and return the response
    -----------------------------------------------------------------------
    FUNCTION soap_call(
        p_envelope    IN CLOB,
        p_soap_action IN VARCHAR2,
        p_username    IN VARCHAR2,
        p_password    IN VARCHAR2
    ) RETURN CLOB
    IS
        l_response CLOB;
    BEGIN
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'text/xml; charset=utf-8';
        apex_web_service.g_request_headers(2).name  := 'SOAPAction';
        apex_web_service.g_request_headers(2).value := p_soap_action;

        l_response := apex_web_service.make_rest_request(
            p_url         => gc_soap_url,
            p_http_method => 'POST',
            p_body        => p_envelope,
            p_username    => p_username,
            p_password    => p_password
        );

        RETURN l_response;
    END soap_call;


    -----------------------------------------------------------------------
    -- submit_extract
    -----------------------------------------------------------------------
    FUNCTION submit_extract(
        p_datastore_ids IN VARCHAR2,
        p_username      IN VARCHAR2,
        p_password      IN VARCHAR2,
        p_extract_type  IN VARCHAR2 DEFAULT 'VO_EXTRACT',
        p_description   IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER
    IS
        l_datastore_list VARCHAR2(4000);
        l_friendly_list  VARCHAR2(4000);
        l_description    VARCHAR2(500);
        l_envelope       CLOB;
        l_response       CLOB;
        l_request_id     NUMBER;
    BEGIN
        -- Resolve datastore IDs to comma-separated paths
        SELECT LISTAGG(d.datastore_path, ',') WITHIN GROUP (ORDER BY d.datastore_id),
               LISTAGG(d.friendly_name, ', ') WITHIN GROUP (ORDER BY d.datastore_id)
        INTO   l_datastore_list, l_friendly_list
        FROM   bicc_datastore d
        WHERE  INSTR(',' || p_datastore_ids || ',', ',' || d.datastore_id || ',') > 0
        AND    d.is_active = 'Y';

        IF l_datastore_list IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'No active datastores found for IDs: ' || p_datastore_ids);
        END IF;

        l_description := NVL(p_description, 'ATP Extract: ' || SUBSTR(l_friendly_list, 1, 450));

        l_envelope := build_submit_envelope(
            p_datastore_list => l_datastore_list,
            p_extract_type   => p_extract_type,
            p_description    => l_description
        );

        l_response := soap_call(
            p_envelope    => l_envelope,
            p_soap_action => 'http://xmlns.oracle.com/scheduler/submitRequest',
            p_username    => p_username,
            p_password    => p_password
        );

        IF apex_web_service.g_status_code = 200 THEN
            l_request_id := TO_NUMBER(
                REGEXP_SUBSTR(l_response, '<requestId[^>]*>(\d+)</requestId>', 1, 1, NULL, 1)
            );
        END IF;

        IF l_request_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002,
                'BICC submit failed (HTTP ' || apex_web_service.g_status_code || '): '
                || SUBSTR(l_response, 1, 500));
        END IF;

        RETURN l_request_id;
    END submit_extract;


    -----------------------------------------------------------------------
    -- get_status
    -----------------------------------------------------------------------
    FUNCTION get_status(
        p_request_id IN NUMBER,
        p_username   IN VARCHAR2,
        p_password   IN VARCHAR2
    ) RETURN VARCHAR2
    IS
        l_response CLOB;
        l_state    VARCHAR2(100);
    BEGIN
        l_response := soap_call(
            p_envelope    => build_status_envelope(p_request_id),
            p_soap_action => 'http://xmlns.oracle.com/scheduler/getRequestState',
            p_username    => p_username,
            p_password    => p_password
        );

        IF apex_web_service.g_status_code = 200 THEN
            l_state := REGEXP_SUBSTR(l_response, '<state[^>]*>([^<]+)</state>', 1, 1, NULL, 1);
        END IF;

        RETURN NVL(l_state, 'HTTP_' || apex_web_service.g_status_code);
    END get_status;

END pkg_bicc_trigger;
/
