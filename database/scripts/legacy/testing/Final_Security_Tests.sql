-- ================================================================
-- FINAL SECURITY TESTS FOR ONEVAULT LOGIN SYSTEM
-- ================================================================
-- Tests the api.auth_login function with proper parameters
-- Database: the_one_spa_oregon
-- Updated with correct password: MySecurePassword123
-- PGADMIN COMPATIBLE VERSION
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'ONEVAULT LOGIN SECURITY TESTS - FINAL (UPDATED PASSWORD)';
    RAISE NOTICE '================================================================';
END $$;

-- ================================================================
-- TEST 1: VALID LOGIN TEST (UPDATED PASSWORD)
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 1: Valid Login Test (With Correct Password)';
    RAISE NOTICE '------------------------------------------------';
END $$;

SELECT 
    'VALID LOGIN' as test_type,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "MySecurePassword123",
        "ip_address": "192.168.1.100",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- ================================================================
-- TEST 2: INVALID PASSWORD TEST
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 2: Invalid Password Test';
    RAISE NOTICE '-----------------------------';
END $$;

SELECT 
    'INVALID PASSWORD' as test_type,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "wrongpassword",
        "ip_address": "192.168.1.101",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- ================================================================
-- TEST 3: OLD PASSWORD TEST (Should fail)
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 3: Old Password Test (Should fail now)';
    RAISE NOTICE '-------------------------------------------';
END $$;

SELECT 
    'OLD PASSWORD' as test_type,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "secureP@ssw0rd123!",
        "ip_address": "192.168.1.102",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- ================================================================
-- TEST 4: NON-EXISTENT USER TEST
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 4: Non-existent User Test';
    RAISE NOTICE '------------------------------';
END $$;

SELECT 
    'NON-EXISTENT USER' as test_type,
    api.auth_login('{
        "username": "nonexistent@example.com",
        "password": "anypassword",
        "ip_address": "192.168.1.103",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- ================================================================
-- TEST 5: SQL INJECTION ATTEMPTS
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 5: SQL Injection Attempts';
    RAISE NOTICE '------------------------------';
END $$;

-- SQL Injection in username
SELECT 
    'SQL INJECTION - USERNAME' as test_type,
    api.auth_login('{"username": "admin@test.com'' OR 1=1 --", "password": "password", "ip_address": "192.168.1.104", "user_agent": "Test Security Suite v1.0"}'::jsonb) as result;

-- SQL Injection in password
SELECT 
    'SQL INJECTION - PASSWORD' as test_type,
    api.auth_login('{"username": "admin@test.com", "password": "'' OR 1=1 --", "ip_address": "192.168.1.105", "user_agent": "Test Security Suite v1.0"}'::jsonb) as result;

-- ================================================================
-- TEST 6: EMPTY CREDENTIALS
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 6: Empty Credentials';
    RAISE NOTICE '------------------------';
END $$;

-- Empty username
SELECT 
    'EMPTY USERNAME' as test_type,
    api.auth_login('{"username": "", "password": "password123", "ip_address": "192.168.1.106", "user_agent": "Test Security Suite v1.0"}'::jsonb) as result;

-- Empty password
SELECT 
    'EMPTY PASSWORD' as test_type,
    api.auth_login('{"username": "admin@test.com", "password": "", "ip_address": "192.168.1.107", "user_agent": "Test Security Suite v1.0"}'::jsonb) as result;

-- ================================================================
-- TEST 7: MALFORMED JSON
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 7: Malformed Parameters';
    RAISE NOTICE '---------------------------';
END $$;

-- Missing required fields
SELECT 
    'MISSING USERNAME' as test_type,
    api.auth_login('{"password": "password123", "ip_address": "192.168.1.108", "user_agent": "Test Security Suite v1.0"}'::jsonb) as result;

-- ================================================================
-- TEST 8: BRUTE FORCE SIMULATION (With wrong password)
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 8: Brute Force Simulation (Individual attempts)';
    RAISE NOTICE '--------------------------------------------------';
END $$;

SELECT 'BRUTE FORCE 1' as test_type, api.auth_login('{"username": "travisdwoodward72@gmail.com", "password": "brute1", "ip_address": "192.168.1.200", "user_agent": "Brute Force Bot"}'::jsonb) as result;
SELECT 'BRUTE FORCE 2' as test_type, api.auth_login('{"username": "travisdwoodward72@gmail.com", "password": "brute2", "ip_address": "192.168.1.200", "user_agent": "Brute Force Bot"}'::jsonb) as result;
SELECT 'BRUTE FORCE 3' as test_type, api.auth_login('{"username": "travisdwoodward72@gmail.com", "password": "brute3", "ip_address": "192.168.1.200", "user_agent": "Brute Force Bot"}'::jsonb) as result;
SELECT 'BRUTE FORCE 4' as test_type, api.auth_login('{"username": "travisdwoodward72@gmail.com", "password": "brute4", "ip_address": "192.168.1.200", "user_agent": "Brute Force Bot"}'::jsonb) as result;
SELECT 'BRUTE FORCE 5' as test_type, api.auth_login('{"username": "travisdwoodward72@gmail.com", "password": "brute5", "ip_address": "192.168.1.200", "user_agent": "Brute Force Bot"}'::jsonb) as result;

-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'VERIFICATION: Checking login attempts logged';
    RAISE NOTICE '-------------------------------------------';
END $$;

SELECT 
    'Login attempts in last 5 minutes' as info,
    COUNT(*) as attempt_count
FROM raw.login_attempt_h 
WHERE load_date >= NOW() - INTERVAL '5 minutes';

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'VERIFICATION: Account lockout status';
    RAISE NOTICE '-----------------------------------';
END $$;

SELECT 
    username,
    account_locked,
    failed_login_attempts
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com' 
AND load_end_date IS NULL;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'VERIFICATION: Recent login attempts (simplified)';
    RAISE NOTICE '----------------------------------------------';
END $$;

-- FIXED: Simplified query without username column
SELECT 
    'Recent login attempts' as info,
    COUNT(*) as total_attempts,
    MIN(load_date) as first_attempt,
    MAX(load_date) as last_attempt
FROM raw.login_attempt_h 
WHERE load_date >= NOW() - INTERVAL '5 minutes';

-- ================================================================
-- FINAL SUCCESSFUL LOGIN TEST
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'FINAL TEST: Confirm Working Login';
    RAISE NOTICE '=================================';
END $$;

SELECT 
    'FINAL WORKING LOGIN' as test_type,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "MySecurePassword123",
        "ip_address": "192.168.1.199",
        "user_agent": "Final Success Test"
    }'::jsonb) as result;

-- ================================================================
-- SUMMARY
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'SECURITY TEST COMPLETED - UPDATED WITH CORRECT PASSWORD';
    RAISE NOTICE 'EXPECTED RESULTS:';
    RAISE NOTICE '- TEST 1 (Valid Login): SUCCESS with session token';
    RAISE NOTICE '- TEST 2 (Invalid Password): FAILED properly';
    RAISE NOTICE '- TEST 3 (Old Password): FAILED (password was changed)';
    RAISE NOTICE '- All other invalid attempts: FAILED properly';
    RAISE NOTICE '- SQL injection attempts: BLOCKED';
    RAISE NOTICE '- Input validation: WORKING';
    RAISE NOTICE '- Final test: SUCCESS';
    RAISE NOTICE '================================================================';
END $$; 