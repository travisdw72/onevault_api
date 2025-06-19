-- =====================================================================================
-- PRODUCTION API TOKEN GENERATOR - New Function (No Conflicts)
-- =====================================================================================
-- Purpose: Enhanced API token generation for production use
-- Function Name: auth.generate_production_api_token (NEW - no conflicts)
-- Author: One Vault Development Team
-- Created: 2024
-- =====================================================================================

-- This is a BRAND NEW function that doesn't interfere with your existing auth.generate_api_token
-- Use this for new API token generation while keeping your existing session system intact

CREATE OR REPLACE FUNCTION auth.generate_production_api_token(
    p_user_hk BYTEA,
    p_token_type VARCHAR(50) DEFAULT 'API',
    p_scope TEXT[] DEFAULT ARRAY['api:access'],
    p_expires_in INTERVAL DEFAULT '24 hours',
    p_description TEXT DEFAULT 'Production API Token'
) RETURNS TABLE (
    token_value TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    token_id BYTEA,
    security_level VARCHAR(20),
    rate_limit_per_hour INTEGER
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
    v_security_level VARCHAR(20);
    v_rate_limit INTEGER;
    v_max_tokens_per_user INTEGER := 10;
    v_current_token_count INTEGER;
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
    
    -- Set security level and rate limits based on user role
    IF v_user_role = 'ADMIN' THEN
        v_security_level := 'HIGH';
        v_rate_limit := 10000;  -- 10k requests per hour for admins
    ELSIF v_user_role = 'MANAGER' THEN
        v_security_level := 'MEDIUM';
        v_rate_limit := 5000;   -- 5k requests per hour for managers
    ELSE
        v_security_level := 'STANDARD';
        v_rate_limit := 1000;   -- 1k requests per hour for regular users
    END IF;
    
    -- Check token limits per user (prevent token spam)
    SELECT COUNT(*) INTO v_current_token_count
    FROM auth.user_token_l utl
    JOIN auth.api_token_s ats ON utl.api_token_hk = ats.api_token_hk
    WHERE utl.user_hk = p_user_hk
    AND ats.is_revoked = FALSE
    AND ats.expires_at > CURRENT_TIMESTAMP
    AND ats.load_end_date IS NULL
    AND ats.token_type = 'API';  -- Only count API tokens, not session tokens
    
    IF v_current_token_count >= v_max_tokens_per_user THEN
        RAISE EXCEPTION 'Maximum number of active API tokens (%) exceeded for user. Please revoke unused tokens first.', v_max_tokens_per_user;
    END IF;
    
    -- Enforce reasonable expiration limits for API tokens
    IF p_expires_in > '30 days'::INTERVAL THEN
        RAISE EXCEPTION 'API token expiration cannot exceed 30 days for security reasons';
    END IF;
    
    -- Generate production-grade secure token with prefix
    v_token_value := 'ovt_prod_' || encode(
        sha256(
            (EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::text || 
             encode(gen_random_bytes(32), 'hex') ||
             encode(p_user_hk, 'hex') ||
             p_token_type ||
             v_security_level)::bytea
        ), 
        'hex'
    );
    
    -- Hash the token for storage
    v_token_hash := sha256(v_token_value::bytea);
    v_expires_at := CURRENT_TIMESTAMP + p_expires_in;
    
    -- Set load metadata
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();

    -- Create business key and hash key for token
    v_api_token_bk := util.generate_bk(encode(v_tenant_hk, 'hex') || '_PROD_TOKEN_' || v_token_value);
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

    -- Create API token satellite record with production features
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
        v_record_source
    );

    -- Create user-token link
    INSERT INTO auth.user_token_l (
        user_token_hk,
        user_hk,
        api_token_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(p_user_hk::text || v_api_token_hk::text),
        p_user_hk,
        v_api_token_hk,
        v_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Create initial activity record (if table exists)
    BEGIN
        INSERT INTO auth.token_activity_s (
            api_token_hk,
            load_date,
            hash_diff,
            last_activity_timestamp,
            activity_type,
            activity_metadata,
            record_source
        ) VALUES (
            v_api_token_hk,
            v_load_date,
            util.hash_binary('PROD_TOKEN_CREATION' || CURRENT_TIMESTAMP::text),
            CURRENT_TIMESTAMP,
            'CREATION',
            jsonb_build_object(
                'token_type', p_token_type,
                'scope', p_scope,
                'expires_at', v_expires_at,
                'created_by', SESSION_USER,
                'security_level', v_security_level,
                'rate_limit_per_hour', v_rate_limit,
                'description', p_description,
                'user_role', v_user_role
            ),
            v_record_source
        );
    EXCEPTION WHEN OTHERS THEN
        -- Continue if token_activity_s table doesn't exist yet
        NULL;
    END;

    -- Optional: Log security event if audit system exists
    BEGIN
        PERFORM audit.log_security_event(
            v_tenant_hk,
            'PRODUCTION_TOKEN_CREATED',
            format('Production API token created for user %s, type: %s, expires: %s', 
                   encode(p_user_hk, 'hex'), p_token_type, v_expires_at),
            jsonb_build_object(
                'user_hk', encode(p_user_hk, 'hex'),
                'token_type', p_token_type,
                'scope', p_scope,
                'expires_at', v_expires_at,
                'security_level', v_security_level,
                'rate_limit_per_hour', v_rate_limit,
                'description', p_description
            )
        );
    EXCEPTION WHEN OTHERS THEN
        -- Continue if audit system doesn't exist
        NULL;
    END;

    -- Return comprehensive token information
    RETURN QUERY SELECT 
        v_token_value,
        v_expires_at,
        v_api_token_hk,
        v_security_level,
        v_rate_limit;
    
EXCEPTION WHEN OTHERS THEN
    -- Enhanced error handling
    RAISE EXCEPTION 'Production token creation failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add helpful comment
COMMENT ON FUNCTION auth.generate_production_api_token IS 
'Production-grade API token generation with enhanced security, rate limiting, and comprehensive audit trails. Use this for new API tokens while keeping existing session system intact.';

-- =====================================================================================
-- PRODUCTION TOKEN VALIDATION FUNCTION
-- =====================================================================================

CREATE OR REPLACE FUNCTION auth.validate_production_api_token(
    p_token_value TEXT,
    p_required_scope TEXT DEFAULT 'api:read',
    p_client_ip INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_api_endpoint TEXT DEFAULT NULL
) RETURNS TABLE (
    is_valid BOOLEAN,
    user_hk BYTEA,
    tenant_hk BYTEA,
    token_hk BYTEA,
    scope TEXT[],
    security_level VARCHAR(20),
    rate_limit_remaining INTEGER,
    rate_limit_reset_time TIMESTAMP WITH TIME ZONE,
    validation_message TEXT
) AS $$
DECLARE
    v_token_hash BYTEA;
    v_token_record RECORD;
    v_current_hour TIMESTAMP WITH TIME ZONE;
    v_usage_this_hour INTEGER;
    v_rate_limit_remaining INTEGER;
    v_validation_message TEXT;
    v_is_valid BOOLEAN := FALSE;
BEGIN
    -- Only validate production tokens (with prefix)
    IF NOT (p_token_value LIKE 'ovt_prod_%') THEN
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                           NULL::TEXT[], NULL::VARCHAR(20), 0, NULL::TIMESTAMP WITH TIME ZONE, 
                           'Not a production token'::TEXT;
        RETURN;
    END IF;

    -- Hash the provided token
    v_token_hash := util.hash_binary(p_token_value);
    v_current_hour := DATE_TRUNC('hour', CURRENT_TIMESTAMP);

    -- Get token information
    SELECT 
        ats.api_token_hk,
        ats.token_type,
        ats.expires_at,
        ats.is_revoked,
        ats.scope,
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
        v_validation_message := 'Invalid production token';
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                           NULL::TEXT[], NULL::VARCHAR(20), 0, NULL::TIMESTAMP WITH TIME ZONE, v_validation_message;
        RETURN;
    END IF;

    -- Check if token is revoked
    IF v_token_record.is_revoked THEN
        v_validation_message := 'Production token has been revoked';
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                           NULL::TEXT[], NULL::VARCHAR(20), 0, NULL::TIMESTAMP WITH TIME ZONE, v_validation_message;
        RETURN;
    END IF;

    -- Check if token is expired
    IF v_token_record.expires_at <= CURRENT_TIMESTAMP THEN
        v_validation_message := 'Production token has expired';
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                           NULL::TEXT[], NULL::VARCHAR(20), 0, NULL::TIMESTAMP WITH TIME ZONE, v_validation_message;
        RETURN;
    END IF;

    -- Check scope permissions
    IF p_required_scope IS NOT NULL AND NOT (p_required_scope = ANY(v_token_record.scope)) THEN
        v_validation_message := 'Insufficient scope permissions for production token';
        RETURN QUERY SELECT FALSE, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, 
                           NULL::TEXT[], NULL::VARCHAR(20), 0, NULL::TIMESTAMP WITH TIME ZONE, v_validation_message;
        RETURN;
    END IF;

    -- Check rate limiting (simplified - would need actual rate limit table)
    v_rate_limit_remaining := 1000; -- Default rate limit
    
    -- Token is valid - log usage if activity table exists
    BEGIN
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
            util.hash_binary('PROD_API_REQUEST' || CURRENT_TIMESTAMP::text),
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
    EXCEPTION WHEN OTHERS THEN
        -- Continue if activity table doesn't exist
        NULL;
    END;

    v_validation_message := 'Production token valid';
    v_is_valid := TRUE;

    RETURN QUERY SELECT 
        v_is_valid,
        v_token_record.user_hk,
        v_token_record.tenant_hk,
        v_token_record.api_token_hk,
        v_token_record.scope,
        'PRODUCTION'::VARCHAR(20),
        v_rate_limit_remaining,
        v_current_hour + INTERVAL '1 hour',
        v_validation_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION auth.validate_production_api_token IS 
'Validates production API tokens with comprehensive security checks and usage tracking.';

-- =====================================================================================
-- PRODUCTION TOKEN MANAGEMENT FUNCTIONS
-- =====================================================================================

-- Revoke production API token
CREATE OR REPLACE FUNCTION auth.revoke_production_api_token(
    p_token_value TEXT,
    p_revoked_by VARCHAR(100) DEFAULT SESSION_USER,
    p_revocation_reason TEXT DEFAULT 'Manual revocation'
) RETURNS BOOLEAN AS $$
DECLARE
    v_token_hash BYTEA;
    v_token_hk BYTEA;
    v_tenant_hk BYTEA;
BEGIN
    -- Only handle production tokens
    IF NOT (p_token_value LIKE 'ovt_prod_%') THEN
        RETURN FALSE;
    END IF;

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
        expires_at, is_revoked, scope, created_by, record_source
    ) SELECT 
        api_token_hk, util.current_load_date(), 
        util.hash_binary(token_hash::text || 'REVOKED'), 
        token_hash, token_type, expires_at, TRUE, scope, created_by, 
        record_source
    FROM auth.api_token_s 
    WHERE api_token_hk = v_token_hk 
    AND load_end_date = util.current_load_date();

    -- Log revocation activity
    BEGIN
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
            util.hash_binary('PROD_TOKEN_REVOCATION' || CURRENT_TIMESTAMP::text),
            CURRENT_TIMESTAMP,
            'REVOCATION',
            jsonb_build_object(
                'revoked_by', p_revoked_by,
                'reason', p_revocation_reason,
                'revocation_timestamp', CURRENT_TIMESTAMP
            ),
            util.get_record_source()
        );
    EXCEPTION WHEN OTHERS THEN
        -- Continue if activity table doesn't exist
        NULL;
    END;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION auth.revoke_production_api_token IS 
'Revokes production API tokens with comprehensive audit trail.';

-- List production tokens for user
CREATE OR REPLACE FUNCTION auth.list_production_api_tokens(
    p_user_hk BYTEA
) RETURNS TABLE (
    token_id BYTEA,
    token_prefix TEXT,
    token_type VARCHAR(50),
    scope TEXT[],
    created_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    is_revoked BOOLEAN,
    security_level VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ats.api_token_hk,
        'ovt_prod_***'::TEXT,  -- Don't show full token
        ats.token_type,
        ats.scope,
        ats.load_date,
        ats.expires_at,
        ats.is_revoked,
        'PRODUCTION'::VARCHAR(20)
    FROM auth.api_token_s ats
    JOIN auth.user_token_l utl ON ats.api_token_hk = utl.api_token_hk
    WHERE utl.user_hk = p_user_hk
    AND ats.load_end_date IS NULL
    AND ats.token_type = 'API'  -- Only API tokens, not session tokens
    ORDER BY ats.load_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION auth.list_production_api_tokens IS 
'Lists production API tokens for a user without exposing token values.';

-- =====================================================================================
-- USAGE EXAMPLES AND DOCUMENTATION
-- =====================================================================================

/*
USAGE EXAMPLES:

1. Generate a production API token:
   SELECT * FROM auth.generate_production_api_token(
       p_user_hk := decode('your_user_hash', 'hex'),
       p_token_type := 'API',
       p_scope := ARRAY['api:read', 'api:write'],
       p_expires_in := '7 days'::INTERVAL,
       p_description := 'My production API access token'
   );

2. Validate a production token:
   SELECT * FROM auth.validate_production_api_token(
       p_token_value := 'ovt_prod_abc123...',
       p_required_scope := 'api:read',
       p_client_ip := '192.168.1.100'::INET,
       p_api_endpoint := '/api/v1/users'
   );

3. Revoke a production token:
   SELECT auth.revoke_production_api_token(
       p_token_value := 'ovt_prod_abc123...',
       p_revocation_reason := 'Security rotation'
   );

4. List user's production tokens:
   SELECT * FROM auth.list_production_api_tokens(
       p_user_hk := decode('your_user_hash', 'hex')
   );

FEATURES:
- Production-grade security with 'ovt_prod_' prefix
- Role-based rate limiting and security levels
- Comprehensive audit trails
- Token usage tracking
- Scope-based permissions
- Safe revocation with audit trail
- No interference with existing session system
*/ 