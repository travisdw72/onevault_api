-- =====================================================================================
-- Script: step_5_performance_optimization.sql
-- Description: Performance Optimization Infrastructure Implementation - Phase 3 Part 1
-- Version: 1.0
-- Date: 2024-12-19
-- Author: One Vault Development Team
-- 
-- Purpose: Implement comprehensive performance optimization infrastructure including
--          query optimization, connection pooling, caching strategies, automated
--          performance tuning, and database optimization for production scale
-- =====================================================================================

-- Enable required extensions for performance optimization
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_buffercache";
CREATE EXTENSION IF NOT EXISTS "pgstattuple";

-- =====================================================================================
-- PERFORMANCE OPTIMIZATION SCHEMA
-- =====================================================================================

-- Create performance schema for optimization tracking
CREATE SCHEMA IF NOT EXISTS performance;

-- Grant permissions to performance schema
GRANT USAGE ON SCHEMA performance TO postgres;

-- =====================================================================================
-- QUERY OPTIMIZATION TABLES (Data Vault 2.0 Pattern)
-- =====================================================================================

-- Query Performance Hub
CREATE TABLE performance.query_performance_h (
    query_performance_hk BYTEA PRIMARY KEY,
    query_performance_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide queries
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'PERFORMANCE_OPTIMIZER'
);

-- Query Performance Satellite
CREATE TABLE performance.query_performance_s (
    query_performance_hk BYTEA NOT NULL REFERENCES performance.query_performance_h(query_performance_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    query_hash VARCHAR(64) NOT NULL,        -- pg_stat_statements.queryid
    query_text TEXT,
    database_name VARCHAR(100),
    username VARCHAR(100),
    calls INTEGER,
    total_exec_time DECIMAL(15,4),          -- Total execution time in ms
    mean_exec_time DECIMAL(15,4),           -- Average execution time in ms
    min_exec_time DECIMAL(15,4),            -- Minimum execution time in ms
    max_exec_time DECIMAL(15,4),            -- Maximum execution time in ms
    stddev_exec_time DECIMAL(15,4),         -- Standard deviation of execution time
    rows_examined INTEGER,
    rows_returned INTEGER,
    shared_blks_hit INTEGER,                -- Buffer cache hits
    shared_blks_read INTEGER,               -- Disk reads
    shared_blks_dirtied INTEGER,            -- Pages dirtied
    shared_blks_written INTEGER,            -- Pages written
    local_blks_hit INTEGER,                 -- Local buffer hits
    local_blks_read INTEGER,                -- Local buffer reads
    local_blks_dirtied INTEGER,             -- Local pages dirtied
    local_blks_written INTEGER,             -- Local pages written
    temp_blks_read INTEGER,                 -- Temp file reads
    temp_blks_written INTEGER,              -- Temp file writes
    blk_read_time DECIMAL(15,4),            -- Time spent reading blocks
    blk_write_time DECIMAL(15,4),           -- Time spent writing blocks
    wal_records INTEGER,                    -- WAL records generated
    wal_fpi INTEGER,                        -- WAL full page images
    wal_bytes BIGINT,                       -- WAL bytes generated
    jit_functions INTEGER,                  -- JIT functions compiled
    jit_generation_time DECIMAL(15,4),      -- JIT generation time
    jit_inlining_time DECIMAL(15,4),        -- JIT inlining time
    jit_optimization_time DECIMAL(15,4),    -- JIT optimization time
    jit_emission_time DECIMAL(15,4),        -- JIT emission time
    performance_rating VARCHAR(20),         -- EXCELLENT, GOOD, POOR, CRITICAL
    optimization_suggestions TEXT[],
    execution_plan_hash VARCHAR(64),        -- Hash of execution plan
    index_usage_efficiency DECIMAL(5,2),    -- Percentage of efficient index usage
    cache_hit_ratio DECIMAL(5,2),          -- Buffer cache hit ratio for this query
    measurement_period_start TIMESTAMP WITH TIME ZONE,
    measurement_period_end TIMESTAMP WITH TIME ZONE,
    record_source VARCHAR(100) NOT NULL DEFAULT 'PERFORMANCE_OPTIMIZER',
    PRIMARY KEY (query_performance_hk, load_date)
);

-- Index Optimization Hub
CREATE TABLE performance.index_optimization_h (
    index_optimization_hk BYTEA PRIMARY KEY,
    index_optimization_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'INDEX_OPTIMIZER'
);

-- Index Optimization Satellite
CREATE TABLE performance.index_optimization_s (
    index_optimization_hk BYTEA NOT NULL REFERENCES performance.index_optimization_h(index_optimization_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    schema_name VARCHAR(100) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    index_name VARCHAR(100),
    index_type VARCHAR(50),                 -- BTREE, HASH, GIN, GIST, SPGIST, BRIN
    index_columns TEXT[],
    index_size_bytes BIGINT,
    table_size_bytes BIGINT,
    index_scans INTEGER,                    -- Number of index scans
    index_tup_read INTEGER,                 -- Tuples read via index
    index_tup_fetch INTEGER,                -- Tuples fetched via index
    table_seq_scan INTEGER,                 -- Sequential scans on table
    table_seq_tup_read INTEGER,             -- Tuples read via sequential scan
    index_usage_ratio DECIMAL(5,2),         -- Index usage vs sequential scan ratio
    index_efficiency_score DECIMAL(5,2),    -- Overall index efficiency (0-100)
    bloat_percentage DECIMAL(5,2),          -- Index bloat percentage
    fragmentation_level VARCHAR(20),        -- LOW, MEDIUM, HIGH, CRITICAL
    last_vacuum TIMESTAMP WITH TIME ZONE,
    last_analyze TIMESTAMP WITH TIME ZONE,
    last_autoanalyze TIMESTAMP WITH TIME ZONE,
    optimization_recommendation VARCHAR(50), -- CREATE, DROP, REBUILD, REINDEX, ANALYZE
    recommended_index_definition TEXT,       -- Suggested index creation SQL
    estimated_performance_gain DECIMAL(5,2), -- Expected performance improvement %
    maintenance_priority VARCHAR(20),       -- LOW, MEDIUM, HIGH, CRITICAL
    analysis_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    record_source VARCHAR(100) NOT NULL DEFAULT 'INDEX_OPTIMIZER',
    PRIMARY KEY (index_optimization_hk, load_date)
);

-- Connection Pool Optimization Hub
CREATE TABLE performance.connection_pool_h (
    connection_pool_hk BYTEA PRIMARY KEY,
    connection_pool_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'CONNECTION_OPTIMIZER'
);

-- Connection Pool Optimization Satellite
CREATE TABLE performance.connection_pool_s (
    connection_pool_hk BYTEA NOT NULL REFERENCES performance.connection_pool_h(connection_pool_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    pool_name VARCHAR(100),
    max_connections INTEGER,
    current_connections INTEGER,
    active_connections INTEGER,
    idle_connections INTEGER,
    waiting_connections INTEGER,
    connection_utilization_pct DECIMAL(5,2),
    avg_connection_duration_ms DECIMAL(15,4),
    max_connection_duration_ms DECIMAL(15,4),
    connection_timeouts INTEGER,
    connection_errors INTEGER,
    pool_efficiency_score DECIMAL(5,2),     -- 0-100 efficiency rating
    recommended_max_connections INTEGER,
    recommended_pool_settings JSONB,
    optimization_notes TEXT,
    measurement_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    record_source VARCHAR(100) NOT NULL DEFAULT 'CONNECTION_OPTIMIZER',
    PRIMARY KEY (connection_pool_hk, load_date)
);

-- Cache Optimization Hub
CREATE TABLE performance.cache_optimization_h (
    cache_optimization_hk BYTEA PRIMARY KEY,
    cache_optimization_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'CACHE_OPTIMIZER'
);

-- Cache Optimization Satellite
CREATE TABLE performance.cache_optimization_s (
    cache_optimization_hk BYTEA NOT NULL REFERENCES performance.cache_optimization_h(cache_optimization_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    cache_type VARCHAR(50) NOT NULL,        -- SHARED_BUFFERS, QUERY_CACHE, PLAN_CACHE, OS_CACHE
    cache_size_bytes BIGINT,
    cache_used_bytes BIGINT,
    cache_hit_ratio DECIMAL(5,2),
    cache_miss_ratio DECIMAL(5,2),
    cache_evictions INTEGER,
    cache_efficiency_score DECIMAL(5,2),    -- 0-100 efficiency rating
    buffer_allocation JSONB,                -- Detailed buffer allocation stats
    most_accessed_objects TEXT[],           -- Most frequently accessed tables/indexes
    cache_pressure_indicators JSONB,        -- Indicators of cache pressure
    recommended_cache_size_bytes BIGINT,
    optimization_recommendations TEXT[],
    measurement_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    record_source VARCHAR(100) NOT NULL DEFAULT 'CACHE_OPTIMIZER',
    PRIMARY KEY (cache_optimization_hk, load_date)
);

-- =====================================================================================
-- PERFORMANCE INDEXES FOR OPTIMIZATION TABLES
-- =====================================================================================

-- Query Performance Indexes
CREATE INDEX idx_query_performance_s_rating ON performance.query_performance_s(performance_rating, mean_exec_time DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_query_performance_s_exec_time ON performance.query_performance_s(mean_exec_time DESC, calls DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_query_performance_s_period ON performance.query_performance_s(measurement_period_start DESC, measurement_period_end DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_query_performance_s_hash ON performance.query_performance_s(query_hash) 
WHERE load_end_date IS NULL;

-- Index Optimization Indexes
CREATE INDEX idx_index_optimization_s_efficiency ON performance.index_optimization_s(index_efficiency_score ASC, maintenance_priority) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_index_optimization_s_table ON performance.index_optimization_s(schema_name, table_name) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_index_optimization_s_recommendation ON performance.index_optimization_s(optimization_recommendation, maintenance_priority) 
WHERE load_end_date IS NULL;

-- Connection Pool Indexes
CREATE INDEX idx_connection_pool_s_utilization ON performance.connection_pool_s(connection_utilization_pct DESC, pool_efficiency_score ASC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_connection_pool_s_timestamp ON performance.connection_pool_s(measurement_timestamp DESC) 
WHERE load_end_date IS NULL;

-- Cache Optimization Indexes
CREATE INDEX idx_cache_optimization_s_hit_ratio ON performance.cache_optimization_s(cache_hit_ratio ASC, cache_type) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_cache_optimization_s_efficiency ON performance.cache_optimization_s(cache_efficiency_score ASC, cache_type) 
WHERE load_end_date IS NULL;

-- =====================================================================================
-- PERFORMANCE ANALYSIS FUNCTIONS
-- =====================================================================================

-- Function to analyze query performance and provide optimization recommendations
CREATE OR REPLACE FUNCTION performance.analyze_query_performance(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_analysis_period_hours INTEGER DEFAULT 24,
    p_min_calls INTEGER DEFAULT 10
) RETURNS TABLE (
    query_hash VARCHAR(64),
    query_text TEXT,
    performance_rating VARCHAR(20),
    mean_exec_time DECIMAL(15,4),
    total_calls INTEGER,
    optimization_suggestions TEXT[]
) AS $$
DECLARE
    v_query_record RECORD;
    v_performance_hk BYTEA;
    v_performance_bk VARCHAR(255);
    v_rating VARCHAR(20);
    v_suggestions TEXT[];
    v_cache_hit_ratio DECIMAL(5,2);
    v_index_efficiency DECIMAL(5,2);
BEGIN
    -- Analyze queries from pg_stat_statements
    FOR v_query_record IN 
        SELECT 
            pss.queryid::text as query_hash,
            pss.query as query_text,
            pss.calls,
            pss.total_exec_time,
            pss.mean_exec_time,
            pss.min_exec_time,
            pss.max_exec_time,
            pss.stddev_exec_time,
            pss.rows,
            pss.shared_blks_hit,
            pss.shared_blks_read,
            pss.shared_blks_dirtied,
            pss.shared_blks_written,
            pss.local_blks_hit,
            pss.local_blks_read,
            pss.local_blks_dirtied,
            pss.local_blks_written,
            pss.temp_blks_read,
            pss.temp_blks_written,
            pss.blk_read_time,
            pss.blk_write_time,
            pss.wal_records,
            pss.wal_fpi,
            pss.wal_bytes
        FROM pg_stat_statements pss
        WHERE pss.calls >= p_min_calls
        AND pss.last_seen >= CURRENT_TIMESTAMP - (p_analysis_period_hours || ' hours')::INTERVAL
        ORDER BY pss.total_exec_time DESC
        LIMIT 100
    LOOP
        -- Calculate performance metrics
        v_cache_hit_ratio := CASE 
            WHEN (v_query_record.shared_blks_hit + v_query_record.shared_blks_read) > 0 
            THEN ROUND((v_query_record.shared_blks_hit::DECIMAL / 
                       (v_query_record.shared_blks_hit + v_query_record.shared_blks_read)) * 100, 2)
            ELSE 100.0
        END;
        
        -- Determine performance rating
        v_rating := CASE 
            WHEN v_query_record.mean_exec_time > 5000 THEN 'CRITICAL'
            WHEN v_query_record.mean_exec_time > 1000 THEN 'POOR'
            WHEN v_query_record.mean_exec_time > 100 THEN 'GOOD'
            ELSE 'EXCELLENT'
        END;
        
        -- Generate optimization suggestions
        v_suggestions := ARRAY[]::TEXT[];
        
        IF v_query_record.mean_exec_time > 1000 THEN
            v_suggestions := array_append(v_suggestions, 'Query execution time exceeds 1 second - review query structure');
        END IF;
        
        IF v_cache_hit_ratio < 95 THEN
            v_suggestions := array_append(v_suggestions, 'Low cache hit ratio (' || v_cache_hit_ratio || '%) - consider adding indexes');
        END IF;
        
        IF v_query_record.temp_blks_read > 0 OR v_query_record.temp_blks_written > 0 THEN
            v_suggestions := array_append(v_suggestions, 'Query uses temporary files - increase work_mem or optimize query');
        END IF;
        
        IF v_query_record.stddev_exec_time > (v_query_record.mean_exec_time * 0.5) THEN
            v_suggestions := array_append(v_suggestions, 'High execution time variance - query performance is inconsistent');
        END IF;
        
        IF v_query_record.wal_bytes > (1024 * 1024 * 10) THEN -- 10MB WAL
            v_suggestions := array_append(v_suggestions, 'High WAL generation - consider batching or optimizing write operations');
        END IF;
        
        -- Generate business key and hash key
        v_performance_bk := 'QUERY_PERF_' || v_query_record.query_hash || '_' || 
                           to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24');
        v_performance_hk := util.hash_binary(v_performance_bk);
        
        -- Insert hub record
        INSERT INTO performance.query_performance_h VALUES (
            v_performance_hk, v_performance_bk, p_tenant_hk,
            util.current_load_date(), 'PERFORMANCE_ANALYZER'
        ) ON CONFLICT (query_performance_bk) DO NOTHING;
        
        -- Close any existing open satellite record
        UPDATE performance.query_performance_s 
        SET load_end_date = util.current_load_date()
        WHERE query_performance_hk = v_performance_hk 
        AND load_end_date IS NULL
        AND hash_diff != util.hash_binary(v_performance_bk || v_rating || v_query_record.mean_exec_time::text);
        
        -- Insert new satellite record
        INSERT INTO performance.query_performance_s VALUES (
            v_performance_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_performance_bk || v_rating || v_query_record.mean_exec_time::text),
            v_query_record.query_hash,
            v_query_record.query_text,
            current_database(),
            SESSION_USER,
            v_query_record.calls,
            v_query_record.total_exec_time,
            v_query_record.mean_exec_time,
            v_query_record.min_exec_time,
            v_query_record.max_exec_time,
            v_query_record.stddev_exec_time,
            v_query_record.rows,
            v_query_record.rows,
            v_query_record.shared_blks_hit,
            v_query_record.shared_blks_read,
            v_query_record.shared_blks_dirtied,
            v_query_record.shared_blks_written,
            v_query_record.local_blks_hit,
            v_query_record.local_blks_read,
            v_query_record.local_blks_dirtied,
            v_query_record.local_blks_written,
            v_query_record.temp_blks_read,
            v_query_record.temp_blks_written,
            v_query_record.blk_read_time,
            v_query_record.blk_write_time,
            v_query_record.wal_records,
            v_query_record.wal_fpi,
            v_query_record.wal_bytes,
            0, -- jit_functions
            0, -- jit_generation_time
            0, -- jit_inlining_time
            0, -- jit_optimization_time
            0, -- jit_emission_time
            v_rating,
            v_suggestions,
            NULL, -- execution_plan_hash
            NULL, -- index_usage_efficiency
            v_cache_hit_ratio,
            CURRENT_TIMESTAMP - (p_analysis_period_hours || ' hours')::INTERVAL,
            CURRENT_TIMESTAMP,
            'PERFORMANCE_ANALYZER'
        ) ON CONFLICT (query_performance_hk, load_date) DO NOTHING;
        
        -- Return query analysis results
        RETURN QUERY SELECT 
            v_query_record.query_hash,
            v_query_record.query_text,
            v_rating,
            v_query_record.mean_exec_time,
            v_query_record.calls,
            v_suggestions;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to analyze index usage and provide optimization recommendations
CREATE OR REPLACE FUNCTION performance.analyze_index_optimization(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_schema_filter VARCHAR(100) DEFAULT NULL
) RETURNS TABLE (
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    index_name VARCHAR(100),
    optimization_recommendation VARCHAR(50),
    efficiency_score DECIMAL(5,2),
    maintenance_priority VARCHAR(20)
) AS $$
DECLARE
    v_index_record RECORD;
    v_optimization_hk BYTEA;
    v_optimization_bk VARCHAR(255);
    v_efficiency_score DECIMAL(5,2);
    v_recommendation VARCHAR(50);
    v_priority VARCHAR(20);
    v_bloat_pct DECIMAL(5,2);
    v_usage_ratio DECIMAL(5,2);
BEGIN
    -- Analyze indexes from pg_stat_user_indexes and pg_statio_user_indexes
    FOR v_index_record IN 
        SELECT 
            schemaname,
            tablename,
            indexrelname,
            idx_scan,
            idx_tup_read,
            idx_tup_fetch,
            pg_relation_size(indexrelid) as index_size,
            pg_relation_size(relid) as table_size,
            COALESCE(seq_scan, 0) as seq_scan,
            COALESCE(seq_tup_read, 0) as seq_tup_read
        FROM pg_stat_user_indexes psui
        LEFT JOIN pg_stat_user_tables psut ON psui.relid = psut.relid
        WHERE (p_schema_filter IS NULL OR psui.schemaname = p_schema_filter)
        AND psui.schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY psui.schemaname, psui.tablename, psui.indexrelname
    LOOP
        -- Calculate index efficiency metrics
        v_usage_ratio := CASE 
            WHEN (v_index_record.idx_scan + v_index_record.seq_scan) > 0 
            THEN ROUND((v_index_record.idx_scan::DECIMAL / 
                       (v_index_record.idx_scan + v_index_record.seq_scan)) * 100, 2)
            ELSE 0.0
        END;
        
        -- Estimate index bloat (simplified calculation)
        v_bloat_pct := CASE 
            WHEN v_index_record.index_size > 0 
            THEN LEAST(50.0, GREATEST(0.0, 
                (v_index_record.index_size - (v_index_record.idx_tup_read * 100))::DECIMAL / 
                v_index_record.index_size * 100))
            ELSE 0.0
        END;
        
        -- Calculate overall efficiency score
        v_efficiency_score := ROUND(
            (v_usage_ratio * 0.6) + 
            ((100 - v_bloat_pct) * 0.3) + 
            (CASE WHEN v_index_record.idx_scan > 100 THEN 10 ELSE v_index_record.idx_scan / 10.0 END)
        , 2);
        
        -- Determine optimization recommendation
        IF v_index_record.idx_scan = 0 AND v_index_record.index_size > 1024*1024 THEN -- Unused index > 1MB
            v_recommendation := 'DROP';
            v_priority := 'HIGH';
        ELSIF v_bloat_pct > 30 THEN
            v_recommendation := 'REINDEX';
            v_priority := 'MEDIUM';
        ELSIF v_usage_ratio < 10 AND v_index_record.seq_scan > 1000 THEN
            v_recommendation := 'ANALYZE';
            v_priority := 'MEDIUM';
        ELSIF v_efficiency_score < 50 THEN
            v_recommendation := 'REBUILD';
            v_priority := 'LOW';
        ELSE
            v_recommendation := 'MAINTAIN';
            v_priority := 'LOW';
        END IF;
        
        -- Generate business key and hash key
        v_optimization_bk := 'INDEX_OPT_' || v_index_record.schemaname || '_' || 
                            v_index_record.tablename || '_' || 
                            COALESCE(v_index_record.indexrelname, 'TABLE') || '_' ||
                            to_char(CURRENT_TIMESTAMP, 'YYYYMMDD');
        v_optimization_hk := util.hash_binary(v_optimization_bk);
        
        -- Insert hub record
        INSERT INTO performance.index_optimization_h VALUES (
            v_optimization_hk, v_optimization_bk, p_tenant_hk,
            util.current_load_date(), 'INDEX_ANALYZER'
        ) ON CONFLICT (index_optimization_bk) DO NOTHING;
        
        -- Close any existing open satellite record
        UPDATE performance.index_optimization_s 
        SET load_end_date = util.current_load_date()
        WHERE index_optimization_hk = v_optimization_hk 
        AND load_end_date IS NULL
        AND hash_diff != util.hash_binary(v_optimization_bk || v_recommendation || v_efficiency_score::text);
        
        -- Insert new satellite record
        INSERT INTO performance.index_optimization_s VALUES (
            v_optimization_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_optimization_bk || v_recommendation || v_efficiency_score::text),
            v_index_record.schemaname,
            v_index_record.tablename,
            v_index_record.indexrelname,
            'BTREE', -- Default index type
            ARRAY[]::TEXT[], -- index_columns - would need additional query to populate
            v_index_record.index_size,
            v_index_record.table_size,
            v_index_record.idx_scan,
            v_index_record.idx_tup_read,
            v_index_record.idx_tup_fetch,
            v_index_record.seq_scan,
            v_index_record.seq_tup_read,
            v_usage_ratio,
            v_efficiency_score,
            v_bloat_pct,
            CASE 
                WHEN v_bloat_pct > 40 THEN 'CRITICAL'
                WHEN v_bloat_pct > 25 THEN 'HIGH'
                WHEN v_bloat_pct > 10 THEN 'MEDIUM'
                ELSE 'LOW'
            END,
            NULL, -- last_vacuum
            NULL, -- last_analyze
            NULL, -- last_autoanalyze
            v_recommendation,
            NULL, -- recommended_index_definition
            CASE 
                WHEN v_recommendation = 'DROP' THEN 5.0
                WHEN v_recommendation = 'REINDEX' THEN 15.0
                WHEN v_recommendation = 'REBUILD' THEN 10.0
                ELSE 2.0
            END, -- estimated_performance_gain
            v_priority,
            CURRENT_TIMESTAMP,
            'INDEX_ANALYZER'
        ) ON CONFLICT (index_optimization_hk, load_date) DO NOTHING;
        
        -- Return index analysis results
        RETURN QUERY SELECT 
            v_index_record.schemaname,
            v_index_record.tablename,
            v_index_record.indexrelname,
            v_recommendation,
            v_efficiency_score,
            v_priority;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to analyze connection pool performance
CREATE OR REPLACE FUNCTION performance.analyze_connection_pool(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    pool_name VARCHAR(100),
    current_utilization_pct DECIMAL(5,2),
    efficiency_score DECIMAL(5,2),
    recommended_max_connections INTEGER
) AS $$
DECLARE
    v_pool_record RECORD;
    v_pool_hk BYTEA;
    v_pool_bk VARCHAR(255);
    v_utilization_pct DECIMAL(5,2);
    v_efficiency_score DECIMAL(5,2);
    v_recommended_max INTEGER;
    v_max_connections INTEGER;
    v_current_connections INTEGER;
    v_active_connections INTEGER;
    v_idle_connections INTEGER;
    v_waiting_connections INTEGER;
BEGIN
    -- Get current connection statistics
    SELECT 
        current_setting('max_connections')::INTEGER,
        COUNT(*),
        COUNT(*) FILTER (WHERE state = 'active'),
        COUNT(*) FILTER (WHERE state = 'idle'),
        0 -- waiting connections - would need pgbouncer integration
    INTO v_max_connections, v_current_connections, v_active_connections, 
         v_idle_connections, v_waiting_connections
    FROM pg_stat_activity
    WHERE backend_type = 'client backend';
    
    -- Calculate utilization and efficiency
    v_utilization_pct := ROUND((v_current_connections::DECIMAL / v_max_connections) * 100, 2);
    
    v_efficiency_score := ROUND(
        CASE 
            WHEN v_utilization_pct > 90 THEN 30 -- Over-utilized
            WHEN v_utilization_pct > 80 THEN 70 -- High utilization
            WHEN v_utilization_pct > 60 THEN 90 -- Good utilization
            WHEN v_utilization_pct > 40 THEN 85 -- Moderate utilization
            WHEN v_utilization_pct > 20 THEN 75 -- Low utilization
            ELSE 50 -- Very low utilization
        END +
        CASE 
            WHEN v_idle_connections > (v_active_connections * 2) THEN -20 -- Too many idle
            WHEN v_idle_connections > v_active_connections THEN -10 -- Some idle
            ELSE 0 -- Good active/idle ratio
        END
    , 2);
    
    -- Calculate recommended max connections
    v_recommended_max := CASE 
        WHEN v_utilization_pct > 90 THEN ROUND(v_max_connections * 1.2)
        WHEN v_utilization_pct < 30 THEN ROUND(v_max_connections * 0.8)
        ELSE v_max_connections
    END;
    
    -- Generate business key and hash key
    v_pool_bk := 'CONN_POOL_MAIN_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24');
    v_pool_hk := util.hash_binary(v_pool_bk);
    
    -- Insert hub record
    INSERT INTO performance.connection_pool_h VALUES (
        v_pool_hk, v_pool_bk, p_tenant_hk,
        util.current_load_date(), 'CONNECTION_ANALYZER'
    ) ON CONFLICT (connection_pool_bk) DO NOTHING;
    
    -- Close any existing open satellite record
    UPDATE performance.connection_pool_s 
    SET load_end_date = util.current_load_date()
    WHERE connection_pool_hk = v_pool_hk 
    AND load_end_date IS NULL
    AND hash_diff != util.hash_binary(v_pool_bk || v_utilization_pct::text || v_efficiency_score::text);
    
    -- Insert new satellite record
    INSERT INTO performance.connection_pool_s VALUES (
        v_pool_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_pool_bk || v_utilization_pct::text || v_efficiency_score::text),
        'main_pool',
        v_max_connections,
        v_current_connections,
        v_active_connections,
        v_idle_connections,
        v_waiting_connections,
        v_utilization_pct,
        NULL, -- avg_connection_duration_ms
        NULL, -- max_connection_duration_ms
        0, -- connection_timeouts
        0, -- connection_errors
        v_efficiency_score,
        v_recommended_max,
        jsonb_build_object(
            'pool_mode', 'session',
            'max_client_conn', v_recommended_max * 2,
            'default_pool_size', v_recommended_max,
            'reserve_pool_size', ROUND(v_recommended_max * 0.1)
        ),
        'Connection pool analysis based on current usage patterns',
        CURRENT_TIMESTAMP,
        'CONNECTION_ANALYZER'
    ) ON CONFLICT (connection_pool_hk, load_date) DO NOTHING;
    
    -- Return connection pool analysis results
    RETURN QUERY SELECT 
        'main_pool'::VARCHAR(100),
        v_utilization_pct,
        v_efficiency_score,
        v_recommended_max;
END;
$$ LANGUAGE plpgsql;

-- Function to analyze cache performance
CREATE OR REPLACE FUNCTION performance.analyze_cache_performance(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    cache_type VARCHAR(50),
    hit_ratio DECIMAL(5,2),
    efficiency_score DECIMAL(5,2),
    optimization_recommendations TEXT[]
) AS $$
DECLARE
    v_cache_record RECORD;
    v_cache_hk BYTEA;
    v_cache_bk VARCHAR(255);
    v_shared_buffers_hit_ratio DECIMAL(5,2);
    v_shared_buffers_size BIGINT;
    v_recommendations TEXT[];
BEGIN
    -- Analyze shared buffer cache
    SELECT 
        ROUND(100.0 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2),
        current_setting('shared_buffers')::text
    INTO v_shared_buffers_hit_ratio, v_shared_buffers_size
    FROM pg_stat_database;
    
    -- Generate recommendations for shared buffers
    v_recommendations := ARRAY[]::TEXT[];
    
    IF v_shared_buffers_hit_ratio < 95 THEN
        v_recommendations := array_append(v_recommendations, 'Consider increasing shared_buffers size');
    END IF;
    
    IF v_shared_buffers_hit_ratio < 90 THEN
        v_recommendations := array_append(v_recommendations, 'Review query patterns and add missing indexes');
    END IF;
    
    IF v_shared_buffers_hit_ratio > 99.5 THEN
        v_recommendations := array_append(v_recommendations, 'Excellent cache performance - monitor for changes');
    END IF;
    
    -- Generate business key and hash key for shared buffers
    v_cache_bk := 'CACHE_SHARED_BUFFERS_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24');
    v_cache_hk := util.hash_binary(v_cache_bk);
    
    -- Insert hub record
    INSERT INTO performance.cache_optimization_h VALUES (
        v_cache_hk, v_cache_bk, p_tenant_hk,
        util.current_load_date(), 'CACHE_ANALYZER'
    ) ON CONFLICT (cache_optimization_bk) DO NOTHING;
    
    -- Insert satellite record for shared buffers
    INSERT INTO performance.cache_optimization_s VALUES (
        v_cache_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_cache_bk || v_shared_buffers_hit_ratio::text),
        'SHARED_BUFFERS',
        pg_size_bytes(current_setting('shared_buffers')),
        NULL, -- cache_used_bytes
        v_shared_buffers_hit_ratio,
        100.0 - v_shared_buffers_hit_ratio,
        0, -- cache_evictions
        CASE 
            WHEN v_shared_buffers_hit_ratio >= 99 THEN 95.0
            WHEN v_shared_buffers_hit_ratio >= 95 THEN 85.0
            WHEN v_shared_buffers_hit_ratio >= 90 THEN 70.0
            WHEN v_shared_buffers_hit_ratio >= 80 THEN 50.0
            ELSE 30.0
        END,
        jsonb_build_object(
            'total_buffers', current_setting('shared_buffers'),
            'effective_cache_size', current_setting('effective_cache_size'),
            'work_mem', current_setting('work_mem')
        ),
        ARRAY[]::TEXT[], -- most_accessed_objects
        jsonb_build_object(
            'buffer_pressure', CASE WHEN v_shared_buffers_hit_ratio < 90 THEN 'HIGH' ELSE 'LOW' END,
            'memory_pressure', 'NORMAL'
        ),
        CASE 
            WHEN v_shared_buffers_hit_ratio < 90 THEN pg_size_bytes(current_setting('shared_buffers')) * 2
            ELSE pg_size_bytes(current_setting('shared_buffers'))
        END,
        v_recommendations,
        CURRENT_TIMESTAMP,
        'CACHE_ANALYZER'
    ) ON CONFLICT (cache_optimization_hk, load_date) DO NOTHING;
    
    -- Return cache analysis results
    RETURN QUERY SELECT 
        'SHARED_BUFFERS'::VARCHAR(50),
        v_shared_buffers_hit_ratio,
        CASE 
            WHEN v_shared_buffers_hit_ratio >= 99 THEN 95.0
            WHEN v_shared_buffers_hit_ratio >= 95 THEN 85.0
            WHEN v_shared_buffers_hit_ratio >= 90 THEN 70.0
            WHEN v_shared_buffers_hit_ratio >= 80 THEN 50.0
            ELSE 30.0
        END,
        v_recommendations;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- PERFORMANCE OPTIMIZATION DASHBOARD VIEWS
-- =====================================================================================

-- Performance optimization dashboard view
CREATE OR REPLACE VIEW performance.optimization_dashboard AS
WITH query_performance AS (
    SELECT 
        'Query Performance' as optimization_category,
        COUNT(*) as total_queries,
        COUNT(*) FILTER (WHERE performance_rating = 'CRITICAL') as critical_queries,
        COUNT(*) FILTER (WHERE performance_rating = 'POOR') as poor_queries,
        ROUND(AVG(mean_exec_time), 2) as avg_execution_time,
        ROUND(MAX(mean_exec_time), 2) as max_execution_time
    FROM performance.query_performance_s 
    WHERE load_end_date IS NULL
    AND measurement_period_end >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
),
index_optimization AS (
    SELECT 
        'Index Optimization' as optimization_category,
        COUNT(*) as total_indexes,
        COUNT(*) FILTER (WHERE optimization_recommendation = 'DROP') as unused_indexes,
        COUNT(*) FILTER (WHERE optimization_recommendation = 'REINDEX') as bloated_indexes,
        ROUND(AVG(index_efficiency_score), 2) as avg_efficiency_score,
        COUNT(*) FILTER (WHERE maintenance_priority = 'HIGH') as high_priority_items
    FROM performance.index_optimization_s 
    WHERE load_end_date IS NULL
    AND analysis_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
),
connection_performance AS (
    SELECT 
        'Connection Pool' as optimization_category,
        ROUND(AVG(connection_utilization_pct), 2) as avg_utilization,
        ROUND(AVG(pool_efficiency_score), 2) as avg_efficiency,
        MAX(current_connections) as peak_connections,
        AVG(recommended_max_connections) as recommended_max
    FROM performance.connection_pool_s 
    WHERE load_end_date IS NULL
    AND measurement_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
),
cache_performance AS (
    SELECT 
        'Cache Performance' as optimization_category,
        ROUND(AVG(cache_hit_ratio), 2) as avg_hit_ratio,
        ROUND(AVG(cache_efficiency_score), 2) as avg_efficiency,
        COUNT(*) FILTER (WHERE cache_hit_ratio < 90) as underperforming_caches
    FROM performance.cache_optimization_s 
    WHERE load_end_date IS NULL
    AND measurement_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
)
SELECT 
    qp.optimization_category,
    qp.total_queries as metric_count,
    qp.critical_queries as critical_items,
    qp.avg_execution_time as primary_metric,
    'ms' as metric_unit,
    CASE 
        WHEN qp.critical_queries > 0 THEN 'CRITICAL'
        WHEN qp.poor_queries > 5 THEN 'WARNING'
        ELSE 'NORMAL'
    END as status
FROM query_performance qp

UNION ALL

SELECT 
    io.optimization_category,
    io.total_indexes,
    io.high_priority_items,
    io.avg_efficiency_score,
    'score',
    CASE 
        WHEN io.unused_indexes > 10 THEN 'WARNING'
        WHEN io.bloated_indexes > 5 THEN 'WARNING'
        ELSE 'NORMAL'
    END
FROM index_optimization io

UNION ALL

SELECT 
    cp.optimization_category,
    1, -- Single connection pool
    CASE WHEN cp.avg_utilization > 90 THEN 1 ELSE 0 END,
    cp.avg_utilization,
    '%',
    CASE 
        WHEN cp.avg_utilization > 95 THEN 'CRITICAL'
        WHEN cp.avg_utilization > 85 THEN 'WARNING'
        ELSE 'NORMAL'
    END
FROM connection_performance cp

UNION ALL

SELECT 
    cache.optimization_category,
    1, -- Cache analysis
    cache.underperforming_caches,
    cache.avg_hit_ratio,
    '%',
    CASE 
        WHEN cache.avg_hit_ratio < 85 THEN 'CRITICAL'
        WHEN cache.avg_hit_ratio < 95 THEN 'WARNING'
        ELSE 'NORMAL'
    END
FROM cache_performance cache

ORDER BY optimization_category;

-- Grant permissions for performance functions
GRANT EXECUTE ON FUNCTION performance.analyze_query_performance TO postgres;
GRANT EXECUTE ON FUNCTION performance.analyze_index_optimization TO postgres;
GRANT EXECUTE ON FUNCTION performance.analyze_connection_pool TO postgres;
GRANT EXECUTE ON FUNCTION performance.analyze_cache_performance TO postgres;

-- Grant SELECT permissions on performance views
GRANT SELECT ON performance.optimization_dashboard TO postgres;

-- =====================================================================================
-- COMMENTS AND DOCUMENTATION
-- =====================================================================================

COMMENT ON SCHEMA performance IS 
'Performance optimization schema containing query analysis, index optimization, connection pool management, and cache performance tracking for production database optimization.';

COMMENT ON TABLE performance.query_performance_h IS
'Hub table for query performance analysis tracking execution times, resource usage, and optimization recommendations with tenant isolation support.';

COMMENT ON TABLE performance.index_optimization_h IS
'Hub table for index optimization analysis including usage statistics, bloat detection, and maintenance recommendations.';

COMMENT ON FUNCTION performance.analyze_query_performance IS
'Analyzes query performance from pg_stat_statements and provides optimization recommendations including execution time analysis and resource usage patterns.';

COMMENT ON VIEW performance.optimization_dashboard IS
'Real-time performance optimization dashboard providing current status across query performance, index optimization, connection pooling, and cache efficiency.';

-- =====================================================================================
-- SCRIPT COMPLETION
-- =====================================================================================

-- Log successful completion
DO $$
BEGIN
    RAISE NOTICE 'Step 5: Performance Optimization Infrastructure deployment completed successfully at %', CURRENT_TIMESTAMP;
    RAISE NOTICE 'Created performance schema with % tables and % functions', 
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'performance'),
        (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'performance');
END
$$; 