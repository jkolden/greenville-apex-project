create or replace PACKAGE BODY pkg_rest_sync AS

    gc_app_id        CONSTANT NUMBER := 121;
    gc_overlap_days  CONSTANT NUMBER := 2;
    gc_sync_step_id  CONSTANT VARCHAR2(100) := 'Synchronization Step 1';

    ---------------------------------------------------------------------------
    -- sync_source: incremental sync for one REST Data Source
    ---------------------------------------------------------------------------
    PROCEDURE sync_source (
        p_module_static_id  IN VARCHAR2,
        p_sync_step_id      IN VARCHAR2 DEFAULT 'Synchronization Step 1',
        p_date_field        IN VARCHAR2 DEFAULT 'LastUpdateDate'
    ) IS
        l_last_sync  TIMESTAMP WITH LOCAL TIME ZONE;
        l_filter     VARCHAR2(200);
    BEGIN
        -- Get timestamp of last successful sync for this source
        l_last_sync := apex_rest_source_sync.get_last_sync_timestamp(
            p_module_static_id => p_module_static_id,
            p_application_id   => gc_app_id
        );

        -- Build incremental filter; NULL = full refresh (first run)
        IF l_last_sync IS NOT NULL AND p_date_field IS NOT NULL THEN
            l_filter := p_date_field || ' > '''
                || TO_CHAR(l_last_sync - gc_overlap_days,
                           'YYYY-MM-DD"T"HH24:MI:SS".000Z"')
                || '''';
        END IF;

        apex_rest_source_sync.dynamic_synchronize_data(
            p_module_static_id          => p_module_static_id,
            p_sync_static_id            => p_sync_step_id,
            p_sync_external_filter_expr => l_filter,
            p_application_id            => gc_app_id
        );
    END sync_source;

    ---------------------------------------------------------------------------
    -- sync_source_safe: wraps sync_source, returns 'OK' or error text.
    -- Looks up date_field from rest_source_registry when p_date_field is NULL.
    ---------------------------------------------------------------------------
    FUNCTION sync_source_safe (
        p_module_static_id  IN VARCHAR2,
        p_date_field        IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        l_date_field  VARCHAR2(100) := p_date_field;
        l_sync_type   VARCHAR2(30);
    BEGIN
        -- Look up date field and sync type from registry if not supplied
        IF l_date_field IS NULL THEN
            SELECT r.date_field, r.sync_type
              INTO l_date_field, l_sync_type
              FROM rest_source_registry r
             WHERE r.module_static_id = p_module_static_id;
        END IF;

        -- FULL_ONLY sources never get a date filter
        IF l_sync_type = 'FULL_ONLY' THEN
            sync_source(
                p_module_static_id => p_module_static_id,
                p_date_field       => NULL
            );
        ELSE
            sync_source(
                p_module_static_id => p_module_static_id,
                p_date_field       => NVL(l_date_field, 'LastUpdateDate')
            );
        END IF;

        RETURN 'OK';

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Source not in registry — try with default date field
            BEGIN
                sync_source(p_module_static_id => p_module_static_id);
                RETURN 'OK';
            EXCEPTION
                WHEN OTHERS THEN
                    RETURN SQLERRM;
            END;
        WHEN OTHERS THEN
            RETURN SQLERRM;
    END sync_source_safe;

    ---------------------------------------------------------------------------
    -- sync_all: loop through every active source in the registry
    ---------------------------------------------------------------------------
    PROCEDURE sync_all IS
        l_errors       NUMBER := 0;
        l_err_list     VARCHAR2(4000);
        l_need_session BOOLEAN := FALSE;
    BEGIN
        -----------------------------------------------------------------------
        -- Create APEX session when called from DBMS_SCHEDULER (no session).
        -- When called from an APEX page, the session already exists.
        -----------------------------------------------------------------------
        IF apex_application.g_flow_id IS NULL THEN
            apex_session.create_session(
                p_app_id   => gc_app_id,
                p_page_id  => 1,
                p_username => 'ADMIN'
            );
            l_need_session := TRUE;
        END IF;

        -----------------------------------------------------------------------
        -- Sync each active source from the registry.
        -- INCREMENTAL sources use the configured date_field.
        -- FULL_ONLY sources pass NULL date_field (no filter = full refresh).
        -----------------------------------------------------------------------
        FOR r IN (
            SELECT module_static_id, date_field, sync_type
              FROM rest_source_registry
             WHERE is_active = 'Y'
             ORDER BY module_code, display_name
        ) LOOP
            BEGIN
                IF r.sync_type = 'FULL_ONLY' THEN
                    -- No date filter — full refresh
                    sync_source(
                        p_module_static_id => r.module_static_id,
                        p_date_field       => NULL
                    );
                ELSE
                    -- Incremental with the configured date field
                    sync_source(
                        p_module_static_id => r.module_static_id,
                        p_date_field       => NVL(r.date_field, 'LastUpdateDate')
                    );
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    l_errors   := l_errors + 1;
                    l_err_list := l_err_list
                        || r.module_static_id || ': ' || SQLERRM || CHR(10);
            END;
        END LOOP;

        IF l_need_session THEN
            apex_session.delete_session;
        END IF;

        IF l_errors > 0 THEN
            raise_application_error(-20001,
                l_errors || ' REST source(s) failed to sync:' || CHR(10)
                || l_err_list);
        END IF;
    END sync_all;

END pkg_rest_sync;
/
