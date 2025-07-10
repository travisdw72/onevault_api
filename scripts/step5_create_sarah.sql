-- ========================================================================
-- STEP 5: CREATE SARAH ROBERTSON (VP BUSINESS DEVELOPMENT)
-- ========================================================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_manager_role_bk VARCHAR;
    v_business_user_hk BYTEA;
    v_existing_user_count INTEGER;
BEGIN
    RAISE NOTICE '👤 === STEP 5: CREATE SARAH ROBERTSON (VP BUSINESS DEVELOPMENT) ===';
    RAISE NOTICE '';
    
    -- Get tenant
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RAISE NOTICE '❌ ERROR: one_barn_ai tenant not found!';
        RAISE NOTICE 'Please run step1_create_tenant.sql first';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Found tenant: %', encode(v_tenant_hk, 'hex');
    
    -- Check if Sarah already exists
    SELECT COUNT(*) INTO v_existing_user_count
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'sarah.robertson@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_existing_user_count > 0 THEN
        RAISE NOTICE '⚠️  Sarah Robertson already exists - skipping';
        RAISE NOTICE '🎯 Now run step6_create_demo.sql';
        RETURN;
    END IF;
    
    -- Get manager role
    SELECT role_bk INTO v_manager_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk 
    AND role_bk LIKE '%_MANAGER'
    LIMIT 1;
    
    RAISE NOTICE '✅ Using role: %', v_manager_role_bk;
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Creating Sarah Robertson...';
    
    -- Create user
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'sarah.robertson@onebarnai.com',
        p_password := 'VPBusinessDev789!',
        p_first_name := 'Sarah',
        p_last_name := 'Robertson',
        p_role_bk := v_manager_role_bk,
        p_user_hk := v_business_user_hk
    );
    
    RAISE NOTICE '✅ SUCCESS: Sarah Robertson created!';
    RAISE NOTICE 'User HK: %', encode(v_business_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Now run step6_create_demo.sql';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ FAILED to create Sarah Robertson';
    RAISE NOTICE 'Error: %', SQLERRM;
    RAISE NOTICE 'SQL State: %', SQLSTATE;
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Troubleshooting options:';
    RAISE NOTICE '1. Run step2_clear_audit.sql again';
    RAISE NOTICE '2. Wait 30 seconds and try again';
    RAISE NOTICE '3. Check audit table for conflicts';
    
END $$; 