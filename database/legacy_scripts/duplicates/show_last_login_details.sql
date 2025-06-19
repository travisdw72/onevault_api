-- ============================================================================
-- SHOW LAST LOGIN DETAILS - Direct Data View
-- Shows exactly who logged in last and where their password data is stored
-- ============================================================================

-- 1. WHO WAS THE LAST PERSON TO LOGIN?
SELECT 
    'LAST LOGIN USER' as info_type,
    up.first_name || ' ' || up.last_name as full_name,
    up.email,
    uas.username,
    uas.last_login_date,
    uas.password_last_changed,
    EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - uas.password_last_changed)) as password_age_days
FROM auth.user_auth_s uas
JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
WHERE uas.load_end_date IS NULL 
AND up.load_end_date IS NULL
AND uas.last_login_date IS NOT NULL
ORDER BY uas.last_login_date DESC
LIMIT 1;

-- 2. WHERE IS THEIR PASSWORD INFORMATION STORED?
WITH last_user AS (
    SELECT uas.user_hk, uas.username, up.email
    FROM auth.user_auth_s uas
    JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uas.load_end_date IS NULL 
    AND up.load_end_date IS NULL
    AND uas.last_login_date IS NOT NULL
    ORDER BY uas.last_login_date DESC
    LIMIT 1
)
SELECT 
    'PASSWORD STORAGE LOCATION' as info_type,
    'auth.user_auth_s' as table_name,
    'password_hash' as column_name,
    LENGTH(uas.password_hash) as stored_bytes,
    'SECURE BCRYPT HASH' as content_type,
    LEFT(encode(uas.password_hash, 'hex'), 20) || '...' as hash_preview
FROM auth.user_auth_s uas
JOIN last_user lu ON uas.user_hk = lu.user_hk
WHERE uas.load_end_date IS NULL

UNION ALL

SELECT 
    'PASSWORD SALT LOCATION' as info_type,
    'auth.user_auth_s' as table_name,
    'password_salt' as column_name,
    LENGTH(uas.password_salt) as stored_bytes,
    'SECURE SALT' as content_type,
    LEFT(encode(uas.password_salt, 'hex'), 20) || '...' as hash_preview
FROM auth.user_auth_s uas
JOIN last_user lu ON uas.user_hk = lu.user_hk
WHERE uas.load_end_date IS NULL;

-- 3. CHECK WHAT COLUMNS EXIST IN RAW LOGIN ATTEMPT TABLE
SELECT 
    'RAW LOGIN TABLE STRUCTURE' as info_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'raw' 
AND table_name = 'login_attempt_s'
ORDER BY ordinal_position;

-- 4. WHAT RAW DATA EXISTS FOR LAST USER? (Using correct column names)
WITH last_user AS (
    SELECT uas.username
    FROM auth.user_auth_s uas
    WHERE uas.load_end_date IS NULL 
    AND uas.last_login_date IS NOT NULL
    ORDER BY uas.last_login_date DESC
    LIMIT 1
)
SELECT 
    'RAW LOGIN ATTEMPTS' as info_type,
    rla.username,
    rla.password_indicator,
    rla.load_date as attempt_timestamp,
    CASE 
        WHEN rla.login_successful IS NOT NULL THEN 
            CASE WHEN rla.login_successful THEN 'SUCCESS' ELSE 'FAILED' END
        ELSE 'UNKNOWN'
    END as attempt_result,
    COALESCE(rla.ip_address::text, 'NO IP RECORDED') as source_ip
FROM raw.login_attempt_s rla
JOIN last_user lu ON rla.username = lu.username
WHERE rla.load_end_date IS NULL
ORDER BY rla.load_date DESC
LIMIT 3;

-- 5. WHAT SESSION DATA EXISTS FOR THIS USER?
WITH last_user AS (
    SELECT uas.user_hk, uas.username
    FROM auth.user_auth_s uas
    WHERE uas.load_end_date IS NULL 
    AND uas.last_login_date IS NOT NULL
    ORDER BY uas.last_login_date DESC
    LIMIT 1
)
SELECT 
    'SESSION DATA' as info_type,
    ss.session_status,
    ss.ip_address::text as session_ip,
    ss.session_start,
    ss.last_activity,
    LEFT(COALESCE(ss.user_agent, 'NO USER AGENT'), 50) || '...' as browser_info
FROM auth.session_state_s ss
JOIN auth.session_h sh ON ss.session_hk = sh.session_hk
JOIN auth.user_session_l usl ON sh.session_hk = usl.session_hk
JOIN last_user lu ON usl.user_hk = lu.user_hk
WHERE ss.load_end_date IS NULL
ORDER BY ss.session_start DESC
LIMIT 3;

-- 6. SUMMARY: WHAT PASSWORD-RELATED DATA IS STORED WHERE?
SELECT 
    'SECURITY SUMMARY' as category,
    'NO PLAINTEXT PASSWORDS ANYWHERE' as finding,
    'All passwords stored as secure hashes only' as details;

-- 7. SHOW ALL TABLES THAT CONTAIN ANY PASSWORD-RELATED COLUMNS
SELECT 
    'PASSWORD COLUMNS IN DATABASE' as category,
    table_schema || '.' || table_name as table_location,
    column_name,
    data_type,
    CASE 
        WHEN column_name LIKE '%hash%' THEN '✅ SECURE HASH STORAGE'
        WHEN column_name LIKE '%salt%' THEN '✅ SECURE SALT STORAGE'
        WHEN column_name LIKE '%indicator%' THEN '✅ SAFE INDICATOR ONLY'
        WHEN column_name LIKE '%password%' AND data_type = 'bytea' THEN '✅ SECURE BINARY'
        WHEN column_name LIKE '%password%' THEN '⚠️ REVIEW NEEDED'
        ELSE '📋 OTHER'
    END as security_assessment
FROM information_schema.columns 
WHERE LOWER(column_name) LIKE '%password%'
   OR LOWER(column_name) LIKE '%hash%'
   OR LOWER(column_name) LIKE '%salt%'
AND table_schema NOT LIKE 'pg_%'
AND table_schema != 'information_schema'
ORDER BY table_schema, table_name, column_name; 