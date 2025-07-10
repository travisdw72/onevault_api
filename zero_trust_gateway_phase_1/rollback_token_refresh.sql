-- =============================================
-- ROLLBACK SCRIPT - Enhanced Token Refresh System
-- Safely removes all enhanced token refresh functions
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '🔄 Starting rollback of Enhanced Token Refresh System...';
END $$;

-- =============================================
-- Drop Enhanced Token Refresh Functions
-- =============================================

DO $$
BEGIN
    -- Drop the enhanced refresh function
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'auth' 
        AND p.proname = 'refresh_production_token_enhanced'
    ) THEN
        DROP FUNCTION auth.refresh_production_token_enhanced(TEXT, INTEGER, BOOLEAN);
        RAISE NOTICE '✅ Dropped function: auth.refresh_production_token_enhanced()';
    ELSE
        RAISE NOTICE '⚠️  Function auth.refresh_production_token_enhanced() not found';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error dropping refresh_production_token_enhanced: %', SQLERRM;
END $$;

DO $$
BEGIN
    -- Drop the token status function
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'auth' 
        AND p.proname = 'get_token_refresh_status'
    ) THEN
        DROP FUNCTION auth.get_token_refresh_status(TEXT);
        RAISE NOTICE '✅ Dropped function: auth.get_token_refresh_status()';
    ELSE
        RAISE NOTICE '⚠️  Function auth.get_token_refresh_status() not found';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error dropping get_token_refresh_status: %', SQLERRM;
END $$;

-- =============================================
-- Check for Compatible Version Functions (optional cleanup)
-- =============================================

DO $$
BEGIN
    -- Check if compatible version exists and offer to remove it
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'auth' 
        AND p.proname = 'refresh_production_token_compatible'
    ) THEN
        RAISE NOTICE '🔍 Found compatible version: auth.refresh_production_token_compatible()';
        RAISE NOTICE '💡 To remove compatible version too, run:';
        RAISE NOTICE '   DROP FUNCTION auth.refresh_production_token_compatible(TEXT, INTEGER, BOOLEAN);';
        RAISE NOTICE '   DROP FUNCTION auth.check_token_refresh_needed_compatible(TEXT, INTEGER);';
    END IF;
END $$;

-- =============================================
-- Verify Cleanup
-- =============================================

DO $$
DECLARE
    v_enhanced_exists BOOLEAN := false;
    v_status_exists BOOLEAN := false;
BEGIN
    -- Check if enhanced function still exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'auth' 
        AND p.proname = 'refresh_production_token_enhanced'
    ) INTO v_enhanced_exists;
    
    -- Check if status function still exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'auth' 
        AND p.proname = 'get_token_refresh_status'
    ) INTO v_status_exists;
    
    IF NOT v_enhanced_exists AND NOT v_status_exists THEN
        RAISE NOTICE '🎉 Rollback completed successfully!';
        RAISE NOTICE '✅ All enhanced token refresh functions have been removed';
        RAISE NOTICE '📋 Your database is back to the previous state';
    ELSE
        RAISE NOTICE '⚠️  Rollback incomplete:';
        IF v_enhanced_exists THEN
            RAISE NOTICE '   - refresh_production_token_enhanced still exists';
        END IF;
        IF v_status_exists THEN
            RAISE NOTICE '   - get_token_refresh_status still exists';
        END IF;
    END IF;
END $$;

-- =============================================
-- Optional: Remove Compatible Version Too
-- =============================================

/*
-- Uncomment to also remove the compatible version functions:

DROP FUNCTION IF EXISTS auth.refresh_production_token_compatible(TEXT, INTEGER, BOOLEAN);
DROP FUNCTION IF EXISTS auth.check_token_refresh_needed_compatible(TEXT, INTEGER);

DO $$
BEGIN
    RAISE NOTICE '🧹 Compatible version functions also removed';
END $$;
*/

-- =============================================
-- Final Status
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '📊 Current token refresh functions in auth schema:';
    
    -- List remaining token-related functions
    FOR rec IN 
        SELECT p.proname as function_name
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'auth' 
        AND (p.proname LIKE '%token%' OR p.proname LIKE '%refresh%')
        ORDER BY p.proname
    LOOP
        RAISE NOTICE '   - %', rec.function_name;
    END LOOP;
    
    RAISE NOTICE '🔧 If you need to redeploy, run: token_refresh_enhanced_FIXED.sql';
END $$; 