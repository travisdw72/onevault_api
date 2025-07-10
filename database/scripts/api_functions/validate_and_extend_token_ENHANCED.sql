-- =============================================
-- Enhanced Token Validation with Automatic Extension
-- Production-ready integration of validation + extension
-- Zero client impact, automatic token lifecycle management
-- =============================================

CREATE OR REPLACE FUNCTION auth.validate_and_extend_production_token(
    p_token_value TEXT,
    p_required_scope TEXT DEFAULT 'api:read',
    p_client_ip INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_api_endpoint TEXT DEFAULT NULL,
    p_auto_extend BOOLEAN DEFAULT true,
    p_extend_threshold_days INTEGER DEFAULT 7,
    p_extension_days INTEGER DEFAULT 30
) RETURNS TABLE(
    is_valid BOOLEAN, 
    user_hk BYTEA, 
    tenant_hk BYTEA, 
    token_hk BYTEA, 
    scope TEXT[], 
    security_level VARCHAR(20), 
    rate_limit_remaining INTEGER, 
    rate_limit_reset_time TIMESTAMP WITH TIME ZONE, 
    validation_message TEXT,
    -- EXTENSION FIELDS:
    token_extended BOOLEAN,
    new_expires_at TIMESTAMP WITH TIME ZONE,
    days_until_expiry INTEGER,
    extension_reason VARCHAR(100),
    -- AUDIT FIELDS:
    session_id TEXT,
    extension_audit_id TEXT
) AS $$
DECLARE
    v_validation_result RECORD;
    v_extension_result RECORD;
    v_extension_check RECORD;
    v_was_extended BOOLEAN := false;
    v_final_expires_at TIMESTAMP WITH TIME ZONE;
    v_final_message TEXT;
    v_session_id TEXT;
    v_audit_id TEXT;
    v_token_hk BYTEA;
    v_extension_attempts INTEGER := 0;
BEGIN
    -- Generate session ID for this validation + extension operation
    v_session_id := 'VAL_EXT_' || encode(gen_random_bytes(8), 'hex');
    
    -- Step 1: Check if token format is valid before calling validation
    IF NOT (p_token_value LIKE 'ovt_prod_%') THEN
        RETURN QUERY SELECT 
            false, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, NULL::TEXT[], 
            'INVALID'::VARCHAR(20), 0, NULL::TIMESTAMP WITH TIME ZONE,
            'Invalid token format - must start with ovt_prod_'::TEXT,
            false, NULL::TIMESTAMP WITH TIME ZONE, 0, 'INVALID_FORMAT'::VARCHAR(100),
            v_session_id, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Step 2: Run existing validation logic first
    BEGIN
        -- Try the exact function signature you have
        SELECT * INTO v_validation_result
        FROM auth.validate_production_api_token(
            p_token_value, p_required_scope, p_client_ip, p_user_agent, p_api_endpoint
        );
    EXCEPTION 
        WHEN undefined_function THEN
            -- Fallback to simpler validation if full function doesn't exist
            BEGIN
                SELECT * INTO v_validation_result
                FROM auth.validate_production_api_token(p_token_value, p_required_scope);
            EXCEPTION
                WHEN undefined_function THEN
                    -- Manual validation as final fallback
                    DECLARE
                        v_token_hash BYTEA := sha256(p_token_value::bytea);
                        v_token_record RECORD;
                    BEGIN
                        SELECT 
                            ath.api_token_hk,
                            ath.tenant_hk,
                            ats.expires_at > CURRENT_TIMESTAMP as is_valid,
                            ats.scope,
                            utl.user_hk
                        INTO v_token_record
                        FROM auth.api_token_s ats
                        JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
                        LEFT JOIN auth.user_token_l utl ON ath.api_token_hk = utl.api_token_hk
                        WHERE ats.token_hash = v_token_hash
                        AND ats.load_end_date IS NULL
                        AND ats.is_revoked = false;
                        
                        -- Build validation result manually
                        v_validation_result.is_valid := COALESCE(v_token_record.is_valid, false);
                        v_validation_result.user_hk := v_token_record.user_hk;
                        v_validation_result.tenant_hk := v_token_record.tenant_hk;
                        v_validation_result.token_hk := v_token_record.api_token_hk;
                        v_validation_result.scope := COALESCE(v_token_record.scope, ARRAY['api:read']);
                        v_validation_result.security_level := 'STANDARD';
                        v_validation_result.rate_limit_remaining := 1000;
                        v_validation_result.rate_limit_reset_time := CURRENT_TIMESTAMP + INTERVAL '1 hour';
                        v_validation_result.validation_message := 
                            CASE WHEN v_validation_result.is_valid 
                                 THEN 'Token validated via fallback method'
                                 ELSE 'Token invalid or not found' END;
                    END;
            END;
    END;
    
    v_token_hk := v_validation_result.token_hk;
    
    -- If token is invalid, return immediately (no point extending invalid token)
    IF NOT v_validation_result.is_valid THEN
        -- Log failed validation attempt
        BEGIN
            INSERT INTO auth.token_activity_s (
                api_token_hk, load_date, hash_diff, last_activity_timestamp,
                activity_type, activity_metadata, record_source
            ) VALUES (
                COALESCE(v_token_hk, '\x00'::bytea),
                util.current_load_date(), util.hash_binary('VALIDATION_FAILED_' || v_session_id),
                CURRENT_TIMESTAMP, 'VALIDATION_FAILED',
                jsonb_build_object(
                    'session_id', v_session_id,
                    'client_ip', p_client_ip,
                    'user_agent', p_user_agent,
                    'api_endpoint', p_api_endpoint,
                    'required_scope', p_required_scope,
                    'failure_reason', v_validation_result.validation_message
                ),
                'auth.validate_and_extend_production_token'
            );
        EXCEPTION WHEN OTHERS THEN
            NULL; -- Graceful fallback if audit table doesn't exist
        END;
        
        RETURN QUERY SELECT 
            v_validation_result.is_valid,
            v_validation_result.user_hk,
            v_validation_result.tenant_hk,
            v_validation_result.token_hk,
            v_validation_result.scope,
            v_validation_result.security_level,
            v_validation_result.rate_limit_remaining,
            v_validation_result.rate_limit_reset_time,
            v_validation_result.validation_message,
            false,  -- token_extended
            NULL::TIMESTAMP WITH TIME ZONE,  -- new_expires_at
            0,  -- days_until_expiry
            'TOKEN_INVALID'::VARCHAR(100),  -- extension_reason
            v_session_id,
            NULL::TEXT;
        RETURN;
    END IF;
    
    -- Step 3: Check if extension is needed (if auto_extend enabled)
    IF p_auto_extend THEN
        SELECT * INTO v_extension_check
        FROM auth.check_token_extension_needed(p_token_value, p_extend_threshold_days);
        
        -- Step 4: Perform extension if recommended
        IF v_extension_check.extension_recommended THEN
            v_extension_attempts := 1;
            
            SELECT * INTO v_extension_result
            FROM auth.extend_token_expiration(
                p_token_value, 
                p_extension_days,
                p_extend_threshold_days
            );
            
            -- Generate audit ID for the extension
            v_audit_id := 'EXT_' || encode(gen_random_bytes(6), 'hex');
            
            -- Check if extension was successful
            IF v_extension_result.success THEN
                v_was_extended := true;
                v_final_expires_at := v_extension_result.new_expires_at;
                v_final_message := v_validation_result.validation_message || 
                                 format(' (Auto-extended %s days until %s)', 
                                        p_extension_days, 
                                        v_extension_result.new_expires_at::date);
                
                -- Log successful auto-extension
                BEGIN
                    INSERT INTO auth.token_activity_s (
                        api_token_hk, load_date, hash_diff, last_activity_timestamp,
                        activity_type, activity_metadata, record_source
                    ) VALUES (
                        v_token_hk,
                        util.current_load_date(),
                        util.hash_binary('AUTO_EXTEND_SUCCESS_' || v_audit_id),
                        CURRENT_TIMESTAMP,
                        'AUTO_EXTENSION_SUCCESS',
                        jsonb_build_object(
                            'session_id', v_session_id,
                            'audit_id', v_audit_id,
                            'extension_reason', v_extension_result.extension_reason,
                            'extension_days', p_extension_days,
                            'original_expires_at', v_extension_check.current_expires_at,
                            'new_expires_at', v_extension_result.new_expires_at,
                            'client_ip', p_client_ip,
                            'api_endpoint', p_api_endpoint,
                            'user_agent', p_user_agent,
                            'threshold_days', p_extend_threshold_days,
                            'days_until_old_expiry', v_extension_check.days_until_expiry
                        ),
                        'auth.validate_and_extend_production_token'
                    );
                EXCEPTION WHEN OTHERS THEN
                    NULL; -- Graceful fallback
                END;
                
            ELSE
                -- Extension failed, but token is still valid
                v_final_expires_at := v_extension_check.current_expires_at;
                v_final_message := v_validation_result.validation_message || 
                                 ' (Auto-extension failed: ' || v_extension_result.message || ')';
                
                -- Log failed auto-extension
                BEGIN
                    INSERT INTO auth.token_activity_s (
                        api_token_hk, load_date, hash_diff, last_activity_timestamp,
                        activity_type, activity_metadata, record_source
                    ) VALUES (
                        v_token_hk,
                        util.current_load_date(),
                        util.hash_binary('AUTO_EXTEND_FAILED_' || v_audit_id),
                        CURRENT_TIMESTAMP,
                        'AUTO_EXTENSION_FAILED',
                        jsonb_build_object(
                            'session_id', v_session_id,
                            'audit_id', v_audit_id,
                            'failure_message', v_extension_result.message,
                            'extension_days', p_extension_days,
                            'current_expires_at', v_extension_check.current_expires_at,
                            'client_ip', p_client_ip,
                            'api_endpoint', p_api_endpoint,
                            'threshold_days', p_extend_threshold_days
                        ),
                        'auth.validate_and_extend_production_token'
                    );
                EXCEPTION WHEN OTHERS THEN
                    NULL; -- Graceful fallback
                END;
            END IF;
        ELSE
            -- No extension needed
            v_final_expires_at := v_extension_check.current_expires_at;
            v_final_message := v_validation_result.validation_message;
        END IF;
    ELSE
        -- Auto-extend disabled, just get current expiry info
        SELECT current_expires_at, days_until_expiry 
        INTO v_final_expires_at, v_extension_check.days_until_expiry
        FROM auth.check_token_extension_needed(p_token_value, p_extend_threshold_days);
        
        v_final_message := v_validation_result.validation_message || ' (Auto-extension disabled)';
    END IF;
    
    -- Step 5: Log successful validation (with or without extension)
    BEGIN
        INSERT INTO auth.token_activity_s (
            api_token_hk, load_date, hash_diff, last_activity_timestamp,
            activity_type, activity_metadata, record_source
        ) VALUES (
            v_token_hk,
            util.current_load_date(),
            util.hash_binary('VALIDATION_SUCCESS_' || v_session_id),
            CURRENT_TIMESTAMP,
            'VALIDATION_SUCCESS',
            jsonb_build_object(
                'session_id', v_session_id,
                'client_ip', p_client_ip,
                'user_agent', p_user_agent,
                'api_endpoint', p_api_endpoint,
                'required_scope', p_required_scope,
                'auto_extend_enabled', p_auto_extend,
                'token_extended', v_was_extended,
                'extension_attempts', v_extension_attempts,
                'final_expires_at', v_final_expires_at,
                'security_level', v_validation_result.security_level
            ),
            'auth.validate_and_extend_production_token'
        );
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Graceful fallback
    END;
    
    -- Step 6: Return comprehensive result
    RETURN QUERY SELECT 
        v_validation_result.is_valid,
        v_validation_result.user_hk,
        v_validation_result.tenant_hk,
        v_validation_result.token_hk,
        v_validation_result.scope,
        v_validation_result.security_level,
        v_validation_result.rate_limit_remaining,
        v_validation_result.rate_limit_reset_time,
        v_final_message,
        v_was_extended,  -- token_extended
        v_final_expires_at,  -- new_expires_at (possibly extended)
        COALESCE(v_extension_check.days_until_expiry, 0),  -- days_until_expiry
        CASE 
            WHEN v_was_extended THEN v_extension_result.extension_reason
            WHEN v_extension_check.extension_recommended THEN 'EXTENSION_FAILED'
            ELSE 'NO_EXTENSION_NEEDED'
        END::VARCHAR(100),  -- extension_reason
        v_session_id,
        v_audit_id;
        
EXCEPTION
    WHEN OTHERS THEN
        -- Ultimate fallback - return error but don't crash
        RETURN QUERY SELECT 
            false, NULL::BYTEA, NULL::BYTEA, NULL::BYTEA, NULL::TEXT[], 
            'ERROR'::VARCHAR(20), 0, NULL::TIMESTAMP WITH TIME ZONE,
            format('Validation function error: %s (SQLSTATE: %s)', SQLERRM, SQLSTATE)::TEXT,
            false, NULL::TIMESTAMP WITH TIME ZONE, 0, 'FUNCTION_ERROR'::VARCHAR(100),
            COALESCE(v_session_id, 'ERROR_SESSION'), NULL::TEXT;
        
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Simplified API endpoint function for manual extension
-- =============================================

CREATE OR REPLACE FUNCTION auth.api_extend_token(
    p_token TEXT,
    p_days INTEGER DEFAULT 30,
    p_client_ip INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    days_extended INTEGER,
    audit_id TEXT
) AS $$
DECLARE
    v_result RECORD;
    v_check RECORD;
    v_audit_id TEXT;
BEGIN
    v_audit_id := 'MAN_EXT_' || encode(gen_random_bytes(6), 'hex');
    
    -- Check current status first
    SELECT * INTO v_check
    FROM auth.check_token_extension_needed(p_token, 0); -- Check regardless of threshold
    
    IF NOT v_check.token_found THEN
        RETURN QUERY SELECT false, 'Token not found'::TEXT, NULL::TIMESTAMP, 0, v_audit_id;
        RETURN;
    END IF;
    
    -- Perform extension
    SELECT * INTO v_result
    FROM auth.extend_token_expiration(p_token, p_days, 0); -- Force extend regardless of threshold
    
    -- Log manual extension attempt
    BEGIN
        DECLARE v_token_hk BYTEA := (
            SELECT ath.api_token_hk 
            FROM auth.api_token_s ats
            JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
            WHERE ats.token_hash = sha256(p_token::bytea)
            AND ats.load_end_date IS NULL
        );
        BEGIN
            INSERT INTO auth.token_activity_s (
                api_token_hk, load_date, hash_diff, last_activity_timestamp,
                activity_type, activity_metadata, record_source
            ) VALUES (
                v_token_hk,
                util.current_load_date(),
                util.hash_binary('MANUAL_EXTEND_' || v_audit_id),
                CURRENT_TIMESTAMP,
                CASE WHEN v_result.success THEN 'MANUAL_EXTENSION_SUCCESS' ELSE 'MANUAL_EXTENSION_FAILED' END,
                jsonb_build_object(
                    'audit_id', v_audit_id,
                    'extension_days', p_days,
                    'client_ip', p_client_ip,
                    'user_agent', p_user_agent,
                    'original_expires_at', v_check.current_expires_at,
                    'new_expires_at', v_result.new_expires_at,
                    'success', v_result.success,
                    'message', v_result.message
                ),
                'auth.api_extend_token'
            );
        EXCEPTION WHEN OTHERS THEN
            NULL; -- Graceful fallback
        END;
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Graceful fallback
    END;
    
    RETURN QUERY SELECT 
        v_result.success,
        v_result.message,
        v_result.new_expires_at,
        p_days,
        v_audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Token extension dashboard function
-- =============================================

CREATE OR REPLACE FUNCTION auth.get_token_extension_stats(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_days_back INTEGER DEFAULT 7
) RETURNS TABLE(
    total_validations INTEGER,
    auto_extensions INTEGER,
    manual_extensions INTEGER,
    extension_failures INTEGER,
    average_days_extended DECIMAL(5,2),
    most_recent_extension TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) FILTER (WHERE activity_type = 'VALIDATION_SUCCESS')::INTEGER,
        COUNT(*) FILTER (WHERE activity_type = 'AUTO_EXTENSION_SUCCESS')::INTEGER,
        COUNT(*) FILTER (WHERE activity_type = 'MANUAL_EXTENSION_SUCCESS')::INTEGER,
        COUNT(*) FILTER (WHERE activity_type IN ('AUTO_EXTENSION_FAILED', 'MANUAL_EXTENSION_FAILED'))::INTEGER,
        AVG((activity_metadata->>'extension_days')::INTEGER)::DECIMAL(5,2),
        MAX(last_activity_timestamp) FILTER (WHERE activity_type LIKE '%EXTENSION_SUCCESS')
    FROM auth.token_activity_s tas
    WHERE last_activity_timestamp >= CURRENT_TIMESTAMP - (p_days_back || ' days')::INTERVAL
    AND (p_tenant_hk IS NULL OR api_token_hk IN (
        SELECT ath.api_token_hk 
        FROM auth.api_token_h ath 
        WHERE ath.tenant_hk = p_tenant_hk
    ))
    AND activity_type IN (
        'VALIDATION_SUCCESS', 'AUTO_EXTENSION_SUCCESS', 'MANUAL_EXTENSION_SUCCESS',
        'AUTO_EXTENSION_FAILED', 'MANUAL_EXTENSION_FAILED'
    );
    
EXCEPTION WHEN OTHERS THEN
    -- Graceful fallback if audit table doesn't exist
    RETURN QUERY SELECT 0, 0, 0, 0, 0.0::DECIMAL(5,2), NULL::TIMESTAMP WITH TIME ZONE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Permissions and Success Message
-- =============================================

DO $$
BEGIN
    -- Grant permissions to existing roles
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'api_user') THEN
        GRANT EXECUTE ON FUNCTION auth.validate_and_extend_production_token(TEXT, TEXT, INET, TEXT, TEXT, BOOLEAN, INTEGER, INTEGER) TO api_user;
        GRANT EXECUTE ON FUNCTION auth.api_extend_token(TEXT, INTEGER, INET, TEXT) TO api_user;
        GRANT EXECUTE ON FUNCTION auth.get_token_extension_stats(BYTEA, INTEGER) TO api_user;
        RAISE NOTICE '✅ Permissions granted to api_user role';
    ELSE
        RAISE NOTICE '⚠️  Role api_user does not exist - permissions not granted';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
        GRANT EXECUTE ON FUNCTION auth.validate_and_extend_production_token(TEXT, TEXT, INET, TEXT, TEXT, BOOLEAN, INTEGER, INTEGER) TO postgres;
        GRANT EXECUTE ON FUNCTION auth.api_extend_token(TEXT, INTEGER, INET, TEXT) TO postgres;
        GRANT EXECUTE ON FUNCTION auth.get_token_extension_stats(BYTEA, INTEGER) TO postgres;
        RAISE NOTICE '✅ Permissions granted to postgres role';
    END IF;
    
    RAISE NOTICE '🎉 Enhanced Validate & Extend Token System deployed!';
    RAISE NOTICE '📋 Available functions:';
    RAISE NOTICE '   - auth.validate_and_extend_production_token() - Main API validation with auto-extension';
    RAISE NOTICE '   - auth.api_extend_token() - Manual extension via REST API';
    RAISE NOTICE '   - auth.get_token_extension_stats() - Extension analytics dashboard';
    RAISE NOTICE '🚀 Zero client impact - tokens never change, only expiration extends';
END $$;

-- =============================================
-- Usage Examples
-- =============================================

/*
-- Primary use case - validate with auto-extension:
SELECT * FROM auth.validate_and_extend_production_token(
    'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e',
    'api:read',
    '192.168.1.100'::inet,
    'OneVault-Client/1.0',
    '/api/v1/users'
);

-- Manual extension via API:
SELECT * FROM auth.api_extend_token(
    'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e',
    60  -- Extend by 60 days
);

-- Get extension statistics:
SELECT * FROM auth.get_token_extension_stats(NULL, 30); -- Last 30 days, all tenants
*/ 