-- =============================================================================
-- Migration: V016__smart_tenant_resolution.sql
-- Description: SMART TENANT RESOLUTION - Derive tenant from API token
-- Author: OneVault Security Team
-- Date: 2025-06-26
-- Dependencies: V015 secure authentication
-- IMPROVEMENT: Remove silly requirement for users to send tenant_hk
-- =============================================================================

-- Migration Metadata Logging
DO $$
BEGIN
    INSERT INTO util.migration_log (
        migration_version,
        migration_name,
        migration_type,
        started_at,
        executed_by
    ) VALUES (
        'V016',
        'smart_tenant_resolution',
        'FORWARD',
        CURRENT_TIMESTAMP,
        SESSION_USER
    ) ON CONFLICT (migration_version, migration_type) DO NOTHING;
    
    RAISE NOTICE '🧠 Starting SMART ENHANCEMENT V016: Tenant Resolution from API Token';
    RAISE NOTICE '💡 Removing silly requirement for users to send tenant_hk manually';
END $$;

-- 1. CREATE API TOKEN TO TENANT MAPPING TABLE
CREATE TABLE IF NOT EXISTS auth.api_token_h (
    api_token_hk BYTEA PRIMARY KEY,
    api_token_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS auth.api_token_s (
    api_token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(api_token_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    token_name VARCHAR(200) NOT NULL,
    token_type VARCHAR(50) DEFAULT 'API_ACCESS',
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    expires_at TIMESTAMP WITH TIME ZONE,
    last_used_at TIMESTAMP WITH TIME ZONE,
    usage_count INTEGER DEFAULT 0,
    allowed_origins TEXT[],
    rate_limit_per_hour INTEGER DEFAULT 1000,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (api_token_hk, load_date)
);

-- 2. CREATE SMART TENANT RESOLUTION FUNCTION
CREATE OR REPLACE FUNCTION auth.resolve_tenant_from_token(
    p_api_token VARCHAR(255)
) RETURNS BYTEA
LANGUAGE 'plpgsql'
SECURITY DEFINER
AS $BODY$
DECLARE
    v_tenant_hk BYTEA;
    v_token_active BOOLEAN;
BEGIN
    -- Resolve tenant from API token
    SELECT 
        ath.tenant_hk,
        COALESCE(ats.is_active, TRUE)
    INTO 
        v_tenant_hk,
        v_token_active
    FROM auth.api_token_h ath
    JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk
    WHERE ath.api_token_bk = p_api_token
    AND ats.load_end_date IS NULL
    AND (ats.expires_at IS NULL OR ats.expires_at > CURRENT_TIMESTAMP);
    
    -- Validate token
    IF v_tenant_hk IS NULL THEN
        RAISE WARNING 'SECURITY: Invalid or expired API token used: %', 
                     LEFT(p_api_token, 8) || '...';
        RETURN NULL;
    END IF;
    
    IF NOT v_token_active THEN
        RAISE WARNING 'SECURITY: Inactive API token used: %', 
                     LEFT(p_api_token, 8) || '...';
        RETURN NULL;
    END IF;
    
    -- Update token usage statistics
    UPDATE auth.api_token_s 
    SET last_used_at = CURRENT_TIMESTAMP,
        usage_count = usage_count + 1
    WHERE api_token_hk = (
        SELECT api_token_hk FROM auth.api_token_h WHERE api_token_bk = p_api_token
    ) AND load_end_date IS NULL;
    
    RETURN v_tenant_hk;
END;
$BODY$;

-- 3. CREATE USER-FRIENDLY AUTHENTICATION PROCEDURE
CREATE OR REPLACE PROCEDURE auth.login_user_smart(
    IN p_username character varying,
    IN p_password text,
    IN p_api_token VARCHAR(255),        -- 🧠 SMART: Use API token instead of tenant_hk
    IN p_ip_address inet,
    IN p_user_agent text,
    OUT p_success boolean,
    OUT p_message text,
    OUT p_tenant_list jsonb,
    OUT p_session_token text,
    OUT p_user_data jsonb,
    IN p_auto_login boolean DEFAULT true
)
LANGUAGE 'plpgsql'
SECURITY DEFINER 
AS $BODY$
DECLARE
    v_tenant_hk BYTEA;
    v_tenant_name TEXT;
BEGIN
    -- Initialize outputs
    p_success := FALSE;
    p_message := 'Authentication failed';
    p_tenant_list := NULL;
    p_session_token := NULL;
    p_user_data := NULL;

    -- 🧠 SMART RESOLUTION: Get tenant from API token
    v_tenant_hk := auth.resolve_tenant_from_token(p_api_token);
    
    IF v_tenant_hk IS NULL THEN
        p_message := 'Invalid API token or token expired';
        
        -- Log security incident
        INSERT INTO audit.security_incident_s (
            incident_hk,
            tenant_hk,
            incident_type,
            severity,
            description,
            user_involved,
            ip_address,
            incident_timestamp,
            load_date,
            record_source
        ) VALUES (
            util.hash_binary('INVALID_TOKEN_' || p_username || CURRENT_TIMESTAMP::text),
            NULL,  -- No tenant available
            'INVALID_API_TOKEN',
            'HIGH',
            'Authentication attempted with invalid or expired API token',
            p_username,
            p_ip_address,
            CURRENT_TIMESTAMP,
            util.current_load_date(),
            'AUTH_LOGIN_SMART'
        );
        
        RETURN;
    END IF;
    
    -- Get tenant name for logging
    SELECT COALESCE(tps.tenant_name, th.tenant_bk) INTO v_tenant_name
    FROM auth.tenant_h th
    LEFT JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk 
        AND tps.load_end_date IS NULL
    WHERE th.tenant_hk = v_tenant_hk;
    
    -- 🔒 SECURE: Call the secure authentication with resolved tenant
    CALL auth.login_user(
        p_username,
        p_password,
        v_tenant_hk,                    -- 🧠 Resolved from token!
        p_ip_address,
        p_user_agent,
        p_success,
        p_message,
        p_tenant_list,
        p_session_token,
        p_user_data,
        p_auto_login
    );
    
    -- Enhance success message with tenant context
    IF p_success THEN
        p_message := 'Authentication successful for ' || v_tenant_name;
        
        RAISE NOTICE 'SMART AUTH: Successful login for % in tenant % (resolved from API token)', 
                     p_username, v_tenant_name;
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    p_success := FALSE;
    p_message := 'System error during authentication';
    
    RAISE WARNING 'SMART AUTH: System error for % from %: %', 
                 p_username, p_ip_address, SQLERRM;
END;
$BODY$;

-- 4. CREATE SMART API WRAPPER
CREATE OR REPLACE FUNCTION api.auth_login_smart(p_request JSONB)
RETURNS JSONB
LANGUAGE 'plpgsql'
SECURITY DEFINER
AS $BODY$
DECLARE
    v_username VARCHAR(255);
    v_password TEXT;
    v_api_token VARCHAR(255);
    v_ip_address INET;
    v_user_agent TEXT;
    v_auto_login BOOLEAN;
    v_success BOOLEAN;
    v_message TEXT;
    v_tenant_list JSONB;
    v_session_token TEXT;
    v_user_data JSONB;
BEGIN
    -- Extract parameters (NO tenant_hk required!)
    v_username := p_request->>'username';
    v_password := p_request->>'password';
    v_api_token := p_request->>'api_token';  -- 🧠 SMART: Get from token instead
    v_ip_address := COALESCE((p_request->>'ip_address')::INET, '127.0.0.1'::INET);
    v_user_agent := COALESCE(p_request->>'user_agent', 'Unknown');
    v_auto_login := COALESCE((p_request->>'auto_login')::BOOLEAN, TRUE);
    
    -- Validate required parameters
    IF v_username IS NULL OR v_password IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Username and password are required',
            'error_code', 'MISSING_CREDENTIALS'
        );
    END IF;
    
    IF v_api_token IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'API token is required for authentication',
            'error_code', 'MISSING_API_TOKEN',
            'help', 'Include your API token in the request. Each tenant has a unique API token.'
        );
    END IF;
    
    -- Call smart login procedure
    CALL auth.login_user_smart(
        v_username,
        v_password,
        v_api_token,                    -- 🧠 Pass token, not tenant_hk!
        v_ip_address,
        v_user_agent,
        v_success,
        v_message,
        v_tenant_list,
        v_session_token,
        v_user_data,
        v_auto_login
    );
    
    -- Return user-friendly response
    RETURN jsonb_build_object(
        'success', v_success,
        'message', v_message,
        'data', CASE 
            WHEN v_success THEN jsonb_build_object(
                'session_token', v_session_token,
                'user_data', v_user_data,
                'tenant_list', v_tenant_list,
                'security', jsonb_build_object(
                    'tenant_resolved_from_token', TRUE,
                    'cross_tenant_protected', TRUE,
                    'auth_method', 'SMART_TENANT_LOGIN'
                )
            )
            ELSE NULL
        END,
        'api_version', '2.1.0',
        'timestamp', CURRENT_TIMESTAMP
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', FALSE,
        'message', 'Authentication system error',
        'error_code', 'SYSTEM_ERROR',
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$BODY$;

-- 5. CREATE FUNCTION TO REGISTER API TOKENS FOR TENANTS
CREATE OR REPLACE FUNCTION auth.register_api_token(
    p_tenant_bk VARCHAR(255),
    p_token_name VARCHAR(200),
    p_expires_days INTEGER DEFAULT NULL
)
RETURNS VARCHAR(255)
LANGUAGE 'plpgsql'
SECURITY DEFINER
AS $BODY$
DECLARE
    v_tenant_hk BYTEA;
    v_api_token VARCHAR(255);
    v_token_hk BYTEA;
    v_expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Get tenant
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h
    WHERE tenant_bk = p_tenant_bk;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'Tenant not found: %', p_tenant_bk;
    END IF;
    
    -- Generate secure API token
    v_api_token := 'ovt_' || encode(gen_random_bytes(32), 'hex');
    v_token_hk := util.hash_binary(v_api_token);
    
    -- Calculate expiration
    IF p_expires_days IS NOT NULL THEN
        v_expires_at := CURRENT_TIMESTAMP + (p_expires_days || ' days')::INTERVAL;
    END IF;
    
    -- Insert token
    INSERT INTO auth.api_token_h VALUES (
        v_token_hk, v_api_token, v_tenant_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    INSERT INTO auth.api_token_s VALUES (
        v_token_hk, util.current_load_date(), NULL,
        util.hash_binary(v_api_token || p_token_name),
        p_token_name, 'API_ACCESS', TRUE, SESSION_USER,
        v_expires_at, NULL, 0, NULL, 1000,
        util.get_record_source()
    );
    
    RAISE NOTICE 'API token created for tenant %: %...', p_tenant_bk, LEFT(v_api_token, 12);
    
    RETURN v_api_token;
END;
$BODY$;

-- 6. POPULATE EXISTING TENANTS WITH API TOKENS
DO $$
DECLARE
    tenant_record RECORD;
    v_api_token VARCHAR(255);
BEGIN
    RAISE NOTICE '🔑 Creating API tokens for existing tenants...';
    
    FOR tenant_record IN 
        SELECT th.tenant_bk, COALESCE(tps.tenant_name, th.tenant_bk) as tenant_name
        FROM auth.tenant_h th
        LEFT JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            AND tps.load_end_date IS NULL
    LOOP
        -- Create API token for each tenant
        v_api_token := auth.register_api_token(
            tenant_record.tenant_bk,
            'Default API Token for ' || tenant_record.tenant_name,
            NULL  -- No expiration
        );
        
        RAISE NOTICE '  ✅ Created token for %: %...', 
                     tenant_record.tenant_name, LEFT(v_api_token, 12);
    END LOOP;
END $$;

-- 7. UPDATE PERMISSIONS
DO $$
BEGIN
    -- Grant permissions to application roles
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
        GRANT EXECUTE ON PROCEDURE auth.login_user_smart TO app_user;
        GRANT EXECUTE ON FUNCTION auth.resolve_tenant_from_token TO app_user;
        GRANT EXECUTE ON FUNCTION api.auth_login_smart TO app_user;
        GRANT EXECUTE ON FUNCTION auth.register_api_token TO app_user;
        RAISE NOTICE '✅ Granted permissions to app_user role';
    END IF;
    
    RAISE NOTICE '🔒 Smart authentication permissions configured';
END $$;

-- 8. VALIDATION AND COMPLETION
DO $$
DECLARE
    v_smart_procedure_exists BOOLEAN;
    v_smart_api_exists BOOLEAN;
    v_token_tables_exist INTEGER;
    v_tokens_created INTEGER;
BEGIN
    -- Validate smart procedure creation
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'auth' AND p.proname = 'login_user_smart'
    ) INTO v_smart_procedure_exists;
    
    -- Validate smart API function creation
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' AND p.proname = 'auth_login_smart'
    ) INTO v_smart_api_exists;
    
    -- Validate token tables
    SELECT COUNT(*) INTO v_token_tables_exist
    FROM information_schema.tables
    WHERE table_schema = 'auth' 
    AND table_name IN ('api_token_h', 'api_token_s');
    
    -- Count created tokens
    SELECT COUNT(*) INTO v_tokens_created
    FROM auth.api_token_s
    WHERE load_end_date IS NULL;
    
    -- Report results
    RAISE NOTICE '🧠 SMART ENHANCEMENT VALIDATION:';
    RAISE NOTICE '   Smart auth.login_user_smart procedure: %', 
                 CASE WHEN v_smart_procedure_exists THEN '✅ CREATED' ELSE '❌ FAILED' END;
    RAISE NOTICE '   Smart API function: %', 
                 CASE WHEN v_smart_api_exists THEN '✅ CREATED' ELSE '❌ FAILED' END;
    RAISE NOTICE '   Token management tables: %/2 created', v_token_tables_exist;
    RAISE NOTICE '   API tokens generated: % tokens', v_tokens_created;
    
    IF v_smart_procedure_exists AND v_smart_api_exists AND v_token_tables_exist >= 2 THEN
        RAISE NOTICE '🎉 SMART ENHANCEMENT V016 COMPLETED SUCCESSFULLY!';
        RAISE NOTICE '💡 Users no longer need to send tenant_hk - resolved from API token!';
        
        UPDATE util.migration_log 
        SET completed_at = CURRENT_TIMESTAMP,
            status = 'SUCCESS'
        WHERE migration_version = 'V016' AND migration_type = 'FORWARD';
    ELSE
        RAISE EXCEPTION '❌ SMART ENHANCEMENT VALIDATION FAILED!';
    END IF;
END $$;

-- Final smart enhancement notice
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧠 SMART AUTHENTICATION ENHANCEMENT DEPLOYED';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '✅ Tenant resolution from API token implemented';
    RAISE NOTICE '✅ User-friendly authentication API created';
    RAISE NOTICE '✅ No more silly tenant_hk requirements for users';
    RAISE NOTICE '✅ Automatic API token generation for existing tenants';
    RAISE NOTICE '';
    RAISE NOTICE '💡 NEW USAGE:';
    RAISE NOTICE '   Use api.auth_login_smart() with just username, password, and api_token';
    RAISE NOTICE '   Tenant context automatically resolved from API token';
    RAISE NOTICE '';
    RAISE NOTICE '🔑 API TOKENS CREATED:';
    RAISE NOTICE '   Check auth.api_token_s table for tenant API tokens';
    RAISE NOTICE '   Each tenant now has a unique API token for authentication';
    RAISE NOTICE '';
END $$; 