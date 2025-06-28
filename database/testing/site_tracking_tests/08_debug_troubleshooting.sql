-- ============================================================================
-- DEBUG & TROUBLESHOOTING GUIDE
-- Site Tracking System Testing
-- ============================================================================
-- Purpose: Comprehensive debugging queries for common issues and fixes
-- Issues Addressed: Field mapping, tenant isolation, processing failures
-- ============================================================================

-- DEBUG 1: Tenant Isolation Issues
SELECT 
    '🔍 DEBUG 1: TENANT ISOLATION INVESTIGATION' as debug_section,
    'tenant_mismatch_analysis' as issue_type,
    th.tenant_bk as tenant_business_key,
    encode(th.tenant_hk, 'hex') as tenant_hk_hex,
    COUNT(r.raw_event_id) as raw_events_count,
    COUNT(s.staging_event_id) as staging_events_count,
    CASE 
        WHEN th.tenant_bk LIKE '%one_spa%' THEN '✅ Correct Tenant'
        WHEN th.tenant_bk LIKE '%Test Company%' THEN '⚠️ Test Tenant'
        ELSE '❓ Unknown Tenant'
    END as tenant_status
FROM auth.tenant_h th
LEFT JOIN raw.site_tracking_events_r r ON th.tenant_hk = r.tenant_hk
LEFT JOIN staging.site_tracking_events_s s ON r.raw_event_id = s.raw_event_id
GROUP BY th.tenant_hk, th.tenant_bk
ORDER BY raw_events_count DESC;

-- DEBUG 2: Field Mapping Issues
SELECT 
    '🔍 DEBUG 2: FIELD MAPPING INVESTIGATION' as debug_section,
    'field_mapping_analysis' as issue_type,
    r.raw_event_id,
    'Raw Event Fields:' as field_analysis,
    jsonb_object_keys(r.raw_payload) as available_fields
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4

UNION ALL

SELECT 
    '🔍 DEBUG 2: FIELD MAPPING INVESTIGATION',
    'field_mapping_analysis',
    r.raw_event_id,
    'Event Type Mapping:',
    COALESCE(
        'raw: ' || COALESCE(r.raw_payload->>'event_type', 'NULL') || 
        ' | evt_type: ' || COALESCE(r.raw_payload->>'evt_type', 'NULL'),
        'No event type fields'
    )
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4

UNION ALL

SELECT 
    '🔍 DEBUG 2: FIELD MAPPING INVESTIGATION',
    'field_mapping_analysis',
    r.raw_event_id,
    'Session ID Mapping:',
    COALESCE(r.raw_payload->>'session_id', 'NULL')
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4

UNION ALL

SELECT 
    '🔍 DEBUG 2: FIELD MAPPING INVESTIGATION',
    'field_mapping_analysis',
    r.raw_event_id,
    'Timestamp Mapping:',
    COALESCE(r.raw_payload->>'timestamp', r.received_timestamp::text)
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4;

-- DEBUG 3: Staging Function Analysis
SELECT 
    '🔍 DEBUG 3: STAGING FUNCTION ANALYSIS' as debug_section,
    'function_exists' as check_type,
    p.proname as function_name,
    n.nspname as schema_name,
    pg_get_function_identity_arguments(p.oid) as parameters,
    p.prosrc as function_body_sample
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'validate_and_enrich_event'
  AND n.nspname = 'staging';

-- DEBUG 4: Table Structure Comparison
SELECT 
    '🔍 DEBUG 4: TABLE STRUCTURE COMPARISON' as debug_section,
    'staging_table_structure' as structure_type,
    column_name,
    data_type,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'staging'
  AND table_name = 'site_tracking_events_s'
ORDER BY ordinal_position;

-- DEBUG 5: Processing Error Analysis
SELECT 
    '🔍 DEBUG 5: PROCESSING ERROR ANALYSIS' as debug_section,
    'error_pattern_analysis' as error_type,
    processing_status,
    error_message,
    COUNT(*) as error_count,
    array_agg(DISTINCT raw_event_id ORDER BY raw_event_id) as affected_events,
    MIN(received_timestamp) as first_error,
    MAX(received_timestamp) as last_error
FROM raw.site_tracking_events_r
WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND (processing_status = 'ERROR' OR error_message IS NOT NULL)
GROUP BY processing_status, error_message
ORDER BY error_count DESC;

-- DEBUG 6: Manual Staging Test Query
SELECT 
    '🔍 DEBUG 6: MANUAL STAGING TEST' as debug_section,
    'manual_field_extraction' as test_type,
    r.raw_event_id,
    r.raw_payload->>'event_type' as extracted_event_type,
    r.raw_payload->>'page_url' as extracted_page_url,
    r.raw_payload->>'session_id' as extracted_session_id,
    r.raw_payload->'event_data'->>'action' as extracted_action,
    r.received_timestamp as extracted_timestamp,
    CASE 
        WHEN r.raw_payload->>'event_type' IS NOT NULL THEN '✅ Event Type OK'
        WHEN r.raw_payload->>'evt_type' IS NOT NULL THEN '⚠️ Use evt_type'
        ELSE '❌ No Event Type'
    END as event_type_status
FROM raw.site_tracking_events_r r
WHERE r.raw_event_id = 4;

-- DEBUG 7: Business Layer Processing Check
SELECT 
    '🔍 DEBUG 7: BUSINESS LAYER PROCESSING' as debug_section,
    'business_processing_status' as check_type,
    s.staging_event_id,
    s.event_type as staging_event_type,
    s.session_id as staging_session_id,
    CASE 
        WHEN EXISTS(SELECT 1 FROM business.site_event_h eh WHERE eh.event_bk = s.staging_event_id::text) 
        THEN '✅ Event Hub Created'
        ELSE '❌ No Event Hub'
    END as event_hub_status,
    CASE 
        WHEN EXISTS(SELECT 1 FROM business.site_session_h sh WHERE sh.session_bk = s.session_id) 
        THEN '✅ Session Hub Created'
        ELSE '❌ No Session Hub'
    END as session_hub_status
FROM staging.site_tracking_events_s s
WHERE s.raw_event_id = 4;

-- DEBUG 8: Data Vault Function Testing
SELECT 
    '🔍 DEBUG 8: DATA VAULT FUNCTION TESTING' as debug_section,
    'utility_function_test' as test_type,
    'hash_binary_test' as function_name,
    encode(util.hash_binary('test_value'), 'hex') as hash_result,
    length(util.hash_binary('test_value')) as hash_length;

-- DEBUG 9: Constraint Violations Check
SELECT 
    '🔍 DEBUG 9: CONSTRAINT VIOLATIONS' as debug_section,
    'constraint_check' as violation_type,
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid IN (
    SELECT oid FROM pg_class 
    WHERE relname IN ('site_tracking_events_s', 'site_tracking_events_r')
);

-- DEBUG 10: Processing Pipeline Status Summary
SELECT 
    '🔍 DEBUG 10: PIPELINE STATUS SUMMARY' as debug_section,
    'pipeline_health_check' as status_type,
    layer,
    status,
    record_count,
    issues
FROM (
    SELECT 
        'Raw Layer' as layer,
        CASE 
            WHEN COUNT(*) FILTER (WHERE processing_status = 'PENDING') > 0 THEN 'PENDING'
            WHEN COUNT(*) FILTER (WHERE processing_status = 'ERROR') > 0 THEN 'ERRORS'
            ELSE 'HEALTHY'
        END as status,
        COUNT(*) as record_count,
        array_agg(DISTINCT processing_status) as issues
    FROM raw.site_tracking_events_r
    WHERE received_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    
    UNION ALL
    
    SELECT 
        'Staging Layer',
        CASE 
            WHEN COUNT(*) FILTER (WHERE validation_status = 'INVALID') > 0 THEN 'VALIDATION_ERRORS'
            WHEN COUNT(*) = 0 THEN 'NO_DATA'
            ELSE 'HEALTHY'
        END,
        COUNT(*),
        array_agg(DISTINCT validation_status)
    FROM staging.site_tracking_events_s
    WHERE processed_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    
    UNION ALL
    
    SELECT 
        'Business Layer',
        CASE 
            WHEN COUNT(*) = 0 THEN 'NO_DATA'
            ELSE 'HEALTHY'
        END,
        COUNT(*),
        ARRAY['active']
    FROM business.site_event_h
    WHERE load_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
) pipeline_status;

-- ============================================================================
-- RECOMMENDED FIXES
-- ============================================================================
SELECT 
    '🔧 RECOMMENDED FIXES' as fix_section,
    'Fix 1: Field Mapping' as fix_type,
    'Update staging function to handle both event_type and evt_type fields' as recommendation,
    'v_event_type := COALESCE(v_event_data->>''evt_type'', v_event_data->>''event_type'');' as code_sample

UNION ALL

SELECT 
    '🔧 RECOMMENDED FIXES',
    'Fix 2: Tenant Registration',
    'Register correct one_spa tenant if missing',
    'CALL auth.register_tenant(''one_spa'', ''One Spa Business'', ''spa@example.com'');' 

UNION ALL

SELECT 
    '🔧 RECOMMENDED FIXES',
    'Fix 3: Manual Processing',
    'Use manual staging processing script for current events',
    'Run: 03_staging_manual_processing_fix.sql'

UNION ALL

SELECT 
    '🔧 RECOMMENDED FIXES',
    'Fix 4: Business Layer Trigger',
    'Ensure business layer processing triggers are active',
    'Check trigger status on staging tables'

UNION ALL

SELECT 
    '🔧 RECOMMENDED FIXES',
    'Fix 5: Index Optimization',
    'Add performance indexes if missing',
    'CREATE INDEX IF NOT EXISTS idx_raw_events_tenant_status ON raw.site_tracking_events_r(tenant_hk, processing_status);';

-- ============================================================================
-- DEBUG SUMMARY
-- ============================================================================
SELECT 
    '🎯 DEBUG & TROUBLESHOOTING COMPLETE' as summary,
    'Issues identified and fixes recommended' as status,
    '1. Field mapping issues (event_type vs evt_type)' as issue1,
    '2. Tenant isolation verification needed' as issue2,
    '3. Manual processing required for current events' as issue3,
    '4. Business layer pipeline activation' as issue4; 