-- Phase 1 Database Additions for Parallel Validation Tracking
-- Execute these on localhost database before Phase 1 implementation

-- 1. Parallel Validation Logging
CREATE TABLE IF NOT EXISTS audit.parallel_validation_h (
    validation_hk BYTEA PRIMARY KEY,
    validation_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'phase1_parallel_validation'
);

CREATE TABLE IF NOT EXISTS audit.parallel_validation_s (
    validation_hk BYTEA NOT NULL REFERENCES audit.parallel_validation_h(validation_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    -- Request context
    api_endpoint VARCHAR(200),
    http_method VARCHAR(10),
    client_ip INET,
    user_agent TEXT,
    -- Current validation results
    current_method_success BOOLEAN,
    current_method_duration_ms INTEGER,
    current_method_response JSONB,
    -- Enhanced validation results  
    enhanced_method_success BOOLEAN,
    enhanced_method_duration_ms INTEGER,
    enhanced_method_response JSONB,
    enhanced_token_extended BOOLEAN DEFAULT false,
    enhanced_cross_tenant_blocked BOOLEAN DEFAULT false,
    -- Performance comparison
    performance_improvement_ms INTEGER, -- positive = enhanced faster
    cache_hit BOOLEAN DEFAULT false,
    -- Audit trail
    validation_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    session_id VARCHAR(100),
    record_source VARCHAR(100) NOT NULL DEFAULT 'phase1_parallel_validation',
    PRIMARY KEY (validation_hk, load_date)
);

-- 2. Performance Metrics Tracking
CREATE TABLE IF NOT EXISTS audit.performance_metrics_h (
    metric_hk BYTEA PRIMARY KEY,
    metric_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'phase1_performance'
);

CREATE TABLE IF NOT EXISTS audit.performance_metrics_s (
    metric_hk BYTEA NOT NULL REFERENCES audit.performance_metrics_h(metric_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    -- Metric details
    metric_type VARCHAR(50) NOT NULL, -- 'api_response', 'validation', 'cache_performance'
    metric_category VARCHAR(50), -- 'current_system', 'enhanced_system', 'parallel_comparison'
    operation_name VARCHAR(100),
    -- Performance measurements
    duration_ms INTEGER,
    memory_usage_mb DECIMAL(10,2),
    cpu_usage_percent DECIMAL(5,2),
    cache_hit_rate DECIMAL(5,2),
    -- Comparison metrics
    baseline_duration_ms INTEGER,
    improvement_percentage DECIMAL(5,2),
    -- Context
    measurement_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    environment VARCHAR(20) DEFAULT 'localhost',
    phase VARCHAR(20) DEFAULT 'phase1',
    additional_metrics JSONB,
    record_source VARCHAR(100) NOT NULL DEFAULT 'phase1_performance',
    PRIMARY KEY (metric_hk, load_date)
);

-- 3. Cache Performance Tracking
CREATE TABLE IF NOT EXISTS audit.cache_performance_h (
    cache_event_hk BYTEA PRIMARY KEY,
    cache_event_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'phase1_cache'
);

CREATE TABLE IF NOT EXISTS audit.cache_performance_s (
    cache_event_hk BYTEA NOT NULL REFERENCES audit.cache_performance_h(cache_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    -- Cache event details
    cache_type VARCHAR(50), -- 'validation_cache', 'tenant_cache', 'permission_cache'
    cache_operation VARCHAR(20), -- 'hit', 'miss', 'set', 'invalidate'
    cache_key_hash BYTEA, -- Hash of cache key for privacy
    -- Performance impact
    cache_response_time_ms INTEGER,
    cache_size_bytes INTEGER,
    cache_ttl_seconds INTEGER,
    cache_hit_rate DECIMAL(5,2),
    -- Without cache comparison
    uncached_response_time_ms INTEGER,
    performance_gain_ms INTEGER,
    -- Context
    api_endpoint VARCHAR(200),
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    cache_statistics JSONB,
    record_source VARCHAR(100) NOT NULL DEFAULT 'phase1_cache',
    PRIMARY KEY (cache_event_hk, load_date)
);

-- 4. Enhanced Security Events (extends existing audit.security_event_s)
CREATE TABLE IF NOT EXISTS audit.phase1_security_events_h (
    security_event_hk BYTEA PRIMARY KEY,
    security_event_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'phase1_security'
);

CREATE TABLE IF NOT EXISTS audit.phase1_security_events_s (
    security_event_hk BYTEA NOT NULL REFERENCES audit.phase1_security_events_h(security_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    -- Security event details
    event_type VARCHAR(50), -- 'cross_tenant_blocked', 'token_extended', 'enhanced_validation_success'
    event_severity VARCHAR(20) DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    detection_method VARCHAR(50) DEFAULT 'enhanced_validation', -- 'enhanced_validation', 'parallel_check'
    -- Request context
    source_ip INET,
    user_agent TEXT,
    api_endpoint VARCHAR(200),
    -- Token and tenant details
    token_tenant_hk BYTEA,
    requested_tenant_hk BYTEA,
    user_hk BYTEA,
    session_hk BYTEA,
    -- Enhanced validation specific
    current_validation_result BOOLEAN,
    enhanced_validation_result BOOLEAN,
    validation_discrepancy BOOLEAN, -- true if current and enhanced disagree
    auto_remediation_applied BOOLEAN DEFAULT false,
    -- Incident details
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    event_description TEXT,
    additional_context JSONB,
    resolved_at TIMESTAMP WITH TIME ZONE,
    record_source VARCHAR(100) NOT NULL DEFAULT 'phase1_security',
    PRIMARY KEY (security_event_hk, load_date)
);

-- Helper functions for Phase 1 logging
CREATE OR REPLACE FUNCTION audit.log_parallel_validation(
    p_tenant_hk BYTEA,
    p_api_endpoint VARCHAR(200),
    p_current_success BOOLEAN,
    p_current_duration_ms INTEGER,
    p_enhanced_success BOOLEAN,
    p_enhanced_duration_ms INTEGER,
    p_enhanced_response JSONB DEFAULT NULL,
    p_token_extended BOOLEAN DEFAULT false,
    p_cross_tenant_blocked BOOLEAN DEFAULT false,
    p_cache_hit BOOLEAN DEFAULT false
) RETURNS BYTEA AS $$
DECLARE
    v_validation_hk BYTEA;
    v_validation_bk VARCHAR(255);
    v_performance_improvement INTEGER;
BEGIN
    -- Generate keys
    v_validation_bk := 'PARALLEL_VAL_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US');
    v_validation_hk := util.hash_binary(v_validation_bk);
    
    -- Calculate performance improvement
    v_performance_improvement := p_current_duration_ms - p_enhanced_duration_ms;
    
    -- Insert hub
    INSERT INTO audit.parallel_validation_h VALUES (
        v_validation_hk, v_validation_bk, p_tenant_hk,
        util.current_load_date(), 'phase1_parallel_validation'
    );
    
    -- Insert satellite
    INSERT INTO audit.parallel_validation_s VALUES (
        v_validation_hk, util.current_load_date(), NULL,
        util.hash_binary(v_validation_bk || p_current_success::text || p_enhanced_success::text),
        p_api_endpoint, 'POST', inet_client_addr(), 
        current_setting('application_name', true),
        p_current_success, p_current_duration_ms, NULL,
        p_enhanced_success, p_enhanced_duration_ms, p_enhanced_response,
        p_token_extended, p_cross_tenant_blocked,
        v_performance_improvement, p_cache_hit,
        CURRENT_TIMESTAMP, current_setting('session_id', true),
        'phase1_parallel_validation'
    );
    
    RETURN v_validation_hk;
END;
$$ LANGUAGE plpgsql;

-- Performance benchmarking function
CREATE OR REPLACE FUNCTION audit.log_performance_metric(
    p_tenant_hk BYTEA,
    p_metric_type VARCHAR(50),
    p_category VARCHAR(50),
    p_operation VARCHAR(100),
    p_duration_ms INTEGER,
    p_baseline_ms INTEGER DEFAULT NULL,
    p_additional_metrics JSONB DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_metric_hk BYTEA;
    v_metric_bk VARCHAR(255);
    v_improvement_pct DECIMAL(5,2);
BEGIN
    -- Generate keys
    v_metric_bk := p_metric_type || '_' || p_category || '_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US');
    v_metric_hk := util.hash_binary(v_metric_bk);
    
    -- Calculate improvement percentage
    IF p_baseline_ms IS NOT NULL AND p_baseline_ms > 0 THEN
        v_improvement_pct := ROUND(((p_baseline_ms - p_duration_ms)::DECIMAL / p_baseline_ms) * 100, 2);
    END IF;
    
    -- Insert hub
    INSERT INTO audit.performance_metrics_h VALUES (
        v_metric_hk, v_metric_bk, p_tenant_hk,
        util.current_load_date(), 'phase1_performance'
    );
    
    -- Insert satellite
    INSERT INTO audit.performance_metrics_s VALUES (
        v_metric_hk, util.current_load_date(), NULL,
        util.hash_binary(v_metric_bk || p_duration_ms::text),
        p_metric_type, p_category, p_operation,
        p_duration_ms, NULL, NULL, NULL,
        p_baseline_ms, v_improvement_pct,
        CURRENT_TIMESTAMP, 'localhost', 'phase1',
        p_additional_metrics, 'phase1_performance'
    );
    
    RETURN v_metric_hk;
END;
$$ LANGUAGE plpgsql;

-- Comments for documentation
COMMENT ON TABLE audit.parallel_validation_h IS 'Phase 1: Tracks parallel validation attempts between current and enhanced zero trust systems';
COMMENT ON TABLE audit.performance_metrics_h IS 'Phase 1: Tracks performance improvements from enhanced validation and caching';
COMMENT ON TABLE audit.cache_performance_h IS 'Phase 1: Monitors cache effectiveness for security validation acceleration';
COMMENT ON TABLE audit.phase1_security_events_h IS 'Phase 1: Enhanced security event tracking for zero trust implementation';

-- Grant permissions (adjust as needed)
GRANT SELECT, INSERT, UPDATE ON audit.parallel_validation_h TO api_role;
GRANT SELECT, INSERT, UPDATE ON audit.parallel_validation_s TO api_role;
GRANT SELECT, INSERT, UPDATE ON audit.performance_metrics_h TO api_role;
GRANT SELECT, INSERT, UPDATE ON audit.performance_metrics_s TO api_role;
GRANT SELECT, INSERT, UPDATE ON audit.cache_performance_h TO api_role;
GRANT SELECT, INSERT, UPDATE ON audit.cache_performance_s TO api_role;
GRANT SELECT, INSERT, UPDATE ON audit.phase1_security_events_h TO api_role;
GRANT SELECT, INSERT, UPDATE ON audit.phase1_security_events_s TO api_role;

GRANT EXECUTE ON FUNCTION audit.log_parallel_validation TO api_role;
GRANT EXECUTE ON FUNCTION audit.log_performance_metric TO api_role; 