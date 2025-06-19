-- =============================================================================
-- PASSWORD MANAGEMENT API ENDPOINT TESTING
-- Date: 2025-01-08
-- Purpose: Test all password management APIs for frontend integration readiness
-- =============================================================================

DO $$
DECLARE
    v_test_user TEXT := 'travisdwoodward72@gmail.com';
    v_test_admin TEXT := 'travisdwoodward72@gmail.com'; -- Same user as admin for testing
    v_current_password TEXT := 'MySecurePassword123';
    v_new_password TEXT := 'NewTestPassword456';
    v_temp_password TEXT := 'TempResetPassword789';
    
    v_change_response JSONB;
    v_reset_response JSONB;
    v_forgot_response JSONB;
    v_reset_token TEXT;
    
    v_test_session_token TEXT := 'test_session_token_12345';
    v_user_hk BYTEA;
    v_tenant_hk BYTEA;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE '           PASSWORD MANAGEMENT API ENDPOINT TESTING';
    RAISE NOTICE '=============================================================================';
    
    -- Get user context for testing
    SELECT uh.user_hk, uh.tenant_hk INTO v_user_hk, v_tenant_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_test_user
    AND uas.load_end_date IS NULL
    LIMIT 1;
    
    IF v_user_hk IS NULL THEN
        RAISE NOTICE '❌ Test user not found: %', v_test_user;
        RAISE NOTICE 'Cannot proceed with API testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Test user found: % (User HK: %)', v_test_user, encode(v_user_hk, 'hex');
    RAISE NOTICE '';
    
    -- =================================================================
    -- TEST 1: User Password Change API
    -- =================================================================
    RAISE NOTICE '🔐 TEST 1: User Password Change API';
    RAISE NOTICE '   Endpoint: POST /api/v1/auth/change-password';
    RAISE NOTICE '   Function: api.change_password()';
    
    -- Check if function exists
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' AND p.proname = 'change_password'
    ) THEN
        RAISE NOTICE '   ✅ Function exists: api.change_password()';
        
        -- Test the API call
        SELECT api.change_password(jsonb_build_object(
            'username', v_test_user,
            'current_password', v_current_password,
            'new_password', v_new_password,
            'session_token', v_test_session_token,
            'ip_address', '192.168.1.100',
            'user_agent', 'Password-Test-Suite/1.0'
        )) INTO v_change_response;
        
        RAISE NOTICE '   API Response:';
        RAISE NOTICE '     Success: %', v_change_response->>'success';
        RAISE NOTICE '     Message: %', v_change_response->>'message';
        RAISE NOTICE '     HTTP Status: %', COALESCE(v_change_response->>'http_status', 'Not specified');
        
        IF (v_change_response->>'success')::BOOLEAN THEN
            RAISE NOTICE '   ✅ Password change API working correctly!';
            
            -- Update our test password for subsequent tests
            v_current_password := v_new_password;
        ELSE
            RAISE NOTICE '   ⚠️  Password change failed: %', v_change_response->>'error_code';
        END IF;
    ELSE
        RAISE NOTICE '   ❌ Function NOT found: api.change_password()';
    END IF;
    
    RAISE NOTICE '';
    
    -- =================================================================
    -- TEST 2: Admin Password Reset API  
    -- =================================================================
    RAISE NOTICE '🔧 TEST 2: Admin Password Reset API';
    RAISE NOTICE '   Endpoint: POST /api/v1/auth/admin/reset-password';
    RAISE NOTICE '   Function: api.admin_reset_password()';
    
    -- Check if function exists
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' AND p.proname = 'admin_reset_password'
    ) THEN
        RAISE NOTICE '   ✅ Function exists: api.admin_reset_password()';
        
        -- Test admin reset (self-reset for testing)
        SELECT api.admin_reset_password(jsonb_build_object(
            'admin_username', v_test_admin,
            'target_username', v_test_user,
            'new_password', v_temp_password,
            'generate_random', false,
            'force_change', false,
            'admin_session_token', v_test_session_token,
            'ip_address', '192.168.1.100',
            'user_agent', 'Admin-Reset-Test/1.0'
        )) INTO v_reset_response;
        
        RAISE NOTICE '   API Response:';
        RAISE NOTICE '     Success: %', v_reset_response->>'success';
        RAISE NOTICE '     Message: %', v_reset_response->>'message';
        RAISE NOTICE '     HTTP Status: %', COALESCE(v_reset_response->>'http_status', 'Not specified');
        
        IF (v_reset_response->>'success')::BOOLEAN THEN
            RAISE NOTICE '   ✅ Admin password reset API working correctly!';
            
            -- Show reset details
            IF v_reset_response->'data' IS NOT NULL THEN
                RAISE NOTICE '     Reset Date: %', v_reset_response->'data'->>'password_reset_date';
                RAISE NOTICE '     Account Unlocked: %', v_reset_response->'data'->>'account_unlocked';
            END IF;
            
            -- Update our test password for subsequent tests
            v_current_password := v_temp_password;
        ELSE
            RAISE NOTICE '   ⚠️  Admin reset failed: %', v_reset_response->>'error_code';
        END IF;
    ELSE
        RAISE NOTICE '   ❌ Function NOT found: api.admin_reset_password()';
    END IF;
    
    RAISE NOTICE '';
    
    -- =================================================================
    -- TEST 3: Forgot Password Request API
    -- =================================================================
    RAISE NOTICE '🔄 TEST 3: Forgot Password Request API';
    RAISE NOTICE '   Endpoint: POST /api/v1/auth/forgot-password';
    RAISE NOTICE '   Function: api.forgot_password_request()';
    
    -- Check if function exists
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' AND p.proname = 'forgot_password_request'
    ) THEN
        RAISE NOTICE '   ✅ Function exists: api.forgot_password_request()';
        
        -- Test forgot password request
        SELECT api.forgot_password_request(jsonb_build_object(
            'username', v_test_user,
            'ip_address', '192.168.1.100',
            'user_agent', 'Forgot-Password-Test/1.0'
        )) INTO v_forgot_response;
        
        RAISE NOTICE '   API Response:';
        RAISE NOTICE '     Success: %', v_forgot_response->>'success';
        RAISE NOTICE '     Message: %', v_forgot_response->>'message';
        RAISE NOTICE '     HTTP Status: %', COALESCE(v_forgot_response->>'http_status', 'Not specified');
        
        IF (v_forgot_response->>'success')::BOOLEAN THEN
            RAISE NOTICE '   ✅ Forgot password API working correctly!';
            
            -- Extract reset token for testing
            v_reset_token := v_forgot_response->'data'->>'reset_token';
            IF v_reset_token IS NOT NULL AND v_reset_token != 'NO_USER' THEN
                RAISE NOTICE '     Reset Token Generated: %...', SUBSTRING(v_reset_token, 1, 16);
                RAISE NOTICE '     Token Expires In: % minutes', v_forgot_response->'data'->>'expires_in_minutes';
            END IF;
        ELSE
            RAISE NOTICE '   ⚠️  Forgot password failed: %', v_forgot_response->>'error_code';
        END IF;
    ELSE
        RAISE NOTICE '   ❌ Function NOT found: api.forgot_password_request()';
    END IF;
    
    RAISE NOTICE '';
    
    -- =================================================================
    -- TEST 4: Core Password Functions (Backend)
    -- =================================================================
    RAISE NOTICE '⚙️  TEST 4: Core Password Management Functions';
    
    -- Test auth.change_password (core function)
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'auth' AND p.proname = 'change_password'
    ) THEN
        RAISE NOTICE '   ✅ Core function exists: auth.change_password()';
    ELSE
        RAISE NOTICE '   ❌ Core function MISSING: auth.change_password()';
    END IF;
    
    -- Test auth.reset_password (core function)
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'auth' AND p.proname = 'reset_password'
    ) THEN
        RAISE NOTICE '   ✅ Core function exists: auth.reset_password()';
    ELSE
        RAISE NOTICE '   ❌ Core function MISSING: auth.reset_password()';
    END IF;
    
    -- Test auth.update_user_password_direct (emergency function)
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'auth' AND p.proname = 'update_user_password_direct'
    ) THEN
        RAISE NOTICE '   ✅ Emergency function exists: auth.update_user_password_direct()';
    ELSE
        RAISE NOTICE '   ❌ Emergency function MISSING: auth.update_user_password_direct()';
    END IF;
    
    RAISE NOTICE '';
    
    -- =================================================================
    -- TEST 5: Password Validation After Changes
    -- =================================================================
    RAISE NOTICE '🧪 TEST 5: Password Validation After Changes';
    
    -- Test if we can authenticate with the current password
    DECLARE
        v_auth_test JSONB;
    BEGIN
        SELECT api.auth_login(jsonb_build_object(
            'username', v_test_user,
            'password', v_current_password,
            'ip_address', '192.168.1.100',
            'user_agent', 'Password-Validation-Test/1.0',
            'auto_login', false
        )) INTO v_auth_test;
        
        RAISE NOTICE '   Current Password Test:';
        RAISE NOTICE '     Success: %', v_auth_test->>'success';
        RAISE NOTICE '     Message: %', v_auth_test->>'message';
        
        IF (v_auth_test->>'success')::BOOLEAN THEN
            RAISE NOTICE '   ✅ Current password is valid for authentication';
        ELSE
            RAISE NOTICE '   ⚠️  Current password authentication failed';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '   ❌ Password validation test error: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
    
    -- =================================================================
    -- TEST SUMMARY & FRONTEND INTEGRATION READINESS
    -- =================================================================
    RAISE NOTICE '📋 API TESTING SUMMARY:';
    RAISE NOTICE '';
    
    -- Check all required API functions
    DECLARE
        v_change_api_exists BOOLEAN;
        v_reset_api_exists BOOLEAN;
        v_forgot_api_exists BOOLEAN;
        v_readiness_score INTEGER := 0;
    BEGIN
        -- Check API function availability
        SELECT EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api' AND p.proname = 'change_password'
        ) INTO v_change_api_exists;
        
        SELECT EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api' AND p.proname = 'admin_reset_password'
        ) INTO v_reset_api_exists;
        
        SELECT EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api' AND p.proname = 'forgot_password_request'
        ) INTO v_forgot_api_exists;
        
        -- Calculate readiness score
        IF v_change_api_exists THEN v_readiness_score := v_readiness_score + 1; END IF;
        IF v_reset_api_exists THEN v_readiness_score := v_readiness_score + 1; END IF;
        IF v_forgot_api_exists THEN v_readiness_score := v_readiness_score + 1; END IF;
        
        RAISE NOTICE '   Password Management API Readiness: %/3 (%.0f%%)',
            v_readiness_score, 
            (v_readiness_score::numeric / 3.0 * 100);
        
        RAISE NOTICE '';
        RAISE NOTICE '   API Endpoints Status:';
        RAISE NOTICE '     POST /api/v1/auth/change-password: %',
            CASE WHEN v_change_api_exists THEN '✅ READY' ELSE '❌ MISSING' END;
        RAISE NOTICE '     POST /api/v1/auth/admin/reset-password: %',
            CASE WHEN v_reset_api_exists THEN '✅ READY' ELSE '❌ MISSING' END;
        RAISE NOTICE '     POST /api/v1/auth/forgot-password: %',
            CASE WHEN v_forgot_api_exists THEN '✅ READY' ELSE '❌ MISSING' END;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '🚀 FRONTEND INTEGRATION RECOMMENDATIONS:';
    
    IF v_change_api_exists THEN
        RAISE NOTICE '   ✅ User password change: Frontend can implement self-service password change';
    ELSE
        RAISE NOTICE '   ⚠️  User password change: Need to implement api.change_password()';
    END IF;
    
    IF v_reset_api_exists THEN
        RAISE NOTICE '   ✅ Admin password reset: Frontend can implement admin user management';
    ELSE
        RAISE NOTICE '   ⚠️  Admin password reset: Need to implement api.admin_reset_password()';
    END IF;
    
    IF v_forgot_api_exists THEN
        RAISE NOTICE '   ✅ Forgot password: Frontend can implement password recovery flow';
    ELSE
        RAISE NOTICE '   ⚠️  Forgot password: Need to implement api.forgot_password_request()';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎯 NEXT STEPS FOR FRONTEND:';
    RAISE NOTICE '   1. Implement password change form with current/new password fields';
    RAISE NOTICE '   2. Add admin password reset interface for user management';
    RAISE NOTICE '   3. Create forgot password flow with email integration';
    RAISE NOTICE '   4. Add password strength validation on frontend';
    RAISE NOTICE '   5. Implement proper error handling for all password operations';
    
    RAISE NOTICE '';
    RAISE NOTICE '=============================================================================';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '';
    RAISE NOTICE '❌ ERROR during password management API testing: %', SQLERRM;
    RAISE NOTICE '   SQLState: %', SQLSTATE;
END $$; 