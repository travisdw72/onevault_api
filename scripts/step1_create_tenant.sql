-- ========================================================================
-- STEP 1: CREATE TENANT ONLY
-- ========================================================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_existing_tenant_hk BYTEA;
BEGIN
    RAISE NOTICE '🐎🤖 === STEP 1: CREATE TENANT ONLY ===';
    RAISE NOTICE '';
    
    -- Check for existing tenant
    SELECT th.tenant_hk INTO v_existing_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
    AND tp.load_end_date IS NULL;
    
    IF v_existing_tenant_hk IS NOT NULL THEN
        RAISE NOTICE '⚠️  Found existing tenant: %', encode(v_existing_tenant_hk, 'hex');
        RAISE NOTICE 'STEP 1 ALREADY COMPLETE';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Creating new tenant...';
    
    -- Create tenant
    SELECT tenant_hk, admin_user_hk
    INTO v_tenant_hk, v_admin_user_hk
    FROM auth.register_tenant_with_roles(
        p_tenant_name := 'one_barn_ai',
        p_admin_email := 'admin@onebarnai.com',
        p_admin_password := 'AdminPass123!',
        p_admin_first_name := 'System',
        p_admin_last_name := 'Administrator'
    );
    
    RAISE NOTICE '✅ STEP 1 COMPLETE';
    RAISE NOTICE 'Tenant HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE 'Admin User HK: %', encode(v_admin_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Now run step2_clear_audit.sql';
    
END $$; 