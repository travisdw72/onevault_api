-- =============================================
-- Token Activity Tracking Table (Missing from previous scripts) with corrected table names
-- =============================================

-- Satellite table for token activity tracking
CREATE TABLE auth.token_activity_s (
    token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(token_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    last_activity_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    endpoint_accessed VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (token_hk, load_date)
);

-- =============================================
-- Updated Raw Login Capture Function
-- =============================================

CREATE OR REPLACE FUNCTION raw.capture_login_attempt(
    p_tenant_hk BYTEA,
    p_email VARCHAR(255),
    p_password TEXT,
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
    
    -- Insert into hub table with corrected table name
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
    
    -- Store raw password temporarily for validation with corrected table name
    INSERT INTO raw.login_details_s (
        login_attempt_hk,
        load_date,
        hash_diff,
        username,
        password_indicator, -- Updated field name for security
        ip_address,
        attempt_timestamp,
        user_agent,
        record_source
    ) VALUES (
        v_login_attempt_hk,
        util.current_load_date(),
        util.hash_concat(p_email, 'PASSWORD_PROVIDED', p_ip_address::text),
        p_email,
        convert_to(p_password, 'UTF8'),  -- Temporary storage for validation only
        p_ip_address,
        CURRENT_TIMESTAMP,
        p_user_agent,
        util.get_record_source()
    );
    
    RETURN v_login_attempt_hk;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION raw.capture_login_attempt IS 
'Captures raw login attempt data with temporary password storage for validation. The password is stored temporarily in bytea format for immediate validation processing only.';

-- =============================================
-- Updated Token and Session Validation Function
-- =============================================

CREATE OR REPLACE FUNCTION auth.validate_token_and_session(
    p_token_value TEXT,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS TABLE (
    is_valid BOOLEAN,
    user_hk BYTEA,
    session_hk BYTEA,
    username VARCHAR,
    message TEXT
) AS $$
DECLARE
    v_token_hk BYTEA;
    v_ip_address INET;
BEGIN
    -- Convert token string directly to token hash key
    v_token_hk := decode(p_token_value, 'hex');
    
    -- Convert IP address safely if provided
    BEGIN
        IF p_ip_address IS NOT NULL AND p_ip_address != '' THEN
            v_ip_address := p_ip_address::INET;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_ip_address := NULL;
    END;
    
    -- Return validation results with completely corrected table names
    RETURN QUERY
    WITH token_data AS (
        SELECT 
            sat.token_hk,
            sat.is_revoked,
            sat.expires_at,
            lst.session_hk,
            sss.session_status,
            lus.user_hk,
            sua.username
        FROM auth.api_token_h hat
        JOIN auth.api_token_s sat ON hat.token_hk = sat.token_hk
        JOIN auth.session_token_l lst ON sat.token_hk = lst.token_hk
        JOIN auth.session_state_s sss ON lst.session_hk = sss.session_hk
        JOIN auth.user_session_l lus ON lst.session_hk = lus.session_hk
        JOIN auth.user_auth_s sua ON lus.user_hk = sua.user_hk
        WHERE hat.token_hk = v_token_hk
        AND sat.load_end_date IS NULL
        AND sss.load_end_date IS NULL
        AND sua.load_end_date IS NULL
        ORDER BY sat.load_date DESC, sss.load_date DESC, sua.load_date DESC
        LIMIT 1
    )
    SELECT 
        CASE 
            WHEN td.token_hk IS NULL THEN FALSE
            WHEN td.is_revoked THEN FALSE
            WHEN td.expires_at < CURRENT_TIMESTAMP THEN FALSE
            WHEN td.session_status != 'ACTIVE' THEN FALSE
            ELSE TRUE
        END,
        td.user_hk,
        td.session_hk,
        td.username,
        CASE 
            WHEN td.token_hk IS NULL THEN 'Token not found'
            WHEN td.is_revoked THEN 'Token revoked'
            WHEN td.expires_at < CURRENT_TIMESTAMP THEN 'Token expired'
            WHEN td.session_status != 'ACTIVE' THEN 'Session not active'
            ELSE 'Valid'
        END
    FROM token_data td;
    
    -- Record token activity if found and IP address is valid
    IF v_token_hk IS NOT NULL AND v_ip_address IS NOT NULL THEN
        BEGIN
            INSERT INTO auth.token_activity_s (
                token_hk,
                load_date,
                hash_diff,
                last_activity_timestamp,
                activity_type,
                endpoint_accessed,
                ip_address,
                user_agent,
                record_source
            ) VALUES (
                v_token_hk,
                util.current_load_date(),
                util.hash_binary('VALIDATION_' || CURRENT_TIMESTAMP::text),
                CURRENT_TIMESTAMP,
                'VALIDATION',
                'token_validation',
                v_ip_address,
                COALESCE(p_user_agent, 'system'),
                util.get_record_source()
            );
        EXCEPTION WHEN OTHERS THEN
            -- Silently handle errors in activity logging to prevent validation failure
            NULL;
        END;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION auth.validate_token_and_session IS 
'Validates API tokens and associated sessions with comprehensive security checks. Records token activity for audit purposes while maintaining high performance for API authentication.';

-- =============================================
-- Enhanced Credential Validation Function
-- =============================================

CREATE OR REPLACE FUNCTION staging.validate_login_credentials(
    p_login_attempt_hk BYTEA
) RETURNS JSONB AS $$
DECLARE
    v_login_details RECORD;
    v_user RECORD;
    v_result JSONB;
    v_raw_password TEXT;
BEGIN
    -- Get login attempt details with corrected table names
    SELECT 
        username,
        convert_from(password_indicator, 'UTF8') AS raw_password
    INTO v_login_details
    FROM raw.login_details_s
    WHERE login_attempt_hk = p_login_attempt_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC 
    LIMIT 1;
    
    v_raw_password := v_login_details.raw_password;
    
    -- Get the user's stored credentials with corrected table names
    SELECT 
        user_hk,
        password_hash::text AS stored_hash,
        account_locked
    INTO v_user
    FROM auth.user_auth_s
    WHERE username = v_login_details.username
    AND load_end_date IS NULL
    ORDER BY load_date DESC 
    LIMIT 1;
    
    -- Comprehensive validation logic
    IF v_user.user_hk IS NULL THEN
        v_result := jsonb_build_object('status', 'INVALID_USER');
    ELSIF v_user.account_locked = true THEN
        v_result := jsonb_build_object('status', 'LOCKED');
    ELSIF v_user.stored_hash IS NULL OR crypt(v_raw_password, v_user.stored_hash) != v_user.stored_hash THEN
        v_result := jsonb_build_object('status', 'INVALID_PASSWORD');
    ELSE
        v_result := jsonb_build_object(
            'status', 'VALID',
            'user_hk', encode(v_user.user_hk, 'hex')
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION staging.validate_login_credentials IS 
'Validates user credentials using bcrypt password verification with comprehensive security checks including account lockout status.';

-- =============================================
-- Session and User Management Procedure
-- =============================================

CREATE OR REPLACE PROCEDURE auth.process_login_attempt(
    IN p_login_attempt_hk BYTEA,
    OUT p_session_hk BYTEA,
    OUT p_user_hk BYTEA
) AS $$
DECLARE
    v_login_status RECORD;
    v_session_bk VARCHAR(255);
    v_tenant_hk BYTEA;
BEGIN
    -- Verify login validation status with corrected table name
    SELECT validation_status, login_attempt_hk INTO v_login_status
    FROM staging.login_status_s
    WHERE login_attempt_hk = p_login_attempt_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC 
    LIMIT 1;
    
    IF v_login_status.validation_status = 'VALID' THEN
        -- Get the user hash key and tenant with corrected table names
        SELECT u.user_hk, u.tenant_hk INTO p_user_hk, v_tenant_hk
        FROM auth.user_h u
        JOIN auth.user_auth_s ua ON u.user_hk = ua.user_hk
        JOIN raw.login_details_s ld ON ua.username = ld.username
        WHERE ld.login_attempt_hk = p_login_attempt_hk
        AND ua.load_end_date IS NULL
        AND ld.load_end_date IS NULL
        ORDER BY ua.load_date DESC
        LIMIT 1;
        
        -- Generate session identifiers
        v_session_bk := encode(v_tenant_hk, 'hex') || '_SESSION_' || 
                       encode(p_user_hk, 'hex') || '_' ||
                       to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
        p_session_hk := util.hash_binary(v_session_bk);
        
        -- Create the session with corrected table name
        INSERT INTO auth.session_h (
            session_hk,
            session_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            p_session_hk,
            v_session_bk,
            v_tenant_hk,
            util.current_load_date(),
            util.get_record_source()
        );
        
        -- Create session state record with corrected table name
        INSERT INTO auth.session_state_s (
            session_hk,
            load_date,
            hash_diff,
            session_start,
            ip_address,
            user_agent,
            session_status,
            last_activity,
            record_source
        )
        SELECT 
            p_session_hk,
            util.current_load_date(),
            util.hash_binary(v_session_bk || 'ACTIVE'),
            CURRENT_TIMESTAMP,
            ld.ip_address,
            ld.user_agent,
            'ACTIVE',
            CURRENT_TIMESTAMP,
            util.get_record_source()
        FROM raw.login_details_s ld
        WHERE ld.login_attempt_hk = p_login_attempt_hk
        AND ld.load_end_date IS NULL;
        
        -- Link session to user with corrected table name
        INSERT INTO auth.user_session_l (
            link_user_session_hk,
            user_hk,
            session_hk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            util.hash_binary(p_user_hk::text || p_session_hk::text),
            p_user_hk,
            p_session_hk,
            v_tenant_hk,
            util.current_load_date(),
            util.get_record_source()
        );
    ELSE
        p_session_hk := NULL;
        p_user_hk := NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON PROCEDURE auth.process_login_attempt IS 
'Processes validated login attempts to create user sessions with complete tenant isolation and proper audit trails.';

-- =============================================
-- Performance Indexes for Token Activity
-- =============================================

-- Token activity indexes
CREATE INDEX idx_token_activity_s_timestamp ON auth.token_activity_s(last_activity_timestamp) 
WHERE load_end_date IS NULL;
CREATE INDEX idx_token_activity_s_activity_type ON auth.token_activity_s(activity_type) 
WHERE load_end_date IS NULL;
CREATE INDEX idx_token_activity_s_ip_address ON auth.token_activity_s(ip_address) 
WHERE load_end_date IS NULL;

-- Enhanced validation indexes
CREATE INDEX idx_login_details_s_username_current ON raw.login_details_s(username) 
WHERE load_end_date IS NULL;
CREATE INDEX idx_user_auth_s_username_current ON auth.user_auth_s(username) 
WHERE load_end_date IS NULL AND account_locked = false;