-- FUNCTION: api.ai_video_upload(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_video_upload(jsonb);

CREATE OR REPLACE FUNCTION api.ai_video_upload(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_tenant_id VARCHAR(255);
    v_ai_session_id VARCHAR(255);
    v_camera_id VARCHAR(255);
    v_video_path TEXT;
    v_file_size BIGINT;
    v_duration INTEGER;
    v_recording_timestamp TIMESTAMP WITH TIME ZONE;
    v_ai_analysis JSONB;
    v_importance_score DECIMAL(5,4);
    v_tenant_hk BYTEA;
    v_session_hk BYTEA;
    v_camera_hk BYTEA;
    v_upload_result RECORD;
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_ai_session_id := p_request->>'aiSessionId';
    v_camera_id := p_request->>'cameraId';
    v_video_path := p_request->>'videoPath';
    v_file_size := (p_request->>'fileSize')::BIGINT;
    v_duration := (p_request->>'duration')::INTEGER;
    v_recording_timestamp := (p_request->>'recordingTimestamp')::TIMESTAMP WITH TIME ZONE;
    v_ai_analysis := p_request->'aiAnalysis';
    v_importance_score := COALESCE((p_request->>'importanceScore')::DECIMAL, 0.50);
    
    -- Validate required parameters
    IF v_tenant_id IS NULL OR v_camera_id IS NULL OR v_video_path IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameters: tenantId, cameraId, videoPath',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get hash keys
    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h WHERE tenant_bk = v_tenant_id;
    
    IF v_ai_session_id IS NOT NULL THEN
        v_session_hk := decode(v_ai_session_id, 'hex');
    END IF;
    
    v_camera_hk := decode(v_camera_id, 'hex');
    
    -- Call AI upload function
    SELECT * INTO v_upload_result
    FROM media.ai_upload_video(
        v_tenant_hk,
        v_session_hk,
        v_camera_hk,
        v_video_path,
        v_file_size,
        v_duration,
        v_recording_timestamp,
        v_ai_analysis,
        v_importance_score
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'AI video uploaded successfully',
        'data', jsonb_build_object(
            'videoId', encode(v_upload_result.media_file_hk, 'hex'),
            'uploadStatus', v_upload_result.upload_status,
            'retentionDecision', v_upload_result.retention_decision,
            'estimatedRetentionDays', v_upload_result.estimated_retention_days,
            'importanceScore', v_importance_score,
            'uploadTimestamp', CURRENT_TIMESTAMP::TEXT
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error uploading AI video',
        'error_code', 'AI_UPLOAD_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$BODY$;

ALTER FUNCTION api.ai_video_upload(jsonb)
    OWNER TO postgres;

COMMENT ON FUNCTION api.ai_video_upload(jsonb)
    IS 'POST /api/v1/ai/videos/upload - AI system endpoint for uploading analyzed video content.';


-- FUNCTION: api.ai_secure_chat(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_secure_chat(jsonb);

CREATE OR REPLACE FUNCTION api.ai_secure_chat(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    -- Request parameters
    v_question TEXT;
    v_context_type VARCHAR(50);
    v_session_id VARCHAR(255);
    v_horse_ids TEXT[];
    v_tenant_id VARCHAR(255);
    v_user_id VARCHAR(255);
    v_ip_address INET;
    v_user_agent TEXT;
    
    -- Internal variables
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_interaction_bk VARCHAR(255);
    v_interaction_hk BYTEA;
    v_session_hk BYTEA;
    v_ai_response TEXT;
    v_processing_start TIMESTAMP WITH TIME ZONE;
    v_processing_time_ms INTEGER;
    v_confidence_score DECIMAL(5,4);
    v_tokens_input INTEGER;
    v_tokens_output INTEGER;
    v_security_level VARCHAR(20) := 'safe';
    
    -- Validation variables
    v_has_ai_access BOOLEAN;
    v_permissions TEXT[];
    v_data_filters JSONB;
    
    -- Rate limiting and safety variables
    v_recent_requests INTEGER;
    v_content_safety_level VARCHAR(20);
    v_estimated_cost DECIMAL(10,6);
    
BEGIN
    v_processing_start := CURRENT_TIMESTAMP;
    
    -- Extract parameters from JSON request
    v_question := p_request->>'question';
    v_context_type := COALESCE(p_request->>'contextType', 'general');
    v_session_id := p_request->>'sessionId';
    v_horse_ids := ARRAY(SELECT jsonb_array_elements_text(p_request->'horseIds'));
    v_tenant_id := p_request->>'tenantId';
    v_user_id := p_request->>'userId';
    v_ip_address := (p_request->>'ip_address')::INET;
    v_user_agent := p_request->>'user_agent';
    
    -- Validate required parameters
    IF v_question IS NULL OR LENGTH(v_question) < 1 THEN
        PERFORM audit.log_security_event(
            'AI_INVALID_REQUEST',
            'MEDIUM',
            'AI chat request missing question',
            COALESCE(v_ip_address, '0.0.0.0'::inet),
            COALESCE(v_user_agent, 'Unknown'),
            NULL,
            'MEDIUM',
            jsonb_build_object(
                'tenant_id', v_tenant_id,
                'user_id', v_user_id,
                'context_type', v_context_type,
                'timestamp', NOW()
            )
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Question is required',
            'error_code', 'MISSING_QUESTION'
        );
    END IF;
    
    -- Get tenant hash key
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
    WHERE tps.tenant_name = v_tenant_id -- Assuming tenant_id is tenant name
    AND tps.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        PERFORM audit.log_security_event(
            'AI_INVALID_TENANT',
            'HIGH',
            'AI chat request for invalid tenant: ' || COALESCE(v_tenant_id, 'null'),
            v_ip_address,
            v_user_agent,
            NULL,
            'HIGH',
            jsonb_build_object(
                'tenant_id', v_tenant_id,
                'user_id', v_user_id,
                'timestamp', NOW()
            )
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid tenant',
            'error_code', 'INVALID_TENANT'
        );
    END IF;
    
    -- Get user hash key
    SELECT user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
    WHERE ups.email = v_user_id -- Assuming user_id is email
    AND uh.tenant_hk = v_tenant_hk
    AND ups.load_end_date IS NULL;
    
    IF v_user_hk IS NULL THEN
        PERFORM audit.log_security_event(
            'AI_INVALID_USER',
            'HIGH',
            'AI chat request for invalid user: ' || COALESCE(v_user_id, 'null'),
            v_ip_address,
            v_user_agent,
            NULL,
            'HIGH',
            jsonb_build_object(
                'tenant_id', v_tenant_id,
                'user_id', v_user_id,
                'timestamp', NOW()
            )
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid user',
            'error_code', 'INVALID_USER'
        );
    END IF;
    
    -- Validate AI access permissions using existing auth.validate_ai_access function
    SELECT p_has_access, p_permissions, p_data_filters 
    INTO v_has_ai_access, v_permissions, v_data_filters
    FROM auth.validate_ai_access(v_user_id, v_tenant_id, 'ai_chat');
    
    -- If user doesn't have AI access, deny the request
    IF NOT COALESCE(v_has_ai_access, false) THEN
        PERFORM audit.log_security_event(
            'AI_ACCESS_DENIED',
            'HIGH',
            'AI access denied for user: ' || v_user_id,
            v_ip_address,
            v_user_agent,
            v_user_hk,
            'HIGH',
            jsonb_build_object(
                'tenant_id', v_tenant_id,
                'user_id', v_user_id,
                'context_type', v_context_type,
                'requested_feature', 'ai_chat',
                'timestamp', NOW()
            )
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Access denied - insufficient AI permissions',
            'error_code', 'ACCESS_DENIED'
        );
    END IF;
    
    -- Check rate limits (configurable per tenant/user)
    SELECT COUNT(*) INTO v_recent_requests
    FROM business.ai_interaction_h aih
    JOIN business.ai_interaction_details_s aids ON aih.interaction_hk = aids.interaction_hk
    WHERE aids.user_bk = v_user_id
    AND aids.interaction_timestamp > CURRENT_TIMESTAMP - INTERVAL '1 minute'
    AND aids.load_end_date IS NULL
    AND aih.tenant_hk = v_tenant_hk;
    
    IF v_recent_requests >= 10 THEN -- Configurable rate limit (could be stored in tenant settings)
        PERFORM audit.log_security_event(
            'AI_RATE_LIMIT_EXCEEDED',
            'MEDIUM',
            'Rate limit exceeded for user: ' || v_user_id || ' (' || v_recent_requests || ' requests in last minute)',
            v_ip_address,
            v_user_agent,
            v_user_hk,
            'MEDIUM',
            jsonb_build_object(
                'tenant_id', v_tenant_id,
                'user_id', v_user_id,
                'recent_requests', v_recent_requests,
                'rate_limit', 10,
                'window_minutes', 1,
                'timestamp', NOW()
            )
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Rate limit exceeded. Please wait before making another request.',
            'error_code', 'RATE_LIMIT_EXCEEDED',
            'data', jsonb_build_object(
                'retry_after_seconds', 60,
                'requests_made', v_recent_requests,
                'rate_limit', 10,
                'window', '1 minute'
            )
        );
    END IF;
    
    -- Content safety analysis
    BEGIN
        SELECT safety_level INTO v_content_safety_level
        FROM business.analyze_content_safety(v_question, v_context_type);
        
        IF v_content_safety_level IN ('unsafe', 'high_risk') THEN
            PERFORM audit.log_security_event(
                'AI_UNSAFE_CONTENT_DETECTED',
                'HIGH',
                'Unsafe content detected in AI request from user: ' || v_user_id,
                v_ip_address,
                v_user_agent,
                v_user_hk,
                'HIGH',
                jsonb_build_object(
                    'tenant_id', v_tenant_id,
                    'user_id', v_user_id,
                    'context_type', v_context_type,
                    'safety_level', v_content_safety_level,
                    'question_hash', encode(digest(v_question, 'sha256'), 'hex'),
                    'timestamp', NOW()
                )
            );
            
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Content does not meet safety guidelines. Please modify your request.',
                'error_code', 'UNSAFE_CONTENT',
                'data', jsonb_build_object(
                    'safety_level', v_content_safety_level,
                    'guidelines_url', '/ai/content-guidelines'
                )
            );
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- If content safety function doesn't exist or fails, default to moderate safety
        v_content_safety_level := 'moderate';
        
        PERFORM audit.log_security_event(
            'AI_CONTENT_SAFETY_ERROR',
            'MEDIUM',
            'Content safety analysis failed for user: ' || v_user_id || ' - ' || SQLERRM,
            v_ip_address,
            v_user_agent,
            v_user_hk,
            'MEDIUM',
            jsonb_build_object(
                'tenant_id', v_tenant_id,
                'user_id', v_user_id,
                'error_message', SQLERRM,
                'timestamp', NOW()
            )
        );
    END;
    
    -- Generate interaction business key
    v_interaction_bk := 'ai-int-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD-HH24MISS') || '-' || 
                        encode(gen_random_bytes(8), 'hex');
    
    -- TODO: Call actual AI provider (OpenAI, Anthropic, etc.)
    -- For now, simulate AI response
    v_ai_response := 'This is a simulated AI response to: ' || v_question || 
                     ' (Context: ' || v_context_type || ')';
    v_confidence_score := 0.85;
    v_tokens_input := LENGTH(v_question) / 4; -- Rough token estimate
    v_tokens_output := LENGTH(v_ai_response) / 4;
    
    -- Calculate estimated cost (GPT-4 Turbo pricing as of 2024)
    -- Input: $0.01 per 1K tokens, Output: $0.03 per 1K tokens
    v_estimated_cost := (v_tokens_input * 0.01 + v_tokens_output * 0.03) / 1000.0;
    
    -- Calculate processing time
    v_processing_time_ms := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_processing_start)) * 1000;
    
    -- Store AI interaction in business schema using existing function
    SELECT p_interaction_hk INTO v_interaction_hk
    FROM business.store_ai_interaction(
        v_interaction_bk,
        v_user_id,
        v_tenant_id,
        v_question,
        v_ai_response,
        'gpt-4-turbo',
        v_session_id,
        v_context_type
    );
    
    -- Log successful AI interaction with enhanced metrics
    PERFORM audit.log_security_event(
        'AI_CHAT_SUCCESS',
        'LOW',
        'Successful AI chat interaction for user: ' || v_user_id,
        v_ip_address,
        v_user_agent,
        v_user_hk,
        'LOW',
        jsonb_build_object(
            'tenant_id', v_tenant_id,
            'user_id', v_user_id,
            'context_type', v_context_type,
            'interaction_id', v_interaction_bk,
            'processing_time_ms', v_processing_time_ms,
            'tokens_used', v_tokens_input + v_tokens_output,
            'estimated_cost_usd', v_estimated_cost,
            'content_safety_level', v_content_safety_level,
            'rate_limit_remaining', GREATEST(0, 10 - v_recent_requests - 1),
            'timestamp', NOW()
        )
    );
    
    -- Return success response with enhanced data
    RETURN jsonb_build_object(
        'success', true,
        'message', 'AI response generated successfully',
        'data', jsonb_build_object(
            'response', v_ai_response,
            'interactionId', v_interaction_bk,
            'sessionId', v_session_id,
            'confidence', v_confidence_score,
            'processingTimeMs', v_processing_time_ms,
            'tokensUsed', jsonb_build_object(
                'input', v_tokens_input,
                'output', v_tokens_output,
                'total', v_tokens_input + v_tokens_output
            ),
            'contextType', v_context_type,
            'securityLevel', v_security_level,
            'contentSafetyLevel', v_content_safety_level,
            'estimatedCostUsd', v_estimated_cost,
            'rateLimitInfo', jsonb_build_object(
                'remaining', GREATEST(0, 10 - v_recent_requests - 1),
                'resetIn', 60,
                'limit', 10
            )
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    -- Log system error
    PERFORM audit.log_security_event(
        'AI_SYSTEM_ERROR',
        'CRITICAL',
        'System error during AI chat for user: ' || COALESCE(v_user_id, 'unknown'),
        COALESCE(v_ip_address, '0.0.0.0'::inet),
        COALESCE(v_user_agent, 'unknown'),
        v_user_hk,
        'CRITICAL',
        jsonb_build_object(
            'tenant_id', v_tenant_id,
            'user_id', v_user_id,
            'context_type', v_context_type,
            'error_message', SQLERRM,
            'error_state', SQLSTATE,
            'timestamp', NOW()
        )
    );
    
    RETURN jsonb_build_object(
        'success', false,
        'message', 'An unexpected error occurred during AI processing',
        'error_code', 'AI_SYSTEM_ERROR',
        'debug_info', jsonb_build_object(
            'error', SQLERRM,
            'sqlstate', SQLSTATE
        )
    );
END;
$BODY$;

ALTER FUNCTION api.ai_secure_chat(jsonb)
    OWNER TO postgres;

-- FUNCTION: api.ai_retention_cleanup(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_retention_cleanup(jsonb);

CREATE OR REPLACE FUNCTION api.ai_retention_cleanup(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_tenant_id VARCHAR(255);
    v_camera_id VARCHAR(255);
    v_tenant_hk BYTEA;
    v_camera_hk BYTEA;
    v_cleanup_result RECORD;
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_camera_id := p_request->>'cameraId';
    
    -- Validate parameters
    IF v_tenant_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameter: tenantId',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get hash keys
    SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h WHERE tenant_bk = v_tenant_id;
    
    IF v_camera_id IS NOT NULL THEN
        v_camera_hk := decode(v_camera_id, 'hex');
    END IF;
    
    -- Execute retention cleanup
    SELECT * INTO v_cleanup_result
    FROM media.manage_ai_video_retention(v_tenant_hk, v_camera_hk);
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'AI video retention cleanup completed',
        'data', jsonb_build_object(
            'videosProcessed', v_cleanup_result.videos_processed,
            'videosDeleted', v_cleanup_result.videos_deleted,
            'videosCompressed', v_cleanup_result.videos_compressed,
            'importantSegmentsExtracted', v_cleanup_result.important_segments_extracted,
            'storageFreedGb', v_cleanup_result.storage_freed_gb,
            'cleanupTimestamp', CURRENT_TIMESTAMP::TEXT
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error during retention cleanup',
        'error_code', 'RETENTION_CLEANUP_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$BODY$;

ALTER FUNCTION api.ai_retention_cleanup(jsonb)
    OWNER TO postgres;

COMMENT ON FUNCTION api.ai_retention_cleanup(jsonb)
    IS 'POST /api/v1/ai/videos/retention/cleanup - Triggers AI-optimized retention cleanup process.';


-- FUNCTION: api.ai_monitoring_system_health(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_monitoring_system_health(jsonb);

CREATE OR REPLACE FUNCTION api.ai_monitoring_system_health(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE SECURITY DEFINER PARALLEL UNSAFE
AS $BODY$
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
$BODY$;

ALTER FUNCTION api.ai_monitoring_system_health(jsonb)
    OWNER TO postgres;


-- FUNCTION: api.ai_monitoring_ingest(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_monitoring_ingest(jsonb);

CREATE OR REPLACE FUNCTION api.ai_monitoring_ingest(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
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
$BODY$;

ALTER FUNCTION api.ai_monitoring_ingest(jsonb)
    OWNER TO postgres;


-- FUNCTION: api.ai_monitoring_get_entity_timeline(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_monitoring_get_entity_timeline(jsonb);

CREATE OR REPLACE FUNCTION api.ai_monitoring_get_entity_timeline(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE SECURITY DEFINER PARALLEL UNSAFE
AS $BODY$
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
$BODY$;

ALTER FUNCTION api.ai_monitoring_get_entity_timeline(jsonb)
    OWNER TO postgres;


-- FUNCTION: api.ai_monitoring_get_alerts(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_monitoring_get_alerts(jsonb);

CREATE OR REPLACE FUNCTION api.ai_monitoring_get_alerts(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE SECURITY DEFINER PARALLEL UNSAFE
AS $BODY$
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
$BODY$;

ALTER FUNCTION api.ai_monitoring_get_alerts(jsonb)
    OWNER TO postgres;


-- FUNCTION: api.ai_monitoring_acknowledge_alert(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_monitoring_acknowledge_alert(jsonb);

CREATE OR REPLACE FUNCTION api.ai_monitoring_acknowledge_alert(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE SECURITY DEFINER PARALLEL UNSAFE
AS $BODY$
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
$BODY$;

ALTER FUNCTION api.ai_monitoring_acknowledge_alert(jsonb)
    OWNER TO postgres;


-- FUNCTION: api.ai_log_observation(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_log_observation(jsonb);

CREATE OR REPLACE FUNCTION api.ai_log_observation(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_tenant_hk BYTEA;
    v_observation_hk BYTEA;
    v_observation_bk VARCHAR(255);
    v_alert_hk BYTEA;
    v_alert_bk VARCHAR(255);
    
    -- Extracted parameters
    v_tenant_id VARCHAR(255);
    v_observation_type VARCHAR(50);
    v_severity_level VARCHAR(20);
    v_confidence_score DECIMAL(5,4);
    v_entity_id VARCHAR(255);
    v_sensor_id VARCHAR(255);
    v_observation_data JSONB;
    v_visual_evidence JSONB;
    v_recommended_actions TEXT[];
    v_ip_address INET;
    v_user_agent TEXT;
    
    -- Alert generation variables
    v_should_create_alert BOOLEAN := false;
    v_alert_type VARCHAR(50);
    v_priority_level INTEGER;
    v_escalation_required BOOLEAN := false;
    v_primary_recipients TEXT[];
    v_escalation_recipients TEXT[];
    
BEGIN
    -- Extract and validate parameters
    v_tenant_id := p_request->>'tenantId';
    v_observation_type := p_request->>'observationType';
    v_severity_level := p_request->>'severityLevel';
    v_confidence_score := COALESCE((p_request->>'confidenceScore')::DECIMAL, 0.75);
    v_entity_id := p_request->>'entityId';
    v_sensor_id := p_request->>'sensorId';
    v_observation_data := COALESCE(p_request->'observationData', '{}'::JSONB);
    v_visual_evidence := p_request->'visualEvidence';
    v_recommended_actions := CASE 
        WHEN p_request->'recommendedActions' IS NOT NULL 
        THEN ARRAY(SELECT jsonb_array_elements_text(p_request->'recommendedActions'))
        ELSE ARRAY[]::TEXT[]
    END;
    v_ip_address := COALESCE((p_request->>'ip_address')::INET, '127.0.0.1'::INET);
    v_user_agent := COALESCE(p_request->>'user_agent', 'AI System');
    
    -- Validate required parameters
    IF v_tenant_id IS NULL OR v_observation_type IS NULL OR v_severity_level IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameters: tenantId, observationType, severityLevel',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get tenant hash key
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h 
    WHERE tenant_bk = v_tenant_id;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid tenant ID',
            'error_code', 'INVALID_TENANT'
        );
    END IF;
    
    -- Generate observation business key and hash key
    v_observation_bk := 'ai-obs-' || v_observation_type || '-' || 
                        to_char(CURRENT_TIMESTAMP, 'YYYYMMDD-HH24MISS') || '-' || 
                        encode(gen_random_bytes(4), 'hex');
    v_observation_hk := util.hash_binary(v_observation_bk);
    
    -- Insert observation hub record
    INSERT INTO business.ai_observation_h (
        ai_observation_hk, ai_observation_bk, tenant_hk, 
        load_date, record_source
    ) VALUES (
        v_observation_hk, v_observation_bk, v_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    -- Get entity and sensor hash keys if provided
    DECLARE
        v_entity_hk BYTEA;
        v_sensor_hk BYTEA;
    BEGIN
        IF v_entity_id IS NOT NULL THEN
            SELECT entity_hk INTO v_entity_hk
            FROM business.monitored_entity_h 
            WHERE entity_bk = v_entity_id AND tenant_hk = v_tenant_hk;
        END IF;
        
        IF v_sensor_id IS NOT NULL THEN
            SELECT sensor_hk INTO v_sensor_hk
            FROM business.monitoring_sensor_h 
            WHERE sensor_bk = v_sensor_id AND tenant_hk = v_tenant_hk;
        END IF;
    END;
    
    -- Insert observation details satellite
    INSERT INTO business.ai_observation_details_s (
        ai_observation_hk, load_date, load_end_date, hash_diff,
        entity_hk, sensor_hk, observation_type, observation_category,
        severity_level, confidence_score, observation_title, observation_description,
        observation_data, visual_evidence, observation_timestamp,
        recommended_actions, status, record_source
    ) VALUES (
        v_observation_hk, util.current_load_date(), NULL,
        util.hash_binary(v_observation_bk || v_observation_type || v_severity_level),
        v_entity_hk, v_sensor_hk, v_observation_type,
        CASE v_observation_type
            WHEN 'behavior_anomaly' THEN 'behavior'
            WHEN 'health_concern' THEN 'health'
            WHEN 'safety_concern' THEN 'safety'
            WHEN 'equipment_malfunction' THEN 'maintenance'
            WHEN 'security_breach' THEN 'security'
            ELSE 'general'
        END,
        v_severity_level, v_confidence_score,
        INITCAP(REPLACE(v_observation_type, '_', ' ')) || ' Detected',
        'AI-detected ' || v_observation_type || ' with ' || (v_confidence_score * 100)::text || '% confidence',
        v_observation_data, v_visual_evidence, CURRENT_TIMESTAMP,
        v_recommended_actions, 'detected', util.get_record_source()
    );
    
    -- Determine if alert should be created
    v_should_create_alert := CASE
        WHEN v_severity_level IN ('critical', 'emergency') THEN true
        WHEN v_severity_level = 'high' AND v_confidence_score >= 0.85 THEN true
        WHEN v_observation_type IN ('safety_concern', 'security_breach') AND v_confidence_score >= 0.80 THEN true
        ELSE false
    END;
    
    -- Create alert if needed
    IF v_should_create_alert THEN
        -- Determine alert type and priority
        v_alert_type := CASE v_observation_type
            WHEN 'safety_concern' THEN 'immediate_response'
            WHEN 'security_breach' THEN 'security_incident'
            WHEN 'health_concern' THEN 'health_follow_up'
            WHEN 'equipment_malfunction' THEN 'scheduled_maintenance'
            ELSE 'information_only'
        END;
        
        v_priority_level := CASE v_severity_level
            WHEN 'emergency' THEN 1
            WHEN 'critical' THEN 1
            WHEN 'high' THEN 2
            WHEN 'medium' THEN 3
            ELSE 4
        END;
        
        -- Set recipients based on severity and type
        v_primary_recipients := CASE v_severity_level
            WHEN 'emergency' THEN ARRAY['emergency-contact@facility.com', 'facility-manager@facility.com']
            WHEN 'critical' THEN ARRAY['facility-manager@facility.com', 'supervisor@facility.com']
            ELSE ARRAY['supervisor@facility.com']
        END;
        
        v_escalation_recipients := ARRAY['facility-owner@facility.com', 'emergency-contact@facility.com'];
        
        -- Generate alert keys
        v_alert_bk := 'ai-alert-' || v_observation_type || '-' || 
                      to_char(CURRENT_TIMESTAMP, 'YYYYMMDD-HH24MISS') || '-' || 
                      encode(gen_random_bytes(4), 'hex');
        v_alert_hk := util.hash_binary(v_alert_bk);
        
        -- Insert alert hub
        INSERT INTO business.ai_alert_h (
            ai_alert_hk, ai_alert_bk, tenant_hk, 
            load_date, record_source
        ) VALUES (
            v_alert_hk, v_alert_bk, v_tenant_hk,
            util.current_load_date(), util.get_record_source()
        );
        
        -- Insert alert details
        INSERT INTO business.ai_alert_details_s (
            ai_alert_hk, load_date, load_end_date, hash_diff,
            alert_type, alert_category, priority_level, urgency_level,
            alert_title, alert_description, primary_recipients, escalation_recipients,
            notification_channels, alert_created_at, response_required_by,
            auto_escalate_after, alert_status, record_source
        ) VALUES (
            v_alert_hk, util.current_load_date(), NULL,
            util.hash_binary(v_alert_bk || v_alert_type || v_priority_level::text),
            v_alert_type,
            CASE v_observation_type
                WHEN 'safety_concern' THEN 'safety'
                WHEN 'health_concern' THEN 'health'
                WHEN 'security_breach' THEN 'security'
                ELSE 'general'
            END,
            v_priority_level,
            CASE v_priority_level
                WHEN 1 THEN 'immediate'
                WHEN 2 THEN 'within_hour'
                WHEN 3 THEN 'same_day'
                ELSE 'next_day'
            END,
            'AI Alert: ' || INITCAP(REPLACE(v_observation_type, '_', ' ')),
            'AI system detected ' || v_observation_type || ' requiring attention. Confidence: ' || 
            (v_confidence_score * 100)::text || '%',
            v_primary_recipients, v_escalation_recipients,
            CASE v_priority_level
                WHEN 1 THEN ARRAY['sms', 'push', 'email', 'dashboard']
                WHEN 2 THEN ARRAY['push', 'email', 'dashboard']
                ELSE ARRAY['email', 'dashboard']
            END,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP + CASE v_priority_level
                WHEN 1 THEN INTERVAL '15 minutes'
                WHEN 2 THEN INTERVAL '1 hour'
                WHEN 3 THEN INTERVAL '4 hours'
                ELSE INTERVAL '24 hours'
            END,
            CASE v_priority_level
                WHEN 1 THEN INTERVAL '5 minutes'
                WHEN 2 THEN INTERVAL '30 minutes'
                ELSE INTERVAL '2 hours'
            END,
            'active', util.get_record_source()
        );
        
        -- Link observation to alert
        INSERT INTO business.ai_observation_alert_l (
            link_observation_alert_hk, ai_observation_hk, ai_alert_hk, 
            tenant_hk, relationship_type, load_date, record_source
        ) VALUES (
            util.hash_binary(v_observation_bk || v_alert_bk || 'triggered_by'),
            v_observation_hk, v_alert_hk, v_tenant_hk, 'triggered_by',
            util.current_load_date(), util.get_record_source()
        );
    END IF;
    
    -- Log audit event
    PERFORM audit.log_security_event(
        'AI_OBSERVATION_LOGGED',
        CASE v_severity_level
            WHEN 'emergency' THEN 'CRITICAL'
            WHEN 'critical' THEN 'HIGH'
            ELSE 'MEDIUM'
        END,
        'AI observation logged: ' || v_observation_type || ' (' || v_severity_level || ')',
        NULL, 'ai_observation_system', v_ip_address, 'MEDIUM',
        jsonb_build_object(
            'observation_id', v_observation_bk,
            'observation_type', v_observation_type,
            'severity_level', v_severity_level,
            'confidence_score', v_confidence_score,
            'entity_id', v_entity_id,
            'sensor_id', v_sensor_id,
            'alert_created', v_should_create_alert,
            'alert_id', v_alert_bk,
            'user_agent', v_user_agent,
            'timestamp', CURRENT_TIMESTAMP
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'AI observation logged successfully',
        'data', jsonb_build_object(
            'observationId', v_observation_bk,
            'observationType', v_observation_type,
            'severityLevel', v_severity_level,
            'confidenceScore', v_confidence_score,
            'alertCreated', v_should_create_alert,
            'alertId', v_alert_bk,
            'escalationRequired', v_should_create_alert AND v_priority_level <= 2,
            'timestamp', CURRENT_TIMESTAMP
        )
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error logging AI observation',
        'error_code', 'OBSERVATION_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$BODY$;

ALTER FUNCTION api.ai_log_observation(jsonb)
    OWNER TO postgres;


-- FUNCTION: api.ai_get_observations(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_get_observations(jsonb);

CREATE OR REPLACE FUNCTION api.ai_get_observations(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_tenant_id VARCHAR(255);
    v_entity_id VARCHAR(255);
    v_sensor_id VARCHAR(255);
    v_observation_type VARCHAR(50);
    v_severity_level VARCHAR(20);
    v_status VARCHAR(30);
    v_start_date TIMESTAMP WITH TIME ZONE;
    v_end_date TIMESTAMP WITH TIME ZONE;
    v_limit INTEGER;
    v_offset INTEGER;
    
    v_tenant_hk BYTEA;
    v_observations JSONB;
    v_total_count INTEGER;
    
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_entity_id := p_request->>'entityId';
    v_sensor_id := p_request->>'sensorId';
    v_observation_type := p_request->>'observationType';
    v_severity_level := p_request->>'severityLevel';
    v_status := p_request->>'status';
    v_start_date := COALESCE(
        (p_request->>'startDate')::TIMESTAMP WITH TIME ZONE,
        CURRENT_TIMESTAMP - INTERVAL '7 days'
    );
    v_end_date := COALESCE(
        (p_request->>'endDate')::TIMESTAMP WITH TIME ZONE,
        CURRENT_TIMESTAMP
    );
    v_limit := COALESCE((p_request->>'limit')::INTEGER, 50);
    v_offset := COALESCE((p_request->>'offset')::INTEGER, 0);
    
    -- Validate tenant
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h 
    WHERE tenant_bk = v_tenant_id;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid tenant ID',
            'error_code', 'INVALID_TENANT'
        );
    END IF;
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM business.ai_observation_h aoh
    JOIN business.ai_observation_details_s aods ON aoh.ai_observation_hk = aods.ai_observation_hk
    LEFT JOIN business.monitored_entity_h meh ON aods.entity_hk = meh.entity_hk
    LEFT JOIN business.monitoring_sensor_h msh ON aods.sensor_hk = msh.sensor_hk
    WHERE aoh.tenant_hk = v_tenant_hk
    AND aods.load_end_date IS NULL
    AND aods.observation_timestamp BETWEEN v_start_date AND v_end_date
    AND (v_entity_id IS NULL OR meh.entity_bk = v_entity_id)
    AND (v_sensor_id IS NULL OR msh.sensor_bk = v_sensor_id)
    AND (v_observation_type IS NULL OR aods.observation_type = v_observation_type)
    AND (v_severity_level IS NULL OR aods.severity_level = v_severity_level)
    AND (v_status IS NULL OR aods.status = v_status);
    
    -- Get observations
    SELECT jsonb_agg(
        jsonb_build_object(
            'observationId', aoh.ai_observation_bk,
            'observationType', aods.observation_type,
            'observationCategory', aods.observation_category,
            'severityLevel', aods.severity_level,
            'confidenceScore', aods.confidence_score,
            'observationTitle', aods.observation_title,
            'observationDescription', aods.observation_description,
            'observationData', aods.observation_data,
            'visualEvidence', aods.visual_evidence,
            'recommendedActions', aods.recommended_actions,
            'observationTimestamp', aods.observation_timestamp,
            'status', aods.status,
            'acknowledgedBy', aods.acknowledged_by,
            'acknowledgedAt', aods.acknowledged_at,
            'resolvedAt', aods.resolved_at,
            'resolutionNotes', aods.resolution_notes,
            'entityId', meh.entity_bk,
            'sensorId', msh.sensor_bk,
            'processingTimeMs', aods.processing_time_ms,
            'modelVersion', aods.model_version
        ) ORDER BY aods.observation_timestamp DESC
    ) INTO v_observations
    FROM business.ai_observation_h aoh
    JOIN business.ai_observation_details_s aods ON aoh.ai_observation_hk = aods.ai_observation_hk
    LEFT JOIN business.monitored_entity_h meh ON aods.entity_hk = meh.entity_hk
    LEFT JOIN business.monitoring_sensor_h msh ON aods.sensor_hk = msh.sensor_hk
    WHERE aoh.tenant_hk = v_tenant_hk
    AND aods.load_end_date IS NULL
    AND aods.observation_timestamp BETWEEN v_start_date AND v_end_date
    AND (v_entity_id IS NULL OR meh.entity_bk = v_entity_id)
    AND (v_sensor_id IS NULL OR msh.sensor_bk = v_sensor_id)
    AND (v_observation_type IS NULL OR aods.observation_type = v_observation_type)
    AND (v_severity_level IS NULL OR aods.severity_level = v_severity_level)
    AND (v_status IS NULL OR aods.status = v_status)
    LIMIT v_limit OFFSET v_offset;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'AI observations retrieved successfully',
        'data', jsonb_build_object(
            'observations', COALESCE(v_observations, '[]'::JSONB),
            'totalCount', v_total_count,
            'limit', v_limit,
            'offset', v_offset,
            'hasMore', v_total_count > (v_offset + v_limit),
            'filters', jsonb_build_object(
                'tenantId', v_tenant_id,
                'entityId', v_entity_id,
                'sensorId', v_sensor_id,
                'observationType', v_observation_type,
                'severityLevel', v_severity_level,
                'status', v_status,
                'startDate', v_start_date,
                'endDate', v_end_date
            )
        )
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error retrieving AI observations',
        'error_code', 'RETRIEVAL_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$BODY$;

ALTER FUNCTION api.ai_get_observations(jsonb)
    OWNER TO postgres;


-- FUNCTION: api.ai_get_observation_analytics(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_get_observation_analytics(jsonb);

CREATE OR REPLACE FUNCTION api.ai_get_observation_analytics(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_tenant_id VARCHAR(255);
    v_start_date TIMESTAMP WITH TIME ZONE;
    v_end_date TIMESTAMP WITH TIME ZONE;
    v_group_by VARCHAR(20); -- 'hour', 'day', 'week', 'month'
    
    v_tenant_hk BYTEA;
    v_analytics JSONB;
    
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_start_date := COALESCE(
        (p_request->>'startDate')::TIMESTAMP WITH TIME ZONE,
        CURRENT_TIMESTAMP - INTERVAL '30 days'
    );
    v_end_date := COALESCE(
        (p_request->>'endDate')::TIMESTAMP WITH TIME ZONE,
        CURRENT_TIMESTAMP
    );
    v_group_by := COALESCE(p_request->>'groupBy', 'day');
    
    -- Validate tenant
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h 
    WHERE tenant_bk = v_tenant_id;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid tenant ID',
            'error_code', 'INVALID_TENANT'
        );
    END IF;
    
    -- Generate comprehensive analytics
    WITH analytics_base AS (
        SELECT 
            aods.observation_type,
            aods.observation_category,
            aods.severity_level,
            aods.confidence_score,
            aods.observation_timestamp,
            aods.status,
            meh.entity_bk,
            msh.sensor_bk,
            CASE WHEN oal.ai_alert_hk IS NOT NULL THEN 1 ELSE 0 END as has_alert,
            CASE WHEN aods.acknowledged_at IS NOT NULL THEN 1 ELSE 0 END as is_acknowledged,
            CASE WHEN aods.resolved_at IS NOT NULL THEN 1 ELSE 0 END as is_resolved
        FROM business.ai_observation_h aoh
        JOIN business.ai_observation_details_s aods ON aoh.ai_observation_hk = aods.ai_observation_hk
        LEFT JOIN business.monitored_entity_h meh ON aods.entity_hk = meh.entity_hk
        LEFT JOIN business.monitoring_sensor_h msh ON aods.sensor_hk = msh.sensor_hk
        LEFT JOIN business.ai_observation_alert_l oal ON aoh.ai_observation_hk = oal.ai_observation_hk
        WHERE aoh.tenant_hk = v_tenant_hk
        AND aods.load_end_date IS NULL
        AND aods.observation_timestamp BETWEEN v_start_date AND v_end_date
    )
    SELECT jsonb_build_object(
        'summary', jsonb_build_object(
            'totalObservations', COUNT(*),
            'alertsGenerated', SUM(has_alert),
            'acknowledgedCount', SUM(is_acknowledged),
            'resolvedCount', SUM(is_resolved),
            'avgConfidenceScore', ROUND(AVG(confidence_score), 4),
            'dateRange', jsonb_build_object(
                'startDate', v_start_date,
                'endDate', v_end_date,
                'groupBy', v_group_by
            )
        ),
        'byObservationType', (
            SELECT jsonb_object_agg(
                observation_type, 
                jsonb_build_object(
                    'count', COUNT(*),
                    'alertRate', ROUND(AVG(has_alert::numeric), 4),
                    'avgConfidence', ROUND(AVG(confidence_score), 4),
                    'severityBreakdown', jsonb_object_agg(severity_level, severity_count)
                )
            )
            FROM (
                SELECT 
                    observation_type,
                    severity_level,
                    has_alert,
                    confidence_score,
                    COUNT(*) as severity_count
                FROM analytics_base
                GROUP BY observation_type, severity_level, has_alert, confidence_score
            ) severity_sub
            GROUP BY observation_type
        ),
        'bySeverityLevel', (
            SELECT jsonb_object_agg(
                severity_level, 
                jsonb_build_object(
                    'count', COUNT(*),
                    'alertRate', ROUND(AVG(has_alert::numeric), 4),
                    'avgConfidence', ROUND(AVG(confidence_score), 4),
                    'avgResolutionTime', COALESCE(ROUND(AVG(
                        CASE WHEN is_resolved = 1 
                        THEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - observation_timestamp))/3600 
                        END
                    ), 2), 0)
                )
            )
            FROM analytics_base
            GROUP BY severity_level
        ),
        'timeSeries', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'period', time_period,
                    'observationCount', observation_count,
                    'alertCount', alert_count,
                    'criticalCount', critical_count,
                    'avgConfidence', avg_confidence
                ) ORDER BY time_period
            )
            FROM (
                SELECT 
                    CASE v_group_by
                        WHEN 'hour' THEN date_trunc('hour', observation_timestamp)
                        WHEN 'day' THEN date_trunc('day', observation_timestamp)
                        WHEN 'week' THEN date_trunc('week', observation_timestamp)
                        WHEN 'month' THEN date_trunc('month', observation_timestamp)
                    END as time_period,
                    COUNT(*) as observation_count,
                    SUM(has_alert) as alert_count,
                    COUNT(CASE WHEN severity_level IN ('critical', 'emergency') THEN 1 END) as critical_count,
                    ROUND(AVG(confidence_score), 4) as avg_confidence
                FROM analytics_base
                GROUP BY time_period
                ORDER BY time_period
            ) time_data
        ),
        'entityAnalytics', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'entityId', entity_bk,
                    'observationCount', COUNT(*),
                    'alertCount', SUM(has_alert),
                    'avgConfidence', ROUND(AVG(confidence_score), 4),
                    'mostCommonType', mode() WITHIN GROUP (ORDER BY observation_type),
                    'riskScore', CASE 
                        WHEN COUNT(*) = 0 THEN 0
                        ELSE ROUND((SUM(has_alert)::numeric / COUNT(*)::numeric) * 100, 2)
                    END
                )
            )
            FROM analytics_base
            WHERE entity_bk IS NOT NULL
            GROUP BY entity_bk
            HAVING COUNT(*) > 0
        ),
        'sensorAnalytics', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'sensorId', sensor_bk,
                    'observationCount', COUNT(*),
                    'alertCount', SUM(has_alert),
                    'avgConfidence', ROUND(AVG(confidence_score), 4),
                    'detectionRate', ROUND(COUNT(*)::numeric / EXTRACT(EPOCH FROM (v_end_date - v_start_date)) * 3600, 2)
                )
            )
            FROM analytics_base
            WHERE sensor_bk IS NOT NULL
            GROUP BY sensor_bk
            HAVING COUNT(*) > 0
        )
    ) INTO v_analytics
    FROM analytics_base;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'AI observation analytics retrieved successfully',
        'data', COALESCE(v_analytics, jsonb_build_object(
            'summary', jsonb_build_object(
                'totalObservations', 0,
                'alertsGenerated', 0,
                'acknowledgedCount', 0,
                'resolvedCount', 0,
                'avgConfidenceScore', 0,
                'dateRange', jsonb_build_object(
                    'startDate', v_start_date,
                    'endDate', v_end_date,
                    'groupBy', v_group_by
                )
            )
        ))
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error generating AI observation analytics',
        'error_code', 'ANALYTICS_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$BODY$;

ALTER FUNCTION api.ai_get_observation_analytics(jsonb)
    OWNER TO postgres;


-- FUNCTION: api.ai_get_active_alerts(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_get_active_alerts(jsonb);

CREATE OR REPLACE FUNCTION api.ai_get_active_alerts(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_tenant_id VARCHAR(255);
    v_alert_type VARCHAR(50);
    v_priority_level INTEGER;
    v_limit INTEGER;
    v_offset INTEGER;
    
    v_tenant_hk BYTEA;
    v_alerts JSONB;
    v_total_count INTEGER;
    
BEGIN
    -- Extract parameters
    v_tenant_id := p_request->>'tenantId';
    v_alert_type := p_request->>'alertType';
    v_priority_level := (p_request->>'priorityLevel')::INTEGER;
    v_limit := COALESCE((p_request->>'limit')::INTEGER, 20);
    v_offset := COALESCE((p_request->>'offset')::INTEGER, 0);
    
    -- Validate tenant
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h 
    WHERE tenant_bk = v_tenant_id;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid tenant ID',
            'error_code', 'INVALID_TENANT'
        );
    END IF;
    
    -- Get total count
    SELECT COUNT(*) INTO v_total_count
    FROM business.ai_alert_h aah
    JOIN business.ai_alert_details_s aads ON aah.ai_alert_hk = aads.ai_alert_hk
    WHERE aah.tenant_hk = v_tenant_hk
    AND aads.load_end_date IS NULL
    AND aads.alert_status IN ('active', 'acknowledged', 'escalated')
    AND (v_alert_type IS NULL OR aads.alert_type = v_alert_type)
    AND (v_priority_level IS NULL OR aads.priority_level = v_priority_level);
    
    -- Get alerts with observation details
    SELECT jsonb_agg(
        jsonb_build_object(
            'alertId', aah.ai_alert_bk,
            'alertType', aads.alert_type,
            'alertCategory', aads.alert_category,
            'priorityLevel', aads.priority_level,
            'urgencyLevel', aads.urgency_level,
            'escalationLevel', aads.escalation_level,
            'alertTitle', aads.alert_title,
            'alertDescription', aads.alert_description,
            'alertSummary', aads.alert_summary,
            'primaryRecipients', aads.primary_recipients,
            'escalationRecipients', aads.escalation_recipients,
            'notificationChannels', aads.notification_channels,
            'alertCreatedAt', aads.alert_created_at,
            'responseRequiredBy', aads.response_required_by,
            'resolutionRequiredBy', aads.resolution_required_by,
            'autoEscalateAfter', aads.auto_escalate_after,
            'alertStatus', aads.alert_status,
            'acknowledgedBy', aads.acknowledged_by,
            'acknowledgedAt', aads.acknowledged_at,
            'assignedTo', aads.assigned_to,
            'assignedAt', aads.assigned_at,
            'resolvedBy', aads.resolved_by,
            'resolvedAt', aads.resolved_at,
            'resolutionMethod', aads.resolution_method,
            'resolutionNotes', aads.resolution_notes,
            'responseTimeSeconds', aads.response_time_seconds,
            'resolutionTimeSeconds', aads.resolution_time_seconds,
            'escalationCount', aads.escalation_count,
            'customerImpactLevel', aads.customer_impact_level,
            'followUpRequired', aads.follow_up_required,
            'followUpDate', aads.follow_up_date,
            'observation', CASE 
                WHEN oal.ai_observation_hk IS NOT NULL THEN
                    jsonb_build_object(
                        'observationId', aoh.ai_observation_bk,
                        'observationType', aods.observation_type,
                        'severityLevel', aods.severity_level,
                        'confidenceScore', aods.confidence_score,
                        'observationTimestamp', aods.observation_timestamp,
                        'entityId', meh.entity_bk,
                        'sensorId', msh.sensor_bk
                    )
                ELSE NULL
            END
        ) ORDER BY aads.priority_level ASC, aads.alert_created_at DESC
    ) INTO v_alerts
    FROM business.ai_alert_h aah
    JOIN business.ai_alert_details_s aads ON aah.ai_alert_hk = aads.ai_alert_hk
    LEFT JOIN business.ai_observation_alert_l oal ON aah.ai_alert_hk = oal.ai_alert_hk
    LEFT JOIN business.ai_observation_h aoh ON oal.ai_observation_hk = aoh.ai_observation_hk
    LEFT JOIN business.ai_observation_details_s aods ON aoh.ai_observation_hk = aods.ai_observation_hk AND aods.load_end_date IS NULL
    LEFT JOIN business.monitored_entity_h meh ON aods.entity_hk = meh.entity_hk
    LEFT JOIN business.monitoring_sensor_h msh ON aods.sensor_hk = msh.sensor_hk
    WHERE aah.tenant_hk = v_tenant_hk
    AND aads.load_end_date IS NULL
    AND aads.alert_status IN ('active', 'acknowledged', 'escalated')
    AND (v_alert_type IS NULL OR aads.alert_type = v_alert_type)
    AND (v_priority_level IS NULL OR aads.priority_level = v_priority_level)
    LIMIT v_limit OFFSET v_offset;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Active AI alerts retrieved successfully',
        'data', jsonb_build_object(
            'alerts', COALESCE(v_alerts, '[]'::JSONB),
            'totalCount', v_total_count,
            'limit', v_limit,
            'offset', v_offset,
            'hasMore', v_total_count > (v_offset + v_limit),
            'filters', jsonb_build_object(
                'tenantId', v_tenant_id,
                'alertType', v_alert_type,
                'priorityLevel', v_priority_level
            )
        )
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error retrieving active alerts',
        'error_code', 'RETRIEVAL_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$BODY$;

ALTER FUNCTION api.ai_get_active_alerts(jsonb)
    OWNER TO postgres;

-- FUNCTION: api.ai_create_session(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_create_session(jsonb);

CREATE OR REPLACE FUNCTION api.ai_create_session(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    -- Request parameters
    v_user_id VARCHAR(255);
    v_tenant_id VARCHAR(255);
    v_session_purpose VARCHAR(100);
    v_ip_address INET;
    v_user_agent TEXT;
    
    -- Internal variables
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_session_bk VARCHAR(255);
    v_session_hk BYTEA;
    
BEGIN
    -- Extract parameters
    v_user_id := p_request->>'userId';
    v_tenant_id := p_request->>'tenantId';
    v_session_purpose := COALESCE(p_request->>'sessionPurpose', 'general_chat');
    v_ip_address := (p_request->>'ip_address')::INET;
    v_user_agent := p_request->>'user_agent';
    
    -- Validate parameters
    IF v_user_id IS NULL OR v_tenant_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User ID and Tenant ID are required',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get hash keys (same validation pattern)
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
    WHERE tps.tenant_name = v_tenant_id
    AND tps.load_end_date IS NULL;
    
    SELECT user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
    WHERE ups.email = v_user_id
    AND uh.tenant_hk = v_tenant_hk
    AND ups.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL OR v_user_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid user or tenant',
            'error_code', 'INVALID_CREDENTIALS'
        );
    END IF;
    
    -- Generate session business key
    v_session_bk := 'ai-sess-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD-HH24MISS') || '-' || 
                    encode(gen_random_bytes(8), 'hex');
    
    -- Create AI session using existing function
    SELECT p_session_hk INTO v_session_hk
    FROM business.create_ai_session(
        v_session_bk,
        v_user_id,
        v_tenant_id,
        v_session_purpose
    );
    
    -- Log session creation
    PERFORM audit.log_security_event(
        'AI_SESSION_CREATED',
        'LOW',
        'AI chat session created for user: ' || v_user_id,
        v_ip_address,
        v_user_agent,
        v_user_hk,
        'LOW',
        jsonb_build_object(
            'tenant_id', v_tenant_id,
            'user_id', v_user_id,
            'session_id', v_session_bk,
            'session_purpose', v_session_purpose,
            'timestamp', NOW()
        )
    );
    
    -- Return session info
    RETURN jsonb_build_object(
        'success', true,
        'message', 'AI session created successfully',
        'data', jsonb_build_object(
            'sessionId', v_session_bk,
            'sessionPurpose', v_session_purpose,
            'createdAt', CURRENT_TIMESTAMP,
            'expiresAt', CURRENT_TIMESTAMP + INTERVAL '24 hours'
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error creating AI session',
        'error_code', 'SESSION_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$BODY$;

ALTER FUNCTION api.ai_create_session(jsonb)
    OWNER TO postgres;


-- FUNCTION: api.ai_chat_history(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_chat_history(jsonb);

CREATE OR REPLACE FUNCTION api.ai_chat_history(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    -- Request parameters
    v_user_id VARCHAR(255);
    v_tenant_id VARCHAR(255);
    v_session_id VARCHAR(255);
    v_context_type VARCHAR(50);
    v_limit INTEGER;
    v_offset INTEGER;
    v_start_date TIMESTAMP WITH TIME ZONE;
    v_end_date TIMESTAMP WITH TIME ZONE;
    v_ip_address INET;
    v_user_agent TEXT;
    
    -- Internal variables
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_history_data JSONB;
    v_total_count INTEGER;
    
BEGIN
    -- Extract parameters from JSON request
    v_user_id := p_request->>'userId';
    v_tenant_id := p_request->>'tenantId';
    v_session_id := p_request->>'sessionId';
    v_context_type := p_request->>'contextType';
    v_limit := COALESCE((p_request->>'limit')::INTEGER, 20);
    v_offset := COALESCE((p_request->>'offset')::INTEGER, 0);
    v_start_date := (p_request->>'startDate')::TIMESTAMP WITH TIME ZONE;
    v_end_date := (p_request->>'endDate')::TIMESTAMP WITH TIME ZONE;
    v_ip_address := (p_request->>'ip_address')::INET;
    v_user_agent := p_request->>'user_agent';
    
    -- Validate required parameters
    IF v_user_id IS NULL OR v_tenant_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User ID and Tenant ID are required',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get tenant and user hash keys (same validation as ai_secure_chat)
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
    WHERE tps.tenant_name = v_tenant_id
    AND tps.load_end_date IS NULL;
    
    SELECT user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
    WHERE ups.email = v_user_id
    AND uh.tenant_hk = v_tenant_hk
    AND ups.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL OR v_user_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid user or tenant',
            'error_code', 'INVALID_CREDENTIALS'
        );
    END IF;
    
    -- Get AI interaction history using existing function
    SELECT jsonb_agg(
        jsonb_build_object(
            'interactionId', interaction_id,
            'question', question_text,
            'response', response_text,
            'contextType', context_type,
            'modelUsed', model_used,
            'timestamp', interaction_timestamp,
            'processingTimeMs', processing_time_ms,
            'securityLevel', security_level
        ) ORDER BY interaction_timestamp DESC
    ), COUNT(*) 
    INTO v_history_data, v_total_count
    FROM business.get_ai_interaction_history(
        v_user_id,
        v_tenant_id,
        v_limit,
        v_offset,
        v_context_type
    );
    
    -- Log history access
    PERFORM audit.log_security_event(
        'AI_HISTORY_ACCESS',
        'LOW',
        'AI chat history accessed by user: ' || v_user_id,
        v_ip_address,
        v_user_agent,
        v_user_hk,
        'LOW',
        jsonb_build_object(
            'tenant_id', v_tenant_id,
            'user_id', v_user_id,
            'session_id', v_session_id,
            'context_type', v_context_type,
            'limit', v_limit,
            'offset', v_offset,
            'records_returned', COALESCE(jsonb_array_length(v_history_data), 0),
            'timestamp', NOW()
        )
    );
    
    -- Return history data
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Chat history retrieved successfully',
        'data', jsonb_build_object(
            'interactions', COALESCE(v_history_data, '[]'::jsonb),
            'totalCount', COALESCE(v_total_count, 0),
            'limit', v_limit,
            'offset', v_offset,
            'hasMore', (v_offset + v_limit) < COALESCE(v_total_count, 0)
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    PERFORM audit.log_security_event(
        'AI_HISTORY_ERROR',
        'ERROR',
        'Error retrieving AI chat history for user: ' || COALESCE(v_user_id, 'unknown'),
        COALESCE(v_ip_address, '0.0.0.0'::inet),
        COALESCE(v_user_agent, 'unknown'),
        v_user_hk,
        'ERROR',
        jsonb_build_object(
            'tenant_id', v_tenant_id,
            'user_id', v_user_id,
            'error_message', SQLERRM,
            'timestamp', NOW()
        )
    );
    
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error retrieving chat history',
        'error_code', 'HISTORY_ERROR'
    );
END;
$BODY$;

ALTER FUNCTION api.ai_chat_history(jsonb)
    OWNER TO postgres;

-- FUNCTION: api.ai_acknowledge_alert(jsonb)

-- DROP FUNCTION IF EXISTS api.ai_acknowledge_alert(jsonb);

CREATE OR REPLACE FUNCTION api.ai_acknowledge_alert(
	p_request jsonb)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_alert_id VARCHAR(255);
    v_acknowledged_by VARCHAR(255);
    v_tenant_id VARCHAR(255);
    v_acknowledgment_notes TEXT;
    v_ip_address INET;
    
    v_tenant_hk BYTEA;
    v_alert_hk BYTEA;
    v_current_status VARCHAR(30);
    v_alert_created_at TIMESTAMP WITH TIME ZONE;
    v_response_time_seconds INTEGER;
    
BEGIN
    -- Extract parameters
    v_alert_id := p_request->>'alertId';
    v_acknowledged_by := p_request->>'acknowledgedBy';
    v_tenant_id := p_request->>'tenantId';
    v_acknowledgment_notes := p_request->>'acknowledgmentNotes';
    v_ip_address := COALESCE((p_request->>'ip_address')::INET, '127.0.0.1'::INET);
    
    -- Validate required parameters
    IF v_alert_id IS NULL OR v_acknowledged_by IS NULL OR v_tenant_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Missing required parameters: alertId, acknowledgedBy, tenantId',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Get tenant hash key
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h 
    WHERE tenant_bk = v_tenant_id;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid tenant ID',
            'error_code', 'INVALID_TENANT'
        );
    END IF;
    
    -- Get alert hash key and current status
    SELECT aah.ai_alert_hk, aads.alert_status, aads.alert_created_at
    INTO v_alert_hk, v_current_status, v_alert_created_at
    FROM business.ai_alert_h aah
    JOIN business.ai_alert_details_s aads ON aah.ai_alert_hk = aads.ai_alert_hk
    WHERE aah.ai_alert_bk = v_alert_id 
    AND aah.tenant_hk = v_tenant_hk
    AND aads.load_end_date IS NULL;
    
    IF v_alert_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Alert not found',
            'error_code', 'ALERT_NOT_FOUND'
        );
    END IF;
    
    -- Check if alert is already acknowledged
    IF v_current_status NOT IN ('active', 'escalated') THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Alert is already acknowledged or resolved',
            'error_code', 'ALERT_ALREADY_PROCESSED',
            'data', jsonb_build_object('currentStatus', v_current_status)
        );
    END IF;
    
    -- Calculate response time
    v_response_time_seconds := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_alert_created_at));
    
    -- End-date current record
    UPDATE business.ai_alert_details_s 
    SET load_end_date = util.current_load_date()
    WHERE ai_alert_hk = v_alert_hk 
    AND load_end_date IS NULL;
    
    -- Insert acknowledged alert record
    INSERT INTO business.ai_alert_details_s (
        ai_alert_hk, load_date, load_end_date, hash_diff,
        alert_type, alert_category, priority_level, urgency_level,
        escalation_level, max_escalation_level, alert_title, alert_description,
        alert_summary, primary_recipients, escalation_recipients, 
        notification_channels, alert_created_at, response_required_by,
        resolution_required_by, auto_escalate_after, auto_resolve_after,
        alert_status, acknowledged_by, acknowledged_at, assigned_to, assigned_at,
        resolved_by, resolved_at, resolution_method, resolution_notes,
        response_time_seconds, resolution_time_seconds, customer_impact_level,
        escalation_count, escalation_history, follow_up_required, follow_up_date,
        prevention_measures_taken, similar_incidents_count, record_source
    )
    SELECT 
        ai_alert_hk, util.current_load_date(), NULL,
        util.hash_binary(v_alert_id || 'acknowledged' || CURRENT_TIMESTAMP::text),
        alert_type, alert_category, priority_level, urgency_level,
        escalation_level, max_escalation_level, alert_title, alert_description,
        alert_summary, primary_recipients, escalation_recipients,
        notification_channels, alert_created_at, response_required_by,
        resolution_required_by, auto_escalate_after, auto_resolve_after,
        'acknowledged', v_acknowledged_by, CURRENT_TIMESTAMP, v_acknowledged_by, CURRENT_TIMESTAMP,
        resolved_by, resolved_at, resolution_method, 
        COALESCE(resolution_notes || E'\n' || 'Acknowledged: ' || COALESCE(v_acknowledgment_notes, 'No notes provided'), 
                 'Acknowledged: ' || COALESCE(v_acknowledgment_notes, 'No notes provided')),
        v_response_time_seconds, resolution_time_seconds, customer_impact_level,
        escalation_count, escalation_history, follow_up_required, follow_up_date,
        prevention_measures_taken, similar_incidents_count, util.get_record_source()
    FROM business.ai_alert_details_s
    WHERE ai_alert_hk = v_alert_hk 
    AND load_end_date = util.current_load_date();
    
    -- Log acknowledgment
    PERFORM audit.log_security_event(
        'AI_ALERT_ACKNOWLEDGED',
        'MEDIUM',
        'AI alert acknowledged: ' || v_alert_id || ' by ' || v_acknowledged_by,
        NULL, v_acknowledged_by, v_ip_address, 'MEDIUM',
        jsonb_build_object(
            'alert_id', v_alert_id,
            'acknowledged_by', v_acknowledged_by,
            'acknowledgment_notes', v_acknowledgment_notes,
            'response_time_seconds', v_response_time_seconds,
            'previous_status', v_current_status,
            'timestamp', CURRENT_TIMESTAMP
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Alert acknowledged successfully',
        'data', jsonb_build_object(
            'alertId', v_alert_id,
            'acknowledgedBy', v_acknowledged_by,
            'acknowledgedAt', CURRENT_TIMESTAMP,
            'responseTimeSeconds', v_response_time_seconds,
            'previousStatus', v_current_status,
            'newStatus', 'acknowledged'
        )
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Error acknowledging alert',
        'error_code', 'ACKNOWLEDGMENT_ERROR',
        'debug_info', jsonb_build_object('error', SQLERRM)
    );
END;
$BODY$;

ALTER FUNCTION api.ai_acknowledge_alert(jsonb)
    OWNER TO postgres;

