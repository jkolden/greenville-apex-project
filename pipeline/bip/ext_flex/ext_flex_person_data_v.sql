-- EFF decoding view: Additional GCS Person Data
-- All column assignments confirmed from Manage Extensible Flexfields UI (PER_PERSON_EIT_EFF):
-- Char columns:
--   PEI_INFORMATION1  = Teacher Subject Area       (seq 20)
--   PEI_INFORMATION2  = SmartFind Class Code       (seq 30)
--   PEI_INFORMATION3  = Banked Vacation            (seq 60)
--   PEI_INFORMATION4  = Contract Type              (seq 70)
--   PEI_INFORMATION5  = Contract Stipulation 1     (seq 80)
--   PEI_INFORMATION6  = Contract Stipulation 2     (seq 90)
--   PEI_INFORMATION7  = Contract Stipulation 3     (seq 100)
--   PEI_INFORMATION8  = Vacation Carryover Ext Y/N (seq 65)
--   PEI_INFORMATION9  = Rehire Eligible            (seq 9)
--   PEI_INFORMATION10 = Processing Owner           (seq 35)
--   PEI_INFORMATION11 = Work Keys                  (seq 8)
--   PEI_INFORMATION12 = Reference Check            (seq 7)
--   PEI_INFORMATION13 = SLED                       (seq 6)
--   PEI_INFORMATION14 = Certification              (seq 5)
--   PEI_INFORMATION15 = Additional FTE             (seq 110)
--   PEI_INFORMATION16 = Interview Notes            (seq 3)
-- Date columns:
--   PEI_INFORMATION_DATE1 = Effective Date         (seq 22)
-- Number columns:
--   PEI_INFORMATION_NUMBER1 = Teacher Years of Experience (seq 10)
--   PEI_INFORMATION_NUMBER2 = CATE Experience             (seq 40)
--   PEI_INFORMATION_NUMBER3 = Personal Leave Used         (seq 50)
--   PEI_INFORMATION_NUMBER4 = FTE                         (seq 25)
--   PEI_INFORMATION_NUMBER5 = Educator ID                 (seq 21)
--   PEI_INFORMATION_NUMBER6 = Teacher Assessment Score    (seq 4)
create or replace view ext_flex_person_data_v as
select
    person_extra_info_id,
    person_id,
    candidate_number,
    information_type,
    effective_start_date,
    effective_end_date,
    -- Character columns
    pei_info1   as teacher_subject_area,          -- PEI_INFORMATION1  seq 20
    pei_info2   as smartfind_class_code,          -- PEI_INFORMATION2  seq 30
    pei_info3   as banked_vacation,               -- PEI_INFORMATION3  seq 60
    pei_info4   as contract_type,                 -- PEI_INFORMATION4  seq 70
    pei_info5   as contract_stipulation_1,        -- PEI_INFORMATION5  seq 80
    pei_info6   as contract_stipulation_2,        -- PEI_INFORMATION6  seq 90
    pei_info7   as contract_stipulation_3,        -- PEI_INFORMATION7  seq 100
    pei_info8   as vacation_carryover_extension,  -- PEI_INFORMATION8  seq 65
    pei_info9   as rehire_eligible,               -- PEI_INFORMATION9  seq 9
    pei_info10  as processing_owner,              -- PEI_INFORMATION10 seq 35
    pei_info11  as work_keys,                     -- PEI_INFORMATION11 seq 8
    pei_info12  as reference_check,               -- PEI_INFORMATION12 seq 7
    pei_info13  as sled,                          -- PEI_INFORMATION13 seq 6
    pei_info14  as certification,                 -- PEI_INFORMATION14 seq 5
    pei_info15  as additional_fte,                -- PEI_INFORMATION15 seq 110
    pei_info16  as interview_notes,               -- PEI_INFORMATION16 seq 3
    -- Date column
    pei_date1   as gcs_effective_date,            -- PEI_INFORMATION_DATE1 seq 22
    -- Number columns
    pei_num1    as teacher_years_of_experience,   -- PEI_INFORMATION_NUMBER1 seq 10
    pei_num2    as cate_experience,               -- PEI_INFORMATION_NUMBER2 seq 40
    pei_num3    as personal_leave_used,           -- PEI_INFORMATION_NUMBER3 seq 50
    pei_num4    as fte,                           -- PEI_INFORMATION_NUMBER4 seq 25
    pei_num5    as educator_id,                   -- PEI_INFORMATION_NUMBER5 seq 21
    pei_num6    as teacher_assessment_score,      -- PEI_INFORMATION_NUMBER6 seq 4
    load_ts
  from ext_flex_stg
 where information_type = 'Additional GCS Person Data'
/
