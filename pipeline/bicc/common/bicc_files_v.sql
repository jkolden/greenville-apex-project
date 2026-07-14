
  CREATE OR REPLACE FORCE EDITIONABLE VIEW "BICC_FILES_V" ("FILE_NAME", "LOAD_TYPE") AS 
  with o as (
  select regexp_substr(object_name, '[^/]+$') as file_name
  from table(
    dbms_cloud.list_objects(
      credential_name => 'OBJ_STORE_CRED_JK',
      location_uri    => 'https://objectstorage.us-ashburn-1.oraclecloud.com/n/idlhcuqzdx2c/b/SCI_Conversion/o/'
    )
  )
  where lower(object_name) like '%.zip'
)
select
  o.file_name,
  coalesce(m.load_type, 'UNMAPPED') as load_type
from o
outer apply (
  select m1.load_type
  from bicc_loader_map m1
  where m1.is_active = 'Y'
    and m1.load_type is not null
    and m1.file_like is not null
    and lower(o.file_name) like lower(m1.file_like)
  order by m1.priority
  fetch first 1 row only
) m;