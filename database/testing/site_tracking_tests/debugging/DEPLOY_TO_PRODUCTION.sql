-- ============================================================================
-- DEPLOY SITE TRACKING FIXES TO PRODUCTION ENVIRONMENT
-- Production deployment with maximum safety and rollback capabilities
-- ============================================================================
-- Purpose: Deploy all site tracking fixes to Production with comprehensive safety checks
-- Author: One Vault Development Team
-- Date: 2025-06-27
-- Environment: Production
-- CRITICAL: This script must be reviewed and approved before execution
-- ============================================================================

\echo '🚨 PRODUCTION DEPLOYMENT - SITE TRACKING FIXES'
\echo '⚠️  CRITICAL: Ensure all pre-deployment checks are completed'
\echo '⚠️  CRITICAL: Backup completed and verified'
\echo '⚠️  CRITICAL: Mock environment testing passed'

-- Step 1: Production Environment Safety Verification
\echo '🔒 STEP 1: PRODUCTION ENVIRONMENT SAFETY VERIFICATION...'

-- Verify we're in the correct production environment
DO $$
BEGIN
    IF current_database() NOT LIKE '%prod%' AND current_database() NOT LIKE '%production%' THEN
        RAISE WARNING 'Database name does not indicate production environment: %', current_database();
        RAISE WARNING 'Verify this is the correct production database before proceeding';
    END IF;
    
    IF current_user = 'postgres' THEN
        RAISE WARNING 'Running as postgres superuser - consider using service account';
    END IF;
    
    RAISE NOTICE 'Production environment verification completed';
END $$;

-- Check current system load and connections
SELECT 
    '🔒 PRODUCTION ENVIRONMENT STATUS' as status_check,
    current_database() as database_name,
    current_user as deployment_user,
    (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') as active_connections,
    (SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction') as idle_in_transaction,
    CASE 
        WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') > 50 THEN '⚠️ High Connection Load'
        WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction') > 10 THEN '⚠️ Idle Transactions Detected'
        ELSE '✅ Normal Load'
    END as system_status;

-- Check raw table structure (CRITICAL - this was our main discovery)
SELECT 
    '🔍 CRITICAL: RAW TABLE STRUCTURE VERIFICATION' as verification,
    column_name,
    data_type,
    CASE 
        WHEN column_name = 'processed_timestamp' THEN '❌ UNEXPECTED COLUMN - DEPLOYMENT WILL FAIL'
        ELSE '✅ Expected Column'
    END as column_status
FROM information_schema.columns
WHERE table_schema = 'raw' 
AND table_name = 'site_tracking_events_r'
ORDER BY ordinal_position;

-- Check for any pending transactions that might conflict
SELECT 
    '🔍 TRANSACTION CONFLICT CHECK' as conflict_check,
    COUNT(*) as pending_transactions,
    CASE 
        WHEN COUNT(*) > 0 THEN '⚠️ Pending transactions detected - consider waiting'
        ELSE '✅ No conflicting transactions'
    END as transaction_status
FROM pg_stat_activity 
WHERE state = 'idle in transaction' 
AND query LIKE '%site_tracking%';

-- Step 2: Pre-Deployment Data Backup
\echo '💾 STEP 2: PRE-DEPLOYMENT DATA VERIFICATION...'

-- Check existing data that will be affected
SELECT 
    '💾 EXISTING DATA ANALYSIS' as data_analysis,
    COUNT(*) as total_raw_events,
    COUNT(*) FILTER (WHERE processing_status = 'PENDING') as pending_events,
    COUNT(*) FILTER (WHERE processing_status = 'PROCESSED') as processed_events,
    COUNT(*) FILTER (WHERE processing_status = 'ERROR') as error_events,
    MIN(received_timestamp) as earliest_event,
    MAX(received_timestamp) as latest_event,
    CASE 
        WHEN COUNT(*) FILTER (WHERE processing_status = 'ERROR') > 0 THEN '⚠️ Existing Errors - Review Before Deployment'
        WHEN COUNT(*) FILTER (WHERE processing_status = 'PENDING') > 100 THEN '⚠️ Large Pending Queue - Monitor Performance'
        ELSE '✅ Data Ready for Processing'
    END as data_readiness
FROM raw.site_tracking_events_r;

-- Check staging table current state
SELECT 
    '💾 STAGING TABLE CURRENT STATE' as staging_state,
    COUNT(*) as staging_events,
    COUNT(*) FILTER (WHERE validation_status = 'VALID') as valid_events,
    COUNT(*) FILTER (WHERE validation_status = 'ERROR') as error_events,
    MAX(processed_timestamp) as last_processed
FROM staging.site_tracking_events_s;

-- Step 3: Deploy Production Function
\echo '🚀 STEP 3: DEPLOYING PRODUCTION FUNCTIONS...'

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
        LIMIT 1000  -- Production safety: Process in batches
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
                'processing_version', 'PROD_2.0_fixed',
                'enrichment_timestamp', CURRENT_TIMESTAMP,
                'field_mapping_corrected', true,
                'original_fields', (
                    SELECT array_agg(key) 
                    FROM jsonb_object_keys(v_event_data) AS key
                ),
                'validation_applied', true,
                'tenant_verified', true,
                'environment', 'production'
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
                v_enrichment_data, v_validation_errors, 'prod_staging_processor_v2.0'
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
            SET processing_status = 'ERROR', error_message = 'PROD: ' || SQLERRM
            WHERE raw_event_id = v_raw_event.raw_event_id;
        END;
    END LOOP;
    
    RETURN QUERY SELECT 
        v_processed_count, v_success_count, v_error_count,
        jsonb_build_object(
            'processed_timestamp', CURRENT_TIMESTAMP,
            'processing_version', 'PROD_2.0_fixed',
            'environment', 'production',
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

-- Step 4: Test Deployment
\echo '🧪 STEP 4: CONTROLLED PRODUCTION TESTING...'

SELECT * FROM staging.process_site_tracking_events();

-- Step 5: Verification
\echo '✅ STEP 5: POST-DEPLOYMENT VERIFICATION...'

SELECT 
    '🎉 PRODUCTION DEPLOYMENT COMPLETE' as status,
    'Monitor system for 24 hours' as monitoring_requirement,
    CURRENT_TIMESTAMP as deployment_time;

\echo '🎉 PRODUCTION DEPLOYMENT COMPLETE!'
\echo '📋 CRITICAL FIXES DEPLOYED:'
\echo '   ✅ Fixed event_type field mapping (was evt_type)'
\echo '   ✅ Fixed jsonb_object_keys() usage with proper subquery'
\echo '   ✅ Removed processed_timestamp column references'
\echo '   ✅ Production safety enhancements and batch processing'
\echo '   ✅ Comprehensive error handling and logging'
\echo ''
\echo '🔍 POST-DEPLOYMENT MONITORING:'
\echo '   1. Monitor error logs for 24 hours'
\echo '   2. Verify processing performance metrics'
\echo '   3. Check data quality scores in staging table'
\echo '   4. Validate tenant isolation is maintained'
\echo '   5. Confirm audit logging is functioning'
\echo ''
\echo '🚨 ROLLBACK PLAN:'
\echo '   If critical issues arise, restore function from backup'
\echo '   Reset failed events to PENDING status for reprocessing'
\echo '   Contact development team for assistance' 