-- =============================================================================
-- APEX Page 9003: "BIP Load History" tab
-- =============================================================================
-- Add as a new sub-region (tab) under the "tabs" parent region on page 9003.
-- Display sequence: 75 (between REST Manual Trigger at 60 and Reconciliation at 70,
--                       or adjust to wherever you want it in the tab order)
-- Template: Interactive Report
-- Region Name: bip_load_history  (static ID for JS refresh)
-- =============================================================================

-- IR Source Query:
SELECT
    l.log_id,
    l.report_key,
    CASE l.report_key
        WHEN 'GALLUP'         THEN 'Gallup Assessments'
        WHEN 'QUESTIONNAIRES' THEN 'Questionnaires'
        WHEN 'DFF'            THEN 'DFF Configuration'
        WHEN 'EXT_FLEX'       THEN 'Extensible Flex'
        ELSE INITCAP(REPLACE(l.report_key, '_', ' '))
    END AS report_label,
    l.status,
    l.source_rows,
    l.rows_merged,
    l.triggered_by,
    l.started_ts,
    l.completed_ts,
    CASE
        WHEN l.completed_ts IS NOT NULL
        THEN ROUND(
            EXTRACT(SECOND FROM (l.completed_ts - l.started_ts))
            + EXTRACT(MINUTE FROM (l.completed_ts - l.started_ts)) * 60,
            1
        )
    END AS elapsed_secs,
    l.error_message,
    l.report_path
FROM bip_load_log l
ORDER BY l.started_ts DESC;

-- =============================================================================
-- Column settings:
--   LOG_ID         - Hidden
--   REPORT_KEY     - Hidden
--   REPORT_LABEL   - Label "Report", width 180
--   STATUS         - Label "Status", width 80
--                    Highlight rule: green for SUCCESS, red for ERROR, blue for RUNNING
--   SOURCE_ROWS    - Label "Source Rows", format 999,999,999
--   ROWS_MERGED    - Label "Rows Merged", format 999,999,999
--   TRIGGERED_BY   - Label "Triggered By", width 80
--   STARTED_TS     - Label "Started", format DD-MON-YYYY HH24:MI:SS
--   COMPLETED_TS   - Label "Completed", format DD-MON-YYYY HH24:MI:SS
--   ELAPSED_SECS   - Label "Elapsed (s)", format 999.9
--   ERROR_MESSAGE  - Label "Error", display as tooltip or hidden by default
--   REPORT_PATH    - Hidden
-- =============================================================================

-- Optional: after adding the tab, refresh it when a BIP load completes.
-- In the existing BIP Manual Trigger Ajax callback success handler, add:
--
--   if (apex.region("bip_load_history")) {
--       apex.region("bip_load_history").refresh();
--   }
-- =============================================================================
