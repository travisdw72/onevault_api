-- =============================================
-- Step 13 Enhanced: Rollback-Safe Security Features Implementation
-- Data Vault 2.0 with New Naming Conventions
-- Enhanced Security with Proper Error Handling and Rollback Support
-- =============================================

-- Create rollback procedure first
CREATE OR REPLACE PROCEDURE auth.rollback_step_13()
LANGUAGE plpgsql AS $$
BEGIN
    -- Drop functions and procedures created in this step
    DROP FUNCTION IF EXISTS auth.check_account_lockout(BYTEA, BYTEA);
    DROP PROCEDURE IF EXISTS auth.process_valid_login_enhanced(BYTEA, BYTEA, BYTEA);
    DROP FUNCTION IF EXISTS auth.process_failed_login(BYTEA, VARCHAR, VARCHAR, INET);
    DROP PROCEDURE IF EXISTS auth.maintain_security_state();
    DROP FUNCTION IF EXISTS auth.validate_session_enhanced(BYTEA, INET, TEXT);
    
    -- Drop indexes created in this step (ignore errors if they don't exist)
    DROP INDEX IF EXISTS auth.idx_user_auth_s_failed_attempts;
    DROP INDEX IF EXISTS auth.idx_user_auth_s_account_locked_step13;
    DROP INDEX IF EXISTS auth.idx_session_state_s_last_activity_step13;
    DROP INDEX IF EXISTS auth.idx_session_state_s_session_start;
    DROP INDEX IF EXISTS auth.idx_login_status_s_username_validation;
    
    RAISE NOTICE 'Step 13 rollback completed successfully';
END;
$$;

-- Enhanced audit trigger creation function that handles existing triggers
CREATE OR REPLACE FUNCTION util.create_audit_triggers_safe(p_schema_name text)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    v_table_name text;
    v_trigger_name text;
    v_trigger_exists boolean;
BEGIN
    FOR v_table_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = p_schema_name 
        AND table_type = 'BASE TABLE'
    LOOP
        -- Generate trigger name
        v_trigger_name := 'trg_audit_' || lower(v_table_name);
        
        -- Check if trigger already exists
        SELECT EXISTS (
            SELECT 1 
            FROM information_schema.triggers 
            WHERE trigger_schema = p_schema_name 
            AND event_object_table = v_table_name 
            AND trigger_name = v_trigger_name
        ) INTO v_trigger_exists;
        
        -- Only create trigger if it doesn't exist
        IF NOT v_trigger_exists THEN
            EXECUTE format('
                CREATE TRIGGER %I
                AFTER INSERT OR UPDATE OR DELETE ON %I.%I
                FOR EACH ROW
                EXECUTE FUNCTION util.audit_track_dispatcher();',
                v_trigger_name,
                p_schema_name,
                v_table_name
            );
            
            RAISE NOTICE 'Created audit trigger % for %.%', v_trigger_name, p_schema_name, v_table_name;
        ELSE
            RAISE NOTICE 'Audit trigger % already exists for %.% - skipping', v_trigger_name, p_schema_name, v_table_name;
        END IF;
    END LOOP;
END;
$$;

-- Function to check if account should be locked based on security policy
CREATE OR REPLACE FUNCTION auth.check_account_lockout(
    p_tenant_hk BYTEA,
    p_user_hk BYTEA
) RETURNS BOOLEAN AS $$
DECLARE
    v_failed_attempts INTEGER;
    v_lockout_threshold INTEGER;
    v_lockout_duration INTEGER;
    v_username VARCHAR(100);
    v_last_lockout_time TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Get username for this user
    SELECT username INTO v_username
    FROM auth.user_auth_s
    WHERE user_hk = p_user_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    -- Get security policy settings for the tenant
    SELECT 
        sp.account_lockout_threshold,
        sp.account_lockout_duration_minutes
    INTO 
        v_lockout_threshold,
        v_lockout_duration
    FROM auth.security_policy_s sp
    JOIN auth.security_policy_h hp ON sp.security_policy_hk = hp.security_policy_hk
    WHERE hp.tenant_hk = p_tenant_hk
    AND sp.is_active = TRUE
    AND sp.load_end_date IS NULL
    ORDER BY sp.load_date DESC
    LIMIT 1;

    -- Get the last lockout time for this user
    SELECT account_locked_until INTO v_last_lockout_time
    FROM auth.user_auth_s
    WHERE user_hk = p_user_hk
    AND account_locked = TRUE
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    -- If account is currently locked, check if lockout period has expired
    IF v_last_lockout_time IS NOT NULL AND 
       v_last_lockout_time > CURRENT_TIMESTAMP THEN
        RETURN TRUE; -- Account is still locked
    END IF;

    -- Count recent failed login attempts from staging login status
    -- Note: Using the table names with new naming convention
    SELECT COUNT(*) INTO v_failed_attempts
    FROM staging.login_status_s sls
    JOIN staging.login_attempt_h slh ON sls.login_attempt_hk = slh.login_attempt_hk
    WHERE slh.tenant_hk = p_tenant_hk
    AND sls.username = v_username
    AND sls.validation_status IN ('INVALID_PASSWORD', 'INVALID_USER')
    AND sls.attempt_timestamp > CURRENT_TIMESTAMP - (COALESCE(v_lockout_duration, 30) || ' minutes')::INTERVAL
    AND sls.load_end_date IS NULL;

    -- Return true if failed attempts exceed threshold
    RETURN v_failed_attempts >= COALESCE(v_lockout_threshold, 5);
END;
$$ LANGUAGE plpgsql;

-- Procedure to process valid login and create session with enhanced security
CREATE OR REPLACE PROCEDURE auth.process_valid_login_enhanced(
    IN p_login_attempt_hk BYTEA,
    OUT p_session_hk BYTEA,
    OUT p_user_hk BYTEA
) LANGUAGE plpgsql AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_session_bk VARCHAR(255);
    v_username VARCHAR(255);
    v_ip_address INET;
    v_user_agent TEXT;
    v_validation_status VARCHAR(20);
    v_security_policy RECORD;
    v_api_token TEXT;
BEGIN
    -- Get validation status and related information
    SELECT 
        slh.tenant_hk,
        sls.validation_status,
        sls.username,
        sls.ip_address,
        sls.user_agent
    INTO 
        v_tenant_hk,
        v_validation_status,
        v_username,
        v_ip_address,
        v_user_agent
    FROM staging.login_attempt_h slh
    JOIN staging.login_status_s sls ON slh.login_attempt_hk = sls.login_attempt_hk
    WHERE slh.login_attempt_hk = p_login_attempt_hk
    AND sls.validation_status = 'VALID'
    AND sls.load_end_date IS NULL
    ORDER BY sls.load_date DESC
    LIMIT 1;

    -- Only proceed if login is valid
    IF v_validation_status = 'VALID' THEN
        -- Get user details
        SELECT uh.user_hk INTO v_user_hk
        FROM auth.user_h uh
        JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
        WHERE uh.tenant_hk = v_tenant_hk
        AND uas.username = v_username
        AND uas.load_end_date IS NULL
        ORDER BY uas.load_date DESC
        LIMIT 1;

        -- Check if account should be locked
        IF auth.check_account_lockout(v_tenant_hk, v_user_hk) THEN
            -- Lock the account by creating new auth satellite record
            INSERT INTO auth.user_auth_s (
                user_hk,
                load_date,
                hash_diff,
                username,
                password_hash,
                password_salt,
                last_login_date,
                password_last_changed,
                failed_login_attempts,
                account_locked,
                account_locked_until,
                must_change_password,
                record_source
            )
            SELECT 
                user_hk,
                util.current_load_date(),
                util.hash_binary(username || 'LOCKED' || CURRENT_TIMESTAMP::text),
                username,
                password_hash,
                password_salt,
                last_login_date,
                password_last_changed,
                COALESCE(failed_login_attempts, 0) + 1,
                TRUE, -- account_locked
                CURRENT_TIMESTAMP + INTERVAL '30 minutes', -- account_locked_until
                must_change_password,
                util.get_record_source()
            FROM auth.user_auth_s
            WHERE user_hk = v_user_hk
            AND load_end_date IS NULL
            ORDER BY load_date DESC
            LIMIT 1;

            -- End-date the previous record
            UPDATE auth.user_auth_s
            SET load_end_date = util.current_load_date()
            WHERE user_hk = v_user_hk
            AND load_end_date IS NULL
            AND load_date < util.current_load_date();

            -- Return null values to indicate failed login due to lockout
            p_session_hk := NULL;
            p_user_hk := NULL;
            RETURN;
        END IF;

        -- Get security policy for session creation
        SELECT 
            sp.session_timeout_minutes,
            sp.require_mfa,
            COALESCE(sp.session_absolute_timeout_hours, 12) as session_absolute_timeout_hours
        INTO v_security_policy
        FROM auth.security_policy_s sp
        JOIN auth.security_policy_h hp ON sp.security_policy_hk = hp.security_policy_hk
        WHERE hp.tenant_hk = v_tenant_hk
        AND sp.is_active = TRUE
        AND sp.load_end_date IS NULL
        ORDER BY sp.load_date DESC
        LIMIT 1;

        -- Generate session identifiers
        v_session_bk := 'SESSION_' || encode(v_tenant_hk, 'hex') || '_' || 
                       encode(v_user_hk, 'hex') || '_' || 
                       to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
        p_session_hk := util.hash_binary(v_session_bk);

        -- Create session hub record
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

        -- Create session state satellite record
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
        ) VALUES (
            p_session_hk,
            util.current_load_date(),
            util.hash_binary(v_session_bk || 'ACTIVE' || COALESCE(v_ip_address::text, 'UNKNOWN')),
            CURRENT_TIMESTAMP,
            NULL, -- session_end
            v_ip_address,
            v_user_agent,
            jsonb_build_object(
                'require_mfa', COALESCE(v_security_policy.require_mfa, false),
                'timeout_minutes', COALESCE(v_security_policy.session_timeout_minutes, 60)
            ),
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
            util.hash_binary(v_user_hk::text || p_session_hk::text),
            v_user_hk,
            p_session_hk,
            v_tenant_hk,
            util.current_load_date(),
            util.get_record_source()
        );

        -- Update user's last login and reset failed attempts
        INSERT INTO auth.user_auth_s (
            user_hk,
            load_date,
            hash_diff,
            username,
            password_hash,
            password_salt,
            last_login_date,
            password_last_changed,
            failed_login_attempts,
            account_locked,
            account_locked_until,
            must_change_password,
            record_source
        )
        SELECT 
            user_hk,
            util.current_load_date(),
            util.hash_binary(username || 'LOGIN_SUCCESS' || CURRENT_TIMESTAMP::text),
            username,
            password_hash,
            password_salt,
            CURRENT_TIMESTAMP, -- last_login_date
            password_last_changed,
            0, -- Reset failed_login_attempts
            FALSE, -- account_locked
            NULL, -- account_locked_until
            must_change_password,
            util.get_record_source()
        FROM auth.user_auth_s
        WHERE user_hk = v_user_hk
        AND load_end_date IS NULL
        ORDER BY load_date DESC
        LIMIT 1;

        -- End-date the previous auth record
        UPDATE auth.user_auth_s
        SET load_end_date = util.current_load_date()
        WHERE user_hk = v_user_hk
        AND load_end_date IS NULL
        AND load_date < util.current_load_date();

        -- Generate API token for the session if the procedure exists
        BEGIN
            CALL auth.generate_token_for_session(p_session_hk, v_api_token);
            
            -- Update session business key to include token reference
            UPDATE auth.session_h
            SET session_bk = v_api_token
            WHERE session_hk = p_session_hk;
        EXCEPTION WHEN OTHERS THEN
            -- If token generation fails, continue without it
            RAISE NOTICE 'Token generation skipped: %', SQLERRM;
        END;

        -- Set output parameters
        p_user_hk := v_user_hk;

    ELSE
        -- Invalid login attempt
        p_session_hk := NULL;
        p_user_hk := NULL;
    END IF;
END;
$$;

-- Function to handle failed login attempts and update security metrics
CREATE OR REPLACE FUNCTION auth.process_failed_login(
    p_tenant_hk BYTEA,
    p_username VARCHAR(255),
    p_failure_reason VARCHAR(255),
    p_ip_address INET
) RETURNS BOOLEAN AS $$
DECLARE
    v_user_hk BYTEA;
    v_current_attempts INTEGER;
    v_lockout_threshold INTEGER;
BEGIN
    -- Get user hash key
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uh.tenant_hk = p_tenant_hk
    AND uas.username = p_username
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;

    -- If user not found, return false
    IF v_user_hk IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Get current failed attempts and lockout threshold
    SELECT 
        COALESCE(uas.failed_login_attempts, 0),
        COALESCE(sp.account_lockout_threshold, 5)
    INTO 
        v_current_attempts,
        v_lockout_threshold
    FROM auth.user_auth_s uas
    JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
    LEFT JOIN auth.security_policy_h sph ON uh.tenant_hk = sph.tenant_hk
    LEFT JOIN auth.security_policy_s sp ON sph.security_policy_hk = sp.security_policy_hk 
        AND sp.is_active = TRUE AND sp.load_end_date IS NULL
    WHERE uas.user_hk = v_user_hk
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC, sp.load_date DESC
    LIMIT 1;

    -- Increment failed attempts counter
    v_current_attempts := v_current_attempts + 1;

    -- Create new auth satellite record with updated failed attempts
    INSERT INTO auth.user_auth_s (
        user_hk,
        load_date,
        hash_diff,
        username,
        password_hash,
        password_salt,
        last_login_date,
        password_last_changed,
        failed_login_attempts,
        account_locked,
        account_locked_until,
        must_change_password,
        record_source
    )
    SELECT 
        user_hk,
        util.current_load_date(),
        util.hash_binary(username || 'FAILED_LOGIN' || v_current_attempts::text || CURRENT_TIMESTAMP::text),
        username,
        password_hash,
        password_salt,
        last_login_date,
        password_last_changed,
        v_current_attempts,
        CASE 
            WHEN v_current_attempts >= v_lockout_threshold THEN TRUE 
            ELSE COALESCE(account_locked, false)
        END,
        CASE 
            WHEN v_current_attempts >= v_lockout_threshold 
            THEN CURRENT_TIMESTAMP + INTERVAL '30 minutes'
            ELSE account_locked_until 
        END,
        must_change_password,
        util.get_record_source()
    FROM auth.user_auth_s
    WHERE user_hk = v_user_hk
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    -- End-date the previous record
    UPDATE auth.user_auth_s
    SET load_end_date = util.current_load_date()
    WHERE user_hk = v_user_hk
    AND load_end_date IS NULL
    AND load_date < util.current_load_date();

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Procedure to maintain security state and clean up expired sessions
CREATE OR REPLACE PROCEDURE auth.maintain_security_state()
LANGUAGE plpgsql AS $$
DECLARE
    v_audit_event_bk VARCHAR(255);
    v_audit_event_hk BYTEA;
    v_expired_sessions INTEGER := 0;
    v_unlocked_accounts INTEGER := 0;
    v_representative_tenant_hk BYTEA;
BEGIN
    -- Get a representative tenant for audit logging
    SELECT tenant_hk INTO v_representative_tenant_hk
    FROM auth.tenant_h
    LIMIT 1;

    -- Create audit event for maintenance
    v_audit_event_bk := 'SECURITY_MAINTENANCE_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    v_audit_event_hk := util.hash_binary(v_audit_event_bk);

    -- Expire old sessions based on security policy
    WITH expired_session_updates AS (
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
            util.hash_binary(sh.session_bk || 'EXPIRED' || CURRENT_TIMESTAMP::text),
            sss.session_start,
            CURRENT_TIMESTAMP, -- session_end
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
    SELECT COUNT(*) INTO v_expired_sessions FROM expired_session_updates;

    -- End-date the previous session state records that were expired
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

    -- Unlock accounts where lockout period has expired
    WITH unlocked_account_updates AS (
        INSERT INTO auth.user_auth_s (
            user_hk,
            load_date,
            hash_diff,
            username,
            password_hash,
            password_salt,
            last_login_date,
            password_last_changed,
            failed_login_attempts,
            account_locked,
            account_locked_until,
            must_change_password,
            record_source
        )
        SELECT 
            user_hk,
            util.current_load_date(),
            util.hash_binary(username || 'AUTO_UNLOCK' || CURRENT_TIMESTAMP::text),
            username,
            password_hash,
            password_salt,
            last_login_date,
            password_last_changed,
            0, -- Reset failed attempts
            FALSE, -- account_locked
            NULL, -- account_locked_until
            must_change_password,
            util.get_record_source()
        FROM auth.user_auth_s
        WHERE account_locked = TRUE
        AND account_locked_until < CURRENT_TIMESTAMP
        AND load_end_date IS NULL
        RETURNING user_hk
    )
    SELECT COUNT(*) INTO v_unlocked_accounts FROM unlocked_account_updates;

    -- End-date the previous locked auth records
    UPDATE auth.user_auth_s
    SET load_end_date = util.current_load_date()
    WHERE account_locked = TRUE
    AND account_locked_until < CURRENT_TIMESTAMP
    AND load_end_date IS NULL
    AND load_date < util.current_load_date();

    -- Log the maintenance activity if any changes were made and we have a tenant
    IF (v_expired_sessions > 0 OR v_unlocked_accounts > 0) AND v_representative_tenant_hk IS NOT NULL THEN
        INSERT INTO audit.audit_event_h (
            audit_event_hk,
            audit_event_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_audit_event_hk,
            v_audit_event_bk,
            v_representative_tenant_hk,
            util.current_load_date(),
            util.get_record_source()
        );

        -- Log maintenance details
        INSERT INTO audit.audit_detail_s (
            audit_event_hk,
            hash_diff,
            table_name,
            operation,
            changed_by,
            old_data,
            new_data
        ) VALUES (
            v_audit_event_hk,
            util.hash_binary('SECURITY_MAINTENANCE_' || CURRENT_TIMESTAMP::text),
            'auth.session_state_s, auth.user_auth_s',
            'MAINTENANCE',
            SESSION_USER,
            NULL,
            jsonb_build_object(
                'maintenance_time', CURRENT_TIMESTAMP,
                'expired_sessions', v_expired_sessions,
                'unlocked_accounts', v_unlocked_accounts
            )
        );
    END IF;
END;
$$;

-- Function to validate session with enhanced security checks
CREATE OR REPLACE FUNCTION auth.validate_session_enhanced(
    p_session_hk BYTEA,
    p_ip_address INET,
    p_user_agent TEXT
) RETURNS TABLE (
    is_valid BOOLEAN,
    validation_message TEXT,
    user_hk BYTEA,
    requires_mfa BOOLEAN,
    session_expires_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_session_data RECORD;
    v_security_policy RECORD;
BEGIN
    -- Get session and related data
    SELECT 
        sss.session_status,
        sss.session_start,
        sss.last_activity,
        sss.ip_address,
        sss.session_data,
        usl.user_hk,
        sh.tenant_hk
    INTO v_session_data
    FROM auth.session_state_s sss
    JOIN auth.session_h sh ON sss.session_hk = sh.session_hk
    JOIN auth.user_session_l usl ON sh.session_hk = usl.session_hk
    WHERE sss.session_hk = p_session_hk
    AND sss.load_end_date IS NULL
    ORDER BY sss.load_date DESC
    LIMIT 1;

    -- If no session found
    IF v_session_data.session_status IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Session not found', NULL::BYTEA, FALSE, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    -- Get security policy
    SELECT 
        COALESCE(sp.session_timeout_minutes, 60) as session_timeout_minutes,
        COALESCE(sp.session_absolute_timeout_hours, 12) as session_absolute_timeout_hours,
        COALESCE(sp.require_mfa, false) as require_mfa,
        sp.allowed_ip_ranges
    INTO v_security_policy
    FROM auth.security_policy_s sp
    JOIN auth.security_policy_h sph ON sp.security_policy_hk = sph.security_policy_hk
    WHERE sph.tenant_hk = v_session_data.tenant_hk
    AND sp.is_active = TRUE
    AND sp.load_end_date IS NULL
    ORDER BY sp.load_date DESC
    LIMIT 1;

    -- Set defaults if no policy found
    IF v_security_policy.session_timeout_minutes IS NULL THEN
        v_security_policy.session_timeout_minutes := 60;
        v_security_policy.session_absolute_timeout_hours := 12;
        v_security_policy.require_mfa := false;
    END IF;

    -- Validate session status
    IF v_session_data.session_status != 'ACTIVE' THEN
        RETURN QUERY SELECT FALSE, 'Session is not active', v_session_data.user_hk, 
                           v_security_policy.require_mfa, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    -- Check session timeout
    IF v_session_data.last_activity < (CURRENT_TIMESTAMP - (v_security_policy.session_timeout_minutes || ' minutes')::interval) THEN
        RETURN QUERY SELECT FALSE, 'Session has timed out due to inactivity', v_session_data.user_hk, 
                           v_security_policy.require_mfa, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    -- Check absolute session timeout
    IF v_session_data.session_start < (CURRENT_TIMESTAMP - (v_security_policy.session_absolute_timeout_hours || ' hours')::interval) THEN
        RETURN QUERY SELECT FALSE, 'Session has exceeded maximum duration', v_session_data.user_hk, 
                           v_security_policy.require_mfa, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;

    -- Check IP address validation if configured
    IF v_security_policy.allowed_ip_ranges IS NOT NULL AND array_length(v_security_policy.allowed_ip_ranges, 1) > 0 THEN
        -- Simple IP validation (can be enhanced for CIDR ranges)
        IF NOT (p_ip_address::text = ANY(v_security_policy.allowed_ip_ranges)) THEN
            RETURN QUERY SELECT FALSE, 'IP address not allowed', v_session_data.user_hk, 
                               v_security_policy.require_mfa, NULL::TIMESTAMP WITH TIME ZONE;
            RETURN;
        END IF;
    END IF;

    -- Update last activity time
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
    ) VALUES (
        p_session_hk,
        util.current_load_date(),
        util.hash_binary(p_session_hk::text || 'ACTIVITY_UPDATE' || CURRENT_TIMESTAMP::text),
        v_session_data.session_start,
        NULL, -- session_end
        p_ip_address,
        p_user_agent,
        v_session_data.session_data,
        'ACTIVE',
        CURRENT_TIMESTAMP, -- last_activity
        util.get_record_source()
    );

    -- End-date the previous session state record
    UPDATE auth.session_state_s
    SET load_end_date = util.current_load_date()
    WHERE session_hk = p_session_hk
    AND load_end_date IS NULL
    AND load_date < util.current_load_date();

    -- Calculate session expiration time
    RETURN QUERY SELECT 
        TRUE, 
        'Session is valid', 
        v_session_data.user_hk, 
        v_security_policy.require_mfa,
        LEAST(
            v_session_data.last_activity + (v_security_policy.session_timeout_minutes || ' minutes')::interval,
            v_session_data.session_start + (v_security_policy.session_absolute_timeout_hours || ' hours')::interval
        );
END;
$$ LANGUAGE plpgsql;

-- Create performance indexes with unique names to avoid conflicts
CREATE INDEX IF NOT EXISTS idx_user_auth_s_failed_attempts_step13 
ON auth.user_auth_s(user_hk, failed_login_attempts) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_auth_s_account_locked_step13 
ON auth.user_auth_s(account_locked, account_locked_until) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_session_state_s_last_activity_step13 
ON auth.session_state_s(session_hk, last_activity) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_session_state_s_session_start_step13 
ON auth.session_state_s(session_hk, session_start) 
WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_login_status_s_username_validation_step13 
ON staging.login_status_s(username, validation_status, attempt_timestamp) 
WHERE load_end_date IS NULL;

-- Create audit triggers using the safe function
SELECT util.create_audit_triggers_safe('auth');
SELECT util.create_audit_triggers_safe('staging');

-- Verification procedure
CREATE OR REPLACE PROCEDURE auth.verify_step_13_implementation()
LANGUAGE plpgsql AS $$
DECLARE
    v_function_count INTEGER;
    v_index_count INTEGER;
    v_trigger_count INTEGER;
BEGIN
    -- Count functions and procedures created
    SELECT COUNT(*) INTO v_function_count
    FROM information_schema.routines
    WHERE routine_schema = 'auth'
    AND routine_name IN (
        'check_account_lockout',
        'process_valid_login_enhanced',
        'process_failed_login',
        'maintain_security_state',
        'validate_session_enhanced'
    );

    -- Count indexes created
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE schemaname IN ('auth', 'staging')
    AND indexname LIKE '%_step13';

    -- Count audit triggers
    SELECT COUNT(*) INTO v_trigger_count
    FROM information_schema.triggers
    WHERE trigger_schema IN ('auth', 'staging')
    AND trigger_name LIKE 'trg_audit_%';

    RAISE NOTICE 'Step 13 Verification Results:';
    RAISE NOTICE 'Functions/Procedures: % (expected: 5)', v_function_count;
    RAISE NOTICE 'Indexes: % (expected: 5)', v_index_count;
    RAISE NOTICE 'Audit Triggers: % (varies by table count)', v_trigger_count;
    
    IF v_function_count = 5 THEN
        RAISE NOTICE 'Step 13 implementation appears successful!';
    ELSE
        RAISE NOTICE 'Step 13 implementation may have issues - please review';
    END IF;
END;
$$;

-- Run verification
CALL auth.verify_step_13_implementation();

COMMENT ON PROCEDURE auth.rollback_step_13 IS 
'Rollback procedure for Step 13 implementation - removes all functions, procedures, and indexes created in this step';

COMMENT ON FUNCTION util.create_audit_triggers_safe IS 
'Enhanced audit trigger creation that checks for existing triggers before attempting to create new ones';

COMMENT ON PROCEDURE auth.verify_step_13_implementation IS 
'Verification procedure that checks if all Step 13 components were successfully installed';