-- ========================================================================
-- ONE BARN AI - SETUP VERIFICATION
-- ========================================================================
-- Run these queries after setup to verify everything worked correctly
-- Expected: 1 tenant, 6 roles, 5 users, 5 role assignments
-- ========================================================================

\echo '🐎🤖 === ONE BARN AI SETUP VERIFICATION ==='
\echo ''

-- 1. Verify tenant created
\echo '--- 1. TENANT VERIFICATION ---'
SELECT 
    'TENANT_CHECK' as verification_type,
    tp.tenant_name,
    encode(th.tenant_hk, 'hex') as tenant_hk,
    tp.load_date,
    'Should be: one_barn_ai' as expected
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- 2. Verify roles created (should be 6)
\echo ''
\echo '--- 2. ROLES VERIFICATION ---'
SELECT 
    'ROLE_COUNT' as verification_type,
    COUNT(*) as actual_count,
    6 as expected_count,
    CASE WHEN COUNT(*) = 6 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM auth.role_h rh
JOIN auth.tenant_h th ON rh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- 3. List all roles
\echo ''
\echo '--- 3. ROLE DETAILS ---'
SELECT 
    'ROLE_LIST' as verification_type,
    CASE 
        WHEN rh.role_bk LIKE '%_ADMINISTRATOR' THEN 'ADMINISTRATOR'
        WHEN rh.role_bk LIKE '%_MANAGER' THEN 'MANAGER'
        WHEN rh.role_bk LIKE '%_ANALYST' THEN 'ANALYST'
        WHEN rh.role_bk LIKE '%_AUDITOR' THEN 'AUDITOR'
        WHEN rh.role_bk LIKE '%_USER' THEN 'USER'
        WHEN rh.role_bk LIKE '%_VIEWER' THEN 'VIEWER'
        ELSE 'UNKNOWN'
    END as role_type,
    rh.role_bk,
    encode(rh.role_hk, 'hex') as role_hk
FROM auth.role_h rh
JOIN auth.tenant_h th ON rh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL
ORDER BY role_type;

-- 4. Verify users created (should be 5: 1 admin + 4 demo users)
\echo ''
\echo '--- 4. USERS VERIFICATION ---'
SELECT 
    'USER_COUNT' as verification_type,
    COUNT(*) as actual_count,
    5 as expected_count,
    CASE WHEN COUNT(*) = 5 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM auth.user_h uh
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- 5. List all users with their roles
\echo ''
\echo '--- 5. USER & ROLE ASSIGNMENTS ---'
SELECT 
    'USER_ROLES' as verification_type,
    up.email,
    up.first_name,
    up.last_name,
    CASE 
        WHEN rh.role_bk LIKE '%_ADMINISTRATOR' THEN 'ADMINISTRATOR'
        WHEN rh.role_bk LIKE '%_MANAGER' THEN 'MANAGER'
        WHEN rh.role_bk LIKE '%_ANALYST' THEN 'ANALYST'
        WHEN rh.role_bk LIKE '%_AUDITOR' THEN 'AUDITOR'
        WHEN rh.role_bk LIKE '%_USER' THEN 'USER'
        WHEN rh.role_bk LIKE '%_VIEWER' THEN 'VIEWER'
        ELSE 'UNKNOWN'
    END as assigned_role,
    encode(uh.user_hk, 'hex') as user_hk
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
JOIN auth.role_h rh ON url.role_hk = rh.role_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL
AND up.load_end_date IS NULL
ORDER BY up.email;

-- 6. Verify role assignments count (should be 5)
\echo ''
\echo '--- 6. ROLE ASSIGNMENTS COUNT ---'
SELECT 
    'ASSIGNMENT_COUNT' as verification_type,
    COUNT(*) as actual_assignments,
    5 as expected_assignments,
    CASE WHEN COUNT(*) = 5 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM auth.user_role_l url
JOIN auth.user_h uh ON url.user_hk = uh.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- 7. Final summary
\echo ''
\echo '--- 7. SETUP SUMMARY ---'
SELECT 
    'FINAL_STATUS' as verification_type,
    (SELECT tp.tenant_name FROM auth.tenant_h th 
     JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk 
     WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL) as tenant_name,
    (SELECT COUNT(*) FROM auth.role_h rh 
     JOIN auth.tenant_h th ON rh.tenant_hk = th.tenant_hk 
     JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk 
     WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL) as roles_created,
    (SELECT COUNT(*) FROM auth.user_h uh 
     JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk 
     JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk 
     WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL) as users_created,
    (SELECT COUNT(*) FROM auth.user_role_l url 
     JOIN auth.user_h uh ON url.user_hk = uh.user_hk 
     JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk 
     JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk 
     WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL) as role_assignments;

\echo ''
\echo '🎯 === EXPECTED RESULTS ==='
\echo 'Tenant: one_barn_ai ✅'
\echo 'Roles: 6 (ADMINISTRATOR, MANAGER, ANALYST, AUDITOR, USER, VIEWER) ✅'
\echo 'Users: 5 (admin + travis + michelle + sarah + demo) ✅'
\echo 'Role Assignments: 5 (one per user) ✅'
\echo ''
\echo '🐎🤖 If all checks show ✅ PASS, setup is ready for July 7, 2025 demo!' 