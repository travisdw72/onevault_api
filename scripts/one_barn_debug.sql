-- ========================================================================
-- ONE BARN AI - DIAGNOSTIC SCRIPT
-- ========================================================================
-- Issue: Tenant was created successfully but can't be found by our query
-- Let's see what's actually in the database

-- ========================================================================
-- STEP 1: CHECK ALL TENANTS
-- ========================================================================

SELECT 
    'ALL_TENANTS' as check_type,
    th.tenant_bk,
    tp.tenant_name,
    tp.is_active,
    tp.load_date,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex
FROM auth.tenant_h th
LEFT JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.load_end_date IS NULL OR tp.load_end_date IS NULL
ORDER BY tp.load_date DESC
LIMIT 10;

-- ========================================================================
-- STEP 2: SEARCH FOR ONE_BARN SPECIFICALLY
-- ========================================================================

-- Try different search patterns
SELECT 
    'SEARCH_PATTERNS' as check_type,
    'Pattern: tenant_bk LIKE %one_barn_ai%' as pattern,
    COUNT(*) as matches
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE th.tenant_bk LIKE '%one_barn_ai%'
AND tp.load_end_date IS NULL

UNION ALL

SELECT 
    'SEARCH_PATTERNS' as check_type,
    'Pattern: tenant_name LIKE %one_barn%' as pattern,
    COUNT(*) as matches
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name LIKE '%one_barn%'
AND tp.load_end_date IS NULL

UNION ALL

SELECT 
    'SEARCH_PATTERNS' as check_type,
    'Pattern: tenant_name = one_barn_ai' as pattern,
    COUNT(*) as matches
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- ========================================================================
-- STEP 3: CHECK RECENT TENANTS (LAST HOUR)
-- ========================================================================

SELECT 
    'RECENT_TENANTS' as check_type,
    th.tenant_bk,
    tp.tenant_name,
    tp.is_active,
    tp.load_date,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex
FROM auth.tenant_h th
LEFT JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE th.load_date >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
ORDER BY th.load_date DESC;

-- ========================================================================
-- STEP 4: DIRECT LOOKUP BY KNOWN TENANT HK
-- ========================================================================

-- We know the tenant HK from the success message
SELECT 
    'DIRECT_LOOKUP' as check_type,
    th.tenant_bk,
    tp.tenant_name,
    tp.is_active,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex
FROM auth.tenant_h th
LEFT JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE th.tenant_hk = decode('a812fc66f97c05ecd7f5ead025394a831f6886117c74242c2709253f9cc9e399', 'hex');

-- ========================================================================
-- STEP 5: CHECK IF TENANT_PROFILE_S EXISTS
-- ========================================================================

-- Check if the tenant hub exists but profile is missing
SELECT 
    'HUB_WITHOUT_PROFILE' as check_type,
    th.tenant_bk,
    th.load_date,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    CASE WHEN tp.tenant_hk IS NULL THEN 'MISSING_PROFILE' ELSE 'HAS_PROFILE' END as profile_status
FROM auth.tenant_h th
LEFT JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk AND tp.load_end_date IS NULL
WHERE th.load_date >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
ORDER BY th.load_date DESC;

-- ========================================================================
-- SOLUTION: USE DIRECT TENANT HK (GUARANTEED TO WORK)
-- ========================================================================

-- If diagnostics show the tenant exists, use this approach:
DO $$
DECLARE
    v_tenant_hk BYTEA := decode('a812fc66f97c05ecd7f5ead025394a831f6886117c74242c2709253f9cc9e399', 'hex');
    v_user_hk BYTEA;
    v_tenant_exists BOOLEAN := FALSE;
BEGIN
    -- Verify the tenant exists
    SELECT EXISTS(
        SELECT 1 FROM auth.tenant_h 
        WHERE tenant_hk = v_tenant_hk
    ) INTO v_tenant_exists;
    
    IF NOT v_tenant_exists THEN
        RAISE EXCEPTION 'Tenant with HK % does not exist', encode(v_tenant_hk, 'hex');
    END IF;
    
    RAISE NOTICE 'Using direct tenant HK: %', encode(v_tenant_hk, 'hex');
    
    -- Create additional users using the known tenant HK
    
    -- Veterinary Specialist
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
    
    -- AI Technical Lead
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
    
    -- Business Development Manager
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
    
    RAISE NOTICE 'All One_Barn_AI team members created successfully using direct tenant HK!';
END $$;

-- ========================================================================
-- FINAL VERIFICATION USING DIRECT TENANT HK
-- ========================================================================

SELECT 
    'FINAL_USER_COUNT' as check_type,
    COUNT(*) as user_count,
    CASE WHEN COUNT(*) >= 4 THEN '✅ SUCCESS' ELSE '⚠️ PARTIAL' END as status
FROM auth.user_h uh
WHERE uh.tenant_hk = decode('a812fc66f97c05ecd7f5ead025394a831f6886117c74242c2709253f9cc9e399', 'hex');

-- Show all users for this tenant
SELECT 
    'TENANT_USERS' as info_type,
    up.email,
    up.first_name,
    up.last_name,
    up.is_active,
    encode(uh.user_hk, 'hex') as user_hk_hex
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
WHERE uh.tenant_hk = decode('a812fc66f97c05ecd7f5ead025394a831f6886117c74242c2709253f9cc9e399', 'hex')
AND up.load_end_date IS NULL
ORDER BY up.load_date; 