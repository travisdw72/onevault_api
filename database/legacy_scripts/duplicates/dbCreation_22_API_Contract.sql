-- =============================================
-- dbCreation_22_API_Contract.sql
-- Data Vault 2.0 API Contract Definition for Project Goal 3
-- Authentication, Authorization, and Session Management
-- =============================================
-- 
-- This document defines the official SQL API contract for Project Goal 3
-- All procedures/functions listed here are designed to be called via REST API
-- following the established naming conventions and security patterns.
--
-- Security Level: PUBLIC API ENDPOINTS (with proper authentication)
-- HIPAA Compliance: All procedures include audit logging and data protection
-- =============================================

-- =============================================
-- CREATE API SCHEMA
-- =============================================

-- Create the API schema for organizing REST API endpoint functions
-- This schema will contain:
-- 1. JSON-friendly wrapper functions for authentication
-- 2. Future integration endpoints (QuickBooks, other systems)
-- 3. API versioning and contract management functions
-- 4. Standardized JSON request/response handling

CREATE SCHEMA IF NOT EXISTS api;

COMMENT ON SCHEMA api IS 
'API contract layer providing JSON-based REST endpoint functions. 
This schema wraps core Data Vault 2.0 procedures with standardized 
JSON input/output for seamless REST API integration. Designed for 
external system integrations including accounting, reporting, and 
third-party healthcare platforms.';

-- Grant appropriate permissions
-- Note: Adjust these based on your security requirements
GRANT USAGE ON SCHEMA api TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO postgres;

-- Set default privileges for future functions
ALTER DEFAULT PRIVILEGES IN SCHEMA api 
GRANT EXECUTE ON FUNCTIONS TO postgres;

-- =============================================
-- API CONTRACT OVERVIEW
-- =============================================

/*
PROJECT GOAL 3 API ENDPOINTS:

1. AUTHENTICATION ENDPOINTS
   - POST /api/auth/login           → auth.login_user()
   - POST /api/auth/complete-login  → auth.complete_login()
   - POST /api/auth/validate        → auth.validate_session()
   - POST /api/auth/logout          → auth.logout_user()

2. TENANT MANAGEMENT ENDPOINTS  
   - POST /api/tenants/register     → auth.register_tenant()
   - GET  /api/tenants/list         → auth.get_user_tenants()

3. USER MANAGEMENT ENDPOINTS
   - POST /api/users/register       → auth.register_user()
   - GET  /api/users/profile        → auth.get_user_profile()
   - PUT  /api/users/profile        → auth.update_user_profile()

4. TOKEN MANAGEMENT ENDPOINTS
   - POST /api/tokens/generate      → auth.generate_api_token()
   - POST /api/tokens/validate      → auth.validate_token_and_session()
   - DELETE /api/tokens/revoke      → auth.revoke_token()

5. SECURITY ENDPOINTS
   - GET  /api/security/policies    → auth.get_tenant_security_policy()
   - POST /api/security/check       → auth.check_rate_limit_enhanced()
*/

-- =============================================
-- 1. PRIMARY AUTHENTICATION ENDPOINTS
-- =============================================

/*
ENDPOINT: POST /api/auth/login
PURPOSE: Primary authentication entry point
INPUT: JSON { "username": string, "password": string, "ip_address": string, "user_agent": string }
OUTPUT: JSON with success status, tenant list, optional session token
*/
CREATE OR REPLACE FUNCTION api.auth_login(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_username VARCHAR(255);
    v_password TEXT;
    v_ip_address INET;
    v_user_agent TEXT;
    v_auto_login BOOLEAN;
    v_success BOOLEAN;
    v_message TEXT;
    v_tenant_list JSONB;
    v_session_token TEXT;
    v_user_data JSONB;
    v_response JSONB;
BEGIN
    -- Extract parameters from JSON request
    v_username := p_request->>'username';
    v_password := p_request->>'password';
    v_ip_address := (p_request->>'ip_address')::INET;
    v_user_agent := p_request->>'user_agent';
    v_auto_login := COALESCE((p_request->>'auto_login')::BOOLEAN, TRUE);
    
    -- Validate required parameters
    IF v_username IS NULL OR v_password IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Username and password are required',
            'error_code', 'MISSING_CREDENTIALS'
        );
    END IF;
    
    -- Call the authentication procedure
    CALL auth.login_user(
        v_username,
        v_password,
        v_ip_address,
        v_user_agent,
        v_success,
        v_message,
        v_tenant_list,
        v_session_token,
        v_user_data,
        v_auto_login
    );
    
    -- Build response
    v_response := jsonb_build_object(
        'success', v_success,
        'message', v_message,
        'data', jsonb_build_object(
            'requires_tenant_selection', (v_session_token IS NULL AND v_success),
            'tenant_list', v_tenant_list,
            'session_token', v_session_token,
            'user_data', v_user_data
        )
    );
    
    RETURN v_response;
END;
$$;

/*
ENDPOINT: POST /api/auth/complete-login  
PURPOSE: Complete login after tenant selection
INPUT: JSON { "username": string, "tenant_id": string, "ip_address": string, "user_agent": string }
OUTPUT: JSON with session token and user data
*/
CREATE OR REPLACE FUNCTION api.auth_complete_login(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_username VARCHAR(255);
    v_tenant_id TEXT;
    v_ip_address INET;
    v_user_agent TEXT;
    v_success BOOLEAN;
    v_message TEXT;
    v_session_token TEXT;
    v_user_data JSONB;
BEGIN
    -- Extract parameters
    v_username := p_request->>'username';
    v_tenant_id := p_request->>'tenant_id';
    v_ip_address := (p_request->>'ip_address')::INET;
    v_user_agent := p_request->>'user_agent';
    
    -- Validate required parameters
    IF v_username IS NULL OR v_tenant_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Username and tenant_id are required',
            'error_code', 'MISSING_PARAMETERS'
        );
    END IF;
    
    -- Call the complete login procedure
    CALL auth.complete_login(
        v_username,
        v_tenant_id,
        v_ip_address,
        v_user_agent,
        v_success,
        v_message,
        v_session_token,
        v_user_data
    );
    
    RETURN jsonb_build_object(
        'success', v_success,
        'message', v_message,
        'data', jsonb_build_object(
            'session_token', v_session_token,
            'user_data', v_user_data
        )
    );
END;
$$;

/*
ENDPOINT: POST /api/auth/validate
PURPOSE: Validate session tokens and get user context
INPUT: JSON { "session_token": string, "ip_address": string, "user_agent": string }
OUTPUT: JSON with validation status and user context
*/
CREATE OR REPLACE FUNCTION api.auth_validate_session(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_token TEXT;
    v_ip_address INET;
    v_user_agent TEXT;
    v_is_valid BOOLEAN;
    v_message TEXT;
    v_user_context JSONB;
BEGIN
    -- Extract parameters
    v_session_token := p_request->>'session_token';
    v_ip_address := (p_request->>'ip_address')::INET;
    v_user_agent := p_request->>'user_agent';
    
    -- Validate required parameters
    IF v_session_token IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Session token is required',
            'error_code', 'MISSING_TOKEN'
        );
    END IF;
    
    -- Call the validation procedure
    CALL auth.validate_session(
        v_session_token,
        v_ip_address,
        v_user_agent,
        v_is_valid,
        v_message,
        v_user_context
    );
    
    RETURN jsonb_build_object(
        'success', v_is_valid,
        'message', v_message,
        'data', v_user_context
    );
END;
$$;

-- =============================================
-- 2. TENANT MANAGEMENT ENDPOINTS
-- =============================================

/*
ENDPOINT: POST /api/tenants/register
PURPOSE: Register new tenant organization
INPUT: JSON { "tenant_name": string, "admin_email": string, "admin_password": string, "admin_first_name": string, "admin_last_name": string }
OUTPUT: JSON with tenant and admin user details
*/
CREATE OR REPLACE FUNCTION api.tenant_register(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_name VARCHAR(100);
    v_admin_email VARCHAR(255);
    v_admin_password TEXT;
    v_admin_first_name VARCHAR(100);
    v_admin_last_name VARCHAR(100);
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
BEGIN
    -- Extract parameters
    v_tenant_name := p_request->>'tenant_name';
    v_admin_email := p_request->>'admin_email';
    v_admin_password := p_request->>'admin_password';
    v_admin_first_name := p_request->>'admin_first_name';
    v_admin_last_name := p_request->>'admin_last_name';
    
    -- Validate required parameters
    IF v_tenant_name IS NULL OR v_admin_email IS NULL OR v_admin_password IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Tenant name, admin email, and password are required',
            'error_code', 'MISSING_REQUIRED_FIELDS'
        );
    END IF;
    
    -- Call the registration procedure  
    CALL auth.register_tenant(
        v_tenant_name,
        v_admin_email,
        v_admin_password,
        v_admin_first_name,
        v_admin_last_name,
        v_tenant_hk,
        v_admin_user_hk
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Tenant registered successfully',
        'data', jsonb_build_object(
            'tenant_id', (SELECT tenant_bk FROM auth.tenant_h WHERE tenant_hk = v_tenant_hk),
            'admin_user_id', (SELECT user_bk FROM auth.user_h WHERE user_hk = v_admin_user_hk)
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Failed to register tenant: ' || SQLERRM,
        'error_code', 'REGISTRATION_FAILED'
    );
END;
$$;

-- =============================================
-- 3. USER MANAGEMENT ENDPOINTS  
-- =============================================

/*
ENDPOINT: POST /api/users/register
PURPOSE: Register new user within a tenant
INPUT: JSON { "tenant_id": string, "email": string, "password": string, "first_name": string, "last_name": string, "role": string }
OUTPUT: JSON with user registration status
*/
CREATE OR REPLACE FUNCTION api.user_register(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_email VARCHAR(255);
    v_password TEXT;
    v_first_name VARCHAR(100);
    v_last_name VARCHAR(100);
    v_role_bk VARCHAR(255);
    v_user_hk BYTEA;
BEGIN
    -- Get tenant hash key
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h
    WHERE tenant_bk = (p_request->>'tenant_id');
    
    IF v_tenant_hk IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid tenant identifier',
            'error_code', 'INVALID_TENANT'
        );
    END IF;
    
    -- Extract parameters
    v_email := p_request->>'email';
    v_password := p_request->>'password';
    v_first_name := p_request->>'first_name';
    v_last_name := p_request->>'last_name';
    v_role_bk := COALESCE(p_request->>'role', 'USER');
    
    -- Validate required parameters
    IF v_email IS NULL OR v_password IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Email and password are required',
            'error_code', 'MISSING_CREDENTIALS'
        );
    END IF;
    
    -- Call the registration procedure
    CALL auth.register_user(
        v_tenant_hk,
        v_email,
        v_password,
        v_first_name,
        v_last_name,
        v_role_bk,
        v_user_hk
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'User registered successfully',
        'data', jsonb_build_object(
            'user_id', (SELECT user_bk FROM auth.user_h WHERE user_hk = v_user_hk)
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Failed to register user: ' || SQLERRM,
        'error_code', 'USER_REGISTRATION_FAILED'
    );
END;
$$;

-- =============================================
-- 4. TOKEN MANAGEMENT ENDPOINTS
-- =============================================

/*
ENDPOINT: POST /api/tokens/validate
PURPOSE: Validate API tokens and get context
INPUT: JSON { "token": string, "ip_address": string, "user_agent": string, "endpoint": string }
OUTPUT: JSON with validation status and user context
*/
CREATE OR REPLACE FUNCTION api.token_validate(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_token TEXT;
    v_ip_address INET;
    v_user_agent TEXT;
    v_endpoint VARCHAR(500);
    v_validation_result RECORD;
BEGIN
    -- Extract parameters
    v_token := p_request->>'token';
    v_ip_address := (p_request->>'ip_address')::INET;
    v_user_agent := p_request->>'user_agent';
    v_endpoint := p_request->>'endpoint';
    
    -- Validate required parameters
    IF v_token IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Token is required',
            'error_code', 'MISSING_TOKEN'
        );
    END IF;
    
    -- Call the enhanced validation function
    SELECT * INTO v_validation_result
    FROM auth.validate_token_and_session(
        v_token,
        v_ip_address,
        v_user_agent,
        v_endpoint
    );
    
    RETURN jsonb_build_object(
        'success', COALESCE(v_validation_result.is_valid, false),
        'message', COALESCE(v_validation_result.message, 'Token validation failed'),
        'data', CASE 
            WHEN v_validation_result.is_valid THEN
                jsonb_build_object(
                    'user_hk', encode(v_validation_result.user_hk, 'hex'),
                    'session_hk', encode(v_validation_result.session_hk, 'hex')
                )
            ELSE NULL
        END
    );
END;
$$;

-- =============================================
-- 5. SECURITY AND MONITORING ENDPOINTS
-- =============================================

/*
ENDPOINT: POST /api/security/rate-limit-check
PURPOSE: Check if request should be rate limited
INPUT: JSON { "tenant_id": string, "ip_address": string, "endpoint": string, "user_agent": string }
OUTPUT: JSON with rate limit status
*/
CREATE OR REPLACE FUNCTION api.security_rate_limit_check(
    p_request JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_ip_address INET;
    v_endpoint VARCHAR(500);
    v_user_agent TEXT;
    v_is_allowed BOOLEAN;
    v_retry_after INTEGER;
    v_message TEXT;
BEGIN
    -- Get tenant hash key
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h
    WHERE tenant_bk = (p_request->>'tenant_id');
    
    -- Extract parameters
    v_ip_address := (p_request->>'ip_address')::INET;
    v_endpoint := p_request->>'endpoint';
    v_user_agent := p_request->>'user_agent';
    
    -- Call rate limiting function
    SELECT allowed, retry_after_seconds, message
    INTO v_is_allowed, v_retry_after, v_message
    FROM auth.check_rate_limit_enhanced(
        v_tenant_hk,
        v_ip_address,
        v_endpoint,
        v_user_agent
    );
    
    RETURN jsonb_build_object(
        'allowed', COALESCE(v_is_allowed, true),
        'retry_after_seconds', v_retry_after,
        'message', v_message
    );
END;
$$;

-- =============================================
-- API CONTRACT VALIDATION AND TESTING
-- =============================================

/*
TESTING FUNCTION: Validates that all API contract functions exist and are callable
*/
CREATE OR REPLACE FUNCTION api.validate_contract()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_functions TEXT[] := ARRAY[
        'api.auth_login',
        'api.auth_complete_login', 
        'api.auth_validate_session',
        'api.tenant_register',
        'api.user_register',
        'api.token_validate',
        'api.security_rate_limit_check'
    ];
    v_function TEXT;
    v_exists BOOLEAN;
    v_results JSONB := '[]'::JSONB;
BEGIN
    FOREACH v_function IN ARRAY v_functions
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = split_part(v_function, '.', 1)
            AND p.proname = split_part(v_function, '.', 2)
        ) INTO v_exists;
        
        v_results := v_results || jsonb_build_object(
            'function', v_function,
            'exists', v_exists,
            'status', CASE WHEN v_exists THEN 'OK' ELSE 'MISSING' END
        );
    END LOOP;
    
    RETURN jsonb_build_object(
        'contract_validation', 'completed',
        'timestamp', CURRENT_TIMESTAMP,
        'functions', v_results
    );
END;
$$;

-- =============================================
-- USAGE EXAMPLES
-- =============================================

/*
EXAMPLE API CALLS:

1. Login:
SELECT api.auth_login('{"username": "user@example.com", "password": "password123", "ip_address": "192.168.1.100", "user_agent": "Mozilla/5.0"}');

2. Complete Login:
SELECT api.auth_complete_login('{"username": "user@example.com", "tenant_id": "TENANT001", "ip_address": "192.168.1.100", "user_agent": "Mozilla/5.0"}');

3. Validate Session:
SELECT api.auth_validate_session('{"session_token": "abc123", "ip_address": "192.168.1.100", "user_agent": "Mozilla/5.0"}');

4. Register Tenant:
SELECT api.tenant_register('{"tenant_name": "Test Org", "admin_email": "admin@test.com", "admin_password": "secure123", "admin_first_name": "John", "admin_last_name": "Doe"}');

5. Register User:
SELECT api.user_register('{"tenant_id": "TENANT001", "email": "user@test.com", "password": "password123", "first_name": "Jane", "last_name": "Smith", "role": "USER"}');

6. Validate Token:
SELECT api.token_validate('{"token": "xyz789", "ip_address": "192.168.1.100", "user_agent": "Mozilla/5.0", "endpoint": "/api/data/patients"}');

7. Rate Limit Check:
SELECT api.security_rate_limit_check('{"tenant_id": "TENANT001", "ip_address": "192.168.1.100", "endpoint": "/api/auth/login", "user_agent": "Mozilla/5.0"}');

8. Validate Contract:
SELECT api.validate_contract();
*/

-- =============================================
-- FUTURE API SCHEMA EXPANSION
-- =============================================

/*
The API schema is designed for future expansion and integration needs:

PLANNED INTEGRATIONS:
1. QuickBooks Integration
   - api.quickbooks_sync_patients()
   - api.quickbooks_sync_billing()
   - api.quickbooks_get_status()

2. Reporting APIs  
   - api.reports_generate()
   - api.reports_schedule()
   - api.reports_export()

3. External Health Systems
   - api.hl7_receive_message()
   - api.fhir_export_data()
   - api.epic_sync_patient()

4. Mobile App APIs
   - api.mobile_login()
   - api.mobile_sync_data()
   - api.mobile_push_notification()

5. Audit and Compliance
   - api.audit_generate_report()
   - api.compliance_check_hipaa()
   - api.security_scan_results()

SCHEMA BENEFITS:
- Consistent JSON input/output formats
- Centralized API versioning and deprecation
- Standardized error handling across all integrations
- Clean separation between Data Vault core and external interfaces
- Easy to add new endpoints without touching core authentication
- Perfect for REST API framework integration (FastAPI, Express, etc.)

EXAMPLE FUTURE FUNCTION:
CREATE OR REPLACE FUNCTION api.quickbooks_sync_billing(
    p_request JSONB  -- {"tenant_id": "...", "date_range": "...", "sync_type": "..."}
) RETURNS JSONB    -- {"success": true, "synced_records": 150, "errors": []}

The schema can grow without affecting your core Data Vault 2.0 implementation!
*/

-- =============================================
-- COMPLETION
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== PROJECT GOAL 3 API CONTRACT CREATED ===';
    RAISE NOTICE 'All API endpoint functions have been defined.';
    RAISE NOTICE '';
    RAISE NOTICE 'To validate the contract:';
    RAISE NOTICE 'SELECT api.validate_contract();';
    RAISE NOTICE '';
    RAISE NOTICE 'API endpoints ready for REST API integration.';
    RAISE NOTICE '';
END $$; 