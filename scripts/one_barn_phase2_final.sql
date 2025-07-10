-- ========================================================================
-- ONE BARN AI - PHASE 2: USER CREATION (FINAL VERSION)
-- ========================================================================
-- Using CORRECT tenant HK that actually has the roles
-- Tenant: one_barn_ai (HK: 518a00fd8cb1b99f7f214dbdc465d0d75fe738dfccff79d7baabb7c102eebc95)

DO $$
DECLARE
    v_tenant_hk BYTEA := decode('518a00fd8cb1b99f7f214dbdc465d0d75fe738dfccff79d7baabb7c102eebc95', 'hex');
    v_admin_user_hk BYTEA;
    v_tech_user_hk BYTEA;
    v_business_user_hk BYTEA;
    v_demo_user_hk BYTEA;
    
    -- Actual role business keys from database
    v_admin_role_bk VARCHAR := 'one_barn_ai_2025-07-04 08:00:35.324738-07_ADMINISTRATOR';
    v_manager_role_bk VARCHAR := 'one_barn_ai_2025-07-04 08:00:35.324738-07_MANAGER';
    v_analyst_role_bk VARCHAR := 'one_barn_ai_2025-07-04 08:00:35.324738-07_ANALYST';
    v_user_role_bk VARCHAR := 'one_barn_ai_2025-07-04 08:00:35.324738-07_USER';
    
BEGIN
    RAISE NOTICE '=== ONE BARN AI - PHASE 2: USER CREATION ===';
    RAISE NOTICE 'Using CORRECT Tenant HK: %', encode(v_tenant_hk, 'hex');
    
    -- ================================
    -- CREATE ADMIN USER: Travis Woodward
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Creating Admin User: Travis Woodward ---';
    
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'travis.woodward@onebarnai.com',
        p_password := 'SecurePass123!',
        p_first_name := 'Travis',
        p_last_name := 'Woodward',
        p_role_bk := v_admin_role_bk,
        p_user_hk := v_admin_user_hk
    );
    
    RAISE NOTICE '✅ Admin User Created Successfully';
    RAISE NOTICE '   User HK: %', encode(v_admin_user_hk, 'hex');
    RAISE NOTICE '   Email: travis.woodward@onebarnai.com';
    RAISE NOTICE '   Role: ADMINISTRATOR';
    
    -- ================================
    -- CREATE TECH LEAD: Michelle Nash
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Creating Support Manager: Michelle Nash ---';
    
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'michelle.nash@onebarnai.com',
        p_password := 'TechLead456!',
        p_first_name := 'Michelle',
        p_last_name := 'Nash',
        p_role_bk := v_manager_role_bk,
        p_user_hk := v_tech_user_hk
    );
    
    RAISE NOTICE '✅ Support Manager Created Successfully';
    RAISE NOTICE '   User HK: %', encode(v_tech_user_hk, 'hex');
    RAISE NOTICE '   Email: michelle.nash@onebarnai.com';
    RAISE NOTICE '   Role: MANAGER';
    
    -- ================================
    -- CREATE BUSINESS DEV: Sarah Robertson
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Creating Business Dev: Sarah Robertson ---';
    
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'sarah.robertson@onebarnai.com',
        p_password := 'BizDev789!',
        p_first_name := 'Sarah',
        p_last_name := 'Robertson',
        p_role_bk := v_analyst_role_bk,
        p_user_hk := v_business_user_hk
    );
    
    RAISE NOTICE '✅ Business Dev Created Successfully';
    RAISE NOTICE '   User HK: %', encode(v_business_user_hk, 'hex');
    RAISE NOTICE '   Email: sarah.robertson@onebarnai.com';
    RAISE NOTICE '   Role: ANALYST';
    
    -- ================================
    -- CREATE DEMO USER: Demo User
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Creating Demo User ---';
    
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'demo@onebarnai.com',
        p_password := 'Demo123!',
        p_first_name := 'Demo',
        p_last_name := 'User',
        p_role_bk := v_user_role_bk,
        p_user_hk := v_demo_user_hk
    );
    
    RAISE NOTICE '✅ Demo User Created Successfully';
    RAISE NOTICE '   User HK: %', encode(v_demo_user_hk, 'hex');
    RAISE NOTICE '   Email: demo@onebarnai.com';
    RAISE NOTICE '   Role: USER';
    
    -- ================================
    -- SUMMARY
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '🎉 === ONE BARN AI PHASE 2 COMPLETED SUCCESSFULLY ===';
    RAISE NOTICE '';
    RAISE NOTICE 'TENANT: one_barn_ai';
    RAISE NOTICE 'TENANT HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE 'CREATED: 2025-07-04 08:00:35';
    RAISE NOTICE '';
    RAISE NOTICE 'USERS CREATED:';
    RAISE NOTICE '1. Travis Woodward (CEO & Founder) - ADMINISTRATOR';
    RAISE NOTICE '   Email: travis.woodward@onebarnai.com';
    RAISE NOTICE '   User HK: %', encode(v_admin_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '2. Michelle Nash (Support Manager) - MANAGER';
    RAISE NOTICE '   Email: michelle.nash@onebarnai.com';
    RAISE NOTICE '   User HK: %', encode(v_tech_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '3. Sarah Robertson (VP Business Development) - ANALYST';
    RAISE NOTICE '   Email: sarah.robertson@onebarnai.com';
    RAISE NOTICE '   User HK: %', encode(v_business_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '4. Demo User - USER';
    RAISE NOTICE '   Email: demo@onebarnai.com';
    RAISE NOTICE '   User HK: %', encode(v_demo_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '🐎🤖 ONE BARN AI DEMO ENVIRONMENT READY!';
    RAISE NOTICE 'Ready for July 7, 2025 presentation!';
    RAISE NOTICE '';
    RAISE NOTICE 'Login credentials for demo:';
    RAISE NOTICE '- Travis: travis.woodward@onebarnai.com / SecurePass123!';
    RAISE NOTICE '- Michelle: michelle.nash@onebarnai.com / TechLead456!';
    RAISE NOTICE '- Sarah: sarah.robertson@onebarnai.com / BizDev789!';
    RAISE NOTICE '- Demo: demo@onebarnai.com / Demo123!';
    
END $$; 