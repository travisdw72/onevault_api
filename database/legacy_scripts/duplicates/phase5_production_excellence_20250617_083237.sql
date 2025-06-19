-- Phase 5: Production Excellence & Maintenance
-- Objective: Implement comprehensive monitoring, maintenance, and alerting

-- Start transaction
BEGIN;

-- Create maintenance log table
CREATE TABLE IF NOT EXISTS util.maintenance_log (
    maintenance_id BIGSERIAL PRIMARY KEY,
    maintenance_type VARCHAR(50) NOT NULL,
    maintenance_details JSONB NOT NULL,
    execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    execution_status VARCHAR(20) NOT NULL,
    completion_timestamp TIMESTAMP WITH TIME ZONE,
    error_details TEXT,
    affected_objects TEXT[],
    execution_duration_ms INTEGER,
    executed_by VARCHAR(100) DEFAULT SESSION_USER,
    
    CONSTRAINT chk_maintenance_log_status 
        CHECK (execution_status IN ('STARTED', 'COMPLETED', 'FAILED', 'LOGGED'))
);

COMMENT ON TABLE util.maintenance_log IS 
'Comprehensive maintenance logging for tracking all system maintenance activities and their outcomes.';

-- Create indexes for maintenance log
CREATE INDEX IF NOT EXISTS idx_maintenance_log_type_status 
ON util.maintenance_log (maintenance_type, execution_status, execution_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_maintenance_log_timestamp 
ON util.maintenance_log (execution_timestamp DESC);

-- Create detailed system health metrics function
CREATE OR REPLACE FUNCTION util.get_detailed_health_metrics()
RETURNS TABLE (
    component_name VARCHAR(100),
    health_status VARCHAR(20),
    metric_value DECIMAL(15,4),
    threshold_warning DECIMAL(15,4),
    threshold_critical DECIMAL(15,4),
    last_check_timestamp TIMESTAMP WITH TIME ZONE,
    details JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH health_metrics AS (
        -- Database connection usage
        SELECT 
            'database_connections' as component,
            (SELECT COUNT(*) FROM pg_stat_activity)::DECIMAL as current_value,
            (SELECT setting::DECIMAL * 0.8 FROM pg_settings WHERE name = 'max_connections') as warn_threshold,
            (SELECT setting::DECIMAL * 0.9 FROM pg_settings WHERE name = 'max_connections') as crit_threshold
            
        UNION ALL
        
        -- Database size
        SELECT 
            'database_size_gb',
            pg_database_size(current_database())::DECIMAL / 1024 / 1024 / 1024,
            50.0, -- Warning at 50GB
            80.0  -- Critical at 80GB
            
        UNION ALL
        
        -- Table bloat estimate
        SELECT 
            'table_bloat_percent',
            COALESCE((
                SELECT (SUM(CASE WHEN n_dead_tup > 0 THEN n_dead_tup ELSE 0 END)::DECIMAL / 
                        NULLIF(SUM(n_live_tup + CASE WHEN n_dead_tup > 0 THEN n_dead_tup ELSE 0 END), 0) * 100)
                FROM pg_stat_user_tables
            ), 0),
            10.0, -- Warning at 10% bloat
            20.0  -- Critical at 20% bloat
            
        UNION ALL
        
        -- Index health
        SELECT 
            'index_fragmentation_percent',
            COALESCE((
                SELECT (SUM(CASE WHEN idx_scan = 0 THEN 1 ELSE 0 END)::DECIMAL / 
                        COUNT(*)::DECIMAL * 100)
                FROM pg_stat_user_indexes
                WHERE idx_scan IS NOT NULL
            ), 0),
            5.0,  -- Warning at 5% unused indexes
            10.0  -- Critical at 10% unused indexes
            
        UNION ALL
        
        -- Transaction ID wraparound
        SELECT 
            'transaction_id_usage_percent',
            COALESCE((
                SELECT (age(datfrozenxid)::DECIMAL / 2000000000 * 100)
                FROM pg_database
                WHERE datname = current_database()
            ), 0),
            75.0, -- Warning at 75% usage
            90.0  -- Critical at 90% usage
    )
    SELECT 
        hm.component::VARCHAR(100),
        CASE 
            WHEN hm.current_value >= hm.crit_threshold THEN 'CRITICAL'
            WHEN hm.current_value >= hm.warn_threshold THEN 'WARNING'
            ELSE 'HEALTHY'
        END::VARCHAR(20) as status,
        hm.current_value,
        hm.warn_threshold,
        hm.crit_threshold,
        CURRENT_TIMESTAMP as check_timestamp,
        jsonb_build_object(
            'metric_name', hm.component,
            'current_value', hm.current_value,
            'warning_threshold', hm.warn_threshold,
            'critical_threshold', hm.crit_threshold,
            'check_timestamp', CURRENT_TIMESTAMP
        ) as details
    FROM health_metrics hm;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION util.get_detailed_health_metrics() IS 
'Detailed system health metrics monitoring database components, resource usage, and performance indicators with threshold-based alerting.';

-- Create maintenance procedure
CREATE OR REPLACE FUNCTION util.perform_maintenance(
    p_maintenance_type VARCHAR(50),
    p_options JSONB DEFAULT '{}'::JSONB
) RETURNS TABLE (
    maintenance_action VARCHAR(100),
    execution_status VARCHAR(20),
    affected_objects INTEGER,
    execution_time_ms INTEGER,
    details JSONB
) AS $$
DECLARE
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_affected_count INTEGER;
    v_maintenance_id BIGINT;
    v_error_details TEXT;
BEGIN
    -- Start maintenance logging
    INSERT INTO util.maintenance_log (
        maintenance_type,
        maintenance_details,
        execution_status,
        execution_timestamp
    ) VALUES (
        p_maintenance_type,
        p_options,
        'STARTED',
        CURRENT_TIMESTAMP
    ) RETURNING maintenance_id INTO v_maintenance_id;
    
    BEGIN
        v_start_time := CURRENT_TIMESTAMP;
        
        CASE p_maintenance_type
            -- Vacuum maintenance
            WHEN 'VACUUM_ANALYZE' THEN
                FOR maintenance_action, execution_status, affected_objects, execution_time_ms, details IN
                    WITH tables_to_vacuum AS (
                        SELECT schemaname, tablename
                        FROM pg_stat_user_tables
                        WHERE n_dead_tup > 1000 OR 
                              last_vacuum < CURRENT_TIMESTAMP - INTERVAL '1 day' OR
                              last_analyze < CURRENT_TIMESTAMP - INTERVAL '1 day'
                    )
                    SELECT 
                        'VACUUM_ANALYZE'::VARCHAR(100),
                        'COMPLETED'::VARCHAR(20),
                        COUNT(*)::INTEGER,
                        EXTRACT(MILLISECONDS FROM CURRENT_TIMESTAMP - v_start_time)::INTEGER,
                        jsonb_build_object(
                            'tables_processed', array_agg(schemaname || '.' || tablename),
                            'start_time', v_start_time,
                            'end_time', CURRENT_TIMESTAMP
                        )
                    FROM tables_to_vacuum
                LOOP
                    RETURN NEXT;
                END LOOP;
                
            -- Index maintenance
            WHEN 'INDEX_MAINTENANCE' THEN
                FOR maintenance_action, execution_status, affected_objects, execution_time_ms, details IN
                    WITH index_maintenance AS (
                        SELECT schemaname, tablename, indexrelname
                        FROM pg_stat_user_indexes
                        WHERE idx_scan = 0 AND 
                              indexrelname NOT LIKE '%_pkey' AND
                              indexrelname NOT LIKE '%_unique'
                    )
                    SELECT 
                        'INDEX_MAINTENANCE'::VARCHAR(100),
                        'COMPLETED'::VARCHAR(20),
                        COUNT(*)::INTEGER,
                        EXTRACT(MILLISECONDS FROM CURRENT_TIMESTAMP - v_start_time)::INTEGER,
                        jsonb_build_object(
                            'unused_indexes', array_agg(schemaname || '.' || indexrelname),
                            'start_time', v_start_time,
                            'end_time', CURRENT_TIMESTAMP
                        )
                    FROM index_maintenance
                LOOP
                    RETURN NEXT;
                END LOOP;
                
            -- Statistics update
            WHEN 'UPDATE_STATISTICS' THEN
                FOR maintenance_action, execution_status, affected_objects, execution_time_ms, details IN
                    WITH statistics_update AS (
                        SELECT schemaname, tablename
                        FROM pg_stat_user_tables
                        WHERE (last_analyze IS NULL OR 
                               last_analyze < CURRENT_TIMESTAMP - INTERVAL '12 hours') AND
                              n_live_tup > 0
                    )
                    SELECT 
                        'UPDATE_STATISTICS'::VARCHAR(100),
                        'COMPLETED'::VARCHAR(20),
                        COUNT(*)::INTEGER,
                        EXTRACT(MILLISECONDS FROM CURRENT_TIMESTAMP - v_start_time)::INTEGER,
                        jsonb_build_object(
                            'tables_processed', array_agg(schemaname || '.' || tablename),
                            'start_time', v_start_time,
                            'end_time', CURRENT_TIMESTAMP
                        )
                    FROM statistics_update
                LOOP
                    RETURN NEXT;
                END LOOP;
                
            ELSE
                RAISE EXCEPTION 'Unsupported maintenance type: %', p_maintenance_type;
        END CASE;
        
        -- Update maintenance log with success
        UPDATE util.maintenance_log 
        SET execution_status = 'COMPLETED',
            completion_timestamp = CURRENT_TIMESTAMP,
            execution_duration_ms = EXTRACT(MILLISECONDS FROM CURRENT_TIMESTAMP - v_start_time)::INTEGER
        WHERE maintenance_id = v_maintenance_id;
        
    EXCEPTION WHEN OTHERS THEN
        -- Update maintenance log with failure
        GET STACKED DIAGNOSTICS v_error_details = PG_EXCEPTION_DETAIL;
        
        UPDATE util.maintenance_log 
        SET execution_status = 'FAILED',
            completion_timestamp = CURRENT_TIMESTAMP,
            error_details = v_error_details,
            execution_duration_ms = EXTRACT(MILLISECONDS FROM CURRENT_TIMESTAMP - v_start_time)::INTEGER
        WHERE maintenance_id = v_maintenance_id;
        
        -- Return failure record
        RETURN QUERY SELECT 
            p_maintenance_type::VARCHAR(100),
            'FAILED'::VARCHAR(20),
            0::INTEGER,
            EXTRACT(MILLISECONDS FROM CURRENT_TIMESTAMP - v_start_time)::INTEGER,
            jsonb_build_object(
                'error', v_error_details,
                'start_time', v_start_time,
                'end_time', CURRENT_TIMESTAMP
            );
    END;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION util.perform_maintenance(VARCHAR, JSONB) IS 
'Executes various database maintenance operations with comprehensive logging and error handling.';

-- Create alert notification table
CREATE TABLE IF NOT EXISTS util.alert_notifications (
    notification_id BIGSERIAL PRIMARY KEY,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    notification_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    message TEXT NOT NULL,
    details JSONB,
    status VARCHAR(20) NOT NULL DEFAULT 'NEW',
    acknowledged_by VARCHAR(100),
    acknowledgment_timestamp TIMESTAMP WITH TIME ZONE,
    resolution_notes TEXT,
    
    CONSTRAINT chk_alert_notifications_severity 
        CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL', 'EMERGENCY')),
    CONSTRAINT chk_alert_notifications_status 
        CHECK (status IN ('NEW', 'ACKNOWLEDGED', 'RESOLVED', 'FALSE_POSITIVE'))
);

COMMENT ON TABLE util.alert_notifications IS 
'System-wide alert notifications for monitoring and maintenance events requiring attention.';

-- Create indexes for alert notifications
CREATE INDEX IF NOT EXISTS idx_alert_notifications_type_severity 
ON util.alert_notifications (alert_type, severity, notification_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_alert_notifications_status 
ON util.alert_notifications (status, severity) 
WHERE status = 'NEW';

-- Create alert notification function
CREATE OR REPLACE FUNCTION util.create_alert_notification(
    p_alert_type VARCHAR(50),
    p_severity VARCHAR(20),
    p_message TEXT,
    p_details JSONB DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_notification_id BIGINT;
BEGIN
    INSERT INTO util.alert_notifications (
        alert_type,
        severity,
        message,
        details
    ) VALUES (
        p_alert_type,
        p_severity,
        p_message,
        p_details
    ) RETURNING notification_id INTO v_notification_id;
    
    -- Log alert creation in maintenance log
    INSERT INTO util.maintenance_log (
        maintenance_type,
        maintenance_details,
        execution_status,
        execution_timestamp
    ) VALUES (
        'ALERT_CREATED',
        jsonb_build_object(
            'notification_id', v_notification_id,
            'alert_type', p_alert_type,
            'severity', p_severity
        ),
        'LOGGED',
        CURRENT_TIMESTAMP
    );
    
    RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION util.create_alert_notification(VARCHAR, VARCHAR, TEXT, JSONB) IS 
'Creates and logs system alert notifications with severity-based categorization and detailed tracking.';

-- Create automated maintenance schedule
CREATE TABLE IF NOT EXISTS util.maintenance_schedule (
    schedule_id BIGSERIAL PRIMARY KEY,
    maintenance_type VARCHAR(50) NOT NULL,
    schedule_interval INTERVAL NOT NULL,
    last_execution TIMESTAMP WITH TIME ZONE,
    next_execution TIMESTAMP WITH TIME ZONE NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    configuration JSONB,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_maintenance_schedule_interval 
        CHECK (schedule_interval >= INTERVAL '1 minute')
);

COMMENT ON TABLE util.maintenance_schedule IS 
'Automated maintenance schedule configuration for regular system maintenance tasks.';

-- Create maintenance schedule function
CREATE OR REPLACE FUNCTION util.schedule_maintenance(
    p_maintenance_type VARCHAR(50),
    p_interval INTERVAL,
    p_config JSONB DEFAULT '{}'::JSONB,
    p_description TEXT DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_schedule_id BIGINT;
BEGIN
    INSERT INTO util.maintenance_schedule (
        maintenance_type,
        schedule_interval,
        next_execution,
        configuration,
        description
    ) VALUES (
        p_maintenance_type,
        p_interval,
        CURRENT_TIMESTAMP + p_interval,
        p_config,
        p_description
    ) RETURNING schedule_id INTO v_schedule_id;
    
    -- Log schedule creation
    INSERT INTO util.maintenance_log (
        maintenance_type,
        maintenance_details,
        execution_status
    ) VALUES (
        'MAINTENANCE_SCHEDULED',
        jsonb_build_object(
            'schedule_id', v_schedule_id,
            'maintenance_type', p_maintenance_type,
            'interval', p_interval,
            'next_execution', CURRENT_TIMESTAMP + p_interval
        ),
        'LOGGED'
    );
    
    RETURN v_schedule_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION util.schedule_maintenance(VARCHAR, INTERVAL, JSONB, TEXT) IS 
'Schedules regular maintenance tasks with configurable intervals and execution parameters.';

-- Create default maintenance schedules
INSERT INTO util.maintenance_schedule (
    maintenance_type,
    schedule_interval,
    next_execution,
    configuration,
    description
) VALUES 
    ('VACUUM_ANALYZE', 
     INTERVAL '1 day',
     CURRENT_TIMESTAMP + INTERVAL '1 day',
     '{"vacuum_full": false, "analyze": true}'::JSONB,
     'Daily VACUUM ANALYZE on all user tables'),
     
    ('INDEX_MAINTENANCE',
     INTERVAL '1 week',
     CURRENT_TIMESTAMP + INTERVAL '1 week',
     '{"rebuild_indexes": false, "reindex": false}'::JSONB,
     'Weekly index maintenance and optimization'),
     
    ('UPDATE_STATISTICS',
     INTERVAL '12 hours',
     CURRENT_TIMESTAMP + INTERVAL '12 hours',
     '{"sample_size": 30}'::JSONB,
     'Update table statistics every 12 hours')
ON CONFLICT DO NOTHING;

-- Commit transaction
COMMIT; 