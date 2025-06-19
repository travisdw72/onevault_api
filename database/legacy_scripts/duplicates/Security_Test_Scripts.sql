-- ================================================
-- SECURITY TEST SCRIPTS FOR LOGIN SYSTEM
-- ================================================
-- Purpose: Validate authentication system against common attacks
-- Environment: Development/Staging ONLY - NEVER run in production
-- Last Updated: December 2024

-- ================================================
-- SECTION 1: SQL INJECTION TESTS
-- ================================================

-- TEST S010: SQL Injection in Email Field
-- These should ALL FAIL and return proper error messages

-- Test 1: Basic SQL injection attempt
SELECT 'TEST S010-1: Basic SQL Injection' as test_name;
DO $$
BEGIN
    -- This should fail safely
    PERFORM api.auth_login(jsonb_build_object(
        'p_email', ''' OR 1=1 --',
        'p_password', 'any_password',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    RAISE NOTICE 'SQL injection test completed - check for errors above';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;

-- Test 2: Union-based injection
SELECT 'TEST S010-2: Union-based SQL Injection' as test_name;
DO $$
BEGIN
    PERFORM api.auth_login(jsonb_build_object(
        'p_email', ''' UNION SELECT password_hash FROM auth.user_h --',
        'p_password', 'any_password',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    RAISE NOTICE 'Union injection test completed';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;

-- Test 3: Boolean-based blind injection
SELECT 'TEST S010-3: Boolean-based Injection' as test_name;
DO $$
BEGIN
    PERFORM api.auth_login(jsonb_build_object(
        'p_email', ''' AND (SELECT COUNT(*) FROM auth.user_h) > 0 --',
        'p_password', 'any_password',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    RAISE NOTICE 'Boolean injection test completed';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;

-- Test 4: Time-based injection
SELECT 'TEST S010-4: Time-based Injection' as test_name;
DO $$
BEGIN
    PERFORM api.auth_login(jsonb_build_object(
        'p_email', ''' AND (SELECT pg_sleep(5)) --',
        'p_password', 'any_password',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    RAISE NOTICE 'Time-based injection test completed';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;

-- ================================================
-- SECTION 2: PASSWORD FIELD INJECTION TESTS
-- ================================================

-- TEST S011: SQL Injection in Password Field
SELECT 'TEST S011-1: Password Field SQL Injection' as test_name;
DO $$
BEGIN
    PERFORM api.auth_login(jsonb_build_object(
        'p_email', 'travisdwoodward72@gmail.com',
        'p_password', ''' OR 1=1 --',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    RAISE NOTICE 'Password injection test completed';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error caught: %', SQLERRM;
END $$;

-- ================================================
-- SECTION 3: INPUT VALIDATION TESTS
-- ================================================

-- TEST F010: Empty Credentials
SELECT 'TEST F010: Empty Credentials Validation' as test_name;
DO $$
BEGIN
    -- Test empty email
    PERFORM api.auth_login(jsonb_build_object(
        'p_email', '',
        'p_password', 'password123',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    RAISE NOTICE 'Empty email test completed';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error for empty email: %', SQLERRM;
END $$;

DO $$
BEGIN
    -- Test empty password
    PERFORM api.auth_login(jsonb_build_object(
        'p_email', 'travisdwoodward72@gmail.com',
        'p_password', '',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    RAISE NOTICE 'Empty password test completed';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error for empty password: %', SQLERRM;
END $$;

-- TEST F013: Extremely Long Inputs
SELECT 'TEST F013: Long Input Validation' as test_name;
DO $$
DECLARE
    v_long_email TEXT := repeat('a', 1000) || '@example.com';
    v_long_password TEXT := repeat('x', 10000);
BEGIN
    -- Test extremely long email
    PERFORM api.auth_login(jsonb_build_object(
        'p_email', v_long_email,
        'p_password', 'password123',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    RAISE NOTICE 'Long email test completed';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error for long email: %', SQLERRM;
END $$;

DO $$
DECLARE
    v_long_password TEXT := repeat('x', 10000);
BEGIN
    -- Test extremely long password
    PERFORM api.auth_login(jsonb_build_object(
        'p_email', 'travisdwoodward72@gmail.com',
        'p_password', v_long_password,
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    RAISE NOTICE 'Long password test completed';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error for long password: %', SQLERRM;
END $$;

-- ================================================
-- SECTION 4: SPECIAL CHARACTER TESTS
-- ================================================

-- TEST: Special characters in email and password
SELECT 'TEST: Special Character Handling' as test_name;
DO $$
BEGIN
    -- Test special characters that might break parsing
    PERFORM api.auth_login(jsonb_build_object(
        'p_email', 'test''email@example.com',
        'p_password', 'pass''word"123',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    RAISE NOTICE 'Special character test completed';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error with special characters: %', SQLERRM;
END $$;

-- ================================================
-- SECTION 5: BRUTE FORCE SIMULATION
-- ================================================

-- TEST S001: Enhanced Brute Force Testing
SELECT 'TEST S001: Brute Force Protection Validation' as test_name;
DO $$
DECLARE
    i INTEGER;
    v_result JSONB;
BEGIN
    RAISE NOTICE 'Starting brute force simulation...';
    
    -- Attempt 10 failed logins (should trigger lockout after 5)
    FOR i IN 1..10 LOOP
        BEGIN
            SELECT INTO v_result api.auth_login(jsonb_build_object(
                'p_email', 'travisdwoodward72@gmail.com',
                'p_password', 'wrong_password_' || i,
                'p_tenant_id', '00000000-0000-0000-0000-000000000001'
            ));
            
            RAISE NOTICE 'Attempt %: Success = %', i, (v_result->>'p_success')::BOOLEAN;
            
            -- Check if account is locked
            IF (v_result->>'p_message') LIKE '%locked%' THEN
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
-- SECTION 6: SESSION TOKEN TESTS
-- ================================================

-- TEST S004: Token Validation Tests
SELECT 'TEST S004: Session Token Security' as test_name;

-- First, get a valid token
DO $$
DECLARE
    v_login_result JSONB;
    v_token TEXT;
BEGIN
    -- Get a valid login token
    SELECT INTO v_login_result api.auth_login(jsonb_build_object(
        'p_email', 'travisdwoodward72@gmail.com',
        'p_password', 'secureP@ssw0rd123!',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    
    IF (v_login_result->>'p_success')::BOOLEAN THEN
        v_token := v_login_result->>'p_session_token';
        RAISE NOTICE 'Valid token obtained: %', LEFT(v_token, 20) || '...';
        
        -- Store token for further tests (in a real scenario)
        -- For now, just verify it exists
        IF LENGTH(v_token) > 0 THEN
            RAISE NOTICE 'Token validation: PASS - Token generated';
        ELSE
            RAISE NOTICE 'Token validation: FAIL - No token generated';
        END IF;
    ELSE
        RAISE NOTICE 'Failed to get valid token: %', v_login_result->>'p_message';
    END IF;
END $$;

-- ================================================
-- SECTION 7: TENANT ISOLATION TESTS
-- ================================================

-- TEST F003: Enhanced Tenant Isolation
SELECT 'TEST F003: Tenant Isolation Validation' as test_name;
DO $$
DECLARE
    v_result1 JSONB;
    v_result2 JSONB;
    v_fake_tenant_id UUID := '99999999-9999-9999-9999-999999999999';
BEGIN
    -- Test with real tenant
    SELECT INTO v_result1 api.auth_login(jsonb_build_object(
        'p_email', 'travisdwoodward72@gmail.com',
        'p_password', 'secureP@ssw0rd123!',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    
    -- Test with fake tenant (should fail)
    SELECT INTO v_result2 api.auth_login(jsonb_build_object(
        'p_email', 'travisdwoodward72@gmail.com',
        'p_password', 'secureP@ssw0rd123!',
        'p_tenant_id', v_fake_tenant_id
    ));
    
    RAISE NOTICE 'Real tenant login: %', (v_result1->>'p_success')::BOOLEAN;
    RAISE NOTICE 'Fake tenant login: %', (v_result2->>'p_success')::BOOLEAN;
    
    IF (v_result1->>'p_success')::BOOLEAN AND NOT (v_result2->>'p_success')::BOOLEAN THEN
        RAISE NOTICE 'Tenant isolation: PASS';
    ELSE
        RAISE NOTICE 'Tenant isolation: FAIL - Security issue detected!';
    END IF;
END $$;

-- ================================================
-- SECTION 8: DATA VAULT AUDIT VALIDATION
-- ================================================

-- TEST C001: Audit Trail Completeness
SELECT 'TEST C001: Audit Trail Validation' as test_name;
DO $$
DECLARE
    v_audit_count_before INTEGER;
    v_audit_count_after INTEGER;
    v_login_result JSONB;
BEGIN
    -- Count audit records before
    SELECT COUNT(*) INTO v_audit_count_before FROM raw.login_attempt_l;
    
    -- Perform login
    SELECT INTO v_login_result api.auth_login(jsonb_build_object(
        'p_email', 'travisdwoodward72@gmail.com',
        'p_password', 'secureP@ssw0rd123!',
        'p_tenant_id', '00000000-0000-0000-0000-000000000001'
    ));
    
    -- Count audit records after
    SELECT COUNT(*) INTO v_audit_count_after FROM raw.login_attempt_l;
    
    IF v_audit_count_after > v_audit_count_before THEN
        RAISE NOTICE 'Audit trail: PASS - Login recorded (% -> % records)', 
                     v_audit_count_before, v_audit_count_after;
    ELSE
        RAISE NOTICE 'Audit trail: FAIL - Login not recorded';
    END IF;
END $$;

-- ================================================
-- SECTION 9: ERROR HANDLING TESTS
-- ================================================

-- TEST: Database connection simulation (would need special setup)
SELECT 'TEST: Error Handling Validation' as test_name;
DO $$
BEGIN
    -- Test with malformed JSON (should be caught by input validation)
    BEGIN
        PERFORM api.auth_login('{"invalid_json":}');
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Malformed JSON handled: %', SQLERRM;
    END;
    
    -- Test with missing required fields
    BEGIN
        PERFORM api.auth_login(jsonb_build_object('p_email', 'test@example.com'));
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Missing fields handled: %', SQLERRM;
    END;
END $$;

-- ================================================
-- SECTION 10: PERFORMANCE BASELINE TEST
-- ================================================

-- TEST P001: Basic Performance Test
SELECT 'TEST P001: Performance Baseline' as test_name;
DO $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
    v_result JSONB;
    i INTEGER;
BEGIN
    v_start_time := clock_timestamp();
    
    -- Perform 10 login attempts to get baseline performance
    FOR i IN 1..10 LOOP
        SELECT INTO v_result api.auth_login(jsonb_build_object(
            'p_email', 'travisdwoodward72@gmail.com',
            'p_password', 'secureP@ssw0rd123!',
            'p_tenant_id', '00000000-0000-0000-0000-000000000001'
        ));
    END LOOP;
    
    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;
    
    RAISE NOTICE 'Performance test: 10 logins in %', v_duration;
    RAISE NOTICE 'Average per login: %', v_duration / 10;
    
    IF (EXTRACT(EPOCH FROM v_duration) / 10) < 1.0 THEN
        RAISE NOTICE 'Performance: PASS - Under 1 second per login';
    ELSE
        RAISE NOTICE 'Performance: FAIL - Over 1 second per login';
    END IF;
END $$;

-- ================================================
-- TEST SUMMARY
-- ================================================

SELECT 'SECURITY TEST SUMMARY' as test_phase;
SELECT '===================' as separator;
SELECT 'All security tests completed. Review output above for:' as instruction;
SELECT '1. SQL injection attempts (should all fail safely)' as check1;
SELECT '2. Input validation (should catch malformed data)' as check2;
SELECT '3. Brute force protection (should lock after 5 attempts)' as check3;
SELECT '4. Tenant isolation (should block cross-tenant access)' as check4;
SELECT '5. Audit trail (should log all attempts)' as check5;
SELECT '6. Performance baseline (should be under 1 second)' as check6;
SELECT '' as spacer;
SELECT 'CRITICAL: Any test showing unexpected success indicates a security vulnerability!' as warning; 