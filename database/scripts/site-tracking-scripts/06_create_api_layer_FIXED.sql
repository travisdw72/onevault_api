-- ============================================================================
-- 06_create_api_layer_FIXED.sql
-- Site Tracking API Layer - CRITICAL TENANT ASSIGNMENT FIX
-- ============================================================================
-- CRITICAL FIX: Proper tenant assignment instead of hardcoded first tenant
-- This fixes the major security vulnerability in tenant isolation
-- ============================================================================

-- Create API schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS api;

-- ============================================================================
-- FIXED SITE TRACKING API FUNCTION WITH PROPER TENANT HANDLING
-- ============================================================================

CREATE OR REPLACE FUNCTION api.track_site_event(
    p_api_key VARCHAR(255),
    p_event_data JSONB,
    p_client_ip INET,
    p_user_agent TEXT
) RETURNS JSONB AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_api_key_hk BYTEA;
    v_raw_event_id INTEGER;
    v_audit_result JSONB;
    v_rate_limit_result RECORD;
    v_security_score DECIMAL(5,2);
BEGIN
    -- Input validation
    IF p_api_key IS NULL OR LENGTH(p_api_key) = 0 THEN
        RAISE EXCEPTION 'API key is required for tenant identification';
    END IF;
    
    IF p_event_data IS NULL OR p_event_data = '{}'::JSONB THEN
        RAISE EXCEPTION 'Event data cannot be null or empty';
    END IF;
    
    -- CRITICAL FIX: Resolve tenant from API key instead of hardcoded selection
    SELECT ak.tenant_hk, ak.api_key_hk 
    INTO v_tenant_hk, v_api_key_hk
    FROM auth.api_key_h ak
    JOIN auth.api_key_details_s akd ON ak.api_key_hk = akd.api_key_hk
    WHERE akd.api_key_value = p_api_key
    AND akd.is_active = true
    AND akd.load_end_date IS NULL;
    
    -- If no tenant found for API key, reject request
    IF v_tenant_hk IS NULL THEN
        PERFORM util.log_audit_event(
            'INVALID_API_KEY',
            'SECURITY_VIOLATION',
            'api_key:' || p_api_key,
            'API_SECURITY',
            jsonb_build_object(
                'api_key', p_api_key,
                'client_ip', p_client_ip::text,
                'user_agent', p_user_agent,
                'violation_type', 'invalid_api_key',
                'action_taken', 'request_rejected'
            )
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid API key',
            'error_code', 'INVALID_API_KEY'
        );
    END IF;
    
    -- Check rate limiting for this IP
    SELECT * INTO v_rate_limit_result
    FROM api.check_rate_limit(p_client_ip, '/api/track_site_event', 100, 1);
    
    IF NOT v_rate_limit_result.is_allowed THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Rate limit exceeded',
            'error_code', 'RATE_LIMITED',
            'retry_after', v_rate_limit_result.reset_time
        );
    END IF;
    
    -- Calculate security score
    v_security_score := api.calculate_security_score(p_client_ip, p_user_agent, p_event_data);
    
    -- Ingest raw event with CORRECT tenant assignment
    SELECT raw.ingest_tracking_event(
        v_tenant_hk,  -- FIXED: Use resolved tenant, not hardcoded
        v_api_key_hk,
        p_client_ip,
        p_user_agent,
        p_event_data
    ) INTO v_raw_event_id;
    
    -- Log successful tracking with tenant context
    SELECT util.log_audit_event(
        'SITE_EVENT_TRACKED',
        'SITE_TRACKING',
        'tenant:' || encode(v_tenant_hk, 'hex'),
        'API_SYSTEM',
        jsonb_build_object(
            'raw_event_id', v_raw_event_id,
            'tenant_hk', encode(v_tenant_hk, 'hex'),
            'api_key_hk', encode(v_api_key_hk, 'hex'),
            'event_type', p_event_data->>'event_type',
            'page_url', p_event_data->>'page_url',
            'client_ip', p_client_ip::text,
            'user_agent', p_user_agent,
            'security_score', v_security_score,
            'processing_status', 'ingested'
        )
    ) INTO v_audit_result;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Event tracked successfully',
        'raw_event_id', v_raw_event_id,
        'tenant_hk', encode(v_tenant_hk, 'hex'),
        'security_score', v_security_score,
        'audit_logged', v_audit_result->'success'
    );
    
EXCEPTION WHEN OTHERS THEN
    -- Log error with tenant context if available
    SELECT util.log_audit_event(
        'TRACKING_ERROR',
        'SYSTEM_ERROR',
        'api:track_site_event',
        'ERROR_HANDLER',
        jsonb_build_object(
            'error_code', SQLSTATE,
            'error_message', SQLERRM,
            'api_key', p_api_key,
            'tenant_hk', COALESCE(encode(v_tenant_hk, 'hex'), 'UNKNOWN'),
            'client_ip', p_client_ip::text
        )
    ) INTO v_audit_result;
    
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Internal server error',
        'error_code', 'INTERNAL_ERROR',
        'audit_logged', v_audit_result->'success'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- TEMPORARY TESTING FUNCTION (For current test scenarios)
-- ============================================================================

CREATE OR REPLACE FUNCTION api.track_site_event_test(
    p_tenant_bk VARCHAR(255),  -- Use business key for testing
    p_event_data JSONB,
    p_client_ip INET,
    p_user_agent TEXT
) RETURNS JSONB AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_raw_event_id INTEGER;
    v_audit_result JSONB;
BEGIN
    -- Resolve tenant by business key for testing
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h
    WHERE tenant_bk = p_tenant_bk;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'Tenant not found: %', p_tenant_bk;
    END IF;
    
    -- Ingest with correct tenant
    SELECT raw.ingest_tracking_event(
        v_tenant_hk,
        NULL, -- No API key for testing
        p_client_ip,
        p_user_agent,
        p_event_data
    ) INTO v_raw_event_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'raw_event_id', v_raw_event_id,
        'tenant_hk', encode(v_tenant_hk, 'hex'),
        'tenant_bk', p_tenant_bk
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TENANT CORRECTION UTILITY
-- ============================================================================

CREATE OR REPLACE FUNCTION api.correct_event_tenant(
    p_raw_event_id INTEGER,
    p_correct_tenant_bk VARCHAR(255)
) RETURNS JSONB AS $$
DECLARE
    v_correct_tenant_hk BYTEA;
    v_old_tenant_hk BYTEA;
    v_audit_result JSONB;
BEGIN
    -- Get correct tenant hash key
    SELECT tenant_hk INTO v_correct_tenant_hk
    FROM auth.tenant_h
    WHERE tenant_bk = p_correct_tenant_bk;
    
    IF v_correct_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'Tenant not found: %', p_correct_tenant_bk;
    END IF;
    
    -- Get current (wrong) tenant
    SELECT tenant_hk INTO v_old_tenant_hk
    FROM raw.site_tracking_events_r
    WHERE raw_event_id = p_raw_event_id;
    
    -- Update the tenant assignment
    UPDATE raw.site_tracking_events_r
    SET tenant_hk = v_correct_tenant_hk
    WHERE raw_event_id = p_raw_event_id;
    
    -- Log the correction
    SELECT util.log_audit_event(
        'TENANT_CORRECTION',
        'DATA_CORRECTION',
        'raw_event:' || p_raw_event_id,
        'ADMIN_CORRECTION',
        jsonb_build_object(
            'raw_event_id', p_raw_event_id,
            'old_tenant_hk', encode(v_old_tenant_hk, 'hex'),
            'new_tenant_hk', encode(v_correct_tenant_hk, 'hex'),
            'new_tenant_bk', p_correct_tenant_bk,
            'correction_reason', 'tenant_assignment_bug_fix'
        )
    ) INTO v_audit_result;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Tenant corrected successfully',
        'raw_event_id', p_raw_event_id,
        'old_tenant_hk', encode(v_old_tenant_hk, 'hex'),
        'new_tenant_hk', encode(v_correct_tenant_hk, 'hex'),
        'new_tenant_bk', p_correct_tenant_bk
    );
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION api.track_site_event(VARCHAR, JSONB, INET, TEXT) TO PUBLIC;
GRANT EXECUTE ON FUNCTION api.track_site_event_test(VARCHAR, JSONB, INET, TEXT) TO PUBLIC;
GRANT EXECUTE ON FUNCTION api.correct_event_tenant(INTEGER, VARCHAR) TO PUBLIC;

-- ============================================================================
-- VALIDATION
-- ============================================================================

SELECT '✅ CRITICAL TENANT ASSIGNMENT FIX DEPLOYED' as status,
       'Use api.correct_event_tenant() to fix existing data' as action_required,
       'Use api.track_site_event_test() for testing with tenant_bk' as testing_method; 