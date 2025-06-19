-- =============================================
-- investigate_missing_sessions.sql
-- Investigates why session records are missing despite successful logins
-- Based on logs showing LOGIN_SUCCESS but no sessions in database
-- =============================================

-- =============================================
-- SECTION 1: Test Current Login Function
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 1: TESTING CURRENT LOGIN ===';
    RAISE NOTICE 'Testing the exact login call from your logs...';
END $$;

-- Test the exact login call from your logs
SELECT 'TEST: api.auth_login with MyNewSecurePassword123' as test_description;

SELECT api.auth_login(jsonb_build_object(
    'username', 'travisdwoodward72@gmail.com',
    'password', 'MyNewSecurePassword123',
    'ip_address', '192.168.1.100',
    'user_agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    'auto_login', true
)) as login_result;

-- Also test with the other password that was failing
SELECT 'TEST: api.auth_login with SimpleTest123' as test_description;

SELECT api.auth_login(jsonb_build_object(
    'username', 'travisdwoodward72@gmail.com',
    'password', 'SimpleTest123',
    'ip_address', '192.168.1.100',
    'user_agent', 'Mozilla/5.0 Test Browser'
)) as login_result;

-- =============================================
-- SECTION 2: Check Current Password Hash
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 2: CURRENT PASSWORD VERIFICATION ===';
END $$;

-- Check current password hash and details
SELECT 
    'CURRENT PASSWORD INFO' as info_type,
    username,
    length(password_hash) as hash_length,
    convert_from(password_hash, 'UTF8') as hash_text,
    password_last_changed,
    failed_login_attempts,
    account_locked,
    must_change_password,
    load_date,
    load_end_date,
    record_source
FROM auth.user_auth_s
WHERE username = 'travisdwoodward72@gmail.com'
ORDER BY load_date DESC
LIMIT 3;

-- Test password verification manually
DO $$
DECLARE
    v_stored_hash TEXT;
    v_test_password1 TEXT := 'MyNewSecurePassword123';
    v_test_password2 TEXT := 'SimpleTest123';
    v_result1 BOOLEAN;
    v_result2 BOOLEAN;
BEGIN
    RAISE NOTICE '=== MANUAL PASSWORD VERIFICATION ===';
    
    -- Get the current password hash
    SELECT convert_from(password_hash, 'UTF8') INTO v_stored_hash
    FROM auth.user_auth_s
    WHERE username = 'travisdwoodward72@gmail.com'
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;
    
    IF v_stored_hash IS NOT NULL THEN
        RAISE NOTICE 'Stored hash: %', LEFT(v_stored_hash, 20) || '...';
        
        -- Test both passwords
        v_result1 := (crypt(v_test_password1, v_stored_hash) = v_stored_hash);
        v_result2 := (crypt(v_test_password2, v_stored_hash) = v_stored_hash);
        
        RAISE NOTICE 'Password "%" verification: %', v_test_password1, v_result1;
        RAISE NOTICE 'Password "%" verification: %', v_test_password2, v_result2;
    ELSE
        RAISE NOTICE 'ERROR: No password hash found!';
    END IF;
END $$;

-- =============================================
-- SECTION 3: Check All Sessions (Expand Search)
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 3: ALL SESSION RECORDS FOR USER ===';
END $$;

-- Check ALL sessions for this user (not just the timeframe)
SELECT 
    'ALL USER SESSIONS' as session_type,
    sh.session_bk,
    sss.session_start,
    sss.session_end,
    sss.session_status,
    sss.ip_address,
    sss.last_activity,
    sss.load_date,
    sss.load_end_date
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

-- Check sessions from a broader timeframe
SELECT 
    'RECENT SESSIONS (24H)' as session_type,
    COUNT(*) as session_count,
    MIN(sss.session_start) as earliest_session,
    MAX(sss.session_start) as latest_session
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
AND sss.session_start >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
AND sss.load_end_date IS NULL;

-- =============================================
-- SECTION 4: Check if Sessions Are Created But Failed
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 4: FAILED OR INACTIVE SESSIONS ===';
END $$;

-- Check for ANY sessions (including failed/inactive ones)
SELECT 
    'ALL SESSION STATUSES' as check_type,
    sss.session_status,
    COUNT(*) as count,
    MIN(sss.session_start) as earliest,
    MAX(sss.session_start) as latest
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
AND sss.session_start >= '2025-06-05 20:00:00'::TIMESTAMP WITH TIME ZONE
GROUP BY sss.session_status
ORDER BY latest DESC;

-- =============================================
-- SECTION 5: Check API Function Behavior
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 5: API FUNCTION INVESTIGATION ===';
END $$;

-- Check if api.auth_login function exists and its definition
SELECT 
    'API FUNCTION CHECK' as check_type,
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    CASE p.prorettype 
        WHEN 'jsonb'::regtype THEN 'JSONB'
        ELSE pg_catalog.format_type(p.prorettype, NULL)
    END as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api'
AND p.proname = 'auth_login';

-- =============================================
-- SECTION 6: Test Session Creation Manually
-- =============================================

DO $$
DECLARE
    v_user_hk BYTEA;
    v_tenant_hk BYTEA;
    v_session_hk BYTEA;
    v_session_bk VARCHAR(255);
    v_load_date TIMESTAMP WITH TIME ZONE;
BEGIN
    RAISE NOTICE '=== SECTION 6: MANUAL SESSION CREATION TEST ===';
    
    -- Get user and tenant
    SELECT uh.user_hk, uh.tenant_hk INTO v_user_hk, v_tenant_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = 'travisdwoodward72@gmail.com'
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    IF v_user_hk IS NOT NULL THEN
        v_load_date := util.current_load_date();
        v_session_bk := 'MANUAL_TEST_SESSION_' || extract(epoch from v_load_date)::text;
        v_session_hk := util.hash_binary(v_session_bk);
        
        RAISE NOTICE 'Found user - attempting manual session creation...';
        RAISE NOTICE 'User HK: %', encode(v_user_hk, 'hex');
        RAISE NOTICE 'Tenant HK: %', encode(v_tenant_hk, 'hex');
        
        BEGIN
            -- Create session hub
            INSERT INTO auth.session_h (
                session_hk, session_bk, tenant_hk, load_date, record_source
            ) VALUES (
                v_session_hk, v_session_bk, v_tenant_hk, v_load_date, 'MANUAL_TEST'
            );
            
            -- Create session state
            INSERT INTO auth.session_state_s (
                session_hk, load_date, hash_diff, session_start, session_end,
                ip_address, user_agent, session_data, session_status, 
                last_activity, record_source
            ) VALUES (
                v_session_hk, v_load_date, util.hash_binary(v_session_bk || 'TEST'),
                v_load_date, NULL, '192.168.1.100'::INET, 'Manual Test',
                '{}'::JSONB, 'ACTIVE', v_load_date, 'MANUAL_TEST'
            );
            
            -- Create user-session link
            INSERT INTO auth.user_session_l (
                link_user_session_hk, user_hk, session_hk, tenant_hk,
                load_date, record_source
            ) VALUES (
                util.hash_binary(v_user_hk::text || v_session_hk::text),
                v_user_hk, v_session_hk, v_tenant_hk, v_load_date, 'MANUAL_TEST'
            );
            
            RAISE NOTICE 'SUCCESS: Manual session created successfully!';
            RAISE NOTICE 'Session HK: %', encode(v_session_hk, 'hex');
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'ERROR: Manual session creation failed: % - %', SQLSTATE, SQLERRM;
        END;
        
    ELSE
        RAISE NOTICE 'ERROR: User not found for manual session test';
    END IF;
END $$;

-- Final summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== INVESTIGATION SUMMARY ===';
    RAISE NOTICE 'This script will help identify:';
    RAISE NOTICE '1. Whether login function returns success but fails to create sessions';
    RAISE NOTICE '2. Password verification issues';
    RAISE NOTICE '3. Session creation problems';
    RAISE NOTICE '4. Database constraint or permission issues';
    RAISE NOTICE '';
    RAISE NOTICE 'Check the results above to understand why sessions are missing.';
    RAISE NOTICE '';
END $$; 