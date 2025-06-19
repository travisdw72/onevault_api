-- Quick test to check password management API functions
DO $$
DECLARE
    v_test_result JSONB;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔍 QUICK PASSWORD API AVAILABILITY TEST';
    RAISE NOTICE '====================================';
    RAISE NOTICE '';
    
    -- Check if api.change_password exists
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' AND p.proname = 'change_password'
    ) THEN
        RAISE NOTICE '✅ api.change_password() - EXISTS';
    ELSE
        RAISE NOTICE '❌ api.change_password() - MISSING';
    END IF;
    
    -- Check if api.admin_reset_password exists
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' AND p.proname = 'admin_reset_password'
    ) THEN
        RAISE NOTICE '✅ api.admin_reset_password() - EXISTS';
    ELSE
        RAISE NOTICE '❌ api.admin_reset_password() - MISSING';
    END IF;
    
    -- Check if api.forgot_password_request exists
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' AND p.proname = 'forgot_password_request'
    ) THEN
        RAISE NOTICE '✅ api.forgot_password_request() - EXISTS';
    ELSE
        RAISE NOTICE '❌ api.forgot_password_request() - MISSING';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TESTING API CALLS WITH INVALID DATA (Expected to fail gracefully)';
    RAISE NOTICE '';
    
    -- Test 1: api.change_password with missing parameters
    BEGIN
        SELECT api.change_password(jsonb_build_object()) INTO v_test_result;
        RAISE NOTICE '✅ api.change_password() responds to empty request: %', v_test_result->>'message';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ api.change_password() error: %', SQLERRM;
    END;
    
    -- Test 2: api.admin_reset_password with missing parameters
    BEGIN
        SELECT api.admin_reset_password(jsonb_build_object()) INTO v_test_result;
        RAISE NOTICE '✅ api.admin_reset_password() responds to empty request: %', v_test_result->>'message';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ api.admin_reset_password() error: %', SQLERRM;
    END;
    
    -- Test 3: api.forgot_password_request with missing parameters
    BEGIN
        SELECT api.forgot_password_request(jsonb_build_object()) INTO v_test_result;
        RAISE NOTICE '✅ api.forgot_password_request() responds to empty request: %', v_test_result->>'message';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ api.forgot_password_request() error: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 FRONTEND INTEGRATION STATUS:';
    
    -- Count available functions
    DECLARE
        v_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' AND p.proname IN ('change_password', 'admin_reset_password', 'forgot_password_request');
        
        RAISE NOTICE '   Available Password APIs: %/3', v_count;
        
        IF v_count = 3 THEN
            RAISE NOTICE '   🎉 All password management APIs are ready for frontend integration!';
            RAISE NOTICE '';
            RAISE NOTICE '📝 API ENDPOINTS READY:';
            RAISE NOTICE '   POST /api/v1/auth/change-password';
            RAISE NOTICE '   POST /api/v1/auth/admin/reset-password';
            RAISE NOTICE '   POST /api/v1/auth/forgot-password';
        ELSE
            RAISE NOTICE '   ⚠️  Some password APIs are missing - need to implement missing functions';
        END IF;
    END;
    
    RAISE NOTICE '';

END $$; 