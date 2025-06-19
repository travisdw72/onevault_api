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