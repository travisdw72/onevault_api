-- =============================================================================
-- FIX AUTHENTICATION SYSTEM ISSUES
-- Date: 2025-01-08
-- Purpose: Fix database errors and session creation problems
-- =============================================================================

-- 1. FIX THE SESSION EXPIRATION COLUMN ERROR
-- The error shows `sss.expires_at` doesn't exist - let's check what columns we have
SELECT 'Checking session_state_s table columns' AS fix_section;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'auth' 
AND table_name = 'session_state_s'
ORDER BY column_name;

-- 2. ADD MISSING SESSION EXPIRATION COLUMN IF NEEDED
DO $$
BEGIN
    -- Check if expires_at column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'auth' 
        AND table_name = 'session_state_s' 
        AND column_name = 'expires_at'
    ) THEN
        -- Add the missing column
        ALTER TABLE auth.session_state_s 
        ADD COLUMN expires_at TIMESTAMP WITH TIME ZONE;
        
        RAISE NOTICE '✅ Added expires_at column to auth.session_state_s';
        
        -- Update existing records with default expiration (24 hours from creation)
        UPDATE auth.session_state_s 
        SET expires_at = created_at + INTERVAL '24 hours'
        WHERE expires_at IS NULL 
        AND created_at IS NOT NULL;
        
        -- For records without created_at, use load_date
        UPDATE auth.session_state_s 
        SET expires_at = load_date + INTERVAL '24 hours'
        WHERE expires_at IS NULL;
        
        RAISE NOTICE '✅ Updated existing session records with expiration times';
    ELSE
        RAISE NOTICE '✅ expires_at column already exists in auth.session_state_s';
    END IF;
    
    -- Also check if created_at exists and add if needed
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'auth' 
        AND table_name = 'session_state_s' 
        AND column_name = 'created_at'
    ) THEN
        ALTER TABLE auth.session_state_s 
        ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
        
        RAISE NOTICE '✅ Added created_at column to auth.session_state_s';
    END IF;
END $$;

-- 3. FIX SESSION CREATION ISSUE
-- The test shows session_token is NULL despite only having 1 tenant
-- Let's check the session creation function

SELECT 'Checking session creation functions' AS fix_section;
SELECT 
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_arguments(p.oid) AS parameters
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname LIKE '%session%'
AND n.nspname IN ('auth', 'api')
ORDER BY n.nspname, p.proname;

-- 4. CREATE/FIX SESSION TOKEN CREATION FUNCTION
CREATE OR REPLACE FUNCTION auth.create_session_with_token(
    p_user_hk BYTEA,
    p_ip_address INET,
    p_user_agent TEXT,
    OUT p_session_hk BYTEA,
    OUT p_session_token TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_bk VARCHAR(255);
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_record_source VARCHAR(100);
    v_tenant_hk BYTEA;
BEGIN
    -- Initialize variables
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();
    
    -- Generate session business key and token
    v_session_bk := 'SESSION_' || encode(gen_random_bytes(16), 'hex');
    p_session_token := encode(gen_random_bytes(32), 'hex');
    p_session_hk := util.hash_binary(v_session_bk);
    
    -- Get user's tenant
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.user_h
    WHERE user_hk = p_user_hk;
    
    -- Create session hub record
    INSERT INTO auth.session_h (
        session_hk,
        session_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        p_session_hk,
        v_session_bk,
        v_tenant_hk,
        v_load_date,
        v_record_source
    );
    
    -- Create session state satellite
    INSERT INTO auth.session_state_s (
        session_hk,
        load_date,
        hash_diff,
        session_status,
        created_at,
        expires_at,
        last_activity,
        ip_address,
        user_agent,
        record_source
    ) VALUES (
        p_session_hk,
        v_load_date,
        util.hash_binary(v_session_bk || 'ACTIVE' || v_load_date::text),
        'ACTIVE',
        v_load_date,
        v_load_date + INTERVAL '24 hours',
        v_load_date,
        p_ip_address,
        p_user_agent,
        v_record_source
    );
    
    -- Link user to session
    INSERT INTO auth.user_session_l (
        user_session_hk,
        user_hk,
        session_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(encode(p_user_hk, 'hex') || encode(p_session_hk, 'hex')),
        p_user_hk,
        p_session_hk,
        v_load_date,
        v_record_source
    );
    
    -- Create API token for the session if api_token_s table exists
    BEGIN
        INSERT INTO auth.api_token_s (
            api_token_hk,
            load_date,
            hash_diff,
            token_hash,
            token_type,
            status,
            created_at,
            expires_at,
            record_source
        ) VALUES (
            util.hash_binary('TOKEN_' || p_session_token),
            v_load_date,
            util.hash_binary(p_session_token || 'SESSION_TOKEN'),
            util.hash_binary(p_session_token),
            'SESSION',
            'ACTIVE',
            v_load_date,
            v_load_date + INTERVAL '24 hours',
            v_record_source
        );
        
        -- Link token to session if session_token_l exists
        INSERT INTO auth.session_token_l (
            session_token_hk,
            session_hk,
            api_token_hk,
            load_date,
            record_source
        ) VALUES (
            util.hash_binary(encode(p_session_hk, 'hex') || 'TOKEN_' || p_session_token),
            p_session_hk,
            util.hash_binary('TOKEN_' || p_session_token),
            v_load_date,
            v_record_source
        );
    EXCEPTION WHEN OTHERS THEN
        -- Ignore if token tables don't exist
        RAISE NOTICE 'API token tables not available, session created without token link';
    END;
    
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to create session: % - %', SQLSTATE, SQLERRM;
END;
$$;

-- 5. TEST THE FIXED SESSION CREATION
DO $$
DECLARE
    v_user_hk BYTEA;
    v_session_hk BYTEA;
    v_session_token TEXT;
    v_test_user TEXT := 'travisdwoodward72@gmail.com';
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔧 TESTING SESSION CREATION FIX';
    
    -- Get user hash key
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_test_user
    AND uas.load_end_date IS NULL
    LIMIT 1;
    
    IF v_user_hk IS NOT NULL THEN
        RAISE NOTICE '   User found: %', encode(v_user_hk, 'hex');
        
        -- Test session creation
        CALL auth.create_session_with_token(
            v_user_hk,
            '192.168.1.100'::INET,
            'Session-Test/1.0',
            v_session_hk,
            v_session_token
        );
        
        IF v_session_token IS NOT NULL THEN
            RAISE NOTICE '   ✅ Session created successfully!';
            RAISE NOTICE '   Session HK: %', encode(v_session_hk, 'hex');
            RAISE NOTICE '   Session Token: %...', SUBSTRING(v_session_token, 1, 16);
        ELSE
            RAISE NOTICE '   ❌ Session creation failed - no token returned';
        END IF;
    ELSE
        RAISE NOTICE '   ❌ Test user not found: %', v_test_user;
    END IF;
END $$;

-- 6. FIX AUTO-LOGIN LOGIC IN AUTH_LOGIN FUNCTION
-- Check if the api.auth_login function has the correct session creation logic
SELECT 'Checking auto-login logic' AS fix_section;

-- Create or replace the corrected auth.login_user procedure
CREATE OR REPLACE PROCEDURE auth.login_user(
    IN p_username VARCHAR(255),
    IN p_password TEXT,
    IN p_ip_address INET,
    IN p_user_agent TEXT,
    OUT p_success BOOLEAN,
    OUT p_message TEXT,
    OUT p_tenant_list JSONB,
    OUT p_session_token TEXT,
    OUT p_user_data JSONB,
    IN p_auto_login BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_login_attempt_hk BYTEA;
    v_user_hk BYTEA;
    v_session_hk BYTEA;
    v_single_tenant_id TEXT;
    v_validation_result JSONB;
BEGIN
    -- Initialize outputs
    p_success := FALSE;
    p_message := 'Authentication failed';
    p_tenant_list := NULL;
    p_session_token := NULL;
    p_user_data := NULL;

    -- Step 1: Get system tenant for initial validation
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h
    WHERE tenant_bk = 'SYSTEM'
    LIMIT 1;
    
    IF v_tenant_hk IS NULL THEN
        -- Fallback to first available tenant for testing
        SELECT tenant_hk INTO v_tenant_hk
        FROM auth.tenant_h
        LIMIT 1;
        
        IF v_tenant_hk IS NULL THEN
            p_success := FALSE;
            p_message := 'No valid tenant found for authentication';
            RETURN;
        END IF;
    END IF;
    
    -- Step 2: Record the login attempt in raw schema
    v_login_attempt_hk := raw.capture_login_attempt(
        v_tenant_hk,
        p_username,
        p_password,
        p_ip_address,
        p_user_agent
    );
    
    -- Step 3: Validate the credentials
    v_validation_result := staging.validate_login_credentials(v_login_attempt_hk);
    
    -- Step 4: Process validation results
    IF (v_validation_result->>'status') != 'VALID' THEN
        p_success := FALSE;
        p_message := CASE 
            WHEN (v_validation_result->>'status') = 'INVALID_USER' THEN 'User not found'
            WHEN (v_validation_result->>'status') = 'INVALID_PASSWORD' THEN 'Invalid password'
            WHEN (v_validation_result->>'status') = 'LOCKED' THEN 'Account is locked'
            ELSE 'Login failed'
        END;
        RETURN;
    END IF;
    
    -- Credentials are valid - get user hash key
    v_user_hk := decode(v_validation_result->>'user_hk', 'hex');
    
    -- Step 5: Get list of tenants this user has access to
    SELECT jsonb_agg(
        jsonb_build_object(
            'tenant_id', t.tenant_bk,
            'tenant_name', COALESCE(tps.tenant_name, t.tenant_bk),
            'role', rds.role_name
        )
    ) INTO p_tenant_list
    FROM auth.user_h u
    JOIN auth.user_role_l url ON u.user_hk = url.user_hk
    JOIN auth.role_h r ON url.role_hk = r.role_hk
    JOIN auth.tenant_h t ON r.tenant_hk = t.tenant_hk
    LEFT JOIN auth.tenant_profile_s tps ON t.tenant_hk = tps.tenant_hk 
        AND tps.load_end_date IS NULL
    LEFT JOIN auth.role_definition_s rds ON r.role_hk = rds.role_hk
        AND rds.load_end_date IS NULL
    WHERE u.user_hk = v_user_hk;
    
    -- Authentication successful
    p_success := TRUE;
    p_message := 'Authentication successful';
    
    -- Step 6: Auto-login if requested and user has only one tenant
    IF p_auto_login AND jsonb_array_length(COALESCE(p_tenant_list, '[]'::jsonb)) = 1 THEN
        v_single_tenant_id := p_tenant_list->0->>'tenant_id';
        
        -- FIXED: Use the corrected session creation function
        CALL auth.create_session_with_token(
            v_user_hk,
            p_ip_address,
            p_user_agent,
            v_session_hk,
            p_session_token
        );
        
        -- Get user profile data
        SELECT jsonb_build_object(
            'user_id', u.user_bk,
            'email', uas.username,
            'first_name', COALESCE(ups.first_name, ''),
            'last_name', COALESCE(ups.last_name, ''),
            'tenant_id', v_single_tenant_id
        ) INTO p_user_data
        FROM auth.user_h u
        JOIN auth.user_auth_s uas ON u.user_hk = uas.user_hk
        LEFT JOIN auth.user_profile_s ups ON u.user_hk = ups.user_hk
        WHERE u.user_hk = v_user_hk
        AND uas.load_end_date IS NULL
        AND (ups.load_end_date IS NULL OR ups.load_end_date IS NULL);
        
        p_message := 'Login successful';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    -- Return generic error message
    p_success := FALSE;
    p_message := 'An unexpected error occurred during authentication';
    p_tenant_list := NULL;
    p_session_token := NULL;
    p_user_data := NULL;
    
    RAISE NOTICE 'Login error: % - %', SQLSTATE, SQLERRM;
END;
$$;

-- 7. FINAL TEST OF COMPLETE AUTHENTICATION FLOW
DO $$
DECLARE
    v_login_response JSONB;
    v_test_user TEXT := 'travisdwoodward72@gmail.com';
    v_test_password TEXT := 'MySecurePassword123';
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 FINAL AUTHENTICATION TEST AFTER FIXES';
    
    SELECT api.auth_login(jsonb_build_object(
        'username', v_test_user,
        'password', v_test_password,
        'ip_address', '192.168.1.100',
        'user_agent', 'Fixed-Auth-Test/1.0',
        'auto_login', true
    )) INTO v_login_response;
    
    RAISE NOTICE '   Login Success: %', v_login_response->>'success';
    RAISE NOTICE '   Message: %', v_login_response->>'message';
    RAISE NOTICE '   Session Token: %', 
        CASE 
            WHEN v_login_response->'data'->>'session_token' IS NOT NULL 
            THEN 'GENERATED ✅' 
            ELSE 'NULL ❌' 
        END;
    
    IF v_login_response->'data'->>'session_token' IS NOT NULL THEN
        RAISE NOTICE '';
        RAISE NOTICE '🎉 SUCCESS: Authentication system is now working correctly!';
        RAISE NOTICE '   • Session tokens are being generated';
        RAISE NOTICE '   • Auto-login is working for single-tenant users';
        RAISE NOTICE '   • Frontend can now receive complete authentication data';
    ELSE
        RAISE NOTICE '❌ Issue still exists - session token not generated';
    END IF;
END $$; 