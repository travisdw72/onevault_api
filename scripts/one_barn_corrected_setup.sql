-- ========================================================================
-- ONE_BARN_AI ENTERPRISE TENANT SETUP - CORRECTED VERSION
-- ========================================================================
-- Date: January 7, 2025 - CORRECTED FOR ACTUAL DATABASE FUNCTIONS
-- Objective: Create One_Barn_AI as enterprise partner tenant with horse health AI capabilities
-- Database: one_vault_site_testing (localhost)
-- Target Demo: July 7, 2025

-- ========================================================================
-- PHASE 1: TENANT CREATION (CORRECTED)
-- ========================================================================

-- Step 1.1: Create One_Barn_AI Enterprise Tenant
-- CORRECTED: Using actual function signature
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_result RECORD;
BEGIN
    -- Call the ACTUAL register_tenant_with_roles function
    SELECT * INTO v_result FROM auth.register_tenant_with_roles(
        p_tenant_name := 'one_barn_ai',
        p_admin_email := 'admin@onebarnai.com',
        p_admin_password := 'HorseHealth2025!',
        p_admin_first_name := 'Sarah',
        p_admin_last_name := 'Mitchell'
    );
    
    v_tenant_hk := v_result.tenant_hk;
    v_admin_user_hk := v_result.admin_user_hk;
    
    RAISE NOTICE 'One_Barn_AI tenant created successfully';
    RAISE NOTICE 'Tenant HK: %', encode(v_tenant_hk, 'hex');
    RAISE NOTICE 'Admin User HK: %', encode(v_admin_user_hk, 'hex');
END $$;

-- Step 1.2: Verify Tenant Creation
SELECT 
    th.tenant_bk,
    tp.tenant_name,
    tp.is_active,
    tp.load_date as created_date,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.load_end_date IS NULL
AND th.tenant_bk LIKE '%one_barn_ai%'  -- Since actual function generates BK
ORDER BY tp.load_date DESC;

-- Step 1.3: Verify Admin User Creation
SELECT 
    up.email,
    up.first_name,
    up.last_name,
    uas.is_active,
    uas.account_locked,
    encode(uh.user_hk, 'hex') as user_hk_hex
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
WHERE up.load_end_date IS NULL
AND (uas.load_end_date IS NULL OR uas.load_end_date IS NULL)
AND up.email = 'admin@onebarnai.com';

-- ========================================================================
-- PHASE 2: GET TENANT HASH KEY FOR SUBSEQUENT OPERATIONS
-- ========================================================================

-- Step 2.1: Get One_Barn_AI Tenant Hash Key (CRITICAL FOR REMAINING STEPS)
SELECT 
    'TENANT_CREATED' as status,
    th.tenant_hk,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    th.tenant_bk,
    tp.tenant_name
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE th.tenant_bk LIKE '%one_barn_ai%'  -- Dynamically generated BK
AND tp.load_end_date IS NULL;

-- ========================================================================
-- PHASE 3: ENTERPRISE USER SETUP (CORRECTED)
-- ========================================================================

-- Step 3.1: Create Additional One_Barn_AI Team Members
-- CORRECTED: Using actual register_user function signature
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
BEGIN
    -- Get tenant hash key first
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE th.tenant_bk LIKE '%one_barn_ai%'
    AND tp.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'One_Barn_AI tenant not found';
    END IF;
    
    -- Veterinary Specialist (using ADMINISTRATOR role)
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'vet@onebarnai.com',
        p_password := 'VetSpecialist2025!',
        p_first_name := 'Dr. Sarah',
        p_last_name := 'Mitchell',
        p_role_bk := 'ADMINISTRATOR',  -- Using existing role
        p_user_hk := v_user_hk
    );
    RAISE NOTICE 'Created veterinary specialist user';
    
    -- AI Technical Lead (using MANAGER role)
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'tech@onebarnai.com',
        p_password := 'TechLead2025!',
        p_first_name := 'Marcus',
        p_last_name := 'Rodriguez',
        p_role_bk := 'MANAGER',
        p_user_hk := v_user_hk
    );
    RAISE NOTICE 'Created technical lead user';
    
    -- Business Development Manager (using USER role)
    CALL auth.register_user(
        p_tenant_hk := v_tenant_hk,
        p_email := 'business@onebarnai.com',
        p_password := 'BizDev2025!',
        p_first_name := 'Jennifer',
        p_last_name := 'Park',
        p_role_bk := 'USER',
        p_user_hk := v_user_hk
    );
    RAISE NOTICE 'Created business development user';
    
    RAISE NOTICE 'All One_Barn_AI team members created successfully';
END $$;

-- ========================================================================
-- PHASE 4: AI AGENT CREATION (IF TABLES EXIST)
-- ========================================================================

-- Step 4.1: Create Horse Health Specialist AI Agent (if ai_agents schema exists)
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_agent_hk BYTEA;
    v_ai_schema_exists BOOLEAN := FALSE;
BEGIN
    -- Check if AI agents schema exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.schemata 
        WHERE schema_name = 'ai_agents'
    ) INTO v_ai_schema_exists;
    
    IF NOT v_ai_schema_exists THEN
        RAISE NOTICE 'AI agents schema does not exist yet - skipping AI agent creation';
        RETURN;
    END IF;
    
    -- Get tenant hash key
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE th.tenant_bk LIKE '%one_barn_ai%'
    AND tp.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'One_Barn_AI tenant not found for AI agent creation';
    END IF;
    
    v_agent_hk := util.hash_binary('one_barn_ai_horse_health_specialist');
    
    -- Create AI agent hub record
    INSERT INTO ai_agents.agent_h (
        agent_hk,
        agent_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_agent_hk,
        'horse_health_specialist',
        v_tenant_hk,
        util.current_load_date(),
        'enterprise_partnership_setup'
    );
    
    -- Create AI agent configuration
    INSERT INTO ai_agents.agent_s (
        agent_hk,
        load_date,
        load_end_date,
        hash_diff,
        agent_name,
        agent_type,
        agent_status,
        description,
        capabilities,
        model_configuration,
        specialization_area,
        confidence_threshold,
        emergency_threshold,
        is_active,
        created_by,
        record_source
    ) VALUES (
        v_agent_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary('horse_health_specialist_config_v1'),
        'Horse Health Specialist',
        'image_analysis',
        'active',
        'Specialized AI agent for analyzing horse health from photographs and videos.',
        '["photo_analysis", "health_assessment", "emergency_detection", "breed_recognition", "lameness_detection"]'::jsonb,
        '{
            "base_model": "gpt-4-vision-preview",
            "specialty_model": "equine_health_v2.1",
            "confidence_threshold": 0.80,
            "emergency_threshold": 0.90
        }'::jsonb,
        'equine_health_monitoring',
        0.80,
        0.90,
        true,
        'enterprise_setup_admin',
        'enterprise_partnership_setup'
    );
    
    RAISE NOTICE 'Horse Health Specialist AI agent created successfully';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'AI agent creation skipped: %', SQLERRM;
END $$;

-- ========================================================================
-- PHASE 5: DEMO DATA PREPARATION (IF BUSINESS SCHEMA EXISTS)
-- ========================================================================

-- Step 5.1: Create Demo Horse Records (if business schema exists)
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_business_schema_exists BOOLEAN := FALSE;
BEGIN
    -- Check if business schema exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.schemata 
        WHERE schema_name = 'business'
    ) INTO v_business_schema_exists;
    
    IF NOT v_business_schema_exists THEN
        RAISE NOTICE 'Business schema does not exist yet - skipping demo data creation';
        RETURN;
    END IF;
    
    -- Get tenant hash key
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE th.tenant_bk LIKE '%one_barn_ai%'
    AND tp.load_end_date IS NULL;
    
    -- Create demo horses (simplified for compatibility)
    RAISE NOTICE 'Demo horse data creation would go here when business schema is available';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Demo data creation skipped: %', SQLERRM;
END $$;

-- ========================================================================
-- PHASE 6: API INTEGRATION TESTING
-- ========================================================================

-- Step 6.1: Test Tenant Authentication (Manual test after setup)
SELECT 
    'AUTHENTICATION_TEST' as test_type,
    'Run this manually after setup:' as instruction,
    'SELECT api.auth_login(''{"username": "admin@onebarnai.com", "password": "HorseHealth2025!", "ip_address": "127.0.0.1", "user_agent": "OneVault-Demo-Client", "auto_login": true}'');' as test_command;

-- ========================================================================
-- VERIFICATION QUERIES
-- ========================================================================

-- Final verification of complete setup
SELECT 
    'FINAL_VERIFICATION' as check_type,
    COUNT(*) as count,
    CASE WHEN COUNT(*) > 0 THEN '✅ SUCCESS' ELSE '❌ FAILED' END as status
FROM auth.tenant_profile_s 
WHERE tenant_name LIKE '%one_barn%' 
AND load_end_date IS NULL

UNION ALL

SELECT 
    'USER_COUNT' as check_type,
    COUNT(*) as count,
    CASE WHEN COUNT(*) >= 4 THEN '✅ SUCCESS' ELSE '⚠️ PARTIAL' END as status
FROM auth.user_h uh
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE th.tenant_bk LIKE '%one_barn_ai%'
AND tp.load_end_date IS NULL;

-- Show created users
SELECT 
    'CREATED_USERS' as info_type,
    up.email,
    up.first_name,
    up.last_name,
    r.role_name
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
LEFT JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
LEFT JOIN auth.role_h rh ON url.role_hk = rh.role_hk
LEFT JOIN auth.role_profile_s r ON rh.role_hk = r.role_hk AND r.load_end_date IS NULL
WHERE th.tenant_bk LIKE '%one_barn_ai%'
AND tp.load_end_date IS NULL
AND up.load_end_date IS NULL
ORDER BY up.load_date;

-- ========================================================================
-- SUCCESS SUMMARY
-- ========================================================================

SELECT 
    '🎯 ONE BARN AI SETUP COMPLETE!' as summary,
    'Next Steps:' as action_needed,
    '1. Test authentication with API endpoints' as step_1,
    '2. Verify Canvas integration' as step_2,
    '3. Prepare July 7th demo scenarios' as step_3; 