-- =============================================================================
-- TABLE: BIP_LOAD_LOG
-- =============================================================================
-- One row per BIP report execution.  Tracks when each report was run, how many
-- rows came back from Fusion, how many were merged into the local table, and
-- whether the load succeeded or failed.
--
-- Logging uses PRAGMA AUTONOMOUS_TRANSACTION inside pkg_bip_soap so the row
-- persists even when the calling transaction rolls back on error.
-- =============================================================================

CREATE TABLE bip_load_log (
    log_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    report_key      VARCHAR2(80)   NOT NULL,   -- e.g. GALLUP, QUESTIONNAIRES, DFF, EXT_FLEX
    report_path     VARCHAR2(4000),            -- full XDO path sent to BIP
    status          VARCHAR2(20)   NOT NULL,   -- RUNNING, SUCCESS, ERROR
    source_rows     NUMBER,                    -- ROW count from the XML response
    rows_merged     NUMBER,                    -- SQL%ROWCOUNT after MERGE
    error_message   VARCHAR2(4000),
    started_ts      TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL,
    completed_ts    TIMESTAMP(6),
    triggered_by    VARCHAR2(100)              -- MANUAL / SCHEDULER / username
);

COMMENT ON TABLE  bip_load_log IS 'BIP report load history — one row per execution';
COMMENT ON COLUMN bip_load_log.report_key    IS 'Short identifier: GALLUP, QUESTIONNAIRES, DFF, EXT_FLEX';
COMMENT ON COLUMN bip_load_log.source_rows   IS 'Number of ROW elements in the BIP XML response';
COMMENT ON COLUMN bip_load_log.rows_merged   IS 'SQL%ROWCOUNT from the MERGE statement';
COMMENT ON COLUMN bip_load_log.triggered_by  IS 'How the load was initiated (MANUAL from APEX, SCHEDULER from DBMS_SCHEDULER)';

CREATE INDEX bip_load_log_n1 ON bip_load_log (report_key, started_ts DESC);
