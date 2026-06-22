--------------------------------------------------------------------------
-- FA_USER_ROLES — Fusion user-to-role assignments loaded via BIP report
--
-- Source BIP report: /Custom/SCI/BIP/User_Role_XML.xdo
-- Data model:       user_roles_DM.xdm
-- Loaded by:        pkg_bip_soap.load_fa_user_roles
-- Pattern:          DELETE + INSERT (a user can have many roles, roles
--                   can be removed — full refresh is safest)
--------------------------------------------------------------------------
CREATE TABLE fa_user_roles (
    user_id             NUMBER(18,0),
    user_guid           VARCHAR2(64),
    ase_role_id         NUMBER(18,0),
    role_common_name    VARCHAR2(4000),
    type_code           VARCHAR2(30),
    role_name           VARCHAR2(4000),
    effective_end_date  TIMESTAMP(6) WITH TIME ZONE,
    load_ts             TIMESTAMP(6)    DEFAULT SYSTIMESTAMP
);

CREATE INDEX fa_user_roles_n1 ON fa_user_roles (user_id);
CREATE INDEX fa_user_roles_n2 ON fa_user_roles (user_guid);
CREATE INDEX fa_user_roles_n3 ON fa_user_roles (role_common_name);
