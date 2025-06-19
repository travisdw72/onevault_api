-- =============================================
-- ROLLBACK SCRIPT: Remove Failed Implementation Attempts
-- This script removes all partially created components from failed attempts
-- Run this first before implementing the correct solution
-- =============================================

-- Drop functions that may have been created in failed attempts
DROP FUNCTION IF EXISTS auth.check_rate_limit_enhanced(BYTEA, INET, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS auth.generate_api_token_enhanced(BYTEA, BYTEA, VARCHAR, TEXT[], INTERVAL, VARCHAR);
DROP FUNCTION IF EXISTS auth.validate_token_comprehensive(TEXT, INET, TEXT, VARCHAR);
DROP FUNCTION IF EXISTS auth.revoke_token_enhanced(TEXT, TEXT, BYTEA);

-- Drop tables in proper dependency order (satellites first, then hubs)
DROP TABLE IF EXISTS auth.token_activity_s CASCADE;
DROP TABLE IF EXISTS auth.ip_tracking_s CASCADE;
DROP TABLE IF EXISTS auth.security_tracking_h CASCADE;

-- Drop any indexes that may have been created
DROP INDEX IF EXISTS idx_security_tracking_h_tenant;
DROP INDEX IF EXISTS idx_ip_tracking_s_ip_address;
DROP INDEX IF EXISTS idx_ip_tracking_s_blocked;
DROP INDEX IF EXISTS idx_ip_tracking_s_suspicious;
DROP INDEX IF EXISTS idx_token_activity_s_timestamp;
DROP INDEX IF EXISTS idx_token_activity_s_compliance;
DROP INDEX IF EXISTS idx_token_activity_s_type;

-- =============================================
-- CLEAN IMPLEMENTATION: Phase 3 Missing Components
-- Only creates components genuinely missing from step 4
-- =============================================

-- =============================================
-- 1. Security Tracking Infrastructure
-- =============================================

CREATE TABLE auth.security_tracking_h (
    security_tracking_hk BYTEA PRIMARY KEY,
    security_tracking_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
);

CREATE TABLE auth.ip_tracking_s (
    security_tracking_hk BYTEA NOT NULL REFERENCES auth.security_tracking_h(security_tracking_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    ip_address INET NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 1,
    first_request_time TIMESTAMP WITH TIME ZONE NOT NULL,
    last_request_time TIMESTAMP WITH TIME ZONE NOT NULL,
    is_blocked BOOLEAN NOT NULL DEFAULT false,
    block_reason TEXT,
    suspicious_activity_flag BOOLEAN NOT NULL DEFAULT false,
    suspicious_activity_details JSONB,
    endpoint_accessed VARCHAR(255),
    user_agent_hash BYTEA,
    geo_location VARCHAR(100),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (security_tracking_hk, load_date)
);

-- =============================================
-- 2. Token Activity Tracking
-- =============================================

CREATE TABLE auth.token_activity_s (
    token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(token_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    activity_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    endpoint_accessed VARCHAR(255),
    ip_address INET,
    user_agent_hash BYTEA,
    request_method VARCHAR(10),
    response_status INTEGER,
    processing_time_ms INTEGER,
    data_accessed JSONB,
    compliance_event BOOLEAN DEFAULT false,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    PRIMARY KEY (token_hk, load_date)
);

-- =============================================
-- 3. Enhanced Rate Limiting Function
-- =============================================

CREATE OR REPLACE FUNCTION auth.check_rate_limit_enhanced(
    p_tenant_hk BYTEA,
    p_ip_address INET,
    p_endpoint_path VARCHAR(255),
    p_user_agent TEXT DEFAULT NULL
) RETURNS TABLE (
    is_allowed BOOLEAN,
    wait_time_seconds INTEGER,
    reason TEXT,
    compliance_alert BOOLEAN
) AS $$
DECLARE
    v_tracking_hk BYTEA;
    v_tracking_bk VARCHAR(255);
    v_request_count INTEGER;
    v_time_window INTERVAL;
    v_max_requests INTEGER;
    v_user_agent_hash BYTEA;
    v_is_suspicious BOOLEAN := false;
    v_compliance_threshold INTEGER := 100;
BEGIN
    v_user_agent_hash := CASE 
        WHEN p_user_agent IS NOT NULL 
        THEN util.hash_binary(p_user_agent)
        ELSE NULL 
    END;

    SELECT 
        INTERVAL '1 minute' * COALESCE(sp.session_timeout_minutes, 15),
        COALESCE(sp.account_lockout_threshold * 10, 50)
    INTO 
        v_time_window,
        v_max_requests
    FROM auth.security_policy_s sp
    JOIN auth.security_policy_h hp ON sp.security_policy_hk = hp.security_policy_hk
    WHERE hp.tenant_hk = p_tenant_hk
    AND sp.load_end_date IS NULL
    ORDER BY sp.load_date DESC
    LIMIT 1;

    v_time_window := COALESCE(v_time_window, INTERVAL '15 minutes');
    v_max_requests := COALESCE(v_max_requests, 50);

    v_tracking_bk := encode(p_tenant_hk, 'hex') || '_IP_' || 
                     encode(digest(p_ip_address::text, 'sha256'), 'hex');
    v_tracking_hk := util.hash_binary(v_tracking_bk);

    INSERT INTO auth.security_tracking_h (
        security_tracking_hk,
        security_tracking_bk,
        tenant_hk
    ) VALUES (
        v_tracking_hk,
        v_tracking_bk,
        p_tenant_hk
    ) ON CONFLICT (security_tracking_hk) DO NOTHING;

    SELECT 
        request_count,
        CASE 
            WHEN request_count > (v_max_requests * 0.8) THEN true
            WHEN first_request_time > CURRENT_TIMESTAMP - INTERVAL '1 minute' 
                 AND request_count > 10 THEN true
            ELSE false
        END
    INTO v_request_count, v_is_suspicious
    FROM auth.ip_tracking_s
    WHERE security_tracking_hk = v_tracking_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    INSERT INTO auth.ip_tracking_s (
        security_tracking_hk,
        hash_diff,
        ip_address,
        request_count,
        first_request_time,
        last_request_time,
        is_blocked,
        suspicious_activity_flag,
        suspicious_activity_details,
        endpoint_accessed,
        user_agent_hash
    )
    SELECT
        v_tracking_hk,
        util.hash_binary(p_ip_address::text || CURRENT_TIMESTAMP::text || p_endpoint_path),
        p_ip_address,
        CASE 
            WHEN its.first_request_time < CURRENT_TIMESTAMP - v_time_window OR its.first_request_time IS NULL
            THEN 1
            ELSE COALESCE(its.request_count, 0) + 1
        END,
        CASE 
            WHEN its.first_request_time < CURRENT_TIMESTAMP - v_time_window OR its.first_request_time IS NULL
            THEN CURRENT_TIMESTAMP
            ELSE COALESCE(its.first_request_time, CURRENT_TIMESTAMP)
        END,
        CURRENT_TIMESTAMP,
        CASE 
            WHEN COALESCE(its.request_count, 0) + 1 > v_max_requests THEN true
            ELSE false
        END,
        v_is_suspicious,
        jsonb_build_object(
            'endpoint_path', p_endpoint_path,
            'request_time', CURRENT_TIMESTAMP,
            'user_agent_provided', (p_user_agent IS NOT NULL),
            'rate_limit_threshold', v_max_requests
        ),
        p_endpoint_path,
        v_user_agent_hash
    FROM (
        SELECT * FROM auth.ip_tracking_s 
        WHERE security_tracking_hk = v_tracking_hk 
        AND load_end_date IS NULL
        ORDER BY load_date DESC 
        LIMIT 1
    ) its;

    SELECT request_count INTO v_request_count
    FROM auth.ip_tracking_s
    WHERE security_tracking_hk = v_tracking_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    RETURN QUERY 
    SELECT 
        CASE
            WHEN its.is_blocked THEN FALSE
            WHEN COALESCE(v_request_count, 0) <= v_max_requests THEN TRUE
            ELSE FALSE
        END,
        GREATEST(0, EXTRACT(EPOCH FROM (
            (its.first_request_time + v_time_window) - CURRENT_TIMESTAMP
        ))::INTEGER),
        CASE
            WHEN its.is_blocked THEN 'IP address blocked due to excessive requests'
            WHEN COALESCE(v_request_count, 0) > v_max_requests THEN 'Rate limit exceeded for time window'
            ELSE 'Request allowed within rate limits'
        END,
        CASE 
            WHEN COALESCE(v_request_count, 0) > v_compliance_threshold THEN TRUE
            WHEN v_is_suspicious THEN TRUE
            ELSE FALSE
        END
    FROM auth.ip_tracking_s its
    WHERE its.security_tracking_hk = v_tracking_hk
    AND its.load_end_date IS NULL
    ORDER BY its.load_date DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 4. Enhanced Token Validation Function
-- =============================================

CREATE OR REPLACE FUNCTION auth.validate_token_comprehensive(
    p_token_value TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_endpoint VARCHAR(255) DEFAULT NULL
) RETURNS TABLE (
    is_valid BOOLEAN,
    user_hk BYTEA,
    session_hk BYTEA,
    tenant_hk BYTEA,
    username VARCHAR,
    permissions TEXT[],
    expires_at TIMESTAMP WITH TIME ZONE,
    message TEXT,
    compliance_alert BOOLEAN
) AS $$
DECLARE
    v_token_hash BYTEA;
    v_token_hk BYTEA;
    v_user_agent_hash BYTEA;
    v_is_compliance_event BOOLEAN := false;
BEGIN
    v_token_hash := util.hash_binary(p_token_value);
    
    v_user_agent_hash := CASE 
        WHEN p_user_agent IS NOT NULL 
        THEN util.hash_binary(p_user_agent)
        ELSE NULL 
    END;

    RETURN QUERY
    WITH token_validation AS (
        SELECT 
            ats.token_hk,
            ats.token_hash,
            ats.is_revoked,
            ats.expires_at,
            ats.scope,
            uth.tenant_hk,
            uth.user_hk,
            utl.user_hk as linked_user_hk,
            stl.session_hk,
            ups.email as username,
            sss.session_status,
            sss.last_activity,
            CASE 
                WHEN p_ip_address IS NOT NULL AND 
                     EXISTS (
                         SELECT 1 FROM auth.ip_tracking_s its 
                         WHERE its.ip_address = p_ip_address 
                         AND its.suspicious_activity_flag = true
                         AND its.load_end_date IS NULL
                     ) THEN true
                ELSE false
            END as compliance_event
        FROM auth.api_token_s ats
        JOIN auth.api_token_h ath ON ats.token_hk = ath.token_hk
        JOIN auth.user_token_l utl ON ath.token_hk = utl.token_hk
        JOIN auth.user_h uth ON utl.user_hk = uth.user_hk
        JOIN auth.user_profile_s ups ON uth.user_hk = ups.user_hk AND ups.load_end_date IS NULL
        LEFT JOIN auth.session_token_l stl ON ath.token_hk = stl.token_hk
        LEFT JOIN auth.session_state_s sss ON stl.session_hk = sss.session_hk AND sss.load_end_date IS NULL
        WHERE ats.token_hash = v_token_hash
        AND ats.load_end_date IS NULL
        ORDER BY ats.load_date DESC
        LIMIT 1
    )
    SELECT 
        CASE 
            WHEN tv.token_hk IS NULL THEN FALSE
            WHEN tv.is_revoked THEN FALSE
            WHEN tv.expires_at < CURRENT_TIMESTAMP THEN FALSE
            WHEN tv.session_hk IS NOT NULL AND tv.session_status != 'ACTIVE' THEN FALSE
            WHEN tv.session_hk IS NOT NULL AND tv.last_activity < CURRENT_TIMESTAMP - INTERVAL '20 minutes' THEN FALSE
            ELSE TRUE
        END as is_valid,
        tv.linked_user_hk as user_hk,
        tv.session_hk,
        tv.tenant_hk,
        tv.username,
        tv.scope as permissions,
        tv.expires_at,
        CASE 
            WHEN tv.token_hk IS NULL THEN 'Token not found'
            WHEN tv.is_revoked THEN 'Token has been revoked'
            WHEN tv.expires_at < CURRENT_TIMESTAMP THEN 'Token has expired'
            WHEN tv.session_hk IS NOT NULL AND tv.session_status != 'ACTIVE' THEN 'Associated session is not active'
            WHEN tv.session_hk IS NOT NULL AND tv.last_activity < CURRENT_TIMESTAMP - INTERVAL '20 minutes' THEN 'Session has timed out'
            ELSE 'Token is valid and active'
        END as message,
        tv.compliance_event as compliance_alert
    FROM token_validation tv;

    SELECT ath.token_hk INTO v_token_hk
    FROM auth.api_token_h ath
    JOIN auth.api_token_s ats ON ath.token_hk = ats.token_hk
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL;

    IF v_token_hk IS NOT NULL THEN
        INSERT INTO auth.token_activity_s (
            token_hk,
            hash_diff,
            activity_timestamp,
            activity_type,
            endpoint_accessed,
            ip_address,
            user_agent_hash,
            compliance_event
        ) VALUES (
            v_token_hk,
            util.hash_binary('VALIDATION_' || CURRENT_TIMESTAMP::text),
            CURRENT_TIMESTAMP,
            'TOKEN_VALIDATION',
            COALESCE(p_endpoint, 'unknown'),
            p_ip_address,
            v_user_agent_hash,
            v_is_compliance_event
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 5. Enhanced Token Revocation Function
-- =============================================

CREATE OR REPLACE FUNCTION auth.revoke_token_enhanced(
    p_token_value TEXT,
    p_reason TEXT DEFAULT 'Manual revocation',
    p_revoked_by_user_hk BYTEA DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_token_hash BYTEA;
    v_token_hk BYTEA;
BEGIN
    v_token_hash := util.hash_binary(p_token_value);
    
    SELECT ath.token_hk INTO v_token_hk
    FROM auth.api_token_h ath
    JOIN auth.api_token_s ats ON ath.token_hk = ats.token_hk
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL;

    IF v_token_hk IS NULL THEN
        RETURN false;
    END IF;

    UPDATE auth.api_token_s
    SET load_end_date = util.current_load_date()
    WHERE token_hk = v_token_hk
    AND load_end_date IS NULL;

    INSERT INTO auth.api_token_s (
        token_hk,
        hash_diff,
        token_hash,
        token_type,
        expires_at,
        is_revoked,
        revocation_reason,
        scope,
        last_used_at
    )
    SELECT 
        token_hk,
        util.hash_binary(token_hash::text || 'REVOKED' || p_reason),
        token_hash,
        token_type,
        expires_at,
        true,
        p_reason,
        scope,
        last_used_at
    FROM auth.api_token_s
    WHERE token_hk = v_token_hk
    AND load_end_date = util.current_load_date();

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 6. Performance Indexes
-- =============================================

CREATE INDEX idx_security_tracking_h_tenant ON auth.security_tracking_h(tenant_hk);
CREATE INDEX idx_ip_tracking_s_ip_address ON auth.ip_tracking_s(ip_address) WHERE load_end_date IS NULL;
CREATE INDEX idx_ip_tracking_s_blocked ON auth.ip_tracking_s(is_blocked) WHERE load_end_date IS NULL;
CREATE INDEX idx_ip_tracking_s_suspicious ON auth.ip_tracking_s(suspicious_activity_flag) WHERE load_end_date IS NULL;
CREATE INDEX idx_token_activity_s_timestamp ON auth.token_activity_s(activity_timestamp);
CREATE INDEX idx_token_activity_s_compliance ON auth.token_activity_s(compliance_event) WHERE compliance_event = true;
CREATE INDEX idx_token_activity_s_type ON auth.token_activity_s(activity_type);

-- =============================================
-- 7. Documentation Comments
-- =============================================

COMMENT ON TABLE auth.security_tracking_h IS 'Hub table for security tracking events including IP monitoring and rate limiting';
COMMENT ON TABLE auth.ip_tracking_s IS 'Satellite table containing IP address tracking data for security and compliance monitoring';
COMMENT ON TABLE auth.token_activity_s IS 'Satellite table tracking all token usage for audit and compliance purposes';

COMMENT ON FUNCTION auth.check_rate_limit_enhanced IS 'Enhanced rate limiting with HIPAA compliance monitoring and suspicious activity detection';
COMMENT ON FUNCTION auth.validate_token_comprehensive IS 'Full token validation with activity tracking and compliance alerting';
COMMENT ON FUNCTION auth.revoke_token_enhanced IS 'Token revocation with comprehensive audit trail and reason tracking';