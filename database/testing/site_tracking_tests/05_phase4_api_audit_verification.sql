-- ============================================================================
-- PHASE 4: API LAYER & AUDIT VERIFICATION
-- Site Tracking System Testing - CORRECTED FOR ACTUAL TABLE STRUCTURE
-- ============================================================================
-- Purpose: Verify API security, rate limiting, and comprehensive audit logging
-- Tests: API endpoint security, audit trail completeness, compliance tracking
-- ============================================================================

-- 4.1 API Security Tracking Verification
SELECT 
    '🔐 PHASE 4: API SECURITY VERIFICATION' as test_phase,
    COUNT(*) as ip_tracking_records,
    COUNT(DISTINCT ip_address) as unique_ips,
    MAX(last_request_time) as latest_request,
    AVG(request_count) as avg_requests_per_ip
FROM auth.ip_tracking_s
WHERE last_request_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND load_end_date IS NULL;

-- 4.2 Rate Limiting Analysis
SELECT 
    '⚡ RATE LIMITING ANALYSIS' as analysis_type,
    ip_address,
    request_count,
    is_blocked,
    block_reason,
    suspicious_activity_flag,
    last_request_time,
    CASE 
        WHEN is_blocked = true THEN '🚫 Blocked IP'
        WHEN request_count > 100 THEN '⚠️ High Activity'
        WHEN suspicious_activity_flag = true THEN '🚨 Suspicious Activity'
        ELSE '✅ Normal Activity'
    END as activity_status
FROM auth.ip_tracking_s
WHERE last_request_time >= CURRENT_TIMESTAMP - INTERVAL '2 hours'
  AND load_end_date IS NULL
ORDER BY request_count DESC
LIMIT 10;

-- 4.3 Security Analysis
SELECT 
    '🛡️ SECURITY ANALYSIS' as security_analysis,
    CASE 
        WHEN is_blocked = true THEN 'BLOCKED'
        WHEN suspicious_activity_flag = true THEN 'SUSPICIOUS'
        WHEN request_count > 1000 THEN 'HIGH_VOLUME'
        WHEN request_count > 100 THEN 'MEDIUM_VOLUME'
        ELSE 'NORMAL'
    END as threat_category,
    COUNT(*) as ip_count,
    AVG(request_count) as avg_requests,
    COUNT(*) FILTER (WHERE is_blocked = true) as blocked_count,
    COUNT(*) FILTER (WHERE suspicious_activity_flag = true) as suspicious_count
FROM auth.ip_tracking_s
WHERE last_request_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND load_end_date IS NULL
GROUP BY 1
ORDER BY avg_requests DESC;

-- 4.4 Geographic Distribution (if available)
SELECT 
    '🌍 GEOGRAPHIC DISTRIBUTION' as geo_analysis,
    COALESCE(geographic_location, 'Unknown') as location,
    COUNT(*) as ip_count,
    SUM(request_count) as total_requests,
    AVG(request_count) as avg_requests_per_ip,
    COUNT(*) FILTER (WHERE is_blocked = true) as blocked_ips
FROM auth.ip_tracking_s
WHERE last_request_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND load_end_date IS NULL
GROUP BY geographic_location
ORDER BY total_requests DESC;

-- 4.5 Suspicious Activity Analysis
SELECT 
    '🚨 SUSPICIOUS ACTIVITY ANALYSIS' as suspicious_analysis,
    ip_address,
    request_count,
    suspicious_activity_flag,
    jsonb_pretty(suspicious_activity_details) as activity_details,
    block_reason,
    first_request_time,
    last_request_time,
    EXTRACT(EPOCH FROM (last_request_time - first_request_time)) / 60 as activity_duration_minutes
FROM auth.ip_tracking_s
WHERE (suspicious_activity_flag = true OR is_blocked = true)
  AND last_request_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND load_end_date IS NULL
ORDER BY request_count DESC;

-- 4.6 Site Tracking Event Audit (using util.log_audit_event results)
SELECT 
    '🎯 SITE TRACKING AUDIT EVENTS' as tracking_audit,
    'Checking for site tracking audit events...' as status,
    COUNT(*) as potential_audit_events
FROM raw.site_tracking_events_r
WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- 4.7 Raw Event Processing Audit
SELECT 
    '📊 RAW EVENT PROCESSING AUDIT' as processing_audit,
    processing_status,
    COUNT(*) as event_count,
    COUNT(DISTINCT tenant_hk) as unique_tenants,
    MIN(received_timestamp) as first_event,
    MAX(received_timestamp) as last_event,
    array_agg(DISTINCT COALESCE(error_message, 'No error')) as error_messages
FROM raw.site_tracking_events_r
WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY processing_status
ORDER BY event_count DESC;

-- 4.8 Staging Event Processing Audit
SELECT 
    '📋 STAGING EVENT PROCESSING AUDIT' as staging_audit,
    validation_status,
    enrichment_status,
    COUNT(*) as event_count,
    AVG(quality_score) as avg_quality_score,
    COUNT(DISTINCT tenant_hk) as unique_tenants,
    array_agg(DISTINCT record_source) as processing_sources
FROM staging.site_tracking_events_s
WHERE processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY validation_status, enrichment_status
ORDER BY event_count DESC;

-- 4.9 Business Layer Processing Audit
SELECT 
    '🏢 BUSINESS LAYER PROCESSING AUDIT' as business_audit,
    'Hub Creation Summary' as audit_type,
    'Event Hubs' as entity_type,
    COUNT(*) as records_created,
    COUNT(DISTINCT tenant_hk) as unique_tenants,
    array_agg(DISTINCT record_source) as creation_sources,
    MIN(load_date) as first_created,
    MAX(load_date) as last_created
FROM business.site_event_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'

UNION ALL

SELECT 
    '🏢 BUSINESS LAYER PROCESSING AUDIT',
    'Hub Creation Summary',
    'Session Hubs',
    COUNT(*),
    COUNT(DISTINCT tenant_hk),
    array_agg(DISTINCT record_source),
    MIN(load_date),
    MAX(load_date)
FROM business.site_session_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'

UNION ALL

SELECT 
    '🏢 BUSINESS LAYER PROCESSING AUDIT',
    'Hub Creation Summary',
    'Visitor Hubs',
    COUNT(*),
    COUNT(DISTINCT tenant_hk),
    array_agg(DISTINCT record_source),
    MIN(load_date),
    MAX(load_date)
FROM business.site_visitor_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- 4.10 Data Quality Audit
SELECT 
    '📊 DATA QUALITY AUDIT' as quality_audit,
    'Staging Quality Metrics' as metric_type,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE validation_status = 'VALID') as valid_events,
    COUNT(*) FILTER (WHERE validation_status = 'INVALID') as invalid_events,
    COUNT(*) FILTER (WHERE validation_status = 'SUSPICIOUS') as suspicious_events,
    ROUND(AVG(quality_score), 3) as avg_quality_score,
    ROUND(
        COUNT(*) FILTER (WHERE validation_status = 'VALID')::numeric / 
        NULLIF(COUNT(*), 0) * 100, 2
    ) as validation_success_rate
FROM staging.site_tracking_events_s
WHERE processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- 4.11 Tenant Isolation Audit
SELECT 
    '🔒 TENANT ISOLATION AUDIT' as isolation_audit,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    COUNT(DISTINCT r.raw_event_id) as raw_events,
    COUNT(DISTINCT s.staging_event_id) as staging_events,
    COUNT(DISTINCT eh.site_event_hk) as business_events,
    CASE 
        WHEN COUNT(DISTINCT r.raw_event_id) = COUNT(DISTINCT s.staging_event_id) 
         AND COUNT(DISTINCT s.staging_event_id) = COUNT(DISTINCT eh.site_event_hk)
        THEN '✅ Perfect Isolation'
        WHEN COUNT(DISTINCT r.raw_event_id) = COUNT(DISTINCT s.staging_event_id)
        THEN '⚠️ Business Layer Gap'
        ELSE '❌ Processing Issues'
    END as isolation_status
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
LEFT JOIN business.site_event_h eh ON s.staging_event_id::text = eh.site_event_bk
WHERE r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY tenant_hk
ORDER BY raw_events DESC;

-- 4.12 Processing Performance Audit
SELECT 
    '⚡ PROCESSING PERFORMANCE AUDIT' as performance_audit,
    'Pipeline Performance Metrics' as metric_type,
    COUNT(DISTINCT r.raw_event_id) as total_events,
    ROUND(AVG(EXTRACT(EPOCH FROM (s.processed_timestamp - r.received_timestamp))), 2) as avg_raw_to_staging_seconds,
    ROUND(AVG(EXTRACT(EPOCH FROM (eh.load_date - s.processed_timestamp))), 2) as avg_staging_to_business_seconds,
    ROUND(
        COUNT(DISTINCT s.staging_event_id)::numeric / 
        NULLIF(COUNT(DISTINCT r.raw_event_id), 0) * 100, 2
    ) as raw_to_staging_success_rate,
    ROUND(
        COUNT(DISTINCT eh.site_event_hk)::numeric / 
        NULLIF(COUNT(DISTINCT s.staging_event_id), 0) * 100, 2
    ) as staging_to_business_success_rate
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
LEFT JOIN business.site_event_h eh ON s.staging_event_id::text = eh.site_event_bk
WHERE r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- ============================================================================
-- API & AUDIT VERIFICATION SUMMARY
-- ============================================================================
SELECT 
    '🎯 PHASE 4 API & AUDIT COMPLETE' as summary,
    'Verification checklist:' as checklist,
    '1. IP tracking and rate limiting verification' as check1,
    '2. Site tracking event audit logging' as check2,
    '3. Data processing audit trail' as check3,
    '4. Tenant isolation audit verification' as check4,
    '5. Data quality and performance auditing' as check5,
    '6. Business layer processing audit' as check6; 