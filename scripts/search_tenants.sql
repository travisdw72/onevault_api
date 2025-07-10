-- ========================================================================
-- TENANT SEARCH AND INVESTIGATION
-- ========================================================================
-- Let's see what tenants exist and investigate the strange behavior

RAISE NOTICE '🔍 === TENANT SEARCH AND INVESTIGATION ===';
RAISE NOTICE '';

-- ================================
-- 1. ALL TENANTS (ACTIVE)
-- ================================
RAISE NOTICE '--- 1. ALL ACTIVE TENANTS ---';

SELECT 
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    tp.tenant_name,
    tp.load_date as created_date,
    tp.load_end_date,
    th.record_source
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.load_end_date IS NULL
ORDER BY tp.load_date DESC;

-- ================================
-- 2. SEARCH FOR 'one_barn' SPECIFICALLY  
-- ================================
RAISE NOTICE '';
RAISE NOTICE '--- 2. SEARCHING FOR ONE_BARN TENANTS ---';

SELECT 
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    tp.tenant_name,
    tp.load_date as created_date,
    tp.load_end_date,
    CASE WHEN tp.load_end_date IS NULL THEN 'ACTIVE' ELSE 'INACTIVE' END as status
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE LOWER(tp.tenant_name) LIKE '%one_barn%'
   OR LOWER(tp.tenant_name) LIKE '%onebarn%'
   OR LOWER(tp.tenant_name) LIKE '%barn%'
ORDER BY tp.load_date DESC;

-- ================================
-- 3. COUNT USERS PER TENANT
-- ================================
RAISE NOTICE '';
RAISE NOTICE '--- 3. USER COUNTS PER TENANT ---';

SELECT 
    tp.tenant_name,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    COUNT(uh.user_hk) as user_count,
    string_agg(up.email, ', ') as user_emails
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
LEFT JOIN auth.user_h uh ON th.tenant_hk = uh.tenant_hk
LEFT JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk AND up.load_end_date IS NULL
WHERE tp.load_end_date IS NULL
GROUP BY th.tenant_hk, tp.tenant_name
ORDER BY user_count DESC;

-- ================================
-- 4. RECENT TENANT ACTIVITY
-- ================================
RAISE NOTICE '';
RAISE NOTICE '--- 4. RECENT TENANT ACTIVITY (LAST 7 DAYS) ---';

SELECT 
    tp.tenant_name,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    tp.load_date as created_date,
    CASE WHEN tp.load_end_date IS NULL THEN 'ACTIVE' ELSE 'INACTIVE' END as status
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.load_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY tp.load_date DESC;

-- ================================
-- 5. CHECK TENANT BUSINESS KEYS
-- ================================
RAISE NOTICE '';
RAISE NOTICE '--- 5. TENANT BUSINESS KEYS ---';

SELECT 
    th.tenant_bk,
    tp.tenant_name,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    tp.load_date as created_date
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.load_end_date IS NULL
ORDER BY tp.load_date DESC;

-- ================================
-- 6. AUDIT EVENT INVESTIGATION  
-- ================================
RAISE NOTICE '';
RAISE NOTICE '--- 6. RECENT AUDIT EVENTS (LAST 24 HOURS) ---';

SELECT 
    encode(audit_event_hk, 'hex') as audit_event_hk_hex,
    audit_event_bk,
    load_date,
    record_source
FROM audit.audit_event_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY load_date DESC
LIMIT 10; 