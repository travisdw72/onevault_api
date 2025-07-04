-- ========================================================================
-- ONE_BARN_AI ENTERPRISE TENANT SETUP - ENHANCED VERSION
-- ========================================================================
-- Date: July 2, 2025
-- Objective: Create One_Barn_AI as enterprise partner tenant with horse health AI capabilities
-- Database: one_vault_site_testing (localhost)
-- Target Demo: July 7, 2025
-- Enhanced: Dynamic tenant_hk handling, error checking, comprehensive verification

-- ========================================================================
-- SETUP CONFIGURATION VARIABLES
-- ========================================================================
\set ON_ERROR_STOP on

-- Create temporary function for dynamic tenant_hk handling
CREATE OR REPLACE FUNCTION temp.get_one_barn_tenant_hk() 
RETURNS BYTEA AS $$
DECLARE
    v_tenant_hk BYTEA;
BEGIN
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
    AND tp.load_end_date IS NULL;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'One_Barn_AI tenant not found. Please run Phase 1 first.';
    END IF;
    
    RETURN v_tenant_hk;
END;
$$ LANGUAGE plpgsql;

-- ========================================================================
-- PHASE 1: TENANT CREATION WITH VALIDATION
-- ========================================================================

-- Step 1.1: Check if tenant already exists
DO $$
DECLARE
    v_tenant_exists INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_tenant_exists
    FROM auth.tenant_profile_s 
    WHERE tenant_name = 'one_barn_ai' 
    AND load_end_date IS NULL;
    
    IF v_tenant_exists > 0 THEN
        RAISE NOTICE 'One_Barn_AI tenant already exists. Skipping creation.';
    ELSE
        RAISE NOTICE 'Creating One_Barn_AI enterprise tenant...';
        
        -- Create One_Barn_AI Enterprise Tenant
        PERFORM auth.register_tenant_with_roles(
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
        );
        
        RAISE NOTICE '✅ One_Barn_AI tenant created successfully';
    END IF;
END $$;

-- Step 1.2: Verify Tenant Creation
SELECT 
    'TENANT VERIFICATION' as check_type,
    th.tenant_bk,
    tp.tenant_name,
    tp.domain_name,
    tp.subscription_level,
    tp.is_active,
    tp.load_date as created_date,
    '✅ SUCCESS' as status
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.load_end_date IS NULL
AND tp.tenant_name = 'one_barn_ai'
ORDER BY tp.load_date DESC;

-- Step 1.3: Verify Admin User Creation
SELECT 
    'ADMIN USER VERIFICATION' as check_type,
    up.email,
    up.first_name,
    up.last_name,
    tp.tenant_name,
    uas.is_active,
    CASE WHEN uas.account_locked THEN '❌ LOCKED' ELSE '✅ ACTIVE' END as account_status
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
WHERE up.load_end_date IS NULL
AND tp.load_end_date IS NULL
AND (uas.load_end_date IS NULL OR uas.load_end_date IS NULL)
AND up.email = 'admin@onebarnai.com';

-- ========================================================================
-- PHASE 2: HORSE HEALTH AI AGENT CREATION
-- ========================================================================

-- Step 2.1: Create Horse Health Specialist AI Agent
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_agent_exists INTEGER;
    v_agent_hk BYTEA;
BEGIN
    -- Get tenant hash key
    v_tenant_hk := temp.get_one_barn_tenant_hk();
    v_agent_hk := util.hash_binary('one_barn_ai_horse_health_specialist');
    
    -- Check if agent already exists
    SELECT COUNT(*) INTO v_agent_exists
    FROM ai_agents.agent_h
    WHERE agent_hk = v_agent_hk;
    
    IF v_agent_exists > 0 THEN
        RAISE NOTICE 'Horse Health Specialist AI agent already exists. Skipping creation.';
    ELSE
        RAISE NOTICE 'Creating Horse Health Specialist AI Agent...';
        
        -- Create agent hub record
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
        
        -- Create agent configuration
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
            'Specialized AI agent for analyzing horse health from photographs and videos. Trained on equine anatomy, common health conditions, and emergency indicators.',
            '["photo_analysis", "health_assessment", "emergency_detection", "breed_recognition", "lameness_detection", "wound_assessment", "body_condition_scoring"]'::jsonb,
            '{
                "base_model": "gpt-4-vision-preview",
                "specialty_model": "equine_health_v2.1",
                "image_resolution": "high",
                "analysis_depth": "comprehensive",
                "emergency_keywords": ["colic", "laminitis", "severe_injury", "distress"],
                "confidence_calibration": "conservative"
            }'::jsonb,
            'equine_health_monitoring',
            0.80,
            0.90,
            true,
            'enterprise_setup_admin',
            'enterprise_partnership_setup'
        );
        
        RAISE NOTICE '✅ Horse Health Specialist AI agent created successfully';
    END IF;
END $$;

-- Step 2.2: Create Agent Training Data Hub
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_agent_hk BYTEA;
    v_training_hk BYTEA;
    v_training_exists INTEGER;
BEGIN
    v_tenant_hk := temp.get_one_barn_tenant_hk();
    v_agent_hk := util.hash_binary('one_barn_ai_horse_health_specialist');
    v_training_hk := util.hash_binary('one_barn_ai_horse_health_training');
    
    -- Check if training data already exists
    SELECT COUNT(*) INTO v_training_exists
    FROM ai_agents.agent_training_h
    WHERE training_hk = v_training_hk;
    
    IF v_training_exists > 0 THEN
        RAISE NOTICE 'Agent training data already exists. Skipping creation.';
    ELSE
        RAISE NOTICE 'Creating agent training data configuration...';
        
        -- Create training hub
        INSERT INTO ai_agents.agent_training_h (
            training_hk,
            training_bk,
            agent_hk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_training_hk,
            'horse_health_training_dataset',
            v_agent_hk,
            v_tenant_hk,
            util.current_load_date(),
            'enterprise_partnership_setup'
        );
        
        -- Create training configuration
        INSERT INTO ai_agents.agent_training_s (
            training_hk,
            load_date,
            load_end_date,
            hash_diff,
            training_name,
            training_type,
            training_description,
            data_sources,
            training_status,
            quality_metrics,
            is_active,
            record_source
        ) VALUES (
            v_training_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary('horse_health_training_v1'),
            'Horse Health Analysis Training Dataset',
            'supervised_learning',
            'Curated dataset of horse health images with expert veterinarian annotations for training specialized health assessment models.',
            '["veterinary_clinics", "breed_associations", "research_institutions", "one_barn_user_submissions"]'::jsonb,
            'active',
            '{
                "accuracy_target": 0.95,
                "recall_target": 0.90,
                "precision_target": 0.92,
                "f1_score_target": 0.91
            }'::jsonb,
            true,
            'enterprise_partnership_setup'
        );
        
        RAISE NOTICE '✅ Agent training data configuration created successfully';
    END IF;
END $$;

-- ========================================================================
-- PHASE 3: ENTERPRISE USER SETUP
-- ========================================================================

-- Step 3.1: Create Enterprise Team Members
DO $$
DECLARE
    v_user_exists INTEGER;
BEGIN
    -- Veterinary Specialist
    SELECT COUNT(*) INTO v_user_exists
    FROM auth.user_profile_s up
    WHERE up.email = 'vet@onebarnai.com' AND up.load_end_date IS NULL;
    
    IF v_user_exists = 0 THEN
        PERFORM auth.register_user(
            p_tenant_name := 'one_barn_ai',
            p_email := 'vet@onebarnai.com',
            p_password := 'VetSpecialist2025!',
            p_first_name := 'Dr. Sarah',
            p_last_name := 'Mitchell',
            p_phone := '+1-555-VET-CARE',
            p_job_title := 'Lead Veterinary Specialist'
        );
        RAISE NOTICE '✅ Veterinary Specialist user created';
    ELSE
        RAISE NOTICE 'Veterinary Specialist user already exists. Skipping.';
    END IF;
    
    -- AI Technical Lead
    SELECT COUNT(*) INTO v_user_exists
    FROM auth.user_profile_s up
    WHERE up.email = 'tech@onebarnai.com' AND up.load_end_date IS NULL;
    
    IF v_user_exists = 0 THEN
        PERFORM auth.register_user(
            p_tenant_name := 'one_barn_ai',
            p_email := 'tech@onebarnai.com',
            p_password := 'TechLead2025!',
            p_first_name := 'Marcus',
            p_last_name := 'Rodriguez',
            p_phone := '+1-555-AI-TECH',
            p_job_title := 'AI Technical Lead'
        );
        RAISE NOTICE '✅ AI Technical Lead user created';
    ELSE
        RAISE NOTICE 'AI Technical Lead user already exists. Skipping.';
    END IF;
    
    -- Business Development Manager
    SELECT COUNT(*) INTO v_user_exists
    FROM auth.user_profile_s up
    WHERE up.email = 'business@onebarnai.com' AND up.load_end_date IS NULL;
    
    IF v_user_exists = 0 THEN
        PERFORM auth.register_user(
            p_tenant_name := 'one_barn_ai',
            p_email := 'business@onebarnai.com',
            p_password := 'BizDev2025!',
            p_first_name := 'Jennifer',
            p_last_name := 'Park',
            p_phone := '+1-555-BIZ-DEV',
            p_job_title := 'Business Development Manager'
        );
        RAISE NOTICE '✅ Business Development Manager user created';
    ELSE
        RAISE NOTICE 'Business Development Manager user already exists. Skipping.';
    END IF;
END $$;

-- ========================================================================
-- PHASE 4: DEMO PREPARATION DATA
-- ========================================================================

-- Step 4.1: Create Demo Horse Records
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_buttercup_hk BYTEA;
    v_thunder_hk BYTEA;
    v_entity_exists INTEGER;
BEGIN
    v_tenant_hk := temp.get_one_barn_tenant_hk();
    v_buttercup_hk := util.hash_binary('demo_horse_buttercup');
    v_thunder_hk := util.hash_binary('demo_horse_thunder');
    
    -- Demo Horse 1: Buttercup (Healthy)
    SELECT COUNT(*) INTO v_entity_exists
    FROM business.entity_h
    WHERE entity_hk = v_buttercup_hk;
    
    IF v_entity_exists = 0 THEN
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
            'demo_preparation'
        );
        
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
            util.hash_binary('buttercup_demo_data'),
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
                "demo_scenario": "healthy_baseline"
            }'::jsonb,
            true,
            'demo_preparation'
        );
        
        RAISE NOTICE '✅ Demo horse Buttercup created';
    ELSE
        RAISE NOTICE 'Demo horse Buttercup already exists. Skipping.';
    END IF;
    
    -- Demo Horse 2: Thunder (Minor Concern)
    SELECT COUNT(*) INTO v_entity_exists
    FROM business.entity_h
    WHERE entity_hk = v_thunder_hk;
    
    IF v_entity_exists = 0 THEN
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
            'demo_preparation'
        );
        
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
            util.hash_binary('thunder_demo_data'),
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
                "demo_scenario": "minor_lameness_detection"
            }'::jsonb,
            true,
            'demo_preparation'
        );
        
        RAISE NOTICE '✅ Demo horse Thunder created';
    ELSE
        RAISE NOTICE 'Demo horse Thunder already exists. Skipping.';
    END IF;
END $$;

-- ========================================================================
-- COMPREHENSIVE VERIFICATION
-- ========================================================================

-- Final Setup Verification Report
SELECT 
    'SETUP VERIFICATION REPORT' as report_title,
    CURRENT_TIMESTAMP as generated_at;

-- Tenant Status
SELECT 
    '1. TENANT SETUP' as verification_step,
    tp.tenant_name,
    tp.domain_name,
    tp.subscription_level,
    tp.is_active,
    '✅ SUCCESS' as status
FROM auth.tenant_profile_s tp
WHERE tp.tenant_name = 'one_barn_ai' 
AND tp.load_end_date IS NULL;

-- User Count
SELECT 
    '2. USER SETUP' as verification_step,
    COUNT(*) as user_count,
    CASE WHEN COUNT(*) >= 4 THEN '✅ SUCCESS' ELSE '❌ NEEDS ATTENTION' END as status
FROM auth.user_profile_s up
JOIN auth.user_h uh ON up.user_hk = uh.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND up.load_end_date IS NULL
AND tp.load_end_date IS NULL;

-- AI Agent Status
SELECT 
    '3. AI AGENT SETUP' as verification_step,
    agent_name,
    agent_type,
    agent_status,
    specialization_area,
    '✅ SUCCESS' as status
FROM ai_agents.agent_s
WHERE agent_name = 'Horse Health Specialist'
AND load_end_date IS NULL;

-- Demo Data Status
SELECT 
    '4. DEMO DATA SETUP' as verification_step,
    COUNT(*) as demo_horses_count,
    CASE WHEN COUNT(*) >= 2 THEN '✅ SUCCESS' ELSE '❌ NEEDS ATTENTION' END as status
FROM business.entity_details_s
WHERE entity_type = 'horse'
AND entity_metadata->>'demo_scenario' IS NOT NULL
AND load_end_date IS NULL;

-- Clean up temporary function
DROP FUNCTION IF EXISTS temp.get_one_barn_tenant_hk();

-- ========================================================================
-- DEMO QUERIES - READY TO USE ON JULY 7TH
-- ========================================================================

-- Demo Query 1: Tenant Dashboard Overview
SELECT 
    'TENANT OVERVIEW' as section,
    tp.tenant_name as "Tenant Name",
    tp.business_name as "Business Name",
    tp.domain_name as "Domain",
    tp.subscription_level as "Subscription",
    COUNT(DISTINCT up.email) as "Total Users",
    tp.load_date::date as "Created Date"
FROM auth.tenant_profile_s tp
JOIN auth.tenant_h th ON tp.tenant_hk = th.tenant_hk
LEFT JOIN auth.user_h uh ON th.tenant_hk = uh.tenant_hk
LEFT JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL
AND (up.load_end_date IS NULL OR up.load_end_date IS NULL)
GROUP BY tp.tenant_name, tp.business_name, tp.domain_name, tp.subscription_level, tp.load_date;

-- Demo Query 2: AI Agent Capabilities Showcase
SELECT 
    'AI AGENT CAPABILITIES' as section,
    agent_name as "Agent Name",
    agent_type as "Type",
    specialization_area as "Specialization",
    confidence_threshold as "Confidence Threshold",
    emergency_threshold as "Emergency Threshold",
    capabilities as "Capabilities"
FROM ai_agents.agent_s
WHERE agent_name = 'Horse Health Specialist'
AND load_end_date IS NULL;

-- Demo Query 3: Demo Horses for Live Analysis
SELECT 
    'DEMO HORSES' as section,
    entity_name as "Horse Name",
    entity_metadata->>'breed' as "Breed",
    entity_metadata->>'age' as "Age",
    entity_metadata->>'gender' as "Gender",
    entity_metadata->>'health_status' as "Health Status",
    entity_metadata->>'demo_scenario' as "Demo Scenario"
FROM business.entity_details_s
WHERE entity_type = 'horse'
AND entity_metadata->>'demo_scenario' IS NOT NULL
AND load_end_date IS NULL
ORDER BY entity_name;

-- ========================================================================
-- SUCCESS CONFIRMATION
-- ========================================================================

SELECT 
    '🎉 ONE_BARN_AI ENTERPRISE SETUP COMPLETE!' as message,
    'Ready for July 7th Demo' as status,
    CURRENT_TIMESTAMP as completion_time; 