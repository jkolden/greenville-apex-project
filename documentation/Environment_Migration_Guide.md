# Greenville County Schools — Oracle Fusion Cloud Integration
# Environment Migration Guide

**Project**: BICC Data Integration & Recruiting Platform
**Database**: Oracle Autonomous Transaction Processing (ATP)
**Application**: Oracle APEX (Application 121)
**Prepared by**: John Kolden, Sierra-Cedar
**Date**: July 2026

---

## 1. Purpose

This document provides step-by-step instructions for repointing the Greenville County Schools integration platform from one Oracle Fusion Cloud instance to another (e.g., DEV to TEST, or TEST to PROD). The OCI database, APEX application, and all schema objects remain in place — only the Fusion-side configuration and connection details change.

---

## 2. Scope of Change

When moving to a new Fusion environment, the following must be updated:

```
Fusion Instance URL         →  Package constants, APEX REST Data Sources, APEX page deep-links
APEX Web Credential          →  Update username/password for new Fusion service account
BICC External Storage        →  New storage profile name (if different)
BIP Reports                  →  Redeploy custom reports to new Fusion BI Publisher catalog
Fusion Security Roles        →  Provision integration user in new instance
Routing Phase/State IDs      →  Re-extract from new Fusion (instance-specific IDs)
IDCS OAuth (if applicable)   →  New token URL, client ID/secret, scope
```

What does NOT change: OCI Object Storage bucket, ATP database, APEX workspace, schema objects, scheduler jobs, VPD policies, seed data (except routing tables).

---

## 3. Prerequisites in the Target Fusion Environment

Before starting, confirm the following exist in the new Fusion instance:

- [ ] Integration user provisioned with required roles:
  - BI Administrator (for BICC extract submissions)
  - Integration Specialist or equivalent (for REST API access)
  - BIP report execution privileges
  - Recruiting data security: "View All Requisitions" (ORC must be provisioned)
- [ ] BICC offerings configured for all required datastores (24 datastores — see Section 6.1)
- [ ] External Storage profile created and pointed to the existing OCI bucket
- [ ] Custom BIP reports deployed to the same catalog paths (see Section 6.3)
- [ ] ATP network access can reach the new Fusion hostname on HTTPS 443

---

## 4. Update Fusion Instance URL

The Fusion hostname is now **centralized** in a single package constant. Most other packages reference this constant rather than storing their own copy.

### 4.1 Current Value

```
ibzsjb-dev4.fa.ocs.oraclecloud.com
```

### 4.2 File to Update

| File | Constant | Line | Notes |
|---|---|---|---|
| `pkg_bicc_common.sql` | `gc_fa_base_url` | 12 | **Single source of truth** — all other packages reference this |

The following packages derive their URL from `pkg_bicc_common.gc_fa_base_url` at runtime and require **no changes**:

- `pkg_bicc_dimensions` — dimension refresh
- `pkg_rest_recruiting` — requisition and candidate loading
- `pkg_rec_move` — applicant move action
- `pkg_app_attachments` — attachment download
- `pkg_bip_soap` — BIP SOAP report execution
- `pkg_bicc_trigger` — BICC extract submission
- `pkg_recon` — reconciliation counts
- `pkg_otl_time` — OTL time records

**Packages with their own constant (placeholder values — not yet migrated)**:

| File | Constant | Line | Status |
|---|---|---|---|
| `rec_email/pkg_rec_email.sql` | `gc_fa_base_url` | 10 | Placeholder `https://<FUSION_HOST_DEV>` — should be migrated to reference `pkg_bicc_common.gc_fa_base_url` |
| `security/pkg_app_security.sql` | `gc_fa_base_url` | 66 | Placeholder `https://<FUSION_HOST_DEV>` — should be migrated to reference `pkg_bicc_common.gc_fa_base_url` |
| `data_extract/pkg_data_extract.sql` | `gc_base_url` | 12 | 26B POC only — uses IDCS OAuth (see Section 10) |
| `bpm_tasks/pkg_bpm_tasks.sql` | `gc_base_url` | 12 | **Intentionally independent** — may target a different Fusion instance than the rest of the app. Has its own credential (`gcs_reports_dev4`). Update only when BPM workflow tasks should move to the new instance. Also update `gc_credential` and `gc_user_credential` constants to match the target instance's Web Credentials. |

After updating `pkg_bicc_common.sql`, recompile it and then recompile all dependent packages.

### 4.3 APEX Page Deep-Links

`f121_page_24.sql` contains hardcoded Fusion UI deep-links (lines ~1486, 1546) that open requisitions in Fusion. Update the hostname in these URLs or they will point to the old instance.

### 4.4 Cosmetic References

All APEX page export files (`f121_*.sql`) reference the environment name in header comments (e.g., `ibzsjb-test`). These are cosmetic only and do not affect functionality, but will be corrected automatically when the app is re-exported from APEX.

### 4.5 Quick Method

Edit line 12 of `pkg_bicc_common.sql`:

```sql
-- Change this:
gc_fa_base_url CONSTANT VARCHAR2(200) := 'https://ibzsjb-dev4.fa.ocs.oraclecloud.com';
-- To:
gc_fa_base_url CONSTANT VARCHAR2(200) := 'https://<new_fusion_host>.fa.ocs.oraclecloud.com';
```

Then recompile `pkg_bicc_common` and all dependent packages from APEX SQL Commands. A global find-and-replace is no longer necessary since the hostname is centralized.

---

## 5. Update APEX Web Credential

The APEX Web Credential `gcs_reports` stores the Fusion service account username and password. This credential is used by all packages that call Fusion REST APIs, BIP SOAP reports, and reconciliation.

### 5.1 Steps

1. Open APEX > Shared Components > Web Credentials
2. Edit the credential with static ID `gcs_reports`
3. Update the username and password to match the new Fusion instance's integration user
4. Test connectivity:

```sql
SELECT apex_web_service.make_rest_request(
    p_url => 'https://<new_fusion_host>/hcmRestApi/resources/11.13.18.05/emps?limit=1',
    p_http_method => 'GET',
    p_credential_static_id => 'gcs_reports'
) FROM dual;
```

A successful response confirms the credential is working. A 401 means bad credentials; a 403 means the user lacks required roles.

### 5.2 Update Application Settings

Two Application Settings store Basic Auth credentials used by packages that cannot use APEX Web Credentials (due to SOAP custom headers or OAuth conflicts):

1. Open APEX > Shared Components > Application Settings
2. Update these settings with the new Fusion instance's integration user credentials:

| Setting | Used By | Why Basic Auth? |
|---|---|---|
| `BICC_FUSION_USERNAME` | `pkg_bicc_trigger` (BICC SOAP extract submission) | SOAP WS-Addressing headers conflict with OAuth token exchange |
| `BICC_FUSION_PASSWORD` | `pkg_rec_move` (applicant move action) | Custom `Content-Type` header corrupts OAuth flow |

**Why separate from Web Credential?** These packages use `apex_web_service.make_rest_request` with `p_username`/`p_password` parameters instead of `p_credential_static_id`. This is required when the package sets custom request headers (like WS-Addressing for SOAP or `application/vnd.oracle.adf.action+json`) that APEX inadvertently applies to its internal OAuth token requests, causing authentication failures.

### 5.3 Packages That Use This Credential

All of these will automatically pick up the updated credential — no code changes needed:

- `pkg_bicc_dimensions` — dimension refresh (Jobs, Grades, Locations)
- `pkg_rest_recruiting` — requisition and candidate loading
- `pkg_rec_move` — applicant move action
- `pkg_app_attachments` — attachment download
- `pkg_bip_soap` — BIP report execution
- `pkg_recon` — reconciliation REST counts
- `pkg_app_security` — login role caching
- `pkg_rec_email` — content library loading
- `pkg_otl_time` — OTL time records

---

## 6. Fusion Cloud Configuration

### 6.1 BICC Offering Export / Import

Rather than manually recreating each BICC offering in the new Fusion instance, export the complete BICC configuration from the source environment and import it into the target.

#### Export from Source (e.g., DEV4)

1. Navigate to **Tools > Scheduled Processes** (or use the Navigator)
2. Open **BI Cloud Connector Console** (BICC)
3. Go to **Configure Manage Offerings** (the offerings page)
4. Click **Export** — this produces a set of CSV files containing all offering configurations, data store selections, job definitions, and runtime settings
5. Save the CSV files to a reference folder (e.g., `BICC Artifacts from dev4/`)

The export produces the following artifact files:

| Artifact File | Contents |
|---|---|
| `C_BIA_OFFFERING.csv` | Offering definitions (which functional areas are enabled) |
| `C_DATA_STORE.csv` | Data store definitions (which VO entities are selected) |
| `C_DATA_STORE_CUST_PAR*.csv` | Custom parameters per data store |
| `C_DATA_STORE_CUSTOM_*.csv` | Custom column/attribute selections |
| `C_DATA_STORE_RUNTIME*.csv` | Runtime settings (filters, incremental mode) |
| `C_DATA_EXTERNAL_STOR*.csv` | External storage profile assignments |
| `C_JOB.csv` | Scheduled job definitions |
| `C_JOB_DATA_STORE_REL.csv` | Job-to-data-store relationships |
| `C_JOB_DATA_STORE_CUST*.csv` | Job-level custom data store settings |
| `C_JOB_DATA_STORE_RUNT*.csv` | Job-level runtime data store settings |

#### Import to Target (e.g., TEST or PROD)

1. In the **target** Fusion instance, open the BICC Console
2. Go to **Configure Manage Offerings**
3. Click **Import** and upload the artifact CSV files exported from the source
4. Review the import summary — all offerings, data stores, and attribute selections will be restored
5. **Update the External Storage assignment** if the storage profile name differs between environments (see Section 6.3)
6. **Verify scheduling** — import may or may not preserve the schedule; confirm and re-enable if needed

#### What the Import Does NOT Cover

- **External Storage profile** — must be created separately in the target instance (Section 6.3)
- **OCI bucket connectivity** — the storage profile must be pointed at the correct OCI bucket
- **Security roles** — the integration user in the target instance still needs BI Administrator and related roles (Section 6.5)
- **Initial extract** — after import, run an initial BICC extract to populate Object Storage with data from the new instance

#### Artifact Retention

The DEV4 BICC artifacts have been saved to the SharePoint folder `Historical Data .../BICC Artifacts from dev4/`. These serve as a backup of the complete BICC configuration and can be re-imported if offerings are accidentally modified or need to be restored.

### 6.2 BICC Offerings (Manual Reference)

If the import approach is not available or a manual review is needed, the 24 datastores registered in the `BICC_DATASTORE` table span:

| Module | Examples |
|---|---|
| HCM | Employee, Assignment, Position, Salary, Questionnaires |
| FIN | AP Invoices, GL Balances, GL Journals, AR Invoices |
| PRC | PO Headers, PO Lines, Suppliers |
| Recruiting | Routing Steps, Questionnaire Responses |

### 6.3 BICC External Storage

The BICC console in the new Fusion instance needs an External Storage profile that points to the **existing** OCI Object Storage bucket (`SCI_Conversion`).

| Setting | Value |
|---|---|
| Storage Type | Oracle Cloud Object Storage |
| Profile Name | Must match `gc_storage_name` in `pkg_bicc_trigger.sql` (currently `GCS_HISTORY_DATA_STORAGE`) |
| Bucket | Same OCI bucket the platform already uses |

If the storage profile name differs from the current value, update `pkg_bicc_trigger.sql` line 24:
```sql
gc_storage_name CONSTANT VARCHAR2(100) := '<new_storage_profile_name>';
```

### 6.4 BIP Reports

Deploy all custom BIP reports to the target Fusion BI Publisher catalog at the same paths:

**Data Load Reports** — `/Custom/SCI/BIP/`:

| Report File | Purpose |
|---|---|
| `Extensible_Flex.xdo` | Person extensible flexfield data |
| `Questionnaires.xdo` | Questionnaire responses |
| `Gallup_XML.xdo` | Gallup assessment scores |
| `User Account_XML.xdo` | Fusion user accounts (security fallback) |
| `user_roles_XML.xdo` | Fusion user-role assignments (security fallback) |
| `hcm_object_counts.xdo` | HCM record counts (reconciliation) |
| `Financials_object_counts.xdo` | FIN record counts (reconciliation) |

**Security Reports** — `/Custom/SCI/Security/Data Validation/XML Reports/`:

| Report File | Purpose |
|---|---|
| `User Account_XML_v2.xdo` | User account analysis |
| `Role List_XML.xdo` | Role inventory |
| `Inherited Roles_XML.xdo` | Role inheritance tree |
| `Role Privileges_XML.xdo` | Role-to-privilege mapping |
| `User Role_XML.xdo` | User-to-role assignments |
| `ERP Data Context_XML.xdo` | ERP data security contexts |
| `Position Assignments_XML.xdo` | Position-based assignments |

If report paths differ in the new environment, update:
- `pkg_bip_soap.plb` line 16: `c_report_folder` constant
- Individual report path defaults in `pkg_bip_soap.sql`

### 6.5 Fusion Security Roles

The integration user in the new Fusion instance needs:
- **BI Administrator** — BICC extract submissions
- **Integration Specialist** (or equivalent) — REST API access for HCM, FIN, PRC
- **Recruiting roles** — with "View All Requisitions" data security profile
- **ORC provisioned** — Oracle Recruiting Cloud must be enabled

---

## 7. Update APEX REST Data Sources

The 19 APEX REST Data Sources in Shared Components each have a "Remote Server" URL pointing to the Fusion instance. Update all of them to the new hostname.

### 7.1 Steps

1. Open APEX > Shared Components > REST Data Sources
2. For each source, edit the Remote Server to point to the new Fusion hostname
3. The REST endpoint paths (e.g., `/hcmRestApi/resources/11.13.18.05/salaries`) remain the same

### 7.2 REST Data Source Inventory

| Static ID | Endpoint Path |
|---|---|
| `rest_sync_account_values` | `/fscmRestApi/.../valueSets/GCS_GL_ACCOUNT/child/values` |
| `rest_sync_fund_values` | `/fscmRestApi/.../valueSets/GCS_GL_FUND/child/values` |
| `rest_sync_function_values` | `/fscmRestApi/.../valueSets/GCS_GL_FUNCTION/child/values` |
| `rest_sync_grant_values` | `/fscmRestApi/.../valueSets/GCS_GL_GRANT/child/values` |
| `rest_sync_initiative_values` | `/fscmRestApi/.../valueSets/GCS_GL_INITIATIVE/child/values` |
| `rest_sync_activity_values` | `/fscmRestApi/.../valueSets/GCS_GL_ACTIVITY/child/values` |
| `rest_sync_interfund_values` | `/fscmRestApi/.../valueSets/GCS_GL_INTERFUND/child/values` |
| `rest_sync_location_values` | `/fscmRestApi/.../valueSets/GCS_GL_LOCATION/child/values` |
| `rest_sync_accounting_scenario_values` | `/fscmRestApi/.../valueSets/GCS_GL_ACCTG_SCENARIO/child/values` |
| `rest_sync_invoices` | `/fscmRestApi/.../invoices` |
| `rest_sync_receivable_transactions` | `/fscmRestApi/.../receivablesInvoices` |
| `rest_sync_purchase_orders` | `/fscmRestApi/.../purchaseOrders` |
| `rest_sync_job_applications` | `/hcmRestApi/.../recruitingJobApplications` |
| `rest_sync_absences` | `/hcmRestApi/.../absences` |
| `rest_sync_positions` | `/hcmRestApi/.../positions` |
| `rest_sync_salaries` | `/hcmRestApi/.../salaries` |
| `rest_sync_locations` | `/hcmRestApi/.../locationsV2` |
| `rest_sync_suppliers` | `/fscmRestApi/.../suppliers` |
| `rest_sync_job_requisitions` | CODE_BASED (deactivated sync, used by `pkg_rest_recruiting`) |
| `rest_sync_recruitingcandidates` | CODE_BASED (deactivated sync, used by `pkg_rest_recruiting`) |

**Note on GL Value Sets**: If the target Fusion environment uses different Value Set names (e.g., something other than `GCS_GL_ACCOUNT`), update the URL paths accordingly.

### 7.3 Run Initial Sync

After updating all REST Data Sources, run a full sync to populate tables from the new instance:

```sql
BEGIN
    pkg_rest_sync.sync_all;
    pkg_rest_recruiting.refresh_all;
    pkg_bicc_dimensions.refresh_all;
END;
```

---

## 7a. Clean OCI Object Storage and Tracking Data

The OCI bucket (`SCI_Conversion`) contains BICC extract ZIPs, staged CSVs, and status files from the previous Fusion instance. These must be purged before loading from the new instance to avoid mixing data from different environments.

### 7a.1 Purge BICC Files from Object Storage

Delete your BICC pipeline files while preserving other teams' data (e.g., `FileToTable/`, `ERP/`):

```sql
BEGIN
    FOR r IN (
        SELECT object_name
        FROM dbms_cloud.list_objects('OBJ_STORE_CRED_JK',
            'https://objectstorage.us-ashburn-1.oraclecloud.com/n/idlhcuqzdx2c/b/SCI_Conversion/o/')
        WHERE (object_name LIKE 'file\_%' ESCAPE '\' AND object_name LIKE '%.zip')
           OR object_name LIKE 'staging/%'
           OR object_name LIKE 'EXTRACT\_STATUS\_DATA\_%' ESCAPE '\'
           OR object_name LIKE 'MANIFEST%'
           OR object_name LIKE '%\_unzipped.csv' ESCAPE '\'
    ) LOOP
        dbms_cloud.delete_object('OBJ_STORE_CRED_JK',
            'https://objectstorage.us-ashburn-1.oraclecloud.com/n/idlhcuqzdx2c/b/SCI_Conversion/o/' || r.object_name);
    END LOOP;
END;
```

### 7a.2 Truncate Tracking Table

```sql
TRUNCATE TABLE bicc_files;
```

This clears file discovery metadata from the old instance. New files from the target instance will be tracked fresh.

---

## 8. Re-Extract Routing Phase and State Data

The `REC_ROUTING_PHASE` (24 phases) and `REC_ROUTING_STATE` (103 states) tables contain recruiting process lifecycle definitions used as LOVs for the applicant move action on Page 24. Custom phase/state IDs are **Fusion-instance-specific** — seeded Oracle IDs (e.g., 11=New, 1001=To be Reviewed) remain the same, but custom IDs (e.g., HR Screening, Qualified, Pre-Offer) will be different in the new environment.

The `IRC_ROUTING_STEPS_STG` table (routing step hierarchy, ~1600 rows) is loaded separately via the `RoutingStepPVO` BICC datastore and must also be refreshed.

### 8.1 Run One-Off BICC Extracts

These PVOs are **not** part of the daily BICC pipeline. Run them as one-off manual extracts from the new Fusion BICC Console:

| BICC Module | Data Store / PVO | Purpose |
|---|---|---|
| `HcmRecProcessLifecycleAM` | `RoutingStepPhasePVO` | Phase definitions (e.g., New, Screening, Offer, HR) |
| `HcmRecProcessLifecycleAM` | `RoutingStepStatePVO` | State definitions (e.g., To be Reviewed, Under Consideration) |
| `HcmRecProcessLifecycleAM` | `RoutingStepPVO` | Routing step hierarchy (phase→state mapping) |

1. In the target Fusion instance, open **BICC Console**
2. Create or select the `HcmRecProcessLifecycleAM` offering
3. Run the extract — it will produce CSV files in Object Storage
4. Download the three CSV files to `DDL/Phase and State Data/`

### 8.2 Regenerate the Reload Script

The Python script below parses the Phase and State PVO CSVs and generates `reload_routing_lookups.sql` with environment-specific INSERT statements:

```bash
cd DDL
python3 -c "
import csv

def q(s):
    if s is None or s == '': return 'NULL'
    return \"'\" + s.replace(\"'\", \"''\") + \"'\"

def qn(s):
    if s is None or s == '': return 'NULL'
    return s

# --- Parse Phase CSV ---
phases = {}
with open('Phase and State Data/<phase_csv_filename>.csv', 'r') as f:
    for row in csv.DictReader(f):
        pid = row['PHASEID']
        if pid not in phases:
            code = row['CODE']
            name = row['PHASETRANSLATIONPEONAME']
            desc = row['PHASETRANSLATIONPEODESCRIPTION']
            seq = row['SEQUENCENUMBER']
            if code.startswith('REQUISITION'): ptype = 'REQUISITION'
            elif code.startswith('CANDIDATE'): ptype = 'CANDIDATE'
            elif code in ('REGISTRATION','ATTENDANCE'): ptype = 'EVENT'
            else: ptype = 'APPLICATION'
            phases[pid] = (pid, code, name, desc, seq, ptype)

# --- Parse State CSV ---
states = {}
with open('Phase and State Data/<state_csv_filename>.csv', 'r') as f:
    for row in csv.DictReader(f):
        sid = row['STATEID']
        if sid not in states:
            code = row['CODE']
            name = row['STATETRANSLATIONPEONAME']
            desc = row['STATETRANSLATIONPEODESCRIPTION']
            pub_id = row['PUBLICSTATEID'] or None
            pub_name = row['PUBLICSTATETRANSLATIONPEONAME'] or None
            if code.startswith('REQUISITION'): stype = 'REQUISITION'
            elif 441 <= int(sid) <= 451: stype = 'EVENT'
            elif 551 <= int(sid) <= 884: stype = 'CANDIDATE'
            else: stype = 'APPLICATION'
            states[sid] = (sid, code, name, desc, pub_id, pub_name, stype)

# --- Generate SQL ---
with open('reload_routing_lookups.sql', 'w') as f:
    f.write('DELETE FROM rec_routing_phase;\n\n')
    for p in sorted(phases.values(), key=lambda x: ({'APPLICATION':0,'REQUISITION':1,'CANDIDATE':2,'EVENT':3}[x[5]], float(x[0]))):
        f.write(f\"INSERT INTO rec_routing_phase (phase_id, phase_code, phase_name, phase_desc, seq_num, phase_type)\n\")
        f.write(f\"VALUES ({p[0]}, {q(p[1])}, {q(p[2])}, {q(p[3]) if p[3] else 'NULL'}, {p[4]}, {q(p[5])});\n\n\")
    f.write('DELETE FROM rec_routing_state;\n\n')
    for s in sorted(states.values(), key=lambda x: ({'APPLICATION':0,'REQUISITION':1,'CANDIDATE':2,'EVENT':3}[x[6]], float(x[0]))):
        f.write(f\"INSERT INTO rec_routing_state (state_id, state_code, state_name, state_desc, public_state_id, public_state_name, state_type)\n\")
        f.write(f\"VALUES ({s[0]}, {q(s[1])}, {q(s[2])}, {q(s[3]) if s[3] else 'NULL'}, {qn(s[4])}, {q(s[5]) if s[5] else 'NULL'}, {q(s[6])});\n\n\")
    f.write('COMMIT;\n')
print('Generated reload_routing_lookups.sql')
"
```

Replace `<phase_csv_filename>` and `<state_csv_filename>` with the actual filenames from the BICC extract.

### 8.3 Execute the Reload Script

Run `reload_routing_lookups.sql` in APEX SQL Commands. This DELETEs existing rows and INSERTs the new environment's phase and state definitions.

### 8.4 Reload Routing Step Hierarchy

The `IRC_ROUTING_STEPS_STG` table must also be refreshed from the `RoutingStepPVO` extract. This table provides the phase-to-state mapping used by the State LOV on Page 24. Load it using the same method used in the original setup (BICC pipeline or manual load).

### 8.5 Verify

1. Confirm row counts:
```sql
SELECT 'PHASE' t, COUNT(*) cnt FROM rec_routing_phase
UNION ALL SELECT 'STATE', COUNT(*) FROM rec_routing_state
UNION ALL SELECT 'ROUTING_STEPS', COUNT(*) FROM irc_routing_steps_stg;
```
   Expected: ~24 phases, ~103 states, ~1600 routing steps.

2. Test the Phase LOV on Page 24 — should return APPLICATION phases (New, Screening, HR Screening, Qualified, etc.)
3. Select a phase and confirm the State LOV populates (not all phases have states — this is normal for custom phases without state-level routing)
4. Test an actual applicant move to confirm end-to-end functionality

### 8.6 Files Reference

| File | Purpose |
|---|---|
| `DDL/rec_routing_phase.sql` | CREATE TABLE DDL for phase lookup |
| `DDL/rec_routing_state.sql` | CREATE TABLE DDL for state lookup |
| `DDL/reload_routing_lookups.sql` | DELETE + INSERT script (environment-specific, regenerated per migration) |
| `DDL/Phase and State Data/` | Raw BICC CSV extracts used to generate the reload script |

---

## 9. Update Environment Name in Email Config

Update the `EMAIL_CONFIG` table so notification emails reflect the correct environment:

```sql
UPDATE email_config SET config_value = 'PROD (ibzsjb.fa.ocs.oraclecloud.com)'
WHERE config_key = 'ENVIRONMENT_NAME';
COMMIT;
```

---

## 10. IDCS OAuth (26B Data Extract POC Only)

If the 26B Data Extract feature is in use, update `data_extract/pkg_data_extract.plb` with the target environment's IDCS credentials:

| Constant | Description |
|---|---|
| `gc_token_url` | IDCS token endpoint URL |
| `gc_client_id` | IDCS application client ID |
| `gc_client_sec` | IDCS application client secret |
| `gc_scope` | Scope URI including the new Fusion instance name |

Recompile the package body after updating.

---

## 11. Post-Migration Validation

### 11.1 Connectivity Tests

```sql
-- Test Fusion REST API
SELECT apex_web_service.make_rest_request(
    p_url => 'https://<new_host>/hcmRestApi/resources/11.13.18.05/emps?limit=1',
    p_http_method => 'GET',
    p_credential_static_id => 'gcs_reports'
) FROM dual;

-- Test BIP SOAP (will return XML or error)
SELECT pkg_bip_soap.run_report_xml('/Custom/SCI/BIP/hcm_object_counts.xdo') FROM dual;
```

### 11.2 BICC Pipeline

1. Submit a BICC extract via Page 9003 "BICC Manual Trigger" tab
2. Verify the extract completes successfully (check status)
3. Load one entity (e.g., HCM_EMPLOYEE) via "BICC Extract Files" tab
4. Confirm row count: `SELECT COUNT(*) FROM HCM_EMPLOYEE_BC;`

### 11.3 REST Sync

1. Trigger a single REST source from Page 9003 "REST Manual Trigger" tab
2. Verify rows appear in the corresponding table
3. Run `pkg_rest_recruiting.refresh_all` to test code-based loaders

### 11.4 BIP Reports

1. Load Gallup assessments from Page 9003 "BIP Manual Trigger" tab
2. Check `BIP_LOAD_LOG` for SUCCESS status

### 11.5 Reconciliation

Run a reconciliation to confirm record counts align with the new Fusion instance:

```sql
DECLARE
    v_run_id NUMBER;
BEGIN
    v_run_id := pkg_recon.run_recon;
END;
```

Review results on the "Reconciliation" tab of Page 9003.

### 11.6 Recruiting Workflow

1. Verify requisitions and candidates loaded from the new instance
2. Test an applicant move action
3. Confirm questionnaire data populated via BICC

### 11.7 Security

1. Log in as a non-admin user
2. Verify VPD restricts `RECRUITING_REPORT_V` to authorized departments
3. Confirm `pkg_app_security.login_role_check` resolves roles from the new Fusion instance

---

## 12. Quick Reference Checklist

| Step | Action | Where |
|---|---|---|
| 1 | Replace Fusion hostname in `pkg_bicc_common.sql` | 1 file (Section 4.2), then recompile dependents |
| 2 | Recompile all dependent packages | APEX SQL Commands |
| 3 | Update APEX Web Credential `gcs_reports` | Shared Components > Web Credentials |
| 3a | Update Application Settings (`BICC_FUSION_USERNAME`/`PASSWORD`) | Shared Components > Application Settings (Section 5.2) |
| 3b | Update `pkg_bpm_tasks` URL and credentials (if moving BPM) | `bpm_tasks/pkg_bpm_tasks.sql` — `gc_base_url`, `gc_credential`, `gc_user_credential` |
| 4 | Update APEX REST Data Source remote servers | Shared Components > REST Data Sources (19 sources) |
| 5 | Import BICC offering artifacts from source ZIP | Fusion BICC console (Section 6.1) |
| 6 | Create BICC External Storage profile | Fusion BICC console |
| 7 | Deploy BIP reports to new Fusion catalog | Fusion BI Publisher |
| 8 | Provision integration user with roles | Fusion Security Console |
| 8a | Purge old BICC files from OCI Object Storage | PL/SQL loop (Section 7a.1) |
| 8b | Truncate `bicc_files` tracking table | `TRUNCATE TABLE bicc_files` (Section 7a.2) |
| 9 | Re-extract routing phases/states | BICC extract from new instance |
| 10 | Update ENVIRONMENT_NAME in email_config | SQL UPDATE |
| 11 | Run initial data sync | `pkg_rest_sync.sync_all` + `refresh_all` calls |
| 12 | Run validation tests | Section 11 checklist |

---

## 13. Known Considerations

### GL Segment Value Set Names
The 9 GL segment REST data sources reference Greenville-specific Value Set names (e.g., `GCS_GL_ACCOUNT`, `GCS_GL_FUND`). If the target environment uses different names, the REST Data Source URLs must be updated.

### Date-Effective Reconciliation Drift
HCM tables (`PER_ALL_PEOPLE_F`, `PER_ALL_ASSIGNMENTS_M`) will show 50%+ drift in reconciliation because BIP `COUNT(*)` includes all history rows while BICC extracts current-effective records only. This is expected, not an error.

### APEX Page Deep-Links
Page 24 contains hardcoded URLs that open requisitions directly in the Fusion UI. These will silently point to the old instance if not updated (see Section 4.3).

### Scheduler Jobs
No scheduler job changes are needed — the jobs call PL/SQL packages, and the packages read the updated constants. However, verify jobs are still enabled after migration:

```sql
SELECT job_name, state, next_run_date
FROM user_scheduler_jobs
WHERE job_name LIKE 'JOB_%';
```
