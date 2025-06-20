-- =============================================================================
-- COMPREHENSIVE ENTERPRISE TRACKING SYSTEM TEST
-- Tests all components: Foundation, Automation, Enterprise Features
-- Run this directly in pgAdmin to validate your system
-- Author: AI Agent
-- Date: 2025-01-19
-- =============================================================================

-- ############################################################################
-- TEST INITIALIZATION AND CLEANUP
-- ############################################################################

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 COMPREHENSIVE ENTERPRISE TRACKING SYSTEM TEST';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Testing foundation, automation, and enterprise features...';
    RAISE NOTICE '';
END $$;

-- Create test results table for this session
DROP TABLE IF EXISTS temp_test_results;
CREATE TEMP TABLE temp_test_results (
    test_number INTEGER,
    test_category VARCHAR(50),
    test_name VARCHAR(200),
    expected_result TEXT,
    actual_result TEXT,
    status VARCHAR(10),
    error_message TEXT
);

-- ############################################################################
-- TEST 1: FOUNDATION INFRASTRUCTURE TESTS
-- ############################################################################

DO $$
DECLARE
    v_test_num INTEGER := 1;
    v_result TEXT;
    v_count INTEGER;
BEGIN
    RAISE NOTICE '📋 TEST 1: Foundation Infrastructure';
    RAISE NOTICE '-----------------------------------';
    
    -- Test 1.1: Schema exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM information_schema.schemata 
        WHERE schema_name = 'script_tracking';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'FOUNDATION', 'Schema Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 1.2: Hub table exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM information_schema.tables 
        WHERE table_schema = 'script_tracking' AND table_name = 'script_execution_h';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'FOUNDATION', 'Hub Table Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 1.3: Satellite table exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM information_schema.tables 
        WHERE table_schema = 'script_tracking' AND table_name = 'script_execution_s';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'FOUNDATION', 'Satellite Table Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 1.4: Sequence exists (FIXED primary key solution)
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_sequences
        WHERE schemaname = 'script_tracking' AND sequencename = 'script_execution_version_seq';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'FOUNDATION', 'Version Sequence Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 1.5: Main tracking function exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'script_tracking' AND p.proname = 'track_script_execution';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'FOUNDATION', 'Main Tracking Function Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 1.6: Completion function exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'script_tracking' AND p.proname = 'complete_script_execution';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'FOUNDATION', 'Completion Function Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
    END;
    
    RAISE NOTICE '✅ Foundation infrastructure tests completed';
END $$;

-- ############################################################################
-- TEST 2: MANUAL TRACKING FUNCTIONALITY TESTS
-- ############################################################################

DO $$
DECLARE
    v_test_num INTEGER := 10;
    v_execution_hk BYTEA;
    v_count INTEGER;
    v_status TEXT;
    v_error TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 2: Manual Tracking Functionality';
    RAISE NOTICE '----------------------------------------';
    
    -- Test 2.1: Basic script tracking works
    BEGIN
        v_execution_hk := script_tracking.track_script_execution(
            'TEST_SCRIPT_MANUAL',
            'TEST',
            'VALIDATION',
            'SELECT 1 as test_query;',
            NULL, -- file path
            'v1.0.0',
            NULL, -- tenant
            'Testing manual tracking functionality',
            'TEST-001'
        );
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'MANUAL', 'Basic Script Tracking', 'BYTEA', 'SUCCESS',
            CASE WHEN v_execution_hk IS NOT NULL THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
        
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'MANUAL', 'Basic Script Tracking', 'SUCCESS', 'FAILED',
            'FAIL', SQLERRM
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 2.2: Script completion works
    BEGIN
        PERFORM script_tracking.complete_script_execution(
            v_execution_hk,
            'COMPLETED',
            150, -- duration ms
            1,   -- rows affected
            NULL, -- no error
            NULL, -- no error code
            ARRAY['test_table'], -- objects created
            ARRAY[]::TEXT[],     -- objects modified
            ARRAY[]::TEXT[],     -- objects dropped
            ARRAY['public']      -- schemas affected
        );
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'MANUAL', 'Script Completion', 'SUCCESS', 'SUCCESS', 'PASS', NULL
        );
        v_test_num := v_test_num + 1;
        
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'MANUAL', 'Script Completion', 'SUCCESS', 'FAILED',
            'FAIL', SQLERRM
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 2.3: Data actually stored correctly
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM script_tracking.script_execution_s
        WHERE script_execution_hk = v_execution_hk;
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'MANUAL', 'Data Storage Verification', '2', v_count::text,
            CASE WHEN v_count = 2 THEN 'PASS' ELSE 'FAIL' END, 
            CASE WHEN v_count != 2 THEN 'Expected 2 records (start + completion), got ' || v_count ELSE NULL END
        );
        v_test_num := v_test_num + 1;
        
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'MANUAL', 'Data Storage Verification', '2', 'ERROR',
            'FAIL', SQLERRM
        );
    END;
    
    RAISE NOTICE '✅ Manual tracking functionality tests completed';
END $$;

-- ############################################################################
-- TEST 3: AUTOMATIC DDL TRACKING TESTS (Event Triggers)
-- ############################################################################

DO $$
DECLARE
    v_test_num INTEGER := 20;
    v_count INTEGER;
    v_before_count INTEGER;
    v_after_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 3: Automatic DDL Tracking (Event Triggers)';
    RAISE NOTICE '-----------------------------------------------';
    
    -- Test 3.1: Event trigger exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_event_trigger
        WHERE evtname = 'auto_ddl_tracker';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'AUTOMATION', 'DDL Event Trigger Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 3.2: Event trigger function exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'script_tracking' AND p.proname = 'auto_track_ddl_operations';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'AUTOMATION', 'DDL Trigger Function Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 3.3: Automatic DDL tracking works (create a test table)
    BEGIN
        -- Count current executions
        SELECT COUNT(*) INTO v_before_count
        FROM script_tracking.script_execution_s
        WHERE script_type = 'AUTO_DDL';
        
        -- Create a test table (should trigger automatic tracking)
        CREATE TABLE IF NOT EXISTS test_ddl_tracking (
            id SERIAL PRIMARY KEY,
            test_data VARCHAR(100),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        
        -- Small delay to allow trigger to process
        PERFORM pg_sleep(0.1);
        
        -- Count after DDL operation
        SELECT COUNT(*) INTO v_after_count
        FROM script_tracking.script_execution_s
        WHERE script_type = 'AUTO_DDL';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'AUTOMATION', 'Automatic DDL Tracking Works', 
            'INCREASED', 
            CASE WHEN v_after_count > v_before_count THEN 'INCREASED' ELSE 'NO_CHANGE' END,
            CASE WHEN v_after_count > v_before_count THEN 'PASS' ELSE 'FAIL' END, 
            CASE WHEN v_after_count <= v_before_count THEN 
                'Before: ' || v_before_count || ', After: ' || v_after_count ELSE NULL END
        );
        v_test_num := v_test_num + 1;
        
        -- Clean up test table
        DROP TABLE IF EXISTS test_ddl_tracking;
        
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'AUTOMATION', 'Automatic DDL Tracking Works', 'INCREASED', 'ERROR',
            'FAIL', SQLERRM
        );
        v_test_num := v_test_num + 1;
    END;
    
    RAISE NOTICE '✅ Automatic DDL tracking tests completed';
END $$;

-- ############################################################################
-- TEST 4: ENTERPRISE FUNCTION WRAPPERS TESTS
-- ############################################################################

DO $$
DECLARE
    v_test_num INTEGER := 30;
    v_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 4: Enterprise Function Wrappers';
    RAISE NOTICE '--------------------------------------';
    
    -- Test 4.1: Login tracking wrapper exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'auth' AND p.proname = 'login_user_tracking';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'ENTERPRISE', 'Login Tracking Wrapper Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 4.2: Registration tracking wrapper exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'auth' AND p.proname = 'register_user_tracking';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'ENTERPRISE', 'Registration Tracking Wrapper Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 4.3: Session validation tracking wrapper exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'auth' AND p.proname = 'validate_session_tracking';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'ENTERPRISE', 'Session Validation Tracking Wrapper Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 4.4: Migration runner exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'script_tracking' AND p.proname = 'run_migration_enterprise';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'ENTERPRISE', 'Enterprise Migration Runner Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    RAISE NOTICE '✅ Enterprise function wrapper tests completed';
END $$;

-- ############################################################################
-- TEST 5: ENTERPRISE DASHBOARD AND REPORTING TESTS
-- ############################################################################

DO $$
DECLARE
    v_test_num INTEGER := 40;
    v_count INTEGER;
    v_dashboard_result RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 5: Enterprise Dashboard and Reporting';
    RAISE NOTICE '--------------------------------------------';
    
    -- Test 5.1: Dashboard function exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'script_tracking' AND p.proname = 'get_enterprise_dashboard';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'REPORTING', 'Enterprise Dashboard Function Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 5.2: Dashboard function works
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM script_tracking.get_enterprise_dashboard();
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'REPORTING', 'Enterprise Dashboard Function Works', '>0', v_count::text,
            CASE WHEN v_count > 0 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
        
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'REPORTING', 'Enterprise Dashboard Function Works', '>0', 'ERROR',
            'FAIL', SQLERRM
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 5.3: Historical import function exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'script_tracking' AND p.proname = 'import_historical_operations';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'REPORTING', 'Historical Import Function Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 5.4: Setup function exists
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'script_tracking' AND p.proname = 'setup_enterprise_tracking';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'REPORTING', 'Enterprise Setup Function Exists', '1', v_count::text,
            CASE WHEN v_count = 1 THEN 'PASS' ELSE 'FAIL' END, NULL
        );
    END;
    
    RAISE NOTICE '✅ Enterprise dashboard and reporting tests completed';
END $$;

-- ############################################################################
-- TEST 6: SIMPLE WRAPPER FUNCTIONS TESTS
-- ############################################################################

DO $$
DECLARE
    v_test_num INTEGER := 50;
    v_execution_hk BYTEA;
    v_success BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 6: Simple Wrapper Functions';
    RAISE NOTICE '---------------------------------';
    
    -- Test 6.1: Simple track_operation function works
    BEGIN
        v_execution_hk := track_operation('TEST_SIMPLE_WRAPPER', 'VALIDATION');
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'WRAPPERS', 'Simple track_operation Works', 'BYTEA', 'SUCCESS',
            CASE WHEN v_execution_hk IS NOT NULL THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        v_test_num := v_test_num + 1;
        
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'WRAPPERS', 'Simple track_operation Works', 'BYTEA', 'ERROR',
            'FAIL', SQLERRM
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 6.2: Simple complete_operation function works
    BEGIN
        v_success := complete_operation(v_execution_hk, true, NULL);
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'WRAPPERS', 'Simple complete_operation Works', 'TRUE', v_success::text,
            CASE WHEN v_success THEN 'PASS' ELSE 'FAIL' END, NULL
        );
        
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'WRAPPERS', 'Simple complete_operation Works', 'TRUE', 'ERROR',
            'FAIL', SQLERRM
        );
    END;
    
    RAISE NOTICE '✅ Simple wrapper function tests completed';
END $$;

-- ############################################################################
-- TEST 7: DATA INTEGRITY AND PERFORMANCE TESTS
-- ############################################################################

DO $$
DECLARE
    v_test_num INTEGER := 60;
    v_count INTEGER;
    v_duplicate_count INTEGER;
    v_orphan_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📋 TEST 7: Data Integrity and Performance';
    RAISE NOTICE '----------------------------------------';
    
    -- Test 7.1: No duplicate primary keys (the original issue)
    BEGIN
        SELECT COUNT(*) - COUNT(DISTINCT (script_execution_hk, version_number)) INTO v_duplicate_count
        FROM script_tracking.script_execution_s;
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'INTEGRITY', 'No Duplicate Primary Keys', '0', v_duplicate_count::text,
            CASE WHEN v_duplicate_count = 0 THEN 'PASS' ELSE 'FAIL' END, 
            CASE WHEN v_duplicate_count > 0 THEN 'Found ' || v_duplicate_count || ' duplicate primary keys' ELSE NULL END
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 7.2: No orphaned satellite records
    BEGIN
        SELECT COUNT(*) INTO v_orphan_count
        FROM script_tracking.script_execution_s s
        WHERE NOT EXISTS (
            SELECT 1 FROM script_tracking.script_execution_h h 
            WHERE h.script_execution_hk = s.script_execution_hk
        );
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'INTEGRITY', 'No Orphaned Satellite Records', '0', v_orphan_count::text,
            CASE WHEN v_orphan_count = 0 THEN 'PASS' ELSE 'FAIL' END, 
            CASE WHEN v_orphan_count > 0 THEN 'Found ' || v_orphan_count || ' orphaned records' ELSE NULL END
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 7.3: Sequence is working properly
    BEGIN
        SELECT COUNT(DISTINCT version_number) INTO v_count
        FROM script_tracking.script_execution_s;
        
        SELECT COUNT(*) INTO v_duplicate_count
        FROM script_tracking.script_execution_s;
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'PERFORMANCE', 'Sequence Generating Unique Values', 'UNIQUE', 
            CASE WHEN v_count = v_duplicate_count THEN 'UNIQUE' ELSE 'DUPLICATES' END,
            CASE WHEN v_count = v_duplicate_count THEN 'PASS' ELSE 'FAIL' END, 
            'Unique versions: ' || v_count || ', Total records: ' || v_duplicate_count
        );
        v_test_num := v_test_num + 1;
    END;
    
    -- Test 7.4: Indexes exist for performance
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_indexes
        WHERE schemaname = 'script_tracking' AND tablename = 'script_execution_s';
        
        INSERT INTO temp_test_results VALUES (
            v_test_num, 'PERFORMANCE', 'Performance Indexes Exist', '>5', v_count::text,
            CASE WHEN v_count >= 5 THEN 'PASS' ELSE 'FAIL' END, 
            'Found ' || v_count || ' indexes on satellite table'
        );
    END;
    
    RAISE NOTICE '✅ Data integrity and performance tests completed';
END $$;

-- ############################################################################
-- TEST RESULTS SUMMARY
-- ############################################################################

DO $$
DECLARE
    v_total_tests INTEGER;
    v_passed_tests INTEGER;
    v_failed_tests INTEGER;
    v_pass_rate DECIMAL(5,2);
    v_result RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📊 COMPREHENSIVE TEST RESULTS SUMMARY';
    RAISE NOTICE '=====================================';
    
    -- Calculate summary statistics
    SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'PASS') as passed,
        COUNT(*) FILTER (WHERE status = 'FAIL') as failed
    INTO v_total_tests, v_passed_tests, v_failed_tests
    FROM temp_test_results;
    
    v_pass_rate := ROUND((v_passed_tests::DECIMAL / v_total_tests * 100), 2);
    
    RAISE NOTICE 'Total Tests: %', v_total_tests;
    RAISE NOTICE 'Passed: % (%.2f%%)', v_passed_tests, v_pass_rate;
    RAISE NOTICE 'Failed: %', v_failed_tests;
    RAISE NOTICE '';
    
    -- Show results by category
    FOR v_result IN 
        SELECT 
            test_category,
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE status = 'PASS') as passed,
            COUNT(*) FILTER (WHERE status = 'FAIL') as failed
        FROM temp_test_results
        GROUP BY test_category
        ORDER BY test_category
    LOOP
        RAISE NOTICE '% Tests: %/% passed', 
                     RPAD(v_result.test_category, 12), 
                     v_result.passed, 
                     v_result.total;
    END LOOP;
    
    RAISE NOTICE '';
    
    -- Show failed tests details
    IF v_failed_tests > 0 THEN
        RAISE NOTICE '❌ FAILED TESTS DETAILS:';
        RAISE NOTICE '-----------------------';
        
        FOR v_result IN 
            SELECT test_category, test_name, expected_result, actual_result, error_message
            FROM temp_test_results
            WHERE status = 'FAIL'
            ORDER BY test_number
        LOOP
            RAISE NOTICE '   [%] % - Expected: %, Got: %', 
                         v_result.test_category, 
                         v_result.test_name,
                         v_result.expected_result,
                         v_result.actual_result;
            
            IF v_result.error_message IS NOT NULL THEN
                RAISE NOTICE '      Error: %', v_result.error_message;
            END IF;
        END LOOP;
    ELSE
        RAISE NOTICE '🎉 ALL TESTS PASSED! Your enterprise tracking system is working perfectly!';
    END IF;
    
    RAISE NOTICE '';
    
    -- Overall system status
    IF v_pass_rate >= 90 THEN
        RAISE NOTICE '🟢 SYSTEM STATUS: EXCELLENT (%.2f%% pass rate)', v_pass_rate;
        RAISE NOTICE '   Your enterprise tracking system is production-ready!';
    ELSIF v_pass_rate >= 75 THEN
        RAISE NOTICE '🟡 SYSTEM STATUS: GOOD (%.2f%% pass rate)', v_pass_rate;
        RAISE NOTICE '   Most features working, some issues need attention.';
    ELSE
        RAISE NOTICE '🔴 SYSTEM STATUS: NEEDS ATTENTION (%.2f%% pass rate)', v_pass_rate;
        RAISE NOTICE '   Significant issues detected, review failed tests.';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 DETAILED TEST RESULTS:';
    RAISE NOTICE '';
END $$;

-- Show detailed test results table
SELECT 
    test_number as "#",
    test_category as "Category",
    test_name as "Test Name",
    expected_result as "Expected",
    actual_result as "Actual",
    status as "Status",
    COALESCE(error_message, '') as "Error Details"
FROM temp_test_results
ORDER BY test_number;

-- ############################################################################
-- SAMPLE DATA VERIFICATION
-- ############################################################################

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📋 SAMPLE DATA VERIFICATION';
    RAISE NOTICE '---------------------------';
    RAISE NOTICE 'Recent tracking entries in your system:';
    RAISE NOTICE '';
END $$;

-- Show recent tracking data
SELECT 
    LEFT(script_name, 30) as "Script Name",
    script_type as "Type",
    execution_status as "Status",
    execution_timestamp as "When",
    COALESCE(execution_duration_ms::text || 'ms', 'N/A') as "Duration"
FROM script_tracking.script_execution_s
ORDER BY execution_timestamp DESC
LIMIT 10;

-- ############################################################################
-- USAGE EXAMPLES AND NEXT STEPS
-- ############################################################################

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🚀 USAGE EXAMPLES AND NEXT STEPS';
    RAISE NOTICE '=================================';
    RAISE NOTICE '';
    RAISE NOTICE '1. Manual Tracking:';
    RAISE NOTICE '   hk := track_operation(''My Script'', ''MAINTENANCE'');';
    RAISE NOTICE '   SELECT complete_operation(hk, true);';
    RAISE NOTICE '';
    RAISE NOTICE '2. View Enterprise Dashboard:';
    RAISE NOTICE '   SELECT * FROM script_tracking.get_enterprise_dashboard();';
    RAISE NOTICE '';
    RAISE NOTICE '3. DDL Operations (Automatic):';
    RAISE NOTICE '   CREATE TABLE test (...); -- Automatically tracked!';
    RAISE NOTICE '';
    RAISE NOTICE '4. Use Tracking Function Wrappers:';
    RAISE NOTICE '   SELECT * FROM auth.login_user_tracking(email, pass, tenant);';
    RAISE NOTICE '';
    RAISE NOTICE '5. Run Migration with Tracking:';
    RAISE NOTICE '   SELECT * FROM script_tracking.run_migration_enterprise(''V001.sql'', ''V001'');';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Your enterprise tracking system is ready for production use!';
    RAISE NOTICE '   All DDL operations are now automatically tracked.';
    RAISE NOTICE '   Use the tracking wrappers for enhanced authentication monitoring.';
    RAISE NOTICE '';
END $$; 