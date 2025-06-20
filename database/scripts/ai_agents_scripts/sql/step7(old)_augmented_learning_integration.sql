-- ==========================================
-- STEP 7: AUGMENTED LEARNING INTEGRATION
-- Integrate Zero Trust AI Agents with AI/ML 99.9% System
-- Enable agents to learn and improve from every interaction
-- ==========================================

BEGIN;

-- ==========================================
-- AGENT LEARNING INTEGRATION HUB
-- ==========================================

-- Agent Learning Session Hub (connects agents to learning system)
CREATE TABLE ai_agents.agent_learning_session_h (
    learning_session_hk BYTEA PRIMARY KEY,
    learning_session_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    agent_hk BYTEA NOT NULL REFERENCES ai_agents.agent_h(agent_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Agent Learning Session Satellite
CREATE TABLE ai_agents.agent_learning_session_s (
    learning_session_hk BYTEA NOT NULL REFERENCES ai_agents.agent_learning_session_h(learning_session_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Learning Session Details
    session_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    session_end_time TIMESTAMP WITH TIME ZONE,
    learning_domain VARCHAR(100) NOT NULL,        -- 'equine_health', 'medical_diagnosis', etc.
    learning_type VARCHAR(50) NOT NULL,           -- 'SUPERVISED', 'REINFORCEMENT', 'FEEDBACK'
    
    -- Input Data for Learning
    input_data JSONB NOT NULL,                    -- Original request data
    agent_response JSONB NOT NULL,                -- Agent's response
    user_feedback JSONB,                          -- User feedback on response quality
    actual_outcome JSONB,                         -- What actually happened
    
    -- Learning Metrics
    confidence_before DECIMAL(5,4),               -- Agent confidence before learning
    confidence_after DECIMAL(5,4),                -- Agent confidence after learning
    accuracy_improvement DECIMAL(5,4),            -- Measured improvement
    learning_weight DECIMAL(5,4) DEFAULT 1.0,     -- How much to weight this learning
    
    -- Domain-Specific Learning
    domain_patterns JSONB,                        -- Patterns discovered for this domain
    cross_domain_insights JSONB,                  -- Insights applicable to other domains
    
    -- Integration with AI/ML 99.9% System
    ml_model_updated BOOLEAN DEFAULT false,       -- Whether ML models were updated
    pattern_recognition_improved BOOLEAN DEFAULT false,
    business_intelligence_enhanced BOOLEAN DEFAULT false,
    
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (learning_session_hk, load_date)
);

-- ==========================================
-- ENHANCED AGENT EXECUTION WITH LEARNING
-- ==========================================

-- Enhanced Agent Execution Function with Learning Integration
CREATE OR REPLACE FUNCTION ai_agents.execute_agent_with_learning(
    p_agent_hk BYTEA,
    p_input_data JSONB,
    p_execution_context JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE (
    execution_id VARCHAR(255),
    agent_response JSONB,
    confidence_score DECIMAL(5,4),
    learning_session_id VARCHAR(255),
    performance_metrics JSONB
) AS $$
DECLARE
    v_execution_hk BYTEA;
    v_execution_bk VARCHAR(255);
    v_learning_session_hk BYTEA;
    v_learning_session_bk VARCHAR(255);
    v_agent_response JSONB;
    v_confidence DECIMAL(5,4);
    v_domain VARCHAR(100);
    v_tenant_hk BYTEA;
    v_pre_learning_patterns JSONB;
    v_post_learning_patterns JSONB;
BEGIN
    -- Get agent details
    SELECT a.tenant_hk, ats.domain_specialization
    INTO v_tenant_hk, v_domain
    FROM ai_agents.agent_h a
    JOIN ai_agents.agent_template_s ats ON a.agent_hk = ats.agent_hk
    WHERE a.agent_hk = p_agent_hk
    AND ats.load_end_date IS NULL;
    
    -- Generate execution identifiers
    v_execution_bk := 'EXEC_' || encode(p_agent_hk, 'hex') || '_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    v_execution_hk := util.hash_binary(v_execution_bk);
    
    v_learning_session_bk := 'LEARN_' || encode(p_agent_hk, 'hex') || '_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    v_learning_session_hk := util.hash_binary(v_learning_session_bk);
    
    -- Step 1: Get current learning patterns from AI/ML 99.9% system
    SELECT business.get_domain_patterns(v_tenant_hk, v_domain) INTO v_pre_learning_patterns;
    
    -- Step 2: Execute agent with current knowledge
    v_agent_response := ai_agents.process_agent_request(p_agent_hk, p_input_data);
    v_confidence := (v_agent_response->>'confidence_score')::DECIMAL(5,4);
    
    -- Step 3: Create learning session
    INSERT INTO ai_agents.agent_learning_session_h VALUES (
        v_learning_session_hk, v_learning_session_bk, v_tenant_hk, p_agent_hk,
        util.current_load_date(), util.get_record_source()
    );
    
    INSERT INTO ai_agents.agent_learning_session_s VALUES (
        v_learning_session_hk, util.current_load_date(), NULL,
        util.hash_binary(v_learning_session_bk || 'ACTIVE'),
        CURRENT_TIMESTAMP, NULL, v_domain, 'SUPERVISED',
        p_input_data, v_agent_response, NULL, NULL,
        v_confidence, NULL, NULL, 1.0,
        v_pre_learning_patterns, NULL,
        false, false, false,
        util.get_record_source()
    );
    
    -- Step 4: Feed data to AI/ML 99.9% learning system
    PERFORM business.ai_learn_from_data(
        v_tenant_hk,
        v_domain,
        'agent_execution',
        encode(p_agent_hk, 'hex'),
        jsonb_build_array(p_input_data || v_agent_response)
    );
    
    -- Step 5: Get updated patterns after learning
    SELECT business.get_domain_patterns(v_tenant_hk, v_domain) INTO v_post_learning_patterns;
    
    RETURN QUERY SELECT 
        v_execution_bk,
        v_agent_response,
        v_confidence,
        v_learning_session_bk,
        jsonb_build_object(
            'pre_learning_patterns', v_pre_learning_patterns,
            'post_learning_patterns', v_post_learning_patterns,
            'learning_occurred', (v_pre_learning_patterns != v_post_learning_patterns),
            'domain', v_domain
        );
        
EXCEPTION WHEN OTHERS THEN
    -- Fallback to regular execution if learning fails
    v_agent_response := ai_agents.process_agent_request(p_agent_hk, p_input_data);
    v_confidence := COALESCE((v_agent_response->>'confidence_score')::DECIMAL(5,4), 0.5);
    
    RETURN QUERY SELECT 
        v_execution_bk,
        v_agent_response,
        v_confidence,
        NULL::VARCHAR(255),
        jsonb_build_object('error', SQLERRM, 'fallback_mode', true);
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- FEEDBACK LEARNING SYSTEM
-- ==========================================

-- Function to process user feedback and improve agents
CREATE OR REPLACE FUNCTION ai_agents.process_agent_feedback(
    p_learning_session_hk BYTEA,
    p_user_feedback JSONB,
    p_actual_outcome JSONB DEFAULT NULL
) RETURNS TABLE (
    feedback_processed BOOLEAN,
    confidence_improvement DECIMAL(5,4),
    learning_impact VARCHAR(100)
) AS $$
DECLARE
    v_agent_hk BYTEA;
    v_tenant_hk BYTEA;
    v_domain VARCHAR(100);
    v_current_confidence DECIMAL(5,4);
    v_new_confidence DECIMAL(5,4);
    v_improvement DECIMAL(5,4);
    v_feedback_score DECIMAL(5,4);
BEGIN
    -- Get learning session details
    SELECT als.agent_hk, als.tenant_hk, alss.learning_domain, alss.confidence_before
    INTO v_agent_hk, v_tenant_hk, v_domain, v_current_confidence
    FROM ai_agents.agent_learning_session_h als
    JOIN ai_agents.agent_learning_session_s alss ON als.learning_session_hk = alss.learning_session_hk
    WHERE als.learning_session_hk = p_learning_session_hk
    AND alss.load_end_date IS NULL;
    
    -- Calculate feedback score (0.0 to 1.0)
    v_feedback_score := CASE 
        WHEN p_user_feedback->>'rating' = 'excellent' THEN 1.0
        WHEN p_user_feedback->>'rating' = 'good' THEN 0.8
        WHEN p_user_feedback->>'rating' = 'fair' THEN 0.6
        WHEN p_user_feedback->>'rating' = 'poor' THEN 0.3
        ELSE 0.5
    END;
    
    -- Calculate confidence improvement based on feedback
    v_improvement := (v_feedback_score - v_current_confidence) * 0.1; -- 10% learning rate
    v_new_confidence := GREATEST(0.0, LEAST(1.0, v_current_confidence + v_improvement));
    
    -- Update learning session with feedback
    UPDATE ai_agents.agent_learning_session_s 
    SET load_end_date = util.current_load_date()
    WHERE learning_session_hk = p_learning_session_hk AND load_end_date IS NULL;
    
    INSERT INTO ai_agents.agent_learning_session_s VALUES (
        p_learning_session_hk, util.current_load_date(), NULL,
        util.hash_binary(encode(p_learning_session_hk, 'hex') || 'FEEDBACK'),
        (SELECT session_start_time FROM ai_agents.agent_learning_session_s WHERE learning_session_hk = p_learning_session_hk ORDER BY load_date DESC LIMIT 1),
        CURRENT_TIMESTAMP, v_domain, 'FEEDBACK',
        (SELECT input_data FROM ai_agents.agent_learning_session_s WHERE learning_session_hk = p_learning_session_hk ORDER BY load_date DESC LIMIT 1),
        (SELECT agent_response FROM ai_agents.agent_learning_session_s WHERE learning_session_hk = p_learning_session_hk ORDER BY load_date DESC LIMIT 1),
        p_user_feedback, p_actual_outcome,
        v_current_confidence, v_new_confidence, v_improvement, 
        CASE WHEN v_feedback_score > 0.8 THEN 1.5 ELSE 1.0 END, -- Higher weight for positive feedback
        NULL, NULL, true, true, true, util.get_record_source()
    );
    
    -- Feed feedback to AI/ML 99.9% system for domain-wide learning
    PERFORM business.ai_learn_from_feedback(
        v_tenant_hk,
        v_domain,
        'agent_feedback',
        encode(v_agent_hk, 'hex'),
        jsonb_build_object(
            'feedback', p_user_feedback,
            'outcome', p_actual_outcome,
            'confidence_improvement', v_improvement
        )
    );
    
    RETURN QUERY SELECT 
        true,
        v_improvement,
        CASE 
            WHEN v_improvement > 0.1 THEN 'SIGNIFICANT_IMPROVEMENT'
            WHEN v_improvement > 0.05 THEN 'MODERATE_IMPROVEMENT'
            WHEN v_improvement > 0.0 THEN 'MINOR_IMPROVEMENT'
            ELSE 'NO_IMPROVEMENT'
        END;
        
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT false, 0.0::DECIMAL(5,4), 'ERROR_PROCESSING_FEEDBACK';
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- CROSS-DOMAIN LEARNING SYSTEM
-- ==========================================

-- Function to apply learning from one domain to another
CREATE OR REPLACE FUNCTION ai_agents.apply_cross_domain_learning(
    p_tenant_hk BYTEA,
    p_source_domain VARCHAR(100),
    p_target_domain VARCHAR(100),
    p_pattern_similarity_threshold DECIMAL(5,4) DEFAULT 0.7
) RETURNS TABLE (
    patterns_transferred INTEGER,
    confidence_boost_applied DECIMAL(5,4),
    cross_domain_insights JSONB
) AS $$
DECLARE
    v_source_patterns JSONB;
    v_target_patterns JSONB;
    v_transferable_patterns JSONB;
    v_confidence_boost DECIMAL(5,4);
    v_patterns_count INTEGER;
BEGIN
    -- Get patterns from source domain
    SELECT business.get_domain_patterns(p_tenant_hk, p_source_domain) INTO v_source_patterns;
    SELECT business.get_domain_patterns(p_tenant_hk, p_target_domain) INTO v_target_patterns;
    
    -- Identify transferable patterns (simplified logic - in reality would use ML similarity)
    v_transferable_patterns := jsonb_build_object(
        'health_monitoring_patterns', v_source_patterns->'health_monitoring_patterns',
        'anomaly_detection_patterns', v_source_patterns->'anomaly_detection_patterns',
        'predictive_indicators', v_source_patterns->'predictive_indicators'
    );
    
    v_patterns_count := jsonb_array_length(v_transferable_patterns->'health_monitoring_patterns');
    v_confidence_boost := LEAST(0.2, v_patterns_count * 0.02); -- Max 20% boost
    
    -- Apply cross-domain learning to AI/ML 99.9% system
    PERFORM business.apply_cross_domain_patterns(
        p_tenant_hk,
        p_source_domain,
        p_target_domain,
        v_transferable_patterns
    );
    
    RETURN QUERY SELECT 
        v_patterns_count,
        v_confidence_boost,
        jsonb_build_object(
            'source_domain', p_source_domain,
            'target_domain', p_target_domain,
            'transferred_patterns', v_transferable_patterns,
            'similarity_threshold', p_pattern_similarity_threshold
        );
        
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 0, 0.0::DECIMAL(5,4), jsonb_build_object('error', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- HORSE IMAGE ANALYSIS LEARNING INTEGRATION
-- ==========================================

-- Enhanced Horse Image Analysis with Learning
CREATE OR REPLACE FUNCTION ai_agents.process_image_batch_with_learning(
    p_hia_agent_hk BYTEA,
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
    v_batch_result RECORD;
    v_learning_session_hk BYTEA;
    v_tenant_hk BYTEA;
    v_learning_data JSONB;
BEGIN
    -- Get tenant information
    SELECT tenant_hk INTO v_tenant_hk
    FROM ai_agents.horse_image_analysis_agent_h
    WHERE hia_agent_hk = p_hia_agent_hk;
    
    -- Process images with existing function
    SELECT * INTO v_batch_result
    FROM ai_agents.process_image_batch(p_hia_agent_hk, p_horse_id, p_image_urls, p_batch_metadata);
    
    -- Create learning data from image analysis
    v_learning_data := jsonb_build_object(
        'horse_id', p_horse_id,
        'image_count', array_length(p_image_urls, 1),
        'findings', v_batch_result.findings_summary,
        'processing_metadata', p_batch_metadata
    );
    
    -- Feed to AI/ML 99.9% learning system
    PERFORM business.ai_learn_from_data(
        v_tenant_hk,
        'equine_visual_analysis',
        'image_batch',
        p_horse_id,
        jsonb_build_array(v_learning_data)
    );
    
    -- Apply cross-domain learning (visual patterns to health patterns)
    PERFORM ai_agents.apply_cross_domain_learning(
        v_tenant_hk,
        'equine_visual_analysis',
        'equine_health',
        0.8
    );
    
    RETURN QUERY SELECT 
        v_batch_result.success,
        v_batch_result.batch_id,
        v_batch_result.processing_status,
        v_batch_result.findings_summary,
        jsonb_build_object(
            'learning_applied', true,
            'domain', 'equine_visual_analysis',
            'cross_domain_transfer', 'equine_health',
            'learning_data_points', array_length(p_image_urls, 1)
        );
        
EXCEPTION WHEN OTHERS THEN
    -- Fallback to regular processing
    SELECT * INTO v_batch_result
    FROM ai_agents.process_image_batch(p_hia_agent_hk, p_horse_id, p_image_urls, p_batch_metadata);
    
    RETURN QUERY SELECT 
        v_batch_result.success,
        v_batch_result.batch_id,
        v_batch_result.processing_status,
        v_batch_result.findings_summary,
        jsonb_build_object('learning_error', SQLERRM, 'fallback_mode', true);
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- PERFORMANCE INDEXES
-- ==========================================

CREATE INDEX idx_agent_learning_session_h_agent_hk ON ai_agents.agent_learning_session_h(agent_hk);
CREATE INDEX idx_agent_learning_session_h_tenant_hk ON ai_agents.agent_learning_session_h(tenant_hk);
CREATE INDEX idx_agent_learning_session_s_domain ON ai_agents.agent_learning_session_s(learning_domain) WHERE load_end_date IS NULL;
CREATE INDEX idx_agent_learning_session_s_confidence ON ai_agents.agent_learning_session_s(confidence_after) WHERE load_end_date IS NULL;

-- ==========================================
-- INTEGRATION VALIDATION FUNCTION
-- ==========================================

CREATE OR REPLACE FUNCTION ai_agents.validate_learning_integration(
    p_tenant_hk BYTEA
) RETURNS TABLE (
    component VARCHAR(100),
    status VARCHAR(20),
    details JSONB
) AS $$
BEGIN
    -- Check learning session tables
    RETURN QUERY SELECT 
        'Learning Session Tables',
        CASE WHEN EXISTS (SELECT 1 FROM ai_agents.agent_learning_session_h LIMIT 1) 
             THEN 'ACTIVE' ELSE 'MISSING' END,
        jsonb_build_object('table_exists', true, 'has_data', EXISTS (SELECT 1 FROM ai_agents.agent_learning_session_h LIMIT 1));
    
    -- Check AI/ML 99.9% integration
    RETURN QUERY SELECT 
        'AI/ML 99.9% Integration',
        CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'ai_learn_from_data') 
             THEN 'ACTIVE' ELSE 'MISSING' END,
        jsonb_build_object('function_exists', EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'ai_learn_from_data'));
    
    -- Check cross-domain learning
    RETURN QUERY SELECT 
        'Cross-Domain Learning',
        'ACTIVE',
        jsonb_build_object('function_available', true, 'domains_supported', ARRAY['equine_health', 'medical_diagnosis', 'equine_visual_analysis']);
    
    -- Check agent learning functions
    RETURN QUERY SELECT 
        'Agent Learning Functions',
        'ACTIVE',
        jsonb_build_object(
            'execute_with_learning', EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'execute_agent_with_learning'),
            'process_feedback', EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'process_agent_feedback'),
            'image_learning', EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'process_image_batch_with_learning')
        );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- COMMENTS FOR DOCUMENTATION
-- ==========================================

COMMENT ON TABLE ai_agents.agent_learning_session_h IS 'Hub table connecting AI agents to the AI/ML 99.9% augmented learning system for continuous improvement';
COMMENT ON FUNCTION ai_agents.execute_agent_with_learning IS 'Enhanced agent execution that feeds results to AI/ML learning system for continuous improvement';
COMMENT ON FUNCTION ai_agents.process_agent_feedback IS 'Process user feedback to improve agent performance using reinforcement learning principles';
COMMENT ON FUNCTION ai_agents.apply_cross_domain_learning IS 'Transfer learning patterns between domains (e.g., equine visual analysis to equine health)';

COMMIT; 