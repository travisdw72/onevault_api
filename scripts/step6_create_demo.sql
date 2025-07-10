-- ========================================================================
-- STEP 6: CREATE DEMO USER (FOR PRESENTATIONS)
-- ========================================================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_role_bk VARCHAR;
    v_demo_user_hk BYTEA;
    v_existing_user_count INTEGER;
BEGIN
    RAISE NOTICE '👤 === STEP 6: CREATE DEMO USER (FOR PRESENTATIONS) ===';
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
    
    -- Check if Demo User already exists
    SELECT COUNT(*) INTO v_existing_user_count
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'demo@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_existing_user_count > 0 THEN
        RAISE NOTICE '⚠️  Demo User already exists - skipping';
        RAISE NOTICE '🎯 Now run step7_final_verification.sql';
        RETURN;
    END IF;
    
    -- Get user role
    SELECT role_bk INTO v_user_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk 
    AND role_bk LIKE '%_USER'
    LIMIT 1;
    
    RAISE NOTICE '✅ Using role: %', v_user_role_bk;
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Creating Demo User...';
    
    -- Create user
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'demo@onebarnai.com',
        p_password := 'Demo123!',
        p_first_name := 'Demo',
        p_last_name := 'User',
        p_role_bk := v_user_role_bk,
        p_user_hk := v_demo_user_hk
    );
    
    RAISE NOTICE '✅ SUCCESS: Demo User created!';
    RAISE NOTICE 'User HK: %', encode(v_demo_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '🎉 ALL USERS CREATED SUCCESSFULLY!';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Now run step7_final_verification.sql to confirm everything';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ FAILED to create Demo User';
    RAISE NOTICE 'Error: %', SQLERRM;
    RAISE NOTICE 'SQL State: %', SQLSTATE;
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Troubleshooting options:';
    RAISE NOTICE '1. Run step2_clear_audit.sql again';
    RAISE NOTICE '2. Wait 30 seconds and try again';
    RAISE NOTICE '3. Check audit table for conflicts';
    
END $$; 