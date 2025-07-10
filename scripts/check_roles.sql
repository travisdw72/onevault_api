-- ========================================================================
-- CHECK AVAILABLE ROLES FOR ONE BARN AI TENANT
-- ========================================================================
-- Quick diagnostic to see what roles were created with the tenant

-- Get the One Barn AI tenant HK
SELECT 
    'TENANT_INFO' as info_type,
    th.tenant_bk,
    tp.tenant_name,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- Check all roles for One Barn AI tenant
SELECT 
    'AVAILABLE_ROLES' as info_type,
    rh.role_bk,
    rp.role_name,
    rp.role_description,
    rp.is_active,
    encode(rh.role_hk, 'hex') as role_hk_hex
FROM auth.role_h rh
JOIN auth.role_profile_s rp ON rh.role_hk = rp.role_hk
JOIN auth.tenant_h th ON rh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL
AND rp.load_end_date IS NULL
ORDER BY rp.role_name;

-- Check all roles across all tenants (for comparison)
SELECT 
    'ALL_SYSTEM_ROLES' as info_type,
    rh.role_bk,
    rp.role_name,
    COUNT(*) as tenant_count
FROM auth.role_h rh
JOIN auth.role_profile_s rp ON rh.role_hk = rp.role_hk
WHERE rp.load_end_date IS NULL
GROUP BY rh.role_bk, rp.role_name
ORDER BY rp.role_name;

-- Check what roles the admin user actually has
SELECT 
    'ADMIN_USER_ROLES' as info_type,
    up.email,
    rp.role_name,
    rh.role_bk
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
JOIN auth.role_h rh ON url.role_hk = rh.role_hk
JOIN auth.role_profile_s rp ON rh.role_hk = rp.role_hk
WHERE up.email = 'admin@onebarnai.com'
AND up.load_end_date IS NULL
AND rp.load_end_date IS NULL; 