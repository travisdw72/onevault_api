-- =============================================
-- STEP 28: SECURITY ROLES & USER ACCOUNTS
-- Multi-Entity Business Optimization Platform
-- Implements role-based access control for HIPAA compliance
-- =============================================

-- =============================================
-- PHASE 1: CREATE APPLICATION-SPECIFIC ROLES
-- =============================================

-- Raw Data Layer User (ETL and data ingestion)
CREATE ROLE app_raw_user LOGIN PASSWORD '!@mXj9#mK2$pL5vN8@qR3raw';
COMMENT ON ROLE app_raw_user IS 'Application user for raw data ingestion and ETL processes';

-- Staging Layer User (data processing and transformation) 
CREATE ROLE app_staging_user LOGIN PASSWORD '!@mXj9#mK2$pL5vN8@qR3staging';
COMMENT ON ROLE app_staging_user IS 'Application user for data staging and transformation';

-- Business Layer User (read-only access to clean business data)
CREATE ROLE app_business_user LOGIN PASSWORD '!@mXj9#mK2$pL5vN8@qR3business';
COMMENT ON ROLE app_business_user IS 'Application user for business layer read access';

-- API Layer User (web application and API access)
CREATE ROLE app_api_user LOGIN PASSWORD '!@mXj9#mK2$pL5vN8@qR3api';
COMMENT ON ROLE app_api_user IS 'Application user for API and web application access';

-- Audit User (audit trail and compliance logging)
CREATE ROLE app_audit_user LOGIN PASSWORD '!@mXj9#mK2$pL5vN8@qR3audit';
COMMENT ON ROLE app_audit_user IS 'Application user for audit trail and compliance logging';

-- =============================================
-- PHASE 2: GRANT SCHEMA-LEVEL PERMISSIONS
-- =============================================

-- Raw Data User Permissions
GRANT USAGE ON SCHEMA raw TO app_raw_user;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA raw TO app_raw_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA raw TO app_raw_user;
-- Allow future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT SELECT, INSERT ON TABLES TO app_raw_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT USAGE, SELECT ON SEQUENCES TO app_raw_user;

-- Staging User Permissions  
GRANT USAGE ON SCHEMA raw, staging TO app_staging_user;
GRANT SELECT ON ALL TABLES IN SCHEMA raw TO app_staging_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA staging TO app_staging_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA staging TO app_staging_user;
-- Allow future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT SELECT, INSERT, UPDATE ON TABLES TO app_staging_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT USAGE, SELECT ON SEQUENCES TO app_staging_user;

-- Business User Permissions (Read-only)
GRANT USAGE ON SCHEMA business TO app_business_user;
GRANT SELECT ON ALL TABLES IN SCHEMA business TO app_business_user;
-- Allow future tables (read-only)
ALTER DEFAULT PRIVILEGES IN SCHEMA business GRANT SELECT ON TABLES TO app_business_user;

-- API User Permissions (Limited access to specific functions and views)
GRANT USAGE ON SCHEMA business, auth, api, ref, util, raw TO app_api_user;
GRANT SELECT ON ALL TABLES IN SCHEMA business TO app_api_user;
GRANT SELECT ON ALL TABLES IN SCHEMA ref TO app_api_user;
GRANT SELECT ON ALL TABLES IN SCHEMA raw TO app_api_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO app_api_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO app_api_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA util TO app_api_user;
-- Allow future functions
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT EXECUTE ON FUNCTIONS TO app_api_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT EXECUTE ON FUNCTIONS TO app_api_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA util GRANT EXECUTE ON FUNCTIONS TO app_api_user;
-- Allow future tables in raw schema
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT SELECT ON TABLES TO app_api_user;

-- Audit User Permissions
GRANT USAGE ON SCHEMA audit TO app_audit_user;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA audit TO app_audit_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA audit TO app_audit_user;
-- Allow future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT SELECT, INSERT ON TABLES TO app_audit_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT USAGE, SELECT ON SEQUENCES TO app_audit_user;

-- =============================================
-- PHASE 3: REVOKE UNNECESSARY PERMISSIONS
-- =============================================

-- Ensure users cannot access other schemas
REVOKE ALL ON SCHEMA public FROM app_raw_user, app_staging_user, app_business_user, app_api_user, app_audit_user;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM app_raw_user, app_staging_user, app_business_user, app_api_user, app_audit_user;

-- Prevent users from creating objects in schemas they don't own
REVOKE CREATE ON SCHEMA raw FROM app_raw_user;
REVOKE CREATE ON SCHEMA staging FROM app_staging_user;
REVOKE CREATE ON SCHEMA business FROM app_business_user;
REVOKE CREATE ON SCHEMA api FROM app_api_user;
REVOKE CREATE ON SCHEMA audit FROM app_audit_user;

-- =============================================
-- PHASE 4: CREATE SECURITY VALIDATION FUNCTIONS
-- =============================================

-- Function to test role permissions
CREATE OR REPLACE FUNCTION util.test_role_permissions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB := '[]'::JSONB;
    v_test_result RECORD;
BEGIN
    -- Test each role's access
    FOR v_test_result IN 
        SELECT rolname as role_name,
               has_schema_privilege(rolname, 'raw', 'USAGE') as can_access_raw,
               has_schema_privilege(rolname, 'staging', 'USAGE') as can_access_staging,
               has_schema_privilege(rolname, 'business', 'USAGE') as can_access_business,
               has_schema_privilege(rolname, 'api', 'USAGE') as can_access_api,
               has_schema_privilege(rolname, 'audit', 'USAGE') as can_access_audit
        FROM pg_roles 
        WHERE rolname LIKE 'app_%_user'
        ORDER BY rolname
    LOOP
        v_results := v_results || jsonb_build_object(
            'role', v_test_result.role_name,
            'permissions', jsonb_build_object(
                'raw_access', v_test_result.can_access_raw,
                'staging_access', v_test_result.can_access_staging,
                'business_access', v_test_result.can_access_business,
                'api_access', v_test_result.can_access_api,
                'audit_access', v_test_result.can_access_audit
            )
        );
    END LOOP;
    
    RETURN jsonb_build_object(
        'test_name', 'Role Permissions Validation',
        'timestamp', CURRENT_TIMESTAMP,
        'roles_tested', jsonb_array_length(v_results),
        'results', v_results
    );
END;
$$;

-- =============================================
-- PHASE 5: CREATE ROLE MAPPING FOR APPLICATION
-- =============================================

-- Function to get database connection info for application layers
CREATE OR REPLACE FUNCTION util.get_connection_info()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'connection_guide', 'Use these accounts in your application .env files',
        'accounts', jsonb_build_object(
            'raw_layer', jsonb_build_object(
                'username', 'app_raw_user',
                'purpose', 'ETL and data ingestion processes',
                'schemas', '["raw"]',
                'permissions', '["SELECT", "INSERT"]'
            ),
            'staging_layer', jsonb_build_object(
                'username', 'app_staging_user', 
                'purpose', 'Data processing and transformation',
                'schemas', '["raw", "staging"]',
                'permissions', '["SELECT on raw", "SELECT/INSERT/UPDATE on staging"]'
            ),
            'business_layer', jsonb_build_object(
                'username', 'app_business_user',
                'purpose', 'Read-only access to clean business data',
                'schemas', '["business"]', 
                'permissions', '["SELECT only"]'
            ),
            'api_layer', jsonb_build_object(
                'username', 'app_api_user',
                'purpose', 'Web application and API access',
                'schemas', '["business", "auth", "api", "ref"]',
                'permissions', '["SELECT on data", "EXECUTE on functions"]'
            ),
            'audit_layer', jsonb_build_object(
                'username', 'app_audit_user',
                'purpose', 'Audit trail and compliance logging', 
                'schemas', '["audit"]',
                'permissions', '["SELECT", "INSERT"]'
            )
        ),
        'security_notes', jsonb_build_array(
            'Never use PostgreSQL admin account in .env files',
            'Each layer has minimum required permissions only',
            'Passwords should be stored in secure environment variables',
            'Consider using connection pooling for better performance',
            'Enable SSL/TLS for all connections in production'
        )
    );
END;
$$;

-- =============================================
-- PHASE 6: VERIFICATION AND TESTING
-- =============================================

-- Test the new role permissions
SELECT util.test_role_permissions();

-- Show connection information
SELECT util.get_connection_info();

-- Verification message
DO $$ 
BEGIN
    RAISE NOTICE '=== SECURITY ROLES IMPLEMENTATION COMPLETE ===';
    RAISE NOTICE 'Created 5 application-specific database users:';
    RAISE NOTICE '  - app_raw_user (raw data ingestion)';
    RAISE NOTICE '  - app_staging_user (data processing)'; 
    RAISE NOTICE '  - app_business_user (business data read-only)';
    RAISE NOTICE '  - app_api_user (web application access)';
    RAISE NOTICE '  - app_audit_user (audit logging)';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '  1. Update your .env files to use these accounts';
    RAISE NOTICE '  2. Test your application with app_api_user account';
    RAISE NOTICE '  3. Configure connection pooling for each layer';
    RAISE NOTICE '  4. Enable SSL/TLS for production connections';
    RAISE NOTICE '';
    RAISE NOTICE 'Run: SELECT util.get_connection_info(); for implementation guide';
END $$; 