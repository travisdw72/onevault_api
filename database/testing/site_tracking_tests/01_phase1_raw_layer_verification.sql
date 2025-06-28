-- ============================================================================
-- PHASE 1: RAW LAYER VERIFICATION
-- Site Tracking System Testing
-- ============================================================================
-- Purpose: Verify raw event ingestion and tenant isolation
-- Event ID: 8cd163b059e08cf57d494eeb3f7715391c6da48b2a50f10ebda3e4f34528cb7c
-- Raw Event ID: 4
-- ============================================================================

-- 1.1 Complete Raw Event Details
SELECT 
    '🔍 PHASE 1: RAW LAYER VERIFICATION' as test_phase,
    r.raw_event_id,
    r.tenant_hk,
    encode(r.tenant_hk, 'hex') as tenant_hk_hex,
    r.received_timestamp,
    r.client_ip,
    r.user_agent,
    r.processing_status,
    r.batch_id,
    r.retry_count,
    r.error_message,
    r.record_source,
    -- JSON Payload Analysis
    r.raw_payload->>'event_type' as event_type,
    r.raw_payload->'event_data'->>'action' as action,
    r.raw_payload->'event_data'->>'service_type' as service_type,
    r.raw_payload->>'page_url' as page_url,
    r.raw_payload->>'session_id' as session_id,
    r.raw_payload->>'location_id' as location_id,
    -- Complete payload
    jsonb_pretty(r.raw_payload) as complete_payload
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4
   OR r.batch_id LIKE '%8cd163b059e08cf57d494eeb3f7715391c6da48b2a50f10ebda3e4f34528cb7c%';

    -- 1.2 Tenant Isolation Verification
    SELECT 
        '🔒 TENANT ISOLATION CHECK' as check_type,
        th.tenant_bk,
        th.tenant_hk,
        encode(th.tenant_hk, 'hex') as tenant_hk_hex,
        th.load_date as tenant_created,
        COUNT(r.raw_event_id) as events_for_this_tenant
    FROM auth.tenant_h th
    LEFT JOIN raw.site_tracking_events_r r ON th.tenant_hk = r.tenant_hk
    WHERE th.tenant_bk = 'one_spa'
    OR r.raw_event_id = 4
    GROUP BY th.tenant_hk, th.tenant_bk, th.load_date
    ORDER BY th.load_date DESC;

-- 1.3 Find Correct one_spa Tenant
SELECT 
    '🎯 FIND CORRECT one_spa TENANT' as search_type,
    tenant_bk,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    load_date,
    record_source
FROM auth.tenant_h
WHERE tenant_bk ILIKE '%one_spa%'
   OR tenant_bk ILIKE '%spa%'
ORDER BY load_date DESC;

-- 1.4 Processing Status & Batch Analysis
SELECT 
    '📊 PROCESSING STATUS' as analysis_type,
    processing_status,
    COUNT(*) as count,
    MIN(received_timestamp) as earliest_event,
    MAX(received_timestamp) as latest_event,
    EXTRACT(EPOCH FROM (MAX(received_timestamp) - MIN(received_timestamp))) as time_span_seconds
FROM raw.site_tracking_events_r
WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '2 hours'
GROUP BY processing_status
ORDER BY processing_status;

-- 1.5 Recent Events Summary
SELECT 
    '📋 RECENT EVENTS SUMMARY' as summary_type,
    raw_event_id,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    received_timestamp,
    processing_status,
    raw_payload->>'event_type' as event_type,
    raw_payload->>'page_url' as page_url,
    substring(batch_id, 1, 50) as batch_id_prefix
FROM raw.site_tracking_events_r
WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY received_timestamp DESC
LIMIT 10;

-- 1.6 JSON Payload Structure Analysis
SELECT 
    '🔍 PAYLOAD STRUCTURE ANALYSIS' as analysis_type,
    raw_event_id,
    jsonb_object_keys(raw_payload) as top_level_keys
FROM raw.site_tracking_events_r
WHERE raw_event_id = 4;

-- 1.7 Event Data Sub-structure Analysis
SELECT 
    '🔍 EVENT DATA STRUCTURE' as analysis_type,
    raw_event_id,
    jsonb_object_keys(raw_payload->'event_data') as event_data_keys
FROM raw.site_tracking_events_r
WHERE raw_event_id = 4
  AND raw_payload ? 'event_data';

-- ============================================================================
-- RESULTS SUMMARY
-- ============================================================================
SELECT 
    '✅ PHASE 1 VERIFICATION COMPLETE' as phase_status,
    'Check results above for:' as instructions,
    '1. Raw event details and payload structure' as check1,
    '2. Tenant isolation verification' as check2,
    '3. Processing status analysis' as check3,
    '4. Payload key structure' as check4; 