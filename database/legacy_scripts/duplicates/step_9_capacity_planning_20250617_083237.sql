-- =====================================================================================
-- Phase 5: Capacity Planning & Growth Management Infrastructure
-- One Vault Multi-Tenant Data Vault 2.0 Platform
-- =====================================================================================

-- Create capacity planning schema
CREATE SCHEMA IF NOT EXISTS capacity_planning;

-- =====================================================================================
-- HUB TABLES
-- =====================================================================================

-- Capacity forecast hub - tracks unique capacity forecasting events
CREATE TABLE capacity_planning.capacity_forecast_h (
    capacity_forecast_hk BYTEA PRIMARY KEY,
    capacity_forecast_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide forecasts
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Resource utilization hub - tracks unique resource monitoring events
CREATE TABLE capacity_planning.resource_utilization_h (
    resource_utilization_hk BYTEA PRIMARY KEY,
    resource_utilization_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide resources
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Growth pattern hub - tracks unique growth analysis patterns
CREATE TABLE capacity_planning.growth_pattern_h (
    growth_pattern_hk BYTEA PRIMARY KEY,
    growth_pattern_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide patterns
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Capacity threshold hub - tracks capacity threshold definitions
CREATE TABLE capacity_planning.capacity_threshold_h (
    capacity_threshold_hk BYTEA PRIMARY KEY,
    capacity_threshold_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide thresholds
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- =====================================================================================
-- SATELLITE TABLES
-- =====================================================================================

-- Capacity forecast satellite - stores detailed forecasting information
CREATE TABLE capacity_planning.capacity_forecast_s (
    capacity_forecast_hk BYTEA NOT NULL REFERENCES capacity_planning.capacity_forecast_h(capacity_forecast_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    forecast_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    resource_type VARCHAR(50) NOT NULL,         -- STORAGE, MEMORY, CPU, CONNECTIONS, USERS, TRANSACTIONS
    resource_category VARCHAR(50) NOT NULL,     -- DATABASE, APPLICATION, SYSTEM, NETWORK
    current_usage DECIMAL(15,4) NOT NULL,
    current_capacity DECIMAL(15,4) NOT NULL,
    utilization_percentage DECIMAL(5,2) NOT NULL,
    projected_usage_7d DECIMAL(15,4),
    projected_usage_30d DECIMAL(15,4),
    projected_usage_90d DECIMAL(15,4),
    projected_usage_1y DECIMAL(15,4),
    growth_rate_daily DECIMAL(8,4),             -- Daily growth rate percentage
    growth_rate_weekly DECIMAL(8,4),            -- Weekly growth rate percentage
    growth_rate_monthly DECIMAL(8,4),           -- Monthly growth rate percentage
    time_to_capacity_days INTEGER,              -- Days until capacity reached
    time_to_warning_days INTEGER,               -- Days until warning threshold
    time_to_critical_days INTEGER,              -- Days until critical threshold
    recommended_action VARCHAR(500),
    action_priority VARCHAR(20) DEFAULT 'MEDIUM', -- LOW, MEDIUM, HIGH, CRITICAL, URGENT
    confidence_level DECIMAL(5,2),              -- 0-100% confidence in forecast
    forecast_model VARCHAR(50),                 -- LINEAR, EXPONENTIAL, SEASONAL, POLYNOMIAL, ARIMA
    model_accuracy DECIMAL(5,2),                -- Historical accuracy of this model
    seasonal_factor DECIMAL(8,4),               -- Seasonal adjustment factor
    trend_direction VARCHAR(20),                -- INCREASING, DECREASING, STABLE, VOLATILE
    volatility_score DECIMAL(5,2),              -- 0-100 volatility measure
    data_points_used INTEGER,                   -- Number of historical data points
    forecast_horizon_days INTEGER,              -- How far ahead this forecast projects
    last_model_training TIMESTAMP WITH TIME ZONE,
    model_parameters JSONB,                     -- Model-specific parameters
    external_factors JSONB,                     -- External factors affecting growth
    business_impact_assessment TEXT,
    cost_projection DECIMAL(15,2),              -- Projected cost impact
    risk_assessment VARCHAR(20) DEFAULT 'MEDIUM', -- LOW, MEDIUM, HIGH, CRITICAL
    mitigation_strategies TEXT[],
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (capacity_forecast_hk, load_date)
);

-- Resource utilization satellite - stores detailed resource usage data
CREATE TABLE capacity_planning.resource_utilization_s (
    resource_utilization_hk BYTEA NOT NULL REFERENCES capacity_planning.resource_utilization_h(resource_utilization_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    measurement_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_name VARCHAR(200) NOT NULL,
    resource_category VARCHAR(50) NOT NULL,
    current_value DECIMAL(15,4) NOT NULL,
    maximum_capacity DECIMAL(15,4) NOT NULL,
    utilization_percentage DECIMAL(5,2) NOT NULL,
    peak_value_24h DECIMAL(15,4),
    average_value_24h DECIMAL(15,4),
    minimum_value_24h DECIMAL(15,4),
    peak_value_7d DECIMAL(15,4),
    average_value_7d DECIMAL(15,4),
    peak_value_30d DECIMAL(15,4),
    average_value_30d DECIMAL(15,4),
    threshold_warning DECIMAL(15,4),
    threshold_critical DECIMAL(15,4),
    threshold_maximum DECIMAL(15,4),
    status VARCHAR(20) DEFAULT 'NORMAL',         -- NORMAL, WARNING, CRITICAL, EXCEEDED
    alert_triggered BOOLEAN DEFAULT false,
    last_alert_time TIMESTAMP WITH TIME ZONE,
    measurement_source VARCHAR(100),             -- POSTGRES, SYSTEM, APPLICATION, CUSTOM
    measurement_method VARCHAR(100),             -- QUERY, SYSTEM_CALL, AGENT, API
    measurement_accuracy DECIMAL(5,2),           -- Confidence in measurement accuracy
    measurement_latency_ms INTEGER,              -- How old is this measurement
    related_metrics JSONB,                       -- Related performance metrics
    performance_impact_score DECIMAL(5,2),       -- 0-100 impact on performance
    business_criticality VARCHAR(20) DEFAULT 'MEDIUM', -- LOW, MEDIUM, HIGH, CRITICAL
    auto_scaling_enabled BOOLEAN DEFAULT false,
    auto_scaling_triggered BOOLEAN DEFAULT false,
    auto_scaling_action VARCHAR(200),
    maintenance_window_exempt BOOLEAN DEFAULT false,
    monitoring_frequency_seconds INTEGER DEFAULT 300, -- How often to measure
    retention_period_days INTEGER DEFAULT 90,
    data_quality_score DECIMAL(5,2),            -- Quality of the measurement data
    anomaly_detected BOOLEAN DEFAULT false,
    anomaly_score DECIMAL(5,2),                 -- 0-100 anomaly likelihood
    seasonal_pattern_detected BOOLEAN DEFAULT false,
    trend_analysis JSONB,                       -- Trend analysis results
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (resource_utilization_hk, load_date)
);

-- Growth pattern satellite - stores growth analysis and patterns
CREATE TABLE capacity_planning.growth_pattern_s (
    growth_pattern_hk BYTEA NOT NULL REFERENCES capacity_planning.growth_pattern_h(growth_pattern_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    analysis_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    pattern_type VARCHAR(50) NOT NULL,          -- LINEAR, EXPONENTIAL, SEASONAL, CYCLICAL, IRREGULAR
    resource_type VARCHAR(50) NOT NULL,
    analysis_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    analysis_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    data_points_analyzed INTEGER NOT NULL,
    growth_rate_percentage DECIMAL(8,4),
    growth_acceleration DECIMAL(8,4),           -- Rate of change in growth rate
    seasonality_detected BOOLEAN DEFAULT false,
    seasonal_period_days INTEGER,               -- Length of seasonal cycle
    seasonal_amplitude DECIMAL(8,4),            -- Strength of seasonal variation
    trend_strength DECIMAL(5,2),                -- 0-100 strength of trend
    pattern_stability DECIMAL(5,2),             -- 0-100 stability of pattern
    pattern_confidence DECIMAL(5,2),            -- 0-100 confidence in pattern
    outliers_detected INTEGER DEFAULT 0,
    outlier_impact_score DECIMAL(5,2),          -- Impact of outliers on pattern
    correlation_factors JSONB,                  -- Factors correlated with growth
    external_events_impact JSONB,               -- External events affecting pattern
    pattern_breaks_detected INTEGER DEFAULT 0,   -- Structural breaks in pattern
    last_pattern_break_date DATE,
    forecast_accuracy_7d DECIMAL(5,2),          -- Historical 7-day forecast accuracy
    forecast_accuracy_30d DECIMAL(5,2),         -- Historical 30-day forecast accuracy
    forecast_accuracy_90d DECIMAL(5,2),         -- Historical 90-day forecast accuracy
    model_selection_criteria JSONB,             -- Criteria used for model selection
    cross_validation_score DECIMAL(5,2),        -- Cross-validation performance
    residual_analysis JSONB,                    -- Analysis of model residuals
    pattern_description TEXT,
    business_drivers TEXT[],                     -- Business factors driving growth
    risk_factors TEXT[],                         -- Risk factors for pattern change
    pattern_sustainability_assessment TEXT,
    recommended_monitoring_frequency VARCHAR(50), -- HOURLY, DAILY, WEEKLY
    next_analysis_due_date DATE,
    pattern_revision_history JSONB,             -- History of pattern changes
    statistical_significance DECIMAL(5,2),       -- Statistical significance of pattern
    confidence_intervals JSONB,                 -- Confidence intervals for projections
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (growth_pattern_hk, load_date)
);

-- Capacity threshold satellite - stores threshold definitions and configurations
CREATE TABLE capacity_planning.capacity_threshold_s (
    capacity_threshold_hk BYTEA NOT NULL REFERENCES capacity_planning.capacity_threshold_h(capacity_threshold_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    threshold_name VARCHAR(200) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_category VARCHAR(50) NOT NULL,
    threshold_type VARCHAR(50) NOT NULL,        -- WARNING, CRITICAL, MAXIMUM, OPTIMAL
    threshold_value DECIMAL(15,4) NOT NULL,
    threshold_percentage DECIMAL(5,2),          -- Percentage of capacity
    threshold_operator VARCHAR(10) NOT NULL,    -- GT, GTE, LT, LTE, EQ, NEQ
    evaluation_frequency_minutes INTEGER DEFAULT 5,
    alert_enabled BOOLEAN DEFAULT true,
    alert_severity VARCHAR(20) DEFAULT 'MEDIUM',
    alert_message_template TEXT,
    notification_channels TEXT[],               -- EMAIL, SLACK, SMS, WEBHOOK, PAGERDUTY
    escalation_enabled BOOLEAN DEFAULT false,
    escalation_delay_minutes INTEGER DEFAULT 30,
    escalation_contacts TEXT[],
    auto_resolution_enabled BOOLEAN DEFAULT false,
    auto_resolution_action VARCHAR(500),
    suppression_enabled BOOLEAN DEFAULT false,
    suppression_duration_minutes INTEGER DEFAULT 60,
    business_hours_only BOOLEAN DEFAULT false,
    maintenance_window_exempt BOOLEAN DEFAULT true,
    threshold_effectiveness_score DECIMAL(5,2), -- How effective this threshold is
    false_positive_rate DECIMAL(5,2),           -- Rate of false positive alerts
    true_positive_rate DECIMAL(5,2),            -- Rate of true positive alerts
    last_triggered_date TIMESTAMP WITH TIME ZONE,
    trigger_count_24h INTEGER DEFAULT 0,
    trigger_count_7d INTEGER DEFAULT 0,
    trigger_count_30d INTEGER DEFAULT 0,
    average_resolution_time_minutes INTEGER,
    threshold_tuning_history JSONB,             -- History of threshold adjustments
    related_thresholds TEXT[],                   -- Related threshold names
    dependency_thresholds TEXT[],                -- Thresholds this depends on
    business_justification TEXT,
    compliance_requirement VARCHAR(100),         -- Compliance requirement this supports
    cost_impact_per_trigger DECIMAL(10,2),      -- Cost impact of each trigger
    performance_impact_assessment TEXT,
    threshold_documentation TEXT,
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    approved_by VARCHAR(100),
    approval_date TIMESTAMP WITH TIME ZONE,
    review_frequency_days INTEGER DEFAULT 90,
    next_review_date DATE,
    is_active BOOLEAN DEFAULT true,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (capacity_threshold_hk, load_date)
);

-- =====================================================================================
-- LINK TABLES
-- =====================================================================================

-- Link between capacity forecasts and resource utilization
CREATE TABLE capacity_planning.forecast_utilization_l (
    link_forecast_utilization_hk BYTEA PRIMARY KEY,
    capacity_forecast_hk BYTEA NOT NULL REFERENCES capacity_planning.capacity_forecast_h(capacity_forecast_hk),
    resource_utilization_hk BYTEA NOT NULL REFERENCES capacity_planning.resource_utilization_h(resource_utilization_hk),
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Link between growth patterns and capacity forecasts
CREATE TABLE capacity_planning.pattern_forecast_l (
    link_pattern_forecast_hk BYTEA PRIMARY KEY,
    growth_pattern_hk BYTEA NOT NULL REFERENCES capacity_planning.growth_pattern_h(growth_pattern_hk),
    capacity_forecast_hk BYTEA NOT NULL REFERENCES capacity_planning.capacity_forecast_h(capacity_forecast_hk),
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- =====================================================================================
-- PERFORMANCE INDEXES
-- =====================================================================================

-- Capacity forecast indexes
CREATE INDEX idx_capacity_forecast_h_tenant_hk ON capacity_planning.capacity_forecast_h(tenant_hk);
CREATE INDEX idx_capacity_forecast_h_load_date ON capacity_planning.capacity_forecast_h(load_date);
CREATE INDEX idx_capacity_forecast_s_resource_type ON capacity_planning.capacity_forecast_s(resource_type, resource_category);
CREATE INDEX idx_capacity_forecast_s_forecast_timestamp ON capacity_planning.capacity_forecast_s(forecast_timestamp);
CREATE INDEX idx_capacity_forecast_s_utilization_pct ON capacity_planning.capacity_forecast_s(utilization_percentage);
CREATE INDEX idx_capacity_forecast_s_time_to_capacity ON capacity_planning.capacity_forecast_s(time_to_capacity_days) WHERE time_to_capacity_days IS NOT NULL;
CREATE INDEX idx_capacity_forecast_s_action_priority ON capacity_planning.capacity_forecast_s(action_priority, time_to_capacity_days);
CREATE INDEX idx_capacity_forecast_s_active ON capacity_planning.capacity_forecast_s(capacity_forecast_hk, load_date) WHERE load_end_date IS NULL;

-- Resource utilization indexes
CREATE INDEX idx_resource_utilization_h_tenant_hk ON capacity_planning.resource_utilization_h(tenant_hk);
CREATE INDEX idx_resource_utilization_h_load_date ON capacity_planning.resource_utilization_h(load_date);
CREATE INDEX idx_resource_utilization_s_resource_type ON capacity_planning.resource_utilization_s(resource_type, resource_name);
CREATE INDEX idx_resource_utilization_s_measurement_timestamp ON capacity_planning.resource_utilization_s(measurement_timestamp);
CREATE INDEX idx_resource_utilization_s_utilization_pct ON capacity_planning.resource_utilization_s(utilization_percentage);
CREATE INDEX idx_resource_utilization_s_status ON capacity_planning.resource_utilization_s(status) WHERE status != 'NORMAL';
CREATE INDEX idx_resource_utilization_s_alert_triggered ON capacity_planning.resource_utilization_s(alert_triggered, last_alert_time) WHERE alert_triggered = true;
CREATE INDEX idx_resource_utilization_s_active ON capacity_planning.resource_utilization_s(resource_utilization_hk, load_date) WHERE load_end_date IS NULL;

-- Growth pattern indexes
CREATE INDEX idx_growth_pattern_h_tenant_hk ON capacity_planning.growth_pattern_h(tenant_hk);
CREATE INDEX idx_growth_pattern_h_load_date ON capacity_planning.growth_pattern_h(load_date);
CREATE INDEX idx_growth_pattern_s_pattern_type ON capacity_planning.growth_pattern_s(pattern_type, resource_type);
CREATE INDEX idx_growth_pattern_s_analysis_timestamp ON capacity_planning.growth_pattern_s(analysis_timestamp);
CREATE INDEX idx_growth_pattern_s_growth_rate ON capacity_planning.growth_pattern_s(growth_rate_percentage);
CREATE INDEX idx_growth_pattern_s_confidence ON capacity_planning.growth_pattern_s(pattern_confidence);
CREATE INDEX idx_growth_pattern_s_active ON capacity_planning.growth_pattern_s(growth_pattern_hk, load_date) WHERE load_end_date IS NULL;

-- Capacity threshold indexes
CREATE INDEX idx_capacity_threshold_h_tenant_hk ON capacity_planning.capacity_threshold_h(tenant_hk);
CREATE INDEX idx_capacity_threshold_h_load_date ON capacity_planning.capacity_threshold_h(load_date);
CREATE INDEX idx_capacity_threshold_s_resource_type ON capacity_planning.capacity_threshold_s(resource_type, threshold_type);
CREATE INDEX idx_capacity_threshold_s_alert_enabled ON capacity_planning.capacity_threshold_s(alert_enabled, is_active) WHERE alert_enabled = true AND is_active = true;
CREATE INDEX idx_capacity_threshold_s_last_triggered ON capacity_planning.capacity_threshold_s(last_triggered_date);
CREATE INDEX idx_capacity_threshold_s_active ON capacity_planning.capacity_threshold_s(capacity_threshold_hk, load_date) WHERE load_end_date IS NULL;

-- Link table indexes
CREATE INDEX idx_forecast_utilization_l_forecast_hk ON capacity_planning.forecast_utilization_l(capacity_forecast_hk);
CREATE INDEX idx_forecast_utilization_l_utilization_hk ON capacity_planning.forecast_utilization_l(resource_utilization_hk);
CREATE INDEX idx_forecast_utilization_l_tenant_hk ON capacity_planning.forecast_utilization_l(tenant_hk);

CREATE INDEX idx_pattern_forecast_l_pattern_hk ON capacity_planning.pattern_forecast_l(growth_pattern_hk);
CREATE INDEX idx_pattern_forecast_l_forecast_hk ON capacity_planning.pattern_forecast_l(capacity_forecast_hk);
CREATE INDEX idx_pattern_forecast_l_tenant_hk ON capacity_planning.pattern_forecast_l(tenant_hk);

-- =====================================================================================
-- CORE CAPACITY PLANNING FUNCTIONS
-- =====================================================================================

-- Function to capture current resource utilization
CREATE OR REPLACE FUNCTION capacity_planning.capture_resource_utilization(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    resource_type VARCHAR(50),
    current_usage DECIMAL(15,4),
    capacity DECIMAL(15,4),
    utilization_percentage DECIMAL(5,2),
    status VARCHAR(20)
) AS $$
DECLARE
    v_utilization_record RECORD;
    v_resource_hk BYTEA;
    v_resource_bk VARCHAR(255);
    v_database_size BIGINT;
    v_connection_count INTEGER;
    v_max_connections INTEGER;
    v_memory_usage BIGINT;
    v_cpu_usage DECIMAL(5,2);
    v_disk_usage DECIMAL(5,2);
    v_user_count INTEGER;
    v_transaction_rate DECIMAL(10,2);
BEGIN
    -- Capture database size
    SELECT pg_database_size(current_database()) INTO v_database_size;
    
    -- Capture connection statistics
    SELECT 
        COUNT(*),
        current_setting('max_connections')::INTEGER
    INTO v_connection_count, v_max_connections
    FROM pg_stat_activity 
    WHERE state = 'active';
    
    -- Capture user count for tenant
    SELECT COUNT(DISTINCT uh.user_hk) INTO v_user_count
    FROM auth.user_h uh
    WHERE (p_tenant_hk IS NULL OR uh.tenant_hk = p_tenant_hk);
    
    -- Simulate system metrics (would be replaced with real system monitoring)
    v_memory_usage := 8589934592; -- 8GB in bytes
    v_cpu_usage := 25.5; -- 25.5% CPU usage
    v_disk_usage := 45.2; -- 45.2% disk usage
    v_transaction_rate := 150.75; -- 150.75 transactions per second
    
    -- Process each resource type
    FOR v_utilization_record IN 
        SELECT * FROM (VALUES 
            ('STORAGE', 'DATABASE', v_database_size::DECIMAL, 107374182400::DECIMAL, 'bytes'), -- 100GB capacity
            ('CONNECTIONS', 'DATABASE', v_connection_count::DECIMAL, v_max_connections::DECIMAL, 'count'),
            ('MEMORY', 'SYSTEM', v_memory_usage::DECIMAL * 0.75, v_memory_usage::DECIMAL, 'bytes'), -- 75% memory usage
            ('CPU', 'SYSTEM', v_cpu_usage, 100.0, 'percentage'),
            ('DISK', 'SYSTEM', v_disk_usage, 100.0, 'percentage'),
            ('USERS', 'APPLICATION', v_user_count::DECIMAL, 10000::DECIMAL, 'count'), -- 10K user capacity
            ('TRANSACTIONS', 'APPLICATION', v_transaction_rate, 1000.0, 'per_second') -- 1K TPS capacity
        ) AS t(resource_type, category, current_val, max_val, unit)
    LOOP
        -- Generate business key and hash key
        v_resource_bk := v_utilization_record.resource_type || '_' || 
                        COALESCE(encode(p_tenant_hk, 'hex'), 'SYSTEM') || '_' ||
                        to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
        v_resource_hk := util.hash_binary(v_resource_bk);
        
        -- Insert hub record
        INSERT INTO capacity_planning.resource_utilization_h VALUES (
            v_resource_hk, v_resource_bk, p_tenant_hk,
            util.current_load_date(), 'CAPACITY_MONITOR'
        ) ON CONFLICT (resource_utilization_bk) DO NOTHING;
        
        -- Insert satellite record
        INSERT INTO capacity_planning.resource_utilization_s VALUES (
            v_resource_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_resource_bk || v_utilization_record.current_val::text),
            CURRENT_TIMESTAMP,
            v_utilization_record.resource_type,
            v_utilization_record.resource_type || '_RESOURCE',
            v_utilization_record.category,
            v_utilization_record.current_val,
            v_utilization_record.max_val,
            ROUND((v_utilization_record.current_val / v_utilization_record.max_val * 100), 2),
            v_utilization_record.current_val * 1.1, -- Simulated peak 24h
            v_utilization_record.current_val * 0.9, -- Simulated average 24h
            v_utilization_record.current_val * 0.8, -- Simulated minimum 24h
            v_utilization_record.current_val * 1.2, -- Simulated peak 7d
            v_utilization_record.current_val * 0.95, -- Simulated average 7d
            v_utilization_record.current_val * 1.3, -- Simulated peak 30d
            v_utilization_record.current_val * 1.0, -- Simulated average 30d
            v_utilization_record.max_val * 0.8, -- Warning at 80%
            v_utilization_record.max_val * 0.9, -- Critical at 90%
            v_utilization_record.max_val, -- Maximum
            CASE 
                WHEN (v_utilization_record.current_val / v_utilization_record.max_val) >= 0.9 THEN 'CRITICAL'
                WHEN (v_utilization_record.current_val / v_utilization_record.max_val) >= 0.8 THEN 'WARNING'
                ELSE 'NORMAL'
            END,
            false, -- alert_triggered
            NULL, -- last_alert_time
            'POSTGRES', -- measurement_source
            'SYSTEM_QUERY', -- measurement_method
            95.0, -- measurement_accuracy
            0, -- measurement_latency_ms
            jsonb_build_object('unit', v_utilization_record.unit, 'category', v_utilization_record.category),
            LEAST(100.0, (v_utilization_record.current_val / v_utilization_record.max_val) * 100), -- performance_impact_score
            CASE v_utilization_record.resource_type
                WHEN 'STORAGE' THEN 'HIGH'
                WHEN 'CONNECTIONS' THEN 'CRITICAL'
                WHEN 'MEMORY' THEN 'HIGH'
                ELSE 'MEDIUM'
            END, -- business_criticality
            false, -- auto_scaling_enabled
            false, -- auto_scaling_triggered
            NULL, -- auto_scaling_action
            false, -- maintenance_window_exempt
            300, -- monitoring_frequency_seconds
            90, -- retention_period_days
            98.5, -- data_quality_score
            false, -- anomaly_detected
            0.0, -- anomaly_score
            false, -- seasonal_pattern_detected
            jsonb_build_object('trend', 'STABLE', 'confidence', 85.0),
            'CAPACITY_MONITOR'
        ) ON CONFLICT (resource_utilization_hk, load_date) DO NOTHING;
        
        -- Return utilization data
        RETURN QUERY SELECT 
            v_utilization_record.resource_type,
            v_utilization_record.current_val,
            v_utilization_record.max_val,
            ROUND((v_utilization_record.current_val / v_utilization_record.max_val * 100), 2),
            CASE 
                WHEN (v_utilization_record.current_val / v_utilization_record.max_val) >= 0.9 THEN 'CRITICAL'
                WHEN (v_utilization_record.current_val / v_utilization_record.max_val) >= 0.8 THEN 'WARNING'
                ELSE 'NORMAL'
            END;
    END LOOP;
END;
$$ LANGUAGE plpgsql; 