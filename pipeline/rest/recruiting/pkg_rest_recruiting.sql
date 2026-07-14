create or replace package pkg_rest_recruiting as
-- =============================================================================
-- Consolidated REST loaders for Oracle Fusion recruiting APIs.
-- Handles entities that need ?expand for nested child resources,
-- replacing APEX declarative sync + separate child loaders.
--
-- load_requisitions : parent + DFF + published jobs in one pass
-- load_candidates   : parent + phones in one pass
-- =============================================================================

    -- Fusion REST API credential
    gc_fa_credential constant varchar2(60)  := 'gcs_reports';

    -- Consolidated requisition loader (expand=requisitionDFF,publishedJobs)
    -- MERGEs into JOB_REQUISITIONS_R + REQ_DFF_R + REQ_PUBLISHED_JOBS_R
    -- p_full_refresh = TRUE: loads all requisitions (default, legacy behavior)
    -- p_full_refresh = FALSE: incremental, filters by RequisitionLastModifiedDate
    procedure load_requisitions(p_full_refresh in boolean default true);

    -- Consolidated candidate + phone loader (expand=candidatePhones)
    -- MERGEs into RECRUITING_CANDIDATES_R + CANDIDATE_PHONES_R
    -- p_full_refresh = TRUE: ignores date filter, starts from beginning
    -- p_full_refresh = FALSE: incremental from max CandLastModifiedDate (default)
    procedure load_candidates(p_full_refresh in boolean default false);

    -- Refresh all
    procedure refresh_all;

end pkg_rest_recruiting;
/
