create or replace package eba_fa_sec_util as

 g_bip_base_folder constant varchar2(4000) := '/Custom/SCI/Security/Data Validation/XML Reports';

function run_bip_report_via_soapapi (
    p_report_path      in varchar2,              -- /Custom/.../MyReport.xdo
    p_attribute_format in varchar2 default 'xml',    -- currently expecting xml
    p_bypass_cache     in boolean  default true,
    p_flatten_xml      in boolean  default true,
    -- optional: full <pub:parameterNameValues>...</pub:parameterNameValues> block
    p_parameter_xml    in clob     default null,
    p_instance_id      in number   default v('G_INSTANCE_ID')
) return xmltype;

procedure refresh_fa_user_account (p_instance_id in number default v('G_INSTANCE_ID'));
procedure refresh_fa_role_list    (p_instance_id in number default v('G_INSTANCE_ID'));
procedure refresh_fa_inherited_role (p_instance_id in number default v('G_INSTANCE_ID'));
procedure refresh_fa_role_privileges (p_instance_id in number default v('G_INSTANCE_ID'));
procedure refresh_fa_user_role    (p_instance_id in number default v('G_INSTANCE_ID'));
procedure refresh_fa_erp_data_context (p_instance_id in number default v('G_INSTANCE_ID'));


procedure refresh_data_securities (
    p_merge_mode  in varchar2 default 'MERGE',
    p_instance_id in number   default v('G_INSTANCE_ID')
);

procedure refresh_user_positions (
    p_instance_id in number default v('G_INSTANCE_ID')
);

end;
/