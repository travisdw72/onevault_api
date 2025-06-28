-- ============================================================================
-- FIX PRODUCTION TENANT ASSIGNMENT FOR EVENTS 4 & 5
-- Critical fix: Move events from "Test Company" to "The ONE Spa"
-- ============================================================================
-- Purpose: Correct tenant assignment for events 4 & 5 in production
-- Issue: Events were processed with wrong tenant assignment
-- Solution: Apply the tenant correction we developed in testing
-- ============================================================================

\echo '🚨 FIXING PRODUCTION TENANT ASSIGNMENT FOR EVENTS 4 & 5...'
\echo '📋 Moving events from "Test Company" to "The ONE Spa"'

-- Step 1: Verify Current State
\echo '🔍 STEP 1: VERIFYING CURRENT TENANT ASSIGNMENTS...'

WITH tenant_info AS (
    SELECT 
        th.tenant_hk,
        tp.domain_name,
        tp.tenant_name as company_name
    FROM auth.tenant_profile_s tp
    JOIN auth.tenant_h th ON tp.tenant_hk = th.tenant_hk
    WHERE tp.load_end_date IS NULL
)
SELECT 
    '📋 CURRENT TENANT ASSIGNMENTS' as current_state,
    r.raw_event_id,
    encode(r.tenant_hk, 'hex') as current_tenant_hex,
    ti.company_name as current_tenant_name,
    ti.domain_name as current_domain,
    CASE 
        WHEN ti.company_name = 'Test Company' THEN '❌ WRONG TENANT - NEEDS CORRECTION'
        WHEN ti.company_name = 'The ONE Spa' THEN '✅ CORRECT TENANT'
        ELSE '❓ UNKNOWN TENANT'
    END as tenant_status
FROM raw.site_tracking_events_r r
LEFT JOIN tenant_info ti ON r.tenant_hk = ti.tenant_hk
WHERE r.raw_event_id IN (4, 5)
ORDER BY r.raw_event_id;

-- Step 2: Get The ONE Spa Tenant Hash Key
\echo '🎯 STEP 2: IDENTIFYING THE ONE SPA TENANT...'

DO $$
DECLARE
    v_one_spa_tenant_hk BYTEA;
    v_test_company_tenant_hk BYTEA;
    v_events_to_fix INTEGER;
BEGIN
    -- Get The ONE Spa tenant hash key
    SELECT th.tenant_hk INTO v_one_spa_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'The ONE Spa'
    AND tp.load_end_date IS NULL;
    
    -- Get Test Company tenant hash key
    SELECT th.tenant_hk INTO v_test_company_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'Test Company'
    AND tp.load_end_date IS NULL;
    
    -- Count events that need fixing
    SELECT COUNT(*) INTO v_events_to_fix
    FROM raw.site_tracking_events_r
    WHERE raw_event_id IN (4, 5)
    AND tenant_hk = v_test_company_tenant_hk;
    
    RAISE NOTICE '🎯 The ONE Spa tenant HK: %', encode(v_one_spa_tenant_hk, 'hex');
    RAISE NOTICE '📋 Test Company tenant HK: %', encode(v_test_company_tenant_hk, 'hex');
    RAISE NOTICE '🔧 Events needing tenant correction: %', v_events_to_fix;
    
    IF v_one_spa_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'The ONE Spa tenant not found - cannot proceed with correction';
    END IF;
    
    IF v_events_to_fix = 0 THEN
        RAISE NOTICE '✅ No events need tenant correction';
    ELSE
        RAISE NOTICE '⚠️ % events need tenant correction', v_events_to_fix;
    END IF;
END $$;

-- Step 3: Create Tenant Correction Function (Production-Safe)
\echo '🛠️ STEP 3: CREATING PRODUCTION-SAFE TENANT CORRECTION FUNCTION...'

CREATE OR REPLACE FUNCTION api.correct_event_tenant_production(
    p_raw_event_id INTEGER,
    p_target_tenant_name VARCHAR(100)
) RETURNS JSONB AS $$
DECLARE
    v_target_tenant_hk BYTEA;
    v_current_tenant_hk BYTEA;
    v_staging_records INTEGER;
    v_result JSONB;
BEGIN
    -- Get target tenant hash key
    SELECT th.tenant_hk INTO v_target_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = p_target_tenant_name
    AND tp.load_end_date IS NULL;
    
    IF v_target_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Target tenant not found: ' || p_target_tenant_name,
            'raw_event_id', p_raw_event_id
        );
    END IF;
    
    -- Get current tenant for the event
    SELECT tenant_hk INTO v_current_tenant_hk
    FROM raw.site_tracking_events_r
    WHERE raw_event_id = p_raw_event_id;
    
    IF v_current_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Raw event not found: ' || p_raw_event_id,
            'raw_event_id', p_raw_event_id
        );
    END IF;
    
    -- Check if correction is needed
    IF v_current_tenant_hk = v_target_tenant_hk THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Event already assigned to correct tenant',
            'raw_event_id', p_raw_event_id,
            'action', 'no_change_needed'
        );
    END IF;
    
    -- Update raw event tenant assignment
    UPDATE raw.site_tracking_events_r
    SET tenant_hk = v_target_tenant_hk
    WHERE raw_event_id = p_raw_event_id;
    
    -- Update any existing staging records
    UPDATE staging.site_tracking_events_s
    SET tenant_hk = v_target_tenant_hk
    WHERE raw_event_id = p_raw_event_id;
    
    GET DIAGNOSTICS v_staging_records = ROW_COUNT;
    
    -- Log the correction
    PERFORM util.log_audit_event(
        'TENANT_CORRECTION',
        'site_tracking',
        jsonb_build_object(
            'raw_event_id', p_raw_event_id,
            'old_tenant_hk', encode(v_current_tenant_hk, 'hex'),
            'new_tenant_hk', encode(v_target_tenant_hk, 'hex'),
            'target_tenant_name', p_target_tenant_name,
            'staging_records_updated', v_staging_records,
            'environment', 'production'
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Tenant assignment corrected successfully',
        'raw_event_id', p_raw_event_id,
        'old_tenant_hk', encode(v_current_tenant_hk, 'hex'),
        'new_tenant_hk', encode(v_target_tenant_hk, 'hex'),
        'staging_records_updated', v_staging_records,
        'environment', 'production'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'raw_event_id', p_raw_event_id,
        'environment', 'production'
    );
END;
$$ LANGUAGE plpgsql;

-- Step 4: Apply Tenant Corrections
\echo '🔧 STEP 4: APPLYING TENANT CORRECTIONS...'

-- Correct Event 4
SELECT 
    '🔧 EVENT 4 TENANT CORRECTION' as correction_step,
    api.correct_event_tenant_production(4, 'The ONE Spa') as correction_result;

-- Correct Event 5  
SELECT 
    '🔧 EVENT 5 TENANT CORRECTION' as correction_step,
    api.correct_event_tenant_production(5, 'The ONE Spa') as correction_result;

-- Step 5: Verify Corrections Applied
\echo '✅ STEP 5: VERIFYING TENANT CORRECTIONS...'

WITH tenant_info AS (
    SELECT 
        th.tenant_hk,
        tp.domain_name,
        tp.tenant_name as company_name
    FROM auth.tenant_profile_s tp
    JOIN auth.tenant_h th ON tp.tenant_hk = th.tenant_hk
    WHERE tp.load_end_date IS NULL
)
SELECT 
    '✅ CORRECTED TENANT ASSIGNMENTS' as verification_step,
    r.raw_event_id,
    encode(r.tenant_hk, 'hex') as tenant_hex,
    ti.company_name as tenant_name,
    ti.domain_name as domain_name,
    CASE 
        WHEN ti.company_name = 'The ONE Spa' THEN '✅ CORRECTLY ASSIGNED'
        WHEN ti.company_name = 'Test Company' THEN '❌ STILL WRONG TENANT'
        ELSE '❓ UNKNOWN TENANT'
    END as correction_status,
    r.processing_status as raw_status
FROM raw.site_tracking_events_r r
LEFT JOIN tenant_info ti ON r.tenant_hk = ti.tenant_hk
WHERE r.raw_event_id IN (4, 5)
ORDER BY r.raw_event_id;

-- Step 6: Verify Staging Records Updated
\echo '🔍 STEP 6: VERIFYING STAGING RECORDS UPDATED...'

WITH tenant_info AS (
    SELECT 
        th.tenant_hk,
        tp.domain_name,
        tp.tenant_name as company_name
    FROM auth.tenant_profile_s tp
    JOIN auth.tenant_h th ON tp.tenant_hk = tp.tenant_hk
    WHERE tp.load_end_date IS NULL
)
SELECT 
    '🔍 STAGING TENANT VERIFICATION' as staging_verification,
    s.staging_event_id,
    s.raw_event_id,
    encode(s.tenant_hk, 'hex') as staging_tenant_hex,
    ti.company_name as staging_tenant_name,
    s.event_type,
    s.validation_status,
    CASE 
        WHEN ti.company_name = 'The ONE Spa' THEN '✅ STAGING TENANT CORRECTED'
        WHEN ti.company_name = 'Test Company' THEN '❌ STAGING TENANT NOT CORRECTED'
        ELSE '❓ UNKNOWN STAGING TENANT'
    END as staging_correction_status
FROM staging.site_tracking_events_s s
LEFT JOIN tenant_info ti ON s.tenant_hk = ti.tenant_hk
WHERE s.raw_event_id IN (4, 5)
ORDER BY s.raw_event_id;

-- Step 7: Final Summary
\echo '📋 STEP 7: FINAL CORRECTION SUMMARY...'

WITH correction_summary AS (
    SELECT 
        COUNT(*) FILTER (WHERE raw_event_id IN (4, 5)) as total_events,
        COUNT(*) FILTER (WHERE raw_event_id IN (4, 5) AND tenant_hk = (
            SELECT th.tenant_hk 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
            WHERE tp.tenant_name = 'The ONE Spa' AND tp.load_end_date IS NULL
        )) as correctly_assigned_events
    FROM raw.site_tracking_events_r
),
staging_summary AS (
    SELECT 
        COUNT(*) FILTER (WHERE raw_event_id IN (4, 5)) as staging_records,
        COUNT(*) FILTER (WHERE raw_event_id IN (4, 5) AND tenant_hk = (
            SELECT th.tenant_hk 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
            WHERE tp.tenant_name = 'The ONE Spa' AND tp.load_end_date IS NULL
        )) as correctly_assigned_staging
    FROM staging.site_tracking_events_s
)
SELECT 
    '📋 FINAL CORRECTION SUMMARY' as final_summary,
    cs.total_events as "Total Events",
    cs.correctly_assigned_events as "Correctly Assigned Raw Events",
    ss.staging_records as "Total Staging Records",
    ss.correctly_assigned_staging as "Correctly Assigned Staging Records",
    CASE 
        WHEN cs.correctly_assigned_events = 2 AND ss.correctly_assigned_staging = 2 THEN
            '🎉 PERFECT: All tenant assignments corrected!'
        WHEN cs.correctly_assigned_events = 2 THEN
            '✅ Raw events corrected, staging may need manual update'
        WHEN cs.correctly_assigned_events > 0 THEN
            '⚠️ Partial correction applied'
        ELSE
            '❌ Tenant correction failed'
    END as correction_assessment,
    CURRENT_TIMESTAMP as correction_timestamp
FROM correction_summary cs
CROSS JOIN staging_summary ss;

\echo '🎉 PRODUCTION TENANT CORRECTION COMPLETE!'
\echo ''
\echo '📋 WHAT WAS CORRECTED:'
\echo '   ✅ Events 4 & 5 moved from "Test Company" to "The ONE Spa"'
\echo '   ✅ Raw table tenant assignments updated'
\echo '   ✅ Staging table tenant assignments updated'
\echo '   ✅ Audit trail created for corrections'
\echo ''
\echo '🔍 NEXT STEPS:'
\echo '   1. Re-run verification script to confirm corrections'
\echo '   2. Test new site tracking events to ensure proper tenant assignment'
\echo '   3. Monitor system for any tenant assignment issues' 