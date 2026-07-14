-- =============================================================================
-- TABLE: RECON_RESULT
-- =============================================================================
-- Per-entity results within a reconciliation run.
-- Stores local count, Fusion count, delta, and status for each source.
-- =============================================================================

CREATE TABLE recon_result (
    result_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id         NUMBER         NOT NULL REFERENCES recon_run(run_id),
    entity_name    VARCHAR2(100)  NOT NULL,
    source_type    VARCHAR2(20),
    local_table_name VARCHAR2(128),
    fusion_source  VARCHAR2(500),
    local_count    NUMBER,
    fusion_count   NUMBER,
    delta          NUMBER,
    pct_delta      NUMBER(7,2),
    status         VARCHAR2(20)   NOT NULL
                   CHECK (status IN ('OK','VARIANCE','ERROR')),
    error_message  VARCHAR2(4000),
    checked_ts     TIMESTAMP(6)   DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE INDEX recon_result_run_n1 ON recon_result (run_id);

COMMENT ON TABLE  recon_result IS 'Per-entity reconciliation results — local vs Fusion counts';
COMMENT ON COLUMN recon_result.delta     IS 'fusion_count - local_count (positive = Fusion has more)';
COMMENT ON COLUMN recon_result.pct_delta IS 'delta / NULLIF(fusion_count,0) * 100';
COMMENT ON COLUMN recon_result.status    IS 'OK = counts match; VARIANCE = mismatch; ERROR = could not compare';
COMMENT ON COLUMN recon_result.local_table_name IS 'Local table counted (e.g. REST_JOB_APPLICANTS, FBX_HCM_EMPLOYEE)';
COMMENT ON COLUMN recon_result.fusion_source    IS 'Fusion count source: REST URL path or BIP entity key';
