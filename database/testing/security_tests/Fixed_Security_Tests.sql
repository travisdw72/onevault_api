-- ================================================
-- CORRECTED SECURITY TEST SCRIPTS FOR LOGIN SYSTEM
-- ================================================
-- Purpose: Test authentication system with CORRECT parameter names
-- Based on actual api.auth_login function signature
-- Environment: Development/Staging ONLY
-- Last Updated: December 2024

-- ================================================
-- SECTION 1: CORRECTED SQL INJECTION TESTS
-- ================================================

-- TEST S010: SQL Injection in Email Field (CORRECTED PARAMETERS)
SELECT 'TEST S010-1: Basic SQL Injection (Corrected)' as test_name;
DO $$
DECLARE
    v_result JSONB;
BEGIN
    -- Using CORRECT parameter names: username, password, ip_address, user_agent
    SELECT INTO v_result api.auth_login(jsonb_build_object(
        'username', ''' OR 1=1 --',
        'password', 'any_password',
        'ip_address', '192.168.1.100',
        'user_agent', 'SecurityTest/1.0'
    ));
    
    RAISE NOTICE 'SQL injection test result: %', v_result;
    
    -- Check if injection was blocked
    IF (v_result->>'success')::BOOLEAN THEN
        RAISE NOTICE 'CRITICAL SECURITY ISSUE: SQL injection succeeded!';
    ELSE
        RAISE NOTICE 'SUCCESS: SQL injection properly blocked';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;

-- Test 2: Union-based injection (CORRECTED)
SELECT 'TEST S010-2: Union-based SQL Injection (Corrected)' as test_name;
DO $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT INTO v_result api.auth_login(jsonb_build_object(
        'username', ''' UNION SELECT password_hash FROM auth.user_auth_s --',
        'password', 'any_password',
        'ip_address', '192.168.1.100',
        'user_agent', 'SecurityTest/1.0'
    ));
    
    RAISE NOTICE 'Union injection result: %', v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;

-- Test 3: Boolean-based blind injection (CORRECTED)
SELECT 'TEST S010-3: Boolean-based Injection (Corrected)' as test_name;
DO $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT INTO v_result api.auth_login(jsonb_build_object(
        'username', ''' AND (SELECT COUNT(*) FROM auth.user_h) > 0 --',
        'password', 'any_password',
        'ip_address', '192.168.1.100',
        'user_agent', 'SecurityTest/1.0'
    ));
    
    RAISE NOTICE 'Boolean injection result: %', v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;

-- ================================================
-- SECTION 2: PASSWORD FIELD INJECTION TESTS (CORRECTED)
-- ================================================

SELECT 'TEST S011-1: Password Field SQL Injection (Corrected)' as test_name;
DO $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT INTO v_result api.auth_login(jsonb_build_object(
        'username', 'travisdwoodward72@gmail.com',
        'password', ''' OR 1=1 --',
        'ip_address', '192.168.1.100',
        'user_agent', 'SecurityTest/1.0'
    ));
    
    RAISE NOTICE 'Password injection result: %', v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;

-- ================================================
-- SECTION 3: INPUT VALIDATION TESTS (CORRECTED)
-- ================================================

-- TEST F010: Empty Credentials (CORRECTED)
SELECT 'TEST F010: Empty Credentials Validation (Corrected)' as test_name;
DO $$
DECLARE
    v_result JSONB;
BEGIN
    -- Test empty username
    SELECT INTO v_result api.auth_login(jsonb_build_object(
        'username', '',
        'password', 'password123',
        'ip_address', '192.168.1.100',
        'user_agent', 'SecurityTest/1.0'
    ));
    
    RAISE NOTICE 'Empty username result: %', v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error for empty username: %', SQLERRM;
END $$;

DO $$
DECLARE
    v_result JSONB;
BEGIN
    -- Test empty password
    SELECT INTO v_result api.auth_login(jsonb_build_object(
        'username', 'travisdwoodward72@gmail.com',
        'password', '',
        'ip_address', '192.168.1.100',
        'user_agent', 'SecurityTest/1.0'
    ));
    
    RAISE NOTICE 'Empty password result: %', v_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error for empty password: %', SQLERRM;
END $$;

-- ================================================
-- SECTION 4: VALID LOGIN TEST (CORRECTED)
-- ================================================

SELECT 'TEST: Valid Login with Correct Parameters' as test_name;
DO $$
DECLARE
    v_result JSONB;
BEGIN
    -- Test with known good credentials and CORRECT parameter format
    SELECT INTO v_result api.auth_login(jsonb_build_object(
        'username', 'travisdwoodward72@gmail.com',
        'password', 'secureP@ssw0rd123!',  -- Update this to your actual current password
        'ip_address', '192.168.1.100',
        'user_agent', 'SecurityTest/1.0'
    ));
    
    RAISE NOTICE 'Valid login result: %', v_result;
    
    -- Check if login was successful
    IF (v_result->>'success')::BOOLEAN THEN
        RAISE NOTICE 'SUCCESS: Valid login working correctly';
        RAISE NOTICE 'User data returned: %', v_result->'data'->'user_data';
        RAISE NOTICE 'Roles returned: %', v_result->'data'->'user_data'->'roles';
    ELSE
        RAISE NOTICE 'LOGIN FAILED: %', v_result->>'message';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error during valid login test: %', SQLERRM;
END $$;

-- ================================================
-- SECTION 5: BRUTE FORCE SIMULATION (CORRECTED)
-- ================================================

SELECT 'TEST S001: Brute Force Protection (Corrected)' as test_name;
DO $$
DECLARE
    i INTEGER;
    v_result JSONB;
BEGIN
    RAISE NOTICE 'Starting brute force simulation with correct parameters...';
    
    -- Attempt 10 failed logins (should trigger lockout after 5)
    FOR i IN 1..10 LOOP
        BEGIN
            SELECT INTO v_result api.auth_login(jsonb_build_object(
                'username', 'travisdwoodward72@gmail.com',
                'password', 'wrong_password_' || i,
                'ip_address', '192.168.1.100',
                'user_agent', 'SecurityTest/1.0'
            ));
            
            RAISE NOTICE 'Attempt %: Success = %', i, (v_result->>'success')::BOOLEAN;
            RAISE NOTICE 'Attempt %: Message = %', i, v_result->>'message';
            
            -- Check if account is locked
            IF (v_result->>'message') LIKE '%locked%' OR (v_result->>'error_code') = 'ACCOUNT_LOCKED' THEN
                RAISE NOTICE 'Account locked after % attempts', i;
                EXIT;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Attempt % failed with error: %', i, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE 'Brute force simulation completed';
END $$;

-- ================================================
-- SECTION 6: DATABASE INSPECTION TESTS
-- ================================================

-- Check what audit tables actually exist
SELECT 'DATABASE INSPECTION: Available Tables' as test_name;
DO $$
DECLARE
    v_table_name TEXT;
BEGIN
    RAISE NOTICE 'Checking available audit tables in raw schema:';
    
    FOR v_table_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'raw' 
        AND table_name LIKE '%login%'
        ORDER BY table_name
    LOOP
        RAISE NOTICE 'Found table: raw.%', v_table_name;
    END LOOP;
    
    RAISE NOTICE 'Checking available tables in staging schema:';
    
    FOR v_table_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'staging' 
        AND table_name LIKE '%login%'
        ORDER BY table_name
    LOOP
        RAISE NOTICE 'Found table: staging.%', v_table_name;
    END LOOP;
END $$;

-- Check function signature
SELECT 'DATABASE INSPECTION: Function Signature' as test_name;
DO $$
DECLARE
    v_function_info RECORD;
BEGIN
    RAISE NOTICE 'Checking api.auth_login function signature:';
    
    FOR v_function_info IN
        SELECT 
            p.proname as function_name,
            pg_catalog.pg_get_function_arguments(p.oid) as arguments,
            pg_catalog.pg_get_function_result(p.oid) as return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' 
        AND p.proname = 'auth_login'
    LOOP
        RAISE NOTICE 'Function: %.%(%)', 'api', v_function_info.function_name, v_function_info.arguments;
        RAISE NOTICE 'Returns: %', v_function_info.return_type;
    END LOOP;
END $$;

-- ================================================
-- TEST SUMMARY (CORRECTED)
-- ================================================

SELECT 'CORRECTED SECURITY TEST SUMMARY' as test_phase;
SELECT '=====================================' as separator;
SELECT 'Tests now use CORRECT parameter names:' as instruction;
SELECT '- username (not p_email)' as param1;
SELECT '- password (not p_password)' as param2;
SELECT '- ip_address (not missing)' as param3;
SELECT '- user_agent (not missing)' as param4;
SELECT '' as spacer;
SELECT 'Review output above for:' as check_instruction;
SELECT '1. Valid login should succeed' as check1;
SELECT '2. SQL injection attempts should fail' as check2;
SELECT '3. Empty credentials should be rejected' as check3;
SELECT '4. Brute force protection should activate' as check4;
SELECT '5. Available audit tables should be listed' as check5; 