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
-- Table names verified against user_tables (2026-08-18).
-- Usage: Paste into APEX SQL Commands and run as the schema owner.
--        Uses EXECUTE IMMEDIATE because TRUNCATE is DDL.
--        Disables/re-enables FK constraints to avoid ORA-02266.
--------------------------------------------------------------------------------
BEGIN
  -- Disable all foreign keys first to avoid ORA-02266
  FOR c IN (SELECT constraint_name, table_name
            FROM user_constraints
            WHERE constraint_type = 'R'
            AND status = 'ENABLED') LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name ||
      ' DISABLE CONSTRAINT ' || c.constraint_name;
  END LOOP;

  -- BICC FINAL TABLES (21)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE hcm_employee_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE hcm_assignment_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE hcm_position_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE hcm_salary_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE pos_custom_flex_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE qstnr_answer_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE qstnr_question_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE qstnr_response_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE ap_invoice_hdr_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE ap_disbursement_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE ap_inv_application_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE ar_invoices_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE gl_code_comb_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE gl_balance_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE gl_budget_balance_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE gl_journal_batch_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE gl_journal_header_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE gl_journal_lines_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE po_hdr_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE po_lines_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE supplier_hdr_bc';

  -- BICC STAGING TABLES (21)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_hcm_employee_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_hcm_assignment_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_hcm_position_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_hcm_salary_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_pos_custom_flex_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_qstnr_answer_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_qstnr_question_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_qstnr_response_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_ap_invoice_hdr_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_ap_disbursement_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_ap_inv_application_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_ar_invoices_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_gl_code_comb_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_gl_balance_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_gl_budget_balance_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_gl_journal_batch_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_gl_journal_header_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_gl_journal_lines_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_po_hdr_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_po_lines_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE s_supplier_hdr_bc';

  -- BICC LANDING TABLES (21)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_hcm_employee_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_hcm_assignment_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_hcm_position_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_hcm_salary_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_pos_custom_flex_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_qstnr_answer_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_qstnr_question_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_qstnr_response_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_ap_invoice_hdr_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_ap_disbursement_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_ap_inv_application_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_ar_invoices_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_gl_code_comb_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_gl_balance_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_gl_budget_balance_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_gl_journal_batch_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_gl_journal_header_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_gl_journal_lines_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_po_hdr_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_po_lines_bc';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE l_supplier_hdr_bc';

  -- REST SYNC TABLES — APEX Declarative (18)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE account_values_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE acctg_scenario_values_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE activity_values_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE fund_values_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE function_values_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE grant_values_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE initiative_values_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE interfund_values_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE location_values_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE hcm_absences_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE hcm_position_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE hcm_salary_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE ap_invoice_hdr_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE receivable_transactions_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE po_hdr_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE departments_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE locations_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE suppliers_r';

  -- REST SYNC TABLES — Code-based / pkg_rest_recruiting (6)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE job_applicants_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE job_requisitions_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE recruiting_candidates_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE candidate_phones_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE req_dff_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE req_published_jobs_r';

  -- DIMENSION TABLES (3)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE dim_job_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE dim_grade_r';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE dim_location_r';

  -- BIP REPORT TABLES (3)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE bip_gallup_assessments';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE bip_questionnaires';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE ext_flex_stg';

  -- ROUTING PHASE/STATE — instance-specific IDs (2)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE rec_routing_phase';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE rec_routing_state';

  -- FUSION SECURITY SNAPSHOT TABLES (2)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE fa_user_accounts';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE fa_user_roles';

  -- OTL TIME & LABOR (2)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE otl_time_record';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE otl_time_attribute';

  -- LOAD LOGS & TRACKING (6)
  EXECUTE IMMEDIATE 'TRUNCATE TABLE bicc_load_log';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE bicc_load_job';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE bicc_files';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE bip_load_log';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE recon_run';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE recon_result';

  -- Re-enable all foreign keys
  FOR c IN (SELECT constraint_name, table_name
            FROM user_constraints
            WHERE constraint_type = 'R'
            AND status = 'DISABLED') LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name ||
      ' ENABLE CONSTRAINT ' || c.constraint_name;
  END LOOP;
END;
/

--------------------------------------------------------------------------------
-- TABLES INTENTIONALLY NOT CLEARED (config, user data, metadata)
--------------------------------------------------------------------------------
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
