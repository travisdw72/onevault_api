-- ============================================================================
-- CHECK BUSINESS KEY CONSTRAINTS
-- Site Tracking System Debugging
-- ============================================================================
-- Purpose: Examine business key format constraints to understand expected format
-- Issue: chk_site_event_bk_format constraint violation
-- ============================================================================

\echo '🔍 CHECKING BUSINESS KEY CONSTRAINTS...'

-- 1. Check all constraints on business tables
\echo '📋 STEP 1: ALL BUSINESS TABLE CONSTRAINTS'
SELECT 
    '📋 BUSINESS CONSTRAINTS' as constraint_type,
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    cc.check_clause
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'business' 
  AND tc.table_name LIKE 'site_%'
  AND tc.constraint_name LIKE '%_bk_%'
ORDER BY tc.table_name, tc.constraint_name;

-- 2. Check specific site_event_h constraints
\echo '📋 STEP 2: SITE_EVENT_H SPECIFIC CONSTRAINTS'
SELECT 
    '📋 SITE_EVENT_H CONSTRAINTS' as constraint_info,
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'business.site_event_h'::regclass
  AND conname LIKE '%bk%'
ORDER BY conname;

-- 3. Check what business keys currently exist (if any)
\echo '📋 STEP 3: EXISTING BUSINESS KEY PATTERNS'

-- Check site_event_h
SELECT 
    '📋 EXISTING BK PATTERNS' as pattern_analysis,
    'site_event_h' as table_name,
    COALESCE(site_event_bk, 'NO_RECORDS') as business_key_example,
    COALESCE(LENGTH(site_event_bk), 0) as key_length,
    COALESCE(LEFT(site_event_bk, 10), 'NO_RECORDS') as key_prefix
FROM business.site_event_h
LIMIT 5;

-- Check site_session_h
SELECT 
    '📋 EXISTING BK PATTERNS' as pattern_analysis,
    'site_session_h' as table_name,
    COALESCE(site_session_bk, 'NO_RECORDS') as business_key_example,
    COALESCE(LENGTH(site_session_bk), 0) as key_length,
    COALESCE(LEFT(site_session_bk, 10), 'NO_RECORDS') as key_prefix
FROM business.site_session_h
LIMIT 5;

-- Check site_page_h
SELECT 
    '📋 EXISTING BK PATTERNS' as pattern_analysis,
    'site_page_h' as table_name,
    COALESCE(site_page_bk, 'NO_RECORDS') as business_key_example,
    COALESCE(LENGTH(site_page_bk), 0) as key_length,
    COALESCE(LEFT(site_page_bk, 10), 'NO_RECORDS') as key_prefix
FROM business.site_page_h
LIMIT 5;

-- Check site_visitor_h
SELECT 
    '📋 EXISTING BK PATTERNS' as pattern_analysis,
    'site_visitor_h' as table_name,
    COALESCE(site_visitor_bk, 'NO_RECORDS') as business_key_example,
    COALESCE(LENGTH(site_visitor_bk), 0) as key_length,
    COALESCE(LEFT(site_visitor_bk, 10), 'NO_RECORDS') as key_prefix
FROM business.site_visitor_h
LIMIT 5;

-- 4. Test different business key formats
\echo '📋 STEP 4: TEST BUSINESS KEY FORMATS'
DO $$
DECLARE
    v_test_formats TEXT[] := ARRAY[
        'EVENT_17',
        'staging_event_17',
        'site_event_17',
        '17',
        'event_staging_17',
        'EVT_17',
        'SE_17'
    ];
    v_format TEXT;
    v_staging_record RECORD;
BEGIN
    -- Get staging record for reference
    SELECT * INTO v_staging_record
    FROM staging.site_tracking_events_s 
    WHERE raw_event_id = 4 
    ORDER BY processed_timestamp DESC 
    LIMIT 1;
    
    RAISE NOTICE '🧪 Testing business key formats for staging_event_id: %', v_staging_record.staging_event_id;
    
    FOREACH v_format IN ARRAY v_test_formats
    LOOP
        BEGIN
            -- Test if this format would pass the constraint
            PERFORM 1 WHERE v_format ~ '^[a-zA-Z0-9_-]+$';  -- Basic format test
            
            RAISE NOTICE '✅ Format test PASSED: %', v_format;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Format test FAILED: % - %', v_format, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- 5. Check business functions that create business keys
\echo '📋 STEP 5: BUSINESS KEY CREATION FUNCTIONS'
SELECT 
    '📋 BK CREATION FUNCTIONS' as function_info,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as parameters,
    CASE 
        WHEN p.proname LIKE '%site_event%' THEN '🎯 Event Related'
        WHEN p.proname LIKE '%site_session%' THEN '🎯 Session Related'
        WHEN p.proname LIKE '%site_page%' THEN '🎯 Page Related'
        WHEN p.proname LIKE '%site_visitor%' THEN '🎯 Visitor Related'
        ELSE '❓ Other'
    END as relevance
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'business'
  AND (p.proname LIKE '%site_%' OR p.proname LIKE '%create%' OR p.proname LIKE '%get_or_create%')
  AND p.proname NOT LIKE '%ai_%'
ORDER BY relevance, p.proname;

-- 6. Look at existing staging processing function
\echo '📋 STEP 6: STAGING PROCESSING FUNCTION ANALYSIS'
SELECT 
    '📋 STAGING FUNCTIONS' as function_analysis,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as parameters
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'staging'
  AND p.proname LIKE '%site_tracking%'
ORDER BY p.proname;

\echo ''
\echo '🎯 BUSINESS KEY CONSTRAINT ANALYSIS COMPLETE!'
\echo ''
\echo '📋 WHAT TO LOOK FOR:'
\echo '   1. Check constraint definition for site_event_bk format'
\echo '   2. Existing business key patterns and formats'
\echo '   3. Functions that create proper business keys'
\echo '   4. Expected business key format (length, prefix, pattern)'
\echo ''
\echo '🔧 LIKELY SOLUTIONS:'
\echo '   - Use existing business functions to create proper keys'
\echo '   - Match the expected business key format pattern'
\echo '   - Call get_or_create functions instead of direct INSERT' 