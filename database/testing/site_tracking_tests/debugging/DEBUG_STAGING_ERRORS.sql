-- ============================================================================
-- DEBUG STAGING PROCESSING ERRORS
-- Site Tracking System - Staging Layer Debugging
-- ============================================================================
-- Purpose: Identify and fix staging processing errors for events 4 & 5
-- Issues: Events stuck in PENDING, staging processing fails
-- ============================================================================

-- Step 1: Check Audit Table Structure
\echo '🔍 STEP 1: CHECKING AUDIT TABLE STRUCTURE...'

-- Check if audit tables exist
SELECT 
    '📋 AUDIT TABLES CHECK' as table_check,
    schemaname,
    tablename,
    'EXISTS' as status
FROM pg_tables 
WHERE schemaname = 'audit'
ORDER BY tablename;

-- Check for alternative audit table names
SELECT 
    '🔍 SEARCHING FOR AUDIT TABLES' as search_type,
    schemaname,
    tablename
FROM pg_tables 
WHERE tablename LIKE '%audit%'
ORDER BY schemaname, tablename;

-- Step 2: Manual Staging Processing with Error Capture
\echo '🛠️ STEP 2: MANUAL STAGING PROCESSING WITH ERROR CAPTURE...'

-- Try to process event 4 manually and capture the specific error
DO $$
DECLARE
    v_error_message TEXT;
    v_staging_result INTEGER;
BEGIN
    BEGIN
        -- Try to process event 4
        SELECT staging.validate_and_enrich_event(4) INTO v_staging_result;
        RAISE NOTICE 'Event 4 processed successfully. Staging ID: %', v_staging_result;
    EXCEPTION WHEN OTHERS THEN
        v_error_message := SQLERRM;
        RAISE NOTICE 'Event 4 processing failed: %', v_error_message;
    END;
    
    BEGIN
        -- Try to process event 5
        SELECT staging.validate_and_enrich_event(5) INTO v_staging_result;
        RAISE NOTICE 'Event 5 processed successfully. Staging ID: %', v_staging_result;
    EXCEPTION WHEN OTHERS THEN
        v_error_message := SQLERRM;
        RAISE NOTICE 'Event 5 processing failed: %', v_error_message;
    END;
END $$;

-- Step 3: Check Raw Event Data Structure
\echo '📊 STEP 3: CHECKING RAW EVENT DATA STRUCTURE...'

SELECT 
    '📊 RAW EVENT DATA ANALYSIS' as analysis_type,
    r.raw_event_id,
    r.raw_payload->>'event_type' as event_type_field,
    r.raw_payload->>'evt_type' as evt_type_field,
    CASE 
        WHEN r.raw_payload ? 'event_type' THEN '✅ Has event_type'
        WHEN r.raw_payload ? 'evt_type' THEN '⚠️ Has evt_type (needs mapping)'
        ELSE '❌ Missing event type field'
    END as event_type_status,
    jsonb_object_keys(r.raw_payload) as available_keys
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id IN (4, 5);

-- Step 4: Check Staging Table Structure
\echo '🏗️ STEP 4: CHECKING STAGING TABLE STRUCTURE...'

-- Check if staging table exists and its structure
SELECT 
    '🏗️ STAGING TABLE STRUCTURE' as table_info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'staging' 
AND table_name = 'site_tracking_events_s'
ORDER BY ordinal_position;

-- Step 5: Check Staging Function Exists
\echo '🔧 STEP 5: CHECKING STAGING FUNCTIONS...'

SELECT 
    '🔧 STAGING FUNCTIONS CHECK' as function_check,
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as function_args,
    'EXISTS' as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'staging'
AND p.proname LIKE '%validate%'
ORDER BY p.proname;

-- Step 6: Simplified Manual Processing Test
\echo '🧪 STEP 6: SIMPLIFIED MANUAL PROCESSING TEST...'

-- Try a very basic insert to staging to test table accessibility
DO $$
DECLARE
    v_raw_event RECORD;
    v_staging_id INTEGER;
BEGIN
    -- Get raw event 4 data
    SELECT * INTO v_raw_event
    FROM raw.site_tracking_events_r
    WHERE raw_event_id = 4;
    
    -- Try basic staging insert
    BEGIN
        INSERT INTO staging.site_tracking_events_s (
            raw_event_id,
            tenant_hk,
            event_type,
            page_url,
            processed_timestamp,
            validation_status,
            quality_score,
            record_source
        ) VALUES (
            v_raw_event.raw_event_id,
            v_raw_event.tenant_hk,
            COALESCE(v_raw_event.raw_payload->>'event_type', v_raw_event.raw_payload->>'evt_type', 'unknown'),
            v_raw_event.raw_payload->>'page_url',
            CURRENT_TIMESTAMP,
            'PENDING_VALIDATION',
            0.5,
            'manual_test'
        ) RETURNING staging_event_id INTO v_staging_id;
        
        RAISE NOTICE 'Manual staging insert successful. Staging ID: %', v_staging_id;
        
        -- Update raw event status
        UPDATE raw.site_tracking_events_r 
        SET processing_status = 'PROCESSED'
        WHERE raw_event_id = 4;
        
        RAISE NOTICE 'Raw event 4 status updated to PROCESSED';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Manual staging insert failed: %', SQLERRM;
    END;
END $$;

-- Step 7: Check for Field Mapping Issues
\echo '🔍 STEP 7: CHECKING FIELD MAPPING ISSUES...'

-- Check what fields the staging function expects vs what raw events provide
WITH raw_fields AS (
    SELECT 
        raw_event_id,
        jsonb_object_keys(raw_payload) as field_name
    FROM raw.site_tracking_events_r
    WHERE raw_event_id IN (4, 5)
),
expected_fields AS (
    SELECT unnest(ARRAY[
        'event_type', 'evt_type', 'session_id', 'user_id', 'page_url', 
        'page_title', 'referrer', 'timestamp'
    ]) as expected_field
)
SELECT 
    '🔍 FIELD MAPPING ANALYSIS' as mapping_analysis,
    e.expected_field,
    COUNT(r.field_name) as found_in_events,
    CASE 
        WHEN COUNT(r.field_name) > 0 THEN '✅ Available'
        ELSE '❌ Missing'
    END as availability_status
FROM expected_fields e
LEFT JOIN raw_fields r ON e.expected_field = r.field_name
GROUP BY e.expected_field
ORDER BY e.expected_field;

-- Step 8: Check if evt_type vs event_type is the issue
\echo '⚠️ STEP 8: CHECKING evt_type vs event_type MAPPING...'

SELECT 
    '⚠️ EVENT TYPE FIELD MAPPING' as mapping_issue,
    raw_event_id,
    raw_payload->>'event_type' as has_event_type,
    raw_payload->>'evt_type' as has_evt_type,
    CASE 
        WHEN raw_payload ? 'event_type' THEN 'Uses event_type'
        WHEN raw_payload ? 'evt_type' THEN 'Uses evt_type (needs function fix)'
        ELSE 'Missing both'
    END as mapping_needed
FROM raw.site_tracking_events_r
WHERE raw_event_id IN (4, 5);

-- Final diagnosis
SELECT 
    '🎯 STAGING PROCESSING DIAGNOSIS' as diagnosis,
    'Check NOTICE messages above for specific errors' as step_1,
    'Field mapping issues likely causing staging failures' as step_2,
    'Manual insert test will show if basic staging works' as step_3; 