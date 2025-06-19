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

-- Satellite table for login attempt details (no password storage)
CREATE TABLE raw.login_details_s (
    login_attempt_hk BYTEA NOT NULL REFERENCES raw.login_attempt_h(login_attempt_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    username VARCHAR(255) NOT NULL,
    password_indicator VARCHAR(50) NOT NULL, -- Security: No actual password data stored
    ip_address INET NOT NULL,
    attempt_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    user_agent TEXT,
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
-- Updated Functions with Corrected Table Names
-- =============================================

CREATE OR REPLACE FUNCTION raw.capture_login_attempt(
    p_tenant_hk BYTEA,
    p_email VARCHAR(255),
    p_password TEXT, -- Received but not stored for security
    p_ip_address INET,
    p_user_agent TEXT
) RETURNS BYTEA AS $$
DECLARE
    v_login_attempt_bk VARCHAR(255);
    v_login_attempt_hk BYTEA;
BEGIN
    -- Create business key using tenant context and timestamp
    v_login_attempt_bk := encode(p_tenant_hk, 'hex') || '_' || 
                         replace(p_email, '@', '_') || '_' ||
                         to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    
    -- Generate hash key
    v_login_attempt_hk := util.hash_binary(v_login_attempt_bk);
    
    -- Insert into hub table
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
        util.current_load_date(),
        util.get_record_source()
    );
    
    -- Insert into satellite table - NO PASSWORD HASH STORED
    INSERT INTO raw.login_details_s (
        login_attempt_hk,
        load_date,
        hash_diff,
        username,
        password_indicator,
        ip_address,
        attempt_timestamp,
        user_agent,
        record_source
    ) VALUES (
        v_login_attempt_hk,
        util.current_load_date(),
        util.hash_concat(p_email, 'PASSWORD_PROVIDED', p_ip_address::text),
        p_email,
        'PASSWORD_PROVIDED', -- Security indicator only
        p_ip_address,
        CURRENT_TIMESTAMP,
        p_user_agent,
        util.get_record_source()
    );
    
    RETURN v_login_attempt_hk;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION raw.capture_login_attempt IS 
'Captures raw login attempt data without validation or password storage. Records both hub and satellite information for the login attempt. Returns the login attempt hash key for reference.';

CREATE OR REPLACE FUNCTION staging.process_raw_login_attempt(
    p_login_attempt_hk BYTEA
) RETURNS BOOLEAN AS $$
DECLARE
    v_raw_login RECORD;
    v_validation_status VARCHAR(20);
    v_validation_message TEXT;
    v_hash_diff BYTEA;
BEGIN
    -- Get raw login attempt data with corrected table names
    SELECT 
        rh.login_attempt_hk,
        rh.login_attempt_bk,
        rh.tenant_hk,
        rs.username,
        rs.password_indicator, -- Corrected field name
        rs.ip_address,
        rs.attempt_timestamp,
        rs.user_agent
    INTO v_raw_login
    FROM raw.login_attempt_h rh
    JOIN raw.login_details_s rs ON rh.login_attempt_hk = rs.login_attempt_hk
    WHERE rh.login_attempt_hk = p_login_attempt_hk
    AND rs.load_end_date IS NULL; -- Get current version only

    -- Basic validation checks
    IF v_raw_login.username IS NULL OR v_raw_login.password_indicator IS NULL THEN
        v_validation_status := 'INVALID';
        v_validation_message := 'Missing required fields';
    ELSE
        v_validation_status := 'VALID';
        v_validation_message := 'Login attempt validated';
    END IF;

    -- Calculate hash diff for staging satellite
    v_hash_diff := util.hash_concat(
        v_raw_login.username,
        v_raw_login.ip_address::text,
        v_raw_login.attempt_timestamp::text,
        v_validation_status
    );
    
    -- Insert into staging hub with corrected table name
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

    -- Insert into staging satellite with corrected table name
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
'Processes a single raw login attempt and creates corresponding staging records. Returns TRUE if successful, FALSE if an error occurred.';

-- =============================================
-- Performance Indexes
-- =============================================

-- Raw layer indexes
CREATE INDEX idx_login_attempt_h_tenant_hk ON raw.login_attempt_h(tenant_hk);
CREATE INDEX idx_login_details_s_username ON raw.login_details_s(username) 
WHERE load_end_date IS NULL;
CREATE INDEX idx_login_details_s_timestamp ON raw.login_details_s(attempt_timestamp) 
WHERE load_end_date IS NULL;

-- Staging layer indexes
CREATE INDEX idx_staging_login_attempt_h_tenant_hk ON staging.login_attempt_h(tenant_hk);
CREATE INDEX idx_staging_login_status_s_username ON staging.login_status_s(username) 
WHERE load_end_date IS NULL;
CREATE INDEX idx_staging_login_status_s_status ON staging.login_status_s(validation_status) 
WHERE load_end_date IS NULL;