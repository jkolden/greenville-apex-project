-- =============================================================================
-- CANDIDATE_PHONES_R
-- Candidate phone numbers (child of recruitingCandidates via ?expand=candidatePhones)
-- One row per phone per candidate (MOBILE, HOME, WORK, etc.)
-- Loaded by pkg_rest_recruiting.load_candidates
-- =============================================================================

create table candidate_phones_r (
    phone_id                number          not null,
    person_id               number          not null,
    phone_type              varchar2(30),
    country_code_number     varchar2(10),
    area_code               varchar2(30),
    phone_number            varchar2(60),
    extension               varchar2(30),
    legislation_code        varchar2(10),
    primary_flag            varchar2(1),
    created_by              varchar2(240),
    creation_date           timestamp,
    last_updated_by         varchar2(240),
    last_update_date        timestamp,
    refreshed_ts            timestamp(6)    default systimestamp,
    constraint candidate_phones_r_pk
        primary key (phone_id)
);

create index candidate_phones_r_n1 on candidate_phones_r (person_id);

comment on table candidate_phones_r is
    'Candidate phone numbers from Fusion recruitingCandidates?expand=candidatePhones';
