-- =====================================================================
-- AI Monitoring System - Stored Procedures and Functions
-- Zero Trust Security and Dynamic Access Control
-- =====================================================================

-- =====================================================================
-- DEPLOYMENT LOGGING
-- =====================================================================
DO $$
DECLARE
    deployment_id INTEGER;
BEGIN
    SELECT util.log_deployment_start(
        'AI_MONITORING_FUNCTIONS_V1',
        'AI monitoring system functions with Zero Trust security',
        'ROLLBACK: Drop ai_monitoring functions'
    ) INTO deployment_id;
    
    RAISE NOTICE 'Starting functions deployment ID: %', deployment_id;
END $$;

-- =====================================================================
-- ZERO TRUST ACCESS VALIDATION
-- =====================================================================

-- Main Zero Trust access validation function
CREATE OR REPLACE FUNCTION ai_monitoring.validate_zero_trust_access(
    p_tenant_hk BYTEA,
    p_user_hk BYTEA DEFAULT NULL,
    p_token_value TEXT DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_requested_resource VARCHAR(255) DEFAULT NULL,
    p_endpoint VARCHAR(255) DEFAULT NULL
) RETURNS TABLE (
    p_access_granted BOOLEAN,
    p_risk_score INTEGER,
    p_access_level VARCHAR(50),
    p_required_actions TEXT[],
    p_session_valid BOOLEAN,
    p_user_context JSONB
) LANGUAGE plpgsql AS $$
DECLARE
    v_device_trust_score INTEGER := 50;
    v_location_risk_score INTEGER := 0;
    v_behavioral_score INTEGER := 50;
    v_final_risk_score INTEGER;
    v_access_level VARCHAR(50);
    v_required_actions TEXT[] := ARRAY[]::TEXT[];
    v_access_granted BOOLEAN := FALSE;
    v_session_valid BOOLEAN := FALSE;
    v_user_context JSONB := '{}';
    v_auth_result RECORD;
    v_session_result RECORD;
    v_security_event_hk BYTEA;
BEGIN
    -- 1. INTEGRATE WITH EXISTING TOKEN VALIDATION SYSTEM
    IF p_token_value IS NOT NULL THEN
        SELECT * INTO v_auth_result
        FROM auth.validate_token_comprehensive(
            p_token_value, 
            p_ip_address, 
            p_user_agent, 
            p_endpoint
        );
        
        IF v_auth_result.is_valid THEN
            v_session_valid := TRUE;
            p_user_hk := v_auth_result.user_hk;
            v_user_context := jsonb_build_object(
                'user_hk', encode(v_auth_result.user_hk, 'hex'),
                'tenant_hk', encode(v_auth_result.tenant_hk, 'hex'),
                'username', v_auth_result.username,
                'permissions', v_auth_result.permissions,
                'expires_at', v_auth_result.expires_at,
                'compliance_alert', v_auth_result.compliance_alert
            );
            
            -- Use existing session validation for additional checks
            SELECT * INTO v_session_result
            FROM auth.validate_session_optimized(
                NULL, -- Will be derived from token
                p_ip_address,
                p_user_agent
            );
            
        ELSE
            -- Log failed authentication with existing security event system
            PERFORM audit.log_security_event(
                'AUTHENTICATION_FAILED'::VARCHAR,
                'HIGH'::VARCHAR,
                'AI monitoring access denied - invalid token'::TEXT,
                p_ip_address,
                p_user_agent,
                p_user_hk,
                'HIGH'::VARCHAR,
                jsonb_build_object(
                    'endpoint', p_endpoint,
                    'requested_resource', p_requested_resource,
                    'token_validation_message', v_auth_result.message
                )
            );
            
            RETURN QUERY SELECT FALSE, 100, 'DENIED'::VARCHAR(50), 
                               ARRAY['INVALID_AUTHENTICATION']::TEXT[], 
                               FALSE, '{}'::JSONB;
            RETURN;
        END IF;
    END IF;

    -- 2. DEVICE TRUST ANALYSIS (Enhanced with existing session data)
    IF p_user_agent IS NOT NULL THEN
        -- Check against existing session patterns
        SELECT COUNT(*) INTO v_device_trust_score
        FROM auth.session_state_s sss
        JOIN auth.session_h sh ON sss.session_hk = sh.session_hk
        WHERE sh.tenant_hk = p_tenant_hk
        AND sss.user_agent = p_user_agent
        AND sss.session_status = 'ACTIVE'
        AND sss.last_activity >= CURRENT_TIMESTAMP - INTERVAL '30 days'
        AND sss.load_end_date IS NULL;
        
        -- Scale to 0-100 range
        v_device_trust_score := LEAST(100, v_device_trust_score * 10 + 30);
    END IF;

    -- 3. LOCATION RISK ANALYSIS (Enhanced with IP tracking)
    IF p_ip_address IS NOT NULL THEN
        -- Check existing IP tracking system
        SELECT 
            CASE 
                WHEN COUNT(*) > 5 THEN 10  -- Known IP
                WHEN COUNT(*) > 0 THEN 30  -- Seen before
                ELSE 60                    -- New IP
            END INTO v_location_risk_score
        FROM auth.session_state_s sss
        JOIN auth.session_h sh ON sss.session_hk = sh.session_hk
        WHERE sh.tenant_hk = p_tenant_hk
        AND sss.ip_address = p_ip_address
        AND sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '90 days'
        AND sss.load_end_date IS NULL;
        
        -- Check for suspicious IP patterns using existing security tracking
        IF EXISTS (
            SELECT 1 FROM auth.security_tracking_h sth
            JOIN ai_monitoring.zt_security_events_s ses ON sth.security_tracking_hk = ses.security_tracking_hk
            WHERE ses.source_ip_address = p_ip_address
            AND ses.threat_level IN ('HIGH', 'CRITICAL')
            AND ses.event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
            AND ses.load_end_date IS NULL
        ) THEN
            v_location_risk_score := v_location_risk_score + 40;
        END IF;
    END IF;

    -- 4. BEHAVIORAL ANALYSIS (Using existing user activity patterns)
    IF p_user_hk IS NOT NULL THEN
        -- Analyze normal access patterns from existing session data
        SELECT 
            CASE 
                WHEN EXTRACT(HOUR FROM CURRENT_TIMESTAMP) BETWEEN normal_start_hour AND normal_end_hour 
                THEN 10
                ELSE 40
            END INTO v_behavioral_score
        FROM (
            SELECT 
                EXTRACT(HOUR FROM MIN(sss.session_start)) as normal_start_hour,
                EXTRACT(HOUR FROM MAX(sss.session_start)) as normal_end_hour
            FROM auth.session_state_s sss
            JOIN auth.user_session_l usl ON sss.session_hk = usl.session_hk
            WHERE usl.user_hk = p_user_hk
            AND usl.tenant_hk = p_tenant_hk
            AND sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '30 days'
            AND sss.load_end_date IS NULL
        ) user_patterns;
        
        -- Check for unusual endpoint access patterns
        IF p_endpoint LIKE '%ai_monitoring%' THEN
            -- Check if user has accessed AI monitoring before
            SELECT COUNT(*) INTO v_behavioral_score
            FROM auth.token_activity_s tas
            JOIN auth.user_token_l utl ON tas.api_token_hk = utl.api_token_hk
            WHERE utl.user_hk = p_user_hk
            AND utl.tenant_hk = p_tenant_hk
            AND tas.endpoint_accessed LIKE '%ai_monitoring%'
            AND tas.last_activity_timestamp >= CURRENT_TIMESTAMP - INTERVAL '90 days'
            AND tas.load_end_date IS NULL;
            
            v_behavioral_score := CASE 
                WHEN v_behavioral_score > 0 THEN 10  -- Regular AI user
                ELSE 25                               -- New to AI features
            END;
        END IF;
    END IF;

    -- 5. CALCULATE FINAL RISK SCORE
    v_final_risk_score := (v_device_trust_score + v_location_risk_score + v_behavioral_score) / 3;

    -- 6. DETERMINE ACCESS LEVEL AND ACTIONS (Aligned with existing security policies)
    CASE 
        WHEN v_final_risk_score <= 20 THEN
            v_access_level := 'FULL_ACCESS';
            v_access_granted := TRUE;
            
        WHEN v_final_risk_score <= 40 THEN
            v_access_level := 'STANDARD_ACCESS';
            v_access_granted := TRUE;
            v_required_actions := ARRAY['ENHANCED_LOGGING'];
            
        WHEN v_final_risk_score <= 60 THEN
            v_access_level := 'LIMITED_ACCESS';
            v_access_granted := TRUE;
            v_required_actions := ARRAY['MFA_RECOMMENDED', 'ENHANCED_MONITORING'];
            
        WHEN v_final_risk_score <= 80 THEN
            v_access_level := 'RESTRICTED_ACCESS';
            v_access_granted := TRUE;
            v_required_actions := ARRAY['MFA_REQUIRED', 'ADMIN_NOTIFICATION'];
            
        ELSE
            v_access_level := 'ACCESS_DENIED';
            v_access_granted := FALSE;
            v_required_actions := ARRAY['ACCESS_BLOCKED', 'SECURITY_REVIEW', 'ADMIN_APPROVAL_REQUIRED'];
    END CASE;

    -- 7. LOG SECURITY EVENT USING EXISTING AUDIT SYSTEM
    IF v_final_risk_score > 40 OR NOT v_access_granted THEN
        PERFORM audit.log_security_event(
            'ZERO_TRUST_ASSESSMENT'::VARCHAR,
            CASE WHEN v_final_risk_score > 80 THEN 'HIGH' ELSE 'MEDIUM' END::VARCHAR,
            format('Zero Trust access assessment: %s (Risk Score: %s)', v_access_level, v_final_risk_score)::TEXT,
            p_ip_address,
            p_user_agent,
            p_user_hk,
            CASE 
                WHEN v_final_risk_score > 80 THEN 'CRITICAL'
                WHEN v_final_risk_score > 60 THEN 'HIGH'
                WHEN v_final_risk_score > 40 THEN 'MEDIUM'
                ELSE 'LOW'
            END::VARCHAR,
            jsonb_build_object(
                'risk_score', v_final_risk_score,
                'device_trust', v_device_trust_score,
                'location_risk', v_location_risk_score,
                'behavioral_score', v_behavioral_score,
                'access_level', v_access_level,
                'required_actions', v_required_actions,
                'endpoint', p_endpoint,
                'resource', p_requested_resource
            )
        );
    END IF;

    -- 8. RETURN RESULTS WITH EXISTING USER CONTEXT
    RETURN QUERY SELECT 
        v_access_granted,
        v_final_risk_score,
        v_access_level,
        v_required_actions,
        v_session_valid,
        v_user_context;
END;
$$;

-- =====================================================================
-- SECURITY EVENT LOGGING
-- =====================================================================

CREATE OR REPLACE FUNCTION ai_monitoring.log_security_event(
    p_tenant_hk BYTEA,
    p_event_type VARCHAR(100),
    p_severity VARCHAR(20),
    p_description TEXT,
    p_source_ip INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_user_hk BYTEA DEFAULT NULL,
    p_event_metadata JSONB DEFAULT NULL
) RETURNS BYTEA LANGUAGE plpgsql AS $$
DECLARE
    v_security_event_hk BYTEA;
    v_threat_level VARCHAR(20);
    v_response_actions TEXT[];
BEGIN
    -- Determine threat level and response actions
    CASE p_severity
        WHEN 'LOW' THEN
            v_threat_level := 'LOW';
            v_response_actions := ARRAY['LOG_ONLY'];
        WHEN 'MEDIUM' THEN
            v_threat_level := 'MEDIUM';
            v_response_actions := ARRAY['ENHANCED_MONITORING', 'RATE_LIMIT_CHECK'];
        WHEN 'HIGH' THEN
            v_threat_level := 'HIGH';
            v_response_actions := ARRAY['MFA_REQUIRED', 'ADMIN_NOTIFICATION', 'ENHANCED_LOGGING'];
        WHEN 'CRITICAL' THEN
            v_threat_level := 'CRITICAL';
            v_response_actions := ARRAY['ACCOUNT_LOCKOUT', 'IMMEDIATE_ADMIN_ALERT', 'FORENSIC_LOGGING'];
        ELSE
            v_threat_level := 'MEDIUM';
            v_response_actions := ARRAY['STANDARD_MONITORING'];
    END CASE;

    -- Use existing audit system for comprehensive logging
    v_security_event_hk := audit.log_security_event(
        p_event_type,
        p_severity,
        p_description,
        p_source_ip,
        p_user_agent,
        p_user_hk,
        v_threat_level,
        COALESCE(p_event_metadata, '{}') || jsonb_build_object(
            'ai_monitoring_event', true,
            'threat_level', v_threat_level,
            'response_actions', v_response_actions,
            'tenant_context', encode(p_tenant_hk, 'hex')
        )
    );

    -- Execute automated response actions
    PERFORM ai_monitoring.trigger_security_response(
        p_tenant_hk,
        v_threat_level,
        v_response_actions,
        p_user_hk,
        v_security_event_hk
    );

    RETURN v_security_event_hk;
END;
$$;

-- =====================================================================
-- AUTOMATED SECURITY RESPONSE
-- =====================================================================

CREATE OR REPLACE FUNCTION ai_monitoring.trigger_security_response(
    p_tenant_hk BYTEA,
    p_threat_level VARCHAR(20),
    p_response_actions TEXT[],
    p_user_hk BYTEA DEFAULT NULL,
    p_security_event_hk BYTEA DEFAULT NULL
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
    v_action TEXT;
    v_response_success BOOLEAN := TRUE;
BEGIN
    FOREACH v_action IN ARRAY p_response_actions
    LOOP
        CASE v_action
            WHEN 'ACCOUNT_LOCKOUT' THEN
                -- Integrate with existing account lockout system
                IF p_user_hk IS NOT NULL THEN
                    UPDATE auth.user_auth_s 
                    SET 
                        load_end_date = util.current_load_date(),
                        hash_diff = util.hash_binary('LOCKED_BY_AI_MONITORING_' || CURRENT_TIMESTAMP::text)
                    WHERE user_hk = p_user_hk 
                    AND tenant_hk = p_tenant_hk
                    AND load_end_date IS NULL;
                    
                    INSERT INTO auth.user_auth_s (
                        user_hk, load_date, hash_diff, username, password_hash, password_salt,
                        account_locked, account_locked_until, failed_login_attempts,
                        lockout_reason, last_login_date, record_source
                    )
                    SELECT 
                        user_hk, util.current_load_date(), 
                        util.hash_binary('AI_MONITORING_LOCKOUT_' || CURRENT_TIMESTAMP::text),
                        username, password_hash, password_salt,
                        TRUE, CURRENT_TIMESTAMP + INTERVAL '24 hours', failed_login_attempts + 1,
                        'AI Monitoring Security Response: ' || p_threat_level || ' threat detected',
                        last_login_date, util.get_record_source()
                    FROM auth.user_auth_s 
                    WHERE user_hk = p_user_hk 
                    AND tenant_hk = p_tenant_hk
                    AND load_end_date IS NULL;
                END IF;
                
            WHEN 'ENHANCED_MONITORING' THEN
                -- Enable enhanced session monitoring using existing infrastructure
                PERFORM auth.monitor_failed_logins(p_tenant_hk, INTERVAL '1 hour');
                
            WHEN 'MFA_REQUIRED' THEN
                -- Flag user for MFA requirement in existing security policy system
                UPDATE auth.security_policy_s 
                SET 
                    load_end_date = util.current_load_date(),
                    hash_diff = util.hash_binary('MFA_REQUIRED_UPDATE_' || CURRENT_TIMESTAMP::text)
                WHERE security_policy_hk IN (
                    SELECT security_policy_hk 
                    FROM auth.security_policy_h 
                    WHERE tenant_hk = p_tenant_hk
                ) AND load_end_date IS NULL;
                
                INSERT INTO auth.security_policy_s (
                    security_policy_hk, load_date, hash_diff,
                    policy_name, password_min_length, session_timeout_minutes,
                    require_mfa, max_failed_attempts, account_lockout_duration_minutes,
                    is_hipaa_compliant, record_source
                )
                SELECT 
                    security_policy_hk, util.current_load_date(),
                    util.hash_binary('AI_MONITORING_MFA_' || CURRENT_TIMESTAMP::text),
                    policy_name, password_min_length, session_timeout_minutes,
                    TRUE, max_failed_attempts, account_lockout_duration_minutes,
                    is_hipaa_compliant, util.get_record_source()
                FROM auth.security_policy_s 
                WHERE security_policy_hk IN (
                    SELECT security_policy_hk 
                    FROM auth.security_policy_h 
                    WHERE tenant_hk = p_tenant_hk
                ) AND load_end_date IS NULL;
                
            WHEN 'ADMIN_NOTIFICATION' THEN
                -- Create alert for admin users using existing notification system
                PERFORM ai_monitoring.create_alert(
                    p_tenant_hk,
                    NULL,
                    NULL,
                    'SECURITY_RESPONSE_ADMIN_NOTIFICATION',
                    'HIGH',
                    format('Security response triggered: %s threat level detected', p_threat_level),
                    jsonb_build_object(
                        'threat_level', p_threat_level,
                        'response_actions', p_response_actions,
                        'security_event_hk', encode(COALESCE(p_security_event_hk, '\x00'), 'hex')
                    ),
                    p_user_hk
                );
                
            ELSE
                -- Log unknown action type
                PERFORM audit.log_security_event(
                    'UNKNOWN_SECURITY_RESPONSE',
                    'MEDIUM',
                    format('Unknown security response action: %s', v_action),
                    NULL,
                    NULL,
                    p_user_hk,
                    'MEDIUM',
                    jsonb_build_object(
                        'action', v_action,
                        'threat_level', p_threat_level,
                        'tenant_hk', encode(p_tenant_hk, 'hex')
                    )
                );
        END CASE;
    END LOOP;

    RETURN v_response_success;
END;
$$;

-- =====================================================================
-- GENERIC ENTITY MONITORING FUNCTIONS
-- =====================================================================

-- Create monitored entity (generic, not horse-specific)
CREATE OR REPLACE FUNCTION ai_monitoring.create_monitored_entity(
    p_tenant_hk BYTEA,
    p_entity_bk VARCHAR(255),
    p_entity_name VARCHAR(200),
    p_entity_type VARCHAR(100),
    p_location_info JSONB DEFAULT NULL,
    p_monitoring_config JSONB DEFAULT NULL,
    p_created_by_user_hk BYTEA DEFAULT NULL
) RETURNS BYTEA LANGUAGE plpgsql AS $$
DECLARE
    v_entity_hk BYTEA;
    v_load_date TIMESTAMP WITH TIME ZONE;
BEGIN
    v_load_date := util.current_load_date();
    v_entity_hk := util.hash_binary(p_entity_bk || '_' || encode(p_tenant_hk, 'hex'));

    -- Insert hub record following existing patterns
    INSERT INTO ai_monitoring.monitored_entity_h (
        monitored_entity_hk,
        monitored_entity_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_entity_hk,
        p_entity_bk,
        p_tenant_hk,
        v_load_date,
        util.get_record_source()
    ) ON CONFLICT (monitored_entity_hk) DO NOTHING;

    -- Insert satellite record with enhanced monitoring configuration
    INSERT INTO ai_monitoring.monitored_entity_details_s (
        monitored_entity_hk,
        load_date,
        hash_diff,
        entity_name,
        entity_type,
        entity_status,
        location_info,
        monitoring_config,
        alert_thresholds,
        data_classification,
        created_by_user_hk,
        record_source
    ) VALUES (
        v_entity_hk,
        v_load_date,
        util.hash_binary(p_entity_name || p_entity_type || COALESCE(p_location_info::text, '')),
        p_entity_name,
        p_entity_type,
        'ACTIVE',
        COALESCE(p_location_info, '{}'),
        COALESCE(p_monitoring_config, jsonb_build_object(
            'monitoring_enabled', true,
            'alert_level', 'MEDIUM',
            'data_retention_days', 90,
            'encryption_required', true
        )),
        jsonb_build_object(
            'critical_threshold', 90,
            'warning_threshold', 70,
            'info_threshold', 50
        ),
        'INTERNAL', -- Default classification
        p_created_by_user_hk,
        util.get_record_source()
    );

    -- Log entity creation using existing audit system
    PERFORM audit.log_security_event(
        'ENTITY_CREATED',
        'LOW',
        format('Monitored entity created: %s (%s)', p_entity_name, p_entity_type),
        NULL,
        NULL,
        p_created_by_user_hk,
        'LOW',
        jsonb_build_object(
            'entity_hk', encode(v_entity_hk, 'hex'),
            'entity_type', p_entity_type,
            'tenant_hk', encode(p_tenant_hk, 'hex')
        )
    );

    RETURN v_entity_hk;
END;
$$;

-- Store AI analysis result
CREATE OR REPLACE FUNCTION ai_monitoring.store_ai_analysis(
    p_tenant_hk BYTEA,
    p_entity_hk BYTEA,
    p_analysis_type VARCHAR(100),
    p_analysis_data JSONB,
    p_confidence_score DECIMAL(5,2) DEFAULT NULL,
    p_model_version VARCHAR(50) DEFAULT NULL,
    p_created_by_user_hk BYTEA DEFAULT NULL
) RETURNS BYTEA LANGUAGE plpgsql AS $$
DECLARE
    v_analysis_hk BYTEA;
    v_analysis_bk VARCHAR(255);
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_data_hash BYTEA;
BEGIN
    v_load_date := util.current_load_date();
    v_analysis_bk := p_analysis_type || '_' || 
                     encode(p_entity_hk, 'hex') || '_' ||
                     to_char(v_load_date, 'YYYYMMDD_HH24MISS');
    v_analysis_hk := util.hash_binary(v_analysis_bk);
    v_data_hash := util.hash_binary(p_analysis_data::text);

    -- Insert hub record
    INSERT INTO ai_monitoring.ai_analysis_h (
        ai_analysis_hk,
        ai_analysis_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_analysis_hk,
        v_analysis_bk,
        p_tenant_hk,
        v_load_date,
        util.get_record_source()
    );

    -- Insert satellite record with enhanced metadata
    INSERT INTO ai_monitoring.ai_analysis_results_s (
        ai_analysis_hk,
        load_date,
        hash_diff,
        analysis_type,
        analysis_timestamp,
        analysis_data_encrypted,
        confidence_score,
        model_version,
        processing_time_ms,
        data_classification,
        validation_status,
        created_by_user_hk,
        record_source
    ) VALUES (
        v_analysis_hk,
        v_load_date,
        v_data_hash,
        p_analysis_type,
        v_load_date,
        -- Encrypt sensitive analysis data following existing patterns
        pgp_sym_encrypt(p_analysis_data::text, encode(p_tenant_hk, 'hex')),
        COALESCE(p_confidence_score, 85.0),
        COALESCE(p_model_version, 'GPT-4'),
        extract(epoch from (CURRENT_TIMESTAMP - v_load_date)) * 1000,
        'CONFIDENTIAL', -- AI analysis is sensitive
        'VALIDATED',
        p_created_by_user_hk,
        util.get_record_source()
    );

    -- Create entity-analysis link
    INSERT INTO ai_monitoring.entity_analysis_l (
        entity_analysis_hk,
        monitored_entity_hk,
        ai_analysis_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(encode(p_entity_hk, 'hex') || '_' || encode(v_analysis_hk, 'hex')),
        p_entity_hk,
        v_analysis_hk,
        p_tenant_hk,
        v_load_date,
        util.get_record_source()
    );

    RETURN v_analysis_hk;
END;
$$;

-- Create alert function
CREATE OR REPLACE FUNCTION ai_monitoring.create_alert(
    p_tenant_hk BYTEA,
    p_alert_type VARCHAR(100),
    p_severity VARCHAR(20),
    p_alert_message TEXT,
    p_analysis_hk BYTEA DEFAULT NULL,
    p_entity_hk BYTEA DEFAULT NULL,
    p_alert_data JSONB DEFAULT NULL,
    p_created_by_user_hk BYTEA DEFAULT NULL
) RETURNS BYTEA LANGUAGE plpgsql AS $$
DECLARE
    v_alert_hk BYTEA;
    v_alert_bk VARCHAR(255);
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_escalation_chain JSONB;
    v_requires_immediate_response BOOLEAN := FALSE;
BEGIN
    v_load_date := util.current_load_date();
    v_alert_bk := p_alert_type || '_' || 
                  COALESCE(encode(p_entity_hk, 'hex'), 'SYSTEM') || '_' ||
                  to_char(v_load_date, 'YYYYMMDD_HH24MISS');
    v_alert_hk := util.hash_binary(v_alert_bk);

    -- Determine escalation chain based on severity
    CASE p_severity
        WHEN 'CRITICAL' THEN
            v_escalation_chain := jsonb_build_object(
                'immediate_notification', true,
                'escalation_levels', ARRAY['ADMIN', 'SECURITY_TEAM', 'MANAGEMENT'],
                'max_response_time_minutes', 15
            );
            v_requires_immediate_response := TRUE;
        WHEN 'HIGH' THEN
            v_escalation_chain := jsonb_build_object(
                'immediate_notification', true,
                'escalation_levels', ARRAY['ADMIN', 'SECURITY_TEAM'],
                'max_response_time_minutes', 60
            );
        WHEN 'MEDIUM' THEN
            v_escalation_chain := jsonb_build_object(
                'immediate_notification', false,
                'escalation_levels', ARRAY['ADMIN'],
                'max_response_time_minutes', 240
            );
        ELSE
            v_escalation_chain := jsonb_build_object(
                'immediate_notification', false,
                'escalation_levels', ARRAY['SYSTEM'],
                'max_response_time_minutes', 1440
            );
    END CASE;

    -- Insert hub record
    INSERT INTO ai_monitoring.alert_h (
        alert_hk,
        alert_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_alert_hk,
        v_alert_bk,
        p_tenant_hk,
        v_load_date,
        util.get_record_source()
    );

    -- Insert satellite record with enhanced alert management
    INSERT INTO ai_monitoring.alert_details_s (
        alert_hk,
        load_date,
        hash_diff,
        alert_type,
        severity,
        alert_message_encrypted,
        alert_timestamp,
        alert_status,
        escalation_chain,
        requires_immediate_response,
        estimated_resolution_time,
        created_by_user_hk,
        record_source
    ) VALUES (
        v_alert_hk,
        v_load_date,
        util.hash_binary(p_alert_type || p_severity || p_alert_message),
        p_alert_type,
        p_severity,
        -- Encrypt alert messages for security
        pgp_sym_encrypt(p_alert_message, encode(p_tenant_hk, 'hex')),
        v_load_date,
        'ACTIVE',
        v_escalation_chain,
        v_requires_immediate_response,
        CASE p_severity
            WHEN 'CRITICAL' THEN INTERVAL '1 hour'
            WHEN 'HIGH' THEN INTERVAL '4 hours'
            WHEN 'MEDIUM' THEN INTERVAL '1 day'
            ELSE INTERVAL '3 days'
        END,
        p_created_by_user_hk,
        util.get_record_source()
    );

    -- Create analysis-alert link if analysis provided
    IF p_analysis_hk IS NOT NULL THEN
        INSERT INTO ai_monitoring.analysis_alert_l (
            analysis_alert_hk,
            ai_analysis_hk,
            alert_hk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            util.hash_binary(encode(p_analysis_hk, 'hex') || '_' || encode(v_alert_hk, 'hex')),
            p_analysis_hk,
            v_alert_hk,
            p_tenant_hk,
            v_load_date,
            util.get_record_source()
        );
    END IF;

    -- Log alert creation using existing audit system
    PERFORM audit.log_security_event(
        'ALERT_CREATED',
        p_severity,
        format('AI monitoring alert created: %s (%s)', p_alert_type, p_severity),
        NULL,
        NULL,
        p_created_by_user_hk,
        CASE p_severity
            WHEN 'CRITICAL' THEN 'CRITICAL'
            WHEN 'HIGH' THEN 'HIGH'
            ELSE 'MEDIUM'
        END,
        jsonb_build_object(
            'alert_hk', encode(v_alert_hk, 'hex'),
            'alert_type', p_alert_type,
            'severity', p_severity,
            'requires_immediate_response', v_requires_immediate_response,
            'tenant_hk', encode(p_tenant_hk, 'hex')
        )
    );

    RETURN v_alert_hk;
END;
$$;

-- =====================================================================
-- HELPER FUNCTIONS
-- =====================================================================

-- Note: Tenant context is handled through existing authentication system
-- All functions receive tenant_hk as parameters from validated API tokens

-- =====================================================================
-- PERMISSIONS
-- =====================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION ai_monitoring.validate_zero_trust_access TO authenticated_users, app_user;
GRANT EXECUTE ON FUNCTION ai_monitoring.log_security_event TO authenticated_users, app_user;
GRANT EXECUTE ON FUNCTION ai_monitoring.create_monitored_entity TO app_user;
GRANT EXECUTE ON FUNCTION ai_monitoring.store_ai_analysis TO app_user;
GRANT EXECUTE ON FUNCTION ai_monitoring.create_alert TO app_user;


-- =====================================================================
-- COMPLETION LOG
-- =====================================================================

DO $$
DECLARE
    v_deployment_id INTEGER;
BEGIN
    SELECT deployment_id INTO v_deployment_id 
    FROM util.deployment_log 
    WHERE deployment_name = 'AI_MONITORING_FUNCTIONS_V1' 
    ORDER BY deployment_start DESC 
    LIMIT 1;
    
    PERFORM util.log_deployment_complete(
        v_deployment_id,
        TRUE,
        'AI Monitoring functions deployed successfully with Zero Trust security'
    );
    
    RAISE NOTICE 'AI Monitoring functions deployment completed!';
END $$; 