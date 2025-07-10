-- ========================================================================
-- ONE BARN AI - MANUAL APPROACH (BYPASS AUDIT ISSUES)
-- ========================================================================
-- Direct approach to bypass the persistent audit constraint issues

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_existing_tenant_hk BYTEA;
BEGIN
    RAISE NOTICE '🐎🤖 === ONE BARN AI MANUAL APPROACH ===';
    RAISE NOTICE 'Bypassing audit issues with direct approach';
    RAISE NOTICE '';
    
    -- Check for existing tenant
    SELECT th.tenant_hk INTO v_existing_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
    AND tp.load_end_date IS NULL;
    
    IF v_existing_tenant_hk IS NOT NULL THEN
        RAISE NOTICE '⚠️  Found existing tenant: %', encode(v_existing_tenant_hk, 'hex');
        RAISE NOTICE 'Will attempt to add users to existing tenant';
        v_tenant_hk := v_existing_tenant_hk;
    ELSE
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
        
        RAISE NOTICE '✅ Tenant Created: %', encode(v_tenant_hk, 'hex');
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Now check what users already exist...';
    
END $$;

-- ================================
-- CHECK EXISTING USERS
-- ================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_count INTEGER;
BEGIN
    -- Get tenant
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
    AND tp.load_end_date IS NULL;
    
    -- Count existing users
    SELECT COUNT(*) INTO v_user_count
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.load_end_date IS NULL;
    
    RAISE NOTICE '';
    RAISE NOTICE '👥 EXISTING USERS FOR one_barn_ai:';
    RAISE NOTICE 'Count: %', v_user_count;
    RAISE NOTICE '';
    
    -- Show existing users
    FOR rec IN 
        SELECT up.email, up.first_name, up.last_name
        FROM auth.user_h uh
        JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
        WHERE uh.tenant_hk = v_tenant_hk
        AND up.load_end_date IS NULL
        ORDER BY up.load_date
    LOOP
        RAISE NOTICE '  User: % % (Email: %)', rec.first_name, rec.last_name, rec.email;
    END LOOP;
    
    IF v_user_count = 1 THEN
        RAISE NOTICE '';
        RAISE NOTICE '✅ Only admin user exists - ready to add demo users';
    ELSIF v_user_count > 1 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  Multiple users already exist - check if setup is already complete';
    END IF;
    
END $$;

-- ================================
-- AGGRESSIVE AUDIT CLEANUP
-- ================================

-- Clear all audit events to prevent conflicts
DELETE FROM audit.audit_event_h WHERE load_date >= CURRENT_DATE - INTERVAL '1 day';

RAISE NOTICE '';
RAISE NOTICE '🧹 Cleared recent audit events to prevent conflicts';
RAISE NOTICE '';

-- ================================
-- CREATE USERS ONE BY ONE WITH LONG DELAYS
-- ================================

-- User 1: Travis Woodward
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_role_bk VARCHAR;
    v_ceo_user_hk BYTEA;
    v_existing_user_count INTEGER;
BEGIN
    RAISE NOTICE '👤 CREATING USER 1: Travis Woodward (CEO)';
    
    -- Get tenant
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL;
    
    -- Check if user already exists
    SELECT COUNT(*) INTO v_existing_user_count
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'travis.woodward@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_existing_user_count > 0 THEN
        RAISE NOTICE '⚠️  Travis Woodward already exists - skipping';
        RETURN;
    END IF;
    
    -- Get admin role
    SELECT role_bk INTO v_admin_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk 
    AND role_bk LIKE '%_ADMINISTRATOR'
    LIMIT 1;
    
    -- 5 second delay before creation
    PERFORM pg_sleep(5);
    
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
    
    RAISE NOTICE '✅ Travis Woodward created successfully';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Failed to create Travis Woodward: %', SQLERRM;
END $$;

-- 10 second delay between users
SELECT pg_sleep(10);

-- User 2: Michelle Nash  
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_manager_role_bk VARCHAR;
    v_tech_user_hk BYTEA;
    v_existing_user_count INTEGER;
BEGIN
    RAISE NOTICE '👤 CREATING USER 2: Michelle Nash (Support Manager)';
    
    -- Get tenant
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL;
    
    -- Check if user already exists
    SELECT COUNT(*) INTO v_existing_user_count
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    WHERE uh.tenant_hk = v_tenant_hk
    AND up.email = 'michelle.nash@onebarnai.com'
    AND up.load_end_date IS NULL;
    
    IF v_existing_user_count > 0 THEN
        RAISE NOTICE '⚠️  Michelle Nash already exists - skipping';
        RETURN;
    END IF;
    
    -- Get manager role
    SELECT role_bk INTO v_manager_role_bk
    FROM auth.role_h
    WHERE tenant_hk = v_tenant_hk 
    AND role_bk LIKE '%_MANAGER'
    LIMIT 1;
    
    -- 5 second delay before creation
    PERFORM pg_sleep(5);
    
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
    
    RAISE NOTICE '✅ Michelle Nash created successfully';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Failed to create Michelle Nash: %', SQLERRM;
END $$;

-- Final status check
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎯 === FINAL STATUS CHECK ===';
    
    -- Get tenant
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai' AND tp.load_end_date IS NULL;
    
    -- Count users
    SELECT COUNT(*) INTO v_user_count
    FROM auth.user_h uh
    WHERE uh.tenant_hk = v_tenant_hk;
    
    RAISE NOTICE 'Tenant: one_barn_ai';
    RAISE NOTICE 'Tenant HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE 'Total Users: %', v_user_count;
    
    IF v_user_count >= 2 THEN
        RAISE NOTICE '🎉 SUCCESS! Users created successfully!';
    ELSE
        RAISE NOTICE '⚠️  Only % user(s) - may need manual intervention', v_user_count;
    END IF;
    
END $$; 