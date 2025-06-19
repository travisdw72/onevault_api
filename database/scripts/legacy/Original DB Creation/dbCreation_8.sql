/**
 * Data Vault 2.0 Tenant and User Registration - Complete Rollback-Safe Implementation
 * 
 * This script provides a comprehensive tenant registration and user management system
 * using the new table naming conventions (_h, _s, _l suffixes) with complete conflict resolution.
 * 
 * Deployment Strategy:
 * - Complete cleanup of existing objects with CASCADE handling
 * - Rollback-safe implementation with proper dependency management
 * - Enhanced error handling and audit logging
 * - HIPAA-compliant security configurations
 */

-- =============================================
-- PHASE 1: COMPREHENSIVE CLEANUP
-- =============================================

-- Drop all potentially conflicting functions and procedures with CASCADE
DROP FUNCTION IF EXISTS util.generate_bk(text) CASCADE;
DROP PROCEDURE IF EXISTS auth.register_tenant(VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR, BYTEA, BYTEA) CASCADE;
DROP PROCEDURE IF EXISTS auth.register_user(BYTEA, VARCHAR, TEXT, VARCHAR, VARCHAR, VARCHAR, BYTEA) CASCADE;

-- Drop any alternative signatures that might exist
DROP FUNCTION IF EXISTS util.generate_bk(VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS util.generate_bk(TEXT, TEXT) CASCADE;

-- =============================================
-- PHASE 2: UTILITY FUNCTION CREATION
-- =============================================

/**
 * util.generate_bk - Generates consistent business keys for Data Vault entities
 * 
 * This function creates standardized business keys that ensure uniqueness
 * while maintaining readability for operational purposes.
 */
CREATE OR REPLACE FUNCTION util.generate_bk(p_input_text TEXT)
RETURNS VARCHAR(255)
LANGUAGE SQL
IMMUTABLE
STRICT
AS $$
    SELECT 'BK_' || encode(util.hash_binary(COALESCE(p_input_text, 'NULL_INPUT')), 'hex');
$$;

COMMENT ON FUNCTION util.generate_bk IS 
'Generates standardized business keys for Data Vault 2.0 entities using consistent hashing methodology';

-- =============================================
-- PHASE 3: TENANT REGISTRATION IMPLEMENTATION
-- =============================================

/**
 * auth.register_tenant - Complete tenant registration with admin user creation
 * 
 * This procedure establishes a complete tenant environment including organizational
 * structure, administrative access, security policies, and audit frameworks.
 * The implementation follows Data Vault 2.0 principles while ensuring HIPAA compliance.
 *
 * Parameters:
 * - p_tenant_name: Organization name for the tenant
 * - p_admin_email: Primary administrator email address
 * - p_admin_password: Initial administrator password (plain text)
 * - p_admin_first_name: Administrator first name
 * - p_admin_last_name: Administrator last name
 *
 * Returns:
 * - tenant_hk: Hash key identifier for the created tenant
 * - admin_user_hk: Hash key identifier for the administrator user
 */
CREATE OR REPLACE PROCEDURE auth.register_tenant(
    p_tenant_name VARCHAR(100),
    p_admin_email VARCHAR(255),
    p_admin_password TEXT,
    p_admin_first_name VARCHAR(100),
    p_admin_last_name VARCHAR(100),
    OUT tenant_hk BYTEA,
    OUT admin_user_hk BYTEA
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_bk VARCHAR(255);
    v_user_bk VARCHAR(255);
    v_salt TEXT;
    v_password_hash TEXT;
    v_role_hk BYTEA;
    v_role_bk VARCHAR(255);
    v_audit_event_hk BYTEA;
    v_audit_event_bk VARCHAR(255);
    v_security_policy_hk BYTEA;
    v_security_policy_bk VARCHAR(255);
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_record_source VARCHAR(100);
BEGIN
    -- Initialize common values
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();
    
    -- Generate tenant business identifiers
    v_tenant_bk := util.generate_bk(p_tenant_name || '_' || CURRENT_TIMESTAMP::text);
    tenant_hk := util.hash_binary(v_tenant_bk);

    -- Create audit framework for tenant registration
    v_audit_event_bk := util.generate_bk('TENANT_REGISTRATION_' || v_tenant_bk);
    v_audit_event_hk := util.hash_binary(v_audit_event_bk);

    -- Step 1: Create tenant hub record
    INSERT INTO auth.tenant_h (
        tenant_hk,
        tenant_bk,
        load_date,
        record_source
    ) VALUES (
        tenant_hk,
        v_tenant_bk,
        v_load_date,
        v_record_source
    );

    -- Step 2: Create comprehensive tenant profile
    INSERT INTO auth.tenant_profile_s (
        tenant_hk,
        load_date,
        hash_diff,
        tenant_name,
        tenant_description,
        is_active,
        subscription_level,
        subscription_start_date,
        contact_email,
        max_users,
        created_date,
        record_source
    ) VALUES (
        tenant_hk,
        v_load_date,
        util.hash_binary(p_tenant_name || 'ACTIVE' || 'standard' || p_admin_email),
        p_tenant_name,
        'Tenant registration for ' || p_tenant_name || ' organization',
        TRUE,
        'standard',
        CURRENT_TIMESTAMP,
        p_admin_email,
        10,
        CURRENT_TIMESTAMP,
        v_record_source
    );

    -- Step 3: Create administrative role structure
    v_role_bk := util.generate_bk('ADMIN_ROLE_' || v_tenant_bk);
    v_role_hk := util.hash_binary(v_role_bk);

    INSERT INTO auth.role_h (
        role_hk,
        role_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_role_hk,
        v_role_bk,
        tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Step 4: Define administrative role capabilities
    INSERT INTO auth.role_definition_s (
        role_hk,
        load_date,
        hash_diff,
        role_name,
        role_description,
        is_system_role,
        permissions,
        created_date,
        record_source
    ) VALUES (
        v_role_hk,
        v_load_date,
        util.hash_binary('ADMINISTRATOR' || 'SYSTEM_ADMIN' || 'FULL_ACCESS'),
        'Administrator',
        'Complete administrative access for tenant operations and user management',
        TRUE,
        jsonb_build_object(
            'user_management', TRUE,
            'system_administration', TRUE,
            'data_access_level', 'full',
            'reporting_access', TRUE,
            'security_management', TRUE,
            'audit_access', TRUE
        ),
        CURRENT_TIMESTAMP,
        v_record_source
    );

    -- Step 5: Generate secure administrator credentials
    v_user_bk := util.generate_bk(p_admin_email || '_ADMIN_' || CURRENT_TIMESTAMP::text);
    admin_user_hk := util.hash_binary(v_user_bk);
    v_salt := gen_salt('bf');
    v_password_hash := crypt(p_admin_password, v_salt);

    -- Step 6: Create administrator user hub
    INSERT INTO auth.user_h (
        user_hk,
        user_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        admin_user_hk,
        v_user_bk,
        tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Step 7: Establish authentication credentials
    INSERT INTO auth.user_auth_s (
        user_hk,
        load_date,
        hash_diff,
        username,
        password_hash,
        password_salt,
        last_login_date,
        password_last_changed,
        failed_login_attempts,
        account_locked,
        must_change_password,
        record_source
    ) VALUES (
        admin_user_hk,
        v_load_date,
        util.hash_binary(p_admin_email || 'ADMIN_AUTH' || CURRENT_TIMESTAMP::text),
        p_admin_email,
        v_password_hash::BYTEA,
        v_salt::BYTEA,
        NULL,
        CURRENT_TIMESTAMP,
        0,
        FALSE,
        FALSE,
        v_record_source
    );

    -- Step 8: Create comprehensive user profile
    INSERT INTO auth.user_profile_s (
        user_hk,
        load_date,
        hash_diff,
        first_name,
        last_name,
        email,
        job_title,
        department,
        is_active,
        created_date,
        record_source
    ) VALUES (
        admin_user_hk,
        v_load_date,
        util.hash_binary(p_admin_first_name || p_admin_last_name || p_admin_email || 'ADMIN'),
        p_admin_first_name,
        p_admin_last_name,
        p_admin_email,
        'System Administrator',
        'Administration',
        TRUE,
        CURRENT_TIMESTAMP,
        v_record_source
    );

    -- Step 9: Establish administrative role assignment
    INSERT INTO auth.user_role_l (
        link_user_role_hk,
        user_hk,
        role_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(admin_user_hk::text || v_role_hk::text),
        admin_user_hk,
        v_role_hk,
        tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Step 10: Create HIPAA-compliant security policy
    v_security_policy_bk := util.generate_bk(v_tenant_bk || '_SECURITY_POLICY');
    v_security_policy_hk := util.hash_binary(v_security_policy_bk);

    INSERT INTO auth.security_policy_h (
        security_policy_hk,
        security_policy_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_security_policy_hk,
        v_security_policy_bk,
        tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Step 11: Configure comprehensive security parameters
    INSERT INTO auth.security_policy_s (
        security_policy_hk,
        load_date,
        hash_diff,
        policy_name,
        policy_description,
        password_min_length,
        password_require_uppercase,
        password_require_lowercase,
        password_require_number,
        password_require_special,
        password_expiry_days,
        account_lockout_threshold,
        account_lockout_duration_minutes,
        session_timeout_minutes,
        require_mfa,
        is_active,
        created_date,
        record_source
    ) VALUES (
        v_security_policy_hk,
        v_load_date,
        util.hash_binary('HIPAA_POLICY' || 'COMPLIANT' || p_tenant_name),
        'HIPAA Compliance Policy',
        'Healthcare-grade security policy ensuring regulatory compliance for ' || p_tenant_name,
        12, -- Strong password length requirement
        TRUE, -- Require uppercase characters
        TRUE, -- Require lowercase characters
        TRUE, -- Require numeric characters
        TRUE, -- Require special characters
        90, -- Password expiration period
        5, -- Account lockout threshold
        30, -- Lockout duration in minutes
        15, -- HIPAA-compliant session timeout
        FALSE, -- MFA can be enabled post-registration
        TRUE, -- Policy is active
        CURRENT_TIMESTAMP,
        v_record_source
    );

    -- Step 12: Create comprehensive audit trail
    INSERT INTO audit.audit_event_h (
        audit_event_hk,
        audit_event_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_audit_event_hk,
        v_audit_event_bk,
        tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Step 13: Document registration transaction details
    INSERT INTO audit.audit_detail_s (
        audit_event_hk,
        load_date,
        hash_diff,
        table_name,
        operation,
        changed_by,
        old_data,
        new_data
    ) VALUES (
        v_audit_event_hk,
        v_load_date,
        util.hash_binary('TENANT_REGISTRATION_COMPLETE' || p_tenant_name),
        'auth.tenant_h',
        'INSERT',
        SESSION_USER,
        NULL,
        jsonb_build_object(
            'tenant_name', p_tenant_name,
            'admin_email', p_admin_email,
            'tenant_hk', encode(tenant_hk, 'hex'),
            'admin_user_hk', encode(admin_user_hk, 'hex'),
            'registration_timestamp', CURRENT_TIMESTAMP,
            'security_policy_applied', 'HIPAA_COMPLIANT'
        )
    );

EXCEPTION WHEN OTHERS THEN
    -- Comprehensive error handling with detailed audit logging
    DECLARE
        v_error_event_hk BYTEA;
        v_error_event_bk VARCHAR(255);
        v_fallback_tenant_hk BYTEA;
    BEGIN
        -- Establish fallback tenant context for error logging
        SELECT tenant_hk INTO v_fallback_tenant_hk 
        FROM auth.tenant_h 
        WHERE tenant_bk LIKE '%SYSTEM%' 
        LIMIT 1;
        
        v_fallback_tenant_hk := COALESCE(tenant_hk, v_fallback_tenant_hk);

        -- Create error audit event
        v_error_event_bk := util.generate_bk('ERROR_TENANT_REGISTRATION_' || COALESCE(p_tenant_name, 'UNKNOWN') || '_' || CURRENT_TIMESTAMP::text);
        v_error_event_hk := util.hash_binary(v_error_event_bk);

        -- Log error event
        INSERT INTO audit.audit_event_h (
            audit_event_hk,
            audit_event_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_error_event_hk,
            v_error_event_bk,
            v_fallback_tenant_hk,
            util.current_load_date(),
            util.get_record_source()
        );

        -- Document error details for troubleshooting
        INSERT INTO audit.audit_detail_s (
            audit_event_hk,
            load_date,
            hash_diff,
            table_name,
            operation,
            changed_by,
            old_data,
            new_data
        ) VALUES (
            v_error_event_hk,
            util.current_load_date(),
            util.hash_binary(SQLSTATE || SQLERRM),
            'auth.register_tenant',
            'ERROR',
            SESSION_USER,
            NULL,
            jsonb_build_object(
                'error_code', SQLSTATE,
                'error_message', SQLERRM,
                'tenant_name', COALESCE(p_tenant_name, 'NULL'),
                'admin_email', COALESCE(p_admin_email, 'NULL'),
                'error_timestamp', CURRENT_TIMESTAMP
            )
        );
    END;
    
    RAISE;
END;
$$;

-- =============================================
-- PHASE 4: USER REGISTRATION IMPLEMENTATION
-- =============================================

/**
 * auth.register_user - Register additional users within existing tenant
 * 
 * This procedure creates new user accounts within an established tenant environment
 * with appropriate role assignments and comprehensive audit documentation.
 *
 * Parameters:
 * - p_tenant_hk: Hash key of the target tenant
 * - p_email: User email address (serves as username)
 * - p_password: Initial user password (plain text)
 * - p_first_name: User first name
 * - p_last_name: User last name
 * - p_role_bk: Business key of the role to assign
 *
 * Returns:
 * - user_hk: Hash key identifier for the created user
 */
CREATE OR REPLACE PROCEDURE auth.register_user(
    p_tenant_hk BYTEA,
    p_email VARCHAR(255),
    p_password TEXT,
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_role_bk VARCHAR(255),
    OUT user_hk BYTEA
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_bk VARCHAR(255);
    v_salt TEXT;
    v_password_hash TEXT;
    v_role_hk BYTEA;
    v_audit_event_hk BYTEA;
    v_audit_event_bk VARCHAR(255);
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_record_source VARCHAR(100);
    v_tenant_name VARCHAR(100);
BEGIN
    -- Initialize common values
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();
    
    -- Get tenant name for audit purposes
    SELECT tenant_name INTO v_tenant_name
    FROM auth.tenant_profile_s
    WHERE tenant_hk = p_tenant_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    -- Generate secure user credentials
    v_user_bk := util.generate_bk(p_email || '_USER_' || CURRENT_TIMESTAMP::text);
    user_hk := util.hash_binary(v_user_bk);
    v_salt := gen_salt('bf');
    v_password_hash := crypt(p_password, v_salt);

    -- Validate role availability within tenant
    SELECT role_hk INTO v_role_hk
    FROM auth.role_h
    WHERE role_bk = p_role_bk
    AND tenant_hk = p_tenant_hk;

    IF v_role_hk IS NULL THEN
        RAISE EXCEPTION 'Role % not found for tenant % (%)', 
            p_role_bk, 
            COALESCE(v_tenant_name, 'UNKNOWN'), 
            encode(p_tenant_hk, 'hex');
    END IF;

    -- Step 1: Create user hub record
    INSERT INTO auth.user_h (
        user_hk,
        user_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        user_hk,
        v_user_bk,
        p_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Step 2: Establish authentication credentials
    INSERT INTO auth.user_auth_s (
        user_hk,
        load_date,
        hash_diff,
        username,
        password_hash,
        password_salt,
        last_login_date,
        password_last_changed,
        failed_login_attempts,
        account_locked,
        must_change_password,
        record_source
    ) VALUES (
        user_hk,
        v_load_date,
        util.hash_binary(p_email || 'USER_AUTH' || CURRENT_TIMESTAMP::text),
        p_email,
        v_password_hash::BYTEA,
        v_salt::BYTEA,
        NULL,
        CURRENT_TIMESTAMP,
        0,
        FALSE,
        FALSE,
        v_record_source
    );

    -- Step 3: Create comprehensive user profile
    INSERT INTO auth.user_profile_s (
        user_hk,
        load_date,
        hash_diff,
        first_name,
        last_name,
        email,
        is_active,
        created_date,
        record_source
    ) VALUES (
        user_hk,
        v_load_date,
        util.hash_binary(p_first_name || p_last_name || p_email || 'USER_PROFILE'),
        p_first_name,
        p_last_name,
        p_email,
        TRUE,
        CURRENT_TIMESTAMP,
        v_record_source
    );

    -- Step 4: Establish role assignment
    INSERT INTO auth.user_role_l (
        link_user_role_hk,
        user_hk,
        role_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(user_hk::text || v_role_hk::text),
        user_hk,
        v_role_hk,
        p_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Step 5: Create comprehensive audit trail
    v_audit_event_bk := util.generate_bk('USER_REGISTRATION_' || p_email || '_' || CURRENT_TIMESTAMP::text);
    v_audit_event_hk := util.hash_binary(v_audit_event_bk);

    INSERT INTO audit.audit_event_h (
        audit_event_hk,
        audit_event_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_audit_event_hk,
        v_audit_event_bk,
        p_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Step 6: Document user registration details
    INSERT INTO audit.audit_detail_s (
        audit_event_hk,
        load_date,
        hash_diff,
        table_name,
        operation,
        changed_by,
        old_data,
        new_data
    ) VALUES (
        v_audit_event_hk,
        v_load_date,
        util.hash_binary('USER_REGISTRATION_COMPLETE' || p_email),
        'auth.user_h',
        'INSERT',
        SESSION_USER,
        NULL,
        jsonb_build_object(
            'email', p_email,
            'first_name', p_first_name,
            'last_name', p_last_name,
            'role_bk', p_role_bk,
            'user_hk', encode(user_hk, 'hex'),
            'tenant_hk', encode(p_tenant_hk, 'hex'),
            'tenant_name', COALESCE(v_tenant_name, 'UNKNOWN'),
            'registration_timestamp', CURRENT_TIMESTAMP
        )
    );

EXCEPTION WHEN OTHERS THEN
    -- Comprehensive error handling with audit documentation
    DECLARE
        v_error_event_hk BYTEA;
        v_error_event_bk VARCHAR(255);
    BEGIN
        -- Create error audit event
        v_error_event_bk := util.generate_bk('ERROR_USER_REGISTRATION_' || COALESCE(p_email, 'UNKNOWN') || '_' || CURRENT_TIMESTAMP::text);
        v_error_event_hk := util.hash_binary(v_error_event_bk);

        -- Log error event
        INSERT INTO audit.audit_event_h (
            audit_event_hk,
            audit_event_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_error_event_hk,
            v_error_event_bk,
            p_tenant_hk,
            util.current_load_date(),
            util.get_record_source()
        );

        -- Document error details for operational support
        INSERT INTO audit.audit_detail_s (
            audit_event_hk,
            load_date,
            hash_diff,
            table_name,
            operation,
            changed_by,
            old_data,
            new_data
        ) VALUES (
            v_error_event_hk,
            util.current_load_date(),
            util.hash_binary(SQLSTATE || SQLERRM),
            'auth.register_user',
            'ERROR',
            SESSION_USER,
            NULL,
            jsonb_build_object(
                'error_code', SQLSTATE,
                'error_message', SQLERRM,
                'email', COALESCE(p_email, 'NULL'),
                'tenant_hk', encode(p_tenant_hk, 'hex'),
                'role_bk', COALESCE(p_role_bk, 'NULL'),
                'error_timestamp', CURRENT_TIMESTAMP
            )
        );
    END;
    
    RAISE;
END;
$$;

-- =============================================
-- PHASE 5: PERFORMANCE OPTIMIZATION
-- =============================================

-- Create strategic indexes for tenant and user management operations
CREATE INDEX IF NOT EXISTS idx_tenant_profile_s_tenant_name 
    ON auth.tenant_profile_s(tenant_name) 
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_tenant_profile_s_contact_email 
    ON auth.tenant_profile_s(contact_email) 
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_auth_s_username_tenant 
    ON auth.user_auth_s(username) 
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_profile_s_email_active 
    ON auth.user_profile_s(email) 
    WHERE load_end_date IS NULL AND is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_role_definition_s_tenant_active 
    ON auth.role_definition_s(role_name) 
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_security_policy_s_tenant_active 
    ON auth.security_policy_s(policy_name) 
    WHERE load_end_date IS NULL AND is_active = TRUE;

-- =============================================
-- PHASE 6: DOCUMENTATION AND COMPLIANCE
-- =============================================

-- Comprehensive procedure documentation
COMMENT ON PROCEDURE auth.register_tenant IS 
'Comprehensive tenant registration creating complete organizational infrastructure including administrative users, role hierarchies, security policies, and audit frameworks. Implements HIPAA-compliant defaults and maintains complete transaction audit trails for regulatory compliance.';

COMMENT ON PROCEDURE auth.register_user IS 
'Secure user registration within existing tenant environments with role-based access control and comprehensive audit documentation. Supports multi-tenant isolation while maintaining operational flexibility and compliance requirements.';

COMMENT ON FUNCTION util.generate_bk IS 
'Standardized business key generation for Data Vault 2.0 entities ensuring consistency across the authentication and tenant management infrastructure.';

-- Schema documentation for operational reference
COMMENT ON SCHEMA auth IS 
'Authentication and authorization infrastructure implementing Data Vault 2.0 methodology with comprehensive tenant isolation, role-based access control, and HIPAA-compliant audit frameworks suitable for healthcare and enterprise SaaS applications.';