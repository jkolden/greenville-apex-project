-- =============================================================================
-- TABLE: RECON_SOURCE_CONFIG
-- =============================================================================
-- Registry of data sources for record-count reconciliation against Fusion.
-- Each row maps an entity to its local table and the method used to obtain
-- the Fusion-side record count (REST totalResults or BIP count report).
--
-- Used by pkg_recon.run_recon to loop through sources and compare counts.
-- =============================================================================

CREATE TABLE recon_source_config (
    source_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_name      VARCHAR2(100)  NOT NULL,
    source_type      VARCHAR2(20)   NOT NULL
                     CHECK (source_type IN ('REST','BICC')),
    local_table_name VARCHAR2(128)  NOT NULL,
    count_method     VARCHAR2(20)   NOT NULL
                     CHECK (count_method IN ('REST_TOTAL','BIP_COUNT')),
    rest_url_path    VARCHAR2(500),              -- REST only: path after host
    bip_report_name  VARCHAR2(200),              -- BIP only: report path in BI Publisher
    bip_entity_key   VARCHAR2(100),              -- BIP only: entity tag in XML
    local_count_sql  VARCHAR2(500),             -- custom count SQL override (default: COUNT(*))
    is_active        VARCHAR2(1)    DEFAULT 'Y' NOT NULL
                     CHECK (is_active IN ('Y','N')),
    created_ts       TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT recon_src_entity_uk UNIQUE (entity_name)
);

COMMENT ON TABLE  recon_source_config IS 'Registry of data sources for record-count reconciliation';
COMMENT ON COLUMN recon_source_config.entity_name      IS 'Friendly entity identifier, e.g. AP_INVOICES';
COMMENT ON COLUMN recon_source_config.source_type      IS 'REST = APEX REST Data Source; BICC = BICC pipeline entity';
COMMENT ON COLUMN recon_source_config.local_table_name IS 'Local table to COUNT(*) against';
COMMENT ON COLUMN recon_source_config.count_method     IS 'REST_TOTAL = ?totalResults=true; BIP_COUNT = BIP count report';
COMMENT ON COLUMN recon_source_config.rest_url_path    IS 'Fusion REST path after base host, e.g. /fscmRestApi/resources/latest/invoices';
COMMENT ON COLUMN recon_source_config.bip_report_name  IS 'BIP report path, e.g. /Custom/SCI/BIP/hcm_object_counts.xdo';
COMMENT ON COLUMN recon_source_config.bip_entity_key   IS 'Entity key in the BIP report XML, e.g. HCM_EMPLOYEE';
COMMENT ON COLUMN recon_source_config.local_count_sql  IS 'Custom SQL for local count (e.g. SELECT COUNT(DISTINCT x) FROM t). NULL = COUNT(*)';


-- =============================================================================
-- SEED DATA — REST Sources
-- =============================================================================
-- Naming convention: <ENTITY>_R for REST-synced tables.
-- rest_url_path values should match the APEX REST Data Source URL.
-- =============================================================================

-- FIN (2 sources)
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('AP_INVOICES',              'REST', 'AP_INVOICE_HDR_R',            'REST_TOTAL', '/fscmRestApi/resources/latest/invoices');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('RECEIVABLE_TRANSACTIONS',  'REST', 'RECEIVABLE_TRANSACTIONS_R',   'REST_TOTAL', '/fscmRestApi/resources/latest/receivablesInvoices');

-- HCM (5 sources)
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('JOB_APPLICATIONS',  'REST', 'JOB_APPLICANTS_R',      'REST_TOTAL', '/hcmRestApi/resources/latest/recruitingJobApplications');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('JOB_REQUISITIONS',  'REST', 'JOB_REQUISITIONS_R',    'REST_TOTAL', '/hcmRestApi/resources/latest/recruitingJobRequisitions');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('ABSENCES',          'REST', 'HCM_ABSENCES_R',         'REST_TOTAL', '/hcmRestApi/resources/11.13.18.05/absences');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('POSITIONS',         'REST', 'HCM_POSITION_R',         'REST_TOTAL', '/hcmRestApi/resources/11.13.18.05/positions');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('SALARIES',          'REST', 'HCM_SALARY_R',           'REST_TOTAL', '/hcmRestApi/resources/11.13.18.05/salaries');

-- PRC (2 sources)
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('PURCHASE_ORDERS',   'REST', 'PO_HDR_R',               'REST_TOTAL', '/fscmRestApi/resources/latest/purchaseOrders');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('SUPPLIERS',         'REST', 'SUPPLIERS_R',             'REST_TOTAL', '/fscmRestApi/resources/latest/suppliers');

-- HCM full-only
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('LOCATIONS',         'REST', 'LOCATIONS_R',             'REST_TOTAL', '/hcmRestApi/resources/11.13.18.05/locationsV2');
UPDATE recon_source_config SET local_count_sql = 'SELECT COUNT(DISTINCT LOCATIONID) FROM LOCATIONS_R' WHERE entity_name = 'LOCATIONS';

-- GL Segment Values (9 sources) — /fscmRestApi/resources/11.13.18.05/valueSets/<name>/child/values
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('GL_ACCOUNT_VALUES',            'REST', 'ACCOUNT_VALUES_R',            'REST_TOTAL', '/fscmRestApi/resources/11.13.18.05/valueSets/Account/child/values');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('GL_ACCOUNTING_SCENARIO_VALUES','REST', 'ACCTG_SCENARIO_VALUES_R',     'REST_TOTAL', '/fscmRestApi/resources/11.13.18.05/valueSets/Accounting%20Scenario/child/values');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('GL_ACTIVITY_VALUES',           'REST', 'ACTIVITY_VALUES_R',           'REST_TOTAL', '/fscmRestApi/resources/11.13.18.05/valueSets/Activity/child/values');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('GL_FUND_VALUES',               'REST', 'FUND_VALUES_R',               'REST_TOTAL', '/fscmRestApi/resources/11.13.18.05/valueSets/Fund/child/values');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('GL_FUNCTION_VALUES',           'REST', 'FUNCTION_VALUES_R',           'REST_TOTAL', '/fscmRestApi/resources/11.13.18.05/valueSets/Function/child/values');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('GL_GRANT_VALUES',              'REST', 'GRANT_VALUES_R',              'REST_TOTAL', '/fscmRestApi/resources/11.13.18.05/valueSets/Grant/child/values');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('GL_INITIATIVE_VALUES',         'REST', 'INITIATIVE_VALUES_R',         'REST_TOTAL', '/fscmRestApi/resources/11.13.18.05/valueSets/Initiative/child/values');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('GL_INTERFUND_VALUES',          'REST', 'INTERFUND_VALUES_R',          'REST_TOTAL', '/fscmRestApi/resources/11.13.18.05/valueSets/InterFund/child/values');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, rest_url_path) VALUES
    ('GL_LOCATION_VALUES',           'REST', 'LOCATION_VALUES_R',           'REST_TOTAL', '/fscmRestApi/resources/11.13.18.05/valueSets/Location/child/values');


-- =============================================================================
-- SEED DATA — BICC Sources
-- =============================================================================
-- bip_entity_key must match the ENTITY_NAME value returned by the
-- Record_Counts_XML.xdo BIP report.
-- =============================================================================

-- HCM (4) — hcm_object_counts.xdo via ApplicationDB_HCM
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('HCM_EMPLOYEE',     'BICC', 'HCM_EMPLOYEE_BC',     'BIP_COUNT', '/Custom/SCI/BIP/hcm_object_counts.xdo', 'HCM_EMPLOYEE');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('HCM_POSITION',     'BICC', 'HCM_POSITION_BC',     'BIP_COUNT', '/Custom/SCI/BIP/hcm_object_counts.xdo', 'HCM_POSITION');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('HCM_ASSIGNMENT',   'BICC', 'HCM_ASSIGNMENT_BC',   'BIP_COUNT', '/Custom/SCI/BIP/hcm_object_counts.xdo', 'HCM_ASSIGNMENT');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('HCM_SALARY',       'BICC', 'HCM_SALARY_BC',       'BIP_COUNT', '/Custom/SCI/BIP/hcm_object_counts.xdo', 'HCM_SALARY');

-- GL (6) — Financials_object_counts.xdo via ApplicationDB_FSCM
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('GL_CODE_COMB',     'BICC', 'GL_CODE_COMB_BC',     'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'GL_CODE_COMB');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('GL_BALANCE',       'BICC', 'GL_BALANCE_BC',       'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'GL_BALANCE');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('GL_BUDGET_BALANCE','BICC', 'GL_BUDGET_BALANCE_BC', 'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'GL_BUDGET_BALANCE');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('GL_JOURNAL_BATCH', 'BICC', 'GL_JOURNAL_BATCH_BC', 'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'GL_JOURNAL_BATCH');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('GL_JOURNAL_HEADER','BICC', 'GL_JOURNAL_HEADER_BC','BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'GL_JOURNAL_HEADER');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('GL_JOURNAL_LINES', 'BICC', 'GL_JOURNAL_LINES_BC', 'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'GL_JOURNAL_LINES');

-- AP (3) — Financials_object_counts.xdo via ApplicationDB_FSCM
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('AP_INVOICE_HDR',   'BICC', 'AP_INVOICE_HDR_BC',   'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'AP_INVOICE_HDR');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('AP_DISBURSEMENT',  'BICC', 'AP_DISBURSEMENT_BC',  'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'AP_DISBURSEMENT');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('AP_INV_APPLICATION','BICC','AP_INV_APPLICATION_BC','BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'AP_INV_APPLICATION');

-- AR (1) — Financials_object_counts.xdo via ApplicationDB_FSCM
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('AR_INVOICES',      'BICC', 'AR_INVOICES_BC',      'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'AR_INVOICES');

-- PO / Procurement (3) — Financials_object_counts.xdo via ApplicationDB_FSCM
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('PO_HDR',           'BICC', 'PO_HDR_BC',           'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'PO_HDR');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('PO_LINES',         'BICC', 'PO_LINES_BC',         'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'PO_LINES');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key) VALUES
    ('SUPPLIER_HDR',     'BICC', 'SUPPLIER_HDR_BC',     'BIP_COUNT', '/Custom/SCI/BIP/Financials_object_counts.xdo', 'SUPPLIER_HDR');

-- Recruiting / Questionnaires (3) — INACTIVE: Fusion table names TBD (IRC tables not in ApplicationDB_HCM)
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key, is_active) VALUES
    ('QSTNR_ANSWER',    'BICC', 'QSTNR_ANSWER_BC',    'BIP_COUNT', NULL, 'QSTNR_ANSWER',   'N');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key, is_active) VALUES
    ('QSTNR_QUESTION',  'BICC', 'QSTNR_QUESTION_BC',  'BIP_COUNT', NULL, 'QSTNR_QUESTION', 'N');
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key, is_active) VALUES
    ('QSTNR_RESPONSE',  'BICC', 'QSTNR_RESPONSE_BC',  'BIP_COUNT', NULL, 'QSTNR_RESPONSE', 'N');

-- Position DFF (1) — INACTIVE: Fusion table name TBD
INSERT INTO recon_source_config (entity_name, source_type, local_table_name, count_method, bip_report_name, bip_entity_key, is_active) VALUES
    ('POS_CUSTOM_FLEX',  'BICC', 'POS_CUSTOM_FLEX_BC',  'BIP_COUNT', NULL, 'POS_CUSTOM_FLEX', 'N');

COMMIT;
