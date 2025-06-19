    -- =============================================
    -- API Token Management Tables (Missing from previous scripts with corrected table names)
    -- =============================================

    -- Hub table for API tokens
    CREATE TABLE auth.api_token_h (
        token_hk BYTEA PRIMARY KEY,
        token_bk VARCHAR(255) NOT NULL,
        tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
        load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
        record_source VARCHAR(100) NOT NULL
    );

    -- Satellite table for API token details
    CREATE TABLE auth.api_token_s (
        token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(token_hk),
        load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
        load_end_date TIMESTAMP WITH TIME ZONE,
        hash_diff BYTEA NOT NULL,
        token_hash BYTEA NOT NULL,
        token_type VARCHAR(20) NOT NULL,
        expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
        is_revoked BOOLEAN NOT NULL DEFAULT false,
        revocation_reason TEXT,
        scope TEXT[] NOT NULL,
        last_used_at TIMESTAMP WITH TIME ZONE,
        record_source VARCHAR(100) NOT NULL,
        PRIMARY KEY (token_hk, load_date)
    );

    -- Link table for user-token relationships
    CREATE TABLE auth.user_token_l (
        link_user_token_hk BYTEA PRIMARY KEY,
        user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
        token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(token_hk),
        tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
        load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
        record_source VARCHAR(100) NOT NULL
    );

    -- Link table for session-token relationships
    CREATE TABLE auth.session_token_l (
        link_session_token_hk BYTEA PRIMARY KEY,
        session_hk BYTEA NOT NULL REFERENCES auth.session_h(session_hk),
        token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(token_hk),
        tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
        load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
        record_source VARCHAR(100) NOT NULL
    );

    -- =============================================
    -- Missing Utility Function
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
    -- Updated Business Process Procedures
    -- =============================================

    CREATE OR REPLACE PROCEDURE auth.process_valid_login(
        IN p_login_attempt_hk BYTEA,
        OUT p_session_hk BYTEA,
        OUT p_user_hk BYTEA
    )
    LANGUAGE plpgsql
    AS $$
    DECLARE
        v_tenant_hk BYTEA;
        v_user_hk BYTEA;
        v_session_bk VARCHAR(255);
        v_session_hk BYTEA;
        v_username VARCHAR(255);
        v_ip_address INET;
        v_user_agent TEXT;
        v_session_timeout INTEGER;
        v_validation_status VARCHAR(20);
        v_api_token TEXT;  
    BEGIN
        -- Log the input
        RAISE NOTICE 'process_valid_login starting with login_attempt_hk: %', encode(p_login_attempt_hk, 'hex');
        
        -- Get validation status with corrected table name
        SELECT 
            sls.validation_status INTO v_validation_status
        FROM staging.login_status_s sls
        WHERE sls.login_attempt_hk = p_login_attempt_hk
        AND sls.load_end_date IS NULL
        ORDER BY sls.load_date DESC
        LIMIT 1;
        
        RAISE NOTICE 'Validation status: %', COALESCE(v_validation_status, 'NULL');
        
        -- Only proceed if the login is valid
        IF v_validation_status = 'VALID' THEN
            -- Log before detailed query
            RAISE NOTICE 'Attempting to get user details';
            
            -- Get the user details using corrected table names
            SELECT 
                hla.tenant_hk,
                hu.user_hk,
                sls.username,
                sls.ip_address,
                sls.user_agent,
                COALESCE(sp.session_timeout_minutes, 60) -- Default to 60 minutes if NULL
            INTO 
                v_tenant_hk,
                v_user_hk,
                v_username,
                v_ip_address,
                v_user_agent,
                v_session_timeout
            FROM staging.login_attempt_h hla
            JOIN staging.login_status_s sls ON hla.login_attempt_hk = sls.login_attempt_hk
            JOIN auth.user_auth_s sua ON sls.username = sua.username
            JOIN auth.user_h hu ON sua.user_hk = hu.user_hk
            LEFT JOIN auth.security_policy_h hsp ON hsp.tenant_hk = hla.tenant_hk
            LEFT JOIN auth.security_policy_s sp ON sp.security_policy_hk = hsp.security_policy_hk 
            WHERE hla.login_attempt_hk = p_login_attempt_hk
            AND sls.validation_status = 'VALID'
            AND sls.load_end_date IS NULL
            AND sua.load_end_date IS NULL
            AND (sp.load_end_date IS NULL OR sp.load_end_date IS NULL)
            ORDER BY sls.load_date DESC, sua.load_date DESC, sp.load_date DESC
            LIMIT 1;

            RAISE NOTICE 'User details query results - tenant_hk: %, user_hk: %, username: %', 
                CASE WHEN v_tenant_hk IS NULL THEN 'NULL' ELSE encode(v_tenant_hk, 'hex') END,
                CASE WHEN v_user_hk IS NULL THEN 'NULL' ELSE encode(v_user_hk, 'hex') END,
                v_username;
                
            -- Check if we got user details
            IF v_user_hk IS NULL THEN
                RAISE NOTICE 'Failed to retrieve user details - query returned no results';
                RETURN;
            END IF;

            -- Generate session identifiers using Data Vault 2.0 standards
            v_session_bk := util.generate_bk(COALESCE(v_tenant_hk::text, 'UNKNOWN') || '::' || COALESCE(v_user_hk::text, 'UNKNOWN') || '::' || CURRENT_TIMESTAMP::text);
            v_session_hk := util.hash_binary(v_session_bk);
            
            RAISE NOTICE 'Generated session business key: %', v_session_bk;
            RAISE NOTICE 'Generated session hash key: %', encode(v_session_hk, 'hex');

            -- Create new session hub record with corrected table name
            BEGIN
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
                RAISE NOTICE 'Created session hub record';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Error creating session hub record: % %', SQLSTATE, SQLERRM;
            END;

            -- Create session state satellite record with corrected table name
            BEGIN
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
                ) VALUES (
                    v_session_hk,
                    util.current_load_date(),
                    util.hash_binary(v_session_bk || 'ACTIVE' || COALESCE(v_ip_address::text, 'UNKNOWN') || COALESCE(v_user_agent, 'UNKNOWN')),
                    CURRENT_TIMESTAMP,
                    v_ip_address,
                    v_user_agent,
                    'ACTIVE',
                    CURRENT_TIMESTAMP,
                    util.get_record_source()
                );
                RAISE NOTICE 'Created session state satellite record';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Error creating session state record: % %', SQLSTATE, SQLERRM;
            END;

            -- Create user-session link record with corrected table name
            BEGIN
                INSERT INTO auth.user_session_l (
                    link_user_session_hk,
                    user_hk,
                    session_hk,
                    tenant_hk,
                    load_date,
                    record_source
                ) VALUES (
                    util.hash_binary(v_user_hk::text || '::' || v_session_hk::text),
                    v_user_hk,
                    v_session_hk,
                    v_tenant_hk,
                    util.current_load_date(),
                    util.get_record_source()
                );
                RAISE NOTICE 'Created user-session link record';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Error creating user-session link: % %', SQLSTATE, SQLERRM;
            END;

            -- Update user's last login in auth satellite with corrected table and field names
            BEGIN
                INSERT INTO auth.user_auth_s (
                    user_hk,
                    load_date,
                    hash_diff,
                    username,
                    password_hash,
                    password_salt,
                    last_login_date,
                    failed_login_attempts,
                    account_locked,
                    record_source
                )
                SELECT 
                    user_hk,
                    util.current_load_date(),
                    util.hash_binary(username || COALESCE(password_hash::text, '') || 'ACTIVE' || CURRENT_TIMESTAMP::text),
                    username,
                    password_hash,
                    password_salt,
                    CURRENT_TIMESTAMP,
                    0, -- Reset failed attempts on successful login
                    false, -- Unlock account on successful login
                    util.get_record_source()
                FROM auth.user_auth_s
                WHERE user_hk = v_user_hk
                AND load_end_date IS NULL
                ORDER BY load_date DESC
                LIMIT 1;
                RAISE NOTICE 'Updated user last login';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Error updating user last login: % %', SQLSTATE, SQLERRM;
            END;

            -- Generate API token for the session
            v_api_token := NULL;  -- Initialize token value
            CALL auth.generate_token_for_session(v_session_hk, v_api_token);

            -- Update session record to store the API token reference
            UPDATE auth.session_h
            SET session_bk = v_api_token  -- Replace complex session_bk with API token
            WHERE session_hk = v_session_hk;
            
            -- Set the output parameters
            p_session_hk := v_session_hk;
            p_user_hk := v_user_hk;
            
            RAISE NOTICE 'Successfully created session - session_hk: %, user_hk: %', 
                encode(p_session_hk, 'hex'), encode(p_user_hk, 'hex');
        ELSE
            RAISE NOTICE 'Login validation status not VALID, stopping session creation';
            p_session_hk := NULL;
            p_user_hk := NULL;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error in process_valid_login: %', SQLERRM;
        p_session_hk := NULL;
        p_user_hk := NULL;
    END;
    $$;

        CREATE OR REPLACE PROCEDURE auth.generate_token_for_session(
            p_session_hk BYTEA,
            INOUT p_token_value TEXT DEFAULT NULL
        )
        LANGUAGE plpgsql
        AS $$
        DECLARE
            v_user_hk BYTEA;
            v_tenant_hk BYTEA;
            v_api_token_hk BYTEA;  -- FIX: Use api_token_hk consistently
            v_link_hk BYTEA;
            v_security_policy auth.security_policy_s%ROWTYPE;
            v_token_hash BYTEA;
            v_expires_at TIMESTAMP WITH TIME ZONE;
            v_timeout_minutes NUMERIC;
            c_MAX_HIPAA_TIMEOUT CONSTANT NUMERIC := 20;
            c_MIN_HIPAA_TIMEOUT CONSTANT NUMERIC := 10;
        BEGIN
            -- Get user_hk from session
            SELECT lus.user_hk INTO v_user_hk
            FROM auth.user_session_l lus
            WHERE lus.session_hk = p_session_hk;
            
            IF v_user_hk IS NULL THEN
                RAISE EXCEPTION 'No user found for session';
            END IF;
            
            -- Get tenant_hk from user with corrected table name
            SELECT hu.tenant_hk INTO v_tenant_hk
            FROM auth.user_h hu
            WHERE hu.user_hk = v_user_hk;
            
            IF v_tenant_hk IS NULL THEN
                RAISE EXCEPTION 'No tenant found for user';
            END IF;
            
            -- Get security policy for tenant with corrected table names
            SELECT sp.* INTO v_security_policy
            FROM auth.security_policy_s sp
            JOIN auth.security_policy_h hp ON sp.security_policy_hk = hp.security_policy_hk
            WHERE hp.tenant_hk = v_tenant_hk
            AND sp.load_end_date IS NULL
            ORDER BY sp.load_date DESC
            LIMIT 1;
            
            -- HIPAA-Compliant Timeout Calculation
            v_timeout_minutes := COALESCE(
                v_security_policy.session_timeout_minutes, 
                c_MAX_HIPAA_TIMEOUT
            );
            
            -- Enforce minimum and maximum timeout
            v_timeout_minutes := LEAST(
                GREATEST(v_timeout_minutes, c_MIN_HIPAA_TIMEOUT), 
                c_MAX_HIPAA_TIMEOUT
            );
            
            -- Calculate expires_at
            v_expires_at := CURRENT_TIMESTAMP + (v_timeout_minutes * INTERVAL '1 minute');
            
            -- Generate token and its hash
            v_token_hk := util.hash_binary(gen_random_uuid()::text);
            v_token_hash := util.hash_binary(v_token_hk::text);
            
            -- First, insert into api_token_h with corrected table name
            INSERT INTO auth.api_token_h (
                token_hk,
                token_bk,
                tenant_hk,
                load_date,
                record_source
            ) VALUES (
                v_token_hk,
                encode(v_token_hk, 'hex'),
                v_tenant_hk,
                util.current_load_date(),
                util.get_record_source()
            ) ON CONFLICT DO NOTHING;
            
            -- Then, insert into api_token_s with corrected table name
            INSERT INTO auth.api_token_s (
                token_hk,
                load_date,
                hash_diff,
                token_hash,
                token_type,
                expires_at,
                is_revoked,
                scope,
                record_source
            ) VALUES (
                v_token_hk,
                util.current_load_date(),
                util.hash_binary(v_token_hk::text),
                v_token_hash,
                'SESSION',
                v_expires_at,
                false,
                ARRAY['api:access'],
                util.get_record_source()
            );
            
            -- Set output token value (this will be the token_hk)
            p_token_value := encode(v_token_hk, 'hex');
            
            -- Create session-token link with corrected table name
            v_link_hk := util.hash_binary(p_session_hk::text || v_token_hk::text);
            
            INSERT INTO auth.session_token_l (
                link_session_token_hk,
                session_hk,
                token_hk,
                tenant_hk,
                load_date,
                record_source
            ) VALUES (
                v_link_hk,
                p_session_hk,
                v_token_hk,
                v_tenant_hk,
                util.current_load_date(),
                util.get_record_source()
            ) ON CONFLICT DO NOTHING;

            -- Link token to user with corrected table name
            INSERT INTO auth.user_token_l (
                link_user_token_hk,
                user_hk,
                token_hk,
                tenant_hk,
                load_date,
                record_source
            ) VALUES (
                util.hash_binary(v_user_hk::text || v_token_hk::text),
                v_user_hk,
                v_token_hk,
                v_tenant_hk,
                util.current_load_date(),
                util.get_record_source()
            ) ON CONFLICT DO NOTHING;
            
        END;
        $$;

    CREATE OR REPLACE FUNCTION auth.get_user_salt(
        p_email VARCHAR(255),
        p_tenant_hk BYTEA
    ) RETURNS BYTEA AS $$
    DECLARE
        v_salt BYTEA;
    BEGIN
        -- Updated with corrected table names and field name
        SELECT password_salt INTO v_salt
        FROM auth.user_auth_s sua
        JOIN auth.user_h hu ON sua.user_hk = hu.user_hk
        WHERE sua.username = p_email  -- Assuming username is email
        AND hu.tenant_hk = p_tenant_hk
        AND sua.load_end_date IS NULL
        ORDER BY sua.load_date DESC
        LIMIT 1;
        
        RETURN v_salt;
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    -- =============================================
    -- Performance Indexes for New Tables
    -- =============================================

    -- API Token indexes
    CREATE INDEX idx_api_token_h_tenant_hk ON auth.api_token_h(tenant_hk);
    CREATE INDEX idx_api_token_s_expires_at ON auth.api_token_s(expires_at) 
    WHERE load_end_date IS NULL;
    CREATE INDEX idx_api_token_s_is_revoked ON auth.api_token_s(is_revoked) 
    WHERE load_end_date IS NULL;

    -- Link table indexes
    CREATE INDEX idx_user_token_l_user_hk ON auth.user_token_l(user_hk);
    CREATE INDEX idx_user_token_l_token_hk ON auth.user_token_l(token_hk);
    CREATE INDEX idx_session_token_l_session_hk ON auth.session_token_l(session_hk);
    CREATE INDEX idx_session_token_l_token_hk ON auth.session_token_l(token_hk);

    -- Additional performance indexes
    CREATE INDEX idx_user_auth_s_username ON auth.user_auth_s(username) 
    WHERE load_end_date IS NULL;
    CREATE INDEX idx_user_auth_s_last_login ON auth.user_auth_s(last_login_date) 
    WHERE load_end_date IS NULL;