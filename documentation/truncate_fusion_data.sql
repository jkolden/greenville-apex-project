--------------------------------------------------------------------------------
-- truncate_fusion_data.sql
--
-- Clears all Fusion-sourced data from the ATP schema in preparation for
-- switching to a new Fusion instance (e.g., dev4 → dev2). Run this BEFORE
-- loading data from the new instance.
--
-- WHAT THIS CLEARS:
--   - BICC pipeline tables (landing, staging, final)
--   - REST sync tables (APEX declarative + code-based)
--   - BIP report tables
--   - Dimension tables
--   - Routing phase/state LOVs (instance-specific IDs)
--   - Fusion security snapshot tables
--   - Load logs and reconciliation history
--
-- WHAT THIS DOES NOT CLEAR:
--   - Config/registry tables (bicc_loader_map, bicc_datastore, rest_source_registry, etc.)
--   - User-entered data (notes, rankings, tickets, email config, security grants)
--   - Schema metadata (view_column_crosswalk)
--
-- Usage: Run from APEX SQL Commands or SQLcl as the schema owner.
--------------------------------------------------------------------------------

-- ============================================================================
-- 1. BICC FINAL TABLES
-- ============================================================================
TRUNCATE TABLE hcm_employee_bc;
TRUNCATE TABLE hcm_assignment_bc;
TRUNCATE TABLE hcm_position_bc;
TRUNCATE TABLE hcm_salary_bc;
TRUNCATE TABLE pos_custom_flex_bc;
TRUNCATE TABLE qstnr_answer_bc;
TRUNCATE TABLE qstnr_question_bc;
TRUNCATE TABLE qstnr_response_bc;
TRUNCATE TABLE ap_invoice_hdr_bc;
TRUNCATE TABLE ap_disbursement_bc;
TRUNCATE TABLE ap_inv_application_bc;
TRUNCATE TABLE ar_invoices_bc;
TRUNCATE TABLE gl_code_comb_bc;
TRUNCATE TABLE gl_balance_bc;
TRUNCATE TABLE gl_budget_balance_bc;
TRUNCATE TABLE gl_journal_batch_bc;
TRUNCATE TABLE gl_journal_header_bc;
TRUNCATE TABLE gl_journal_lines_bc;
TRUNCATE TABLE po_hdr_bc;
TRUNCATE TABLE po_lines_bc;
TRUNCATE TABLE supplier_hdr_bc;

-- ============================================================================
-- 2. BICC STAGING TABLES
-- ============================================================================
TRUNCATE TABLE s_hcm_employee_bc;
TRUNCATE TABLE s_hcm_assignment_bc;
TRUNCATE TABLE s_hcm_position_bc;
TRUNCATE TABLE s_hcm_salary_bc;
TRUNCATE TABLE s_pos_custom_flex_bc;
TRUNCATE TABLE s_qstnr_answer_bc;
TRUNCATE TABLE s_qstnr_question_bc;
TRUNCATE TABLE s_qstnr_response_bc;
TRUNCATE TABLE s_ap_invoice_hdr_bc;
TRUNCATE TABLE s_ap_disbursement_bc;
TRUNCATE TABLE s_ap_inv_application_bc;
TRUNCATE TABLE s_gl_code_comb_bc;
TRUNCATE TABLE s_gl_balance_bc;
TRUNCATE TABLE s_gl_budget_balance_bc;
TRUNCATE TABLE s_po_hdr_bc;
TRUNCATE TABLE s_po_lines_bc;
TRUNCATE TABLE s_supplier_hdr_bc;

-- ============================================================================
-- 3. BICC LANDING TABLES
-- ============================================================================
TRUNCATE TABLE l_hcm_employee_bc;
TRUNCATE TABLE l_hcm_assignment_bc;
TRUNCATE TABLE l_hcm_position_bc;
TRUNCATE TABLE l_hcm_salary_bc;
TRUNCATE TABLE l_pos_custom_flex_bc;
TRUNCATE TABLE l_qstnr_answer_bc;
TRUNCATE TABLE l_qstnr_question_bc;
TRUNCATE TABLE l_qstnr_response_bc;
TRUNCATE TABLE l_ap_invoice_hdr_bc;
TRUNCATE TABLE l_ap_disbursement_bc;
TRUNCATE TABLE l_ap_inv_application_bc;
TRUNCATE TABLE l_gl_code_comb_bc;
TRUNCATE TABLE l_gl_balance_bc;
TRUNCATE TABLE l_gl_budget_balance_bc;
TRUNCATE TABLE l_po_hdr_bc;
TRUNCATE TABLE l_po_lines_bc;
TRUNCATE TABLE l_supplier_hdr_bc;

-- ============================================================================
-- 4. REST SYNC TABLES (APEX Declarative)
-- ============================================================================
-- GL Segment Values
TRUNCATE TABLE account_values_r;
TRUNCATE TABLE acctg_scenario_values_r;
TRUNCATE TABLE activity_values_r;
TRUNCATE TABLE fund_values_r;
TRUNCATE TABLE function_values_r;
TRUNCATE TABLE grant_values_r;
TRUNCATE TABLE initiative_values_r;
TRUNCATE TABLE interfund_values_r;
TRUNCATE TABLE location_values_r;
-- HCM
TRUNCATE TABLE hcm_absences_r;
TRUNCATE TABLE hcm_position_r;
TRUNCATE TABLE hcm_salary_r;
-- Financials
TRUNCATE TABLE ap_invoice_hdr_r;
TRUNCATE TABLE receivable_transactions_r;
TRUNCATE TABLE po_hdr_r;
-- Reference
TRUNCATE TABLE departments_r;
TRUNCATE TABLE locations_r;
TRUNCATE TABLE suppliers_r;

-- ============================================================================
-- 5. REST SYNC TABLES (Code-based — pkg_rest_recruiting)
-- ============================================================================
TRUNCATE TABLE job_applicants_r;
TRUNCATE TABLE job_requisitions_r;
TRUNCATE TABLE recruiting_candidates_r;
TRUNCATE TABLE candidate_phones_r;
TRUNCATE TABLE req_dff_r;
TRUNCATE TABLE req_published_jobs_r;

-- ============================================================================
-- 6. DIMENSION TABLES
-- ============================================================================
TRUNCATE TABLE fbx_dim_job;
TRUNCATE TABLE fbx_dim_grade;
TRUNCATE TABLE fbx_dim_location;
TRUNCATE TABLE dim_department_r;

-- ============================================================================
-- 7. BIP REPORT TABLES
-- ============================================================================
TRUNCATE TABLE bip_gallup_assessments;
TRUNCATE TABLE bip_questionnaires;

-- ============================================================================
-- 8. ROUTING PHASE/STATE (instance-specific IDs)
-- ============================================================================
TRUNCATE TABLE rec_routing_phase;
TRUNCATE TABLE rec_routing_state;

-- ============================================================================
-- 9. FUSION SECURITY SNAPSHOT TABLES
-- ============================================================================
TRUNCATE TABLE fa_user_accounts;
TRUNCATE TABLE fa_user_roles;

-- ============================================================================
-- 10. OTL TIME & LABOR
-- ============================================================================
TRUNCATE TABLE otl_time_record;
TRUNCATE TABLE otl_time_attribute;

-- ============================================================================
-- 11. LOAD LOGS & TRACKING (clear history from old instance)
-- ============================================================================
TRUNCATE TABLE bicc_load_log;
TRUNCATE TABLE bicc_load_job;
TRUNCATE TABLE bicc_files;
TRUNCATE TABLE bip_load_log;
TRUNCATE TABLE recon_run;
TRUNCATE TABLE recon_result;

-- ============================================================================
-- TABLES INTENTIONALLY NOT CLEARED (config, user data, metadata)
-- ============================================================================
-- bicc_loader_map          — file pattern → load type config
-- bicc_datastore           — BICC datastore registry
-- rest_source_registry     — REST sync config
-- recon_source_config      — reconciliation entity config
-- view_column_crosswalk    — view metadata (regenerated by refresh_view_crosswalk)
-- email_config             — notification settings (update ENVIRONMENT_NAME separately)
-- email_message            — user-composed emails
-- email_notification_log   — send history (clear if desired)
-- rec_dept_grant           — user-assigned security grants
-- app_user_roles           — user role assignments
-- candidate_note           — user-entered notes
-- applicant_note           — user-entered notes
-- applicant_ranking        — user-entered rankings
-- rec_content_library      — email templates
-- app_ticket_*             — support tickets
-- ref_correction*          — data corrections
