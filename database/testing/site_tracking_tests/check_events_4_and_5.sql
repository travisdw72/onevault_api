-- ============================================================================
-- SIMPLE QUERY: See Events 4 & 5 Across All Layers
-- Copy/paste this into pgAdmin to see the complete data flow
-- ============================================================================

-- Raw Layer Data
SELECT 
    '🔴 RAW LAYER' as layer,
    raw_event_id,
    processing_status,
    received_timestamp,
    raw_payload->>'event_type' as event_type,
    raw_payload->>'session_id' as session_id,
    raw_payload->>'page_url' as page_url
FROM raw.site_tracking_events_r 
WHERE raw_event_id IN (4, 5)
ORDER BY raw_event_id;

-- Staging Layer Data  
SELECT 
    '🟡 STAGING LAYER' as layer,
    staging_event_id,
    raw_event_id,
    validation_status,
    quality_score,
    event_type,
    session_id,
    page_url,
    processed_to_business
FROM staging.site_tracking_events_s 
WHERE raw_event_id IN (4, 5)
ORDER BY raw_event_id;

-- Business Layer Data - Event Hubs
SELECT 
    '🟢 BUSINESS LAYER - EVENTS' as layer,
    site_event_bk as business_key,
    encode(site_event_hk, 'hex') as event_hash_key,
    load_date,
    record_source
FROM business.site_event_h 
WHERE site_event_bk LIKE 'evt_staging_%'
ORDER BY site_event_bk;

-- Business Layer Data - Event Details (Satellites)
SELECT 
    '🟢 BUSINESS LAYER - EVENT DETAILS' as layer,
    eh.site_event_bk as business_key,
    ed.event_timestamp,
    ed.event_type,
    ed.event_category,
    ed.event_action,
    ed.event_label,
    ed.event_value
FROM business.site_event_h eh
JOIN business.site_event_details_s ed ON eh.site_event_hk = ed.site_event_hk
WHERE eh.site_event_bk LIKE 'evt_staging_%'
  AND ed.load_end_date IS NULL
ORDER BY eh.site_event_bk;

-- Complete Flow Summary
SELECT 
    '📊 COMPLETE FLOW SUMMARY' as summary,
    r.raw_event_id,
    r.processing_status as raw_status,
    s.staging_event_id,
    s.validation_status as staging_status,
    s.processed_to_business,
    eh.site_event_bk as business_key,
    CASE 
        WHEN eh.site_event_bk IS NOT NULL THEN '✅ Complete Pipeline'
        WHEN s.staging_event_id IS NOT NULL THEN '⚠️ Missing Business'
        ELSE '❌ Processing Failed'
    END as pipeline_status
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id  
LEFT JOIN business.site_event_h eh ON ('evt_staging_' || s.staging_event_id::text) = eh.site_event_bk
WHERE r.raw_event_id IN (4, 5)
ORDER BY r.raw_event_id; 