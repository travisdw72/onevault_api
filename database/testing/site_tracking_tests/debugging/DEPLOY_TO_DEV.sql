-- ============================================================================
-- DEPLOY SITE TRACKING FIXES TO DEV ENVIRONMENT
-- Complete fix deployment based on testing environment resolution
-- ============================================================================
-- Purpose: Deploy all site tracking fixes discovered in testing to Dev
-- Author: One Vault Development Team
-- Date: 2025-06-27
-- Environment: Development
-- ============================================================================

\echo '🚀 DEPLOYING SITE TRACKING FIXES TO DEV ENVIRONMENT...'

-- Step 1: Environment Verification
\echo '🔍 STEP 1: VERIFYING DEV ENVIRONMENT...'

-- Check if raw table exists and has correct structure
\d raw.site_tracking_events_r

-- Verify no processed_timestamp column (this was our key discovery)
SELECT 
    '📋 RAW TABLE STRUCTURE VERIFICATION' as verification,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'raw' 
AND table_name = 'site_tracking_events_r'
AND column_name = 'processed_timestamp';

-- Should return no rows - if it returns a row, the schema is different!

-- Check staging table exists
SELECT 
    '📋 STAGING TABLE VERIFICATION' as verification,
    COUNT(*) as table_exists
FROM information_schema.tables
WHERE table_schema = 'staging' 
AND table_name = 'site_tracking_events_s';

-- Step 2: Deploy Fixed Staging Function
\echo '🛠️ STEP 2: DEPLOYING FIXED STAGING FUNCTION...'

CREATE OR REPLACE FUNCTION staging.process_site_tracking_events()
RETURNS TABLE(
    processed_count INTEGER,
    success_count INTEGER,
    error_count INTEGER,
    processing_summary JSONB
) AS $$
DECLARE
    v_raw_event RECORD;
    v_event_data JSONB;
    v_tenant_hk BYTEA;
    v_validation_status VARCHAR(20);
    v_quality_score DECIMAL(3,2);
    v_validation_errors TEXT[];
    v_enrichment_data JSONB;
    v_event_timestamp TIMESTAMP WITH TIME ZONE;
    v_processed_count INTEGER := 0;
    v_success_count INTEGER := 0;
    v_error_count INTEGER := 0;
    v_processing_errors JSONB := '[]'::JSONB;
BEGIN
    -- Process each raw event that hasn't been processed yet
    FOR v_raw_event IN 
        SELECT * FROM raw.site_tracking_events_r 
        WHERE processing_status = 'PENDING'
        ORDER BY received_timestamp ASC
    LOOP
        BEGIN
            v_processed_count := v_processed_count + 1;
            v_event_data := v_raw_event.raw_payload;
            v_tenant_hk := v_raw_event.tenant_hk;
            
            -- Initialize validation variables
            v_validation_status := 'VALID';
            v_quality_score := 1.0;
            v_validation_errors := ARRAY[]::TEXT[];
            
            -- CRITICAL FIX 1: Use event_type (not evt_type)
            IF v_event_data->>'event_type' IS NULL THEN
                v_validation_errors := array_append(v_validation_errors, 'Missing event_type');
                v_validation_status := 'INVALID';
                v_quality_score := v_quality_score - 0.3;
            END IF;
            
            IF v_event_data->>'session_id' IS NULL THEN
                v_validation_errors := array_append(v_validation_errors, 'Missing session_id');
                v_quality_score := v_quality_score - 0.2;
            END IF;
            
            -- Determine event timestamp
            v_event_timestamp := COALESCE(
                (v_event_data->>'timestamp')::TIMESTAMP WITH TIME ZONE,
                v_raw_event.received_timestamp
            );
            
            -- CRITICAL FIX 2: Fixed jsonb_object_keys() usage
            v_enrichment_data := jsonb_build_object(
                'processing_version', 'DEV_2.0_fixed',
                'enrichment_timestamp', CURRENT_TIMESTAMP,
                'field_mapping_corrected', true,
                'original_fields', (
                    SELECT array_agg(key) 
                    FROM jsonb_object_keys(v_event_data) AS key
                ),
                'validation_applied', true,
                'tenant_verified', true,
                'environment', 'development'
            );
            
            -- Insert into staging table
            INSERT INTO staging.site_tracking_events_s (
                raw_event_id,
                tenant_hk,
                event_type,
                session_id,
                user_id,
                page_url,
                page_title,
                referrer_url,
                event_timestamp,
                processed_timestamp,
                validation_status,
                enrichment_status,
                quality_score,
                enrichment_data,
                validation_errors,
                record_source
            ) VALUES (
                v_raw_event.raw_event_id,
                v_tenant_hk,
                v_event_data->>'event_type',  -- FIXED: Use event_type
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
                'dev_staging_processor_v2.0'
            );
            
            -- CRITICAL FIX 3: Update raw event status (NO processed_timestamp!)
            UPDATE raw.site_tracking_events_r 
            SET processing_status = 'PROCESSED'
            WHERE raw_event_id = v_raw_event.raw_event_id;
            
            v_success_count := v_success_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            
            -- Log the error
            v_processing_errors := v_processing_errors || jsonb_build_object(
                'raw_event_id', v_raw_event.raw_event_id,
                'error_message', SQLERRM,
                'error_timestamp', CURRENT_TIMESTAMP,
                'environment', 'development'
            );
            
            -- CRITICAL FIX 3: Update raw event with error status (NO processed_timestamp!)
            UPDATE raw.site_tracking_events_r 
            SET processing_status = 'ERROR',
                error_message = SQLERRM
            WHERE raw_event_id = v_raw_event.raw_event_id;
        END;
    END LOOP;
    
    -- Return processing summary
    RETURN QUERY SELECT 
        v_processed_count,
        v_success_count,
        v_error_count,
        jsonb_build_object(
            'processed_timestamp', CURRENT_TIMESTAMP,
            'processing_version', 'DEV_2.0_fixed',
            'environment', 'development',
            'errors', v_processing_errors,
            'success_rate', CASE 
                WHEN v_processed_count > 0 THEN 
                    ROUND((v_success_count::DECIMAL / v_processed_count) * 100, 2)
                ELSE 0 
            END,
            'fixes_applied', ARRAY[
                'Fixed event_type field mapping',
                'Fixed jsonb_object_keys usage',
                'Removed processed_timestamp references'
            ]
        );
END;
$$ LANGUAGE plpgsql;

-- Step 3: Deploy Individual Event Processing Function
\echo '🔧 STEP 3: DEPLOYING INDIVIDUAL EVENT PROCESSING FUNCTION...'

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
    
    -- Create enrichment data with fixed jsonb_object_keys
    v_enrichment_data := jsonb_build_object(
        'processing_version', 'DEV_2.0_individual_fixed',
        'enrichment_timestamp', CURRENT_TIMESTAMP,
        'field_mapping_corrected', true,
        'original_fields', (
            SELECT array_agg(key) 
            FROM jsonb_object_keys(v_event_data) AS key
        ),
        'environment', 'development'
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
        event_timestamp,
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
        'dev_site_tracker_individual'
    ) RETURNING staging_event_id INTO v_staging_event_id;
    
    -- Update raw event status (NO processed_timestamp column!)
    UPDATE raw.site_tracking_events_r 
    SET processing_status = 'PROCESSED'
    WHERE raw_event_id = p_raw_event_id;
    
    RETURN v_staging_event_id;
    
EXCEPTION WHEN OTHERS THEN
    -- Update raw event with error (NO processed_timestamp column!)
    UPDATE raw.site_tracking_events_r 
    SET processing_status = 'ERROR',
        error_message = SQLERRM
    WHERE raw_event_id = p_raw_event_id;
    
    RAISE EXCEPTION 'Failed to process raw event % to staging: %', p_raw_event_id, SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Test Deployment
\echo '🧪 STEP 4: TESTING DEV DEPLOYMENT...'

-- Check if there are any pending events to test with
SELECT 
    '📊 DEV ENVIRONMENT TEST DATA' as test_data,
    COUNT(*) as total_raw_events,
    COUNT(*) FILTER (WHERE processing_status = 'PENDING') as pending_events,
    COUNT(*) FILTER (WHERE processing_status = 'PROCESSED') as processed_events,
    COUNT(*) FILTER (WHERE processing_status = 'ERROR') as error_events
FROM raw.site_tracking_events_r;

-- If there are pending events, test the function
DO $$
DECLARE
    v_pending_count INTEGER;
    v_result RECORD;
BEGIN
    SELECT COUNT(*) INTO v_pending_count
    FROM raw.site_tracking_events_r 
    WHERE processing_status = 'PENDING';
    
    IF v_pending_count > 0 THEN
        RAISE NOTICE 'Testing with % pending events...', v_pending_count;
        
        SELECT * INTO v_result FROM staging.process_site_tracking_events();
        
        RAISE NOTICE 'DEV TEST RESULTS: Processed: %, Success: %, Errors: %, Success Rate: %', 
                     v_result.processed_count,
                     v_result.success_count, 
                     v_result.error_count,
                     v_result.processing_summary->>'success_rate';
    ELSE
        RAISE NOTICE 'No pending events found in Dev environment - deployment successful but no test data';
    END IF;
END $$;

-- Step 5: Deployment Verification
\echo '✅ STEP 5: DEV DEPLOYMENT VERIFICATION...'

-- Verify functions exist
SELECT 
    '✅ FUNCTION DEPLOYMENT VERIFICATION' as verification,
    p.proname as function_name,
    'EXISTS' as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'staging'
AND p.proname IN ('process_site_tracking_events', 'validate_and_enrich_event')
ORDER BY p.proname;

-- Final status
SELECT 
    '🎉 DEV DEPLOYMENT COMPLETE' as deployment_status,
    'All critical fixes applied to Dev environment' as summary,
    CURRENT_TIMESTAMP as deployment_timestamp,
    'Ready for Mock environment deployment' as next_step;

\echo '🎉 DEV DEPLOYMENT COMPLETE!'
\echo '📋 FIXES APPLIED:'
\echo '   ✅ Fixed event_type field mapping (was evt_type)'
\echo '   ✅ Fixed jsonb_object_keys() usage with proper subquery'
\echo '   ✅ Removed processed_timestamp column references'
\echo '   ✅ Enhanced error handling and validation'
\echo '   ✅ Added environment-specific tracking'
\echo ''
\echo '🚀 NEXT STEPS:'
\echo '   1. Test Dev environment with real site tracking events'
\echo '   2. Deploy to Mock environment using DEPLOY_TO_MOCK.sql'
\echo '   3. Deploy to Production using DEPLOY_TO_PRODUCTION.sql' 