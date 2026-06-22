-- =============================================================================
-- REC_EMAIL_TOKEN — Discovered substitution tokens from content library templates
-- Populated by pkg_rec_email.discover_tokens
-- =============================================================================

create table rec_email_token (
    token_name      varchar2(200)   not null,
    display_label   varchar2(200),
    default_value   varchar2(4000),
    source_hint     varchar2(500),
    template_count  number,
    constraint rec_email_token_pk primary key (token_name)
);

comment on table  rec_email_token                    is 'Discovered substitution tokens from content library templates';
comment on column rec_email_token.token_name         is 'Token name as it appears between ${ and }';
comment on column rec_email_token.display_label      is 'Friendly label for UI display';
comment on column rec_email_token.default_value      is 'Default substitution value for preview/testing';
comment on column rec_email_token.source_hint        is 'Where the real value comes from (e.g. REST_JOB_APPLICANTS.candidatefirstname)';
comment on column rec_email_token.template_count     is 'Number of templates that reference this token';
