-- =============================================
-- fix_duplicate_key_violation.sql
-- Investigates and fixes the duplicate key violation in user_auth_s table
-- Error: duplicate key value violates unique constraint "user_auth_s_pkey"
-- =============================================

-- Check current user_auth_s records for our user
SELECT 'CURRENT USER_AUTH_S RECORDS:' as info;

SELECT 
    encode(user_hk, 'hex') as user_hk_hex,
    load_date,
    load_end_date,
    username,
    password_last_changed,
    failed_login_attempts,
    account_locked,
    record_source,
    ROW_NUMBER() OVER (ORDER BY load_date DESC) as row_num
FROM auth.user_auth_s
WHERE username = 'travisdwoodward72@gmail.com'
ORDER BY load_date DESC;

-- Check for duplicate load_dates (this might be the issue)
SELECT 'CHECKING FOR DUPLICATE LOAD_DATES:' as info;

SELECT 
    encode(user_hk, 'hex') as user_hk_hex,
    load_date,
    COUNT(*) as duplicate_count
FROM auth.user_auth_s
WHERE username = 'travisdwoodward72@gmail.com'
GROUP BY user_hk, load_date
HAVING COUNT(*) > 1;

-- Check the util.current_load_date() function behavior
SELECT 'CHECKING LOAD_DATE FUNCTION:' as info;

SELECT 
    util.current_load_date() as current_load_date_1,
    util.current_load_date() as current_load_date_2,
    util.current_load_date() as current_load_date_3,
    CASE 
        WHEN util.current_load_date() = util.current_load_date() 
        THEN 'SAME - This could cause duplicates!'
        ELSE 'DIFFERENT - Good'
    END as load_date_uniqueness;

-- Check what records have load_end_date IS NULL (should be only 1)
SELECT 'ACTIVE RECORDS (load_end_date IS NULL):' as info;

SELECT 
    COUNT(*) as active_record_count,
    COUNT(CASE WHEN load_end_date IS NULL THEN 1 END) as null_end_date_count
FROM auth.user_auth_s
WHERE username = 'travisdwoodward72@gmail.com';

-- Show the exact primary key constraint
SELECT 'PRIMARY KEY CONSTRAINT DETAILS:' as info;

SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'auth.user_auth_s'::regclass 
AND contype = 'p';

-- Test what happens when we try to get current time multiple times quickly
SELECT 'RAPID LOAD_DATE GENERATION TEST:' as info;

SELECT 
    generate_series(1,5) as test_num,
    util.current_load_date() as load_date,
    EXTRACT(MICROSECONDS FROM util.current_load_date()) as microseconds
FROM generate_series(1,5);

-- Investigate what the login function is trying to do
SELECT 'SIMULATING LOGIN FUNCTION LOGIC:' as info;

DO $$
DECLARE
    v_user_hk BYTEA;
    v_current_load_date TIMESTAMP WITH TIME ZONE;
    v_existing_count INTEGER;
BEGIN
    -- Get user hash key
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = 'travisdwoodward72@gmail.com'
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    -- Get current load date
    v_current_load_date := util.current_load_date();
    
    -- Check if a record with this user_hk and load_date already exists
    SELECT COUNT(*) INTO v_existing_count
    FROM auth.user_auth_s
    WHERE user_hk = v_user_hk
    AND load_date = v_current_load_date;
    
    RAISE NOTICE 'User HK: %', encode(v_user_hk, 'hex');
    RAISE NOTICE 'Current load date: %', v_current_load_date;
    RAISE NOTICE 'Records with this user_hk and load_date: %', v_existing_count;
    
    IF v_existing_count > 0 THEN
        RAISE NOTICE 'PROBLEM: A record already exists with this user_hk and load_date!';
        RAISE NOTICE 'This would cause the duplicate key violation.';
    ELSE
        RAISE NOTICE 'OK: No duplicate would be created.';
    END IF;
END $$;

-- Fix option 1: Clean up any existing duplicates
SELECT 'POTENTIAL FIX 1: Clean up duplicates (if any exist)' as fix_option;

-- Show what records would be affected by cleanup
SELECT 
    'RECORDS TO CLEAN UP (keeping most recent):' as action,
    encode(user_hk, 'hex') as user_hk_hex,
    load_date,
    load_end_date,
    record_source,
    ROW_NUMBER() OVER (PARTITION BY user_hk ORDER BY load_date DESC) as keep_order
FROM auth.user_auth_s
WHERE username = 'travisdwoodward72@gmail.com'
AND load_end_date IS NULL;

-- Fix option 2: Ensure proper end-dating of previous records
SELECT 'POTENTIAL FIX 2: Ensure only one active record exists' as fix_option;

-- Count how many active records exist
SELECT 
    COUNT(*) as total_active_records,
    'Should be 1 or 0' as expected_count
FROM auth.user_auth_s
WHERE username = 'travisdwoodward72@gmail.com'
AND load_end_date IS NULL;

-- Proposed fix script
SELECT 'PROPOSED FIX SCRIPT:' as action;

DO $$
DECLARE
    v_user_hk BYTEA;
    v_latest_load_date TIMESTAMP WITH TIME ZONE;
    v_fix_count INTEGER := 0;
BEGIN
    -- Get user hash key
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = 'travisdwoodward72@gmail.com'
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    -- Get the latest load_date for this user
    SELECT MAX(load_date) INTO v_latest_load_date
    FROM auth.user_auth_s
    WHERE user_hk = v_user_hk;
    
    -- End-date all records except the most recent one
    UPDATE auth.user_auth_s
    SET load_end_date = CURRENT_TIMESTAMP
    WHERE user_hk = v_user_hk
    AND load_date < v_latest_load_date
    AND load_end_date IS NULL;
    
    GET DIAGNOSTICS v_fix_count = ROW_COUNT;
    
    RAISE NOTICE 'Fixed % duplicate active records', v_fix_count;
    
    IF v_fix_count > 0 THEN
        RAISE NOTICE 'You should now be able to login successfully!';
    ELSE
        RAISE NOTICE 'No duplicate records found. The issue may be in the login function logic.';
    END IF;
END $$; 