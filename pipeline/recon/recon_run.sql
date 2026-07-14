-- =============================================================================
-- TABLE: RECON_RUN
-- =============================================================================
-- Header record for each reconciliation execution.
-- Created by pkg_recon.run_recon, updated with summary counts on completion.
-- =============================================================================

CREATE TABLE recon_run (
    run_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    started_ts    TIMESTAMP(6) DEFAULT SYSTIMESTAMP NOT NULL,
    completed_ts  TIMESTAMP(6),
    total_sources NUMBER,
    sources_ok    NUMBER,
    sources_variance NUMBER,
    sources_error NUMBER
);

COMMENT ON TABLE  recon_run IS 'Reconciliation run header — one row per execution';
