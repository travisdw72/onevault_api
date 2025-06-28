-- ============================================================================
-- COMPLETE SYSTEM TEST - ALL PHASES
-- Site Tracking System Testing
-- ============================================================================
-- Purpose: Sequential execution of all testing phases for comprehensive validation
-- Usage: Run this file to execute all phases or run individual phase files
-- Event ID: 8cd163b059e08cf57d494eeb3f7715391c6da48b2a50f10ebda3e4f34528cb7c
-- Raw Event ID: 4
-- ============================================================================

-- ============================================================================
-- SYSTEM TEST INITIALIZATION
-- ============================================================================
SELECT 
    '🚀 COMPLETE SYSTEM TEST INITIALIZATION' as test_start,
    'Site Tracking System Comprehensive Testing' as test_name,
    CURRENT_TIMESTAMP as test_start_time,
    'Event ID: 8cd163b059e08cf57d494eeb3f7715391c6da48b2a50f10ebda3e4f34528cb7c' as target_event,
    'Raw Event ID: 4' as target_raw_event;

-- ============================================================================
-- PHASE 1: RAW LAYER VERIFICATION
-- ============================================================================
SELECT '🔍 EXECUTING PHASE 1: RAW LAYER VERIFICATION' as current_phase;

-- Quick Raw Layer Status
SELECT 
    '📊 PHASE 1 SUMMARY' as phase_summary,
    COUNT(*) as total_raw_events,
    COUNT(*) FILTER (WHERE processing_status = 'PROCESSED') as processed,
    COUNT(*) FILTER (WHERE processing_status = 'PENDING') as pending,
    COUNT(*) FILTER (WHERE processing_status = 'ERROR') as errors,
    COUNT(*) FILTER (WHERE raw_event_id = 4) as target_event_found
FROM raw.site_tracking_events_r
WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- ============================================================================
-- PHASE 2: STAGING LAYER VERIFICATION
-- ============================================================================
SELECT '🔄 EXECUTING PHASE 2: STAGING LAYER VERIFICATION' as current_phase;

-- Quick Staging Layer Status
SELECT 
    '📊 PHASE 2 SUMMARY' as phase_summary,
    COUNT(*) as total_staging_events,
    COUNT(*) FILTER (WHERE validation_status = 'VALID') as valid_events,
    COUNT(*) FILTER (WHERE validation_status = 'INVALID') as invalid_events,
    COUNT(*) FILTER (WHERE raw_event_id = 4) as target_event_processed,
    AVG(quality_score) as avg_quality_score
FROM staging.site_tracking_events_s
WHERE processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- ============================================================================
-- PHASE 3: BUSINESS LAYER VERIFICATION
-- ============================================================================
SELECT '🏢 EXECUTING PHASE 3: BUSINESS LAYER VERIFICATION' as current_phase;

-- Quick Business Layer Status
SELECT 
    '📊 PHASE 3 SUMMARY' as phase_summary,
    'hub_counts' as metric_type,
    COUNT(DISTINCT eh.event_hk) as event_hubs,
    COUNT(DISTINCT sh.session_hk) as session_hubs,
    COUNT(DISTINCT vh.visitor_hk) as visitor_hubs,
    COUNT(DISTINCT ph.page_hk) as page_hubs
FROM business.site_event_h eh
FULL OUTER JOIN business.site_session_h sh ON eh.tenant_hk = sh.tenant_hk
FULL OUTER JOIN business.site_visitor_h vh ON eh.tenant_hk = vh.tenant_hk
FULL OUTER JOIN business.site_page_h ph ON eh.tenant_hk = ph.tenant_hk
WHERE COALESCE(eh.load_date, sh.load_date, vh.load_date, ph.load_date) >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- ============================================================================
-- PHASE 4: API & AUDIT VERIFICATION
-- ============================================================================
SELECT '🔐 EXECUTING PHASE 4: API & AUDIT VERIFICATION' as current_phase;

-- Quick API & Audit Status
SELECT 
    '📊 PHASE 4 SUMMARY' as phase_summary,
    COUNT(*) as total_audit_events,
    COUNT(DISTINCT event_category) as event_categories,
    COUNT(DISTINCT client_ip) as unique_ips,
    MAX(event_timestamp) as latest_audit_event
FROM audit.audit_event_s
WHERE event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND load_end_date IS NULL;

-- ============================================================================
-- PHASE 5: END-TO-END FLOW VERIFICATION
-- ============================================================================
SELECT '🔄 EXECUTING PHASE 5: END-TO-END FLOW VERIFICATION' as current_phase;

-- Complete Pipeline Status for Target Event
SELECT 
    '📊 PHASE 5 SUMMARY - TARGET EVENT TRACE' as phase_summary,
    r.raw_event_id,
    r.processing_status as raw_status,
    s.staging_event_id,
    s.validation_status as staging_status,
    encode(eh.event_hk, 'hex') as event_hub_created,
    encode(eds.event_hk, 'hex') as event_satellite_created,
    CASE 
        WHEN eds.event_hk IS NOT NULL THEN '✅ Complete Pipeline'
        WHEN eh.event_hk IS NOT NULL THEN '🔄 Hub Only'
        WHEN s.staging_event_id IS NOT NULL THEN '📝 Staging Only'
        ELSE '🔴 Raw Only'
    END as pipeline_status
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
LEFT JOIN business.site_event_h eh ON s.staging_event_id::text = eh.event_bk
LEFT JOIN business.site_event_details_s eds ON eh.event_hk = eds.event_hk 
                                            AND eds.load_end_date IS NULL
WHERE r.raw_event_id = 4;

-- ============================================================================
-- PHASE 6: PERFORMANCE & MONITORING
-- ============================================================================
SELECT '📊 EXECUTING PHASE 6: PERFORMANCE & MONITORING' as current_phase;

-- Quick Performance Summary
SELECT 
    '📊 PHASE 6 SUMMARY' as phase_summary,
    'performance_metrics' as metric_type,
    COUNT(DISTINCT r.raw_event_id) as total_events_24h,
    ROUND(
        COUNT(DISTINCT s.staging_event_id)::numeric / 
        NULLIF(COUNT(DISTINCT r.raw_event_id), 0) * 100, 2
    ) as staging_processing_rate,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (s.processed_timestamp - r.received_timestamp))), 2
    ) as avg_processing_time_seconds
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
WHERE r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- ============================================================================
-- COMPREHENSIVE SYSTEM HEALTH CHECK
-- ============================================================================
SELECT '🎯 COMPREHENSIVE SYSTEM HEALTH CHECK' as health_check_phase;

-- Overall System Status
WITH system_metrics AS (
    SELECT 
        COUNT(DISTINCT r.raw_event_id) as raw_events,
        COUNT(DISTINCT s.staging_event_id) as staging_events,
        COUNT(DISTINCT eh.event_hk) as business_events,
        COUNT(DISTINCT ae.audit_event_hk) as audit_events
    FROM raw.site_tracking_events_r r
    LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
    LEFT JOIN business.site_event_h eh ON s.staging_event_id::text = eh.event_bk
    LEFT JOIN audit.audit_event_h ae ON ae.load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    WHERE r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
)
SELECT 
    '🏥 SYSTEM HEALTH SUMMARY' as health_summary,
    raw_events,
    staging_events,
    business_events,
    audit_events,
    ROUND(staging_events::numeric / NULLIF(raw_events, 0) * 100, 2) as raw_to_staging_rate,
    ROUND(business_events::numeric / NULLIF(staging_events, 0) * 100, 2) as staging_to_business_rate,
    CASE 
        WHEN raw_events > 0 AND staging_events > 0 AND business_events > 0 THEN '✅ All Layers Active'
        WHEN raw_events > 0 AND staging_events > 0 THEN '⚠️ Business Layer Issue'
        WHEN raw_events > 0 THEN '⚠️ Staging Layer Issue'
        ELSE '❌ No Recent Activity'
    END as overall_health
FROM system_metrics;

-- ============================================================================
-- TENANT ISOLATION VERIFICATION
-- ============================================================================
SELECT '🔒 TENANT ISOLATION VERIFICATION' as isolation_check;

SELECT 
    '🏢 TENANT DISTRIBUTION SUMMARY' as tenant_summary,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    COUNT(*) as event_count,
    MIN(received_timestamp) as first_event,
    MAX(received_timestamp) as last_event
FROM raw.site_tracking_events_r
WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY tenant_hk
ORDER BY event_count DESC;

-- ============================================================================
-- DATA QUALITY ASSESSMENT
-- ============================================================================
SELECT '📊 DATA QUALITY ASSESSMENT' as quality_check;

SELECT 
    '📋 DATA QUALITY SUMMARY' as quality_summary,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE raw_payload ? 'event_type') as events_with_type,
    COUNT(*) FILTER (WHERE raw_payload ? 'session_id') as events_with_session,
    COUNT(*) FILTER (WHERE raw_payload ? 'page_url') as events_with_page,
    ROUND(
        COUNT(*) FILTER (WHERE raw_payload ? 'event_type')::numeric / 
        NULLIF(COUNT(*), 0) * 100, 2
    ) as event_type_completeness,
    ROUND(
        COUNT(*) FILTER (WHERE raw_payload ? 'session_id')::numeric / 
        NULLIF(COUNT(*), 0) * 100, 2
    ) as session_id_completeness
FROM raw.site_tracking_events_r
WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- ============================================================================
-- ERROR ANALYSIS
-- ============================================================================
SELECT '❌ ERROR ANALYSIS' as error_check;

SELECT 
    '🚨 ERROR SUMMARY' as error_summary,
    processing_status,
    COUNT(*) as error_count,
    array_agg(DISTINCT COALESCE(error_message, 'No message')) as error_messages
FROM raw.site_tracking_events_r
WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND (processing_status != 'PROCESSED' OR error_message IS NOT NULL)
GROUP BY processing_status
ORDER BY error_count DESC;

-- ============================================================================
-- PERFORMANCE BENCHMARKS
-- ============================================================================
SELECT '⚡ PERFORMANCE BENCHMARKS' as performance_check;

SELECT 
    '🏃 PERFORMANCE BENCHMARKS' as benchmark_summary,
    'Processing Time Percentiles' as metric_name,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (s.processed_timestamp - r.received_timestamp))
    ), 2) as p50_seconds,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (s.processed_timestamp - r.received_timestamp))
    ), 2) as p95_seconds,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (s.processed_timestamp - r.received_timestamp))
    ), 2) as p99_seconds
FROM raw.site_tracking_events_r r
JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
WHERE r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- ============================================================================
-- FINAL SYSTEM STATUS
-- ============================================================================
SELECT 
    '🎯 COMPLETE SYSTEM TEST RESULTS' as final_results,
    CURRENT_TIMESTAMP as test_completion_time,
    CASE 
        WHEN EXISTS(SELECT 1 FROM raw.site_tracking_events_r WHERE raw_event_id = 4)
         AND EXISTS(SELECT 1 FROM staging.site_tracking_events_s WHERE raw_event_id = 4)
        THEN '✅ Target Event Successfully Processed'
        WHEN EXISTS(SELECT 1 FROM raw.site_tracking_events_r WHERE raw_event_id = 4)
        THEN '⚠️ Target Event In Raw Layer Only'
        ELSE '❌ Target Event Not Found'
    END as target_event_status,
    CASE 
        WHEN (SELECT COUNT(*) FROM raw.site_tracking_events_r WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours') > 0
         AND (SELECT COUNT(*) FROM staging.site_tracking_events_s WHERE processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours') > 0
         AND (SELECT COUNT(*) FROM business.site_event_h WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours') > 0
        THEN '✅ All Pipeline Layers Active'
        ELSE '⚠️ Pipeline Issues Detected'
    END as pipeline_status,
    'Review individual phase files for detailed analysis' as next_steps;

-- ============================================================================
-- TEST COMPLETION SUMMARY
-- ============================================================================
SELECT 
    '🏁 TESTING COMPLETE' as test_status,
    'All 6 phases executed successfully' as phases_completed,
    'Individual phase files available for detailed analysis:' as available_files,
    '• 01_phase1_raw_layer_verification.sql' as file1,
    '• 02_phase2_staging_layer_debug.sql' as file2,
    '• 03_staging_manual_processing_fix.sql' as file3,
    '• 04_phase3_business_layer_verification.sql' as file4,
    '• 05_phase4_api_audit_verification.sql' as file5,
    '• 06_phase5_end_to_end_flow.sql' as file6,
    '• 07_phase6_performance_monitoring.sql' as file7,
    '• 08_debug_troubleshooting.sql' as file8; 