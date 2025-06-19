-- =============================================
-- Check api.auth_login Function Signature
-- Find the correct parameters and test it properly
-- =============================================

DO $$
DECLARE
    v_function_info RECORD;
    v_tenant_hk BYTEA;
    v_test_username TEXT := 'travisdwoodward72@gmail.com';
    v_test_password TEXT := 'MyNewSecurePassword123';
    v_test_ip INET := '192.168.1.100';
    v_test_user_agent TEXT := 'Test-Authentication-Suite/1.0';
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'CHECKING api.auth_login FUNCTION SIGNATURE';
    RAISE NOTICE '==============================================';
    
    -- Check if the function exists and get its signature
    FOR v_function_info IN
        SELECT 
            p.proname as function_name,
            pg_catalog.pg_get_function_arguments(p.oid) as arguments,
            pg_catalog.pg_get_function_result(p.oid) as return_type,
            p.pronargs as num_args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' 
        AND p.proname = 'auth_login'
    LOOP
        RAISE NOTICE 'Found function: %.%()', v_function_info.function_name, v_function_info.arguments;
        RAISE NOTICE 'Return type: %', v_function_info.return_type;
        RAISE NOTICE 'Number of arguments: %', v_function_info.num_args;
    END LOOP;
    
    -- Get tenant HK for testing
    SELECT uh.tenant_hk INTO v_tenant_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_test_username
    AND uas.load_end_date IS NULL
    LIMIT 1;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Testing with tenant HK: %', encode(v_tenant_hk, 'hex');
    
    -- =============================================
    -- TEST DIFFERENT FUNCTION CALL APPROACHES
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Testing Different Function Call Methods ---';
    
    -- Method 1: Try with explicit parameter names
    BEGIN
        RAISE NOTICE 'Method 1: Testing with explicit parameter casting...';
        
        DECLARE
            v_result RECORD;
        BEGIN
            SELECT * INTO v_result FROM api.auth_login(
                v_tenant_hk::BYTEA,
                v_test_username::VARCHAR(255),
                v_test_password::VARCHAR(255),
                v_test_ip::INET,
                v_test_user_agent::TEXT
            );
            
            RAISE NOTICE '✅ Method 1 SUCCESS: Function called successfully';
            RAISE NOTICE 'Result columns: %', v_result;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Method 1 FAILED: % - %', SQLSTATE, SQLERRM;
        END;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Method 1 ERROR: % - %', SQLSTATE, SQLERRM;
    END;
    
    -- Method 2: Try with table-valued function approach
    BEGIN
        RAISE NOTICE '';
        RAISE NOTICE 'Method 2: Testing table-valued function approach...';
        
        DECLARE
            v_success BOOLEAN;
            v_message TEXT;
            v_token TEXT;
            v_user_data JSONB;
        BEGIN
            SELECT 
                p_success,
                p_message,
                p_session_token,
                p_user_data
            INTO 
                v_success,
                v_message,
                v_token,
                v_user_data
            FROM api.auth_login(
                v_tenant_hk,
                v_test_username,
                v_test_password,
                v_test_ip,
                v_test_user_agent
            );
            
            RAISE NOTICE '✅ Method 2 SUCCESS: Function called successfully';
            RAISE NOTICE 'Success: %, Message: %', v_success, v_message;
            RAISE NOTICE 'Token: %...', left(COALESCE(v_token, 'NULL'), 20);
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Method 2 FAILED: % - %', SQLSTATE, SQLERRM;
        END;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Method 2 ERROR: % - %', SQLSTATE, SQLERRM;
    END;
    
    -- Method 3: Try with different parameter types
    BEGIN
        RAISE NOTICE '';
        RAISE NOTICE 'Method 3: Testing with string IP address...';
        
        DECLARE
            v_result RECORD;
        BEGIN
            SELECT * INTO v_result FROM api.auth_login(
                v_tenant_hk,
                v_test_username,
                v_test_password,
                v_test_ip::TEXT,
                v_test_user_agent
            );
            
            RAISE NOTICE '✅ Method 3 SUCCESS: Function called successfully';
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Method 3 FAILED: % - %', SQLSTATE, SQLERRM;
        END;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Method 3 ERROR: % - %', SQLSTATE, SQLERRM;
    END;
    
    -- =============================================
    -- MANUAL FUNCTION CALL TEST
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Manual Function Call Test ---';
    
    BEGIN
        RAISE NOTICE 'Attempting manual function call with known parameters...';
        
        -- Try calling the function as we know it should work
        DECLARE
            v_login_result RECORD;
        BEGIN
            -- Direct SQL call
            EXECUTE format(
                'SELECT * FROM api.auth_login($1, $2, $3, $4, $5)'
            ) INTO v_login_result
            USING v_tenant_hk, v_test_username, v_test_password, v_test_ip, v_test_user_agent;
            
            RAISE NOTICE '✅ Manual call SUCCESS: %', v_login_result;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Manual call FAILED: % - %', SQLSTATE, SQLERRM;
        END;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Manual call ERROR: % - %', SQLSTATE, SQLERRM;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'FUNCTION SIGNATURE INVESTIGATION COMPLETE';
    RAISE NOTICE 'Check the successful method above for the correct calling syntax';
    RAISE NOTICE '==============================================';
    
END $$; 