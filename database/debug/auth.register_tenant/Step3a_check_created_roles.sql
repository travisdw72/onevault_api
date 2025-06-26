-- =============================================
-- STEP 3A: DIAGNOSTIC - CHECK CREATED ROLES
-- =============================================
-- Let's see what roles were actually created for The ONE Spa tenant

-- Check what roles exist for The ONE Spa tenant
SELECT 
    tps.tenant_name,
    rds.role_name,
    rds.role_description,
    rds.is_system_role,
    rds.created_date
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
JOIN auth.role_h rh ON th.tenant_hk = rh.tenant_hk
JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
WHERE tps.contact_email LIKE '%theonespaoregon.com%'
AND tps.load_end_date IS NULL
AND rds.load_end_date IS NULL
ORDER BY rds.created_date DESC;

-- Also check if there are any similar role names
SELECT 
    rds.role_name,
    rds.role_description
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
JOIN auth.role_h rh ON th.tenant_hk = rh.tenant_hk
JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
WHERE tps.contact_email LIKE '%theonespaoregon.com%'
AND tps.load_end_date IS NULL
AND rds.load_end_date IS NULL
AND (LOWER(rds.role_name) LIKE '%admin%' 
     OR LOWER(rds.role_name) LIKE '%manager%'
     OR LOWER(rds.role_description) LIKE '%admin%'); 