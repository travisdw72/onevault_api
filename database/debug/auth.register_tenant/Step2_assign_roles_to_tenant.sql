-- Step 1: Create default roles for The ONE Spa tenant
DO $$
DECLARE
    v_tenant_hk BYTEA;
BEGIN
    -- Get The ONE Spa tenant hash key
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
    WHERE tps.contact_email LIKE '%theonespaoregon.com%'
    AND tps.load_end_date IS NULL
    LIMIT 1;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'The ONE Spa tenant not found';
    END IF;
    
    -- Create all default roles for this tenant
    PERFORM auth.create_tenant_default_roles(v_tenant_hk);
    
    RAISE NOTICE '✅ Default roles created for The ONE Spa tenant';
END $$;