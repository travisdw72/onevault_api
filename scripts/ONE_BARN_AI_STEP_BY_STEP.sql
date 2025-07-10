-- ========================================================================
-- ONE BARN AI - STEP BY STEP SETUP (TRANSACTION ISOLATION)
-- ========================================================================
-- Each user created in separate transaction to avoid audit hash collisions

-- ================================
-- STEP 1: CLEANUP AND CREATE TENANT
-- ================================

-- Clear any existing data
DELETE FROM audit.audit_event_h WHERE load_date >= CURRENT_DATE;

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_existing_tenant_hk BYTEA;
BEGIN
    RAISE NOTICE '🐎 STEP 1: Creating One Barn AI Tenant';
    
    -- Check for existing tenant
    SELECT th.tenant_hk INTO v_existing_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
    AND tp.load_end_date IS NULL;
    
    IF v_existing_tenant_hk IS NOT NULL THEN
        RAISE NOTICE 'Removing existing tenant...';
        DELETE FROM auth.user_role_l WHERE tenant_hk = v_existing_tenant_hk;
        DELETE FROM auth.user_auth_s WHERE user_hk IN (SELECT user_hk FROM auth.user_h WHERE tenant_hk = v_existing_tenant_hk);
        DELETE FROM auth.user_profile_s WHERE user_hk IN (SELECT user_hk FROM auth.user_h WHERE tenant_hk = v_existing_tenant_hk);
        DELETE FROM auth.user_h WHERE tenant_hk = v_existing_tenant_hk;
        DELETE FROM auth.role_definition_s WHERE role_hk IN (SELECT role_hk FROM auth.role_h WHERE tenant_hk = v_existing_tenant_hk);
        DELETE FROM auth.role_h WHERE tenant_hk = v_existing_tenant_hk;
        DELETE FROM auth.tenant_profile_s WHERE tenant_hk = v_existing_tenant_hk;
        DELETE FROM auth.tenant_h WHERE tenant_hk = v_existing_tenant_hk;
    END IF;
    
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
    
    RAISE NOTICE '✅ Tenant Created: %', encode(v_tenant_hk, 'hex');
END $$;

COMMIT;

-- Wait 3 seconds
SELECT pg_sleep(3);

-- ================================
-- STEP 2: CREATE TRAVIS WOODWARD
-- ================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_role_bk VARCHAR;
    v_ceo_user_hk BYTEA;
BEGIN
    RAISE NOTICE '🐎 STEP 2: Creating Travis Woodward (CEO)';
    
    -- Get tenant info
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL;
    
    -- Get admin role
    SELECT role_bk INTO v_admin_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk AND role_bk LIKE '%_ADMINISTRATOR';
    
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
    
    RAISE NOTICE '✅ Travis Woodward Created';
END $$;

COMMIT;

-- Wait 2 seconds
SELECT pg_sleep(2);

-- ================================
-- STEP 3: CREATE MICHELLE NASH
-- ================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_manager_role_bk VARCHAR;
    v_tech_user_hk BYTEA;
BEGIN
    RAISE NOTICE '🐎 STEP 3: Creating Michelle Nash (Support Manager)';
    
    -- Get tenant info
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL;
    
    -- Get manager role
    SELECT role_bk INTO v_manager_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk AND role_bk LIKE '%_MANAGER';
    
    -- Create user
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'michelle.nash@onebarnai.com',
        p_password := 'SupportManager456!',
        p_first_name := 'Michelle',
        p_last_name := 'Nash',
        p_role_bk := v_manager_role_bk,
        p_user_hk := v_tech_user_hk
    );
    
    RAISE NOTICE '✅ Michelle Nash Created';
END $$;

COMMIT;

-- Wait 2 seconds
SELECT pg_sleep(2);

-- ================================
-- STEP 4: CREATE SARAH ROBERTSON
-- ================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_manager_role_bk VARCHAR;
    v_business_user_hk BYTEA;
BEGIN
    RAISE NOTICE '🐎 STEP 4: Creating Sarah Robertson (VP Business Development)';
    
    -- Get tenant info
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL;
    
    -- Get manager role
    SELECT role_bk INTO v_manager_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk AND role_bk LIKE '%_MANAGER';
    
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
    
    RAISE NOTICE '✅ Sarah Robertson Created';
END $$;

COMMIT;

-- Wait 2 seconds
SELECT pg_sleep(2);

-- ================================
-- STEP 5: CREATE DEMO USER
-- ================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_role_bk VARCHAR;
    v_demo_user_hk BYTEA;
BEGIN
    RAISE NOTICE '🐎 STEP 5: Creating Demo User';
    
    -- Get tenant info
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL;
    
    -- Get user role
    SELECT role_bk INTO v_user_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk AND role_bk LIKE '%_USER';
    
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
    
    RAISE NOTICE '✅ Demo User Created';
END $$;

COMMIT;

-- ================================
-- FINAL SUMMARY
-- ================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
BEGIN
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎉 === ONE BARN AI SETUP COMPLETED ===';
    RAISE NOTICE '';
    RAISE NOTICE 'TENANT: one_barn_ai';
    RAISE NOTICE 'TENANT HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE 'DEMO USERS:';
    RAISE NOTICE '  admin@onebarnai.com / AdminPass123! (ADMINISTRATOR)';
    RAISE NOTICE '  travis.woodward@onebarnai.com / SecurePass123! (ADMINISTRATOR)';
    RAISE NOTICE '  michelle.nash@onebarnai.com / SupportManager456! (MANAGER)';
    RAISE NOTICE '  sarah.robertson@onebarnai.com / VPBusinessDev789! (MANAGER)';
    RAISE NOTICE '  demo@onebarnai.com / Demo123! (USER)';
    RAISE NOTICE '';
    RAISE NOTICE '🐎🤖 ONE BARN AI READY FOR JULY 7, 2025 DEMO!';
END $$; 