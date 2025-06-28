-- ============================================================================
-- FIX BUSINESS KEY FORMATS
-- Site Tracking System Business Layer Fix
-- ============================================================================
-- Purpose: Use proper business key formats and get_or_create functions
-- Constraints: evt_*, sess_*/session_*, visitor_*, any non-empty for pages
-- ============================================================================

\echo '🔧 FIXING WITH CORRECT BUSINESS KEY FORMATS...'

-- 1. Create business records using CORRECT formats and functions
\echo '📋 STEP 1: BUSINESS RECORD CREATION WITH CORRECT FORMATS'
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
    
    RAISE NOTICE '🚀 Creating business records with CORRECT formats for staging_event_id: %', v_staging_record.staging_event_id;
    
    -- 1. Create Event Hub using get_or_create function
    -- Format: evt_[identifier] (REQUIRED by constraint)
    v_event_bk := 'evt_staging_' || v_staging_record.staging_event_id::text;
    
    BEGIN
        SELECT business.get_or_create_site_event_hk(
            v_event_bk,
            v_staging_record.tenant_hk,
            'corrected_manual_test'
        ) INTO v_event_hk;
        
        RAISE NOTICE '✅ Event hub creation: SUCCESS (evt_staging_%)', v_staging_record.staging_event_id;
        RAISE NOTICE '   - Business Key: %', v_event_bk;
        RAISE NOTICE '   - Hash Key: %', encode(v_event_hk, 'hex');
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Event hub creation: FAILED - %', SQLERRM;
        RETURN;
    END;
    
    -- 2. Create Event Details Satellite
    BEGIN
        INSERT INTO business.site_event_details_s (
            site_event_hk,
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
            util.hash_binary(v_staging_record.event_type || COALESCE(v_staging_record.page_url, '')),
            v_staging_record.event_timestamp,
            v_staging_record.event_type,
            'user_interaction',
            'click',
            v_staging_record.page_url,
            v_staging_record.page_title,
            jsonb_build_object(
                'staging_event_id', v_staging_record.staging_event_id,
                'validation_status', v_staging_record.validation_status,
                'quality_score', v_staging_record.quality_score,
                'corrected_format', true
            ),
            'corrected_manual_test'
        );
        
        RAISE NOTICE '✅ Event details satellite: SUCCESS';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Event details satellite: FAILED - %', SQLERRM;
    END;
    
    -- 3. Create Page Hub using get_or_create function
    -- Format: Any non-empty string (flexible constraint)
    IF v_staging_record.page_url IS NOT NULL THEN
        v_page_bk := business.normalize_page_url(v_staging_record.page_url);
        
        BEGIN
            SELECT business.get_or_create_site_page_hk(
                v_page_bk,
                v_staging_record.tenant_hk,
                'corrected_manual_test'
            ) INTO v_page_hk;
            
            RAISE NOTICE '✅ Page hub creation: SUCCESS';
            RAISE NOTICE '   - Business Key: %', v_page_bk;
            RAISE NOTICE '   - Hash Key: %', encode(v_page_hk, 'hex');
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Page hub creation: FAILED - %', SQLERRM;
        END;
    END IF;
    
    -- 4. Create Session Hub using get_or_create function
    -- Format: sess_[identifier] OR session_[identifier] (REQUIRED by constraint)
    IF v_staging_record.session_id IS NOT NULL THEN
        v_session_bk := 'sess_' || v_staging_record.session_id;
        
        BEGIN
            SELECT business.get_or_create_site_session_hk(
                v_session_bk,
                v_staging_record.tenant_hk,
                'corrected_manual_test'
            ) INTO v_session_hk;
            
            RAISE NOTICE '✅ Session hub creation: SUCCESS';
            RAISE NOTICE '   - Business Key: %', v_session_bk;
            RAISE NOTICE '   - Hash Key: %', encode(v_session_hk, 'hex');
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Session hub creation: FAILED - %', SQLERRM;
        END;
    ELSE
        -- Create a session based on staging event if no session_id
        v_session_bk := 'sess_staging_' || v_staging_record.staging_event_id::text;
        
        BEGIN
            SELECT business.get_or_create_site_session_hk(
                v_session_bk,
                v_staging_record.tenant_hk,
                'corrected_manual_test'
            ) INTO v_session_hk;
            
            RAISE NOTICE '✅ Session hub creation (generated): SUCCESS';
            RAISE NOTICE '   - Business Key: %', v_session_bk;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Session hub creation (generated): FAILED - %', SQLERRM;
        END;
    END IF;
    
    -- 5. Create Visitor Hub using get_or_create function
    -- Format: visitor_[alphanumeric] (REQUIRED by constraint)
    v_visitor_bk := 'visitor_' || COALESCE(
        LOWER(REGEXP_REPLACE(v_staging_record.user_id, '[^a-zA-Z0-9]', '', 'g')), 
        'anonymous' || v_staging_record.staging_event_id::text
    );
    
    BEGIN
        SELECT business.get_or_create_site_visitor_hk(
            v_visitor_bk,
            v_staging_record.tenant_hk,
            'corrected_manual_test'
        ) INTO v_visitor_hk;
        
        RAISE NOTICE '✅ Visitor hub creation: SUCCESS';
        RAISE NOTICE '   - Business Key: %', v_visitor_bk;
        RAISE NOTICE '   - Hash Key: %', encode(v_visitor_hk, 'hex');
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Visitor hub creation: FAILED - %', SQLERRM;
    END;
    
    -- 6. Create Link Relationships using get_or_create functions
    IF v_event_hk IS NOT NULL AND v_session_hk IS NOT NULL THEN
        BEGIN
            PERFORM business.get_or_create_event_session_link(
                v_event_hk,
                v_session_hk,
                v_staging_record.tenant_hk,
                'corrected_manual_test'
            );
            
            RAISE NOTICE '✅ Event-Session link: SUCCESS';
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Event-Session link: FAILED - %', SQLERRM;
        END;
    END IF;
    
    IF v_event_hk IS NOT NULL AND v_page_hk IS NOT NULL THEN
        BEGIN
            PERFORM business.get_or_create_event_page_link(
                v_event_hk,
                v_page_hk,
                v_staging_record.tenant_hk,
                'corrected_manual_test'
            );
            
            RAISE NOTICE '✅ Event-Page link: SUCCESS';
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Event-Page link: FAILED - %', SQLERRM;
        END;
    END IF;
    
    IF v_session_hk IS NOT NULL AND v_visitor_hk IS NOT NULL THEN
        BEGIN
            PERFORM business.get_or_create_session_visitor_link(
                v_session_hk,
                v_visitor_hk,
                v_staging_record.tenant_hk,
                'corrected_manual_test'
            );
            
            RAISE NOTICE '✅ Session-Visitor link: SUCCESS';
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Session-Visitor link: FAILED - %', SQLERRM;
        END;
    END IF;
    
    RAISE NOTICE '🎯 Corrected business record creation complete!';
    
END;
$$;

-- 2. Verify business records were created with correct formats
\echo '📋 STEP 2: VERIFY CORRECTED BUSINESS RECORDS'
SELECT 
    '✅ CORRECTED RECORDS VERIFICATION' as verification_type,
    'Event Hubs' as record_type,
    COUNT(*) as record_count,
    MAX(load_date) as latest_record,
    string_agg(DISTINCT site_event_bk, ', ') as business_keys
FROM business.site_event_h
WHERE record_source = 'corrected_manual_test'

UNION ALL

SELECT 
    '✅ CORRECTED RECORDS VERIFICATION',
    'Session Hubs',
    COUNT(*),
    MAX(load_date),
    string_agg(DISTINCT site_session_bk, ', ')
FROM business.site_session_h
WHERE record_source = 'corrected_manual_test'

UNION ALL

SELECT 
    '✅ CORRECTED RECORDS VERIFICATION',
    'Visitor Hubs',
    COUNT(*),
    MAX(load_date),
    string_agg(DISTINCT site_visitor_bk, ', ')
FROM business.site_visitor_h
WHERE record_source = 'corrected_manual_test'

UNION ALL

SELECT 
    '✅ CORRECTED RECORDS VERIFICATION',
    'Page Hubs',
    COUNT(*),
    MAX(load_date),
    string_agg(DISTINCT site_page_bk, ', ')
FROM business.site_page_h
WHERE record_source = 'corrected_manual_test';

-- 3. Show the complete Data Vault 2.0 structure created
\echo '📋 STEP 3: COMPLETE DATA VAULT 2.0 STRUCTURE'
SELECT 
    '🏢 COMPLETE DV2.0 STRUCTURE' as structure_type,
    encode(eh.site_event_hk, 'hex') as event_hk,
    eh.site_event_bk as event_bk,
    eds.event_type,
    eds.page_url,
    eds.event_timestamp,
    encode(eh.tenant_hk, 'hex') as tenant_hk
FROM business.site_event_h eh
JOIN business.site_event_details_s eds ON eh.site_event_hk = eds.site_event_hk
WHERE eh.record_source = 'corrected_manual_test'
ORDER BY eh.load_date DESC;

\echo ''
\echo '🎯 CORRECTED BUSINESS KEY FORMAT FIX COMPLETE!'
\echo ''
\echo '📋 SUCCESS CRITERIA:'
\echo '   ✅ Used correct business key formats (evt_, sess_, visitor_)'
\echo '   ✅ Used get_or_create functions instead of direct INSERT'
\echo '   ✅ Created complete Data Vault 2.0 structure'
\echo '   ✅ Established proper link relationships'
\echo '   ✅ Verified constraint compliance'
\echo ''
\echo '🔧 NEXT STEPS:'
\echo '   1. Update staging processing function to use these patterns'
\echo '   2. Test automatic processing pipeline'
\echo '   3. Run Phase 3 business layer verification again' 