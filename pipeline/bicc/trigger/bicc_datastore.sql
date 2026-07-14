-- =============================================================================
-- TABLE: BICC_DATASTORE
-- =============================================================================
-- Registry of BICC data stores available for on-demand extract triggering.
-- Each row maps a Fusion datastore path to a friendly name and (optionally)
-- to an existing BICC loader pipeline load type.
--
-- Used by pkg_bicc_trigger and the APEX manual extract page.
-- =============================================================================

CREATE TABLE bicc_datastore (
    datastore_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    business_object     VARCHAR2(100)  NOT NULL,
    datastore_path      VARCHAR2(500)  NOT NULL,   -- full AM.AM.PVO path for SOAP DATA_STORE_LIST
    friendly_name       VARCHAR2(200)  NOT NULL,   -- human-readable label for APEX page
    load_type           VARCHAR2(50),              -- maps to bicc_loader_map.load_type (NULL if no pipeline yet)
    module_code         VARCHAR2(10)   NOT NULL,   -- HCM, FIN, PRC, GL
    is_active           VARCHAR2(1)    DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y','N')),
    created_ts          TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT bicc_ds_path_uk UNIQUE (datastore_path)
);

COMMENT ON TABLE bicc_datastore IS 'Registry of BICC data stores for on-demand extract triggering';
COMMENT ON COLUMN bicc_datastore.datastore_path IS 'Full datastore path passed to SOAP DATA_STORE_LIST parameter';
COMMENT ON COLUMN bicc_datastore.load_type IS 'Maps to bicc_loader_map.load_type — NULL if no load pipeline exists yet';
COMMENT ON COLUMN bicc_datastore.module_code IS 'Functional module: HCM, FIN, PRC, GL';


-- =============================================================================
-- SEED DATA
-- =============================================================================

-- HCM
INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('Person', 'HcmTopModelAnalyticsGlobalAM.PersonAM.GlobalPersonPVOViewAll', 'HCM Employee (Person)', 'HCM_EMPLOYEE', 'HCM');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('Position', 'HcmTopModelAnalyticsGlobalAM.PositionAM.PositionPVOViewAll', 'HCM Position', 'HCM_POSITION', 'HCM');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('Assignment', 'HcmTopModelAnalyticsGlobalAM.AssignmentAM.AssignmentPVO', 'HCM Assignment', 'HCM_ASSIGNMENT', 'HCM');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('HCMExtractAM.HcmCompBiccExtract', 'HcmTopModelAnalyticsGlobalAM.HCMExtractAM.HcmCompBiccExtractAM.SalaryExtractPVO', 'HCM Salary', 'HCM_SALARY', 'HCM');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('PositionCustomerFlexBI', 'HcmTopModelAnalyticsGlobalAM.PositionCustomerFlexBIAM.FLEX_BI_PositionCustomerFlex_VI', 'Position Customer Flex DFF', 'POS_CUSTOM_FLEX', 'HCM');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('Questionnaire', 'HcmTopModelAnalyticsGlobalAM.QuestionnaireAM.ParticipantQuestionnaireQuestionPVO', 'Questionnaire Questions', 'QSTNR_QUESTION', 'HCM');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('Questionnaire', 'HcmTopModelAnalyticsGlobalAM.QuestionnaireAM.QuestionnaireQuestionResponsePVO', 'Questionnaire Responses', 'QSTNR_RESPONSE', 'HCM');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('QuestionnaireLibrary', 'HcmTopModelAnalyticsGlobalAM.QuestionnaireLibraryAM.QuestionAnswerPVO', 'Questionnaire Answers', 'QSTNR_ANSWER', 'HCM');

-- Financials - AP
INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinApInvTransactions', 'FscmTopModelAM.FinApInvTransactionsAM.InvoiceHeaderPVO', 'AP Invoice Headers', 'AP_INVOICE_HDR', 'FIN');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinExtractAM.ApBiccExtract', 'FscmTopModelAM.FinExtractAM.ApBiccExtractAM.InvoiceHeaderExtractPVO', 'AP Invoice Header Extract', 'AP_INVOICE_HDR', 'FIN');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinExtractAM.ApBiccExtract', 'FscmTopModelAM.FinExtractAM.ApBiccExtractAM.DisbursementHeaderExtractPVO', 'AP Disbursement Headers', 'AP_DISBURSEMENT', 'FIN');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinExtractAM.ApBiccExtract', 'FscmTopModelAM.FinExtractAM.ApBiccExtractAM.PaidDisbursementScheduleExtractPVO', 'AP Paid Disbursement Schedule', 'AP_INV_APPLICATION', 'FIN');

-- Financials - AR
INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinExtractAM.ArBiccExtract', 'FscmTopModelAM.FinExtractAM.ArBiccExtractAM.TransactionHeaderExtractPVO', 'AR Transaction Headers', 'AR_INVOICES', 'FIN');

-- Financials - GL
INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinExtractAM.GlBiccExtract', 'FscmTopModelAM.FinExtractAM.GlBiccExtractAM.BalanceExtractPVO', 'GL Balances', 'GL_BALANCE', 'GL');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinExtractAM.GlBiccExtract', 'FscmTopModelAM.FinExtractAM.GlBiccExtractAM.BudgetBalanceExtractPVO', 'GL Budget Balances', 'GL_BUDGET_BALANCE', 'GL');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinExtractAM.GlBiccExtract', 'FscmTopModelAM.FinExtractAM.GlBiccExtractAM.CodeCombinationExtractPVO', 'GL Code Combinations', 'GL_CODE_COMB', 'GL');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinExtractAM.GlBiccExtract', 'FscmTopModelAM.FinExtractAM.GlBiccExtractAM.JournalBatchExtractPVO', 'GL Journal Batches', 'GL_JOURNAL_BATCH', 'GL');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinExtractAM.GlBiccExtract', 'FscmTopModelAM.FinExtractAM.GlBiccExtractAM.JournalHeaderExtractPVO', 'GL Journal Headers', 'GL_JOURNAL_HEADER', 'GL');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinExtractAM.GlBiccExtract', 'FscmTopModelAM.FinExtractAM.GlBiccExtractAM.JournalLineExtractPVO', 'GL Journal Lines', 'GL_JOURNAL_LINES', 'GL');

-- Financials - GL Inquiry Balances
INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('FinGlInquiryBalances', 'FscmTopModelAM.FinGlInquiryBalancesAM.BudgetBalancePVO', 'GL Inquiry Budget Balances', 'GL_BUDGET_BALANCE', 'GL');

-- Procurement - PO
INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('PrcExtractAM.PoBiccExtract', 'FscmTopModelAM.PrcExtractAM.PoBiccExtractAM.PurchasingDocumentHeaderExtractPVO', 'PO Headers', 'PO_HDR', 'PRC');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('PrcExtractAM.PoBiccExtract', 'FscmTopModelAM.PrcExtractAM.PoBiccExtractAM.PurchasingDocumentLineExtractPVO', 'PO Lines', 'PO_LINES', 'PRC');

-- Procurement - Suppliers
INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('PrcExtractAM.PozBiccExtract', 'FscmTopModelAM.PrcExtractAM.PozBiccExtractAM.SupplierExtractPVO', 'Supplier Headers', 'SUPPLIER_HDR', 'PRC');

INSERT INTO bicc_datastore (business_object, datastore_path, friendly_name, load_type, module_code) VALUES
    ('PrcExtractAM.PozBiccExtract', 'FscmTopModelAM.PrcExtractAM.PozBiccExtractAM.SupplierSiteExtractPVO', 'Supplier Sites', NULL, 'PRC');

COMMIT;
