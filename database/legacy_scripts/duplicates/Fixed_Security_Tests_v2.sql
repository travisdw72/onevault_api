-- ================================================================
-- CORRECTED SECURITY TESTS FOR ONEVAULT LOGIN SYSTEM v2
-- ================================================================
-- Tests the api.auth_login function with proper parameters
-- Database: the_one_spa_oregon
-- ================================================================

\echo '================================================================'
\echo 'ONEVAULT LOGIN SECURITY TESTS v2 - CORRECTED'
\echo '================================================================'

-- ================================================================
-- TEST 1: VALID LOGIN TEST
-- ================================================================
\echo ''
\echo 'TEST 1: Valid Login Test'
\echo '------------------------'

SELECT 
    'VALID LOGIN' as test_type,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "secureP@ssw0rd123!",
        "ip_address": "192.168.1.100",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- ================================================================
-- TEST 2: INVALID PASSWORD TEST
-- ================================================================
\echo ''
\echo 'TEST 2: Invalid Password Test'
\echo '-----------------------------'

SELECT 
    'INVALID PASSWORD' as test_type,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "wrongpassword",
        "ip_address": "192.168.1.101",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- ================================================================
-- TEST 3: NON-EXISTENT USER TEST
-- ================================================================
\echo ''
\echo 'TEST 3: Non-existent User Test'
\echo '------------------------------'

SELECT 
    'NON-EXISTENT USER' as test_type,
    api.auth_login('{
        "username": "nonexistent@example.com",
        "password": "anypassword",
        "ip_address": "192.168.1.102",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- ================================================================
-- TEST 4: SQL INJECTION ATTEMPTS
-- ================================================================
\echo ''
\echo 'TEST 4: SQL Injection Attempts'
\echo '------------------------------'

-- SQL Injection in username
SELECT 
    'SQL INJECTION - USERNAME' as test_type,
    api.auth_login('{
        "username": "admin@test.com'' OR 1=1 --",
        "password": "password",
        "ip_address": "192.168.1.103",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- SQL Injection in password
SELECT 
    'SQL INJECTION - PASSWORD' as test_type,
    api.auth_login('{
        "username": "admin@test.com",
        "password": "'' OR 1=1 --",
        "ip_address": "192.168.1.104",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- ================================================================
-- TEST 5: EMPTY CREDENTIALS
-- ================================================================
\echo ''
\echo 'TEST 5: Empty Credentials'
\echo '------------------------'

-- Empty username
SELECT 
    'EMPTY USERNAME' as test_type,
    api.auth_login('{
        "username": "",
        "password": "password123",
        "ip_address": "192.168.1.105",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- Empty password
SELECT 
    'EMPTY PASSWORD' as test_type,
    api.auth_login('{
        "username": "admin@test.com",
        "password": "",
        "ip_address": "192.168.1.106",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- ================================================================
-- TEST 6: MALFORMED JSON
-- ================================================================
\echo ''
\echo 'TEST 6: Malformed Parameters'
\echo '---------------------------'

-- Missing required fields
SELECT 
    'MISSING USERNAME' as test_type,
    api.auth_login('{
        "password": "password123",
        "ip_address": "192.168.1.107",
        "user_agent": "Test Security Suite v1.0"
    }'::jsonb) as result;

-- ================================================================
-- TEST 7: BRUTE FORCE SIMULATION
-- ================================================================
\echo ''
\echo 'TEST 7: Brute Force Simulation (10 failed attempts)'
\echo '--------------------------------------------------'

-- Multiple failed login attempts
SELECT 
    'BRUTE FORCE ATTEMPT ' || attempt_num as test_type,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "brute_force_attempt_' || attempt_num || '",
        "ip_address": "192.168.1.200",
        "user_agent": "Brute Force Bot"
    }'::jsonb) as result
FROM generate_series(1, 10) as attempt_num;

-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================
\echo ''
\echo 'VERIFICATION: Checking login attempts logged'
\echo '-------------------------------------------'

SELECT 
    'Login attempts in last 5 minutes' as info,
    COUNT(*) as attempt_count
FROM raw.login_attempt_h 
WHERE load_date >= NOW() - INTERVAL '5 minutes';

\echo ''
\echo 'VERIFICATION: Account lockout status'
\echo '-----------------------------------'

SELECT 
    username,
    account_locked,
    failed_login_attempts,
    last_failed_login
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com' 
AND load_end_date IS NULL;

\echo ''
\echo '================================================================'
\echo 'SECURITY TEST COMPLETED'
\echo '================================================================' 