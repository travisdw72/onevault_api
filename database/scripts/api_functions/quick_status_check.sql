-- =============================================
-- Quick Status Check for onevault_api_full Role
-- Run this to verify the role was created successfully
-- =============================================

-- 1. Check if role exists and can login
SELECT 
    CASE 
        WHEN EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'onevault_api_full' AND rolcanlogin = true) 
        THEN '✅ SUCCESS: Role exists and can login' 
        WHEN EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'onevault_api_full' AND rolcanlogin = false)
        THEN '⚠️ PARTIAL: Role exists but cannot login'
        ELSE '❌ FAILED: Role does not exist' 
    END as role_status;

-- 2. Count total permissions (should be 100+)
SELECT 
    COUNT(*) as total_permissions,
    COUNT(DISTINCT table_schema) as schemas_with_access,
    CASE 
        WHEN COUNT(*) >= 100 THEN '✅ SUCCESS: Comprehensive permissions granted'
        WHEN COUNT(*) >= 50 THEN '⚠️ PARTIAL: Some permissions granted'
        WHEN COUNT(*) > 0 THEN '⚠️ LIMITED: Few permissions granted'
        ELSE '❌ FAILED: No permissions granted'
    END as permission_status
FROM information_schema.table_privileges 
WHERE grantee = 'onevault_api_full';

-- 3. Check critical schemas have access
SELECT 
    'Critical Schema Access' as check_type,
    string_agg(
        CASE 
            WHEN schema_permissions.schema_name IS NOT NULL THEN '✅ ' || critical_schemas.schema_name
            ELSE '❌ ' || critical_schemas.schema_name
        END, 
        ', ' 
        ORDER BY critical_schemas.schema_name
    ) as schema_status
FROM (
    VALUES ('auth'), ('business'), ('audit'), ('util'), ('ref')
) AS critical_schemas(schema_name)
LEFT JOIN (
    SELECT DISTINCT table_schema as schema_name
    FROM information_schema.table_privileges 
    WHERE grantee = 'onevault_api_full'
) AS schema_permissions ON critical_schemas.schema_name = schema_permissions.schema_name;

-- 4. Overall status summary
DO $$
DECLARE
    v_role_exists BOOLEAN;
    v_can_login BOOLEAN;
    v_total_permissions INTEGER;
    v_critical_schemas INTEGER;
    v_status TEXT;
BEGIN
    -- Check role existence and login capability
    SELECT 
        EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'onevault_api_full'),
        EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'onevault_api_full' AND rolcanlogin = true)
    INTO v_role_exists, v_can_login;
    
    -- Count permissions
    SELECT COUNT(*) INTO v_total_permissions
    FROM information_schema.table_privileges 
    WHERE grantee = 'onevault_api_full';
    
    -- Count critical schemas with access
    SELECT COUNT(*) INTO v_critical_schemas
    FROM (
        SELECT DISTINCT table_schema
        FROM information_schema.table_privileges 
        WHERE grantee = 'onevault_api_full'
        AND table_schema IN ('auth', 'business', 'audit', 'util', 'ref')
    ) AS critical_access;
    
    -- Determine overall status
    IF v_role_exists AND v_can_login AND v_total_permissions >= 100 AND v_critical_schemas >= 4 THEN
        v_status := '🎉 SUCCESS: API Role fully configured and ready for production!';
    ELSIF v_role_exists AND v_can_login AND v_total_permissions >= 50 THEN
        v_status := '⚠️ PARTIAL: API Role created but may need additional permissions';
    ELSIF v_role_exists THEN
        v_status := '⚠️ INCOMPLETE: API Role exists but not properly configured';
    ELSE
        v_status := '❌ FAILED: API Role was not created';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍 QUICK STATUS CHECK RESULTS';
    RAISE NOTICE '===============================';
    RAISE NOTICE 'Role exists: %', CASE WHEN v_role_exists THEN 'YES' ELSE 'NO' END;
    RAISE NOTICE 'Can login: %', CASE WHEN v_can_login THEN 'YES' ELSE 'NO' END;
    RAISE NOTICE 'Total permissions: %', v_total_permissions;
    RAISE NOTICE 'Critical schemas: %/5', v_critical_schemas;
    RAISE NOTICE '';
    RAISE NOTICE '%', v_status;
    
    IF v_role_exists AND v_can_login AND v_total_permissions >= 100 THEN
        RAISE NOTICE '';
        RAISE NOTICE '📋 NEXT STEPS:';
        RAISE NOTICE '   1. Update API connection string to use: onevault_api_full';
        RAISE NOTICE '   2. Change password from default before production';
        RAISE NOTICE '   3. Your existing token still works: ovt_prod_cf70c68c...';
        RAISE NOTICE '   4. Token auto-extension is now active';
    ELSIF v_role_exists THEN
        RAISE NOTICE '';
        RAISE NOTICE '🔧 RECOMMENDED ACTION:';
        RAISE NOTICE '   Run create_full_api_role_FIXED.sql to complete setup';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '🔧 REQUIRED ACTION:';
        RAISE NOTICE '   Run create_full_api_role_FIXED.sql to create the role';
    END IF;
    RAISE NOTICE '';
END $$;