-- ========================================================================
-- ONE_BARN_AI ENTERPRISE SETUP - FINAL VERSION FOR JULY 7TH DEMO
-- ========================================================================
-- Date: July 2, 2025
-- Database: one_vault_site_testing
-- Demo Date: July 7, 2025
-- Purpose: Create One_Barn_AI enterprise tenant with horse health AI capabilities

\set ON_ERROR_STOP on
\timing on

-- ========================================================================
-- PHASE 1: TENANT CREATION
-- ========================================================================

DO $$
DECLARE
    v_tenant_exists INTEGER;
    v_setup_result TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Starting One_Barn_AI Enterprise Setup for July 7th Demo';
    RAISE NOTICE '============================================================';
    
    -- Check if tenant already exists
    SELECT COUNT(*) INTO v_tenant_exists
    FROM auth.tenant_profile_s 
    WHERE tenant_name = 'one_barn_ai' 
    AND load_end_date IS NULL;
    
    IF v_tenant_exists > 0 THEN
        RAISE NOTICE '⚠️  One_Barn_AI tenant already exists. Skipping creation.';
    ELSE
        RAISE NOTICE '📝 Creating One_Barn_AI enterprise tenant...';
        
        -- Create One_Barn_AI Enterprise Tenant
        SELECT auth.register_tenant_with_roles(
            p_tenant_name := 'one_barn_ai',
            p_business_name := 'One Barn AI Solutions',
            p_admin_email := 'admin@onebarnai.com',
            p_admin_password := 'HorseHealth2025!',
            p_contact_phone := '+1-555-HORSE-AI',
            p_tenant_description := 'Enterprise AI partner specializing in equine health monitoring and analysis',
            p_industry_type := 'agriculture_technology',
            p_subscription_level := 'enterprise_partner',
            p_domain_name := 'onebarnai.com',
            p_record_source := 'enterprise_partnership_setup'
        ) INTO v_setup_result;
        
        RAISE NOTICE '✅ One_Barn_AI tenant created successfully';
    END IF;
END $$;

-- ========================================================================
-- PHASE 2: CREATE ENTERPRISE TEAM USERS
-- ========================================================================

DO $$
DECLARE
    v_user_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '👥 Creating enterprise team users...';
    
    -- Create team users with error handling
    BEGIN
        PERFORM auth.register_user(
            p_tenant_name := 'one_barn_ai',
            p_email := 'vet@onebarnai.com',
            p_password := 'VetSpecialist2025!',
            p_first_name := 'Dr. Sarah',
            p_last_name := 'Mitchell',
            p_phone := '+1-555-VET-CARE',
            p_job_title := 'Lead Veterinary Specialist'
        );
        RAISE NOTICE '✅ Veterinary Specialist created';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠️  Veterinary Specialist may already exist';
    END;
    
    BEGIN
        PERFORM auth.register_user(
            p_tenant_name := 'one_barn_ai',
            p_email := 'tech@onebarnai.com',
            p_password := 'TechLead2025!',
            p_first_name := 'Marcus',
            p_last_name := 'Rodriguez',
            p_phone := '+1-555-AI-TECH',
            p_job_title := 'AI Technical Lead'
        );
        RAISE NOTICE '✅ AI Technical Lead created';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠️  AI Technical Lead may already exist';
    END;
    
    BEGIN
        PERFORM auth.register_user(
            p_tenant_name := 'one_barn_ai',
            p_email := 'business@onebarnai.com',
            p_password := 'BizDev2025!',
            p_first_name := 'Jennifer',
            p_last_name := 'Park',
            p_phone := '+1-555-BIZ-DEV',
            p_job_title := 'Business Development Manager'
        );
        RAISE NOTICE '✅ Business Development Manager created';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠️  Business Development Manager may already exist';
    END;
    
    -- Count total users
    SELECT COUNT(*) INTO v_user_count
    FROM auth.user_profile_s up
    JOIN auth.user_h uh ON up.user_hk = uh.user_hk
    JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
    AND up.load_end_date IS NULL
    AND tp.load_end_date IS NULL;
    
    RAISE NOTICE '✅ Total users for One_Barn_AI: %', v_user_count;
END $$;

-- ========================================================================
-- PHASE 3: CREATE DEMO HORSES FOR JULY 7TH
-- ========================================================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_buttercup_hk BYTEA;
    v_thunder_hk BYTEA;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🐴 Creating demo horses for July 7th demo...';
    
    -- Get tenant hash key
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
    AND tp.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION '❌ Could not find One_Barn_AI tenant';
    END IF;
    
    v_buttercup_hk := util.hash_binary('demo_horse_buttercup');
    v_thunder_hk := util.hash_binary('demo_horse_thunder');
    
    -- Demo Horse 1: Buttercup (Healthy Baseline)
    INSERT INTO business.entity_h (
        entity_hk,
        entity_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_buttercup_hk,
        'HORSE_BUTTERCUP_DEMO',
        v_tenant_hk,
        util.current_load_date(),
        'demo_preparation_july_7'
    ) ON CONFLICT (entity_hk) DO NOTHING;
    
    INSERT INTO business.entity_details_s (
        entity_hk,
        load_date,
        load_end_date,
        hash_diff,
        entity_name,
        entity_type,
        entity_description,
        entity_metadata,
        is_active,
        record_source
    ) VALUES (
        v_buttercup_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary('buttercup_demo_july7'),
        'Buttercup',
        'horse',
        'Demo horse for health analysis - 8-year-old Thoroughbred mare in excellent health',
        '{
            "breed": "Thoroughbred",
            "age": 8,
            "gender": "mare",
            "color": "chestnut",
            "height": "16.2 hands",
            "weight": "1100 lbs",
            "health_status": "excellent",
            "last_checkup": "2025-06-15",
            "vaccinations_current": true,
            "demo_scenario": "healthy_baseline",
            "demo_date": "2025-07-07",
            "ai_analysis_ready": true
        }'::jsonb,
        true,
        'demo_preparation_july_7'
    ) ON CONFLICT (entity_hk, load_date) DO UPDATE SET
        entity_metadata = EXCLUDED.entity_metadata,
        hash_diff = EXCLUDED.hash_diff;
    
    -- Demo Horse 2: Thunder (Minor Lameness)
    INSERT INTO business.entity_h (
        entity_hk,
        entity_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_thunder_hk,
        'HORSE_THUNDER_DEMO',
        v_tenant_hk,
        util.current_load_date(),
        'demo_preparation_july_7'
    ) ON CONFLICT (entity_hk) DO NOTHING;
    
    INSERT INTO business.entity_details_s (
        entity_hk,
        load_date,
        load_end_date,
        hash_diff,
        entity_name,
        entity_type,
        entity_description,
        entity_metadata,
        is_active,
        record_source
    ) VALUES (
        v_thunder_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary('thunder_demo_july7'),
        'Thunder',
        'horse',
        'Demo horse showing minor lameness for AI analysis demonstration',
        '{
            "breed": "Quarter Horse",
            "age": 12,
            "gender": "gelding",
            "color": "bay",
            "height": "15.1 hands",
            "weight": "1050 lbs",
            "health_status": "minor_concern",
            "concern_type": "mild_lameness_front_left",
            "severity": "grade_1",
            "demo_scenario": "minor_lameness_detection",
            "demo_date": "2025-07-07",
            "ai_analysis_ready": true
        }'::jsonb,
        true,
        'demo_preparation_july_7'
    ) ON CONFLICT (entity_hk, load_date) DO UPDATE SET
        entity_metadata = EXCLUDED.entity_metadata,
        hash_diff = EXCLUDED.hash_diff;
    
    RAISE NOTICE '✅ Demo horses Buttercup and Thunder ready for July 7th';
END $$;

-- ========================================================================
-- DEMO VERIFICATION QUERIES
-- ========================================================================

\echo ''
\echo '📊 JULY 7TH DEMO VERIFICATION'
\echo '============================================================'

-- 1. Tenant Status
SELECT 
    '🏢 TENANT STATUS' as category,
    tp.tenant_name as "Name",
    tp.business_name as "Business",
    tp.subscription_level as "Level",
    CASE WHEN tp.is_active THEN '✅ READY' ELSE '❌ INACTIVE' END as "Demo Ready"
FROM auth.tenant_profile_s tp
WHERE tp.tenant_name = 'one_barn_ai' 
AND tp.load_end_date IS NULL;

-- 2. Demo Team
SELECT 
    '👥 DEMO TEAM' as category,
    up.first_name || ' ' || up.last_name as "Name",
    up.email as "Login Email",
    up.job_title as "Role",
    CASE WHEN uas.is_active THEN '✅ ACTIVE' ELSE '❌ INACTIVE' END as "Status"
FROM auth.user_profile_s up
JOIN auth.user_h uh ON up.user_hk = uh.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND up.load_end_date IS NULL
AND tp.load_end_date IS NULL
AND (uas.load_end_date IS NULL OR uas.load_end_date IS NULL)
ORDER BY up.email;

-- 3. Demo Horses
SELECT 
    '🐴 DEMO HORSES' as category,
    ed.entity_name as "Horse Name",
    ed.entity_metadata->>'breed' as "Breed",
    ed.entity_metadata->>'demo_scenario' as "Demo Scenario",
    ed.entity_metadata->>'health_status' as "Health Status",
    CASE WHEN ed.entity_metadata->>'ai_analysis_ready' = 'true' THEN '✅ READY' ELSE '⚠️ PENDING' END as "AI Ready"
FROM business.entity_details_s ed
JOIN business.entity_h eh ON ed.entity_hk = eh.entity_hk
JOIN auth.tenant_h th ON eh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND ed.entity_type = 'horse'
AND ed.load_end_date IS NULL
AND tp.load_end_date IS NULL
ORDER BY ed.entity_name;

-- ========================================================================
-- API TEST COMMANDS FOR DEMO
-- ========================================================================

\echo ''
\echo '🔧 API TEST COMMANDS FOR JULY 7TH DEMO'
\echo '============================================================'

SELECT 
    'AUTHENTICATION TEST' as test_type,
    'Run this in pgAdmin to test login:' as instruction;

-- Show the authentication command
\echo 'SELECT api.auth_login(''{''
\echo '    "username": "admin@onebarnai.com",'
\echo '    "password": "HorseHealth2025!",'
\echo '    "ip_address": "127.0.0.1",'
\echo '    "user_agent": "OneVault-July7-Demo",'
\echo '    "auto_login": true'
\echo '}'');'

SELECT 
    'SYSTEM HEALTH TEST' as test_type,
    'Run this to check system status:' as instruction;

\echo 'SELECT api.system_health_check(''{}'')'

-- ========================================================================
-- DEMO DAY CHECKLIST
-- ========================================================================

\echo ''
\echo '📋 JULY 7TH DEMO DAY CHECKLIST'
\echo '============================================================'
\echo '[ ] Database connection tested'
\echo '[ ] One_Barn_AI tenant active'
\echo '[ ] Admin login working'
\echo '[ ] Demo horses loaded'
\echo '[ ] API endpoints responding'
\echo '[ ] Canvas app configured'
\echo '[ ] Presentation slides ready'
\echo '[ ] Revenue model prepared'
\echo ''
\echo '🎯 DEMO CREDENTIALS:'
\echo '   Admin: admin@onebarnai.com / HorseHealth2025!'
\echo '   Vet: vet@onebarnai.com / VetSpecialist2025!'
\echo '   Tech: tech@onebarnai.com / TechLead2025!'
\echo '   Business: business@onebarnai.com / BizDev2025!'
\echo ''
\echo '🐴 DEMO SCENARIOS:'
\echo '   1. Buttercup - Healthy horse baseline analysis'
\echo '   2. Thunder - Minor lameness detection'
\echo ''
\echo '💰 PARTNERSHIP VALUE PROPS:'
\echo '   • Custom AI agents vs generic services'
\echo '   • OneVault handles tech infrastructure'
\echo '   • One_Barn_AI focuses on horse expertise'
\echo '   • Revenue sharing model'
\echo '   • Faster time to market'
\echo ''
\echo '🎉 ONE_BARN_AI READY FOR JULY 7TH DEMO!'
\echo '============================================================' 