-- ============================================================================
-- DIAGNOSE DUPLICATE ROWS ISSUE
-- Site Tracking System - Duplicate Row Investigation
-- ============================================================================
-- Purpose: Identify what's causing "query returned more than one row" error
-- Issue: Staging function failing with duplicate row error
-- ============================================================================

-- Step 1: Check for actual duplicate raw events
\echo '🔍 STEP 1: CHECKING FOR DUPLICATE RAW EVENTS...'

SELECT 
    '🔍 RAW EVENT DUPLICATES CHECK' as duplicate_check,
    raw_event_id,
    tenant_hk,
    encode(tenant_hk, 'hex') as tenant_hex,
    received_timestamp,
    processing_status,
    batch_id,
    COUNT(*) OVER (PARTITION BY raw_event_id) as duplicate_count,
    CASE 
        WHEN COUNT(*) OVER (PARTITION BY raw_event_id) > 1 THEN '❌ DUPLICATE RAW EVENT ID'
        ELSE '✅ Unique Event ID'
    END as uniqueness_status
FROM raw.site_tracking_events_r
WHERE raw_event_id IN (4, 5)
ORDER BY raw_event_id;

-- Step 2: Check for duplicate staging events
\echo '🔍 STEP 2: CHECKING FOR DUPLICATE STAGING EVENTS...'

SELECT 
    '🔍 STAGING EVENT DUPLICATES CHECK' as staging_check,
    staging_event_id,
    raw_event_id,
    event_type,
    processed_timestamp,
    COUNT(*) OVER (PARTITION BY raw_event_id) as staging_duplicates,
    CASE 
        WHEN COUNT(*) OVER (PARTITION BY raw_event_id) > 1 THEN '❌ DUPLICATE STAGING FOR RAW EVENT'
        ELSE '✅ Unique Staging Event'
    END as staging_uniqueness
FROM staging.site_tracking_events_s
WHERE raw_event_id IN (4, 5)
ORDER BY raw_event_id, staging_event_id;

-- Step 3: Check tenant_h table for duplicates (likely culprit)
\echo '🔍 STEP 3: CHECKING TENANT TABLE FOR DUPLICATES...'

-- Check if there are multiple tenant records with same business key
SELECT 
    '🔍 TENANT DUPLICATES CHECK' as tenant_check,
    tenant_bk,
    encode(tenant_hk, 'hex') as tenant_hex,
    load_date,
    record_source,
    COUNT(*) OVER (PARTITION BY tenant_bk) as duplicate_count,
    CASE 
        WHEN COUNT(*) OVER (PARTITION BY tenant_bk) > 1 THEN '❌ DUPLICATE TENANT BK'
        ELSE '✅ Unique Tenant BK'
    END as tenant_uniqueness
FROM auth.tenant_h
WHERE tenant_bk LIKE '%ONE Spa%' OR tenant_bk LIKE '%Test Company%'
ORDER BY tenant_bk, load_date;

-- Step 4: Identify the exact query causing the duplicate issue
\echo '🔍 STEP 4: TESTING INDIVIDUAL QUERIES FROM STAGING FUNCTION...'

-- Test the SELECT query that's likely causing the issue
DO $$
DECLARE
    v_raw_event RECORD;
    v_count INTEGER;
BEGIN
    -- Test the main SELECT query
    SELECT COUNT(*) INTO v_count
    FROM raw.site_tracking_events_r
    WHERE raw_event_id = 4;
    
    RAISE NOTICE 'Raw events with ID 4: %', v_count;
    
    -- Try the actual SELECT that's failing
    BEGIN
        SELECT * INTO v_raw_event
        FROM raw.site_tracking_events_r
        WHERE raw_event_id = 4;
        
        RAISE NOTICE '✅ Single raw event selection successful for event 4';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Raw event selection failed: %', SQLERRM;
    END;
    
    -- Check if it's a tenant lookup issue
    SELECT COUNT(*) INTO v_count
    FROM auth.tenant_h 
    WHERE tenant_hk = (SELECT tenant_hk FROM raw.site_tracking_events_r WHERE raw_event_id = 4);
    
    RAISE NOTICE 'Tenant records for event 4 tenant: %', v_count;
    
END $$;

-- Step 5: Check for any other tables that might have duplicates
\echo '🔍 STEP 5: COMPREHENSIVE DUPLICATE ANALYSIS...'

-- Check if there are any constraint violations or index issues
SELECT 
    '🔍 TABLE CONSTRAINTS CHECK' as constraint_check,
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    CASE 
        WHEN tc.constraint_type = 'PRIMARY KEY' THEN '✅ Primary Key'
        WHEN tc.constraint_type = 'UNIQUE' THEN '✅ Unique Constraint'
        ELSE '⚠️ Other: ' || tc.constraint_type
    END as constraint_status
FROM information_schema.table_constraints tc
WHERE tc.table_schema IN ('raw', 'staging', 'auth')
AND tc.table_name IN ('site_tracking_events_r', 'site_tracking_events_s', 'tenant_h')
AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
ORDER BY tc.table_name, tc.constraint_type;

-- Step 6: Create a simplified test of the failing function
\echo '🔍 STEP 6: SIMPLIFIED STAGING FUNCTION TEST...'

-- Create a minimal version to isolate the issue
CREATE OR REPLACE FUNCTION staging.test_raw_event_selection(
    p_raw_event_id INTEGER
) RETURNS TEXT AS $$
DECLARE
    v_raw_event RECORD;
    v_count INTEGER;
    v_result TEXT;
BEGIN
    -- Count matching records
    SELECT COUNT(*) INTO v_count
    FROM raw.site_tracking_events_r
    WHERE raw_event_id = p_raw_event_id;
    
    v_result := 'Found ' || v_count || ' records for event ' || p_raw_event_id;
    
    IF v_count = 0 THEN
        RETURN v_result || ' - ❌ NO RECORDS FOUND';
    ELSIF v_count > 1 THEN
        RETURN v_result || ' - ❌ MULTIPLE RECORDS FOUND';
    END IF;
    
    -- Try to select the single record
    BEGIN
        SELECT * INTO STRICT v_raw_event
        FROM raw.site_tracking_events_r
        WHERE raw_event_id = p_raw_event_id;
        
        RETURN v_result || ' - ✅ SINGLE RECORD SELECTED SUCCESSFULLY';
        
    EXCEPTION 
        WHEN NO_DATA_FOUND THEN
            RETURN v_result || ' - ❌ NO_DATA_FOUND EXCEPTION';
        WHEN TOO_MANY_ROWS THEN
            RETURN v_result || ' - ❌ TOO_MANY_ROWS EXCEPTION';
        WHEN OTHERS THEN
            RETURN v_result || ' - ❌ OTHER EXCEPTION: ' || SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- Test the simplified function
SELECT 
    '🧪 SIMPLIFIED FUNCTION TEST' as test_type,
    staging.test_raw_event_selection(4) as event_4_result,
    staging.test_raw_event_selection(5) as event_5_result;

-- Step 7: Check for any triggers or rules that might be causing issues
\echo '🔍 STEP 7: CHECKING FOR TRIGGERS AND RULES...'

SELECT 
    '🔍 TRIGGERS AND RULES CHECK' as trigger_check,
    schemaname,
    tablename,
    triggername,
    'TRIGGER' as object_type
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname IN ('raw', 'staging')
AND c.relname LIKE '%site_tracking%'

UNION ALL

SELECT 
    '🔍 TRIGGERS AND RULES CHECK' as trigger_check,
    schemaname,
    tablename,
    rulename,
    'RULE' as object_type
FROM pg_rules
WHERE schemaname IN ('raw', 'staging')
AND tablename LIKE '%site_tracking%'
ORDER BY schemaname, tablename; 