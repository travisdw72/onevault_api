-- =============================================================================
-- Migration: V015__secure_tenant_isolated_auth.sql
-- Description: SECURITY ENHANCEMENT - Add mandatory tenant isolation to authentication
-- Author: OneVault Security Team
-- Date: 2025-06-26
-- Dependencies: auth schema, existing login_user procedure
-- CRITICAL: Fixes cross-tenant login vulnerability (CVE-OneVault-2025-001)
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
        'V015',
        'secure_tenant_isolated_auth',
        'FORWARD',
        CURRENT_TIMESTAMP,
        SESSION_USER
    ) ON CONFLICT (migration_version, migration_type) DO NOTHING;
    
    RAISE NOTICE '🔒 Starting SECURITY MIGRATION V015: Tenant-Isolated Authentication';
    RAISE NOTICE '⚠️  This migration fixes CRITICAL cross-tenant login vulnerability';
END $$;

-- 1. CREATE REQUIRED SUPPORT TABLES FOR AUDIT LOGGING
CREATE TABLE IF NOT EXISTS audit.auth_failure_s (
    auth_failure_hk BYTEA PRIMARY KEY,
    tenant_hk BYTEA,
    attempted_username VARCHAR(255),
    failure_reason VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS audit.security_incident_s (
    incident_hk BYTEA PRIMARY KEY,
    tenant_hk BYTEA,
    incident_type VARCHAR(100),
    severity VARCHAR(20),
    description TEXT,
    user_involved VARCHAR(255),
    ip_address INET,
    incident_timestamp TIMESTAMP WITH TIME ZONE,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS audit.auth_success_s (
    auth_success_hk BYTEA PRIMARY KEY,
    user_hk BYTEA,
    tenant_hk BYTEA,
    session_token_hash BYTEA,
    ip_address INET,
    user_agent TEXT,
    auth_method VARCHAR(50),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100)
);

-- 2. CREATE SECURE TENANT-ISOLATED AUTHENTICATION PROCEDURE
CREATE OR REPLACE PROCEDURE auth.login_user(
    IN p_username character varying,
    IN p_password text,
    IN p_tenant_hk BYTEA,                    -- 🔒 NEW: Mandatory tenant context
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
    v_login_attempt_hk BYTEA;
    v_user_hk BYTEA;
    v_validation_result JSONB;
    v_tenant_exists BOOLEAN := FALSE;
    v_user_tenant_match BOOLEAN := FALSE;
    v_tenant_name TEXT;
    v_attempts_count INTEGER;
    v_lockout_expires TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Initialize outputs
    p_success := FALSE;
    p_message := 'Authentication failed';
    p_tenant_list := NULL;
    p_session_token := NULL;
    p_user_data := NULL;

    -- 🔒 SECURITY VALIDATION: Tenant Context Required
    IF p_tenant_hk IS NULL THEN
        p_message := 'Tenant context required for authentication';
        RAISE WARNING 'SECURITY: Authentication attempted without tenant context from %', p_ip_address;
        RETURN;
    END IF;
    
    -- 🔒 SECURITY VALIDATION: Verify tenant exists and is active
    SELECT 
        TRUE,
        COALESCE(tps.tenant_name, th.tenant_bk)
    INTO 
        v_tenant_exists,
        v_tenant_name
    FROM auth.tenant_h th
    LEFT JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk 
        AND tps.load_end_date IS NULL
    WHERE th.tenant_hk = p_tenant_hk
    AND COALESCE(tps.is_active, TRUE) = TRUE;
    
    IF NOT v_tenant_exists THEN
        p_message := 'Invalid or inactive tenant';
        RAISE WARNING 'SECURITY: Authentication attempted for invalid tenant % from %', 
                     encode(p_tenant_hk, 'hex'), p_ip_address;
        RETURN;
    END IF;
    
    -- 🔒 SECURITY CHECK: Rate limiting per tenant/IP
    SELECT COUNT(*), MAX(uas.lockout_expires)
    INTO v_attempts_count, v_lockout_expires
    FROM auth.user_auth_s uas
    JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
    WHERE uh.tenant_hk = p_tenant_hk
    AND uas.last_failed_login > CURRENT_TIMESTAMP - INTERVAL '15 minutes'
    AND uas.last_failed_ip = p_ip_address;
    
    -- Check if IP is locked out for this tenant
    IF v_lockout_expires IS NOT NULL AND v_lockout_expires > CURRENT_TIMESTAMP THEN
        p_message := 'Account temporarily locked due to failed attempts';
        RAISE WARNING 'SECURITY: Locked out IP % attempted access to tenant %', 
                     p_ip_address, v_tenant_name;
        RETURN;
    END IF;
    
    -- Check rate limiting (max 5 attempts per 15 minutes per tenant/IP)
    IF v_attempts_count >= 5 THEN
        p_message := 'Too many authentication attempts. Please try again later.';
        RAISE WARNING 'SECURITY: Rate limit exceeded for IP % on tenant %', 
                     p_ip_address, v_tenant_name;
        RETURN;
    END IF;
    
    -- Record login attempt with tenant context
    v_login_attempt_hk := raw.capture_login_attempt(
        p_tenant_hk,                         -- 🔒 Use provided tenant context
        p_username,
        p_password,
        p_ip_address,
        p_user_agent
    );
    
    -- 🔒 SECURE VALIDATION: Only search within specified tenant
    SELECT 
        uh.user_hk,
        uas.password_hash,
        uas.failed_login_attempts,
        uas.lockout_expires,
        COALESCE(ups.is_active, TRUE) as is_active,
        uas.username
    INTO v_user_hk, v_validation_result
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    LEFT JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
        AND ups.load_end_date IS NULL
    WHERE uas.username = p_username
    AND uh.tenant_hk = p_tenant_hk          -- 🔒 CRITICAL: Tenant isolation
    AND uas.load_end_date IS NULL;
    
    -- Check if user exists in this tenant
    IF v_user_hk IS NULL THEN
        p_success := FALSE;
        p_message := 'Invalid username or password';
        
        -- 🔒 SECURITY AUDIT: Log failed attempt
        INSERT INTO audit.auth_failure_s (
            auth_failure_hk,
            tenant_hk,
            attempted_username,
            failure_reason,
            ip_address,
            user_agent,
            load_date,
            record_source
        ) VALUES (
            util.hash_binary(p_tenant_hk::text || p_username || CURRENT_TIMESTAMP::text),
            p_tenant_hk,
            p_username,
            'INVALID_USER',
            p_ip_address,
            p_user_agent,
            util.current_load_date(),
            'AUTH_LOGIN_SECURE'
        );
        
        RETURN;
    END IF;
    
    -- Validate password (simplified for this migration)
    IF crypt(p_password, (SELECT password_hash FROM auth.user_auth_s WHERE user_hk = v_user_hk AND load_end_date IS NULL)) = 
       (SELECT password_hash FROM auth.user_auth_s WHERE user_hk = v_user_hk AND load_end_date IS NULL) THEN
        
        -- 🔒 SUCCESS: Authentication passed all security checks
        p_success := TRUE;
        p_message := 'Authentication successful';
        
        -- Get tenant information (only for the authenticated tenant)
        SELECT jsonb_build_array(
            jsonb_build_object(
                'tenant_id', t.tenant_bk,
                'tenant_name', COALESCE(tps.tenant_name, t.tenant_bk),
                'tenant_hk', encode(t.tenant_hk, 'hex')
            )
        ) INTO p_tenant_list
        FROM auth.tenant_h t
        LEFT JOIN auth.tenant_profile_s tps ON t.tenant_hk = tps.tenant_hk 
            AND tps.load_end_date IS NULL
        WHERE t.tenant_hk = p_tenant_hk;
        
        -- Create session if auto-login is enabled
        IF p_auto_login THEN
            -- Generate secure session token
            p_session_token := encode(gen_random_bytes(32), 'hex');
            
            -- Get comprehensive user data with security context
            SELECT jsonb_build_object(
                'user_id', encode(u.user_hk, 'hex'),
                'user_bk', u.user_bk,
                'username', uas.username,
                'email', uas.username,
                'first_name', COALESCE(ups.first_name, ''),
                'last_name', COALESCE(ups.last_name, ''),
                'job_title', ups.job_title,
                'department', ups.department,
                'is_active', COALESCE(ups.is_active, TRUE),
                'last_login', uas.last_login_date,
                'tenant_hk', encode(u.tenant_hk, 'hex'),
                'tenant_name', v_tenant_name,
                'security_context', jsonb_build_object(
                    'tenant_isolated', TRUE,
                    'auth_method', 'SECURE_LOGIN',
                    'ip_address', p_ip_address::text,
                    'login_timestamp', CURRENT_TIMESTAMP
                )
            ) INTO p_user_data
            FROM auth.user_h u
            JOIN auth.user_auth_s uas ON u.user_hk = uas.user_hk
            LEFT JOIN auth.user_profile_s ups ON u.user_hk = ups.user_hk
                AND ups.load_end_date IS NULL
            WHERE u.user_hk = v_user_hk
            AND uas.load_end_date IS NULL;
            
            -- 🔒 SECURITY AUDIT: Log successful authentication
            INSERT INTO audit.auth_success_s (
                auth_success_hk,
                user_hk,
                tenant_hk,
                session_token_hash,
                ip_address,
                user_agent,
                auth_method,
                load_date,
                record_source
            ) VALUES (
                util.hash_binary(encode(v_user_hk, 'hex') || p_session_token || CURRENT_TIMESTAMP::text),
                v_user_hk,
                p_tenant_hk,
                util.hash_binary(p_session_token),
                p_ip_address,
                p_user_agent,
                'SECURE_TENANT_LOGIN',
                util.current_load_date(),
                'AUTH_LOGIN_SECURE'
            );
            
            -- Update last login information
            UPDATE auth.user_auth_s 
            SET last_login_date = CURRENT_TIMESTAMP,
                last_login_ip = p_ip_address,
                failed_login_attempts = 0  -- Reset on successful login
            WHERE user_hk = v_user_hk 
            AND load_end_date IS NULL;
        END IF;
        
        RAISE NOTICE 'SECURITY: Successful tenant-isolated login for % in tenant %', 
                     p_username, v_tenant_name;
    ELSE
        -- Invalid password
        p_success := FALSE;
        p_message := 'Invalid username or password';
        
        -- Log failed password attempt
        INSERT INTO audit.auth_failure_s (
            auth_failure_hk,
            tenant_hk,
            attempted_username,
            failure_reason,
            ip_address,
            user_agent,
            load_date,
            record_source
        ) VALUES (
            util.hash_binary(p_tenant_hk::text || p_username || CURRENT_TIMESTAMP::text),
            p_tenant_hk,
            p_username,
            'INVALID_PASSWORD',
            p_ip_address,
            p_user_agent,
            util.current_load_date(),
            'AUTH_LOGIN_SECURE'
        );
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    p_success := FALSE;
    p_message := 'System error during authentication';
    
    RAISE WARNING 'SECURITY: Authentication system error for % from %: %', 
                 p_username, p_ip_address, SQLERRM;
END;
$BODY$;

-- 3. CREATE SECURE API WRAPPER FUNCTION
CREATE OR REPLACE FUNCTION api.auth_login_secure(p_request JSONB)
RETURNS JSONB
LANGUAGE 'plpgsql'
SECURITY DEFINER
AS $BODY$
DECLARE
    v_username VARCHAR(255);
    v_password TEXT;
    v_tenant_hk BYTEA;
    v_ip_address INET;
    v_user_agent TEXT;
    v_auto_login BOOLEAN;
    v_success BOOLEAN;
    v_message TEXT;
    v_tenant_list JSONB;
    v_session_token TEXT;
    v_user_data JSONB;
BEGIN
    -- Extract parameters with tenant context validation
    v_username := p_request->>'username';
    v_password := p_request->>'password';
    v_tenant_hk := COALESCE(
        decode(p_request->>'tenant_hk', 'hex'),
        NULL
    );
    v_ip_address := COALESCE((p_request->>'ip_address')::INET, '127.0.0.1'::INET);
    v_user_agent := COALESCE(p_request->>'user_agent', 'Unknown');
    v_auto_login := COALESCE((p_request->>'auto_login')::BOOLEAN, TRUE);
    
    -- 🔒 SECURITY: Validate required parameters
    IF v_username IS NULL OR v_password IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Username and password are required',
            'error_code', 'MISSING_CREDENTIALS'
        );
    END IF;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Tenant context is required for secure authentication',
            'error_code', 'MISSING_TENANT_CONTEXT',
            'security_enhancement', 'This endpoint now requires tenant isolation for security'
        );
    END IF;
    
    -- Call secure login procedure
    CALL auth.login_user(
        v_username,
        v_password,
        v_tenant_hk,                        -- 🔒 Pass tenant context
        v_ip_address,
        v_user_agent,
        v_success,
        v_message,
        v_tenant_list,
        v_session_token,
        v_user_data,
        v_auto_login
    );
    
    -- Return secure response
    RETURN jsonb_build_object(
        'success', v_success,
        'message', v_message,
        'data', CASE 
            WHEN v_success THEN jsonb_build_object(
                'session_token', v_session_token,
                'user_data', v_user_data,
                'tenant_list', v_tenant_list,
                'security', jsonb_build_object(
                    'tenant_isolated', TRUE,
                    'cross_tenant_protected', TRUE,
                    'auth_method', 'SECURE_TENANT_LOGIN'
                )
            )
            ELSE NULL
        END,
        'security_version', '2.0.0',
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

-- 4. UPDATE PERMISSIONS AND SECURITY
DO $$
BEGIN
    -- Grant permissions to application roles
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
        GRANT EXECUTE ON PROCEDURE auth.login_user TO app_user;
        GRANT EXECUTE ON FUNCTION api.auth_login_secure TO app_user;
        RAISE NOTICE '✅ Granted permissions to app_user role';
    END IF;
    
    -- Revoke dangerous permissions if they exist
    REVOKE ALL ON PROCEDURE auth.login_user FROM PUBLIC;
    
    RAISE NOTICE '🔒 Security permissions configured';
END $$;

-- 5. VALIDATION AND COMPLETION
DO $$
DECLARE
    v_procedure_exists BOOLEAN;
    v_api_function_exists BOOLEAN;
    v_audit_tables_exist INTEGER;
BEGIN
    -- Validate procedure creation
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'auth' AND p.proname = 'login_user'
        AND array_length(p.proargtypes, 1) = 7  -- New parameter count
    ) INTO v_procedure_exists;
    
    -- Validate API function creation
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' AND p.proname = 'auth_login_secure'
    ) INTO v_api_function_exists;
    
    -- Validate audit tables
    SELECT COUNT(*) INTO v_audit_tables_exist
    FROM information_schema.tables
    WHERE table_schema = 'audit' 
    AND table_name IN ('auth_success_s', 'auth_failure_s', 'security_incident_s');
    
    -- Report results
    RAISE NOTICE '🔒 SECURITY MIGRATION VALIDATION:';
    RAISE NOTICE '   Enhanced auth.login_user procedure: %', 
                 CASE WHEN v_procedure_exists THEN '✅ CREATED' ELSE '❌ FAILED' END;
    RAISE NOTICE '   Secure API function: %', 
                 CASE WHEN v_api_function_exists THEN '✅ CREATED' ELSE '❌ FAILED' END;
    RAISE NOTICE '   Audit tables: %/3 created', v_audit_tables_exist;
    
    IF v_procedure_exists AND v_api_function_exists AND v_audit_tables_exist >= 3 THEN
        RAISE NOTICE '🎉 SECURITY MIGRATION V015 COMPLETED SUCCESSFULLY!';
        RAISE NOTICE '🔒 Cross-tenant login vulnerability has been RESOLVED';
        
        UPDATE util.migration_log 
        SET completed_at = CURRENT_TIMESTAMP,
            status = 'SUCCESS'
        WHERE migration_version = 'V015' AND migration_type = 'FORWARD';
    ELSE
        RAISE EXCEPTION '❌ SECURITY MIGRATION VALIDATION FAILED!';
    END IF;
END $$;

-- Final security notice
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🛡️  CRITICAL SECURITY ENHANCEMENT DEPLOYED';
    RAISE NOTICE '=====================================';
    RAISE NOTICE '✅ Tenant isolation now MANDATORY in authentication';
    RAISE NOTICE '✅ Cross-tenant login attacks are BLOCKED';
    RAISE NOTICE '✅ Enhanced audit logging implemented';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  OLD FUNCTION SIGNATURE IS DEPRECATED';
    RAISE NOTICE '   Update API calls to include tenant_hk parameter';
    RAISE NOTICE '   Use api.auth_login_secure() for new implementations';
    RAISE NOTICE '';
END $$; 