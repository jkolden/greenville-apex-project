create or replace package pkg_rest_recruiting as
-- =============================================================================
-- Consolidated REST loaders for Oracle Fusion recruiting APIs.
-- Handles entities that need ?expand for nested child resources,
-- replacing APEX declarative sync + separate child loaders.
--
-- load_requisitions : parent + DFF + published jobs in one pass
-- load_candidates   : parent + phones in one pass
-- =============================================================================

    -- Fusion REST API credential and base URL
    gc_fa_credential constant varchar2(60)  := '<FUSION_CREDENTIAL>';
    gc_fa_base_url   constant varchar2(200) := 'https://<FUSION_HOST_DEV>';

    -- Consolidated requisition loader (expand=requisitionDFF,publishedJobs)
    -- MERGEs into JOB_REQUISITIONS_R + REQ_DFF_R + REQ_PUBLISHED_JOBS_R
    procedure load_requisitions;

    -- Consolidated candidate + phone loader (expand=candidatePhones)
    -- MERGEs into RECRUITING_CANDIDATES_R + CANDIDATE_PHONES_R
    procedure load_candidates;

    -- Refresh all
    procedure refresh_all;

end pkg_rest_recruiting;
/
