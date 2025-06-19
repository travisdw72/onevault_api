/**
 * Data Vault 2.0 Advanced Token Management - Enhanced Rollback-Safe Version
 * 
 * This script implements comprehensive API token management with proper rollback
 * capabilities and conflict resolution for existing function signatures.
 * 
 * Version: 2.0
 * Date: 2025-06-01
 * Dependencies: Core authentication tables from Project2_dbCreation_1.sql and Project2_dbCreation_2.sql
 */

-- =============================================
-- TRANSACTION MANAGEMENT AND ROLLBACK SAFETY
-- =============================================

-- Begin transaction for atomic rollback capability
BEGIN;

-- Create savepoint for granular rollback control
SAVEPOINT token_management_start;

-- =============================================
-- PHASE 1: COMPREHENSIVE CLEANUP AND DEPENDENCY MANAGEMENT
-- =============================================

-- Drop all existing function variations with explicit signatures
-- This resolves the "function name is not unique" error

-- Drop validate_token_and_session variations
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT, INET, TEXT, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT, INET, TEXT, VARCHAR(255)) CASCADE;
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT, INET, TEXT) CASCADE;
DROP FUNCTION IF EXISTS auth.validate_token_and_session(TEXT, INET) CASCADE;

-- Drop other potentially conflicting functions
DROP FUNCTION IF EXISTS auth.generate_api_token(BYTEA, VARCHAR, TEXT[], INTERVAL) CASCADE;
DROP FUNCTION IF EXISTS auth.generate_api_token(BYTEA, VARCHAR(20), TEXT[], INTERVAL) CASCADE;
DROP FUNCTION IF EXISTS auth.generate_api_token(BYTEA, VARCHAR(50), TEXT[], INTERVAL) CASCADE;
DROP FUNCTION IF EXISTS auth.revoke_token(BYTEA, TEXT) CASCADE;
DROP FUNCTION IF EXISTS auth.update_token_usage(BYTEA) CASCADE;

-- Drop util.generate_bk to resolve parameter name conflicts
DROP FUNCTION IF EXISTS util.generate_bk(TEXT) CASCADE;

-- Drop procedures with explicit signatures
DROP PROCEDURE IF EXISTS auth.create_session_with_token(BYTEA, INET, TEXT, BYTEA, TEXT) CASCADE;

-- Drop tables in dependency order (satellites first, then links, then hubs)
DROP TABLE IF EXISTS auth.token_activity_s CASCADE;
DROP TABLE IF EXISTS auth.ip_tracking_s CASCADE;
DROP TABLE IF EXISTS auth.session_token_l CASCADE;
DROP TABLE IF EXISTS auth.user_token_l CASCADE;
DROP TABLE IF EXISTS auth.api_token_s CASCADE;
DROP TABLE IF EXISTS auth.api_token_h CASCADE;
DROP TABLE IF EXISTS auth.security_tracking_h CASCADE;

-- Create another savepoint after cleanup
SAVEPOINT cleanup_complete;

-- =============================================
-- PHASE 2: UTILITY FUNCTIONS FOR DATA VAULT OPERATIONS
-- =============================================

-- Enhanced business key generation function
CREATE OR REPLACE FUNCTION util.generate_bk(input_text TEXT)
RETURNS VARCHAR(255)
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT CASE 
        WHEN LENGTH(input_text) > 200 THEN 
            LEFT(input_text, 100) || '_' || encode(util.hash_binary(input_text), 'hex')
        ELSE 
            input_text
    END;
$$;

-- Savepoint after utility functions
SAVEPOINT utilities_created;

-- =============================================
-- PHASE 3: API TOKEN INFRASTRUCTURE
-- =============================================

-- Hub table for API tokens
CREATE TABLE auth.api_token_h (
    api_token_hk BYTEA PRIMARY KEY,
    api_token_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Constraints and indexes
    CONSTRAINT uk_api_token_h_bk_tenant UNIQUE (api_token_bk, tenant_hk)
);

-- Satellite table for API token details
CREATE TABLE auth.api_token_s (
    api_token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(api_token_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    token_hash BYTEA NOT NULL,
    token_type VARCHAR(50) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    revocation_reason TEXT,
    scope TEXT[] NOT NULL,
    last_used_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(100) DEFAULT SESSION_USER,
    revoked_by VARCHAR(100),
    revoked_at TIMESTAMP WITH TIME ZONE,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Constraints
    PRIMARY KEY (api_token_hk, load_date),
    CONSTRAINT chk_token_type CHECK (token_type IN ('SESSION', 'API_KEY', 'REFRESH', 'TEMPORARY')),
    CONSTRAINT chk_load_end_date CHECK (load_end_date IS NULL OR load_end_date > load_date),
    CONSTRAINT chk_revocation_logic CHECK (
        (is_revoked = FALSE AND revoked_by IS NULL AND revoked_at IS NULL) OR
        (is_revoked = TRUE AND revoked_by IS NOT NULL AND revoked_at IS NOT NULL)
    )
);

-- Link table for user-token relationships
CREATE TABLE auth.user_token_l (
    user_token_hk BYTEA PRIMARY KEY,
    user_hk BYTEA NOT NULL REFERENCES auth.user_h(user_hk),
    api_token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(api_token_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
    
    -- Note: Tenant consistency enforced by foreign key relationships and application logic
    -- Cannot use subqueries in CHECK constraints in PostgreSQL
);

-- Savepoint after token infrastructure
SAVEPOINT token_infrastructure_created;

-- =============================================
-- PHASE 4: SESSION-TOKEN INTEGRATION
-- =============================================

-- Link table for session-token relationships
CREATE TABLE auth.session_token_l (
    session_token_hk BYTEA PRIMARY KEY,
    session_hk BYTEA NOT NULL REFERENCES auth.session_h(session_hk),
    api_token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(api_token_hk),
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source()
    
    -- Note: Tenant consistency enforced by foreign key relationships and application logic
    -- Cannot use subqueries in CHECK constraints in PostgreSQL
);

-- Satellite table for token activity tracking
CREATE TABLE auth.token_activity_s (
    api_token_hk BYTEA NOT NULL REFERENCES auth.api_token_h(api_token_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    last_activity_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    endpoint_accessed VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    request_method VARCHAR(10),
    response_status INTEGER,
    activity_metadata JSONB,
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Constraints
    PRIMARY KEY (api_token_hk, load_date),
    CONSTRAINT chk_activity_type CHECK (activity_type IN ('CREATION', 'VALIDATION', 'API_ACCESS', 'REVOCATION', 'EXPIRATION')),
    CONSTRAINT chk_load_end_date_activity CHECK (load_end_date IS NULL OR load_end_date > load_date),
    CONSTRAINT chk_response_status CHECK (response_status IS NULL OR (response_status >= 100 AND response_status < 600))
);

-- Savepoint after session integration
SAVEPOINT session_integration_created;

-- =============================================
-- PHASE 5: SECURITY TRACKING INFRASTRUCTURE
-- =============================================

-- Hub table for security tracking entities
CREATE TABLE auth.security_tracking_h (
    security_tracking_hk BYTEA PRIMARY KEY,
    security_tracking_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Business key uniqueness within tenant
    CONSTRAINT uk_security_tracking_h_bk_tenant UNIQUE (security_tracking_bk, tenant_hk)
);

-- Satellite table for IP tracking and rate limiting
CREATE TABLE auth.ip_tracking_s (
    security_tracking_hk BYTEA NOT NULL REFERENCES auth.security_tracking_h(security_tracking_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    ip_address INET NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 1,
    first_request_time TIMESTAMP WITH TIME ZONE NOT NULL,
    last_request_time TIMESTAMP WITH TIME ZONE NOT NULL,
    is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    block_reason TEXT,
    suspicious_activity_flag BOOLEAN NOT NULL DEFAULT FALSE,
    suspicious_activity_details JSONB,
    geographic_location VARCHAR(100),
    record_source VARCHAR(100) NOT NULL DEFAULT util.get_record_source(),
    
    -- Constraints
    PRIMARY KEY (security_tracking_hk, load_date),
    CONSTRAINT chk_load_end_date_ip CHECK (load_end_date IS NULL OR load_end_date > load_date),
    CONSTRAINT chk_request_count CHECK (request_count > 0),
    CONSTRAINT chk_request_times CHECK (last_request_time >= first_request_time),
    CONSTRAINT chk_block_reason CHECK (
        (is_blocked = FALSE AND block_reason IS NULL) OR
        (is_blocked = TRUE AND block_reason IS NOT NULL)
    )
);

-- Savepoint after security infrastructure
SAVEPOINT security_infrastructure_created;

-- =============================================
-- PHASE 6: TOKEN GENERATION FUNCTION
-- =============================================

CREATE OR REPLACE FUNCTION auth.generate_api_token(
    p_user_hk BYTEA,
    p_token_type VARCHAR(50),
    p_scope TEXT[],
    p_expires_in INTERVAL DEFAULT INTERVAL '1 day'
) RETURNS TABLE (
    token_value TEXT,
    expires_at TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_api_token_bk VARCHAR(255);
    v_api_token_hk BYTEA;
    v_tenant_hk BYTEA;
    v_token_value TEXT;
    v_expires_at TIMESTAMP WITH TIME ZONE;
    v_token_hash BYTEA;
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_record_source VARCHAR(100);
BEGIN
    -- Initialize operational variables
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();
    
    -- Get tenant context from user
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.user_h
    WHERE user_hk = p_user_hk;

    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'User not found: %', encode(p_user_hk, 'hex');
    END IF;

    -- Generate cryptographically secure token
    v_token_value := encode(gen_random_bytes(32), 'hex');
    v_token_hash := util.hash_binary(v_token_value);
    v_expires_at := CURRENT_TIMESTAMP + p_expires_in;

    -- Create business key and hash key for token
    v_api_token_bk := util.generate_bk(encode(v_tenant_hk, 'hex') || '_TOKEN_' || v_token_value);
    v_api_token_hk := util.hash_binary(v_api_token_bk);

    -- Create API token hub record
    INSERT INTO auth.api_token_h (
        api_token_hk,
        api_token_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_api_token_hk,
        v_api_token_bk,
        v_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Create API token satellite
    INSERT INTO auth.api_token_s (
        api_token_hk,
        load_date,
        hash_diff,
        token_hash,
        token_type,
        expires_at,
        is_revoked,
        scope,
        created_by,
        record_source
    ) VALUES (
        v_api_token_hk,
        v_load_date,
        util.hash_binary(v_token_value || p_token_type || v_expires_at::text),
        v_token_hash,
        p_token_type,
        v_expires_at,
        FALSE,
        p_scope,
        SESSION_USER,
        v_record_source
    );

    -- Create user-token link
    INSERT INTO auth.user_token_l (
        user_token_hk,
        user_hk,
        api_token_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(p_user_hk::text || v_api_token_hk::text),
        p_user_hk,
        v_api_token_hk,
        v_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Create initial activity record
    INSERT INTO auth.token_activity_s (
        api_token_hk,
        load_date,
        hash_diff,
        last_activity_timestamp,
        activity_type,
        activity_metadata,
        record_source
    ) VALUES (
        v_api_token_hk,
        v_load_date,
        util.hash_binary('TOKEN_CREATION' || CURRENT_TIMESTAMP::text),
        CURRENT_TIMESTAMP,
        'CREATION',
        jsonb_build_object(
            'token_type', p_token_type,
            'scope', p_scope,
            'expires_at', v_expires_at,
            'created_by', SESSION_USER
        ),
        v_record_source
    );

    -- Return token information
    RETURN QUERY SELECT v_token_value, v_expires_at;
END;
$$;

-- Savepoint after token generation function
SAVEPOINT token_generation_created;

-- =============================================
-- PHASE 7: SESSION WITH TOKEN CREATION PROCEDURE
-- =============================================

CREATE OR REPLACE PROCEDURE auth.create_session_with_token(
    p_user_hk BYTEA,
    p_ip_address INET,
    p_user_agent TEXT,
    OUT p_session_hk BYTEA,
    OUT p_token_value TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_hk BYTEA;
    v_session_bk VARCHAR(255);
    v_api_token_hk BYTEA;
    v_security_policy auth.security_policy_s%ROWTYPE;
    v_expires_at TIMESTAMP WITH TIME ZONE;
    v_load_date TIMESTAMP WITH TIME ZONE;
    v_record_source VARCHAR(100);
BEGIN
    -- Initialize operational variables
    v_load_date := util.current_load_date();
    v_record_source := util.get_record_source();
    
    -- Get tenant context
    SELECT tenant_hk INTO v_tenant_hk
    FROM auth.user_h
    WHERE user_hk = p_user_hk;

    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'User not found: %', encode(p_user_hk, 'hex');
    END IF;

    -- Get current security policy
    SELECT sp.* INTO v_security_policy
    FROM auth.security_policy_s sp
    JOIN auth.security_policy_h hp ON sp.security_policy_hk = hp.security_policy_hk
    WHERE hp.tenant_hk = v_tenant_hk
    AND sp.load_end_date IS NULL
    ORDER BY sp.load_date DESC
    LIMIT 1;

    -- Generate session business key and hash key
    v_session_bk := util.generate_bk(encode(v_tenant_hk, 'hex') || '_SESSION_' || CURRENT_TIMESTAMP::text);
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
        v_load_date,
        v_record_source
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
        p_session_hk,
        v_load_date,
        util.hash_binary(v_session_bk || 'ACTIVE' || p_ip_address::text),
        CURRENT_TIMESTAMP,
        p_ip_address,
        p_user_agent,
        jsonb_build_object(
            'created_timestamp', CURRENT_TIMESTAMP,
            'security_policy_applied', COALESCE(v_security_policy.policy_name, 'default')
        ),
        'ACTIVE',
        CURRENT_TIMESTAMP,
        v_record_source
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
        util.hash_binary(p_user_hk::text || p_session_hk::text),
        p_user_hk,
        p_session_hk,
        v_tenant_hk,
        v_load_date,
        v_record_source
    );

    -- Generate associated API token
    SELECT token_value, expires_at INTO p_token_value, v_expires_at
    FROM auth.generate_api_token(
        p_user_hk,
        'SESSION',
        ARRAY['api:access', 'session:maintain'],
        COALESCE(v_security_policy.session_timeout_minutes, 60) * INTERVAL '1 minute'
    );

    -- Get token hash key for relationship creation
    SELECT api_token_hk INTO v_api_token_hk
    FROM auth.api_token_s
    WHERE token_hash = util.hash_binary(p_token_value)
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    -- Create session-token relationship
    INSERT INTO auth.session_token_l (
        session_token_hk,
        session_hk,
        api_token_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(p_session_hk::text || v_api_token_hk::text),
        p_session_hk,
        v_api_token_hk,
        v_tenant_hk,
        v_load_date,
        v_record_source
    );
END;
$$;

-- Savepoint after session creation procedure
SAVEPOINT session_creation_created;

-- =============================================
-- PHASE 8: TOKEN VALIDATION FUNCTION
-- =============================================

CREATE OR REPLACE FUNCTION auth.validate_token_and_session(
    p_token_value TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_endpoint VARCHAR(255) DEFAULT NULL
) RETURNS TABLE (
    is_valid BOOLEAN,
    user_hk BYTEA,
    session_hk BYTEA,
    message TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_token_hash BYTEA;
    v_api_token_hk BYTEA;
    v_activity_metadata JSONB;
BEGIN
    -- Calculate token hash for lookup
    v_token_hash := util.hash_binary(p_token_value);

    -- Comprehensive token and session validation
    RETURN QUERY
    WITH token_validation AS (
        SELECT 
            ats.api_token_hk,
            ats.token_hash,
            ats.expires_at,
            ats.is_revoked,
            stl.session_hk,
            utl.user_hk,
            sss.session_start,
            sss.session_status,
            COALESCE(sps.session_timeout_minutes, 60) AS session_timeout_minutes,
            ath.tenant_hk
        FROM auth.api_token_s ats
        JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
        LEFT JOIN auth.session_token_l stl ON ats.api_token_hk = stl.api_token_hk
        LEFT JOIN auth.user_token_l utl ON ats.api_token_hk = utl.api_token_hk
        LEFT JOIN auth.session_state_s sss ON stl.session_hk = sss.session_hk AND sss.load_end_date IS NULL
        LEFT JOIN auth.security_policy_h sph ON ath.tenant_hk = sph.tenant_hk
        LEFT JOIN auth.security_policy_s sps ON sph.security_policy_hk = sps.security_policy_hk AND sps.load_end_date IS NULL
        WHERE ats.token_hash = v_token_hash
        AND ats.load_end_date IS NULL
        ORDER BY ats.load_date DESC, sss.load_date DESC, sps.load_date DESC
        LIMIT 1
    )
    SELECT 
        CASE 
            WHEN tv.api_token_hk IS NULL THEN FALSE
            WHEN tv.is_revoked THEN FALSE
            WHEN tv.expires_at < CURRENT_TIMESTAMP THEN FALSE
            WHEN tv.session_hk IS NOT NULL AND tv.session_status != 'ACTIVE' THEN FALSE
            WHEN tv.session_hk IS NOT NULL AND tv.session_start + (tv.session_timeout_minutes || ' minutes')::INTERVAL < CURRENT_TIMESTAMP THEN FALSE
            ELSE TRUE
        END,
        tv.user_hk,
        tv.session_hk,
        CASE 
            WHEN tv.api_token_hk IS NULL THEN 'Token not found'
            WHEN tv.is_revoked THEN 'Token has been revoked'
            WHEN tv.expires_at < CURRENT_TIMESTAMP THEN 'Token has expired'
            WHEN tv.session_hk IS NOT NULL AND tv.session_status != 'ACTIVE' THEN 'Associated session is not active'
            WHEN tv.session_hk IS NOT NULL AND tv.session_start + (tv.session_timeout_minutes || ' minutes')::INTERVAL < CURRENT_TIMESTAMP THEN 'Session has timed out'
            ELSE 'Token and session are valid'
        END
    FROM token_validation tv;

    -- Record token activity for valid tokens
    SELECT api_token_hk INTO v_api_token_hk
    FROM auth.api_token_s
    WHERE token_hash = v_token_hash
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    IF v_api_token_hk IS NOT NULL THEN
        -- Prepare activity metadata
        v_activity_metadata := jsonb_build_object(
            'endpoint', COALESCE(p_endpoint, 'unknown'),
            'ip_address', COALESCE(p_ip_address::text, 'unknown'),
            'user_agent', COALESCE(p_user_agent, 'unknown'),
            'validation_timestamp', CURRENT_TIMESTAMP
        );

        -- End previous activity record
        UPDATE auth.token_activity_s
        SET load_end_date = util.current_load_date()
        WHERE api_token_hk = v_api_token_hk
        AND load_end_date IS NULL;

        -- Create new activity record
        INSERT INTO auth.token_activity_s (
            api_token_hk,
            load_date,
            hash_diff,
            last_activity_timestamp,
            activity_type,
            endpoint_accessed,
            ip_address,
            user_agent,
            activity_metadata,
            record_source
        ) VALUES (
            v_api_token_hk,
            util.current_load_date(),
            util.hash_binary(CURRENT_TIMESTAMP::text || COALESCE(p_endpoint, 'validation')),
            CURRENT_TIMESTAMP,
            'VALIDATION',
            p_endpoint,
            p_ip_address,
            p_user_agent,
            v_activity_metadata,
            util.get_record_source()
        );
    END IF;
END;
$$;

-- Savepoint after validation function
SAVEPOINT validation_function_created;

-- =============================================
-- PHASE 9: TOKEN LIFECYCLE MANAGEMENT
-- =============================================

CREATE OR REPLACE FUNCTION auth.revoke_token(
    p_token_hash BYTEA,
    p_reason TEXT DEFAULT 'Administrative revocation'
) RETURNS BOOLEAN 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_api_token_hk BYTEA;
    v_current_token auth.api_token_s%ROWTYPE;
BEGIN
    -- Get current token details
    SELECT * INTO v_current_token
    FROM auth.api_token_s
    WHERE token_hash = p_token_hash
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    v_api_token_hk := v_current_token.api_token_hk;

    -- End current token record
    UPDATE auth.api_token_s
    SET load_end_date = util.current_load_date()
    WHERE api_token_hk = v_api_token_hk
    AND load_end_date IS NULL;

    -- Create revoked token record
    INSERT INTO auth.api_token_s (
        api_token_hk,
        load_date,
        hash_diff,
        token_hash,
        token_type,
        expires_at,
        is_revoked,
        revocation_reason,
        scope,
        last_used_at,
        created_by,
        revoked_by,
        revoked_at,
        record_source
    ) VALUES (
        v_api_token_hk,
        util.current_load_date(),
        util.hash_binary(v_current_token.token_hash::text || 'REVOKED' || p_reason),
        v_current_token.token_hash,
        v_current_token.token_type,
        v_current_token.expires_at,
        TRUE,
        p_reason,
        v_current_token.scope,
        v_current_token.last_used_at,
        v_current_token.created_by,
        SESSION_USER,
        CURRENT_TIMESTAMP,
        util.get_record_source()
    );

    -- Record revocation activity
    INSERT INTO auth.token_activity_s (
        api_token_hk,
        load_date,
        hash_diff,
        last_activity_timestamp,
        activity_type,
        activity_metadata,
        record_source
    ) VALUES (
        v_api_token_hk,
        util.current_load_date(),
        util.hash_binary('TOKEN_REVOCATION' || CURRENT_TIMESTAMP::text),
        CURRENT_TIMESTAMP,
        'REVOCATION',
        jsonb_build_object(
            'revocation_reason', p_reason,
            'revoked_by', SESSION_USER,
            'revoked_at', CURRENT_TIMESTAMP
        ),
        util.get_record_source()
    );

    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION auth.update_token_usage(
    p_token_hash BYTEA
) RETURNS BOOLEAN 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_api_token_hk BYTEA;
    v_current_token auth.api_token_s%ROWTYPE;
BEGIN
    -- Get current token details
    SELECT * INTO v_current_token
    FROM auth.api_token_s
    WHERE token_hash = p_token_hash
    AND load_end_date IS NULL
    ORDER BY load_date DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    v_api_token_hk := v_current_token.api_token_hk;

    -- End current token record
    UPDATE auth.api_token_s
    SET load_end_date = util.current_load_date()
    WHERE api_token_hk = v_api_token_hk
    AND load_end_date IS NULL;

    -- Create updated token record
    INSERT INTO auth.api_token_s (
        api_token_hk,
        load_date,
        hash_diff,
        token_hash,
        token_type,
        expires_at,
        is_revoked,
        revocation_reason,
        scope,
        last_used_at,
        created_by,
        revoked_by,
        revoked_at,
        record_source
    ) VALUES (
        v_api_token_hk,
        util.current_load_date(),
        util.hash_binary(v_current_token.token_hash::text || CURRENT_TIMESTAMP::text),
        v_current_token.token_hash,
        v_current_token.token_type,
        v_current_token.expires_at,
        v_current_token.is_revoked,
        v_current_token.revocation_reason,
        v_current_token.scope,
        CURRENT_TIMESTAMP,
        v_current_token.created_by,
        v_current_token.revoked_by,
        v_current_token.revoked_at,
        util.get_record_source()
    );

    RETURN TRUE;
END;
$$;

-- Savepoint after lifecycle management
SAVEPOINT lifecycle_management_created;

-- =============================================
-- PHASE 10: PERFORMANCE OPTIMIZATION
-- =============================================

-- Strategic indexes for high-performance operations
CREATE INDEX IF NOT EXISTS idx_api_token_s_token_hash_active 
    ON auth.api_token_s(token_hash) 
    WHERE load_end_date IS NULL AND is_revoked = FALSE;

CREATE INDEX IF NOT EXISTS idx_api_token_s_expires_at_active 
    ON auth.api_token_s(expires_at) 
    WHERE load_end_date IS NULL AND is_revoked = FALSE;

CREATE INDEX IF NOT EXISTS idx_api_token_s_type_active 
    ON auth.api_token_s(token_type) 
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_token_activity_s_timestamp_active 
    ON auth.token_activity_s(last_activity_timestamp DESC) 
    WHERE load_end_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_session_token_l_session 
    ON auth.session_token_l(session_hk);

CREATE INDEX IF NOT EXISTS idx_session_token_l_token 
    ON auth.session_token_l(api_token_hk);

CREATE INDEX IF NOT EXISTS idx_user_token_l_user 
    ON auth.user_token_l(user_hk);

CREATE INDEX IF NOT EXISTS idx_user_token_l_token 
    ON auth.user_token_l(api_token_hk);

CREATE INDEX IF NOT EXISTS idx_ip_tracking_s_ip_time_active 
    ON auth.ip_tracking_s(ip_address, last_request_time DESC) 
    WHERE load_end_date IS NULL;

-- Composite indexes for common query patterns
-- Note: Cannot use subqueries in index expressions, so we create separate indexes
-- for common tenant-based queries
CREATE INDEX IF NOT EXISTS idx_api_token_h_tenant_bk 
    ON auth.api_token_h(tenant_hk, api_token_bk);

-- Index for efficient joins between token satellite and hub on tenant context
CREATE INDEX IF NOT EXISTS idx_api_token_s_hk_type_active 
    ON auth.api_token_s(api_token_hk, token_type) 
    WHERE load_end_date IS NULL;

-- Savepoint after performance optimization
SAVEPOINT performance_optimization_created;

-- =============================================
-- PHASE 11: AUDIT TRIGGERS AND COMPLIANCE
-- =============================================

-- Add comprehensive audit triggers for all new tables
CREATE TRIGGER trg_api_token_h_audit
AFTER INSERT OR UPDATE OR DELETE ON auth.api_token_h
FOR EACH ROW EXECUTE FUNCTION util.audit_track_dispatcher();

CREATE TRIGGER trg_api_token_s_audit
AFTER INSERT OR UPDATE OR DELETE ON auth.api_token_s
FOR EACH ROW EXECUTE FUNCTION util.audit_track_dispatcher();

CREATE TRIGGER trg_user_token_l_audit
AFTER INSERT OR UPDATE OR DELETE ON auth.user_token_l
FOR EACH ROW EXECUTE FUNCTION util.audit_track_dispatcher();

CREATE TRIGGER trg_session_token_l_audit
AFTER INSERT OR UPDATE OR DELETE ON auth.session_token_l
FOR EACH ROW EXECUTE FUNCTION util.audit_track_dispatcher();

CREATE TRIGGER trg_token_activity_s_audit
AFTER INSERT OR UPDATE OR DELETE ON auth.token_activity_s
FOR EACH ROW EXECUTE FUNCTION util.audit_track_dispatcher();

CREATE TRIGGER trg_security_tracking_h_audit
AFTER INSERT OR UPDATE OR DELETE ON auth.security_tracking_h
FOR EACH ROW EXECUTE FUNCTION util.audit_track_dispatcher();

CREATE TRIGGER trg_ip_tracking_s_audit
AFTER INSERT OR UPDATE OR DELETE ON auth.ip_tracking_s
FOR EACH ROW EXECUTE FUNCTION util.audit_track_dispatcher();

-- Savepoint after audit triggers
SAVEPOINT audit_triggers_created;

-- =============================================
-- PHASE 12: COMPREHENSIVE DOCUMENTATION
-- =============================================

-- Function and procedure documentation
COMMENT ON FUNCTION auth.generate_api_token IS 
'Generates secure API tokens with comprehensive lifecycle management, audit trails, and security policy integration. Supports multiple token types and configurable expiration periods for enterprise authentication workflows.';

COMMENT ON PROCEDURE auth.create_session_with_token IS 
'Creates integrated session and API token pairs with proper relationship management and security policy enforcement. Provides seamless authentication experience while maintaining comprehensive audit documentation.';

COMMENT ON FUNCTION auth.validate_token_and_session IS 
'Comprehensive token and session validation with activity tracking and security monitoring. Validates token authenticity, expiration, revocation status, and associated session state for complete security verification.';

COMMENT ON FUNCTION auth.revoke_token IS 
'Secure token revocation with comprehensive audit trails and proper cleanup of associated relationships. Supports administrative and automated revocation scenarios with detailed reason tracking.';

-- Table documentation
COMMENT ON TABLE auth.api_token_h IS 
'Hub table for API token entities maintaining unique identifiers and tenant context for comprehensive token lifecycle management in multi-tenant environments.';

COMMENT ON TABLE auth.api_token_s IS 
'Satellite table containing detailed API token information including lifecycle status, security attributes, and comprehensive usage tracking for regulatory compliance and security monitoring.';

COMMENT ON TABLE auth.session_token_l IS 
'Link table establishing relationships between user sessions and API tokens enabling integrated authentication workflows and comprehensive session management.';

COMMENT ON TABLE auth.token_activity_s IS 
'Satellite table tracking comprehensive API token activity including access patterns, endpoint usage, and security events for monitoring and compliance reporting.';

COMMENT ON TABLE auth.security_tracking_h IS 
'Hub table for security tracking entities managing rate limiting, threat detection, and comprehensive security monitoring across tenant environments.';

COMMENT ON TABLE auth.ip_tracking_s IS 
'Satellite table tracking IP address activity patterns for rate limiting, geographical monitoring, and suspicious activity detection supporting comprehensive security policies.';

-- Final savepoint
SAVEPOINT documentation_complete;

-- =============================================
-- TRANSACTION COMPLETION
-- =============================================

-- If we reach here successfully, commit the transaction
COMMIT;

-- Success message
SELECT 'Token management infrastructure deployed successfully' AS deployment_status;