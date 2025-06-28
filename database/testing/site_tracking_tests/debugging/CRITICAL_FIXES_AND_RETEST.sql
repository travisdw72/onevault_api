-- ============================================================================
-- CRITICAL FIXES AND RETEST SCRIPT
-- Site Tracking System - Emergency Fixes
-- ============================================================================
-- Purpose: Fix critical tenant assignment bug and process stuck events
-- Issues: 1) Wrong tenant assignment, 2) Events stuck in PENDING status
-- ============================================================================

-- Step 1: Deploy Critical Tenant Assignment Fix
\echo '🚨 STEP 1: DEPLOYING CRITICAL TENANT ASSIGNMENT FIX...'
\i database/scripts/site-tracking-scripts/06_create_api_layer_FIXED.sql

-- Step 2: Identify Current Issues
\echo '🔍 STEP 2: ANALYZING CURRENT ISSUES...'

SELECT 
    '🚨 CURRENT TENANT ASSIGNMENT ISSUE' as issue_analysis,
    r.raw_event_id,
    encode(r.tenant_hk, 'hex') as current_tenant_hk,
    th.tenant_bk as current_tenant_name,
    r.processing_status,
    r.received_timestamp
FROM raw.site_tracking_events_r r
JOIN auth.tenant_h th ON r.tenant_hk = th.tenant_hk
WHERE r.raw_event_id IN (4, 5)
ORDER BY r.raw_event_id;

-- Get the correct ONE Spa tenant information
SELECT 
    '🎯 CORRECT TENANT INFORMATION' as correct_tenant,
    tenant_bk,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    load_date
FROM auth.tenant_h
WHERE tenant_bk LIKE '%ONE Spa%'
OR tenant_bk LIKE '%one_spa%'
ORDER BY load_date DESC;

-- Step 3: Fix Tenant Assignments
\echo '🛠️ STEP 3: CORRECTING TENANT ASSIGNMENTS...'

-- Correct event 4
SELECT api.correct_event_tenant(4, 'The ONE Spa_2025-06-21 11:11:44.562053-07') as event_4_correction;

-- Correct event 5  
SELECT api.correct_event_tenant(5, 'The ONE Spa_2025-06-21 11:11:44.562053-07') as event_5_correction;

-- Step 4: Verify Tenant Corrections
\echo '✅ STEP 4: VERIFYING TENANT CORRECTIONS...'

SELECT 
    '✅ TENANT CORRECTION VERIFICATION' as verification_step,
    r.raw_event_id,
    encode(r.tenant_hk, 'hex') as corrected_tenant_hk,
    th.tenant_bk as corrected_tenant_name,
    r.processing_status,
    'Should be: The ONE Spa' as expected_tenant
FROM raw.site_tracking_events_r r
JOIN auth.tenant_h th ON r.tenant_hk = th.tenant_hk
WHERE r.raw_event_id IN (4, 5)
ORDER BY r.raw_event_id;

-- Step 5: Process Stuck Events from PENDING to Staging
\echo '🔄 STEP 5: PROCESSING STUCK EVENTS...'

-- Get the correct tenant hash key for ONE Spa
DO $$
DECLARE
    v_one_spa_tenant_hk BYTEA;
    v_batch_result RECORD;
BEGIN
    -- Get ONE Spa tenant hash key
    SELECT tenant_hk INTO v_one_spa_tenant_hk
    FROM auth.tenant_h
    WHERE tenant_bk LIKE '%ONE Spa%'
    ORDER BY load_date DESC
    LIMIT 1;
    
    -- Process pending events for ONE Spa
    SELECT * INTO v_batch_result
    FROM staging.process_raw_events_batch(v_one_spa_tenant_hk, 10);
    
    RAISE NOTICE 'Batch processing results: Processed: %, Errors: %, Batch ID: %', 
                 v_batch_result.processed_count, 
                 v_batch_result.error_count, 
                 v_batch_result.batch_id;
END $$;

-- Step 6: Verify Processing Results
\echo '📊 STEP 6: VERIFYING PROCESSING RESULTS...'

-- Check raw layer status after processing
SELECT 
    '📊 RAW LAYER STATUS AFTER PROCESSING' as status_check,
    processing_status,
    COUNT(*) as event_count,
    MIN(received_timestamp) as earliest,
    MAX(received_timestamp) as latest
FROM raw.site_tracking_events_r
WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY processing_status
ORDER BY processing_status;

-- Check if events made it to staging
SELECT 
    '🔄 STAGING LAYER STATUS' as staging_status,
    s.raw_event_id,
    s.staging_event_id,
    s.event_type,
    s.validation_status,
    s.quality_score,
    s.processed_timestamp
FROM staging.site_tracking_events_s s
WHERE s.raw_event_id IN (4, 5)
ORDER BY s.raw_event_id;

-- Step 7: Re-run Phase 1 Verification Tests
\echo '🔍 STEP 7: RE-RUNNING PHASE 1 VERIFICATION...'

-- Re-run the critical verification queries

-- 7.1 Complete Raw Event Details (Re-test)
SELECT 
    '🔍 RETEST - RAW LAYER VERIFICATION' as test_phase,
    r.raw_event_id,
    encode(r.tenant_hk, 'hex') as tenant_hk_hex,
    th.tenant_bk as tenant_name,
    r.received_timestamp,
    r.processing_status,
    r.batch_id,
    r.error_message,
    -- JSON Payload Analysis
    r.raw_payload->>'event_type' as event_type,
    r.raw_payload->>'page_url' as page_url,
    CASE 
        WHEN th.tenant_bk LIKE '%ONE Spa%' THEN '✅ Correct Tenant'
        ELSE '❌ Wrong Tenant: ' || th.tenant_bk
    END as tenant_verification
FROM raw.site_tracking_events_r r
JOIN auth.tenant_h th ON r.tenant_hk = th.tenant_hk
WHERE r.raw_event_id IN (4, 5)
ORDER BY r.raw_event_id;

-- 7.2 Processing Pipeline Status
SELECT 
    '🔄 PROCESSING PIPELINE STATUS' as pipeline_status,
    r.raw_event_id,
    r.processing_status as raw_status,
    s.staging_event_id,
    s.validation_status as staging_status,
    s.quality_score,
    CASE 
        WHEN s.staging_event_id IS NOT NULL THEN '✅ Reached Staging'
        WHEN r.processing_status = 'PROCESSED' THEN '⚠️ Processed but Missing Staging'
        WHEN r.processing_status = 'PENDING' THEN '❌ Still Pending'
        WHEN r.processing_status = 'ERROR' THEN '❌ Error: ' || r.error_message
        ELSE '❓ Unknown Status'
    END as pipeline_verification
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
WHERE r.raw_event_id IN (4, 5)
ORDER BY r.raw_event_id;

-- Step 8: Audit Trail Verification
\echo '🔒 STEP 8: AUDIT TRAIL VERIFICATION...'

SELECT 
    '🔒 AUDIT TRAIL FOR CORRECTIONS' as audit_verification,
    ae.event_type,
    ae.event_category,
    ae.event_timestamp,
    ae.event_data->>'raw_event_id' as affected_event,
    ae.event_data->>'correction_reason' as reason,
    encode(ae.tenant_hk, 'hex') as tenant_hk
FROM audit.audit_event_s ae
WHERE ae.event_type = 'TENANT_CORRECTION'
AND ae.event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
AND ae.load_end_date IS NULL
ORDER BY ae.event_timestamp DESC;

-- Step 9: System Health Summary
\echo '🏥 STEP 9: SYSTEM HEALTH SUMMARY...'

WITH health_metrics AS (
    SELECT 
        COUNT(*) as total_raw_events,
        COUNT(*) FILTER (WHERE processing_status = 'PROCESSED') as processed_events,
        COUNT(*) FILTER (WHERE processing_status = 'PENDING') as pending_events,
        COUNT(*) FILTER (WHERE processing_status = 'ERROR') as error_events
    FROM raw.site_tracking_events_r
    WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
),
staging_metrics AS (
    SELECT 
        COUNT(*) as staging_events,
        COUNT(*) FILTER (WHERE validation_status = 'VALID') as valid_events,
        AVG(quality_score) as avg_quality_score
    FROM staging.site_tracking_events_s
    WHERE processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
)
SELECT 
    '🏥 SYSTEM HEALTH AFTER FIXES' as health_summary,
    h.total_raw_events,
    h.processed_events,
    h.pending_events,
    h.error_events,
    s.staging_events,
    s.valid_events,
    ROUND(s.avg_quality_score, 2) as avg_quality_score,
    CASE 
        WHEN h.pending_events = 0 AND h.error_events = 0 THEN '✅ All Events Processed'
        WHEN h.pending_events > 0 THEN '⚠️ Events Still Pending'
        WHEN h.error_events > 0 THEN '❌ Events Have Errors'
        ELSE '❓ Unknown Status'
    END as overall_health
FROM health_metrics h
CROSS JOIN staging_metrics s;

-- Final Recommendations
\echo '📋 FINAL RECOMMENDATIONS:'
\echo '1. ✅ Tenant assignment fix deployed'
\echo '2. ✅ Existing data corrected'  
\echo '3. ✅ Events processed to staging'
\echo '4. 🔄 Continue with Phase 2 testing if all health checks pass'
\echo '5. 🚨 If issues remain, investigate specific errors before proceeding'

SELECT 
    '🎯 NEXT STEPS' as recommendations,
    'If all events show ✅ status above, proceed to Phase 2 staging tests' as step_1,
    'If any ❌ or ⚠️ status remains, debug specific issues first' as step_2,
    'Use staging.validate_and_enrich_event(raw_event_id) to manually process individual events' as manual_processing_tip; 