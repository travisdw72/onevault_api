-- =============================================
-- Step 12: Security Policy Management
-- Data Vault 2.0 with New Naming Conventions
-- HIPAA-Compliant Security Policy Implementation
-- =============================================

-- Function to process hexadecimal tenant values
CREATE OR REPLACE FUNCTION util.process_hex_tenant(hex_string text)
RETURNS bytea
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT decode(
        CASE 
            WHEN hex_string LIKE '\\x%' THEN substring(hex_string from 3)
            WHEN hex_string LIKE '\x%' THEN substring(hex_string from 2)
            ELSE hex_string
        END, 
        'hex'
    );
$$;

-- Function to generate policy business keys consistently
CREATE OR REPLACE FUNCTION auth.generate_policy_bk(
    p_tenant_hk BYTEA,
    p_policy_name VARCHAR(50)
) RETURNS VARCHAR(50) AS $$
BEGIN
    RETURN 'POLICY_' || substr(encode(p_tenant_hk, 'hex'), 1, 8) || '_' || p_policy_name;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Procedure to establish base security policies
CREATE OR REPLACE PROCEDURE auth.establish_base_security_policy(
    p_tenant_hk BYTEA,
    p_policy_name VARCHAR(50)
) LANGUAGE plpgsql AS $$
DECLARE
    v_policy_bk VARCHAR(50);
    v_policy_hk BYTEA;
    v_base_hash_diff BYTEA;
BEGIN
    -- Generate policy identifiers
    v_policy_bk := auth.generate_policy_bk(p_tenant_hk, p_policy_name);
    v_policy_hk := util.hash_binary(v_policy_bk);
    
    -- Calculate initial hash diff for satellite
    v_base_hash_diff := util.hash_binary(v_policy_bk || CURRENT_TIMESTAMP::text);

    -- Insert into hub if not exists
    INSERT INTO auth.security_policy_h (
        security_policy_hk,
        security_policy_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_policy_hk,
        v_policy_bk,
        p_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    ) ON CONFLICT (security_policy_hk) DO NOTHING;

    -- Insert HIPAA-compliant security settings into satellite
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
        password_history_count,
        session_absolute_timeout_hours,
        mfa_timeout_minutes,
        is_active,
        record_source
    ) VALUES (
        v_policy_hk,
        util.current_load_date(),
        v_base_hash_diff,
        p_policy_name,
        'HIPAA-compliant security policy for tenant',
        12,                   -- password_min_length: Strong password requirement
        TRUE,                 -- password_require_uppercase: Enhanced password complexity
        TRUE,                 -- password_require_lowercase: Enhanced password complexity
        TRUE,                 -- password_require_number: Enhanced password complexity
        TRUE,                 -- password_require_special: Complex password requirement
        90,                   -- password_expiry_days: HIPAA password change requirement
        5,                    -- account_lockout_threshold: HIPAA recommends limiting failed attempts
        30,                   -- account_lockout_duration_minutes: 30-minute lockout period
        15,                   -- session_timeout_minutes: HIPAA requires automatic logoff
        TRUE,                 -- require_mfa: Enhanced security requirement
        24,                   -- password_history_count: Prevent password reuse
        12,                   -- session_absolute_timeout_hours: Maximum session duration
        5,                    -- mfa_timeout_minutes: MFA code expiration
        TRUE,                 -- is_active: Policy is active
        util.get_record_source()
    );
END;
$$;

-- Procedure to update existing security policies
CREATE OR REPLACE PROCEDURE auth.update_security_policy(
    p_policy_hk BYTEA,
    p_updates JSONB
) LANGUAGE plpgsql AS $$
DECLARE
    v_current_policy auth.security_policy_s%ROWTYPE;
    v_new_hash_diff BYTEA;
BEGIN
    -- Get current policy settings
    SELECT * INTO v_current_policy
    FROM auth.security_policy_s
    WHERE security_policy_hk = p_policy_hk
    ORDER BY load_date DESC
    LIMIT 1;

    -- Calculate new hash diff
    v_new_hash_diff := util.hash_binary(
        p_policy_hk::text || 
        COALESCE(p_updates->>'password_min_length', v_current_policy.password_min_length::text) ||
        CURRENT_TIMESTAMP::text
    );

    -- Insert new policy version with updated settings
    INSERT INTO auth.security_policy_s (
        security_policy_hk,
        load_date,
        load_end_date,
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
        password_history_count,
        session_absolute_timeout_hours,
        mfa_timeout_minutes,
        is_active,
        record_source
    )
    SELECT
        p_policy_hk,
        util.current_load_date(),
        NULL, -- load_end_date
        v_new_hash_diff,
        COALESCE(p_updates->>'policy_name', policy_name),
        COALESCE(p_updates->>'policy_description', policy_description),
        COALESCE((p_updates->>'password_min_length')::integer, password_min_length),
        COALESCE((p_updates->>'password_require_uppercase')::boolean, password_require_uppercase),
        COALESCE((p_updates->>'password_require_lowercase')::boolean, password_require_lowercase),
        COALESCE((p_updates->>'password_require_number')::boolean, password_require_number),
        COALESCE((p_updates->>'password_require_special')::boolean, password_require_special),
        COALESCE((p_updates->>'password_expiry_days')::integer, password_expiry_days),
        COALESCE((p_updates->>'account_lockout_threshold')::integer, account_lockout_threshold),
        COALESCE((p_updates->>'account_lockout_duration_minutes')::integer, account_lockout_duration_minutes),
        COALESCE((p_updates->>'session_timeout_minutes')::integer, session_timeout_minutes),
        COALESCE((p_updates->>'require_mfa')::boolean, require_mfa),
        COALESCE((p_updates->>'password_history_count')::integer, password_history_count),
        COALESCE((p_updates->>'session_absolute_timeout_hours')::integer, session_absolute_timeout_hours),
        COALESCE((p_updates->>'mfa_timeout_minutes')::integer, mfa_timeout_minutes),
        COALESCE((p_updates->>'is_active')::boolean, is_active),
        util.get_record_source()
    FROM auth.security_policy_s
    WHERE security_policy_hk = p_policy_hk
    ORDER BY load_date DESC
    LIMIT 1;

    -- End-date the previous record
    UPDATE auth.security_policy_s
    SET load_end_date = util.current_load_date()
    WHERE security_policy_hk = p_policy_hk
    AND load_date = v_current_policy.load_date;
END;
$$;

-- Function to validate if a policy meets HIPAA minimum requirements
CREATE OR REPLACE FUNCTION auth.validate_hipaa_policy(
    p_policy_hk BYTEA
) RETURNS TABLE (
    is_compliant BOOLEAN,
    validation_messages TEXT[]
) AS $$
DECLARE
    v_messages TEXT[] := ARRAY[]::TEXT[];
    v_policy auth.security_policy_s%ROWTYPE;
BEGIN
    -- Get current policy settings
    SELECT * INTO v_policy
    FROM auth.security_policy_s
    WHERE security_policy_hk = p_policy_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    -- Validate each HIPAA requirement
    IF v_policy.password_min_length < 12 THEN
        v_messages := array_append(v_messages, 'Password length must be at least 12 characters for HIPAA compliance');
    END IF;

    IF NOT v_policy.password_require_special OR 
       NOT v_policy.password_require_number OR 
       NOT v_policy.password_require_uppercase THEN
        v_messages := array_append(v_messages, 'Password must require special characters, numbers, and uppercase letters');
    END IF;

    IF v_policy.password_expiry_days > 90 THEN
        v_messages := array_append(v_messages, 'Passwords must expire within 90 days for HIPAA compliance');
    END IF;

    IF v_policy.session_timeout_minutes > 15 THEN
        v_messages := array_append(v_messages, 'Session timeout must not exceed 15 minutes for HIPAA compliance');
    END IF;

    IF NOT v_policy.require_mfa THEN
        v_messages := array_append(v_messages, 'Multi-factor authentication must be enabled for HIPAA compliance');
    END IF;

    IF v_policy.password_history_count < 12 THEN
        v_messages := array_append(v_messages, 'Password history must remember at least 12 previous passwords');
    END IF;

    IF v_policy.account_lockout_threshold > 5 THEN
        v_messages := array_append(v_messages, 'Account lockout threshold should not exceed 5 failed attempts');
    END IF;

    RETURN QUERY SELECT 
        CASE WHEN array_length(v_messages, 1) IS NULL THEN TRUE ELSE FALSE END,
        v_messages;
END;
$$ LANGUAGE plpgsql;

-- Function to get active security policy for a tenant
CREATE OR REPLACE FUNCTION auth.get_tenant_security_policy(
    p_tenant_hk BYTEA
) RETURNS TABLE (
    security_policy_hk BYTEA,
    policy_name VARCHAR,
    password_min_length INTEGER,
    session_timeout_minutes INTEGER,
    require_mfa BOOLEAN,
    is_hipaa_compliant BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH policy_data AS (
        SELECT 
            sp_h.security_policy_hk,
            sp_s.policy_name,
            sp_s.password_min_length,
            sp_s.session_timeout_minutes,
            sp_s.require_mfa,
            sp_s.password_require_special,
            sp_s.password_require_number,
            sp_s.password_require_uppercase,
            sp_s.password_expiry_days,
            sp_s.password_history_count,
            sp_s.account_lockout_threshold
        FROM auth.security_policy_h sp_h
        JOIN auth.security_policy_s sp_s ON sp_h.security_policy_hk = sp_s.security_policy_hk
        WHERE sp_h.tenant_hk = p_tenant_hk
        AND sp_s.is_active = TRUE
        AND sp_s.load_end_date IS NULL
        ORDER BY sp_s.load_date DESC
        LIMIT 1
    )
    SELECT 
        pd.security_policy_hk,
        pd.policy_name,
        pd.password_min_length,
        pd.session_timeout_minutes,
        pd.require_mfa,
        CASE 
            WHEN pd.password_min_length >= 12 
            AND pd.password_require_special 
            AND pd.password_require_number 
            AND pd.password_require_uppercase
            AND pd.password_expiry_days <= 90
            AND pd.session_timeout_minutes <= 15
            AND pd.require_mfa
            AND pd.password_history_count >= 12
            AND pd.account_lockout_threshold <= 5
            THEN TRUE 
            ELSE FALSE 
        END AS is_hipaa_compliant
    FROM policy_data pd;
END;
$$ LANGUAGE plpgsql;

-- Create audit triggers for the new tables
SELECT util.create_audit_triggers('auth');

-- Create indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_security_policy_h_tenant_hk 
ON auth.security_policy_h(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_security_policy_s_active 
ON auth.security_policy_s(security_policy_hk, is_active) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_security_policy_s_load_date 
ON auth.security_policy_s(security_policy_hk, load_date DESC);

-- Example usage for creating a default HIPAA-compliant policy for a tenant
/*
-- Create a base security policy for a tenant
CALL auth.establish_base_security_policy(
    decode('a1b2c3d4e5f6', 'hex'), -- tenant_hk
    'DEFAULT_HIPAA_POLICY'
);

-- Validate HIPAA compliance
SELECT * FROM auth.validate_hipaa_policy(
    (SELECT security_policy_hk FROM auth.security_policy_h WHERE security_policy_bk LIKE '%DEFAULT_HIPAA_POLICY%' LIMIT 1)
);

-- Get tenant security policy
SELECT * FROM auth.get_tenant_security_policy(
    decode('a1b2c3d4e5f6', 'hex') -- tenant_hk
);

-- Update a security policy
CALL auth.update_security_policy(
    (SELECT security_policy_hk FROM auth.security_policy_h WHERE security_policy_bk LIKE '%DEFAULT_HIPAA_POLICY%' LIMIT 1),
    '{"session_timeout_minutes": 10, "password_min_length": 14}'::jsonb
);
*/

COMMENT ON PROCEDURE auth.establish_base_security_policy IS 
'Creates HIPAA-compliant base security policy for a tenant with enterprise-grade security defaults';

COMMENT ON FUNCTION auth.validate_hipaa_policy IS 
'Validates security policy against HIPAA compliance requirements and returns detailed validation results';

COMMENT ON FUNCTION auth.get_tenant_security_policy IS 
'Retrieves active security policy for a tenant with HIPAA compliance status indicator';