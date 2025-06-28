-- ============================================================================
-- CRITICAL FIXES AND RETEST SCRIPT - CORRECTED
-- Site Tracking System - Emergency Fixes with Audit Table Fix
-- ============================================================================
-- Purpose: Fix critical tenant assignment bug, staging processing, and audit references
-- Issues: 1) Wrong tenant assignment, 2) Events stuck in PENDING status, 3) Wrong audit table name
-- ============================================================================

-- Step 1: Deploy Critical Tenant Assignment Fix
\echo '🚨 STEP 1: DEPLOYING CRITICAL TENANT ASSIGNMENT FIX...'
\i database/scripts/site-tracking-scripts/06_create_api_layer_FIXED.sql

-- Step 2: Deploy Staging Function Fix
\echo '🛠️ STEP 2: DEPLOYING STAGING FUNCTION FIX...'
\i database/testing/site_tracking_tests/FIX_STAGING_FUNCTION.sql

-- Step 3: Verify All Fixes Applied
\echo '✅ STEP 3: VERIFYING ALL FIXES APPLIED...'

-- Check tenant assignments (should be correct after previous fix)
SELECT 
    '✅ TENANT VERIFICATION' as verification_step,
    r.raw_event_id,
    encode(r.tenant_hk, 'hex') as tenant_hk_hex,
    th.tenant_bk as tenant_name,
    r.processing_status,
    CASE 
        WHEN th.tenant_bk LIKE '%ONE Spa%' THEN '✅ Correct Tenant'
        ELSE '❌ Wrong Tenant: ' || th.tenant_bk
    END as tenant_status
FROM raw.site_tracking_events_r r
JOIN auth.tenant_h th ON r.tenant_hk = th.tenant_hk
WHERE r.raw_event_id IN (4, 5)
ORDER BY r.raw_event_id;

-- Check staging processing results
SELECT 
    '🔄 STAGING PROCESSING RESULTS' as processing_results,
    r.raw_event_id,
    r.processing_status as raw_status,
    s.staging_event_id,
    s.event_type,
    s.validation_status as staging_status,
    s.quality_score,
    CASE 
        WHEN s.staging_event_id IS NOT NULL AND r.processing_status = 'PROCESSED' THEN '✅ Pipeline Success'
        WHEN s.staging_event_id IS NOT NULL THEN '⚠️ Staging Only'
        WHEN r.processing_status = 'PROCESSED' THEN '⚠️ Raw Only'
        ELSE '❌ Processing Failed'
    END as pipeline_status
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
WHERE r.raw_event_id IN (4, 5)
ORDER BY r.raw_event_id;

-- Step 4: Audit Trail Verification (CORRECTED TABLE NAME)
\echo '🔒 STEP 4: AUDIT TRAIL VERIFICATION...'

SELECT 
    '🔒 AUDIT TRAIL FOR CORRECTIONS' as audit_verification,
    ae.event_timestamp,
    ae.event_category,
    ae.event_type,
    ae.event_data->>'raw_event_id' as affected_event,
    ae.event_data->>'correction_reason' as reason,
    ae.event_data->>'processing_version' as version,
    encode(ae.tenant_hk, 'hex') as tenant_hk
FROM audit.audit_event_h ae  -- CORRECTED: Use audit_event_h (not audit_event_s)
WHERE ae.event_type IN ('TENANT_CORRECTION', 'STAGING_PROCESSING_SUCCESS', 'STAGING_PROCESSING_ERROR')
AND ae.event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '2 hours'
ORDER BY ae.event_timestamp DESC
LIMIT 10;

-- Step 5: System Health Summary
\echo '🏥 STEP 5: SYSTEM HEALTH SUMMARY...'

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
        COUNT(*) FILTER (WHERE validation_status = 'SUSPICIOUS') as suspicious_events,
        COUNT(*) FILTER (WHERE validation_status = 'INVALID') as invalid_events,
        ROUND(AVG(quality_score), 2) as avg_quality_score
    FROM staging.site_tracking_events_s
    WHERE processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
)
SELECT 
    '🏥 COMPREHENSIVE SYSTEM HEALTH' as health_summary,
    h.total_raw_events,
    h.processed_events,
    h.pending_events,
    h.error_events,
    s.staging_events,
    s.valid_events,
    s.suspicious_events,
    s.invalid_events,
    s.avg_quality_score,
    CASE 
        WHEN h.pending_events = 0 AND h.error_events = 0 AND s.staging_events > 0 THEN '✅ All Systems Operational'
        WHEN h.pending_events = 0 AND h.error_events = 0 THEN '⚠️ Raw Processing OK, No Staging Data'
        WHEN h.pending_events > 0 THEN '⚠️ Events Still Pending'
        WHEN h.error_events > 0 THEN '❌ Processing Errors Detected'
        ELSE '❓ Unknown Status'
    END as overall_health
FROM health_metrics h
CROSS JOIN staging_metrics s;

-- Step 6: Data Quality Assessment
\echo '📊 STEP 6: DATA QUALITY ASSESSMENT...'

SELECT 
    '📊 EVENT DATA QUALITY' as quality_assessment,
    s.raw_event_id,
    s.event_type,
    s.validation_status,
    s.quality_score,
    array_length(s.validation_errors, 1) as error_count,
    s.validation_errors,
    jsonb_pretty(s.enrichment_data) as enrichment_info
FROM staging.site_tracking_events_s s
WHERE s.raw_event_id IN (4, 5)
ORDER BY s.raw_event_id;

-- Final Status Check
\echo '📋 FINAL STATUS CHECK:'

-- Check if both tenant and staging fixes worked
WITH fix_status AS (
    SELECT 
        r.raw_event_id,
        th.tenant_bk LIKE '%ONE Spa%' as tenant_correct,
        r.processing_status = 'PROCESSED' as raw_processed,
        s.staging_event_id IS NOT NULL as staging_exists,
        s.validation_status = 'VALID' as staging_valid
    FROM raw.site_tracking_events_r r
    JOIN auth.tenant_h th ON r.tenant_hk = th.tenant_hk
    LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
    WHERE r.raw_event_id IN (4, 5)
)
SELECT 
    '🎯 FINAL FIX STATUS' as final_status,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE tenant_correct) as tenant_fixes_successful,
    COUNT(*) FILTER (WHERE raw_processed) as raw_processing_successful,
    COUNT(*) FILTER (WHERE staging_exists) as staging_processing_successful,
    COUNT(*) FILTER (WHERE staging_valid) as staging_validation_successful,
    CASE 
        WHEN COUNT(*) FILTER (WHERE tenant_correct AND raw_processed AND staging_exists) = COUNT(*) 
        THEN '✅ ALL FIXES SUCCESSFUL'
        WHEN COUNT(*) FILTER (WHERE tenant_correct) = COUNT(*) 
        THEN '⚠️ TENANT FIXED, STAGING ISSUES REMAIN'
        ELSE '❌ CRITICAL ISSUES REMAIN'
    END as overall_fix_status
FROM fix_status;

-- Recommendations
SELECT 
    '🎯 NEXT STEPS' as recommendations,
    CASE 
        WHEN (SELECT COUNT(*) FROM staging.site_tracking_events_s WHERE raw_event_id IN (4, 5)) = 2
        THEN 'Proceed to Phase 2 staging verification tests'
        ELSE 'Debug remaining staging processing issues'
    END as step_1,
    'Monitor audit logs for any ongoing issues' as step_2,
    'Run complete system test if all fixes successful' as step_3; 