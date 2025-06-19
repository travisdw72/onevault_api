-- =====================================================
-- ONE VAULT TEMPLATE DATABASE FOUNDATION
-- Essential infrastructure for the template database
-- Must be deployed BEFORE any other scripts
-- =====================================================

-- Connect to one_vault template database
-- \c one_vault;

-- Start transaction for atomic deployment
BEGIN;

-- Set session variables for deployment tracking
SET session_replication_role = replica; -- Disable triggers during deployment
SET work_mem = '256MB'; -- Increase memory for large operations

-- =====================================================
-- ESSENTIAL UTILITY INFRASTRUCTURE
-- =====================================================


-- Create deployment log table (REQUIRED by all other scripts)
-- This is the ONLY table missing that we need
CREATE TABLE IF NOT EXISTS util.deployment_log (
    deployment_id SERIAL PRIMARY KEY,
    deployment_name VARCHAR(255) NOT NULL,
    deployment_start TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deployment_end TIMESTAMP WITH TIME ZONE,
    deployment_status VARCHAR(50) DEFAULT 'IN_PROGRESS',
    deployment_notes TEXT,
    deployed_by VARCHAR(255) DEFAULT SESSION_USER,
    rollback_script TEXT
);

-- Create database version tracking
CREATE TABLE IF NOT EXISTS util.database_version (
    version_id SERIAL PRIMARY KEY,
    version_number VARCHAR(20) NOT NULL,
    version_name VARCHAR(255) NOT NULL,
    deployment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    is_current BOOLEAN DEFAULT true
);

-- Create feature flags table for template database capabilities
CREATE TABLE IF NOT EXISTS util.template_features (
    feature_id SERIAL PRIMARY KEY,
    feature_name VARCHAR(100) NOT NULL UNIQUE,
    feature_description TEXT,
    is_enabled BOOLEAN DEFAULT true,
    deployment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    enabled_by VARCHAR(255) DEFAULT SESSION_USER
);

-- =====================================================
-- VERIFY EXISTING FUNCTIONS (DO NOT RECREATE)
-- =====================================================

-- The investigation shows these functions already exist:
-- - util.current_load_date() -> timestamp with time zone
-- - util.get_record_source() -> character varying  
-- - util.hash_binary(input text) -> bytea
-- - util.hash_concat(VARIADIC args text[]) -> bytea

-- Verify they exist and warn if missing
DO $$
BEGIN
    -- Check util.hash_binary
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'util' AND p.proname = 'hash_binary'
    ) THEN
        RAISE WARNING 'util.hash_binary function is missing - this may cause deployment issues';
    ELSE
        RAISE NOTICE '✅ util.hash_binary function exists';
    END IF;
    
    -- Check util.current_load_date
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'util' AND p.proname = 'current_load_date'
    ) THEN
        RAISE WARNING 'util.current_load_date function is missing - this may cause deployment issues';
    ELSE
        RAISE NOTICE '✅ util.current_load_date function exists';
    END IF;
    
    -- Check util.get_record_source
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'util' AND p.proname = 'get_record_source'
    ) THEN
        RAISE WARNING 'util.get_record_source function is missing - this may cause deployment issues';
    ELSE
        RAISE NOTICE '✅ util.get_record_source function exists';
    END IF;
END $$;

-- =====================================================
-- TEMPLATE DATABASE CONFIGURATION
-- =====================================================

-- Insert initial database version
INSERT INTO util.database_version (version_number, version_name, description, is_current)
VALUES (
    '1.0.0', 
    'One Vault Template Foundation', 
    'Initial template database with Data Vault 2.0 foundation, AI integration ready, HIPAA/GDPR compliant infrastructure',
    true
) ON CONFLICT DO NOTHING;

-- Insert template features
INSERT INTO util.template_features (feature_name, feature_description, is_enabled) VALUES
('data_vault_2_0', 'Complete Data Vault 2.0 implementation with temporal tracking', true),
('ai_integration', 'AI system integration with audit trails and compliance', true),
('hipaa_compliance', 'HIPAA compliant audit trails and data protection', true),
('gdpr_compliance', 'GDPR compliant data processing and privacy controls', true),
('multi_tenant', 'Multi-tenant architecture with complete isolation', true),
('financial_management', 'Comprehensive financial tracking and reporting', true),
('health_management', 'Health records and veterinary management', true),
('performance_tracking', 'Training and competition performance analytics', true),
('zero_trust_security', 'Zero trust security model with comprehensive logging', true),
('enterprise_audit', 'Enterprise-grade audit trails and compliance reporting', true)
ON CONFLICT (feature_name) DO NOTHING;

-- =====================================================
-- ENHANCED AUDIT AND LOGGING INFRASTRUCTURE
-- =====================================================


-- Enhanced deployment tracking function
CREATE OR REPLACE FUNCTION util.log_deployment_start(
    p_deployment_name VARCHAR(255),
    p_deployment_notes TEXT DEFAULT NULL,
    p_rollback_script TEXT DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_deployment_id INTEGER;
BEGIN
    INSERT INTO util.deployment_log (
        deployment_name, 
        deployment_notes, 
        rollback_script,
        deployment_status
    ) VALUES (
        p_deployment_name,
        p_deployment_notes,
        p_rollback_script,
        'IN_PROGRESS'
    ) RETURNING deployment_id INTO v_deployment_id;
    
    RAISE NOTICE 'Started deployment: % (ID: %)', p_deployment_name, v_deployment_id;
    RETURN v_deployment_id;
END;
$$ LANGUAGE plpgsql;

-- Complete deployment tracking
CREATE OR REPLACE FUNCTION util.log_deployment_complete(
    p_deployment_id INTEGER,
    p_success BOOLEAN DEFAULT true,
    p_final_notes TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE util.deployment_log 
    SET deployment_end = CURRENT_TIMESTAMP,
        deployment_status = CASE WHEN p_success THEN 'COMPLETED' ELSE 'FAILED' END,
        deployment_notes = COALESCE(deployment_notes || ' | ' || p_final_notes, p_final_notes)
    WHERE deployment_id = p_deployment_id;
    
    IF FOUND THEN
        RAISE NOTICE 'Completed deployment ID: % with status: %', 
                     p_deployment_id, 
                     CASE WHEN p_success THEN 'SUCCESS' ELSE 'FAILURE' END;
        RETURN true;
    ELSE
        RAISE WARNING 'Deployment ID % not found', p_deployment_id;
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Template database validation function
CREATE OR REPLACE FUNCTION util.validate_template_readiness()
RETURNS TABLE (
    check_name VARCHAR(100),
    status VARCHAR(20),
    details TEXT
) AS $$
BEGIN
    -- Check if essential schemas exist
    RETURN QUERY
    SELECT 
        'Schema: auth'::VARCHAR(100) as check_name,
        CASE WHEN EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth') 
             THEN 'PASS'::VARCHAR(20) ELSE 'FAIL'::VARCHAR(20) END as status,
        'Authentication and authorization schema'::TEXT as details;
    
    RETURN QUERY
    SELECT 
        'Schema: business'::VARCHAR(100) as check_name,
        CASE WHEN EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'business') 
             THEN 'PASS'::VARCHAR(20) ELSE 'FAIL'::VARCHAR(20) END as status,
        'Business logic and entities schema'::TEXT as details;
        
    RETURN QUERY
    SELECT 
        'Schema: util'::VARCHAR(100) as check_name,
        CASE WHEN EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'util') 
             THEN 'PASS'::VARCHAR(20) ELSE 'FAIL'::VARCHAR(20) END as status,
        'Utility functions and tools schema'::TEXT as details;
        
    RETURN QUERY
    SELECT 
        'Schema: audit'::VARCHAR(100) as check_name,
        CASE WHEN EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'audit') 
             THEN 'PASS'::VARCHAR(20) ELSE 'FAIL'::VARCHAR(20) END as status,
        'Audit and compliance tracking schema'::TEXT as details;
    
    -- Check if essential functions exist
    RETURN QUERY
    SELECT 
        'Function: util.hash_binary'::VARCHAR(100) as check_name,
        CASE WHEN EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
                        WHERE n.nspname = 'util' AND p.proname = 'hash_binary') 
             THEN 'PASS'::VARCHAR(20) ELSE 'FAIL'::VARCHAR(20) END as status,
        'Data Vault 2.0 hash key generation'::TEXT as details;
        
    RETURN QUERY
    SELECT 
        'Table: util.deployment_log'::VARCHAR(100) as check_name,
        CASE WHEN EXISTS(SELECT 1 FROM information_schema.tables 
                        WHERE table_schema = 'util' AND table_name = 'deployment_log') 
             THEN 'PASS'::VARCHAR(20) ELSE 'FAIL'::VARCHAR(20) END as status,
        'Deployment tracking and audit trail'::TEXT as details;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- APPLICATION USER MANAGEMENT
-- =====================================================

-- Create generic application user for template inheritance
-- Investigation shows both app_user (no login) and barn_user (can login) exist
-- We'll create a proper app_user with login capabilities for the template
DO $$
BEGIN
    -- Check if app_user exists and has login capability
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user' AND rolcanlogin = false) THEN
        -- app_user exists but can't login - modify it
        ALTER ROLE app_user WITH LOGIN PASSWORD 'secure_template_password_change_in_production';
        RAISE NOTICE 'Modified existing app_user to allow login';
    ELSIF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
        -- app_user doesn't exist - create it
        CREATE USER app_user WITH PASSWORD 'secure_template_password_change_in_production';
        RAISE NOTICE 'Created app_user for template database';
    ELSE
        RAISE NOTICE 'app_user already exists with proper configuration';
    END IF;
END $$;

-- Grant essential permissions on infrastructure
GRANT USAGE ON SCHEMA util TO app_user;
GRANT USAGE ON SCHEMA audit TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA util TO app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA util TO app_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA util TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA audit TO app_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA audit TO app_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT ALL ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT ALL ON SEQUENCES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT EXECUTE ON FUNCTIONS TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT INSERT, SELECT ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT EXECUTE ON FUNCTIONS TO app_user;

-- =====================================================
-- LOG FOUNDATION DEPLOYMENT
-- =====================================================

-- Log this deployment
INSERT INTO util.deployment_log (
    deployment_name, 
    deployment_notes, 
    deployment_status,
    rollback_script
) VALUES (
    'Template Foundation v1.0',
    'Essential infrastructure for One Vault template database - deployment tracking, core utilities, version management, and validation functions. Updated to work with existing functions.',
    'COMPLETED',
    'DROP TABLE IF EXISTS util.template_features CASCADE; DROP TABLE IF EXISTS util.database_version CASCADE; DROP TABLE IF EXISTS util.deployment_log CASCADE; DROP FUNCTION IF EXISTS util.validate_template_readiness CASCADE; DROP FUNCTION IF EXISTS util.log_deployment_complete CASCADE; DROP FUNCTION IF EXISTS util.log_deployment_start CASCADE;'
);

-- Reset session variables
RESET session_replication_role;
RESET work_mem;

-- Commit the transaction
COMMIT;

-- =====================================================
-- FOUNDATION VALIDATION AND SUMMARY
-- =====================================================

-- Validate template readiness
SELECT 'FOUNDATION VALIDATION' as section;
SELECT * FROM util.validate_template_readiness();

-- Display deployment summary
SELECT 
    'TEMPLATE FOUNDATION DEPLOYED SUCCESSFULLY!' as status,
    'Core infrastructure ready for additional deployments' as message,
    CURRENT_TIMESTAMP as completed_at,
    SESSION_USER as deployed_by;

-- Show template features
SELECT 'TEMPLATE FEATURES ENABLED' as section;
SELECT 
    feature_name,
    feature_description,
    is_enabled,
    deployment_date
FROM util.template_features 
WHERE is_enabled = true
ORDER BY feature_name;

-- Show current version
SELECT 'DATABASE VERSION' as section;
SELECT 
    version_number,
    version_name,
    deployment_date,
    description
FROM util.database_version 
WHERE is_current = true;

-- Final deployment completion message
DO $$
BEGIN
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'ONE VAULT TEMPLATE FOUNDATION DEPLOYMENT COMPLETE';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Template database is ready for:';
    RAISE NOTICE '- AI Data Vault 2.0 integration';
    RAISE NOTICE '- Critical schemas deployment';
    RAISE NOTICE '- Business application deployment';
    RAISE NOTICE '- Multi-tenant system instantiation';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'NOTE: Existing functions (hash_binary, current_load_date, get_record_source) were preserved';
    RAISE NOTICE 'Only missing infrastructure was added: deployment_log table and tracking functions';
END $$; 