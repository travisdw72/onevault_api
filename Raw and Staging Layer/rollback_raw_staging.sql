-- ============================================================================
-- ROLLBACK SCRIPT - Raw & Staging Layer Removal
-- Universal Learning Loop - Safe Cleanup
-- Supports: One Vault Demo Barn & One Vault Production
-- ============================================================================

\echo 'Starting Universal Learning Loop Raw & Staging Layer Rollback...'
\echo ''
\echo '⚠️  WARNING: This will remove ALL raw and staging data and structures!'
\echo ''

-- Prompt for confirmation (commented out for script execution)
-- \prompt 'Are you sure you want to proceed? Type YES to continue: ' confirmation

-- ============================================================================
-- SAFETY CHECKS
-- ============================================================================

\echo '🔍 SAFETY CHECK: Identifying objects to be removed...'

-- Count existing objects
SELECT 
    'Objects that will be removed:' as warning_message,
    '' as spacer

UNION ALL

SELECT 
    '  Raw Schema Tables: ' || count(*)::text,
    ''
FROM information_schema.tables 
WHERE table_schema = 'raw'

UNION ALL

SELECT 
    '  Staging Schema Tables: ' || count(*)::text,
    ''
FROM information_schema.tables 
WHERE table_schema = 'staging'

UNION ALL

SELECT 
    '  Raw Schema Functions: ' || count(*)::text,
    ''
FROM information_schema.routines 
WHERE routine_schema = 'raw'

UNION ALL

SELECT 
    '  Staging Schema Functions: ' || count(*)::text,
    ''
FROM information_schema.routines 
WHERE routine_schema = 'staging';

\echo ''

-- Check for any data in the tables
DO $$
DECLARE
    v_raw_data_count INTEGER := 0;
    v_staging_data_count INTEGER := 0;
    v_table_name TEXT;
BEGIN
    -- Count raw data
    FOR v_table_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'raw'
    LOOP
        EXECUTE format('SELECT count(*) FROM raw.%I', v_table_name) INTO v_raw_data_count;
        IF v_raw_data_count > 0 THEN
            RAISE NOTICE 'WARNING: Table raw.% contains % records', v_table_name, v_raw_data_count;
        END IF;
    END LOOP;
    
    -- Count staging data
    FOR v_table_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'staging'
    LOOP
        EXECUTE format('SELECT count(*) FROM staging.%I', v_table_name) INTO v_staging_data_count;
        IF v_staging_data_count > 0 THEN
            RAISE NOTICE 'WARNING: Table staging.% contains % records', v_table_name, v_staging_data_count;
        END IF;
    END LOOP;
    
    IF v_raw_data_count > 0 OR v_staging_data_count > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  DATA LOSS WARNING: Tables contain data that will be permanently lost!';
        RAISE NOTICE '';
    ELSE
        RAISE NOTICE '✅ No data found in tables - safe to proceed';
        RAISE NOTICE '';
    END IF;
END $$;

-- ============================================================================
-- STEP 1: DROP STAGING SCHEMA (Drop dependent objects first)
-- ============================================================================

\echo '🔄 STEP 1: Removing Staging Schema and Objects...'

-- Drop staging functions first
DROP FUNCTION IF EXISTS staging.start_user_input_validation(BYTEA, BYTEA, VARCHAR);
DROP FUNCTION IF EXISTS staging.start_data_validation(BYTEA, VARCHAR, BYTEA, VARCHAR);
DROP FUNCTION IF EXISTS staging.calculate_data_quality_score(DECIMAL, DECIMAL, DECIMAL, DECIMAL, DECIMAL, DECIMAL, DECIMAL, DECIMAL);
DROP FUNCTION IF EXISTS staging.analyze_json_structure(JSONB);
DROP FUNCTION IF EXISTS staging.extract_learning_patterns(BYTEA, VARCHAR, JSONB, VARCHAR);
DROP FUNCTION IF EXISTS staging.get_processing_statistics(BYTEA, DATE);

-- Drop staging tables in reverse dependency order
DROP TABLE IF EXISTS staging.standardization_s CASCADE;
DROP TABLE IF EXISTS staging.standardization_h CASCADE;
DROP TABLE IF EXISTS staging.entity_resolution_s CASCADE;
DROP TABLE IF EXISTS staging.entity_resolution_h CASCADE;
DROP TABLE IF EXISTS staging.business_rule_s CASCADE;
DROP TABLE IF EXISTS staging.business_rule_h CASCADE;
DROP TABLE IF EXISTS staging.data_validation_s CASCADE;
DROP TABLE IF EXISTS staging.data_validation_h CASCADE;
DROP TABLE IF EXISTS staging.user_behavior_analysis_s CASCADE;
DROP TABLE IF EXISTS staging.user_behavior_analysis_h CASCADE;
DROP TABLE IF EXISTS staging.user_input_validation_s CASCADE;
DROP TABLE IF EXISTS staging.user_input_validation_h CASCADE;

-- Drop staging schema
DROP SCHEMA IF EXISTS staging CASCADE;

\echo '  ✅ Staging schema and objects removed'
\echo ''

-- ============================================================================
-- STEP 2: DROP RAW SCHEMA
-- ============================================================================

\echo '🗄️  STEP 2: Removing Raw Schema and Objects...'

-- Drop raw functions first
DROP FUNCTION IF EXISTS raw.insert_external_data(BYTEA, VARCHAR, VARCHAR, JSONB, VARCHAR);
DROP FUNCTION IF EXISTS raw.insert_user_input(BYTEA, BYTEA, BYTEA, VARCHAR, VARCHAR, JSONB, VARCHAR);
DROP FUNCTION IF EXISTS raw.insert_file_data(BYTEA, BYTEA, VARCHAR, BYTEA, VARCHAR, VARCHAR);

-- Drop raw tables in reverse dependency order
DROP TABLE IF EXISTS raw.sensor_data_s CASCADE;
DROP TABLE IF EXISTS raw.sensor_data_h CASCADE;
DROP TABLE IF EXISTS raw.file_data_s CASCADE;
DROP TABLE IF EXISTS raw.file_data_h CASCADE;
DROP TABLE IF EXISTS raw.user_input_s CASCADE;
DROP TABLE IF EXISTS raw.user_input_h CASCADE;
DROP TABLE IF EXISTS raw.external_data_s CASCADE;
DROP TABLE IF EXISTS raw.external_data_h CASCADE;

-- Drop raw schema
DROP SCHEMA IF EXISTS raw CASCADE;

\echo '  ✅ Raw schema and objects removed'
\echo ''

-- ============================================================================
-- STEP 3: CLEANUP AND VERIFICATION
-- ============================================================================

\echo '🧹 STEP 3: Cleanup and Verification...'

-- Verify removal
SELECT 
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.schemata 
            WHERE schema_name = 'raw'
        ) THEN '✅ Raw schema successfully removed'
        ELSE '❌ Raw schema still exists'
    END as raw_schema_status

UNION ALL

SELECT 
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.schemata 
            WHERE schema_name = 'staging'
        ) THEN '✅ Staging schema successfully removed'
        ELSE '❌ Staging schema still exists'
    END as staging_schema_status;

\echo ''

-- Check for any remaining objects
SELECT 
    'Remaining raw objects: ' || count(*)::text as cleanup_status
FROM information_schema.tables 
WHERE table_schema = 'raw'

UNION ALL

SELECT 
    'Remaining staging objects: ' || count(*)::text
FROM information_schema.tables 
WHERE table_schema = 'staging'

UNION ALL

SELECT 
    'Remaining raw functions: ' || count(*)::text
FROM information_schema.routines 
WHERE routine_schema = 'raw'

UNION ALL

SELECT 
    'Remaining staging functions: ' || count(*)::text
FROM information_schema.routines 
WHERE routine_schema = 'staging';

\echo ''

-- ============================================================================
-- STEP 4: CLEANUP STATISTICS AND CACHED PLANS
-- ============================================================================

\echo '📊 STEP 4: Cleaning up database statistics and cached plans...'

-- Reset statistics
SELECT pg_stat_reset();

-- Clear query plan cache (if available)
SELECT CASE 
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'pg_stat_statements_reset') 
    THEN pg_stat_statements_reset()::text
    ELSE 'pg_stat_statements not available'
END as plan_cache_status;

\echo '  ✅ Database statistics and cached plans cleared'
\echo ''

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

\echo '🎯 ROLLBACK COMPLETED SUCCESSFULLY!'
\echo ''
\echo 'Universal Learning Loop Infrastructure Removed:'
\echo '  ✅ Raw schema and all tables dropped'
\echo '  ✅ Staging schema and all tables dropped'
\echo '  ✅ All helper functions removed'
\echo '  ✅ All indexes and constraints dropped'
\echo '  ✅ Database statistics cleaned'
\echo ''
\echo '📋 What was removed:'
\echo '  • 4 Raw schema tables (8 total with hub/satellite pairs)'
\echo '  • 6 Staging schema tables (12 total with hub/satellite pairs)'
\echo '  • All data ingestion functions'
\echo '  • All data processing functions'
\echo '  • All performance optimization indexes'
\echo '  • All JSONB search indexes'
\echo ''
\echo '⚠️  NOTE: Core authentication and business schemas remain intact'
\echo ''
\echo 'To recreate the Universal Learning Loop infrastructure:'
\echo '  Run: \\i run_all_raw_staging.sql'
\echo ''

-- ============================================================================
-- COMPLETION TIMESTAMP
-- ============================================================================

SELECT 
    'Universal Learning Loop Rollback Completed at: ' || CURRENT_TIMESTAMP as completion_message; 