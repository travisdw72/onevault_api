-- ==========================================
-- STEP 7: AUGMENTED LEARNING INTEGRATION - PRODUCTION VERSION
-- Integrate existing production agents with AI/ML learning system
-- Uses REAL production functions: agents.process_agent_request, agents.vet_agent_process, business.ai_learn_from_data
-- ==========================================

BEGIN;

-- ==========================================
-- PRODUCTION AGENT INTEGRATION FUNCTIONS
-- ==========================================

-- Enhanced Horse Image Analysis using REAL production functions
CREATE OR REPLACE FUNCTION ai_agents.process_image_batch_with_learning_production(
    p_tenant_hk BYTEA,
    p_horse_id VARCHAR(100),
    p_image_urls TEXT[],
    p_batch_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE (
    success BOOLEAN,
    batch_id VARCHAR(255),
    processing_status VARCHAR(100),
    findings_summary JSONB,
    learning_insights JSONB
) AS $$
DECLARE
    v_image_analysis_result JSONB;
    v_vet_analysis_result JSONB;
    v_learning_data JSONB;
    v_batch_id VARCHAR(255);
    v_success BOOLEAN := true;
    v_findings JSONB := '[]'::jsonb;
BEGIN
    -- Generate batch ID
    v_batch_id := 'BATCH_' || encode(util.hash_binary(p_horse_id || CURRENT_TIMESTAMP::text), 'hex');
    
    -- Step 1: Process images with REAL Image Analyzer Agent (via orchestrator)
    FOR i IN 1..array_length(p_image_urls, 1) LOOP
        BEGIN
            -- Use REAL production orchestrator
            SELECT agents.process_agent_request(
                p_tenant_hk,
                'image_analysis',
                p_horse_id,
                jsonb_build_object(
                    'image_url', p_image_urls[i],
                    'analysis_type', ARRAY['health', 'lameness', 'injuries'],
                    'horse_id', p_horse_id,
                    'batch_id', v_batch_id,
                    'image_index', i
                )
            ) INTO v_image_analysis_result;
            
            -- Collect findings
            v_findings := v_findings || jsonb_build_object(
                'image_index', i,
                'image_url', p_image_urls[i],
                'analysis_result', v_image_analysis_result
            );
            
        EXCEPTION WHEN OTHERS THEN
            v_success := false;
            v_findings := v_findings || jsonb_build_object(
                'image_index', i,
                'image_url', p_image_urls[i],
                'error', SQLERRM
            );
        END;
    END LOOP;
    
    -- Step 2: Send image analysis results to REAL Equine Health Specialist
    IF v_success AND jsonb_array_length(v_findings) > 0 THEN
        BEGIN
            -- Use REAL production vet agent
            SELECT agents.vet_agent_process(
                p_tenant_hk,
                p_horse_id,
                jsonb_build_object(
                    'image_analysis_findings', v_findings,
                    'batch_id', v_batch_id,
                    'analysis_type', 'comprehensive_health_assessment',
                    'source', 'image_analysis_batch'
                )
            ) INTO v_vet_analysis_result;
            
        EXCEPTION WHEN OTHERS THEN
            v_vet_analysis_result := jsonb_build_object(
                'success', false,
                'error', 'Vet agent processing failed: ' || SQLERRM
            );
        END;
    END IF;
    
    -- Step 3: Learn from the complete analysis using REAL AI/ML system
    v_learning_data := jsonb_build_object(
        'horse_id', p_horse_id,
        'batch_id', v_batch_id,
        'image_count', array_length(p_image_urls, 1),
        'image_findings', v_findings,
        'vet_analysis', v_vet_analysis_result,
        'batch_metadata', p_batch_metadata,
        'analysis_timestamp', CURRENT_TIMESTAMP
    );
    
    -- Feed to REAL AI/ML learning system
    PERFORM business.ai_learn_from_data(
        p_tenant_hk,
        'equine_visual_analysis',
        'image_batch',
        p_horse_id,
        jsonb_build_array(v_learning_data)
    );
    
    -- Cross-domain learning: visual findings → health patterns
    PERFORM business.ai_learn_from_data(
        p_tenant_hk,
        'equine_health',
        'horse',
        p_horse_id,
        jsonb_build_array(
            jsonb_build_object(
                'source', 'visual_analysis',
                'health_insights', v_vet_analysis_result,
                'visual_data_points', jsonb_array_length(v_findings),
                'cross_domain_learning', true
            )
        )
    );
    
    RETURN QUERY SELECT 
        v_success,
        v_batch_id,
        (CASE WHEN v_success THEN 'COMPLETED' ELSE 'PARTIAL_FAILURE' END)::VARCHAR(100),
        jsonb_build_object(
            'image_analysis', v_findings,
            'vet_analysis', v_vet_analysis_result,
            'total_images', array_length(p_image_urls, 1)
        ),
        jsonb_build_object(
            'learning_applied', true,
            'domains', ARRAY['equine_visual_analysis', 'equine_health'],
            'learning_mode', 'PRODUCTION',
            'cross_domain_transfer', true,
            'data_points_learned', jsonb_array_length(v_findings)
        );
        
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        false,
        COALESCE(v_batch_id, 'ERROR_BATCH')::VARCHAR(255),
        'FAILED'::VARCHAR(100),
        jsonb_build_object('error', SQLERRM),
        jsonb_build_object('learning_applied', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- PRODUCTION TEMPLATE AGENT WORKFLOW
-- ==========================================

-- Create user agents from existing templates using REAL production agents
CREATE OR REPLACE FUNCTION ai_agents.create_production_horse_health_agent(
    p_tenant_hk BYTEA,
    p_user_name VARCHAR(100),
    p_horse_id VARCHAR(100),
    p_configuration JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE (
    agent_hk BYTEA,
    agent_created BOOLEAN,
    template_used VARCHAR(255),
    production_ready BOOLEAN
) AS $$
DECLARE
    v_template_hk BYTEA;
    v_user_agent_result RECORD;
    v_horse_template_config JSONB;
BEGIN
    -- Get the REAL production horse health template
    SELECT agent_template_hk INTO v_template_hk
    FROM ai_agents.agent_template_h 
    WHERE agent_template_bk = 'HORSE_HEALTH_ANALYZER_V1';
    
    IF v_template_hk IS NULL THEN
        RAISE EXCEPTION 'Horse Health Analyzer template not found. Run USER_AGENT_BUILDER_SCHEMA first.';
    END IF;
    
    -- Enhanced configuration for production use
    v_horse_template_config := jsonb_build_object(
        'horse_id', p_horse_id,
        'analysis_focus', ARRAY['health', 'lameness', 'injuries', 'body_condition'],
        'confidence_thresholds', jsonb_build_object(
            'injury_detection', 0.7,
            'lameness_assessment', 0.6,
            'urgent_findings', 0.9
        ),
        'integration_mode', 'PRODUCTION',
        'backend_agents', jsonb_build_object(
            'image_analyzer', 'agents.process_agent_request',
            'health_specialist', 'agents.vet_agent_process',
            'learning_system', 'business.ai_learn_from_data'
        ),
        'user_configuration', p_configuration
    );
    
    -- Create user agent using existing function
    SELECT * INTO v_user_agent_result
    FROM ai_agents.create_user_agent(
        p_tenant_hk,
        v_template_hk,
        p_user_name,
        v_horse_template_config
    );
    
    RETURN QUERY SELECT 
        v_user_agent_result.user_agent_hk,
        true,
        'HORSE_HEALTH_ANALYZER_V1'::VARCHAR(255),
        true;
        
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        NULL::BYTEA,
        false,
        'HORSE_HEALTH_ANALYZER_V1'::VARCHAR(255),
        false;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- PRODUCTION WORKFLOW ORCHESTRATION
-- ==========================================

-- Execute complete horse health workflow using REAL production agents
CREATE OR REPLACE FUNCTION ai_agents.execute_complete_horse_health_workflow(
    p_tenant_hk BYTEA,
    p_horse_id VARCHAR(100),
    p_image_urls TEXT[],
    p_user_agent_hk BYTEA,
    p_workflow_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE (
    workflow_success BOOLEAN,
    workflow_id VARCHAR(255),
    image_analysis_summary JSONB,
    health_assessment JSONB,
    learning_summary JSONB,
    recommendations JSONB
) AS $$
DECLARE
    v_workflow_id VARCHAR(255);
    v_batch_result RECORD;
    v_final_recommendations JSONB;
BEGIN
    -- Generate workflow ID
    v_workflow_id := 'WORKFLOW_' || encode(util.hash_binary(p_horse_id || CURRENT_TIMESTAMP::text), 'hex');
    
    -- Execute the complete workflow using production functions
    SELECT * INTO v_batch_result
    FROM ai_agents.process_image_batch_with_learning_production(
        p_tenant_hk,
        p_horse_id,
        p_image_urls,
        p_workflow_metadata || jsonb_build_object('workflow_id', v_workflow_id)
    );
    
    -- Generate final recommendations
    v_final_recommendations := jsonb_build_object(
        'immediate_actions', CASE 
            WHEN v_batch_result.findings_summary->'vet_analysis'->>'success' = 'true' THEN
                v_batch_result.findings_summary->'vet_analysis'->'analysis'->'recommendations'
            ELSE 
                jsonb_build_array('Review image analysis results with veterinarian')
        END,
        'monitoring_schedule', jsonb_build_object(
            'frequency', 'weekly',
            'focus_areas', ARRAY['areas identified in image analysis']
        ),
        'learning_insights', v_batch_result.learning_insights
    );
    
    RETURN QUERY SELECT 
        v_batch_result.success,
        v_workflow_id::VARCHAR(255),
        v_batch_result.findings_summary->'image_analysis',
        v_batch_result.findings_summary->'vet_analysis',
        v_batch_result.learning_insights,
        v_final_recommendations;
        
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        false,
        COALESCE(v_workflow_id, 'ERROR_WORKFLOW')::VARCHAR(255),
        jsonb_build_object('error', SQLERRM),
        jsonb_build_object('error', SQLERRM),
        jsonb_build_object('error', SQLERRM),
        jsonb_build_object('error', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- SUCCESS MESSAGE
-- ==========================================

DO $$ 
BEGIN
    RAISE NOTICE '✅ PRODUCTION Augmented Learning Integration completed successfully!';
    RAISE NOTICE '🔧 All functions use REAL production agents:';
    RAISE NOTICE '   - Orchestrator: agents.process_agent_request()';
    RAISE NOTICE '   - Image Analyzer: HORSE_HEALTH_ANALYZER_V1 template';
    RAISE NOTICE '   - Health Specialist: agents.vet_agent_process()';
    RAISE NOTICE '   - Learning System: business.ai_learn_from_data()';
    RAISE NOTICE '🚀 Ready for immediate production use with real agent templates!';
    RAISE NOTICE '📝 FIXED: Type casting issues resolved (VARCHAR/TEXT compatibility)';
END $$;

COMMIT; 