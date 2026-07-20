# Greenville APEX Project

Oracle Fusion Cloud BICC data integration pipeline using Oracle Autonomous Database (ATP) and Oracle APEX.

## Architecture

Data flows through a three-tier pipeline from Oracle Fusion BICC extracts into reporting tables:

```
BICC ZIP (Object Storage)
    → extract_and_stage_csv  (pkg_bicc_common)
    → L_<ENTITY>_BC          Landing table  (all VARCHAR2(4000), raw CSV)
    → S_<ENTITY>_BC          Staging table  (typed columns, JOB_ID batch tracking)
    → <ENTITY>_BC            Final table    (PK enforced, published data)
```

## Table Naming

| Prefix | Type | Example |
|--------|------|---------|
| `L_*_BC` | Landing | `L_HCM_EMPLOYEE_BC` |
| `EXT_*_BC` | External table | `EXT_HCM_EMPLOYEE_BC` |
| `S_*_BC` | Staging | `S_HCM_EMPLOYEE_BC` |
| `*_BC` | Final | `HCM_EMPLOYEE_BC` |

## Repository Structure

```
pipeline/bicc/
├── common/                  Shared infrastructure
│   ├── pkg_bicc_common      Core package (extract, safe_to_number, safe_to_timestamp)
│   ├── bicc_files           File tracking table + view
│   └── bicc_loader_map_*    Entity-to-loader mapping
│
└── entities/
    ├── hcm/                 HCM: employee, assignment, position, salary
    ├── finance/             GL (balance, budget_balance, code_comb, journal_batch/header/lines)
    │                        AP (invoice_hdr, disbursement, inv_application)
    │                        PO (hdr, lines), AR (invoices), supplier_hdr
    └── recruiting/          Questionnaire (answer, question, response), pos_custom_flex
```

Each entity folder contains:
- `l_<entity>_bc.sql` — Landing table DDL + external table setup
- `s_<entity>_bc.sql` — Staging table DDL + indexes
- `<entity>_bc.sql` — Final table DDL + indexes
- `pkg_bicc_<entity>.sql` — Package spec
- `pkg_bicc_<entity>.plb` — Package body

## Documentation

- [Environment Migration Guide](documentation/Environment_Migration_Guide.md) — Step-by-step instructions for repointing the platform from one Fusion instance to another (DEV → TEST → PROD)
- [BICC PVO Primary Keys](documentation/BICC_PVO_Primary_Keys.md) — Oracle-documented primary keys for each BICC extract PVO, compared against our pipeline's assumed PKs

## Setup

The Fusion hostname is centralized in `pkg_bicc_common.sql` (`gc_fa_base_url`). Change it once and recompile dependent packages. See the [Migration Guide](documentation/Environment_Migration_Guide.md) for the full checklist.

Other placeholders to review:

| Placeholder | Description |
|-------------|-------------|
| `<FUSION_HOST_TEST>` | Oracle Fusion test instance hostname (in `pkg_rec_email`, `pkg_app_security`) |
| `<APEX_WORKSPACE>` | APEX workspace name |
| `pkg_bicc_common.gc_credential` | OCI Object Storage credential name |
| `pkg_bicc_common.gc_bucket_uri` | OCI Object Storage bucket URI |

