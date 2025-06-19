-- =============================================
-- step_by_step_diagnosis.sql
-- Step-by-step diagnosis that shows results even when queries return no data
-- =============================================

-- Check if api.auth_login function exists
SELECT 'STEP 1: Checking if api.auth_login function exists' as step;

SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN 'FOUND: api.auth_login function exists'
        ELSE 'ERROR: api.auth_login function does NOT exist!'
    END as function_status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api' AND p.proname = 'auth_login';

-- Check what api functions DO exist
SELECT 'STEP 2: What API functions exist?' as step;

SELECT 
    COALESCE(string_agg(p.proname, ', ' ORDER BY p.proname), 'NO API FUNCTIONS FOUND') as existing_api_functions
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api';

-- Check if api schema exists
SELECT 'STEP 3: Checking if api schema exists' as step;

SELECT 
    CASE 
        WHEN EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'api') 
        THEN 'FOUND: api schema exists'
        ELSE 'ERROR: api schema does NOT exist!'
    END as schema_status;

-- Check what schemas DO exist
SELECT 'STEP 4: What schemas exist?' as step;

SELECT string_agg(nspname, ', ' ORDER BY nspname) as existing_schemas
FROM pg_namespace 
WHERE nspname NOT LIKE 'pg_%' AND nspname != 'information_schema';

-- Test if we can call a simple auth function
SELECT 'STEP 5: Testing basic auth function access' as step;

SELECT 
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'auth' AND p.proname LIKE '%login%'
        ) 
        THEN 'FOUND: Auth functions with "login" in name exist'
        ELSE 'WARNING: No auth functions with "login" found'
    END as auth_function_status;

-- List auth functions that might be related to login
SELECT 'STEP 6: Auth functions containing "login" or "auth"' as step;

SELECT 
    COALESCE(
        string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', E'\n' ORDER BY p.proname), 
        'NO MATCHING FUNCTIONS FOUND'
    ) as auth_login_functions
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'auth' 
AND (p.proname ILIKE '%login%' OR p.proname ILIKE '%auth%');

-- Check recent sessions (simplified)
SELECT 'STEP 7: Recent session count' as step;

SELECT 
    COUNT(*) as total_sessions_last_hour,
    COUNT(CASE WHEN sss.session_status = 'ACTIVE' THEN 1 END) as active_sessions
FROM auth.session_h sh
JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
WHERE sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
AND sss.load_end_date IS NULL;

-- Check if our user exists and is properly set up
SELECT 'STEP 8: User verification' as step;

SELECT 
    COUNT(*) as user_records,
    COUNT(CASE WHEN uas.load_end_date IS NULL THEN 1 END) as active_user_records
FROM auth.user_h uh
JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
WHERE uas.username = 'travisdwoodward72@gmail.com';

-- Summary and next steps
SELECT 'STEP 9: DIAGNOSIS SUMMARY' as step;

SELECT 'Based on the results above, we can determine:' as analysis;
SELECT '1. Whether api.auth_login function exists (most likely it does NOT)' as point1;
SELECT '2. What the correct function name should be' as point2;  
SELECT '3. Whether sessions exist at all' as point3;
SELECT '4. Whether the user is properly configured' as point4;

SELECT 'NEXT STEPS:' as next_steps;
SELECT 'If api.auth_login does not exist, we need to find the correct login function name' as step_a;
SELECT 'Check your PHP logs to see what function is actually being called' as step_b;
SELECT 'Look for functions in auth schema that handle login' as step_c; 