--------------------------------------------------------------------------
-- FA_USER_ACCOUNTS — Fusion user account data loaded via BIP report
--
-- Source BIP report: /Custom/SCI/BIP/User_Account_XML.xdo
-- Data model:       User_Account_DM.xdm
-- Loaded by:        pkg_bip_soap.load_fa_user_accounts
-- PK:               USER_GUID
--------------------------------------------------------------------------
CREATE TABLE fa_user_accounts (
    username                VARCHAR2(255),
    user_id                 NUMBER(18,0),
    user_guid               VARCHAR2(64)    NOT NULL,
    person_id               NUMBER(18,0),
    active_flag             VARCHAR2(30),
    hr_terminated           VARCHAR2(30),
    suspended               VARCHAR2(30),
    credentials_email_sent  VARCHAR2(30),
    user_first_name         VARCHAR2(255),
    user_last_name          VARCHAR2(255),
    user_email              VARCHAR2(255),
    user_category           VARCHAR2(30),
    ase_user_id             NUMBER(18,0),
    person_number           VARCHAR2(10),
    load_ts                 TIMESTAMP(6)    DEFAULT SYSTIMESTAMP,
    CONSTRAINT fa_user_accounts_pk PRIMARY KEY (user_guid)
);

CREATE INDEX fa_user_accounts_n1 ON fa_user_accounts (username);
CREATE INDEX fa_user_accounts_n2 ON fa_user_accounts (person_id);
CREATE INDEX fa_user_accounts_n3 ON fa_user_accounts (user_email);
