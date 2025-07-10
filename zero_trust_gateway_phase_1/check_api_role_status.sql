-- =============================================
-- OneVault API Role Status Check
-- Run this to see current role status and permissions
-- =============================================

-- Check if the role exists
SELECT 
    'onevault_api_full' as role_name,
    CASE 
        WHEN EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'onevault_api_full') 
        THEN '✅ EXISTS' 
        ELSE '❌ MISSING' 
    END as role_status,
    CASE 
        WHEN EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'onevault_api_full' AND rolcanlogin = true) 
        THEN '✅ CAN LOGIN' 
        ELSE '❌ CANNOT LOGIN' 
    END as login_status;

-- Check role privileges
SELECT 
    rolname as role_name,
    rolsuper as is_superuser,
    rolcreaterole as can_create_roles,
    rolcreatedb as can_create_databases,
    rolcanlogin as can_login,
    rolreplication as replication_role
FROM pg_roles 
WHERE rolname = 'onevault_api_full';

-- Count permissions by schema
SELECT 
    table_schema as schema_name,
    COUNT(*) as permission_count,
    array_agg(DISTINCT privilege_type) as privilege_types
FROM information_schema.table_privileges 
WHERE grantee = 'onevault_api_full'
GROUP BY table_schema
ORDER BY table_schema;

-- Check function permissions
SELECT 
    routine_schema as schema_name,
    COUNT(*) as function_permission_count
FROM information_schema.routine_privileges 
WHERE grantee = 'onevault_api_full'
GROUP BY routine_schema
ORDER BY routine_schema;

-- Check active connections
SELECT 
    usename as username,
    COUNT(*) as active_connections,
    array_agg(DISTINCT state) as connection_states
FROM pg_stat_activity 
WHERE usename = 'onevault_api_full'
GROUP BY usename;

-- Overall status summary
DO $$
DECLARE
    v_role_exists BOOLEAN;
    v_total_permissions INTEGER;
    v_schema_count INTEGER;
BEGIN
    -- Check if role exists
    SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'onevault_api_full') INTO v_role_exists;
    
    IF v_role_exists THEN
        -- Count total permissions
        SELECT COUNT(*) INTO v_total_permissions
        FROM information_schema.table_privileges 
        WHERE grantee = 'onevault_api_full';
        
        SELECT COUNT(DISTINCT table_schema) INTO v_schema_count
        FROM information_schema.table_privileges 
        WHERE grantee = 'onevault_api_full';
        
        RAISE NOTICE '';
        RAISE NOTICE '🎯 CURRENT STATUS SUMMARY';
        RAISE NOTICE '=========================';
        RAISE NOTICE '✅ Role: onevault_api_full EXISTS';
        RAISE NOTICE '📊 Total permissions: %', v_total_permissions;
        RAISE NOTICE '📁 Schemas with access: %', v_schema_count;
        RAISE NOTICE '';
        
        IF v_total_permissions > 100 THEN
            RAISE NOTICE '🎉 STATUS: COMPREHENSIVE PERMISSIONS GRANTED';
            RAISE NOTICE '   Ready for production API use';
        ELSE
            RAISE NOTICE '⚠️  STATUS: LIMITED PERMISSIONS';
            RAISE NOTICE '   May need additional setup';
        END IF;
        
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '❌ Role onevault_api_full does NOT exist';
        RAISE NOTICE '💡 Run create_full_api_role_FIXED.sql to create it';
        RAISE NOTICE '';
    END IF;
END $$; 