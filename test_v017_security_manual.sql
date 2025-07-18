-- =============================================================================
-- V017 Security Validation Test Script - pgAdmin Compatible
-- =============================================================================
-- Run this in pgAdmin to test the V017 security fix
-- Expected Results:
--   ✅ Valid tenant authentication should SUCCEED
--   ❌ Cross-tenant attacks should FAIL
--   ✅ Backward compatibility should work
-- 
-- INSTRUCTIONS: Run each section individually in pgAdmin
-- =============================================================================

-- 🔒 V017 SECURITY VALIDATION TEST SUITE
-- ======================================

-- STEP 1: Get test tokens for validation
-- 📋 Getting Test Tokens...
-- Copy the full_token values from this query for use in the tests below

SELECT 
    th.tenant_bk as tenant_name,
    SUBSTRING(ats.token_value, 1, 20) || '...' as token_preview,
    ats.token_value as full_token
FROM auth.api_token_s ats
JOIN auth.tenant_h th ON ats.tenant_hk = th.tenant_hk
WHERE ats.load_end_date IS NULL
ORDER BY th.tenant_bk;

-- 📝 COPY THE TOKENS ABOVE BEFORE PROCEEDING
-- Replace the placeholder tokens in the tests below with actual values

-- =============================================================================
-- TEST 1: Valid Tenant Authentication (SHOULD SUCCEED)
-- =============================================================================
-- 📋 TEST 1: Valid Tenant Authentication (SHOULD SUCCEED)
-- Replace 'YOUR_THEONESPAOREGON_TOKEN_HERE' with the actual theonespaoregon token

SELECT 
    'TEST 1: Valid Authentication' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = true THEN '✅ PASS - Authentication successful'
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
-- TEST 2: Cross-Tenant Attack (SHOULD FAIL) - CRITICAL SECURITY TEST
-- =============================================================================
-- 📋 TEST 2: Cross-Tenant Attack Prevention (SHOULD FAIL)
-- Replace 'YOUR_OTHER_TENANT_TOKEN_HERE' with a DIFFERENT tenant's token
-- 🚨 THIS MUST FAIL - If it succeeds, DO NOT DEPLOY TO PRODUCTION!

SELECT 
    'TEST 2: Cross-Tenant Attack' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = false THEN '✅ PASS - Attack blocked'
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
-- 📋 TEST 3: Invalid Token Handling (SHOULD FAIL)

SELECT 
    'TEST 3: Invalid Token' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = false THEN '✅ PASS - Invalid token rejected'
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
-- 📋 TEST 4: Missing Token Handling (SHOULD FAIL)

SELECT 
    'TEST 4: Missing Token' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = false THEN '✅ PASS - Missing token rejected'
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
-- 📋 TEST 5: Backward Compatibility (SHOULD SUCCEED)
-- Replace 'YOUR_THEONESPAOREGON_TOKEN_HERE' with the actual theonespaoregon token

SELECT 
    'TEST 5: Backward Compatibility' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = true THEN '✅ PASS - Backward compatibility works'
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
-- 📋 TEST 6: Invalid Password (SHOULD FAIL)
-- Replace 'YOUR_THEONESPAOREGON_TOKEN_HERE' with the actual theonespaoregon token

SELECT 
    'TEST 6: Wrong Password' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = false THEN '✅ PASS - Wrong password rejected'
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
-- 📊 Recent Authentication Audit Log

-- Check successful authentications
SELECT 
    'Recent Auth Attempts' as log_type,
    COUNT(*) as total_attempts,
    COUNT(*) FILTER (WHERE record_source = 'AUTH_LOGIN_SECURE') as secure_attempts,
    MAX(load_date) as last_attempt
FROM audit.auth_success_s 
WHERE load_date >= CURRENT_DATE;

-- Check failed attempts (should include blocked cross-tenant attacks)
SELECT 
    'Recent Auth Failures' as log_type,
    COUNT(*) as total_failures,
    COUNT(*) FILTER (WHERE failure_reason = 'USER_NOT_IN_TENANT') as cross_tenant_blocks,
    COUNT(*) FILTER (WHERE failure_reason = 'INVALID_PASSWORD') as password_failures
FROM audit.auth_failure_s 
WHERE load_date >= CURRENT_DATE;

-- =============================================================================
-- 🎯 MANUAL TEST INSTRUCTIONS FOR pgAdmin:
-- =============================================================================
-- 
-- 1. Run the first query to get API tokens
-- 2. Copy the 'full_token' values from the results
-- 3. Replace 'YOUR_THEONESPAOREGON_TOKEN_HERE' with the theonespaoregon token
-- 4. Replace 'YOUR_OTHER_TENANT_TOKEN_HERE' with a different tenant's token
-- 5. Run each test individually and verify the expected results
-- 
-- EXPECTED RESULTS:
-- ✅ TEST 1: Should SUCCEED (valid auth)
-- ❌ TEST 2: Should FAIL (cross-tenant blocked) - CRITICAL!
-- ❌ TEST 3: Should FAIL (invalid token)
-- ❌ TEST 4: Should FAIL (missing token)
-- ✅ TEST 5: Should SUCCEED (backward compatibility)
-- ❌ TEST 6: Should FAIL (wrong password)
-- 
-- 🔒 CRITICAL: If TEST 2 shows success=true, DO NOT DEPLOY - security vulnerability exists!
-- ✅ If all tests pass as expected, V017 is ready for production! 