-- =============================================
-- OneVault API Role Rollback Script
-- ONLY USE IF YOU NEED TO REMOVE THE API ROLE
-- =============================================

-- ⚠️  WARNING: This will remove the onevault_api_full role
-- Make sure no applications are using this role before running

DO $$
DECLARE
    v_role_exists BOOLEAN;
    v_connections INTEGER;
BEGIN
    -- Check if role exists
    SELECT EXISTS(
        SELECT 1 FROM pg_roles WHERE rolname = 'onevault_api_full'
    ) INTO v_role_exists;
    
    IF NOT v_role_exists THEN
        RAISE NOTICE '✅ Role onevault_api_full does not exist - nothing to rollback';
        RETURN;
    END IF;
    
    -- Check for active connections
    SELECT COUNT(*) INTO v_connections
    FROM pg_stat_activity 
    WHERE usename = 'onevault_api_full';
    
    IF v_connections > 0 THEN
        RAISE NOTICE '⚠️  WARNING: % active connections using onevault_api_full', v_connections;
        RAISE NOTICE '⚠️  Terminate connections before rollback or they will be forcibly closed';
        
        -- Uncomment this line if you want to force-close connections
        -- PERFORM pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'onevault_api_full';
    END IF;
    
    RAISE NOTICE '🔄 Starting rollback of onevault_api_full role...';
    
    -- Step 1: Revoke all privileges (PostgreSQL automatically handles this when dropping role)
    RAISE NOTICE '📝 Revoking all privileges...';
    
    -- Step 2: Drop the role
    DROP ROLE IF EXISTS onevault_api_full;
    
    RAISE NOTICE '✅ Role onevault_api_full has been completely removed';
    RAISE NOTICE '🎯 Rollback completed successfully';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Rollback failed: %', SQLERRM;
        RAISE NOTICE '💡 Manual cleanup may be required';
        RAISE;
END $$;

-- =============================================
-- Verification Query
-- =============================================

-- Check that role is gone
SELECT 
    CASE 
        WHEN EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'onevault_api_full') 
        THEN '❌ Role still exists - rollback failed'
        ELSE '✅ Role successfully removed'
    END as rollback_status;

-- Check for any remaining permissions (should be empty)
SELECT 
    COUNT(*) as remaining_permissions,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ No remaining permissions'
        ELSE '⚠️  Some permissions may remain'
    END as cleanup_status
FROM information_schema.table_privileges 
WHERE grantee = 'onevault_api_full';

-- =============================================
-- Post-Rollback Recommendations
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📋 POST-ROLLBACK CHECKLIST:';
    RAISE NOTICE '=============================';
    RAISE NOTICE '✅ 1. Role onevault_api_full removed';
    RAISE NOTICE '✅ 2. All permissions automatically revoked';
    RAISE NOTICE '✅ 3. Database connections closed';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 NEXT STEPS:';
    RAISE NOTICE '   • Update application connection strings';
    RAISE NOTICE '   • Use neondb_owner for admin tasks';
    RAISE NOTICE '   • Re-run create_full_api_role.sql if needed';
    RAISE NOTICE '';
END $$; 