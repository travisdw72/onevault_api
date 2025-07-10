-- =============================================
-- Token Expiration Extension Function
-- EXTENDS existing token expiration WITHOUT changing token value
-- =============================================

CREATE OR REPLACE FUNCTION auth.extend_token_expiration(
    p_current_token TEXT,
    p_extension_days INTEGER DEFAULT 30,
    p_extend_threshold_days INTEGER DEFAULT 7
) RETURNS TABLE (
    success BOOLEAN,
    token_unchanged TEXT,
    new_expires_at TIMESTAMP WITH TIME ZONE,
    extension_reason VARCHAR(100),
    message TEXT
) AS $$
DECLARE
    v_token_hk BYTEA;
    v_token_hash BYTEA;
    v_current_expires_at TIMESTAMP WITH TIME ZONE;
    v_days_until_expiry INTEGER;
    v_should_extend BOOLEAN := false;
    v_extension_reason VARCHAR(100);
    v_new_expires_at TIMESTAMP WITH TIME ZONE;
    v_is_revoked BOOLEAN;
    v_token_type VARCHAR(50);
BEGIN
    -- Step 1: Validate current token exists and get details
    v_token_hash := sha256(p_current_token::bytea);
    
    SELECT 
        ath.api_token_hk,
        ats.expires_at,
        ats.is_revoked,
        ats.token_type
    INTO 
        v_token_hk,
        v_current_expires_at,
        v_is_revoked,
        v_token_type
    FROM auth.api_token_s ats
    JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL
    AND ats.token_type IN ('PRODUCTION', 'API', 'API_KEY');
    
    -- If token not found, return error
    IF v_token_hk IS NULL THEN
        RETURN QUERY SELECT 
            false,
            p_current_token,
            NULL::TIMESTAMP WITH TIME ZONE,
            'TOKEN_NOT_FOUND'::VARCHAR(100),
            'Current token not found in database'::TEXT;
        RETURN;
    END IF;
    
    -- If token is revoked, return error
    IF v_is_revoked THEN
        RETURN QUERY SELECT 
            false,
            p_current_token,
            NULL::TIMESTAMP WITH TIME ZONE,
            'TOKEN_REVOKED'::VARCHAR(100),
            'Cannot extend a revoked token'::TEXT;
        RETURN;
    END IF;
    
    -- Step 2: Check if extension is needed
    v_days_until_expiry := EXTRACT(DAY FROM (v_current_expires_at - CURRENT_TIMESTAMP));
    
    IF v_current_expires_at <= CURRENT_TIMESTAMP THEN
        v_should_extend := true;
        v_extension_reason := 'EXPIRED';
    ELSIF v_days_until_expiry <= p_extend_threshold_days THEN
        v_should_extend := true;
        v_extension_reason := 'EXPIRING_SOON';
    ELSE
        -- Token doesn't need extension yet
        RETURN QUERY SELECT 
            true,
            p_current_token,
            v_current_expires_at,
            'NO_EXTENSION_NEEDED'::VARCHAR(100),
            format('Token valid for %s more days - no extension needed', v_days_until_expiry)::TEXT;
        RETURN;
    END IF;
    
    -- Step 3: Calculate new expiration date
    v_new_expires_at := CURRENT_TIMESTAMP + (p_extension_days || ' days')::INTERVAL;
    
    -- Step 4: EXTEND existing token by creating new satellite record (Data Vault 2.0 pattern)
    -- End-date the current satellite record
    UPDATE auth.api_token_s 
    SET load_end_date = util.current_load_date()
    WHERE api_token_hk = v_token_hk
    AND load_end_date IS NULL;
    
    -- Insert new satellite record with SAME token hash but extended expiration
    INSERT INTO auth.api_token_s (
        api_token_hk,               -- SAME hub record (token unchanged)
        load_date,
        load_end_date,
        hash_diff,
        token_hash,                 -- SAME token hash (token unchanged)
        token_type,
        expires_at,                 -- NEW expiration date
        is_revoked,
        scope,
        created_by,
        record_source
    ) 
    SELECT 
        ats_old.api_token_hk,       -- Keep same hub
        util.current_load_date(),   -- New load date
        NULL,                       -- Active record
        util.hash_binary(           -- New hash diff for change tracking
            encode(ats_old.token_hash, 'hex') || 
            v_new_expires_at::text || 
            v_extension_reason
        ),
        ats_old.token_hash,         -- SAME token hash (token unchanged)
        ats_old.token_type,         -- Preserve token type
        v_new_expires_at,           -- NEW expiration date
        false,                      -- Not revoked
        ats_old.scope,              -- Preserve scope
        ats_old.created_by,         -- Preserve creator
        'auth.extend_token_expiration' -- Track the extension
    FROM auth.api_token_s ats_old
    WHERE ats_old.api_token_hk = v_token_hk
    AND ats_old.load_end_date = util.current_load_date(); -- The record we just end-dated
    
    -- Step 5: Log the extension activity
    BEGIN
        INSERT INTO auth.token_activity_s (
            api_token_hk,
            load_date,
            hash_diff,
            last_activity_timestamp,
            activity_type,
            activity_metadata,
            record_source
        ) VALUES (
            v_token_hk,
            util.current_load_date(),
            util.hash_binary('TOKEN_EXTEND_' || v_extension_reason || CURRENT_TIMESTAMP::text),
            CURRENT_TIMESTAMP,
            'EXPIRATION_EXTENDED',
            jsonb_build_object(
                'extension_reason', v_extension_reason,
                'original_expires_at', v_current_expires_at,
                'new_expires_at', v_new_expires_at,
                'days_until_old_expiry', v_days_until_expiry,
                'extension_days', p_extension_days,
                'extended_by', SESSION_USER,
                'token_value_unchanged', true
            ),
            'auth.extend_token_expiration'
        );
    EXCEPTION WHEN undefined_table THEN
        -- Gracefully continue without detailed audit logging
        NULL;
    END;
    
    -- Return success result
    RETURN QUERY SELECT 
        true,
        p_current_token,           -- SAME token returned
        v_new_expires_at,
        v_extension_reason,
        format('✅ Token expiration extended successfully. Reason: %s. Token value UNCHANGED. New expiration: %s', 
               v_extension_reason, 
               v_new_expires_at::text)::TEXT;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            false,
            p_current_token,
            NULL::TIMESTAMP WITH TIME ZONE,
            'ERROR'::VARCHAR(100),
            format('❌ Token extension failed: %s (SQLSTATE: %s)', SQLERRM, SQLSTATE)::TEXT;
        
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Convenience function to check if extension is recommended
-- =============================================

CREATE OR REPLACE FUNCTION auth.check_token_extension_needed(
    p_token TEXT,
    p_threshold_days INTEGER DEFAULT 7
) RETURNS TABLE (
    token_found BOOLEAN,
    current_expires_at TIMESTAMP WITH TIME ZONE,
    days_until_expiry INTEGER,
    extension_recommended BOOLEAN,
    reason VARCHAR(100)
) AS $$
DECLARE
    v_token_hash BYTEA;
    v_expires_at TIMESTAMP WITH TIME ZONE;
    v_days_left INTEGER;
    v_is_revoked BOOLEAN;
BEGIN
    v_token_hash := sha256(p_token::bytea);
    
    SELECT 
        ats.expires_at,
        ats.is_revoked
    INTO 
        v_expires_at,
        v_is_revoked
    FROM auth.api_token_s ats
    WHERE ats.token_hash = v_token_hash
    AND ats.load_end_date IS NULL;
    
    IF v_expires_at IS NULL THEN
        RETURN QUERY SELECT 
            false, NULL::TIMESTAMP WITH TIME ZONE, 0, false, 'TOKEN_NOT_FOUND'::VARCHAR(100);
        RETURN;
    END IF;
    
    v_days_left := EXTRACT(DAY FROM (v_expires_at - CURRENT_TIMESTAMP));
    
    RETURN QUERY SELECT 
        true,
        v_expires_at,
        v_days_left,
        CASE 
            WHEN v_is_revoked THEN false
            WHEN v_expires_at <= CURRENT_TIMESTAMP THEN true
            WHEN v_days_left <= p_threshold_days THEN true
            ELSE false
        END,
        CASE 
            WHEN v_is_revoked THEN 'TOKEN_REVOKED'
            WHEN v_expires_at <= CURRENT_TIMESTAMP THEN 'EXPIRED'
            WHEN v_days_left <= p_threshold_days THEN 'EXPIRING_SOON'
            ELSE 'FRESH'
        END::VARCHAR(100);
        
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Grant permissions
-- =============================================

DO $$
BEGIN
    -- Check if api_user role exists and grant permissions
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'api_user') THEN
        GRANT EXECUTE ON FUNCTION auth.extend_token_expiration(TEXT, INTEGER, INTEGER) TO api_user;
        GRANT EXECUTE ON FUNCTION auth.check_token_extension_needed(TEXT, INTEGER) TO api_user;
        RAISE NOTICE '✅ Permissions granted to api_user role';
    ELSE
        RAISE NOTICE '⚠️  Role api_user does not exist - permissions not granted';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
        GRANT EXECUTE ON FUNCTION auth.extend_token_expiration(TEXT, INTEGER, INTEGER) TO postgres;
        GRANT EXECUTE ON FUNCTION auth.check_token_extension_needed(TEXT, INTEGER) TO postgres;
        RAISE NOTICE '✅ Permissions granted to postgres role';
    END IF;
END $$;

-- =============================================
-- Success message
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '🎉 Token Extension System deployed successfully!';
    RAISE NOTICE '📋 Available functions:';
    RAISE NOTICE '   - auth.extend_token_expiration() - Extends expiration WITHOUT changing token';
    RAISE NOTICE '   - auth.check_token_extension_needed() - Checks if extension recommended';
    RAISE NOTICE '🔧 Token value remains UNCHANGED - only expiration date updates';
END $$;

-- =============================================
-- Usage Examples
-- =============================================

/*
-- Check if extension is needed:
SELECT * FROM auth.check_token_extension_needed('ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e');

-- Extend token expiration by 30 days (default):
SELECT * FROM auth.extend_token_expiration('ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e');

-- Extend token expiration by custom number of days:
SELECT * FROM auth.extend_token_expiration('ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e', 60);

-- Check extension with custom threshold:
SELECT * FROM auth.check_token_extension_needed('ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e', 14);
*/

-- =============================================
-- KEY DIFFERENCES FROM REFRESH FUNCTION:
-- =============================================

/*
🎯 TOKEN EXTENSION vs TOKEN REFRESH:

EXTENSION (This Function):
- ✅ Token value stays EXACTLY the same
- ✅ Only expiration date changes  
- ✅ Client keeps using same token
- ✅ No token distribution needed
- ✅ Simpler client integration

REFRESH (Other Function):
- ❌ Creates completely NEW token value
- ❌ Client must update to new token
- ❌ Old token becomes invalid
- ❌ Requires token distribution mechanism
- ❌ More complex client handling

🚀 RECOMMENDATION: Use EXTENSION for production simplicity
*/ 