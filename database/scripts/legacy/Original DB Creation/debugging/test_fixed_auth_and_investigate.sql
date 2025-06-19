-- =============================================
-- 🧪 TEST FIXED AUTH API AND INVESTIGATE ROLES
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TESTING FIXED AUTHENTICATION API...';
    RAISE NOTICE '';
END $$;

-- Test the fixed authentication
SELECT api.test_auth_with_roles(); 