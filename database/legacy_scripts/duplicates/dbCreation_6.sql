-- =============================================
-- FUNCTION CONFLICT RESOLUTION
-- =============================================

-- Drop all possible variations of the validate_token_and_session function
-- Using CASCADE to handle any dependencies
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT) CASCADE;
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT, INET) CASCADE;
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT, INET, TEXT) CASCADE;
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT, TEXT, TEXT) CASCADE;

-- Drop any other potentially conflicting functions that may have been created
DROP FUNCTION IF EXISTS staging.validate_login_credentials(BYTEA) CASCADE;
DROP PROCEDURE IF EXISTS auth.process_login_attempt(BYTEA) CASCADE;

-- =============================================
-- CREATE ESSENTIAL UTILITY FUNCTION
-- =============================================

CREATE OR REPLACE FUNCTION util.generate_bk(input_data TEXT)
RETURNS VARCHAR(255)
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT 'BK_' || upper(substring(encode(util.hash_binary(input_data), 'hex') from 1 for 16)) || '_' || 
           to_char(CURRENT_TIMESTAMP, 'YYYYMMDD');
$$;

-- =============================================
-- CORRECTED FUNCTION IMPLEMENTATIONS
-- =============================================

-- Raw login capture function
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
    v_login_attempt_bk := encode(p_tenant_hk, 'hex') || '_' || 
                         replace(p_email, '@', '_') || '_' ||
                         to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    
    v_login_attempt_hk := util.hash_binary(v_login_attempt_bk);
    
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
        convert_to(p_password, 'UTF8'),
        p_ip_address,
        CURRENT_TIMESTAMP,
        p_user_agent,
        util.get_record_source()
    );
    
    RETURN v_login_attempt_hk;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Staging validation function
CREATE OR REPLACE FUNCTION staging.validate_login_credentials(p_login_attempt_hk BYTEA) 
RETURNS JSONB AS $$
DECLARE
    v_login_details RECORD;
    v_user RECORD;
    v_result JSONB;
    v_raw_password TEXT;
BEGIN
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

-- Login processing procedure
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
    SELECT validation_status, login_attempt_hk INTO v_login_status
    FROM staging.login_status_s
    WHERE login_attempt_hk = p_login_attempt_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC 
    LIMIT 1;
    
    IF v_login_status.validation_status = 'VALID' THEN
        SELECT u.user_hk, u.tenant_hk INTO p_user_hk, v_tenant_hk
        FROM auth.user_h u
        JOIN auth.user_auth_s ua ON u.user_hk = ua.user_hk
        JOIN raw.login_details_s ld ON ua.username = ld.username
        WHERE ld.login_attempt_hk = p_login_attempt_hk
        AND ua.load_end_date IS NULL
        AND ld.load_end_date IS NULL
        ORDER BY ua.load_date DESC
        LIMIT 1;
        
        v_session_bk := encode(v_tenant_hk, 'hex') || '_SESSION_' || 
                       encode(p_user_hk, 'hex') || '_' ||
                       to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
        p_session_hk := util.hash_binary(v_session_bk);
        
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

-- Token and session validation function (single definitive version)
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
DECLARE
    v_token_hk BYTEA;
BEGIN
    v_token_hk := decode(p_token_value, 'hex');
    
    RETURN QUERY
    WITH token_data AS (
        SELECT 
            sat.token_hk,
            sat.is_revoked,
            sat.expires_at,
            lst.session_hk,
            sss.session_status,
            lut.user_hk,
            sua.username
        FROM auth.api_token_h hat
        JOIN auth.api_token_s sat ON hat.token_hk = sat.token_hk
        JOIN auth.session_token_l lst ON hat.token_hk = lst.token_hk
        JOIN auth.session_state_s sss ON lst.session_hk = sss.session_hk
        JOIN auth.user_token_l lut ON hat.token_hk = lut.token_hk
        JOIN auth.user_auth_s sua ON lut.user_hk = sua.user_hk
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
    
    IF v_token_hk IS NOT NULL AND p_ip_address IS NOT NULL THEN
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
                p_ip_address,
                COALESCE(p_user_agent, 'system'),
                util.get_record_source()
            );
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- VERIFICATION
-- =============================================

-- Verify function creation
SELECT 
    p.proname as function_name,
    pg_catalog.pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'auth' 
AND p.proname = 'validate_token_and_session';