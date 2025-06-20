-- =============================================================================
-- COMPLETE ROLLBACK: Remove All Script Tracking Components
-- This will completely remove the script tracking system for a clean restart
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '🧹 STARTING COMPLETE ROLLBACK OF SCRIPT TRACKING SYSTEM...';
END $$;

-- ############################################################################
-- STEP 1: DROP EVENT TRIGGERS (Must be first to prevent interference)
-- ############################################################################

DO $$
BEGIN
    -- Drop all event triggers related to script tracking
    DROP EVENT TRIGGER IF EXISTS auto_ddl_tracker CASCADE;
    RAISE NOTICE '✅ Dropped event trigger: auto_ddl_tracker';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Event trigger removal: %', SQLERRM;
END $$;

-- ############################################################################
-- STEP 2: DROP ALL FUNCTIONS (Remove dependencies first)
-- ############################################################################

DO $$
BEGIN
    -- Drop wrapper functions
    DROP FUNCTION IF EXISTS track_operation(VARCHAR, VARCHAR) CASCADE;
    DROP FUNCTION IF EXISTS complete_operation(BYTEA, BOOLEAN, TEXT) CASCADE;
    RAISE NOTICE '✅ Dropped wrapper functions';
    
    -- Drop reporting functions
    DROP FUNCTION IF EXISTS script_tracking.get_execution_history(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, VARCHAR, VARCHAR, INTEGER) CASCADE;
    DROP FUNCTION IF EXISTS script_tracking.get_execution_statistics(INTEGER) CASCADE;
    RAISE NOTICE '✅ Dropped reporting functions';
    
    -- Drop convenience functions
    DROP FUNCTION IF EXISTS script_tracking.track_migration(VARCHAR, VARCHAR, VARCHAR, TEXT, BYTEA) CASCADE;
    DROP FUNCTION IF EXISTS script_tracking.track_function_execution(VARCHAR, TEXT, BYTEA) CASCADE;
    DROP FUNCTION IF EXISTS script_tracking.track_maintenance(VARCHAR, VARCHAR, TEXT, TEXT) CASCADE;
    RAISE NOTICE '✅ Dropped convenience functions';
    
    -- Drop core functions
    DROP FUNCTION IF EXISTS script_tracking.complete_script_execution(BYTEA, VARCHAR, BIGINT, BIGINT, TEXT, VARCHAR, TEXT[], TEXT[], TEXT[], TEXT[]) CASCADE;
    DROP FUNCTION IF EXISTS script_tracking.track_script_execution(VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR, BYTEA, TEXT, VARCHAR) CASCADE;
    RAISE NOTICE '✅ Dropped core tracking functions';
    
    -- Drop event trigger function
    DROP FUNCTION IF EXISTS script_tracking.auto_track_ddl_operations() CASCADE;
    RAISE NOTICE '✅ Dropped event trigger function';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Function removal: %', SQLERRM;
END $$;

-- ############################################################################
-- STEP 3: DROP TABLES (Remove data and structure)
-- ############################################################################

DO $$
BEGIN
    -- Drop satellite table first (has foreign key to hub)
    DROP TABLE IF EXISTS script_tracking.script_execution_s CASCADE;
    RAISE NOTICE '✅ Dropped table: script_execution_s';
    
    -- Drop hub table
    DROP TABLE IF EXISTS script_tracking.script_execution_h CASCADE;
    RAISE NOTICE '✅ Dropped table: script_execution_h';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Table removal: %', SQLERRM;
END $$;

-- ############################################################################
-- STEP 4: DROP SCHEMA (Complete cleanup)
-- ############################################################################

DO $$
BEGIN
    -- Drop the entire schema
    DROP SCHEMA IF EXISTS script_tracking CASCADE;
    RAISE NOTICE '✅ Dropped schema: script_tracking';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Schema removal: %', SQLERRM;
END $$;

-- ############################################################################
-- STEP 5: CLEAN UP MIGRATION LOG INTEGRATION (If exists)
-- ############################################################################

DO $$
BEGIN
    -- Remove script_execution_hk column from migration_log if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns 
              WHERE table_schema = 'util' 
              AND table_name = 'migration_log' 
              AND column_name = 'script_execution_hk') THEN
        ALTER TABLE util.migration_log DROP COLUMN script_execution_hk;
        RAISE NOTICE '✅ Removed script_execution_hk from migration_log';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Migration log cleanup: %', SQLERRM;
END $$;

-- ############################################################################
-- STEP 6: VALIDATION AND COMPLETION
-- ############################################################################

DO $$
DECLARE
    v_schema_count INTEGER;
    v_table_count INTEGER;
    v_function_count INTEGER;
    v_trigger_count INTEGER;
BEGIN
    -- Validate complete removal
    SELECT COUNT(*) INTO v_schema_count
    FROM information_schema.schemata 
    WHERE schema_name = 'script_tracking';
    
    SELECT COUNT(*) INTO v_table_count
    FROM information_schema.tables 
    WHERE table_schema = 'script_tracking';
    
    SELECT COUNT(*) INTO v_function_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'script_tracking';
    
    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_event_trigger
    WHERE evtname = 'auto_ddl_tracker';
    
    -- Report results
    RAISE NOTICE '';
    RAISE NOTICE '📊 ROLLBACK COMPLETION STATUS:';
    RAISE NOTICE '   Schemas remaining: % (should be 0)', v_schema_count;
    RAISE NOTICE '   Tables remaining: % (should be 0)', v_table_count;
    RAISE NOTICE '   Functions remaining: % (should be 0)', v_function_count;
    RAISE NOTICE '   Event triggers remaining: % (should be 0)', v_trigger_count;
    
    IF v_schema_count = 0 AND v_table_count = 0 AND v_function_count = 0 AND v_trigger_count = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '🎉 COMPLETE ROLLBACK SUCCESSFUL!';
        RAISE NOTICE '   ✅ All script tracking components removed';
        RAISE NOTICE '   ✅ Database is clean and ready for fresh installation';
        RAISE NOTICE '';
        RAISE NOTICE '📝 NEXT STEPS:';
        RAISE NOTICE '   1. Run the corrected universal_script_execution_tracker.sql';
        RAISE NOTICE '   2. Run the corrected automatic_script_tracking_options.sql';
        RAISE NOTICE '   3. Test with simple DDL operations';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '⚠️ ROLLBACK INCOMPLETE - Some components remain';
        RAISE NOTICE '   Manual cleanup may be required';
    END IF;
END $$; 