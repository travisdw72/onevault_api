-- =============================================
-- Secure API Role Creation for OneVault
-- Creates minimal-privilege role for token operations
-- =============================================

-- Step 1: Create the API role
CREATE ROLE onevault_api LOGIN;

-- Step 2: Set a secure password (change this!)
ALTER ROLE onevault_api PASSWORD 'CHANGE_THIS_SECURE_PASSWORD_123!';

-- Step 3: Grant minimal database access
GRANT CONNECT ON DATABASE "One_Vault" TO onevault_api;

-- Step 4: Grant schema access
GRANT USAGE ON SCHEMA auth TO onevault_api;
GRANT USAGE ON SCHEMA util TO onevault_api;

-- Step 5: Grant specific table permissions (read-only where possible)
GRANT SELECT ON auth.api_token_h TO onevault_api;
GRANT SELECT, INSERT, UPDATE ON auth.api_token_s TO onevault_api;
GRANT SELECT ON auth.user_token_l TO onevault_api;
GRANT SELECT ON auth.tenant_h TO onevault_api;

-- Step 6: Grant function execution permissions
GRANT EXECUTE ON FUNCTION auth.validate_production_api_token(TEXT, TEXT) TO onevault_api;
GRANT EXECUTE ON FUNCTION auth.validate_production_api_token(TEXT, TEXT, INET, TEXT, TEXT) TO onevault_api;
GRANT EXECUTE ON FUNCTION auth.validate_and_extend_production_token(TEXT, TEXT, INET, TEXT, TEXT, BOOLEAN, INTEGER, INTEGER) TO onevault_api;
GRANT EXECUTE ON FUNCTION auth.extend_token_expiration(TEXT, INTEGER, INTEGER) TO onevault_api;
GRANT EXECUTE ON FUNCTION auth.check_token_extension_needed(TEXT, INTEGER) TO onevault_api;
GRANT EXECUTE ON FUNCTION auth.api_extend_token(TEXT, INTEGER, INET, TEXT) TO onevault_api;
GRANT EXECUTE ON FUNCTION auth.get_token_extension_stats(BYTEA, INTEGER) TO onevault_api;

-- Step 7: Grant utility function access
GRANT EXECUTE ON FUNCTION util.current_load_date() TO onevault_api;
GRANT EXECUTE ON FUNCTION util.hash_binary(TEXT) TO onevault_api;
GRANT EXECUTE ON FUNCTION util.get_record_source() TO onevault_api;

-- Step 8: Grant audit table permissions (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'token_activity_s') THEN
        GRANT SELECT, INSERT ON auth.token_activity_s TO onevault_api;
        RAISE NOTICE '✅ Granted permissions on token_activity_s audit table';
    ELSE
        RAISE NOTICE '⚠️  token_activity_s table not found - audit permissions skipped';
    END IF;
END $$;

-- Step 9: Security verification
DO $$
DECLARE
    v_role_info RECORD;
BEGIN
    SELECT 
        rolname,
        rolsuper,
        rolcreaterole,
        rolcreatedb,
        rolcanlogin,
        rolreplication
    INTO v_role_info
    FROM pg_roles 
    WHERE rolname = 'onevault_api';
    
    RAISE NOTICE '🔍 Security Verification for onevault_api:';
    RAISE NOTICE '   ✅ Superuser: % (should be FALSE)', v_role_info.rolsuper;
    RAISE NOTICE '   ✅ Create Roles: % (should be FALSE)', v_role_info.rolcreaterole;
    RAISE NOTICE '   ✅ Create DB: % (should be FALSE)', v_role_info.rolcreatedb;
    RAISE NOTICE '   ✅ Can Login: % (should be TRUE)', v_role_info.rolcanlogin;
    RAISE NOTICE '   ✅ Replication: % (should be FALSE)', v_role_info.rolreplication;
    
    IF NOT v_role_info.rolsuper AND 
       NOT v_role_info.rolcreaterole AND 
       NOT v_role_info.rolcreatedb AND 
       v_role_info.rolcanlogin AND 
       NOT v_role_info.rolreplication THEN
        RAISE NOTICE '🎉 SECURE: onevault_api has minimal privileges!';
    ELSE
        RAISE NOTICE '⚠️  WARNING: onevault_api may have excessive privileges';
    END IF;
END $$;

-- Step 10: Generate connection string template
DO $$
BEGIN
    RAISE NOTICE '📋 Connection String Template:';
    RAISE NOTICE 'postgresql://onevault_api:CHANGE_THIS_SECURE_PASSWORD_123!@your-neon-host/One_Vault';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Next Steps:';
    RAISE NOTICE '1. Change the password above to something secure';
    RAISE NOTICE '2. Update your application to use onevault_api instead of neondb_owner';
    RAISE NOTICE '3. Test the connection with limited permissions';
    RAISE NOTICE '4. Keep neondb_owner for admin operations only';
END $$;

-- =============================================
-- Permission Summary Query
-- =============================================

SELECT 
    'onevault_api' as role_name,
    schemaname,
    tablename,
    privilege_type
FROM information_schema.table_privileges 
WHERE grantee = 'onevault_api'
ORDER BY schemaname, tablename, privilege_type; 