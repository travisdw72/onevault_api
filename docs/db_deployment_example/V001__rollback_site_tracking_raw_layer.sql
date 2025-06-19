-- =====================================================
-- V001__rollback_site_tracking_raw_layer.sql
-- Production Rollback: Site Tracking Raw Layer
-- =====================================================
-- ROLLBACK PRINCIPLES:
-- 1. SAFE: Checks for dependencies before dropping
-- 2. LOGGED: Records rollback actions for audit
-- 3. GRACEFUL: Handles missing objects without errors
-- 4. DATA PRESERVATION: Options to preserve data
-- =====================================================

-- Rollback metadata
INSERT INTO migrations.rollback_log (
    version, 
    script_name, 
    description,
    rolled_back_by,
    rolled_back_at,
    reason
) VALUES (
    '001',
    'V001__rollback_site_tracking_raw_layer.sql',
    'Rollback raw layer for universal site tracking system',
    current_user,
    CURRENT_TIMESTAMP,
    'Manual rollback requested'
) ON CONFLICT (version) DO UPDATE SET
    rolled_back_by = current_user,
    rolled_back_at = CURRENT_TIMESTAMP,
    rollback_count = COALESCE(rollback_count, 0) + 1;

-- =====================================================
-- PRE-ROLLBACK VALIDATION
-- =====================================================

DO $$
DECLARE
    v_dependent_tables INTEGER;
    v_active_events INTEGER;
    v_continue_rollback BOOLEAN := true;
BEGIN
    -- Check for dependent objects
    SELECT COUNT(*) INTO v_dependent_tables
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
    WHERE ccu.table_schema = 'raw' 
    AND ccu.table_name = 'site_tracking_events_r'
    AND tc.constraint_type = 'FOREIGN KEY';
    
    -- Check for data that might be lost
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'site_tracking_events_r') THEN
        SELECT COUNT(*) INTO v_active_events 
        FROM raw.site_tracking_events_r 
        WHERE processing_status = 'PROCESSING';
    ELSE
        v_active_events := 0;
    END IF;
    
    -- Warnings for potentially destructive actions
    IF v_dependent_tables > 0 THEN
        RAISE WARNING 'Found % dependent objects. Rollback may fail due to dependencies.', v_dependent_tables;
    END IF;
    
    IF v_active_events > 0 THEN
        RAISE WARNING 'Found % events currently processing. Consider waiting for completion.', v_active_events;
    END IF;
    
    RAISE NOTICE 'Pre-rollback validation completed';
    RAISE NOTICE '  Dependent tables: %', v_dependent_tables;
    RAISE NOTICE '  Active events: %', v_active_events;
END $$;

-- =====================================================
-- DATA BACKUP (OPTIONAL)
-- =====================================================

-- Create backup table for data preservation (optional)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'site_tracking_events_r') THEN
        -- Create backup schema if needed
        CREATE SCHEMA IF NOT EXISTS backup;
        
        -- Create timestamped backup table
        EXECUTE format('CREATE TABLE backup.site_tracking_events_r_backup_%s AS SELECT * FROM raw.site_tracking_events_r', 
                      to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'));
        
        RAISE NOTICE '✅ Data backed up to backup.site_tracking_events_r_backup_%', 
                     to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    END IF;
END $$;

-- =====================================================
-- FUNCTION REMOVAL (SAFE)
-- =====================================================

-- Drop functions if they exist
DO $$
BEGIN
    -- Drop the ingestion function
    IF EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'raw' 
        AND routine_name = 'ingest_tracking_event'
    ) THEN
        DROP FUNCTION raw.ingest_tracking_event(BYTEA, BYTEA, INET, TEXT, JSONB);
        RAISE NOTICE '✅ Dropped function raw.ingest_tracking_event';
    ELSE
        RAISE NOTICE '⚠️  Function raw.ingest_tracking_event not found';
    END IF;
END $$;

-- =====================================================
-- PERMISSION REVOCATION (SAFE)
-- =====================================================

-- Revoke permissions (safe even if role doesn't exist)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tracking_processor_role') THEN
        -- Revoke table permissions
        REVOKE ALL ON raw.site_tracking_events_r FROM tracking_processor_role;
        
        -- Revoke sequence permissions  
        IF EXISTS (
            SELECT 1 FROM information_schema.sequences 
            WHERE sequence_schema = 'raw' 
            AND sequence_name = 'site_tracking_events_r_raw_event_id_seq'
        ) THEN
            REVOKE ALL ON SEQUENCE raw.site_tracking_events_r_raw_event_id_seq FROM tracking_processor_role;
        END IF;
        
        -- Revoke schema permissions
        REVOKE CREATE ON SCHEMA raw FROM tracking_processor_role;
        
        RAISE NOTICE '✅ Revoked permissions from tracking_processor_role';
    ELSE
        RAISE NOTICE '⚠️  tracking_processor_role not found - skipping permission revocation';
    END IF;
END $$;

-- =====================================================
-- TABLE REMOVAL (WITH DEPENDENCY CHECK)
-- =====================================================

-- Drop table if it exists (with CASCADE option for emergency)
DO $$
DECLARE
    v_has_dependencies BOOLEAN := false;
BEGIN
    -- Check for foreign key dependencies
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE ccu.table_schema = 'raw' 
        AND ccu.table_name = 'site_tracking_events_r'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema != 'raw'  -- External dependencies
    ) THEN
        v_has_dependencies := true;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'site_tracking_events_r') THEN
        IF v_has_dependencies THEN
            RAISE WARNING 'Table has external dependencies. Use CASCADE option manually if needed.';
            RAISE NOTICE 'Manual command: DROP TABLE raw.site_tracking_events_r CASCADE;';
        ELSE
            DROP TABLE raw.site_tracking_events_r;
            RAISE NOTICE '✅ Dropped table raw.site_tracking_events_r';
        END IF;
    ELSE
        RAISE NOTICE '⚠️  Table raw.site_tracking_events_r not found';
    END IF;
END $$;

-- =====================================================
-- SCHEMA CLEANUP (CONDITIONAL)
-- =====================================================

-- Drop schema only if empty
DO $$
DECLARE
    v_object_count INTEGER;
BEGIN
    -- Count remaining objects in raw schema
    SELECT COUNT(*) INTO v_object_count
    FROM (
        SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw'
        UNION ALL
        SELECT 1 FROM information_schema.routines WHERE routine_schema = 'raw'
        UNION ALL
        SELECT 1 FROM information_schema.views WHERE table_schema = 'raw'
    ) objects;
    
    IF v_object_count = 0 THEN
        DROP SCHEMA raw;
        RAISE NOTICE '✅ Dropped empty schema raw';
    ELSE
        RAISE NOTICE '⚠️  Schema raw contains % objects - keeping schema', v_object_count;
    END IF;
END $$;

-- =====================================================
-- MIGRATION LOG CLEANUP
-- =====================================================

-- Update migration status to rolled back
UPDATE migrations.migration_log 
SET 
    status = 'ROLLED_BACK',
    rolled_back_at = CURRENT_TIMESTAMP,
    notes = COALESCE(notes, '') || ' | Rolled back successfully'
WHERE version = '001';

-- =====================================================
-- ROLLBACK VALIDATION
-- =====================================================

DO $$
DECLARE
    v_remaining_tables INTEGER;
    v_remaining_functions INTEGER;
    v_schema_exists BOOLEAN;
BEGIN
    -- Count remaining objects
    SELECT COUNT(*) INTO v_remaining_tables 
    FROM information_schema.tables 
    WHERE table_schema = 'raw' AND table_name = 'site_tracking_events_r';
    
    SELECT COUNT(*) INTO v_remaining_functions 
    FROM information_schema.routines 
    WHERE routine_schema = 'raw' AND routine_name = 'ingest_tracking_event';
    
    SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'raw') 
    INTO v_schema_exists;
    
    RAISE NOTICE '🔄 ROLLBACK V001 COMPLETED!';
    RAISE NOTICE '   Tables remaining: %', v_remaining_tables;
    RAISE NOTICE '   Functions remaining: %', v_remaining_functions;
    RAISE NOTICE '   Schema exists: %', v_schema_exists;
    
    IF v_remaining_tables = 0 AND v_remaining_functions = 0 THEN
        RAISE NOTICE '✅ Rollback successful - all objects removed';
    ELSE
        RAISE WARNING '⚠️  Some objects may remain due to dependencies';
    END IF;
END $$;

-- Update rollback completion
UPDATE migrations.rollback_log 
SET 
    completed_at = CURRENT_TIMESTAMP,
    status = 'SUCCESS',
    notes = 'Raw layer rollback completed successfully'
WHERE version = '001';

-- Final rollback message
SELECT 'V001 Rollback: Site Tracking Raw Layer' as rollback_name,
       'SUCCESS' as status,
       'Database restored to pre-migration state' as result; 