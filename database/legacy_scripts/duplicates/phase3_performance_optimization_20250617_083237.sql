-- Phase 3: Performance & Scale Optimization
-- Objective: Optimize for enterprise-scale AI workloads (1M+ interactions/day)

-- Start transaction
BEGIN;

-- Create AI-specific performance indexes (removed CONCURRENTLY for template database)
CREATE INDEX IF NOT EXISTS idx_ai_interaction_details_s_tenant_date_performance 
ON business.ai_interaction_details_s (tenant_hk, interaction_timestamp DESC, processing_time_ms) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_interaction_details_s_model_performance 
ON business.ai_interaction_details_s (model_used, interaction_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_interaction_details_s_safety_analysis 
ON business.ai_interaction_details_s (security_level, context_type, interaction_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_interaction_details_s_token_usage 
ON business.ai_interaction_details_s (interaction_timestamp DESC) 
INCLUDE (token_count_input, token_count_output) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_model_performance_s_tenant_model_date 
ON business.ai_model_performance_s (tenant_hk, model_name, evaluation_date DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_model_performance_s_degradation_alert 
ON business.ai_model_performance_s (performance_degradation, retraining_recommended, evaluation_date DESC) 
WHERE load_end_date IS NULL AND (performance_degradation = true OR retraining_recommended = true);

CREATE INDEX IF NOT EXISTS idx_ai_training_execution_s_tenant_status_time 
ON business.ai_training_execution_s (tenant_hk, training_status, training_start_time DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_training_execution_s_model_duration 
ON business.ai_training_execution_s (model_name, training_duration_minutes DESC) 
WHERE load_end_date IS NULL AND training_status = 'COMPLETED';

CREATE INDEX IF NOT EXISTS idx_ai_deployment_status_s_tenant_env_status 
ON business.ai_deployment_status_s (tenant_hk, deployment_environment, deployment_status) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_deployment_status_s_active_prod 
ON business.ai_deployment_status_s (deployment_timestamp DESC) 
WHERE load_end_date IS NULL AND deployment_status = 'ACTIVE' AND deployment_environment = 'PROD';

CREATE INDEX IF NOT EXISTS idx_ai_feature_pipeline_s_tenant_status_time 
ON business.ai_feature_pipeline_s (tenant_hk, execution_status, execution_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_feature_pipeline_s_quality_drift 
ON business.ai_feature_pipeline_s (data_quality_score DESC, feature_drift_detected, execution_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_tenant_isolation_performance_enhanced 
ON auth.tenant_h (tenant_hk) INCLUDE (tenant_bk, load_date);

CREATE INDEX IF NOT EXISTS idx_ai_analytics_materialized_view_refresh 
ON business.ai_interaction_details_s (interaction_timestamp DESC, tenant_hk) 
WHERE load_end_date IS NULL;

-- Create performance tracking tables
CREATE TABLE IF NOT EXISTS util.query_performance_log (
    performance_log_id BIGSERIAL PRIMARY KEY,
    query_name VARCHAR(200) NOT NULL,
    execution_time_ms INTEGER NOT NULL,
    execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tenant_hk BYTEA,
    query_type VARCHAR(50) DEFAULT 'GENERAL',
    database_name VARCHAR(100) DEFAULT current_database(),
    executing_user VARCHAR(100) DEFAULT SESSION_USER,
    additional_metrics JSONB,
    
    CONSTRAINT chk_query_performance_log_time_positive 
        CHECK (execution_time_ms >= 0)
);

COMMENT ON TABLE util.query_performance_log IS 
'Performance tracking table storing query execution metrics for monitoring, optimization, and capacity planning analysis.';

CREATE INDEX IF NOT EXISTS idx_query_performance_log_timestamp 
ON util.query_performance_log (execution_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_query_performance_log_query_name 
ON util.query_performance_log (query_name, execution_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_query_performance_log_tenant 
ON util.query_performance_log (tenant_hk, execution_timestamp DESC) 
WHERE tenant_hk IS NOT NULL;

-- System Health Metrics Table
CREATE TABLE IF NOT EXISTS util.system_health_metrics (
    metric_id BIGSERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(15,4) NOT NULL,
    metric_unit VARCHAR(20),
    measurement_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tenant_hk BYTEA,
    metric_category VARCHAR(50) DEFAULT 'GENERAL',
    threshold_warning DECIMAL(15,4),
    threshold_critical DECIMAL(15,4),
    status VARCHAR(20) DEFAULT 'NORMAL',
    additional_context JSONB
);

COMMENT ON TABLE util.system_health_metrics IS 
'System health metrics storage for real-time monitoring and historical analysis of AI platform performance and capacity.';

CREATE INDEX IF NOT EXISTS idx_system_health_metrics_timestamp 
ON util.system_health_metrics (measurement_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_system_health_metrics_name_category 
ON util.system_health_metrics (metric_name, metric_category, measurement_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_system_health_metrics_status 
ON util.system_health_metrics (status, measurement_timestamp DESC) 
WHERE status != 'NORMAL';

-- Create performance monitoring functions
CREATE OR REPLACE FUNCTION util.monitor_ai_performance()
RETURNS TABLE (
    metric_name VARCHAR(100),
    current_value DECIMAL(15,4),
    threshold_warning DECIMAL(15,4),
    threshold_critical DECIMAL(15,4),
    status VARCHAR(20),
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH ai_metrics AS (
        SELECT 
            'avg_ai_response_time_ms' as metric,
            COALESCE(AVG(processing_time_ms), 0) as value,
            500.0 as warn_threshold,
            2000.0 as crit_threshold
        FROM business.ai_interaction_details_s 
        WHERE interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        AND load_end_date IS NULL
        
        UNION ALL
        
        SELECT 
            'ai_interactions_per_minute',
            COALESCE(COUNT(*)::DECIMAL / 60, 0),
            100.0,
            500.0
        FROM business.ai_interaction_details_s 
        WHERE interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        AND load_end_date IS NULL
        
        UNION ALL
        
        SELECT 
            'ai_safety_score_percent',
            COALESCE(AVG(CASE WHEN security_level = 'safe' THEN 100 ELSE 0 END), 100),
            95.0,
            90.0
        FROM business.ai_interaction_details_s 
        WHERE interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
        AND load_end_date IS NULL
        
        UNION ALL
        
        SELECT 
            'active_tenants_hourly',
            COUNT(DISTINCT aih.tenant_hk)::DECIMAL,
            50.0,
            100.0
        FROM business.ai_interaction_h aih
        JOIN business.ai_interaction_details_s aid ON aih.ai_interaction_hk = aid.ai_interaction_hk
        WHERE aid.interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        AND aid.load_end_date IS NULL
        
        UNION ALL
        
        SELECT 
            'database_connections_count',
            (SELECT count(*)::DECIMAL FROM pg_stat_activity WHERE state = 'active'),
            80.0,
            95.0
            
        UNION ALL
        
        SELECT 
            'database_size_gb',
            pg_database_size(current_database())::DECIMAL / 1024 / 1024 / 1024,
            50.0,
            80.0
    )
    SELECT 
        am.metric,
        am.value,
        am.warn_threshold,
        am.crit_threshold,
        CASE 
            WHEN am.value >= am.crit_threshold THEN 'CRITICAL'
            WHEN am.value >= am.warn_threshold THEN 'WARNING'
            ELSE 'NORMAL'
        END,
        CASE 
            WHEN am.metric = 'avg_ai_response_time_ms' AND am.value >= am.crit_threshold 
                THEN 'Consider scaling AI infrastructure or optimizing queries'
            WHEN am.metric = 'ai_interactions_per_minute' AND am.value >= am.crit_threshold 
                THEN 'High AI usage detected - monitor for capacity planning'
            WHEN am.metric = 'ai_safety_score_percent' AND am.value <= am.crit_threshold 
                THEN 'Safety score below threshold - review AI content filtering'
            WHEN am.metric = 'database_connections_count' AND am.value >= am.crit_threshold 
                THEN 'High database connection count - consider connection pooling'
            WHEN am.metric = 'database_size_gb' AND am.value >= am.crit_threshold 
                THEN 'Database size growing large - consider archival strategy'
            ELSE 'Performance within normal parameters'
        END
    FROM ai_metrics am;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION util.monitor_ai_performance() IS 
'Monitors AI system performance metrics including response times, usage patterns, safety scores, and infrastructure utilization with automated threshold alerting.';

-- Create query performance tracking function
CREATE OR REPLACE FUNCTION util.log_query_performance(
    p_query_name VARCHAR(200),
    p_execution_time_ms INTEGER,
    p_tenant_hk BYTEA DEFAULT NULL,
    p_query_type VARCHAR(50) DEFAULT 'GENERAL'
) RETURNS VOID AS $$
BEGIN
    INSERT INTO util.query_performance_log (
        query_name,
        execution_time_ms,
        execution_timestamp,
        tenant_hk,
        query_type,
        database_name,
        executing_user
    ) VALUES (
        p_query_name,
        p_execution_time_ms,
        CURRENT_TIMESTAMP,
        p_tenant_hk,
        p_query_type,
        current_database(),
        SESSION_USER
    );
EXCEPTION WHEN OTHERS THEN
    -- Silently ignore logging errors to not affect main operations
    NULL;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION util.log_query_performance(VARCHAR, INTEGER, BYTEA, VARCHAR) IS 
'Logs query performance metrics for monitoring and optimization analysis with tenant awareness and error resilience.';

-- Create materialized view refresh procedure
CREATE OR REPLACE FUNCTION util.refresh_all_materialized_views()
RETURNS TABLE (
    view_name VARCHAR(100),
    refresh_status VARCHAR(20),
    refresh_duration_ms INTEGER,
    error_message TEXT
) AS $$
DECLARE
    view_record RECORD;
    start_time TIMESTAMP WITH TIME ZONE;
    end_time TIMESTAMP WITH TIME ZONE;
    duration_ms INTEGER;
    error_msg TEXT;
BEGIN
    -- Refresh AI analytics view (removed CONCURRENTLY since it can't be used in functions called from transactions)
    FOR view_record IN 
        SELECT schemaname, matviewname 
        FROM pg_matviews 
        WHERE schemaname IN ('infomart', 'business', 'util')
        ORDER BY schemaname, matviewname
    LOOP
        start_time := CURRENT_TIMESTAMP;
        error_msg := NULL;
        
        BEGIN
            EXECUTE format('REFRESH MATERIALIZED VIEW %I.%I', 
                         view_record.schemaname, view_record.matviewname);
            
            end_time := CURRENT_TIMESTAMP;
            duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
            
            RETURN QUERY SELECT 
                (view_record.schemaname || '.' || view_record.matviewname)::VARCHAR(100),
                'SUCCESS'::VARCHAR(20),
                duration_ms,
                error_msg;
                
        EXCEPTION WHEN OTHERS THEN
            end_time := CURRENT_TIMESTAMP;
            duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
            error_msg := SQLERRM;
            
            RETURN QUERY SELECT 
                (view_record.schemaname || '.' || view_record.matviewname)::VARCHAR(100),
                'FAILED'::VARCHAR(20),
                duration_ms,
                error_msg;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION util.refresh_all_materialized_views() IS 
'Automated refresh of all materialized views with performance tracking and error handling for scheduled maintenance operations.';

-- Create performance analysis procedure
CREATE OR REPLACE FUNCTION util.analyze_performance_trends(
    p_hours_lookback INTEGER DEFAULT 24
) RETURNS TABLE (
    analysis_category VARCHAR(50),
    metric_name VARCHAR(100),
    avg_value DECIMAL(15,4),
    min_value DECIMAL(15,4),
    max_value DECIMAL(15,4),
    trend_direction VARCHAR(20),
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH performance_trends AS (
        -- AI Response Time Trends
        SELECT 
            'AI_PERFORMANCE' as category,
            'response_time_ms' as metric,
            AVG(processing_time_ms) as avg_val,
            MIN(processing_time_ms) as min_val,
            MAX(processing_time_ms) as max_val,
            CASE 
                WHEN AVG(processing_time_ms) > 1000 THEN 'DEGRADING'
                WHEN AVG(processing_time_ms) < 200 THEN 'EXCELLENT'
                ELSE 'STABLE'
            END as trend,
            CASE 
                WHEN AVG(processing_time_ms) > 1000 THEN 'Consider query optimization or infrastructure scaling'
                WHEN AVG(processing_time_ms) < 200 THEN 'Performance is excellent'
                ELSE 'Performance is acceptable'
            END as recommendation
        FROM business.ai_interaction_details_s 
        WHERE interaction_timestamp >= CURRENT_TIMESTAMP - (p_hours_lookback || ' hours')::INTERVAL
        AND load_end_date IS NULL
        
        UNION ALL
        
        -- Database Connection Trends
        SELECT 
            'DATABASE_PERFORMANCE',
            'active_connections',
            (SELECT count(*)::DECIMAL FROM pg_stat_activity WHERE state = 'active'),
            (SELECT count(*)::DECIMAL FROM pg_stat_activity WHERE state = 'active'),
            (SELECT count(*)::DECIMAL FROM pg_stat_activity WHERE state = 'active'),
            CASE 
                WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') > 80 THEN 'HIGH'
                ELSE 'NORMAL'
            END,
            CASE 
                WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') > 80 THEN 'Consider connection pooling'
                ELSE 'Connection usage is normal'
            END
            
        UNION ALL
        
        -- Token Usage Trends
        SELECT 
            'AI_USAGE',
            'tokens_per_hour',
            AVG(token_count_input + token_count_output),
            MIN(token_count_input + token_count_output),
            MAX(token_count_input + token_count_output),
            CASE 
                WHEN AVG(token_count_input + token_count_output) > 10000 THEN 'HIGH_USAGE'
                ELSE 'NORMAL_USAGE'
            END,
            CASE 
                WHEN AVG(token_count_input + token_count_output) > 10000 THEN 'Monitor token costs and usage patterns'
                ELSE 'Token usage is within normal ranges'
            END
        FROM business.ai_interaction_details_s 
        WHERE interaction_timestamp >= CURRENT_TIMESTAMP - (p_hours_lookback || ' hours')::INTERVAL
        AND load_end_date IS NULL
    )
    SELECT 
        pt.category,
        pt.metric,
        pt.avg_val,
        pt.min_val,
        pt.max_val,
        pt.trend,
        pt.recommendation
    FROM performance_trends pt;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION util.analyze_performance_trends(INTEGER) IS 
'Analyzes performance trends over specified time period providing insights and recommendations for optimization and capacity planning.';

-- Create PostgreSQL configuration analysis function
CREATE OR REPLACE FUNCTION util.analyze_postgresql_config()
RETURNS TABLE (
    setting_name VARCHAR(100),
    current_value TEXT,
    recommended_value TEXT,
    optimization_impact VARCHAR(50),
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ps.name::VARCHAR(100),
        ps.setting,
        CASE 
            WHEN ps.name = 'shared_buffers' AND ps.setting::INTEGER < 262144 THEN '256MB or 25% of RAM'
            WHEN ps.name = 'work_mem' AND ps.setting::INTEGER < 4096 THEN '8MB'
            WHEN ps.name = 'maintenance_work_mem' AND ps.setting::INTEGER < 65536 THEN '128MB'
            WHEN ps.name = 'effective_cache_size' AND ps.setting::INTEGER < 524288 THEN '75% of available RAM'
            WHEN ps.name = 'max_connections' AND ps.setting::INTEGER > 200 THEN '100-200'
            WHEN ps.name = 'checkpoint_completion_target' AND ps.setting::DECIMAL < 0.9 THEN '0.9'
            WHEN ps.name = 'wal_buffers' AND ps.setting::INTEGER < 2048 THEN '16MB'
            WHEN ps.name = 'random_page_cost' AND ps.setting::DECIMAL > 2.0 THEN '1.1 (for SSD)'
            ELSE 'Optimal'
        END as recommended,
        CASE 
            WHEN ps.name = 'shared_buffers' THEN 'HIGH'
            WHEN ps.name = 'work_mem' THEN 'MEDIUM'
            WHEN ps.name = 'effective_cache_size' THEN 'HIGH'
            WHEN ps.name = 'max_connections' THEN 'MEDIUM'
            ELSE 'LOW'
        END as impact,
        CASE 
            WHEN ps.name = 'shared_buffers' AND ps.setting::INTEGER < 262144 THEN 'Increase shared_buffers for better caching'
            WHEN ps.name = 'work_mem' AND ps.setting::INTEGER < 4096 THEN 'Increase work_mem for complex queries'
            WHEN ps.name = 'maintenance_work_mem' AND ps.setting::INTEGER < 65536 THEN 'Increase for faster maintenance operations'
            WHEN ps.name = 'effective_cache_size' AND ps.setting::INTEGER < 524288 THEN 'Set to reflect available OS cache'
            WHEN ps.name = 'max_connections' AND ps.setting::INTEGER > 200 THEN 'Consider connection pooling instead'
            ELSE 'Configuration is appropriate'
        END as recommendation
    FROM pg_settings ps
    WHERE ps.name IN (
        'shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size',
        'max_connections', 'checkpoint_completion_target', 'wal_buffers', 'random_page_cost'
    )
    ORDER BY 
        CASE 
            WHEN ps.name = 'shared_buffers' THEN 1
            WHEN ps.name = 'effective_cache_size' THEN 2
            WHEN ps.name = 'work_mem' THEN 3
            ELSE 4
        END;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION util.analyze_postgresql_config() IS 
'Analyzes PostgreSQL configuration settings and provides optimization recommendations for AI workload performance enhancement.';

-- Commit transaction
COMMIT; 