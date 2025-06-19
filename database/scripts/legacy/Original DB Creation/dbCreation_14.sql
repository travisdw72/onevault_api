-- =============================================
-- Step 14: Comprehensive Error Handling and Monitoring System
-- Data Vault 2.0 with New Naming Conventions
-- Production-Ready Error Tracking and Monitoring Infrastructure
-- =============================================

-- Create rollback procedure for step 14
CREATE OR REPLACE PROCEDURE util.rollback_step_14()
LANGUAGE plpgsql AS $$
BEGIN
    -- Drop functions and procedures created in this step
    DROP FUNCTION IF EXISTS audit.log_error(BYTEA, VARCHAR, TEXT, JSONB);
    DROP FUNCTION IF EXISTS audit.log_security_event(BYTEA, VARCHAR, VARCHAR, JSONB);
    DROP FUNCTION IF EXISTS auth.cleanup_expired_sessions();
    DROP FUNCTION IF EXISTS auth.monitor_failed_logins(BYTEA, INTERVAL);
    DROP FUNCTION IF EXISTS auth.validate_password_policy(BYTEA, TEXT);
    DROP PROCEDURE IF EXISTS audit.maintain_audit_tables();
    DROP PROCEDURE IF EXISTS auth.generate_security_report(BYTEA, TIMESTAMP, TIMESTAMP);
    DROP FUNCTION IF EXISTS util.check_system_health();
    
    -- Drop tables created in this step
    DROP TABLE IF EXISTS audit.error_log_s;
    DROP TABLE IF EXISTS audit.error_log_h;
    DROP TABLE IF EXISTS audit.security_event_s;
    DROP TABLE IF EXISTS audit.security_event_h;
    DROP TABLE IF EXISTS audit.system_health_s;
    DROP TABLE IF EXISTS audit.system_health_h;
    
    -- Drop indexes created in this step
    DROP INDEX IF EXISTS audit.idx_error_log_h_tenant_hk_step14;
    DROP INDEX IF EXISTS audit.idx_error_log_s_error_code_step14;
    DROP INDEX IF EXISTS audit.idx_security_event_s_event_type_step14;
    DROP INDEX IF EXISTS audit.idx_system_health_s_health_status_step14;
    
    RAISE NOTICE 'Step 14 rollback completed successfully';
END;
$$;

-- =============================================
-- 1. Enhanced Error Logging Infrastructure
-- =============================================

-- Hub table for error events
CREATE TABLE audit.error_log_h (
    error_log_hk BYTEA PRIMARY KEY,
    error_log_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Satellite table for error details
CREATE TABLE audit.error_log_s (
    error_log_hk BYTEA NOT NULL REFERENCES audit.error_log_h(error_log_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    error_code VARCHAR(10) NOT NULL,
    error_message TEXT NOT NULL,
    error_severity VARCHAR(20) NOT NULL DEFAULT 'ERROR',
    stack_trace TEXT,
    context_data JSONB,
    affected_user_hk BYTEA,
    affected_session_hk BYTEA,
    resolution_status VARCHAR(20) DEFAULT 'OPEN',
    resolution_notes TEXT,
    first_occurrence TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    occurrence_count INTEGER DEFAULT 1,
    last_occurrence TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (error_log_hk, load_date)
);

-- =============================================
-- 2. Security Event Tracking Infrastructure
-- =============================================

-- Hub table for security events
CREATE TABLE audit.security_event_h (
    security_event_hk BYTEA PRIMARY KEY,
    security_event_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Satellite table for security event details
CREATE TABLE audit.security_event_s (
    security_event_hk BYTEA NOT NULL REFERENCES audit.security_event_h(security_event_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    event_severity VARCHAR(20) NOT NULL DEFAULT 'INFO',
    event_description TEXT NOT NULL,
    source_ip_address INET,
    user_agent TEXT,
    affected_user_hk BYTEA,
    affected_session_hk BYTEA,
    threat_level VARCHAR(20) DEFAULT 'LOW',
    investigation_status VARCHAR(20) DEFAULT 'PENDING',
    investigation_notes TEXT,
    event_metadata JSONB,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (security_event_hk, load_date)
);

-- =============================================
-- 3. System Health Monitoring Infrastructure
-- =============================================

-- Hub table for system health checks
CREATE TABLE audit.system_health_h (
    system_health_hk BYTEA PRIMARY KEY,
    system_health_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA REFERENCES auth.tenant_h(tenant_hk), -- Nullable for system-wide checks
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Satellite table for system health details
CREATE TABLE audit.system_health_s (
    system_health_hk BYTEA NOT NULL REFERENCES audit.system_health_h(system_health_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    check_type VARCHAR(50) NOT NULL,
    health_status VARCHAR(20) NOT NULL,
    health_score DECIMAL(5,2),
    performance_metrics JSONB,
    warning_indicators JSONB,
    error_indicators JSONB,
    recommendations JSONB,
    check_duration_ms INTEGER,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (system_health_hk, load_date)
);

-- =============================================
-- 4. Enhanced Error Logging Functions
-- =============================================

-- Function to log errors with comprehensive context
CREATE OR REPLACE FUNCTION audit.log_error(
    p_tenant_hk BYTEA,
    p_error_code VARCHAR(10),
    p_error_message TEXT,
    p_context_data JSONB DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_error_log_bk VARCHAR(255);
    v_error_log_hk BYTEA;
    v_hash_diff BYTEA;
    v_existing_error_hk BYTEA;
    v_occurrence_count INTEGER;
BEGIN
    -- Generate error log business key
    v_error_log_bk := 'ERROR_' || p_error_code || '_' || 
                     encode(p_tenant_hk, 'hex') || '_' || 
                     to_char(CURRENT_TIMESTAMP, 'YYYYMMDD');
    
    v_error_log_hk := util.hash_binary(v_error_log_bk);
    
    -- Check if this error already exists today
    SELECT error_log_hk, occurrence_count INTO v_existing_error_hk, v_occurrence_count
    FROM audit.error_log_s els
    JOIN audit.error_log_h elh ON els.error_log_hk = elh.error_log_hk
    WHERE elh.tenant_hk = p_tenant_hk
    AND els.error_code = p_error_code
    AND els.error_message = p_error_message
    AND els.load_end_date IS NULL
    AND els.first_occurrence::date = CURRENT_DATE
    ORDER BY els.load_date DESC
    LIMIT 1;
    
    IF v_existing_error_hk IS NOT NULL THEN
        -- Update existing error with new occurrence
        v_hash_diff := util.hash_binary(p_error_code || p_error_message || (v_occurrence_count + 1)::text || CURRENT_TIMESTAMP::text);
        
        INSERT INTO audit.error_log_s (
            error_log_hk,
            load_date,
            hash_diff,
            error_code,
            error_message,
            error_severity,
            context_data,
            resolution_status,
            first_occurrence,
            occurrence_count,
            last_occurrence,
            record_source
        )
        SELECT 
            error_log_hk,
            util.current_load_date(),
            v_hash_diff,
            error_code,
            error_message,
            error_severity,
            COALESCE(p_context_data, context_data),
            resolution_status,
            first_occurrence,
            occurrence_count + 1,
            CURRENT_TIMESTAMP,
            util.get_record_source()
        FROM audit.error_log_s
        WHERE error_log_hk = v_existing_error_hk
        AND load_end_date IS NULL
        ORDER BY load_date DESC
        LIMIT 1;
        
        -- End-date the previous record
        UPDATE audit.error_log_s
        SET load_end_date = util.current_load_date()
        WHERE error_log_hk = v_existing_error_hk
        AND load_end_date IS NULL
        AND load_date < util.current_load_date();
        
        RETURN v_existing_error_hk;
    ELSE
        -- Create new error log entry
        v_hash_diff := util.hash_binary(p_error_code || p_error_message || CURRENT_TIMESTAMP::text);
        
        -- Insert into hub
        INSERT INTO audit.error_log_h (
            error_log_hk,
            error_log_bk,
            tenant_hk,
            record_source
        ) VALUES (
            v_error_log_hk,
            v_error_log_bk,
            p_tenant_hk,
            util.get_record_source()
        );
        
        -- Insert into satellite
        INSERT INTO audit.error_log_s (
            error_log_hk,
            hash_diff,
            error_code,
            error_message,
            error_severity,
            context_data,
            resolution_status,
            record_source
        ) VALUES (
            v_error_log_hk,
            v_hash_diff,
            p_error_code,
            p_error_message,
            CASE 
                WHEN p_error_code IN ('FATAL', 'CRITICAL') THEN 'CRITICAL'
                WHEN p_error_code IN ('ERROR', 'FAILURE') THEN 'ERROR'
                WHEN p_error_code IN ('WARN', 'WARNING') THEN 'WARNING'
                ELSE 'ERROR'
            END,
            p_context_data,
            'OPEN',
            util.get_record_source()
        );
        
        RETURN v_error_log_hk;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to log security events
CREATE OR REPLACE FUNCTION audit.log_security_event(
    p_tenant_hk BYTEA,
    p_event_type VARCHAR(50),
    p_event_description TEXT,
    p_event_metadata JSONB DEFAULT NULL
) RETURNS BYTEA AS $$
DECLARE
    v_security_event_bk VARCHAR(255);
    v_security_event_hk BYTEA;
    v_hash_diff BYTEA;
    v_threat_level VARCHAR(20);
    v_event_severity VARCHAR(20);
BEGIN
    -- Generate security event business key
    v_security_event_bk := 'SEC_' || p_event_type || '_' || 
                          encode(p_tenant_hk, 'hex') || '_' || 
                          to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    
    v_security_event_hk := util.hash_binary(v_security_event_bk);
    v_hash_diff := util.hash_binary(p_event_type || p_event_description || CURRENT_TIMESTAMP::text);
    
    -- Determine threat level and severity based on event type
    CASE p_event_type
        WHEN 'FAILED_LOGIN_ATTEMPT' THEN
            v_threat_level := 'LOW';
            v_event_severity := 'INFO';
        WHEN 'ACCOUNT_LOCKED' THEN
            v_threat_level := 'MEDIUM';
            v_event_severity := 'WARNING';
        WHEN 'SUSPICIOUS_LOGIN_PATTERN' THEN
            v_threat_level := 'HIGH';
            v_event_severity := 'ERROR';
        WHEN 'UNAUTHORIZED_ACCESS_ATTEMPT' THEN
            v_threat_level := 'CRITICAL';
            v_event_severity := 'CRITICAL';
        WHEN 'SESSION_HIJACKING_DETECTED' THEN
            v_threat_level := 'CRITICAL';
            v_event_severity := 'CRITICAL';
        ELSE
            v_threat_level := 'LOW';
            v_event_severity := 'INFO';
    END CASE;
    
    -- Insert into hub
    INSERT INTO audit.security_event_h (
        security_event_hk,
        security_event_bk,
        tenant_hk,
        record_source
    ) VALUES (
        v_security_event_hk,
        v_security_event_bk,
        p_tenant_hk,
        util.get_record_source()
    );
    
    -- Insert into satellite
    INSERT INTO audit.security_event_s (
        security_event_hk,
        hash_diff,
        event_type,
        event_severity,
        event_description,
        source_ip_address,
        user_agent,
        threat_level,
        investigation_status,
        event_metadata,
        record_source
    ) VALUES (
        v_security_event_hk,
        v_hash_diff,
        p_event_type,
        v_event_severity,
        p_event_description,
        COALESCE((p_event_metadata->>'ip_address')::inet, NULL),
        p_event_metadata->>'user_agent',
        v_threat_level,
        'PENDING',
        p_event_metadata,
        util.get_record_source()
    );
    
    RETURN v_security_event_hk;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 5. Session Management and Cleanup Functions
-- =============================================

-- Function to cleanup expired sessions with comprehensive logging
CREATE OR REPLACE FUNCTION auth.cleanup_expired_sessions()
RETURNS TABLE (
    sessions_expired INTEGER,
    tokens_revoked INTEGER,
    cleanup_duration_ms INTEGER
) AS $$
DECLARE
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_sessions_expired INTEGER := 0;
    v_tokens_revoked INTEGER := 0;
    v_cleanup_duration_ms INTEGER;
    v_representative_tenant_hk BYTEA;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    -- Get a representative tenant for logging
    SELECT tenant_hk INTO v_representative_tenant_hk
    FROM auth.tenant_h
    LIMIT 1;
    
    -- Expire sessions based on security policies
    WITH expired_sessions AS (
        INSERT INTO auth.session_state_s (
            session_hk,
            load_date,
            hash_diff,
            session_start,
            session_end,
            ip_address,
            user_agent,
            session_data,
            session_status,
            last_activity,
            record_source
        )
        SELECT 
            sss.session_hk,
            util.current_load_date(),
            util.hash_binary(sh.session_bk || 'EXPIRED_CLEANUP' || CURRENT_TIMESTAMP::text),
            sss.session_start,
            CURRENT_TIMESTAMP,
            sss.ip_address,
            sss.user_agent,
            sss.session_data,
            'EXPIRED',
            sss.last_activity,
            util.get_record_source()
        FROM auth.session_state_s sss
        JOIN auth.session_h sh ON sss.session_hk = sh.session_hk
        LEFT JOIN auth.security_policy_h sph ON sh.tenant_hk = sph.tenant_hk
        LEFT JOIN auth.security_policy_s sp ON sph.security_policy_hk = sp.security_policy_hk 
            AND sp.is_active = TRUE AND sp.load_end_date IS NULL
        WHERE sss.session_status = 'ACTIVE'
        AND sss.load_end_date IS NULL
        AND (
            sss.last_activity < (CURRENT_TIMESTAMP - (COALESCE(sp.session_timeout_minutes, 60) || ' minutes')::interval)
            OR sss.session_start < (CURRENT_TIMESTAMP - (COALESCE(sp.session_absolute_timeout_hours, 12) || ' hours')::interval)
        )
        RETURNING session_hk
    )
    SELECT COUNT(*) INTO v_sessions_expired FROM expired_sessions;
    
    -- End-date the previous session records
    UPDATE auth.session_state_s sss
    SET load_end_date = util.current_load_date()
    FROM auth.session_h sh
    LEFT JOIN auth.security_policy_h sph ON sh.tenant_hk = sph.tenant_hk
    LEFT JOIN auth.security_policy_s sp ON sph.security_policy_hk = sp.security_policy_hk 
        AND sp.is_active = TRUE AND sp.load_end_date IS NULL
    WHERE sss.session_hk = sh.session_hk
    AND sss.session_status = 'ACTIVE'
    AND sss.load_end_date IS NULL
    AND sss.load_date < util.current_load_date()
    AND (
        sss.last_activity < (CURRENT_TIMESTAMP - (COALESCE(sp.session_timeout_minutes, 60) || ' minutes')::interval)
        OR sss.session_start < (CURRENT_TIMESTAMP - (COALESCE(sp.session_absolute_timeout_hours, 12) || ' hours')::interval)
    );
    
    -- Revoke tokens for expired sessions if token management exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'api_token_s') THEN
        WITH revoked_tokens AS (
            INSERT INTO auth.api_token_s (
                token_hk,
                load_date,
                hash_diff,
                token_hash,
                token_type,
                expires_at,
                is_revoked,
                revocation_reason,
                scope,
                last_used_at,
                record_source
            )
            SELECT 
                ats.token_hk,
                util.current_load_date(),
                util.hash_binary(ats.token_hash::text || 'SESSION_EXPIRED' || CURRENT_TIMESTAMP::text),
                ats.token_hash,
                ats.token_type,
                ats.expires_at,
                TRUE,
                'Session expired during cleanup',
                ats.scope,
                ats.last_used_at,
                util.get_record_source()
            FROM auth.api_token_s ats
            JOIN auth.session_token_l stl ON ats.token_hk = stl.token_hk
            JOIN auth.session_state_s sss ON stl.session_hk = sss.session_hk
            WHERE sss.session_status = 'EXPIRED'
            AND ats.is_revoked = FALSE
            AND ats.load_end_date IS NULL
            AND sss.load_date >= v_start_time
            RETURNING token_hk
        )
        SELECT COUNT(*) INTO v_tokens_revoked FROM revoked_tokens;
    END IF;
    
    v_end_time := CURRENT_TIMESTAMP;
    v_cleanup_duration_ms := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
    
    -- Log the cleanup operation
    IF v_sessions_expired > 0 OR v_tokens_revoked > 0 THEN
        PERFORM audit.log_security_event(
            COALESCE(v_representative_tenant_hk, decode('00000000', 'hex')),
            'SESSION_CLEANUP',
            format('Automated cleanup expired %s sessions and revoked %s tokens', v_sessions_expired, v_tokens_revoked),
            jsonb_build_object(
                'sessions_expired', v_sessions_expired,
                'tokens_revoked', v_tokens_revoked,
                'cleanup_duration_ms', v_cleanup_duration_ms
            )
        );
    END IF;
    
    RETURN QUERY SELECT v_sessions_expired, v_tokens_revoked, v_cleanup_duration_ms;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 6. Security Monitoring Functions
-- =============================================

-- Function to monitor failed login patterns
CREATE OR REPLACE FUNCTION auth.monitor_failed_logins(
    p_tenant_hk BYTEA,
    p_time_window INTERVAL DEFAULT '1 hour'::interval
) RETURNS TABLE (
    suspicious_ips INET[],
    failed_attempts_count INTEGER,
    unique_usernames_targeted INTEGER,
    threat_assessment VARCHAR(20)
) AS $$
DECLARE
    v_suspicious_ips INET[];
    v_failed_count INTEGER;
    v_unique_users INTEGER;
    v_threat_level VARCHAR(20);
BEGIN
    -- Analyze failed login patterns
    WITH failed_login_analysis AS (
        SELECT 
            sls.ip_address,
            COUNT(*) as attempt_count,
            COUNT(DISTINCT sls.username) as unique_users
        FROM staging.login_status_s sls
        JOIN staging.login_attempt_h slh ON sls.login_attempt_hk = slh.login_attempt_hk
        WHERE slh.tenant_hk = p_tenant_hk
        AND sls.validation_status IN ('INVALID_PASSWORD', 'INVALID_USER')
        AND sls.attempt_timestamp > (CURRENT_TIMESTAMP - p_time_window)
        AND sls.load_end_date IS NULL
        GROUP BY sls.ip_address
        HAVING COUNT(*) >= 5 -- Threshold for suspicious activity
    )
    SELECT 
        array_agg(ip_address),
        SUM(attempt_count)::INTEGER,
        SUM(unique_users)::INTEGER
    INTO 
        v_suspicious_ips,
        v_failed_count,
        v_unique_users
    FROM failed_login_analysis;
    
    -- Determine threat level
    IF v_failed_count > 100 OR v_unique_users > 20 THEN
        v_threat_level := 'CRITICAL';
    ELSIF v_failed_count > 50 OR v_unique_users > 10 THEN
        v_threat_level := 'HIGH';
    ELSIF v_failed_count > 20 OR v_unique_users > 5 THEN
        v_threat_level := 'MEDIUM';
    ELSE
        v_threat_level := 'LOW';
    END IF;
    
    -- Log security event if suspicious activity detected
    IF v_failed_count > 0 THEN
        PERFORM audit.log_security_event(
            p_tenant_hk,
            'SUSPICIOUS_LOGIN_PATTERN',
            format('Detected %s failed login attempts from %s IP addresses targeting %s users', 
                   v_failed_count, array_length(v_suspicious_ips, 1), v_unique_users),
            jsonb_build_object(
                'failed_attempts', v_failed_count,
                'suspicious_ips', v_suspicious_ips,
                'unique_users_targeted', v_unique_users,
                'time_window', p_time_window,
                'threat_level', v_threat_level
            )
        );
    END IF;
    
    RETURN QUERY SELECT 
        COALESCE(v_suspicious_ips, ARRAY[]::INET[]),
        COALESCE(v_failed_count, 0),
        COALESCE(v_unique_users, 0),
        v_threat_level;
END;
$$ LANGUAGE plpgsql;

-- Function to validate password policies with detailed reporting
CREATE OR REPLACE FUNCTION auth.validate_password_policy(
    p_tenant_hk BYTEA,
    p_password TEXT
) RETURNS TABLE (
    is_valid BOOLEAN,
    validation_score INTEGER,
    policy_violations TEXT[],
    recommendations TEXT[]
) AS $$
DECLARE
    v_policy auth.security_policy_s%ROWTYPE;
    v_violations TEXT[] := ARRAY[]::TEXT[];
    v_recommendations TEXT[] := ARRAY[]::TEXT[];
    v_score INTEGER := 100;
BEGIN
    -- Get security policy for tenant
    SELECT sp.* INTO v_policy
    FROM auth.security_policy_s sp
    JOIN auth.security_policy_h hp ON sp.security_policy_hk = hp.security_policy_hk
    WHERE hp.tenant_hk = p_tenant_hk
    AND sp.is_active = TRUE
    AND sp.load_end_date IS NULL
    ORDER BY sp.load_date DESC
    LIMIT 1;
    
    -- If no policy found, use defaults
    IF v_policy.security_policy_hk IS NULL THEN
        v_policy.password_min_length := 8;
        v_policy.password_require_uppercase := TRUE;
        v_policy.password_require_lowercase := TRUE;
        v_policy.password_require_number := TRUE;
        v_policy.password_require_special := TRUE;
    END IF;
    
    -- Validate password length
    IF LENGTH(p_password) < v_policy.password_min_length THEN
        v_violations := array_append(v_violations, 
            format('Password must be at least %s characters long', v_policy.password_min_length));
        v_recommendations := array_append(v_recommendations, 
            format('Add %s more characters to meet minimum length requirement', 
                   v_policy.password_min_length - LENGTH(p_password)));
        v_score := v_score - 30;
    END IF;
    
    -- Validate uppercase requirement
    IF v_policy.password_require_uppercase AND NOT (p_password ~ '[A-Z]') THEN
        v_violations := array_append(v_violations, 'Password must contain at least one uppercase letter');
        v_recommendations := array_append(v_recommendations, 'Add at least one uppercase letter (A-Z)');
        v_score := v_score - 20;
    END IF;
    
    -- Validate lowercase requirement
    IF v_policy.password_require_lowercase AND NOT (p_password ~ '[a-z]') THEN
        v_violations := array_append(v_violations, 'Password must contain at least one lowercase letter');
        v_recommendations := array_append(v_recommendations, 'Add at least one lowercase letter (a-z)');
        v_score := v_score - 20;
    END IF;
    
    -- Validate number requirement
    IF v_policy.password_require_number AND NOT (p_password ~ '[0-9]') THEN
        v_violations := array_append(v_violations, 'Password must contain at least one number');
        v_recommendations := array_append(v_recommendations, 'Add at least one number (0-9)');
        v_score := v_score - 20;
    END IF;
    
    -- Validate special character requirement
    IF v_policy.password_require_special AND NOT (p_password ~ '[^A-Za-z0-9]') THEN
        v_violations := array_append(v_violations, 'Password must contain at least one special character');
        v_recommendations := array_append(v_recommendations, 'Add at least one special character (!@#$%^&*()_+-=[]{}|;:,.<>?)');
        v_score := v_score - 20;
    END IF;
    
    -- Additional strength checks
    IF LENGTH(p_password) >= 16 THEN
        v_score := v_score + 10; -- Bonus for long passwords
    END IF;
    
    IF p_password ~ '.*(.)\1{2,}.*' THEN
        v_violations := array_append(v_violations, 'Password should not contain repeated characters');
        v_recommendations := array_append(v_recommendations, 'Avoid using the same character more than twice in a row');
        v_score := v_score - 10;
    END IF;
    
    -- Ensure score doesn't go below 0
    v_score := GREATEST(v_score, 0);
    
    RETURN QUERY SELECT 
        array_length(v_violations, 1) IS NULL,
        v_score,
        v_violations,
        v_recommendations;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 7. System Health Monitoring
-- =============================================

-- Function to check overall system health
CREATE OR REPLACE FUNCTION util.check_system_health()
RETURNS TABLE (
    health_status VARCHAR(20),
    overall_score DECIMAL(5,2),
    component_scores JSONB,
    warnings TEXT[],
    critical_issues TEXT[]
) AS $$
DECLARE
    v_health_status VARCHAR(20);
    v_overall_score DECIMAL(5,2) := 0;
    v_component_scores JSONB := '{}'::jsonb;
    v_warnings TEXT[] := ARRAY[]::TEXT[];
    v_critical_issues TEXT[] := ARRAY[]::TEXT[];
    v_db_connections INTEGER;
    v_active_sessions INTEGER;
    v_failed_logins_24h INTEGER;
    v_error_count_24h INTEGER;
    v_avg_response_time DECIMAL(10,2);
BEGIN
    -- Check database connections
    SELECT COUNT(*) INTO v_db_connections
    FROM pg_stat_activity
    WHERE state = 'active';
    
    -- Check active sessions
    SELECT COUNT(*) INTO v_active_sessions
    FROM auth.session_state_s
    WHERE session_status = 'ACTIVE'
    AND load_end_date IS NULL;
    
    -- Check failed logins in last 24 hours
    SELECT COUNT(*) INTO v_failed_logins_24h
    FROM staging.login_status_s
    WHERE validation_status IN ('INVALID_PASSWORD', 'INVALID_USER')
    AND attempt_timestamp > CURRENT_TIMESTAMP - INTERVAL '24 hours'
    AND load_end_date IS NULL;
    
    -- Check error count in last 24 hours
    SELECT COALESCE(SUM(occurrence_count), 0) INTO v_error_count_24h
    FROM audit.error_log_s
    WHERE first_occurrence > CURRENT_TIMESTAMP - INTERVAL '24 hours'
    AND load_end_date IS NULL;
    
    -- Build component scores
    v_component_scores := jsonb_build_object(
        'database_connections', CASE 
            WHEN v_db_connections < 50 THEN 100
            WHEN v_db_connections < 100 THEN 75
            WHEN v_db_connections < 200 THEN 50
            ELSE 25
        END,
        'active_sessions', CASE 
            WHEN v_active_sessions < 1000 THEN 100
            WHEN v_active_sessions < 5000 THEN 75
            WHEN v_active_sessions < 10000 THEN 50
            ELSE 25
        END,
        'failed_logins_24h', CASE 
            WHEN v_failed_logins_24h < 100 THEN 100
            WHEN v_failed_logins_24h < 500 THEN 75
            WHEN v_failed_logins_24h < 1000 THEN 50
            ELSE 25
        END,
        'error_count_24h', CASE 
            WHEN v_error_count_24h < 10 THEN 100
            WHEN v_error_count_24h < 50 THEN 75
            WHEN v_error_count_24h < 100 THEN 50
            ELSE 25
        END
    );
    
    -- Calculate overall score
    v_overall_score := (
        (v_component_scores->>'database_connections')::INTEGER +
        (v_component_scores->>'active_sessions')::INTEGER +
        (v_component_scores->>'failed_logins_24h')::INTEGER +
        (v_component_scores->>'error_count_24h')::INTEGER
    ) / 4.0;
    
    -- Generate warnings and critical issues
    IF v_db_connections > 150 THEN
        v_warnings := array_append(v_warnings, format('High database connection count: %s', v_db_connections));
    END IF;
    
    IF v_failed_logins_24h > 500 THEN
        v_critical_issues := array_append(v_critical_issues, format('Excessive failed logins in 24h: %s', v_failed_logins_24h));
    END IF;
    
    IF v_error_count_24h > 100 THEN
        v_critical_issues := array_append(v_critical_issues, format('High error count in 24h: %s', v_error_count_24h));
    END IF;
    
    -- Determine overall health status
    IF v_overall_score >= 90 AND array_length(v_critical_issues, 1) IS NULL THEN
        v_health_status := 'HEALTHY';
    ELSIF v_overall_score >= 70 AND array_length(v_critical_issues, 1) IS NULL THEN
        v_health_status := 'WARNING';
    ELSE
        v_health_status := 'CRITICAL';
    END IF;
    
    RETURN QUERY SELECT 
        v_health_status,
        v_overall_score,
        v_component_scores,
        v_warnings,
        v_critical_issues;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 8. Maintenance and Reporting Procedures
-- =============================================

-- Procedure to maintain audit tables and optimize performance
CREATE OR REPLACE PROCEDURE audit.maintain_audit_tables()
LANGUAGE plpgsql AS $$
DECLARE
    v_archive_threshold TIMESTAMP WITH TIME ZONE;
    v_archived_records INTEGER := 0;
    v_maintenance_log_hk BYTEA;
BEGIN
    -- Set archive threshold to 90 days ago
    v_archive_threshold := CURRENT_TIMESTAMP - INTERVAL '90 days';
    
    -- Archive old error logs by end-dating them
    UPDATE audit.error_log_s
    SET load_end_date = CURRENT_TIMESTAMP
    WHERE first_occurrence < v_archive_threshold
    AND resolution_status = 'RESOLVED'
    AND load_end_date IS NULL;
    
    GET DIAGNOSTICS v_archived_records = ROW_COUNT;
    
    -- Archive old security events
    UPDATE audit.security_event_s
    SET load_end_date = CURRENT_TIMESTAMP
    WHERE load_date < v_archive_threshold
    AND investigation_status = 'CLOSED'
    AND load_end_date IS NULL;
    
    -- Log maintenance activity
    SELECT audit.log_security_event(
        (SELECT tenant_hk FROM auth.tenant_h LIMIT 1),
        'AUDIT_MAINTENANCE',
        format('Archived %s old audit records', v_archived_records),
        jsonb_build_object(
            'archived_records', v_archived_records,
            'archive_threshold', v_archive_threshold
        )
    ) INTO v_maintenance_log_hk;
    
    -- Analyze tables for performance optimization
    ANALYZE audit.error_log_h;
    ANALYZE audit.error_log_s;
    ANALYZE audit.security_event_h;
    ANALYZE audit.security_event_s;
    
    RAISE NOTICE 'Audit maintenance completed: archived % records', v_archived_records;
END;
$$;

-- Procedure to generate comprehensive security reports
CREATE OR REPLACE PROCEDURE auth.generate_security_report(
    p_tenant_hk BYTEA,
    p_start_date TIMESTAMP WITH TIME ZONE,
    p_end_date TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql AS $$
DECLARE
    v_report_data JSONB;
    v_failed_logins INTEGER;
    v_successful_logins INTEGER;
    v_locked_accounts INTEGER;
    v_security_events INTEGER;
    v_critical_errors INTEGER;
BEGIN
    -- Gather security metrics
    SELECT COUNT(*) INTO v_failed_logins
    FROM staging.login_status_s sls
    JOIN staging.login_attempt_h slh ON sls.login_attempt_hk = slh.login_attempt_hk
    WHERE slh.tenant_hk = p_tenant_hk
    AND sls.validation_status IN ('INVALID_PASSWORD', 'INVALID_USER')
    AND sls.attempt_timestamp BETWEEN p_start_date AND p_end_date
    AND sls.load_end_date IS NULL;
    
    SELECT COUNT(*) INTO v_successful_logins
    FROM staging.login_status_s sls
    JOIN staging.login_attempt_h slh ON sls.login_attempt_hk = slh.login_attempt_hk
    WHERE slh.tenant_hk = p_tenant_hk
    AND sls.validation_status = 'VALID'
    AND sls.attempt_timestamp BETWEEN p_start_date AND p_end_date
    AND sls.load_end_date IS NULL;
    
    SELECT COUNT(*) INTO v_locked_accounts
    FROM auth.user_auth_s uas
    JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
    WHERE uh.tenant_hk = p_tenant_hk
    AND uas.account_locked = TRUE
    AND uas.load_date BETWEEN p_start_date AND p_end_date
    AND uas.load_end_date IS NULL;
    
    SELECT COUNT(*) INTO v_security_events
    FROM audit.security_event_s ses
    JOIN audit.security_event_h seh ON ses.security_event_hk = seh.security_event_hk
    WHERE seh.tenant_hk = p_tenant_hk
    AND ses.load_date BETWEEN p_start_date AND p_end_date
    AND ses.load_end_date IS NULL;
    
    SELECT COUNT(*) INTO v_critical_errors
    FROM audit.error_log_s els
    JOIN audit.error_log_h elh ON els.error_log_hk = elh.error_log_hk
    WHERE elh.tenant_hk = p_tenant_hk
    AND els.error_severity = 'CRITICAL'
    AND els.first_occurrence BETWEEN p_start_date AND p_end_date
    AND els.load_end_date IS NULL;
    
    -- Build comprehensive report
    v_report_data := jsonb_build_object(
        'report_period', jsonb_build_object(
            'start_date', p_start_date,
            'end_date', p_end_date
        ),
        'authentication_metrics', jsonb_build_object(
            'successful_logins', v_successful_logins,
            'failed_logins', v_failed_logins,
            'success_rate', CASE 
                WHEN (v_successful_logins + v_failed_logins) > 0 
                THEN ROUND((v_successful_logins::DECIMAL / (v_successful_logins + v_failed_logins)) * 100, 2)
                ELSE 0 
            END
        ),
        'security_metrics', jsonb_build_object(
            'locked_accounts', v_locked_accounts,
            'security_events', v_security_events,
            'critical_errors', v_critical_errors
        )
    );
    
    -- Log the report generation
    PERFORM audit.log_security_event(
        p_tenant_hk,
        'SECURITY_REPORT_GENERATED',
        format('Security report generated for period %s to %s', p_start_date, p_end_date),
        v_report_data
    );
    
    RAISE NOTICE 'Security report generated: %', v_report_data;
END;
$$;

-- =============================================
-- 9. Performance Indexes and Constraints
-- =============================================

-- Create performance indexes for error logging
CREATE INDEX IF NOT EXISTS idx_error_log_h_tenant_hk_step14 
ON audit.error_log_h(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_error_log_s_error_code_step14 
ON audit.error_log_s(error_code, first_occurrence) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_error_log_s_severity_step14 
ON audit.error_log_s(error_severity, first_occurrence) 
WHERE load_end_date IS NULL;

-- Create indexes for security event tracking
CREATE INDEX IF NOT EXISTS idx_security_event_h_tenant_hk_step14 
ON audit.security_event_h(tenant_hk);

CREATE INDEX IF NOT EXISTS idx_security_event_s_event_type_step14 
ON audit.security_event_s(event_type, load_date) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_security_event_s_threat_level_step14 
ON audit.security_event_s(threat_level, load_date) 
WHERE load_end_date IS NULL;

-- Create indexes for system health monitoring
CREATE INDEX IF NOT EXISTS idx_system_health_s_health_status_step14 
ON audit.system_health_s(health_status, load_date) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_system_health_s_check_type_step14 
ON audit.system_health_s(check_type, load_date) 
WHERE load_end_date IS NULL;

-- Create audit triggers for new tables
SELECT util.create_audit_triggers_safe('audit');

-- Verification procedure for step 14
CREATE OR REPLACE PROCEDURE util.verify_step_14_implementation()
LANGUAGE plpgsql AS $$
DECLARE
    v_table_count INTEGER;
    v_function_count INTEGER;
    v_index_count INTEGER;
BEGIN
    -- Count tables created
    SELECT COUNT(*) INTO v_table_count
    FROM information_schema.tables
    WHERE table_schema = 'audit'
    AND table_name IN ('error_log_h', 'error_log_s', 'security_event_h', 'security_event_s', 'system_health_h', 'system_health_s');

    -- Count functions and procedures created
    SELECT COUNT(*) INTO v_function_count
    FROM information_schema.routines
    WHERE routine_schema IN ('audit', 'auth', 'util')
    AND routine_name IN (
        'log_error', 'log_security_event', 'cleanup_expired_sessions',
        'monitor_failed_logins', 'validate_password_policy', 'check_system_health',
        'maintain_audit_tables', 'generate_security_report'
    );

    -- Count indexes created
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE schemaname = 'audit'
    AND indexname LIKE '%_step14';

    RAISE NOTICE 'Step 14 Verification Results:';
    RAISE NOTICE 'Tables created: % (expected: 6)', v_table_count;
    RAISE NOTICE 'Functions/Procedures: % (expected: 8)', v_function_count;
    RAISE NOTICE 'Indexes created: % (expected: 8)', v_index_count;
    
    IF v_table_count = 6 AND v_function_count = 8 THEN
        RAISE NOTICE 'Step 14 implementation appears successful!';
    ELSE
        RAISE NOTICE 'Step 14 implementation may have issues - please review';
    END IF;
END;
$$;

-- Run verification
CALL util.verify_step_14_implementation();

COMMENT ON FUNCTION audit.log_error IS 
'Comprehensive error logging with context tracking and occurrence counting for production monitoring';

COMMENT ON FUNCTION audit.log_security_event IS 
'Security event logging with threat assessment and automated categorization for compliance and monitoring';

COMMENT ON FUNCTION auth.cleanup_expired_sessions IS 
'Automated session cleanup with comprehensive logging and token revocation for security maintenance';

COMMENT ON PROCEDURE audit.maintain_audit_tables IS 
'Automated audit table maintenance including archival and performance optimization for long-term operations';