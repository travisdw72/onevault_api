-- ========================================
-- TRACK LIVE EVENT FROM THEONESPAOREGON.COM
-- ========================================
-- Event ID: 1ec01584e339fc26186b071a1a419c92752e44d9067280afaa72b6ff72d7cf4f
-- Timestamp: 2025-06-29T01:51:20.211937
-- Source: Browser console test from theonespaoregon.com
-- Processing: automatic (should flow through all layers)

\echo '🔍 TRACKING LIVE EVENT FROM THE ONE SPA WEBSITE'
\echo 'Event ID: 1ec01584e339fc26186b071a1a419c92752e44d9067280afaa72b6ff72d7cf4f'
\echo 'Expected: Complete pipeline flow (Raw → Staging → Business)'
\echo ''

-- ========================================
-- STEP 1: Check Raw Layer
-- ========================================
\echo '📥 STEP 1: Checking Raw Layer...'

SELECT 
    'RAW LAYER' as layer,
    event_id,
    event_type,
    page_url,
    event_data,
    processed_timestamp,
    processing_status,
    created_at
FROM raw.site_tracking_events 
WHERE event_id = '1ec01584e339fc26186b071a1a419c92752e44d9067280afaa72b6ff72d7cf4f'
ORDER BY created_at DESC;

\echo ''

-- ========================================
-- STEP 2: Check Staging Layer
-- ========================================
\echo '🔄 STEP 2: Checking Staging Layer...'

SELECT 
    'STAGING LAYER' as layer,
    staging_event_id,
    raw_event_id,
    event_type,
    page_url,
    validation_status,
    quality_score,
    processed_to_business,
    created_at,
    processed_timestamp
FROM staging.site_events 
WHERE raw_event_id = '1ec01584e339fc26186b071a1a419c92752e44d9067280afaa72b6ff72d7cf4f'
ORDER BY created_at DESC;

\echo ''

-- ========================================
-- STEP 3: Check Business Layer - Hubs
-- ========================================
\echo '🏢 STEP 3: Checking Business Layer - Hubs...'

-- Check Site Event Hub
SELECT 
    'SITE_EVENT_HUB' as hub_type,
    site_event_hk,
    site_event_bk,
    tenant_hk,
    load_date
FROM business.site_event_h 
WHERE site_event_bk LIKE '%1ec01584%' 
   OR site_event_bk LIKE '%staging%'
ORDER BY load_date DESC
LIMIT 5;

-- Check Site Session Hub
SELECT 
    'SITE_SESSION_HUB' as hub_type,
    site_session_hk,
    site_session_bk,
    tenant_hk,
    load_date
FROM business.site_session_h 
WHERE load_date >= '2025-06-29 01:50:00'
ORDER BY load_date DESC
LIMIT 3;

-- Check Site Visitor Hub
SELECT 
    'SITE_VISITOR_HUB' as hub_type,
    site_visitor_hk,
    site_visitor_bk,
    tenant_hk,
    load_date
FROM business.site_visitor_h 
WHERE load_date >= '2025-06-29 01:50:00'
ORDER BY load_date DESC
LIMIT 3;

-- Check Site Page Hub
SELECT 
    'SITE_PAGE_HUB' as hub_type,
    site_page_hk,
    site_page_bk,
    tenant_hk,
    load_date
FROM business.site_page_h 
WHERE site_page_bk LIKE '%theonespaoregon%'
   OR load_date >= '2025-06-29 01:50:00'
ORDER BY load_date DESC
LIMIT 3;

\echo ''

-- ========================================
-- STEP 4: Check Business Layer - Satellites
-- ========================================
\echo '🛰️ STEP 4: Checking Business Layer - Satellites...'

-- Check Event Details
SELECT 
    'EVENT_DETAILS' as satellite_type,
    sed.site_event_hk,
    sed.event_type,
    sed.event_timestamp,
    sed.event_data,
    sed.load_date
FROM business.site_event_details_s sed
JOIN business.site_event_h seh ON sed.site_event_hk = seh.site_event_hk
WHERE sed.load_date >= '2025-06-29 01:50:00'
   OR sed.event_data::text LIKE '%console_test%'
ORDER BY sed.load_date DESC
LIMIT 3;

\echo ''

-- ========================================
-- STEP 5: Check Pipeline Status
-- ========================================
\echo '📊 STEP 5: Checking Pipeline Status...'

SELECT * FROM staging.get_pipeline_status();

\echo ''

-- ========================================
-- STEP 6: Check Recent Pipeline Dashboard
-- ========================================
\echo '📈 STEP 6: Recent Pipeline Activity...'

SELECT 
    raw_event_id,
    staging_event_id,
    business_status,
    pipeline_status,
    raw_created_at,
    staging_processed_at,
    business_processed_at
FROM staging.pipeline_dashboard 
WHERE raw_created_at >= '2025-06-29 01:50:00'
ORDER BY raw_created_at DESC
LIMIT 5;

\echo ''

-- ========================================
-- STEP 7: Verify Complete Flow
-- ========================================
\echo '✅ STEP 7: Complete Flow Verification...'

WITH event_flow AS (
    SELECT 
        'Raw Event' as stage,
        event_id as identifier,
        processing_status as status,
        created_at as timestamp
    FROM raw.site_tracking_events 
    WHERE event_id = '1ec01584e339fc26186b071a1a419c92752e44d9067280afaa72b6ff72d7cf4f'
    
    UNION ALL
    
    SELECT 
        'Staging Event' as stage,
        staging_event_id::text as identifier,
        validation_status as status,
        processed_timestamp as timestamp
    FROM staging.site_events 
    WHERE raw_event_id = '1ec01584e339fc26186b071a1a419c92752e44d9067280afaa72b6ff72d7cf4f'
    
    UNION ALL
    
    SELECT 
        'Business Hub' as stage,
        site_event_bk as identifier,
        'CREATED' as status,
        load_date as timestamp
    FROM business.site_event_h 
    WHERE load_date >= '2025-06-29 01:50:00'
    ORDER BY load_date DESC
    LIMIT 1
)
SELECT 
    stage,
    identifier,
    status,
    timestamp,
    CASE 
        WHEN stage = 'Raw Event' AND status = 'PROCESSED' THEN '✅'
        WHEN stage = 'Staging Event' AND status = 'VALID' THEN '✅'
        WHEN stage = 'Business Hub' AND status = 'CREATED' THEN '✅'
        ELSE '❌'
    END as success_indicator
FROM event_flow
ORDER BY timestamp;

\echo ''
\echo '🎯 SUMMARY:'
\echo 'If you see ✅ for all three stages, the automation is working perfectly!'
\echo 'Raw → Staging → Business pipeline completed successfully.'
\echo ''
\echo '📋 NEXT STEPS:'
\echo '1. Check that all stages show ✅'
\echo '2. Verify business key formats are correct'
\echo '3. Confirm tenant isolation is working'
\echo '4. Test additional events from theonespaoregon.com'