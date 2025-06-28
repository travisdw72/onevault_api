-- ============================================================================
-- PHASE 5: END-TO-END FLOW VERIFICATION
-- Site Tracking System Testing
-- ============================================================================
-- Purpose: Verify complete data pipeline from raw ingestion to business insights
-- Tests: Data flow tracing, multi-event processing, session aggregation
-- ============================================================================

-- 5.1 Complete Data Pipeline Flow Trace
SELECT 
    '🔄 PHASE 5: END-TO-END FLOW VERIFICATION' as test_phase,
    r.raw_event_id,
    r.received_timestamp,
    r.processing_status as raw_status,
    s.staging_event_id,
    s.processed_timestamp as staging_processed,
    s.validation_status,
    s.enrichment_status,
    encode(eh.event_hk, 'hex') as event_hub_hk,
    eh.load_date as hub_created,
    encode(eds.event_hk, 'hex') as event_satellite_hk,
    eds.load_date as satellite_created,
    CASE 
        WHEN eds.event_hk IS NOT NULL THEN '✅ Complete Pipeline'
        WHEN eh.event_hk IS NOT NULL THEN '🔄 Hub Created'
        WHEN s.staging_event_id IS NOT NULL THEN '📝 Staging Only'
        ELSE '🔴 Raw Only'
    END as pipeline_status
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
LEFT JOIN business.site_event_h eh ON s.staging_event_id::text = eh.event_bk
LEFT JOIN business.site_event_details_s eds ON eh.event_hk = eds.event_hk 
                                            AND eds.load_end_date IS NULL
WHERE r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY r.received_timestamp DESC;

-- 5.2 Session Journey Tracking
SELECT 
    '👥 SESSION JOURNEY TRACKING' as journey_analysis,
    s.session_id,
    COUNT(DISTINCT ste.staging_event_id) as total_events,
    COUNT(DISTINCT ste.page_url) as unique_pages,
    MIN(ste.event_timestamp) as session_start,
    MAX(ste.event_timestamp) as session_end,
    EXTRACT(EPOCH FROM (MAX(ste.event_timestamp) - MIN(ste.event_timestamp)))::integer as duration_seconds,
    array_agg(DISTINCT ste.event_type ORDER BY ste.event_type) as event_types,
    array_agg(DISTINCT ste.page_url ORDER BY ste.event_timestamp) as page_journey
FROM staging.site_tracking_events_s s
JOIN staging.site_tracking_events_s ste ON s.session_id = ste.session_id
WHERE s.processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND s.session_id IS NOT NULL
GROUP BY s.session_id
ORDER BY total_events DESC;

-- 5.3 Multi-Event Processing Verification
SELECT 
    '⚡ MULTI-EVENT PROCESSING' as processing_analysis,
    DATE_TRUNC('hour', r.received_timestamp) as processing_hour,
    COUNT(*) as raw_events_received,
    COUNT(s.staging_event_id) as staging_events_processed,
    COUNT(eh.event_hk) as business_hubs_created,
    COUNT(eds.event_hk) as business_satellites_created,
    ROUND(
        COUNT(s.staging_event_id)::numeric / 
        NULLIF(COUNT(*), 0) * 100, 2
    ) as staging_processing_rate,
    ROUND(
        COUNT(eh.event_hk)::numeric / 
        NULLIF(COUNT(s.staging_event_id), 0) * 100, 2
    ) as business_processing_rate
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
LEFT JOIN business.site_event_h eh ON s.staging_event_id::text = eh.event_bk
LEFT JOIN business.site_event_details_s eds ON eh.event_hk = eds.event_hk 
                                            AND eds.load_end_date IS NULL
WHERE r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', r.received_timestamp)
ORDER BY processing_hour DESC;

-- 5.4 Data Consistency Verification
SELECT 
    '🔍 DATA CONSISTENCY VERIFICATION' as consistency_check,
    'event_type_consistency' as check_type,
    r.raw_payload->>'event_type' as raw_event_type,
    s.event_type as staging_event_type,
    eds.event_type as business_event_type,
    CASE 
        WHEN r.raw_payload->>'event_type' = s.event_type 
         AND s.event_type = eds.event_type THEN '✅ Consistent'
        WHEN r.raw_payload->>'event_type' = s.event_type THEN '⚠️ Staging OK'
        ELSE '❌ Inconsistent'
    END as consistency_status
FROM raw.site_tracking_events_r r
JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
JOIN business.site_event_h eh ON s.staging_event_id::text = eh.event_bk
JOIN business.site_event_details_s eds ON eh.event_hk = eds.event_hk 
                                        AND eds.load_end_date IS NULL
WHERE r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY r.received_timestamp DESC;

-- 5.5 Timing Sequence Verification
SELECT 
    '⏱️ TIMING SEQUENCE VERIFICATION' as timing_check,
    r.raw_event_id,
    r.received_timestamp as raw_time,
    s.processed_timestamp as staging_time,
    eh.load_date as hub_time,
    eds.load_date as satellite_time,
    EXTRACT(EPOCH FROM (s.processed_timestamp - r.received_timestamp))::integer as raw_to_staging_seconds,
    EXTRACT(EPOCH FROM (eh.load_date - s.processed_timestamp))::integer as staging_to_hub_seconds,
    EXTRACT(EPOCH FROM (eds.load_date - eh.load_date))::integer as hub_to_satellite_seconds,
    CASE 
        WHEN s.processed_timestamp >= r.received_timestamp 
         AND eh.load_date >= s.processed_timestamp 
         AND eds.load_date >= eh.load_date THEN '✅ Correct Sequence'
        ELSE '⚠️ Timing Issue'
    END as sequence_status
FROM raw.site_tracking_events_r r
JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
JOIN business.site_event_h eh ON s.staging_event_id::text = eh.event_bk
JOIN business.site_event_details_s eds ON eh.event_hk = eds.event_hk 
                                        AND eds.load_end_date IS NULL
WHERE r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY r.received_timestamp DESC;

-- 5.6 Error Propagation Analysis
SELECT 
    '❌ ERROR PROPAGATION ANALYSIS' as error_analysis,
    r.processing_status,
    r.error_message as raw_error,
    s.validation_status,
    s.validation_errors as staging_errors,
    COUNT(*) as error_count,
    array_agg(DISTINCT r.raw_event_id ORDER BY r.raw_event_id) as affected_events
FROM raw.site_tracking_events_r r
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
WHERE r.received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND (r.processing_status != 'PROCESSED' 
       OR s.validation_status = 'INVALID' 
       OR r.error_message IS NOT NULL)
GROUP BY r.processing_status, r.error_message, s.validation_status, s.validation_errors
ORDER BY error_count DESC;

-- 5.7 Visitor Journey Aggregation
SELECT 
    '🗺️ VISITOR JOURNEY AGGREGATION' as visitor_analysis,
    encode(vh.visitor_hk, 'hex') as visitor_hk_hex,
    COUNT(DISTINCT sh.session_hk) as total_sessions,
    COUNT(DISTINCT eh.event_hk) as total_events,
    COUNT(DISTINCT ph.page_hk) as unique_pages_visited,
    MIN(sds.session_start_time) as first_visit,
    MAX(sds.session_end_time) as last_visit,
    SUM(sds.duration_seconds) as total_time_spent,
    AVG(sds.page_view_count) as avg_pages_per_session
FROM business.site_visitor_h vh
JOIN business.session_visitor_l svl ON vh.visitor_hk = svl.visitor_hk
JOIN business.site_session_h sh ON svl.session_hk = sh.session_hk
LEFT JOIN business.site_session_details_s sds ON sh.session_hk = sds.session_hk 
                                               AND sds.load_end_date IS NULL
LEFT JOIN business.event_session_l esl ON sh.session_hk = esl.session_hk
LEFT JOIN business.site_event_h eh ON esl.event_hk = eh.event_hk
LEFT JOIN business.event_page_l epl ON eh.event_hk = epl.event_hk
LEFT JOIN business.site_page_h ph ON epl.page_hk = ph.page_hk
WHERE vh.load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY vh.visitor_hk
HAVING COUNT(DISTINCT eh.event_hk) > 0
ORDER BY total_events DESC
LIMIT 10;

-- 5.8 Business Intelligence Readiness
SELECT 
    '📊 BUSINESS INTELLIGENCE READINESS' as bi_readiness,
    'data_completeness' as metric_type,
    COUNT(DISTINCT eh.event_hk) as total_events,
    COUNT(DISTINCT sh.session_hk) as total_sessions,
    COUNT(DISTINCT vh.visitor_hk) as total_visitors,
    COUNT(DISTINCT ph.page_hk) as total_pages,
    COUNT(DISTINCT eds.event_hk) FILTER (WHERE eds.event_type IS NOT NULL) as events_with_type,
    COUNT(DISTINCT sds.session_hk) FILTER (WHERE sds.duration_seconds IS NOT NULL) as sessions_with_duration,
    ROUND(
        COUNT(DISTINCT eds.event_hk) FILTER (WHERE eds.event_type IS NOT NULL)::numeric /
        NULLIF(COUNT(DISTINCT eh.event_hk), 0) * 100, 2
    ) as event_data_completeness_pct
FROM business.site_event_h eh
LEFT JOIN business.site_event_details_s eds ON eh.event_hk = eds.event_hk 
                                             AND eds.load_end_date IS NULL
LEFT JOIN business.event_session_l esl ON eh.event_hk = esl.event_hk
LEFT JOIN business.site_session_h sh ON esl.session_hk = sh.session_hk
LEFT JOIN business.site_session_details_s sds ON sh.session_hk = sds.session_hk 
                                               AND sds.load_end_date IS NULL
LEFT JOIN business.session_visitor_l svl ON sh.session_hk = svl.session_hk
LEFT JOIN business.site_visitor_h vh ON svl.visitor_hk = vh.visitor_hk
LEFT JOIN business.event_page_l epl ON eh.event_hk = epl.event_hk
LEFT JOIN business.site_page_h ph ON epl.page_hk = ph.page_hk
WHERE eh.load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- 5.9 Real-time Analytics Sample
SELECT 
    '📈 REAL-TIME ANALYTICS SAMPLE' as analytics_sample,
    eds.event_type,
    COUNT(*) as event_count,
    COUNT(DISTINCT esl.session_hk) as unique_sessions,
    COUNT(DISTINCT svl.visitor_hk) as unique_visitors,
    ROUND(AVG(sds.duration_seconds), 2) as avg_session_duration,
    array_agg(DISTINCT substring(pds.page_title, 1, 50) ORDER BY COUNT(*) DESC) 
        FILTER (WHERE pds.page_title IS NOT NULL) as top_pages
FROM business.site_event_details_s eds
JOIN business.site_event_h eh ON eds.event_hk = eh.event_hk
JOIN business.event_session_l esl ON eh.event_hk = esl.event_hk
JOIN business.site_session_h sh ON esl.session_hk = sh.session_hk
LEFT JOIN business.site_session_details_s sds ON sh.session_hk = sds.session_hk 
                                               AND sds.load_end_date IS NULL
LEFT JOIN business.session_visitor_l svl ON sh.session_hk = svl.session_hk
LEFT JOIN business.event_page_l epl ON eh.event_hk = epl.event_hk
LEFT JOIN business.site_page_h ph ON epl.page_hk = ph.page_hk
LEFT JOIN business.site_page_details_s pds ON ph.page_hk = pds.page_hk 
                                            AND pds.load_end_date IS NULL
WHERE eds.load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND eds.load_end_date IS NULL
GROUP BY eds.event_type
ORDER BY event_count DESC;

-- ============================================================================
-- END-TO-END FLOW SUMMARY
-- ============================================================================
SELECT 
    '🎯 PHASE 5 END-TO-END FLOW COMPLETE' as summary,
    'Verification checklist:' as checklist,
    '1. Complete data pipeline flow tracking' as check1,
    '2. Session journey and visitor aggregation' as check2,
    '3. Multi-event processing verification' as check3,
    '4. Data consistency across all layers' as check4,
    '5. Timing sequence validation' as check5,
    '6. Error propagation analysis' as check6,
    '7. Business intelligence readiness assessment' as check7; 