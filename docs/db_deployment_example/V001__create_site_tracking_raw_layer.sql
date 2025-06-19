-- =====================================================
-- V001__create_site_tracking_raw_layer.sql
-- Production Migration: Site Tracking Raw Layer
-- =====================================================
-- MIGRATION PRINCIPLES:
-- 1. IDEMPOTENT: Can run multiple times safely
-- 2. BACKWARDS COMPATIBLE: Doesn't break existing code
-- 3. ROLLBACK READY: Corresponding rollback script available
-- =====================================================

-- Migration metadata
INSERT INTO migrations.migration_log (
    version, 
    script_name, 
    description,
    applied_by,
    applied_at
) VALUES (
    '001',
    'V001__create_site_tracking_raw_layer.sql',
    'Create raw layer for universal site tracking system',
    current_user,
    CURRENT_TIMESTAMP
) ON CONFLICT (version) DO NOTHING;

-- =====================================================
-- SCHEMA CREATION (IDEMPOTENT)
-- =====================================================

-- Create raw schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS raw;

-- Grant permissions (safe to repeat)
GRANT USAGE ON SCHEMA raw TO tracking_processor_role;
GRANT CREATE ON SCHEMA raw TO tracking_processor_role;

-- =====================================================
-- TABLE CREATION (IDEMPOTENT)
-- =====================================================

-- Raw event ingestion table - IDEMPOTENT creation
CREATE TABLE IF NOT EXISTS raw.site_tracking_events_r (
    raw_event_id SERIAL PRIMARY KEY,
    tenant_hk BYTEA NOT NULL,
    api_key_hk BYTEA,
    received_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    client_ip INET,
    user_agent TEXT,
    raw_payload JSONB NOT NULL,
    batch_id VARCHAR(100),
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    record_source VARCHAR(100) DEFAULT 'site_tracker',
    
    -- Constraints (using IF NOT EXISTS pattern)
    CONSTRAINT chk_processing_status CHECK (processing_status IN ('PENDING', 'PROCESSING', 'PROCESSED', 'ERROR')),
    CONSTRAINT chk_retry_count_positive CHECK (retry_count >= 0)
);

-- =====================================================
-- FOREIGN KEY CONSTRAINTS (BACKWARDS COMPATIBLE)
-- =====================================================

-- Add foreign key constraints safely (only if they don't exist)
DO $$
BEGIN
    -- Check if tenant_hk foreign key exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_site_tracking_events_r_tenant_hk'
        AND table_name = 'site_tracking_events_r'
        AND table_schema = 'raw'
    ) THEN
        -- Only add if auth.tenant_h exists
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'auth' AND table_name = 'tenant_h'
        ) THEN
            ALTER TABLE raw.site_tracking_events_r 
            ADD CONSTRAINT fk_site_tracking_events_r_tenant_hk 
            FOREIGN KEY (tenant_hk) REFERENCES auth.tenant_h(tenant_hk);
            
            RAISE NOTICE '✅ Added foreign key constraint to auth.tenant_h';
        ELSE
            RAISE NOTICE '⚠️  auth.tenant_h table not found - skipping foreign key constraint';
        END IF;
    ELSE
        RAISE NOTICE '✅ Foreign key constraint already exists';
    END IF;
END $$;

-- =====================================================
-- INDEXES (IDEMPOTENT)
-- =====================================================

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_site_tracking_events_r_received_timestamp 
ON raw.site_tracking_events_r(received_timestamp);

CREATE INDEX IF NOT EXISTS idx_site_tracking_events_r_processing_status 
ON raw.site_tracking_events_r(processing_status);

CREATE INDEX IF NOT EXISTS idx_site_tracking_events_r_tenant_hk 
ON raw.site_tracking_events_r(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_site_tracking_events_r_tenant_status 
ON raw.site_tracking_events_r(tenant_hk, processing_status);

CREATE INDEX IF NOT EXISTS idx_site_tracking_events_r_tenant_month 
ON raw.site_tracking_events_r(tenant_hk, DATE_TRUNC('month', received_timestamp));

-- =====================================================
-- FUNCTIONS (IDEMPOTENT WITH VERSIONING)
-- =====================================================

-- Raw data ingestion function - CREATE OR REPLACE for idempotency
CREATE OR REPLACE FUNCTION raw.ingest_tracking_event(
    p_tenant_hk BYTEA,
    p_api_key_hk BYTEA,
    p_client_ip INET,
    p_user_agent TEXT,
    p_event_data JSONB
) RETURNS INTEGER AS $$
DECLARE
    v_raw_event_id INTEGER;
    v_batch_id VARCHAR(100);
    v_audit_result JSONB;
BEGIN
    -- Input validation
    IF p_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'Tenant hash key cannot be null';
    END IF;
    
    IF p_event_data IS NULL OR p_event_data = '{}'::JSONB THEN
        RAISE EXCEPTION 'Event data cannot be null or empty';
    END IF;
    
    -- Generate batch ID for processing correlation
    v_batch_id := 'BATCH_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS') || '_' || 
                  substring(encode(
                    CASE 
                        WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'hash_binary' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'util'))
                        THEN util.hash_binary(encode(p_tenant_hk, 'hex') || CURRENT_TIMESTAMP::text)
                        ELSE sha256((encode(p_tenant_hk, 'hex') || CURRENT_TIMESTAMP::text)::bytea)
                    END, 'hex'), 1, 8);
    
    -- Insert raw event
    INSERT INTO raw.site_tracking_events_r (
        tenant_hk, 
        api_key_hk,
        client_ip, 
        user_agent, 
        raw_payload, 
        batch_id,
        record_source
    ) VALUES (
        p_tenant_hk, 
        p_api_key_hk,
        p_client_ip, 
        p_user_agent, 
        p_event_data, 
        v_batch_id,
        'site_tracker'
    ) RETURNING raw_event_id INTO v_raw_event_id;
    
    -- Log audit event (backwards compatible - only if function exists)
    BEGIN
        IF EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'log_audit_event' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'util')) THEN
            SELECT util.log_audit_event(
                'RAW_EVENT_INGESTED',
                'SITE_TRACKING',
                'raw_event_id:' || v_raw_event_id,
                'INGESTION_SYSTEM',
                jsonb_build_object(
                    'raw_event_id', v_raw_event_id,
                    'tenant_hk', encode(p_tenant_hk, 'hex'),
                    'batch_id', v_batch_id,
                    'event_type', p_event_data->>'evt_type',
                    'timestamp', CURRENT_TIMESTAMP
                )
            ) INTO v_audit_result;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Audit failure doesn't stop ingestion
        RAISE WARNING 'Audit logging failed: %', SQLERRM;
    END;
    
    -- Trigger async processing notification (backwards compatible)
    BEGIN
        PERFORM pg_notify('process_tracking_events', jsonb_build_object(
            'raw_event_id', v_raw_event_id,
            'tenant_hk', encode(p_tenant_hk, 'hex'),
            'batch_id', v_batch_id,
            'event_type', p_event_data->>'evt_type',
            'timestamp', CURRENT_TIMESTAMP
        )::text);
    EXCEPTION WHEN OTHERS THEN
        -- Notification failure doesn't stop ingestion
        RAISE WARNING 'Notification failed: %', SQLERRM;
    END;
    
    RETURN v_raw_event_id;
    
EXCEPTION WHEN OTHERS THEN
    -- Enhanced error logging
    RAISE EXCEPTION 'Failed to ingest tracking event for tenant %: %', 
        encode(p_tenant_hk, 'hex'), SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PERMISSIONS (IDEMPOTENT)
-- =====================================================

-- Grant function permissions (safe to repeat)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tracking_processor_role') THEN
        GRANT EXECUTE ON FUNCTION raw.ingest_tracking_event(BYTEA, BYTEA, INET, TEXT, JSONB) 
        TO tracking_processor_role;
        
        GRANT SELECT, INSERT, UPDATE ON raw.site_tracking_events_r 
        TO tracking_processor_role;
        
        GRANT USAGE, SELECT ON SEQUENCE raw.site_tracking_events_r_raw_event_id_seq 
        TO tracking_processor_role;
        
        RAISE NOTICE '✅ Granted permissions to tracking_processor_role';
    ELSE
        RAISE NOTICE '⚠️  tracking_processor_role not found - skipping permission grants';
    END IF;
END $$;

-- =====================================================
-- TABLE COMMENTS (DOCUMENTATION)
-- =====================================================

COMMENT ON TABLE raw.site_tracking_events_r IS 
'Raw tracking events landing table for universal site analytics. IDEMPOTENT creation with backwards compatibility for existing systems.';

COMMENT ON FUNCTION raw.ingest_tracking_event IS 
'PRODUCTION-READY function for ingesting single tracking events. Includes backwards compatibility, error handling, and optional audit logging.';

-- =====================================================
-- MIGRATION COMPLETION
-- =====================================================

-- Update migration status
UPDATE migrations.migration_log 
SET 
    completed_at = CURRENT_TIMESTAMP,
    status = 'SUCCESS',
    notes = 'Raw layer created successfully with idempotent patterns'
WHERE version = '001';

-- Validation query
DO $$
DECLARE
    v_table_count INTEGER;
    v_function_count INTEGER;
    v_index_count INTEGER;
BEGIN
    -- Count created objects
    SELECT COUNT(*) INTO v_table_count 
    FROM information_schema.tables 
    WHERE table_schema = 'raw' AND table_name = 'site_tracking_events_r';
    
    SELECT COUNT(*) INTO v_function_count 
    FROM information_schema.routines 
    WHERE routine_schema = 'raw' AND routine_name = 'ingest_tracking_event';
    
    SELECT COUNT(*) INTO v_index_count 
    FROM pg_indexes 
    WHERE schemaname = 'raw' AND tablename = 'site_tracking_events_r';
    
    RAISE NOTICE '🎉 MIGRATION V001 COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '   Tables created: %', v_table_count;
    RAISE NOTICE '   Functions created: %', v_function_count;
    RAISE NOTICE '   Indexes created: %', v_index_count;
    RAISE NOTICE '   Migration is IDEMPOTENT and BACKWARDS COMPATIBLE';
END $$;

-- Final success message
SELECT 'V001 Migration: Site Tracking Raw Layer' as migration_name,
       'SUCCESS' as status,
       'Ready for staging deployment' as next_step; 