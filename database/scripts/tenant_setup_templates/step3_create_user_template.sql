-- step3_create_user_template.sql
-- Template for creating platform users during tenant setup
-- 
-- Usage Instructions:
-- 1. Copy this file for each user (e.g., step3_create_admin_user.sql)
-- 2. Replace all {PLACEHOLDER} values with actual values
-- 3. Run this script for each user you need to create
--
-- Required Replacements:
-- {PLATFORM_NAME} - Platform identifier (must match step1)
-- {USER_EMAIL} - User's email address
-- {SECURE_PASSWORD} - Secure password for the user
-- {FIRST_NAME} - User's first name
-- {LAST_NAME} - User's last name
-- {PHONE} - User's phone number
-- {JOB_TITLE} - User's job title
-- {ROLE} - User's role (ADMINISTRATOR, MANAGER, USER)
-- {USER_DESCRIPTION} - Brief description of the user

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_success BOOLEAN;
    v_message TEXT;
    v_user_data JSONB;
    v_session_token VARCHAR(255);
BEGIN
    RAISE NOTICE 'Creating user: {USER_EMAIL} for platform: {PLATFORM_NAME}';
    
    -- Get tenant HK
    SELECT tenant_hk INTO v_tenant_hk 
    FROM auth.tenant_h 
    WHERE tenant_bk = '{PLATFORM_NAME}';
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'Tenant not found: {PLATFORM_NAME}. Please run step1_create_tenant first.';
    END IF;
    
    -- Create user
    SELECT p_user_hk, p_success, p_message, p_user_data, p_session_token
    INTO v_user_hk, v_success, v_message, v_user_data, v_session_token
    FROM auth.register_user(
        v_tenant_hk,
        '{USER_EMAIL}',
        '{SECURE_PASSWORD}',
        '{FIRST_NAME}',
        '{LAST_NAME}',
        '{PHONE}',
        '{JOB_TITLE}',
        '{ROLE}' -- ADMINISTRATOR, MANAGER, USER
    );
    
    IF NOT v_success THEN
        RAISE EXCEPTION 'Failed to create user: %', v_message;
    END IF;
    
    RAISE NOTICE '✅ User created successfully';
    RAISE NOTICE 'User: {USER_EMAIL}';
    RAISE NOTICE 'Role: {ROLE}';
    RAISE NOTICE 'User HK: %', encode(v_user_hk, 'hex');
    RAISE NOTICE 'Password: {SECURE_PASSWORD}';
    RAISE NOTICE 'Description: {USER_DESCRIPTION}';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 IMPORTANT: Store these credentials securely!';
    
END $$;

-- Verify user creation
SELECT 
    'User Verification' as check_type,
    up.email,
    up.first_name,
    up.last_name,
    rs.role_name,
    encode(uh.user_hk, 'hex') as user_hk_hex,
    uh.load_date
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
JOIN auth.role_s rs ON url.role_hk = rs.role_hk
WHERE uh.tenant_hk = (SELECT tenant_hk FROM auth.tenant_h WHERE tenant_bk = '{PLATFORM_NAME}')
AND up.email = '{USER_EMAIL}'
AND up.load_end_date IS NULL
AND rs.load_end_date IS NULL; 