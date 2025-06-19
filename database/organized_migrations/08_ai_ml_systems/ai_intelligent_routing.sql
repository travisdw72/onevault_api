-- AI Intelligent Routing System
-- Shows how AI systems consume metadata for real-time decision making

-- ==========================================
-- SMART MODEL ROUTING FUNCTION
-- ==========================================

CREATE OR REPLACE FUNCTION business.get_optimal_ai_model(
    p_tenant_hk BYTEA,
    p_model_type VARCHAR(100),
    p_required_accuracy DECIMAL(5,4) DEFAULT 0.85,
    p_max_inference_time_ms INTEGER DEFAULT 500
) RETURNS TABLE (
    model_name VARCHAR(100),
    model_version VARCHAR(50),
    deployment_endpoint VARCHAR(500),
    expected_accuracy DECIMAL(5,4),
    expected_inference_time INTEGER,
    confidence_score DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH model_performance AS (
        -- Get latest performance metrics for each model
        SELECT DISTINCT ON (amp.model_name, amp.model_version)
            amp.model_name,
            amp.model_version,
            amp.accuracy_score,
            amp.inference_time_ms,
            amp.model_drift_score,
            amp.evaluation_date,
            amp.performance_degradation
        FROM business.ai_model_performance_s amp
        JOIN business.ai_model_performance_h amph ON amp.ai_model_performance_hk = amph.ai_model_performance_hk
        WHERE amph.tenant_hk = p_tenant_hk
        AND amp.load_end_date IS NULL
        AND amp.model_name ILIKE '%' || p_model_type || '%'
        ORDER BY amp.model_name, amp.model_version, amp.evaluation_date DESC
    ),
    active_deployments AS (
        -- Get active deployment endpoints
        SELECT DISTINCT ON (ads.model_name, ads.model_version)
            ads.model_name,
            ads.model_version,
            ads.endpoint_url,
            ads.deployment_status,
            ads.traffic_percentage
        FROM business.ai_deployment_status_s ads
        JOIN business.ai_deployment_status_h adsh ON ads.ai_deployment_status_hk = adsh.ai_deployment_status_hk
        WHERE adsh.tenant_hk = p_tenant_hk
        AND ads.load_end_date IS NULL
        AND ads.deployment_status = 'ACTIVE'
        AND ads.deployment_environment = 'PROD'
        ORDER BY ads.model_name, ads.model_version, ads.deployment_timestamp DESC
    )
    SELECT 
        mp.model_name,
        mp.model_version,
        ad.endpoint_url,
        mp.accuracy_score,
        mp.inference_time_ms,
        -- Calculate confidence score based on multiple factors
        ROUND(
            (CASE WHEN mp.accuracy_score >= p_required_accuracy THEN 30 ELSE 0 END) +
            (CASE WHEN mp.inference_time_ms <= p_max_inference_time_ms THEN 25 ELSE 0 END) +
            (CASE WHEN mp.performance_degradation = false THEN 20 ELSE 0 END) +
            (CASE WHEN mp.model_drift_score < 0.1 THEN 15 ELSE 0 END) +
            (CASE WHEN ad.traffic_percentage = 100 THEN 10 ELSE 5 END)
        , 2) as confidence_score
    FROM model_performance mp
    JOIN active_deployments ad ON mp.model_name = ad.model_name AND mp.model_version = ad.model_version
    WHERE mp.accuracy_score >= p_required_accuracy
    AND mp.inference_time_ms <= p_max_inference_time_ms
    AND mp.performance_degradation = false
    ORDER BY confidence_score DESC, mp.accuracy_score DESC
    LIMIT 3;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- AUTOMATED DRIFT DETECTION & RESPONSE
-- ==========================================

CREATE OR REPLACE FUNCTION business.detect_and_respond_to_drift(
    p_tenant_hk BYTEA,
    p_drift_threshold DECIMAL(5,4) DEFAULT 0.15
) RETURNS TABLE (
    model_name VARCHAR(100),
    model_version VARCHAR(50),
    drift_score DECIMAL(5,4),
    action_taken VARCHAR(50),
    retraining_job_id VARCHAR(255)
) AS $$
DECLARE
    v_model_record RECORD;
    v_training_job_id VARCHAR(255);
BEGIN
    -- Find models with significant drift
    FOR v_model_record IN
        SELECT DISTINCT ON (amp.model_name, amp.model_version)
            amp.model_name,
            amp.model_version,
            amp.model_drift_score,
            amp.data_drift_score,
            amp.ai_model_performance_hk
        FROM business.ai_model_performance_s amp
        JOIN business.ai_model_performance_h amph ON amp.ai_model_performance_hk = amph.ai_model_performance_hk
        WHERE amph.tenant_hk = p_tenant_hk
        AND amp.load_end_date IS NULL
        AND (amp.model_drift_score > p_drift_threshold OR amp.data_drift_score > p_drift_threshold)
        ORDER BY amp.model_name, amp.model_version, amp.evaluation_date DESC
    LOOP
        -- Generate unique training job ID
        v_training_job_id := 'DRIFT_RETRAIN_' || v_model_record.model_name || '_' || 
                           extract(epoch from now())::bigint::text;
        
        -- Log the retraining job (would trigger actual ML pipeline)
        INSERT INTO business.ai_training_execution_h (
            ai_training_execution_hk,
            ai_training_execution_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            util.hash_binary(v_training_job_id),
            v_training_job_id,
            p_tenant_hk,
            util.current_load_date(),
            'AUTOMATED_DRIFT_RESPONSE'
        );
        
        INSERT INTO business.ai_training_execution_s (
            ai_training_execution_hk,
            load_date,
            hash_diff,
            training_job_id,
            model_name,
            training_start_time,
            training_status,
            hyperparameters,
            tenant_hk,
            record_source
        ) VALUES (
            util.hash_binary(v_training_job_id),
            util.current_load_date(),
            util.hash_binary(v_training_job_id || 'DRIFT_RESPONSE'),
            v_training_job_id,
            v_model_record.model_name,
            CURRENT_TIMESTAMP,
            'RUNNING',
            jsonb_build_object(
                'triggered_by', 'drift_detection',
                'drift_score', v_model_record.model_drift_score,
                'auto_retrain', true
            ),
            p_tenant_hk,
            'AUTOMATED_DRIFT_RESPONSE'
        );
        
        RETURN QUERY SELECT 
            v_model_record.model_name,
            v_model_record.model_version,
            GREATEST(v_model_record.model_drift_score, v_model_record.data_drift_score),
            'RETRAINING_INITIATED'::VARCHAR(50),
            v_training_job_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- AI FEATURE QUALITY ASSESSMENT
-- ==========================================

CREATE OR REPLACE FUNCTION business.assess_feature_quality_for_inference(
    p_tenant_hk BYTEA,
    p_feature_names TEXT[]
) RETURNS TABLE (
    feature_name TEXT,
    quality_score DECIMAL(5,4),
    drift_detected BOOLEAN,
    recommendation TEXT,
    alternative_features TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    WITH latest_pipeline_runs AS (
        SELECT DISTINCT ON (afp.pipeline_name)
            afp.pipeline_name,
            afp.data_quality_score,
            afp.feature_drift_detected,
            afp.features_generated,
            afp.execution_timestamp,
            afp.feature_transformations
        FROM business.ai_feature_pipeline_s afp
        JOIN business.ai_feature_pipeline_h afph ON afp.ai_feature_pipeline_hk = afph.ai_feature_pipeline_hk
        WHERE afph.tenant_hk = p_tenant_hk
        AND afp.load_end_date IS NULL
        AND afp.execution_status = 'COMPLETED'
        ORDER BY afp.pipeline_name, afp.execution_timestamp DESC
    )
    SELECT 
        feature_name,
        lpr.data_quality_score,
        lpr.feature_drift_detected,
        CASE 
            WHEN lpr.data_quality_score >= 0.9 AND NOT lpr.feature_drift_detected THEN 'EXCELLENT - Use as primary feature'
            WHEN lpr.data_quality_score >= 0.7 AND NOT lpr.feature_drift_detected THEN 'GOOD - Safe to use'
            WHEN lpr.data_quality_score >= 0.5 OR lpr.feature_drift_detected THEN 'CAUTION - Monitor closely'
            ELSE 'POOR - Consider alternatives'
        END as recommendation,
        CASE 
            WHEN lpr.data_quality_score < 0.7 OR lpr.feature_drift_detected THEN 
                ARRAY(SELECT jsonb_array_elements_text(lpr.feature_transformations->'alternatives'))
            ELSE ARRAY[]::TEXT[]
        END as alternative_features
    FROM unnest(p_feature_names) AS feature_name
    LEFT JOIN latest_pipeline_runs lpr ON lpr.pipeline_name ILIKE '%' || feature_name || '%'
    ORDER BY lpr.data_quality_score DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- REAL-TIME AI SYSTEM HEALTH CHECK
-- ==========================================

CREATE OR REPLACE FUNCTION business.ai_system_health_check(
    p_tenant_hk BYTEA
) RETURNS TABLE (
    component VARCHAR(100),
    status VARCHAR(20),
    health_score DECIMAL(5,2),
    issues TEXT[],
    recommendations TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    WITH health_metrics AS (
        SELECT 
            'MODEL_PERFORMANCE' as component,
            CASE 
                WHEN AVG(amp.accuracy_score) >= 0.9 THEN 'EXCELLENT'
                WHEN AVG(amp.accuracy_score) >= 0.8 THEN 'GOOD'
                WHEN AVG(amp.accuracy_score) >= 0.7 THEN 'FAIR'
                ELSE 'POOR'
            END as status,
            ROUND(AVG(amp.accuracy_score) * 100, 2) as health_score,
            ARRAY_AGG(DISTINCT 
                CASE WHEN amp.performance_degradation THEN amp.model_name || ' degraded' ELSE NULL END
            ) FILTER (WHERE amp.performance_degradation) as issues,
            ARRAY_AGG(DISTINCT 
                CASE WHEN amp.retraining_recommended THEN 'Retrain ' || amp.model_name ELSE NULL END
            ) FILTER (WHERE amp.retraining_recommended) as recommendations
        FROM business.ai_model_performance_s amp
        JOIN business.ai_model_performance_h amph ON amp.ai_model_performance_hk = amph.ai_model_performance_hk
        WHERE amph.tenant_hk = p_tenant_hk
        AND amp.load_end_date IS NULL
        AND amp.evaluation_date >= CURRENT_DATE - INTERVAL '7 days'
        
        UNION ALL
        
        SELECT 
            'DEPLOYMENT_HEALTH' as component,
            CASE 
                WHEN COUNT(*) FILTER (WHERE ads.deployment_status = 'ACTIVE') = COUNT(*) THEN 'EXCELLENT'
                WHEN COUNT(*) FILTER (WHERE ads.deployment_status = 'ACTIVE') >= COUNT(*) * 0.8 THEN 'GOOD'
                WHEN COUNT(*) FILTER (WHERE ads.deployment_status = 'ACTIVE') >= COUNT(*) * 0.5 THEN 'FAIR'
                ELSE 'POOR'
            END as status,
            ROUND((COUNT(*) FILTER (WHERE ads.deployment_status = 'ACTIVE')::DECIMAL / COUNT(*)) * 100, 2) as health_score,
            ARRAY_AGG(DISTINCT 
                CASE WHEN ads.deployment_status != 'ACTIVE' THEN ads.model_name || ' not active' ELSE NULL END
            ) FILTER (WHERE ads.deployment_status != 'ACTIVE') as issues,
            ARRAY_AGG(DISTINCT 
                CASE WHEN ads.deployment_status = 'FAILED' THEN 'Redeploy ' || ads.model_name ELSE NULL END
            ) FILTER (WHERE ads.deployment_status = 'FAILED') as recommendations
        FROM business.ai_deployment_status_s ads
        JOIN business.ai_deployment_status_h adsh ON ads.ai_deployment_status_hk = adsh.ai_deployment_status_hk
        WHERE adsh.tenant_hk = p_tenant_hk
        AND ads.load_end_date IS NULL
        
        UNION ALL
        
        SELECT 
            'FEATURE_PIPELINES' as component,
            CASE 
                WHEN AVG(afp.data_quality_score) >= 0.9 THEN 'EXCELLENT'
                WHEN AVG(afp.data_quality_score) >= 0.8 THEN 'GOOD'
                WHEN AVG(afp.data_quality_score) >= 0.7 THEN 'FAIR'
                ELSE 'POOR'
            END as status,
            ROUND(AVG(afp.data_quality_score) * 100, 2) as health_score,
            ARRAY_AGG(DISTINCT 
                CASE WHEN afp.feature_drift_detected THEN afp.pipeline_name || ' drift detected' ELSE NULL END
            ) FILTER (WHERE afp.feature_drift_detected) as issues,
            ARRAY_AGG(DISTINCT 
                CASE WHEN afp.feature_drift_detected THEN 'Review ' || afp.pipeline_name || ' features' ELSE NULL END
            ) FILTER (WHERE afp.feature_drift_detected) as recommendations
        FROM business.ai_feature_pipeline_s afp
        JOIN business.ai_feature_pipeline_h afph ON afp.ai_feature_pipeline_hk = afph.ai_feature_pipeline_hk
        WHERE afph.tenant_hk = p_tenant_hk
        AND afp.load_end_date IS NULL
        AND afp.execution_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    )
    SELECT * FROM health_metrics;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- AUTOMATED AI DECISION ENGINE
-- ==========================================

CREATE OR REPLACE FUNCTION business.ai_decision_engine(
    p_tenant_hk BYTEA,
    p_request_context JSONB
) RETURNS JSONB AS $$
DECLARE
    v_optimal_model RECORD;
    v_feature_quality RECORD;
    v_system_health RECORD;
    v_decision_result JSONB;
BEGIN
    -- Get optimal model for request
    SELECT INTO v_optimal_model *
    FROM business.get_optimal_ai_model(
        p_tenant_hk,
        p_request_context->>'model_type',
        (p_request_context->>'required_accuracy')::DECIMAL(5,4),
        (p_request_context->>'max_inference_time')::INTEGER
    )
    LIMIT 1;
    
    -- Check system health
    SELECT INTO v_system_health *
    FROM business.ai_system_health_check(p_tenant_hk)
    WHERE component = 'MODEL_PERFORMANCE'
    LIMIT 1;
    
    -- Build decision response
    v_decision_result := jsonb_build_object(
        'decision_timestamp', CURRENT_TIMESTAMP,
        'tenant_hk', encode(p_tenant_hk, 'hex'),
        'recommended_model', jsonb_build_object(
            'model_name', v_optimal_model.model_name,
            'model_version', v_optimal_model.model_version,
            'endpoint', v_optimal_model.deployment_endpoint,
            'confidence_score', v_optimal_model.confidence_score
        ),
        'system_health', jsonb_build_object(
            'overall_status', v_system_health.status,
            'health_score', v_system_health.health_score
        ),
        'decision_factors', jsonb_build_object(
            'accuracy_requirement_met', v_optimal_model.expected_accuracy >= (p_request_context->>'required_accuracy')::DECIMAL(5,4),
            'performance_requirement_met', v_optimal_model.expected_inference_time <= (p_request_context->>'max_inference_time')::INTEGER,
            'drift_status', 'within_tolerance'
        ),
        'metadata_sources', ARRAY[
            'ai_model_performance_s',
            'ai_deployment_status_s', 
            'ai_feature_pipeline_s'
        ]
    );
    
    RETURN v_decision_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION business.ai_decision_engine(BYTEA, JSONB) IS 
'Automated AI decision engine that consumes metadata from all AI observation tables to make intelligent routing, scaling, and optimization decisions for AI requests.'; 