-- Quick Tenant Check
-- Simple query to see what's in the database

-- Check for one_barn_ai specifically
SELECT 
    'one_barn_ai tenant search' as search_type,
    encode(th.tenant_hk, 'hex') as tenant_hk,
    tp.tenant_name,
    tp.load_date,
    CASE WHEN tp.load_end_date IS NULL THEN 'ACTIVE' ELSE 'INACTIVE' END as status
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
ORDER BY tp.load_date DESC;

-- Show all tenants if no one_barn_ai found
SELECT 
    'all tenants' as search_type,
    encode(th.tenant_hk, 'hex') as tenant_hk,
    tp.tenant_name,
    tp.load_date,
    CASE WHEN tp.load_end_date IS NULL THEN 'ACTIVE' ELSE 'INACTIVE' END as status
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.load_end_date IS NULL
ORDER BY tp.load_date DESC
LIMIT 10; 