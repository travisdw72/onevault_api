-- ========================================================================
-- STEP 3: CREATE TRAVIS WOODWARD (CEO)
-- ========================================================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_role_bk VARCHAR;
    v_ceo_user_hk BYTEA;
    v_existing_user_count INTEGER;
BEGIN
    RAISE NOTICE '👤 === STEP 3: CREATE TRAVIS WOODWARD (CEO) ===';
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
    
    -- Check if Travis already exists
    SELECT COUNT(*) INTO v_existing_user_count
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'travis.woodward@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_existing_user_count > 0 THEN
        RAISE NOTICE '⚠️  Travis Woodward already exists - skipping';
        RAISE NOTICE '🎯 Now run step4_create_michelle.sql';
        RETURN;
    END IF;
    
    -- Get admin role
    SELECT role_bk INTO v_admin_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk 
    AND role_bk LIKE '%_ADMINISTRATOR'
    LIMIT 1;
    
    RAISE NOTICE '✅ Using role: %', v_admin_role_bk;
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Creating Travis Woodward...';
    
    -- Create user
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'travis.woodward@onebarnai.com',
        p_password := 'SecurePass123!',
        p_first_name := 'Travis',
        p_last_name := 'Woodward',
        p_role_bk := v_admin_role_bk,
        p_user_hk := v_ceo_user_hk
    );
    
    RAISE NOTICE '✅ SUCCESS: Travis Woodward created!';
    RAISE NOTICE 'User HK: %', encode(v_ceo_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Now run step4_create_michelle.sql';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ FAILED to create Travis Woodward';
    RAISE NOTICE 'Error: %', SQLERRM;
    RAISE NOTICE 'SQL State: %', SQLSTATE;
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Troubleshooting options:';
    RAISE NOTICE '1. Run step2_clear_audit.sql again';
    RAISE NOTICE '2. Check if there are other audit conflicts';
    RAISE NOTICE '3. Try creating user manually without audit system';
    
END $$; 