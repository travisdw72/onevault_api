-- ================================================================
-- STEP 2 - CLEAN SECURITY RESULTS (PGADMIN OPTIMIZED)
-- ================================================================
-- Purpose: Test all security scenarios and display clear results
-- Database: the_one_spa_oregon
-- Execute in: pgAdmin - Results will show clearly in Data Output tab
-- ================================================================

-- TEST 1: Valid Login (Should succeed)
SELECT 
    'TEST 1: VALID LOGIN' as test_name,
    'EXPECTED: SUCCESS' as expected_result,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "MySecurePassword123",
        "ip_address": "192.168.1.100",
        "user_agent": "Security Test Suite"
    }'::jsonb) as actual_result;

-- TEST 2: Invalid Password (Should fail)
SELECT 
    'TEST 2: INVALID PASSWORD' as test_name,
    'EXPECTED: FAILED' as expected_result,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "wrongpassword",
        "ip_address": "192.168.1.101",
        "user_agent": "Security Test Suite"
    }'::jsonb) as actual_result;

-- TEST 3: Old Password (Should fail - password was changed)
SELECT 
    'TEST 3: OLD PASSWORD' as test_name,
    'EXPECTED: FAILED' as expected_result,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "secureP@ssw0rd123!",
        "ip_address": "192.168.1.102",
        "user_agent": "Security Test Suite"
    }'::jsonb) as actual_result;

-- TEST 4: Non-existent User (Should fail)
SELECT 
    'TEST 4: NON-EXISTENT USER' as test_name,
    'EXPECTED: FAILED' as expected_result,
    api.auth_login('{
        "username": "hacker@badsite.com",
        "password": "anypassword",
        "ip_address": "192.168.1.103",
        "user_agent": "Security Test Suite"
    }'::jsonb) as actual_result;

-- TEST 5: SQL Injection in Username (Should fail safely)
SELECT 
    'TEST 5: SQL INJECTION USERNAME' as test_name,
    'EXPECTED: BLOCKED' as expected_result,
    api.auth_login('{"username": "admin@test.com'' OR 1=1 --", "password": "password", "ip_address": "192.168.1.104", "user_agent": "Security Test Suite"}'::jsonb) as actual_result;

-- TEST 6: SQL Injection in Password (Should fail safely) 
SELECT 
    'TEST 6: SQL INJECTION PASSWORD' as test_name,
    'EXPECTED: BLOCKED' as expected_result,
    api.auth_login('{"username": "admin@test.com", "password": "'' OR 1=1 --", "ip_address": "192.168.1.105", "user_agent": "Security Test Suite"}'::jsonb) as actual_result;

-- TEST 7: Empty Username (Should fail with validation error)
SELECT 
    'TEST 7: EMPTY USERNAME' as test_name,
    'EXPECTED: VALIDATION ERROR' as expected_result,
    api.auth_login('{"username": "", "password": "password123", "ip_address": "192.168.1.106", "user_agent": "Security Test Suite"}'::jsonb) as actual_result;

-- TEST 8: Empty Password (Should fail with validation error)
SELECT 
    'TEST 8: EMPTY PASSWORD' as test_name,
    'EXPECTED: VALIDATION ERROR' as expected_result,
    api.auth_login('{"username": "test@example.com", "password": "", "ip_address": "192.168.1.107", "user_agent": "Security Test Suite"}'::jsonb) as actual_result;

-- TEST 9: Missing Username (Should fail with parameter error)
SELECT 
    'TEST 9: MISSING USERNAME' as test_name,
    'EXPECTED: PARAMETER ERROR' as expected_result,
    api.auth_login('{"password": "password123", "ip_address": "192.168.1.108", "user_agent": "Security Test Suite"}'::jsonb) as actual_result;

-- TEST 10: Brute Force Attempt 1
SELECT 
    'TEST 10: BRUTE FORCE 1' as test_name,
    'EXPECTED: FAILED' as expected_result,
    api.auth_login('{"username": "travisdwoodward72@gmail.com", "password": "hack1", "ip_address": "192.168.1.200", "user_agent": "Brute Force Bot"}'::jsonb) as actual_result;

-- TEST 11: Brute Force Attempt 2
SELECT 
    'TEST 11: BRUTE FORCE 2' as test_name,
    'EXPECTED: FAILED' as expected_result,
    api.auth_login('{"username": "travisdwoodward72@gmail.com", "password": "hack2", "ip_address": "192.168.1.201", "user_agent": "Brute Force Bot"}'::jsonb) as actual_result;

-- TEST 12: Brute Force Attempt 3
SELECT 
    'TEST 12: BRUTE FORCE 3' as test_name,
    'EXPECTED: FAILED' as expected_result,
    api.auth_login('{"username": "travisdwoodward72@gmail.com", "password": "hack3", "ip_address": "192.168.1.202", "user_agent": "Brute Force Bot"}'::jsonb) as actual_result;

-- VERIFICATION: Check current user status
SELECT 
    'VERIFICATION: USER STATUS' as info_type,
    username,
    account_locked,
    failed_login_attempts,
    last_login_date
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com' 
AND load_end_date IS NULL;

-- VERIFICATION: Check recent login attempts
SELECT 
    'VERIFICATION: LOGIN ATTEMPTS' as info_type,
    'Last 5 minutes' as time_period,
    COUNT(*) as total_attempts
FROM raw.login_attempt_h 
WHERE load_date >= NOW() - INTERVAL '5 minutes';

-- FINAL TEST: Confirm login still works after all tests
SELECT 
    'FINAL CONFIRMATION TEST' as test_name,
    'EXPECTED: SUCCESS' as expected_result,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "MySecurePassword123",
        "ip_address": "192.168.1.199",
        "user_agent": "Final Confirmation Test"
    }'::jsonb) as actual_result; 