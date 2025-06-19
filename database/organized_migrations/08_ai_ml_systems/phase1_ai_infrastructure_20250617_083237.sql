-- Phase 1: AI Infrastructure Enhancement
-- Objective: Add 4 missing AI observation tables to reach 100% AI completeness

-- Start transaction
BEGIN;

-- AI Interaction Hub (for tracking individual AI interactions)
CREATE TABLE IF NOT EXISTS business.ai_interaction_h (
    ai_interaction_hk BYTEA PRIMARY KEY,
    ai_interaction_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_ai_interaction_h_bk_tenant 
        UNIQUE (ai_interaction_bk, tenant_hk)
);

COMMENT ON TABLE business.ai_interaction_h IS 
'Hub table for AI interaction tracking maintaining unique identifiers for each AI conversation or request with complete tenant isolation and audit compliance.';

-- AI Interaction Details Satellite
CREATE TABLE IF NOT EXISTS business.ai_interaction_details_s (
    ai_interaction_hk BYTEA NOT NULL REFERENCES business.ai_interaction_h(ai_interaction_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    interaction_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    user_input TEXT,
    ai_response TEXT,
    model_used VARCHAR(100),
    processing_time_ms INTEGER,
    token_count_input INTEGER,
    token_count_output INTEGER,
    context_type VARCHAR(50),
    security_level VARCHAR(20) DEFAULT 'safe',
    content_filtered BOOLEAN DEFAULT false,
    interaction_metadata JSONB,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL,
    
    PRIMARY KEY (ai_interaction_hk, load_date),
    
    CONSTRAINT chk_ai_interaction_details_s_processing_time 
        CHECK (processing_time_ms IS NULL OR processing_time_ms >= 0),
    CONSTRAINT chk_ai_interaction_details_s_tokens 
        CHECK (token_count_input IS NULL OR token_count_input >= 0),
    CONSTRAINT chk_ai_interaction_details_s_security 
        CHECK (security_level IN ('safe', 'moderate', 'high_risk'))
);

COMMENT ON TABLE business.ai_interaction_details_s IS 
'Satellite table storing AI interaction details including prompts, responses, performance metrics, and safety information with complete tenant isolation and audit trail.';

-- AI Model Performance Hub
CREATE TABLE IF NOT EXISTS business.ai_model_performance_h (
    ai_model_performance_hk BYTEA PRIMARY KEY,
    ai_model_performance_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_ai_model_performance_h_bk_tenant 
        UNIQUE (ai_model_performance_bk, tenant_hk)
);

COMMENT ON TABLE business.ai_model_performance_h IS 
'Hub table for AI model performance tracking maintaining unique identifiers for performance evaluation records with complete tenant isolation and Data Vault 2.0 compliance.';

-- AI Model Performance Satellite
CREATE TABLE IF NOT EXISTS business.ai_model_performance_s (
    ai_model_performance_hk BYTEA NOT NULL REFERENCES business.ai_model_performance_h(ai_model_performance_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    evaluation_date DATE NOT NULL,
    accuracy_score DECIMAL(5,4),
    precision_score DECIMAL(5,4),
    recall_score DECIMAL(5,4),
    f1_score DECIMAL(5,4),
    auc_score DECIMAL(5,4),
    training_data_size INTEGER,
    test_data_size INTEGER,
    inference_time_ms INTEGER,
    memory_usage_mb INTEGER,
    cpu_utilization_percent DECIMAL(5,2),
    model_drift_score DECIMAL(5,4),
    data_drift_score DECIMAL(5,4),
    performance_degradation BOOLEAN DEFAULT false,
    retraining_recommended BOOLEAN DEFAULT false,
    evaluation_metrics JSONB,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL,
    
    PRIMARY KEY (ai_model_performance_hk, load_date),
    
    CONSTRAINT chk_ai_model_performance_s_scores 
        CHECK (accuracy_score IS NULL OR (accuracy_score >= 0 AND accuracy_score <= 1)),
    CONSTRAINT chk_ai_model_performance_s_cpu 
        CHECK (cpu_utilization_percent IS NULL OR (cpu_utilization_percent >= 0 AND cpu_utilization_percent <= 100))
);

COMMENT ON TABLE business.ai_model_performance_s IS 
'Satellite table storing AI model performance metrics including accuracy, precision, recall, drift detection, and resource utilization with full temporal tracking for compliance and optimization.';

-- AI Training Execution Hub
CREATE TABLE IF NOT EXISTS business.ai_training_execution_h (
    ai_training_execution_hk BYTEA PRIMARY KEY,
    ai_training_execution_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_ai_training_execution_h_bk_tenant 
        UNIQUE (ai_training_execution_bk, tenant_hk)
);

COMMENT ON TABLE business.ai_training_execution_h IS 
'Hub table for AI training execution tracking maintaining unique identifiers for training jobs with complete tenant isolation and audit trail compliance.';

-- AI Training Execution Satellite
CREATE TABLE IF NOT EXISTS business.ai_training_execution_s (
    ai_training_execution_hk BYTEA NOT NULL REFERENCES business.ai_training_execution_h(ai_training_execution_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    training_job_id VARCHAR(255) NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    training_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    training_end_time TIMESTAMP WITH TIME ZONE,
    training_status VARCHAR(50) NOT NULL,
    training_duration_minutes INTEGER,
    dataset_version VARCHAR(50),
    hyperparameters JSONB,
    training_loss DECIMAL(10,6),
    validation_loss DECIMAL(10,6),
    epochs_completed INTEGER,
    early_stopping_triggered BOOLEAN DEFAULT false,
    resource_utilization JSONB,
    error_message TEXT,
    artifacts_location VARCHAR(500),
    model_checkpoints JSONB,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL,
    
    PRIMARY KEY (ai_training_execution_hk, load_date),
    
    CONSTRAINT chk_ai_training_execution_s_status 
        CHECK (training_status IN ('RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    CONSTRAINT chk_ai_training_execution_s_duration 
        CHECK (training_duration_minutes IS NULL OR training_duration_minutes >= 0),
    CONSTRAINT chk_ai_training_execution_s_epochs 
        CHECK (epochs_completed IS NULL OR epochs_completed >= 0)
);

COMMENT ON TABLE business.ai_training_execution_s IS 
'Satellite table storing AI training execution details including job status, hyperparameters, loss metrics, and resource utilization with complete audit trail for model lifecycle management.';

-- AI Deployment Status Hub
CREATE TABLE IF NOT EXISTS business.ai_deployment_status_h (
    ai_deployment_status_hk BYTEA PRIMARY KEY,
    ai_deployment_status_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_ai_deployment_status_h_bk_tenant 
        UNIQUE (ai_deployment_status_bk, tenant_hk)
);

COMMENT ON TABLE business.ai_deployment_status_h IS 
'Hub table for AI deployment status tracking maintaining unique identifiers for model deployments with complete tenant isolation and production monitoring compliance.';

-- AI Deployment Status Satellite
CREATE TABLE IF NOT EXISTS business.ai_deployment_status_s (
    ai_deployment_status_hk BYTEA NOT NULL REFERENCES business.ai_deployment_status_h(ai_deployment_status_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    deployment_id VARCHAR(255) NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    deployment_environment VARCHAR(50) NOT NULL,
    deployment_status VARCHAR(50) NOT NULL,
    deployment_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    endpoint_url VARCHAR(500),
    health_check_url VARCHAR(500),
    scaling_config JSONB,
    resource_allocation JSONB,
    traffic_percentage DECIMAL(5,2) DEFAULT 100.00,
    canary_deployment BOOLEAN DEFAULT false,
    rollback_version VARCHAR(50),
    deployment_notes TEXT,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL,
    
    PRIMARY KEY (ai_deployment_status_hk, load_date),
    
    CONSTRAINT chk_ai_deployment_status_s_environment 
        CHECK (deployment_environment IN ('DEV', 'STAGING', 'PROD')),
    CONSTRAINT chk_ai_deployment_status_s_status 
        CHECK (deployment_status IN ('DEPLOYING', 'ACTIVE', 'INACTIVE', 'FAILED')),
    CONSTRAINT chk_ai_deployment_status_s_traffic 
        CHECK (traffic_percentage >= 0 AND traffic_percentage <= 100)
);

COMMENT ON TABLE business.ai_deployment_status_s IS 
'Satellite table storing AI deployment status including environment, scaling configuration, traffic routing, and health monitoring with complete audit trail for production operations.';

-- AI Feature Pipeline Hub
CREATE TABLE IF NOT EXISTS business.ai_feature_pipeline_h (
    ai_feature_pipeline_hk BYTEA PRIMARY KEY,
    ai_feature_pipeline_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL,
    
    CONSTRAINT uk_ai_feature_pipeline_h_bk_tenant 
        UNIQUE (ai_feature_pipeline_bk, tenant_hk)
);

COMMENT ON TABLE business.ai_feature_pipeline_h IS 
'Hub table for AI feature pipeline tracking maintaining unique identifiers for feature engineering processes with complete tenant isolation and data lineage compliance.';

-- AI Feature Pipeline Satellite
CREATE TABLE IF NOT EXISTS business.ai_feature_pipeline_s (
    ai_feature_pipeline_hk BYTEA NOT NULL REFERENCES business.ai_feature_pipeline_h(ai_feature_pipeline_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    pipeline_id VARCHAR(255) NOT NULL,
    pipeline_name VARCHAR(200) NOT NULL,
    pipeline_version VARCHAR(50) NOT NULL,
    execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    execution_status VARCHAR(50) NOT NULL,
    input_data_sources JSONB,
    feature_transformations JSONB,
    output_feature_store VARCHAR(200),
    data_quality_score DECIMAL(5,4),
    feature_drift_detected BOOLEAN DEFAULT false,
    processing_time_minutes INTEGER,
    records_processed INTEGER,
    features_generated INTEGER,
    data_lineage JSONB,
    error_details TEXT,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    record_source VARCHAR(100) NOT NULL,
    
    PRIMARY KEY (ai_feature_pipeline_hk, load_date),
    
    CONSTRAINT chk_ai_feature_pipeline_s_status 
        CHECK (execution_status IN ('RUNNING', 'COMPLETED', 'FAILED')),
    CONSTRAINT chk_ai_feature_pipeline_s_quality 
        CHECK (data_quality_score IS NULL OR (data_quality_score >= 0 AND data_quality_score <= 1)),
    CONSTRAINT chk_ai_feature_pipeline_s_processing_time 
        CHECK (processing_time_minutes IS NULL OR processing_time_minutes >= 0)
);

COMMENT ON TABLE business.ai_feature_pipeline_s IS 
'Satellite table storing AI feature pipeline execution details including data sources, transformations, quality metrics, and lineage tracking with complete audit trail for data governance.';

-- Create performance indexes
-- AI Interaction indexes
CREATE INDEX IF NOT EXISTS idx_ai_interaction_details_s_tenant_timestamp 
ON business.ai_interaction_details_s (tenant_hk, interaction_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_interaction_details_s_model_timestamp 
ON business.ai_interaction_details_s (model_used, interaction_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_model_performance_s_tenant_date 
ON business.ai_model_performance_s (tenant_hk, evaluation_date DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_model_performance_s_model_version 
ON business.ai_model_performance_s (model_name, model_version, evaluation_date DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_training_execution_s_tenant_status 
ON business.ai_training_execution_s (tenant_hk, training_status, training_start_time DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_training_execution_s_job_id 
ON business.ai_training_execution_s (training_job_id, training_start_time DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_deployment_status_s_tenant_env 
ON business.ai_deployment_status_s (tenant_hk, deployment_environment, deployment_status) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_deployment_status_s_model_version 
ON business.ai_deployment_status_s (model_name, model_version, deployment_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_feature_pipeline_s_tenant_status 
ON business.ai_feature_pipeline_s (tenant_hk, execution_status, execution_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_feature_pipeline_s_pipeline_name 
ON business.ai_feature_pipeline_s (pipeline_name, pipeline_version, execution_timestamp DESC) 
WHERE load_end_date IS NULL;

-- Create AI analytics materialized view
CREATE MATERIALIZED VIEW IF NOT EXISTS infomart.ai_comprehensive_analytics AS
SELECT 
    t.tenant_hk,
    t.tenant_name,
    DATE(COALESCE(amp.evaluation_date, ats.training_start_time::date, ads.deployment_timestamp::date, afp.execution_timestamp::date)) as analysis_date,
    
    -- NEW: Model Performance Metrics
    COUNT(DISTINCT amp.ai_model_performance_hk) as performance_evaluations,
    AVG(amp.accuracy_score) as avg_accuracy_score,
    AVG(amp.f1_score) as avg_f1_score,
    COUNT(*) FILTER (WHERE amp.performance_degradation = true) as models_with_degradation,
    COUNT(*) FILTER (WHERE amp.retraining_recommended = true) as models_needing_retraining,
    
    -- NEW: Training Metrics
    COUNT(DISTINCT ats.ai_training_execution_hk) as training_jobs,
    COUNT(*) FILTER (WHERE ats.training_status = 'COMPLETED') as completed_training_jobs,
    COUNT(*) FILTER (WHERE ats.training_status = 'RUNNING') as running_training_jobs,
    COUNT(*) FILTER (WHERE ats.training_status = 'FAILED') as failed_training_jobs,
    AVG(ats.training_duration_minutes) as avg_training_duration_minutes,
    
    -- NEW: Deployment Metrics  
    COUNT(DISTINCT ads.ai_deployment_status_hk) as deployments,
    COUNT(*) FILTER (WHERE ads.deployment_status = 'ACTIVE') as active_deployments,
    COUNT(*) FILTER (WHERE ads.deployment_environment = 'PROD') as prod_deployments,
    COUNT(*) FILTER (WHERE ads.canary_deployment = true) as canary_deployments,
    
    -- NEW: Feature Pipeline Metrics
    COUNT(DISTINCT afp.ai_feature_pipeline_hk) as feature_pipelines,
    COUNT(*) FILTER (WHERE afp.execution_status = 'COMPLETED') as completed_pipelines,
    COUNT(*) FILTER (WHERE afp.feature_drift_detected = true) as pipelines_with_drift,
    AVG(afp.data_quality_score) as avg_data_quality_score,
    
    CURRENT_TIMESTAMP as last_updated

FROM auth.tenant_h th
JOIN auth.tenant_profile_s t ON th.tenant_hk = t.tenant_hk AND t.load_end_date IS NULL

-- Left join with NEW AI observation tables
LEFT JOIN business.ai_model_performance_h amph ON th.tenant_hk = amph.tenant_hk
LEFT JOIN business.ai_model_performance_s amp ON amph.ai_model_performance_hk = amp.ai_model_performance_hk AND amp.load_end_date IS NULL

LEFT JOIN business.ai_training_execution_h ateh ON th.tenant_hk = ateh.tenant_hk
LEFT JOIN business.ai_training_execution_s ats ON ateh.ai_training_execution_hk = ats.ai_training_execution_hk AND ats.load_end_date IS NULL

LEFT JOIN business.ai_deployment_status_h adsh ON th.tenant_hk = adsh.tenant_hk
LEFT JOIN business.ai_deployment_status_s ads ON adsh.ai_deployment_status_hk = ads.ai_deployment_status_hk AND ads.load_end_date IS NULL

LEFT JOIN business.ai_feature_pipeline_h afph ON th.tenant_hk = afph.tenant_hk
LEFT JOIN business.ai_feature_pipeline_s afp ON afph.ai_feature_pipeline_hk = afp.ai_feature_pipeline_hk AND afp.load_end_date IS NULL

GROUP BY 
    t.tenant_hk, 
    t.tenant_name, 
    DATE(COALESCE(amp.evaluation_date, ats.training_start_time::date, ads.deployment_timestamp::date, afp.execution_timestamp::date))

ORDER BY analysis_date DESC, t.tenant_name;

COMMENT ON MATERIALIZED VIEW infomart.ai_comprehensive_analytics IS 
'Comprehensive analytics view combining metrics from all AI observation tables for monitoring and reporting.';

-- Create analytics refresh function
CREATE OR REPLACE FUNCTION infomart.refresh_ai_analytics()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY infomart.ai_comprehensive_analytics;
    
    -- Log the refresh
    INSERT INTO util.maintenance_log (
        maintenance_type,
        maintenance_details,
        execution_timestamp,
        execution_status
    ) VALUES (
        'MATERIALIZED_VIEW_REFRESH',
        'AI comprehensive analytics view refreshed successfully',
        CURRENT_TIMESTAMP,
        'COMPLETED'
    ) ON CONFLICT DO NOTHING;
    
EXCEPTION WHEN OTHERS THEN
    -- Log the error
    INSERT INTO util.maintenance_log (
        maintenance_type,
        maintenance_details,
        execution_timestamp,
        execution_status,
        error_message
    ) VALUES (
        'MATERIALIZED_VIEW_REFRESH',
        'AI comprehensive analytics view refresh failed',
        CURRENT_TIMESTAMP,
        'FAILED',
        SQLERRM
    ) ON CONFLICT DO NOTHING;
    
    RAISE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION infomart.refresh_ai_analytics() IS 
'Refreshes the AI comprehensive analytics materialized view with error handling and logging for automated maintenance procedures.';

-- Commit transaction
COMMIT; 