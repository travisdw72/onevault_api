-- =====================================================================================
-- Phase 4: Database Locks & Blocking Analysis Infrastructure
-- One Vault Multi-Tenant Data Vault 2.0 Platform
-- =====================================================================================

-- Create lock monitoring schema
CREATE SCHEMA IF NOT EXISTS lock_monitoring;

-- =====================================================================================
-- HUB TABLES
-- =====================================================================================

-- Lock activity hub - tracks unique lock events
CREATE TABLE lock_monitoring.lock_activity_h (
    lock_activity_hk BYTEA PRIMARY KEY,
    lock_activity_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Blocking session hub - tracks sessions causing blocks
CREATE TABLE lock_monitoring.blocking_session_h (
    blocking_session_hk BYTEA PRIMARY KEY,
    blocking_session_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Deadlock event hub - tracks deadlock occurrences
CREATE TABLE lock_monitoring.deadlock_event_h (
    deadlock_event_hk BYTEA PRIMARY KEY,
    deadlock_event_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Lock wait analysis hub - tracks lock wait patterns
CREATE TABLE lock_monitoring.lock_wait_analysis_h (
    lock_wait_analysis_hk BYTEA PRIMARY KEY,
    lock_wait_analysis_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- =====================================================================================
-- SATELLITE TABLES
-- =====================================================================================

-- Lock activity details satellite
CREATE TABLE lock_monitoring.lock_activity_s (
    lock_activity_hk BYTEA NOT NULL REFERENCES lock_monitoring.lock_activity_h(lock_activity_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    lock_type VARCHAR(50) NOT NULL,         -- AccessShareLock, ExclusiveLock, etc.
    lock_mode VARCHAR(50) NOT NULL,         -- GRANTED, WAITING
    relation_name VARCHAR(200),
    relation_type VARCHAR(50),              -- table, index, sequence, etc.
    database_name VARCHAR(100),
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    index_name VARCHAR(100),
    lock_pid INTEGER NOT NULL,
    session_id VARCHAR(100),
    user_name VARCHAR(100),
    application_name VARCHAR(200),
    client_addr INET,
    query_text TEXT,
    query_start TIMESTAMP WITH TIME ZONE,
    lock_acquired_time TIMESTAMP WITH TIME ZONE,
    lock_duration_seconds INTEGER,
    wait_event_type VARCHAR(50),
    wait_event VARCHAR(100),
    lock_granted BOOLEAN DEFAULT false,
    lock_fastpath BOOLEAN DEFAULT false,
    lock_virtualtransaction VARCHAR(50),
    lock_transactionid BIGINT,
    blocking_pid INTEGER,
    blocked_by_count INTEGER DEFAULT 0,
    blocking_count INTEGER DEFAULT 0,
    lock_priority INTEGER DEFAULT 0,
    lock_impact_score DECIMAL(5,2),         -- 0-100 impact assessment
    resolution_action VARCHAR(100),         -- TIMEOUT, CANCELLED, COMPLETED, KILLED
    resolution_timestamp TIMESTAMP WITH TIME ZONE,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (lock_activity_hk, load_date)
);

-- Blocking session details satellite
CREATE TABLE lock_monitoring.blocking_session_s (
    blocking_session_hk BYTEA NOT NULL REFERENCES lock_monitoring.blocking_session_h(blocking_session_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    session_pid INTEGER NOT NULL,
    session_start_time TIMESTAMP WITH TIME ZONE,
    user_name VARCHAR(100),
    database_name VARCHAR(100),
    application_name VARCHAR(200),
    client_addr INET,
    client_hostname VARCHAR(200),
    session_state VARCHAR(20),              -- active, idle, idle in transaction
    current_query TEXT,
    query_start TIMESTAMP WITH TIME ZONE,
    transaction_start TIMESTAMP WITH TIME ZONE,
    state_change TIMESTAMP WITH TIME ZONE,
    blocked_sessions_count INTEGER DEFAULT 0,
    total_locks_held INTEGER DEFAULT 0,
    exclusive_locks_held INTEGER DEFAULT 0,
    blocking_duration_seconds INTEGER,
    blocking_severity VARCHAR(20) DEFAULT 'LOW', -- LOW, MEDIUM, HIGH, CRITICAL
    blocking_impact_score DECIMAL(5,2),    -- 0-100 impact assessment
    auto_kill_eligible BOOLEAN DEFAULT false,
    kill_threshold_seconds INTEGER DEFAULT 300,
    escalation_level INTEGER DEFAULT 0,    -- 0=none, 1=warning, 2=alert, 3=critical
    last_activity TIMESTAMP WITH TIME ZONE,
    connection_count_from_client INTEGER DEFAULT 1,
    is_superuser BOOLEAN DEFAULT false,
    backend_type VARCHAR(50),
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (blocking_session_hk, load_date)
);

-- Deadlock event details satellite
CREATE TABLE lock_monitoring.deadlock_event_s (
    deadlock_event_hk BYTEA NOT NULL REFERENCES lock_monitoring.deadlock_event_h(deadlock_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    deadlock_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    deadlock_id VARCHAR(100),
    involved_pids INTEGER[],
    involved_queries TEXT[],
    involved_users VARCHAR(100)[],
    deadlock_victim_pid INTEGER,
    deadlock_victim_query TEXT,
    deadlock_resolution VARCHAR(50),        -- VICTIM_KILLED, TIMEOUT, MANUAL_INTERVENTION
    deadlock_duration_ms INTEGER,
    affected_tables VARCHAR(200)[],
    lock_types_involved VARCHAR(50)[],
    deadlock_frequency_score DECIMAL(5,2), -- How often this pattern occurs
    prevention_suggestion TEXT,
    deadlock_graph JSONB,                  -- Detailed deadlock graph information
    business_impact VARCHAR(20) DEFAULT 'MEDIUM', -- LOW, MEDIUM, HIGH, CRITICAL
    recovery_time_seconds INTEGER,
    data_consistency_affected BOOLEAN DEFAULT false,
    automatic_retry_successful BOOLEAN DEFAULT false,
    manual_intervention_required BOOLEAN DEFAULT false,
    similar_deadlocks_count INTEGER DEFAULT 1,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (deadlock_event_hk, load_date)
);

-- Lock wait analysis satellite
CREATE TABLE lock_monitoring.lock_wait_analysis_s (
    lock_wait_analysis_hk BYTEA NOT NULL REFERENCES lock_monitoring.lock_wait_analysis_h(lock_wait_analysis_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    analysis_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    analysis_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    total_lock_events INTEGER DEFAULT 0,
    blocking_events INTEGER DEFAULT 0,
    deadlock_events INTEGER DEFAULT 0,
    average_lock_wait_time_ms DECIMAL(10,2),
    max_lock_wait_time_ms DECIMAL(10,2),
    lock_timeout_events INTEGER DEFAULT 0,
    most_contended_table VARCHAR(200),
    most_blocking_user VARCHAR(100),
    most_blocked_user VARCHAR(100),
    peak_concurrent_locks INTEGER DEFAULT 0,
    lock_efficiency_score DECIMAL(5,2),    -- 0-100 efficiency rating
    contention_hotspots JSONB,              -- JSON array of high-contention objects
    recommended_optimizations TEXT[],
    lock_escalation_events INTEGER DEFAULT 0,
    shared_lock_conflicts INTEGER DEFAULT 0,
    exclusive_lock_conflicts INTEGER DEFAULT 0,
    update_lock_conflicts INTEGER DEFAULT 0,
    intent_lock_conflicts INTEGER DEFAULT 0,
    performance_impact_score DECIMAL(5,2), -- 0-100 performance impact
    business_hours_impact BOOLEAN DEFAULT false,
    maintenance_window_impact BOOLEAN DEFAULT false,
    trend_direction VARCHAR(20) DEFAULT 'STABLE', -- IMPROVING, STABLE, DEGRADING
    forecast_next_period TEXT,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (lock_wait_analysis_hk, load_date)
);

-- =====================================================================================
-- LINK TABLES
-- =====================================================================================

-- Lock blocking relationship link
CREATE TABLE lock_monitoring.lock_blocking_l (
    link_lock_blocking_hk BYTEA PRIMARY KEY,
    blocking_session_hk BYTEA NOT NULL REFERENCES lock_monitoring.blocking_session_h(blocking_session_hk),
    lock_activity_hk BYTEA NOT NULL REFERENCES lock_monitoring.lock_activity_h(lock_activity_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Deadlock involvement link
CREATE TABLE lock_monitoring.deadlock_involvement_l (
    link_deadlock_involvement_hk BYTEA PRIMARY KEY,
    deadlock_event_hk BYTEA NOT NULL REFERENCES lock_monitoring.deadlock_event_h(deadlock_event_hk),
    lock_activity_hk BYTEA NOT NULL REFERENCES lock_monitoring.lock_activity_h(lock_activity_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- =====================================================================================
-- PERFORMANCE INDEXES
-- =====================================================================================

-- Lock activity indexes
CREATE INDEX idx_lock_activity_s_type_mode ON lock_monitoring.lock_activity_s(lock_type, lock_mode, lock_granted) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_lock_activity_s_duration ON lock_monitoring.lock_activity_s(lock_duration_seconds DESC, lock_impact_score DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_lock_activity_s_blocking ON lock_monitoring.lock_activity_s(blocking_pid, blocked_by_count DESC) 
WHERE load_end_date IS NULL AND blocking_pid IS NOT NULL;

CREATE INDEX idx_lock_activity_s_relation ON lock_monitoring.lock_activity_s(schema_name, table_name, lock_type) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_lock_activity_s_timestamp ON lock_monitoring.lock_activity_s(lock_acquired_time DESC, resolution_timestamp DESC) 
WHERE load_end_date IS NULL;

-- Blocking session indexes
CREATE INDEX idx_blocking_session_s_severity ON lock_monitoring.blocking_session_s(blocking_severity, blocked_sessions_count DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_blocking_session_s_duration ON lock_monitoring.blocking_session_s(blocking_duration_seconds DESC, escalation_level DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_blocking_session_s_user ON lock_monitoring.blocking_session_s(user_name, application_name) 
WHERE load_end_date IS NULL;

-- Deadlock event indexes
CREATE INDEX idx_deadlock_event_s_timestamp ON lock_monitoring.deadlock_event_s(deadlock_timestamp DESC, business_impact) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_deadlock_event_s_frequency ON lock_monitoring.deadlock_event_s(deadlock_frequency_score DESC, similar_deadlocks_count DESC) 
WHERE load_end_date IS NULL;

-- Lock wait analysis indexes
CREATE INDEX idx_lock_wait_analysis_s_period ON lock_monitoring.lock_wait_analysis_s(analysis_period_start DESC, analysis_period_end DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_lock_wait_analysis_s_efficiency ON lock_monitoring.lock_wait_analysis_s(lock_efficiency_score ASC, performance_impact_score DESC) 
WHERE load_end_date IS NULL;

-- =====================================================================================
-- CORE FUNCTIONS
-- =====================================================================================

-- Function to capture current lock activity
CREATE OR REPLACE FUNCTION lock_monitoring.capture_lock_activity(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    locks_captured INTEGER,
    blocking_locks INTEGER,
    critical_locks INTEGER,
    deadlocks_detected INTEGER
) AS $$
DECLARE
    v_lock_record RECORD;
    v_lock_activity_hk BYTEA;
    v_lock_activity_bk VARCHAR(255);
    v_locks_captured INTEGER := 0;
    v_blocking_locks INTEGER := 0;
    v_critical_locks INTEGER := 0;
    v_impact_score DECIMAL(5,2);
    v_blocking_count INTEGER;
BEGIN
    -- Capture current lock activity from pg_locks and pg_stat_activity
    FOR v_lock_record IN 
        WITH lock_details AS (
            SELECT 
                pl.locktype,
                pl.mode,
                pl.granted,
                pl.fastpath,
                pl.virtualtransaction,
                pl.transactionid,
                pl.relation,
                pl.page,
                pl.tuple,
                pl.classid,
                pl.objid,
                pl.objsubid,
                pl.pid,
                psa.usename,
                psa.datname,
                psa.application_name,
                psa.client_addr,
                psa.query,
                psa.query_start,
                psa.state,
                psa.state_change,
                psa.xact_start,
                COALESCE(pc.relname, 'unknown') as relation_name,
                COALESCE(pn.nspname, 'unknown') as schema_name,
                CASE 
                    WHEN pc.relkind = 'r' THEN 'table'
                    WHEN pc.relkind = 'i' THEN 'index'
                    WHEN pc.relkind = 'S' THEN 'sequence'
                    WHEN pc.relkind = 'v' THEN 'view'
                    WHEN pc.relkind = 'm' THEN 'materialized_view'
                    ELSE 'other'
                END as relation_type,
                -- Find blocking relationships
                blocking.pid as blocking_pid,
                COUNT(*) OVER (PARTITION BY pl.pid) as total_locks_for_session
            FROM pg_locks pl
            LEFT JOIN pg_stat_activity psa ON pl.pid = psa.pid
            LEFT JOIN pg_class pc ON pl.relation = pc.oid
            LEFT JOIN pg_namespace pn ON pc.relnamespace = pn.oid
            LEFT JOIN pg_locks blocking ON (
                pl.locktype = blocking.locktype AND
                pl.database IS NOT DISTINCT FROM blocking.database AND
                pl.relation IS NOT DISTINCT FROM blocking.relation AND
                pl.page IS NOT DISTINCT FROM blocking.page AND
                pl.tuple IS NOT DISTINCT FROM blocking.tuple AND
                pl.virtualxid IS NOT DISTINCT FROM blocking.virtualxid AND
                pl.transactionid IS NOT DISTINCT FROM blocking.transactionid AND
                pl.classid IS NOT DISTINCT FROM blocking.classid AND
                pl.objid IS NOT DISTINCT FROM blocking.objid AND
                pl.objsubid IS NOT DISTINCT FROM blocking.objsubid AND
                pl.pid != blocking.pid AND
                NOT pl.granted AND
                blocking.granted
            )
            WHERE psa.backend_type = 'client backend'
            AND (p_tenant_hk IS NULL OR EXISTS (
                SELECT 1 FROM auth.user_h uh 
                WHERE uh.tenant_hk = p_tenant_hk 
                AND uh.user_bk = psa.usename
            ))
        )
        SELECT *,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(query_start, xact_start, state_change)))::INTEGER as duration_seconds
        FROM lock_details
        ORDER BY granted ASC, duration_seconds DESC
    LOOP
        -- Calculate impact score based on multiple factors
        v_impact_score := LEAST(100.0, GREATEST(0.0,
            CASE WHEN NOT v_lock_record.granted THEN 40.0 ELSE 10.0 END + -- Waiting locks have higher impact
            CASE WHEN v_lock_record.mode IN ('AccessExclusiveLock', 'ExclusiveLock') THEN 30.0 ELSE 10.0 END + -- Exclusive locks
            CASE WHEN v_lock_record.duration_seconds > 300 THEN 20.0 
                 WHEN v_lock_record.duration_seconds > 60 THEN 10.0 ELSE 0.0 END + -- Duration impact
            CASE WHEN v_lock_record.blocking_pid IS NOT NULL THEN 20.0 ELSE 0.0 END -- Blocking impact
        ));
        
        -- Count blocking relationships
        SELECT COUNT(*) INTO v_blocking_count
        FROM pg_locks bl
        WHERE bl.pid = v_lock_record.pid
        AND NOT bl.granted;
        
        -- Generate business key and hash key
        v_lock_activity_bk := 'LOCK_' || v_lock_record.pid || '_' || 
                             COALESCE(v_lock_record.relation::text, 'NONE') || '_' ||
                             v_lock_record.locktype || '_' ||
                             to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US');
        v_lock_activity_hk := util.hash_binary(v_lock_activity_bk);
        
        -- Insert hub record
        INSERT INTO lock_monitoring.lock_activity_h VALUES (
            v_lock_activity_hk, v_lock_activity_bk, 
            COALESCE(p_tenant_hk, util.hash_binary('SYSTEM')),
            util.current_load_date(), 'LOCK_MONITOR'
        ) ON CONFLICT (lock_activity_bk) DO NOTHING;
        
        -- Insert satellite record
        INSERT INTO lock_monitoring.lock_activity_s VALUES (
            v_lock_activity_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_lock_activity_bk || v_lock_record.mode || v_impact_score::text),
            v_lock_record.locktype,
            v_lock_record.mode,
            v_lock_record.relation_name,
            v_lock_record.relation_type,
            v_lock_record.datname,
            v_lock_record.schema_name,
            CASE WHEN v_lock_record.relation_type = 'table' THEN v_lock_record.relation_name ELSE NULL END,
            CASE WHEN v_lock_record.relation_type = 'index' THEN v_lock_record.relation_name ELSE NULL END,
            v_lock_record.pid,
            v_lock_record.pid::text, -- session_id
            v_lock_record.usename,
            v_lock_record.application_name,
            v_lock_record.client_addr,
            v_lock_record.query,
            v_lock_record.query_start,
            CURRENT_TIMESTAMP,
            v_lock_record.duration_seconds,
            NULL, -- wait_event_type - would need additional query
            NULL, -- wait_event - would need additional query
            v_lock_record.granted,
            v_lock_record.fastpath,
            v_lock_record.virtualtransaction,
            v_lock_record.transactionid,
            v_lock_record.blocking_pid,
            v_blocking_count,
            CASE WHEN v_lock_record.blocking_pid IS NOT NULL THEN 1 ELSE 0 END,
            CASE WHEN NOT v_lock_record.granted THEN 1 ELSE 0 END, -- priority
            v_impact_score,
            NULL, -- resolution_action
            NULL, -- resolution_timestamp
            'LOCK_MONITOR'
        ) ON CONFLICT (lock_activity_hk, load_date) DO NOTHING;
        
        v_locks_captured := v_locks_captured + 1;
        
        IF v_lock_record.blocking_pid IS NOT NULL THEN
            v_blocking_locks := v_blocking_locks + 1;
        END IF;
        
        IF v_impact_score >= 70.0 THEN
            v_critical_locks := v_critical_locks + 1;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT v_locks_captured, v_blocking_locks, v_critical_locks, 0;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- AUTOMATED MONITORING FUNCTIONS
-- =====================================================================================

-- Function to run comprehensive lock monitoring
CREATE OR REPLACE FUNCTION lock_monitoring.run_lock_monitoring(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    monitoring_summary VARCHAR(200),
    locks_captured INTEGER,
    blocking_sessions INTEGER,
    deadlocks_detected INTEGER,
    critical_issues INTEGER,
    recommendations TEXT[]
) AS $$
DECLARE
    v_lock_results RECORD;
    v_blocking_results RECORD;
    v_deadlock_results RECORD;
    v_analysis_results RECORD;
    v_total_locks INTEGER := 0;
    v_total_blocking INTEGER := 0;
    v_total_deadlocks INTEGER := 0;
    v_critical_issues INTEGER := 0;
    v_recommendations TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Capture current lock activity
    SELECT * INTO v_lock_results
    FROM lock_monitoring.capture_lock_activity(p_tenant_hk)
    LIMIT 1;
    
    v_total_locks := COALESCE(v_lock_results.locks_captured, 0);
    v_critical_issues := COALESCE(v_lock_results.critical_locks, 0);
    
    -- Detect blocking sessions
    SELECT COUNT(*) INTO v_total_blocking
    FROM lock_monitoring.detect_blocking_sessions(p_tenant_hk, 30);
    
    -- Detect deadlocks
    SELECT COUNT(*) INTO v_total_deadlocks
    FROM lock_monitoring.detect_deadlocks(p_tenant_hk)
    WHERE deadlock_detected = true;
    
    -- Perform lock wait analysis
    SELECT * INTO v_analysis_results
    FROM lock_monitoring.analyze_lock_waits(p_tenant_hk, 1)
    LIMIT 1;
    
    -- Compile recommendations
    IF v_total_blocking > 5 THEN
        v_recommendations := array_append(v_recommendations, 'High number of blocking sessions detected - review transaction patterns');
    END IF;
    
    IF v_total_deadlocks > 0 THEN
        v_recommendations := array_append(v_recommendations, 'Deadlocks detected - implement retry logic and review locking order');
    END IF;
    
    IF v_critical_issues > 10 THEN
        v_recommendations := array_append(v_recommendations, 'Critical lock contention - consider emergency intervention');
    END IF;
    
    IF COALESCE(v_analysis_results.efficiency_score, 100) < 70 THEN
        v_recommendations := array_append(v_recommendations, 'Lock efficiency below threshold - optimize query performance');
    END IF;
    
    IF array_length(v_recommendations, 1) IS NULL THEN
        v_recommendations := array_append(v_recommendations, 'Lock monitoring shows normal activity');
    END IF;
    
    RETURN QUERY SELECT 
        'Lock monitoring completed for ' || COALESCE(encode(p_tenant_hk, 'hex'), 'all tenants'),
        v_total_locks,
        v_total_blocking,
        v_total_deadlocks,
        v_critical_issues,
        v_recommendations;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- DASHBOARD VIEWS
-- =====================================================================================

-- Real-time lock activity dashboard
CREATE VIEW lock_monitoring.lock_activity_dashboard AS
SELECT 
    las.lock_type,
    las.lock_mode,
    las.relation_name,
    las.schema_name,
    las.table_name,
    COUNT(*) as lock_count,
    COUNT(*) FILTER (WHERE las.lock_granted = false) as waiting_locks,
    COUNT(*) FILTER (WHERE las.blocking_pid IS NOT NULL) as blocking_locks,
    AVG(las.lock_duration_seconds) as avg_duration_seconds,
    MAX(las.lock_duration_seconds) as max_duration_seconds,
    AVG(las.lock_impact_score) as avg_impact_score,
    MAX(las.lock_impact_score) as max_impact_score,
    COUNT(DISTINCT las.user_name) as distinct_users,
    COUNT(DISTINCT las.application_name) as distinct_applications,
    MIN(las.lock_acquired_time) as earliest_lock,
    MAX(las.lock_acquired_time) as latest_lock
FROM lock_monitoring.lock_activity_h lah
JOIN lock_monitoring.lock_activity_s las ON lah.lock_activity_hk = las.lock_activity_hk
WHERE las.load_end_date IS NULL
AND las.lock_acquired_time >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
GROUP BY las.lock_type, las.lock_mode, las.relation_name, las.schema_name, las.table_name
ORDER BY lock_count DESC, avg_impact_score DESC;

-- Blocking sessions dashboard
CREATE VIEW lock_monitoring.blocking_sessions_dashboard AS
SELECT 
    bss.session_pid,
    bss.user_name,
    bss.database_name,
    bss.application_name,
    bss.client_addr,
    bss.session_state,
    bss.blocked_sessions_count,
    bss.total_locks_held,
    bss.exclusive_locks_held,
    bss.blocking_duration_seconds,
    bss.blocking_severity,
    bss.blocking_impact_score,
    bss.auto_kill_eligible,
    bss.escalation_level,
    LEFT(bss.current_query, 200) as query_preview,
    bss.last_activity,
    CASE 
        WHEN bss.blocking_duration_seconds > 600 THEN 'URGENT'
        WHEN bss.blocking_duration_seconds > 300 THEN 'HIGH'
        WHEN bss.blocking_duration_seconds > 60 THEN 'MEDIUM'
        ELSE 'LOW'
    END as urgency_level
FROM lock_monitoring.blocking_session_h bsh
JOIN lock_monitoring.blocking_session_s bss ON bsh.blocking_session_hk = bss.blocking_session_hk
WHERE bss.load_end_date IS NULL
AND bss.session_state != 'terminated'
ORDER BY bss.blocking_severity DESC, bss.blocked_sessions_count DESC, bss.blocking_duration_seconds DESC;

-- Lock wait analysis dashboard
CREATE VIEW lock_monitoring.lock_wait_analysis_dashboard AS
SELECT 
    lwas.analysis_period_start,
    lwas.analysis_period_end,
    lwas.total_lock_events,
    lwas.blocking_events,
    lwas.deadlock_events,
    ROUND(lwas.average_lock_wait_time_ms, 2) as avg_wait_time_ms,
    ROUND(lwas.max_lock_wait_time_ms, 2) as max_wait_time_ms,
    lwas.lock_timeout_events,
    lwas.most_contended_table,
    lwas.most_blocking_user,
    lwas.most_blocked_user,
    lwas.peak_concurrent_locks,
    ROUND(lwas.lock_efficiency_score, 2) as efficiency_score,
    ROUND(lwas.performance_impact_score, 2) as performance_impact_score,
    lwas.business_hours_impact,
    lwas.trend_direction,
    lwas.recommended_optimizations,
    CASE 
        WHEN lwas.lock_efficiency_score >= 90 THEN 'EXCELLENT'
        WHEN lwas.lock_efficiency_score >= 80 THEN 'GOOD'
        WHEN lwas.lock_efficiency_score >= 70 THEN 'FAIR'
        WHEN lwas.lock_efficiency_score >= 60 THEN 'POOR'
        ELSE 'CRITICAL'
    END as efficiency_rating
FROM lock_monitoring.lock_wait_analysis_h lwah
JOIN lock_monitoring.lock_wait_analysis_s lwas ON lwah.lock_wait_analysis_hk = lwas.lock_wait_analysis_hk
WHERE lwas.load_end_date IS NULL
ORDER BY lwas.analysis_period_start DESC;

-- Deadlock events dashboard
CREATE VIEW lock_monitoring.deadlock_events_dashboard AS
SELECT 
    des.deadlock_timestamp,
    des.deadlock_id,
    array_length(des.involved_pids, 1) as sessions_involved,
    des.involved_pids,
    des.involved_users,
    des.deadlock_victim_pid,
    des.deadlock_resolution,
    des.deadlock_duration_ms,
    des.affected_tables,
    des.lock_types_involved,
    ROUND(des.deadlock_frequency_score, 2) as frequency_score,
    des.prevention_suggestion,
    des.business_impact,
    des.recovery_time_seconds,
    des.data_consistency_affected,
    des.automatic_retry_successful,
    des.manual_intervention_required,
    des.similar_deadlocks_count,
    CASE 
        WHEN des.business_impact = 'CRITICAL' THEN 'IMMEDIATE'
        WHEN des.business_impact = 'HIGH' THEN 'URGENT'
        WHEN des.business_impact = 'MEDIUM' THEN 'MODERATE'
        ELSE 'LOW'
    END as response_priority
FROM lock_monitoring.deadlock_event_h deh
JOIN lock_monitoring.deadlock_event_s des ON deh.deadlock_event_hk = des.deadlock_event_hk
WHERE des.load_end_date IS NULL
ORDER BY des.deadlock_timestamp DESC;

-- =====================================================================================
-- MAINTENANCE AND CLEANUP
-- =====================================================================================

-- Function to cleanup old lock monitoring data
CREATE OR REPLACE FUNCTION lock_monitoring.cleanup_old_data(
    p_retention_days INTEGER DEFAULT 30
) RETURNS TABLE (
    cleanup_summary VARCHAR(200),
    records_cleaned INTEGER
) AS $$
DECLARE
    v_cutoff_date TIMESTAMP WITH TIME ZONE;
    v_records_cleaned INTEGER := 0;
    v_current_count INTEGER;
BEGIN
    v_cutoff_date := CURRENT_TIMESTAMP - (p_retention_days || ' days')::INTERVAL;
    
    -- End-date old satellite records
    UPDATE lock_monitoring.lock_activity_s 
    SET load_end_date = util.current_load_date()
    WHERE load_date < v_cutoff_date 
    AND load_end_date IS NULL;
    
    GET DIAGNOSTICS v_records_cleaned = ROW_COUNT;
    
    UPDATE lock_monitoring.blocking_session_s 
    SET load_end_date = util.current_load_date()
    WHERE load_date < v_cutoff_date 
    AND load_end_date IS NULL;
    
    GET DIAGNOSTICS v_current_count = ROW_COUNT;
    v_records_cleaned := v_records_cleaned + v_current_count;
    
    UPDATE lock_monitoring.deadlock_event_s 
    SET load_end_date = util.current_load_date()
    WHERE load_date < v_cutoff_date 
    AND load_end_date IS NULL;
    
    GET DIAGNOSTICS v_current_count = ROW_COUNT;
    v_records_cleaned := v_records_cleaned + v_current_count;
    
    UPDATE lock_monitoring.lock_wait_analysis_s 
    SET load_end_date = util.current_load_date()
    WHERE load_date < v_cutoff_date 
    AND load_end_date IS NULL;
    
    GET DIAGNOSTICS v_current_count = ROW_COUNT;
    v_records_cleaned := v_records_cleaned + v_current_count;
    
    RETURN QUERY SELECT 
        'Cleaned up lock monitoring data older than ' || p_retention_days || ' days',
        v_records_cleaned;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- COMMENTS AND DOCUMENTATION
-- =====================================================================================

COMMENT ON SCHEMA lock_monitoring IS 
'Lock monitoring and blocking analysis infrastructure for production database performance management and deadlock prevention.';

COMMENT ON TABLE lock_monitoring.lock_activity_h IS 
'Hub table for lock activity events with unique lock identifiers and tenant isolation.';

COMMENT ON TABLE lock_monitoring.lock_activity_s IS 
'Satellite table storing detailed lock activity information including duration, impact, and resolution data.';

COMMENT ON TABLE lock_monitoring.blocking_session_h IS 
'Hub table for sessions that are blocking other database operations.';

COMMENT ON TABLE lock_monitoring.blocking_session_s IS 
'Satellite table with detailed blocking session analysis including severity assessment and auto-resolution eligibility.';

COMMENT ON TABLE lock_monitoring.deadlock_event_h IS 
'Hub table for deadlock events with unique deadlock identifiers.';

COMMENT ON TABLE lock_monitoring.deadlock_event_s IS 
'Satellite table storing comprehensive deadlock analysis including involved sessions, resolution actions, and prevention recommendations.';

COMMENT ON TABLE lock_monitoring.lock_wait_analysis_h IS 
'Hub table for periodic lock wait pattern analysis.';

COMMENT ON TABLE lock_monitoring.lock_wait_analysis_s IS 
'Satellite table with lock wait analysis results including efficiency scores, contention hotspots, and optimization recommendations.';

COMMENT ON FUNCTION lock_monitoring.capture_lock_activity IS 
'Captures current database lock activity with impact assessment and blocking relationship analysis for real-time monitoring.';

COMMENT ON FUNCTION lock_monitoring.run_lock_monitoring IS 
'Comprehensive lock monitoring function that captures activity, detects blocking, analyzes deadlocks, and provides actionable recommendations.';

COMMENT ON VIEW lock_monitoring.lock_activity_dashboard IS 
'Real-time dashboard view showing current lock activity patterns, contention points, and performance impact metrics.';

COMMENT ON VIEW lock_monitoring.blocking_sessions_dashboard IS 
'Dashboard view for monitoring sessions that are blocking others with severity assessment and recommended actions.';

-- =====================================================================================
-- GRANTS AND PERMISSIONS
-- =====================================================================================

-- Create roles if they don't exist
DO $$
BEGIN
    -- Create monitoring role if it doesn't exist
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'monitoring_role') THEN
        CREATE ROLE monitoring_role;
        RAISE NOTICE 'Created monitoring_role';
    END IF;
    
    -- Create lock admin role if it doesn't exist
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'lock_admin_role') THEN
        CREATE ROLE lock_admin_role;
        RAISE NOTICE 'Created lock_admin_role';
    END IF;
END
$$;

-- Grant appropriate permissions for monitoring users
GRANT USAGE ON SCHEMA lock_monitoring TO monitoring_role;
GRANT SELECT ON ALL TABLES IN SCHEMA lock_monitoring TO monitoring_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA lock_monitoring TO monitoring_role;

-- Grant admin permissions for lock management  
GRANT ALL ON SCHEMA lock_monitoring TO lock_admin_role;
GRANT ALL ON ALL TABLES IN SCHEMA lock_monitoring TO lock_admin_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA lock_monitoring TO lock_admin_role;

-- Also grant permissions to existing roles
GRANT USAGE ON SCHEMA lock_monitoring TO authenticated_users;
GRANT SELECT ON ALL TABLES IN SCHEMA lock_monitoring TO authenticated_users;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA lock_monitoring TO authenticated_users;

-- Grant admin permissions to existing admin roles
GRANT ALL ON SCHEMA lock_monitoring TO dv_admin;
GRANT ALL ON ALL TABLES IN SCHEMA lock_monitoring TO dv_admin;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA lock_monitoring TO dv_admin;

GRANT ALL ON SCHEMA lock_monitoring TO admin_access;
GRANT ALL ON ALL TABLES IN SCHEMA lock_monitoring TO admin_access;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA lock_monitoring TO admin_access; 