-- =============================================================================
-- Universal Script Execution Tracker - TRULY FIXED VERSION
-- FIXES: Primary key conflicts, audit function calls, and event trigger issues
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

-- Create sequence for satellite versioning (FIXES primary key conflicts)
CREATE SEQUENCE IF NOT EXISTS script_tracking.script_execution_version_seq;

-- Script Execution Details Satellite - All the details about what was executed
-- FIXED: Using sequence instead of load_date in primary key to prevent conflicts
CREATE TABLE IF NOT EXISTS script_tracking.script_execution_s (
    script_execution_hk BYTEA NOT NULL REFERENCES script_tracking.script_execution_h(script_execution_hk),
    version_number BIGINT DEFAULT nextval('script_tracking.script_execution_version_seq'),
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
    db_session_user VARCHAR(100),                -- FIXED: renamed from session_user (reserved keyword)
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
    
    -- FIXED: Primary key using sequence instead of load_date
    PRIMARY KEY (script_execution_hk, version_number)
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
CREATE INDEX IF NOT EXISTS idx_script_execution_current 
    ON script_tracking.script_execution_s(script_execution_hk) WHERE load_end_date IS NULL;

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
    
    -- Insert satellite record (sequence will auto-generate version_number)
    INSERT INTO script_tracking.script_execution_s (
        script_execution_hk, load_date, load_end_date, hash_diff,
        script_name, script_type, script_category, execution_timestamp,
        executed_by, db_session_user, application_name, client_hostname, client_port,
        script_content, script_hash, script_file_path, script_version,
        execution_status, execution_duration_ms, rows_affected, error_message, error_code,
        objects_created, objects_modified, objects_dropped, schemas_affected,
        cpu_time_ms, io_reads, io_writes, memory_usage_kb, temp_space_used_kb,
        contains_phi, contains_pii, data_classification, compliance_frameworks,
        approval_required, approved_by, approval_timestamp,
        execution_environment, related_ticket, business_justification,
        rollback_script_available, rollback_tested, record_source
    ) VALUES (
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
        NULL, NULL, NULL, NULL,
        ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY[]::TEXT[],
        NULL, NULL, NULL, NULL, NULL,
        v_contains_phi,
        v_contains_pii,
        v_data_classification,
        v_compliance_frameworks,
        false, NULL, NULL,
        v_environment,
        p_related_ticket,
        p_business_justification,
        false, false,
        'SCRIPT_TRACKER'
    );
    
    -- Log to existing audit system if available (FIXED: Explicit type casting)
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'log_audit_event') THEN
            PERFORM util.log_audit_event(
                'SCRIPT_EXECUTION'::text,            -- p_event_type (explicit cast)
                'SCRIPT_TRACKER'::text,              -- p_resource_type (explicit cast)
                encode(v_execution_hk, 'hex')::text, -- p_resource_id (explicit cast)
                SESSION_USER::text,                  -- p_actor (explicit cast)
                jsonb_build_object(                  -- p_event_details (already jsonb)
                    'execution_hk', encode(v_execution_hk, 'hex'),
                    'script_name', p_script_name,
                    'script_type', p_script_type,
                    'executed_by', SESSION_USER,
                    'environment', v_environment,
                    'contains_sensitive_data', (v_contains_phi OR v_contains_pii)
                )::jsonb
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
    ORDER BY version_number DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Script execution record not found: %', encode(p_execution_hk, 'hex');
    END IF;
    
    -- End current record
    UPDATE script_tracking.script_execution_s
    SET load_end_date = util.current_load_date()
    WHERE script_execution_hk = p_execution_hk
    AND load_end_date IS NULL;
    
    -- Insert completion record (sequence will auto-generate new version_number)
    INSERT INTO script_tracking.script_execution_s (
        script_execution_hk, load_date, load_end_date, hash_diff,
        script_name, script_type, script_category, execution_timestamp,
        executed_by, db_session_user, application_name, client_hostname, client_port,
        script_content, script_hash, script_file_path, script_version,
        execution_status, execution_duration_ms, rows_affected, error_message, error_code,
        objects_created, objects_modified, objects_dropped, schemas_affected,
        cpu_time_ms, io_reads, io_writes, memory_usage_kb, temp_space_used_kb,
        contains_phi, contains_pii, data_classification, compliance_frameworks,
        approval_required, approved_by, approval_timestamp,
        execution_environment, related_ticket, business_justification,
        rollback_script_available, rollback_tested, record_source
    ) VALUES (
        p_execution_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(encode(p_execution_hk, 'hex') || p_execution_status || COALESCE(p_execution_duration_ms::text, '')),
        v_current_record.script_name, v_current_record.script_type, v_current_record.script_category,
        v_current_record.execution_timestamp, v_current_record.executed_by, v_current_record.db_session_user,
        v_current_record.application_name, v_current_record.client_hostname, v_current_record.client_port,
        v_current_record.script_content, v_current_record.script_hash, v_current_record.script_file_path,
        v_current_record.script_version, p_execution_status, p_execution_duration_ms, p_rows_affected,
        p_error_message, p_error_code, p_objects_created, p_objects_modified, p_objects_dropped,
        p_schemas_affected, v_current_record.cpu_time_ms, v_current_record.io_reads, v_current_record.io_writes,
        v_current_record.memory_usage_kb, v_current_record.temp_space_used_kb, v_current_record.contains_phi,
        v_current_record.contains_pii, v_current_record.data_classification, v_current_record.compliance_frameworks,
        v_current_record.approval_required, v_current_record.approved_by, v_current_record.approval_timestamp,
        v_current_record.execution_environment, v_current_record.related_ticket, v_current_record.business_justification,
        v_current_record.rollback_script_available, v_current_record.rollback_tested, 'SCRIPT_TRACKER'
    );
    
    -- Log completion to existing audit system (FIXED: Explicit type casting)
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'log_audit_event') THEN
            PERFORM util.log_audit_event(
                'SCRIPT_EXECUTION'::text,            -- p_event_type (explicit cast)
                'SCRIPT_COMPLETION'::text,           -- p_resource_type (explicit cast)
                encode(p_execution_hk, 'hex')::text, -- p_resource_id (explicit cast)
                SESSION_USER::text,                  -- p_actor (explicit cast)
                jsonb_build_object(                  -- p_event_details (already jsonb)
                    'execution_hk', encode(p_execution_hk, 'hex'),
                    'script_name', v_current_record.script_name,
                    'execution_status', p_execution_status,
                    'duration_ms', p_execution_duration_ms,
                    'rows_affected', p_rows_affected,
                    'objects_created', p_objects_created,
                    'objects_modified', p_objects_modified,
                    'objects_dropped', p_objects_dropped,
                    'error_occurred', (p_execution_status = 'FAILED')
                )::jsonb
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
        GRANT USAGE ON SEQUENCE script_tracking.script_execution_version_seq TO app_user;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dba_user') THEN
        GRANT ALL ON SCHEMA script_tracking TO dba_user;
        GRANT ALL ON ALL TABLES IN SCHEMA script_tracking TO dba_user;
        GRANT ALL ON ALL FUNCTIONS IN SCHEMA script_tracking TO dba_user;
        GRANT ALL ON SEQUENCE script_tracking.script_execution_version_seq TO dba_user;
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
    v_sequence_count INTEGER;
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
    
    -- Validate sequence creation
    SELECT COUNT(*) INTO v_sequence_count
    FROM pg_sequences
    WHERE schemaname = 'script_tracking';
    
    -- Report results
    RAISE NOTICE '📊 Universal Script Execution Tracker Setup (TRULY FIXED):';
    RAISE NOTICE '   Schemas created: %', v_schema_count;
    RAISE NOTICE '   Tables created: %', v_table_count;
    RAISE NOTICE '   Functions created: %', v_function_count;
    RAISE NOTICE '   Sequences created: %', v_sequence_count;
    
    IF v_schema_count = 1 AND v_table_count >= 2 AND v_function_count >= 2 AND v_sequence_count >= 1 THEN
        RAISE NOTICE '🎉 Universal Script Execution Tracker (TRULY FIXED) installed successfully!';
        RAISE NOTICE '';
        RAISE NOTICE '🔧 KEY FIXES APPLIED:';
        RAISE NOTICE '   ✅ Primary key conflicts resolved (using sequence instead of load_date)';
        RAISE NOTICE '   ✅ Audit function calls fixed (explicit type casting)';
        RAISE NOTICE '   ✅ Reserved keyword issues resolved (session_user → db_session_user)';
        RAISE NOTICE '';
        RAISE NOTICE '📝 Usage Examples:';
        RAISE NOTICE '   -- Track any operation:';
        RAISE NOTICE '   SELECT track_operation(''My Custom Script'', ''MAINTENANCE'');';
    ELSE
        RAISE EXCEPTION '❌ Universal Script Execution Tracker setup failed!';
    END IF;
END $$;
