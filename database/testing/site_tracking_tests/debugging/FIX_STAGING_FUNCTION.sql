-- ============================================================================
-- FIX STAGING FUNCTION - Correct Field Mapping
-- Site Tracking System - Staging Layer Fix
-- ============================================================================
-- Purpose: Fix staging function to handle event_type (not evt_type) and missing fields
-- Issues: Field mapping mismatch causing staging processing failures
-- ============================================================================

-- Create fixed staging validation function
CREATE OR REPLACE FUNCTION staging.validate_and_enrich_event(
    p_raw_event_id INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_raw_event RECORD;
    v_event_data JSONB;
    v_staging_event_id INTEGER;
    v_validation_status VARCHAR(20) := 'VALID';
    v_quality_score DECIMAL(3,2) := 1.0;
    v_validation_errors TEXT[] := ARRAY[]::TEXT[];
    v_enrichment_data JSONB;
    v_event_timestamp TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Get raw event data
    SELECT * INTO v_raw_event
    FROM raw.site_tracking_events_r
    WHERE raw_event_id = p_raw_event_id;
    
    IF v_raw_event IS NULL THEN
        RAISE EXCEPTION 'Raw event % not found', p_raw_event_id;
    END IF;
    
    v_event_data := v_raw_event.raw_payload;
    
    -- CRITICAL FIX: Use event_type (not evt_type)
    IF NOT (v_event_data ? 'event_type') THEN
        v_validation_errors := array_append(v_validation_errors, 'Missing event_type field');
        v_validation_status := 'INVALID';
        v_quality_score := v_quality_score - 0.3;
    END IF;
    
    -- Extract and validate timestamp
    BEGIN
        v_event_timestamp := COALESCE(
            (v_event_data->>'timestamp')::TIMESTAMP WITH TIME ZONE,
            v_raw_event.received_timestamp
        );
    EXCEPTION WHEN OTHERS THEN
        v_event_timestamp := v_raw_event.received_timestamp;
        v_validation_errors := array_append(v_validation_errors, 'Invalid timestamp format');
        v_quality_score := v_quality_score - 0.1;
    END;
    
    -- Page URL validation
    IF NOT (v_event_data ? 'page_url') OR LENGTH(v_event_data->>'page_url') = 0 THEN
        v_validation_errors := array_append(v_validation_errors, 'Missing or empty page_url');
        v_quality_score := v_quality_score - 0.2;
    END IF;
    
    -- Create enrichment data
    v_enrichment_data := jsonb_build_object(
        'processing_version', '2.0_fixed',
        'enrichment_timestamp', CURRENT_TIMESTAMP,
        'field_mapping_corrected', true,
        'original_fields', jsonb_object_keys(v_event_data)
    );
    
    -- Handle missing optional fields gracefully
    IF v_quality_score < 0.3 THEN
        v_validation_status := 'INVALID';
    ELSIF v_quality_score < 0.7 THEN
        v_validation_status := 'SUSPICIOUS';
    END IF;
    
    -- Insert into staging table with proper field mapping
    INSERT INTO staging.site_tracking_events_s (
        raw_event_id,
        tenant_hk,
        event_type,  -- FIXED: Map from event_type (not evt_type)
        session_id,
        user_id,
        page_url,
        page_title,
        referrer_url,
        event_timestamp,  -- FIXED: Ensure this is set
        processed_timestamp,
        validation_status,
        enrichment_status,
        quality_score,
        enrichment_data,
        validation_errors,
        record_source
    ) VALUES (
        p_raw_event_id,
        v_raw_event.tenant_hk,
        v_event_data->>'event_type',  -- FIXED: Use event_type
        v_event_data->>'session_id',   -- NULL if missing (nullable)
        v_event_data->>'user_id',      -- NULL if missing (nullable)
        v_event_data->>'page_url',
        v_event_data->>'page_title',   -- NULL if missing (nullable)
        v_event_data->>'referrer',     -- NULL if missing (nullable)
        v_event_timestamp,             -- FIXED: Always set
        CURRENT_TIMESTAMP,
        v_validation_status,
        'ENRICHED',
        v_quality_score,
        v_enrichment_data,
        v_validation_errors,
        'site_tracker_fixed'
    ) RETURNING staging_event_id INTO v_staging_event_id;
    
    -- Update raw event status
    UPDATE raw.site_tracking_events_r 
    SET processing_status = 'PROCESSED'
    WHERE raw_event_id = p_raw_event_id;
    
    -- Log successful processing using correct audit table
    PERFORM util.log_audit_event(
        'STAGING_PROCESSING_SUCCESS',
        'SITE_TRACKING',
        'staging_event:' || v_staging_event_id,
        'STAGING_PROCESSOR',
        jsonb_build_object(
            'raw_event_id', p_raw_event_id,
            'staging_event_id', v_staging_event_id,
            'tenant_hk', encode(v_raw_event.tenant_hk, 'hex'),
            'event_type', v_event_data->>'event_type',
            'validation_status', v_validation_status,
            'quality_score', v_quality_score,
            'processing_version', '2.0_fixed'
        )
    );
    
    -- Trigger business layer processing
    PERFORM pg_notify('process_to_business_layer', jsonb_build_object(
        'staging_event_id', v_staging_event_id,
        'tenant_hk', encode(v_raw_event.tenant_hk, 'hex'),
        'event_type', v_event_data->>'event_type',
        'validation_status', v_validation_status,
        'timestamp', CURRENT_TIMESTAMP
    )::text);
    
    RETURN v_staging_event_id;
    
EXCEPTION WHEN OTHERS THEN
    -- Update raw event with error
    UPDATE raw.site_tracking_events_r 
    SET processing_status = 'ERROR',
        error_message = SQLERRM
    WHERE raw_event_id = p_raw_event_id;
    
    -- Log error using correct audit table
    PERFORM util.log_audit_event(
        'STAGING_PROCESSING_ERROR',
        'SYSTEM_ERROR',
        'raw_event:' || p_raw_event_id,
        'STAGING_PROCESSOR',
        jsonb_build_object(
            'raw_event_id', p_raw_event_id,
            'tenant_hk', encode(v_raw_event.tenant_hk, 'hex'),
            'error_message', SQLERRM,
            'error_state', SQLSTATE,
            'processing_version', '2.0_fixed'
        )
    );
    
    RAISE EXCEPTION 'Failed to process raw event % to staging: %', p_raw_event_id, SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Test the fixed function
\echo '🧪 TESTING FIXED STAGING FUNCTION...'

-- Test processing event 4
DO $$
DECLARE
    v_staging_id INTEGER;
BEGIN
    BEGIN
        SELECT staging.validate_and_enrich_event(4) INTO v_staging_id;
        RAISE NOTICE '✅ Event 4 processed successfully. Staging ID: %', v_staging_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Event 4 processing failed: %', SQLERRM;
    END;
END $$;

-- Test processing event 5
DO $$
DECLARE
    v_staging_id INTEGER;
BEGIN
    BEGIN
        SELECT staging.validate_and_enrich_event(5) INTO v_staging_id;
        RAISE NOTICE '✅ Event 5 processed successfully. Staging ID: %', v_staging_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Event 5 processing failed: %', SQLERRM;
    END;
END $$;

-- Verify results
\echo '📊 VERIFYING PROCESSING RESULTS...'

-- Check raw events status
SELECT 
    '📊 RAW EVENTS AFTER FIX' as status_check,
    raw_event_id,
    processing_status,
    error_message,
    CASE 
        WHEN processing_status = 'PROCESSED' THEN '✅ Success'
        WHEN processing_status = 'ERROR' THEN '❌ Error: ' || error_message
        ELSE '⚠️ ' || processing_status
    END as status_summary
FROM raw.site_tracking_events_r
WHERE raw_event_id IN (4, 5)
ORDER BY raw_event_id;

-- Check staging events
SELECT 
    '🔄 STAGING EVENTS AFTER FIX' as staging_check,
    staging_event_id,
    raw_event_id,
    event_type,
    validation_status,
    quality_score,
    processed_timestamp,
    CASE 
        WHEN validation_status = 'VALID' THEN '✅ Valid Event'
        WHEN validation_status = 'SUSPICIOUS' THEN '⚠️ Suspicious Event'
        ELSE '❌ Invalid Event'
    END as validation_summary
FROM staging.site_tracking_events_s
WHERE raw_event_id IN (4, 5)
ORDER BY raw_event_id;

-- Check pipeline flow
SELECT 
    '🔄 COMPLETE PIPELINE STATUS' as pipeline_check,
    r.raw_event_id,
    r.processing_status as raw_status,
    s.staging_event_id,
    s.validation_status as staging_status,
    CASE 
        WHEN s.staging_event_id IS NOT NULL AND r.processing_status = 'PROCESSED' THEN '✅ Complete Success'
        WHEN s.staging_event_id IS NOT NULL THEN '⚠️ Staging Success, Raw Pending'
        WHEN r.processing_status = 'PROCESSED' THEN '⚠️ Raw Success, Staging Missing'
        ELSE '❌ Processing Failed'
    END as pipeline_status
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
WHERE r.raw_event_id IN (4, 5)
ORDER BY r.raw_event_id;

SELECT 
    '🎯 STAGING FIX SUMMARY' as fix_summary,
    'Fixed event_type mapping (was looking for evt_type)' as fix_1,
    'Fixed event_timestamp constraint violation' as fix_2,
    'Added graceful handling of missing optional fields' as fix_3,
    'Updated audit logging to use correct table' as fix_4; 