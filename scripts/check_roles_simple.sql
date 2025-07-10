-- ========================================================================
-- SIMPLE ROLE CHECK - DISCOVER ACTUAL TABLE STRUCTURE
-- ========================================================================

-- Step 1: Check what tables exist in auth schema
SELECT 
    'AUTH_TABLES' as info_type,
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'auth'
AND table_name LIKE '%role%'
ORDER BY table_name;

-- Step 2: Check the structure of role_h table
SELECT 
    'ROLE_H_COLUMNS' as info_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'auth'
AND table_name = 'role_h'
ORDER BY ordinal_position;

-- Step 3: Simple check - what's in role_h table for our tenant
SELECT 
    'ROLES_IN_ROLE_H' as info_type,
    rh.role_bk,
    rh.load_date,
    encode(rh.role_hk, 'hex') as role_hk_hex,
    encode(rh.tenant_hk, 'hex') as tenant_hk_hex
FROM auth.role_h rh
JOIN auth.tenant_h th ON rh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL
ORDER BY rh.role_bk;

-- Step 4: Check what satellite tables exist for roles
SELECT 
    'ROLE_SATELLITES' as info_type,
    table_name
FROM information_schema.tables 
WHERE table_schema = 'auth'
AND table_name LIKE '%role%_s'
ORDER BY table_name;

-- Step 5: Check what roles exist across ALL tenants (simple version)
SELECT DISTINCT
    'ALL_ROLE_BKS' as info_type,
    role_bk,
    COUNT(*) as tenant_count
FROM auth.role_h
GROUP BY role_bk
ORDER BY role_bk;

-- Step 6: Check what the admin user is linked to
SELECT 
    'ADMIN_USER_ROLE_LINKS' as info_type,
    up.email,
    encode(url.user_hk, 'hex') as user_hk_hex,
    encode(url.role_hk, 'hex') as role_hk_hex,
    rh.role_bk
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
JOIN auth.role_h rh ON url.role_hk = rh.role_hk
WHERE up.email = 'admin@onebarnai.com'
AND up.load_end_date IS NULL; 