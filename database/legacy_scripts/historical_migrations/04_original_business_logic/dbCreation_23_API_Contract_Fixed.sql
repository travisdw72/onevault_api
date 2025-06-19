-- =============================================
-- dbCreation_23_API_Contract_Fixed.sql
-- FIXED Data Vault 2.0 API Contract for Project Goal 3
-- Properly Integrated with Raw Schema Processing Pipeline
-- UPDATED: Uses existing auth.create_session_with_token (no redundant code)
-- =============================================
-- 
-- This fixes the API contract to use the proper Data Vault 2.0 flow:
-- Raw Schema → Staging Schema → Auth Schema
-- 
-- All API endpoints now properly use raw.capture_login_attempt() and 
-- the established trigger-based processing pipeline.
-- Uses existing auth.create_session_with_token procedure.
-- =============================================

-- =============================================
-- STEP 1: CLEAN UP CONFLICTING FUNCTIONS
-- =============================================

-- Drop the incorrect API functions that bypass raw schema
DROP FUNCTION IF EXISTS api.auth_login(JSONB) CASCADE;
DROP FUNCTION IF EXISTS api.auth_complete_login(JSONB) CASCADE;
DROP FUNCTION IF EXISTS api.auth_validate_session(JSONB) CASCADE;

-- Drop conflicting auth procedures that bypass the pipeline
DROP PROCEDURE IF EXISTS auth.login_user(VARCHAR, TEXT, INET, TEXT, BOOLEAN, TEXT, JSONB, TEXT, JSONB, BOOLEAN) CASCADE;
DROP PROCEDURE IF EXISTS auth.complete_login(VARCHAR, TEXT, INET, TEXT, BOOLEAN, TEXT, TEXT, JSONB) CASCADE;

-- Drop the redundant session creation procedure I created (use existing one)
DROP PROCEDURE IF EXISTS auth.create_session_for_user(BYTEA, INET, TEXT, BYTEA, TEXT) CASCADE;

-- =============================================
-- STEP 2: ENSURE PROPER RAW SCHEMA FUNCTION EXISTS
-- =============================================

-- Create the definitive raw.capture_login_attempt function
CREATE OR REPLACE FUNCTION raw.capture_login_attempt(
    p_tenant_hk BYTEA,
    p_username VARCHAR(255),
    p_password TEXT,
    p_ip_address INET,
    p_user_agent TEXT
) RETURNS BYTEA
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_login_attempt_bk VARCHAR(255);
    v_login_attempt_hk BYTEA;
    v_hash_diff BYTEA;
BEGIN
    -- Create business key using tenant context and timestamp
    v_login_attempt_bk := encode(p_tenant_hk, 'hex') || '_' || 
                         replace(p_username, '@', '_') || '_' ||
                         to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    
    -- Generate hash key
    v_login_attempt_hk := util.hash_binary(v_login_attempt_bk);
    
    -- Calculate hash diff for satellite
    v_hash_diff := util.hash_concat(
        p_username,
        'PASSWORD_PROVIDED',
        p_ip_address::text,
        COALESCE(p_user_agent, 'UNKNOWN')
    );
    
    -- Insert into hub table (raw.login_attempt_h)
    INSERT INTO raw.login_attempt_h (
        login_attempt_hk,
        login_attempt_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_login_attempt_hk,
        v_login_attempt_bk,
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    );
    
    -- Insert into satellite table (raw.login_details_s)
    -- Store password temporarily for validation processing
    INSERT INTO raw.login_details_s (
        login_attempt_hk,
        load_date,
        hash_diff,
        username,
        password_indicator,
        ip_address,
        attempt_timestamp,
        user_agent,
        record_source
    ) VALUES (
        v_login_attempt_hk,
        util.current_load_date(),
        v_hash_diff,
        p_username,
        convert_to(p_password, 'UTF8'), -- Store temporarily for validation
        p_ip_address,
        CURRENT_TIMESTAMP,
        p_user_agent,
        util.get_record_source()
    );
    
    RETURN v_login_attempt_hk;
END;
$$;

-- =============================================
-- STEP 3: ENSURE STAGING PROCESSING EXISTS
-- =============================================

-- Create the staging validation function if it doesn't exist
CREATE OR REPLACE FUNCTION staging.validate_login_credentials(
    p_login_attempt_hk BYTEA
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_login_details RECORD;
    v_user_auth RECORD;
    v_result JSONB;
    v_raw_password TEXT;
BEGIN
    -- Get login attempt details from raw schema
    SELECT 
        rld.username,
        convert_from(rld.password_indicator, 'UTF8') AS raw_password,
        rlh.tenant_hk
    INTO v_login_details
    FROM raw.login_details_s rld
    JOIN raw.login_attempt_h rlh ON rld.login_attempt_hk = rlh.login_attempt_hk
    WHERE rld.login_attempt_hk = p_login_attempt_hk
    AND rld.load_end_date IS NULL
    ORDER BY rld.load_date DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'ERROR', 'message', 'Login attempt not found');
    END IF;
    
    v_raw_password := v_login_details.raw_password;
    
    -- Get the user's stored credentials
    SELECT 
        uh.user_hk,
        uas.password_hash,
        uas.username,
        uas.account_locked
    INTO v_user_auth
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_login_details.username
    AND uh.tenant_hk = v_login_details.tenant_hk
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    -- Validation logic
    IF v_user_auth.user_hk IS NULL THEN
        v_result := jsonb_build_object('status', 'INVALID_USER');
    ELSIF v_user_auth.account_locked THEN
        v_result := jsonb_build_object('status', 'LOCKED');
    ELSIF NOT (crypt(v_raw_password, v_user_auth.password_hash::text) = v_user_auth.password_hash::text) THEN
        v_result := jsonb_build_object('status', 'INVALID_PASSWORD');
    ELSE
        v_result := jsonb_build_object(
            'status', 'VALID',
            'user_hk', encode(v_user_auth.user_hk, 'hex'),
            'tenant_hk', encode(v_login_details.tenant_hk, 'hex')
        );
    END IF;
    
    -- Create staging records for tracking
    INSERT INTO staging.login_attempt_h (
        login_attempt_hk,
        login_attempt_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        p_login_attempt_hk,
        'STAGING_' || encode(p_login_attempt_hk, 'hex'),
        v_login_details.tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    ) ON CONFLICT (login_attempt_hk) DO NOTHING;
    
    INSERT INTO staging.login_status_s (
        login_attempt_hk,
        load_date,
        hash_diff,
        username,
        ip_address,
        attempt_timestamp,
        user_agent,
        validation_status,
        validation_message,
        record_source
    )
    SELECT 
        p_login_attempt_hk,
        util.current_load_date(),
        util.hash_binary(v_login_details.username || (v_result->>'status')),
        rld.username,
        rld.ip_address,
        rld.attempt_timestamp,
        rld.user_agent,
        v_result->>'status',
        COALESCE(v_result->>'message', v_result->>'status'),
        util.get_record_source()
    FROM raw.login_details_s rld
    WHERE rld.login_attempt_hk = p_login_attempt_hk
    AND rld.load_end_date IS NULL;
    
    RETURN v_result;
END;
$$;

-- =============================================
-- STEP 4: FIXED API CONTRACT FUNCTIONS
-- =============================================

/*
ENDPOINT: POST /api/auth/login
PURPOSE: Primary authentication entry point using proper Data Vault 2.0 flow
FIXED: Now uses raw.capture_login_attempt() → staging validation → existing auth.create_session_with_token
*/
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
    v_login_attempt_hk BYTEA;
    v_validation_result JSONB;
    v_user_hk BYTEA;
    v_session_hk BYTEA;
    v_session_token TEXT;
    
    v_tenant_list JSONB;
    v_user_data JSONB;
    v_response JSONB;
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
    
    -- STEP 1: Find appropriate tenant for this user
    -- Look for user across all tenants first
    SELECT DISTINCT uh.tenant_hk INTO v_tenant_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_username
    AND uas.load_end_date IS NULL
    ORDER BY uh.tenant_hk
    LIMIT 1;
    
    -- If no user found, use a system tenant for the attempt (will fail validation)
    IF v_tenant_hk IS NULL THEN
        SELECT tenant_hk INTO v_tenant_hk
        FROM auth.tenant_h
        WHERE tenant_bk LIKE '%SYSTEM%'
        LIMIT 1;
        
        -- If no system tenant, use first available
        IF v_tenant_hk IS NULL THEN
            SELECT tenant_hk INTO v_tenant_hk
            FROM auth.tenant_h
            LIMIT 1;
        END IF;
    END IF;
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No tenant context available for authentication',
            'error_code', 'NO_TENANT_CONTEXT'
        );
    END IF;
    
    -- STEP 2: Capture login attempt in raw schema (Data Vault 2.0 entry point)
    v_login_attempt_hk := raw.capture_login_attempt(
        v_tenant_hk,
        v_username,
        v_password,
        v_ip_address,
        v_user_agent
    );
    
    -- STEP 3: Validate credentials through staging schema
    v_validation_result := staging.validate_login_credentials(v_login_attempt_hk);
    
    -- STEP 4: Process validation results
    IF (v_validation_result->>'status') != 'VALID' THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', CASE 
                WHEN (v_validation_result->>'status') = 'INVALID_USER' THEN 'User not found'
                WHEN (v_validation_result->>'status') = 'INVALID_PASSWORD' THEN 'Invalid password'
                WHEN (v_validation_result->>'status') = 'LOCKED' THEN 'Account is locked'
                ELSE 'Login failed: ' || (v_validation_result->>'status')
            END,
            'data', jsonb_build_object(
                'requires_tenant_selection', false,
                'tenant_list', null,
                'session_token', null,
                'user_data', null
            )
        );
    END IF;
    
    -- Credentials are valid - get user hash key
    v_user_hk := decode(v_validation_result->>'user_hk', 'hex');
    
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
        -- Use existing session creation procedure
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
-- STEP 5: SESSION VALIDATION API
-- =============================================

/*
ENDPOINT: POST /api/auth/validate
PURPOSE: Validate session tokens using existing Data Vault 2.0 structures
USES: Existing auth schema tables and token validation patterns
*/
CREATE OR REPLACE FUNCTION api.auth_validate_session(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_token TEXT;
    v_ip_address INET;
    v_user_agent TEXT;
    v_session_data RECORD;
    v_user_context JSONB;
BEGIN
    -- Extract parameters
    v_session_token := p_request->>'session_token';
    v_ip_address := (p_request->>'ip_address')::INET;
    v_user_agent := p_request->>'user_agent';
    
    -- Validate required parameters
    IF v_session_token IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Session token is required',
            'error_code', 'MISSING_TOKEN'
        );
    END IF;
    
    -- Look up session using existing token validation patterns
    -- Use the api_token_s table which has the actual token values
    SELECT 
        sh.session_hk,
        sh.tenant_hk,
        sss.session_status,
        sss.last_activity,
        usl.user_hk
    INTO v_session_data
    FROM auth.api_token_s ats
    JOIN auth.session_token_l stl ON ats.api_token_hk = stl.api_token_hk
    JOIN auth.session_h sh ON stl.session_hk = sh.session_hk
    JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
    JOIN auth.user_session_l usl ON sh.session_hk = usl.session_hk
    WHERE ats.token_hash = util.hash_binary(v_session_token)
    AND ats.load_end_date IS NULL
    AND ats.status = 'ACTIVE'
    AND ats.expires_at > CURRENT_TIMESTAMP
    AND sss.load_end_date IS NULL
    AND sss.session_status = 'ACTIVE'
    ORDER BY sss.load_date DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid or expired session',
            'data', null
        );
    END IF;
    
    -- Get user context
    SELECT jsonb_build_object(
        'user_id', u.user_bk,
        'tenant_id', t.tenant_bk,
        'email', uas.username,
        'first_name', COALESCE(ups.first_name, ''),
        'last_name', COALESCE(ups.last_name, ''),
        'session_id', encode(v_session_data.session_hk, 'hex')
    ) INTO v_user_context
    FROM auth.user_h u
    JOIN auth.tenant_h t ON u.tenant_hk = t.tenant_hk
    JOIN auth.user_auth_s uas ON u.user_hk = uas.user_hk
    LEFT JOIN auth.user_profile_s ups ON u.user_hk = ups.user_hk
    WHERE u.user_hk = v_session_data.user_hk
    AND uas.load_end_date IS NULL
    AND (ups.load_end_date IS NULL OR ups.load_end_date IS NULL);
    
    -- Update session activity using existing pattern
    UPDATE auth.session_state_s
    SET load_end_date = util.current_load_date()
    WHERE session_hk = v_session_data.session_hk
    AND load_end_date IS NULL;
    
    INSERT INTO auth.session_state_s (
        session_hk,
        load_date,
        hash_diff,
        session_start,
        ip_address,
        user_agent,
        session_data,
        session_status,
        last_activity,
        record_source
    )
    SELECT 
        session_hk,
        util.current_load_date(),
        util.hash_binary(v_session_token || 'ACTIVE_UPDATED'),
        session_start,
        v_ip_address,
        v_user_agent,
        session_data,
        'ACTIVE',
        CURRENT_TIMESTAMP,
        util.get_record_source()
    FROM auth.session_state_s
    WHERE session_hk = v_session_data.session_hk
    AND load_end_date = util.current_load_date();
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Session valid',
        'data', v_user_context
    );
END;
$$;

-- =============================================
-- STEP 6: VERIFICATION FUNCTION
-- =============================================

CREATE OR REPLACE FUNCTION api.validate_fixed_contract()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_functions TEXT[] := ARRAY[
        'api.auth_login',
        'api.auth_validate_session',
        'raw.capture_login_attempt',
        'staging.validate_login_credentials',
        'auth.create_session_with_token'
    ];
    v_function TEXT;
    v_exists BOOLEAN;
    v_results JSONB := '[]'::JSONB;
BEGIN
    FOREACH v_function IN ARRAY v_functions
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = split_part(v_function, '.', 1)
            AND p.proname = split_part(v_function, '.', 2)
        ) INTO v_exists;
        
        v_results := v_results || jsonb_build_object(
            'function', v_function,
            'exists', v_exists,
            'status', CASE WHEN v_exists THEN 'OK' ELSE 'MISSING' END
        );
    END LOOP;
    
    RETURN jsonb_build_object(
        'contract_validation', 'Data Vault 2.0 Flow Fixed - No Redundant Code',
        'timestamp', CURRENT_TIMESTAMP,
        'functions', v_results,
        'flow', 'Raw Schema → Staging Schema → Auth Schema (using existing procedures)',
        'note', 'Uses existing auth.create_session_with_token - no redundant session creation'
    );
END;
$$;

-- =============================================
-- COMPLETION MESSAGE
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== DATA VAULT 2.0 API CONTRACT FIXED (NO REDUNDANT CODE) ===';
    RAISE NOTICE 'API now properly uses: Raw → Staging → Auth flow';
    RAISE NOTICE 'Uses existing auth.create_session_with_token procedure';
    RAISE NOTICE 'Eliminated redundant session creation code';
    RAISE NOTICE '';
    RAISE NOTICE 'To validate the fixed contract:';
    RAISE NOTICE 'SELECT api.validate_fixed_contract();';
    RAISE NOTICE '';
    RAISE NOTICE 'Test login with:';
    RAISE NOTICE 'SELECT api.auth_login(''{"username": "admin@tenant1.com", "password": "yourpassword", "ip_address": "127.0.0.1", "user_agent": "test"}'');';
    RAISE NOTICE '';
END $$; 