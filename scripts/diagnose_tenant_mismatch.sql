-- ========================================================================
-- DIAGNOSE TENANT MISMATCH - FIND ALL ONE_BARN_AI TENANTS
-- ========================================================================

-- Step 1: Find ALL one_barn_ai tenants
SELECT 
    'ALL_ONE_BARN_TENANTS' as info_type,
    tp.tenant_name,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    tp.load_date,
    tp.load_end_date,
    tp.record_source
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
ORDER BY tp.load_date DESC;

-- Step 2: Check what tenant has the roles
SELECT 
    'TENANT_WITH_ROLES' as info_type,
    tp.tenant_name,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    COUNT(rh.role_hk) as role_count
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
LEFT JOIN auth.role_h rh ON th.tenant_hk = rh.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL
GROUP BY th.tenant_hk, tp.tenant_name
ORDER BY role_count DESC;

-- Step 3: Check roles for the tenant we WANT to use
SELECT 
    'ROLES_FOR_CURRENT_TENANT' as info_type,
    rh.role_bk,
    encode(rh.role_hk, 'hex') as role_hk_hex
FROM auth.role_h rh
WHERE rh.tenant_hk = decode('518a00fd8cb1b99f7f214dbdc465d0d75fe738dfccff79d7baabb7c102eebc95', 'hex')
ORDER BY rh.role_bk;

-- Step 4: Check roles for the tenant that HAS roles
SELECT 
    'ROLES_FOR_ROLES_TENANT' as info_type,
    rh.role_bk,
    encode(rh.role_hk, 'hex') as role_hk_hex,
    encode(rh.tenant_hk, 'hex') as tenant_hk_hex
FROM auth.role_h rh
WHERE rh.tenant_hk = decode('518a00fd8cb1b99f7f214dbdc465d0d75fe738dfccff79d7baabb7c102eebc95', 'hex')
ORDER BY rh.role_bk;

-- Step 5: Check if our current tenant was created successfully in Phase 1
SELECT 
    'PHASE1_TENANT_CHECK' as info_type,
    tp.tenant_name,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    tp.load_date,
    'Phase 1 tenant creation' as notes
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE th.tenant_hk = decode('518a00fd8cb1b99f7f214dbdc465d0d75fe738dfccff79d7baabb7c102eebc95', 'hex')
AND tp.load_end_date IS NULL; 