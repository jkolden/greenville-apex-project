-- EFF decoding view: GCS Retirement
-- INFORMATION_TYPE filter: verify with  select distinct information_type from ext_flex_stg
-- Context: PEI_INFO1 = Working Retiree (Y/N), PEI_DATE1 = SC Retirement Date
create or replace view ext_flex_retirement_v as
select
    person_extra_info_id,
    person_id,
    candidate_number,
    information_type,
    effective_start_date,
    effective_end_date,
    pei_info1  as working_retiree,
    pei_date1  as sc_retirement_date,
    load_ts
  from ext_flex_stg
 where information_type = 'GCS Retirement'
/
