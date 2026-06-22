-- =============================================================================
-- Attach VPD policy to RECRUITING_REPORT_V
-- =============================================================================
-- Run as <APEX_WORKSPACE> (the schema owner).
-- Requires EXECUTE on DBMS_RLS (granted by ADMIN in ATP).
-- Re-runnable: drops existing policy first.
-- =============================================================================

-- Drop existing policy if re-running
BEGIN
    DBMS_RLS.DROP_POLICY(
        object_schema   => '<APEX_WORKSPACE>',
        object_name     => 'RECRUITING_REPORT_V',
        policy_name     => 'REC_SCHOOL_READ_POLICY'
    );
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -28102 THEN NULL;   -- policy does not exist
        ELSE RAISE;
        END IF;
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => '<APEX_WORKSPACE>',
        object_name     => 'RECRUITING_REPORT_V',
        policy_name     => 'REC_SCHOOL_READ_POLICY',
        function_schema => '<APEX_WORKSPACE>',
        policy_function => 'REC_RLS_PKG.READ_POLICY',
        statement_types => 'SELECT',
        policy_type     => DBMS_RLS.DYNAMIC
    );
END;
/
