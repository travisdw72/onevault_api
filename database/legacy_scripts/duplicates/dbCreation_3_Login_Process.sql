-- =============================================
-- Raw Login Attempt Tables (Updated Naming Convention)
-- =============================================

-- Hub table for raw login attempts
CREATE TABLE raw.login_attempt_h (
    login_attempt_hk BYTEA PRIMARY KEY,
    login_attempt_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Satellite table for login attempt details (NO PASSWORD STORAGE)
CREATE TABLE raw.login_attempt_s (
    login_attempt_hk BYTEA NOT NULL REFERENCES raw.login_attempt_h(login_attempt_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    username VARCHAR(255) NOT NULL,
    password_indicator VARCHAR(50) NOT NULL DEFAULT 'HASH_PROVIDED', -- Security: No actual password data
    ip_address INET NOT NULL,
    user_agent TEXT,
    attempt_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (login_attempt_hk, load_date)
);

-- =============================================
-- Staging Login Processing Tables
-- =============================================

-- Hub table for staging login attempts
CREATE TABLE staging.login_attempt_h (
    login_attempt_hk BYTEA PRIMARY KEY,
    login_attempt_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Satellite table for login validation status
CREATE TABLE staging.login_status_s (
    login_attempt_hk BYTEA NOT NULL REFERENCES staging.login_attempt_h(login_attempt_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    username VARCHAR(255) NOT NULL,
    ip_address INET NOT NULL,
    attempt_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    user_agent TEXT,
    validation_status VARCHAR(20) NOT NULL,
    validation_message TEXT,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (login_attempt_hk, load_date)
);

-- =============================================
-- SECURE Raw Login Capture Function (4 parameters - NO PASSWORD)
-- =============================================

CREATE OR REPLACE FUNCTION raw.capture_login_attempt(
    p_tenant_hk BYTEA,
    p_username VARCHAR(255),
    p_ip_address INET,
    p_user_agent TEXT
) RETURNS BYTEA 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_login_attempt_bk VARCHAR(255);
    v_login_attempt_hk BYTEA;
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_record_source VARCHAR(100);
BEGIN
    -- Initialize operational variables
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();
    
    -- Generate business key for login attempt
    v_login_attempt_bk := util.generate_bk(p_username || '_' || p_ip_address::text || '_' || v_load_date::text);
    v_login_attempt_hk := util.hash_binary(v_login_attempt_bk);
    
    -- Insert into raw login attempt hub
    INSERT INTO raw.login_attempt_h (
        login_attempt_hk,
        login_attempt_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_login_attempt_hk,
        v_login_attempt_bk,
        p_tenant_hk,
        v_load_date,
        v_record_source
    ) ON CONFLICT (login_attempt_hk) DO NOTHING;
    
    -- Insert into raw login attempt satellite (NO PASSWORD DATA)
    INSERT INTO raw.login_attempt_s (
        login_attempt_hk,
        load_date,
        hash_diff,
        username,
        password_indicator,
        ip_address,
        user_agent,
        attempt_timestamp,
        record_source
    ) VALUES (
        v_login_attempt_hk,
        v_load_date,
        util.hash_binary(p_username || p_ip_address::text || v_load_date::text),
        p_username,
        'HASH_PROVIDED',  -- Security: Never store actual password data
        p_ip_address,
        p_user_agent,
        v_load_date,
        v_record_source
    );
    
    RETURN v_login_attempt_hk;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to capture login attempt: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION raw.capture_login_attempt IS 
'Securely captures login attempt data without storing any password information. Password validation occurs at the API level before calling this function.';

-- =============================================
-- Staging Processing Function (Working Database Version)
-- =============================================

CREATE OR REPLACE FUNCTION staging.validate_login_credentials(
    p_login_attempt_hk BYTEA
) RETURNS JSONB 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_login_details RECORD;
    v_user RECORD;
    v_result JSONB;
BEGIN
    -- Get login attempt details (username and IP only - no password data)
    SELECT 
        username,
        ip_address
    INTO v_login_details
    FROM raw.login_attempt_s  -- Updated to correct table name
    WHERE login_attempt_hk = p_login_attempt_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC 
    LIMIT 1;
    
    -- Get user credentials and account status
    SELECT 
        user_hk,
        password_hash,
        account_locked
    INTO v_user
    FROM auth.user_auth_s
    WHERE username = v_login_details.username
    AND load_end_date IS NULL
    ORDER BY load_date DESC 
    LIMIT 1;
    
    -- Account validation logic (NOT password validation)
    IF v_user.user_hk IS NULL THEN
        v_result := jsonb_build_object('status', 'INVALID_USER');
    ELSIF v_user.account_locked = true THEN
        v_result := jsonb_build_object('status', 'LOCKED');
    ELSE
        -- Account is valid and in good standing
        v_result := jsonb_build_object(
            'status', 'VALID',
            'user_hk', encode(v_user.user_hk, 'hex')
        );
    END IF;
    
    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION staging.validate_login_credentials IS 
'Validates user account status (exists, not locked) for login attempts. Password validation occurs at API level before this function is called.';

-- Keep the data movement function for staging records
CREATE OR REPLACE FUNCTION staging.process_raw_login_attempt(
    p_login_attempt_hk BYTEA
) RETURNS BOOLEAN AS $$
DECLARE
    v_raw_login RECORD;
    v_validation_status VARCHAR(20);
    v_validation_message TEXT;
    v_hash_diff BYTEA;
BEGIN
    -- Get raw login attempt data
    SELECT 
        rh.login_attempt_hk,
        rh.login_attempt_bk,
        rh.tenant_hk,
        rs.username,
        rs.password_indicator,
        rs.ip_address,
        rs.attempt_timestamp,
        rs.user_agent
    INTO v_raw_login
    FROM raw.login_attempt_h rh
    JOIN raw.login_attempt_s rs ON rh.login_attempt_hk = rs.login_attempt_hk
    WHERE rh.login_attempt_hk = p_login_attempt_hk
    AND rs.load_end_date IS NULL;

    -- Basic validation checks for data integrity
    IF v_raw_login.username IS NULL THEN
        v_validation_status := 'INVALID';
        v_validation_message := 'Missing username';
    ELSIF v_raw_login.password_indicator != 'HASH_PROVIDED' THEN
        v_validation_status := 'INVALID';
        v_validation_message := 'Invalid password indicator';
    ELSE
        v_validation_status := 'CAPTURED';
        v_validation_message := 'Login attempt captured for validation';
    END IF;

    -- Calculate hash diff for staging satellite
    v_hash_diff := util.hash_concat(
        v_raw_login.username,
        v_raw_login.ip_address::text,
        v_raw_login.attempt_timestamp::text,
        v_validation_status
    );
    
    -- Insert into staging hub
    INSERT INTO staging.login_attempt_h (
        login_attempt_hk,
        login_attempt_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_raw_login.login_attempt_hk,
        v_raw_login.login_attempt_bk,
        v_raw_login.tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    )
    ON CONFLICT (login_attempt_hk) DO NOTHING;

    -- Insert into staging satellite
    INSERT INTO staging.login_status_s (
        login_attempt_hk,
        load_date,
        hash_diff,
        username,
        ip_address,
        attempt_timestamp,
        user_agent,
        validation_status,
        validation_message,
        record_source
    ) VALUES (
        v_raw_login.login_attempt_hk,
        util.current_load_date(),
        v_hash_diff,
        v_raw_login.username,
        v_raw_login.ip_address,
        v_raw_login.attempt_timestamp,
        v_raw_login.user_agent,
        v_validation_status,
        v_validation_message,
        util.get_record_source()
    );

    RETURN TRUE;

EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION staging.process_raw_login_attempt IS 
'Processes raw login attempt data and creates staging records for audit trail and data lineage.';

-- =============================================
-- Performance Indexes
-- =============================================

-- Raw layer indexes
CREATE INDEX idx_login_attempt_h_tenant_hk ON raw.login_attempt_h(tenant_hk);
CREATE INDEX idx_login_attempt_s_username ON raw.login_attempt_s(username) 
WHERE load_end_date IS NULL;
CREATE INDEX idx_login_attempt_s_timestamp ON raw.login_attempt_s(attempt_timestamp) 
WHERE load_end_date IS NULL;

-- Staging layer indexes
CREATE INDEX idx_staging_login_attempt_h_tenant_hk ON staging.login_attempt_h(tenant_hk);
CREATE INDEX idx_staging_login_status_s_username ON staging.login_status_s(username) 
WHERE load_end_date IS NULL;
CREATE INDEX idx_staging_login_status_s_status ON staging.login_status_s(validation_status) 
WHERE load_end_date IS NULL;