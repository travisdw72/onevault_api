-- =============================================
-- Comprehensive OneVault API Role - FIXED v2
-- Fixes ambiguous column reference error
-- =============================================

-- Step 1: Create the comprehensive API role
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'onevault_api_full') THEN
        CREATE ROLE onevault_api_full LOGIN;
        RAISE NOTICE '✅ Role onevault_api_full created';
    ELSE
        RAISE NOTICE '⚠️  Role onevault_api_full already exists - updating permissions';
    END IF;
END $$;

-- Step 2: Set secure password
ALTER ROLE onevault_api_full PASSWORD 'CHANGE_THIS_PRODUCTION_PASSWORD_2025!';

-- Step 3: Core database access
GRANT CONNECT ON DATABASE "postgres" TO onevault_api_full;

-- =============================================
-- Schema-Level Permissions
-- =============================================

-- Authentication & Authorization (CRITICAL)
GRANT USAGE ON SCHEMA auth TO onevault_api_full;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO onevault_api_full;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO onevault_api_full;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA auth TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON SEQUENCES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON FUNCTIONS TO onevault_api_full;

-- Business Operations (CORE API FUNCTIONALITY)
GRANT USAGE ON SCHEMA business TO onevault_api_full;
GRANT ALL ON ALL TABLES IN SCHEMA business TO onevault_api_full;
GRANT ALL ON ALL SEQUENCES IN SCHEMA business TO onevault_api_full;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA business TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA business GRANT ALL ON TABLES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA business GRANT ALL ON SEQUENCES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA business GRANT ALL ON FUNCTIONS TO onevault_api_full;

-- Audit & Compliance (REQUIRED FOR HIPAA/SOX)
GRANT USAGE ON SCHEMA audit TO onevault_api_full;
GRANT ALL ON ALL TABLES IN SCHEMA audit TO onevault_api_full;
GRANT ALL ON ALL SEQUENCES IN SCHEMA audit TO onevault_api_full;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA audit TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT ALL ON TABLES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT ALL ON SEQUENCES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT ALL ON FUNCTIONS TO onevault_api_full;

-- Utility Functions (ESSENTIAL)
GRANT USAGE ON SCHEMA util TO onevault_api_full;
GRANT ALL ON ALL TABLES IN SCHEMA util TO onevault_api_full;
GRANT ALL ON ALL SEQUENCES IN SCHEMA util TO onevault_api_full;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA util TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT ALL ON TABLES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT ALL ON SEQUENCES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT ALL ON FUNCTIONS TO onevault_api_full;

-- Reference Data (LOOKUPS & CONFIGURATIONS)
GRANT USAGE ON SCHEMA ref TO onevault_api_full;
GRANT ALL ON ALL TABLES IN SCHEMA ref TO onevault_api_full;
GRANT ALL ON ALL SEQUENCES IN SCHEMA ref TO onevault_api_full;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA ref TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA ref GRANT ALL ON TABLES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA ref GRANT ALL ON SEQUENCES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA ref GRANT ALL ON FUNCTIONS TO onevault_api_full;

-- Raw Data Ingestion (API DATA INTAKE)
GRANT USAGE ON SCHEMA raw TO onevault_api_full;
GRANT ALL ON ALL TABLES IN SCHEMA raw TO onevault_api_full;
GRANT ALL ON ALL SEQUENCES IN SCHEMA raw TO onevault_api_full;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA raw TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT ALL ON TABLES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT ALL ON SEQUENCES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT ALL ON FUNCTIONS TO onevault_api_full;

-- Staging (DATA PROCESSING)
GRANT USAGE ON SCHEMA staging TO onevault_api_full;
GRANT ALL ON ALL TABLES IN SCHEMA staging TO onevault_api_full;
GRANT ALL ON ALL SEQUENCES IN SCHEMA staging TO onevault_api_full;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA staging TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT ALL ON TABLES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT ALL ON SEQUENCES TO onevault_api_full;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT ALL ON FUNCTIONS TO onevault_api_full;

-- API Functions (PUBLIC API ENDPOINTS)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'api') THEN
        GRANT USAGE ON SCHEMA api TO onevault_api_full;
        GRANT ALL ON ALL TABLES IN SCHEMA api TO onevault_api_full;
        GRANT ALL ON ALL SEQUENCES IN SCHEMA api TO onevault_api_full;
        GRANT ALL ON ALL FUNCTIONS IN SCHEMA api TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON TABLES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON SEQUENCES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON FUNCTIONS TO onevault_api_full;
        RAISE NOTICE '✅ API schema permissions granted';
    ELSE
        RAISE NOTICE '⚠️  API schema not found - skipping';
    END IF;
END $$;

-- =============================================
-- Industry-Specific Schema Permissions - FIXED
-- =============================================

-- Compliance schemas (FIXED variable name conflict)
DO $$
DECLARE
    v_schema_name TEXT;  -- FIXED: Renamed variable to avoid conflict
    schema_list TEXT[] := ARRAY['compliance', 'compliance_automation', 'capacity_planning', 'config', 'infomart', 'metadata'];
BEGIN
    FOREACH v_schema_name IN ARRAY schema_list
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = v_schema_name) THEN
            EXECUTE format('GRANT USAGE ON SCHEMA %I TO onevault_api_full', v_schema_name);
            EXECUTE format('GRANT ALL ON ALL TABLES IN SCHEMA %I TO onevault_api_full', v_schema_name);
            EXECUTE format('GRANT ALL ON ALL SEQUENCES IN SCHEMA %I TO onevault_api_full', v_schema_name);
            EXECUTE format('GRANT ALL ON ALL FUNCTIONS IN SCHEMA %I TO onevault_api_full', v_schema_name);
            EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON TABLES TO onevault_api_full', v_schema_name);
            EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON SEQUENCES TO onevault_api_full', v_schema_name);
            EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON FUNCTIONS TO onevault_api_full', v_schema_name);
            RAISE NOTICE '✅ % schema permissions granted', v_schema_name;
        ELSE
            RAISE NOTICE '⚠️  % schema not found - skipping', v_schema_name;
        END IF;
    END LOOP;
END $$;

-- =============================================
-- Security Analysis & Recommendations
-- =============================================

DO $$
DECLARE
    v_role_info RECORD;
    v_schema_count INTEGER;
    v_table_count INTEGER;
    v_function_count INTEGER;
BEGIN
    -- Get role security info
    SELECT 
        rolname,
        rolsuper,
        rolcreaterole,
        rolcreatedb,
        rolcanlogin,
        rolreplication
    INTO v_role_info
    FROM pg_roles 
    WHERE rolname = 'onevault_api_full';
    
    -- Count granted permissions
    SELECT COUNT(DISTINCT table_schema) INTO v_schema_count
    FROM information_schema.table_privileges 
    WHERE grantee = 'onevault_api_full';
    
    SELECT COUNT(*) INTO v_table_count
    FROM information_schema.table_privileges 
    WHERE grantee = 'onevault_api_full';
    
    SELECT COUNT(*) INTO v_function_count
    FROM information_schema.routine_privileges 
    WHERE grantee = 'onevault_api_full';
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍 COMPREHENSIVE API ROLE ANALYSIS';
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'Role: onevault_api_full';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 Security Profile:';
    RAISE NOTICE '   ✅ Superuser: % (GOOD - should be FALSE)', v_role_info.rolsuper;
    RAISE NOTICE '   ✅ Create Roles: % (GOOD - should be FALSE)', v_role_info.rolcreaterole;
    RAISE NOTICE '   ✅ Create DB: % (GOOD - should be FALSE)', v_role_info.rolcreatedb;
    RAISE NOTICE '   ✅ Can Login: % (REQUIRED - should be TRUE)', v_role_info.rolcanlogin;
    RAISE NOTICE '   ✅ Replication: % (GOOD - should be FALSE)', v_role_info.rolreplication;
    RAISE NOTICE '';
    RAISE NOTICE '📊 Permission Summary:';
    RAISE NOTICE '   📁 Schemas with access: %', v_schema_count;
    RAISE NOTICE '   📄 Table permissions: %', v_table_count;
    RAISE NOTICE '   ⚙️  Function permissions: %', v_function_count;
    RAISE NOTICE '';
    
    IF NOT v_role_info.rolsuper AND 
       NOT v_role_info.rolcreaterole AND 
       NOT v_role_info.rolcreatedb AND 
       v_role_info.rolcanlogin AND 
       NOT v_role_info.rolreplication THEN
        RAISE NOTICE '🎉 SECURITY STATUS: GOOD';
        RAISE NOTICE '   ✅ No dangerous system privileges';
        RAISE NOTICE '   ✅ Can handle full API operations';
        RAISE NOTICE '   ✅ Appropriate for production use';
    ELSE
        RAISE NOTICE '⚠️  SECURITY WARNING: Role has elevated privileges';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🚀 DEPLOYMENT RECOMMENDATIONS:';
    RAISE NOTICE '   1. Change password before production use';
    RAISE NOTICE '   2. Use this role for ALL API operations';
    RAISE NOTICE '   3. Keep neondb_owner for admin tasks only';
    RAISE NOTICE '   4. Monitor usage with audit logging';
    RAISE NOTICE '   5. Consider network IP restrictions';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Connection String:';
    RAISE NOTICE 'postgresql://onevault_api_full:CHANGE_THIS_PRODUCTION_PASSWORD_2025!@your-neon-host/postgres';
END $$;

-- =============================================
-- Final Permission Report
-- =============================================

SELECT 
    'COMPREHENSIVE API ROLE PERMISSIONS' as report_title,
    table_schema as schema_name,
    table_name,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE grantee = 'onevault_api_full'
ORDER BY table_schema, table_name, privilege_type; 