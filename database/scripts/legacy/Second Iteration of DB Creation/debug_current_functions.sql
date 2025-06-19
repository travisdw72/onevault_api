-- =============================================
-- Function Diagnostic Script
-- Identifies current authentication functions and their signatures
-- =============================================

DO $$
DECLARE
    rec RECORD;
    v_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'AUTHENTICATION FUNCTION DIAGNOSTIC';
    RAISE NOTICE '==============================================';
    
    -- =============================================
    -- Check raw.capture_login_attempt versions
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- raw.capture_login_attempt Function Analysis ---';
    
    SELECT COUNT(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'raw' AND p.proname = 'capture_login_attempt';
    
    RAISE NOTICE 'Found % version(s) of raw.capture_login_attempt', v_count;
    
    FOR rec IN 
        SELECT 
            p.oid,
            pg_get_function_arguments(p.oid) as arguments,
            pg_get_function_result(p.oid) as return_type,
            array_length(p.proargtypes, 1) as param_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'raw' AND p.proname = 'capture_login_attempt'
        ORDER BY p.oid
    LOOP
        RAISE NOTICE '   Parameters: %', rec.arguments;
        RAISE NOTICE '   Return Type: %', rec.return_type;
        RAISE NOTICE '   Param Count: %', COALESCE(rec.param_count, 0);
        RAISE NOTICE '   ---';
    END LOOP;
    
    -- =============================================
    -- Check auth.process_failed_login
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- auth.process_failed_login Function Analysis ---';
    
    SELECT COUNT(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth' AND p.proname = 'process_failed_login';
    
    IF v_count > 0 THEN
        RAISE NOTICE 'Found % version(s) of auth.process_failed_login', v_count;
        
        FOR rec IN 
            SELECT 
                p.oid,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'auth' AND p.proname = 'process_failed_login'
            ORDER BY p.oid
        LOOP
            RAISE NOTICE '   Parameters: %', rec.arguments;
            RAISE NOTICE '   Return Type: %', rec.return_type;
            RAISE NOTICE '   ---';
        END LOOP;
    ELSE
        RAISE NOTICE '❌ auth.process_failed_login NOT FOUND';
    END IF;
    
    -- =============================================
    -- Check auth.create_session_with_token
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- auth.create_session_with_token Function Analysis ---';
    
    SELECT COUNT(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth' AND p.proname = 'create_session_with_token';
    
    IF v_count > 0 THEN
        RAISE NOTICE 'Found % version(s) of auth.create_session_with_token', v_count;
        
        FOR rec IN 
            SELECT 
                p.oid,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'auth' AND p.proname = 'create_session_with_token'
            ORDER BY p.oid
        LOOP
            RAISE NOTICE '   Parameters: %', rec.arguments;
            RAISE NOTICE '   Return Type: %', rec.return_type;
            RAISE NOTICE '   ---';
        END LOOP;
    ELSE
        RAISE NOTICE '❌ auth.create_session_with_token NOT FOUND';
    END IF;
    
    -- =============================================
    -- Check api.auth_login
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- api.auth_login Function Analysis ---';
    
    SELECT COUNT(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'api' AND p.proname = 'auth_login';
    
    IF v_count > 0 THEN
        RAISE NOTICE 'Found % version(s) of api.auth_login', v_count;
        
        FOR rec IN 
            SELECT 
                p.oid,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api' AND p.proname = 'auth_login'
            ORDER BY p.oid
        LOOP
            RAISE NOTICE '   Parameters: %', rec.arguments;
            RAISE NOTICE '   Return Type: %', rec.return_type;
            RAISE NOTICE '   ---';
        END LOOP;
    ELSE
        RAISE NOTICE '❌ api.auth_login NOT FOUND';
    END IF;
    
    -- =============================================
    -- Check current table structure
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Current Table Structure ---';
    
    -- Check auth schema tables
    RAISE NOTICE 'AUTH SCHEMA TABLES:';
    FOR rec IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'auth' 
        AND table_type = 'BASE TABLE'
        ORDER BY table_name
    LOOP
        RAISE NOTICE '   auth.%', rec.table_name;
    END LOOP;
    
    -- Check raw schema tables
    RAISE NOTICE '';
    RAISE NOTICE 'RAW SCHEMA TABLES:';
    FOR rec IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'raw' 
        AND table_type = 'BASE TABLE'
        ORDER BY table_name
    LOOP
        RAISE NOTICE '   raw.%', rec.table_name;
    END LOOP;
    
    -- =============================================
    -- Test basic user lookup
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Current User Data Check ---';
    
    SELECT COUNT(*) INTO v_count FROM auth.user_h;
    RAISE NOTICE 'Users in auth.user_h: %', v_count;
    
    SELECT COUNT(*) INTO v_count FROM auth.user_auth_s WHERE load_end_date IS NULL;
    RAISE NOTICE 'Active user auth records: %', v_count;
    
    -- Check for our test user
    SELECT COUNT(*) INTO v_count 
    FROM auth.user_auth_s 
    WHERE username = 'travisdwoodward72@gmail.com' 
    AND load_end_date IS NULL;
    
    IF v_count > 0 THEN
        RAISE NOTICE '✅ Test user "travisdwoodward72@gmail.com" found: % records', v_count;
        
        -- Get some details
        FOR rec IN 
            SELECT 
                encode(uas.user_hk, 'hex') as user_hk,
                uas.account_locked,
                COALESCE(uas.failed_login_attempts, 0) as failed_attempts,
                uas.load_date
            FROM auth.user_auth_s uas
            WHERE uas.username = 'travisdwoodward72@gmail.com'
            AND uas.load_end_date IS NULL
            ORDER BY uas.load_date DESC
        LOOP
            RAISE NOTICE '   User HK: %', rec.user_hk;
            RAISE NOTICE '   Account Locked: %', rec.account_locked;
            RAISE NOTICE '   Failed Attempts: %', rec.failed_attempts;
            RAISE NOTICE '   Load Date: %', rec.load_date;
        END LOOP;
    ELSE
        RAISE NOTICE '❌ Test user "travisdwoodward72@gmail.com" NOT FOUND';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'DIAGNOSTIC COMPLETE';
    RAISE NOTICE '==============================================';
    
END $$; 