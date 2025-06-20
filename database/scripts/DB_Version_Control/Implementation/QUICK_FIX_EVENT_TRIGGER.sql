-- =============================================================================
-- QUICK FIX: Replace Broken Event Trigger with Fixed Version
-- =============================================================================

-- Drop the old broken event trigger
DROP EVENT TRIGGER IF EXISTS auto_ddl_tracker;

-- Drop the old broken function
DROP FUNCTION IF EXISTS script_tracking.auto_track_ddl_operations();

-- Recreate with the FIXED version (from automatic_script_tracking_options.sql)
CREATE OR REPLACE FUNCTION script_tracking.auto_track_ddl_operations()
RETURNS event_trigger AS $$
DECLARE
    v_obj record;
    v_execution_hk BYTEA;
    v_operation_type TEXT;
    v_object_identity TEXT;
    v_command_tag TEXT;
    v_objects_created TEXT[] := ARRAY[]::TEXT[];
    v_objects_modified TEXT[] := ARRAY[]::TEXT[];
    v_objects_dropped TEXT[] := ARRAY[]::TEXT[];
    v_schemas_affected TEXT[] := ARRAY[]::TEXT[];
    v_object_count INTEGER := 0;
    v_unique_script_name TEXT;
    v_all_objects TEXT := '';
    v_unique_suffix TEXT;
BEGIN
    -- Get the command that triggered this event
    v_command_tag := tg_tag;
    
    -- Generate unique suffix to prevent duplicate business keys (FIX 2)
    v_unique_suffix := extract(epoch from clock_timestamp())::text || '_' || 
                       (random() * 1000000)::int::text;
    
    -- Collect all objects first to create a unique script name
    FOR v_obj IN SELECT * FROM pg_event_trigger_ddl_commands()
    LOOP
        v_object_identity := v_obj.object_identity;
        v_all_objects := v_all_objects || v_object_identity || ';';
        v_object_count := v_object_count + 1;
        
        -- Collect objects by operation type
        IF v_command_tag LIKE 'CREATE%' THEN
            v_objects_created := array_append(v_objects_created, v_object_identity);
        ELSIF v_command_tag LIKE 'ALTER%' THEN
            v_objects_modified := array_append(v_objects_modified, v_object_identity);
        ELSIF v_command_tag LIKE 'DROP%' THEN
            v_objects_dropped := array_append(v_objects_dropped, v_object_identity);
        END IF;
        
        -- Collect schemas affected
        v_schemas_affected := array_append(v_schemas_affected, split_part(v_object_identity, '.', 1));
    END LOOP;
    
    -- Create unique script name that includes all objects (FIX 2: Prevents duplicates)
    v_unique_script_name := 'AUTO_DDL_' || v_command_tag || '_' || 
                           SUBSTRING(MD5(v_all_objects || v_unique_suffix), 1, 8) || '_' ||
                           v_unique_suffix;
    
    -- Track the DDL operation automatically with unique name
    v_execution_hk := script_tracking.track_script_execution(
        v_unique_script_name,                    -- FIXED: Now unique per operation
        'AUTO_DDL',
        'DDL',
        v_all_objects,                           -- Include objects as script content
        NULL, -- No file path
        NULL, -- No version
        NULL, -- No tenant (system-wide)
        'Automatically tracked DDL operation via event trigger',
        NULL  -- No ticket
    );
    
    -- Complete the tracking ONCE with all object details
    IF v_object_count > 0 THEN
        PERFORM script_tracking.complete_script_execution(
            v_execution_hk,
            'COMPLETED',
            NULL, -- Duration not available
            v_object_count, -- Number of objects affected
            NULL, -- No error
            NULL, -- No error code
            v_objects_created,
            v_objects_modified,
            v_objects_dropped,
            (SELECT array_agg(DISTINCT schema_name) FROM unnest(v_schemas_affected) AS schema_name)
        );
        
        RAISE NOTICE '🤖 AUTO-TRACKED DDL: % affected % objects', v_command_tag, v_object_count;
    ELSE
        -- If no objects found, still complete the tracking
        PERFORM script_tracking.complete_script_execution(
            v_execution_hk,
            'COMPLETED',
            NULL, NULL, NULL, NULL,
            ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY[]::TEXT[]
        );
        
        RAISE NOTICE '🤖 AUTO-TRACKED DDL: % (no objects detected)', v_command_tag;
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    -- Don't let tracking failures break DDL operations
    RAISE NOTICE '⚠️ Auto-tracking failed for %: %', v_command_tag, SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Recreate the event trigger with the fixed function
CREATE EVENT TRIGGER auto_ddl_tracker
ON ddl_command_end
EXECUTE FUNCTION script_tracking.auto_track_ddl_operations();

-- Test the fix
DO $$
BEGIN
    RAISE NOTICE '✅ QUICK FIX APPLIED:';
    RAISE NOTICE '   🔧 Dropped old broken event trigger';
    RAISE NOTICE '   🔧 Replaced with fixed version';
    RAISE NOTICE '   🧪 Ready to test - no more duplicate keys!';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TEST THE FIX:';
    RAISE NOTICE '   CREATE TABLE test_tracking_fix (id SERIAL);';
    RAISE NOTICE '   DROP TABLE test_tracking_fix;';
END $$; 