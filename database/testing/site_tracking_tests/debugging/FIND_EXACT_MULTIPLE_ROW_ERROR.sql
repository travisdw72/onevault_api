-- ============================================================================
-- FIND EXACT MULTIPLE ROW ERROR
-- Minimal diagnostic to isolate the problematic query
-- ============================================================================

-- Test each part of the function individually to find the culprit
\echo '🔍 TESTING EACH PART OF THE STAGING FUNCTION...'

-- Test 1: Raw event selection
DO $$
DECLARE
    v_raw_event RECORD;
BEGIN
    SELECT * INTO v_raw_event
    FROM raw.site_tracking_events_r
    WHERE raw_event_id = 4;
    
    RAISE NOTICE '✅ Test 1 PASSED: Raw event selection works';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Test 1 FAILED: Raw event selection: %', SQLERRM;
END $$;

-- Test 2: JSON payload access
DO $$
DECLARE
    v_raw_event RECORD;
    v_event_data JSONB;
BEGIN
    SELECT * INTO v_raw_event FROM raw.site_tracking_events_r WHERE raw_event_id = 4;
    v_event_data := v_raw_event.raw_payload;
    
    RAISE NOTICE '✅ Test 2 PASSED: JSON payload access works';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Test 2 FAILED: JSON payload access: %', SQLERRM;
END $$;

-- Test 3: Check for problematic jsonb_object_keys function
DO $$
DECLARE
    v_raw_event RECORD;
    v_event_data JSONB;
    v_keys TEXT[];
BEGIN
    SELECT * INTO v_raw_event FROM raw.site_tracking_events_r WHERE raw_event_id = 4;
    v_event_data := v_raw_event.raw_payload;
    
    -- This might be the culprit!
    SELECT array_agg(key) INTO v_keys FROM jsonb_object_keys(v_event_data) AS key;
    
    RAISE NOTICE '✅ Test 3 PASSED: jsonb_object_keys works, found % keys', array_length(v_keys, 1);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Test 3 FAILED: jsonb_object_keys issue: %', SQLERRM;
END $$;

-- Test 4: Check the enrichment_data building
DO $$
DECLARE
    v_raw_event RECORD;
    v_event_data JSONB;
    v_enrichment_data JSONB;
BEGIN
    SELECT * INTO v_raw_event FROM raw.site_tracking_events_r WHERE raw_event_id = 4;
    v_event_data := v_raw_event.raw_payload;
    
    -- This is likely the problem - jsonb_object_keys returns a set, not a single value
    v_enrichment_data := jsonb_build_object(
        'processing_version', '2.0_fixed',
        'enrichment_timestamp', CURRENT_TIMESTAMP,
        'field_mapping_corrected', true,
        'original_fields', (SELECT array_agg(key) FROM jsonb_object_keys(v_event_data) AS key)  -- FIXED VERSION
    );
    
    RAISE NOTICE '✅ Test 4 PASSED: enrichment_data building works';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Test 4 FAILED: enrichment_data building: %', SQLERRM;
END $$;

-- Test 5: Try the INSERT statement structure
DO $$
DECLARE
    v_raw_event RECORD;
    v_event_data JSONB;
    v_validation_status VARCHAR(20) := 'VALID';
    v_quality_score DECIMAL(3,2) := 1.0;
    v_validation_errors TEXT[] := ARRAY[]::TEXT[];
    v_enrichment_data JSONB;
    v_event_timestamp TIMESTAMP WITH TIME ZONE;
    v_staging_event_id INTEGER;
BEGIN
    SELECT * INTO v_raw_event FROM raw.site_tracking_events_r WHERE raw_event_id = 4;
    v_event_data := v_raw_event.raw_payload;
    v_event_timestamp := COALESCE(
        (v_event_data->>'timestamp')::TIMESTAMP WITH TIME ZONE,
        v_raw_event.received_timestamp
    );
    
    -- Fixed enrichment data
    v_enrichment_data := jsonb_build_object(
        'processing_version', '2.0_fixed',
        'enrichment_timestamp', CURRENT_TIMESTAMP,
        'field_mapping_corrected', true,
        'original_fields', (SELECT array_agg(key) FROM jsonb_object_keys(v_event_data) AS key)
    );
    
    -- Test INSERT (but rollback)
    INSERT INTO staging.site_tracking_events_s (
        raw_event_id, tenant_hk, event_type, session_id, user_id,
        page_url, page_title, referrer_url, event_timestamp,
        processed_timestamp, validation_status, enrichment_status,
        quality_score, enrichment_data, validation_errors, record_source
    ) VALUES (
        999999,  -- Use fake ID to avoid conflicts
        v_raw_event.tenant_hk,
        v_event_data->>'event_type',
        v_event_data->>'session_id',
        v_event_data->>'user_id',
        v_event_data->>'page_url',
        v_event_data->>'page_title',
        v_event_data->>'referrer',
        v_event_timestamp,
        CURRENT_TIMESTAMP,
        v_validation_status,
        'ENRICHED',
        v_quality_score,
        v_enrichment_data,
        v_validation_errors,
        'site_tracker_test'
    ) RETURNING staging_event_id INTO v_staging_event_id;
    
    -- Clean up test record
    DELETE FROM staging.site_tracking_events_s WHERE staging_event_id = v_staging_event_id;
    
    RAISE NOTICE '✅ Test 5 PASSED: INSERT statement works, staging_event_id: %', v_staging_event_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Test 5 FAILED: INSERT statement: %', SQLERRM;
END $$;

\echo '🎯 DIAGNOSIS: The error is likely in the jsonb_object_keys() function call';
\echo '💡 SOLUTION: Replace jsonb_object_keys(v_event_data) with array_agg subquery'; 