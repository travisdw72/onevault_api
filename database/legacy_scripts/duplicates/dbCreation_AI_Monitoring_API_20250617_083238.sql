-- =====================================================================
-- AI Monitoring System - API Endpoints
-- Zero Trust Security Enhanced API Layer
-- Generic Entity Monitoring (Industry Agnostic)
-- =====================================================================

-- =====================================================================
-- DEPLOYMENT LOGGING
-- =====================================================================
DO $$
DECLARE
    deployment_id INTEGER;
BEGIN
    SELECT util.log_deployment_start(
        'AI_MONITORING_API_V1',
        'AI monitoring system API endpoints with Zero Trust security',
        'ROLLBACK: Drop ai_monitoring API functions from api schema'
    ) INTO deployment_id;
    
    RAISE NOTICE 'Starting API deployment ID: %', deployment_id;
END $$;

-- =====================================================================
-- REAL-TIME DATA INGESTION (Zero Trust)
-- =====================================================================

-- Real-time Data Ingestion API (Enhanced Authentication Integration)
-- Integrates with existing auth.validate_token_comprehensive() system
CREATE OR REPLACE FUNCTION api.ai_monitoring_ingest(p_request JSONB) 
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_token TEXT;
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_entity_bk VARCHAR(255);
    v_entity_type VARCHAR(100);
    v_monitoring_data JSONB;
    v_ingestion_rate_limit INTEGER := 1000; -- per minute
    v_current_rate INTEGER;
    v_auth_result RECORD;
    v_zero_trust_result RECORD;
    v_entity_hk BYTEA;
    v_analysis_hk BYTEA;
    v_response JSONB;
BEGIN
    -- 1. EXTRACT AND VALIDATE REQUEST PARAMETERS
    v_token := p_request->>'token';
    v_entity_bk := p_request->>'entity_bk';
    v_entity_type := COALESCE(p_request->>'entity_type', 'EQUIPMENT');
    v_monitoring_data := p_request->'monitoring_data';
    
    -- Validate required parameters
    IF v_token IS NULL OR v_entity_bk IS NULL OR v_monitoring_data IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'MISSING_PARAMETERS',
            'message', 'Missing required parameters: token, entity_bk, monitoring_data',
            'timestamp', CURRENT_TIMESTAMP
        );
    END IF;

    -- 2. AUTHENTICATE USING EXISTING TOKEN VALIDATION SYSTEM
    SELECT * INTO v_auth_result
    FROM auth.validate_token_comprehensive(
        v_token,
        (p_request->>'ip_address')::INET,
        p_request->>'user_agent',
        'ai_monitoring_ingest'
    );
    
    IF NOT v_auth_result.is_valid THEN
        -- Log failed authentication using existing audit system
        PERFORM audit.log_security_event(
            'API_AUTHENTICATION_FAILED',
            'HIGH',
            format('AI monitoring ingest authentication failed: %s', v_auth_result.message),
            (p_request->>'ip_address')::INET,
            p_request->>'user_agent',
            NULL,
            'HIGH',
            jsonb_build_object(
                'endpoint', 'ai_monitoring_ingest',
                'entity_bk', v_entity_bk,
                'failure_reason', v_auth_result.message
            )
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'AUTHENTICATION_FAILED',
            'message', v_auth_result.message,
            'timestamp', CURRENT_TIMESTAMP
        );
    END IF;
    
    v_tenant_hk := v_auth_result.tenant_hk;
    v_user_hk := v_auth_result.user_hk;

    -- 3. ZERO TRUST ACCESS VALIDATION
    SELECT * INTO v_zero_trust_result
    FROM ai_monitoring.validate_zero_trust_access(
        v_tenant_hk,
        v_user_hk,
        v_token,
        (p_request->>'ip_address')::INET,
        p_request->>'user_agent',
        'ai_monitoring_data',
        'ai_monitoring_ingest'
    );
    
    IF NOT v_zero_trust_result.p_access_granted THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'ACCESS_DENIED',
            'message', format('Zero Trust access denied: %s (Risk Score: %s)', 
                            v_zero_trust_result.p_access_level, 
                            v_zero_trust_result.p_risk_score),
            'required_actions', v_zero_trust_result.p_required_actions,
            'timestamp', CURRENT_TIMESTAMP
        );
    END IF;

    -- 4. RATE LIMITING USING EXISTING INFRASTRUCTURE
    SELECT * INTO v_current_rate
    FROM auth.check_rate_limit_enhanced(
        v_tenant_hk,
        (p_request->>'ip_address')::INET,
        'ai_monitoring_ingest',
        p_request->>'user_agent'
    );
    
    IF NOT v_current_rate THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'RATE_LIMIT_EXCEEDED',
            'message', 'Ingestion rate limit exceeded. Please reduce request frequency.',
            'retry_after_seconds', 60,
            'timestamp', CURRENT_TIMESTAMP
        );
    END IF;

    -- 5. GET OR CREATE MONITORED ENTITY
    SELECT monitored_entity_hk INTO v_entity_hk
    FROM ai_monitoring.monitored_entity_h
    WHERE monitored_entity_bk = v_entity_bk
    AND tenant_hk = v_tenant_hk;
    
    IF v_entity_hk IS NULL THEN
        v_entity_hk := ai_monitoring.create_monitored_entity(
            v_tenant_hk,
            v_entity_bk,
            COALESCE(v_monitoring_data->>'entity_name', v_entity_bk),
            v_entity_type,
            v_monitoring_data->'location_info',
            jsonb_build_object(
                'auto_created', true,
                'data_source', 'API_INGESTION',
                'monitoring_enabled', true
            ),
            v_user_hk
        );
    END IF;

    -- 6. STORE AI ANALYSIS RESULTS
    v_analysis_hk := ai_monitoring.store_ai_analysis(
        v_tenant_hk,
        v_entity_hk,
        COALESCE(v_monitoring_data->>'analysis_type', 'REAL_TIME_MONITORING'),
        v_monitoring_data,
        COALESCE((v_monitoring_data->>'confidence_score')::DECIMAL(5,2), 85.0),
        COALESCE(v_monitoring_data->>'model_version', 'AI_MONITORING_v1.0'),
        v_user_hk
    );

    -- 7. CHECK FOR ALERT CONDITIONS
    DECLARE
        v_alert_threshold DECIMAL(5,2);
        v_current_value DECIMAL(10,4);
        v_alert_hk BYTEA;
    BEGIN
        v_alert_threshold := COALESCE((v_monitoring_data->>'alert_threshold')::DECIMAL(5,2), 80.0);
        v_current_value := COALESCE((v_monitoring_data->>'metric_value')::DECIMAL(10,4), 0);
        
        IF v_current_value > v_alert_threshold THEN
            v_alert_hk := ai_monitoring.create_alert(
                v_tenant_hk,
                v_analysis_hk,
                v_entity_hk,
                'THRESHOLD_EXCEEDED',
                CASE 
                    WHEN v_current_value > v_alert_threshold * 1.5 THEN 'CRITICAL'
                    WHEN v_current_value > v_alert_threshold * 1.2 THEN 'HIGH'
                    ELSE 'MEDIUM'
                END,
                format('Monitoring threshold exceeded for %s: %.2f > %.2f', 
                       v_entity_bk, v_current_value, v_alert_threshold),
                jsonb_build_object(
                    'metric_value', v_current_value,
                    'threshold', v_alert_threshold,
                    'entity_bk', v_entity_bk,
                    'analysis_hk', encode(v_analysis_hk, 'hex')
                ),
                v_user_hk
            );
        END IF;
    END;

    -- 8. UPDATE TOKEN USAGE TRACKING
    PERFORM auth.update_token_usage(util.hash_binary(v_token));

    -- 9. BUILD SUCCESS RESPONSE
    v_response := jsonb_build_object(
        'success', true,
        'message', 'Data ingested successfully',
        'entity_hk', encode(v_entity_hk, 'hex'),
        'analysis_hk', encode(v_analysis_hk, 'hex'),
        'access_level', v_zero_trust_result.p_access_level,
        'processing_time_ms', extract(epoch from (CURRENT_TIMESTAMP - v_auth_result.expires_at)) * 1000,
        'timestamp', CURRENT_TIMESTAMP
    );
    
    IF v_alert_hk IS NOT NULL THEN
        v_response := v_response || jsonb_build_object(
            'alert_created', true,
            'alert_hk', encode(v_alert_hk, 'hex')
        );
    END IF;
    
    RETURN v_response;

EXCEPTION
    WHEN OTHERS THEN
        -- Log error using existing audit system
        PERFORM audit.log_error(
            v_tenant_hk,
            'AI_MONITORING_INGESTION_ERROR',
            SQLERRM,
            jsonb_build_object(
                'entity_bk', v_entity_bk,
                'user_hk', encode(COALESCE(v_user_hk, '\x00'), 'hex'),
                'request_data', p_request
            )
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INTERNAL_ERROR',
            'message', 'An internal error occurred during data ingestion',
            'timestamp', CURRENT_TIMESTAMP
        );
END;
$$;

-- =====================================================================
-- ALERT MANAGEMENT (Zero Trust)
-- =====================================================================

-- Retrieve alerts with Zero Trust security
CREATE OR REPLACE FUNCTION api.ai_monitoring_get_alerts(p_request JSONB)
RETURNS JSONB AS $$
DECLARE
    v_user_hk BYTEA;
    v_tenant_hk BYTEA;
    v_access_check RECORD;
    v_alerts JSONB := '[]'::JSONB;
    v_alert RECORD;
    v_limit INTEGER := 50;
    v_offset INTEGER := 0;
    v_severity_filter VARCHAR(20) := NULL;
    v_status_filter VARCHAR(20) := NULL;
BEGIN
    -- Validate authentication
    SELECT 
        is_valid, user_hk, tenant_hk, message
    INTO v_access_check
    FROM auth.validate_token_comprehensive(
        p_request->>'auth_token',
        inet_client_addr(),
        p_request->>'user_agent',
        'ai_monitoring_get_alerts'
    );
    
    IF NOT v_access_check.is_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'AUTHENTICATION_FAILED',
            'message', v_access_check.message
        );
    END IF;
    
    v_user_hk := v_access_check.user_hk;
    v_tenant_hk := v_access_check.tenant_hk;
    
    -- Zero Trust access validation
    SELECT access_granted, risk_score, access_reason
    INTO v_access_check
    FROM ai_monitoring.validate_zero_trust_access(
        v_user_hk,
        'ai_monitoring/alerts',
        'READ',
        jsonb_build_object('operation', 'list_alerts')
    );
    
    IF NOT v_access_check.access_granted THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ACCESS_DENIED',
            'message', v_access_check.access_reason
        );
    END IF;
    
    -- Parse query parameters
    IF p_request ? 'limit' THEN
        v_limit := LEAST((p_request->>'limit')::INTEGER, 100);
    END IF;
    
    IF p_request ? 'offset' THEN
        v_offset := (p_request->>'offset')::INTEGER;
    END IF;
    
    IF p_request ? 'severity' THEN
        v_severity_filter := p_request->>'severity';
    END IF;
    
    IF p_request ? 'status' THEN
        v_status_filter := p_request->>'status';
    END IF;
    
    -- Retrieve alerts with field-level access control
    FOR v_alert IN
        SELECT 
            encode(ah.alert_hk, 'hex') as alert_id,
            ah.alert_bk,
            ads.severity,
            ads.alert_type,
            ads.title,
            CASE 
                WHEN v_access_check.risk_score <= 30 THEN 
                    convert_from(ads.message_encrypted, 'UTF8') -- Simplified decryption
                ELSE '[REDACTED - High Risk Session]'
            END as message,
            ads.status,
            ads.acknowledged_date,
            ads.resolved_date,
            ads.response_required_by,
            ads.alert_authenticity_score,
            ads.load_date as created_date
        FROM ai_monitoring.alert_h ah
        JOIN ai_monitoring.alert_details_s ads ON ah.alert_hk = ads.alert_hk
        WHERE ah.tenant_hk = v_tenant_hk
        AND ads.load_end_date IS NULL
        AND (v_severity_filter IS NULL OR ads.severity = v_severity_filter)
        AND (v_status_filter IS NULL OR ads.status = v_status_filter)
        ORDER BY ads.load_date DESC
        LIMIT v_limit OFFSET v_offset
    LOOP
        v_alerts := v_alerts || jsonb_build_object(
            'alert_id', v_alert.alert_id,
            'alert_bk', v_alert.alert_bk,
            'severity', v_alert.severity,
            'alert_type', v_alert.alert_type,
            'title', v_alert.title,
            'message', v_alert.message,
            'status', v_alert.status,
            'acknowledged_date', v_alert.acknowledged_date,
            'resolved_date', v_alert.resolved_date,
            'response_required_by', v_alert.response_required_by,
            'authenticity_score', v_alert.alert_authenticity_score,
            'created_date', v_alert.created_date
        );
    END LOOP;
    
    -- Log data access
    PERFORM ai_monitoring.log_security_event(
        'ALERTS_ACCESSED',
        'INFO',
        format('User accessed alerts list (count: %s)', jsonb_array_length(v_alerts)),
        inet_client_addr(),
        v_user_hk,
        jsonb_build_object(
            'alert_count', jsonb_array_length(v_alerts),
            'filters', jsonb_build_object(
                'severity', v_severity_filter,
                'status', v_status_filter
            )
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'alerts', v_alerts,
        'count', jsonb_array_length(v_alerts),
        'zero_trust_risk_score', v_access_check.risk_score,
        'data_classification', 
            CASE WHEN v_access_check.risk_score <= 30 THEN 'FULL_ACCESS' ELSE 'RESTRICTED' END
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'QUERY_FAILED',
        'message', 'Failed to retrieve alerts'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Acknowledge alert with Zero Trust validation
CREATE OR REPLACE FUNCTION api.ai_monitoring_acknowledge_alert(p_request JSONB)
RETURNS JSONB AS $$
DECLARE
    v_user_hk BYTEA;
    v_tenant_hk BYTEA;
    v_access_check RECORD;
    v_alert_hk BYTEA;
    v_alert_details RECORD;
BEGIN
    -- Validate required fields
    IF NOT (p_request ? 'auth_token' AND p_request ? 'alert_id') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'INVALID_REQUEST',
            'message', 'Missing required fields: auth_token, alert_id'
        );
    END IF;
    
    -- Validate authentication
    SELECT 
        is_valid, user_hk, tenant_hk, message
    INTO v_access_check
    FROM auth.validate_token_comprehensive(
        p_request->>'auth_token',
        inet_client_addr(),
        p_request->>'user_agent',
        'ai_monitoring_acknowledge_alert'
    );
    
    IF NOT v_access_check.is_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'AUTHENTICATION_FAILED',
            'message', v_access_check.message
        );
    END IF;
    
    v_user_hk := v_access_check.user_hk;
    v_tenant_hk := v_access_check.tenant_hk;
    
    -- Convert alert_id to bytea
    v_alert_hk := decode(p_request->>'alert_id', 'hex');
    
    -- Verify alert exists and belongs to tenant
    SELECT 
        ah.alert_hk,
        ads.severity,
        ads.status,
        ads.alert_type
    INTO v_alert_details
    FROM ai_monitoring.alert_h ah
    JOIN ai_monitoring.alert_details_s ads ON ah.alert_hk = ads.alert_hk
    WHERE ah.alert_hk = v_alert_hk
    AND ah.tenant_hk = v_tenant_hk
    AND ads.load_end_date IS NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ALERT_NOT_FOUND',
            'message', 'Alert not found or access denied'
        );
    END IF;
    
    -- Zero Trust access validation for acknowledgment
    SELECT access_granted, risk_score, access_reason
    INTO v_access_check
    FROM ai_monitoring.validate_zero_trust_access(
        v_user_hk,
        'ai_monitoring/alerts/' || p_request->>'alert_id',
        'UPDATE',
        jsonb_build_object(
            'operation', 'acknowledge',
            'alert_severity', v_alert_details.severity,
            'alert_type', v_alert_details.alert_type
        )
    );
    
    IF NOT v_access_check.access_granted THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ACCESS_DENIED',
            'message', v_access_check.access_reason
        );
    END IF;
    
    -- Check if alert is already acknowledged
    IF v_alert_details.status IN ('ACKNOWLEDGED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ALERT_ALREADY_ACKNOWLEDGED',
            'message', format('Alert is already in status: %s', v_alert_details.status)
        );
    END IF;
    
    -- Update alert status to acknowledged
    UPDATE ai_monitoring.alert_details_s
    SET load_end_date = util.current_load_date()
    WHERE alert_hk = v_alert_hk
    AND load_end_date IS NULL;
    
    INSERT INTO ai_monitoring.alert_details_s (
        alert_hk,
        load_date,
        hash_diff,
        severity,
        alert_type,
        title,
        message_encrypted,
        metadata_encrypted,
        status,
        acknowledged_by_hk,
        acknowledged_date,
        alert_authenticity_score,
        false_positive_probability,
        security_impact_assessment,
        response_required_by,
        escalation_chain,
        tenant_hk,
        record_source
    )
    SELECT 
        alert_hk,
        util.current_load_date(),
        util.hash_binary(alert_bk || 'ACKNOWLEDGED' || v_user_hk::TEXT),
        severity,
        alert_type,
        title,
        message_encrypted,
        metadata_encrypted,
        'ACKNOWLEDGED',
        v_user_hk,
        CURRENT_TIMESTAMP,
        alert_authenticity_score,
        false_positive_probability,
        security_impact_assessment,
        response_required_by,
        escalation_chain,
        tenant_hk,
        'ALERT_ACKNOWLEDGMENT'
    FROM ai_monitoring.alert_details_s
    WHERE alert_hk = v_alert_hk
    AND load_end_date = util.current_load_date();
    
    -- Log acknowledgment as security event
    PERFORM ai_monitoring.log_security_event(
        'ALERT_ACKNOWLEDGED',
        'INFO',
        format('Alert acknowledged by user: %s (%s)', 
               encode(v_user_hk, 'hex'), v_alert_details.alert_type),
        inet_client_addr(),
        v_user_hk,
        jsonb_build_object(
            'alert_hk', encode(v_alert_hk, 'hex'),
            'alert_severity', v_alert_details.severity,
            'alert_type', v_alert_details.alert_type,
            'acknowledgment_notes', p_request->>'notes'
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Alert acknowledged successfully',
        'alert_id', p_request->>'alert_id',
        'acknowledged_at', CURRENT_TIMESTAMP,
        'acknowledged_by', encode(v_user_hk, 'hex'),
        'zero_trust_risk_score', v_access_check.risk_score
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'ACKNOWLEDGMENT_FAILED',
        'message', 'Failed to acknowledge alert'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================
-- HISTORICAL ANALYSIS (Zero Trust)
-- =====================================================================

-- Historical data with Zero Trust protection
CREATE OR REPLACE FUNCTION api.ai_monitoring_get_entity_timeline(p_request JSONB)
RETURNS JSONB AS $$
DECLARE
    v_user_hk BYTEA;
    v_tenant_hk BYTEA;
    v_access_check RECORD;
    v_entity_hk BYTEA;
    v_timeline JSONB := '[]'::JSONB;
    v_entry RECORD;
    v_start_date TIMESTAMP WITH TIME ZONE;
    v_end_date TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Validate authentication
    SELECT 
        is_valid, user_hk, tenant_hk, message
    INTO v_access_check
    FROM auth.validate_token_comprehensive(
        p_request->>'auth_token',
        inet_client_addr(),
        p_request->>'user_agent',
        'ai_monitoring_get_entity_timeline'
    );
    
    IF NOT v_access_check.is_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'AUTHENTICATION_FAILED',
            'message', v_access_check.message
        );
    END IF;
    
    v_user_hk := v_access_check.user_hk;
    v_tenant_hk := v_access_check.tenant_hk;
    
    -- Parse entity_id
    IF NOT (p_request ? 'entity_id') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'MISSING_ENTITY_ID',
            'message', 'Entity ID is required'
        );
    END IF;
    
    v_entity_hk := decode(p_request->>'entity_id', 'hex');
    
    -- Zero Trust access validation
    SELECT access_granted, risk_score, access_reason
    INTO v_access_check
    FROM ai_monitoring.validate_zero_trust_access(
        v_user_hk,
        'ai_monitoring/entities/' || p_request->>'entity_id' || '/timeline',
        'READ',
        jsonb_build_object('operation', 'historical_analysis')
    );
    
    IF NOT v_access_check.access_granted THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ACCESS_DENIED',
            'message', v_access_check.access_reason
        );
    END IF;
    
    -- Parse date range
    v_start_date := COALESCE(
        (p_request->>'start_date')::TIMESTAMP WITH TIME ZONE,
        CURRENT_TIMESTAMP - INTERVAL '30 days'
    );
    v_end_date := COALESCE(
        (p_request->>'end_date')::TIMESTAMP WITH TIME ZONE,
        CURRENT_TIMESTAMP
    );
    
    -- Build timeline from analysis data
    FOR v_entry IN
        SELECT 
            'analysis' as event_type,
            encode(aars.analysis_hk, 'hex') as event_id,
            aars.analysis_type,
            aars.ai_provider,
            aars.confidence_score,
            CASE 
                WHEN v_access_check.risk_score <= 40 THEN 
                    'Analysis completed successfully'
                ELSE '[REDACTED - Historical data access restricted]'
            END as description,
            aars.processing_time_ms,
            aars.load_date as event_timestamp
        FROM ai_monitoring.ai_analysis_results_s aars
        JOIN ai_monitoring.entity_analysis_l eal ON aars.analysis_hk = eal.analysis_hk
        WHERE eal.entity_hk = v_entity_hk
        AND eal.tenant_hk = v_tenant_hk
        AND aars.load_date BETWEEN v_start_date AND v_end_date
        AND aars.load_end_date IS NULL
        
        UNION ALL
        
        SELECT 
            'alert' as event_type,
            encode(ads.alert_hk, 'hex') as event_id,
            ads.alert_type,
            'SYSTEM' as ai_provider,
            ads.alert_authenticity_score,
            CASE 
                WHEN v_access_check.risk_score <= 40 THEN ads.title
                ELSE '[REDACTED - Alert details restricted]'
            END as description,
            NULL as processing_time_ms,
            ads.load_date as event_timestamp
        FROM ai_monitoring.alert_details_s ads
        JOIN ai_monitoring.analysis_alert_l aal ON ads.alert_hk = aal.alert_hk
        JOIN ai_monitoring.entity_analysis_l eal ON aal.analysis_hk = eal.analysis_hk
        WHERE eal.entity_hk = v_entity_hk
        AND eal.tenant_hk = v_tenant_hk
        AND ads.load_date BETWEEN v_start_date AND v_end_date
        AND ads.load_end_date IS NULL
        
        ORDER BY event_timestamp DESC
        LIMIT 100
    LOOP
        v_timeline := v_timeline || jsonb_build_object(
            'event_type', v_entry.event_type,
            'event_id', v_entry.event_id,
            'event_subtype', v_entry.analysis_type,
            'provider', v_entry.ai_provider,
            'confidence_score', v_entry.confidence_score,
            'description', v_entry.description,
            'processing_time_ms', v_entry.processing_time_ms,
            'timestamp', v_entry.event_timestamp
        );
    END LOOP;
    
    -- Log timeline access
    PERFORM ai_monitoring.log_security_event(
        'TIMELINE_ACCESSED',
        'INFO',
        format('Historical timeline accessed for entity %s', p_request->>'entity_id'),
        inet_client_addr(),
        v_user_hk,
        jsonb_build_object(
            'entity_id', p_request->>'entity_id',
            'date_range', jsonb_build_object(
                'start_date', v_start_date,
                'end_date', v_end_date
            ),
            'events_returned', jsonb_array_length(v_timeline)
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'entity_id', p_request->>'entity_id',
        'timeline', v_timeline,
        'date_range', jsonb_build_object(
            'start_date', v_start_date,
            'end_date', v_end_date
        ),
        'zero_trust_risk_score', v_access_check.risk_score,
        'data_access_level', 
            CASE WHEN v_access_check.risk_score <= 40 THEN 'FULL' ELSE 'RESTRICTED' END
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'TIMELINE_QUERY_FAILED',
        'message', 'Failed to retrieve entity timeline'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================
-- SYSTEM HEALTH AND MONITORING
-- =====================================================================

-- Zero Trust system health check
CREATE OR REPLACE FUNCTION api.ai_monitoring_system_health(p_request JSONB)
RETURNS JSONB AS $$
DECLARE
    v_user_hk BYTEA;
    v_tenant_hk BYTEA;
    v_access_check RECORD;
    v_health_data JSONB;
    v_entity_count INTEGER;
    v_alert_count INTEGER;
    v_analysis_count INTEGER;
    v_security_events INTEGER;
BEGIN
    -- Validate authentication
    SELECT 
        is_valid, user_hk, tenant_hk, message
    INTO v_access_check
    FROM auth.validate_token_comprehensive(
        p_request->>'auth_token',
        inet_client_addr(),
        p_request->>'user_agent',
        'ai_monitoring_system_health'
    );
    
    IF NOT v_access_check.is_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'AUTHENTICATION_FAILED',
            'message', v_access_check.message
        );
    END IF;
    
    v_user_hk := v_access_check.user_hk;
    v_tenant_hk := v_access_check.tenant_hk;
    
    -- Zero Trust access validation
    SELECT access_granted, risk_score, access_reason
    INTO v_access_check
    FROM ai_monitoring.validate_zero_trust_access(
        v_user_hk,
        'ai_monitoring/system/health',
        'READ',
        jsonb_build_object('operation', 'system_health_check')
    );
    
    IF NOT v_access_check.access_granted THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ACCESS_DENIED',
            'message', v_access_check.access_reason
        );
    END IF;
    
    -- Gather system metrics (tenant-scoped)
    SELECT COUNT(*) INTO v_entity_count
    FROM ai_monitoring.monitored_entity_h
    WHERE tenant_hk = v_tenant_hk;
    
    SELECT COUNT(*) INTO v_alert_count
    FROM ai_monitoring.alert_h ah
    JOIN ai_monitoring.alert_details_s ads ON ah.alert_hk = ads.alert_hk
    WHERE ah.tenant_hk = v_tenant_hk
    AND ads.status IN ('OPEN', 'ACKNOWLEDGED')
    AND ads.load_end_date IS NULL;
    
    SELECT COUNT(*) INTO v_analysis_count
    FROM ai_monitoring.ai_analysis_h
    WHERE tenant_hk = v_tenant_hk
    AND load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours';
    
    SELECT COUNT(*) INTO v_security_events
    FROM ai_monitoring.zt_security_events_h seh
    JOIN ai_monitoring.zt_security_events_s ses ON seh.security_event_hk = ses.security_event_hk
    WHERE seh.tenant_hk = v_tenant_hk
    AND ses.severity IN ('HIGH', 'CRITICAL')
    AND ses.event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    AND ses.load_end_date IS NULL;
    
    -- Build health response
    v_health_data := jsonb_build_object(
        'system_status', 'OPERATIONAL',
        'tenant_id', encode(v_tenant_hk, 'hex'),
        'metrics', jsonb_build_object(
            'monitored_entities', v_entity_count,
            'active_alerts', v_alert_count,
            'analyses_24h', v_analysis_count,
            'security_events_24h', v_security_events
        ),
        'health_score', CASE 
            WHEN v_security_events = 0 AND v_alert_count < 10 THEN 95
            WHEN v_security_events <= 2 AND v_alert_count < 20 THEN 85
            WHEN v_security_events <= 5 AND v_alert_count < 50 THEN 75
            ELSE 60
        END,
        'zero_trust_status', jsonb_build_object(
            'risk_score', v_access_check.risk_score,
            'security_posture', CASE 
                WHEN v_access_check.risk_score <= 30 THEN 'STRONG'
                WHEN v_access_check.risk_score <= 60 THEN 'MODERATE'
                ELSE 'ELEVATED'
            END
        ),
        'last_updated', CURRENT_TIMESTAMP
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'health_data', v_health_data,
        'access_level', CASE 
            WHEN v_access_check.risk_score <= 30 THEN 'ADMINISTRATOR'
            WHEN v_access_check.risk_score <= 60 THEN 'OPERATOR'
            ELSE 'LIMITED'
        END
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'HEALTH_CHECK_FAILED',
        'message', 'System health check failed'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================
-- PERMISSIONS
-- =====================================================================

-- Grant execute permissions on API functions
GRANT EXECUTE ON FUNCTION api.ai_monitoring_ingest TO authenticated_users, app_user;
GRANT EXECUTE ON FUNCTION api.ai_monitoring_get_alerts TO authenticated_users, app_user;
GRANT EXECUTE ON FUNCTION api.ai_monitoring_acknowledge_alert TO authenticated_users, app_user;
GRANT EXECUTE ON FUNCTION api.ai_monitoring_get_entity_timeline TO authenticated_users, app_user;
GRANT EXECUTE ON FUNCTION api.ai_monitoring_system_health TO authenticated_users, app_user;

-- =====================================================================
-- COMPLETION LOG
-- =====================================================================

DO $$
DECLARE
    v_deployment_id INTEGER;
BEGIN
    SELECT deployment_id INTO v_deployment_id 
    FROM util.deployment_log 
    WHERE deployment_name = 'AI_MONITORING_API_V1' 
    ORDER BY deployment_start DESC 
    LIMIT 1;
    
    PERFORM util.log_deployment_complete(
        v_deployment_id,
        TRUE,
        'AI Monitoring API endpoints deployed successfully'
    );
    
    RAISE NOTICE 'AI Monitoring API deployment completed!';
END $$; 