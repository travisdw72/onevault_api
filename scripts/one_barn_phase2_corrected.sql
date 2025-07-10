-- ========================================================================
-- ONE BARN AI - PHASE 2: USER CREATION (CORRECTED VERSION)
-- ========================================================================
-- Using actual role business keys discovered from database
-- Tenant: one_barn_ai (HK: dfafdf04bbf21580ad610ebb9048a719c91b38d8d62f351ad858f98ccd441d82)

DO $$
DECLARE
    v_tenant_hk BYTEA := decode('dfafdf04bbf21580ad610ebb9048a719c91b38d8d62f351ad858f98ccd441d82', 'hex');
    v_admin_user_hk BYTEA;
    v_tech_user_hk BYTEA;
    v_business_user_hk BYTEA;
    v_demo_user_hk BYTEA;
    v_result_data JSONB;
    v_result_success BOOLEAN;
    v_result_message TEXT;
    
    -- Role hash keys (found from role_h table)
    v_admin_role_hk BYTEA := decode('509a89683d373493a173e243e0c59921da93dabd25a54e3bf2b2306f979d5130', 'hex');
    v_manager_role_hk BYTEA := decode('094751929ac6ad91427ba69ed905392837b3e963fee98e7402e84eb2647f475a', 'hex');
    v_analyst_role_hk BYTEA := decode('b64770dc6db5644e4a776fd7258f9c33f42d73d46e3b07162415a01e3bca092d', 'hex');
    v_user_role_hk BYTEA := decode('de1839e84ff248db640cb56111f1314a915a7e682517428c35bed9a409640dbe', 'hex');
    
BEGIN
    RAISE NOTICE '=== ONE BARN AI - PHASE 2: USER CREATION ===';
    RAISE NOTICE 'Tenant HK: %', encode(v_tenant_hk, 'hex');
    
    -- ================================
    -- CREATE ADMIN USER: Travis Woodward
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Creating Admin User: Travis Woodward ---';
    
    SELECT p_user_hk, p_user_data, p_success, p_message
    INTO v_admin_user_hk, v_result_data, v_result_success, v_result_message
    FROM auth.register_user_with_roles(
        p_tenant_hk := v_tenant_hk,
        p_email := 'travis.woodward@onebarnai.com',
        p_username := 'travis.woodward',
        p_first_name := 'Travis',
        p_last_name := 'Woodward',
        p_password := 'SecurePass123!',
        p_phone := '+1-555-0101',
        p_job_title := 'CEO & Founder',
        p_role_bks := ARRAY['one_barn_ai_2025-07-04 08:00:35.324738-07_ADMINISTRATOR']
    );
    
    IF v_result_success THEN
        RAISE NOTICE '✅ Admin User Created Successfully';
        RAISE NOTICE '   User HK: %', encode(v_admin_user_hk, 'hex');
        RAISE NOTICE '   Email: travis.woodward@onebarnai.com';
        RAISE NOTICE '   Role: ADMINISTRATOR';
    ELSE
        RAISE NOTICE '❌ Admin User Creation Failed: %', v_result_message;
        RAISE EXCEPTION 'Failed to create admin user: %', v_result_message;
    END IF;
    
    -- ================================
    -- CREATE TECH LEAD: Michelle Nash
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Creating Tech Lead: Michelle Nash ---';
    
    SELECT p_user_hk, p_user_data, p_success, p_message
    INTO v_tech_user_hk, v_result_data, v_result_success, v_result_message
    FROM auth.register_user_with_roles(
        p_tenant_hk := v_tenant_hk,
        p_email := 'michelle.nash@onebarnai.com',
        p_username := 'michelle.nash',
        p_first_name := 'Michelle',
        p_last_name := 'Nash',
        p_password := 'TechLead456!',
        p_phone := '+1-555-0102',
        p_job_title := 'Support Manager',
        p_role_bks := ARRAY['one_barn_ai_2025-07-04 08:00:35.324738-07_MANAGER']
    );
    
    IF v_result_success THEN
        RAISE NOTICE '✅ Tech Lead Created Successfully';
        RAISE NOTICE '   User HK: %', encode(v_tech_user_hk, 'hex');
        RAISE NOTICE '   Email: michelle.nash@onebarnai.com';
        RAISE NOTICE '   Role: MANAGER';
    ELSE
        RAISE NOTICE '❌ Tech Lead Creation Failed: %', v_result_message;
        RAISE EXCEPTION 'Failed to create tech lead: %', v_result_message;
    END IF;
    
    -- ================================
    -- CREATE BUSINESS DEV: Sarah Robertson
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Creating Business Dev: Sarah Robertson ---';
    
    SELECT p_user_hk, p_user_data, p_success, p_message
    INTO v_business_user_hk, v_result_data, v_result_success, v_result_message
    FROM auth.register_user_with_roles(
        p_tenant_hk := v_tenant_hk,
        p_email := 'sarah.robertson@onebarnai.com',
        p_username := 'sarah.robertson',
        p_first_name := 'Sarah',
        p_last_name := 'Robertson',
        p_password := 'BizDev789!',
        p_phone := '+1-555-0103',
        p_job_title := 'VP Business Development',
        p_role_bks := ARRAY['one_barn_ai_2025-07-04 08:00:35.324738-07_ANALYST']
    );
    
    IF v_result_success THEN
        RAISE NOTICE '✅ Business Dev Created Successfully';
        RAISE NOTICE '   User HK: %', encode(v_business_user_hk, 'hex');
        RAISE NOTICE '   Email: sarah.robertson@onebarnai.com';
        RAISE NOTICE '   Role: ANALYST';
    ELSE
        RAISE NOTICE '❌ Business Dev Creation Failed: %', v_result_message;
        RAISE EXCEPTION 'Failed to create business dev user: %', v_result_message;
    END IF;
    
    -- ================================
    -- CREATE DEMO USER: Demo User
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Creating Demo User ---';
    
    SELECT p_user_hk, p_user_data, p_success, p_message
    INTO v_demo_user_hk, v_result_data, v_result_success, v_result_message
    FROM auth.register_user_with_roles(
        p_tenant_hk := v_tenant_hk,
        p_email := 'demo@onebarnai.com',
        p_username := 'demo.user',
        p_first_name := 'Demo',
        p_last_name := 'User',
        p_password := 'Demo123!',
        p_phone := '+1-555-0199',
        p_job_title := 'Demo Account',
        p_role_bks := ARRAY['one_barn_ai_2025-07-04 08:00:35.324738-07_USER']
    );
    
    IF v_result_success THEN
        RAISE NOTICE '✅ Demo User Created Successfully';
        RAISE NOTICE '   User HK: %', encode(v_demo_user_hk, 'hex');
        RAISE NOTICE '   Email: demo@onebarnai.com';
        RAISE NOTICE '   Role: USER';
    ELSE
        RAISE NOTICE '❌ Demo User Creation Failed: %', v_result_message;
        RAISE EXCEPTION 'Failed to create demo user: %', v_result_message;
    END IF;
    
    -- ================================
    -- SUMMARY
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '🎉 === ONE BARN AI PHASE 2 COMPLETED SUCCESSFULLY ===';
    RAISE NOTICE '';
    RAISE NOTICE 'TENANT: one_barn_ai';
    RAISE NOTICE 'TENANT HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE 'USERS CREATED:';
    RAISE NOTICE '1. Travis Woodward (CEO) - ADMINISTRATOR';
    RAISE NOTICE '   Email: travis.woodward@onebarnai.com';
    RAISE NOTICE '   User HK: %', encode(v_admin_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '2. Michelle Nash (Tech Lead) - MANAGER';
    RAISE NOTICE '   Email: michelle.nash@onebarnai.com';
    RAISE NOTICE '   User HK: %', encode(v_tech_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '3. Sarah Robertson (Business Dev) - ANALYST';
    RAISE NOTICE '   Email: sarah.robertson@onebarnai.com';
    RAISE NOTICE '   User HK: %', encode(v_business_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE '4. Demo User - USER';
    RAISE NOTICE '   Email: demo@onebarnai.com';
    RAISE NOTICE '   User HK: %', encode(v_demo_user_hk, 'hex');
    RAISE NOTICE '';
    RAISE NOTICE 'Ready for July 7, 2025 demo! ��🤖';
    
END $$; 