-- ================================================================
-- STEP 3 - EMERGENCY AUTHENTICATION FIX
-- ================================================================
-- Purpose: Fix the duplicate key violation in user_auth_s
-- Database: the_one_spa_oregon  
-- Execute in: pgAdmin as admin user
-- ================================================================

-- DIAGNOSIS: Check current state
SELECT 
    'DIAGNOSIS' as action,
    COUNT(*) as total_records,
    COUNT(CASE WHEN load_end_date IS NULL THEN 1 END) as active_records,
    'There should be exactly 1 active record' as expected
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com';

-- Show the problematic records
SELECT 
    'PROBLEMATIC RECORDS' as action,
    user_hk,
    load_date,
    load_end_date,
    failed_login_attempts,
    account_locked,
    CASE WHEN load_end_date IS NULL THEN 'ACTIVE' ELSE 'INACTIVE' END as status
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com'
ORDER BY load_date DESC;

-- Check for hash_diff duplicates that might cause primary key violation
SELECT 
    'HASH_DIFF DUPLICATES' as action,
    hash_diff,
    COUNT(*) as duplicate_count,
    MIN(load_date) as first_occurrence,
    MAX(load_date) as last_occurrence
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com'
GROUP BY hash_diff
HAVING COUNT(*) > 1;

-- ================================================================
-- EMERGENCY FIX: End-date all but the newest record
-- ================================================================

-- Step 1: Find the newest active record
WITH newest_record AS (
    SELECT user_hk, load_date
    FROM auth.user_auth_s 
    WHERE username = 'travisdwoodward72@gmail.com'
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1
)
-- Step 2: End-date all older active records
UPDATE auth.user_auth_s 
SET load_end_date = util.current_load_date()
WHERE username = 'travisdwoodward72@gmail.com'
AND load_end_date IS NULL
AND (user_hk, load_date) NOT IN (SELECT user_hk, load_date FROM newest_record);

-- VERIFICATION: Check fix worked
SELECT 
    'POST-FIX VERIFICATION' as action,
    COUNT(*) as total_records,
    COUNT(CASE WHEN load_end_date IS NULL THEN 1 END) as active_records,
    'Should now be exactly 1 active record' as expected
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com';

-- Show final state
SELECT 
    'FINAL STATE' as action,
    user_hk,
    load_date,
    load_end_date,
    failed_login_attempts,
    account_locked,
    CASE WHEN load_end_date IS NULL THEN 'ACTIVE' ELSE 'INACTIVE' END as status
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com'
ORDER BY load_date DESC
LIMIT 5;

-- ================================================================
-- TEST THE FIX
-- ================================================================

-- Test authentication now works
SELECT 
    'AUTHENTICATION TEST' as test_type,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "MySecurePassword123",
        "ip_address": "192.168.1.100",
        "user_agent": "Emergency Fix Test"
    }'::jsonb) as result; 