-- =============================================================================
-- TABLE: REQ_DFF_R
-- =============================================================================
-- Requisition-level Descriptive Flexfields loaded from REST child resource:
--   /recruitingJobRequisitions/{id}/child/requisitionDFF
-- Refreshed by PKG_REST_RECRUITING.LOAD_REQUISITION_DFFS
-- =============================================================================

CREATE TABLE REQ_DFF_R (
    REQUISITION_ID         NUMBER          PRIMARY KEY,
    TRANSFER_COORDINATED   VARCHAR2(10),
    VACANCY_TERM_SUBMITTED VARCHAR2(10),
    FLEX_CONTEXT           VARCHAR2(240),
    REFRESHED_TS           TIMESTAMP(6)
);
