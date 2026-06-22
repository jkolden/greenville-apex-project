-- =============================================================================
-- REC_SCHOOL_GRANT: Which locations a user can see in recruiting reports
-- =============================================================================
-- Drives the VPD policy on RECRUITING_REPORT_V.
-- A user with NO rows here sees NO recruiting data (unless ADMIN).
-- A user with one or more rows sees only matching LOCATION_CODE values.
-- ADMIN users bypass the policy entirely.
--
-- Pattern follows OT_LOCATION_GRANT (App 110 overtime RDS demo).
-- =============================================================================

CREATE TABLE rec_school_grant (
    id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    app_user      VARCHAR2(255)  NOT NULL,
    location_code VARCHAR2(60)   NOT NULL,
    is_active     VARCHAR2(1)    DEFAULT 'Y' NOT NULL,
    granted_by    VARCHAR2(255),
    granted_ts    TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    notes         VARCHAR2(500),
    --
    CONSTRAINT rec_school_grant_u1  UNIQUE (app_user, location_code),
    CONSTRAINT rec_school_grant_ck1 CHECK  (is_active IN ('Y', 'N'))
);

COMMENT ON TABLE  rec_school_grant                 IS 'Maps APEX users to location codes for recruiting report VPD';
COMMENT ON COLUMN rec_school_grant.app_user        IS 'APEX username (upper-case), matches :APP_USER';
COMMENT ON COLUMN rec_school_grant.location_code   IS 'Fusion location code (e.g. 188, 435) — must match RECRUITING_REPORT_V.LOCATION_CODE';
COMMENT ON COLUMN rec_school_grant.is_active       IS 'Y = active grant, N = revoked';

CREATE INDEX rec_school_grant_n1 ON rec_school_grant (UPPER(app_user));
