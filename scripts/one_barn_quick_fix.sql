-- ========================================================================
-- ONE BARN AI - QUICK FIX FOR VERIFICATION QUERY
-- ========================================================================
-- Issue: uas.is_active column doesn't exist, should be up.is_active
-- Status: Core setup succeeded, just fixing verification queries

-- ========================================================================
-- CORRECTED VERIFICATION QUERIES
-- ========================================================================

-- Step 1.3: Verify Admin User Creation (CORRECTED)
SELECT 
    up.email,
    up.first_name,
    up.last_name,
    up.is_active,           -- ✅ FIXED: changed from uas.is_active to up.is_active
    uas.account_locked,     -- This column exists in user_auth_s
    encode(uh.user_hk, 'hex') as user_hk_hex
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
WHERE up.load_end_date IS NULL
AND (uas.load_end_date IS NULL OR uas.load_end_date IS NULL)
AND up.email = 'admin@onebarnai.com';

-- ========================================================================
-- CONTINUE WITH PHASE 3: USER CREATION (Safe to run)
-- ========================================================================

-- Step 3.1: Create Additional One_Barn_AI Team Members
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
BEGIN
    -- Get tenant hash key (we know it exists now)
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE th.tenant_bk LIKE '%one_barn_ai%'
    AND tp.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'One_Barn_AI tenant not found';
    END IF;
    
    RAISE NOTICE 'Found One_Barn_AI tenant: %', encode(v_tenant_hk, 'hex');
    
    -- Veterinary Specialist (using ADMINISTRATOR role)
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'vet@onebarnai.com',
        p_password := 'VetSpecialist2025!',
        p_first_name := 'Dr. Sarah',
        p_last_name := 'Mitchell',
        p_role_bk := 'ADMINISTRATOR',
        p_user_hk := v_user_hk
    );
    RAISE NOTICE 'Created veterinary specialist user: %', encode(v_user_hk, 'hex');
    
    -- AI Technical Lead (using MANAGER role)
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'tech@onebarnai.com',
        p_password := 'TechLead2025!',
        p_first_name := 'Marcus',
        p_last_name := 'Rodriguez',
        p_role_bk := 'MANAGER',
        p_user_hk := v_user_hk
    );
    RAISE NOTICE 'Created technical lead user: %', encode(v_user_hk, 'hex');
    
    -- Business Development Manager (using USER role)
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'business@onebarnai.com',
        p_password := 'BizDev2025!',
        p_first_name := 'Jennifer',
        p_last_name := 'Park',
        p_role_bk := 'USER',
        p_user_hk := v_user_hk
    );
    RAISE NOTICE 'Created business development user: %', encode(v_user_hk, 'hex');
    
    RAISE NOTICE 'All One_Barn_AI team members created successfully';
END $$;

-- ========================================================================
-- FINAL VERIFICATION (CORRECTED QUERIES)
-- ========================================================================

-- Verify all users created
SELECT 
    'FINAL_VERIFICATION' as check_type,
    COUNT(*) as count,
    CASE WHEN COUNT(*) >= 4 THEN '✅ SUCCESS' ELSE '⚠️ PARTIAL' END as status
FROM auth.user_h uh
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE th.tenant_bk LIKE '%one_barn_ai%'
AND tp.load_end_date IS NULL;

-- Show all created users (CORRECTED)
SELECT 
    'CREATED_USERS' as info_type,
    up.email,
    up.first_name,
    up.last_name,
    up.is_active,           -- ✅ FIXED: using up.is_active
    r.role_name
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
LEFT JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
LEFT JOIN auth.role_h rh ON url.role_hk = rh.role_hk
LEFT JOIN auth.role_profile_s r ON rh.role_hk = r.role_hk AND r.load_end_date IS NULL
WHERE th.tenant_bk LIKE '%one_barn_ai%'
AND tp.load_end_date IS NULL
AND up.load_end_date IS NULL
ORDER BY up.load_date;

-- Test API Authentication
SELECT 
    'AUTHENTICATION_TEST' as test_type,
    'Ready to test:' as instruction,
    'SELECT api.auth_login(''{"username": "admin@onebarnai.com", "password": "HorseHealth2025!", "ip_address": "127.0.0.1", "user_agent": "OneVault-Demo-Client", "auto_login": true}'');' as test_command;

-- ========================================================================
-- SUCCESS SUMMARY
-- ========================================================================

SELECT 
    '🎯 ONE BARN AI SETUP COMPLETE!' as summary,
    'Tenant and admin created successfully!' as status,
    'Continue with user creation above' as next_step; 