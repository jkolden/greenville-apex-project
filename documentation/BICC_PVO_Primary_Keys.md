# BICC PVO Primary Keys Reference

Oracle documents primary keys for each BICC PVO (Persistent View Object) in their "Extract Data Stores" guides. This reference maps each PVO we extract to its Oracle-documented PK, our pipeline's PK, and whether they match.

> **Important:** Oracle does NOT publish Extract Data Stores documentation for HCM PVOs. The HCM PKs listed here are assumed based on the underlying Fusion tables. To verify, pull the lineage files from [MOS Doc 2626555.1](https://support.oracle.com/knowledge/Oracle%20Cloud/2626555_1.html) or run a `PRIMARY_KEY_EXTRACT` via BICC.

## Financials

| PVO | Data Store Key | Oracle Documented PK | Our PK | Match | Doc Link |
|-----|---------------|---------------------|--------|-------|----------|
| InvoiceHeaderExtractPVO | FscmTopModelAM.FinExtractAM.ApBiccExtractAM | ApInvoicesInvoiceId | INVOICEID | Yes | [Link](https://docs.oracle.com/en/cloud/saas/financials/26b/oadsr/InvoiceHeaderExtractPVO.html) |
| DisbursementHeaderExtractPVO | FscmTopModelAM.FinExtractAM.ApBiccExtractAM | ApChecksAllCheckId | CHECK_ID | Yes | [Link](https://docs.oracle.com/en/cloud/saas/financials/26b/oadsr/DisbursementHeaderExtractPVO.html) |
| PaidDisbursementScheduleExtractPVO | FscmTopModelAM.FinExtractAM.ApBiccExtractAM | ApInvoicePaymentsAllInvoicePaymentId | INVOICE_PAYMENT_ID | Yes | [Link](https://docs.oracle.com/en/cloud/saas/financials/26b/oadsr/PaidDisbursementScheduleExtractPVO.html) |
| TransactionHeaderExtractPVO | FscmTopModelAM.FinExtractAM.ArBiccExtractAM | TransactionHeaderTransactionHeaderId | — (REST only) | — | [Link](https://docs.oracle.com/en/cloud/saas/financials/26b/oadsr/TransactionHeaderExtractPVO.html) |
| CodeCombinationExtractPVO | FscmTopModelAM.FinExtractAM.GlBiccExtractAM | CodeCombinationCodeCombinationId | CODE_COMBINATION_ID | Yes | [Link](https://docs.oracle.com/en/cloud/saas/financials/26b/oadsr/CodeCombinationExtractPVO.html) |
| JournalBatchExtractPVO | FscmTopModelAM.FinExtractAM.GlBiccExtractAM | JournalBatchJeBatchId | JOURNALBATCHJEBATCHID | Yes | [Link](https://docs.oracle.com/en/cloud/saas/financials/26b/oadsr/JournalBatchExtractPVO.html) |
| JournalHeaderExtractPVO | FscmTopModelAM.FinExtractAM.GlBiccExtractAM | JeHeaderId | JEHEADERID | Yes | [Link](https://docs.oracle.com/en/cloud/saas/financials/26b/oadsr/JournalHeaderExtractPVO.html) |
| JournalLineExtractPVO | FscmTopModelAM.FinExtractAM.GlBiccExtractAM | JeHeaderId, JeLineNum | JEHEADERID, JELINENUM | Yes | [Link](https://docs.oracle.com/en/cloud/saas/financials/26b/oadsr/JournalLineExtractPVO.html) |
| **BalanceExtractPVO (GL)** | FscmTopModelAM.FinExtractAM.GlBiccExtractAM | LedgerId, CodeCombinationId, CurrencyCode, ActualFlag, PeriodName, **TranslatedFlag**, **EncumbranceTypeId** | LedgerId, CodeCombinationId, CurrencyCode, ActualFlag, PeriodName | **NO** | [Link](https://docs.oracle.com/en/cloud/saas/financials/24a/oadsr/BalanceExtractPVO.html) |
| **BudgetBalanceExtractPVO** | FscmTopModelAM.FinExtractAM.GlBiccExtractAM | BudgetName, ConcatAccount, CurrencyCode, PeriodName, **CurrencyType**, LedgerId | LedgerId, BudgetName, CurrencyCode, PeriodName, SegmentString | **NO** | [Link](https://docs.oracle.com/en/cloud/saas/financials/26b/oadsr/BudgetBalanceExtractPVO.html) |

### GL Balance PK Mismatch

Oracle's documented PK for BalanceExtractPVO has **7 columns**. Our pipeline uses 5, missing:
- `TranslatedFlag` — distinguishes functional vs translated currency balances
- `EncumbranceTypeId` — distinguishes encumbrance types (nullable, but part of Oracle's PK)

If the extract contains rows that only differ on these two columns, the ROW_NUMBER dedup silently picks one and drops the other.

### Budget Balance PK Mismatch

Oracle's documented PK includes `CurrencyType`. Our pipeline uses `SegmentString` (computed from LPAD segments) instead of `ConcatAccount`, which may be equivalent. Missing `CurrencyType` could collapse rows with different currency types (e.g., Total vs Entered).

## Procurement

| PVO | Data Store Key | Oracle Documented PK | Our PK | Match | Doc Link |
|-----|---------------|---------------------|--------|-------|----------|
| PurchasingDocumentHeaderExtractPVO | FscmTopModelAM.PrcExtractAM.PoBiccExtractAM | PoHeaderId | POHEADERID | Yes | [Link](https://docs.oracle.com/en/cloud/saas/procurement/26c/oadpr/PurchasingDocumentHeaderExtractPVO.html) |
| PurchasingDocumentLineExtractPVO | FscmTopModelAM.PrcExtractAM.PoBiccExtractAM | PoLineId | POLINEID | Yes | [Link](https://docs.oracle.com/en/cloud/saas/procurement/26c/oadpr/PurchasingDocumentLineExtractPVO.html) |
| SupplierExtractPVO | FscmTopModelAM.PrcExtractAM.PozBiccExtractAM | VendorId | VENDORID | Yes | [Link](https://docs.oracle.com/en/cloud/saas/procurement/26c/oadpr/SupplierExtractPVO.html) |
| SupplierSiteExtractPVO | FscmTopModelAM.PrcExtractAM.PozBiccExtractAM | VendorSiteId | — (not loaded) | — | [Link](https://docs.oracle.com/en/cloud/saas/procurement/26c/oadpr/SupplierSiteExtractPVO.html) |

## HCM (Not Documented by Oracle)

Oracle does not publish "Extract Data Stores" pages for HCM PVOs. These PKs are assumed based on the underlying Fusion table PKs and have not been verified against Oracle's lineage files.

| PVO | Data Store Key | Assumed PK | Our PK | Verified? |
|-----|---------------|-----------|--------|-----------|
| GlobalPersonPVOViewAll | HcmTopModelAnalyticsGlobalAM.PersonAM | PersonId (+ AssignmentId?) | PERSON_ID | No |
| AssignmentPVO | HcmTopModelAnalyticsGlobalAM.AssignmentAM | AssignmentId | ASSIGNMENT_ID | No |
| SalaryExtractPVO | HcmTopModelAnalyticsGlobalAM.HCMExtractAM.HcmCompBiccExtractAM | SalaryId | SALARY_ID | No |
| PositionPVOViewAll | HcmTopModelAnalyticsGlobalAM.PositionAM | PositionId | POSITION_ID | No |
| FLEX_BI_PositionCustomerFlex_VI | HcmTopModelAnalyticsGlobalAM.PositionCustomerFlexBIAM | S_K_5000 (POS_DFF_ID) | POS_DFF_ID | No |
| ParticipantQuestionnaireQuestionPVO | HcmTopModelAnalyticsGlobalAM.QuestionnaireAM | QstnrParticipantId + QstnrQuestionId | QSTNR_PARTICIPANT_ID, QSTNR_QUESTION_ID | No |
| QuestionnaireQuestionResponsePVO | HcmTopModelAnalyticsGlobalAM.QuestionnaireAM | QstnResponseId | QSTN_RESPONSE_ID | No |
| QuestionAnswerPVO | HcmTopModelAnalyticsGlobalAM.QuestionnaireLibraryAM | QstnAnswerId | QSTN_ANSWER_ID | No |

### GlobalPersonPVO Note

The GlobalPersonPVOViewAll extract is denormalized — it delivers one row per person **per assignment**. Our pipeline filters to `primary_assignment_flag = 'Y'` and `effective_latest_change_flag = 'Y'`, then applies ROW_NUMBER to keep one row per PERSON_ID. This is intentional business logic (we want one row per person), not dedup of true duplicates. The actual extract-level PK likely includes AssignmentId.

## How to Verify

1. **MOS Doc 2626555.1** — Contains BICC lineage files mapping each PVO to its source tables and PK columns
2. **PRIMARY_KEY_EXTRACT** — Run via `pkg_bicc_trigger` with `EXTRACT_JOB_TYPE => 'PRIMARY_KEY_EXTRACT'` to get just the PK columns from an extract
3. **Known duplicate bug** — [MOS Doc 2656399.1](https://support.oracle.com/knowledge/Oracle%20Cloud/2656399_1.html) documents PVOs that produce true duplicate rows (e.g., ExpenditureItemPVO)

## Action Items

- [ ] Verify GL Balance: query landing table for rows that share the 5-column PK but differ on TranslatedFlag or EncumbranceTypeId
- [ ] Verify Budget Balance: query landing table for rows that share our PK but differ on CurrencyType
- [ ] Pull HCM lineage files from MOS 2626555.1 to confirm HCM PKs
- [ ] Run PRIMARY_KEY_EXTRACT for at least one HCM entity to validate
