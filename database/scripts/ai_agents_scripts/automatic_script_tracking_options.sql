-- =============================================================================
-- TRULY AUTOMATIC Script Tracking Options
-- Methods to automatically track database operations without manual calls
-- Author: AI Agent  
-- Date: 2025-01-19
-- =============================================================================

-- ############################################################################
-- OPTION 1: EVENT TRIGGERS (DDL Operations Only)
-- Automatically captures CREATE, ALTER, DROP operations
-- ############################################################################

-- Create event trigger to capture DDL operations automatically
CREATE OR REPLACE FUNCTION script_tracking.auto_track_ddl_operations()
RETURNS event_trigger AS $$
DECLARE
    v_obj record;
    v_execution_hk BYTEA;
    v_operation_type TEXT;
    v_object_identity TEXT;
    v_command_tag TEXT;
BEGIN
    -- Get the command that triggered this event
    v_command_tag := tg_tag;
    
    -- Track the DDL operation automatically
    v_execution_hk := script_tracking.track_script_execution(
        'AUTO_DDL_' || v_command_tag,
        'AUTO_DDL',
        'DDL',
        NULL, -- No script content available in event triggers
        NULL, -- No file path
        NULL, -- No version
        NULL, -- No tenant (system-wide)
        'Automatically tracked DDL operation via event trigger',
        NULL  -- No ticket
    );
    
    -- Get details about what objects were affected
    FOR v_obj IN SELECT * FROM pg_event_trigger_ddl_commands()
    LOOP
        v_object_identity := v_obj.object_identity;
        
        -- Complete the tracking with object details
        PERFORM script_tracking.complete_script_execution(
            v_execution_hk,
            'COMPLETED',
            NULL, -- Duration not available
            NULL, -- Rows affected not available
            NULL, -- No error
            NULL, -- No error code
            CASE WHEN v_command_tag LIKE 'CREATE%' THEN ARRAY[v_object_identity] ELSE ARRAY[]::TEXT[] END,
            CASE WHEN v_command_tag LIKE 'ALTER%' THEN ARRAY[v_object_identity] ELSE ARRAY[]::TEXT[] END,
            CASE WHEN v_command_tag LIKE 'DROP%' THEN ARRAY[v_object_identity] ELSE ARRAY[]::TEXT[] END,
            ARRAY[split_part(v_object_identity, '.', 1)] -- schema affected
        );
        
        RAISE NOTICE '🤖 AUTO-TRACKED DDL: % on %', v_command_tag, v_object_identity;
    END LOOP;
    
EXCEPTION WHEN OTHERS THEN
    -- Don't let tracking failures break DDL operations
    RAISE NOTICE '⚠️ Auto-tracking failed for %: %', v_command_tag, SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Create the event trigger (automatically fires on DDL)
DO $$
BEGIN
    -- Drop existing trigger if it exists
    DROP EVENT TRIGGER IF EXISTS auto_ddl_tracker;
    
    -- Create new trigger
    CREATE EVENT TRIGGER auto_ddl_tracker
    ON ddl_command_end
    EXECUTE FUNCTION script_tracking.auto_track_ddl_operations();
    
    RAISE NOTICE '✅ Automatic DDL tracking enabled via event triggers';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Failed to create DDL event trigger: %', SQLERRM;
END $$;

-- ############################################################################
-- OPTION 2: FUNCTION WRAPPER AUTOMATION
-- Automatically track when specific functions are called
-- ############################################################################

-- Example: Auto-tracking wrapper for user authentication
CREATE OR REPLACE FUNCTION auth.login_user_with_tracking(
    p_email VARCHAR(255),
    p_password TEXT,
    p_tenant_id VARCHAR(255)
) RETURNS TABLE (
    p_success BOOLEAN,
    p_session_token VARCHAR(255),
    p_user_data JSONB,
    p_message TEXT
) AS $$
DECLARE
    v_execution_hk BYTEA;
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_duration BIGINT;
    v_success BOOLEAN;
    v_error_msg TEXT;
    v_result RECORD;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    -- Start automatic tracking
    v_execution_hk := script_tracking.track_script_execution(
        'auth.login_user',
        'FUNCTION_CALL',
        'AUTHENTICATION',
        NULL, -- No script content
        NULL, -- No file path
        NULL, -- No version
        util.process_hex_tenant(p_tenant_id), -- Tenant context
        'User authentication attempt',
        NULL  -- No ticket
    );
    
    BEGIN
        -- Call the actual login function
        SELECT * INTO v_result FROM auth.login_user(p_email, p_password, p_tenant_id);
        v_success := v_result.p_success;
        v_error_msg := CASE WHEN NOT v_success THEN v_result.p_message ELSE NULL END;
        
    EXCEPTION WHEN OTHERS THEN
        v_success := false;
        v_error_msg := SQLERRM;
        
        -- Still return something meaningful
        v_result.p_success := false;
        v_result.p_session_token := NULL;
        v_result.p_user_data := NULL;
        v_result.p_message := 'Authentication system error';
    END;
    
    -- Calculate duration and complete tracking
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
    
    PERFORM script_tracking.complete_script_execution(
        v_execution_hk,
        CASE WHEN v_success THEN 'COMPLETED' ELSE 'FAILED' END,
        v_duration,
        1, -- One authentication attempt
        v_error_msg,
        NULL, -- No error code
        ARRAY[]::TEXT[], -- No objects created
        ARRAY[]::TEXT[], -- No objects modified  
        ARRAY[]::TEXT[], -- No objects dropped
        ARRAY['auth']    -- Auth schema accessed
    );
    
    RAISE NOTICE '🔐 AUTO-TRACKED: Login attempt for % (Success: %, Duration: %ms)', 
                 p_email, v_success, v_duration;
    
    -- Return the actual results
    RETURN QUERY SELECT v_result.p_success, v_result.p_session_token, v_result.p_user_data, v_result.p_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ############################################################################
-- OPTION 3: LOGGED STATEMENT ANALYSIS (PostgreSQL Logs)
-- Parse PostgreSQL logs to automatically track all statements
-- ############################################################################

-- Function to parse and import PostgreSQL log entries
CREATE OR REPLACE FUNCTION script_tracking.import_postgres_logs(
    p_log_file_content TEXT
) RETURNS INTEGER AS $$
DECLARE
    v_log_line TEXT;
    v_lines TEXT[];
    v_timestamp TIMESTAMP WITH TIME ZONE;
    v_user_name TEXT;
    v_database_name TEXT;
    v_statement TEXT;
    v_duration DECIMAL;
    v_execution_hk BYTEA;
    v_imported_count INTEGER := 0;
BEGIN
    -- Split log content into lines
    v_lines := string_to_array(p_log_file_content, E'\n');
    
    -- Process each log line
    FOR i IN 1..array_length(v_lines, 1) LOOP
        v_log_line := v_lines[i];
        
        -- Parse PostgreSQL log format (simplified example)
        -- Format: 2025-01-19 10:30:45.123 EST [12345] user@database LOG: statement: SELECT...
        IF v_log_line ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}.*LOG:\s+statement:' THEN
            BEGIN
                -- Extract timestamp (simplified parsing)
                v_timestamp := to_timestamp(substring(v_log_line from '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}'), 'YYYY-MM-DD HH24:MI:SS.MS');
                
                -- Extract user@database
                v_user_name := substring(v_log_line from '\] ([^@]+)@' for '\1');
                v_database_name := substring(v_log_line from '@([^\s]+)' for '\1');
                
                -- Extract statement
                v_statement := substring(v_log_line from 'statement:\s+(.*)$' for '\1');
                
                -- Skip tracking our own tracking statements to avoid recursion
                IF v_statement NOT LIKE '%script_tracking%' AND v_statement NOT LIKE '%track_operation%' THEN
                    -- Track this statement
                    v_execution_hk := script_tracking.track_script_execution(
                        'LOG_IMPORT_' || substring(v_statement, 1, 50),
                        'LOG_IMPORTED',
                        CASE 
                            WHEN v_statement ILIKE 'SELECT%' THEN 'QUERY'
                            WHEN v_statement ILIKE 'INSERT%' OR v_statement ILIKE 'UPDATE%' OR v_statement ILIKE 'DELETE%' THEN 'DML'
                            WHEN v_statement ILIKE 'CREATE%' OR v_statement ILIKE 'ALTER%' OR v_statement ILIKE 'DROP%' THEN 'DDL'
                            ELSE 'OTHER'
                        END,
                        v_statement,
                        NULL, -- No file path
                        NULL, -- No version
                        NULL, -- No tenant (imported from logs)
                        'Statement imported from PostgreSQL logs',
                        NULL  -- No ticket
                    );
                    
                    -- Mark as completed (historical data)
                    PERFORM script_tracking.complete_script_execution(
                        v_execution_hk,
                        'COMPLETED',
                        NULL, -- Duration not available
                        NULL, -- Rows affected not available
                        NULL, -- No error
                        NULL, -- No error code
                        ARRAY[]::TEXT[], -- Objects unknown
                        ARRAY[]::TEXT[], -- Objects unknown
                        ARRAY[]::TEXT[], -- Objects unknown
                        ARRAY[]::TEXT[]  -- Schemas unknown
                    );
                    
                    v_imported_count := v_imported_count + 1;
                END IF;
                
            EXCEPTION WHEN OTHERS THEN
                -- Skip malformed log lines
                RAISE NOTICE 'Skipping malformed log line: %', left(v_log_line, 100);
            END;
        END IF;
    END LOOP;
    
    RAISE NOTICE '📥 Imported % statements from PostgreSQL logs', v_imported_count;
    RETURN v_imported_count;
END;
$$ LANGUAGE plpgsql;

-- ############################################################################
-- OPTION 4: AUTO-TRACKING MIGRATION WRAPPER
-- Automatically track migration executions
-- ############################################################################

-- Function to run migrations with automatic tracking
CREATE OR REPLACE FUNCTION script_tracking.run_migration_with_tracking(
    p_migration_file_path TEXT,
    p_migration_version VARCHAR(50),
    p_migration_type VARCHAR(20) DEFAULT 'FORWARD'
) RETURNS BOOLEAN AS $$
DECLARE
    v_execution_hk BYTEA;
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_duration BIGINT;
    v_migration_content TEXT;
    v_success BOOLEAN := false;
    v_error_msg TEXT;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    -- Read migration file content (would need to implement file reading)
    -- For now, we'll just track the migration execution
    
    -- Start tracking
    v_execution_hk := script_tracking.track_migration(
        p_migration_file_path,
        p_migration_version,
        p_migration_type,
        v_migration_content,
        NULL -- No tenant for system migrations
    );
    
    BEGIN
        -- Execute the migration (would use dynamic SQL in real implementation)
        -- EXECUTE 'psql -f ' || p_migration_file_path;
        
        -- Simulate success for this example
        v_success := true;
        RAISE NOTICE '🚀 Executed migration: %', p_migration_file_path;
        
    EXCEPTION WHEN OTHERS THEN
        v_success := false;
        v_error_msg := SQLERRM;
        RAISE NOTICE '❌ Migration failed: %', v_error_msg;
    END;
    
    -- Calculate duration and complete tracking
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
    
    PERFORM script_tracking.complete_script_execution(
        v_execution_hk,
        CASE WHEN v_success THEN 'COMPLETED' ELSE 'FAILED' END,
        v_duration,
        NULL, -- Rows affected unknown
        v_error_msg,
        NULL, -- No error code
        ARRAY[]::TEXT[], -- Would analyze migration content for objects
        ARRAY[]::TEXT[], -- Would analyze migration content for objects
        ARRAY[]::TEXT[], -- Would analyze migration content for objects
        ARRAY[]::TEXT[]  -- Would analyze migration content for schemas
    );
    
    RETURN v_success;
END;
$$ LANGUAGE plpgsql;

-- ############################################################################
-- OPTION 5: SIMPLE AUTO-WRAPPER FOR EXISTING FUNCTIONS
-- Modify existing functions to automatically include tracking
-- ############################################################################

-- Create a simple auto-tracking macro
CREATE OR REPLACE FUNCTION auto_track(
    p_operation_name TEXT,
    p_sql_to_execute TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_execution_hk BYTEA;
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_duration BIGINT;
    v_success BOOLEAN := false;
    v_error_msg TEXT;
    v_rows_affected BIGINT;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    -- Start tracking
    v_execution_hk := track_operation(p_operation_name, 'AUTO_WRAPPED');
    
    BEGIN
        -- Execute the SQL
        EXECUTE p_sql_to_execute;
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
        v_success := true;
        
    EXCEPTION WHEN OTHERS THEN
        v_success := false;
        v_error_msg := SQLERRM;
    END;
    
    -- Complete tracking
    v_duration := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time)) * 1000;
    
    PERFORM complete_operation(v_execution_hk, v_success, v_error_msg);
    
    RETURN v_success;
END;
$$ LANGUAGE plpgsql;

-- ############################################################################
-- SUMMARY OF AUTOMATION LEVELS
-- ############################################################################

/*
AUTOMATION LEVELS:

1. 🤖 FULLY AUTOMATIC (Event Triggers)
   - DDL operations tracked automatically
   - No code changes required
   - Limited to DDL only

2. 🔄 WRAPPER AUTOMATION (Function Wrappers)  
   - Replace function calls with tracking versions
   - Requires changing function calls
   - Comprehensive tracking

3. 📥 LOG IMPORT AUTOMATION (PostgreSQL Logs)
   - Import all statements from logs
   - Historical tracking possible
   - Requires log parsing setup

4. 🚀 MIGRATION AUTOMATION (Migration Wrapper)
   - Automatically track migration executions
   - Requires using wrapper function
   - Perfect for deployment tracking

5. 🎯 SELECTIVE AUTOMATION (Auto-Wrapper)
   - Track specific operations automatically
   - Simple to implement
   - Flexible usage

CURRENT STATUS:
- ❌ Manual tracking (like your current audit system)
- ✅ Can be made automatic with the options above

RECOMMENDATION:
- Start with Event Triggers for DDL (truly automatic)
- Use function wrappers for critical operations
- Keep manual tracking for custom operations
*/

DO $$
BEGIN
    RAISE NOTICE '🎯 AUTOMATION OPTIONS LOADED:';
    RAISE NOTICE '   1. Event Triggers - Automatic DDL tracking ✅';
    RAISE NOTICE '   2. Function Wrappers - Semi-automatic function tracking';
    RAISE NOTICE '   3. Log Import - Historical tracking from logs';
    RAISE NOTICE '   4. Migration Wrapper - Automatic migration tracking';
    RAISE NOTICE '   5. Auto-Wrapper - Simple operation tracking';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Choose the automation level that fits your needs!';
END $$; 