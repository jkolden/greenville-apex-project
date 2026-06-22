create or replace package pkg_bip_soap as

    function run_report_xml (
        p_report_name   in varchar2 default 'Extensible_Flex.xdo',
        p_parameter_xml in clob     default null
    ) return xmltype;

    procedure load_extensible_flex (
        p_report_name   in varchar2 default 'Extensible_Flex.xdo',
        p_parameter_xml in clob     default null
    );

    procedure load_bip_dff (
        p_report_name   in varchar2 default '/Custom/SCI/BIP/DFF_XML.xdo',
        p_parameter_xml in clob     default null
    );

    procedure load_bip_questionnaires (
        p_report_name   in varchar2 default '/Custom/SCI/BIP/Questionnaires.xdo',
        p_parameter_xml in clob     default null,
        p_days_back     in number   default 30
    );

    procedure load_gallup_assessments (
        p_report_name   in varchar2 default '/Custom/SCI/BIP/Gallup_XML.xdo',
        p_parameter_xml in clob     default null
    );

    procedure load_fa_user_accounts (
        p_report_name   in varchar2 default '/Custom/SCI/BIP/User Account_XML.xdo',
        p_parameter_xml in clob     default null
    );

    procedure load_fa_user_roles (
        p_report_name   in varchar2 default '/Custom/SCI/BIP/user_roles_XML.xdo',
        p_parameter_xml in clob     default null
    );

end pkg_bip_soap;
/
