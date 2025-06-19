-- ================================================
-- LOGIN FLOW TRACER SCRIPT - FIXED VERSION
-- Traces the complete login flow through all tables
-- Shows before/after states to understand data flow
-- Updated to match actual Data Vault 2.0 schema
-- ================================================

-- Clean up any previous trace results
DROP TABLE IF EXISTS temp_login_trace_log;

-- Create table to store trace results
CREATE TEMP TABLE temp_login_trace_log (
    trace_id SERIAL PRIMARY KEY,
    step_order INTEGER,
    step_name VARCHAR(100),
    table_name VARCHAR(100),
    action VARCHAR(50),
    record_count INTEGER,
    sample_data JSONB,
    timestamp_captured TIMESTAMP DEFAULT NOW(),
    notes TEXT
);

DO $$
DECLARE
    v_test_email VARCHAR(255) := 'travisdwoodward72@gmail.com';
    v_test_password VARCHAR(255) := 'MyNewSecurePassword123';
    v_test_ip VARCHAR(45) := '192.168.1.199';
    v_test_user_agent VARCHAR(500) := 'Login Flow Tracer v2.0';
    
    -- Counters for before/after comparison
    v_before_count INTEGER;
    v_after_count INTEGER;
    v_sample_data JSONB;
    
    -- Login result
    v_login_result JSONB;
    
    -- Step counter
    v_step INTEGER := 1;
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'STARTING LOGIN FLOW TRACE - FIXED VERSION';
    RAISE NOTICE 'Test User: %', v_test_email;
    RAISE NOTICE 'Test IP: %', v_test_ip;
    RAISE NOTICE '============================================';

    -- ========================================
    -- STEP 1: CAPTURE BEFORE STATE
    -- ========================================
    RAISE NOTICE 'STEP %: Capturing BEFORE state of all tables...', v_step;
    
    -- Capture auth.user_h (User Hub)
    SELECT COUNT(*) INTO v_before_count FROM auth.user_h;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', encode(user_hk, 'hex'),
        'user_bk', user_bk,
        'load_date', load_date,
        'record_source', record_source
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_h ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'BEFORE Login', 'auth.user_h', 'COUNT', v_before_count, v_sample_data, 'User Hub - Main user records');

    -- Capture auth.user_profile_s (User Profile Satellite)
    SELECT COUNT(*) INTO v_before_count FROM auth.user_profile_s;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', encode(user_hk, 'hex'),
        'email', email,
        'first_name', first_name,
        'last_name', last_name,
        'load_date', load_date,
        'load_end_date', load_end_date
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_profile_s 
          WHERE email = v_test_email 
          ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'BEFORE Login', 'auth.user_profile_s', 'COUNT', v_before_count, v_sample_data, 'User Profile Satellite - User details');

    -- Capture auth.user_auth_s (User Authentication Satellite)
    SELECT COUNT(*) INTO v_before_count FROM auth.user_auth_s;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', encode(user_hk, 'hex'),
        'username', username,
        'load_date', load_date,
        'load_end_date', load_end_date,
        'failed_login_attempts', failed_login_attempts,
        'account_locked', account_locked,
        'password_hash_length', LENGTH(password_hash)
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_auth_s 
          WHERE username = v_test_email
          ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'BEFORE Login', 'auth.user_auth_s', 'COUNT', v_before_count, v_sample_data, 'User Authentication - Password and auth details');

    -- Capture auth.session_state_s (Sessions)
    SELECT COUNT(*) INTO v_before_count FROM auth.session_state_s;
    SELECT jsonb_agg(jsonb_build_object(
        'session_hk', encode(session_hk, 'hex'),
        'session_start', session_start,
        'session_end', session_end,
        'load_date', load_date,
        'load_end_date', load_end_date,
        'session_status', session_status,
        'ip_address', ip_address
    )) INTO v_sample_data
    FROM (SELECT s.* 
          FROM auth.session_state_s s
          JOIN auth.user_session_l usl ON s.session_hk = usl.session_hk
          JOIN auth.user_h uh ON usl.user_hk = uh.user_hk
          JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
          WHERE ups.email = v_test_email
          AND ups.load_end_date IS NULL
          ORDER BY s.load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'BEFORE Login', 'auth.session_state_s', 'COUNT', v_before_count, v_sample_data, 'Session State - Active sessions');

    -- Capture raw.login_attempt_h (Login Attempt Hub) - if exists
    BEGIN
        SELECT COUNT(*) INTO v_before_count FROM raw.login_attempt_h;
        SELECT jsonb_agg(jsonb_build_object(
            'login_attempt_hk', encode(login_attempt_hk, 'hex'),
            'login_attempt_bk', login_attempt_bk,
            'load_date', load_date,
            'record_source', record_source
        )) INTO v_sample_data
        FROM (SELECT * FROM raw.login_attempt_h 
              ORDER BY load_date DESC LIMIT 3) sub;
        
        INSERT INTO temp_login_trace_log 
        (step_order, step_name, table_name, action, record_count, sample_data, notes)
        VALUES 
        (v_step, 'BEFORE Login', 'raw.login_attempt_h', 'COUNT', v_before_count, v_sample_data, 'Raw Login Attempt Hub');
    EXCEPTION
        WHEN undefined_table THEN
            INSERT INTO temp_login_trace_log 
            (step_order, step_name, table_name, action, record_count, sample_data, notes)
            VALUES 
            (v_step, 'BEFORE Login', 'raw.login_attempt_h', 'N/A', 0, '{"status": "table_not_found"}'::jsonb, 'Raw login attempt hub does not exist');
    END;

    -- Capture raw.login_details_s (Login Details Satellite) - if exists
    BEGIN
        SELECT COUNT(*) INTO v_before_count FROM raw.login_details_s;
        SELECT jsonb_agg(jsonb_build_object(
            'login_attempt_hk', encode(login_attempt_hk, 'hex'),
            'username', username,
            'ip_address', ip_address,
            'user_agent', user_agent,
            'load_date', load_date,
            'load_end_date', load_end_date
        )) INTO v_sample_data
        FROM (SELECT * FROM raw.login_details_s 
              WHERE username = v_test_email 
              ORDER BY load_date DESC LIMIT 3) sub;
        
        INSERT INTO temp_login_trace_log 
        (step_order, step_name, table_name, action, record_count, sample_data, notes)
        VALUES 
        (v_step, 'BEFORE Login', 'raw.login_details_s', 'COUNT', v_before_count, v_sample_data, 'Raw Login Details Satellite');
    EXCEPTION
        WHEN undefined_table THEN
            INSERT INTO temp_login_trace_log 
            (step_order, step_name, table_name, action, record_count, sample_data, notes)
            VALUES 
            (v_step, 'BEFORE Login', 'raw.login_details_s', 'N/A', 0, '{"status": "table_not_found"}'::jsonb, 'Raw login details satellite does not exist');
    END;

    -- Capture raw.login_attempt_h and raw.login_details_s (if they exist)
    BEGIN
        SELECT COUNT(*) INTO v_before_count FROM raw.login_attempt_h;
        SELECT jsonb_agg(jsonb_build_object(
            'login_attempt_hk', encode(login_attempt_hk, 'hex'),
            'login_attempt_bk', login_attempt_bk,
            'load_date', load_date
        )) INTO v_sample_data
        FROM (SELECT * FROM raw.login_attempt_h ORDER BY load_date DESC LIMIT 3) sub;
        
        INSERT INTO temp_login_trace_log 
        (step_order, step_name, table_name, action, record_count, sample_data, notes)
        VALUES 
        (v_step, 'BEFORE Login', 'raw.login_attempt_h', 'COUNT', v_before_count, v_sample_data, 'Raw Login Attempt Hub');
    EXCEPTION
        WHEN undefined_table THEN
            INSERT INTO temp_login_trace_log 
            (step_order, step_name, table_name, action, record_count, sample_data, notes)
            VALUES 
            (v_step, 'BEFORE Login', 'raw.login_attempt_h', 'N/A', 0, '{"status": "table_not_found"}'::jsonb, 'Raw login attempt hub does not exist');
    END;

    -- Capture staging.login_status_s (if exists)
    BEGIN
        SELECT COUNT(*) INTO v_before_count FROM staging.login_status_s;
        SELECT jsonb_agg(jsonb_build_object(
            'login_attempt_hk', encode(login_attempt_hk, 'hex'),
            'username', username,
            'validation_status', validation_status,
            'load_date', load_date
        )) INTO v_sample_data
        FROM (SELECT * FROM staging.login_status_s 
              WHERE username = v_test_email 
              ORDER BY load_date DESC LIMIT 3) sub;
        
        INSERT INTO temp_login_trace_log 
        (step_order, step_name, table_name, action, record_count, sample_data, notes)
        VALUES 
        (v_step, 'BEFORE Login', 'staging.login_status_s', 'COUNT', v_before_count, v_sample_data, 'Staging Login Status');
    EXCEPTION
        WHEN undefined_table THEN
            INSERT INTO temp_login_trace_log 
            (step_order, step_name, table_name, action, record_count, sample_data, notes)
            VALUES 
            (v_step, 'BEFORE Login', 'staging.login_status_s', 'N/A', 0, '{"status": "table_not_found"}'::jsonb, 'Staging login status table does not exist');
    END;

    -- Capture audit tables (if they exist)
    BEGIN
        SELECT COUNT(*) INTO v_before_count FROM audit.user_action_log;
        SELECT jsonb_agg(jsonb_build_object(
            'log_id', log_id,
            'user_email', user_email,
            'action_type', action_type,
            'ip_address', ip_address,
            'created_at', created_at
        )) INTO v_sample_data
        FROM (SELECT * FROM audit.user_action_log 
              WHERE user_email = v_test_email 
              ORDER BY created_at DESC LIMIT 3) sub;
        
        INSERT INTO temp_login_trace_log 
        (step_order, step_name, table_name, action, record_count, sample_data, notes)
        VALUES 
        (v_step, 'BEFORE Login', 'audit.user_action_log', 'COUNT', v_before_count, v_sample_data, 'Audit Trail - User Actions');
    EXCEPTION
        WHEN undefined_table THEN
            INSERT INTO temp_login_trace_log 
            (step_order, step_name, table_name, action, record_count, sample_data, notes)
            VALUES 
            (v_step, 'BEFORE Login', 'audit.user_action_log', 'N/A', 0, '{"status": "table_not_found"}'::jsonb, 'Audit table does not exist');
    END;

    v_step := v_step + 1;

    -- ========================================
    -- STEP 2: EXECUTE LOGIN
    -- ========================================
    RAISE NOTICE 'STEP %: Executing login attempt...', v_step;
    
    BEGIN
        SELECT api.auth_login(jsonb_build_object(
            'username', v_test_email,
            'password', v_test_password,
            'ip_address', v_test_ip,
            'user_agent', v_test_user_agent
        )) INTO v_login_result;
        
        INSERT INTO temp_login_trace_log 
        (step_order, step_name, table_name, action, record_count, sample_data, notes)
        VALUES 
        (v_step, 'LOGIN EXECUTION', 'api.auth_login', 'CALL', 1, v_login_result, 'Login function executed');
        
        RAISE NOTICE 'Login Result: %', v_login_result;
    EXCEPTION
        WHEN OTHERS THEN
            v_login_result := jsonb_build_object(
                'error', true,
                'message', SQLERRM,
                'sqlstate', SQLSTATE
            );
            
            INSERT INTO temp_login_trace_log 
            (step_order, step_name, table_name, action, record_count, sample_data, notes)
            VALUES 
            (v_step, 'LOGIN EXECUTION', 'api.auth_login', 'ERROR', 0, v_login_result, 'Login function failed with exception');
            
            RAISE NOTICE 'Login Error: %', SQLERRM;
    END;

    v_step := v_step + 1;

    -- ========================================
    -- STEP 3: CAPTURE AFTER STATE
    -- ========================================
    RAISE NOTICE 'STEP %: Capturing AFTER state of all tables...', v_step;
    
    -- Wait a moment for any async operations
    PERFORM pg_sleep(1);
    
    -- Capture auth.user_h (User Hub) - AFTER
    SELECT COUNT(*) INTO v_after_count FROM auth.user_h;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', encode(user_hk, 'hex'),
        'user_bk', user_bk,
        'load_date', load_date,
        'record_source', record_source
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_h ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'AFTER Login', 'auth.user_h', 'COUNT', v_after_count, v_sample_data, 'User Hub - Check for new records');

    -- Capture auth.user_profile_s (User Profile Satellite) - AFTER
    SELECT COUNT(*) INTO v_after_count FROM auth.user_profile_s;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', encode(user_hk, 'hex'),
        'email', email,
        'first_name', first_name,
        'last_name', last_name,
        'load_date', load_date,
        'load_end_date', load_end_date
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_profile_s 
          WHERE email = v_test_email 
          ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'AFTER Login', 'auth.user_profile_s', 'COUNT', v_after_count, v_sample_data, 'User Profile Satellite - Check for updates');

    -- Capture auth.user_auth_s (User Authentication Satellite) - AFTER
    SELECT COUNT(*) INTO v_after_count FROM auth.user_auth_s;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', encode(user_hk, 'hex'),
        'username', username,
        'load_date', load_date,
        'load_end_date', load_end_date,
        'failed_login_attempts', failed_login_attempts,
        'account_locked', account_locked,
        'password_hash_length', LENGTH(password_hash)
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_auth_s 
          WHERE username = v_test_email
          ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'AFTER Login', 'auth.user_auth_s', 'COUNT', v_after_count, v_sample_data, 'User Authentication - Check for changes');

    -- Capture auth.session_state_s (Sessions) - AFTER
    SELECT COUNT(*) INTO v_after_count FROM auth.session_state_s;
    SELECT jsonb_agg(jsonb_build_object(
        'session_hk', encode(session_hk, 'hex'),
        'session_start', session_start,
        'session_end', session_end,
        'load_date', load_date,
        'load_end_date', load_end_date,
        'session_status', session_status,
        'ip_address', ip_address
    )) INTO v_sample_data
    FROM (SELECT s.* 
          FROM auth.session_state_s s
          JOIN auth.user_session_l usl ON s.session_hk = usl.session_hk
          JOIN auth.user_h uh ON usl.user_hk = uh.user_hk
          JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
          WHERE ups.email = v_test_email
          AND ups.load_end_date IS NULL
          ORDER BY s.load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'AFTER Login', 'auth.session_state_s', 'COUNT', v_after_count, v_sample_data, 'Session State - Look for new sessions');

    -- Capture raw.login_attempt_h (Login Attempt Hub) - AFTER
    BEGIN
        SELECT COUNT(*) INTO v_after_count FROM raw.login_attempt_h;
        SELECT jsonb_agg(jsonb_build_object(
            'login_attempt_hk', encode(login_attempt_hk, 'hex'),
            'login_attempt_bk', login_attempt_bk,
            'load_date', load_date,
            'record_source', record_source
        )) INTO v_sample_data
        FROM (SELECT * FROM raw.login_attempt_h 
              ORDER BY load_date DESC LIMIT 3) sub;
        
        INSERT INTO temp_login_trace_log 
        (step_order, step_name, table_name, action, record_count, sample_data, notes)
        VALUES 
        (v_step, 'AFTER Login', 'raw.login_attempt_h', 'COUNT', v_after_count, v_sample_data, 'Raw Login Attempt Hub - Should have new record');
    EXCEPTION
        WHEN undefined_table THEN
            INSERT INTO temp_login_trace_log 
            (step_order, step_name, table_name, action, record_count, sample_data, notes)
            VALUES 
            (v_step, 'AFTER Login', 'raw.login_attempt_h', 'N/A', 0, '{"status": "table_not_found"}'::jsonb, 'Raw login attempt hub does not exist');
    END;

    -- Capture raw.login_details_s (Login Details Satellite) - AFTER
    BEGIN
        SELECT COUNT(*) INTO v_after_count FROM raw.login_details_s;
        SELECT jsonb_agg(jsonb_build_object(
            'login_attempt_hk', encode(login_attempt_hk, 'hex'),
            'username', username,
            'ip_address', ip_address,
            'user_agent', user_agent,
            'load_date', load_date,
            'load_end_date', load_end_date
        )) INTO v_sample_data
        FROM (SELECT * FROM raw.login_details_s 
              WHERE username = v_test_email 
              ORDER BY load_date DESC LIMIT 3) sub;
        
        INSERT INTO temp_login_trace_log 
        (step_order, step_name, table_name, action, record_count, sample_data, notes)
        VALUES 
        (v_step, 'AFTER Login', 'raw.login_details_s', 'COUNT', v_after_count, v_sample_data, 'Raw Login Details Satellite - Should have new record');
    EXCEPTION
        WHEN undefined_table THEN
            INSERT INTO temp_login_trace_log 
            (step_order, step_name, table_name, action, record_count, sample_data, notes)
            VALUES 
            (v_step, 'AFTER Login', 'raw.login_details_s', 'N/A', 0, '{"status": "table_not_found"}'::jsonb, 'Raw login details satellite does not exist');
    END;

    -- Capture audit tables (if they exist) - AFTER
    BEGIN
        SELECT COUNT(*) INTO v_after_count FROM audit.user_action_log;
        SELECT jsonb_agg(jsonb_build_object(
            'log_id', log_id,
            'user_email', user_email,
            'action_type', action_type,
            'ip_address', ip_address,
            'created_at', created_at
        )) INTO v_sample_data
        FROM (SELECT * FROM audit.user_action_log 
              WHERE user_email = v_test_email 
              ORDER BY created_at DESC LIMIT 3) sub;
        
        INSERT INTO temp_login_trace_log 
        (step_order, step_name, table_name, action, record_count, sample_data, notes)
        VALUES 
        (v_step, 'AFTER Login', 'audit.user_action_log', 'COUNT', v_after_count, v_sample_data, 'Audit Trail - Should have new entries');
    EXCEPTION
        WHEN undefined_table THEN
            INSERT INTO temp_login_trace_log 
            (step_order, step_name, table_name, action, record_count, sample_data, notes)
            VALUES 
            (v_step, 'AFTER Login', 'audit.user_action_log', 'N/A', 0, '{"status": "table_not_found"}'::jsonb, 'Audit table does not exist');
    END;

    RAISE NOTICE 'Login flow trace completed!';
END;
$$;

-- ========================================
-- ANALYSIS AND RESULTS
-- ========================================
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'LOGIN FLOW TRACE ANALYSIS';
    RAISE NOTICE '============================================';
END;
$$;

-- Show the complete flow
SELECT 
    trace_id,
    step_order,
    step_name,
    table_name,
    action,
    record_count,
    LEFT(sample_data::text, 100) || CASE WHEN LENGTH(sample_data::text) > 100 THEN '...' ELSE '' END as sample_preview,
    notes
FROM temp_login_trace_log
ORDER BY step_order, trace_id;

-- Compare before/after counts
WITH before_after AS (
    SELECT 
        table_name,
        MAX(CASE WHEN step_name = 'BEFORE Login' THEN record_count END) as before_count,
        MAX(CASE WHEN step_name = 'AFTER Login' THEN record_count END) as after_count
    FROM temp_login_trace_log
    WHERE action = 'COUNT'
    GROUP BY table_name
)
SELECT 
    table_name,
    before_count,
    after_count,
    (after_count - before_count) as records_added,
    CASE 
        WHEN (after_count - before_count) > 0 THEN '✅ Records Added'
        WHEN (after_count - before_count) = 0 THEN '⚠️ No Change'
        ELSE '❌ Records Lost'
    END as status
FROM before_after
ORDER BY table_name;

-- Show login execution details
SELECT 
    'LOGIN EXECUTION RESULT:' as section,
    sample_data
FROM temp_login_trace_log
WHERE step_name = 'LOGIN EXECUTION';

-- Show recent activity in key tables
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'RECENT ACTIVITY IN KEY TABLES:';
END;
$$;

-- Recent login attempts (check if table exists)
DO $$
BEGIN
    BEGIN
        RAISE NOTICE 'RECENT LOGIN ATTEMPTS (raw.login_attempt):';
        PERFORM 1 FROM raw.login_attempt LIMIT 1;
        -- If we get here, table exists, so show the data
    EXCEPTION
        WHEN undefined_table THEN
            RAISE NOTICE 'Table raw.login_attempt does not exist';
            RETURN;
    END;
END;
$$;

-- Check for Data Vault 2.0 login tracking tables
DO $$
BEGIN
    RAISE NOTICE 'Checking for Data Vault 2.0 login tracking tables...';
    
    -- Check for login attempt hub
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'login_attempt_h') THEN
        RAISE NOTICE '✅ Found raw.login_attempt_h (Login Attempt Hub)';
    ELSE
        RAISE NOTICE '❌ Table raw.login_attempt_h does not exist';
    END IF;
    
    -- Check for login details satellite
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'login_details_s') THEN
        RAISE NOTICE '✅ Found raw.login_details_s (Login Details Satellite)';
    ELSE
        RAISE NOTICE '❌ Table raw.login_details_s does not exist';
    END IF;
    
    -- Check for staging login status
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'staging' AND table_name = 'login_status_s') THEN
        RAISE NOTICE '✅ Found staging.login_status_s (Login Status Satellite)';
    ELSE
        RAISE NOTICE '❌ Table staging.login_status_s does not exist';
    END IF;
END;
$$;

-- Show recent login attempts from Data Vault 2.0 tables
DO $$
DECLARE
    login_rec RECORD;
    login_count INTEGER := 0;
BEGIN
    BEGIN
        -- Try to show from login_details_s if it exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'raw' AND table_name = 'login_details_s') THEN
            RAISE NOTICE 'Recent Login Details from raw.login_details_s:';
            FOR login_rec IN 
                SELECT 
                    encode(login_attempt_hk, 'hex') as login_attempt_hk,
                    username,
                    ip_address,
                    user_agent,
                    load_date,
                    load_end_date,
                    CASE WHEN load_end_date IS NULL THEN 'ACTIVE' ELSE 'INACTIVE' END as status
                FROM raw.login_details_s
                WHERE username = 'travisdwoodward72@gmail.com'
                ORDER BY load_date DESC
                LIMIT 5
            LOOP
                login_count := login_count + 1;
                RAISE NOTICE 'Login %: % | IP: % | Date: % | Status: %', 
                    login_count,
                    login_rec.login_attempt_hk,
                    login_rec.ip_address,
                    login_rec.load_date,
                    login_rec.status;
            END LOOP;
            
            IF login_count = 0 THEN
                RAISE NOTICE 'No login details found for this user';
            END IF;
        ELSE
            RAISE NOTICE 'raw.login_details_s table does not exist - login attempts may not be tracked in raw layer';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error retrieving login details: %', SQLERRM;
    END;
END;
$$;

-- Recent sessions with proper joins
DO $$
BEGIN
    BEGIN
        RAISE NOTICE 'Checking for recent sessions...';
        -- This is a safe way to check if we can query sessions
        PERFORM 1 FROM auth.session_state_s LIMIT 1;
        RAISE NOTICE 'Found session tables - checking for user sessions';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error accessing session tables: %', SQLERRM;
            RETURN;
    END;
END;
$$;

-- Try to show recent sessions
DO $$
DECLARE
    session_rec RECORD;
    session_count INTEGER := 0;
BEGIN
    BEGIN
        RAISE NOTICE 'Recent Sessions for travisdwoodward72@gmail.com:';
        FOR session_rec IN 
            SELECT 
                encode(s.session_hk, 'hex') as session_hk,
                ups.email,
                s.session_start,
                s.session_end,
                s.session_status,
                s.load_date,
                s.load_end_date,
                s.ip_address::text as ip_address
            FROM auth.session_state_s s
            JOIN auth.user_session_l usl ON s.session_hk = usl.session_hk
            JOIN auth.user_h uh ON usl.user_hk = uh.user_hk
            JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
            WHERE ups.email = 'travisdwoodward72@gmail.com'
              AND ups.load_end_date IS NULL
            ORDER BY s.load_date DESC
            LIMIT 5
        LOOP
            session_count := session_count + 1;
            RAISE NOTICE 'Session %: % | Status: % | Start: % | IP: %', 
                session_count, 
                session_rec.session_hk, 
                session_rec.session_status, 
                session_rec.session_start, 
                session_rec.ip_address;
        END LOOP;
        
        IF session_count = 0 THEN
            RAISE NOTICE 'No sessions found for this user';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error retrieving sessions: %', SQLERRM;
    END;
END;
$$;

-- Recent authentication records
DO $$
DECLARE
    auth_rec RECORD;
    auth_count INTEGER := 0;
BEGIN
    BEGIN
        RAISE NOTICE 'Recent Authentication Records for travisdwoodward72@gmail.com:';
        FOR auth_rec IN 
            SELECT 
                encode(user_hk, 'hex') as user_hk,
                username,
                failed_login_attempts,
                account_locked,
                last_login_date,
                load_date,
                load_end_date,
                CASE WHEN load_end_date IS NULL THEN 'ACTIVE' ELSE 'INACTIVE' END as status
            FROM auth.user_auth_s
            WHERE username = 'travisdwoodward72@gmail.com'
            ORDER BY load_date DESC
            LIMIT 5
        LOOP
            auth_count := auth_count + 1;
            RAISE NOTICE 'Auth Record %: % | Status: % | Failed Attempts: % | Locked: % | Last Login: %', 
                auth_count,
                auth_rec.status,
                auth_rec.status,
                auth_rec.failed_login_attempts,
                auth_rec.account_locked,
                auth_rec.last_login_date;
        END LOOP;
        
        IF auth_count = 0 THEN
            RAISE NOTICE 'No authentication records found for this user';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error retrieving authentication records: %', SQLERRM;
    END;
END;
$$;

-- ========================================
-- FLOW SUMMARY AND RECOMMENDATIONS
-- ========================================
DO $$
DECLARE
    v_login_successful BOOLEAN;
    v_session_created BOOLEAN;
    v_attempt_logged BOOLEAN;
    v_audit_logged BOOLEAN;
BEGIN
    -- Check if login was successful
    SELECT (sample_data->>'p_success')::boolean INTO v_login_successful
    FROM temp_login_trace_log 
    WHERE step_name = 'LOGIN EXECUTION';
    
    -- Check if session was created
    SELECT EXISTS(
        SELECT 1 FROM temp_login_trace_log 
        WHERE table_name = 'auth.session_state_s' 
        AND step_name = 'AFTER Login' 
        AND record_count > (
            SELECT COALESCE(record_count, 0) FROM temp_login_trace_log 
            WHERE table_name = 'auth.session_state_s' 
            AND step_name = 'BEFORE Login'
        )
    ) INTO v_session_created;
    
    -- Check if attempt was logged (check multiple possible tables)
    WITH attempt_changes AS (
        SELECT 
            table_name,
            MAX(CASE WHEN step_name = 'BEFORE Login' THEN record_count END) as before_count,
            MAX(CASE WHEN step_name = 'AFTER Login' THEN record_count END) as after_count
        FROM temp_login_trace_log 
        WHERE table_name IN ('raw.login_attempt_h', 'raw.login_details_s', 'staging.login_status_s')
        AND action = 'COUNT'
        GROUP BY table_name
    )
    SELECT EXISTS(
        SELECT 1 FROM attempt_changes 
        WHERE COALESCE(after_count, 0) > COALESCE(before_count, 0)
    ) INTO v_attempt_logged;
    
    -- Check if audit was logged
    SELECT EXISTS(
        SELECT 1 FROM temp_login_trace_log 
        WHERE table_name = 'audit.user_action_log' 
        AND step_name = 'AFTER Login' 
        AND record_count > (
            SELECT COALESCE(record_count, 0) FROM temp_login_trace_log 
            WHERE table_name = 'audit.user_action_log' 
            AND step_name = 'BEFORE Login'
        )
    ) INTO v_audit_logged;
    
    RAISE NOTICE '';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'FLOW SUMMARY';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Login Successful: %', COALESCE(v_login_successful, false);
    RAISE NOTICE 'Session Created: %', v_session_created;
    RAISE NOTICE 'Attempt Logged: %', v_attempt_logged;
    RAISE NOTICE 'Audit Logged: %', v_audit_logged;
    
    IF NOT COALESCE(v_login_successful, false) THEN
        RAISE NOTICE '';
        RAISE NOTICE '❌ LOGIN FAILED - Check error details in execution result';
    END IF;
    
    IF NOT v_session_created THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️ NO SESSION CREATED - This indicates a problem in session creation';
    END IF;
    
    IF NOT v_attempt_logged THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️ NO ATTEMPT LOGGED - Login attempt was not recorded';
    END IF;
    
    IF NOT v_audit_logged THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️ NO AUDIT LOG - Audit trail may be missing or disabled';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'RECOMMENDATIONS:';
    RAISE NOTICE '1. Check that all required tables exist in your schema';
    RAISE NOTICE '2. Verify that the api.auth_login function exists and is accessible';
    RAISE NOTICE '3. Ensure proper Data Vault 2.0 naming conventions are followed';
    RAISE NOTICE '4. Review any error messages in the execution result';
    
END;
$$; 