CREATE OR REPLACE PACKAGE pkg_rest_sync AS
    --------------------------------------------------------------------------
    -- Incremental REST Sync for all APEX REST Data Sources
    --
    -- Uses APEX_REST_SOURCE_SYNC.DYNAMIC_SYNCHRONIZE_DATA with a
    -- LastUpdateDate filter.  Goes back 2 days from the last successful
    -- sync to guarantee no records are missed.  First run (no prior sync)
    -- does a full refresh.
    --
    -- The sync step 'Synchronization Step 1' is created dynamically on
    -- first call — no manual APEX UI setup required.
    --------------------------------------------------------------------------

    -- Sync a single REST source (can be called standalone from a page button)
    PROCEDURE sync_source (
        p_module_static_id  IN VARCHAR2,
        p_sync_step_id      IN VARCHAR2 DEFAULT 'Synchronization Step 1',
        p_date_field        IN VARCHAR2 DEFAULT 'LastUpdateDate'
    );

    -- Sync all configured REST sources; creates APEX session if needed
    PROCEDURE sync_all;

    -- Safe wrapper: returns 'OK' or error message (never raises).
    -- If p_date_field is NULL, looks up from rest_source_registry.
    -- Used by the APEX Ajax callback on page 9510.
    FUNCTION sync_source_safe (
        p_module_static_id  IN VARCHAR2,
        p_date_field        IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

END pkg_rest_sync;
/
