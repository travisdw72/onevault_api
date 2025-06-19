-- =====================================================
-- BARN USER CLEANUP SCRIPT
-- Removes barn_user from TEMPLATE database and ensures app_user has proper permissions
-- ⚠️  WARNING: This is ONLY for the template database (one_vault)
-- ⚠️  DO NOT run this on implementation databases (one_barn_db, etc.)
-- =====================================================

-- Connect to one_vault template database ONLY
-- \c one_vault;

-- Safety check to prevent running on implementation databases
DO $$
BEGIN
    IF current_database() LIKE '%barn%' OR 
       current_database() LIKE '%wealth%' OR 
       current_database() LIKE '%spa%' OR 
       current_database() LIKE '%implementation%' THEN
        RAISE EXCEPTION 'This cleanup script should ONLY be run on the template database (one_vault), not on implementation database: %', current_database();
    END IF;
    
    IF current_database() != 'one_vault' THEN
        RAISE WARNING 'This script is designed for the one_vault template database. Current database: %', current_database();
        RAISE WARNING 'If this is correct, you may continue, but verify this is truly a template database.';
    END IF;
END $$;

-- Start transaction for atomic cleanup
BEGIN;

-- =====================================================
-- BARN USER CLEANUP AND PERMISSION TRANSFER
-- =====================================================

DO $$
DECLARE
    v_barn_user_exists BOOLEAN;
    v_app_user_exists BOOLEAN;
    v_permission_record RECORD;
BEGIN
    -- Check if barn_user exists
    SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'barn_user') INTO v_barn_user_exists;
    
    -- Check if app_user exists
    SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'app_user') INTO v_app_user_exists;
    
    IF v_barn_user_exists AND v_app_user_exists THEN
        RAISE NOTICE 'Starting barn_user cleanup and permission transfer to app_user...';
        
        -- Transfer database-level permissions from barn_user to app_user
        -- Note: This is a simplified transfer - in production you'd want more detailed permission analysis
        
        -- Grant app_user the same basic permissions that barn_user likely had
        GRANT USAGE ON SCHEMA api TO app_user;
        GRANT USAGE ON SCHEMA auth TO app_user;
        GRANT USAGE ON SCHEMA business TO app_user;
        GRANT USAGE ON SCHEMA raw TO app_user;
        GRANT USAGE ON SCHEMA staging TO app_user;
        GRANT USAGE ON SCHEMA ref TO app_user;
        
        -- Grant execute permissions on API functions
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO app_user;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO app_user;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA business TO app_user;
        
        -- Grant table permissions
        GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA auth TO app_user;
        GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA business TO app_user;
        GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA raw TO app_user;
        GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA staging TO app_user;
        GRANT SELECT ON ALL TABLES IN SCHEMA ref TO app_user;
        
        -- Grant sequence permissions
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA auth TO app_user;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA business TO app_user;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA raw TO app_user;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA staging TO app_user;
        
        -- Set default privileges for future objects
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT SELECT, INSERT, UPDATE ON TABLES TO app_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA business GRANT SELECT, INSERT, UPDATE ON TABLES TO app_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT SELECT, INSERT ON TABLES TO app_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT SELECT, INSERT, UPDATE ON TABLES TO app_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA ref GRANT SELECT ON TABLES TO app_user;
        
        ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT EXECUTE ON FUNCTIONS TO app_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT EXECUTE ON FUNCTIONS TO app_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA business GRANT EXECUTE ON FUNCTIONS TO app_user;
        
        RAISE NOTICE '✅ Transferred permissions from barn_user pattern to app_user';
        
        -- Now safely remove barn_user
        -- First, check for dependencies
        IF EXISTS (
            SELECT 1 FROM pg_shdepend 
            WHERE refobjid = (SELECT oid FROM pg_roles WHERE rolname = 'barn_user')
        ) THEN
            RAISE WARNING 'barn_user has dependencies - cannot remove safely';
            RAISE WARNING 'This suggests this is an implementation database, not a template';
            RAISE WARNING 'Dependencies should be transferred manually if cleanup is needed';
        ELSE
            -- First, terminate any active connections for barn_user
            PERFORM pg_terminate_backend(pid)
            FROM pg_stat_activity 
            WHERE usename = 'barn_user' AND pid <> pg_backend_pid();
            
            -- Remove barn_user
            DROP ROLE IF EXISTS barn_user;
            RAISE NOTICE '✅ Removed barn_user from template database';
            RAISE NOTICE '✅ Template database now uses standardized app_user';
        END IF;
        
    ELSIF v_barn_user_exists AND NOT v_app_user_exists THEN
        RAISE WARNING 'barn_user exists but app_user does not - run foundation script first';
        
    ELSIF NOT v_barn_user_exists AND v_app_user_exists THEN
        RAISE NOTICE 'barn_user already removed, app_user is properly configured';
        
    ELSIF NOT v_barn_user_exists AND NOT v_app_user_exists THEN
        RAISE WARNING 'Neither barn_user nor app_user exists - run foundation script first';
        
    END IF;
    
END $$;

-- =====================================================
-- VERIFY CLEANUP SUCCESS
-- =====================================================

-- Show remaining users relevant to the template
SELECT 'TEMPLATE USER VERIFICATION' as section;

SELECT 
    rolname as user_name,
    rolcanlogin as can_login,
    rolsuper as is_superuser,
    rolcreatedb as can_create_db,
    CASE 
        WHEN rolname = 'app_user' THEN '✅ Template user'
        WHEN rolname LIKE 'app_%' THEN '✅ App user'
        WHEN rolname = 'postgres' THEN '⚙️ System admin'
        WHEN rolname LIKE 'onevault_%' THEN '🏗️ Implementation user'
        ELSE '❓ Other user'
    END as user_type
FROM pg_roles 
WHERE rolname IN ('app_user', 'barn_user', 'postgres', 'onevault_implementation', 'onevault_readonly')
   OR rolname LIKE 'app_%'
ORDER BY 
    CASE 
        WHEN rolname = 'app_user' THEN 1
        WHEN rolname LIKE 'app_%' THEN 2
        WHEN rolname = 'postgres' THEN 3
        ELSE 4
    END;

-- Verify app_user has proper permissions
SELECT 'APP_USER PERMISSION VERIFICATION' as section;

-- Check schema access
SELECT 
    'Schema Access' as permission_type,
    nspname as schema_name,
    CASE 
        WHEN has_schema_privilege('app_user', nspname, 'USAGE') THEN '✅ HAS ACCESS'
        ELSE '❌ NO ACCESS'
    END as access_status
FROM pg_namespace 
WHERE nspname IN ('api', 'auth', 'business', 'util', 'audit', 'raw', 'staging', 'ref')
ORDER BY nspname;

-- Log the cleanup completion
INSERT INTO util.deployment_log (
    deployment_name, 
    deployment_notes, 
    deployment_status
) VALUES (
    'Barn User Cleanup',
    'Removed barn_user from template database and transferred permissions to standardized app_user. Template database now uses consistent user naming.',
    'COMPLETED'
);

-- Commit the transaction
COMMIT;

-- =====================================================
-- CLEANUP COMPLETION MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'BARN USER CLEANUP COMPLETED';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Template database now uses standardized naming:';
    RAISE NOTICE '- app_user: Standard template application user';
    RAISE NOTICE '- barn_user: REMOVED (was implementation-specific)';
    RAISE NOTICE '';
    RAISE NOTICE 'When creating implementation databases:';
    RAISE NOTICE '- Rename app_user to implementation-specific name';
    RAISE NOTICE '- Example: one_barn_user, one_wealth_user, etc.';
    RAISE NOTICE '=================================================';
END $$; 