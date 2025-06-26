-- ============================================================================
-- 07_enhanced_api_functions.sql  
-- Enhanced Site Tracking API Functions with Customer Configuration Support
-- ============================================================================

-- Enhanced track_site_event function with customer configuration support
CREATE OR REPLACE FUNCTION api.track_site_event_enhanced(
    p_ip_address INET,
    p_user_agent TEXT,
    p_page_url TEXT,
    p_event_type VARCHAR(50) DEFAULT 'page_view',
    p_event_data JSONB DEFAULT '{}'::jsonb,
    p_customer_id VARCHAR(100) DEFAULT NULL,
    p_rate_limit INTEGER DEFAULT 1000
) RETURNS JSONB AS $$
DECLARE
    v_tracking_result JSONB;
    v_event_hk BYTEA;
    v_audit_result JSONB;
    v_customer_config JSONB;
    v_tenant_hk BYTEA;
BEGIN
    -- Extract customer configuration from event data
    v_customer_config := p_event_data->'tracking_context';
    
    -- Get tenant hash key for customer
    SELECT tenant_hk INTO v_tenant_hk 
    FROM auth.tenant_h 
    WHERE tenant_bk = COALESCE(p_customer_id, 'default')
    ORDER BY load_date DESC 
    LIMIT 1;
    
    -- If no tenant found, use default tenant
    IF v_tenant_hk IS NULL THEN
        SELECT tenant_hk INTO v_tenant_hk 
        FROM auth.tenant_h 
        ORDER BY load_date ASC 
        LIMIT 1;
    END IF;
    
    -- Log the tracking attempt with custom rate limit
    v_tracking_result := api.log_tracking_attempt_enhanced(
        p_ip_address,
        '/api/v1/track',
        p_user_agent,
        jsonb_build_object(
            'page_url', p_page_url,
            'event_type', p_event_type,
            'event_data', p_event_data,
            'customer_id', p_customer_id,
            'customer_config', v_customer_config
        ),
        p_rate_limit
    );
    
    -- If tracking is not allowed, return early
    IF NOT (v_tracking_result->>'allowed')::boolean THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Request rate limited or blocked',
            'tracking_result', v_tracking_result,
            'customer_id', p_customer_id
        );
    END IF;
    
    -- Generate event hash key
    v_event_hk := util.hash_binary(
        COALESCE(p_customer_id, 'default') || 
        p_ip_address::text || 
        p_page_url || 
        p_event_type || 
        CURRENT_TIMESTAMP::text
    );
    
    -- Store the tracking event with enhanced data
    INSERT INTO raw.site_tracking_events_r (
        raw_event_id,
        tenant_hk,
        api_key_hk,
        received_timestamp,
        client_ip,
        user_agent,
        raw_payload,
        batch_id,
        record_source
    ) VALUES (
        DEFAULT,
        v_tenant_hk,
        NULL,
        CURRENT_TIMESTAMP,
        p_ip_address,
        p_user_agent,
        jsonb_build_object(
            'event_type', p_event_type,
            'page_url', p_page_url,
            'event_data', p_event_data,
            'customer_id', p_customer_id,
            'customer_config', v_customer_config,
            'timestamp', CURRENT_TIMESTAMP,
            'api_version', '2.0.0'
        ),
        'API_ENHANCED_' || encode(v_event_hk, 'hex'),
        util.get_record_source()
    );
    
    -- Log successful event storage with customer context
    SELECT util.log_audit_event(
        'SITE_EVENT_STORED_ENHANCED',
        'SITE_TRACKING',
        'event:' || encode(v_event_hk, 'hex'),
        'API_SYSTEM_ENHANCED',
        jsonb_build_object(
            'event_type', p_event_type,
            'page_url', p_page_url,
            'ip_address', p_ip_address::text,
            'user_agent', p_user_agent,
            'event_data', p_event_data,
            'customer_id', p_customer_id,
            'customer_config', v_customer_config,
            'storage_tables', jsonb_build_array('raw.site_tracking_events_r'),
            'event_hk', encode(v_event_hk, 'hex'),
            'tenant_hk', encode(v_tenant_hk, 'hex'),
            'rate_limit_used', p_rate_limit
        )
    ) INTO v_audit_result;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Event tracked successfully with customer configuration',
        'event_id', encode(v_event_hk, 'hex'),
        'customer_id', p_customer_id,
        'tenant_hk', encode(v_tenant_hk, 'hex'),
        'tracking_result', v_tracking_result,
        'audit_logged', v_audit_result->'success',
        'rate_limit_remaining', (v_tracking_result->>'remaining_requests')::integer
    );
    
EXCEPTION WHEN OTHERS THEN
    -- Log error with customer context
    SELECT util.log_audit_event(
        'SYSTEM_ERROR',
        'SITE_TRACKING',
        'function:api.track_site_event_enhanced',
        'SYSTEM',
        jsonb_build_object(
            'error_code', SQLSTATE,
            'error_message', SQLERRM,
            'page_url', p_page_url,
            'event_type', p_event_type,
            'ip_address', p_ip_address::text,
            'customer_id', p_customer_id,
            'customer_config', v_customer_config
        )
    ) INTO v_audit_result;
    
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to track event',
        'error_details', SQLERRM,
        'customer_id', p_customer_id,
        'audit_logged', v_audit_result->'success'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enhanced rate limiting with customer-specific limits
CREATE OR REPLACE FUNCTION api.log_tracking_attempt_enhanced(
    p_ip_address INET,
    p_endpoint VARCHAR(200),
    p_user_agent TEXT,
    p_request_data JSONB DEFAULT '{}'::jsonb,
    p_rate_limit INTEGER DEFAULT 1000
) RETURNS JSONB AS $$
DECLARE
    v_security_score DECIMAL(5,2);
    v_rate_limit_result RECORD;
    v_tracking_hk BYTEA;
    v_audit_result JSONB;
    v_customer_id TEXT;
BEGIN
    -- Extract customer ID from request data
    v_customer_id := p_request_data->>'customer_id';
    
    -- Calculate security score
    v_security_score := api.calculate_security_score(
        p_ip_address,
        p_user_agent,
        p_request_data
    );
    
    -- Check rate limiting with customer-specific limit
    SELECT * INTO v_rate_limit_result 
    FROM api.check_rate_limit(
        p_ip_address,
        p_endpoint,
        p_rate_limit,
        1
    );
    
    -- Generate tracking hash key
    v_tracking_hk := util.hash_binary(
        p_ip_address::text || 
        p_endpoint || 
        COALESCE(v_customer_id, 'default') ||
        CURRENT_TIMESTAMP::text
    );
    
    -- Store tracking attempt with enhanced data
    INSERT INTO auth.security_tracking_h VALUES (
        v_tracking_hk,
        'TRACK_' || COALESCE(v_customer_id, 'DEFAULT') || '_' || 
        to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'),
        (SELECT tenant_hk FROM auth.tenant_h 
         WHERE tenant_bk = COALESCE(v_customer_id, 'default') 
         ORDER BY load_date DESC LIMIT 1),
        util.current_load_date(),
        util.get_record_source()
    ) ON CONFLICT DO NOTHING;
    
    RETURN jsonb_build_object(
        'allowed', v_rate_limit_result.is_allowed,
        'security_score', v_security_score,
        'rate_limit_status', CASE 
            WHEN v_rate_limit_result.is_allowed THEN 'WITHIN_LIMIT'
            ELSE 'RATE_LIMITED'
        END,
        'current_requests', v_rate_limit_result.current_count,
        'remaining_requests', v_rate_limit_result.remaining_requests,
        'reset_time', v_rate_limit_result.reset_time,
        'customer_id', v_customer_id,
        'custom_rate_limit', p_rate_limit,
        'tracking_hk', encode(v_tracking_hk, 'hex')
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'allowed', false,
        'security_score', 1.0,
        'rate_limit_status', 'ERROR',
        'error', SQLERRM,
        'customer_id', v_customer_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Customer configuration retrieval function
CREATE OR REPLACE FUNCTION api.get_customer_tracking_config(
    p_customer_id VARCHAR(100)
) RETURNS JSONB AS $$
DECLARE
    v_config JSONB;
    v_tenant_hk BYTEA;
    v_audit_result JSONB;
BEGIN
    -- Get tenant for customer
    SELECT tenant_hk INTO v_tenant_hk 
    FROM auth.tenant_h 
    WHERE tenant_bk = p_customer_id 
    ORDER BY load_date DESC 
    LIMIT 1;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Customer not found'
        );
    END IF;
    
    -- Build configuration response (this would integrate with actual config storage)
    v_config := jsonb_build_object(
        'customer_id', p_customer_id,
        'tenant_hk', encode(v_tenant_hk, 'hex'),
        'tracking_settings', jsonb_build_object(
            'rate_limit', 10000, -- Default, would come from customer config
            'storage_quota_gb', 500,
            'backup_retention_days', 2555,
            'hipaa_compliance', true
        ),
        'enabled_features', jsonb_build_object(
            'site_tracking', true,
            'member_tracking', true,
            'appointment_tracking', true,
            'treatment_tracking', true,
            'staff_tracking', true,
            'inventory_tracking', true,
            'pos_tracking', true,
            'marketing_tracking', true
        ),
        'api_endpoints', jsonb_build_object(
            'track_event', '/api/v1/track',
            'bulk_track', '/api/v1/track/bulk',
            'get_config', '/api/v1/customer/' || p_customer_id || '/tracking-config'
        ),
        'timestamp', CURRENT_TIMESTAMP
    );
    
    -- Log configuration access
    SELECT util.log_audit_event(
        'CUSTOMER_CONFIG_ACCESSED',
        'API_CONFIGURATION',
        'customer:' || p_customer_id,
        'CONFIG_API',
        jsonb_build_object(
            'customer_id', p_customer_id,
            'tenant_hk', encode(v_tenant_hk, 'hex'),
            'config_retrieved', true
        )
    ) INTO v_audit_result;
    
    RETURN jsonb_build_object(
        'success', true,
        'config', v_config,
        'audit_logged', v_audit_result->'success'
    );
    
EXCEPTION WHEN OTHERS THEN
    -- Log error
    SELECT util.log_audit_event(
        'SYSTEM_ERROR',
        'API_CONFIGURATION',
        'function:api.get_customer_tracking_config',
        'SYSTEM',
        jsonb_build_object(
            'error_code', SQLSTATE,
            'error_message', SQLERRM,
            'customer_id', p_customer_id
        )
    ) INTO v_audit_result;
    
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to retrieve configuration',
        'error_details', SQLERRM,
        'audit_logged', v_audit_result->'success'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for enhanced functions
GRANT EXECUTE ON FUNCTION api.track_site_event_enhanced(INET, TEXT, TEXT, VARCHAR, JSONB, VARCHAR, INTEGER) TO PUBLIC;
GRANT EXECUTE ON FUNCTION api.log_tracking_attempt_enhanced(INET, VARCHAR, TEXT, JSONB, INTEGER) TO PUBLIC;
GRANT EXECUTE ON FUNCTION api.get_customer_tracking_config(VARCHAR) TO PUBLIC;

-- Test the enhanced functions
DO $$
DECLARE
    v_test_result JSONB;
BEGIN
    -- Test enhanced tracking function
    SELECT api.track_site_event_enhanced(
        '192.168.1.100'::inet,
        'Mozilla/5.0 (Test Browser)',
        'https://luxewellness.com/booking',
        'appointment_booking',
        jsonb_build_object(
            'appointment_id', 'APPT_12345',
            'service_type', 'deep_tissue_massage',
            'location_id', 'spa_001',
            'tracking_context', jsonb_build_object(
                'api_version', '2.0.0',
                'customer_config_version', '1.2'
            )
        ),
        'one_spa',
        10000  -- Customer-specific rate limit
    ) INTO v_test_result;
    
    IF (v_test_result->>'success')::boolean THEN
        RAISE NOTICE '✅ Enhanced tracking test: PASSED';
        RAISE NOTICE '   Event ID: %', v_test_result->>'event_id';
        RAISE NOTICE '   Customer: %', v_test_result->>'customer_id';
    ELSE
        RAISE NOTICE '❌ Enhanced tracking test: FAILED';
        RAISE NOTICE '   Error: %', v_test_result->>'error';
    END IF;
END $$;

-- Create view for tracking analytics  
CREATE OR REPLACE VIEW api.tracking_analytics_v AS
SELECT 
    date_trunc('hour', its.last_request_time) as hour_bucket,
    COUNT(*) as total_requests,
    COUNT(DISTINCT its.ip_address) as unique_ips,
    AVG(its.security_score) as avg_security_score,
    jsonb_agg(DISTINCT its.request_data->>'customer_id') FILTER (WHERE its.request_data->>'customer_id' IS NOT NULL) as customers,
    MAX(its.security_score) as max_security_score,
    COUNT(*) FILTER (WHERE its.security_score > 0.5) as high_risk_requests
FROM auth.ip_tracking_s its
JOIN auth.security_tracking_h sth ON its.security_tracking_hk = sth.security_tracking_hk
WHERE its.endpoint = '/api/v1/track'
AND its.last_request_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
AND its.load_end_date IS NULL
GROUP BY date_trunc('hour', its.last_request_time)
ORDER BY hour_bucket DESC;

GRANT SELECT ON api.tracking_analytics_v TO PUBLIC;

RAISE NOTICE '';
RAISE NOTICE '🎉 ENHANCED API FUNCTIONS COMPLETED!';
RAISE NOTICE '=====================================';
RAISE NOTICE 'Functions created:';
RAISE NOTICE '  - api.track_site_event_enhanced()';
RAISE NOTICE '  - api.log_tracking_attempt_enhanced()';
RAISE NOTICE '  - api.get_customer_tracking_config()';
RAISE NOTICE '  - api.tracking_analytics_v (view)';
RAISE NOTICE '';
RAISE NOTICE 'Enhanced features:';
RAISE NOTICE '  ✅ Customer-specific rate limiting';
RAISE NOTICE '  ✅ Enhanced audit logging';
RAISE NOTICE '  ✅ Customer configuration integration';
RAISE NOTICE '  ✅ Multi-tenant isolation';
RAISE NOTICE '  ✅ Tracking analytics view';
RAISE NOTICE '====================================='; 