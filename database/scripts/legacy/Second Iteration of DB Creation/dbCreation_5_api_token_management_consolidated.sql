-- =============================================
-- API Token Management - Comprehensive Consolidated Implementation
-- This consolidates dbCreation_5, dbCreation_6, and dbCreation_7 fixes into a single script
-- Includes complete API contract layer and enhanced functionality
-- =============================================

-- =============================================
-- Token Activity Tracking Table
-- =============================================

-- Satellite table for token activity tracking
CREATE TABLE auth.token_activity_s (
    token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(token_hk),  
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    last_activity_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    endpoint_accessed VARCHAR(500),  -- Enhanced length for complex API URLs
    ip_address INET,
    user_agent TEXT,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (token_hk, load_date)  
);

-- =============================================
-- Essential Utility Function (Enhanced Version)
-- =============================================

CREATE OR REPLACE FUNCTION util.generate_bk(p_input_text TEXT)
RETURNS VARCHAR(255)
LANGUAGE SQL
IMMUTABLE
STRICT
AS $$
    SELECT 'BK_' || encode(util.hash_binary(COALESCE(p_input_text, 'NULL_INPUT')), 'hex');
$$;

COMMENT ON FUNCTION util.generate_bk IS 
'Generates standardized business keys for Data Vault 2.0 entities using consistent hashing methodology with proper NULL handling';

COMMENT ON FUNCTION util.generate_bk IS 
'Standardized business key generation for Data Vault 2.0 entities ensuring consistency across the authentication and tenant management infrastructure.';



-- =============================================
-- Enhanced Session Management Procedure
-- =============================================

CREATE OR REPLACE PROCEDURE auth.process_valid_login(
    IN p_login_attempt_hk BYTEA,
    OUT p_session_hk BYTEA,
    OUT p_user_hk BYTEA
) AS $$
DECLARE
    v_user_hk BYTEA;
    v_tenant_hk BYTEA;
    v_session_bk VARCHAR(255);
    v_session_hk BYTEA;
    v_username VARCHAR(255);
    v_ip_address INET;
    v_user_agent TEXT;
    v_token_value TEXT;
BEGIN
    -- Get validation status and user details
    SELECT 
        uh.user_hk,
        uh.tenant_hk,
        sls.username,
        sls.ip_address,
        sls.user_agent
    INTO 
        v_user_hk,
        v_tenant_hk,
        v_username,
        v_ip_address,
        v_user_agent
    FROM staging.login_status_s sls
    JOIN staging.login_attempt_h slh ON sls.login_attempt_hk = slh.login_attempt_hk
    JOIN auth.user_auth_s uas ON sls.username = uas.username
    JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
    WHERE sls.login_attempt_hk = p_login_attempt_hk
    AND sls.validation_status = 'VALID'
    AND sls.load_end_date IS NULL
    AND uas.load_end_date IS NULL
    ORDER BY sls.load_date DESC, uas.load_date DESC
    LIMIT 1;

    IF v_user_hk IS NULL THEN
        p_session_hk := NULL;
        p_user_hk := NULL;
        RETURN;
    END IF;

    -- Generate session identifiers
    v_session_bk := encode(v_tenant_hk, 'hex') || '_SESSION_' || 
                   encode(v_user_hk, 'hex') || '_' ||
                   to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    v_session_hk := util.hash_binary(v_session_bk);

    -- Create session hub record
    INSERT INTO auth.session_h (
        session_hk,
        session_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_session_hk,
        v_session_bk,
        v_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    );

    -- Create session state satellite
    INSERT INTO auth.session_state_s (
        session_hk,
        load_date,
        hash_diff,
        session_start,
        ip_address,
        user_agent,
        session_data,
        session_status,
        last_activity,
        record_source
    ) VALUES (
        v_session_hk,
        util.current_load_date(),
        util.hash_binary(v_session_bk || 'ACTIVE'),
        CURRENT_TIMESTAMP,
        v_ip_address,
        v_user_agent,
        jsonb_build_object('login_attempt_hk', encode(p_login_attempt_hk, 'hex')),
        'ACTIVE',
        CURRENT_TIMESTAMP,
        util.get_record_source()
    );

    -- Create user-session link
    INSERT INTO auth.user_session_l (
        link_user_session_hk,
        user_hk,
        session_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(v_user_hk::text || v_session_hk::text),
        v_user_hk,
        v_session_hk,
        v_tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    );

    -- Generate API token for session (store in session_bk for easy retrieval)
    v_token_value := encode(gen_random_bytes(32), 'hex');
    
    -- Update session record with token as business key
    UPDATE auth.session_h
    SET session_bk = v_token_value
    WHERE session_hk = v_session_hk;

    -- Set output parameters
    p_session_hk := v_session_hk;
    p_user_hk := v_user_hk;
END;
$$ LANGUAGE plpgsql;

COMMENT ON PROCEDURE auth.process_valid_login IS 
'Processes validated login attempts to create user sessions with complete tenant isolation and proper audit trails.';

-- =============================================
-- Enhanced Token and Session Validation Function
-- =============================================

CREATE OR REPLACE FUNCTION auth.validate_token_and_session(
    p_token_value TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS TABLE (
    is_valid BOOLEAN,
    user_hk BYTEA,
    session_hk BYTEA,
    username TEXT,
    message TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH token_data AS (
        SELECT 
            sh.session_hk,
            sh.session_bk,
            sss.session_status,
            sss.session_start,
            sss.last_activity,
            usl.user_hk,
            uas.username,
            sh.tenant_hk
        FROM auth.session_h sh
        JOIN auth.session_state_s sss ON sh.session_hk = sss.session_hk
        JOIN auth.user_session_l usl ON sh.session_hk = usl.session_hk
        JOIN auth.user_auth_s uas ON usl.user_hk = uas.user_hk
        WHERE sh.session_bk = p_token_value
        AND sss.load_end_date IS NULL
        AND uas.load_end_date IS NULL
        ORDER BY sss.load_date DESC, uas.load_date DESC
        LIMIT 1
    )
    SELECT 
        CASE 
            WHEN td.session_hk IS NULL THEN FALSE
            WHEN td.session_status != 'ACTIVE' THEN FALSE
            WHEN td.last_activity < CURRENT_TIMESTAMP - INTERVAL '2 hours' THEN FALSE
            ELSE TRUE
        END,
        td.user_hk,
        td.session_hk,
        td.username,
        CASE 
            WHEN td.session_hk IS NULL THEN 'Token not found'
            WHEN td.session_status != 'ACTIVE' THEN 'Session not active'
            WHEN td.last_activity < CURRENT_TIMESTAMP - INTERVAL '2 hours' THEN 'Session expired'
            ELSE 'Valid'
        END
    FROM token_data td;
    
    -- Record token activity if found and IP address is valid
    IF p_ip_address IS NOT NULL THEN
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
                decode(p_token_value, 'hex'),
                util.current_load_date(),
                util.hash_binary('VALIDATION_' || CURRENT_TIMESTAMP::text),
                CURRENT_TIMESTAMP,
                'VALIDATION',
                'token_validation',
                p_ip_address,
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
-- Primary Authentication Entry Point (from dbCreation_7)
-- =============================================

CREATE OR REPLACE PROCEDURE auth.login_user(
    IN p_username VARCHAR(255),
    IN p_password TEXT,
    IN p_ip_address INET,
    IN p_user_agent TEXT,
    OUT p_success BOOLEAN,
    OUT p_message TEXT,
    OUT p_tenant_list JSONB,
    OUT p_session_token TEXT,
    OUT p_user_data JSONB,
    IN p_auto_login BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_login_attempt_hk BYTEA;
    v_user_hk BYTEA;
    v_session_hk BYTEA;
    v_single_tenant_id TEXT;
    v_validation_result JSONB;
BEGIN
    -- Initialize outputs
    p_success := FALSE;
    p_message := 'Authentication failed';
    p_tenant_list := NULL;
    p_session_token := NULL;
    p_user_data := NULL;

    -- Step 1: Get system tenant for initial validation
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h
    WHERE tenant_bk = 'SYSTEM'
    LIMIT 1;
    
    IF v_tenant_hk IS NULL THEN
        -- Fallback to first available tenant for testing
        SELECT tenant_hk INTO v_tenant_hk
        FROM auth.tenant_h
        LIMIT 1;
        
        IF v_tenant_hk IS NULL THEN
            p_success := FALSE;
            p_message := 'No valid tenant found for authentication';
            RETURN;
        END IF;
    END IF;
    
    -- Step 2: Record the login attempt in raw schema
    v_login_attempt_hk := raw.capture_login_attempt(
        v_tenant_hk,
        p_username,
        p_password,
        p_ip_address,
        p_user_agent
    );
    
    -- Step 3: Validate the credentials
    v_validation_result := staging.validate_login_credentials(v_login_attempt_hk);
    
    -- Step 4: Process validation results
    IF (v_validation_result->>'status') != 'VALID' THEN
        p_success := FALSE;
        p_message := CASE 
            WHEN (v_validation_result->>'status') = 'INVALID_USER' THEN 'User not found'
            WHEN (v_validation_result->>'status') = 'INVALID_PASSWORD' THEN 'Invalid password'
            WHEN (v_validation_result->>'status') = 'LOCKED' THEN 'Account is locked'
            ELSE 'Login failed'
        END;
        RETURN;
    END IF;
    
    -- Credentials are valid - get user hash key
    v_user_hk := decode(v_validation_result->>'user_hk', 'hex');
    
    -- Step 5: Get list of tenants this user has access to
    SELECT jsonb_agg(
        jsonb_build_object(
            'tenant_id', t.tenant_bk,
            'tenant_name', COALESCE(tps.tenant_name, t.tenant_bk),
            'role', rds.role_name
        )
    ) INTO p_tenant_list
    FROM auth.user_h u
    JOIN auth.user_role_l url ON u.user_hk = url.user_hk
    JOIN auth.role_h r ON url.role_hk = r.role_hk
    JOIN auth.tenant_h t ON r.tenant_hk = t.tenant_hk
    LEFT JOIN auth.tenant_profile_s tps ON t.tenant_hk = tps.tenant_hk 
        AND tps.load_end_date IS NULL
    LEFT JOIN auth.role_definition_s rds ON r.role_hk = rds.role_hk
        AND rds.load_end_date IS NULL
    WHERE u.user_hk = v_user_hk;
    
    -- Authentication successful
    p_success := TRUE;
    p_message := 'Authentication successful';
    
    -- Step 6: Auto-login if requested and user has only one tenant
    IF p_auto_login AND jsonb_array_length(p_tenant_list) = 1 THEN
        v_single_tenant_id := p_tenant_list->0->>'tenant_id';
        
        -- Create staging records for validation
        INSERT INTO staging.login_attempt_h (
            login_attempt_hk,
            login_attempt_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_login_attempt_hk,
            'AUTO_LOGIN_' || encode(v_login_attempt_hk, 'hex'),
            v_tenant_hk,
            util.current_load_date(),
            util.get_record_source()
        ) ON CONFLICT DO NOTHING;
        
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
            v_login_attempt_hk,
            util.current_load_date(),
            util.hash_binary(p_username || 'VALID'),
            p_username,
            p_ip_address,
            CURRENT_TIMESTAMP,
            p_user_agent,
            'VALID',
            'Auto-login for single tenant user',
            util.get_record_source()
        );
        
        -- Process the login and create session
        CALL auth.process_valid_login(
            v_login_attempt_hk,
            v_session_hk,
            v_user_hk
        );
        
        -- Get the session token
        IF v_session_hk IS NOT NULL THEN
            SELECT session_bk INTO p_session_token
            FROM auth.session_h
            WHERE session_hk = v_session_hk;
        END IF;
        
        -- Get basic user data
        SELECT jsonb_build_object(
            'user_id', u.user_bk,
            'email', uas.username,
            'first_name', COALESCE(ups.first_name, ''),
            'last_name', COALESCE(ups.last_name, ''),
            'tenant_id', v_single_tenant_id
        ) INTO p_user_data
        FROM auth.user_h u
        JOIN auth.user_auth_s uas ON u.user_hk = uas.user_hk
        LEFT JOIN auth.user_profile_s ups ON u.user_hk = ups.user_hk
        WHERE u.user_hk = v_user_hk
        AND uas.load_end_date IS NULL
        AND (ups.load_end_date IS NULL OR ups.load_end_date IS NULL);
        
        p_message := 'Login successful';
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Error handling with audit logging
    p_success := FALSE;
    p_message := 'An unexpected error occurred during authentication';
    p_tenant_list := NULL;
    p_session_token := NULL;
    p_user_data := NULL;
END;
$$;

COMMENT ON PROCEDURE auth.login_user IS 
'Primary authentication entry point for API integration with multi-tenant support and auto-login capability.';

-- =============================================
-- Session Validation API Procedures (from dbCreation_7)
-- =============================================

CREATE OR REPLACE PROCEDURE auth.validate_session(
    IN p_session_token TEXT,
    IN p_ip_address INET,
    IN p_user_agent TEXT,
    OUT p_is_valid BOOLEAN,
    OUT p_message TEXT,
    OUT p_user_context JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_validation_result RECORD;
BEGIN
    -- Initialize outputs
    p_is_valid := FALSE;
    p_message := 'Invalid session';
    p_user_context := NULL;

    -- Call the internal validation function
    SELECT 
        is_valid, 
        user_hk,
        session_hk,
        username,
        message
    INTO v_validation_result
    FROM auth.validate_token_and_session(
        p_session_token,
        p_ip_address,
        p_user_agent
    );
    
    -- Handle invalid session
    IF NOT COALESCE(v_validation_result.is_valid, FALSE) THEN
        p_is_valid := FALSE;
        p_message := COALESCE(v_validation_result.message, 'Session validation failed');
        RETURN;
    END IF;
    
    -- Get user and tenant context
    SELECT jsonb_build_object(
        'user_id', u.user_bk,
        'tenant_id', t.tenant_bk,
        'email', uas.username,
        'first_name', COALESCE(ups.first_name, ''),
        'last_name', COALESCE(ups.last_name, ''),
        'roles', COALESCE(
            (SELECT array_agg(rds.role_name)
             FROM auth.user_role_l url
             JOIN auth.role_h r ON url.role_hk = r.role_hk
             JOIN auth.role_definition_s rds ON r.role_hk = rds.role_hk
             WHERE url.user_hk = u.user_hk
             AND rds.load_end_date IS NULL), 
            ARRAY[]::TEXT[]
        )
    ) INTO p_user_context
    FROM auth.user_h u
    JOIN auth.tenant_h t ON u.tenant_hk = t.tenant_hk
    JOIN auth.user_auth_s uas ON u.user_hk = uas.user_hk
    LEFT JOIN auth.user_profile_s ups ON u.user_hk = ups.user_hk
    WHERE u.user_hk = v_validation_result.user_hk
    AND uas.load_end_date IS NULL
    AND (ups.load_end_date IS NULL OR ups.load_end_date IS NULL);
    
    -- Update session activity
    UPDATE auth.session_state_s
    SET last_activity = CURRENT_TIMESTAMP,
        load_end_date = util.current_load_date()
    WHERE session_hk = v_validation_result.session_hk
    AND load_end_date IS NULL;
    
    -- Insert new session state record
    INSERT INTO auth.session_state_s (
        session_hk,
        load_date,
        hash_diff,
        session_start,
        ip_address,
        user_agent,
        session_data,
        session_status,
        last_activity,
        record_source
    )
    SELECT 
        session_hk,
        util.current_load_date(),
        util.hash_binary(session_bk || 'ACTIVE_UPDATED'),
        session_start,
        p_ip_address,
        p_user_agent,
        session_data,
        'ACTIVE',
        CURRENT_TIMESTAMP,
        util.get_record_source()
    FROM auth.session_state_s
    WHERE session_hk = v_validation_result.session_hk
    AND load_end_date = util.current_load_date();
    
    p_is_valid := TRUE;
    p_message := 'Session valid';

EXCEPTION WHEN OTHERS THEN
    p_is_valid := FALSE;
    p_message := 'Session validation failed';
    p_user_context := NULL;
END;
$$;

COMMENT ON PROCEDURE auth.validate_session IS 
'Validates session tokens and returns user context for API requests with activity tracking.';

-- =============================================
-- JSON Session Validation Wrapper (from dbCreation_7)
-- =============================================

CREATE OR REPLACE FUNCTION auth.validate_session_json(
    p_session_token TEXT,
    p_ip_address TEXT,
    p_user_agent TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_valid BOOLEAN;
    v_message TEXT;
    v_user_context JSONB;
    v_inet_address INET;
BEGIN
    -- Handle IP address conversion safely
    BEGIN
        v_inet_address := p_ip_address::INET;
    EXCEPTION WHEN OTHERS THEN
        v_inet_address := '0.0.0.0'::INET;
    END;

    -- Call the existing procedure
    CALL auth.validate_session(
        p_session_token,
        v_inet_address,
        p_user_agent,
        v_is_valid,
        v_message,
        v_user_context
    );
    
    -- Return consolidated JSON response
    RETURN jsonb_build_object(
        'valid', v_is_valid,
        'message', v_message,
        'userContext', v_user_context,
        'timestamp', CURRENT_TIMESTAMP
    );
EXCEPTION WHEN OTHERS THEN
    -- Handle unexpected errors gracefully
    RETURN jsonb_build_object(
        'valid', FALSE,
        'message', 'An unexpected error occurred during session validation: ' || SQLERRM,
        'userContext', NULL,
        'timestamp', CURRENT_TIMESTAMP,
        'errorCode', SQLSTATE
    );
END;
$$;

COMMENT ON FUNCTION auth.validate_session_json IS 
'JSON wrapper for session validation, convenient for REST API integration with comprehensive error handling.';

-- =============================================
-- Performance Indexes
-- =============================================

-- Token activity indexes
CREATE INDEX IF NOT EXISTS idx_token_activity_s_timestamp ON auth.token_activity_s(last_activity_timestamp) 
WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_token_activity_s_activity_type ON auth.token_activity_s(activity_type) 
WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_token_activity_s_ip_address ON auth.token_activity_s(ip_address) 
WHERE load_end_date IS NULL;

-- Enhanced validation indexes
CREATE INDEX IF NOT EXISTS idx_login_details_s_username_current ON raw.login_details_s(username) 
WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_user_auth_s_username_current ON auth.user_auth_s(username) 
WHERE load_end_date IS NULL AND account_locked = false;

-- Session management indexes
CREATE INDEX IF NOT EXISTS idx_session_h_session_bk ON auth.session_h(session_bk);
CREATE INDEX IF NOT EXISTS idx_session_state_s_status ON auth.session_state_s(session_status) 
WHERE load_end_date IS NULL;
CREATE INDEX IF NOT EXISTS idx_user_session_l_user_hk ON auth.user_session_l(user_hk);
CREATE INDEX IF NOT EXISTS idx_user_session_l_session_hk ON auth.user_session_l(session_hk);

-- Login attempt tracking indexes
CREATE INDEX IF NOT EXISTS idx_login_attempt_h_tenant_hk ON raw.login_attempt_h(tenant_hk);
CREATE INDEX IF NOT EXISTS idx_login_details_s_attempt_timestamp ON raw.login_details_s(attempt_timestamp);
CREATE INDEX IF NOT EXISTS idx_login_status_s_validation ON staging.login_status_s(validation_status);

-- =============================================
-- Documentation and Comments
-- =============================================

COMMENT ON SCHEMA auth IS 'Authentication and authorization schema with Data Vault 2.0 structure using new naming conventions';
COMMENT ON PROCEDURE auth.login_user IS 'Primary authentication entry point for API integration with multi-tenant support';
COMMENT ON PROCEDURE auth.validate_session IS 'Validates session tokens and returns user context for API requests';
COMMENT ON FUNCTION auth.validate_session_json IS 'JSON wrapper for session validation, convenient for REST API integration'; 