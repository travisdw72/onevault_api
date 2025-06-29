-- ========================================
-- TRACK LIVE EVENT FROM THEONESPAOREGON.COM - CORRECTED
-- ========================================
-- Event ID: 1ec01584e339fc26186b071a1a419c92752e44d9067280afaa72b6ff72d7cf4f
-- Timestamp: 2025-06-29T01:51:20.211937
-- Source: Browser console test from theonespaoregon.com
-- Processing: automatic (should flow through all layers)
-- FIXED: Using correct table names (_r suffix for raw tables)

\echo '🔍 TRACKING LIVE EVENT FROM THE ONE SPA WEBSITE (CORRECTED)'
\echo 'Event ID: 1ec01584e339fc26186b071a1a419c92752e44d9067280afaa72b6ff72d7cf4f'
\echo 'Expected: Complete pipeline flow (Raw → Staging → Business)'
\echo 'Using correct table names: raw.site_tracking_events_r'
\echo ''

-- ========================================
-- STEP 1: Check Raw Layer (CORRECTED TABLE NAME)
-- ========================================
\echo '📥 STEP 1: Checking Raw Layer (site_tracking_events_r)...'

SELECT 
    'RAW LAYER' as layer,
    raw_event_id,
    tenant_hk,
    received_timestamp,
    client_ip,
    user_agent,
    raw_payload,
    processing_status,
    error_message
FROM raw.site_tracking_events_r 
WHERE raw_payload::text LIKE '%1ec01584e339fc26186b071a1a419c92752e44d9067280afaa72b6ff72d7cf4f%'
   OR received_timestamp >= '2025-06-29 01:50:00'
ORDER BY received_timestamp DESC
LIMIT 5;

\echo ''

-- ========================================
-- STEP 2: Check Staging Layer 
-- ========================================
\echo '🔄 STEP 2: Checking Staging Layer...'

-- Check if staging table exists and what it's called
\echo 'First, let me check what staging tables exist:'
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname = 'staging' 
  AND tablename LIKE '%site%'
ORDER BY tablename;

\echo ''
\echo 'Now checking staging data:'

-- Try to find staging data (correct table name: site_tracking_events_s)
SELECT 
    'STAGING LAYER' as layer,
    staging_event_id,
    raw_event_id,
    tenant_hk,
    event_type,
    page_url,
    page_title,
    event_timestamp,
    processed_timestamp,
    validation_status,
    quality_score,
    processed_to_business,
    business_processing_timestamp
FROM staging.site_tracking_events_s
WHERE raw_event_id IN (
    SELECT raw_event_id 
    FROM raw.site_tracking_events_r 
    WHERE received_timestamp >= '2025-06-29 01:50:00'
       OR raw_payload::text LIKE '%console_test%'
)
ORDER BY processed_timestamp DESC
LIMIT 5;

\echo ''

-- ========================================
-- STEP 3: Check Business Layer - Hubs
-- ========================================
\echo '🏢 STEP 3: Checking Business Layer - Hubs...'

-- First, let's see what business tables exist
\echo 'Business schema tables:'
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname = 'business' 
  AND tablename LIKE '%site%'
ORDER BY tablename;

\echo ''

-- Check Site Event Hub (CONFIRMED EXISTS)
\echo 'Checking for recent business events:'
SELECT 
    'SITE_EVENT_HUB' as hub_type,
    site_event_hk,
    site_event_bk,
    tenant_hk,
    load_date
FROM business.site_event_h 
WHERE load_date >= '2025-06-29 01:50:00'
ORDER BY load_date DESC
LIMIT 5;

\echo ''
\echo 'Checking Site Session Hub:'
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

\echo ''
\echo 'Checking Site Visitor Hub:'
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

\echo ''
\echo 'Checking Site Page Hub:'
SELECT 
    'SITE_PAGE_HUB' as hub_type,
    site_page_hk,
    site_page_bk,
    tenant_hk,
    load_date
FROM business.site_page_h 
WHERE load_date >= '2025-06-29 01:50:00'
   OR site_page_bk LIKE '%theonespaoregon%'
ORDER BY load_date DESC
LIMIT 3;

\echo ''

-- ========================================
-- STEP 4: Business Layer - Satellites (Detailed Data)
-- ========================================
\echo '🛰️ STEP 4: Checking Business Layer - Satellites...'

-- Check Event Details Satellite
\echo 'Checking Site Event Details:'
SELECT 
    'EVENT_DETAILS' as satellite_type,
    sed.site_event_hk,
    sed.event_type,
    sed.event_timestamp,
    sed.page_url,
    sed.event_category,
    sed.event_action,
    sed.load_date
FROM business.site_event_details_s sed
JOIN business.site_event_h seh ON sed.site_event_hk = seh.site_event_hk
WHERE sed.load_date >= '2025-06-29 01:50:00'
   OR sed.page_url LIKE '%theonespaoregon%'
ORDER BY sed.load_date DESC
LIMIT 5;

\echo ''
\echo 'Checking Session Details:'
SELECT 
    'SESSION_DETAILS' as satellite_type,
    ssd.site_session_hk,
    ssd.session_start_time,
    ssd.total_page_views,
    ssd.total_events,
    ssd.entry_page_url,
    ssd.load_date
FROM business.site_session_details_s ssd
JOIN business.site_session_h ssh ON ssd.site_session_hk = ssh.site_session_hk
WHERE ssd.load_date >= '2025-06-29 01:50:00'
ORDER BY ssd.load_date DESC
LIMIT 3;

\echo ''

-- ========================================
-- STEP 5: Raw Data Analysis
-- ========================================
\echo '🔍 STEP 5: Detailed Raw Data Analysis...'

-- Look at the actual raw payload to understand the structure
SELECT 
    raw_event_id,
    tenant_hk,
    received_timestamp,
    processing_status,
    raw_payload,
    raw_payload->'event_id' as extracted_event_id,
    raw_payload->'event_type' as extracted_event_type,
    raw_payload->'page_url' as extracted_page_url
FROM raw.site_tracking_events_r 
WHERE received_timestamp >= '2025-06-29 01:50:00'
   OR raw_payload::text LIKE '%console_test%'
   OR raw_payload::text LIKE '%theonespaoregon%'
ORDER BY received_timestamp DESC
LIMIT 5;

\echo ''

-- ========================================
-- STEP 6: Check API Function Results
-- ========================================
\echo '📊 STEP 6: Checking if API Function Worked...'

-- Check if the api.track_site_event function created the expected structure
\echo 'Looking for events with our specific characteristics:'

SELECT 
    raw_event_id,
    received_timestamp,
    processing_status,
    raw_payload->'event_data'->>'test' as test_flag,
    raw_payload->'event_data'->>'spa_context' as spa_context,
    raw_payload->>'event_type' as event_type,
    raw_payload->>'page_url' as page_url
FROM raw.site_tracking_events_r 
WHERE raw_payload->'event_data'->>'test' = 'console_test'
   OR raw_payload->'event_data'->>'spa_context' = 'browser_console_test'
   OR raw_payload::text LIKE '%theonespaoregon%'
ORDER BY received_timestamp DESC
LIMIT 10;

\echo ''

-- ========================================
-- STEP 7: Tenant Verification
-- ========================================
\echo '🏢 STEP 7: Tenant Verification...'

-- Check which tenant this event was assigned to
-- First, let's see what columns exist in tenant_profile_s
\echo 'Tenant profile table structure:'
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'auth' 
  AND table_name = 'tenant_profile_s'
ORDER BY ordinal_position;

\echo ''
\echo 'Now checking tenant assignment:'

SELECT 
    r.raw_event_id,
    r.tenant_hk,
    t.tenant_bk,
    'Tenant Profile Data' as tenant_info,
    r.received_timestamp,
    r.processing_status
FROM raw.site_tracking_events_r r
JOIN auth.tenant_h t ON r.tenant_hk = t.tenant_hk
WHERE r.received_timestamp >= '2025-06-29 01:50:00'
   OR r.raw_payload::text LIKE '%console_test%'
ORDER BY r.received_timestamp DESC
LIMIT 5;

\echo ''

-- ========================================
-- STEP 8: Pipeline Functions Check
-- ========================================
\echo '⚙️ STEP 8: Checking Pipeline Functions...'

-- Check if pipeline functions exist
\echo 'Available staging functions:'
SELECT routine_name, routine_type
FROM information_schema.routines 
WHERE routine_schema = 'staging' 
  AND routine_name LIKE '%process%'
ORDER BY routine_name;

\echo ''

-- Try to get pipeline status if function exists
\echo 'Attempting to get pipeline status:'
SELECT * FROM staging.get_pipeline_status();

\echo ''
\echo '🎯 SUMMARY:'
\echo 'This corrected script should show:'
\echo '1. ✅ Raw event in site_tracking_events_r table'
\echo '2. 🔍 Which tenant it was assigned to (should be The ONE Spa)'
\echo '3. 📊 Processing status and any automation results'
\echo '4. 🏢 Whether it flowed to staging and business layers'
\echo ''
\echo '📋 KEY FINDINGS TO LOOK FOR:'
\echo '- Event should be assigned to The ONE Spa tenant'
\echo '- Processing status should be PROCESSED'
\echo '- Raw payload should contain our test data'
\echo '- Automation should have triggered staging processing' 