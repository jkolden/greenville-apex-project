CREATE OR REPLACE TRIGGER rec_school_grant_bi
    BEFORE INSERT ON rec_school_grant
    FOR EACH ROW
BEGIN
    :NEW.app_user   := LOWER(:NEW.app_user);
    :NEW.granted_by := COALESCE(
        SYS_CONTEXT('APEX$SESSION', 'APP_USER'),
        SYS_CONTEXT('USERENV', 'SESSION_USER')
    );
    :NEW.granted_ts := SYSTIMESTAMP;
END;
/
