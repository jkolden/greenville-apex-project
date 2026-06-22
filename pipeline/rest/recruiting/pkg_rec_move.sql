CREATE OR REPLACE PACKAGE pkg_rec_move AS
-- =============================================================================
-- Package to move job applications between recruiting phases/states
-- via Oracle Fusion REST API.
--
-- Endpoint: POST /hcmRestApi/resources/11.13.18.05/recruitingJobApplications
--               /{JobApplicationId}/action/move
-- Payload:  {"phaseId": <n>, "stateId": <n>, "comments": "..."}
--
-- Uses same credential as pkg_rest_recruiting / pkg_bicc_dimensions.
-- =============================================================================

    gc_fa_credential CONSTANT VARCHAR2(60)  := '<FUSION_CREDENTIAL>';
    gc_fa_base_url   CONSTANT VARCHAR2(200) := 'https://<FUSION_HOST_DEV>';

    -- Move a single applicant to a new phase/state.
    -- Returns the raw JSON response from Fusion.
    FUNCTION move_application (
        p_job_application_id  IN NUMBER,
        p_phase_id            IN NUMBER,
        p_state_id            IN NUMBER,
        p_comments            IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

END pkg_rec_move;
/
