-- =============================================
-- audit_log_analysis_script.sql
-- Script to analyze Apache/PHP logs and verify corresponding database records
-- Checks auth tables, audit tables, and identifies missing records
-- Created for debugging audit logging issues
-- =============================================

-- Set up analysis variables from the logs
DO $$
DECLARE
    v_analysis_start_time TIMESTAMP WITH TIME ZONE := '2025-06-05 22:15:00'::TIMESTAMP WITH TIME ZONE;
    v_analysis_end_time TIMESTAMP WITH TIME ZONE := '2025-06-06 08:00:00'::TIMESTAMP WITH TIME ZONE;
    v_target_username TEXT := 'travisdwoodward72@gmail.com';
    v_target_ip INET := '192.168.1.100';
    v_target_user_id TEXT := 'a32283f802c79d2b224576c9583583a2b4d4feb27d1373eaa78786cad08757cb';
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== AUDIT LOG ANALYSIS FOR TIMEFRAME ===';
    RAISE NOTICE 'Analysis Period: % to %', v_analysis_start_time, v_analysis_end_time;
    RAISE NOTICE 'Target Username: %', v_target_username;
    RAISE NOTICE 'Target IP: %', v_target_ip;
    RAISE NOTICE 'Target User ID: %', v_target_user_id;
    RAISE NOTICE '';
END $$;

-- =============================================
-- SECTION 1: CHECK USER AUTHENTICATION RECORDS
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 1: USER AUTHENTICATION RECORDS ===';
END $$;

-- Check if user exists in auth system
SELECT 
    '1.1 USER EXISTENCE CHECK' as check_type,
    uh.user_hk,
    uh.user_bk,
    uh.tenant_hk,
    uas.username,
    uas.load_date,
    uas.load_end_date,
    uas.last_login_date,
    uas.failed_login_attempts,
    uas.account_locked,
    uas.password_last_changed
FROM auth.user_h uh
JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
WHERE uas.username = 'travisdwoodward72@gmail.com'
ORDER BY uas.load_date DESC;

-- Check recent password changes
SELECT 
    '1.2 RECENT PASSWORD CHANGES' as check_type,
    uas.load_date,
    uas.password_last_changed,
    uas.must_change_password,
    uas.failed_login_attempts,
    uas.record_source,
    CASE 
        WHEN uas.load_date >= '2025-06-05 22:15:00'::TIMESTAMP WITH TIME ZONE 
        AND uas.load_date <= '2025-06-06 08:00:00'::TIMESTAMP WITH TIME ZONE 
        THEN 'WITHIN_LOG_TIMEFRAME'
        ELSE 'OUTSIDE_TIMEFRAME'
    END as timeframe_match
FROM auth.user_h uh
JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
WHERE uas.username = 'travisdwoodward72@gmail.com'
AND uas.load_date >= '2025-06-05 20:00:00'::TIMESTAMP WITH TIME ZONE
ORDER BY uas.load_date DESC;

-- =============================================
-- SECTION 2: CHECK SESSION MANAGEMENT RECORDS
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 2: SESSION MANAGEMENT RECORDS ===';
END $$;

-- Check for session records during the timeframe
SELECT 
    '2.1 SESSION RECORDS' as check_type,
    sh.session_bk,
    sss.ip_address,
    sss.user_agent,
    sss.session_start,
    sss.last_activity,
    sss.session_status,
    sss.session_end,
    CASE 
        WHEN sss.session_start >= '2025-06-05 22:15:00'::TIMESTAMP WITH TIME ZONE 
        AND sss.session_start <= '2025-06-06 08:00:00'::TIMESTAMP WITH TIME ZONE 
        THEN 'WITHIN_LOG_TIMEFRAME'
        ELSE 'OUTSIDE_TIMEFRAME'
    END as timeframe_match
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
AND sss.load_end_date IS NULL
ORDER BY sss.session_start DESC;

-- =============================================
-- SECTION 3: CHECK AUDIT SYSTEM TABLES
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 3: AUDIT SYSTEM RECORDS ===';
END $$;

-- Check if audit schema and tables exist
SELECT 
    '3.1 AUDIT SCHEMA CHECK' as check_type,
    schemaname as schema_name,
    tablename as table_name,
    tableowner
FROM pg_tables 
WHERE schemaname = 'audit'
ORDER BY tablename;

-- Check audit events during timeframe (if audit tables exist)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'audit' AND tablename = 'audit_event_h') THEN
        PERFORM 1; -- Table exists, we can query it
    ELSE
        RAISE NOTICE 'AUDIT TABLES DO NOT EXIST - This explains the audit logging failures!';
    END IF;
END $$;

-- Conditional audit event check
SELECT 
    '3.2 AUDIT EVENTS' as check_type,
    aeh.audit_event_bk,
    aeh.load_date,
    ads.operation,
    ads.changed_by,
    ads.table_name,
    ads.old_data,
    ads.new_data,
    CASE 
        WHEN aeh.load_date >= '2025-06-05 22:15:00'::TIMESTAMP WITH TIME ZONE 
        AND aeh.load_date <= '2025-06-06 08:00:00'::TIMESTAMP WITH TIME ZONE 
        THEN 'WITHIN_LOG_TIMEFRAME'
        ELSE 'OUTSIDE_TIMEFRAME'
    END as timeframe_match
FROM audit.audit_event_h aeh
LEFT JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
WHERE aeh.load_date >= '2025-06-05 20:00:00'::TIMESTAMP WITH TIME ZONE
AND (
    ads.changed_by = 'travisdwoodward72@gmail.com'
    OR ads.old_data::text LIKE '%travisdwoodward72@gmail.com%'
    OR ads.new_data::text LIKE '%travisdwoodward72@gmail.com%'
)
ORDER BY aeh.load_date DESC;

-- =============================================
-- SECTION 4: CHECK UTIL FUNCTIONS
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 4: UTILITY FUNCTIONS CHECK ===';
END $$;

-- Check if util.log_audit_event function exists (this is causing the errors)
SELECT 
    '4.1 UTIL FUNCTION CHECK' as check_type,
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    CASE p.provolatile
        WHEN 'i' THEN 'IMMUTABLE'
        WHEN 's' THEN 'STABLE'
        WHEN 'v' THEN 'VOLATILE'
    END as volatility
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'util'
AND p.proname LIKE '%audit%'
ORDER BY p.proname;

-- Check what util functions DO exist
SELECT 
    '4.2 EXISTING UTIL FUNCTIONS' as check_type,
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'util'
ORDER BY p.proname;

-- =============================================
-- SECTION 5: ANALYZE LOG EVENTS VS DATABASE RECORDS
-- =============================================

DO $$
DECLARE
    rec RECORD;
    v_username TEXT := 'travisdwoodward72@gmail.com';
    v_user_exists BOOLEAN := FALSE;
    v_recent_logins INTEGER := 0;
    v_audit_tables_exist BOOLEAN := FALSE;
    v_util_function_exists BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '=== SECTION 5: LOG ANALYSIS SUMMARY ===';
    
    -- Check if user exists
    SELECT COUNT(*) > 0 INTO v_user_exists
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_username
    AND uas.load_end_date IS NULL;
    
    -- Count recent login attempts
    SELECT COUNT(*) INTO v_recent_logins
    FROM auth.user_h uh
    JOIN auth.user_session_l usl ON uh.user_hk = usl.user_hk
    JOIN auth.session_h sh ON usl.session_hk = sh.session_hk
    JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
    WHERE uh.user_bk = (
        SELECT user_bk FROM auth.user_h uh2 
        JOIN auth.user_auth_s uas2 ON uh2.user_hk = uas2.user_hk 
        WHERE uas2.username = v_username 
        AND uas2.load_end_date IS NULL
        LIMIT 1
    )
    AND sss.session_start >= '2025-06-05 22:15:00'::TIMESTAMP WITH TIME ZONE
    AND sss.load_end_date IS NULL;
    
    -- Check if audit tables exist
    SELECT COUNT(*) > 0 INTO v_audit_tables_exist
    FROM pg_tables 
    WHERE schemaname = 'audit';
    
    -- Check if util.log_audit_event exists
    SELECT COUNT(*) > 0 INTO v_util_function_exists
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'util'
    AND p.proname = 'log_audit_event';
    
    RAISE NOTICE '';
    RAISE NOTICE 'ANALYSIS RESULTS:';
    RAISE NOTICE '- User exists in auth system: %', v_user_exists;
    RAISE NOTICE '- Recent login sessions found: %', v_recent_logins;
    RAISE NOTICE '- Audit tables exist: %', v_audit_tables_exist;
    RAISE NOTICE '- util.log_audit_event function exists: %', v_util_function_exists;
    RAISE NOTICE '';
    
    IF NOT v_audit_tables_exist THEN
        RAISE NOTICE 'CRITICAL: Audit tables are missing! This explains the "Audit DB Error" messages.';
    END IF;
    
    IF NOT v_util_function_exists THEN
        RAISE NOTICE 'CRITICAL: util.log_audit_event function is missing! This is causing the SQL errors.';
    END IF;
    
    IF v_recent_logins = 0 THEN
        RAISE NOTICE 'WARNING: No successful login sessions found in timeframe, but logs show attempts.';
    END IF;
END $$;

-- =============================================
-- SECTION 6: SPECIFIC LOG EVENT MAPPING
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 6: SPECIFIC LOG EVENT MAPPING ===';
    RAISE NOTICE '';
    RAISE NOTICE 'LOG EVENTS IDENTIFIED:';
    RAISE NOTICE '1. Thu Jun 05 22:15:56 - LOGIN_ATTEMPT -> travisdwoodward72@gmail.com';
    RAISE NOTICE '2. Thu Jun 05 22:15:57 - api.auth_login with password MyNewSecurePassword123';
    RAISE NOTICE '3. Thu Jun 05 22:15:57 - LOGIN_SUCCESS with user_id a32283f...';
    RAISE NOTICE '4. Thu Jun 05 22:16:16 - PASSWORD_CHANGE_ATTEMPT for unknown@domain.com';
    RAISE NOTICE '5. Thu Jun 05 22:16:16 - PASSWORD_CHANGE_FAILED';
    RAISE NOTICE '6. Multiple LOGIN_FAILED events with SimpleTest123 password';
    RAISE NOTICE '7. Fri Jun 06 07:41:27 - LOGIN_ATTEMPT with SimpleTest12 (typo)';
    RAISE NOTICE '';
    RAISE NOTICE 'ERROR PATTERN: "function util.log_audit_event(...) does not exist"';
    RAISE NOTICE 'This indicates the audit logging system is not properly set up.';
    RAISE NOTICE '';
END $$;

-- =============================================
-- SECTION 7: RECOMMENDATIONS
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 7: RECOMMENDATIONS ===';
    RAISE NOTICE '';
    RAISE NOTICE 'IMMEDIATE ACTIONS NEEDED:';
    RAISE NOTICE '1. Create the missing util.log_audit_event function';
    RAISE NOTICE '2. Ensure audit schema and tables are properly created';
    RAISE NOTICE '3. Fix the password verification logic (multiple failed attempts with correct password)';
    RAISE NOTICE '4. Investigate why "unknown@domain.com" appears in password change logs';
    RAISE NOTICE '5. Check if MyNewSecurePassword123 vs SimpleTest123 password discrepancy';
    RAISE NOTICE '';
    RAISE NOTICE 'MISSING FUNCTIONS TO CREATE:';
    RAISE NOTICE '- util.log_audit_event(text, text, text, text, jsonb)';
    RAISE NOTICE '- Proper audit table structure in audit schema';
    RAISE NOTICE '';
    RAISE NOTICE 'INVESTIGATION AREAS:';
    RAISE NOTICE '- Why successful login shows but subsequent attempts fail with same user';
    RAISE NOTICE '- Password hash storage/verification issues';
    RAISE NOTICE '- Audit logging integration with PHP application';
    RAISE NOTICE '';
END $$;

-- =============================================
-- SECTION 8: QUICK FIXES TO TEST
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=== SECTION 8: QUICK TEST QUERIES ===';
    RAISE NOTICE '';
    RAISE NOTICE 'Run these queries to test current state:';
    RAISE NOTICE '';
    RAISE NOTICE '-- Test current password:';
    RAISE NOTICE 'SELECT api.auth_login(jsonb_build_object(';
    RAISE NOTICE '    ''username'', ''travisdwoodward72@gmail.com'',';
    RAISE NOTICE '    ''password'', ''MyNewSecurePassword123'',';
    RAISE NOTICE '    ''ip_address'', ''192.168.1.100'',';
    RAISE NOTICE '    ''user_agent'', ''test''';
    RAISE NOTICE '));';
    RAISE NOTICE '';
    RAISE NOTICE '-- Check current password hash:';
    RAISE NOTICE 'SELECT username, password_hash, convert_from(password_hash, ''UTF8'') as hash_text';
    RAISE NOTICE 'FROM auth.user_auth_s';
    RAISE NOTICE 'WHERE username = ''travisdwoodward72@gmail.com''';
    RAISE NOTICE 'AND load_end_date IS NULL;';
    RAISE NOTICE '';
END $$;

-- Final summary
SELECT 
    'ANALYSIS COMPLETE' as status,
    CURRENT_TIMESTAMP as analysis_time,
    'Check the notices above for detailed findings' as next_steps; 