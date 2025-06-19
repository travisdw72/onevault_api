-- =============================================
-- show_auth_login_function_details.sql
-- Shows the api.auth_login function source code and recent usage
-- =============================================

-- Show the complete function definition
SELECT 'COMPLETE api.auth_login FUNCTION SOURCE CODE:' as info;

SELECT pg_get_functiondef(p.oid) as function_source_code
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api' AND p.proname = 'auth_login';

-- Show function details
SELECT 'FUNCTION DETAILS:' as info;

SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    pg_catalog.format_type(p.prorettype, NULL) as return_type,
    p.prosrc as function_body_short
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api' AND p.proname = 'auth_login';

-- Test the function with both correct and incorrect passwords to see results
SELECT 'TESTING FUNCTION WITH CORRECT PASSWORD:' as test_type;

SELECT api.auth_login(jsonb_build_object(
    'username', 'travisdwoodward72@gmail.com',
    'password', 'MyNewSecurePassword123',
    'ip_address', '192.168.1.100',
    'user_agent', 'Function Analysis Test'
)) as correct_password_result;

SELECT 'TESTING FUNCTION WITH INCORRECT PASSWORD:' as test_type;

SELECT api.auth_login(jsonb_build_object(
    'username', 'travisdwoodward72@gmail.com',
    'password', 'WrongPassword123',
    'ip_address', '192.168.1.100',
    'user_agent', 'Function Analysis Test'
)) as incorrect_password_result;

-- Check if there are any audit records of recent login attempts
SELECT 'RECENT AUDIT RECORDS (if audit logging is working):' as info;

SELECT 
    aeh.audit_event_bk,
    aeh.load_date,
    ads.operation,
    ads.changed_by,
    ads.old_data,
    ads.new_data
FROM audit.audit_event_h aeh
JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
WHERE aeh.load_date >= CURRENT_TIMESTAMP - INTERVAL '2 hours'
AND (
    ads.operation ILIKE '%login%' 
    OR ads.changed_by = 'travisdwoodward72@gmail.com'
    OR ads.new_data::text ILIKE '%travisdwoodward72@gmail.com%'
)
ORDER BY aeh.load_date DESC
LIMIT 5;

-- Check for any sessions created in the last hour
SELECT 'SESSIONS CREATED IN LAST HOUR:' as info;

SELECT 
    sh.session_bk,
    sss.session_start,
    sss.session_status,
    sss.ip_address,
    sss.user_agent,
    sss.record_source,
    sss.session_data
FROM auth.session_h sh
JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
WHERE sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
ORDER BY sss.session_start DESC;

-- Check for sessions specifically linked to our user
SELECT 'SESSIONS LINKED TO travisdwoodward72@gmail.com:' as info;

SELECT 
    sh.session_bk,
    sss.session_start,
    sss.session_status,
    sss.ip_address,
    sss.record_source,
    sss.load_date
FROM auth.user_h uh
JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
JOIN auth.user_session_l usl ON uh.user_hk = usl.user_hk
JOIN auth.session_h sh ON usl.session_hk = sh.session_hk
JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
WHERE uas.username = 'travisdwoodward72@gmail.com'
AND uas.load_end_date IS NULL
AND sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY sss.session_start DESC
LIMIT 10;

-- Show any PostgreSQL log entries (if available)
SELECT 'CHECKING FOR RELATED FUNCTIONS:' as info;

SELECT 
    n.nspname as schema,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE (
    (n.nspname = 'api' AND p.proname ILIKE '%login%')
    OR (n.nspname = 'auth' AND p.proname ILIKE '%session%')
    OR (n.nspname = 'auth' AND p.proname ILIKE '%create%')
)
ORDER BY n.nspname, p.proname;

-- Count total function calls by checking if there's any session creation happening
SELECT 'BEFORE AND AFTER SESSION COUNT:' as info;

-- Count sessions before our test
WITH before_count AS (
    SELECT COUNT(*) as count_before
    FROM auth.session_h sh
    JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
    WHERE sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '5 minutes'
),
-- Run another test login
test_login AS (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travisdwoodward72@gmail.com',
        'password', 'MyNewSecurePassword123',
        'ip_address', '192.168.1.100',
        'user_agent', 'Session Count Test'
    )) as login_result
),
-- Count sessions after our test  
after_count AS (
    SELECT COUNT(*) as count_after
    FROM auth.session_h sh
    JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
    WHERE sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '5 minutes'
)
SELECT 
    bc.count_before,
    tl.login_result,
    ac.count_after,
    (ac.count_after - bc.count_before) as sessions_created_by_login
FROM before_count bc, test_login tl, after_count ac; 