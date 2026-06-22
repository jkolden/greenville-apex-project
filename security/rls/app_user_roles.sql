-- =============================================================================
-- APP_USER_ROLES: Role-based authorization for APEX App 121
-- =============================================================================
-- Proof-of-concept security layer.
-- APEX authorization schemes query this table to gate page/component access.
--
-- Roles:
--   ADMIN       — Full access (BICC Loader, Email Config, all HR pages)
--   HR_USER     — Recruiting/HR pages only (applicant reports, questionnaires)
--   SUPPORT_DEV — Ticket system: view all tickets, self-assign, resolve, internal comments
--
-- Usage:
--   INSERT INTO app_user_roles (username, role_code) VALUES ('JSMITH', 'ADMIN');
-- =============================================================================

CREATE TABLE app_user_roles (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username    VARCHAR2(255)  NOT NULL,
    role_code   VARCHAR2(30)   NOT NULL,
    is_active   VARCHAR2(1)    DEFAULT 'Y' NOT NULL,
    granted_by  VARCHAR2(255),
    granted_ts  TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    notes       VARCHAR2(500),
    email       VARCHAR2(500),
    --
    CONSTRAINT app_user_roles_u1 UNIQUE (username, role_code),
    CONSTRAINT app_user_roles_ck1 CHECK (role_code IN ('ADMIN', 'HR_USER', 'SUPPORT_DEV')),
    CONSTRAINT app_user_roles_ck2 CHECK (is_active IN ('Y', 'N'))
);

COMMENT ON TABLE  app_user_roles              IS 'Maps APEX usernames to application roles';
COMMENT ON COLUMN app_user_roles.username     IS 'APEX username (upper-case, matches :APP_USER)';
COMMENT ON COLUMN app_user_roles.role_code    IS 'ADMIN = full access, HR_USER = recruiting pages, SUPPORT_DEV = ticket management';
COMMENT ON COLUMN app_user_roles.is_active    IS 'Y = active, N = revoked without deleting history';
COMMENT ON COLUMN app_user_roles.granted_by   IS 'Who granted this role';
COMMENT ON COLUMN app_user_roles.email        IS 'Email address for ticket notifications';

-- =============================================================================
-- ALTER script for existing databases (run once):
-- =============================================================================
-- ALTER TABLE app_user_roles ADD email VARCHAR2(500);
-- ALTER TABLE app_user_roles DROP CONSTRAINT app_user_roles_ck1;
-- ALTER TABLE app_user_roles ADD CONSTRAINT app_user_roles_ck1
--     CHECK (role_code IN ('ADMIN', 'HR_USER', 'SUPPORT_DEV'));
