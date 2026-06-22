create or replace package pkg_rec_email as
-- =============================================================================
-- POC: Recruiting Content Library / Email Template discovery and send
-- Fetches content library items from Fusion REST, probes child enclosures
-- for template text, supports token extraction + substitution + email send.
-- =============================================================================

    -- Fusion REST API credential and base URL
    gc_fa_credential constant varchar2(60)  := '<FUSION_CREDENTIAL>';
    gc_fa_base_url   constant varchar2(200) := 'https://<FUSION_HOST_DEV>';

    -- ---- Data Loading ----

    -- Load all content library items from the LOV endpoint (metadata only, fast)
    procedure load_content_items;

    -- Fetch template text (TxtDescription + HtmlDescription) for items.
    -- NULL = all items; pass an ID to fetch a single item.
    procedure load_content_text(p_item_description_id in number default null);

    -- ---- Token Discovery ----

    -- Scan all loaded templates and populate rec_email_token with unique tokens
    procedure discover_tokens;

    -- Extract ${...} token names from template text (deduplicated, in order)
    function extract_tokens(p_template in clob) return apex_t_varchar2;

    -- ---- Substitution & Email ----

    -- Replace ${TokenName} placeholders with supplied values
    function substitute(
        p_template     in clob,
        p_token_names  in apex_t_varchar2,
        p_token_values in apex_t_varchar2
    ) return clob;

    -- Preview: return substituted template text without sending
    function preview_email(
        p_item_description_id in number,
        p_token_names         in apex_t_varchar2 default apex_t_varchar2(),
        p_token_values        in apex_t_varchar2 default apex_t_varchar2()
    ) return clob;

    -- Auto-resolve tokens from database context + return substituted text
    function resolve_tokens(
        p_item_description_id in number,
        p_requisition_id      in number   default null,
        p_candidate_name      in varchar2 default null,
        p_site_name           in varchar2 default 'Greenville County Schools'
    ) return clob;

    -- Send email using a content library template with token substitution
    procedure send_email(
        p_to                  in varchar2,
        p_from                in varchar2 default 'noreply@greenville.k12.sc.us',
        p_subject             in varchar2,
        p_item_description_id in number,
        p_token_names         in apex_t_varchar2 default apex_t_varchar2(),
        p_token_values        in apex_t_varchar2 default apex_t_varchar2()
    );

    -- Send email using resolve_tokens (simpler — pass context, not token arrays)
    procedure send_email_resolved(
        p_to                  in varchar2,
        p_from                in varchar2 default 'noreply@greenville.k12.sc.us',
        p_subject             in varchar2,
        p_item_description_id in number,
        p_requisition_id      in number   default null,
        p_candidate_name      in varchar2 default null,
        p_site_name           in varchar2 default 'Greenville County Schools'
    );

end pkg_rec_email;
/
