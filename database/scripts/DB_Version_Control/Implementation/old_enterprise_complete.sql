-- Enterprise Tracking System - Complete Implementation
-- Function wrappers that provide automatic tracking without changing existing code

-- Wrapper for auth.login_user -> auth.login_user_tracking
CREATE OR REPLACE FUNCTION auth.login_user_tracking(
    p_email VARCHAR(255),
    p_password TEXT,
    p_tenant_id VARCHAR(255)
) RETURNS TABLE (
    p_success BOOLEAN,
    p_session_token VARCHAR(255),
    p_user_data JSONB,
    p_message TEXT
) AS $$
DECLARE
    v_execution_hk BYTEA;
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_duration BIGINT;
    v_result RECORD;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    -- Start automatic tracking
    v_execution_hk := script_tracking.track_script_execution(
        'auth.login_user',
        'AUTHENTICATION',
        'SECURITY',
        NULL, NULL, NULL,
        util.process_hex_tenant(p_tenant_id),
        'User authentication with automatic tracking',
        NULL
    );
    
    -- Call the original function (no changes to existing code!)
    SELECT * INTO v_result FROM auth.login_user(p_email, p_password, p_tenant_id);
    
    -- Complete tracking
    v_duration := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time)) * 1000;
    
    PERFORM script_tracking.complete_script_execution(
        v_execution_hk,
        CASE WHEN v_result.p_success THEN 'COMPLETED' ELSE 'FAILED' END,
        v_duration,
        1,
        CASE WHEN NOT v_result.p_success THEN v_result.p_message ELSE NULL END,
        NULL,
        ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY['auth']
    );
    
    -- Return the results (identical to original function)
    RETURN QUERY SELECT v_result.p_success, v_result.p_session_token, v_result.p_user_data, v_result.p_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enterprise dashboard function
CREATE OR REPLACE FUNCTION script_tracking.get_enterprise_dashboard()
RETURNS TABLE (
    metric_name VARCHAR(100),
    metric_value BIGINT,
    alert_level VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'Total Operations'::VARCHAR(100),
        COUNT(*)::BIGINT,
        'LOW'::VARCHAR(20)
    FROM script_tracking.script_execution_s
    WHERE execution_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    
    UNION ALL
    
    SELECT 
        'Authentication Operations'::VARCHAR(100),
        COUNT(*)::BIGINT,
        'LOW'::VARCHAR(20)
    FROM script_tracking.script_execution_s
    WHERE execution_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    AND script_type = 'AUTHENTICATION';
END;
$$ LANGUAGE plpgsql;

-- Historical data import simulation
CREATE OR REPLACE FUNCTION script_tracking.import_historical_demo()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    -- Create 20 sample historical operations
    FOR i IN 1..20 LOOP
        INSERT INTO script_tracking.script_execution_h VALUES (
            util.hash_binary('HIST_' || i || '_' || CURRENT_TIMESTAMP::text),
            'HISTORICAL_OP_' || i,
            NULL,
            CURRENT_TIMESTAMP - (random() * INTERVAL '30 days'),
            'HISTORICAL_IMPORT'
        );
        
        INSERT INTO script_tracking.script_execution_s VALUES (
            util.hash_binary('HIST_' || i || '_' || CURRENT_TIMESTAMP::text),
            CURRENT_TIMESTAMP - (random() * INTERVAL '30 days'),
            NULL,
            util.hash_binary('HIST_' || i),
            'Historical Operation ' || i,
            'HISTORICAL',
            'DEMO',
            CURRENT_TIMESTAMP - (random() * INTERVAL '30 days'),
            'postgres', 'postgres', 'psql', 'localhost', 5432,
            NULL, NULL, NULL, NULL,
            'COMPLETED',
            (random() * 1000)::BIGINT,
            (random() * 100)::BIGINT,
            NULL, NULL,
            ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY[]::TEXT[],
            NULL, NULL, NULL, NULL, NULL,
            false, false, 'INTERNAL', ARRAY[]::TEXT[],
            false, NULL, NULL,
            'DEVELOPMENT', NULL, 'Historical demo data',
            false, false,
            'HISTORICAL_IMPORT'
        );
        
        v_count := v_count + 1;
    END LOOP;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Initialize the enterprise system
DO $$
DECLARE
    v_imported_count INTEGER;
BEGIN
    RAISE NOTICE '🚀 ENTERPRISE TRACKING SYSTEM SETUP';
    RAISE NOTICE '====================================';
    
    -- Import historical demo data
    SELECT script_tracking.import_historical_demo() INTO v_imported_count;
    RAISE NOTICE '✅ Imported % historical operations', v_imported_count;
    
    -- Verify function wrappers
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'login_user_tracking') THEN
        RAISE NOTICE '✅ Function wrappers created successfully';
    ELSE
        RAISE NOTICE '❌ Function wrapper creation failed';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎉 ENTERPRISE TRACKING READY!';
    RAISE NOTICE '';
    RAISE NOTICE 'USAGE:';
    RAISE NOTICE '  -- Use tracking version:';
    RAISE NOTICE '  SELECT * FROM auth.login_user_tracking(email, pass, tenant);';
    RAISE NOTICE '';
    RAISE NOTICE '  -- View dashboard:';
    RAISE NOTICE '  SELECT * FROM script_tracking.get_enterprise_dashboard();';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Original functions still work unchanged!';
END $$; 