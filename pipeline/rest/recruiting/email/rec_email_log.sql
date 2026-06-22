-- =============================================================================
-- rec_email_log — Records each email sent from the Recruiting Email POC
-- =============================================================================

create table rec_email_log (
    log_id              number generated always as identity primary key,
    template_id         number,              -- rec_content_library.item_description_id
    template_name       varchar2(1000),       -- denormalized for easy reporting
    requisition_id      number,
    requisition_title   varchar2(500),
    to_email            varchar2(400)  not null,
    subject             varchar2(400),
    email_body          clob,
    sent_by             varchar2(255)  default sys_context('APEX$SESSION','APP_USER'),
    sent_ts             timestamp(6)   default systimestamp not null
);

comment on table  rec_email_log               is 'Log of emails sent from the Recruiting Email POC (app 146)';
comment on column rec_email_log.template_id   is 'FK to rec_content_library.item_description_id';
comment on column rec_email_log.sent_by       is 'APEX user who sent the email';

create index rec_email_log_n1 on rec_email_log (sent_ts desc);
