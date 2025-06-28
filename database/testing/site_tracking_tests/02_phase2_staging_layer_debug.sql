-- ============================================================================
-- PHASE 2: STAGING LAYER DEBUG & VERIFICATION
-- Site Tracking System Testing
-- ============================================================================
-- Purpose: Debug staging processing issues and verify staging layer functionality
-- Issue: "null value in column event_type" error during staging processing
-- ============================================================================

-- 2.1 Check Current Staging Processing Status
SELECT 
    '🔄 PHASE 2: STAGING LAYER DEBUG' as test_phase,
    s.staging_event_id,
    s.raw_event_id,
    s.tenant_hk,
    encode(s.tenant_hk, 'hex') as tenant_hk_hex,
    s.event_type,
    s.session_id,
    s.user_id,
    s.page_url,
    s.page_title,
    s.referrer_url,
    s.device_type,
    s.browser_name,
    s.operating_system,
    s.event_timestamp,
    s.processed_timestamp,
    s.validation_status,
    s.enrichment_status,
    s.quality_score,
    s.validation_errors,
    jsonb_pretty(s.enrichment_data) as enrichment_data
FROM staging.site_tracking_events_s s
WHERE s.raw_event_id = 4;

-- 2.2 Manual Processing Status Check
SELECT 
    '🚀 MANUAL STAGING PROCESSING STATUS' as action_type,
    CASE 
        WHEN EXISTS(SELECT 1 FROM staging.site_tracking_events_s WHERE raw_event_id = 4)
        THEN 'Staging record already exists'
        ELSE 'No staging record found - processing needed'
    END as status;

-- 2.3 Debug Raw Event Data for Staging Processing
SELECT 
    '🔍 RAW EVENT DATA ANALYSIS' as debug_type,
    r.raw_event_id,
    'Raw payload keys:' as analysis,
    jsonb_object_keys(r.raw_payload) as payload_keys
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4

UNION ALL

SELECT 
    '🔍 RAW EVENT DATA ANALYSIS',
    r.raw_event_id,
    'Event type mapping:',
    COALESCE(r.raw_payload->>'evt_type', r.raw_payload->>'event_type', 'NULL') as event_type_value
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4

UNION ALL

SELECT 
    '🔍 RAW EVENT DATA ANALYSIS',
    r.raw_event_id,
    'Timestamp mapping:',
    COALESCE(r.raw_payload->>'timestamp', r.received_timestamp::text, 'NULL') as timestamp_value
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4

UNION ALL

SELECT 
    '🔍 RAW EVENT DATA ANALYSIS',
    r.raw_event_id,
    'Page URL mapping:',
    COALESCE(r.raw_payload->>'page_url', 'NULL') as page_url_value
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4;

-- 2.4 Check Staging Function Exists
SELECT 
    '🔧 STAGING FUNCTION CHECK' as function_check,
    p.proname as function_name,
    n.nspname as schema_name,
    pg_get_function_identity_arguments(p.oid) as parameters
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'validate_and_enrich_event'
  AND n.nspname = 'staging';

-- 2.5 Staging Table Structure Analysis
SELECT 
    '📋 STAGING TABLE STRUCTURE' as structure_check,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'staging'
  AND table_name = 'site_tracking_events_s'
  AND column_name IN ('event_type', 'tenant_hk', 'session_id', 'page_url', 'event_timestamp')
ORDER BY ordinal_position;

-- 2.6 Data Quality Assessment (Current State)
SELECT 
    '📊 DATA QUALITY METRICS' as metrics_type,
    COALESCE(AVG(quality_score), 0) as avg_quality_score,
    COUNT(*) FILTER (WHERE validation_status = 'VALID') as valid_events,
    COUNT(*) FILTER (WHERE validation_status = 'INVALID') as invalid_events,
    COUNT(*) FILTER (WHERE validation_status = 'SUSPICIOUS') as suspicious_events,
    COUNT(*) FILTER (WHERE enrichment_status = 'ENRICHED') as enriched_events,
    COUNT(*) as total_staging_events
FROM staging.site_tracking_events_s
WHERE processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '2 hours';

-- 2.7 Recent Staging Events (if any)
SELECT 
    '📋 RECENT STAGING EVENTS' as summary_type,
    staging_event_id,
    raw_event_id,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    event_type,
    session_id,
    validation_status,
    enrichment_status,
    processed_timestamp
FROM staging.site_tracking_events_s
WHERE processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY processed_timestamp DESC
LIMIT 10;

-- ============================================================================
-- DIAGNOSTIC SUMMARY
-- ============================================================================
SELECT 
    '🔍 PHASE 2 DIAGNOSTIC SUMMARY' as diagnostic_summary,
    'Issues to check:' as instructions,
    '1. event_type field mapping (evt_type vs event_type)' as issue1,
    '2. Staging function parameter compatibility' as issue2,
    '3. Required field validation in staging' as issue3,
    '4. Tenant hash key validation' as issue4; 