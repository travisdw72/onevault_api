-- ==========================================
-- ROLLBACK: STEP 12 AUGMENTED LEARNING INTEGRATION - PRODUCTION VERSION
-- ==========================================
-- Safely removes all production augmented learning integration components
-- This rollback removes ONLY the functions created in step12, preserving existing agent infrastructure
-- ==========================================

BEGIN;

-- ==========================================
-- DROP PRODUCTION AUGMENTED LEARNING FUNCTIONS
-- ==========================================

-- Drop production workflow orchestration function
DROP FUNCTION IF EXISTS ai_agents.execute_complete_horse_health_workflow(
    BYTEA, VARCHAR(100), TEXT[], BYTEA, JSONB
);

-- Drop production template agent creation function
DROP FUNCTION IF EXISTS ai_agents.create_production_horse_health_agent(
    BYTEA, VARCHAR(100), VARCHAR(100), JSONB
);

-- Drop main production image batch processing function
DROP FUNCTION IF EXISTS ai_agents.process_image_batch_with_learning_production(
    BYTEA, VARCHAR(100), TEXT[], JSONB
);

-- ==========================================
-- VERIFY CLEANUP
-- ==========================================

-- Verify functions were removed
DO $$
DECLARE
    v_function_count INTEGER;
BEGIN
    -- Check for remaining production learning functions
    SELECT COUNT(*) INTO v_function_count
    FROM information_schema.routines 
    WHERE routine_schema = 'ai_agents' 
    AND routine_name IN (
        'process_image_batch_with_learning_production',
        'create_production_horse_health_agent',
        'execute_complete_horse_health_workflow'
    );
    
    IF v_function_count > 0 THEN
        RAISE WARNING 'Some production learning functions may still exist. Manual cleanup may be required.';
    ELSE
        RAISE NOTICE '✅ All production augmented learning functions successfully removed';
    END IF;
    
    -- Verify core agent infrastructure is preserved
    SELECT COUNT(*) INTO v_function_count
    FROM information_schema.routines 
    WHERE routine_schema = 'ai_agents' 
    AND routine_name IN (
        'create_user_agent',
        'get_predefined_agent_templates'
    );
    
    IF v_function_count >= 2 THEN
        RAISE NOTICE '✅ Core agent infrastructure preserved';
    ELSE
        RAISE WARNING '⚠️  Core agent infrastructure may be affected. Check agent template functions.';
    END IF;
END $$;

-- ==========================================
-- PRESERVATION NOTICE
-- ==========================================

DO $$
BEGIN
    RAISE NOTICE '==========================================';
    RAISE NOTICE '🔄 ROLLBACK COMPLETED: Production Augmented Learning Integration';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '✅ REMOVED:';
    RAISE NOTICE '   - ai_agents.process_image_batch_with_learning_production()';
    RAISE NOTICE '   - ai_agents.create_production_horse_health_agent()';
    RAISE NOTICE '   - ai_agents.execute_complete_horse_health_workflow()';
    RAISE NOTICE '';
    RAISE NOTICE '✅ PRESERVED:';
    RAISE NOTICE '   - All agent template tables and data';
    RAISE NOTICE '   - Core agent creation functions';
    RAISE NOTICE '   - All production agents (process_agent_request, vet_agent_process)';
    RAISE NOTICE '   - AI/ML learning system (business.ai_learn_from_data)';
    RAISE NOTICE '   - User agent builder infrastructure';
    RAISE NOTICE '';
    RAISE NOTICE '📝 NEXT STEPS:';
    RAISE NOTICE '   - Re-run step12 with fixed version if needed';
    RAISE NOTICE '   - Or continue with frontend integration';
    RAISE NOTICE '==========================================';
END $$;

COMMIT; 