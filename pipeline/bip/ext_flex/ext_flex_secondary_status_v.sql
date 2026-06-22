-- EFF decoding view: Secondary Status
-- INFORMATION_TYPE filter: verify with  select distinct information_type from ext_flex_stg
-- Context: PEI_INFO1 = Secondary Status, PEI_INFO2 = Comments,
--          PEI_DATE1 = Begin Date, PEI_DATE2 = End Date
create or replace view ext_flex_secondary_status_v as
select
    person_extra_info_id,
    person_id,
    candidate_number,
    information_type,
    effective_start_date,
    effective_end_date,
    pei_info1  as secondary_status,
    pei_info2  as secondary_status_comments,
    pei_date1  as secondary_status_begin_date,
    pei_date2  as secondary_status_end_date,
    load_ts
  from ext_flex_stg
 where information_type = 'Secondary Status'
/
