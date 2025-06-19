-- ============================================================
-- TEST DATABASE FUNCTIONS AND PERMISSIONS
-- ============================================================
-- Purpose: Check what functions exist and test permissions

-- Check current user and database
SELECT 
    current_user as current_user,
    current_database() as current_database,
    session_user as session_user;

-- Check what schemas are available
SELECT schema_name 
FROM information_schema.schemata 
WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
ORDER BY schema_name;

-- Check what functions exist in api schema (if it exists)
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    pg_catalog.pg_get_function_arguments(p.oid) as arguments,
    pg_catalog.pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api'
ORDER BY p.proname;

-- Check if auth_login function exists specifically
SELECT 
    'Function api.auth_login exists: ' || 
    CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as function_status,
    COUNT(*) as function_count
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api' AND p.proname = 'auth_login';

-- Check current user's table privileges
SELECT 
    table_schema,
    table_name,
    privilege_type
FROM information_schema.table_privileges 
WHERE grantee = current_user
  AND table_schema IN ('api', 'auth', 'public')
ORDER BY table_schema, table_name, privilege_type;

-- Try a simple function call if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api' AND p.proname = 'auth_login'
    ) THEN
        RAISE NOTICE 'api.auth_login function exists - attempting test call';
        -- Could add a test call here if safe
    ELSE
        RAISE NOTICE 'api.auth_login function does not exist';
    END IF;
END $$; 