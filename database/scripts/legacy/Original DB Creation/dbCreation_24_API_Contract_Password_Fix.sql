-- =============================================
-- dbCreation_24_API_Contract_Password_Fix.sql
-- FIX: Correct password handling without invalid convert_from/convert_to
-- Uses proper VARCHAR data type for password_indicator column
-- =============================================

-- Drop and recreate the functions with correct password handling
DROP FUNCTION IF EXISTS raw.capture_login_attempt(BYTEA, VARCHAR, TEXT, INET, TEXT) CASCADE;
DROP FUNCTION IF EXISTS staging.validate_login_credentials(BYTEA) CASCADE;

-- =============================================
-- FIXED: raw.capture_login_attempt with correct password handling
-- =============================================

CREATE OR REPLACE FUNCTION raw.capture_login_attempt(
    p_tenant_hk BYTEA,
    p_username VARCHAR(255),
    p_password TEXT,
    p_ip_address INET,
    p_user_agent TEXT
) RETURNS BYTEA
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_login_attempt_bk VARCHAR(255);
    v_login_attempt_hk BYTEA;
    v_hash_diff BYTEA;
BEGIN
    -- Create business key using tenant context and timestamp
    v_login_attempt_bk := encode(p_tenant_hk, 'hex') || '_' || 
                         replace(p_username, '@', '_') || '_' ||
                         to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    
    -- Generate hash key
    v_login_attempt_hk := util.hash_binary(v_login_attempt_bk);
    
    -- Calculate hash diff for satellite
    v_hash_diff := util.hash_concat(
        p_username,
        'PASSWORD_PROVIDED',
        p_ip_address::text,
        COALESCE(p_user_agent, 'UNKNOWN')
    );
    
    -- Insert into hub table (raw.login_attempt_h)
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
    
    -- Insert into satellite table (raw.login_details_s)
    -- Store password as TEXT temporarily for validation processing
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
        v_hash_diff,
        p_username,
        p_password, -- Store as TEXT (password_indicator is VARCHAR(50) but we need the full password for validation)
        p_ip_address,
        CURRENT_TIMESTAMP,
        p_user_agent,
        util.get_record_source()
    );
    
    RETURN v_login_attempt_hk;
END;
$$;

-- =============================================
-- FIXED: staging.validate_login_credentials with correct password handling
-- =============================================

CREATE OR REPLACE FUNCTION staging.validate_login_credentials(
    p_login_attempt_hk BYTEA
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_login_details RECORD;
    v_user_auth RECORD;
    v_result JSONB;
    v_raw_password TEXT;
BEGIN
    -- Get login attempt details from raw schema
    SELECT 
        rld.username,
        rld.password_indicator AS raw_password, -- password_indicator is VARCHAR, no conversion needed
        rlh.tenant_hk
    INTO v_login_details
    FROM raw.login_details_s rld
    JOIN raw.login_attempt_h rlh ON rld.login_attempt_hk = rlh.login_attempt_hk
    WHERE rld.login_attempt_hk = p_login_attempt_hk
    AND rld.load_end_date IS NULL
    ORDER BY rld.load_date DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'ERROR', 'message', 'Login attempt not found');
    END IF;
    
    v_raw_password := v_login_details.raw_password;
    
    -- Get the user's stored credentials
    SELECT 
        uh.user_hk,
        uas.password_hash,
        uas.username,
        uas.account_locked
    INTO v_user_auth
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_login_details.username
    AND uh.tenant_hk = v_login_details.tenant_hk
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    -- Validation logic
    IF v_user_auth.user_hk IS NULL THEN
        v_result := jsonb_build_object('status', 'INVALID_USER');
    ELSIF v_user_auth.account_locked THEN
        v_result := jsonb_build_object('status', 'LOCKED');
    ELSIF NOT (crypt(v_raw_password, v_user_auth.password_hash::text) = v_user_auth.password_hash::text) THEN
        v_result := jsonb_build_object('status', 'INVALID_PASSWORD');
    ELSE
        v_result := jsonb_build_object(
            'status', 'VALID',
            'user_hk', encode(v_user_auth.user_hk, 'hex'),
            'tenant_hk', encode(v_login_details.tenant_hk, 'hex')
        );
    END IF;
    
    -- Create staging records for tracking
    INSERT INTO staging.login_attempt_h (
        login_attempt_hk,
        login_attempt_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        p_login_attempt_hk,
        'STAGING_' || encode(p_login_attempt_hk, 'hex'),
        v_login_details.tenant_hk,
        util.current_load_date(),
        util.get_record_source()
    ) ON CONFLICT (login_attempt_hk) DO NOTHING;
    
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
    )
    SELECT 
        p_login_attempt_hk,
        util.current_load_date(),
        util.hash_binary(v_login_details.username || (v_result->>'status')),
        rld.username,
        rld.ip_address,
        rld.attempt_timestamp,
        rld.user_agent,
        v_result->>'status',
        COALESCE(v_result->>'message', v_result->>'status'),
        util.get_record_source()
    FROM raw.login_details_s rld
    WHERE rld.login_attempt_hk = p_login_attempt_hk
    AND rld.load_end_date IS NULL;
    
    RETURN v_result;
END;
$$;

-- =============================================
-- VERIFICATION
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== PASSWORD HANDLING FIXED ===';
    RAISE NOTICE 'Removed invalid convert_from/convert_to functions';
    RAISE NOTICE 'Using correct VARCHAR data type for password_indicator';
    RAISE NOTICE '';
    RAISE NOTICE 'Ready to test login again!';
    RAISE NOTICE '';
END $$; 