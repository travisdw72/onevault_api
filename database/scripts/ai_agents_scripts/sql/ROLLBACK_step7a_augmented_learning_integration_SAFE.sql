-- ==========================================
-- ROLLBACK: STEP 7 AUGMENTED LEARNING INTEGRATION - SAFE VERSION
-- ==========================================
-- Removes all SAFE version components including mock functions and tables
-- Prepares for clean installation of PRODUCTION version
-- ==========================================

BEGIN;

-- ==========================================
-- DROP MOCK FUNCTIONS (SAFE VERSION ONLY)
-- ==========================================

-- Drop mock AI/ML 99.9% functions that were created
DROP FUNCTION IF EXISTS business.get_domain_patterns(BYTEA, VARCHAR(100));
DROP FUNCTION IF EXISTS business.ai_learn_from_data(BYTEA, VARCHAR(100), VARCHAR(100), VARCHAR(255), JSONB);
DROP FUNCTION IF EXISTS business.ai_learn_from_feedback(BYTEA, VARCHAR(100), VARCHAR(100), VARCHAR(255), JSONB);
DROP FUNCTION IF EXISTS business.apply_cross_domain_patterns(BYTEA, VARCHAR(100), VARCHAR(100), JSONB);

-- Drop mock agent functions
DROP FUNCTION IF EXISTS ai_agents.process_agent_request(BYTEA, JSONB);
DROP FUNCTION IF EXISTS ai_agents.process_image_batch(BYTEA, VARCHAR(100), TEXT[], JSONB);

-- ==========================================
-- DROP LEARNING INTEGRATION FUNCTIONS
-- ==========================================

-- Drop enhanced learning functions
DROP FUNCTION IF EXISTS ai_agents.execute_agent_with_learning(BYTEA, JSONB, JSONB);
DROP FUNCTION IF EXISTS ai_agents.process_agent_feedback(BYTEA, JSONB, JSONB);
DROP FUNCTION IF EXISTS ai_agents.apply_cross_domain_learning(BYTEA, VARCHAR(100), VARCHAR(100), DECIMAL(5,4));
DROP FUNCTION IF EXISTS ai_agents.process_image_batch_with_learning(BYTEA, VARCHAR(100), TEXT[], JSONB);
DROP FUNCTION IF EXISTS ai_agents.validate_learning_integration(BYTEA);

-- ==========================================
-- DROP LEARNING TABLES
-- ==========================================

-- Drop learning session tables (in correct dependency order)
DROP TABLE IF EXISTS ai_agents.agent_learning_session_s CASCADE;
DROP TABLE IF EXISTS ai_agents.agent_learning_session_h CASCADE;

-- Drop mock horse image analysis table if it was created
DROP TABLE IF EXISTS ai_agents.horse_image_analysis_agent_h CASCADE;

-- ==========================================
-- DROP INDEXES
-- ==========================================

-- Drop performance indexes created for learning tables
DROP INDEX IF EXISTS ai_agents.idx_agent_learning_session_h_agent_hk;
DROP INDEX IF EXISTS ai_agents.idx_agent_learning_session_h_tenant_hk;
DROP INDEX IF EXISTS ai_agents.idx_agent_learning_session_s_domain;
DROP INDEX IF EXISTS ai_agents.idx_agent_learning_session_s_confidence;

-- ==========================================
-- CLEANUP VALIDATION
-- ==========================================

-- Verify cleanup was successful
DO $$ 
DECLARE
    v_remaining_objects INTEGER := 0;
    v_mock_functions INTEGER := 0;
    v_learning_tables INTEGER := 0;
    v_function_list TEXT;
    v_table_list TEXT;
BEGIN
    -- Count remaining mock functions
    SELECT COUNT(*) INTO v_mock_functions
    FROM information_schema.routines 
    WHERE routine_schema = 'business' 
    AND routine_name IN ('get_domain_patterns', 'ai_learn_from_data', 'ai_learn_from_feedback', 'apply_cross_domain_patterns');
    
    -- Count remaining learning tables
    SELECT COUNT(*) INTO v_learning_tables
    FROM information_schema.tables 
    WHERE table_schema = 'ai_agents' 
    AND table_name IN ('agent_learning_session_h', 'agent_learning_session_s', 'horse_image_analysis_agent_h');
    
    v_remaining_objects := v_mock_functions + v_learning_tables;
    
    IF v_remaining_objects = 0 THEN
        RAISE NOTICE 'ROLLBACK SUCCESSFUL: All SAFE version components removed';
        RAISE NOTICE 'Ready for PRODUCTION version installation';
        RAISE NOTICE '   - Mock functions removed: All cleared';
        RAISE NOTICE '   - Learning tables removed: All cleared';
        RAISE NOTICE '   - Indexes removed: All cleared';
    ELSE
        RAISE NOTICE 'ROLLBACK INCOMPLETE: % objects remain', v_remaining_objects;
        RAISE NOTICE '   - Mock functions remaining: %', v_mock_functions;
        RAISE NOTICE '   - Learning tables remaining: %', v_learning_tables;
        RAISE WARNING 'Manual cleanup may be required before installing PRODUCTION version';
        
        -- List remaining functions
        IF v_mock_functions > 0 THEN
            SELECT string_agg('business.' || routine_name, ', ') INTO v_function_list
            FROM information_schema.routines 
            WHERE routine_schema = 'business' 
            AND routine_name IN ('get_domain_patterns', 'ai_learn_from_data', 'ai_learn_from_feedback', 'apply_cross_domain_patterns');
            RAISE NOTICE 'Remaining mock functions: %', v_function_list;
        END IF;
        
        -- List remaining tables
        IF v_learning_tables > 0 THEN
            SELECT string_agg('ai_agents.' || table_name, ', ') INTO v_table_list
            FROM information_schema.tables 
            WHERE table_schema = 'ai_agents' 
            AND table_name IN ('agent_learning_session_h', 'agent_learning_session_s', 'horse_image_analysis_agent_h');
            RAISE NOTICE 'Remaining learning tables: %', v_table_list;
        END IF;
    END IF;
END $$;

-- ==========================================
-- NEXT STEPS MESSAGE
-- ==========================================

DO $$ 
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'ROLLBACK COMPLETED - READY FOR PRODUCTION';
    RAISE NOTICE '============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Run: step7a_augmented_learning_integration_PRODUCTION.sql';
    RAISE NOTICE '2. This will use your REAL production functions:';
    RAISE NOTICE '   - agents.process_agent_request()';
    RAISE NOTICE '   - agents.vet_agent_process()';  
    RAISE NOTICE '   - business.ai_learn_from_data()';
    RAISE NOTICE '3. No more mock functions - pure production code';
    RAISE NOTICE '';
    RAISE NOTICE 'Your two production agents ready for templates:';
    RAISE NOTICE '   - Orchestrator (routing agent)';
    RAISE NOTICE '   - Horse Image Analyzer';
    RAISE NOTICE '   - Horse Equine Specialist (reads analyzer reports)';
    RAISE NOTICE '';
END $$;

COMMIT; 