-- =============================================
-- STEP 3: ASSIGN TRAVIS ADMINISTRATOR ROLE
-- =============================================
-- This script assigns travis@theonespaoregon.com the Administrator role
-- for The ONE Spa tenant, completing the role assignment process.

-- Step 3: Assign Travis the Administrator role
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_role_hk BYTEA;
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
    
    -- Get Travis user hash key
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
    WHERE ups.email = 'travis@theonespaoregon.com'
    AND uh.tenant_hk = v_tenant_hk
    AND ups.load_end_date IS NULL
    LIMIT 1;
    
    IF v_user_hk IS NULL THEN
        RAISE EXCEPTION 'Travis user not found in The ONE Spa tenant';
    END IF;
    
    -- Get Administrator role hash key for this tenant
    SELECT rh.role_hk INTO v_role_hk
    FROM auth.role_h rh
    JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
    WHERE rh.tenant_hk = v_tenant_hk
    AND rds.role_name = 'Administrator'
    AND rds.load_end_date IS NULL
    LIMIT 1;
    
    IF v_role_hk IS NULL THEN
        RAISE EXCEPTION 'Administrator role not found for The ONE Spa tenant';
    END IF;
    
    -- Assign Administrator role to Travis
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
        'travis_admin_assignment'
    ) ON CONFLICT (link_user_role_hk) DO NOTHING;
    
    RAISE NOTICE '✅ SUCCESS: Travis assigned Administrator role for "%"', v_tenant_name;
    RAISE NOTICE '   User: travis@theonespaoregon.com';
    RAISE NOTICE '   Role: Administrator';
    RAISE NOTICE '   Tenant: %', v_tenant_name;
END $$;

-- Step 4: Verify Travis now has the Administrator role
SELECT 
    ups.email,
    ups.first_name,
    ups.last_name,
    tps.tenant_name,
    rds.role_name,
    rds.role_description,
    url.load_date as role_assigned_date
FROM auth.user_profile_s ups
JOIN auth.user_h uh ON ups.user_hk = uh.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
JOIN auth.role_h rh ON url.role_hk = rh.role_hk
JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
WHERE ups.email = 'travis@theonespaoregon.com'
AND ups.load_end_date IS NULL
AND tps.load_end_date IS NULL
AND rds.load_end_date IS NULL; 