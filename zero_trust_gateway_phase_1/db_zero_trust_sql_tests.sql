-- =============================================
-- DATABASE DISCOVERY QUERIES
-- Run these to help me understand your actual system
-- =============================================

-- SECTION 1: TABLE STRUCTURES
-- =============================================

-- 1.1: Core Auth Tables Structure
SELECT 'auth.user_h structure:' as info;
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'user_h';

SELECT 'auth.user_auth_s structure:' as info;
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'user_auth_s';

SELECT 'auth.user_role_l structure:' as info;
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'user_role_l';

SELECT 'auth.tenant_h structure:' as info;
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'tenant_h';

SELECT 'auth.tenant_definition_s structure:' as info;
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'tenant_definition_s';

SELECT 'auth.api_token_h structure:' as info;
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'api_token_h';

SELECT 'auth.api_token_s structure:' as info;
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'api_token_s';

-- 1.2: Check what other auth tables exist
SELECT 'All auth schema tables:' as info;
SELECT schemaname, tablename, tableowner 
FROM pg_tables 
WHERE schemaname = 'auth' 
ORDER BY tablename;

-- SECTION 2: UTILITY FUNCTIONS
-- =============================================

-- 2.1: Test utility functions
SELECT 'Testing util functions:' as info;
SELECT 
    util.current_load_date() as current_load_date,
    util.get_record_source() as record_source;

SELECT util.hash_binary('test_string') as hash_binary_test;

-- 2.2: Check what util functions exist
SELECT 'All util schema functions:' as info;
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'util' 
ORDER BY routine_name;

-- SECTION 3: CURRENT DATA RELATIONSHIPS
-- =============================================

-- 3.1: Sample user data (with tenant relationships)
SELECT 'Sample user-tenant relationships:' as info;
SELECT 
    encode(uh.user_hk, 'hex') as user_hk,
    encode(uh.tenant_hk, 'hex') as primary_tenant_hk,
    uas.username,
    td.tenant_name as primary_tenant_name
FROM auth.user_h uh
JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
LEFT JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
LEFT JOIN auth.tenant_definition_s td ON th.tenant_hk = td.tenant_hk
WHERE uas.load_end_date IS NULL
AND (td.load_end_date IS NULL OR td.load_end_date IS NULL)
LIMIT 5;

-- 3.2: User role relationships
SELECT 'Sample user roles across tenants:' as info;
SELECT 
    encode(url.user_hk, 'hex') as user_hk,
    encode(url.tenant_hk, 'hex') as role_tenant_hk,
    encode(url.role_hk, 'hex') as role_hk,
    td.tenant_name,
    rd.role_name
FROM auth.user_role_l url
JOIN auth.tenant_h th ON url.tenant_hk = th.tenant_hk
JOIN auth.tenant_definition_s td ON th.tenant_hk = td.tenant_hk
LEFT JOIN auth.role_h rh ON url.role_hk = rh.role_hk
LEFT JOIN auth.role_definition_s rd ON rh.role_hk = rd.role_hk
WHERE td.load_end_date IS NULL
AND (rd.load_end_date IS NULL OR rd.load_end_date IS NULL)
LIMIT 10;

-- 3.3: API Token relationships
SELECT 'Sample API token relationships:' as info;
SELECT 
    encode(ath.api_token_hk, 'hex') as token_hk,
    encode(ath.tenant_hk, 'hex') as token_tenant_hk,
    ats.token_type,
    ats.expires_at,
    ats.is_revoked,
    td.tenant_name as token_tenant_name
FROM auth.api_token_h ath
JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk
LEFT JOIN auth.tenant_h th ON ath.tenant_hk = th.tenant_hk
LEFT JOIN auth.tenant_definition_s td ON th.tenant_hk = td.tenant_hk
WHERE ats.load_end_date IS NULL
AND (td.load_end_date IS NULL OR td.load_end_date IS NULL)
LIMIT 5;

-- SECTION 4: EXISTING AUTHENTICATION FUNCTIONS
-- =============================================

-- 4.1: List all auth functions
SELECT 'All auth schema functions:' as info;
SELECT 
    routine_name, 
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'auth' 
ORDER BY routine_name;

-- 4.2: List all api functions
SELECT 'All api schema functions:' as info;
SELECT 
    routine_name, 
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'api' 
ORDER BY routine_name;

-- 4.3: Get the current login function definition
SELECT 'Current api.auth_login function:' as info;
SELECT pg_get_functiondef(
    (SELECT oid FROM pg_proc 
     WHERE proname = 'auth_login' 
     AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'api')
     LIMIT 1)
);

-- 4.4: Get the current token validation function definition  
SELECT 'Current auth.validate_production_api_token function:' as info;
SELECT pg_get_functiondef(
    (SELECT oid FROM pg_proc 
     WHERE proname = 'validate_production_api_token' 
     AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')
     LIMIT 1)
);

-- SECTION 5: TENANT ISOLATION ANALYSIS
-- =============================================

-- 5.1: Count users per tenant
SELECT 'Users per tenant:' as info;
SELECT 
    encode(th.tenant_hk, 'hex') as tenant_hk,
    td.tenant_name,
    COUNT(uh.user_hk) as user_count
FROM auth.tenant_h th
JOIN auth.tenant_definition_s td ON th.tenant_hk = td.tenant_hk
LEFT JOIN auth.user_h uh ON th.tenant_hk = uh.tenant_hk
WHERE td.load_end_date IS NULL
GROUP BY th.tenant_hk, td.tenant_name
ORDER BY user_count DESC;

-- 5.2: Users with multiple tenant access
SELECT 'Users with multiple tenant access:' as info;
SELECT 
    encode(url.user_hk, 'hex') as user_hk,
    uas.username,
    COUNT(DISTINCT url.tenant_hk) as tenant_count,
    array_agg(DISTINCT td.tenant_name) as tenant_names
FROM auth.user_role_l url
JOIN auth.user_auth_s uas ON url.user_hk = uas.user_hk
JOIN auth.tenant_h th ON url.tenant_hk = th.tenant_hk
JOIN auth.tenant_definition_s td ON th.tenant_hk = td.tenant_hk
WHERE uas.load_end_date IS NULL
AND td.load_end_date IS NULL
GROUP BY url.user_hk, uas.username
HAVING COUNT(DISTINCT url.tenant_hk) > 1
LIMIT 10;

-- 5.3: Check if user_h.tenant_hk matches user_role_l.tenant_hk
SELECT 'Tenant consistency check:' as info;
SELECT 
    'Consistent user-tenant relationships' as check_type,
    COUNT(*) as count
FROM auth.user_h uh
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
WHERE uh.tenant_hk = url.tenant_hk

UNION ALL

SELECT 
    'Inconsistent user-tenant relationships' as check_type,
    COUNT(*) as count
FROM auth.user_h uh
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
WHERE uh.tenant_hk != url.tenant_hk;

-- SECTION 6: CURRENT AUTHENTICATION TESTING
-- =============================================

-- 6.1: Test current login function (if it exists)
SELECT 'Testing current login function:' as info;
-- Note: This is a safe test that won't actually create a session
SELECT routine_name, routine_type
FROM information_schema.routines 
WHERE routine_schema = 'api' 
AND routine_name LIKE '%login%';

-- 6.2: Test current token validation (if function exists)
SELECT 'Testing current token validation:' as info;
SELECT routine_name, routine_type
FROM information_schema.routines 
WHERE routine_schema = 'auth' 
AND routine_name LIKE '%validate%token%';

-- SECTION 7: AUDIT AND LOGGING CAPABILITIES
-- =============================================

-- 7.1: Check audit schema
SELECT 'Audit schema tables:' as info;
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname = 'audit' 
ORDER BY tablename;

-- 7.2: Check if audit.log_security_event function exists
SELECT 'Security event logging function:' as info;
SELECT routine_name, routine_type
FROM information_schema.routines 
WHERE routine_schema = 'audit' 
AND routine_name LIKE '%security%event%';

-- SECTION 8: CURRENT PERMISSIONS
-- =============================================

-- 8.1: Current database roles
SELECT 'Database roles:' as info;
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin 
FROM pg_roles 
WHERE rolname IN ('postgres', 'neondb_owner', 'onevault_api_full', 'api_user')
OR rolname = current_user;

-- 8.2: Check current user permissions on auth schema
SELECT 'Current user auth permissions:' as info;
SELECT 
    schemaname,
    tablename,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE schemaname = 'auth'
AND grantee = current_user
ORDER BY tablename, privilege_type;