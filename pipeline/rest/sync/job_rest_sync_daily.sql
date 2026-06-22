--------------------------------------------------------------------------
-- Daily DBMS_SCHEDULER job for incremental REST sync
--
-- Runs pkg_rest_sync.sync_all which creates its own APEX session,
-- loops through all 16 REST sources, and tears down the session.
--------------------------------------------------------------------------
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_REST_SYNC_DAILY',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN pkg_rest_sync.sync_all; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=14; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Daily incremental REST sync — 7 AM Pacific / 14:00 UTC'
    );
END;
/
