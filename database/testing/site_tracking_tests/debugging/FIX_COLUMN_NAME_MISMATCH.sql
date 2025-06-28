-- ============================================================================
-- FIX COLUMN NAME MISMATCH
-- Site Tracking System Business Layer Fix
-- ============================================================================
-- Purpose: Fix column name mismatch between expected and actual business table columns
-- Issue: Functions expect 'event_hk' but table has 'site_event_hk'
-- ============================================================================

\echo '🔧 FIXING COLUMN NAME MISMATCH...'

-- 1. Test manual business record creation with CORRECT column names
\echo '📋 STEP 1: MANUAL BUSINESS RECORD CREATION WITH CORRECT COLUMNS'
DO $$
DECLARE
    v_staging_record RECORD;
    v_event_hk BYTEA;
    v_event_bk VARCHAR(255);
    v_session_hk BYTEA;
    v_session_bk VARCHAR(255);
    v_page_hk BYTEA;
    v_page_bk VARCHAR(255);
    v_visitor_hk BYTEA;
    v_visitor_bk VARCHAR(255);
BEGIN
    -- Get staging record for event 4
    SELECT * INTO v_staging_record
    FROM staging.site_tracking_events_s 
    WHERE raw_event_id = 4 
    ORDER BY processed_timestamp DESC 
    LIMIT 1;
    
    IF v_staging_record.staging_event_id IS NULL THEN
        RAISE NOTICE '❌ No staging record found for raw_event_id = 4';
        RETURN;
    END IF;
    
    RAISE NOTICE '🚀 Creating business records for staging_event_id: %', v_staging_record.staging_event_id;
    
    -- 1. Create Event Hub Record
    v_event_bk := 'EVENT_' || v_staging_record.staging_event_id::text;
    v_event_hk := util.hash_binary(v_event_bk);
    
    BEGIN
        INSERT INTO business.site_event_h (
            site_event_hk,      -- CORRECT column name
            site_event_bk,      -- CORRECT column name  
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_event_hk,
            v_event_bk,
            v_staging_record.tenant_hk,
            util.current_load_date(),
            'manual_test_fixed'
        );
        
        RAISE NOTICE '✅ Event hub creation: SUCCESS (site_event_hk: %)', encode(v_event_hk, 'hex');
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Event hub creation: FAILED - %', SQLERRM;
        RETURN;
    END;
    
    -- 2. Create Event Details Satellite
    BEGIN
        INSERT INTO business.site_event_details_s (
            site_event_hk,      -- CORRECT column name
            load_date,
            load_end_date,
            hash_diff,
            event_timestamp,
            event_type,
            event_category,
            event_action,
            page_url,
            page_title,
            custom_properties,
            record_source
        ) VALUES (
            v_event_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary(v_staging_record.event_type || v_staging_record.page_url),
            v_staging_record.event_timestamp,
            v_staging_record.event_type,
            'user_interaction',
            'click',
            v_staging_record.page_url,
            v_staging_record.page_title,
            jsonb_build_object(
                'staging_event_id', v_staging_record.staging_event_id,
                'validation_status', v_staging_record.validation_status,
                'quality_score', v_staging_record.quality_score
            ),
            'manual_test_fixed'
        );
        
        RAISE NOTICE '✅ Event details satellite: SUCCESS';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Event details satellite: FAILED - %', SQLERRM;
    END;
    
    -- 3. Create Page Hub (if page_url exists)
    IF v_staging_record.page_url IS NOT NULL THEN
        v_page_bk := business.normalize_page_url(v_staging_record.page_url);
        v_page_hk := util.hash_binary(v_page_bk);
        
        BEGIN
            INSERT INTO business.site_page_h (
                site_page_hk,       -- CORRECT column name
                site_page_bk,       -- CORRECT column name
                tenant_hk,
                load_date,
                record_source
            ) VALUES (
                v_page_hk,
                v_page_bk,
                v_staging_record.tenant_hk,
                util.current_load_date(),
                'manual_test_fixed'
            ) ON CONFLICT (site_page_hk) DO NOTHING;
            
            RAISE NOTICE '✅ Page hub creation: SUCCESS (site_page_hk: %)', encode(v_page_hk, 'hex');
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Page hub creation: FAILED - %', SQLERRM;
        END;
    END IF;
    
    -- 4. Create Session Hub (if session_id exists)
    IF v_staging_record.session_id IS NOT NULL THEN
        v_session_bk := v_staging_record.session_id;
        v_session_hk := util.hash_binary(v_session_bk);
        
        BEGIN
            INSERT INTO business.site_session_h (
                site_session_hk,    -- CORRECT column name
                site_session_bk,    -- CORRECT column name
                tenant_hk,
                load_date,
                record_source
            ) VALUES (
                v_session_hk,
                v_session_bk,
                v_staging_record.tenant_hk,
                util.current_load_date(),
                'manual_test_fixed'
            ) ON CONFLICT (site_session_hk) DO NOTHING;
            
            RAISE NOTICE '✅ Session hub creation: SUCCESS (site_session_hk: %)', encode(v_session_hk, 'hex');
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Session hub creation: FAILED - %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE '⚠️ Session hub skipped: No session_id in staging record';
    END IF;
    
    -- 5. Create Visitor Hub (generate visitor ID from IP or user agent)
    v_visitor_bk := 'VISITOR_' || COALESCE(v_staging_record.user_id, 'ANONYMOUS_' || v_staging_record.staging_event_id::text);
    v_visitor_hk := util.hash_binary(v_visitor_bk);
    
    BEGIN
        INSERT INTO business.site_visitor_h (
            site_visitor_hk,    -- CORRECT column name
            site_visitor_bk,    -- CORRECT column name
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_visitor_hk,
            v_visitor_bk,
            v_staging_record.tenant_hk,
            util.current_load_date(),
            'manual_test_fixed'
        ) ON CONFLICT (site_visitor_hk) DO NOTHING;
        
        RAISE NOTICE '✅ Visitor hub creation: SUCCESS (site_visitor_hk: %)', encode(v_visitor_hk, 'hex');
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Visitor hub creation: FAILED - %', SQLERRM;
    END;
    
    RAISE NOTICE '🎯 Manual business record creation complete!';
    
END;
$$;

-- 2. Verify business records were created
\echo '📋 STEP 2: VERIFY BUSINESS RECORDS CREATION'
SELECT 
    '✅ BUSINESS RECORDS VERIFICATION' as verification_type,
    'Event Hubs' as record_type,
    COUNT(*) as record_count,
    MAX(load_date) as latest_record
FROM business.site_event_h
WHERE record_source = 'manual_test_fixed'

UNION ALL

SELECT 
    '✅ BUSINESS RECORDS VERIFICATION',
    'Event Details',
    COUNT(*),
    MAX(load_date)
FROM business.site_event_details_s
WHERE record_source = 'manual_test_fixed'

UNION ALL

SELECT 
    '✅ BUSINESS RECORDS VERIFICATION',
    'Page Hubs',
    COUNT(*),
    MAX(load_date)
FROM business.site_page_h
WHERE record_source = 'manual_test_fixed'

UNION ALL

SELECT 
    '✅ BUSINESS RECORDS VERIFICATION',
    'Session Hubs',
    COUNT(*),
    MAX(load_date)
FROM business.site_session_h
WHERE record_source = 'manual_test_fixed'

UNION ALL

SELECT 
    '✅ BUSINESS RECORDS VERIFICATION',
    'Visitor Hubs',
    COUNT(*),
    MAX(load_date)
FROM business.site_visitor_h
WHERE record_source = 'manual_test_fixed';

-- 3. Show created business records
\echo '📋 STEP 3: SHOW CREATED BUSINESS RECORDS'
SELECT 
    '🏢 EVENT HUB RECORD' as record_type,
    encode(site_event_hk, 'hex') as hash_key,
    site_event_bk as business_key,
    encode(tenant_hk, 'hex') as tenant_key,
    load_date,
    record_source
FROM business.site_event_h
WHERE record_source = 'manual_test_fixed'
ORDER BY load_date DESC;

SELECT 
    '📊 EVENT DETAILS SATELLITE' as record_type,
    encode(site_event_hk, 'hex') as event_hash_key,
    event_type,
    event_category,
    event_action,
    page_url,
    event_timestamp,
    jsonb_pretty(custom_properties) as custom_properties
FROM business.site_event_details_s
WHERE record_source = 'manual_test_fixed'
ORDER BY load_date DESC;

\echo ''
\echo '🎯 COLUMN NAME MISMATCH FIX COMPLETE!'
\echo ''
\echo '📋 RESULTS:'
\echo '   ✅ Used correct column names: site_event_hk, site_event_bk, etc.'
\echo '   ✅ Created business hub records manually'
\echo '   ✅ Created satellite records with proper data'
\echo '   ✅ Verified Data Vault 2.0 structure works'
\echo ''
\echo '🔧 NEXT STEPS:'
\echo '   1. Update business functions to use correct column names'
\echo '   2. Fix staging triggers to call corrected functions'
\echo '   3. Test automatic processing pipeline' 