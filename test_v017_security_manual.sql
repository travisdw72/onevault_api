-- =============================================================================
-- V017 Security Validation Test Script
-- =============================================================================
-- Run this in your database client to test the V017 security fix
-- Expected Results:
--   ✅ Valid tenant authentication should SUCCEED
--   ❌ Cross-tenant attacks should FAIL
--   ✅ Backward compatibility should work
-- =============================================================================

\echo '🔒 V017 SECURITY VALIDATION TEST SUITE'
\echo '======================================'

-- Get test tokens for validation
\echo ''
\echo '📋 Getting Test Tokens...'
SELECT 
    th.tenant_bk as tenant_name,
    SUBSTRING(ats.token_value, 1, 20) || '...' as token_preview,
    ats.token_value as full_token
FROM auth.api_token_s ats
JOIN auth.tenant_h th ON ats.tenant_hk = th.tenant_hk
WHERE ats.load_end_date IS NULL
ORDER BY th.tenant_bk;

-- Store tokens in variables (you'll need to copy these)
\echo ''
\echo '📝 Copy the tokens above for manual testing'
\echo ''

-- =============================================================================
-- TEST 1: Valid Tenant Authentication (SHOULD SUCCEED)
-- =============================================================================
\echo '📋 TEST 1: Valid Tenant Authentication (SHOULD SUCCEED)'
\echo '--------------------------------------------------------'

-- Replace 'YOUR_THEONESPAOREGON_TOKEN_HERE' with actual token from above
SELECT 
    'TEST 1: Valid Authentication' as test_name,
    result.success,
    result.message,
    CASE 
        WHEN result.success = true THEN '✅ PASS - Authentication successful'
        ELSE '❌ FAIL - Should have succeeded'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'Tr@vis123',
        'authorization_token', 'YOUR_THEONESPAOREGON_TOKEN_HERE',  -- Replace with actual token
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test'
    )) as result
) t;

-- =============================================================================
-- TEST 2: Cross-Tenant Attack (SHOULD FAIL)
-- =============================================================================
\echo ''
\echo '📋 TEST 2: Cross-Tenant Attack Prevention (SHOULD FAIL)'
\echo '-------------------------------------------------------'

-- Replace 'YOUR_OTHER_TENANT_TOKEN_HERE' with a different tenant's token
SELECT 
    'TEST 2: Cross-Tenant Attack' as test_name,
    result.success,
    result.message,
    CASE 
        WHEN result.success = false THEN '✅ PASS - Attack blocked'
        ELSE '🚨 FAIL - SECURITY VULNERABILITY!'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'Tr@vis123',
        'authorization_token', 'YOUR_OTHER_TENANT_TOKEN_HERE',  -- Replace with different tenant token
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test-ATTACK'
    )) as result
) t;

-- =============================================================================
-- TEST 3: Invalid API Token (SHOULD FAIL)
-- =============================================================================
\echo ''
\echo '📋 TEST 3: Invalid Token Handling (SHOULD FAIL)'
\echo '-----------------------------------------------'

SELECT 
    'TEST 3: Invalid Token' as test_name,
    result.success,
    result.message,
    CASE 
        WHEN result.success = false THEN '✅ PASS - Invalid token rejected'
        ELSE '❌ FAIL - Should have failed'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'Tr@vis123',
        'authorization_token', 'ovt_invalid_token_123456789',
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test'
    )) as result
) t;

-- =============================================================================
-- TEST 4: Missing API Token (SHOULD FAIL)
-- =============================================================================
\echo ''
\echo '📋 TEST 4: Missing Token Handling (SHOULD FAIL)'
\echo '-----------------------------------------------'

SELECT 
    'TEST 4: Missing Token' as test_name,
    result.success,
    result.message,
    CASE 
        WHEN result.success = false THEN '✅ PASS - Missing token rejected'
        ELSE '❌ FAIL - Should have failed'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'Tr@vis123',
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test'
    )) as result
) t;

-- =============================================================================
-- TEST 5: Backward Compatibility - Token in Body (SHOULD SUCCEED)
-- =============================================================================
\echo ''
\echo '📋 TEST 5: Backward Compatibility (SHOULD SUCCEED)'
\echo '--------------------------------------------------'

-- Replace 'YOUR_THEONESPAOREGON_TOKEN_HERE' with actual token
SELECT 
    'TEST 5: Backward Compatibility' as test_name,
    result.success,
    result.message,
    CASE 
        WHEN result.success = true THEN '✅ PASS - Backward compatibility works'
        ELSE '❌ FAIL - Backward compatibility broken'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'Tr@vis123',
        'api_token', 'YOUR_THEONESPAOREGON_TOKEN_HERE',  -- In body instead of authorization_token
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test'
    )) as result
) t;

-- =============================================================================
-- TEST 6: Wrong Password (SHOULD FAIL)
-- =============================================================================
\echo ''
\echo '📋 TEST 6: Invalid Password (SHOULD FAIL)'
\echo '-----------------------------------------'

-- Replace 'YOUR_THEONESPAOREGON_TOKEN_HERE' with actual token
SELECT 
    'TEST 6: Wrong Password' as test_name,
    result.success,
    result.message,
    CASE 
        WHEN result.success = false THEN '✅ PASS - Wrong password rejected'
        ELSE '❌ FAIL - Should have failed'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'WrongPassword123',
        'authorization_token', 'YOUR_THEONESPAOREGON_TOKEN_HERE',  -- Replace with actual token
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test'
    )) as result
) t;

-- =============================================================================
-- SECURITY AUDIT: Check Recent Authentication Attempts
-- =============================================================================
\echo ''
\echo '📊 Recent Authentication Audit Log'
\echo '----------------------------------'

SELECT 
    'Recent Auth Attempts' as log_type,
    COUNT(*) as total_attempts,
    COUNT(*) FILTER (WHERE record_source = 'AUTH_LOGIN_SECURE') as secure_attempts,
    MAX(load_date) as last_attempt
FROM audit.auth_success_s 
WHERE load_date >= CURRENT_DATE;

SELECT 
    'Recent Auth Failures' as log_type,
    COUNT(*) as total_failures,
    COUNT(*) FILTER (WHERE failure_reason = 'USER_NOT_IN_TENANT') as cross_tenant_blocks,
    COUNT(*) FILTER (WHERE failure_reason = 'INVALID_PASSWORD') as password_failures
FROM audit.auth_failure_s 
WHERE load_date >= CURRENT_DATE;

-- =============================================================================
-- TEST SUMMARY
-- =============================================================================
\echo ''
\echo '🎯 MANUAL TEST INSTRUCTIONS:'
\echo '=============================='
\echo '1. Copy the actual API tokens from the first query'
\echo '2. Replace YOUR_THEONESPAOREGON_TOKEN_HERE with the theonespaoregon token'
\echo '3. Replace YOUR_OTHER_TENANT_TOKEN_HERE with a different tenant token'
\echo '4. Run each test and verify the expected results'
\echo ''
\echo 'EXPECTED RESULTS:'
\echo '✅ TEST 1: Should SUCCEED (valid auth)'
\echo '❌ TEST 2: Should FAIL (cross-tenant blocked)'
\echo '❌ TEST 3: Should FAIL (invalid token)'
\echo '❌ TEST 4: Should FAIL (missing token)'
\echo '✅ TEST 5: Should SUCCEED (backward compatibility)'
\echo '❌ TEST 6: Should FAIL (wrong password)'
\echo ''
\echo '🔒 If TEST 2 succeeds, DO NOT DEPLOY - security vulnerability exists!'
\echo '✅ If all tests pass as expected, V017 is ready for production!' 