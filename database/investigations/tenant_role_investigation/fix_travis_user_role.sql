-- Fix Script for Travis User Role Assignment
-- Generated on: 2025-06-26T13:54:40.297420
-- Target User: travis@theonespaoregon.com

-- Step 1: Create Administrator Role for Tenant (if not exists)
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_role_hk BYTEA;
    v_role_bk VARCHAR(255);
    v_user_hk BYTEA;
BEGIN
    -- Get tenant hash key for theonespaoregon.com
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
    WHERE tps.contact_email LIKE '%theonespaoregon.com%'
    AND tps.load_end_date IS NULL
    LIMIT 1;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'Tenant not found for theonespaoregon.com';
    END IF;
    
    -- Create Administrator role if it doesn't exist
    v_role_bk := 'ADMIN_ROLE_' || substring(encode(v_tenant_hk, 'hex'), 1, 8);
    v_role_hk := util.hash_binary(v_role_bk);
    
    -- Create role hub
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
        'manual_fix_script'
    ) ON CONFLICT (role_hk) DO NOTHING;
    
    -- Create role definition
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
        util.hash_binary('Administrator' || 'Full tenant access'),
        'Administrator',
        'Complete administrative access for tenant operations and user management',
        FALSE,
        jsonb_build_object(
            'user_management', true,
            'system_administration', true,
            'data_access_level', 'full',
            'reporting_access', true,
            'security_management', true,
            'audit_access', true
        ),
        CURRENT_TIMESTAMP,
        'manual_fix_script'
    ) ON CONFLICT (role_hk, load_date) DO NOTHING;
    
    -- Get travis user hash key
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
    WHERE ups.email = 'travis@theonespaoregon.com'
    AND uh.tenant_hk = v_tenant_hk
    AND ups.load_end_date IS NULL
    LIMIT 1;
    
    IF v_user_hk IS NULL THEN
        RAISE EXCEPTION 'User travis@theonespaoregon.com not found in tenant';
    END IF;
    
    -- Assign administrator role to travis
    INSERT INTO auth.user_role_l (
        link_user_role_hk,
        user_hk,
        role_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(v_user_hk::text || v_role_hk::text),
        v_user_hk,
        v_role_hk,
        v_tenant_hk,
        util.current_load_date(),
        'manual_fix_script'
    ) ON CONFLICT (link_user_role_hk) DO NOTHING;
    
    RAISE NOTICE 'SUCCESS: Administrator role assigned to travis@theonespaoregon.com';
    RAISE NOTICE 'Role HK: %', encode(v_role_hk, 'hex');
    RAISE NOTICE 'User HK: %', encode(v_user_hk, 'hex');
END $$;

-- Step 2: Verify the assignment
SELECT 
    ups.email,
    ups.first_name,
    ups.last_name,
    rds.role_name,
    rds.role_description,
    url.load_date as role_assigned_date
FROM auth.user_profile_s ups
JOIN auth.user_h uh ON ups.user_hk = uh.user_hk
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
JOIN auth.role_h rh ON url.role_hk = rh.role_hk
JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
WHERE ups.email = 'travis@theonespaoregon.com'
AND ups.load_end_date IS NULL
AND rds.load_end_date IS NULL;
