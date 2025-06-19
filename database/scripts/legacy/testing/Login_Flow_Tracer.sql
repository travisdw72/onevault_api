-- ================================================
-- LOGIN FLOW TRACER SCRIPT
-- Traces the complete login flow through all tables
-- Shows before/after states to understand data flow
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
    v_test_user_agent VARCHAR(500) := 'Login Flow Tracer v1.0';
    
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
    RAISE NOTICE 'STARTING LOGIN FLOW TRACE';
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
        'user_hk', user_hk,
        'load_date', load_date,
        'record_source', record_source
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_h ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'BEFORE Login', 'auth.user_h', 'COUNT', v_before_count, v_sample_data, 'User Hub - Main user records');

    -- Capture auth.user_s (User Satellite)
    SELECT COUNT(*) INTO v_before_count FROM auth.user_s;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', user_hk,
        'email', email,
        'load_date', load_date,
        'load_end_date', load_end_date
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_s WHERE email = v_test_email ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'BEFORE Login', 'auth.user_s', 'COUNT', v_before_count, v_sample_data, 'User Satellite - User details');

    -- Capture auth.user_credential_s (Password Satellite)
    SELECT COUNT(*) INTO v_before_count FROM auth.user_credential_s;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', user_hk,
        'load_date', load_date,
        'load_end_date', load_end_date,
        'password_hash_length', LENGTH(password_hash)
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_credential_s 
          WHERE user_hk = (SELECT user_hk FROM auth.user_s WHERE email = v_test_email LIMIT 1)
          ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'BEFORE Login', 'auth.user_credential_s', 'COUNT', v_before_count, v_sample_data, 'User Credentials - Password history');

    -- Capture auth.session_state_s (Sessions)
    SELECT COUNT(*) INTO v_before_count FROM auth.session_state_s;
    SELECT jsonb_agg(jsonb_build_object(
        'session_hk', session_hk,
        'user_hk', user_hk,
        'session_token_hash', LEFT(session_token_hash, 10) || '...',
        'load_date', load_date,
        'load_end_date', load_end_date,
        'is_active', is_active
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.session_state_s 
          WHERE user_hk = (SELECT user_hk FROM auth.user_s WHERE email = v_test_email LIMIT 1)
          ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'BEFORE Login', 'auth.session_state_s', 'COUNT', v_before_count, v_sample_data, 'Session State - Active sessions');

    -- Capture raw.login_attempt (Login Attempts)
    SELECT COUNT(*) INTO v_before_count FROM raw.login_attempt;
    SELECT jsonb_agg(jsonb_build_object(
        'attempt_id', attempt_id,
        'email', email,
        'ip_address', ip_address,
        'attempt_time', attempt_time,
        'success', success,
        'failure_reason', failure_reason
    )) INTO v_sample_data
    FROM (SELECT * FROM raw.login_attempt 
          WHERE email = v_test_email 
          ORDER BY attempt_time DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'BEFORE Login', 'raw.login_attempt', 'COUNT', v_before_count, v_sample_data, 'Raw Login Attempts');

    -- Capture auth.failed_login_attempt_s (Failed Attempts)
    SELECT COUNT(*) INTO v_before_count FROM auth.failed_login_attempt_s;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', user_hk,
        'attempt_count', attempt_count,
        'last_attempt_time', last_attempt_time,
        'account_locked_until', account_locked_until,
        'load_date', load_date,
        'load_end_date', load_end_date
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.failed_login_attempt_s 
          WHERE user_hk = (SELECT user_hk FROM auth.user_s WHERE email = v_test_email LIMIT 1)
          ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'BEFORE Login', 'auth.failed_login_attempt_s', 'COUNT', v_before_count, v_sample_data, 'Failed Login Tracking');

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
        'user_hk', user_hk,
        'load_date', load_date,
        'record_source', record_source
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_h ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'AFTER Login', 'auth.user_h', 'COUNT', v_after_count, v_sample_data, 'User Hub - Check for new records');

    -- Capture auth.user_s (User Satellite) - AFTER
    SELECT COUNT(*) INTO v_after_count FROM auth.user_s;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', user_hk,
        'email', email,
        'load_date', load_date,
        'load_end_date', load_end_date
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_s WHERE email = v_test_email ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'AFTER Login', 'auth.user_s', 'COUNT', v_after_count, v_sample_data, 'User Satellite - Check for updates');

    -- Capture auth.user_credential_s (Password Satellite) - AFTER
    SELECT COUNT(*) INTO v_after_count FROM auth.user_credential_s;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', user_hk,
        'load_date', load_date,
        'load_end_date', load_end_date,
        'password_hash_length', LENGTH(password_hash)
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.user_credential_s 
          WHERE user_hk = (SELECT user_hk FROM auth.user_s WHERE email = v_test_email LIMIT 1)
          ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'AFTER Login', 'auth.user_credential_s', 'COUNT', v_after_count, v_sample_data, 'User Credentials - Check for changes');

    -- Capture auth.session_state_s (Sessions) - AFTER
    SELECT COUNT(*) INTO v_after_count FROM auth.session_state_s;
    SELECT jsonb_agg(jsonb_build_object(
        'session_hk', session_hk,
        'user_hk', user_hk,
        'session_token_hash', LEFT(session_token_hash, 10) || '...',
        'load_date', load_date,
        'load_end_date', load_end_date,
        'is_active', is_active
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.session_state_s 
          WHERE user_hk = (SELECT user_hk FROM auth.user_s WHERE email = v_test_email LIMIT 1)
          ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'AFTER Login', 'auth.session_state_s', 'COUNT', v_after_count, v_sample_data, 'Session State - Look for new sessions');

    -- Capture raw.login_attempt (Login Attempts) - AFTER
    SELECT COUNT(*) INTO v_after_count FROM raw.login_attempt;
    SELECT jsonb_agg(jsonb_build_object(
        'attempt_id', attempt_id,
        'email', email,
        'ip_address', ip_address,
        'attempt_time', attempt_time,
        'success', success,
        'failure_reason', failure_reason
    )) INTO v_sample_data
    FROM (SELECT * FROM raw.login_attempt 
          WHERE email = v_test_email 
          ORDER BY attempt_time DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'AFTER Login', 'raw.login_attempt', 'COUNT', v_after_count, v_sample_data, 'Raw Login Attempts - Should have new record');

    -- Capture auth.failed_login_attempt_s (Failed Attempts) - AFTER
    SELECT COUNT(*) INTO v_after_count FROM auth.failed_login_attempt_s;
    SELECT jsonb_agg(jsonb_build_object(
        'user_hk', user_hk,
        'attempt_count', attempt_count,
        'last_attempt_time', last_attempt_time,
        'account_locked_until', account_locked_until,
        'load_date', load_date,
        'load_end_date', load_end_date
    )) INTO v_sample_data
    FROM (SELECT * FROM auth.failed_login_attempt_s 
          WHERE user_hk = (SELECT user_hk FROM auth.user_s WHERE email = v_test_email LIMIT 1)
          ORDER BY load_date DESC LIMIT 3) sub;
    
    INSERT INTO temp_login_trace_log 
    (step_order, step_name, table_name, action, record_count, sample_data, notes)
    VALUES 
    (v_step, 'AFTER Login', 'auth.failed_login_attempt_s', 'COUNT', v_after_count, v_sample_data, 'Failed Login Tracking - Check for updates');

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

-- Recent login attempts
SELECT 'RECENT LOGIN ATTEMPTS:' as section;
SELECT 
    attempt_id,
    email,
    ip_address,
    attempt_time,
    success,
    failure_reason,
    user_agent
FROM raw.login_attempt 
WHERE email = 'travisdwoodward72@gmail.com'
ORDER BY attempt_time DESC 
LIMIT 5;

-- Recent sessions
SELECT 'RECENT SESSIONS:' as section;
SELECT 
    s.session_hk,
    u.email,
    s.session_token_hash,
    s.load_date,
    s.load_end_date,
    s.is_active,
    s.expires_at
FROM auth.session_state_s s
JOIN auth.user_s u ON s.user_hk = u.user_hk
WHERE u.email = 'travisdwoodward72@gmail.com'
  AND u.load_end_date IS NULL
ORDER BY s.load_date DESC
LIMIT 5;

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
            SELECT record_count FROM temp_login_trace_log 
            WHERE table_name = 'auth.session_state_s' 
            AND step_name = 'BEFORE Login'
        )
    ) INTO v_session_created;
    
    -- Check if attempt was logged
    SELECT EXISTS(
        SELECT 1 FROM temp_login_trace_log 
        WHERE table_name = 'raw.login_attempt' 
        AND step_name = 'AFTER Login' 
        AND record_count > (
            SELECT record_count FROM temp_login_trace_log 
            WHERE table_name = 'raw.login_attempt' 
            AND step_name = 'BEFORE Login'
        )
    ) INTO v_attempt_logged;
    
    -- Check if audit was logged
    SELECT EXISTS(
        SELECT 1 FROM temp_login_trace_log 
        WHERE table_name = 'audit.user_action_log' 
        AND step_name = 'AFTER Login' 
        AND record_count > (
            SELECT record_count FROM temp_login_trace_log 
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
    
END;
$$; 