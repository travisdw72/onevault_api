-- =============================================
-- CLEAN FIX FOR NAMING CONFLICTS IN PROJECT GOAL 3
-- =============================================
-- This script first drops existing procedures, then creates the fixed versions

-- =============================================
-- STEP 1: DROP EXISTING PROCEDURES
-- =============================================

-- Drop existing procedures that have the wrong OUT parameter names
DROP PROCEDURE IF EXISTS auth.register_tenant(VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR) CASCADE;
DROP PROCEDURE IF EXISTS auth.register_user(BYTEA, VARCHAR, TEXT, VARCHAR, VARCHAR, VARCHAR) CASCADE;

-- Verification
DO $$ BEGIN
    RAISE NOTICE 'SUCCESS: Existing procedures dropped';
END $$;

-- =============================================
-- STEP 2: CREATE FIXED PROCEDURES
-- =============================================

-- Fixed auth.register_tenant with correct OUT parameter names
CREATE OR REPLACE PROCEDURE auth.register_tenant(
    p_tenant_name VARCHAR(100),
    p_admin_email VARCHAR(255),
    p_admin_password TEXT,
    p_admin_first_name VARCHAR(100),
    p_admin_last_name VARCHAR(100),
    OUT p_tenant_hk BYTEA,        -- FIXED: was tenant_hk
    OUT p_admin_user_hk BYTEA      -- FIXED: was admin_user_hk
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
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_record_source VARCHAR(100);
BEGIN
    -- Initialize common values
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();
    
    -- Generate tenant business identifiers
    v_tenant_bk := util.generate_bk(p_tenant_name || '_' || CURRENT_TIMESTAMP::text);
    p_tenant_hk := util.hash_binary(v_tenant_bk);

    -- Step 1: Create tenant hub record
    INSERT INTO auth.tenant_h (
        tenant_hk,
        tenant_bk,
        load_date,
        record_source
    ) VALUES (
        p_tenant_hk,
        v_tenant_bk,
        v_load_date,
        v_record_source
    );

    -- Step 2: Create tenant profile
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
        p_tenant_hk,
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

    -- Step 3: Create administrative role
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
        p_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Step 4: Define role capabilities
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

    -- Step 5: Create admin user
    v_user_bk := util.generate_bk(p_admin_email || '_ADMIN_' || CURRENT_TIMESTAMP::text);
    p_admin_user_hk := util.hash_binary(v_user_bk);
    v_salt := gen_salt('bf');
    v_password_hash := crypt(p_admin_password, v_salt);

    -- Step 6: Create user hub
    INSERT INTO auth.user_h (
        user_hk,
        user_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        p_admin_user_hk,
        v_user_bk,
        p_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Step 7: Create authentication credentials
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
        p_admin_user_hk,
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

    -- Step 8: Create user profile
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
        p_admin_user_hk,
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

    -- Step 9: Create role assignment
    INSERT INTO auth.user_role_l (
        link_user_role_hk,
        user_hk,
        role_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(p_admin_user_hk::text || v_role_hk::text),
        p_admin_user_hk,
        v_role_hk,
        p_tenant_hk,
        v_load_date,
        v_record_source
    );

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Tenant registration failed: % %', SQLSTATE, SQLERRM;
END;
$$;

-- Verification checkpoint 1
DO $$ BEGIN
    RAISE NOTICE 'SUCCESS: auth.register_tenant procedure created';
END $$;

-- Fixed auth.register_user with correct OUT parameter name
CREATE OR REPLACE PROCEDURE auth.register_user(
    p_tenant_hk BYTEA,
    p_email VARCHAR(255),
    p_password TEXT,
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_role_bk VARCHAR(255),
    OUT p_user_hk BYTEA           -- FIXED: was user_hk
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_bk VARCHAR(255);
    v_salt TEXT;
    v_password_hash TEXT;
    v_role_hk BYTEA;
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_record_source VARCHAR(100);
BEGIN
    -- Initialize common values
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();

    -- Generate user credentials
    v_user_bk := util.generate_bk(p_email || '_USER_' || CURRENT_TIMESTAMP::text);
    p_user_hk := util.hash_binary(v_user_bk);
    v_salt := gen_salt('bf');
    v_password_hash := crypt(p_password, v_salt);

    -- Validate role exists
    SELECT role_hk INTO v_role_hk
    FROM auth.role_h
    WHERE role_bk = p_role_bk
    AND tenant_hk = p_tenant_hk;

    IF v_role_hk IS NULL THEN
        RAISE EXCEPTION 'Role % not found for tenant %', p_role_bk, encode(p_tenant_hk, 'hex');
    END IF;

    -- Create user hub
    INSERT INTO auth.user_h (
        user_hk,
        user_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        p_user_hk,
        v_user_bk,
        p_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Create authentication credentials
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
        p_user_hk,
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

    -- Create user profile
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
        p_user_hk,
        v_load_date,
        util.hash_binary(p_first_name || p_last_name || p_email || 'USER_PROFILE'),
        p_first_name,
        p_last_name,
        p_email,
        TRUE,
        CURRENT_TIMESTAMP,
        v_record_source
    );

    -- Create role assignment
    INSERT INTO auth.user_role_l (
        link_user_role_hk,
        user_hk,
        role_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(p_user_hk::text || v_role_hk::text),
        p_user_hk,
        v_role_hk,
        p_tenant_hk,
        v_load_date,
        v_record_source
    );

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'User registration failed: % %', SQLSTATE, SQLERRM;
END;
$$;

-- Verification checkpoint 2
DO $$ BEGIN
    RAISE NOTICE 'SUCCESS: auth.register_user procedure created';
END $$;

-- =============================================
-- STEP 3: TEST THE FIX
-- =============================================

-- Simple test function
CREATE OR REPLACE FUNCTION util.test_registration()
RETURNS TEXT AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
BEGIN
    -- Test tenant registration
    CALL auth.register_tenant(
        'Test Company'::VARCHAR(100),
        'admin@test.com'::VARCHAR(255), 
        'password123'::TEXT,
        'John'::VARCHAR(100),
        'Doe'::VARCHAR(100),
        v_tenant_hk,
        v_admin_user_hk
    );
    
    RETURN 'SUCCESS! Tenant: ' || encode(v_tenant_hk, 'hex') || ' Admin: ' || encode(v_admin_user_hk, 'hex');
           
EXCEPTION WHEN OTHERS THEN
    RETURN 'ERROR: ' || SQLSTATE || ' - ' || SQLERRM;
END $$ LANGUAGE plpgsql;

-- Final verification
DO $$ BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'SETUP COMPLETE! Test with:';
    RAISE NOTICE 'SELECT util.test_registration();';
    RAISE NOTICE '===========================================';
END $$; 