create or replace package pkg_bicc_ap_inv_application as
    function load_and_preview(p_file_name in varchar2) return number;
    procedure merge(p_job_id in number);
end pkg_bicc_ap_inv_application;
/
