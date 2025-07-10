-- ========================================================================
-- ONE BARN AI - CLEAN SETUP (NO ROLLBACK ISSUES)
-- ========================================================================
-- Fix: Separate each phase to avoid rollback cascades
-- Each section can be run independently

-- ========================================================================
-- PHASE 1: TENANT CREATION (ISOLATED)
-- ========================================================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_result RECORD;
BEGIN
    RAISE NOTICE 'Starting One_Barn_AI tenant creation...';
    
    -- Call the register_tenant_with_roles function
    SELECT * INTO v_result FROM auth.register_tenant_with_roles(
        p_tenant_name := 'one_barn_ai',
        p_admin_email := 'admin@onebarnai.com',
        p_admin_password := 'HorseHealth2025!',
        p_admin_first_name := 'Travis',
        p_admin_last_name := 'Woodward'
    );
    
    v_tenant_hk := v_result.tenant_hk;
    v_admin_user_hk := v_result.admin_user_hk;
    
    RAISE NOTICE '✅ One_Barn_AI tenant created successfully!';
    RAISE NOTICE '✅ Tenant HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE '✅ Admin User HK: %', encode(v_admin_user_hk, 'hex');
    RAISE NOTICE 'Phase 1 Complete - Tenant and Admin ready!';
    
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Tenant creation failed: %', SQLERRM;
END $$;

-- ========================================================================
-- VERIFICATION: CONFIRM TENANT EXISTS (SAFE QUERY)
-- ========================================================================

SELECT 
    '✅ TENANT_CREATED' as status,
    th.tenant_bk,
    tp.tenant_name,
    tp.is_active,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- ========================================================================
-- PHASE 2: ADDITIONAL USERS (ISOLATED)
-- ========================================================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
BEGIN
    RAISE NOTICE 'Starting additional user creation...';
    
    -- Get the tenant HK
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
    AND tp.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'One_Barn_AI tenant not found. Run Phase 1 first.';
    END IF;
    
    RAISE NOTICE '✅ Found tenant HK: %', encode(v_tenant_hk, 'hex');
    
    -- Veterinary Specialist
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'vet@onebarnai.com',
        p_password := 'VetSpecialist2025!',
        p_first_name := 'Dr. Sarah',
        p_last_name := 'Mitchell',
        p_role_bk := 'USER',
        p_user_hk := v_user_hk
    );
    RAISE NOTICE '✅ Created veterinary specialist: %', encode(v_user_hk, 'hex');
    
    -- AI Technical Lead
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'tech@onebarnai.com',
        p_password := 'TechLead2025!',
        p_first_name := 'Michelle',
        p_last_name := 'Nash',
        p_role_bk := 'MANAGER',
        p_user_hk := v_user_hk
    );
    RAISE NOTICE '✅ Created technical lead: %', encode(v_user_hk, 'hex');
    
    -- Business Development Manager
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'business@onebarnai.com',
        p_password := 'BizDev2025!',
        p_first_name := 'Sarah',
        p_last_name := 'Roberston',
        p_role_bk := 'USER',
        p_user_hk := v_user_hk
    );
    RAISE NOTICE '✅ Created business development manager: %', encode(v_user_hk, 'hex');
    
    RAISE NOTICE '🎉 All One_Barn_AI team members created successfully!';
    
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'User creation failed: %', SQLERRM;
END $$;

-- ========================================================================
-- FINAL VERIFICATION (SAFE QUERIES ONLY)
-- ========================================================================

-- Count users for One Barn AI tenant
SELECT 
    '✅ USER_COUNT' as check_type,
    COUNT(*) as user_count,
    CASE WHEN COUNT(*) >= 4 THEN '🎉 SUCCESS' ELSE '⚠️ PARTIAL' END as status
FROM auth.user_h uh
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- Show all created users (CORRECTED - no uas.is_active)
SELECT 
    '✅ CREATED_USERS' as info_type,
    up.email,
    up.first_name,
    up.last_name,
    up.is_active,           -- SAFE: using up.is_active (exists)
    encode(uh.user_hk, 'hex') as user_hk_hex
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL
AND up.load_end_date IS NULL
ORDER BY up.load_date;

-- ========================================================================
-- SUCCESS MESSAGE
-- ========================================================================

SELECT 
    '🎯 ONE BARN AI SETUP COMPLETE!' as summary,
    '4 users created for July 7th demo' as details,
    'Ready for API authentication testing' as next_step;

-- ========================================================================
-- API AUTHENTICATION TEST COMMAND
-- ========================================================================

SELECT 
    '🔑 TEST AUTHENTICATION' as test_type,
    'Copy and run this command:' as instruction,
    'SELECT api.auth_login(''{"username": "admin@onebarnai.com", "password": "HorseHealth2025!", "ip_address": "127.0.0.1", "user_agent": "OneVault-Demo-Client", "auto_login": true}'');' as test_command; 