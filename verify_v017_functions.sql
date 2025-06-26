-- =============================================================================
-- V017 Function Verification Script
-- =============================================================================
-- Quick check to verify V017 functions were created correctly
-- =============================================================================

\echo '🔍 V017 FUNCTION VERIFICATION'
\echo '============================='

-- Check if auth.login_user_secure procedure exists
SELECT 
    'auth.login_user_secure' as function_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'auth' 
            AND p.proname = 'login_user_secure'
            AND p.prokind = 'p'  -- procedure
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status,
    'PROCEDURE' as type;

-- Check if api.auth_login function exists
SELECT 
    'api.auth_login' as function_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api' 
            AND p.proname = 'auth_login'
            AND p.prokind = 'f'  -- function
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status,
    'FUNCTION' as type;

-- Check if auth.resolve_tenant_from_token function exists
SELECT 
    'auth.resolve_tenant_from_token' as function_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'auth' 
            AND p.proname = 'resolve_tenant_from_token'
            AND p.prokind = 'f'  -- function
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status,
    'FUNCTION' as type;

-- Check migration log
SELECT 
    'V017 Migration Log' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM util.migration_log 
            WHERE migration_version = 'V017' 
            AND status = 'SUCCESS'
        ) THEN '✅ COMPLETED'
        ELSE '❌ NOT FOUND'
    END as status,
    'MIGRATION' as type;

-- Check audit tables exist
SELECT 
    'audit.auth_success_s' as table_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'audit' 
            AND table_name = 'auth_success_s'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status,
    'TABLE' as type;

SELECT 
    'audit.auth_failure_s' as table_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'audit' 
            AND table_name = 'auth_failure_s'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status,
    'TABLE' as type;

\echo ''
\echo '🎯 VERIFICATION SUMMARY:'
\echo '========================'
\echo 'All items above should show ✅ EXISTS/COMPLETED'
\echo 'If any show ❌, the V017 migration may have failed' 