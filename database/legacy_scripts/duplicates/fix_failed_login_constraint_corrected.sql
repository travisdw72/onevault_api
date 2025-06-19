-- =============================================
-- Fix auth.process_failed_login Constraint Issue (CORRECTED)
-- The function is hitting a unique constraint when updating user auth records
-- This version fixes the ROWTYPE variable issue
-- =============================================

-- First, let's check the current implementation
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'FIXING auth.process_failed_login ISSUE (CORRECTED)';
    RAISE NOTICE '==============================================';
END $$;

-- Create a fixed version of auth.process_failed_login that properly handles historization
CREATE OR REPLACE FUNCTION auth.process_failed_login(
    p_tenant_hk BYTEA,
    p_username VARCHAR(255),
    p_failure_reason VARCHAR(255),
    p_ip_address INET
) RETURNS BOOLEAN 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_hk BYTEA;
    v_current_attempts INTEGER;
    v_lockout_threshold INTEGER;
    v_lockout_duration_minutes INTEGER;
    v_new_lockout_until TIMESTAMP WITH TIME ZONE;
    
    -- Individual scalar variables instead of ROWTYPE
    v_current_username VARCHAR(255);
    v_current_password_hash BYTEA;
    v_current_password_salt BYTEA;
    v_current_last_login_date TIMESTAMP WITH TIME ZONE;
    v_current_password_last_changed TIMESTAMP WITH TIME ZONE;
    v_current_must_change_password BOOLEAN;
BEGIN
    -- Log the function call
    RAISE NOTICE 'Processing failed login for username: %, reason: %', p_username, p_failure_reason;
    
    -- Get user hash key and current auth record data
    SELECT 
        uh.user_hk,
        uas.username,
        uas.password_hash,
        uas.password_salt,
        uas.last_login_date,
        uas.password_last_changed,
        uas.must_change_password,
        COALESCE(uas.failed_login_attempts, 0)
    INTO 
        v_user_hk,
        v_current_username,
        v_current_password_hash,
        v_current_password_salt,
        v_current_last_login_date,
        v_current_password_last_changed,
        v_current_must_change_password,
        v_current_attempts
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uh.tenant_hk = p_tenant_hk
    AND uas.username = p_username
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;

    -- If user not found, return false (don't reveal user existence)
    IF v_user_hk IS NULL THEN
        RAISE NOTICE 'User not found for failed login processing: %', p_username;
        RETURN FALSE;
    END IF;

    RAISE NOTICE 'Found user HK: %, current failed attempts: %', 
        encode(v_user_hk, 'hex'), v_current_attempts;

    -- Get security policy for lockout settings
    SELECT 
        COALESCE(sp.account_lockout_threshold, 5),
        COALESCE(sp.account_lockout_duration_minutes, 30)
    INTO 
        v_lockout_threshold,
        v_lockout_duration_minutes
    FROM auth.security_policy_h sph
    JOIN auth.security_policy_s sp ON sph.security_policy_hk = sp.security_policy_hk
    WHERE sph.tenant_hk = p_tenant_hk
    AND sp.is_active = TRUE 
    AND sp.load_end_date IS NULL
    ORDER BY sp.load_date DESC
    LIMIT 1;

    -- Use defaults if no policy found
    v_lockout_threshold := COALESCE(v_lockout_threshold, 5);
    v_lockout_duration_minutes := COALESCE(v_lockout_duration_minutes, 30);
    
    RAISE NOTICE 'Using lockout threshold: %, duration: % minutes', 
        v_lockout_threshold, v_lockout_duration_minutes;

    -- Calculate new failed attempts count
    v_current_attempts := v_current_attempts + 1;
    
    -- Determine if account should be locked
    IF v_current_attempts >= v_lockout_threshold THEN
        v_new_lockout_until := CURRENT_TIMESTAMP + (v_lockout_duration_minutes || ' minutes')::INTERVAL;
        RAISE NOTICE 'Account will be locked until: %', v_new_lockout_until;
    ELSE
        v_new_lockout_until := NULL;
        RAISE NOTICE 'Account not locked yet. Attempts: %/%', v_current_attempts, v_lockout_threshold;
    END IF;

    -- CRITICAL FIX: Proper Data Vault 2.0 historization to avoid constraint violations
    BEGIN
        -- STEP 1: End-date the current record FIRST
        UPDATE auth.user_auth_s
        SET load_end_date = util.current_load_date()
        WHERE user_hk = v_user_hk
        AND load_end_date IS NULL;
        
        RAISE NOTICE 'End-dated current auth record';

        -- STEP 2: Insert new record with updated failed attempts
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
        ) VALUES (
            v_user_hk,
            util.current_load_date(),
            util.hash_binary(v_current_username || 'FAILED_LOGIN_' || v_current_attempts::text || '_' || CURRENT_TIMESTAMP::text),
            v_current_username,
            v_current_password_hash,
            v_current_password_salt,
            v_current_last_login_date,
            v_current_password_last_changed,
            v_current_attempts,
            CASE WHEN v_current_attempts >= v_lockout_threshold THEN TRUE ELSE FALSE END,
            v_new_lockout_until,
            v_current_must_change_password,
            util.get_record_source()
        );
        
        RAISE NOTICE '✅ Successfully updated failed login attempts to: %', v_current_attempts;
        
        -- Log the security event
        INSERT INTO auth.security_tracking_h (
            security_event_hk,
            security_event_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            util.hash_binary(p_username || p_failure_reason || CURRENT_TIMESTAMP::text),
            util.generate_bk('FAILED_LOGIN_' || p_username || '_' || CURRENT_TIMESTAMP::text),
            p_tenant_hk,
            util.current_load_date(),
            util.get_record_source()
        ) ON CONFLICT (security_event_hk) DO NOTHING;

        RETURN TRUE;

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Error updating failed login attempts: % - %', SQLSTATE, SQLERRM;
        RAISE NOTICE 'Rolling back transaction...';
        RETURN FALSE;
    END;

END;
$$;

COMMENT ON FUNCTION auth.process_failed_login IS 
'CORRECTED VERSION: Processes failed login attempts with proper Data Vault 2.0 historization. 
Uses individual scalar variables instead of ROWTYPE to avoid PostgreSQL variable issues.
Increments failed attempt counters and applies account lockout policies without constraint violations.
Returns TRUE if processing succeeded, FALSE otherwise.';

-- Test the corrected function
DO $$
DECLARE
    v_result BOOLEAN;
    v_test_tenant_hk BYTEA;
    v_test_username VARCHAR(255) := 'travisdwoodward72@gmail.com';
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'TESTING CORRECTED auth.process_failed_login';
    RAISE NOTICE '==============================================';
    
    -- Get tenant HK for testing
    SELECT uh.tenant_hk INTO v_test_tenant_hk
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = v_test_username
    AND uas.load_end_date IS NULL
    LIMIT 1;
    
    IF v_test_tenant_hk IS NOT NULL THEN
        RAISE NOTICE 'Testing with tenant HK: %', encode(v_test_tenant_hk, 'hex');
        
        -- Test the corrected function
        v_result := auth.process_failed_login(
            v_test_tenant_hk,
            v_test_username,
            'TEST_INVALID_PASSWORD_CORRECTED',
            '192.168.1.100'::INET
        );
        
        IF v_result THEN
            RAISE NOTICE '✅ Corrected function test PASSED';
            
            -- Check the results
            DECLARE
                v_failed_attempts INTEGER;
            BEGIN
                SELECT COALESCE(uas.failed_login_attempts, 0)
                INTO v_failed_attempts
                FROM auth.user_auth_s uas
                JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
                WHERE uas.username = v_test_username
                AND uas.load_end_date IS NULL
                ORDER BY uas.load_date DESC
                LIMIT 1;
                
                RAISE NOTICE 'Updated failed attempts count: %', v_failed_attempts;
            END;
        ELSE
            RAISE NOTICE '❌ Corrected function test FAILED';
        END IF;
    ELSE
        RAISE NOTICE '❌ Could not find tenant for testing';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'CORRECTED FAILED LOGIN FUNCTION FIX COMPLETE';
    RAISE NOTICE '==============================================';
    
END $$; 