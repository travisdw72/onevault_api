-- ============================================================================
-- DIAGNOSE BUSINESS LAYER PROCESSING ISSUE
-- Site Tracking System Debugging
-- ============================================================================
-- Purpose: Identify why staging data is not being processed into business layer
-- Issue: All business hub counts are 0 despite successful staging processing
-- ============================================================================

\echo '🔍 DIAGNOSING BUSINESS LAYER PROCESSING ISSUE...'

-- 1. Check if business schema exists
\echo '📋 STEP 1: BUSINESS SCHEMA VERIFICATION'
SELECT 
    '📋 BUSINESS SCHEMA CHECK' as check_type,
    schema_name,
    CASE 
        WHEN schema_name = 'business' THEN '✅ Business schema exists'
        ELSE '❌ Business schema missing'
    END as status
FROM information_schema.schemata 
WHERE schema_name = 'business';

-- 2. Check if business tables exist
\echo '📋 STEP 2: BUSINESS TABLES VERIFICATION'
SELECT 
    '📋 BUSINESS TABLES CHECK' as check_type,
    table_name,
    CASE 
        WHEN table_name LIKE '%_h' THEN 'Hub Table'
        WHEN table_name LIKE '%_l' THEN 'Link Table'
        WHEN table_name LIKE '%_s' THEN 'Satellite Table'
        ELSE 'Other Table'
    END as table_type
FROM information_schema.tables 
WHERE table_schema = 'business' 
AND table_name LIKE 'site_%'
ORDER BY table_type, table_name;

-- 3. Check for staging triggers
\echo '📋 STEP 3: STAGING TRIGGERS VERIFICATION'
SELECT 
    '📋 STAGING TRIGGERS CHECK' as check_type,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_schema = 'staging' 
AND event_object_table = 'site_tracking_events_s';

-- 4. Check for business processing functions
\echo '📋 STEP 4: BUSINESS PROCESSING FUNCTIONS CHECK'
SELECT 
    '📋 BUSINESS FUNCTIONS CHECK' as check_type,
    p.proname as function_name,
    n.nspname as schema_name,
    pg_get_function_identity_arguments(p.oid) as parameters
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'business'
   OR p.proname LIKE '%business%'
   OR p.proname LIKE '%site_tracking%'
ORDER BY n.nspname, p.proname;

-- 5. Check if staging data exists but business data doesn't
\echo '📋 STEP 5: DATA FLOW VERIFICATION'
SELECT 
    '📋 DATA FLOW CHECK' as check_type,
    'Staging Events' as layer,
    COUNT(*) as record_count,
    MAX(processed_timestamp) as latest_record
FROM staging.site_tracking_events_s
WHERE processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'

UNION ALL

SELECT 
    '📋 DATA FLOW CHECK',
    'Business Events',
    COUNT(*),
    MAX(load_date)
FROM business.site_event_h
WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- 6. Check for any business processing errors
\echo '📋 STEP 6: BUSINESS PROCESSING ERRORS CHECK'
SELECT 
    '📋 BUSINESS ERRORS CHECK' as check_type,
    'Check PostgreSQL logs for business processing errors' as instruction,
    'Look for: INSERT, UPDATE, or function call errors' as what_to_look_for;

-- 7. Manual business record creation test
\echo '📋 STEP 7: MANUAL BUSINESS RECORD CREATION TEST'
DO $$
DECLARE
    v_staging_record RECORD;
    v_event_hk BYTEA;
    v_event_bk VARCHAR(255);
    v_session_hk BYTEA;
    v_session_bk VARCHAR(255);
BEGIN
    -- Get a staging record to test with
    SELECT * INTO v_staging_record
    FROM staging.site_tracking_events_s 
    WHERE raw_event_id = 4 
    ORDER BY processed_timestamp DESC 
    LIMIT 1;
    
    IF v_staging_record.staging_event_id IS NULL THEN
        RAISE NOTICE '❌ No staging record found for raw_event_id = 4';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Testing with staging_event_id: %', v_staging_record.staging_event_id;
    
    -- Test event hub creation
    v_event_bk := v_staging_record.staging_event_id::text;
    v_event_hk := util.hash_binary(v_event_bk);
    
    BEGIN
        INSERT INTO business.site_event_h (
            event_hk,
            event_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_event_hk,
            v_event_bk,
            v_staging_record.tenant_hk,
            util.current_load_date(),
            'manual_test'
        );
        
        RAISE NOTICE '✅ Event hub creation test: SUCCESS';
        
        -- Clean up test record
        DELETE FROM business.site_event_h WHERE event_hk = v_event_hk AND record_source = 'manual_test';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Event hub creation test: FAILED - %', SQLERRM;
    END;
    
    -- Test session hub creation (if session_id exists)
    IF v_staging_record.session_id IS NOT NULL THEN
        v_session_bk := v_staging_record.session_id;
        v_session_hk := util.hash_binary(v_session_bk);
        
        BEGIN
            INSERT INTO business.site_session_h (
                session_hk,
                session_bk,
                tenant_hk,
                load_date,
                record_source
            ) VALUES (
                v_session_hk,
                v_session_bk,
                v_staging_record.tenant_hk,
                util.current_load_date(),
                'manual_test'
            );
            
            RAISE NOTICE '✅ Session hub creation test: SUCCESS';
            
            -- Clean up test record
            DELETE FROM business.site_session_h WHERE session_hk = v_session_hk AND record_source = 'manual_test';
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Session hub creation test: FAILED - %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE '⚠️ Session hub test skipped: No session_id in staging record';
    END IF;
    
END;
$$;

-- 8. Check for missing business layer deployment
\echo '📋 STEP 8: BUSINESS LAYER DEPLOYMENT CHECK'
SELECT 
    '📋 DEPLOYMENT CHECK' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN '❌ No business tables found - Business layer not deployed'
        WHEN COUNT(*) < 10 THEN '⚠️ Partial business layer deployment'
        ELSE '✅ Business layer appears deployed'
    END as deployment_status,
    COUNT(*) as business_table_count
FROM information_schema.tables 
WHERE table_schema = 'business';

\echo ''
\echo '🎯 DIAGNOSIS COMPLETE!'
\echo ''
\echo '📋 WHAT TO CHECK:'
\echo '   1. Business schema exists'
\echo '   2. Business tables exist (hubs, links, satellites)'
\echo '   3. Staging triggers exist to process data'
\echo '   4. Business processing functions exist'
\echo '   5. Manual record creation works'
\echo ''
\echo '🔧 LIKELY SOLUTIONS:'
\echo '   - Deploy business layer tables if missing'
\echo '   - Create staging triggers for automatic processing'
\echo '   - Deploy business processing functions'
\echo '   - Run manual business processing script' 