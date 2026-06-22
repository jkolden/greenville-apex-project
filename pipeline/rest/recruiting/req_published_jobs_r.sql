-- =============================================================================
-- REQ_PUBLISHED_JOBS_R
-- Published job postings (child of recruitingJobRequisitions via ?expand=publishedJobs)
-- One row per posting per requisition (internal, external, etc.)
-- =============================================================================

create table req_published_jobs_r (
    requisition_id          number          not null,
    published_visibility    varchar2(60),
    published_posting_status varchar2(60),
    published_start_date    timestamp,
    published_end_date      timestamp,
    published_time_zone     varchar2(60),
    published_created_by    varchar2(240),
    refreshed_ts            timestamp(6)    default systimestamp,
    constraint req_published_jobs_r_pk
        primary key (requisition_id, published_visibility)
);

comment on table req_published_jobs_r is
    'Published job postings from Fusion recruitingJobRequisitions?expand=publishedJobs';
