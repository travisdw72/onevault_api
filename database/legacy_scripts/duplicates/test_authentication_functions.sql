-- =============================================
-- Authentication Flow Testing Script
-- Testing each step of the api.auth_login() process
-- =============================================

DO $$
DECLARE
    v_test_username VARCHAR(255) := 'travisdwoodward72@gmail.com';
    v_test_password TEXT := 'MyNewSecurePassword123';
    v_test_ip INET := '192.168.1.100';
    v_test_user_agent TEXT := 'Test Browser 1.0';
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_user_auth RECORD;
    v_login_attempt_hk BYTEA;
    v_session_hk BYTEA;
    v_session_token TEXT;
    v_result JSONB;
    v_failed_login_result BOOLEAN;
    v_function_signature TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'AUTHENTICATION FLOW TESTING';
    RAISE NOTICE '====================================';
    
    -- =============================================
    -- TEST 1: Check if required functions exist
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- TEST 1: Function Existence Check ---';
    
    -- Check raw.capture_login_attempt
    PERFORM 1 FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'raw' AND p.proname = 'capture_login_attempt';
    
    IF FOUND THEN
        RAISE NOTICE '✅ raw.capture_login_attempt exists';
        
        -- Check function signature
        SELECT pg_get_function_arguments(p.oid) as signature
        INTO v_function_signature
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'raw' AND p.proname = 'capture_login_attempt';
        
        RAISE NOTICE 'Function signature will be checked...';
    ELSE
        RAISE NOTICE '❌ raw.capture_login_attempt NOT FOUND';
    END IF;
    
    -- Check auth.process_failed_login
    PERFORM 1 FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'auth' AND p.proname = 'process_failed_login';
    
    IF FOUND THEN
        RAISE NOTICE '✅ auth.process_failed_login exists';
    ELSE
        RAISE NOTICE '❌ auth.process_failed_login NOT FOUND';
    END IF;
    
    -- Check auth.create_session_with_token
    PERFORM 1 FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'auth' AND p.proname = 'create_session_with_token';
    
    IF FOUND THEN
        RAISE NOTICE '✅ auth.create_session_with_token exists';
    ELSE
        RAISE NOTICE '❌ auth.create_session_with_token NOT FOUND';
    END IF;
    
    -- =============================================
    -- TEST 2: Test User Lookup (Step 1 of API)
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- TEST 2: User Lookup ---';
    
    SELECT 
        uh.user_hk,
        uh.tenant_hk,
        uas.password_hash,
        uas.username,
        uas.account_locked,
        uas.account_locked_until,
        COALESCE(uas.failed_login_attempts, 0) as failed_attempts
    INTO v_user_auth
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_test_username
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    IF v_user_auth.user_hk IS NOT NULL THEN
        RAISE NOTICE '✅ User found: %', v_test_username;
        RAISE NOTICE '   User HK: %', encode(v_user_auth.user_hk, 'hex');
        RAISE NOTICE '   Tenant HK: %', encode(v_user_auth.tenant_hk, 'hex');
        RAISE NOTICE '   Account Locked: %', v_user_auth.account_locked;
        RAISE NOTICE '   Failed Attempts: %', v_user_auth.failed_attempts;
        
        v_user_hk := v_user_auth.user_hk;
        v_tenant_hk := v_user_auth.tenant_hk;
    ELSE
        RAISE NOTICE '❌ User NOT FOUND: %', v_test_username;
        RETURN; -- Cannot continue without user
    END IF;
    
    -- =============================================
    -- TEST 3: Test Password Validation (Step 3 of API)
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- TEST 3: Password Validation ---';
    
    IF v_user_auth.password_hash IS NOT NULL THEN
        -- Test with correct password
        IF (crypt(v_test_password, v_user_auth.password_hash::text) = v_user_auth.password_hash::text) THEN
            RAISE NOTICE '✅ Password validation PASSED for: %', v_test_password;
        ELSE
            RAISE NOTICE '❌ Password validation FAILED for: %', v_test_password;
        END IF;
        
        -- Test with incorrect password
        IF (crypt('WrongPassword123', v_user_auth.password_hash::text) = v_user_auth.password_hash::text) THEN
            RAISE NOTICE '❌ SECURITY ISSUE: Wrong password accepted!';
        ELSE
            RAISE NOTICE '✅ Wrong password correctly rejected';
        END IF;
    ELSE
        RAISE NOTICE '❌ No password hash found for user';
    END IF;
    
    -- =============================================
    -- TEST 4: Test raw.capture_login_attempt (Step 4 of API)
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- TEST 4: Login Attempt Capture ---';
    
    BEGIN
        -- Test the secure version (4 parameters - no password)
        v_login_attempt_hk := raw.capture_login_attempt(
            v_tenant_hk,
            v_test_username,
            v_test_ip,
            v_test_user_agent
        );
        
        IF v_login_attempt_hk IS NOT NULL THEN
            RAISE NOTICE '✅ Login attempt captured successfully';
            RAISE NOTICE '   Login Attempt HK: %', encode(v_login_attempt_hk, 'hex');
            
            -- Verify the record was created
            PERFORM 1 FROM raw.login_attempt_h 
            WHERE login_attempt_hk = v_login_attempt_hk;
            
            IF FOUND THEN
                RAISE NOTICE '✅ Login attempt hub record verified';
            ELSE
                RAISE NOTICE '❌ Login attempt hub record NOT FOUND';
            END IF;
            
            -- Check satellite record
            PERFORM 1 FROM raw.login_attempt_s 
            WHERE login_attempt_hk = v_login_attempt_hk;
            
            IF FOUND THEN
                RAISE NOTICE '✅ Login attempt satellite record verified';
            ELSE
                RAISE NOTICE '❌ Login attempt satellite record NOT FOUND';
            END IF;
        ELSE
            RAISE NOTICE '❌ Login attempt capture returned NULL';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Login attempt capture FAILED: % - %', SQLSTATE, SQLERRM;
    END;
    
    -- =============================================
    -- TEST 5: Test auth.process_failed_login (Step 5 of API)
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- TEST 5: Failed Login Processing ---';
    
    BEGIN
        -- Test with invalid password scenario
        v_failed_login_result := auth.process_failed_login(
            v_tenant_hk,
            v_test_username,
            'INVALID_PASSWORD',
            v_test_ip
        );
        
        RAISE NOTICE '✅ Failed login processing completed: %', v_failed_login_result;
        
        -- Check if failed attempts were incremented
        SELECT COALESCE(uas.failed_login_attempts, 0) as failed_attempts
        INTO v_user_auth.failed_attempts
        FROM auth.user_auth_s uas
        WHERE uas.user_hk = v_user_hk
        AND uas.load_end_date IS NULL
        ORDER BY uas.load_date DESC
        LIMIT 1;
        
        RAISE NOTICE '   Updated failed attempts: %', v_user_auth.failed_attempts;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Failed login processing ERROR: % - %', SQLSTATE, SQLERRM;
    END;
    
    -- =============================================
    -- TEST 6: Test auth.create_session_with_token (Step 7 of API)
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- TEST 6: Session Creation ---';
    
    BEGIN
        -- Reset failed attempts first (simulate successful login)
        UPDATE auth.user_auth_s
        SET load_end_date = util.current_load_date()
        WHERE user_hk = v_user_hk
        AND load_end_date IS NULL;
        
        INSERT INTO auth.user_auth_s (
            user_hk,
            load_date,
            hash_diff,
            username,
            password_hash,
            password_salt,
            last_login_date,
            password_last_changed,
            failed_login_attempts,
            account_locked,
            account_locked_until,
            must_change_password,
            record_source
        )
        SELECT 
            user_hk,
            util.current_load_date(),
            util.hash_binary(username || 'TEST_RESET' || CURRENT_TIMESTAMP::text),
            username,
            password_hash,
            password_salt,
            CURRENT_TIMESTAMP,
            password_last_changed,
            0, -- Reset failed attempts
            FALSE, -- Unlock account
            NULL, -- Clear lockout time
            must_change_password,
            util.get_record_source()
        FROM auth.user_auth_s
        WHERE user_hk = v_user_hk
        AND load_end_date = util.current_load_date()
        ORDER BY load_date DESC
        LIMIT 1;
        
        RAISE NOTICE '✅ User auth reset for testing';
        
        -- Test session creation
        CALL auth.create_session_with_token(
            v_user_hk,
            v_test_ip,
            v_test_user_agent,
            v_session_hk,
            v_session_token
        );
        
        IF v_session_hk IS NOT NULL AND v_session_token IS NOT NULL THEN
            RAISE NOTICE '✅ Session created successfully';
            RAISE NOTICE '   Session HK: %', encode(v_session_hk, 'hex');
            RAISE NOTICE '   Session Token: %...', left(v_session_token, 20);
            
            -- Verify session hub record
            PERFORM 1 FROM auth.session_h 
            WHERE session_hk = v_session_hk;
            
            IF FOUND THEN
                RAISE NOTICE '✅ Session hub record verified';
            ELSE
                RAISE NOTICE '❌ Session hub record NOT FOUND';
            END IF;
            
            -- Verify session state record
            PERFORM 1 FROM auth.session_state_s 
            WHERE session_hk = v_session_hk
            AND load_end_date IS NULL;
            
            IF FOUND THEN
                RAISE NOTICE '✅ Session state record verified';
            ELSE
                RAISE NOTICE '❌ Session state record NOT FOUND';
            END IF;
            
            -- Verify user-session link
            PERFORM 1 FROM auth.user_session_l 
            WHERE user_hk = v_user_hk 
            AND session_hk = v_session_hk;
            
            IF FOUND THEN
                RAISE NOTICE '✅ User-session link verified';
            ELSE
                RAISE NOTICE '❌ User-session link NOT FOUND';
            END IF;
            
        ELSE
            RAISE NOTICE '❌ Session creation returned NULL values';
            RAISE NOTICE '   Session HK: %', COALESCE(encode(v_session_hk, 'hex'), 'NULL');
            RAISE NOTICE '   Session Token: %', COALESCE(v_session_token, 'NULL');
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Session creation FAILED: % - %', SQLSTATE, SQLERRM;
    END;
    
    -- =============================================
    -- TEST 7: Full API Contract Test
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- TEST 7: Full API Contract ---';
    
    BEGIN
        -- Test the complete API function
        v_result := api.auth_login(jsonb_build_object(
            'username', v_test_username,
            'password', v_test_password,
            'ip_address', v_test_ip::text,
            'user_agent', v_test_user_agent,
            'auto_login', true
        ));
        
        RAISE NOTICE '✅ API Contract executed successfully';
        RAISE NOTICE '   Success: %', v_result->>'success';
        RAISE NOTICE '   Message: %', v_result->>'message';
        RAISE NOTICE '   Error Code: %', COALESCE(v_result->>'error_code', 'NONE');
        
        IF (v_result->>'success')::boolean THEN
            RAISE NOTICE '   Session Token: %...', 
                left(COALESCE(v_result->'data'->>'session_token', 'NULL'), 20);
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ API Contract FAILED: % - %', SQLSTATE, SQLERRM;
    END;
    
    -- =============================================
    -- TEST 8: Validation and Security Verification
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- TEST 8: Security Validation ---';
    
    -- Run the security validation function
    SELECT api.validate_secure_contract() INTO v_result;
    
    RAISE NOTICE '✅ Security Validation Results:';
    RAISE NOTICE '   %', v_result->>'security_validation';
    RAISE NOTICE '   Raw Function Exists: %', v_result->>'raw_function_exists';
    RAISE NOTICE '   Retry Function Exists: %', v_result->>'retry_function_exists';
    RAISE NOTICE '   Critical Fix: %', v_result->>'critical_fix';
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'AUTHENTICATION TESTING COMPLETE';
    RAISE NOTICE '====================================';
    
END $$;