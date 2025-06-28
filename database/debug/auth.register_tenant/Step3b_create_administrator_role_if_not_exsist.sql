-- =============================================
-- STEP 3B: CREATE ADMINISTRATOR ROLE FOR THE ONE SPA
-- =============================================
-- The default role template doesn't include an "Administrator" role
-- We need to create it manually for full tenant admin access

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_role_hk BYTEA;
    v_role_bk VARCHAR(255);
    v_tenant_name VARCHAR(100);
BEGIN
    -- Get The ONE Spa tenant hash key and name
    SELECT th.tenant_hk, tps.tenant_name INTO v_tenant_hk, v_tenant_name
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
    WHERE tps.contact_email LIKE '%theonespaoregon.com%'
    AND tps.load_end_date IS NULL
    LIMIT 1;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'The ONE Spa tenant not found';
    END IF;
    
    -- Generate Administrator role identifiers
    v_role_bk := v_tenant_name || '_ADMINISTRATOR';
    v_role_hk := util.hash_binary(v_role_bk);
    
    -- Create Administrator role hub
    INSERT INTO auth.role_h (
        role_hk,
        role_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_role_hk,
        v_role_bk,
        v_tenant_hk,
        util.current_load_date(),
        'manual_admin_role_creation'
    ) ON CONFLICT (role_hk) DO NOTHING;
    
    -- Create Administrator role definition with full permissions
    INSERT INTO auth.role_definition_s (
        role_hk,
        load_date,
        hash_diff,
        role_name,
        role_description,
        is_system_role,
        permissions,
        created_date,
        record_source
    ) VALUES (
        v_role_hk,
        util.current_load_date(),
        util.hash_binary('Administrator' || 'Full tenant administrative access'),
        'Administrator',
        'Complete administrative access for tenant operations, user management, and system configuration',
        FALSE,
        jsonb_build_object(
            'user_management', true,
            'system_administration', true,
            'data_access_level', 'full',
            'reporting_access', true,
            'security_management', true,
            'audit_access', true,
            'tenant_configuration', true,
            'role_management', true,
            'billing_access', true
        ),
        CURRENT_TIMESTAMP,
        'manual_admin_role_creation'
    ) ON CONFLICT (role_hk, load_date) DO NOTHING;
    
    RAISE NOTICE '✅ SUCCESS: Administrator role created for "%"', v_tenant_name;
    RAISE NOTICE '   Role: Administrator';
    RAISE NOTICE '   Permissions: Full tenant access';
END $$;

-- Verify the Administrator role was created
SELECT 
    tps.tenant_name,
    rds.role_name,
    rds.role_description,
    rds.permissions
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
JOIN auth.role_h rh ON th.tenant_hk = rh.tenant_hk
JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
WHERE tps.contact_email LIKE '%theonespaoregon.com%'
AND rds.role_name = 'Administrator'
AND tps.load_end_date IS NULL
AND rds.load_end_date IS NULL; 