CREATE OR REPLACE PACKAGE pkg_bicc_trigger AS
-- =============================================================================
-- PKG_BICC_TRIGGER - Submit and monitor BICC extracts via SOAP API
-- =============================================================================
-- Calls the Fusion /bi/ess/esswebservice endpoint to trigger BICC extracts
-- from ATP, eliminating the need to use the Fusion BICC UI for ad-hoc runs.
--
-- SOAP endpoint requires:
--   - WS-Addressing headers (wsa:Action + wsa:MessageID) in every request
--   - Basic Auth (integration user)
--
-- Usage from APEX:
--   l_req_id := pkg_bicc_trigger.submit_extract(
--       p_datastore_ids => '1,3,5',
--       p_username      => :P_USERNAME,
--       p_password      => :P_PASSWORD
--   );
-- =============================================================================

    -- Fusion BICC ESS SOAP endpoint (derived from central constant)
    gc_soap_url CONSTANT VARCHAR2(300) := pkg_bicc_common.gc_fa_base_url || '/bi/ess/esswebservice';

    -- External storage name configured in BICC console
    gc_storage_name CONSTANT VARCHAR2(100) := 'GCS_HISTORY_DATA_STORAGE';

    -- Submit a BICC extract for one or more datastores.
    -- p_datastore_ids: comma-separated BICC_DATASTORE.DATASTORE_ID values
    -- p_extract_type:  VO_EXTRACT (data), PRIMARY_KEY_EXTRACT (deletes), VO_AND_PK_EXTRACT (both)
    -- Returns the Fusion ESS request ID on success, NULL on failure.
    FUNCTION submit_extract(
        p_datastore_ids IN VARCHAR2,
        p_username      IN VARCHAR2,
        p_password      IN VARCHAR2,
        p_extract_type  IN VARCHAR2 DEFAULT 'VO_EXTRACT',
        p_description   IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    -- Check the status of a submitted extract request.
    -- Returns state string: WAIT, READY, RUNNING, COMPLETED, SUCCEEDED,
    --                       ERROR, WARNING, CANCELLED, EXPIRED, PAUSED
    FUNCTION get_status(
        p_request_id IN NUMBER,
        p_username   IN VARCHAR2,
        p_password   IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Log table for extract requests submitted from this package.
    -- Populated automatically by submit_extract.

END pkg_bicc_trigger;
/
