-- ================================================================
-- DIAGNOSE PRIMARY KEY ISSUE IN user_auth_s
-- ================================================================
-- Purpose: Identify why we're getting duplicate key violations
-- Database: the_one_spa_oregon
-- ================================================================

-- STEP 1: Check current user_auth_s records for our test user
SELECT 
    'CURRENT USER_AUTH_S RECORDS' as info_type,
    user_hk,
    load_date,
    load_end_date,
    username,
    failed_login_attempts,
    account_locked,
    last_login_date,
    password_last_changed
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com'
ORDER BY load_date DESC;

-- STEP 2: Check the primary key definition
SELECT 
    'PRIMARY KEY INFO' as info_type,
    tc.constraint_name,
    kcu.column_name,
    kcu.ordinal_position
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'auth'
    AND tc.table_name = 'user_auth_s'
    AND tc.constraint_type = 'PRIMARY KEY'
ORDER BY kcu.ordinal_position;

-- STEP 3: Check if there are any records without end dates (should be only 1)
SELECT 
    'ACTIVE RECORDS CHECK' as info_type,
    COUNT(*) as active_record_count,
    MIN(load_date) as oldest_active,
    MAX(load_date) as newest_active
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com'
    AND load_end_date IS NULL;

-- STEP 4: Check the hash_diff values for potential duplicates
SELECT 
    'HASH_DIFF ANALYSIS' as info_type,
    hash_diff,
    COUNT(*) as occurrence_count,
    MIN(load_date) as first_occurrence,
    MAX(load_date) as last_occurrence
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com'
GROUP BY hash_diff
HAVING COUNT(*) > 1;

-- STEP 5: Check what columns exist in login_attempt_h
SELECT 
    'LOGIN_ATTEMPT_H COLUMNS' as info_type,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'raw' 
    AND table_name = 'login_attempt_h'
ORDER BY ordinal_position;

-- STEP 6: Check recent login attempt records (using actual columns)
SELECT 
    'RECENT LOGIN ATTEMPTS' as info_type,
    load_date,
    user_hk,
    success
FROM raw.login_attempt_h 
WHERE load_date >= NOW() - INTERVAL '10 minutes'
ORDER BY load_date DESC
LIMIT 10;

-- STEP 7: Try to identify the exact duplicate that would be created
SELECT 
    'POTENTIAL DUPLICATE CHECK' as info_type,
    user_hk,
    load_date,
    hash_diff,
    'This might be the duplicate' as note
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com'
    AND load_end_date IS NULL;

-- STEP 8: Check if there are any constraint violations in the table
SELECT 
    'CONSTRAINT VIOLATIONS' as info_type,
    conname as constraint_name,
    contype as constraint_type
FROM pg_constraint 
WHERE conrelid = 'auth.user_auth_s'::regclass
    AND contype IN ('p', 'u'); -- primary key and unique constraints 