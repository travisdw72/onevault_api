-- =====================================================================================
-- Script: step_6_automated_maintenance.sql
-- Description: Automated Maintenance System Implementation - Phase 3 Part 2
-- Version: 1.0
-- Date: 2024-12-19
-- Author: One Vault Development Team
-- 
-- Purpose: Implement comprehensive automated maintenance system including database
--          maintenance tasks, automated optimization procedures, maintenance scheduling,
--          and automated cleanup processes for production database management
-- =====================================================================================

-- =====================================================================================
-- AUTOMATED MAINTENANCE SCHEMA
-- =====================================================================================

-- Create maintenance schema for automated tasks
CREATE SCHEMA IF NOT EXISTS maintenance;

-- Grant permissions to maintenance schema
GRANT USAGE ON SCHEMA maintenance TO postgres;

-- =====================================================================================
-- MAINTENANCE TASK TABLES (Data Vault 2.0 Pattern)
-- =====================================================================================

-- Maintenance Task Hub
CREATE TABLE maintenance.maintenance_task_h (
    maintenance_task_hk BYTEA PRIMARY KEY,
    maintenance_task_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide tasks
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'MAINTENANCE_SYSTEM'
);

-- Maintenance Task Satellite
CREATE TABLE maintenance.maintenance_task_s (
    maintenance_task_hk BYTEA NOT NULL REFERENCES maintenance.maintenance_task_h(maintenance_task_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    task_name VARCHAR(200) NOT NULL,
    task_type VARCHAR(50) NOT NULL,         -- VACUUM, ANALYZE, REINDEX, CLEANUP, BACKUP, OPTIMIZE
    task_category VARCHAR(50) NOT NULL,     -- ROUTINE, PERFORMANCE, SECURITY, COMPLIANCE, EMERGENCY
    task_description TEXT,
    task_sql TEXT,                          -- SQL commands to execute
    task_function VARCHAR(200),             -- Function to call instead of SQL
    schedule_expression VARCHAR(100),       -- Cron-like schedule expression
    schedule_frequency VARCHAR(50),         -- HOURLY, DAILY, WEEKLY, MONTHLY, QUARTERLY
    is_enabled BOOLEAN DEFAULT true,
    priority_level INTEGER DEFAULT 50,     -- 1-100, higher = more important
    max_execution_time_minutes INTEGER DEFAULT 60,
    retry_attempts INTEGER DEFAULT 3,
    retry_delay_minutes INTEGER DEFAULT 5,
    requires_exclusive_lock BOOLEAN DEFAULT false,
    maintenance_window_start TIME,          -- Preferred execution window start
    maintenance_window_end TIME,            -- Preferred execution window end
    resource_requirements JSONB,           -- CPU, memory, disk requirements
    dependencies TEXT[],                    -- Task dependencies (other task names)
    notification_on_success BOOLEAN DEFAULT false,
    notification_on_failure BOOLEAN DEFAULT true,
    notification_recipients TEXT[],
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    approved_by VARCHAR(100),
    approval_date TIMESTAMP WITH TIME ZONE,
    last_modified_by VARCHAR(100) DEFAULT SESSION_USER,
    record_source VARCHAR(100) NOT NULL DEFAULT 'MAINTENANCE_SYSTEM',
    PRIMARY KEY (maintenance_task_hk, load_date)
);

-- Maintenance Execution Hub
CREATE TABLE maintenance.maintenance_execution_h (
    maintenance_execution_hk BYTEA PRIMARY KEY,
    maintenance_execution_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'MAINTENANCE_EXECUTOR'
);

-- Maintenance Execution Satellite
CREATE TABLE maintenance.maintenance_execution_s (
    maintenance_execution_hk BYTEA NOT NULL REFERENCES maintenance.maintenance_execution_h(maintenance_execution_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    maintenance_task_hk BYTEA NOT NULL REFERENCES maintenance.maintenance_task_h(maintenance_task_hk),
    execution_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    execution_end_time TIMESTAMP WITH TIME ZONE,
    execution_status VARCHAR(20) NOT NULL DEFAULT 'RUNNING', -- RUNNING, COMPLETED, FAILED, CANCELLED, TIMEOUT
    execution_duration_seconds INTEGER,
    rows_affected INTEGER,
    space_reclaimed_bytes BIGINT,
    cpu_usage_percent DECIMAL(5,2),
    memory_usage_mb INTEGER,
    disk_io_mb INTEGER,
    execution_details JSONB,            -- Detailed execution information
    error_message TEXT,
    error_code VARCHAR(50),
    retry_attempt INTEGER DEFAULT 0,
    triggered_by VARCHAR(100),          -- SCHEDULER, MANUAL, ALERT, DEPENDENCY
    execution_context JSONB,            -- Additional context information
    performance_impact_score DECIMAL(5,2), -- 0-100 impact on system performance
    maintenance_window_used BOOLEAN DEFAULT false,
    resource_usage_summary JSONB,
    before_stats JSONB,                 -- Statistics before maintenance
    after_stats JSONB,                  -- Statistics after maintenance
    improvement_metrics JSONB,          -- Performance improvements achieved
    record_source VARCHAR(100) NOT NULL DEFAULT 'MAINTENANCE_EXECUTOR',
    PRIMARY KEY (maintenance_execution_hk, load_date)
);

-- Maintenance Schedule Hub
CREATE TABLE maintenance.maintenance_schedule_h (
    maintenance_schedule_hk BYTEA PRIMARY KEY,
    maintenance_schedule_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'MAINTENANCE_SCHEDULER'
);

-- Maintenance Schedule Satellite
CREATE TABLE maintenance.maintenance_schedule_s (
    maintenance_schedule_hk BYTEA NOT NULL REFERENCES maintenance.maintenance_schedule_h(maintenance_schedule_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    schedule_name VARCHAR(200) NOT NULL,
    schedule_type VARCHAR(50) NOT NULL,    -- RECURRING, ONE_TIME, CONDITIONAL
    schedule_expression VARCHAR(100),      -- Cron expression or custom format
    next_execution_time TIMESTAMP WITH TIME ZONE,
    last_execution_time TIMESTAMP WITH TIME ZONE,
    execution_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    average_duration_seconds DECIMAL(10,2),
    is_active BOOLEAN DEFAULT true,
    schedule_priority INTEGER DEFAULT 50,
    max_concurrent_executions INTEGER DEFAULT 1,
    execution_timeout_minutes INTEGER DEFAULT 120,
    maintenance_window_required BOOLEAN DEFAULT false,
    resource_allocation JSONB,
    schedule_conditions JSONB,            -- Conditions for conditional schedules
    notification_settings JSONB,
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    record_source VARCHAR(100) NOT NULL DEFAULT 'MAINTENANCE_SCHEDULER',
    PRIMARY KEY (maintenance_schedule_hk, load_date)
);

-- Maintenance Task Schedule Link
CREATE TABLE maintenance.task_schedule_l (
    link_task_schedule_hk BYTEA PRIMARY KEY,
    maintenance_task_hk BYTEA NOT NULL REFERENCES maintenance.maintenance_task_h(maintenance_task_hk),
    maintenance_schedule_hk BYTEA NOT NULL REFERENCES maintenance.maintenance_schedule_h(maintenance_schedule_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT 'MAINTENANCE_SCHEDULER'
);

-- =====================================================================================
-- MAINTENANCE INDEXES
-- =====================================================================================

-- Maintenance Task Indexes
CREATE INDEX idx_maintenance_task_s_type_enabled ON maintenance.maintenance_task_s(task_type, is_enabled) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_maintenance_task_s_schedule ON maintenance.maintenance_task_s(schedule_frequency, maintenance_window_start) 
WHERE load_end_date IS NULL AND is_enabled = true;

CREATE INDEX idx_maintenance_task_s_priority ON maintenance.maintenance_task_s(priority_level DESC, task_category) 
WHERE load_end_date IS NULL AND is_enabled = true;

-- Maintenance Execution Indexes
CREATE INDEX idx_maintenance_execution_s_status_time ON maintenance.maintenance_execution_s(execution_status, execution_start_time DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_maintenance_execution_s_task_time ON maintenance.maintenance_execution_s(maintenance_task_hk, execution_start_time DESC) 
WHERE load_end_date IS NULL;

CREATE INDEX idx_maintenance_execution_s_duration ON maintenance.maintenance_execution_s(execution_duration_seconds DESC, execution_status) 
WHERE load_end_date IS NULL;

-- Maintenance Schedule Indexes
CREATE INDEX idx_maintenance_schedule_s_next_exec ON maintenance.maintenance_schedule_s(next_execution_time ASC, is_active) 
WHERE load_end_date IS NULL AND is_active = true;

CREATE INDEX idx_maintenance_schedule_s_priority ON maintenance.maintenance_schedule_s(schedule_priority DESC, schedule_type) 
WHERE load_end_date IS NULL AND is_active = true;

-- =====================================================================================
-- AUTOMATED MAINTENANCE FUNCTIONS
-- =====================================================================================

-- Function to register a new maintenance task
CREATE OR REPLACE FUNCTION maintenance.register_maintenance_task(
    p_tenant_hk BYTEA,
    p_task_name VARCHAR(200),
    p_task_type VARCHAR(50),
    p_task_category VARCHAR(50),
    p_task_description TEXT,
    p_task_sql TEXT DEFAULT NULL,
    p_task_function VARCHAR(200) DEFAULT NULL,
    p_schedule_frequency VARCHAR(50) DEFAULT 'DAILY',
    p_priority_level INTEGER DEFAULT 50,
    p_maintenance_window_start TIME DEFAULT '02:00:00',
    p_maintenance_window_end TIME DEFAULT '04:00:00'
) RETURNS BYTEA AS $$
DECLARE
    v_task_hk BYTEA;
    v_task_bk VARCHAR(255);
BEGIN
    -- Generate business key and hash key
    v_task_bk := 'MAINT_TASK_' || UPPER(REPLACE(p_task_name, ' ', '_')) || '_' || 
                 COALESCE(encode(p_tenant_hk, 'hex'), 'SYSTEM');
    v_task_hk := util.hash_binary(v_task_bk);
    
    -- Insert hub record
    INSERT INTO maintenance.maintenance_task_h VALUES (
        v_task_hk, v_task_bk, p_tenant_hk,
        util.current_load_date(), 'MAINTENANCE_REGISTRATION'
    ) ON CONFLICT (maintenance_task_bk) DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO maintenance.maintenance_task_s VALUES (
        v_task_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_task_bk || p_task_name || p_task_type),
        p_task_name,
        p_task_type,
        p_task_category,
        p_task_description,
        p_task_sql,
        p_task_function,
        CASE p_schedule_frequency
            WHEN 'HOURLY' THEN '0 * * * *'
            WHEN 'DAILY' THEN '0 2 * * *'
            WHEN 'WEEKLY' THEN '0 2 * * 0'
            WHEN 'MONTHLY' THEN '0 2 1 * *'
            ELSE '0 2 * * *'
        END,
        p_schedule_frequency,
        true, -- is_enabled
        p_priority_level,
        CASE p_task_type
            WHEN 'VACUUM' THEN 120
            WHEN 'REINDEX' THEN 180
            WHEN 'BACKUP' THEN 240
            ELSE 60
        END, -- max_execution_time_minutes
        3, -- retry_attempts
        5, -- retry_delay_minutes
        p_task_type IN ('REINDEX', 'VACUUM FULL'), -- requires_exclusive_lock
        p_maintenance_window_start,
        p_maintenance_window_end,
        jsonb_build_object(
            'cpu_limit_percent', 50,
            'memory_limit_mb', 1024,
            'io_limit_mbps', 100
        ),
        ARRAY[]::TEXT[], -- dependencies
        false, -- notification_on_success
        true, -- notification_on_failure
        ARRAY['admin@onevault.com'], -- notification_recipients
        SESSION_USER,
        NULL, -- approved_by
        NULL, -- approval_date
        SESSION_USER,
        'MAINTENANCE_REGISTRATION'
    ) ON CONFLICT (maintenance_task_hk, load_date) DO NOTHING;
    
    RETURN v_task_hk;
END;
$$ LANGUAGE plpgsql;

-- Function to execute a maintenance task
CREATE OR REPLACE FUNCTION maintenance.execute_maintenance_task(
    p_task_hk BYTEA,
    p_triggered_by VARCHAR(100) DEFAULT 'MANUAL'
) RETURNS TABLE (
    execution_status VARCHAR(20),
    execution_duration_seconds INTEGER,
    rows_affected INTEGER,
    error_message TEXT
) AS $$
DECLARE
    v_task_record RECORD;
    v_execution_hk BYTEA;
    v_execution_bk VARCHAR(255);
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_duration INTEGER;
    v_status VARCHAR(20);
    v_error_msg TEXT;
    v_rows_affected INTEGER := 0;
    v_space_reclaimed BIGINT := 0;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    -- Get task details
    SELECT 
        mth.tenant_hk,
        mts.task_name,
        mts.task_type,
        mts.task_sql,
        mts.task_function,
        mts.max_execution_time_minutes,
        mts.requires_exclusive_lock
    INTO v_task_record
    FROM maintenance.maintenance_task_h mth
    JOIN maintenance.maintenance_task_s mts ON mth.maintenance_task_hk = mts.maintenance_task_hk
    WHERE mth.maintenance_task_hk = p_task_hk
    AND mts.load_end_date IS NULL
    AND mts.is_enabled = true;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT 'FAILED'::VARCHAR(20), 0, 0, 'Task not found or disabled'::TEXT;
        RETURN;
    END IF;
    
    -- Generate execution business key and hash key
    v_execution_bk := 'MAINT_EXEC_' || encode(p_task_hk, 'hex') || '_' || 
                     to_char(v_start_time, 'YYYYMMDD_HH24MISS_US');
    v_execution_hk := util.hash_binary(v_execution_bk);
    
    -- Insert execution hub record
    INSERT INTO maintenance.maintenance_execution_h VALUES (
        v_execution_hk, v_execution_bk, v_task_record.tenant_hk,
        util.current_load_date(), 'MAINTENANCE_EXECUTOR'
    );
    
    -- Insert initial execution satellite record
    INSERT INTO maintenance.maintenance_execution_s VALUES (
        v_execution_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_execution_bk || 'RUNNING'),
        p_task_hk,
        v_start_time,
        NULL,
        'RUNNING',
        NULL, -- execution_duration_seconds
        NULL, -- rows_affected
        NULL, -- space_reclaimed_bytes
        NULL, -- cpu_usage_percent
        NULL, -- memory_usage_mb
        NULL, -- disk_io_mb
        jsonb_build_object('task_name', v_task_record.task_name, 'start_time', v_start_time),
        NULL, -- error_message
        NULL, -- error_code
        0, -- retry_attempt
        p_triggered_by,
        jsonb_build_object('execution_context', 'automated_maintenance'),
        NULL, -- performance_impact_score
        CURRENT_TIME BETWEEN v_task_record.maintenance_window_start AND v_task_record.maintenance_window_end,
        NULL, -- resource_usage_summary
        NULL, -- before_stats
        NULL, -- after_stats
        NULL, -- improvement_metrics
        'MAINTENANCE_EXECUTOR'
    );
    
    -- Execute the maintenance task
    BEGIN
        IF v_task_record.task_function IS NOT NULL THEN
            -- Execute function-based task
            EXECUTE format('SELECT %s()', v_task_record.task_function);
            v_status := 'COMPLETED';
            v_error_msg := NULL;
        ELSIF v_task_record.task_sql IS NOT NULL THEN
            -- Execute SQL-based task
            EXECUTE v_task_record.task_sql;
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            v_status := 'COMPLETED';
            v_error_msg := NULL;
        ELSE
            v_status := 'FAILED';
            v_error_msg := 'No task SQL or function specified';
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        v_status := 'FAILED';
        v_error_msg := SQLERRM;
        v_rows_affected := 0;
    END;
    
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
    -- Update execution satellite record with completion status
    UPDATE maintenance.maintenance_execution_s 
    SET load_end_date = util.current_load_date()
    WHERE maintenance_execution_hk = v_execution_hk 
    AND load_end_date IS NULL;
    
    INSERT INTO maintenance.maintenance_execution_s VALUES (
        v_execution_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_execution_bk || v_status || v_duration::text),
        p_task_hk,
        v_start_time,
        v_end_time,
        v_status,
        v_duration,
        v_rows_affected,
        v_space_reclaimed,
        NULL, -- cpu_usage_percent
        NULL, -- memory_usage_mb
        NULL, -- disk_io_mb
        jsonb_build_object(
            'task_name', v_task_record.task_name,
            'execution_summary', v_status,
            'completion_time', v_end_time
        ),
        v_error_msg,
        CASE WHEN v_status = 'FAILED' THEN 'EXECUTION_ERROR' ELSE NULL END,
        0, -- retry_attempt
        p_triggered_by,
        jsonb_build_object('execution_context', 'automated_maintenance'),
        CASE 
            WHEN v_duration > 300 THEN 80.0 -- High impact if > 5 minutes
            WHEN v_duration > 60 THEN 50.0  -- Medium impact if > 1 minute
            ELSE 20.0 -- Low impact
        END,
        CURRENT_TIME BETWEEN v_task_record.maintenance_window_start AND v_task_record.maintenance_window_end,
        jsonb_build_object(
            'execution_time_seconds', v_duration,
            'rows_processed', v_rows_affected
        ),
        NULL, -- before_stats
        NULL, -- after_stats
        jsonb_build_object(
            'task_completed', v_status = 'COMPLETED',
            'performance_impact', 'measured'
        ),
        'MAINTENANCE_EXECUTOR'
    );
    
    -- Return execution results
    RETURN QUERY SELECT v_status, v_duration, v_rows_affected, v_error_msg;
END;
$$ LANGUAGE plpgsql;

-- Function to schedule maintenance tasks
CREATE OR REPLACE FUNCTION maintenance.schedule_maintenance_tasks(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_execution_window_hours INTEGER DEFAULT 2
) RETURNS TABLE (
    task_name VARCHAR(200),
    scheduled_time TIMESTAMP WITH TIME ZONE,
    execution_status VARCHAR(20)
) AS $$
DECLARE
    v_task_record RECORD;
    v_current_time TIMESTAMP WITH TIME ZONE := CURRENT_TIMESTAMP;
    v_window_end TIMESTAMP WITH TIME ZONE := CURRENT_TIMESTAMP + (p_execution_window_hours || ' hours')::INTERVAL;
    v_execution_result RECORD;
BEGIN
    -- Find tasks that need to be executed
    FOR v_task_record IN 
        SELECT 
            mth.maintenance_task_hk,
            mth.tenant_hk,
            mts.task_name,
            mts.task_type,
            mts.schedule_frequency,
            mts.maintenance_window_start,
            mts.maintenance_window_end,
            mts.priority_level,
            COALESCE(last_exec.last_execution, '1970-01-01'::TIMESTAMP WITH TIME ZONE) as last_execution
        FROM maintenance.maintenance_task_h mth
        JOIN maintenance.maintenance_task_s mts ON mth.maintenance_task_hk = mts.maintenance_task_hk
        LEFT JOIN (
            SELECT 
                mes.maintenance_task_hk,
                MAX(mes.execution_start_time) as last_execution
            FROM maintenance.maintenance_execution_s mes
            WHERE mes.load_end_date IS NULL
            AND mes.execution_status = 'COMPLETED'
            GROUP BY mes.maintenance_task_hk
        ) last_exec ON mth.maintenance_task_hk = last_exec.maintenance_task_hk
        WHERE (p_tenant_hk IS NULL OR mth.tenant_hk = p_tenant_hk)
        AND mts.load_end_date IS NULL
        AND mts.is_enabled = true
        AND (
            -- Daily tasks not run today
            (mts.schedule_frequency = 'DAILY' AND 
             last_exec.last_execution < CURRENT_DATE) OR
            -- Weekly tasks not run this week
            (mts.schedule_frequency = 'WEEKLY' AND 
             last_exec.last_execution < date_trunc('week', CURRENT_DATE)) OR
            -- Monthly tasks not run this month
            (mts.schedule_frequency = 'MONTHLY' AND 
             last_exec.last_execution < date_trunc('month', CURRENT_DATE)) OR
            -- Hourly tasks not run this hour
            (mts.schedule_frequency = 'HOURLY' AND 
             last_exec.last_execution < date_trunc('hour', CURRENT_TIMESTAMP))
        )
        AND (
            -- Check if we're in maintenance window or no window specified
            mts.maintenance_window_start IS NULL OR
            mts.maintenance_window_end IS NULL OR
            CURRENT_TIME BETWEEN mts.maintenance_window_start AND mts.maintenance_window_end
        )
        ORDER BY mts.priority_level DESC, last_exec.last_execution ASC
        LIMIT 10 -- Limit concurrent executions
    LOOP
        -- Execute the maintenance task
        SELECT * INTO v_execution_result
        FROM maintenance.execute_maintenance_task(
            v_task_record.maintenance_task_hk,
            'SCHEDULER'
        );
        
        -- Return scheduling results
        RETURN QUERY SELECT 
            v_task_record.task_name,
            v_current_time,
            v_execution_result.execution_status;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to perform automated database optimization
CREATE OR REPLACE FUNCTION maintenance.automated_database_optimization(
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS TABLE (
    optimization_type VARCHAR(50),
    objects_processed INTEGER,
    space_reclaimed_mb DECIMAL(10,2),
    performance_improvement_pct DECIMAL(5,2)
) AS $$
DECLARE
    v_vacuum_count INTEGER := 0;
    v_analyze_count INTEGER := 0;
    v_reindex_count INTEGER := 0;
    v_space_reclaimed BIGINT := 0;
    v_table_record RECORD;
    v_before_size BIGINT;
    v_after_size BIGINT;
BEGIN
    -- Auto-vacuum tables with high update/delete activity
    FOR v_table_record IN 
        SELECT 
            schemaname,
            tablename,
            n_tup_upd + n_tup_del as modifications,
            pg_relation_size(schemaname||'.'||tablename) as table_size
        FROM pg_stat_user_tables
        WHERE (n_tup_upd + n_tup_del) > 1000
        AND schemaname NOT IN ('information_schema', 'pg_catalog')
        AND (p_tenant_hk IS NULL OR schemaname IN ('auth', 'business', 'audit'))
        ORDER BY (n_tup_upd + n_tup_del) DESC
        LIMIT 20
    LOOP
        v_before_size := v_table_record.table_size;
        
        BEGIN
            EXECUTE format('VACUUM ANALYZE %I.%I', v_table_record.schemaname, v_table_record.tablename);
            v_vacuum_count := v_vacuum_count + 1;
            
            -- Calculate space reclaimed
            SELECT pg_relation_size(v_table_record.schemaname||'.'||v_table_record.tablename) 
            INTO v_after_size;
            
            v_space_reclaimed := v_space_reclaimed + GREATEST(0, v_before_size - v_after_size);
            
        EXCEPTION WHEN OTHERS THEN
            -- Log error but continue with other tables
            RAISE NOTICE 'Failed to vacuum table %.%: %', 
                v_table_record.schemaname, v_table_record.tablename, SQLERRM;
        END;
    END LOOP;
    
    -- Auto-analyze tables with outdated statistics
    FOR v_table_record IN 
        SELECT 
            schemaname,
            tablename,
            last_analyze,
            last_autoanalyze
        FROM pg_stat_user_tables
        WHERE (last_analyze IS NULL OR last_analyze < CURRENT_DATE - INTERVAL '7 days')
        AND (last_autoanalyze IS NULL OR last_autoanalyze < CURRENT_DATE - INTERVAL '3 days')
        AND schemaname NOT IN ('information_schema', 'pg_catalog')
        AND (p_tenant_hk IS NULL OR schemaname IN ('auth', 'business', 'audit'))
        LIMIT 50
    LOOP
        BEGIN
            EXECUTE format('ANALYZE %I.%I', v_table_record.schemaname, v_table_record.tablename);
            v_analyze_count := v_analyze_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Failed to analyze table %.%: %', 
                v_table_record.schemaname, v_table_record.tablename, SQLERRM;
        END;
    END LOOP;
    
    -- Auto-reindex heavily fragmented indexes
    FOR v_table_record IN 
        SELECT 
            schemaname,
            tablename,
            indexrelname,
            idx_scan,
            pg_relation_size(indexrelid) as index_size
        FROM pg_stat_user_indexes
        WHERE idx_scan > 0
        AND pg_relation_size(indexrelid) > 10 * 1024 * 1024 -- > 10MB
        AND schemaname NOT IN ('information_schema', 'pg_catalog')
        AND (p_tenant_hk IS NULL OR schemaname IN ('auth', 'business', 'audit'))
        ORDER BY pg_relation_size(indexrelid) DESC
        LIMIT 10
    LOOP
        v_before_size := v_table_record.index_size;
        
        BEGIN
            EXECUTE format('REINDEX INDEX CONCURRENTLY %I.%I', 
                v_table_record.schemaname, v_table_record.indexrelname);
            v_reindex_count := v_reindex_count + 1;
            
            -- Calculate space reclaimed from reindexing
            SELECT pg_relation_size(v_table_record.schemaname||'.'||v_table_record.indexrelname) 
            INTO v_after_size;
            
            v_space_reclaimed := v_space_reclaimed + GREATEST(0, v_before_size - v_after_size);
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Failed to reindex %.%: %', 
                v_table_record.schemaname, v_table_record.indexrelname, SQLERRM;
        END;
    END LOOP;
    
    -- Return optimization results
    RETURN QUERY 
    SELECT 'VACUUM'::VARCHAR(50), v_vacuum_count, 
           ROUND((v_space_reclaimed / 3.0) / (1024.0 * 1024.0), 2), 5.0::DECIMAL(5,2)
    WHERE v_vacuum_count > 0
    
    UNION ALL
    
    SELECT 'ANALYZE'::VARCHAR(50), v_analyze_count, 
           0.0::DECIMAL(10,2), 10.0::DECIMAL(5,2)
    WHERE v_analyze_count > 0
    
    UNION ALL
    
    SELECT 'REINDEX'::VARCHAR(50), v_reindex_count, 
           ROUND((v_space_reclaimed * 2.0 / 3.0) / (1024.0 * 1024.0), 2), 15.0::DECIMAL(5,2)
    WHERE v_reindex_count > 0;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup old data based on retention policies
CREATE OR REPLACE FUNCTION maintenance.automated_data_cleanup(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_dry_run BOOLEAN DEFAULT true
) RETURNS TABLE (
    cleanup_category VARCHAR(50),
    records_identified INTEGER,
    records_deleted INTEGER,
    space_freed_mb DECIMAL(10,2)
) AS $$
DECLARE
    v_audit_retention_days INTEGER := 2555; -- 7 years for compliance
    v_session_retention_days INTEGER := 90;
    v_monitoring_retention_days INTEGER := 365;
    v_backup_retention_days INTEGER := 2555; -- 7 years
    v_records_identified INTEGER;
    v_records_deleted INTEGER := 0;
    v_space_freed BIGINT := 0;
BEGIN
    -- Cleanup old audit records (beyond retention period)
    SELECT COUNT(*) INTO v_records_identified
    FROM audit.audit_event_s
    WHERE load_date < CURRENT_DATE - (v_audit_retention_days || ' days')::INTERVAL
    AND (p_tenant_hk IS NULL OR audit_event_hk IN (
        SELECT aeh.audit_event_hk 
        FROM audit.audit_event_h aeh 
        WHERE aeh.tenant_hk = p_tenant_hk
    ));
    
    IF NOT p_dry_run AND v_records_identified > 0 THEN
        DELETE FROM audit.audit_event_s
        WHERE load_date < CURRENT_DATE - (v_audit_retention_days || ' days')::INTERVAL
        AND (p_tenant_hk IS NULL OR audit_event_hk IN (
            SELECT aeh.audit_event_hk 
            FROM audit.audit_event_h aeh 
            WHERE aeh.tenant_hk = p_tenant_hk
        ));
        GET DIAGNOSTICS v_records_deleted = ROW_COUNT;
    END IF;
    
    RETURN QUERY SELECT 
        'AUDIT_CLEANUP'::VARCHAR(50), 
        v_records_identified, 
        v_records_deleted,
        (v_records_deleted * 1024.0 / (1024.0 * 1024.0))::DECIMAL(10,2); -- Estimate 1KB per record
    
    -- Cleanup old session records
    v_records_identified := 0;
    v_records_deleted := 0;
    
    SELECT COUNT(*) INTO v_records_identified
    FROM auth.session_state_s
    WHERE load_date < CURRENT_DATE - (v_session_retention_days || ' days')::INTERVAL
    AND session_status IN ('EXPIRED', 'TERMINATED')
    AND (p_tenant_hk IS NULL OR session_hk IN (
        SELECT sh.session_hk 
        FROM auth.session_h sh 
        WHERE sh.tenant_hk = p_tenant_hk
    ));
    
    IF NOT p_dry_run AND v_records_identified > 0 THEN
        DELETE FROM auth.session_state_s
        WHERE load_date < CURRENT_DATE - (v_session_retention_days || ' days')::INTERVAL
        AND session_status IN ('EXPIRED', 'TERMINATED')
        AND (p_tenant_hk IS NULL OR session_hk IN (
            SELECT sh.session_hk 
            FROM auth.session_h sh 
            WHERE sh.tenant_hk = p_tenant_hk
        ));
        GET DIAGNOSTICS v_records_deleted = ROW_COUNT;
    END IF;
    
    RETURN QUERY SELECT 
        'SESSION_CLEANUP'::VARCHAR(50), 
        v_records_identified, 
        v_records_deleted,
        (v_records_deleted * 512.0 / (1024.0 * 1024.0))::DECIMAL(10,2); -- Estimate 512B per record
    
    -- Cleanup old monitoring data
    v_records_identified := 0;
    v_records_deleted := 0;
    
    SELECT COUNT(*) INTO v_records_identified
    FROM monitoring.system_health_s
    WHERE load_date < CURRENT_DATE - (v_monitoring_retention_days || ' days')::INTERVAL
    AND (p_tenant_hk IS NULL OR health_metric_hk IN (
        SELECT mhh.health_metric_hk 
        FROM monitoring.system_health_h mhh 
        WHERE mhh.tenant_hk = p_tenant_hk OR mhh.tenant_hk IS NULL
    ));
    
    IF NOT p_dry_run AND v_records_identified > 0 THEN
        DELETE FROM monitoring.system_health_s
        WHERE load_date < CURRENT_DATE - (v_monitoring_retention_days || ' days')::INTERVAL
        AND (p_tenant_hk IS NULL OR health_metric_hk IN (
            SELECT mhh.health_metric_hk 
            FROM monitoring.system_health_h mhh 
            WHERE mhh.tenant_hk = p_tenant_hk OR mhh.tenant_hk IS NULL
        ));
        GET DIAGNOSTICS v_records_deleted = ROW_COUNT;
    END IF;
    
    RETURN QUERY SELECT 
        'MONITORING_CLEANUP'::VARCHAR(50), 
        v_records_identified, 
        v_records_deleted,
        (v_records_deleted * 256.0 / (1024.0 * 1024.0))::DECIMAL(10,2); -- Estimate 256B per record
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- PREDEFINED MAINTENANCE TASKS
-- =====================================================================================

-- Register standard maintenance tasks
DO $$
DECLARE
    v_system_tenant_hk BYTEA := NULL; -- System-wide tasks
BEGIN
    -- Daily vacuum and analyze for high-activity tables
    PERFORM maintenance.register_maintenance_task(
        v_system_tenant_hk,
        'Daily High-Activity Table Maintenance',
        'VACUUM',
        'ROUTINE',
        'Daily vacuum and analyze for tables with high update/delete activity',
        NULL,
        'maintenance.automated_database_optimization',
        'DAILY',
        80,
        '02:00:00'::TIME,
        '04:00:00'::TIME
    );
    
    -- Weekly comprehensive database optimization
    PERFORM maintenance.register_maintenance_task(
        v_system_tenant_hk,
        'Weekly Database Optimization',
        'OPTIMIZE',
        'PERFORMANCE',
        'Weekly comprehensive database optimization including reindexing and statistics updates',
        NULL,
        'performance.analyze_query_performance',
        'WEEKLY',
        70,
        '01:00:00'::TIME,
        '05:00:00'::TIME
    );
    
    -- Monthly data cleanup
    PERFORM maintenance.register_maintenance_task(
        v_system_tenant_hk,
        'Monthly Data Cleanup',
        'CLEANUP',
        'COMPLIANCE',
        'Monthly cleanup of old data based on retention policies',
        NULL,
        'maintenance.automated_data_cleanup',
        'MONTHLY',
        60,
        '00:00:00'::TIME,
        '06:00:00'::TIME
    );
    
    -- Daily backup verification
    PERFORM maintenance.register_maintenance_task(
        v_system_tenant_hk,
        'Daily Backup Verification',
        'BACKUP',
        'SECURITY',
        'Daily verification of backup integrity and completion',
        NULL,
        'backup_mgmt.verify_backup_integrity',
        'DAILY',
        90,
        '06:00:00'::TIME,
        '07:00:00'::TIME
    );
    
    -- Hourly performance monitoring
    PERFORM maintenance.register_maintenance_task(
        v_system_tenant_hk,
        'Hourly Performance Monitoring',
        'ANALYZE',
        'PERFORMANCE',
        'Hourly collection and analysis of performance metrics',
        NULL,
        'monitoring.collect_system_metrics',
        'HOURLY',
        50,
        NULL,
        NULL
    );
    
    RAISE NOTICE 'Standard maintenance tasks registered successfully';
END
$$;

-- =====================================================================================
-- MAINTENANCE DASHBOARD VIEW
-- =====================================================================================

-- Maintenance dashboard view
CREATE OR REPLACE VIEW maintenance.maintenance_dashboard AS
WITH task_summary AS (
    SELECT 
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE is_enabled = true) as active_tasks,
        COUNT(*) FILTER (WHERE task_category = 'ROUTINE') as routine_tasks,
        COUNT(*) FILTER (WHERE task_category = 'PERFORMANCE') as performance_tasks,
        COUNT(*) FILTER (WHERE task_category = 'SECURITY') as security_tasks,
        COUNT(*) FILTER (WHERE task_category = 'COMPLIANCE') as compliance_tasks
    FROM maintenance.maintenance_task_s 
    WHERE load_end_date IS NULL
),
execution_summary AS (
    SELECT 
        COUNT(*) as total_executions,
        COUNT(*) FILTER (WHERE execution_status = 'COMPLETED') as successful_executions,
        COUNT(*) FILTER (WHERE execution_status = 'FAILED') as failed_executions,
        COUNT(*) FILTER (WHERE execution_start_time >= CURRENT_DATE) as today_executions,
        ROUND(AVG(execution_duration_seconds), 2) as avg_duration_seconds,
        MAX(execution_duration_seconds) as max_duration_seconds
    FROM maintenance.maintenance_execution_s 
    WHERE load_end_date IS NULL
    AND execution_start_time >= CURRENT_DATE - INTERVAL '30 days'
),
next_scheduled AS (
    SELECT 
        COUNT(*) as tasks_due_next_hour
    FROM maintenance.maintenance_task_s mts
    WHERE mts.load_end_date IS NULL
    AND mts.is_enabled = true
    AND (
        (mts.schedule_frequency = 'HOURLY') OR
        (mts.schedule_frequency = 'DAILY' AND 
         CURRENT_TIME BETWEEN mts.maintenance_window_start AND mts.maintenance_window_end)
    )
)
SELECT 
    'Task Management' as category,
    ts.total_tasks as total_count,
    ts.active_tasks as active_count,
    ROUND((ts.active_tasks::DECIMAL / NULLIF(ts.total_tasks, 0)) * 100, 1) as active_percentage,
    'tasks' as unit
FROM task_summary ts

UNION ALL

SELECT 
    'Execution Success Rate',
    es.total_executions,
    es.successful_executions,
    ROUND((es.successful_executions::DECIMAL / NULLIF(es.total_executions, 0)) * 100, 1),
    '%'
FROM execution_summary es

UNION ALL

SELECT 
    'Average Execution Time',
    1,
    es.avg_duration_seconds::INTEGER,
    es.avg_duration_seconds,
    'seconds'
FROM execution_summary es

UNION ALL

SELECT 
    'Tasks Due Next Hour',
    ns.tasks_due_next_hour,
    ns.tasks_due_next_hour,
    100.0,
    'tasks'
FROM next_scheduled ns

ORDER BY category;

-- Grant permissions for maintenance functions
GRANT EXECUTE ON FUNCTION maintenance.register_maintenance_task TO postgres;
GRANT EXECUTE ON FUNCTION maintenance.execute_maintenance_task TO postgres;
GRANT EXECUTE ON FUNCTION maintenance.schedule_maintenance_tasks TO postgres;
GRANT EXECUTE ON FUNCTION maintenance.automated_database_optimization TO postgres;
GRANT EXECUTE ON FUNCTION maintenance.automated_data_cleanup TO postgres;

-- Grant SELECT permissions on maintenance views
GRANT SELECT ON maintenance.maintenance_dashboard TO postgres;

-- =====================================================================================
-- COMMENTS AND DOCUMENTATION
-- =====================================================================================

COMMENT ON SCHEMA maintenance IS 
'Automated maintenance schema containing task definitions, execution tracking, scheduling, and automated optimization procedures for production database maintenance.';

COMMENT ON TABLE maintenance.maintenance_task_h IS
'Hub table for maintenance task definitions including routine, performance, security, and compliance maintenance tasks with tenant isolation support.';

COMMENT ON FUNCTION maintenance.execute_maintenance_task IS
'Executes a registered maintenance task with comprehensive logging, error handling, and performance tracking for automated database maintenance.';

COMMENT ON VIEW maintenance.maintenance_dashboard IS
'Real-time maintenance dashboard providing current status of maintenance tasks, execution success rates, and upcoming scheduled maintenance activities.';

-- =====================================================================================
-- SCRIPT COMPLETION
-- =====================================================================================

-- Log successful completion
DO $$
BEGIN
    RAISE NOTICE 'Step 6: Automated Maintenance System deployment completed successfully at %', CURRENT_TIMESTAMP;
    RAISE NOTICE 'Created maintenance schema with % tables and % functions', 
        (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'maintenance'),
        (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'maintenance');
    RAISE NOTICE 'Registered % standard maintenance tasks', 
        (SELECT COUNT(*) FROM maintenance.maintenance_task_s WHERE load_end_date IS NULL);
END
$$; 