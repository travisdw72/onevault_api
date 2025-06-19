-- AI Application Integration Examples
-- Shows how applications consume AI metadata for intelligent decisions

-- ==========================================
-- API ENDPOINT: GET OPTIMAL MODEL
-- ==========================================
-- Usage: GET /api/v1/ai/optimal-model?type=fraud_detection&accuracy=0.90

CREATE OR REPLACE FUNCTION api.get_optimal_model_for_request(
    p_tenant_hk BYTEA,
    p_model_type VARCHAR(100),
    p_required_accuracy DECIMAL(5,4) DEFAULT 0.85,
    p_max_latency_ms INTEGER DEFAULT 500
) RETURNS JSONB AS $$
DECLARE
    v_model_recommendation RECORD;
    v_fallback_models JSONB;
    v_response JSONB;
BEGIN
    -- Get primary recommendation
    SELECT INTO v_model_recommendation *
    FROM business.get_optimal_ai_model(
        p_tenant_hk, 
        p_model_type, 
        p_required_accuracy, 
        p_max_latency_ms
    ) 
    LIMIT 1;
    
    -- Get fallback options
    SELECT jsonb_agg(
        jsonb_build_object(
            'model_name', model_name,
            'model_version', model_version,
            'endpoint', deployment_endpoint,
            'confidence_score', confidence_score
        )
    ) INTO v_fallback_models
    FROM business.get_optimal_ai_model(
        p_tenant_hk, 
        p_model_type, 
        p_required_accuracy * 0.9, -- Lower accuracy threshold for fallbacks
        p_max_latency_ms * 1.5      -- Higher latency tolerance
    ) 
    OFFSET 1 LIMIT 2;
    
    -- Build API response
    v_response := jsonb_build_object(
        'primary_model', jsonb_build_object(
            'model_name', v_model_recommendation.model_name,
            'model_version', v_model_recommendation.model_version,
            'endpoint_url', v_model_recommendation.deployment_endpoint,
            'expected_accuracy', v_model_recommendation.expected_accuracy,
            'expected_latency_ms', v_model_recommendation.expected_inference_time,
            'confidence_score', v_model_recommendation.confidence_score,
            'recommended_at', CURRENT_TIMESTAMP
        ),
        'fallback_models', COALESCE(v_fallback_models, '[]'::jsonb),
        'selection_criteria', jsonb_build_object(
            'required_accuracy', p_required_accuracy,
            'max_latency_ms', p_max_latency_ms,
            'model_type', p_model_type
        ),
        'metadata_freshness', jsonb_build_object(
            'performance_data_age_hours', EXTRACT(EPOCH FROM (
                CURRENT_TIMESTAMP - (
                    SELECT MAX(load_date) 
                    FROM business.ai_model_performance_s 
                    WHERE model_name = v_model_recommendation.model_name
                )
            )) / 3600,
            'data_source', 'ai_model_performance_s'
        )
    );
    
    RETURN v_response;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- API ENDPOINT: HEALTH CHECK
-- ==========================================
-- Usage: GET /api/v1/ai/health

CREATE OR REPLACE FUNCTION api.get_ai_system_health(
    p_tenant_hk BYTEA
) RETURNS JSONB AS $$
DECLARE
    v_health_summary JSONB;
    v_detailed_metrics JSONB;
    v_recommendations JSONB;
BEGIN
    -- Get overall health summary
    WITH health_data AS (
        SELECT 
            component,
            status,
            health_score,
            issues,
            recommendations
        FROM business.ai_system_health_check(p_tenant_hk)
    )
    SELECT jsonb_object_agg(
        component,
        jsonb_build_object(
            'status', status,
            'score', health_score,
            'issues', to_jsonb(issues),
            'recommendations', to_jsonb(recommendations)
        )
    ) INTO v_health_summary
    FROM health_data;
    
    -- Get detailed performance metrics
    WITH performance_details AS (
        SELECT 
            model_name,
            model_version,
            accuracy_score,
            inference_time_ms,
            model_drift_score,
            performance_degradation,
            evaluation_date
        FROM business.ai_model_performance_s amp
        JOIN business.ai_model_performance_h amph ON amp.ai_model_performance_hk = amph.ai_model_performance_hk
        WHERE amph.tenant_hk = p_tenant_hk
        AND amp.load_end_date IS NULL
        AND amp.evaluation_date >= CURRENT_DATE - INTERVAL '7 days'
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'model', model_name || ':' || model_version,
            'accuracy', accuracy_score,
            'latency_ms', inference_time_ms,
            'drift_score', model_drift_score,
            'degraded', performance_degradation,
            'last_evaluated', evaluation_date
        )
    ) INTO v_detailed_metrics
    FROM performance_details;
    
    -- Build comprehensive response
    RETURN jsonb_build_object(
        'overall_status', CASE 
            WHEN v_health_summary->'MODEL_PERFORMANCE'->>'status' = 'EXCELLENT' 
             AND v_health_summary->'DEPLOYMENT_HEALTH'->>'status' IN ('EXCELLENT', 'GOOD') 
            THEN 'HEALTHY'
            WHEN v_health_summary->'MODEL_PERFORMANCE'->>'status' IN ('GOOD', 'FAIR')
            THEN 'DEGRADED'
            ELSE 'UNHEALTHY'
        END,
        'timestamp', CURRENT_TIMESTAMP,
        'tenant_id', encode(p_tenant_hk, 'hex'),
        'components', v_health_summary,
        'model_details', COALESCE(v_detailed_metrics, '[]'::jsonb),
        'system_recommendations', jsonb_build_array(
            'Monitor drift detection alerts',
            'Review model performance weekly',
            'Ensure training data quality'
        )
    );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- AUDIT: DRIFT ALERT PROCESSOR
-- ==========================================
-- Usage: Called automatically when drift is detected

CREATE OR REPLACE FUNCTION audit.process_drift_alert(
    p_tenant_hk BYTEA,
    p_drift_threshold DECIMAL(5,4) DEFAULT 0.15
) RETURNS JSONB AS $$
DECLARE
    v_drift_response RECORD;
    v_alert_payload JSONB;
    v_actions_taken JSONB := '[]'::jsonb;
BEGIN
    -- Process drift detection and take action
    FOR v_drift_response IN 
        SELECT * FROM business.detect_and_respond_to_drift(p_tenant_hk, p_drift_threshold)
    LOOP
        -- Build action record
        v_actions_taken := v_actions_taken || jsonb_build_object(
            'model_name', v_drift_response.model_name,
            'model_version', v_drift_response.model_version,
            'drift_score', v_drift_response.drift_score,
            'action', v_drift_response.action_taken,
            'training_job_id', v_drift_response.retraining_job_id,
            'timestamp', CURRENT_TIMESTAMP
        );
    END LOOP;
    
    -- Build webhook payload
    v_alert_payload := jsonb_build_object(
        'alert_type', 'MODEL_DRIFT_DETECTED',
        'tenant_id', encode(p_tenant_hk, 'hex'),
        'detection_timestamp', CURRENT_TIMESTAMP,
        'drift_threshold', p_drift_threshold,
        'actions_taken', v_actions_taken,
        'severity', CASE 
            WHEN jsonb_array_length(v_actions_taken) > 3 THEN 'HIGH'
            WHEN jsonb_array_length(v_actions_taken) > 1 THEN 'MEDIUM'
            ELSE 'LOW'
        END,
        'metadata_source', 'ai_model_performance_s'
    );
    
    -- Log the alert to audit system (Phase 1: Simple logging)
    INSERT INTO audit.audit_event_h (
        audit_event_hk,
        audit_event_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary('DRIFT_ALERT_' || encode(p_tenant_hk, 'hex') || '_' || CURRENT_TIMESTAMP::text),
        'AI_DRIFT_ALERT_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'),
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    );
    
    -- Future: When webhook schema exists, this could trigger external notifications
    -- For now: Alert is logged and can be queried/monitored
    
    RETURN v_alert_payload;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- REAL-TIME FEATURE VALIDATION
-- ==========================================
-- Usage: Called before making inference requests

CREATE OR REPLACE FUNCTION api.validate_features_for_inference(
    p_tenant_hk BYTEA,
    p_feature_set JSONB  -- {"features": ["income", "age", "credit_score"]}
) RETURNS JSONB AS $$
DECLARE
    v_feature_names TEXT[];
    v_validation_results RECORD;
    v_feature_analysis JSONB := '[]'::jsonb;
    v_overall_quality DECIMAL(5,4) := 0;
    v_feature_count INTEGER := 0;
BEGIN
    -- Extract feature names from request
    SELECT ARRAY(SELECT jsonb_array_elements_text(p_feature_set->'features')) 
    INTO v_feature_names;
    
    -- Validate each feature
    FOR v_validation_results IN 
        SELECT * FROM business.assess_feature_quality_for_inference(p_tenant_hk, v_feature_names)
    LOOP
        v_feature_analysis := v_feature_analysis || jsonb_build_object(
            'feature_name', v_validation_results.feature_name,
            'quality_score', v_validation_results.quality_score,
            'drift_detected', v_validation_results.drift_detected,
            'recommendation', v_validation_results.recommendation,
            'alternatives', to_jsonb(v_validation_results.alternative_features),
            'status', CASE 
                WHEN v_validation_results.quality_score >= 0.9 THEN 'EXCELLENT'
                WHEN v_validation_results.quality_score >= 0.7 THEN 'GOOD'
                WHEN v_validation_results.quality_score >= 0.5 THEN 'FAIR'
                ELSE 'POOR'
            END
        );
        
        -- Accumulate quality scores
        IF v_validation_results.quality_score IS NOT NULL THEN
            v_overall_quality := v_overall_quality + v_validation_results.quality_score;
            v_feature_count := v_feature_count + 1;
        END IF;
    END LOOP;
    
    -- Calculate average quality
    IF v_feature_count > 0 THEN
        v_overall_quality := v_overall_quality / v_feature_count;
    END IF;
    
    RETURN jsonb_build_object(
        'validation_timestamp', CURRENT_TIMESTAMP,
        'overall_quality_score', v_overall_quality,
        'features_analyzed', v_feature_count,
        'recommendation', CASE 
            WHEN v_overall_quality >= 0.8 THEN 'PROCEED_WITH_INFERENCE'
            WHEN v_overall_quality >= 0.6 THEN 'PROCEED_WITH_CAUTION'
            ELSE 'DEFER_OR_USE_ALTERNATIVES'
        END,
        'feature_analysis', v_feature_analysis,
        'metadata_sources', ARRAY['ai_feature_pipeline_s']
    );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- AUTO-SCALING DECISION ENGINE
-- ==========================================
-- Usage: Called by orchestration system for scaling decisions

CREATE OR REPLACE FUNCTION business.make_scaling_decision(
    p_tenant_hk BYTEA,
    p_current_load JSONB  -- {"requests_per_minute": 1500, "avg_latency_ms": 450}
) RETURNS JSONB AS $$
DECLARE
    v_current_rpm INTEGER;
    v_current_latency INTEGER;
    v_deployment_status RECORD;
    v_scaling_decision JSONB;
    v_model_capacity JSONB := '[]'::jsonb;
BEGIN
    -- Extract current load metrics
    v_current_rpm := (p_current_load->>'requests_per_minute')::INTEGER;
    v_current_latency := (p_current_load->>'avg_latency_ms')::INTEGER;
    
    -- Analyze current deployment capacity
    WITH deployment_analysis AS (
        SELECT 
            ads.model_name,
            ads.model_version,
            ads.scaling_config,
            ads.traffic_percentage,
            amp.inference_time_ms as expected_latency,
            amp.cpu_utilization_percent,
            amp.memory_usage_mb
        FROM business.ai_deployment_status_s ads
        JOIN business.ai_deployment_status_h adsh ON ads.ai_deployment_status_hk = adsh.ai_deployment_status_hk
        LEFT JOIN business.ai_model_performance_s amp ON ads.model_name = amp.model_name 
                                                      AND ads.model_version = amp.model_version
                                                      AND amp.load_end_date IS NULL
        WHERE adsh.tenant_hk = p_tenant_hk
        AND ads.load_end_date IS NULL
        AND ads.deployment_status = 'ACTIVE'
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'model', model_name || ':' || model_version,
            'current_traffic_pct', traffic_percentage,
            'expected_latency_ms', expected_latency,
            'cpu_utilization', cpu_utilization_percent,
            'scaling_config', scaling_config,
            'recommended_action', CASE 
                WHEN cpu_utilization_percent > 80 THEN 'SCALE_UP'
                WHEN cpu_utilization_percent < 30 AND traffic_percentage < 50 THEN 'SCALE_DOWN'
                ELSE 'MAINTAIN'
            END
        )
    ) INTO v_model_capacity
    FROM deployment_analysis;
    
    -- Make scaling decision
    v_scaling_decision := jsonb_build_object(
        'decision_timestamp', CURRENT_TIMESTAMP,
        'current_load', p_current_load,
        'latency_threshold_exceeded', v_current_latency > 500,
        'capacity_threshold_exceeded', v_current_rpm > 1000,
        'recommended_action', CASE 
            WHEN v_current_latency > 500 OR v_current_rpm > 1200 THEN 'SCALE_UP'
            WHEN v_current_latency < 200 AND v_current_rpm < 500 THEN 'SCALE_DOWN' 
            ELSE 'MAINTAIN'
        END,
        'model_capacity_analysis', v_model_capacity,
        'scaling_factors', jsonb_build_object(
            'latency_pressure', ROUND((v_current_latency::DECIMAL / 500) * 100, 2),
            'throughput_pressure', ROUND((v_current_rpm::DECIMAL / 1000) * 100, 2)
        ),
        'metadata_sources', ARRAY[
            'ai_deployment_status_s',
            'ai_model_performance_s'
        ]
    );
    
    RETURN v_scaling_decision;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION business.make_scaling_decision(BYTEA, JSONB) IS 
'Makes intelligent auto-scaling decisions based on real-time load and historical AI performance metadata.'; 