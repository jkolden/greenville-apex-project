--------------------------------------------------------------------------
-- Daily DBMS_SCHEDULER job for code-based REST recruiting loads
--
-- Runs pkg_rest_recruiting.refresh_all which consolidates:
--   load_requisitions : parent reqs + DFFs + published jobs (1 API pass)
--   load_candidates   : parent candidates + phones (1 API pass)
--
-- Uses apex_web_service.make_rest_request (not APEX REST sync),
-- so needs its own APEX session and scheduler job.
--------------------------------------------------------------------------
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_REST_RECRUITING_DAILY',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN apex_session.create_session(p_app_id=>121,p_page_id=>1,p_username=>''ADMIN''); pkg_rest_recruiting.refresh_all; apex_session.delete_session; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=14; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Daily recruiting loads (requisitions + DFFs + published jobs + candidates + phones) — 14:00 UTC'
    );
END;
/
