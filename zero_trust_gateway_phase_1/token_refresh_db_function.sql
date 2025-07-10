-- =============================================
-- Token Refresh Database Function
-- Implements automatic token refresh with Data Vault 2.0 compliance
-- =============================================

CREATE OR REPLACE FUNCTION auth.refresh_production_token(
    p_current_token TEXT,
    p_refresh_threshold_days INTEGER DEFAULT 7,
    p_force_refresh BOOLEAN DEFAULT false
) RETURNS TABLE (
    success BOOLEAN,
    new_token TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    refresh_reason VARCHAR(100),
    message TEXT
) AS $$
DECLARE
    v_token_hk BYTEA;
    v_token_hash BYTEA;
    v_current_expires_at TIMESTAMP WITH TIME ZONE;
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_days_until_expiry INTEGER;
    v_should_refresh BOOLEAN := false;
    v_refresh_reason VARCHAR(100);
    v_new_token TEXT;
    v_new_token_hk BYTEA;
    v_new_token_hash BYTEA;
    v_new_expires_at TIMESTAMP WITH TIME ZONE;
    v_api_response JSONB;
BEGIN
    -- Step 1: Validate current token and get details
    v_token_hash := sha256(p_current_token::bytea);
    
    SELECT 
        ath.api_token_hk,
        ath.tenant_hk,
        utl.user_hk,
        ats.expires_at
    INTO 
        v_token_hk,
        v_tenant_hk, 
        v_user_hk,
        v_current_expires_at
    FROM auth.api_token_s ats
    JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
    LEFT JOIN auth.user_token_l utl ON ats.api_token_hk = utl.api_token_hk
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL
    AND ats.token_type = 'PRODUCTION';
    
    -- If token not found, return error
    IF v_token_hk IS NULL THEN
        RETURN QUERY SELECT 
            false,
            NULL::TEXT,
            NULL::TIMESTAMP WITH TIME ZONE,
            'TOKEN_NOT_FOUND'::VARCHAR(100),
            'Current token not found in database'::TEXT;
        RETURN;
    END IF;
    
    -- Step 2: Check if refresh is needed
    v_days_until_expiry := EXTRACT(DAY FROM (v_current_expires_at - CURRENT_TIMESTAMP));
    
    IF p_force_refresh THEN
        v_should_refresh := true;
        v_refresh_reason := 'FORCE_REFRESH';
    ELSIF v_current_expires_at <= CURRENT_TIMESTAMP THEN
        v_should_refresh := true;
        v_refresh_reason := 'EXPIRED';
    ELSIF v_days_until_expiry <= p_refresh_threshold_days THEN
        v_should_refresh := true;
        v_refresh_reason := 'THRESHOLD_REACHED';
    ELSE
        -- Token is still fresh
        RETURN QUERY SELECT 
            true,
            p_current_token,
            v_current_expires_at,
            'NO_REFRESH_NEEDED'::VARCHAR(100),
            format('Token valid for %s more days', v_days_until_expiry)::TEXT;
        RETURN;
    END IF;
    
    -- Step 3: Call production API to refresh token
    -- This would call your actual token refresh endpoint
    -- For now, we'll simulate the response
    v_new_token := 'ovt_prod_' || encode(gen_random_bytes(32), 'hex');
    v_new_expires_at := CURRENT_TIMESTAMP + INTERVAL '30 days';
    
    -- In real implementation, you'd call:
    -- SELECT auth.call_production_api_refresh(p_current_token) INTO v_api_response;
    
    -- Step 4: Store new token with Data Vault 2.0 historization
    v_new_token_hk := util.hash_binary(v_new_token);
    v_new_token_hash := sha256(v_new_token::bytea);
    
    -- End-date the old token
    UPDATE auth.api_token_s 
    SET load_end_date = util.current_load_date()
    WHERE api_token_hk = v_token_hk
    AND load_end_date IS NULL;
    
    -- Insert new token hub (if needed)
    INSERT INTO auth.api_token_h (
        api_token_hk,
        api_token_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_new_token_hk,
        'PROD_TOKEN_' || encode(v_new_token_hk, 'hex')[:16],
        v_tenant_hk,
        util.current_load_date(),
        'auth.refresh_production_token'
    ) ON CONFLICT (api_token_hk) DO NOTHING;
    
    -- Insert new token satellite
    INSERT INTO auth.api_token_s (
        api_token_hk,
        load_date,
        load_end_date,
        hash_diff,
        token_type,
        token_hash,
        expires_at,
        is_revoked,
        scope,
        created_at,
        last_used_at,
        usage_count,
        rate_limit_per_hour,
        security_level,
        refresh_reason,
        predecessor_token_hk,
        record_source
    ) VALUES (
        v_new_token_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_new_token || v_new_expires_at::text),
        'PRODUCTION',
        v_new_token_hash,
        v_new_expires_at,
        false,
        ARRAY['api:read', 'api:write'],
        util.current_load_date(),
        NULL,
        0,
        10000,
        'STANDARD',
        v_refresh_reason,
        v_token_hk,  -- Link to previous token
        'auth.refresh_production_token'
    );
    
    -- Update user-token link if exists
    IF v_user_hk IS NOT NULL THEN
        -- End-date old link
        UPDATE auth.user_token_l 
        SET load_end_date = util.current_load_date()
        WHERE user_hk = v_user_hk 
        AND api_token_hk = v_token_hk
        AND load_end_date IS NULL;
        
        -- Create new link
        INSERT INTO auth.user_token_l (
            link_user_token_hk,
            user_hk,
            api_token_hk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            util.hash_binary(v_user_hk::text || v_new_token_hk::text),
            v_user_hk,
            v_new_token_hk,
            v_tenant_hk,
            util.current_load_date(),
            'auth.refresh_production_token'
        );
    END IF;
    
    -- Step 5: Log the refresh event
    INSERT INTO audit.token_refresh_event_s (
        event_hk,
        load_date,
        hash_diff,
        old_token_hk,
        new_token_hk,
        tenant_hk,
        user_hk,
        refresh_reason,
        refresh_timestamp,
        api_response_status,
        days_until_old_expiry,
        new_token_expires_at,
        record_source
    ) VALUES (
        util.hash_binary(v_token_hk::text || v_new_token_hk::text || CURRENT_TIMESTAMP::text),
        util.current_load_date(),
        util.hash_binary(v_refresh_reason || CURRENT_TIMESTAMP::text),
        v_token_hk,
        v_new_token_hk,
        v_tenant_hk,
        v_user_hk,
        v_refresh_reason,
        CURRENT_TIMESTAMP,
        'SUCCESS',
        v_days_until_expiry,
        v_new_expires_at,
        'auth.refresh_production_token'
    );
    
    -- Return success result
    RETURN QUERY SELECT 
        true,
        v_new_token,
        v_new_expires_at,
        v_refresh_reason,
        format('Token refreshed successfully. Reason: %s. New expiry: %s', 
               v_refresh_reason, 
               v_new_expires_at::text)::TEXT;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return failure
        INSERT INTO audit.token_refresh_error_s (
            error_hk,
            load_date,
            hash_diff,
            token_hk,
            tenant_hk,
            error_message,
            error_timestamp,
            sql_state,
            record_source
        ) VALUES (
            util.hash_binary(COALESCE(v_token_hk::text, p_current_token) || SQLERRM || CURRENT_TIMESTAMP::text),
            util.current_load_date(),
            util.hash_binary(SQLERRM),
            v_token_hk,
            v_tenant_hk,
            SQLERRM,
            CURRENT_TIMESTAMP,
            SQLSTATE,
            'auth.refresh_production_token'
        );
        
        RETURN QUERY SELECT 
            false,
            NULL::TEXT,
            NULL::TIMESTAMP WITH TIME ZONE,
            'ERROR'::VARCHAR(100),
            format('Token refresh failed: %s', SQLERRM)::TEXT;
        
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Helper function to check if token needs refresh
-- =============================================

CREATE OR REPLACE FUNCTION auth.check_token_refresh_needed(
    p_token TEXT,
    p_threshold_days INTEGER DEFAULT 7
) RETURNS TABLE (
    needs_refresh BOOLEAN,
    days_until_expiry INTEGER,
    current_expires_at TIMESTAMP WITH TIME ZONE,
    reason VARCHAR(100)
) AS $$
DECLARE
    v_token_hash BYTEA;
    v_expires_at TIMESTAMP WITH TIME ZONE;
    v_days_left INTEGER;
BEGIN
    v_token_hash := sha256(p_token::bytea);
    
    SELECT ats.expires_at
    INTO v_expires_at
    FROM auth.api_token_s ats
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL;
    
    IF v_expires_at IS NULL THEN
        RETURN QUERY SELECT 
            true,
            0,
            NULL::TIMESTAMP WITH TIME ZONE,
            'TOKEN_NOT_FOUND'::VARCHAR(100);
        RETURN;
    END IF;
    
    v_days_left := EXTRACT(DAY FROM (v_expires_at - CURRENT_TIMESTAMP));
    
    IF v_expires_at <= CURRENT_TIMESTAMP THEN
        RETURN QUERY SELECT 
            true,
            v_days_left,
            v_expires_at,
            'EXPIRED'::VARCHAR(100);
    ELSIF v_days_left <= p_threshold_days THEN
        RETURN QUERY SELECT 
            true,
            v_days_left,
            v_expires_at,
            'THRESHOLD_REACHED'::VARCHAR(100);
    ELSE
        RETURN QUERY SELECT 
            false,
            v_days_left,
            v_expires_at,
            'FRESH'::VARCHAR(100);
    END IF;
    
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Grant permissions
-- =============================================

GRANT EXECUTE ON FUNCTION auth.refresh_production_token(TEXT, INTEGER, BOOLEAN) TO api_user;
GRANT EXECUTE ON FUNCTION auth.check_token_refresh_needed(TEXT, INTEGER) TO api_user;

-- =============================================
-- Usage Examples
-- =============================================

/*
-- Check if token needs refresh
SELECT * FROM auth.check_token_refresh_needed('ovt_prod_your_token_here');

-- Refresh token if needed (auto-refresh when < 7 days)
SELECT * FROM auth.refresh_production_token('ovt_prod_your_token_here');

-- Force refresh immediately
SELECT * FROM auth.refresh_production_token('ovt_prod_your_token_here', 7, true);

-- Check with custom threshold (refresh when < 14 days)
SELECT * FROM auth.refresh_production_token('ovt_prod_your_token_here', 14);
*/ 