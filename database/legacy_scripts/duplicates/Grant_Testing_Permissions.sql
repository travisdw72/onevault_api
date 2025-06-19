-- ============================================================
-- GRANT TESTING PERMISSIONS FOR SECURITY TESTS
-- ============================================================
-- Purpose: Grant minimal permissions to onevault_readonly user for security testing
-- This allows testing without compromising production security

-- Grant access to the API schema and functions
GRANT USAGE ON SCHEMA api TO onevault_readonly;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO onevault_readonly;

-- Grant specific access to auth_login function (if it exists)
GRANT EXECUTE ON FUNCTION api.auth_login(jsonb) TO onevault_readonly;

-- Grant access to necessary tables for testing (read-only)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO onevault_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA api TO onevault_readonly;

-- Allow creation of temporary tables for test results
GRANT TEMP ON DATABASE the_one_spa_oregon TO onevault_readonly;

-- Check what functions are available in the api schema
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    p.prokind as function_type,
    p.proargnames as argument_names
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api'
  AND p.proname LIKE '%auth%'
ORDER BY p.proname;

-- Check if the auth_login function exists
SELECT 
    'Function api.auth_login exists: ' || 
    CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END as function_status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'api' AND p.proname = 'auth_login';

-- Show current permissions for onevault_readonly
SELECT 
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.table_privileges 
WHERE grantee = 'onevault_readonly'
ORDER BY table_schema, table_name; 