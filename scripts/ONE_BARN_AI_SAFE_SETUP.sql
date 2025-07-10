-- ========================================================================
-- ONE BARN AI - SAFE SETUP (NO DELETES TO AVOID AUDIT CONFLICTS)
-- ========================================================================
-- This version avoids DELETE operations that trigger audit conflicts
-- Safe for production database copies

DO $$
DECLARE
    -- Tenant variables
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_existing_tenant_hk BYTEA;
    
    -- User variables
    v_ceo_user_hk BYTEA;
    v_tech_user_hk BYTEA;
    v_business_user_hk BYTEA;
    v_demo_user_hk BYTEA;
    
    -- Role business keys
    v_admin_role_bk VARCHAR;
    v_manager_role_bk VARCHAR;
    v_analyst_role_bk VARCHAR;
    v_user_role_bk VARCHAR;
    
BEGIN
    RAISE NOTICE '🐎🤖 === ONE BARN AI SAFE SETUP ===';
    RAISE NOTICE 'Safe for production database copies - no DELETE operations';
    RAISE NOTICE '';
    
    -- ================================
    -- CHECK FOR EXISTING TENANT (NO DELETE)
    -- ================================
    
    SELECT th.tenant_hk INTO v_existing_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
    AND tp.load_end_date IS NULL
    LIMIT 1;
    
    IF v_existing_tenant_hk IS NOT NULL THEN
        RAISE NOTICE '⚠️  Found existing one_barn_ai tenant: %', encode(v_existing_tenant_hk, 'hex');
        RAISE NOTICE '⚠️  Skipping setup - tenant already exists!';
        RAISE NOTICE '';
        RAISE NOTICE 'To proceed:';
        RAISE NOTICE '1. Manually remove existing tenant data if needed';
        RAISE NOTICE '2. Or use different tenant name';
        RAISE NOTICE '3. Or run verification script to confirm existing setup';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ No existing one_barn_ai tenant found - proceeding with setup';
    RAISE NOTICE '';
    
    -- ================================
    -- CREATE TENANT WITH ROLES
    -- ================================
    RAISE NOTICE '--- Creating Tenant with Default Roles ---';
    
    SELECT tenant_hk, admin_user_hk
    INTO v_tenant_hk, v_admin_user_hk
    FROM auth.register_tenant_with_roles(
        p_tenant_name := 'one_barn_ai',
        p_admin_email := 'admin@onebarnai.com',
        p_admin_password := 'AdminPass123!',
        p_admin_first_name := 'System',
        p_admin_last_name := 'Administrator'
    );
    
    RAISE NOTICE '✅ Tenant Created Successfully';
    RAISE NOTICE '   Tenant HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE '   Admin User HK: %', encode(v_admin_user_hk, 'hex');
    
    -- Query role business keys
    SELECT 
        MAX(CASE WHEN role_bk LIKE '%_ADMINISTRATOR' THEN role_bk END),
        MAX(CASE WHEN role_bk LIKE '%_MANAGER' THEN role_bk END),
        MAX(CASE WHEN role_bk LIKE '%_ANALYST' THEN role_bk END),
        MAX(CASE WHEN role_bk LIKE '%_USER' THEN role_bk END)
    INTO v_admin_role_bk, v_manager_role_bk, v_analyst_role_bk, v_user_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk;
    
    RAISE NOTICE '   Roles: %, %, %, %', v_admin_role_bk, v_manager_role_bk, v_analyst_role_bk, v_user_role_bk;
    
    -- Small delay to ensure unique timestamps
    PERFORM pg_sleep(1);
    
    -- ================================
    -- CREATE DEMO USERS
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Creating Demo Users ---';
    
    -- CEO: Travis Woodward
    RAISE NOTICE '';
    RAISE NOTICE 'Creating CEO: Travis Woodward...';
    
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'travis.woodward@onebarnai.com',
        p_password := 'SecurePass123!',
        p_first_name := 'Travis',
        p_last_name := 'Woodward',
        p_role_bk := v_admin_role_bk,
        p_user_hk := v_ceo_user_hk
    );
    
    RAISE NOTICE '✅ CEO Created - Travis Woodward (ADMINISTRATOR)';
    PERFORM pg_sleep(1);
    
    -- Support Manager: Michelle Nash
    RAISE NOTICE '';
    RAISE NOTICE 'Creating Support Manager: Michelle Nash...';
    
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'michelle.nash@onebarnai.com',
        p_password := 'SupportManager456!',
        p_first_name := 'Michelle',
        p_last_name := 'Nash',
        p_role_bk := v_manager_role_bk,
        p_user_hk := v_tech_user_hk
    );
    
    RAISE NOTICE '✅ Support Manager Created - Michelle Nash (MANAGER)';
    PERFORM pg_sleep(1);
    
    -- VP Business Development: Sarah Robertson
    RAISE NOTICE '';
    RAISE NOTICE 'Creating VP Business Development: Sarah Robertson...';
    
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'sarah.robertson@onebarnai.com',
        p_password := 'VPBusinessDev789!',
        p_first_name := 'Sarah',
        p_last_name := 'Robertson',
        p_role_bk := v_manager_role_bk,
        p_user_hk := v_business_user_hk
    );
    
    RAISE NOTICE '✅ VP Business Development Created - Sarah Robertson (MANAGER)';
    PERFORM pg_sleep(1);
    
    -- Demo User
    RAISE NOTICE '';
    RAISE NOTICE 'Creating Demo User...';
    
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'demo@onebarnai.com',
        p_password := 'Demo123!',
        p_first_name := 'Demo',
        p_last_name := 'User',
        p_role_bk := v_user_role_bk,
        p_user_hk := v_demo_user_hk
    );
    
    RAISE NOTICE '✅ Demo User Created - Demo User (USER)';
    
    -- ================================
    -- SETUP COMPLETE - SUMMARY
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '🎉 === ONE BARN AI DEMO SETUP COMPLETED SUCCESSFULLY ===';
    RAISE NOTICE '';
    RAISE NOTICE 'TENANT: one_barn_ai';
    RAISE NOTICE 'TENANT HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE 'DEMO USERS CREATED:';
    RAISE NOTICE '';
    RAISE NOTICE '1. System Administrator (Auto-created)';
    RAISE NOTICE '   Email: admin@onebarnai.com';
    RAISE NOTICE '   Password: AdminPass123!';
    RAISE NOTICE '   Role: ADMINISTRATOR';
    RAISE NOTICE '';
    RAISE NOTICE '2. Travis Woodward (CEO & Founder)';
    RAISE NOTICE '   Email: travis.woodward@onebarnai.com';
    RAISE NOTICE '   Password: SecurePass123!';
    RAISE NOTICE '   Role: ADMINISTRATOR';
    RAISE NOTICE '';
    RAISE NOTICE '3. Michelle Nash (Support Manager)';
    RAISE NOTICE '   Email: michelle.nash@onebarnai.com';
    RAISE NOTICE '   Password: SupportManager456!';
    RAISE NOTICE '   Role: MANAGER';
    RAISE NOTICE '';
    RAISE NOTICE '4. Sarah Robertson (VP Business Development)';
    RAISE NOTICE '   Email: sarah.robertson@onebarnai.com';
    RAISE NOTICE '   Password: VPBusinessDev789!';
    RAISE NOTICE '   Role: MANAGER';
    RAISE NOTICE '';
    RAISE NOTICE '5. Demo User (For Presentations)';
    RAISE NOTICE '   Email: demo@onebarnai.com';
    RAISE NOTICE '   Password: Demo123!';
    RAISE NOTICE '   Role: USER';
    RAISE NOTICE '';
    RAISE NOTICE '🐎🤖 ONE BARN AI READY FOR JULY 7, 2025 DEMO!';
    RAISE NOTICE '';
    RAISE NOTICE 'Available Roles: ADMINISTRATOR, MANAGER, ANALYST, AUDITOR, USER, VIEWER';
    RAISE NOTICE 'Horse Health AI Platform: READY FOR ENTERPRISE DEMO';
    
END $$; 