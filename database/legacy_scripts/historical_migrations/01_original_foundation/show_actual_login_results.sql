-- =============================================
-- show_actual_login_results.sql
-- Shows the actual data results (not just notices) from login and session queries
-- This will help us see what api.auth_login() actually returns
-- =============================================

-- =============================================
-- TEST 1: What does api.auth_login() return with correct password?
-- =============================================

SELECT '=== TEST 1: LOGIN WITH CORRECT PASSWORD ===' as test_header;

SELECT api.auth_login(jsonb_build_object(
    'username', 'travisdwoodward72@gmail.com',
    'password', 'MyNewSecurePassword321',
    'ip_address', '192.168.1.100',
    'user_agent', 'Mozilla/5.0 Test',
    'auto_login', true
)) as login_result_correct_password;

SELECT '' as spacer;
SELECT '=== TEST 2: LOGIN WITH INCORRECT PASSWORD ===' as test_header;

SELECT api.auth_login(jsonb_build_object(
    'username', 'travisdwoodward72@gmail.com',
    'password', 'SimpleTest123',
    'ip_address', '192.168.1.100',
    'user_agent', 'Mozilla/5.0 Test'
)) as login_result_incorrect_password;

-- =============================================
-- Show all recent sessions (last 30 minutes)
-- =============================================

SELECT '' as spacer;
SELECT '=== ALL SESSIONS FROM LAST 30 MINUTES ===' as section_header;

SELECT 
    sh.session_bk,
    sss.session_start,
    sss.session_status,
    sss.ip_address,
    sss.user_agent,
    sss.record_source,
    sss.load_date,
    sss.load_end_date
FROM auth.session_h sh
JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
WHERE sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '30 minutes'
ORDER BY sss.session_start DESC;

-- =============================================
-- Show sessions specifically for our user
-- =============================================

SELECT '' as spacer;
SELECT '=== SESSIONS FOR travisdwoodward72@gmail.com ===' as section_header;

SELECT 
    'USER_SESSIONS' as query_type,
    sh.session_bk,
    sss.session_start,
    sss.session_status,
    sss.ip_address,
    sss.record_source
FROM auth.user_h uh
JOIN auth.user_session_l usl ON uh.user_hk = usl.user_hk
JOIN auth.session_h sh ON usl.session_hk = sh.session_hk
JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
WHERE uh.user_bk = (
    SELECT user_bk FROM auth.user_h uh2 
    JOIN auth.user_auth_s uas2 ON uh2.user_hk = uas2.user_hk 
    WHERE uas2.username = 'travisdwoodward72@gmail.com' 
    AND uas2.load_end_date IS NULL
    LIMIT 1
)
ORDER BY sss.session_start DESC
LIMIT 10;

-- =============================================
-- Check if api.auth_login function exists
-- =============================================

SELECT '' as spacer;
SELECT '=== API FUNCTION EXISTENCE CHECK ===' as section_header;

SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api'
AND p.proname = 'auth_login';

-- =============================================
-- Count sessions by status and time
-- =============================================

SELECT '' as spacer;
SELECT '=== SESSION COUNTS BY STATUS ===' as section_header;

SELECT 
    sss.session_status,
    COUNT(*) as count,
    MIN(sss.session_start) as earliest,
    MAX(sss.session_start) as latest
FROM auth.session_h sh
JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
WHERE sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY sss.session_status
ORDER BY count DESC;

-- =============================================
-- Simple test to see if login creates sessions immediately
-- =============================================

SELECT '' as spacer;
SELECT '=== BEFORE/AFTER SESSION COUNT TEST ===' as section_header;

-- Count before
SELECT COUNT(*) as sessions_before_test
FROM auth.session_h sh
JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
WHERE sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '5 minutes';

SELECT 'Running login test now...' as status;

-- Run login test
SELECT 'LOGIN_TEST_RUNNING' as status, 
       api.auth_login(jsonb_build_object(
           'username', 'travisdwoodward72@gmail.com',
           'password', 'MyNewSecurePassword123',
           'ip_address', '192.168.1.100',
           'user_agent', 'Session Test'
       )) as test_login_result;

-- Count after
SELECT COUNT(*) as sessions_after_test
FROM auth.session_h sh
JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
WHERE sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '5 minutes';

SELECT '' as spacer;
SELECT '=== ANALYSIS ===' as section_header;
SELECT 'Compare sessions_before_test vs sessions_after_test' as message;
SELECT 'If they are the same, login function is not creating sessions' as message;
SELECT 'If sessions_after_test is higher, login function IS creating sessions' as message;