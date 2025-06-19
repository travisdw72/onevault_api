-- Business Domain Configuration Examples
-- Shows how to configure the generic AI framework for different industries

BEGIN;

-- ==========================================
-- EXAMPLE 1: EQUINE MANAGEMENT (Horse Barn)
-- ==========================================

-- Configure the AI system for horse barn management
/*
SELECT config.setup_business_domain(
    :tenant_hk,
    'equine_management',
    'Horse Barn Management System',
    '{
        "entity_types": [
            "horse",
            "trainer", 
            "veterinarian",
            "equipment"
        ],
        "entity_attributes": {
            "horse": [
                "breed", "age", "weight", "health_status", "training_level",
                "feeding_schedule", "exercise_routine", "medical_history",
                "performance_metrics", "behavioral_traits"
            ],
            "trainer": [
                "experience_level", "specialization", "success_rate"
            ],
            "equipment": [
                "type", "condition", "maintenance_schedule", "usage_frequency"
            ]
        },
        "pattern_types": [
            {
                "type": "health_trend",
                "algorithm": "time_series_analysis",
                "min_data_points": 10
            },
            {
                "type": "performance_pattern", 
                "algorithm": "regression_analysis",
                "min_data_points": 15
            },
            {
                "type": "feeding_optimization",
                "algorithm": "clustering",
                "min_data_points": 20
            },
            {
                "type": "exercise_effectiveness",
                "algorithm": "correlation_analysis", 
                "min_data_points": 12
            }
        ],
        "learning_algorithms": [
            "time_series_analysis",
            "regression_analysis",
            "clustering",
            "correlation_analysis"
        ],
        "learning_rules": {
            "health_monitoring": {
                "frequency": "daily",
                "critical_indicators": ["temperature", "appetite", "mobility"],
                "alert_conditions": ["temperature > 102", "appetite < 50%"]
            },
            "performance_tracking": {
                "frequency": "weekly", 
                "metrics": ["speed", "endurance", "agility"],
                "improvement_threshold": 0.05
            }
        },
        "decision_types": [
            "feeding_adjustment",
            "exercise_modification", 
            "health_alert",
            "training_recommendation",
            "veterinary_consultation"
        ],
        "alert_thresholds": {
            "health_concern": {
                "temperature_high": 102.0,
                "weight_loss_percentage": 5.0,
                "appetite_decrease": 30.0
            },
            "performance_decline": {
                "speed_decrease": 10.0,
                "endurance_decrease": 15.0
            }
        },
        "automation_rules": {
            "auto_vet_alert": true,
            "auto_feeding_adjustment": false,
            "auto_exercise_modification": false
        },
        "success_metrics": [
            "horse_health_score",
            "performance_improvement",
            "cost_per_horse",
            "veterinary_incident_reduction"
        ],
        "roi_calculations": {
            "health_monitoring": {
                "cost_savings_per_early_detection": 2500.00,
                "prevention_vs_treatment_ratio": 0.3
            },
            "performance_optimization": {
                "competition_earning_increase": 15000.00,
                "training_efficiency_gain": 0.25
            }
        }
    }'::jsonb
);
*/

-- ==========================================
-- EXAMPLE 2: MEDICAL EQUIPMENT MANAGEMENT
-- ==========================================

/*
SELECT config.setup_business_domain(
    :tenant_hk,
    'medical_equipment',
    'Medical Equipment Management',
    '{
        "entity_types": [
            "mri_machine",
            "ct_scanner", 
            "ventilator",
            "dialysis_machine",
            "xray_equipment"
        ],
        "entity_attributes": {
            "mri_machine": [
                "model", "manufacture_date", "last_calibration", "usage_hours",
                "scan_quality_score", "maintenance_history", "downtime_minutes",
                "patient_throughput", "error_frequency"
            ],
            "ct_scanner": [
                "model", "radiation_dose_tracking", "image_quality", "calibration_status",
                "maintenance_schedule", "usage_patterns", "error_logs"
            ]
        },
        "pattern_types": [
            {
                "type": "maintenance_prediction",
                "algorithm": "predictive_maintenance",
                "min_data_points": 30
            },
            {
                "type": "usage_optimization",
                "algorithm": "scheduling_optimization",
                "min_data_points": 50
            },
            {
                "type": "quality_degradation",
                "algorithm": "anomaly_detection",
                "min_data_points": 25
            }
        ],
        "learning_algorithms": [
            "predictive_maintenance",
            "anomaly_detection",
            "scheduling_optimization"
        ],
        "learning_rules": {
            "preventive_maintenance": {
                "frequency": "continuous",
                "predictive_window_days": 30,
                "confidence_threshold": 0.8
            },
            "quality_monitoring": {
                "frequency": "per_use",
                "quality_threshold": 0.95,
                "degradation_alert": 0.05
            }
        },
        "decision_types": [
            "maintenance_scheduling",
            "equipment_replacement",
            "usage_reallocation",
            "quality_intervention"
        ],
        "alert_thresholds": {
            "maintenance_needed": {
                "failure_probability": 0.7,
                "days_until_failure": 7
            },
            "quality_concern": {
                "image_quality_drop": 0.1,
                "calibration_drift": 0.05
            }
        },
        "automation_rules": {
            "auto_maintenance_schedule": true,
            "auto_quality_adjustment": false,
            "auto_usage_balancing": true
        },
        "success_metrics": [
            "equipment_uptime",
            "maintenance_cost_reduction",
            "patient_satisfaction",
            "equipment_lifespan_extension"
        ],
        "roi_calculations": {
            "predictive_maintenance": {
                "downtime_cost_per_hour": 5000.00,
                "maintenance_cost_reduction": 0.30
            },
            "quality_optimization": {
                "repeat_scan_cost": 1200.00,
                "patient_satisfaction_value": 500.00
            }
        }
    }'::jsonb
);
*/

-- ==========================================
-- EXAMPLE 3: MANUFACTURING QUALITY CONTROL
-- ==========================================

SELECT config.setup_business_domain(
    :tenant_hk,
    'manufacturing_qc',
    'Manufacturing Quality Control',
    '{
        "entity_types": [
            "production_line",
            "quality_inspector",
            "raw_material_batch",
            "finished_product"
        ],
        "entity_attributes": {
            "production_line": [
                "line_speed", "temperature", "pressure", "humidity",
                "defect_rate", "throughput", "efficiency_score",
                "maintenance_status", "operator_performance"
            ],
            "finished_product": [
                "quality_score", "dimensions", "weight", "color_consistency",
                "durability_test", "batch_id", "production_timestamp"
            ]
        },
        "pattern_types": [
            {
                "type": "defect_prediction",
                "algorithm": "classification_ml",
                "min_data_points": 100
            },
            {
                "type": "process_optimization",
                "algorithm": "process_mining",
                "min_data_points": 200
            },
            {
                "type": "quality_correlation",
                "algorithm": "multivariate_analysis",
                "min_data_points": 150
            }
        ],
        "learning_algorithms": [
            "classification_ml",
            "process_mining", 
            "multivariate_analysis",
            "control_charts"
        ],
        "learning_rules": {
            "quality_monitoring": {
                "frequency": "real_time",
                "statistical_control": true,
                "control_limits": "3_sigma"
            },
            "process_optimization": {
                "frequency": "daily",
                "optimization_target": "minimize_defects_maximize_throughput"
            }
        },
        "decision_types": [
            "process_adjustment",
            "quality_intervention",
            "batch_rejection",
            "maintenance_trigger"
        ],
        "alert_thresholds": {
            "quality_control": {
                "defect_rate_increase": 0.02,
                "process_drift": 0.05,
                "efficiency_decrease": 0.10
            }
        },
        "automation_rules": {
            "auto_process_adjustment": true,
            "auto_batch_rejection": false,
            "auto_maintenance_trigger": true
        },
        "success_metrics": [
            "defect_rate_reduction",
            "throughput_increase",
            "waste_reduction",
            "customer_satisfaction"
        ],
        "roi_calculations": {
            "defect_reduction": {
                "cost_per_defective_unit": 50.00,
                "rework_cost_multiplier": 3.0
            },
            "efficiency_improvement": {
                "revenue_per_unit": 100.00,
                "throughput_value_multiplier": 1.2
            }
        }
    }'::jsonb
);

-- ==========================================
-- USAGE EXAMPLES: HOW AI LEARNS & DECIDES
-- ==========================================

-- Example 1: Horse health data learning
/*
SELECT business.ai_learn_from_data(
    :tenant_hk,
    'equine_management',
    'horse', 
    'Thunder_ID_12345',
    '[
        {
            "timestamp": "2024-01-15T08:00:00Z",
            "temperature": 100.2,
            "heart_rate": 32,
            "appetite": 85,
            "exercise_performance": 8.5,
            "weight": 1200
        },
        {
            "timestamp": "2024-01-16T08:00:00Z", 
            "temperature": 100.4,
            "heart_rate": 34,
            "appetite": 80,
            "exercise_performance": 8.2,
            "weight": 1198
        },
        {
            "timestamp": "2024-01-17T08:00:00Z",
            "temperature": 101.1,
            "heart_rate": 38,
            "appetite": 70,
            "exercise_performance": 7.8,
            "weight": 1195
        },
        {
            "timestamp": "2024-01-18T08:00:00Z",
            "temperature": 101.8,
            "heart_rate": 42,
            "appetite": 65,
            "exercise_performance": 7.2,
            "weight": 1192
        },
        {
            "timestamp": "2024-01-19T08:00:00Z",
            "temperature": 102.1,
            "heart_rate": 45,
            "appetite": 60,
            "exercise_performance": 6.8,
            "weight": 1190
        }
    ]'::jsonb,
    '{"data_source": "daily_health_monitoring", "collected_by": "stable_manager"}'::jsonb
);
*/

-- Example 2: MRI machine usage pattern learning  
SELECT business.ai_learn_from_data(
    :tenant_hk,
    'medical_equipment',
    'mri_machine',
    'MRI_Unit_A7', 
    '[
        {
            "date": "2024-01-15",
            "scans_performed": 12,
            "average_scan_time": 45,
            "image_quality_score": 0.95,
            "calibration_drift": 0.02,
            "maintenance_alerts": 0
        },
        {
            "date": "2024-01-16", 
            "scans_performed": 14,
            "average_scan_time": 47,
            "image_quality_score": 0.94,
            "calibration_drift": 0.03,
            "maintenance_alerts": 0
        },
        {
            "date": "2024-01-17",
            "scans_performed": 15,
            "average_scan_time": 48,
            "image_quality_score": 0.92,
            "calibration_drift": 0.04,
            "maintenance_alerts": 1
        },
        {
            "date": "2024-01-18",
            "scans_performed": 13,
            "average_scan_time": 50,
            "image_quality_score": 0.90,
            "calibration_drift": 0.06,
            "maintenance_alerts": 2
        },
        {
            "date": "2024-01-19",
            "scans_performed": 11,
            "average_scan_time": 52,
            "image_quality_score": 0.88,
            "calibration_drift": 0.08,
            "maintenance_alerts": 3
        }
    ]'::jsonb,
    '{"department": "radiology", "technician": "Sarah_Johnson"}'::jsonb
);

-- ==========================================
-- GET INSIGHTS FOR ANY ENTITY
-- ==========================================

-- Get insights for a specific horse
/*
SELECT business.get_entity_insights(
    :tenant_hk,
    'equine_management', 
    'horse',
    'Thunder_ID_12345'
);
*/

-- Get insights for MRI machine
SELECT business.get_entity_insights(
    :tenant_hk,
    'medical_equipment',
    'mri_machine', 
    'MRI_Unit_A7'
);

-- ==========================================
-- CROSS-DOMAIN ANALYTICS VIEW
-- ==========================================

CREATE MATERIALIZED VIEW IF NOT EXISTS infomart.cross_domain_ai_analytics AS
SELECT 
    t.tenant_hk,
    t.tenant_name,
    alps.business_domain,
    alps.entity_type,
    COUNT(DISTINCT alps.entity_identifier) as entities_tracked,
    COUNT(DISTINCT alps.pattern_type) as pattern_types_discovered,
    AVG(alps.confidence_score) as avg_pattern_confidence,
    SUM(alps.business_value_generated) as total_business_value,
    COUNT(*) FILTER (WHERE alps.predictions_made > 0) as predictive_patterns,
    AVG(CASE 
        WHEN alps.predictions_made > 0 
        THEN alps.predictions_correct::DECIMAL / alps.predictions_made 
        ELSE NULL 
    END) as avg_prediction_accuracy,
    DATE(alps.pattern_discovered_date) as analysis_date,
    CURRENT_TIMESTAMP as last_updated
FROM auth.tenant_h th
JOIN auth.tenant_profile_s t ON th.tenant_hk = t.tenant_hk AND t.load_end_date IS NULL
JOIN business.ai_business_intelligence_h abih ON th.tenant_hk = abih.tenant_hk
JOIN business.ai_learning_pattern_s alps ON abih.ai_business_intelligence_hk = alps.ai_business_intelligence_hk
WHERE alps.load_end_date IS NULL
GROUP BY 
    t.tenant_hk,
    t.tenant_name, 
    alps.business_domain,
    alps.entity_type,
    DATE(alps.pattern_discovered_date)
ORDER BY analysis_date DESC, total_business_value DESC;

COMMENT ON MATERIALIZED VIEW infomart.cross_domain_ai_analytics IS 
'Cross-domain analytics showing AI learning performance across all business domains and entity types within each tenant.';

-- ==========================================
-- UNIVERSAL BUSINESS INTELLIGENCE QUERY
-- ==========================================

CREATE OR REPLACE FUNCTION reporting.get_business_intelligence_summary(
    p_tenant_hk BYTEA,
    p_business_domain VARCHAR(100) DEFAULT NULL,
    p_date_range_days INTEGER DEFAULT 30
) RETURNS JSONB AS $$
DECLARE
    v_summary JSONB;
BEGIN
    WITH domain_summary AS (
        SELECT 
            alps.business_domain,
            COUNT(DISTINCT alps.entity_identifier) as entities_tracked,
            COUNT(DISTINCT alps.pattern_type) as patterns_learned,
            AVG(alps.confidence_score) as avg_confidence,
            SUM(alps.business_value_generated) as value_generated,
            COUNT(*) FILTER (WHERE alps.predictions_made > 0) as predictive_patterns
        FROM business.ai_learning_pattern_s alps
        JOIN business.ai_business_intelligence_h abih ON alps.ai_business_intelligence_hk = abih.ai_business_intelligence_hk
        WHERE abih.tenant_hk = p_tenant_hk
        AND alps.load_end_date IS NULL
        AND alps.pattern_discovered_date >= CURRENT_DATE - INTERVAL '1 day' * p_date_range_days
        AND (p_business_domain IS NULL OR alps.business_domain = p_business_domain)
        GROUP BY alps.business_domain
    )
    SELECT jsonb_object_agg(
        business_domain,
        jsonb_build_object(
            'entities_tracked', entities_tracked,
            'patterns_learned', patterns_learned,
            'avg_confidence', ROUND(avg_confidence, 4),
            'business_value', value_generated,
            'predictive_patterns', predictive_patterns,
            'learning_maturity', CASE 
                WHEN patterns_learned >= 10 THEN 'advanced'
                WHEN patterns_learned >= 5 THEN 'developing'
                WHEN patterns_learned >= 1 THEN 'emerging'
                ELSE 'insufficient_data'
            END
        )
    ) INTO v_summary
    FROM domain_summary;
    
    RETURN jsonb_build_object(
        'tenant_id', encode(p_tenant_hk, 'hex'),
        'analysis_period_days', p_date_range_days,
        'analysis_timestamp', CURRENT_TIMESTAMP,
        'domains', COALESCE(v_summary, '{}'::jsonb),
        'overall_status', CASE 
            WHEN v_summary IS NULL THEN 'no_learning_activity'
            WHEN jsonb_object_keys(v_summary) IS NULL THEN 'single_domain'
            ELSE 'multi_domain_learning'
        END
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION reporting.get_business_intelligence_summary(BYTEA, VARCHAR, INTEGER) IS 
'Universal business intelligence summary function that works across all configured business domains and entity types.';

COMMIT; 