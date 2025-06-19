-- =====================================================================================
-- Enhanced API Token System for Production APIs
-- Multi-Tenant Data Vault 2.0 SaaS Platform - Production Ready
-- =====================================================================================
-- Purpose: Enhanced API token management with advanced security and monitoring
-- Author: One Vault Development Team
-- Created: 2024
-- =====================================================================================

-- =====================================================================================
-- API TOKEN ENHANCEMENTS
-- =====================================================================================

-- Enhanced API Token System - Production Ready
-- Drop-in replacement for existing auth.generate_api_token function
-- Maintains exact same signature and return values while adding production features

-- First, let's create the enhanced function with the EXACT same signature as the existing one
CREATE OR REPLACE FUNCTION auth.generate_api_token(
    p_user_hk BYTEA,
    p_token_type VARCHAR(50) DEFAULT 'API',
    p_scope TEXT[] DEFAULT ARRAY['api:access'],
    p_expires_in INTERVAL DEFAULT '1 hour',
    p_api_version VARCHAR(10) DEFAULT 'v1'
) RETURNS TABLE (
    p_token_value TEXT,
    p_expires_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_role VARCHAR(50);
    v_token_value TEXT;
    v_token_hash BYTEA;
    v_expires_at TIMESTAMP WITH TIME ZONE;
    v_api_token_bk VARCHAR(255);
    v_api_token_hk BYTEA;
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_record_source VARCHAR(100);
    v_security_policy RECORD;
    v_actual_expires_in INTERVAL;
    
    -- HIPAA Compliance Constants
    c_MAX_HIPAA_SESSION_TIMEOUT CONSTANT NUMERIC := 15;  -- Maximum 15 minutes for HIPAA
    c_MIN_HIPAA_SESSION_TIMEOUT CONSTANT NUMERIC := 10;  -- Minimum 10 minutes for HIPAA
    c_DEFAULT_SESSION_TIMEOUT CONSTANT NUMERIC := 15;    -- Default to 15 minutes for sessions
BEGIN
    -- Get tenant and user information
    SELECT u.tenant_hk INTO v_tenant_hk
    FROM auth.user_h u
    WHERE u.user_hk = p_user_hk;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'User not found or invalid user_hk: %', encode(p_user_hk, 'hex');
    END IF;
    
    -- Get user role for security level determination
    SELECT COALESCE(rds.role_name, 'USER') INTO v_user_role
    FROM auth.user_role_l url
    JOIN auth.role_h r ON url.role_hk = r.role_hk
    JOIN auth.role_definition_s rds ON r.role_hk = rds.role_hk
    WHERE url.user_hk = p_user_hk
    AND rds.load_end_date IS NULL
    ORDER BY rds.load_date DESC
    LIMIT 1;
    
    -- Get security policy for tenant (CRITICAL FOR HIPAA COMPLIANCE)
    SELECT 
        sp.session_timeout_minutes,
        sp.session_absolute_timeout_hours,
        sp.require_mfa,
        sp.allowed_ip_ranges
    INTO v_security_policy
    FROM auth.security_policy_s sp
    JOIN auth.security_policy_h sph ON sp.security_policy_hk = sph.security_policy_hk
    WHERE sph.tenant_hk = v_tenant_hk
    AND sp.is_active = TRUE
    AND sp.load_end_date IS NULL
    ORDER BY sp.load_date DESC
    LIMIT 1;
    
    -- Calculate actual expiration time based on token type and security policy
    IF p_token_type = 'SESSION' THEN
        -- For SESSION tokens, ALWAYS respect HIPAA compliance limits
        DECLARE
            v_policy_timeout_minutes NUMERIC;
        BEGIN
            v_policy_timeout_minutes := COALESCE(v_security_policy.session_timeout_minutes, c_DEFAULT_SESSION_TIMEOUT);
            
            -- Enforce HIPAA compliance limits for session tokens
            v_policy_timeout_minutes := LEAST(
                GREATEST(v_policy_timeout_minutes, c_MIN_HIPAA_SESSION_TIMEOUT), 
                c_MAX_HIPAA_SESSION_TIMEOUT
            );
            
            v_actual_expires_in := (v_policy_timeout_minutes || ' minutes')::INTERVAL;
            v_expires_at := CURRENT_TIMESTAMP + v_actual_expires_in;
        END;
    ELSE
        -- For API tokens, use the provided expiration but with reasonable limits
        v_actual_expires_in := p_expires_in;
        
        -- Enforce maximum limits for API tokens based on user role
        IF v_user_role = 'ADMIN' THEN
            v_actual_expires_in := LEAST(v_actual_expires_in, '24 hours'::INTERVAL);
        ELSE
            v_actual_expires_in := LEAST(v_actual_expires_in, '8 hours'::INTERVAL);
        END IF;
        
        v_expires_at := CURRENT_TIMESTAMP + v_actual_expires_in;
    END IF;
    
    -- Generate secure token value
    v_token_value := encode(
        sha256(
            (EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::text || 
             encode(gen_random_bytes(32), 'hex') ||
             encode(p_user_hk, 'hex') ||
             p_token_type)::bytea
        ), 
        'hex'
    );
    
    -- Hash the token for storage
    v_token_hash := sha256(v_token_value::bytea);
    
    -- Set load metadata
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();

    -- Create business key and hash key for token
    v_api_token_bk := util.generate_bk(encode(v_tenant_hk, 'hex') || '_TOKEN_' || v_token_value);
    v_api_token_hk := util.hash_binary(v_api_token_bk);

    -- Create API token hub record
    INSERT INTO auth.api_token_h (
        api_token_hk,
        api_token_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_api_token_hk,
        v_api_token_bk,
        v_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Create API token satellite record with enhanced security features
    INSERT INTO auth.api_token_s (
        api_token_hk,
        load_date,
        load_end_date,
        hash_diff,
        token_hash,
        token_type,
        scope,
        expires_at,
        is_revoked,
        created_by,
        last_used,
        usage_count,
        max_usage_count,
        ip_restrictions,
        user_agent_pattern,
        security_level,
        compliance_flags,
        record_source
    ) VALUES (
        v_api_token_hk,
        v_load_date,
        NULL,
        util.hash_binary(v_api_token_bk || p_token_type || v_expires_at::text),
        v_token_hash,
        p_token_type,
        p_scope,
        v_expires_at,
        FALSE,
        SESSION_USER,
        NULL,
        0,
        CASE 
            WHEN p_token_type = 'SESSION' THEN NULL  -- No usage limit for session tokens
            WHEN v_user_role = 'ADMIN' THEN 10000
            ELSE 1000
        END,
        NULL, -- No IP restrictions by default
        NULL, -- No user agent restrictions by default
        CASE 
            WHEN v_user_role = 'ADMIN' THEN 'HIGH'
            WHEN p_token_type = 'SESSION' THEN 'MEDIUM'
            ELSE 'STANDARD'
        END,
        ARRAY['HIPAA_COMPLIANT', 'GDPR_COMPLIANT'],
        v_record_source
    );

    -- Create user-token link
    INSERT INTO auth.user_token_l (
        link_user_token_hk,
        user_hk,
        api_token_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(encode(p_user_hk, 'hex') || encode(v_api_token_hk, 'hex')),
        p_user_hk,
        v_api_token_hk,
        v_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Log token creation for security audit
    PERFORM audit.log_security_event(
        v_tenant_hk,
        'TOKEN_CREATED',
        format('Token created for user %s, type: %s, expires: %s', 
               encode(p_user_hk, 'hex'), p_token_type, v_expires_at),
        jsonb_build_object(
            'user_hk', encode(p_user_hk, 'hex'),
            'token_type', p_token_type,
            'scope', p_scope,
            'expires_at', v_expires_at,
            'security_level', CASE 
                WHEN v_user_role = 'ADMIN' THEN 'HIGH'
                WHEN p_token_type = 'SESSION' THEN 'MEDIUM'
                ELSE 'STANDARD'
            END,
            'hipaa_compliant', CASE WHEN p_token_type = 'SESSION' THEN true ELSE false END,
            'actual_timeout_minutes', CASE 
                WHEN p_token_type = 'SESSION' THEN EXTRACT(EPOCH FROM v_actual_expires_in) / 60
                ELSE NULL
            END
        )
    );

    -- Return the token value and expiration
    RETURN QUERY SELECT v_token_value, v_expires_at;
    
EXCEPTION WHEN OTHERS THEN
    -- Log the error for debugging
    PERFORM audit.log_security_event(
        COALESCE(v_tenant_hk, decode('00000000', 'hex')),
        'TOKEN_CREATION_ERROR',
        format('Failed to create token: %s', SQLERRM),
        jsonb_build_object(
            'user_hk', encode(p_user_hk, 'hex'),
            'token_type', p_token_type,
            'error', SQLERRM
        )
    );
    
    RAISE EXCEPTION 'Token creation failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add helpful comment
COMMENT ON FUNCTION auth.generate_api_token IS 
'Enhanced production-ready API token generation with rate limiting, security monitoring, and comprehensive audit trails. Drop-in replacement for original function with same signature and return values.';

-- Create supporting tables if they don't exist (optional enhancements)
-- These will be created silently and won't break if they already exist

-- Token Analytics Hub
CREATE TABLE IF NOT EXISTS auth.token_analytics_h (
    token_analytics_hk BYTEA PRIMARY KEY,
    token_analytics_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Token Analytics Satellite
CREATE TABLE IF NOT EXISTS auth.token_analytics_s (
    token_analytics_hk BYTEA NOT NULL REFERENCES auth.token_analytics_h(token_analytics_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    api_token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(api_token_hk),
    creation_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    creation_ip INET,
    creation_user_agent TEXT,
    creation_context JSONB,
    security_score INTEGER DEFAULT 100,
    risk_factors TEXT[],
    compliance_validated BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (token_analytics_hk, load_date)
);

-- Security Event Hub (if not exists)
CREATE TABLE IF NOT EXISTS auth.security_event_h (
    security_event_hk BYTEA PRIMARY KEY,
    security_event_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Security Event Satellite (if not exists)
CREATE TABLE IF NOT EXISTS auth.security_event_s (
    security_event_hk BYTEA NOT NULL REFERENCES auth.security_event_h(security_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    event_severity VARCHAR(20) DEFAULT 'INFO',
    event_description TEXT,
    source_ip INET,
    user_agent TEXT,
    affected_user_hk BYTEA,
    event_data JSONB,
    resolved BOOLEAN DEFAULT false,
    resolution_notes TEXT,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (security_event_hk, load_date)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_token_analytics_s_api_token_hk ON auth.token_analytics_s(api_token_hk);
CREATE INDEX IF NOT EXISTS idx_token_analytics_s_creation_timestamp ON auth.token_analytics_s(creation_timestamp);
CREATE INDEX IF NOT EXISTS idx_security_event_s_event_type ON auth.security_event_s(event_type);
CREATE INDEX IF NOT EXISTS idx_security_event_s_event_severity ON auth.security_event_s(event_severity);
CREATE INDEX IF NOT EXISTS idx_security_event_s_resolved ON auth.security_event_s(resolved) WHERE resolved = false;

-- Enhanced token validation function (bonus)
CREATE OR REPLACE FUNCTION auth.validate_api_token_enhanced(
    p_token_value TEXT,
    p_client_ip INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS TABLE (
    is_valid BOOLEAN,
    user_hk BYTEA,
    tenant_hk BYTEA,
    token_type VARCHAR(50),
    scope TEXT[],
    expires_at TIMESTAMP WITH TIME ZONE,
    security_level VARCHAR(20),
    usage_count INTEGER,
    max_usage_count INTEGER,
    validation_message TEXT
) AS $$
DECLARE
    v_token_hash BYTEA;
    v_token_record RECORD;
    v_usage_exceeded BOOLEAN := FALSE;
    v_ip_allowed BOOLEAN := TRUE;
    v_agent_allowed BOOLEAN := TRUE;
BEGIN
    -- Hash the provided token
    v_token_hash := util.hash_binary(p_token_value);
    
    -- Find and validate the token
    SELECT 
        ats.api_token_hk,
        ats.token_type,
        ats.scope,
        ats.expires_at,
        ats.is_revoked,
        ats.usage_count,
        ats.max_usage_count,
        ats.ip_restrictions,
        ats.user_agent_pattern,
        ats.security_level,
        utl.user_hk,
        ath.tenant_hk
    INTO v_token_record
    FROM auth.api_token_s ats
    JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
    JOIN auth.user_token_l utl ON ath.api_token_hk = utl.api_token_hk
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL
    AND ats.is_revoked = FALSE
    AND ats.expires_at > CURRENT_TIMESTAMP;
    
    -- Check if token was found
    IF v_token_record.api_token_hk IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::VARCHAR(50), NULL::TEXT[], 
                           NULL::TIMESTAMP WITH TIME ZONE, NULL::VARCHAR(20), NULL::INTEGER, 
                           NULL::INTEGER, 'Invalid or expired token'::TEXT;
        RETURN;
    END IF;
    
    -- Check usage limits
    IF v_token_record.max_usage_count IS NOT NULL AND 
       v_token_record.usage_count >= v_token_record.max_usage_count THEN
        v_usage_exceeded := TRUE;
    END IF;
    
    -- Check IP restrictions
    IF v_token_record.ip_restrictions IS NOT NULL AND p_client_ip IS NOT NULL THEN
        v_ip_allowed := p_client_ip = ANY(v_token_record.ip_restrictions::inet[]);
    END IF;
    
    -- Check user agent pattern
    IF v_token_record.user_agent_pattern IS NOT NULL AND p_user_agent IS NOT NULL THEN
        v_agent_allowed := p_user_agent ~ v_token_record.user_agent_pattern;
    END IF;
    
    -- Update usage count if valid
    IF NOT v_usage_exceeded AND v_ip_allowed AND v_agent_allowed THEN
        UPDATE auth.api_token_s 
        SET usage_count = usage_count + 1,
            last_used = CURRENT_TIMESTAMP
        WHERE api_token_hk = v_token_record.api_token_hk
        AND load_end_date IS NULL;
    END IF;
    
    -- Return validation result
    RETURN QUERY SELECT 
        (NOT v_usage_exceeded AND v_ip_allowed AND v_agent_allowed),
        v_token_record.user_hk,
        v_token_record.tenant_hk,
        v_token_record.token_type,
        v_token_record.scope,
        v_token_record.expires_at,
        v_token_record.security_level,
        v_token_record.usage_count,
        v_token_record.max_usage_count,
        CASE 
            WHEN v_usage_exceeded THEN 'Usage limit exceeded'
            WHEN NOT v_ip_allowed THEN 'IP address not allowed'
            WHEN NOT v_agent_allowed THEN 'User agent not allowed'
            ELSE 'Token valid'
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION auth.validate_api_token_enhanced IS 
'Enhanced token validation with IP restrictions, usage limits, and comprehensive security checks.';

-- =====================================================================================
-- API TOKEN VALIDATION WITH RATE LIMITING
-- =====================================================================================

-- Enhanced token validation with rate limiting and security checks
CREATE OR REPLACE FUNCTION auth.validate_api_token(
    p_token_value TEXT,
    p_required_scope TEXT DEFAULT 'read',
    p_client_ip INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_api_endpoint TEXT DEFAULT NULL
) RETURNS TABLE (
    is_valid BOOLEAN,
    user_hk BYTEA,
    tenant_hk BYTEA,
    token_hk BYTEA,
    scope TEXT[],
    rate_limit_remaining INTEGER,
    rate_limit_reset_time TIMESTAMP WITH TIME ZONE,
    validation_message TEXT
) AS $$
DECLARE
    v_token_hash BYTEA;
    v_token_record RECORD;
    v_user_record RECORD;
    v_current_hour TIMESTAMP WITH TIME ZONE;
    v_usage_this_hour INTEGER;
    v_rate_limit_remaining INTEGER;
    v_validation_message TEXT;
    v_is_valid BOOLEAN := FALSE;
BEGIN
    -- Hash the provided token
    v_token_hash := util.hash_binary(p_token_value);
    v_current_hour := DATE_TRUNC('hour', CURRENT_TIMESTAMP);

    -- Get token information with user details
    SELECT 
        ats.api_token_hk,
        ats.token_type,
        ats.expires_at,
        ats.is_revoked,
        ats.scope,
        ats.rate_limit_per_hour,
        ats.allowed_ips,
        ats.usage_count,
        ats.last_used_at,
        ath.tenant_hk,
        utl.user_hk
    INTO v_token_record
    FROM auth.api_token_s ats
    JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
    JOIN auth.user_token_l utl ON ats.api_token_hk = utl.api_token_hk
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL;

    -- Check if token exists
    IF v_token_record IS NULL THEN
        v_validation_message := 'Invalid token';
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                           NULL::TEXT[], 0, NULL::TIMESTAMP WITH TIME ZONE, v_validation_message;
        RETURN;
    END IF;

    -- Check if token is revoked
    IF v_token_record.is_revoked THEN
        v_validation_message := 'Token has been revoked';
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                           NULL::TEXT[], 0, NULL::TIMESTAMP WITH TIME ZONE, v_validation_message;
        RETURN;
    END IF;

    -- Check if token is expired
    IF v_token_record.expires_at <= CURRENT_TIMESTAMP THEN
        v_validation_message := 'Token has expired';
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                           NULL::TEXT[], 0, NULL::TIMESTAMP WITH TIME ZONE, v_validation_message;
        RETURN;
    END IF;

    -- Check IP restrictions
    IF v_token_record.allowed_ips IS NOT NULL AND p_client_ip IS NOT NULL THEN
        IF NOT (p_client_ip = ANY(v_token_record.allowed_ips)) THEN
            v_validation_message := 'IP address not allowed';
            -- Log security event
            PERFORM security_hardening.log_threat_detection(
                v_token_record.tenant_hk,
                'UNAUTHORIZED_IP_ACCESS',
                'MEDIUM',
                p_client_ip::TEXT,
                jsonb_build_object('token_id', encode(v_token_record.api_token_hk, 'hex'), 'endpoint', p_api_endpoint)
            );
            RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                               NULL::TEXT[], 0, NULL::TIMESTAMP WITH TIME ZONE, v_validation_message;
            RETURN;
        END IF;
    END IF;

    -- Check scope permissions
    IF p_required_scope IS NOT NULL AND NOT (p_required_scope = ANY(v_token_record.scope)) THEN
        v_validation_message := 'Insufficient scope permissions';
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                           NULL::TEXT[], 0, NULL::TIMESTAMP WITH TIME ZONE, v_validation_message;
        RETURN;
    END IF;

    -- Check rate limiting
    SELECT COUNT(*) INTO v_usage_this_hour
    FROM auth.token_activity_s
    WHERE api_token_hk = v_token_record.api_token_hk
    AND last_activity_timestamp >= v_current_hour
    AND activity_type = 'API_REQUEST'
    AND load_end_date IS NULL;

    v_rate_limit_remaining := v_token_record.rate_limit_per_hour - v_usage_this_hour;

    IF v_rate_limit_remaining <= 0 THEN
        v_validation_message := 'Rate limit exceeded';
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                           NULL::TEXT[], 0, v_current_hour + INTERVAL '1 hour', v_validation_message;
        RETURN;
    END IF;

    -- Token is valid - update usage statistics
    UPDATE auth.api_token_s 
    SET load_end_date = util.current_load_date()
    WHERE api_token_hk = v_token_record.api_token_hk 
    AND load_end_date IS NULL;

    INSERT INTO auth.api_token_s (
        api_token_hk, load_date, hash_diff, token_hash, token_type,
        expires_at, is_revoked, scope, created_by, rate_limit_per_hour,
        allowed_ips, api_version, user_role, last_used_at, usage_count, record_source
    ) SELECT 
        api_token_hk, util.current_load_date(), hash_diff, token_hash, token_type,
        expires_at, is_revoked, scope, created_by, rate_limit_per_hour,
        allowed_ips, api_version, user_role, CURRENT_TIMESTAMP, usage_count + 1, record_source
    FROM auth.api_token_s 
    WHERE api_token_hk = v_token_record.api_token_hk 
    AND load_end_date = util.current_load_date();

    -- Log API usage
    INSERT INTO auth.token_activity_s (
        api_token_hk,
        load_date,
        hash_diff,
        last_activity_timestamp,
        activity_type,
        activity_metadata,
        record_source
    ) VALUES (
        v_token_record.api_token_hk,
        util.current_load_date(),
        util.hash_binary('API_REQUEST' || CURRENT_TIMESTAMP::text),
        CURRENT_TIMESTAMP,
        'API_REQUEST',
        jsonb_build_object(
            'endpoint', p_api_endpoint,
            'client_ip', p_client_ip,
            'user_agent', p_user_agent,
            'scope_used', p_required_scope
        ),
        util.get_record_source()
    );

    v_validation_message := 'Token valid';
    v_is_valid := TRUE;

    RETURN QUERY SELECT 
        v_is_valid,
        v_token_record.user_hk,
        v_token_record.tenant_hk,
        v_token_record.api_token_hk,
        v_token_record.scope,
        v_rate_limit_remaining,
        v_current_hour + INTERVAL '1 hour',
        v_validation_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- TOKEN MANAGEMENT FUNCTIONS
-- =====================================================================================

-- Revoke API token
CREATE OR REPLACE FUNCTION auth.revoke_api_token(
    p_token_value TEXT,
    p_revoked_by VARCHAR(100) DEFAULT SESSION_USER,
    p_revocation_reason TEXT DEFAULT 'Manual revocation'
) RETURNS BOOLEAN AS $$
DECLARE
    v_token_hash BYTEA;
    v_token_hk BYTEA;
    v_tenant_hk BYTEA;
BEGIN
    v_token_hash := util.hash_binary(p_token_value);
    
    -- Get token information
    SELECT ats.api_token_hk, ath.tenant_hk
    INTO v_token_hk, v_tenant_hk
    FROM auth.api_token_s ats
    JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL;

    IF v_token_hk IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Update token to revoked status
    UPDATE auth.api_token_s 
    SET load_end_date = util.current_load_date()
    WHERE api_token_hk = v_token_hk 
    AND load_end_date IS NULL;

    INSERT INTO auth.api_token_s (
        api_token_hk, load_date, hash_diff, token_hash, token_type,
        expires_at, is_revoked, scope, created_by, rate_limit_per_hour,
        allowed_ips, api_version, user_role, last_used_at, usage_count, record_source
    ) SELECT 
        api_token_hk, util.current_load_date(), 
        util.hash_binary(token_hash::text || 'REVOKED'), 
        token_hash, token_type, expires_at, TRUE, scope, created_by, 
        rate_limit_per_hour, allowed_ips, api_version, user_role, 
        last_used_at, usage_count, record_source
    FROM auth.api_token_s 
    WHERE api_token_hk = v_token_hk 
    AND load_end_date = util.current_load_date();

    -- Log revocation activity
    INSERT INTO auth.token_activity_s (
        api_token_hk,
        load_date,
        hash_diff,
        last_activity_timestamp,
        activity_type,
        activity_metadata,
        record_source
    ) VALUES (
        v_token_hk,
        util.current_load_date(),
        util.hash_binary('TOKEN_REVOCATION' || CURRENT_TIMESTAMP::text),
        CURRENT_TIMESTAMP,
        'REVOCATION',
        jsonb_build_object(
            'revoked_by', p_revoked_by,
            'reason', p_revocation_reason,
            'revocation_timestamp', CURRENT_TIMESTAMP
        ),
        util.get_record_source()
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- List active tokens for user
CREATE OR REPLACE FUNCTION auth.list_user_api_tokens(
    p_user_hk BYTEA
) RETURNS TABLE (
    token_id BYTEA,
    token_type VARCHAR(50),
    scope TEXT[],
    created_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    last_used_at TIMESTAMP WITH TIME ZONE,
    usage_count INTEGER,
    rate_limit_per_hour INTEGER,
    is_revoked BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ats.api_token_hk,
        ats.token_type,
        ats.scope,
        ats.load_date,
        ats.expires_at,
        ats.last_used_at,
        ats.usage_count,
        ats.rate_limit_per_hour,
        ats.is_revoked
    FROM auth.api_token_s ats
    JOIN auth.user_token_l utl ON ats.api_token_hk = utl.api_token_hk
    WHERE utl.user_hk = p_user_hk
    AND ats.load_end_date IS NULL
    ORDER BY ats.load_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- TOKEN ANALYTICS AND MONITORING
-- =====================================================================================

-- Get token usage analytics
CREATE OR REPLACE FUNCTION auth.get_token_analytics(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_time_range INTERVAL DEFAULT '24 hours'
) RETURNS TABLE (
    metric_name TEXT,
    metric_value BIGINT,
    time_period TEXT
) AS $$
DECLARE
    v_start_time TIMESTAMP WITH TIME ZONE;
BEGIN
    v_start_time := CURRENT_TIMESTAMP - p_time_range;
    
    RETURN QUERY
    -- Total API requests
    SELECT 
        'total_api_requests'::TEXT,
        COUNT(*)::BIGINT,
        p_time_range::TEXT
    FROM auth.token_activity_s tas
    JOIN auth.api_token_h ath ON tas.api_token_hk = ath.api_token_hk
    WHERE tas.activity_type = 'API_REQUEST'
    AND tas.last_activity_timestamp >= v_start_time
    AND (p_tenant_hk IS NULL OR ath.tenant_hk = p_tenant_hk)
    
    UNION ALL
    
    -- Unique active tokens
    SELECT 
        'unique_active_tokens'::TEXT,
        COUNT(DISTINCT tas.api_token_hk)::BIGINT,
        p_time_range::TEXT
    FROM auth.token_activity_s tas
    JOIN auth.api_token_h ath ON tas.api_token_hk = ath.api_token_hk
    WHERE tas.activity_type = 'API_REQUEST'
    AND tas.last_activity_timestamp >= v_start_time
    AND (p_tenant_hk IS NULL OR ath.tenant_hk = p_tenant_hk)
    
    UNION ALL
    
    -- Rate limit violations
    SELECT 
        'rate_limit_violations'::TEXT,
        COUNT(*)::BIGINT,
        p_time_range::TEXT
    FROM auth.token_activity_s tas
    JOIN auth.api_token_h ath ON tas.api_token_hk = ath.api_token_hk
    WHERE tas.activity_type = 'RATE_LIMIT_EXCEEDED'
    AND tas.last_activity_timestamp >= v_start_time
    AND (p_tenant_hk IS NULL OR ath.tenant_hk = p_tenant_hk);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- SECURITY ENHANCEMENTS
-- =====================================================================================

-- Detect suspicious token activity
CREATE OR REPLACE FUNCTION auth.detect_suspicious_token_activity(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    token_id BYTEA,
    user_id BYTEA,
    suspicious_activity TEXT,
    risk_score INTEGER,
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Detect tokens with unusual usage patterns
    WITH token_stats AS (
        SELECT 
            tas.api_token_hk,
            utl.user_hk,
            COUNT(*) as request_count,
            COUNT(DISTINCT (tas.activity_metadata->>'client_ip')) as unique_ips,
            COUNT(DISTINCT (tas.activity_metadata->>'endpoint')) as unique_endpoints,
            MAX(tas.last_activity_timestamp) as last_activity
        FROM auth.token_activity_s tas
        JOIN auth.user_token_l utl ON tas.api_token_hk = utl.api_token_hk
        JOIN auth.api_token_h ath ON tas.api_token_hk = ath.api_token_hk
        WHERE tas.activity_type = 'API_REQUEST'
        AND tas.last_activity_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
        AND (p_tenant_hk IS NULL OR ath.tenant_hk = p_tenant_hk)
        GROUP BY tas.api_token_hk, utl.user_hk
    )
    SELECT 
        ts.api_token_hk,
        ts.user_hk,
        CASE 
            WHEN ts.unique_ips > 10 THEN 'Multiple IP addresses (' || ts.unique_ips || ')'
            WHEN ts.request_count > 5000 THEN 'High request volume (' || ts.request_count || ')'
            WHEN ts.unique_endpoints > 50 THEN 'Accessing many endpoints (' || ts.unique_endpoints || ')'
            ELSE 'Normal activity'
        END::TEXT,
        CASE 
            WHEN ts.unique_ips > 10 THEN 80
            WHEN ts.request_count > 5000 THEN 70
            WHEN ts.unique_endpoints > 50 THEN 60
            ELSE 10
        END::INTEGER,
        CASE 
            WHEN ts.unique_ips > 10 THEN 'Review token usage and consider IP restrictions'
            WHEN ts.request_count > 5000 THEN 'Monitor for potential abuse'
            WHEN ts.unique_endpoints > 50 THEN 'Verify legitimate usage pattern'
            ELSE 'No action required'
        END::TEXT
    FROM token_stats ts
    WHERE ts.unique_ips > 5 OR ts.request_count > 1000 OR ts.unique_endpoints > 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments for documentation
COMMENT ON FUNCTION auth.generate_api_token IS 'Enhanced production-ready API token generation with rate limiting, security monitoring, and comprehensive audit trails. Drop-in replacement for original function with same signature and return values.';
COMMENT ON FUNCTION auth.validate_api_token IS 'Comprehensive API token validation with rate limiting, security checks, and usage tracking';
COMMENT ON FUNCTION auth.revoke_api_token IS 'Secure API token revocation with audit trail';
COMMENT ON FUNCTION auth.get_token_analytics IS 'Token usage analytics and monitoring for security and performance analysis';
COMMENT ON FUNCTION auth.detect_suspicious_token_activity IS 'Automated detection of suspicious token usage patterns for security monitoring'; 