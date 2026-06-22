-- EFF decoding view: GCS Job Application References
-- INFORMATION_TYPE filter: verify with  select distinct information_type from ext_flex_stg
-- Context maps PEI_INFO1-6 to three reference contacts (name + email each)
create or replace view ext_flex_job_refs_v as
select
    person_extra_info_id,
    person_id,
    candidate_number,
    information_type,
    effective_start_date,
    effective_end_date,
    pei_info1  as reference_1_name,
    pei_info2  as reference_1_email,
    pei_info3  as reference_2_name,
    pei_info4  as reference_2_email,
    pei_info5  as reference_3_name,
    pei_info6  as reference_3_email,
    load_ts
  from ext_flex_stg
 where information_type = 'GCS Job Application References'
/
