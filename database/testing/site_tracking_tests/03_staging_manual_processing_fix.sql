-- ============================================================================
-- MANUAL STAGING PROCESSING FIX
-- Site Tracking System Testing
-- ============================================================================
-- Purpose: Fix the event_type mapping issue and manually process raw event 4
-- Issue: Staging function expects 'evt_type' but raw data has 'event_type'
-- ============================================================================

-- 3.1 Pre-Processing Analysis
SELECT 
    '🔧 PRE-PROCESSING ANALYSIS' as fix_phase,
    r.raw_event_id,
    r.processing_status as current_raw_status,
    r.raw_payload->>'event_type' as has_event_type,
    r.raw_payload->>'evt_type' as has_evt_type,
    CASE 
        WHEN r.raw_payload ? 'event_type' THEN 'event_type field exists'
        WHEN r.raw_payload ? 'evt_type' THEN 'evt_type field exists'
        ELSE 'No event type field found'
    END as field_analysis
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4;

-- 3.2 Manual Data Extraction and Processing
DO $$
DECLARE
    v_raw_event RECORD;
    v_staging_event_id INTEGER;
    v_event_data JSONB;
    v_validation_errors TEXT[] := ARRAY[]::TEXT[];
    v_quality_score DECIMAL(3,2) := 1.0;
    v_validation_status VARCHAR(20) := 'VALID';
    v_device_type VARCHAR(50);
    v_browser_name VARCHAR(50);
    v_operating_system VARCHAR(50);
    v_event_type VARCHAR(50);
    v_page_url TEXT;
    v_session_id VARCHAR(255);
    v_event_timestamp TIMESTAMP WITH TIME ZONE;
BEGIN
    RAISE NOTICE '🚀 Starting manual staging processing for raw_event_id = 4';
    
    -- Get raw event data
    SELECT * INTO v_raw_event
    FROM raw.site_tracking_events_r 
    WHERE raw_event_id = 4;
    
    IF v_raw_event.raw_event_id IS NULL THEN
        RAISE EXCEPTION 'Raw event 4 not found';
    END IF;
    
    v_event_data := v_raw_event.raw_payload;
    
    -- Extract event type (handle both 'event_type' and 'evt_type')
    v_event_type := COALESCE(v_event_data->>'evt_type', v_event_data->>'event_type');
    
    -- Extract other key fields
    v_page_url := v_event_data->>'page_url';
    v_session_id := v_event_data->>'session_id';
    v_event_timestamp := COALESCE(
        (v_event_data->>'timestamp')::TIMESTAMP WITH TIME ZONE, 
        v_raw_event.received_timestamp
    );
    
    -- Validate required fields
    IF v_event_type IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Missing event_type/evt_type');
        v_quality_score := v_quality_score - 0.3;
    END IF;
    
    IF v_page_url IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Missing page_url');
        v_quality_score := v_quality_score - 0.2;
    END IF;
    
    -- Parse device information from user agent
    SELECT 
        CASE 
            WHEN v_raw_event.user_agent ~* 'mobile|android|iphone' THEN 'mobile'
            WHEN v_raw_event.user_agent ~* 'tablet|ipad' THEN 'tablet'  
            ELSE 'desktop'
        END,
        CASE 
            WHEN v_raw_event.user_agent ~* 'chrome' THEN 'Chrome'
            WHEN v_raw_event.user_agent ~* 'firefox' THEN 'Firefox'
            WHEN v_raw_event.user_agent ~* 'safari' THEN 'Safari'
            WHEN v_raw_event.user_agent ~* 'edge' THEN 'Edge'
            ELSE 'Unknown'
        END,
        CASE 
            WHEN v_raw_event.user_agent ~* 'windows' THEN 'Windows'
            WHEN v_raw_event.user_agent ~* 'mac os' THEN 'macOS'
            WHEN v_raw_event.user_agent ~* 'linux' THEN 'Linux'
            WHEN v_raw_event.user_agent ~* 'android' THEN 'Android'
            WHEN v_raw_event.user_agent ~* 'ios|iphone|ipad' THEN 'iOS'
            ELSE 'Unknown'
        END
    INTO v_device_type, v_browser_name, v_operating_system;
    
    -- Determine final validation status
    IF array_length(v_validation_errors, 1) > 2 OR v_quality_score < 0.5 THEN
        v_validation_status := 'INVALID';
    END IF;
    
    RAISE NOTICE 'Processing event_type: %, page_url: %, validation_status: %', 
                 v_event_type, v_page_url, v_validation_status;
    
    -- Insert into staging table with corrected field mapping
    INSERT INTO staging.site_tracking_events_s (
        raw_event_id, 
        tenant_hk, 
        event_type, 
        session_id, 
        user_id,
        page_url, 
        page_title, 
        referrer_url,
        device_type, 
        browser_name, 
        operating_system,
        event_timestamp, 
        validation_status, 
        enrichment_status, 
        quality_score, 
        validation_errors,
        enrichment_data,
        record_source
    ) VALUES (
        v_raw_event.raw_event_id,
        v_raw_event.tenant_hk,
        v_event_type,
        v_session_id,
        v_event_data->>'user_id',
        v_page_url,
        v_event_data->>'page_title',
        v_event_data->>'referrer',
        v_device_type,
        v_browser_name,
        v_operating_system,
        v_event_timestamp,
        v_validation_status,
        'ENRICHED',
        v_quality_score,
        v_validation_errors,
        jsonb_build_object(
            'processing_version', '1.0_manual',
            'enrichment_timestamp', CURRENT_TIMESTAMP,
            'user_agent_parsed', true,
            'field_mapping_fixed', true,
            'event_type_source', CASE WHEN v_event_data ? 'evt_type' THEN 'evt_type' ELSE 'event_type' END
        ),
        'manual_processor'
    ) RETURNING staging_event_id INTO v_staging_event_id;
    
    -- Update raw event status
    UPDATE raw.site_tracking_events_r 
    SET processing_status = 'PROCESSED'
    WHERE raw_event_id = 4;
    
    RAISE NOTICE '✅ Manual staging processing completed: staging_event_id = %', v_staging_event_id;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Manual staging processing error: %', SQLERRM;
    
    -- Update raw event with error
    UPDATE raw.site_tracking_events_r 
    SET processing_status = 'ERROR',
        error_message = 'Manual processing failed: ' || SQLERRM
    WHERE raw_event_id = 4;
END;
$$;

-- 3.3 Verify Manual Processing Results
SELECT 
    '✅ MANUAL PROCESSING VERIFICATION' as verification_phase,
    s.staging_event_id,
    s.raw_event_id,
    s.event_type,
    s.session_id,
    s.page_url,
    s.validation_status,
    s.enrichment_status,
    s.quality_score,
    s.validation_errors,
    jsonb_pretty(s.enrichment_data) as enrichment_details
FROM staging.site_tracking_events_s s
WHERE s.raw_event_id = 4;

-- 3.4 Check Raw Event Status Update
SELECT 
    '📊 RAW EVENT STATUS UPDATE' as status_check,
    raw_event_id,
    processing_status,
    error_message,
    retry_count
FROM raw.site_tracking_events_r
WHERE raw_event_id = 4;

-- ============================================================================
-- PROCESSING SUMMARY
-- ============================================================================
SELECT 
    '🎯 MANUAL PROCESSING COMPLETE' as summary,
    'Check results above for:' as instructions,
    '1. Manual staging record creation' as result1,
    '2. Field mapping correction' as result2,
    '3. Raw event status update' as result3,
    '4. Enrichment data validation' as result4; 