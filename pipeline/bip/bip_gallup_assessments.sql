-- =============================================================
-- BIP_GALLUP_ASSESSMENTS
-- Gallup assessment scores from BIP report "Gallup_XML"
-- Source: irc_asmt_package_results joined to irc_submissions
-- Loaded by: pkg_bip_soap.load_gallup_assessments
-- =============================================================

create table bip_gallup_assessments (
    submission_id          number         not null,
    package_status_code    varchar2(80),
    band                   varchar2(400),
    score                  number,
    requisition_id         number,
    requisition_title      varchar2(400),
    person_id              number,
    candidate_name         varchar2(400),
    gallup_result_url      varchar2(4000),
    load_ts                timestamp(6) with time zone default systimestamp not null,
    --
    constraint bip_gallup_assessments_pk
        primary key (submission_id)
);

create index bip_gallup_assessments_n1
    on bip_gallup_assessments (requisition_id);

create index bip_gallup_assessments_n2
    on bip_gallup_assessments (person_id);
