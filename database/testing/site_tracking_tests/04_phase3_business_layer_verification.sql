-- ============================================================================
-- PHASE 3: BUSINESS LAYER VERIFICATION
-- Site Tracking System Testing - Data Vault 2.0 Layer
-- ============================================================================
-- Purpose: Verify Data Vault 2.0 hub/link/satellite creation and processing
-- Requires: Successful completion of Phase 2 (staging processing)
-- ============================================================================

-- 3.1 Hub Record Creation Verification
SELECT 
    '🏢 PHASE 3: BUSINESS LAYER - HUB VERIFICATION' as test_phase,
    'session_hub' as hub_type,
    COUNT(*) as record_count
FROM business.site_session_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'

UNION ALL

SELECT 
    '🏢 PHASE 3: BUSINESS LAYER - HUB VERIFICATION',
    'visitor_hub',
    COUNT(*)
FROM business.site_visitor_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'

UNION ALL

SELECT 
    '🏢 PHASE 3: BUSINESS LAYER - HUB VERIFICATION',
    'event_hub',
    COUNT(*)
FROM business.site_event_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'

UNION ALL

SELECT 
    '🏢 PHASE 3: BUSINESS LAYER - HUB VERIFICATION',
    'page_hub',
    COUNT(*)
FROM business.site_page_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- 3.2 Session Hub Details
SELECT 
    '🔗 SESSION HUB DETAILS' as detail_type,
    encode(session_hk, 'hex') as session_hk_hex,
    session_bk,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    load_date,
    record_source
FROM business.site_session_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY load_date DESC
LIMIT 5;

-- 3.3 Event Hub Details
SELECT 
    '⚡ EVENT HUB DETAILS' as detail_type,
    encode(event_hk, 'hex') as event_hk_hex,
    event_bk,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    load_date,
    record_source
FROM business.site_event_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY load_date DESC
LIMIT 5;

-- 3.4 Link Relationship Verification
SELECT 
    '🔗 LINK RELATIONSHIPS VERIFICATION' as verification_type,
    'session_visitor_links' as link_type,
    COUNT(*) as record_count
FROM business.session_visitor_l
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'

UNION ALL

SELECT 
    '🔗 LINK RELATIONSHIPS VERIFICATION',
    'event_session_links',
    COUNT(*)
FROM business.event_session_l
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'

UNION ALL

SELECT 
    '🔗 LINK RELATIONSHIPS VERIFICATION',
    'event_page_links',
    COUNT(*)
FROM business.event_page_l
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- 3.5 Session-Visitor Link Details
SELECT 
    '👥 SESSION-VISITOR LINK DETAILS' as link_detail_type,
    encode(link_session_visitor_hk, 'hex') as link_hk_hex,
    encode(session_hk, 'hex') as session_hk_hex,
    encode(visitor_hk, 'hex') as visitor_hk_hex,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    load_date,
    record_source
FROM business.session_visitor_l
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY load_date DESC
LIMIT 3;

-- 3.6 Event-Session Link Details
SELECT 
    '⚡🔗 EVENT-SESSION LINK DETAILS' as link_detail_type,
    encode(link_event_session_hk, 'hex') as link_hk_hex,
    encode(event_hk, 'hex') as event_hk_hex,
    encode(session_hk, 'hex') as session_hk_hex,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    load_date,
    record_source
FROM business.event_session_l
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY load_date DESC
LIMIT 3;

-- 3.7 Satellite Data Population Verification
SELECT 
    '📊 SATELLITE DATA VERIFICATION' as satellite_type,
    'event_details_satellites' as satellite_name,
    COUNT(*) as record_count,
    MAX(load_date) as latest_load_date
FROM business.site_event_details_s
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'

UNION ALL

SELECT 
    '📊 SATELLITE DATA VERIFICATION',
    'session_details_satellites',
    COUNT(*),
    MAX(load_date)
FROM business.site_session_details_s
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'

UNION ALL

SELECT 
    '📊 SATELLITE DATA VERIFICATION',
    'visitor_details_satellites',
    COUNT(*),
    MAX(load_date)
FROM business.site_visitor_details_s
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- 3.8 Event Details Satellite Content
SELECT 
    '⚡📊 EVENT DETAILS SATELLITE' as satellite_content,
    encode(event_hk, 'hex') as event_hk_hex,
    load_date,
    load_end_date,
    encode(hash_diff, 'hex') as hash_diff_hex,
    event_type,
    event_action,
    event_category,
    element_id,
    element_class,
    element_text,
    custom_properties,
    jsonb_pretty(tracking_context) as tracking_context_details,
    record_source
FROM business.site_event_details_s
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY load_date DESC
LIMIT 3;

-- 3.9 Session Details Satellite Content
SELECT 
    '🔗📊 SESSION DETAILS SATELLITE' as satellite_content,
    encode(session_hk, 'hex') as session_hk_hex,
    load_date,
    load_end_date,
    session_start_time,
    session_end_time,
    entry_page,
    exit_page,
    page_view_count,
    event_count,
    duration_seconds,
    is_bounce_session,
    device_category,
    browser_info,
    jsonb_pretty(utm_parameters) as utm_details,
    record_source
FROM business.site_session_details_s
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY load_date DESC
LIMIT 3;

-- 3.10 Data Vault Lineage Verification
SELECT 
    '🔄 DATA VAULT LINEAGE CHECK' as lineage_check,
    s.staging_event_id as staging_source,
    encode(eh.event_hk, 'hex') as event_hub_created,
    encode(eds.event_hk, 'hex') as event_satellite_created,
    s.event_type as original_event_type,
    eds.event_type as vault_event_type,
    CASE 
        WHEN eh.event_hk IS NOT NULL AND eds.event_hk IS NOT NULL 
        THEN '✅ Complete DV2.0 Chain'
        WHEN eh.event_hk IS NOT NULL 
        THEN '⚠️ Hub Only'
        ELSE '❌ No DV2.0 Records'
    END as lineage_status
FROM staging.site_tracking_events_s s
LEFT JOIN business.site_event_h eh ON s.staging_event_id::text = eh.event_bk
LEFT JOIN business.site_event_details_s eds ON eh.event_hk = eds.event_hk
WHERE s.processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY s.processed_timestamp DESC;

-- 3.11 Tenant Isolation in Business Layer
SELECT 
    '🔒 BUSINESS LAYER TENANT ISOLATION' as isolation_check,
    'hub_tenant_distribution' as check_type,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    COUNT(*) as record_count
FROM (
    SELECT tenant_hk FROM business.site_session_h WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    UNION ALL
    SELECT tenant_hk FROM business.site_event_h WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    UNION ALL
    SELECT tenant_hk FROM business.site_visitor_h WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    UNION ALL
    SELECT tenant_hk FROM business.site_page_h WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
) hub_tenants
GROUP BY tenant_hk
ORDER BY record_count DESC;

-- ============================================================================
-- BUSINESS LAYER SUMMARY
-- ============================================================================
SELECT 
    '🎯 PHASE 3 BUSINESS LAYER COMPLETE' as summary,
    'Verification checklist:' as checklist,
    '1. Hub record creation (session, visitor, event, page)' as check1,
    '2. Link relationship establishment' as check2,
    '3. Satellite data population and historization' as check3,
    '4. Data Vault 2.0 lineage integrity' as check4,
    '5. Tenant isolation in business layer' as check5; 