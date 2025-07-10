-- step8_final_verification_template.sql
-- Template for final verification of tenant setup completion
-- 
-- Usage Instructions:
-- 1. Copy this file to a new file (e.g., step8_final_verification_onevault.sql)
-- 2. Replace {PLATFORM_NAME} with your platform name
-- 3. Run this script after completing all setup steps
--
-- Required Replacements:
-- {PLATFORM_NAME} - Platform identifier (must match step1)

RAISE NOTICE '🔍 Running final verification for platform: {PLATFORM_NAME}';
RAISE NOTICE '';

-- Verify all components are created correctly
SELECT 
    'TENANT VERIFICATION' as verification_type,
    tenant_bk as identifier,
    encode(tenant_hk, 'hex') as hash_key,
    to_char(load_date, 'YYYY-MM-DD HH24:MI:SS') as created_date,
    '✅ Tenant exists' as status
FROM auth.tenant_h 
WHERE tenant_bk = '{PLATFORM_NAME}'

UNION ALL

SELECT 
    'USER VERIFICATION' as verification_type,
    up.email as identifier,
    encode(uh.user_hk, 'hex') as hash_key,
    to_char(uh.load_date, 'YYYY-MM-DD HH24:MI:SS') as created_date,
    '✅ User: ' || rs.role_name as status
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
JOIN auth.role_s rs ON url.role_hk = rs.role_hk
WHERE uh.tenant_hk = (SELECT tenant_hk FROM auth.tenant_h WHERE tenant_bk = '{PLATFORM_NAME}')
AND up.load_end_date IS NULL
AND rs.load_end_date IS NULL

UNION ALL

SELECT 
    'API KEY VERIFICATION' as verification_type,
    aks.key_name as identifier,
    encode(akh.api_key_hk, 'hex') as hash_key,
    to_char(akh.load_date, 'YYYY-MM-DD HH24:MI:SS') as created_date,
    '✅ API Key expires: ' || to_char(aks.expiration_date, 'YYYY-MM-DD') as status
FROM auth.api_key_h akh
JOIN auth.api_key_s aks ON akh.api_key_hk = aks.api_key_hk
WHERE akh.tenant_hk = (SELECT tenant_hk FROM auth.tenant_h WHERE tenant_bk = '{PLATFORM_NAME}')
AND aks.load_end_date IS NULL

ORDER BY verification_type, identifier;

-- Get summary counts
RAISE NOTICE '';
RAISE NOTICE '📊 SETUP SUMMARY FOR: {PLATFORM_NAME}';
RAISE NOTICE '========================================';

DO $$
DECLARE
    v_tenant_count INTEGER;
    v_user_count INTEGER;
    v_api_key_count INTEGER;
    v_tenant_hk BYTEA;
BEGIN
    -- Get tenant info
    SELECT COUNT(*), MIN(tenant_hk) 
    INTO v_tenant_count, v_tenant_hk
    FROM auth.tenant_h 
    WHERE tenant_bk = '{PLATFORM_NAME}';
    
    -- Get user count
    SELECT COUNT(*) 
    INTO v_user_count
    FROM auth.user_h 
    WHERE tenant_hk = v_tenant_hk;
    
    -- Get API key count
    SELECT COUNT(*) 
    INTO v_api_key_count
    FROM auth.api_key_h 
    WHERE tenant_hk = v_tenant_hk;
    
    RAISE NOTICE 'Tenants Created: %', v_tenant_count;
    RAISE NOTICE 'Users Created: %', v_user_count;
    RAISE NOTICE 'API Keys Created: %', v_api_key_count;
    RAISE NOTICE 'Tenant HK: %', encode(v_tenant_hk, 'hex');
    
    IF v_tenant_count = 1 AND v_user_count >= 1 AND v_api_key_count >= 1 THEN
        RAISE NOTICE '';
        RAISE NOTICE '🎉 SUCCESS: Platform {PLATFORM_NAME} setup completed successfully!';
        RAISE NOTICE '';
        RAISE NOTICE '📋 NEXT STEPS:';
        RAISE NOTICE '1. Store all credentials securely';
        RAISE NOTICE '2. Configure your application with the API key';
        RAISE NOTICE '3. Test user login functionality';
        RAISE NOTICE '4. Verify API integration';
        RAISE NOTICE '5. Set up monitoring and alerts';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '❌ WARNING: Setup appears incomplete!';
        RAISE NOTICE 'Please review the verification results above.';
    END IF;
    
END $$;

-- Display all credentials for reference (remove this section in production)
RAISE NOTICE '';
RAISE NOTICE '🔐 CREDENTIAL SUMMARY (STORE SECURELY):';
RAISE NOTICE '===========================================';

DO $$
DECLARE
    r RECORD;
BEGIN
    -- Show user credentials
    FOR r IN 
        SELECT 
            up.email,
            up.first_name || ' ' || up.last_name as full_name,
            rs.role_name
        FROM auth.user_h uh
        JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
        JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
        JOIN auth.role_s rs ON url.role_hk = rs.role_hk
        WHERE uh.tenant_hk = (SELECT tenant_hk FROM auth.tenant_h WHERE tenant_bk = '{PLATFORM_NAME}')
        AND up.load_end_date IS NULL
        AND rs.load_end_date IS NULL
        ORDER BY rs.role_name, up.email
    LOOP
        RAISE NOTICE 'User: % (%) - Role: %', r.email, r.full_name, r.role_name;
    END LOOP;
    
    -- Show API key info
    FOR r IN 
        SELECT 
            aks.key_name,
            aks.description,
            aks.expiration_date,
            array_to_string(aks.scopes, ', ') as scope_list
        FROM auth.api_key_h akh
        JOIN auth.api_key_s aks ON akh.api_key_hk = aks.api_key_hk
        WHERE akh.tenant_hk = (SELECT tenant_hk FROM auth.tenant_h WHERE tenant_bk = '{PLATFORM_NAME}')
        AND aks.load_end_date IS NULL
    LOOP
        RAISE NOTICE 'API Key: % - Expires: % - Scopes: %', r.key_name, r.expiration_date, r.scope_list;
    END LOOP;
    
END $$;

RAISE NOTICE '';
RAISE NOTICE '✅ Verification complete for {PLATFORM_NAME}';
RAISE NOTICE ''; 