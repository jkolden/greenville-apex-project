-- =============================================================================
-- Seed data for APP_USER_ROLES
-- =============================================================================
-- Adjust usernames to match your APEX login accounts.
-- APEX stores :APP_USER in upper case for APEX-native authentication.
-- =============================================================================

-- Admin users (full access: BICC Loader, Email Config, all HR pages)
INSERT INTO app_user_roles (username, role_code, granted_by, notes)
VALUES ('ADMIN', 'ADMIN', 'SEED', 'Initial setup');

INSERT INTO app_user_roles (username, role_code, granted_by, notes)
VALUES ('JOHNK', 'ADMIN', 'SEED', 'Initial setup');

-- HR users (recruiting pages only)
INSERT INTO app_user_roles (username, role_code, granted_by, notes)
VALUES ('FOSTER', 'HR_USER', 'SEED', 'Customer demo account');

COMMIT;

-- Verify:
SELECT username, role_code, is_active, granted_ts
  FROM app_user_roles
 ORDER BY username, role_code;
