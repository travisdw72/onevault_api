-- =============================================
-- debug_login_function_results.sql
-- Focuses on examining the api.auth_login function results
-- Based on findings: password works, sessions can be created, but something in login function is failing
-- =============================================

-- =============================================
-- Test the login function and examine detailed results
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== TESTING LOGIN FUNCTION - DETAILED RESULTS ===';
    RAISE NOTICE 'Based on investigation: MyNewSecurePassword123 works, SimpleTest123 fails';
    RAISE NOTICE 'Manual session creation works, so issue is in login function logic';
    RAISE NOTICE '';
END $$;

-- Test with the CORRECT password (MyNewSecurePassword123)
DO $$
DECLARE
    v_login_result JSONB;
BEGIN
    RAISE NOTICE '--- TEST 1: CORRECT PASSWORD ---';
    
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travisdwoodward72@gmail.com',
        'password', 'MyNewSecurePassword123',
        'ip_address', '192.168.1.100',
        'user_agent', 'Mozilla/5.0 Test',
        'auto_login', true
    )) INTO v_login_result;
    
    RAISE NOTICE 'LOGIN RESULT: %', v_login_result;
    RAISE NOTICE 'Success: %', v_login_result->>'p_success';
    RAISE NOTICE 'Message: %', v_login_result->>'p_message';
    RAISE NOTICE 'Session Token: %', COALESCE(v_login_result->>'p_session_token', 'NULL');
    RAISE NOTICE 'User Data: %', COALESCE(v_login_result->>'p_user_data', 'NULL');
    RAISE NOTICE '';
END $$;

-- Test with the INCORRECT password (SimpleTest123)
DO $$
DECLARE
    v_login_result JSONB;
BEGIN
    RAISE NOTICE '--- TEST 2: INCORRECT PASSWORD ---';
    
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travisdwoodward72@gmail.com',
        'password', 'SimpleTest123',
        'ip_address', '192.168.1.100',
        'user_agent', 'Mozilla/5.0 Test'
    )) INTO v_login_result;
    
    RAISE NOTICE 'LOGIN RESULT: %', v_login_result;
    RAISE NOTICE 'Success: %', v_login_result->>'p_success';
    RAISE NOTICE 'Message: %', v_login_result->>'p_message';
    RAISE NOTICE '';
END $$;

-- Check sessions created in the last few minutes (should include our tests)
SELECT 
    'SESSIONS CREATED DURING TESTING' as check_type,
    sh.session_bk,
    sss.session_start,
    sss.session_status,
    sss.ip_address,
    sss.user_agent,
    sss.record_source
FROM auth.session_h sh
JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
WHERE sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '10 minutes'
AND sss.load_end_date IS NULL
ORDER BY sss.session_start DESC;

-- Check if the login function is creating sessions but with different criteria
SELECT 
    'ALL RECENT SESSIONS' as check_type,
    COUNT(*) as total_sessions,
    COUNT(CASE WHEN sss.session_status = 'ACTIVE' THEN 1 END) as active_sessions,
    COUNT(CASE WHEN sss.record_source LIKE '%MANUAL%' THEN 1 END) as manual_test_sessions,
    COUNT(CASE WHEN sss.record_source NOT LIKE '%MANUAL%' THEN 1 END) as api_created_sessions
FROM auth.session_h sh
JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
WHERE sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '30 minutes'
AND sss.load_end_date IS NULL;

-- =============================================
-- Examine the api.auth_login function definition
-- =============================================

DO $$
DECLARE
    v_function_source TEXT;
BEGIN
    RAISE NOTICE '=== API.AUTH_LOGIN FUNCTION ANALYSIS ===';
    
    -- Get the function source code (first 500 characters)
    SELECT LEFT(pg_get_functiondef(p.oid), 500) INTO v_function_source
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'api' AND p.proname = 'auth_login';
    
    IF v_function_source IS NOT NULL THEN
        RAISE NOTICE 'Function exists. First 500 chars:';
        RAISE NOTICE '%', v_function_source;
    ELSE
        RAISE NOTICE 'ERROR: api.auth_login function does not exist!';
    END IF;
END $$;

-- =============================================
-- Check if there are any errors in session creation within the function
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== POTENTIAL ISSUES IN LOGIN FUNCTION ===';
    RAISE NOTICE '';
    RAISE NOTICE 'Based on our findings:';
    RAISE NOTICE '1. Password verification works correctly';
    RAISE NOTICE '2. Manual session creation works';
    RAISE NOTICE '3. Database has no permission issues';
    RAISE NOTICE '';
    RAISE NOTICE 'Possible causes of missing sessions:';
    RAISE NOTICE '- Login function returns success but fails silently in session creation';
    RAISE NOTICE '- Login function creates sessions but they are immediately invalidated';
    RAISE NOTICE '- Login function has conditional logic that skips session creation';
    RAISE NOTICE '- Session creation errors are caught and ignored in the function';
    RAISE NOTICE '';
    RAISE NOTICE 'Check the login results above to see what the function actually returns.';
    RAISE NOTICE '';
END $$;

-- =============================================
-- Test session lookup by session token (if we got one)
-- =============================================

-- Note: This will be run manually with the session token from the login result
-- SELECT auth.validate_token_and_session('SESSION_TOKEN_HERE') as validation_result;

DO $$
BEGIN
    RAISE NOTICE '=== NEXT DEBUGGING STEPS ===';
    RAISE NOTICE '';
    RAISE NOTICE 'If login function returns success but no session is found:';
    RAISE NOTICE '1. Check if session creation code is actually being called';
    RAISE NOTICE '2. Look for silent errors in session creation within the function';
    RAISE NOTICE '3. Check if sessions are created but with different load_date filtering';
    RAISE NOTICE '4. Verify session token validation logic';
    RAISE NOTICE '';
    RAISE NOTICE 'If login function returns failure:';
    RAISE NOTICE '1. The password change to MyNewSecurePassword123 may not have been applied';
    RAISE NOTICE '2. There may be additional validation logic failing';
    RAISE NOTICE '3. Account may be locked or have other restrictions';
    RAISE NOTICE '';
END $$; 