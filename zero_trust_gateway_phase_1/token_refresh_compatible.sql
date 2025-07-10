-- =============================================
-- Token Refresh Database Function - COMPATIBLE VERSION
-- Works with existing schema structure
-- =============================================

CREATE OR REPLACE FUNCTION auth.refresh_production_token_compatible(
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
    v_current_scope TEXT[];
    v_created_by TEXT;
BEGIN
    -- Step 1: Validate current token and get details
    v_token_hash := sha256(p_current_token::bytea);
    
    SELECT 
        ath.api_token_hk,
        ath.tenant_hk,
        utl.user_hk,
        ats.expires_at,
        ats.scope,
        ats.created_by
    INTO 
        v_token_hk,
        v_tenant_hk, 
        v_user_hk,
        v_current_expires_at,
        v_current_scope,
        v_created_by
    FROM auth.api_token_s ats
    JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
    LEFT JOIN auth.user_token_l utl ON ats.api_token_hk = utl.api_token_hk
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL
    AND ats.token_type IN ('PRODUCTION', 'API_KEY');  -- Support both token types
    
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
    
    -- Step 3: Generate new token (simulate for now)
    -- In production, this would call your actual API refresh endpoint
    v_new_token := 'ovt_prod_' || encode(gen_random_bytes(32), 'hex');
    v_new_expires_at := CURRENT_TIMESTAMP + INTERVAL '30 days';
    
    -- Step 4: Store new token with Data Vault 2.0 historization (COMPATIBLE VERSION)
    v_new_token_hk := util.hash_binary(v_new_token);
    v_new_token_hash := sha256(v_new_token::bytea);
    
    -- End-date the old token
    UPDATE auth.api_token_s 
    SET 
        load_end_date = util.current_load_date(),
        revoked_at = util.current_load_date(),
        revoked_by = SESSION_USER,
        revocation_reason = 'Token refreshed: ' || v_refresh_reason
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
        'REFRESH_TOKEN_' || substr(encode(v_new_token_hk, 'hex'), 1, 16),
        v_tenant_hk,
        util.current_load_date(),
        'auth.refresh_production_token_compatible'
    ) ON CONFLICT (api_token_hk) DO NOTHING;
    
    -- Insert new token satellite (using EXISTING schema)
    INSERT INTO auth.api_token_s (
        api_token_hk,
        load_date,
        load_end_date,
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
        v_new_token_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_new_token || v_new_expires_at::text),
        v_new_token_hash,
        'API_KEY',  -- Use your existing token type
        v_new_expires_at,
        false,
        NULL,  -- Not revoked yet
        COALESCE(v_current_scope, ARRAY['api:read', 'api:write']),
        NULL,  -- Not used yet
        COALESCE(v_created_by, SESSION_USER),
        NULL,  -- Not revoked yet
        NULL,  -- Not revoked yet
        'auth.refresh_production_token_compatible'
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
            'auth.refresh_production_token_compatible'
        );
    END IF;
    
    -- Step 5: Log the refresh event (using existing audit pattern)
    -- If you have an audit schema, use it; otherwise create a simple log entry
    BEGIN
        INSERT INTO audit.api_token_refresh_log (
            log_hk,
            load_date,
            hash_diff,
            old_token_hk,
            new_token_hk,
            tenant_hk,
            user_hk,
            refresh_reason,
            refresh_timestamp,
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
            v_days_until_expiry,
            v_new_expires_at,
            'auth.refresh_production_token_compatible'
        );
    EXCEPTION WHEN undefined_table THEN
        -- If audit table doesn't exist, just continue
        -- The refresh will still work, but without detailed audit logging
        NULL;
    END;
    
    -- Return success result
    RETURN QUERY SELECT 
        true,
        v_new_token,
        v_new_expires_at,
        v_refresh_reason,
        format('Token refreshed successfully. Reason: %s. New expiry: %s. Old token revoked.', 
               v_refresh_reason, 
               v_new_expires_at::text)::TEXT;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error in existing structure if possible
        BEGIN
            INSERT INTO audit.api_token_error_log (
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
                'auth.refresh_production_token_compatible'
            );
        EXCEPTION WHEN OTHERS THEN
            -- If error logging fails, just continue
            NULL;
        END;
        
        RETURN QUERY SELECT 
            false,
            NULL::TEXT,
            NULL::TIMESTAMP WITH TIME ZONE,
            'ERROR'::VARCHAR(100),
            format('Token refresh failed: %s', SQLERRM)::TEXT;
        
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Helper function to check if token needs refresh (COMPATIBLE)
-- =============================================

CREATE OR REPLACE FUNCTION auth.check_token_refresh_needed_compatible(
    p_token TEXT,
    p_threshold_days INTEGER DEFAULT 7
) RETURNS TABLE (
    needs_refresh BOOLEAN,
    days_until_expiry INTEGER,
    current_expires_at TIMESTAMP WITH TIME ZONE,
    reason VARCHAR(100),
    token_type VARCHAR(50),
    is_revoked BOOLEAN
) AS $$
DECLARE
    v_token_hash BYTEA;
    v_expires_at TIMESTAMP WITH TIME ZONE;
    v_days_left INTEGER;
    v_token_type VARCHAR(50);
    v_is_revoked BOOLEAN;
BEGIN
    v_token_hash := sha256(p_token::bytea);
    
    SELECT 
        ats.expires_at,
        ats.token_type,
        ats.is_revoked
    INTO 
        v_expires_at,
        v_token_type,
        v_is_revoked
    FROM auth.api_token_s ats
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL;
    
    IF v_expires_at IS NULL THEN
        RETURN QUERY SELECT 
            true,
            0,
            NULL::TIMESTAMP WITH TIME ZONE,
            'TOKEN_NOT_FOUND'::VARCHAR(100),
            'UNKNOWN'::VARCHAR(50),
            false;
        RETURN;
    END IF;
    
    IF v_is_revoked THEN
        RETURN QUERY SELECT 
            true,
            0,
            v_expires_at,
            'TOKEN_REVOKED'::VARCHAR(100),
            v_token_type,
            v_is_revoked;
        RETURN;
    END IF;
    
    v_days_left := EXTRACT(DAY FROM (v_expires_at - CURRENT_TIMESTAMP));
    
    IF v_expires_at <= CURRENT_TIMESTAMP THEN
        RETURN QUERY SELECT 
            true,
            v_days_left,
            v_expires_at,
            'EXPIRED'::VARCHAR(100),
            v_token_type,
            v_is_revoked;
    ELSIF v_days_left <= p_threshold_days THEN
        RETURN QUERY SELECT 
            true,
            v_days_left,
            v_expires_at,
            'THRESHOLD_REACHED'::VARCHAR(100),
            v_token_type,
            v_is_revoked;
    ELSE
        RETURN QUERY SELECT 
            false,
            v_days_left,
            v_expires_at,
            'FRESH'::VARCHAR(100),
            v_token_type,
            v_is_revoked;
    END IF;
    
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Grant permissions
-- =============================================

GRANT EXECUTE ON FUNCTION auth.refresh_production_token_compatible(TEXT, INTEGER, BOOLEAN) TO api_user;
GRANT EXECUTE ON FUNCTION auth.check_token_refresh_needed_compatible(TEXT, INTEGER) TO api_user;

-- =============================================
-- Test with your actual production token
-- =============================================

/*
-- Test with your existing production token
SELECT * FROM auth.check_token_refresh_needed_compatible('ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e');

-- If refresh is needed:
SELECT * FROM auth.refresh_production_token_compatible('ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e');

-- Force refresh for testing:
SELECT * FROM auth.refresh_production_token_compatible('ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e', 7, true);
*/

-- =============================================
-- USAGE NOTES:
-- =============================================

/*
🎯 COMPATIBILITY FEATURES:
- ✅ Works with your EXISTING schema (no changes needed)
- ✅ Uses existing columns: token_type, scope, created_by, revoked_at, etc.
- ✅ Supports both 'PRODUCTION' and 'API_KEY' token types
- ✅ Properly handles existing audit patterns
- ✅ Graceful error handling if audit tables don't exist

🚀 IMMEDIATE BENEFITS:
- Automatic token refresh when < 7 days remain
- Force refresh capability for testing
- Complete audit trail using existing fields
- Zero schema changes required
- Works with your production token immediately

🔧 OPTIONAL ENHANCEMENTS (later):
If you want the enhanced features, you can add these columns:
- created_at (use load_date for now)
- usage_count (track separately for now)
- rate_limit_per_hour (use default 1000/hour)
- security_level (use 'STANDARD' for now)
- refresh_reason (stored in revocation_reason for now)
- predecessor_token_hk (can add later for token lineage)
*/ 