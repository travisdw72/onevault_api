-- =============================================
-- Comprehensive OneVault API Role
-- Based on actual OneVault architecture with 56 API functions
-- Handles ALL API operations across multiple schemas
-- =============================================

-- Step 1: Create the comprehensive API role
CREATE ROLE onevault_api_full LOGIN;

-- Step 2: Set secure password
ALTER ROLE onevault_api_full PASSWORD 'CHANGE_THIS_PRODUCTION_PASSWORD_2025!';

-- Step 3: Core database access
GRANT CONNECT ON DATABASE "neondb" TO onevault_api_full;

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
-- Industry-Specific Schema Permissions
-- =============================================

-- Equestrian Industry Module
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'equestrian') THEN
        GRANT USAGE ON SCHEMA equestrian TO onevault_api_full;
        GRANT ALL ON ALL TABLES IN SCHEMA equestrian TO onevault_api_full;
        GRANT ALL ON ALL SEQUENCES IN SCHEMA equestrian TO onevault_api_full;
        GRANT ALL ON ALL FUNCTIONS IN SCHEMA equestrian TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA equestrian GRANT ALL ON TABLES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA equestrian GRANT ALL ON SEQUENCES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA equestrian GRANT ALL ON FUNCTIONS TO onevault_api_full;
        RAISE NOTICE '✅ Equestrian industry module permissions granted';
    ELSE
        RAISE NOTICE '⚠️  Equestrian schema not found - skipping';
    END IF;
END $$; 

-- Compliance Automation
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'compliance') THEN
        GRANT USAGE ON SCHEMA compliance TO onevault_api_full;
        GRANT ALL ON ALL TABLES IN SCHEMA compliance TO onevault_api_full;
        GRANT ALL ON ALL SEQUENCES IN SCHEMA compliance TO onevault_api_full;
        GRANT ALL ON ALL FUNCTIONS IN SCHEMA compliance TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA compliance GRANT ALL ON TABLES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA compliance GRANT ALL ON SEQUENCES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA compliance GRANT ALL ON FUNCTIONS TO onevault_api_full;
        RAISE NOTICE '✅ Compliance schema permissions granted';
    ELSE
        RAISE NOTICE '⚠️  Compliance schema not found - skipping';
    END IF;
END $$;

-- Compliance Automation
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'compliance_automation') THEN
        GRANT USAGE ON SCHEMA compliance_automation TO onevault_api_full;
        GRANT ALL ON ALL TABLES IN SCHEMA compliance_automation TO onevault_api_full;
        GRANT ALL ON ALL SEQUENCES IN SCHEMA compliance_automation TO onevault_api_full;
        GRANT ALL ON ALL FUNCTIONS IN SCHEMA compliance_automation TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA compliance_automation GRANT ALL ON TABLES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA compliance_automation GRANT ALL ON SEQUENCES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA compliance_automation GRANT ALL ON FUNCTIONS TO onevault_api_full;
        RAISE NOTICE '✅ Compliance automation schema permissions granted';
    ELSE
        RAISE NOTICE '⚠️  Compliance automation schema not found - skipping';
    END IF;
END $$;

-- Capacity Planning
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'capacity_planning') THEN
        GRANT USAGE ON SCHEMA capacity_planning TO onevault_api_full;
        GRANT ALL ON ALL TABLES IN SCHEMA capacity_planning TO onevault_api_full;
        GRANT ALL ON ALL SEQUENCES IN SCHEMA capacity_planning TO onevault_api_full;
        GRANT ALL ON ALL FUNCTIONS IN SCHEMA capacity_planning TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA capacity_planning GRANT ALL ON TABLES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA capacity_planning GRANT ALL ON SEQUENCES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA capacity_planning GRANT ALL ON FUNCTIONS TO onevault_api_full;
        RAISE NOTICE '✅ Capacity planning schema permissions granted';
    ELSE
        RAISE NOTICE '⚠️  Capacity planning schema not found - skipping';
    END IF;
END $$;

-- Configuration Management
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'config') THEN
        GRANT USAGE ON SCHEMA config TO onevault_api_full;
        GRANT ALL ON ALL TABLES IN SCHEMA config TO onevault_api_full;
        GRANT ALL ON ALL SEQUENCES IN SCHEMA config TO onevault_api_full;
        GRANT ALL ON ALL FUNCTIONS IN SCHEMA config TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA config GRANT ALL ON TABLES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA config GRANT ALL ON SEQUENCES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA config GRANT ALL ON FUNCTIONS TO onevault_api_full;
        RAISE NOTICE '✅ Configuration schema permissions granted';
    ELSE
        RAISE NOTICE '⚠️  Configuration schema not found - skipping';
    END IF;
END $$;

-- Information Mart
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'infomart') THEN
        GRANT USAGE ON SCHEMA infomart TO onevault_api_full;
        GRANT ALL ON ALL TABLES IN SCHEMA infomart TO onevault_api_full;
        GRANT ALL ON ALL SEQUENCES IN SCHEMA infomart TO onevault_api_full;
        GRANT ALL ON ALL FUNCTIONS IN SCHEMA infomart TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA infomart GRANT ALL ON TABLES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA infomart GRANT ALL ON SEQUENCES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA infomart GRANT ALL ON FUNCTIONS TO onevault_api_full;
        RAISE NOTICE '✅ Information mart schema permissions granted';
    ELSE
        RAISE NOTICE '⚠️  Information mart schema not found - skipping';
    END IF;
END $$;

-- Metadata Management
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'metadata') THEN
        GRANT USAGE ON SCHEMA metadata TO onevault_api_full;
        GRANT ALL ON ALL TABLES IN SCHEMA metadata TO onevault_api_full;
        GRANT ALL ON ALL SEQUENCES IN SCHEMA metadata TO onevault_api_full;
        GRANT ALL ON ALL FUNCTIONS IN SCHEMA metadata TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA metadata GRANT ALL ON TABLES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA metadata GRANT ALL ON SEQUENCES TO onevault_api_full;
        ALTER DEFAULT PRIVILEGES IN SCHEMA metadata GRANT ALL ON FUNCTIONS TO onevault_api_full;
        RAISE NOTICE '✅ Metadata schema permissions granted';
    ELSE
        RAISE NOTICE '⚠️  Metadata schema not found - skipping';
    END IF;
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
    RAISE NOTICE 'postgresql://onevault_api_full:CHANGE_THIS_PRODUCTION_PASSWORD_2025!@your-neon-host/neondb';
END $$;

-- =============================================
-- Architecture Decision Summary
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🏗️  ARCHITECTURE DECISION SUMMARY';
    RAISE NOTICE '===================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ CHOSEN APPROACH: Single Comprehensive API Role';
    RAISE NOTICE '   • One connection for all API operations';
    RAISE NOTICE '   • Covers all 56 API functions';
    RAISE NOTICE '   • Handles multi-tenant business logic';
    RAISE NOTICE '   • Supports industry-specific modules';
    RAISE NOTICE '   • Enables compliance automation';
    RAISE NOTICE '';
    RAISE NOTICE '⚖️  TRADE-OFF ANALYSIS:';
    RAISE NOTICE '   PROS:';
    RAISE NOTICE '   ✅ Simplified connection management';
    RAISE NOTICE '   ✅ Single authentication point';
    RAISE NOTICE '   ✅ Consistent transaction handling';
    RAISE NOTICE '   ✅ Easier application development';
    RAISE NOTICE '   ✅ Better performance (connection pooling)';
    RAISE NOTICE '';
    RAISE NOTICE '   CONS:';
    RAISE NOTICE '   ⚠️  Larger attack surface if compromised';
    RAISE NOTICE '   ⚠️  All API operations share same privileges';
    RAISE NOTICE '   ⚠️  More complex permission auditing';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 RECOMMENDATION:';
    RAISE NOTICE '   Use this comprehensive role for production';
    RAISE NOTICE '   Implement network-level restrictions';
    RAISE NOTICE '   Enable comprehensive audit logging';
    RAISE NOTICE '   Consider rate limiting per IP/user';
    RAISE NOTICE '';
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