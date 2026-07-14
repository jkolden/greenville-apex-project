-- =============================================================================
-- TABLE: REST_SOURCE_REGISTRY
-- =============================================================================
-- Registry of APEX REST Data Sources available for on-demand sync triggering.
-- Each row maps an APEX module static ID to a friendly name, the correct
-- date-filter field, and the sync type (incremental vs full-only).
--
-- Used by pkg_rest_sync (sync_all reads from this table instead of a
-- hardcoded PL/SQL list) and the APEX manual sync page (9510).
-- =============================================================================

CREATE TABLE rest_source_registry (
    source_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    module_static_id VARCHAR2(100)  NOT NULL,
    display_name     VARCHAR2(200)  NOT NULL,
    module_code      VARCHAR2(10)   NOT NULL,   -- HCM, FIN, GL, PRC
    date_field       VARCHAR2(100),             -- NULL for FULL_ONLY sources
    sync_type        VARCHAR2(20)   DEFAULT 'INCREMENTAL' NOT NULL
                     CONSTRAINT rest_src_sync_type_ck
                     CHECK (sync_type IN ('INCREMENTAL','FULL_ONLY','CODE_BASED')),
    is_active        VARCHAR2(1)    DEFAULT 'Y' NOT NULL
                     CHECK (is_active IN ('Y','N')),
    loader_procedure VARCHAR2(200),            -- PL/SQL procedure for CODE_BASED sources
    created_ts       TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT rest_src_module_uk UNIQUE (module_static_id)
);

COMMENT ON TABLE  rest_source_registry IS 'Registry of APEX REST Data Sources for on-demand sync triggering';
COMMENT ON COLUMN rest_source_registry.module_static_id IS 'APEX REST Data Source module static ID (case-sensitive)';
COMMENT ON COLUMN rest_source_registry.date_field IS 'Date attribute for incremental filter; NULL for FULL_ONLY sources';
COMMENT ON COLUMN rest_source_registry.sync_type IS 'INCREMENTAL = date-filtered sync; FULL_ONLY = no queryable date field';
COMMENT ON COLUMN rest_source_registry.module_code IS 'Functional module: HCM, FIN, GL, PRC';
COMMENT ON COLUMN rest_source_registry.loader_procedure IS 'Fully qualified PL/SQL procedure for CODE_BASED sources (e.g. pkg_rest_recruiting.load_requisitions)';


-- =============================================================================
-- SEED DATA
-- =============================================================================

-- GL Segment Values (9 sources)
INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_account_values', 'Account Values', 'GL', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_accounting_scenario_values', 'Accounting Scenario Values', 'GL', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_activity_values', 'Activity Values', 'GL', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_fund_values', 'Fund Values', 'GL', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_function_values', 'Function Values', 'GL', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_grant_values', 'Grant Values', 'GL', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_initiative_values', 'Initiative Values', 'GL', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_interfund_values', 'Interfund Values', 'GL', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_location_values', 'Location Values', 'GL', 'LastUpdateDate', 'INCREMENTAL');

-- Financials (2 sources)
INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_invoices', 'AP Invoices', 'FIN', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_receivable_transactions', 'Receivable Transactions', 'FIN', 'LastUpdateDate', 'INCREMENTAL');

-- HCM (5 sources)
INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_job_applications', 'Job Applications', 'HCM', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type, loader_procedure) VALUES
    ('rest_sync_job_requisitions', 'Job Requisitions', 'HCM', NULL, 'CODE_BASED', 'pkg_rest_recruiting.load_requisitions');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_absences', 'Absences', 'HCM', 'lastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_positions', 'Positions', 'HCM', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_salaries', 'Salaries', 'HCM', 'LastUpdateDate', 'INCREMENTAL');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type, loader_procedure) VALUES
    ('rest_sync_recruitingcandidates', 'Recruiting Candidates', 'HCM', NULL, 'CODE_BASED', 'pkg_rest_recruiting.load_candidates');

-- Procurement (1 source)
INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_purchase_orders', 'Purchase Orders', 'PRC', 'LastUpdateDate', 'INCREMENTAL');

-- Full-only sources (LastUpdateDate not queryable via REST)
INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_locations', 'Locations', 'HCM', NULL, 'FULL_ONLY');

INSERT INTO rest_source_registry (module_static_id, display_name, module_code, date_field, sync_type) VALUES
    ('rest_sync_suppliers', 'Suppliers', 'PRC', NULL, 'FULL_ONLY');

COMMIT;
