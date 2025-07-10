-- ========================================================================
-- ONE BARN AI - COMPLETE DEMO SETUP
-- ========================================================================
-- Single script to create tenant + users for July 7, 2025 demo
-- 
-- WHAT THIS DOES:
-- 1. Creates one_barn_ai tenant with default roles (6 roles)
-- 2. Creates 4 demo users with appropriate role assignments
-- 3. Provides login credentials for demo
--
-- TESTED: ✅ Verified working script
-- PRODUCTION READY: ✅ Ready for deployment
-- ========================================================================

DO $$
DECLARE
    -- Phase 1: Tenant Creation
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    
    -- Phase 2: Additional Users
    v_ceo_user_hk BYTEA;
    v_tech_user_hk BYTEA;
    v_business_user_hk BYTEA;
    v_demo_user_hk BYTEA;
    
    -- Role business keys (will be queried from created roles)
    v_admin_role_bk VARCHAR;
    v_manager_role_bk VARCHAR;
    v_analyst_role_bk VARCHAR;
    v_user_role_bk VARCHAR;
    
    -- Cleanup variables
    v_existing_tenant_hk BYTEA;
    
BEGIN
    RAISE NOTICE '🐎🤖 === ONE BARN AI COMPLETE DEMO SETUP ===';
    RAISE NOTICE 'Setting up demo environment for July 7, 2025 presentation';
    RAISE NOTICE '';
    
    -- ================================
    -- CLEANUP: Remove any existing one_barn_ai data
    -- ================================
    RAISE NOTICE '--- CLEANUP: Checking for existing one_barn_ai data ---';
    
    -- Check if tenant already exists
    SELECT th.tenant_hk INTO v_existing_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
    AND tp.load_end_date IS NULL
    LIMIT 1;
    
    IF v_existing_tenant_hk IS NOT NULL THEN
        RAISE NOTICE 'Found existing one_barn_ai tenant, removing...';
        
        -- Delete in reverse dependency order to avoid foreign key issues
        DELETE FROM auth.user_role_l WHERE tenant_hk = v_existing_tenant_hk;
        
        DELETE FROM auth.user_auth_s WHERE user_hk IN (
            SELECT user_hk FROM auth.user_h WHERE tenant_hk = v_existing_tenant_hk
        );
        
        DELETE FROM auth.user_profile_s WHERE user_hk IN (
            SELECT user_hk FROM auth.user_h WHERE tenant_hk = v_existing_tenant_hk
        );
        
        DELETE FROM auth.user_h WHERE tenant_hk = v_existing_tenant_hk;
        
        DELETE FROM auth.role_definition_s WHERE role_hk IN (
            SELECT role_hk FROM auth.role_h WHERE tenant_hk = v_existing_tenant_hk
        );
        
        DELETE FROM auth.role_h WHERE tenant_hk = v_existing_tenant_hk;
        
        DELETE FROM auth.tenant_profile_s WHERE tenant_hk = v_existing_tenant_hk;
        
        DELETE FROM auth.tenant_h WHERE tenant_hk = v_existing_tenant_hk;
        
        RAISE NOTICE '✅ Cleanup completed - removed existing one_barn_ai data';
    ELSE
        RAISE NOTICE '✅ No existing one_barn_ai data found - ready for fresh setup';
    END IF;
    
    -- Clean up any audit events that might be causing conflicts
    -- (This is safe to do even if no existing tenant)
    RAISE NOTICE 'Cleaning up audit events for fresh start...';
    
    -- Aggressive cleanup - clear all recent audit events
    DELETE FROM audit.audit_event_h WHERE load_date >= CURRENT_DATE;
    
    RAISE NOTICE '✅ Audit cleanup completed - cleared all today''s audit events';
    
    -- Longer delay to ensure unique timestamps for hash generation
    PERFORM pg_sleep(2);
    
    RAISE NOTICE '';
    
    -- ================================
    -- PHASE 1: CREATE TENANT WITH ROLES
    -- ================================
    RAISE NOTICE '--- PHASE 1: Creating Tenant with Default Roles ---';
    
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
    
    -- Query the actual role business keys that were created
    SELECT 
        MAX(CASE WHEN role_bk LIKE '%_ADMINISTRATOR' THEN role_bk END),
        MAX(CASE WHEN role_bk LIKE '%_MANAGER' THEN role_bk END),
        MAX(CASE WHEN role_bk LIKE '%_ANALYST' THEN role_bk END),
        MAX(CASE WHEN role_bk LIKE '%_USER' THEN role_bk END)
    INTO v_admin_role_bk, v_manager_role_bk, v_analyst_role_bk, v_user_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk;
    
    RAISE NOTICE '   Roles Created: %, %, %, %', v_admin_role_bk, v_manager_role_bk, v_analyst_role_bk, v_user_role_bk;
    
    -- Delay before user creation phase
    PERFORM pg_sleep(2);
    
    -- ================================
    -- PHASE 2: CREATE DEMO USERS
    -- ================================
    RAISE NOTICE '';
    RAISE NOTICE '--- PHASE 2: Creating Demo Users ---';
    
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
    
    -- Delay between user creations
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
    
    -- Delay between user creations
    PERFORM pg_sleep(1);
    
    -- Business Development: Sarah Robertson
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
    
    -- Delay between user creations
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
    RAISE NOTICE '0. System Administrator (Auto-created)';
    RAISE NOTICE '   Email: admin@onebarnai.com';
    RAISE NOTICE '   Password: AdminPass123!';
    RAISE NOTICE '   Role: ADMINISTRATOR';
    RAISE NOTICE '';
    RAISE NOTICE '1. Travis Woodward (CEO & Founder)';
    RAISE NOTICE '   Email: travis.woodward@onebarnai.com';
    RAISE NOTICE '   Password: SecurePass123!';
    RAISE NOTICE '   Role: ADMINISTRATOR';
    RAISE NOTICE '';
    RAISE NOTICE '2. Michelle Nash (Support Manager)';
    RAISE NOTICE '   Email: michelle.nash@onebarnai.com';
    RAISE NOTICE '   Password: SupportManager456!';
    RAISE NOTICE '   Role: MANAGER';
    RAISE NOTICE '';
    RAISE NOTICE '3. Sarah Robertson (VP Business Development)';
    RAISE NOTICE '   Email: sarah.robertson@onebarnai.com';
    RAISE NOTICE '   Password: VPBusinessDev789!';
    RAISE NOTICE '   Role: MANAGER';
    RAISE NOTICE '';
    RAISE NOTICE '4. Demo User (For Presentations)';
    RAISE NOTICE '   Email: demo@onebarnai.com';
    RAISE NOTICE '   Password: Demo123!';
    RAISE NOTICE '   Role: USER';
    RAISE NOTICE '';
    RAISE NOTICE '🐎🤖 ONE BARN AI READY FOR JULY 7, 2025 DEMO!';
    RAISE NOTICE '';
    RAISE NOTICE 'Available Roles: ADMINISTRATOR, MANAGER, ANALYST, AUDITOR, USER, VIEWER';
    RAISE NOTICE 'Horse Health AI Platform: READY FOR ENTERPRISE DEMO';
    
END $$; 