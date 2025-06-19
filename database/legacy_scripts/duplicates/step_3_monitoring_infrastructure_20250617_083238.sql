-- =====================================================================================
-- Script: step_3_monitoring_infrastructure.sql
-- Description: Monitoring & Alerting Infrastructure Implementation - Phase 2 Part 1
-- Version: 1.0
-- Date: 2024-12-19
-- Author: One Vault Development Team
-- 
-- Purpose: Implement comprehensive monitoring infrastructure with real-time metrics
--          collection, performance monitoring, and system health tracking for 
--          production readiness and operational excellence
-- =====================================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- =====================================================================================
-- MONITORING SCHEMA CREATION
-- =====================================================================================

-- Create monitoring schema for system metrics and health tracking
CREATE SCHEMA IF NOT EXISTS monitoring;

-- Grant permissions to monitoring schema
GRANT USAGE ON SCHEMA monitoring TO postgres;

-- =====================================================================================
-- SYSTEM HEALTH MONITORING TABLES (Data Vault 2.0 Pattern)
-- =====================================================================================

-- System Health Metrics Hub
CREATE TABLE monitoring.system_health_metric_h (
    health_metric_hk BYTEA PRIMARY KEY,
    health_metric_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide metrics
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'MONITORING_SYSTEM'
);

-- System Health Metrics Satellite
CREATE TABLE monitoring.system_health_metric_s (
    health_metric_hk BYTEA NOT NULL REFERENCES monitoring.system_health_metric_h(health_metric_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_category VARCHAR(50) NOT NULL,   -- PERFORMANCE, AVAILABILITY, SECURITY, COMPLIANCE, CAPACITY
    metric_value DECIMAL(15,4),
    metric_unit VARCHAR(20),                -- ms, %, GB, count, connections, etc.
    threshold_warning DECIMAL(15,4),
    threshold_critical DECIMAL(15,4),
    measurement_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    measurement_interval_seconds INTEGER DEFAULT 300, -- 5 minute default
    status VARCHAR(20) DEFAULT 'NORMAL',    -- NORMAL, WARNING, CRITICAL, UNKNOWN
    additional_context JSONB,
    data_source VARCHAR(100),               -- pg_stat_activity, custom_query, etc.
    collection_method VARCHAR(50),          -- AUTOMATIC, MANUAL, SCHEDULED
    record_source VARCHAR(100) NOT NULL DEFAULT 'MONITORING_SYSTEM',
    PRIMARY KEY (health_metric_hk, load_date)
);

-- Performance Metrics Hub
CREATE TABLE monitoring.performance_metric_h (
    performance_metric_hk BYTEA PRIMARY KEY,
    performance_metric_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'PERFORMANCE_MONITOR'
);

-- Performance Metrics Satellite
CREATE TABLE monitoring.performance_metric_s (
    performance_metric_hk BYTEA NOT NULL REFERENCES monitoring.performance_metric_h(performance_metric_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    query_hash VARCHAR(64),                 -- pg_stat_statements.queryid
    database_name VARCHAR(100),
    username VARCHAR(100),
    query_text TEXT,
    total_time_ms DECIMAL(15,4),
    mean_time_ms DECIMAL(15,4),
    calls INTEGER,
    rows_examined INTEGER,
    rows_returned INTEGER,
    shared_blks_hit INTEGER,
    shared_blks_read INTEGER,
    shared_blks_dirtied INTEGER,
    temp_blks_read INTEGER,
    temp_blks_written INTEGER,
    measurement_period_start TIMESTAMP WITH TIME ZONE,
    measurement_period_end TIMESTAMP WITH TIME ZONE,
    performance_rating VARCHAR(20),         -- EXCELLENT, GOOD, POOR, CRITICAL
    optimization_suggestions TEXT[],
    record_source VARCHAR(100) NOT NULL DEFAULT 'PERFORMANCE_MONITOR',
    PRIMARY KEY (performance_metric_hk, load_date)
);

-- Database Capacity Tracking Hub
CREATE TABLE monitoring.capacity_metric_h (
    capacity_metric_hk BYTEA PRIMARY KEY,
    capacity_metric_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'CAPACITY_MONITOR'
);

-- Database Capacity Tracking Satellite
CREATE TABLE monitoring.capacity_metric_s (
    capacity_metric_hk BYTEA NOT NULL REFERENCES monitoring.capacity_metric_h(capacity_metric_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    resource_type VARCHAR(50) NOT NULL,     -- DATABASE_SIZE, TABLE_SIZE, INDEX_SIZE, WAL_SIZE, CONNECTIONS
    resource_name VARCHAR(200),             -- Database/table/index name
    current_size_bytes BIGINT,
    available_space_bytes BIGINT,
    utilization_percentage DECIMAL(5,2),
    growth_rate_per_day DECIMAL(15,4),      -- Bytes per day
    projected_full_date DATE,               -- When resource will be exhausted
    capacity_warning_threshold DECIMAL(5,2) DEFAULT 80.0,
    capacity_critical_threshold DECIMAL(5,2) DEFAULT 95.0,
    measurement_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    trend_direction VARCHAR(20),            -- INCREASING, DECREASING, STABLE
    record_source VARCHAR(100) NOT NULL DEFAULT 'CAPACITY_MONITOR',
    PRIMARY KEY (capacity_metric_hk, load_date)
);

-- =====================================================================================
-- SECURITY MONITORING TABLES
-- =====================================================================================

-- Security Event Hub
CREATE TABLE monitoring.security_event_h (
    security_event_hk BYTEA PRIMARY KEY,
    security_event_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'SECURITY_MONITOR'
);

-- Security Event Satellite
CREATE TABLE monitoring.security_event_s (
    security_event_hk BYTEA NOT NULL REFERENCES monitoring.security_event_h(security_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    event_type VARCHAR(100) NOT NULL,       -- LOGIN_FAILURE, UNAUTHORIZED_ACCESS, SUSPICIOUS_QUERY, DATA_BREACH_ATTEMPT
    event_severity VARCHAR(20) NOT NULL,    -- LOW, MEDIUM, HIGH, CRITICAL
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    source_ip INET,
    user_agent TEXT,
    username VARCHAR(100),
    database_name VARCHAR(100),
    affected_tables TEXT[],
    event_details JSONB,
    detection_method VARCHAR(100),          -- RULE_BASED, ANOMALY_DETECTION, MANUAL
    false_positive_likelihood DECIMAL(5,2), -- 0-100%
    investigation_status VARCHAR(50) DEFAULT 'OPEN', -- OPEN, INVESTIGATING, RESOLVED, FALSE_POSITIVE
    incident_response_triggered BOOLEAN DEFAULT false,
    mitigation_actions TEXT[],
    investigation_notes TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT 'SECURITY_MONITOR',
    PRIMARY KEY (security_event_hk, load_date)
);

-- =====================================================================================
-- COMPLIANCE MONITORING TABLES
-- =====================================================================================

-- Compliance Check Hub
CREATE TABLE monitoring.compliance_check_h (
    compliance_check_hk BYTEA PRIMARY KEY,
    compliance_check_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'COMPLIANCE_MONITOR'
);

-- Compliance Check Satellite
CREATE TABLE monitoring.compliance_check_s (
    compliance_check_hk BYTEA NOT NULL REFERENCES monitoring.compliance_check_h(compliance_check_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    compliance_framework VARCHAR(50) NOT NULL, -- HIPAA, GDPR, SOX, PCI_DSS, SOC2
    check_name VARCHAR(200) NOT NULL,
    check_description TEXT,
    check_category VARCHAR(100),            -- ACCESS_CONTROL, DATA_ENCRYPTION, AUDIT_LOGGING, etc.
    check_frequency VARCHAR(50),            -- CONTINUOUS, DAILY, WEEKLY, MONTHLY, QUARTERLY
    last_check_timestamp TIMESTAMP WITH TIME ZONE,
    check_status VARCHAR(20),               -- COMPLIANT, NON_COMPLIANT, PARTIALLY_COMPLIANT, NOT_TESTED
    compliance_score DECIMAL(5,2),          -- 0-100%
    finding_details JSONB,
    remediation_required BOOLEAN DEFAULT false,
    remediation_priority VARCHAR(20),       -- LOW, MEDIUM, HIGH, CRITICAL
    remediation_deadline DATE,
    responsible_party VARCHAR(100),
    evidence_location TEXT,
    audit_trail_reference TEXT,
    record_source VARCHAR(100) NOT NULL DEFAULT 'COMPLIANCE_MONITOR',
    PRIMARY KEY (compliance_check_hk, load_date)
);

-- =====================================================================================
-- MONITORING CONFIGURATION TABLES
-- =====================================================================================

-- Monitoring Configuration Hub
CREATE TABLE monitoring.monitor_config_h (
    monitor_config_hk BYTEA PRIMARY KEY,
    monitor_config_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'CONFIG_MANAGER'
);

-- Monitoring Configuration Satellite
CREATE TABLE monitoring.monitor_config_s (
    monitor_config_hk BYTEA NOT NULL REFERENCES monitoring.monitor_config_h(monitor_config_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    config_name VARCHAR(200) NOT NULL,
    config_type VARCHAR(50) NOT NULL,       -- METRIC_COLLECTION, ALERT_THRESHOLD, NOTIFICATION, RETENTION
    config_category VARCHAR(100),           -- PERFORMANCE, SECURITY, COMPLIANCE, CAPACITY
    config_value JSONB NOT NULL,
    config_description TEXT,
    is_enabled BOOLEAN DEFAULT true,
    priority_level INTEGER DEFAULT 5,       -- 1-10, 10 being highest priority
    update_frequency_seconds INTEGER,
    last_updated_by VARCHAR(100) DEFAULT SESSION_USER,
    validation_rules JSONB,
    environment_scope VARCHAR(50) DEFAULT 'ALL', -- DEV, STAGING, PROD, ALL
    record_source VARCHAR(100) NOT NULL DEFAULT 'CONFIG_MANAGER',
    PRIMARY KEY (monitor_config_hk, load_date)
);

-- =====================================================================================
-- PERFORMANCE INDEXES FOR MONITORING TABLES
-- =====================================================================================

-- System Health Metrics Indexes
CREATE INDEX idx_system_health_metric_s_timestamp ON monitoring.system_health_metric_s(measurement_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_system_health_metric_s_category_status ON monitoring.system_health_metric_s(metric_category, status) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_system_health_metric_s_tenant_metric ON monitoring.system_health_metric_h(tenant_hk, health_metric_bk);

-- Performance Metrics Indexes
CREATE INDEX idx_performance_metric_s_period ON monitoring.performance_metric_s(measurement_period_start DESC, measurement_period_end DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_performance_metric_s_query_hash ON monitoring.performance_metric_s(query_hash) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_performance_metric_s_total_time ON monitoring.performance_metric_s(total_time_ms DESC) 
WHERE load_end_date IS NULL;

-- Capacity Metrics Indexes
CREATE INDEX idx_capacity_metric_s_timestamp ON monitoring.capacity_metric_s(measurement_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_capacity_metric_s_resource_type ON monitoring.capacity_metric_s(resource_type, utilization_percentage DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_capacity_metric_s_projected_full ON monitoring.capacity_metric_s(projected_full_date ASC) 
WHERE load_end_date IS NULL AND projected_full_date IS NOT NULL;

-- Security Event Indexes
CREATE INDEX idx_security_event_s_timestamp ON monitoring.security_event_s(event_timestamp DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_security_event_s_severity_type ON monitoring.security_event_s(event_severity, event_type) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_security_event_s_investigation ON monitoring.security_event_s(investigation_status, event_severity) 
WHERE load_end_date IS NULL;

-- Compliance Check Indexes
CREATE INDEX idx_compliance_check_s_framework ON monitoring.compliance_check_s(compliance_framework, check_status) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_compliance_check_s_remediation ON monitoring.compliance_check_s(remediation_required, remediation_priority) 
WHERE load_end_date IS NULL AND remediation_required = true;

-- =====================================================================================
-- MONITORING DATA COLLECTION FUNCTIONS
-- =====================================================================================

-- Function to collect system health metrics
CREATE OR REPLACE FUNCTION monitoring.collect_system_health_metrics(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    metric_name VARCHAR(100),
    current_value DECIMAL(15,4),
    status VARCHAR(20),
    threshold_warning DECIMAL(15,4),
    threshold_critical DECIMAL(15,4)
) AS $$
DECLARE
    v_metric_record RECORD;
    v_health_hk BYTEA;
    v_metric_bk VARCHAR(255);
    v_db_size BIGINT;
    v_connection_count INTEGER;
    v_active_session_count INTEGER;
    v_avg_query_time DECIMAL(15,4);
    v_cache_hit_ratio DECIMAL(5,2);
    v_wal_size BIGINT;
    v_disk_usage DECIMAL(5,2);
BEGIN
    -- Collect basic database metrics
    SELECT pg_database_size(current_database()) INTO v_db_size;
    
    -- Active connections
    SELECT count(*) INTO v_connection_count 
    FROM pg_stat_activity 
    WHERE state = 'active' AND backend_type = 'client backend';
    
    -- Active sessions for tenant (if specified)
    IF p_tenant_hk IS NOT NULL THEN
        SELECT count(*) INTO v_active_session_count
        FROM auth.session_state_s sss
        JOIN auth.session_h sh ON sss.session_hk = sh.session_hk
        WHERE sss.session_status = 'ACTIVE' 
        AND sss.load_end_date IS NULL
        AND sh.tenant_hk = p_tenant_hk;
    ELSE
        SELECT count(*) INTO v_active_session_count
        FROM auth.session_state_s 
        WHERE session_status = 'ACTIVE' 
        AND load_end_date IS NULL;
    END IF;
    
    -- Average query execution time from pg_stat_statements
    SELECT COALESCE(AVG(mean_exec_time), 0) INTO v_avg_query_time
    FROM pg_stat_statements 
    WHERE calls > 10; -- Only consider queries with meaningful sample size
    
    -- Cache hit ratio
    SELECT ROUND(
        100.0 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2
    ) INTO v_cache_hit_ratio
    FROM pg_stat_database;
    
    -- WAL size (approximate)
    SELECT COALESCE(SUM(size), 0) INTO v_wal_size
    FROM pg_ls_waldir();
    
    -- Simulate disk usage (would need actual disk monitoring in production)
    v_disk_usage := 45.2; -- Placeholder - integrate with actual disk monitoring
    
    -- Process each metric and store/return results
    FOR v_metric_record IN 
        SELECT * FROM (VALUES 
            ('database_size_gb', v_db_size / 1024.0 / 1024.0 / 1024.0, 'CAPACITY', 50.0, 80.0),
            ('active_connections', v_connection_count::DECIMAL, 'PERFORMANCE', 150.0, 180.0),
            ('active_sessions', v_active_session_count::DECIMAL, 'AVAILABILITY', 1000.0, 5000.0),
            ('avg_query_time_ms', v_avg_query_time, 'PERFORMANCE', 200.0, 500.0),
            ('cache_hit_ratio_pct', v_cache_hit_ratio, 'PERFORMANCE', 95.0, 90.0),
            ('wal_size_gb', v_wal_size / 1024.0 / 1024.0 / 1024.0, 'PERFORMANCE', 2.0, 4.0),
            ('disk_usage_pct', v_disk_usage, 'CAPACITY', 80.0, 95.0)
        ) AS t(name, value, category, warn_threshold, crit_threshold)
    LOOP
        -- Generate unique business key
        v_metric_bk := v_metric_record.category || '_' || v_metric_record.name || '_' || 
                       COALESCE(encode(p_tenant_hk, 'hex'), 'SYSTEM');
        
        v_health_hk := util.hash_binary(v_metric_bk);
        
        -- Insert/update hub record
        INSERT INTO monitoring.system_health_metric_h VALUES (
            v_health_hk, v_metric_bk, p_tenant_hk,
            util.current_load_date(), 'SYSTEM_COLLECTOR'
        ) ON CONFLICT (health_metric_bk) DO NOTHING;
        
        -- Close any existing open satellite record
        UPDATE monitoring.system_health_metric_s 
        SET load_end_date = util.current_load_date()
        WHERE health_metric_hk = v_health_hk 
        AND load_end_date IS NULL
        AND hash_diff != util.hash_binary(v_metric_record.name || v_metric_record.value::text || v_metric_record.category);
        
        -- Insert new satellite record
        INSERT INTO monitoring.system_health_metric_s VALUES (
            v_health_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_metric_record.name || v_metric_record.value::text || v_metric_record.category),
            v_metric_record.name,
            v_metric_record.category,
            v_metric_record.value,
            CASE v_metric_record.name 
                WHEN 'database_size_gb' THEN 'GB'
                WHEN 'avg_query_time_ms' THEN 'ms'
                WHEN 'cache_hit_ratio_pct' THEN '%'
                WHEN 'disk_usage_pct' THEN '%'
                WHEN 'wal_size_gb' THEN 'GB'
                ELSE 'count'
            END,
            v_metric_record.warn_threshold,
            v_metric_record.crit_threshold,
            CURRENT_TIMESTAMP,
            300, -- 5 minute collection interval
            CASE 
                WHEN v_metric_record.name = 'cache_hit_ratio_pct' THEN
                    CASE WHEN v_metric_record.value <= v_metric_record.crit_threshold THEN 'CRITICAL'
                         WHEN v_metric_record.value <= v_metric_record.warn_threshold THEN 'WARNING'
                         ELSE 'NORMAL' END
                ELSE
                    CASE WHEN v_metric_record.value >= v_metric_record.crit_threshold THEN 'CRITICAL'
                         WHEN v_metric_record.value >= v_metric_record.warn_threshold THEN 'WARNING'
                         ELSE 'NORMAL' END
            END,
            jsonb_build_object(
                'tenant_scoped', p_tenant_hk IS NOT NULL,
                'collection_method', 'automated',
                'data_freshness_seconds', 0
            ),
            'pg_stat_database,pg_stat_activity',
            'AUTOMATIC',
            'SYSTEM_COLLECTOR'
        ) ON CONFLICT (health_metric_hk, load_date) DO NOTHING;
        
        -- Return the metric data
        RETURN QUERY SELECT 
            v_metric_record.name,
            v_metric_record.value,
            CASE 
                WHEN v_metric_record.name = 'cache_hit_ratio_pct' THEN
                    CASE WHEN v_metric_record.value <= v_metric_record.crit_threshold THEN 'CRITICAL'
                         WHEN v_metric_record.value <= v_metric_record.warn_threshold THEN 'WARNING'
                         ELSE 'NORMAL' END
                ELSE
                    CASE WHEN v_metric_record.value >= v_metric_record.crit_threshold THEN 'CRITICAL'
                         WHEN v_metric_record.value >= v_metric_record.warn_threshold THEN 'WARNING'
                         ELSE 'NORMAL' END
            END,
            v_metric_record.warn_threshold,
            v_metric_record.crit_threshold;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to collect performance metrics from pg_stat_statements
CREATE OR REPLACE FUNCTION monitoring.collect_performance_metrics(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_top_queries_limit INTEGER DEFAULT 20
) RETURNS TABLE (
    query_hash VARCHAR(64),
    total_time_ms DECIMAL(15,4),
    mean_time_ms DECIMAL(15,4),
    calls INTEGER,
    performance_rating VARCHAR(20)
) AS $$
DECLARE
    v_perf_record RECORD;
    v_performance_hk BYTEA;
    v_performance_bk VARCHAR(255);
BEGIN
    -- Collect top queries by total time
    FOR v_perf_record IN 
        SELECT 
            pss.queryid::text as query_hash,
            pss.query as query_text,
            pss.total_exec_time as total_time,
            pss.mean_exec_time as mean_time,
            pss.calls,
            pss.rows as rows_returned,
            pss.shared_blks_hit,
            pss.shared_blks_read,
            pss.shared_blks_dirtied,
            pss.temp_blks_read,
            pss.temp_blks_written
        FROM pg_stat_statements pss
        WHERE pss.calls > 5  -- Only consider queries with meaningful usage
        ORDER BY pss.total_exec_time DESC
        LIMIT p_top_queries_limit
    LOOP
        -- Generate business key for performance metric
        v_performance_bk := 'QUERY_PERF_' || v_perf_record.query_hash || '_' || 
                           to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24');
        
        v_performance_hk := util.hash_binary(v_performance_bk);
        
        -- Insert hub record
        INSERT INTO monitoring.performance_metric_h VALUES (
            v_performance_hk, v_performance_bk, p_tenant_hk,
            util.current_load_date(), 'PERFORMANCE_COLLECTOR'
        ) ON CONFLICT (performance_metric_bk) DO NOTHING;
        
        -- Insert satellite record
        INSERT INTO monitoring.performance_metric_s VALUES (
            v_performance_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_performance_bk || v_perf_record.total_time::text),
            v_perf_record.query_hash,
            current_database(),
            SESSION_USER,
            v_perf_record.query_text,
            v_perf_record.total_time,
            v_perf_record.mean_time,
            v_perf_record.calls,
            v_perf_record.rows_returned,
            v_perf_record.rows_returned, -- Placeholder for rows_examined
            v_perf_record.shared_blks_hit,
            v_perf_record.shared_blks_read,
            v_perf_record.shared_blks_dirtied,
            v_perf_record.temp_blks_read,
            v_perf_record.temp_blks_written,
            CURRENT_TIMESTAMP - INTERVAL '1 hour',
            CURRENT_TIMESTAMP,
            CASE 
                WHEN v_perf_record.mean_time > 1000 THEN 'CRITICAL'
                WHEN v_perf_record.mean_time > 500 THEN 'POOR'
                WHEN v_perf_record.mean_time > 100 THEN 'GOOD'
                ELSE 'EXCELLENT'
            END,
            CASE 
                WHEN v_perf_record.mean_time > 500 THEN 
                    ARRAY['Consider query optimization', 'Check for missing indexes', 'Review execution plan']
                ELSE ARRAY[]::TEXT[]
            END,
            'PERFORMANCE_COLLECTOR'
        ) ON CONFLICT (performance_metric_hk, load_date) DO NOTHING;
        
        -- Return query performance data
        RETURN QUERY SELECT 
            v_perf_record.query_hash,
            v_perf_record.total_time,
            v_perf_record.mean_time,
            v_perf_record.calls,
            CASE 
                WHEN v_perf_record.mean_time > 1000 THEN 'CRITICAL'
                WHEN v_perf_record.mean_time > 500 THEN 'POOR'
                WHEN v_perf_record.mean_time > 100 THEN 'GOOD'
                ELSE 'EXCELLENT'
            END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- MONITORING DASHBOARD VIEW
-- =====================================================================================

-- Real-time monitoring dashboard view
CREATE OR REPLACE VIEW monitoring.system_dashboard AS
SELECT 
    'System Health' as dashboard_section,
    shms.metric_name,
    shms.metric_value,
    shms.metric_unit,
    shms.status,
    shms.threshold_warning,
    shms.threshold_critical,
    shms.measurement_timestamp,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - shms.measurement_timestamp)) as age_seconds
FROM monitoring.system_health_metric_h shmh
JOIN monitoring.system_health_metric_s shms ON shmh.health_metric_hk = shms.health_metric_hk
WHERE shms.load_end_date IS NULL
AND shms.measurement_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'

UNION ALL

SELECT 
    'Performance' as dashboard_section,
    'slow_queries_count' as metric_name,
    COUNT(*) as metric_value,
    'count' as metric_unit,
    CASE WHEN COUNT(*) > 50 THEN 'CRITICAL'
         WHEN COUNT(*) > 20 THEN 'WARNING'
         ELSE 'NORMAL' END as status,
    20.0 as threshold_warning,
    50.0 as threshold_critical,
    MAX(pms.measurement_period_end) as measurement_timestamp,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(pms.measurement_period_end))) as age_seconds
FROM monitoring.performance_metric_h pmh
JOIN monitoring.performance_metric_s pms ON pmh.performance_metric_hk = pms.performance_metric_hk
WHERE pms.load_end_date IS NULL
AND pms.performance_rating IN ('POOR', 'CRITICAL')
AND pms.measurement_period_end >= CURRENT_TIMESTAMP - INTERVAL '1 hour'

UNION ALL

SELECT 
    'Security' as dashboard_section,
    'security_events_last_hour' as metric_name,
    COUNT(*) as metric_value,
    'count' as metric_unit,
    CASE WHEN COUNT(*) > 10 THEN 'CRITICAL'
         WHEN COUNT(*) > 5 THEN 'WARNING'
         ELSE 'NORMAL' END as status,
    5.0 as threshold_warning,
    10.0 as threshold_critical,
    COALESCE(MAX(ses.event_timestamp), CURRENT_TIMESTAMP - INTERVAL '1 hour') as measurement_timestamp,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(MAX(ses.event_timestamp), CURRENT_TIMESTAMP - INTERVAL '1 hour'))) as age_seconds
FROM monitoring.security_event_h seh
JOIN monitoring.security_event_s ses ON seh.security_event_hk = ses.security_event_hk
WHERE ses.load_end_date IS NULL
AND ses.event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
AND ses.event_severity IN ('HIGH', 'CRITICAL')

ORDER BY dashboard_section, metric_name;

-- Grant permissions for monitoring functions
GRANT EXECUTE ON FUNCTION monitoring.collect_system_health_metrics TO postgres;
GRANT EXECUTE ON FUNCTION monitoring.collect_performance_metrics TO postgres;

-- Grant SELECT permissions on monitoring views
GRANT SELECT ON monitoring.system_dashboard TO postgres;

-- =====================================================================================
-- COMMENTS AND DOCUMENTATION
-- =====================================================================================

COMMENT ON SCHEMA monitoring IS 
'Monitoring schema containing system health metrics, performance data, security events, and compliance tracking for production operations and Data Vault 2.0 platform monitoring.';

COMMENT ON TABLE monitoring.system_health_metric_h IS
'Hub table for system health metrics including performance, capacity, availability, and operational metrics with tenant isolation support.';

COMMENT ON TABLE monitoring.performance_metric_h IS
'Hub table for database performance metrics collected from pg_stat_statements and custom performance monitoring queries.';

COMMENT ON TABLE monitoring.security_event_h IS
'Hub table for security events including login failures, unauthorized access attempts, and suspicious database activities.';

COMMENT ON FUNCTION monitoring.collect_system_health_metrics IS
'Collects comprehensive system health metrics including database size, connections, sessions, query performance, and capacity utilization with optional tenant scoping.';

COMMENT ON VIEW monitoring.system_dashboard IS
'Real-time monitoring dashboard view providing current system status across health, performance, and security metrics for operational teams.';

-- =====================================================================================
-- SCRIPT COMPLETION
-- =====================================================================================

-- Log successful completion
DO $$
BEGIN
    RAISE NOTICE 'Step 3: Monitoring Infrastructure deployment completed successfully at %', CURRENT_TIMESTAMP;
    RAISE NOTICE 'Created monitoring schema with % tables and % functions', 
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'monitoring'),
        (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'monitoring');
END
$$; 