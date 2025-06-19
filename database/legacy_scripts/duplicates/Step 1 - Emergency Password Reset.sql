-- ================================================================
-- STEP 1 - EMERGENCY PASSWORD RESET
-- ================================================================
-- Purpose: Reset password for travisdwoodward72@gmail.com to fix login issue
-- Database: the_one_spa_oregon
-- Execute in: pgAdmin as user with write permissions
-- ================================================================

-- ================================================================
-- GET USER AND TENANT INFORMATION + RESET PASSWORD
-- ================================================================

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_tenant_bk TEXT;
    v_result JSONB;
    v_new_password TEXT := 'MySecurePassword123';
BEGIN
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'STEP 1 - EMERGENCY PASSWORD RESET';
    RAISE NOTICE '================================================================';
    RAISE NOTICE '';
    
    -- Get tenant and user info
    RAISE NOTICE 'Getting user and tenant information...';
    
    SELECT 
        uh.tenant_hk,
        uh.user_hk,
        th.tenant_bk
    INTO v_tenant_hk, v_user_hk, v_tenant_bk
    FROM auth.user_h uh
    JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = 'travisdwoodward72@gmail.com'
    AND uas.load_end_date IS NULL
    LIMIT 1;

    IF v_tenant_hk IS NOT NULL THEN
        RAISE NOTICE '✅ Found user - Tenant: %, User HK: %', v_tenant_bk, encode(v_user_hk, 'hex');
        RAISE NOTICE '';
        
        -- Check if the direct password update function exists
        IF EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'auth' AND p.proname = 'update_user_password_direct'
        ) THEN
            RAISE NOTICE 'Using auth.update_user_password_direct() function...';
            
            -- Reset password using direct update function
            SELECT auth.update_user_password_direct(
                v_tenant_hk,
                'travisdwoodward72@gmail.com',
                v_new_password,
                FALSE  -- Don't force change on next login
            ) INTO v_result;
            
            RAISE NOTICE 'Password reset result: %', v_result;
            
            IF (v_result->>'success')::BOOLEAN THEN
                RAISE NOTICE '';
                RAISE NOTICE '🎉 SUCCESS: Password has been reset using direct function!';
                RAISE NOTICE 'Username: travisdwoodward72@gmail.com';
                RAISE NOTICE 'New Password: %', v_new_password;
            ELSE
                RAISE NOTICE '❌ FUNCTION FAILED: %', v_result->>'message';
                RAISE NOTICE 'Falling back to manual method...';
                v_result := NULL; -- Force manual method
            END IF;
        ELSE
            RAISE NOTICE 'Direct password function not found, using manual method...';
            v_result := NULL; -- Force manual method
        END IF;
        
        -- Manual password reset if function failed or doesn't exist
        IF v_result IS NULL THEN
            DECLARE
                v_salt TEXT;
                v_password_hash TEXT;
                v_load_date TIMESTAMP WITH TIME ZONE;
            BEGIN
                RAISE NOTICE 'Performing manual password reset...';
                
                v_load_date := util.current_load_date();
                v_salt := gen_salt('bf', 12);
                v_password_hash := crypt(v_new_password, v_salt);
                
                RAISE NOTICE 'Generated new hash for password: %...', left(v_password_hash, 20);
                
                -- Verify the new hash works
                IF (crypt(v_new_password, v_password_hash) = v_password_hash) THEN
                    RAISE NOTICE '✅ New hash verification PASSED';
                    
                    -- End-date current record
                    UPDATE auth.user_auth_s
                    SET load_end_date = v_load_date
                    WHERE user_hk = v_user_hk
                    AND load_end_date IS NULL;
                    
                    RAISE NOTICE 'End-dated current auth record';
                    
                    -- Create new record with updated password
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
                        v_load_date,
                        util.hash_binary(username || 'EMERGENCY_RESET_' || v_load_date::text),
                        username,
                        v_password_hash::BYTEA,
                        v_salt::BYTEA,
                        last_login_date,
                        v_load_date, -- Update password_last_changed
                        0, -- Reset failed attempts
                        FALSE, -- Unlock account
                        NULL, -- Clear lockout time
                        FALSE, -- No password change required
                        util.get_record_source() || '_EMERGENCY_RESET'
                    FROM auth.user_auth_s
                    WHERE user_hk = v_user_hk
                    AND load_end_date = v_load_date
                    ORDER BY load_date DESC
                    LIMIT 1;
                    
                    RAISE NOTICE '';
                    RAISE NOTICE '🎉 SUCCESS: Password manually updated!';
                    RAISE NOTICE 'Username: travisdwoodward72@gmail.com';
                    RAISE NOTICE 'New Password: %', v_new_password;
                ELSE
                    RAISE NOTICE '❌ New hash verification FAILED';
                END IF;
                
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE '❌ Manual password update FAILED: % - %', SQLSTATE, SQLERRM;
            END;
        END IF;
    ELSE
        RAISE NOTICE '❌ User not found: travisdwoodward72@gmail.com';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'STEP 1 COMPLETED - PASSWORD RESET';
    RAISE NOTICE '================================================================';
END $$;

-- ================================================================
-- VERIFY PASSWORD RESET SUCCESS
-- ================================================================

-- Check the updated user record
SELECT 
    'Current User Auth Record' as info,
    username,
    load_date,
    password_last_changed,
    failed_login_attempts,
    account_locked,
    must_change_password,
    record_source
FROM auth.user_auth_s 
WHERE username = 'travisdwoodward72@gmail.com' 
AND load_end_date IS NULL;

-- ================================================================
-- IMMEDIATE PASSWORD TEST
-- ================================================================

-- Test the new password immediately
SELECT 
    'IMMEDIATE PASSWORD TEST' as test_type,
    api.auth_login('{
        "username": "travisdwoodward72@gmail.com",
        "password": "MySecurePassword123",
        "ip_address": "192.168.1.199",
        "user_agent": "Emergency Password Reset Test"
    }'::jsonb) as result;

-- ================================================================
-- FINAL STATUS
-- ================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'STEP 1 - EMERGENCY PASSWORD RESET COMPLETED';
    RAISE NOTICE '';
    RAISE NOTICE 'If the test above shows {"success": true, ...} then:';
    RAISE NOTICE '✅ LOGIN SYSTEM IS NOW WORKING!';
    RAISE NOTICE '';
    RAISE NOTICE 'If it still shows "Invalid username or password":';
    RAISE NOTICE '❌ Additional debugging required';
    RAISE NOTICE '';
    RAISE NOTICE 'New Credentials:';
    RAISE NOTICE 'Username: travisdwoodward72@gmail.com';
    RAISE NOTICE 'Password: MySecurePassword123';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Step: Run security tests to verify full functionality';
    RAISE NOTICE '================================================================';
END $$; 