--------------------------------------------------------------------------
-- Daily DBMS_SCHEDULER job for all BIP report loads
--
-- Runs five BIP reports in sequence:
--   1. Extensible Flex (EXT_FLEX)
--   2. Questionnaires (QUESTIONNAIRES)
--   3. Gallup Assessments (GALLUP)
--   4. FA User Accounts (USER_ACCOUNTS)
--   5. FA User Roles (USER_ROLES)
--
-- Each procedure handles its own APEX session creation when called from
-- the scheduler.  All loads are logged to bip_load_log automatically.
--
-- To apply this change to an existing job, drop and recreate:
--   EXEC DBMS_SCHEDULER.DROP_JOB('JOB_BIP_FLEX_DAILY');
--   then run this script.
--------------------------------------------------------------------------
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_BIP_FLEX_DAILY',
        job_type        => 'PLSQL_BLOCK',
        job_action      => q'[
BEGIN
    pkg_bip_soap.load_extensible_flex;
    pkg_bip_soap.load_bip_questionnaires;
    pkg_bip_soap.load_gallup_assessments;
    pkg_bip_soap.load_fa_user_accounts;
    pkg_bip_soap.load_fa_user_roles;
END;
]',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=15; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Daily BIP report loads (5 reports) — 8 AM Pacific / 15:00 UTC'
    );
END;
/
