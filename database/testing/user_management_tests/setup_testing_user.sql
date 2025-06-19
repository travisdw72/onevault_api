-- ================================================
-- Setup Testing User for Security Tests
-- Creates a user with appropriate permissions for testing
-- ================================================

-- Option 1: Use your main postgres user (recommended for testing)
-- Update your .env file with:
-- DB_USER=postgres
-- DB_PASSWORD=your_postgres_password

-- Option 2: Create a dedicated testing user with limited permissions
-- (This is more secure but requires setup)

DO $$
BEGIN
    -- Check if testing user exists
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'testing_user') THEN
        CREATE USER testing_user WITH PASSWORD 'testing_password_123';
        RAISE NOTICE 'Created testing_user';
    ELSE
        RAISE NOTICE 'testing_user already exists';
    END IF;
END
$$;

-- Grant necessary permissions for security testing
GRANT CONNECT ON DATABASE onevault TO testing_user;

-- Grant usage on schemas
GRANT USAGE ON SCHEMA auth TO testing_user;
GRANT USAGE ON SCHEMA raw TO testing_user;
GRANT USAGE ON SCHEMA api TO testing_user;
GRANT USAGE ON SCHEMA util TO testing_user;

-- Grant permissions on auth schema tables
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA auth TO testing_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA raw TO testing_user;

-- Grant execute permissions on functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO testing_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO testing_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA raw TO testing_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA util TO testing_user;

-- Grant sequence permissions
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA auth TO testing_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA raw TO testing_user;

-- Grant permissions on audit schema if it exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.schemata WHERE schema_name = 'audit') THEN
        EXECUTE 'GRANT USAGE ON SCHEMA audit TO testing_user';
        EXECUTE 'GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA audit TO testing_user';
        EXECUTE 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA audit TO testing_user';
        RAISE NOTICE 'Granted permissions on audit schema';
    ELSE
        RAISE NOTICE 'audit schema does not exist - skipping';
    END IF;
END
$$;

-- Show what we've granted
SELECT 
    'TESTING USER PERMISSIONS SUMMARY:' as info;

SELECT 
    grantee as user_name,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.table_privileges 
WHERE grantee = 'testing_user'
ORDER BY table_schema, table_name, privilege_type;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'TESTING USER SETUP COMPLETE';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Option 1 (Recommended): Use postgres user';
    RAISE NOTICE '  Update .env: DB_USER=postgres';
    RAISE NOTICE '';
    RAISE NOTICE 'Option 2: Use dedicated testing user';
    RAISE NOTICE '  Update .env: DB_USER=testing_user';
    RAISE NOTICE '  Update .env: DB_PASSWORD=testing_password_123';
    RAISE NOTICE '';
    RAISE NOTICE 'Then run: run_security_tests.bat';
    RAISE NOTICE '================================================';
END;
$$; 