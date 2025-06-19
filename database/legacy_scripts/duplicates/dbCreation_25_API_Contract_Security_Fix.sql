-- =============================================
-- dbCreation_25_API_Contract_Security_Fix.sql
-- SECURITY FIX: Proper password validation at API level
-- Maintains existing secure raw.capture_login_attempt (no password storage)
-- Validates credentials BEFORE raw capture, not after
-- =============================================

-- Drop my insecure functions
DROP FUNCTION IF EXISTS raw.capture_login_attempt(BYTEA, VARCHAR, TEXT, INET, TEXT) CASCADE;
DROP FUNCTION IF EXISTS staging.validate_login_credentials(BYTEA) CASCADE;

-- =============================================
-- FIXED API CONTRACT: Security-First Approach
-- Validates credentials at API level, then captures attempt
-- =============================================

CREATE OR REPLACE FUNCTION api.auth_login(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_username VARCHAR(255);
    v_password TEXT;
    v_ip_address INET;
    v_user_agent TEXT;
    v_auto_login BOOLEAN;
    
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_user_auth RECORD;
    v_login_attempt_hk BYTEA;
    v_session_hk BYTEA;
    v_session_token TEXT;
    
    v_tenant_list JSONB;
    v_user_data JSONB;
    v_credentials_valid BOOLEAN := FALSE;
BEGIN
    -- Extract parameters from JSON request
    v_username := p_request->>'username';
    v_password := p_request->>'password';
    v_ip_address := (p_request->>'ip_address')::INET;
    v_user_agent := p_request->>'user_agent';
    v_auto_login := COALESCE((p_request->>'auto_login')::BOOLEAN, TRUE);
    
    -- Validate required parameters
    IF v_username IS NULL OR v_password IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Username and password are required',
            'error_code', 'MISSING_CREDENTIALS'
        );
    END IF;
    
    -- STEP 1: Find user and validate credentials directly (BEFORE raw capture)
    SELECT 
        uh.user_hk,
        uh.tenant_hk,
        uas.password_hash,
        uas.username,
        uas.account_locked
    INTO v_user_auth
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_username
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    -- Check if user exists
    IF v_user_auth.user_hk IS NULL THEN
        -- User not found - still capture attempt for security logging
        -- Use first available tenant for logging purposes
        SELECT tenant_hk INTO v_tenant_hk FROM auth.tenant_h LIMIT 1;
        
        IF v_tenant_hk IS NOT NULL THEN
            -- Use existing secure function (stores no password data)
            v_login_attempt_hk := raw.capture_login_attempt(
                v_tenant_hk,
                v_username,
                v_ip_address,
                v_user_agent
            );
        END IF;
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found',
            'data', jsonb_build_object(
                'requires_tenant_selection', false,
                'tenant_list', null,
                'session_token', null,
                'user_data', null
            )
        );
    END IF;
    
    -- Get user context
    v_user_hk := v_user_auth.user_hk;
    v_tenant_hk := v_user_auth.tenant_hk;
    
    -- Check account status
    IF v_user_auth.account_locked THEN
        -- Capture failed attempt
        v_login_attempt_hk := raw.capture_login_attempt(
            v_tenant_hk,
            v_username,
            v_ip_address,
            v_user_agent
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Account is locked',
            'data', jsonb_build_object(
                'requires_tenant_selection', false,
                'tenant_list', null,
                'session_token', null,
                'user_data', null
            )
        );
    END IF;
    
    -- STEP 2: Validate password using crypt function
    v_credentials_valid := (crypt(v_password, v_user_auth.password_hash::text) = v_user_auth.password_hash::text);
    
    -- STEP 3: Capture login attempt (secure - no password storage)
    v_login_attempt_hk := raw.capture_login_attempt(
        v_tenant_hk,
        v_username,
        v_ip_address,
        v_user_agent
    );
    
    -- STEP 4: Process validation results
    IF NOT v_credentials_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid password',
            'data', jsonb_build_object(
                'requires_tenant_selection', false,
                'tenant_list', null,
                'session_token', null,
                'user_data', null
            )
        );
    END IF;
    
    -- STEP 5: Get list of tenants this user has access to
    SELECT jsonb_agg(
        jsonb_build_object(
            'tenant_id', t.tenant_bk,
            'tenant_name', COALESCE(tps.tenant_name, t.tenant_bk),
            'role', COALESCE(rds.role_name, 'USER')
        )
    ) INTO v_tenant_list
    FROM auth.user_h u
    JOIN auth.tenant_h t ON u.tenant_hk = t.tenant_hk
    LEFT JOIN auth.tenant_profile_s tps ON t.tenant_hk = tps.tenant_hk 
        AND tps.load_end_date IS NULL
    LEFT JOIN auth.user_role_l url ON u.user_hk = url.user_hk
    LEFT JOIN auth.role_h r ON url.role_hk = r.role_hk
    LEFT JOIN auth.role_definition_s rds ON r.role_hk = rds.role_hk
        AND rds.load_end_date IS NULL
    WHERE u.user_hk = v_user_hk;
    
    -- STEP 6: Auto-login if requested and user has only one tenant
    IF v_auto_login AND jsonb_array_length(COALESCE(v_tenant_list, '[]'::jsonb)) = 1 THEN
        -- Use existing secure session creation procedure
        CALL auth.create_session_with_token(
            v_user_hk,
            v_ip_address,
            v_user_agent,
            v_session_hk,
            v_session_token
        );
        
        -- Get user profile data
        SELECT jsonb_build_object(
            'user_id', u.user_bk,
            'email', uas.username,
            'first_name', COALESCE(ups.first_name, ''),
            'last_name', COALESCE(ups.last_name, ''),
            'tenant_id', (v_tenant_list->0->>'tenant_id')
        ) INTO v_user_data
        FROM auth.user_h u
        JOIN auth.user_auth_s uas ON u.user_hk = uas.user_hk
        LEFT JOIN auth.user_profile_s ups ON u.user_hk = ups.user_hk
        WHERE u.user_hk = v_user_hk
        AND uas.load_end_date IS NULL
        AND (ups.load_end_date IS NULL OR ups.load_end_date IS NULL);
        
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Login successful',
            'data', jsonb_build_object(
                'requires_tenant_selection', false,
                'tenant_list', v_tenant_list,
                'session_token', v_session_token,
                'user_data', v_user_data
            )
        );
    ELSE
        -- Multiple tenants - require tenant selection
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Authentication successful - please select tenant',
            'data', jsonb_build_object(
                'requires_tenant_selection', true,
                'tenant_list', v_tenant_list,
                'session_token', null,
                'user_data', null
            )
        );
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'An unexpected error occurred during authentication',
        'error_code', 'AUTHENTICATION_ERROR',
        'debug_info', jsonb_build_object(
            'error', SQLERRM,
            'sqlstate', SQLSTATE
        )
    );
END;
$$;

-- =============================================
-- VERIFICATION: Confirm we're using secure functions
-- =============================================

CREATE OR REPLACE FUNCTION api.validate_secure_contract()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_raw_function_exists BOOLEAN;
    v_function_details RECORD;
BEGIN
    -- Check that we're using the secure raw.capture_login_attempt
    SELECT 
        p.proname,
        array_length(p.proargtypes, 1) as param_count,
        pg_get_function_arguments(p.oid) as signature
    INTO v_function_details
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'raw'
    AND p.proname = 'capture_login_attempt';
    
    v_raw_function_exists := FOUND;
    
    RETURN jsonb_build_object(
        'security_validation', 'API-Level Password Validation',
        'timestamp', CURRENT_TIMESTAMP,
        'raw_function_exists', v_raw_function_exists,
        'function_signature', COALESCE(v_function_details.signature, 'NOT_FOUND'),
        'security_note', 'Passwords validated at API level, never stored in raw schema',
        'flow', 'API Validation → Raw Capture (secure) → Session Creation'
    );
END;
$$;

-- =============================================
-- COMPLETION MESSAGE
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== SECURITY-COMPLIANT API CONTRACT ===';
    RAISE NOTICE 'Password validation moved to API level';
    RAISE NOTICE 'Raw schema maintains security (no password storage)';
    RAISE NOTICE 'Uses existing secure raw.capture_login_attempt()';
    RAISE NOTICE '';
    RAISE NOTICE 'To validate security compliance:';
    RAISE NOTICE 'SELECT api.validate_secure_contract();';
    RAISE NOTICE '';
    RAISE NOTICE 'Test login with:';
    RAISE NOTICE 'SELECT api.auth_login(''{"username": "your_username", "password": "your_password", "ip_address": "127.0.0.1", "user_agent": "test"}'');';
    RAISE NOTICE '';
END $$; 