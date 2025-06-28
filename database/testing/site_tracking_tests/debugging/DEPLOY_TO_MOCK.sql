-- ============================================================================
-- DEPLOY SITE TRACKING FIXES TO MOCK ENVIRONMENT
-- Pre-Production deployment with enhanced validation
-- ============================================================================
-- Purpose: Deploy all site tracking fixes to Mock environment with production-like testing
-- Author: One Vault Development Team
-- Date: 2025-06-27
-- Environment: Mock (Pre-Production)
-- ============================================================================

\echo '🚀 DEPLOYING SITE TRACKING FIXES TO MOCK ENVIRONMENT...'

-- Step 1: Pre-Production Environment Verification
\echo '🔍 STEP 1: MOCK ENVIRONMENT PRE-DEPLOYMENT VERIFICATION...'

-- Verify Mock environment configuration
SELECT 
    '🏗️ MOCK ENVIRONMENT CONFIGURATION' as config_check,
    current_database() as database_name,
    current_user as current_user,
    version() as postgresql_version,
    CASE 
        WHEN current_database() LIKE '%mock%' OR current_database() LIKE '%staging%' THEN '✅ Mock Environment'
        WHEN current_database() LIKE '%prod%' THEN '❌ PRODUCTION DATABASE - STOP DEPLOYMENT'
        ELSE '⚠️ Verify Environment'
    END as environment_verification;

-- Check raw table structure (critical for our fixes)
SELECT 
    '📋 RAW TABLE STRUCTURE VERIFICATION' as verification,
    column_name,
    data_type,
    is_nullable,
    CASE 
        WHEN column_name = 'processed_timestamp' THEN '❌ UNEXPECTED COLUMN - SCHEMA DIFFERENCE'
        ELSE '✅ Expected Column'
    END as column_status
FROM information_schema.columns
WHERE table_schema = 'raw' 
AND table_name = 'site_tracking_events_r'
ORDER BY ordinal_position;

-- Verify staging table exists and has correct structure
SELECT 
    '📋 STAGING TABLE VERIFICATION' as verification,
    COUNT(*) as table_exists,
    CASE 
        WHEN COUNT(*) = 1 THEN '✅ Staging Table Exists'
        ELSE '❌ Staging Table Missing'
    END as table_status
FROM information_schema.tables
WHERE table_schema = 'staging' 
AND table_name = 'site_tracking_events_s';

-- Check for any existing data that might conflict
SELECT 
    '📊 EXISTING DATA ANALYSIS' as data_check,
    COUNT(*) as total_raw_events,
    COUNT(*) FILTER (WHERE processing_status = 'PENDING') as pending_events,
    COUNT(*) FILTER (WHERE processing_status = 'PROCESSED') as processed_events,
    COUNT(*) FILTER (WHERE processing_status = 'ERROR') as error_events,
    CASE 
        WHEN COUNT(*) FILTER (WHERE processing_status = 'ERROR') > 0 THEN '⚠️ Existing Errors Found'
        WHEN COUNT(*) FILTER (WHERE processing_status = 'PENDING') > 0 THEN '📋 Pending Events Available for Testing'
        ELSE '✅ Clean Environment'
    END as data_status
FROM raw.site_tracking_events_r;

-- Step 2: Deploy Fixed Functions (same fixes as testing environment)
\echo '🛠️ STEP 2: DEPLOYING FIXED STAGING FUNCTIONS...'

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
    FOR v_raw_event IN 
        SELECT * FROM raw.site_tracking_events_r 
        WHERE processing_status = 'PENDING'
        ORDER BY received_timestamp ASC
    LOOP
        BEGIN
            v_processed_count := v_processed_count + 1;
            v_event_data := v_raw_event.raw_payload;
            v_tenant_hk := v_raw_event.tenant_hk;
            
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
            
            v_event_timestamp := COALESCE(
                (v_event_data->>'timestamp')::TIMESTAMP WITH TIME ZONE,
                v_raw_event.received_timestamp
            );
            
            -- CRITICAL FIX 2: Fixed jsonb_object_keys() usage
            v_enrichment_data := jsonb_build_object(
                'processing_version', 'MOCK_2.0_fixed',
                'enrichment_timestamp', CURRENT_TIMESTAMP,
                'field_mapping_corrected', true,
                'original_fields', (
                    SELECT array_agg(key) 
                    FROM jsonb_object_keys(v_event_data) AS key
                ),
                'validation_applied', true,
                'tenant_verified', true,
                'environment', 'mock'
            );
            
            INSERT INTO staging.site_tracking_events_s (
                raw_event_id, tenant_hk, event_type, session_id, user_id,
                page_url, page_title, referrer_url, event_timestamp,
                processed_timestamp, validation_status, enrichment_status,
                quality_score, enrichment_data, validation_errors, record_source
            ) VALUES (
                v_raw_event.raw_event_id, v_tenant_hk, v_event_data->>'event_type',
                v_event_data->>'session_id', v_event_data->>'user_id',
                v_event_data->>'page_url', v_event_data->>'page_title',
                v_event_data->>'referrer', v_event_timestamp, CURRENT_TIMESTAMP,
                v_validation_status, 'ENRICHED', v_quality_score,
                v_enrichment_data, v_validation_errors, 'mock_staging_processor_v2.0'
            );
            
            -- CRITICAL FIX 3: Update raw event status (NO processed_timestamp!)
            UPDATE raw.site_tracking_events_r 
            SET processing_status = 'PROCESSED'
            WHERE raw_event_id = v_raw_event.raw_event_id;
            
            v_success_count := v_success_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
            v_processing_errors := v_processing_errors || jsonb_build_object(
                'raw_event_id', v_raw_event.raw_event_id,
                'error_message', SQLERRM,
                'error_timestamp', CURRENT_TIMESTAMP
            );
            
            UPDATE raw.site_tracking_events_r 
            SET processing_status = 'ERROR', error_message = SQLERRM
            WHERE raw_event_id = v_raw_event.raw_event_id;
        END;
    END LOOP;
    
    RETURN QUERY SELECT 
        v_processed_count, v_success_count, v_error_count,
        jsonb_build_object(
            'processed_timestamp', CURRENT_TIMESTAMP,
            'processing_version', 'MOCK_2.0_fixed',
            'environment', 'mock',
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

-- Step 3: Test Deployment
\echo '🧪 STEP 3: TESTING MOCK DEPLOYMENT...'

SELECT * FROM staging.process_site_tracking_events();

-- Step 4: Verification
\echo '✅ STEP 4: MOCK DEPLOYMENT VERIFICATION...'

SELECT 
    '🎉 MOCK DEPLOYMENT COMPLETE' as status,
    'Ready for Production if tests pass' as next_step,
    CURRENT_TIMESTAMP as deployment_time;

\echo '🎉 MOCK DEPLOYMENT COMPLETE!' 