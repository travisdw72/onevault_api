-- ================================================================
-- INVESTIGATE LOGIN ISSUE DIAGNOSTIC SCRIPT
-- ================================================================
-- Purpose: Diagnose why valid login credentials are failing
-- Based on test results showing all logins return "Invalid username or password"
-- Last Updated: December 2024
-- ================================================================

-- ================================================================
-- SECTION 1: CHECK USER EXISTENCE
-- ================================================================

SELECT 'USER EXISTENCE CHECK' as diagnostic_section;

-- Check if the test user exists in auth.user_h
SELECT 
    'auth.user_h' as table_name,
    COUNT(*) as user_count,
    CASE WHEN COUNT(*) > 0 THEN '✅ User exists' ELSE '❌ User NOT found' END as status
FROM auth.user_h 
WHERE user_bk = 'travisdwoodward72@gmail.com'
   OR user_bk LIKE '%travisdwoodward72%';

-- Check if user exists in auth.user_auth_s (authentication table)
SELECT 
    'auth.user_auth_s' as table_name,
    COUNT(*) as auth_record_count,
    CASE WHEN COUNT(*) > 0 THEN '✅ Auth record exists' ELSE '❌ Auth record NOT found' END as status
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com'
   OR username LIKE '%travisdwoodward72%';

-- ================================================================
-- SECTION 2: CHECK CURRENT USER RECORDS
-- ================================================================

SELECT 'CURRENT USER RECORDS' as diagnostic_section;

-- Show current active user records
SELECT 
    'Current user_auth_s records' as info,
    uas.username,
    uas.account_locked,
    uas.failed_login_attempts,
    uas.last_login_date,
    uas.load_date,
    uas.load_end_date,
    CASE WHEN uas.load_end_date IS NULL THEN '✅ ACTIVE' ELSE '❌ ENDED' END as record_status
FROM auth.user_auth_s uas
WHERE uas.username = 'travisdwoodward72@gmail.com'
ORDER BY uas.load_date DESC
LIMIT 5;

-- ================================================================
-- SECTION 3: PASSWORD HASH ANALYSIS
-- ================================================================

SELECT 'PASSWORD HASH ANALYSIS' as diagnostic_section;

-- Check password hash format and content
SELECT 
    'Password Hash Details' as info,
    uas.username,
    CASE 
        WHEN uas.password_hash IS NULL THEN '❌ NULL password hash'
        WHEN length(uas.password_hash) = 0 THEN '❌ Empty password hash'
        ELSE '✅ Password hash exists'
    END as hash_status,
    length(uas.password_hash) as hash_length,
    encode(uas.password_hash, 'escape') as hash_preview,
    CASE 
        WHEN convert_from(uas.password_hash, 'UTF8') LIKE '$2%' THEN '✅ bcrypt format'
        ELSE '❌ Not bcrypt format'
    END as hash_format
FROM auth.user_auth_s uas
WHERE uas.username = 'travisdwoodward72@gmail.com'
AND uas.load_end_date IS NULL
ORDER BY uas.load_date DESC
LIMIT 1;

-- ================================================================
-- SECTION 4: TEST PASSWORD VALIDATION MANUALLY
-- ================================================================

SELECT 'PASSWORD VALIDATION TEST' as diagnostic_section;

-- Test the exact password validation logic used in the API
DO $$
DECLARE
    v_test_password TEXT := 'secureP@ssw0rd123!';
    v_stored_hash_bytea BYTEA;
    v_stored_hash_text TEXT;
    v_crypt_result TEXT;
    v_validation_result BOOLEAN;
BEGIN
    -- Get the stored password hash
    SELECT password_hash INTO v_stored_hash_bytea
    FROM auth.user_auth_s
    WHERE username = 'travisdwoodward72@gmail.com'
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;
    
    IF v_stored_hash_bytea IS NULL THEN
        RAISE NOTICE '❌ No password hash found for user';
        RETURN;
    END IF;
    
    -- Convert to text format
    BEGIN
        v_stored_hash_text := convert_from(v_stored_hash_bytea, 'UTF8');
        RAISE NOTICE '✅ Password hash converted: %', LEFT(v_stored_hash_text, 20) || '...';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Failed to convert password hash: %', SQLERRM;
        RETURN;
    END;
    
    -- Test crypt function
    BEGIN
        v_crypt_result := crypt(v_test_password, v_stored_hash_text);
        RAISE NOTICE '✅ Crypt function executed';
        RAISE NOTICE 'Stored hash: %', LEFT(v_stored_hash_text, 30) || '...';
        RAISE NOTICE 'Crypt result: %', LEFT(v_crypt_result, 30) || '...';
        
        v_validation_result := (v_crypt_result = v_stored_hash_text);
        RAISE NOTICE 'Password validation result: %', 
            CASE WHEN v_validation_result THEN '✅ VALID' ELSE '❌ INVALID' END;
            
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Crypt function failed: %', SQLERRM;
    END;
END $$;

-- ================================================================
-- SECTION 5: CHECK TENANT RELATIONSHIPS
-- ================================================================

SELECT 'TENANT RELATIONSHIP CHECK' as diagnostic_section;

-- Check user-tenant relationships
SELECT 
    'User-Tenant Relationship' as info,
    uh.user_bk,
    th.tenant_bk,
    encode(uh.user_hk, 'hex') as user_hk_hex,
    encode(uh.tenant_hk, 'hex') as tenant_hk_hex
FROM auth.user_h uh
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
WHERE uh.user_bk = 'travisdwoodward72@gmail.com'
   OR uh.user_bk LIKE '%travisdwoodward72%';

-- ================================================================
-- SECTION 6: CHECK ALL USERS IN SYSTEM
-- ================================================================

SELECT 'ALL USERS IN SYSTEM' as diagnostic_section;

-- Show all users currently in the system
SELECT 
    'All current users' as info,
    uas.username,
    uas.account_locked,
    uas.load_date,
    uas.load_end_date,
    CASE WHEN uas.load_end_date IS NULL THEN 'ACTIVE' ELSE 'ENDED' END as status
FROM auth.user_auth_s uas
WHERE uas.load_end_date IS NULL
ORDER BY uas.load_date DESC
LIMIT 10;

-- ================================================================
-- SECTION 7: RECENT LOGIN ATTEMPTS
-- ================================================================

SELECT 'RECENT LOGIN ATTEMPTS' as diagnostic_section;

-- Check recent login attempts in audit tables
SELECT 
    'Recent login attempts' as info,
    COUNT(*) as attempt_count
FROM raw.login_attempt_h
WHERE load_date > CURRENT_TIMESTAMP - INTERVAL '1 day';

-- Show recent login details if available
SELECT 
    'Login attempt details' as info,
    rld.username,
    rld.ip_address,
    rld.attempt_timestamp,
    rld.load_date
FROM raw.login_details_s rld
JOIN raw.login_attempt_h rlh ON rld.login_attempt_hk = rlh.login_attempt_hk
WHERE rld.load_date > CURRENT_TIMESTAMP - INTERVAL '1 hour'
ORDER BY rld.load_date DESC
LIMIT 5;

-- ================================================================
-- SECTION 8: SUGGESTED FIXES
-- ================================================================

SELECT 'DIAGNOSTIC COMPLETE' as section;
SELECT 'REVIEW RESULTS ABOVE TO IDENTIFY ISSUES:' as instruction;
SELECT '1. Check if user exists in auth.user_auth_s' as check1;
SELECT '2. Verify password hash is bcrypt format' as check2;
SELECT '3. Confirm account is not locked' as check3;
SELECT '4. Verify tenant relationship exists' as check4;
SELECT '5. Test password validation manually' as check5; 