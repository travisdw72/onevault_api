-- =============================================================================
-- Universal Script Execution Tracker
-- Automatically tracks every database script and operation with full audit trails
-- Author: AI Agent
-- Date: 2025-01-19
-- Purpose: Enterprise-grade database change tracking and compliance
-- =============================================================================

-- ############################################################################
-- SCRIPT EXECUTION TRACKING INFRASTRUCTURE
-- ############################################################################

-- Create comprehensive script execution tracking tables
CREATE SCHEMA IF NOT EXISTS script_tracking;
COMMENT ON SCHEMA script_tracking IS 'Comprehensive tracking of all database script executions and operations';

-- Script Execution Hub - Every script execution gets tracked
CREATE TABLE IF NOT EXISTS script_tracking.script_execution_h (
    script_execution_hk BYTEA PRIMARY KEY,
    script_execution_bk VARCHAR(255) NOT NULL UNIQUE,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- NULL for system-wide scripts
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) DEFAULT 'SCRIPT_TRACKER'
);

-- Script Execution Details Satellite - All the details about what was executed
CREATE TABLE IF NOT EXISTS script_tracking.script_execution_s (
    script_execution_hk BYTEA NOT NULL REFERENCES script_tracking.script_execution_h(script_execution_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    
    -- Execution Context
    script_name VARCHAR(500) NOT NULL,
    script_type VARCHAR(100) NOT NULL,           -- MIGRATION, FUNCTION, PROCEDURE, QUERY, MAINTENANCE, etc.
    script_category VARCHAR(100) NOT NULL,       -- DDL, DML, QUERY, ADMIN, etc.
    execution_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- User and Session Information
    executed_by VARCHAR(100) NOT NULL,
    session_user VARCHAR(100),
    application_name VARCHAR(255),
    client_hostname VARCHAR(255),
    client_port INTEGER,
    
    -- Script Content and Metadata
    script_content TEXT,                         -- The actual SQL executed (if appropriate)
    script_hash BYTEA,                          -- Hash of script content for integrity
    script_file_path VARCHAR(1000),            -- Source file path if applicable
    script_version VARCHAR(50),                 -- Version/tag information
    
    -- Execution Results
    execution_status VARCHAR(20) NOT NULL,      -- STARTED, COMPLETED, FAILED, ROLLED_BACK
    execution_duration_ms BIGINT,
    rows_affected BIGINT,
    error_message TEXT,
    error_code VARCHAR(50),
    
    -- Impact Analysis
    objects_created TEXT[],                     -- Tables, indexes, functions created
    objects_modified TEXT[],                    -- Objects altered
    objects_dropped TEXT[],                     -- Objects removed
    schemas_affected TEXT[],                    -- Which schemas were touched
    
    -- Performance and Resource Usage
    cpu_time_ms BIGINT,
    io_reads BIGINT,
    io_writes BIGINT,
    memory_usage_kb BIGINT,
    temp_space_used_kb BIGINT,
    
    -- Compliance and Security
    contains_phi BOOLEAN DEFAULT false,
    contains_pii BOOLEAN DEFAULT false,
    data_classification VARCHAR(50),            -- PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED
    compliance_frameworks TEXT[],               -- HIPAA, GDPR, SOX, etc.
    approval_required BOOLEAN DEFAULT false,
    approved_by VARCHAR(100),
    approval_timestamp TIMESTAMP WITH TIME ZONE,
    
    -- Additional Context
    execution_environment VARCHAR(50),          -- DEV, TEST, STAGING, PROD
    related_ticket VARCHAR(100),                -- Jira ticket, work order, etc.
    business_justification TEXT,
    rollback_script_available BOOLEAN DEFAULT false,
    rollback_tested BOOLEAN DEFAULT false,
    
    record_source VARCHAR(100) DEFAULT 'SCRIPT_TRACKER',
    PRIMARY KEY (script_execution_hk, load_date)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_script_execution_timestamp 
    ON script_tracking.script_execution_s(execution_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_script_execution_user 
    ON script_tracking.script_execution_s(executed_by);
CREATE INDEX IF NOT EXISTS idx_script_execution_status 
    ON script_tracking.script_execution_s(execution_status);
CREATE INDEX IF NOT EXISTS idx_script_execution_type 
    ON script_tracking.script_execution_s(script_type);
CREATE INDEX IF NOT EXISTS idx_script_execution_environment 
    ON script_tracking.script_execution_s(execution_environment);

-- ############################################################################
-- UNIVERSAL SCRIPT TRACKING FUNCTION
-- ############################################################################

-- Main function to track any script execution
CREATE OR REPLACE FUNCTION script_tracking.track_script_execution(
    p_script_name VARCHAR(500),
    p_script_type VARCHAR(100),
    p_script_category VARCHAR(100) DEFAULT 'UNKNOWN',
    p_script_content TEXT DEFAULT NULL,
    p_script_file_path VARCHAR(1000) DEFAULT NULL,
    p_script_version VARCHAR(50) DEFAULT NULL,
    p_tenant_hk BYTEA DEFAULT NULL,
    p_business_justification TEXT DEFAULT NULL,
    p_related_ticket VARCHAR(100) DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_execution_hk BYTEA;
    v_execution_bk VARCHAR(255);
    v_script_hash BYTEA;
    v_environment VARCHAR(50);
    v_contains_phi BOOLEAN := false;
    v_contains_pii BOOLEAN := false;
    v_data_classification VARCHAR(50) := 'INTERNAL';
    v_compliance_frameworks TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Generate unique execution identifier
    v_execution_bk := 'SCRIPT_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS_US') || '_' || 
                      SUBSTRING(MD5(p_script_name || COALESCE(p_script_content, '') || SESSION_USER), 1, 8);
    v_execution_hk := util.hash_binary(v_execution_bk);
    
    -- Calculate script hash if content provided
    IF p_script_content IS NOT NULL THEN
        v_script_hash := digest(p_script_content, 'sha256');
    END IF;
    
    -- Detect environment
    v_environment := COALESCE(current_setting('app.environment', true), 'DEVELOPMENT');
    
    -- Analyze script content for sensitive data patterns
    IF p_script_content IS NOT NULL THEN
        -- Check for PHI indicators
        IF p_script_content ~* '(ssn|social.security|medical.record|patient|diagnosis|treatment|health)' THEN
            v_contains_phi := true;
            v_compliance_frameworks := array_append(v_compliance_frameworks, 'HIPAA');
            v_data_classification := 'RESTRICTED';
        END IF;
        
        -- Check for PII indicators
        IF p_script_content ~* '(email|phone|address|birth.date|credit.card|personal)' THEN
            v_contains_pii := true;
            v_compliance_frameworks := array_append(v_compliance_frameworks, 'GDPR');
            IF v_data_classification = 'INTERNAL' THEN
                v_data_classification := 'CONFIDENTIAL';
            END IF;
        END IF;
        
        -- Check for financial data
        IF p_script_content ~* '(financial|transaction|payment|account|revenue|sox)' THEN
            v_compliance_frameworks := array_append(v_compliance_frameworks, 'SOX');
        END IF;
    END IF;
    
    -- Insert hub record
    INSERT INTO script_tracking.script_execution_h VALUES (
        v_execution_hk,
        v_execution_bk,
        p_tenant_hk,
        util.current_load_date(),
        'SCRIPT_TRACKER'
    ) ON CONFLICT (script_execution_bk) DO NOTHING;
    
    -- Insert satellite record
    INSERT INTO script_tracking.script_execution_s VALUES (
        v_execution_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_execution_bk || 'STARTED'),
        p_script_name,
        p_script_type,
        p_script_category,
        CURRENT_TIMESTAMP,
        SESSION_USER,
        current_user,
        current_setting('application_name', true),
        inet_client_addr()::text,
        inet_client_port(),
        p_script_content,
        v_script_hash,
        p_script_file_path,
        p_script_version,
        'STARTED',
        NULL, -- execution_duration_ms
        NULL, -- rows_affected
        NULL, -- error_message
        NULL, -- error_code
        ARRAY[]::TEXT[], -- objects_created
        ARRAY[]::TEXT[], -- objects_modified
        ARRAY[]::TEXT[], -- objects_dropped
        ARRAY[]::TEXT[], -- schemas_affected
        NULL, -- cpu_time_ms
        NULL, -- io_reads
        NULL, -- io_writes
        NULL, -- memory_usage_kb
        NULL, -- temp_space_used_kb
        v_contains_phi,
        v_contains_pii,
        v_data_classification,
        v_compliance_frameworks,
        false, -- approval_required
        NULL, -- approved_by
        NULL, -- approval_timestamp
        v_environment,
        p_related_ticket,
        p_business_justification,
        false, -- rollback_script_available
        false, -- rollback_tested
        'SCRIPT_TRACKER'
    );
    
    -- Log to existing audit system if available
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'log_audit_event') THEN
            PERFORM util.log_audit_event(
                'SCRIPT_EXECUTION',
                'SCRIPT_STARTED',
                jsonb_build_object(
                    'execution_hk', encode(v_execution_hk, 'hex'),
                    'script_name', p_script_name,
                    'script_type', p_script_type,
                    'executed_by', SESSION_USER,
                    'environment', v_environment,
                    'contains_sensitive_data', (v_contains_phi OR v_contains_pii)
                )
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Continue if audit function fails
        RAISE NOTICE 'External audit logging failed: %', SQLERRM;
    END;
    
    RAISE NOTICE '📝 Script execution tracked: % (ID: %)', p_script_name, encode(v_execution_hk, 'hex');
    
    RETURN v_execution_hk;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to complete/update script execution tracking
CREATE OR REPLACE FUNCTION script_tracking.complete_script_execution(
    p_execution_hk BYTEA,
    p_execution_status VARCHAR(20),
    p_execution_duration_ms BIGINT DEFAULT NULL,
    p_rows_affected BIGINT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL,
    p_error_code VARCHAR(50) DEFAULT NULL,
    p_objects_created TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_objects_modified TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_objects_dropped TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_schemas_affected TEXT[] DEFAULT ARRAY[]::TEXT[]
) RETURNS BOOLEAN AS $$
DECLARE
    v_current_record RECORD;
BEGIN
    -- Get current record for updating
    SELECT * INTO v_current_record
    FROM script_tracking.script_execution_s
    WHERE script_execution_hk = p_execution_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Script execution record not found: %', encode(p_execution_hk, 'hex');
    END IF;
    
    -- End current record
    UPDATE script_tracking.script_execution_s
    SET load_end_date = util.current_load_date()
    WHERE script_execution_hk = p_execution_hk
    AND load_end_date IS NULL;
    
    -- Insert completion record
    INSERT INTO script_tracking.script_execution_s VALUES (
        p_execution_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(encode(p_execution_hk, 'hex') || p_execution_status || COALESCE(p_execution_duration_ms::text, '')),
        v_current_record.script_name,
        v_current_record.script_type,
        v_current_record.script_category,
        v_current_record.execution_timestamp,
        v_current_record.executed_by,
        v_current_record.session_user,
        v_current_record.application_name,
        v_current_record.client_hostname,
        v_current_record.client_port,
        v_current_record.script_content,
        v_current_record.script_hash,
        v_current_record.script_file_path,
        v_current_record.script_version,
        p_execution_status,
        p_execution_duration_ms,
        p_rows_affected,
        p_error_message,
        p_error_code,
        p_objects_created,
        p_objects_modified,
        p_objects_dropped,
        p_schemas_affected,
        v_current_record.cpu_time_ms,
        v_current_record.io_reads,
        v_current_record.io_writes,
        v_current_record.memory_usage_kb,
        v_current_record.temp_space_used_kb,
        v_current_record.contains_phi,
        v_current_record.contains_pii,
        v_current_record.data_classification,
        v_current_record.compliance_frameworks,
        v_current_record.approval_required,
        v_current_record.approved_by,
        v_current_record.approval_timestamp,
        v_current_record.execution_environment,
        v_current_record.related_ticket,
        v_current_record.business_justification,
        v_current_record.rollback_script_available,
        v_current_record.rollback_tested,
        'SCRIPT_TRACKER'
    );
    
    -- Log completion to existing audit system
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'log_audit_event') THEN
            PERFORM util.log_audit_event(
                'SCRIPT_EXECUTION',
                'SCRIPT_COMPLETED',
                jsonb_build_object(
                    'execution_hk', encode(p_execution_hk, 'hex'),
                    'script_name', v_current_record.script_name,
                    'execution_status', p_execution_status,
                    'duration_ms', p_execution_duration_ms,
                    'rows_affected', p_rows_affected,
                    'objects_created', p_objects_created,
                    'objects_modified', p_objects_modified,
                    'objects_dropped', p_objects_dropped,
                    'error_occurred', (p_execution_status = 'FAILED')
                )
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'External audit logging failed: %', SQLERRM;
    END;
    
    RAISE NOTICE '✅ Script execution completed: % (Status: %)', 
                 v_current_record.script_name, p_execution_status;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ############################################################################
-- CONVENIENCE TRACKING FUNCTIONS FOR DIFFERENT SCRIPT TYPES
-- ############################################################################

-- Track migration execution
CREATE OR REPLACE FUNCTION script_tracking.track_migration(
    p_migration_name VARCHAR(500),
    p_migration_version VARCHAR(50),
    p_migration_type VARCHAR(20) DEFAULT 'FORWARD', -- FORWARD, ROLLBACK
    p_script_content TEXT DEFAULT NULL,
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS BYTEA AS $$
BEGIN
    RETURN script_tracking.track_script_execution(
        p_migration_name,
        'MIGRATION',
        'DDL',
        p_script_content,
        NULL, -- file_path
        p_migration_version,
        p_tenant_hk,
        'Database migration execution',
        NULL -- related_ticket
    );
END;
$$ LANGUAGE plpgsql;

-- Track function/procedure execution
CREATE OR REPLACE FUNCTION script_tracking.track_function_execution(
    p_function_name VARCHAR(500),
    p_function_params TEXT DEFAULT NULL,
    p_tenant_hk BYTEA DEFAULT NULL
) RETURNS BYTEA AS $$
BEGIN
    RETURN script_tracking.track_script_execution(
        p_function_name || COALESCE('(' || p_function_params || ')', '()'),
        'FUNCTION_CALL',
        'DML',
        NULL, -- script_content
        NULL, -- file_path
        NULL, -- version
        p_tenant_hk,
        'Function execution',
        NULL -- related_ticket
    );
END;
$$ LANGUAGE plpgsql;

-- Track maintenance operations
CREATE OR REPLACE FUNCTION script_tracking.track_maintenance(
    p_operation_name VARCHAR(500),
    p_operation_type VARCHAR(100),
    p_script_content TEXT DEFAULT NULL,
    p_business_justification TEXT DEFAULT NULL
) RETURNS BYTEA AS $$
BEGIN
    RETURN script_tracking.track_script_execution(
        p_operation_name,
        'MAINTENANCE',
        p_operation_type,
        p_script_content,
        NULL, -- file_path
        NULL, -- version
        NULL, -- tenant_hk
        p_business_justification,
        NULL -- related_ticket
    );
END;
$$ LANGUAGE plpgsql;

-- ############################################################################
-- REPORTING AND ANALYSIS FUNCTIONS
-- ############################################################################

-- Get script execution history
CREATE OR REPLACE FUNCTION script_tracking.get_execution_history(
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_DATE - INTERVAL '7 days',
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    p_script_type VARCHAR(100) DEFAULT NULL,
    p_executed_by VARCHAR(100) DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
) RETURNS TABLE (
    execution_timestamp TIMESTAMP WITH TIME ZONE,
    script_name VARCHAR(500),
    script_type VARCHAR(100),
    executed_by VARCHAR(100),
    execution_status VARCHAR(20),
    duration_seconds DECIMAL(10,3),
    rows_affected BIGINT,
    environment VARCHAR(50),
    contains_sensitive_data BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ses.execution_timestamp,
        ses.script_name,
        ses.script_type,
        ses.executed_by,
        ses.execution_status,
        ROUND(ses.execution_duration_ms::DECIMAL / 1000, 3) as duration_seconds,
        ses.rows_affected,
        ses.execution_environment,
        (ses.contains_phi OR ses.contains_pii) as contains_sensitive_data
    FROM script_tracking.script_execution_s ses
    WHERE ses.load_end_date IS NULL
    AND ses.execution_timestamp BETWEEN p_start_date AND p_end_date
    AND (p_script_type IS NULL OR ses.script_type = p_script_type)
    AND (p_executed_by IS NULL OR ses.executed_by = p_executed_by)
    ORDER BY ses.execution_timestamp DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Get script execution statistics
CREATE OR REPLACE FUNCTION script_tracking.get_execution_statistics(
    p_days_back INTEGER DEFAULT 30
) RETURNS TABLE (
    metric_name VARCHAR(100),
    metric_value BIGINT,
    metric_percentage DECIMAL(5,2)
) AS $$
DECLARE
    v_total_executions BIGINT;
    v_start_date TIMESTAMP WITH TIME ZONE;
BEGIN
    v_start_date := CURRENT_DATE - (p_days_back || ' days')::INTERVAL;
    
    -- Get total executions for percentage calculations
    SELECT COUNT(*) INTO v_total_executions
    FROM script_tracking.script_execution_s
    WHERE load_end_date IS NULL
    AND execution_timestamp >= v_start_date;
    
    -- Return statistics
    RETURN QUERY
    WITH stats AS (
        SELECT 
            'Total Executions' as metric,
            COUNT(*) as value
        FROM script_tracking.script_execution_s
        WHERE load_end_date IS NULL
        AND execution_timestamp >= v_start_date
        
        UNION ALL
        
        SELECT 
            'Successful Executions' as metric,
            COUNT(*) as value
        FROM script_tracking.script_execution_s
        WHERE load_end_date IS NULL
        AND execution_timestamp >= v_start_date
        AND execution_status = 'COMPLETED'
        
        UNION ALL
        
        SELECT 
            'Failed Executions' as metric,
            COUNT(*) as value
        FROM script_tracking.script_execution_s
        WHERE load_end_date IS NULL
        AND execution_timestamp >= v_start_date
        AND execution_status = 'FAILED'
        
        UNION ALL
        
        SELECT 
            'Executions with Sensitive Data' as metric,
            COUNT(*) as value
        FROM script_tracking.script_execution_s
        WHERE load_end_date IS NULL
        AND execution_timestamp >= v_start_date
        AND (contains_phi = true OR contains_pii = true)
        
        UNION ALL
        
        SELECT 
            'Production Executions' as metric,
            COUNT(*) as value
        FROM script_tracking.script_execution_s
        WHERE load_end_date IS NULL
        AND execution_timestamp >= v_start_date
        AND execution_environment = 'PRODUCTION'
    )
    SELECT 
        stats.metric::VARCHAR(100),
        stats.value,
        CASE 
            WHEN v_total_executions > 0 THEN 
                ROUND((stats.value::DECIMAL / v_total_executions) * 100, 2)
            ELSE 0
        END as percentage
    FROM stats;
END;
$$ LANGUAGE plpgsql;

-- ############################################################################
-- INTEGRATION WITH EXISTING MIGRATION SYSTEM
-- ############################################################################

-- Update the existing migration log table to integrate with script tracking
DO $$
BEGIN
    -- Add script_execution_hk to existing migration_log if it exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'migration_log' AND table_schema = 'util') THEN
        -- Add column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                      WHERE table_schema = 'util' 
                      AND table_name = 'migration_log' 
                      AND column_name = 'script_execution_hk') THEN
            ALTER TABLE util.migration_log 
            ADD COLUMN script_execution_hk BYTEA REFERENCES script_tracking.script_execution_h(script_execution_hk);
        END IF;
    END IF;
END $$;

-- ############################################################################
-- WRAPPER FUNCTIONS FOR EASY INTEGRATION
-- ############################################################################

-- Simple wrapper to start tracking any operation
CREATE OR REPLACE FUNCTION track_operation(
    p_operation_name VARCHAR(500),
    p_operation_type VARCHAR(100) DEFAULT 'QUERY'
) RETURNS BYTEA AS $$
BEGIN
    RETURN script_tracking.track_script_execution(
        p_operation_name,
        p_operation_type,
        'DML',
        NULL, -- script_content
        NULL, -- file_path  
        NULL, -- version
        NULL, -- tenant_hk
        'Ad-hoc operation tracking',
        NULL  -- related_ticket
    );
END;
$$ LANGUAGE plpgsql;

-- Simple wrapper to complete tracking
CREATE OR REPLACE FUNCTION complete_operation(
    p_execution_hk BYTEA,
    p_success BOOLEAN DEFAULT true,
    p_error_message TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN script_tracking.complete_script_execution(
        p_execution_hk,
        CASE WHEN p_success THEN 'COMPLETED' ELSE 'FAILED' END,
        NULL, -- duration (would need to be calculated)
        NULL, -- rows_affected
        p_error_message,
        NULL, -- error_code
        ARRAY[]::TEXT[], -- objects_created
        ARRAY[]::TEXT[], -- objects_modified
        ARRAY[]::TEXT[], -- objects_dropped
        ARRAY[]::TEXT[]  -- schemas_affected
    );
END;
$$ LANGUAGE plpgsql;

-- ############################################################################
-- PERMISSIONS AND SECURITY
-- ############################################################################

-- Grant appropriate permissions
DO $$
BEGIN
    -- Grant usage on schema to appropriate roles
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
        GRANT USAGE ON SCHEMA script_tracking TO app_user;
        GRANT SELECT ON ALL TABLES IN SCHEMA script_tracking TO app_user;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA script_tracking TO app_user;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dba_user') THEN
        GRANT ALL ON SCHEMA script_tracking TO dba_user;
        GRANT ALL ON ALL TABLES IN SCHEMA script_tracking TO dba_user;
        GRANT ALL ON ALL FUNCTIONS IN SCHEMA script_tracking TO dba_user;
    END IF;
    
    RAISE NOTICE '✅ Permissions granted for script tracking system';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️  Permission setup incomplete: %', SQLERRM;
END $$;

-- ############################################################################
-- VALIDATION AND COMPLETION
-- ############################################################################

DO $$
DECLARE
    v_schema_count INTEGER;
    v_table_count INTEGER;
    v_function_count INTEGER;
BEGIN
    -- Validate schema creation
    SELECT COUNT(*) INTO v_schema_count
    FROM information_schema.schemata 
    WHERE schema_name = 'script_tracking';
    
    -- Validate table creation
    SELECT COUNT(*) INTO v_table_count
    FROM information_schema.tables 
    WHERE table_schema = 'script_tracking';
    
    -- Validate function creation
    SELECT COUNT(*) INTO v_function_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'script_tracking';
    
    -- Report results
    RAISE NOTICE '📊 Universal Script Execution Tracker Setup:';
    RAISE NOTICE '   Schemas created: %', v_schema_count;
    RAISE NOTICE '   Tables created: %', v_table_count;
    RAISE NOTICE '   Functions created: %', v_function_count;
    
    IF v_schema_count = 1 AND v_table_count >= 2 AND v_function_count >= 6 THEN
        RAISE NOTICE '🎉 Universal Script Execution Tracker installed successfully!';
        RAISE NOTICE '';
        RAISE NOTICE '📝 Usage Examples:';
        RAISE NOTICE '   -- Track any operation:';
        RAISE NOTICE '   SELECT track_operation(''My Custom Script'', ''MAINTENANCE'');';
        RAISE NOTICE '';
        RAISE NOTICE '   -- Track migration:';
        RAISE NOTICE '   SELECT script_tracking.track_migration(''V001_create_feature'', ''V001'');';
        RAISE NOTICE '';
        RAISE NOTICE '   -- View recent history:';
        RAISE NOTICE '   SELECT * FROM script_tracking.get_execution_history();';
    ELSE
        RAISE EXCEPTION '❌ Universal Script Execution Tracker setup failed!';
    END IF;
END $$; 