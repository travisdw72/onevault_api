-- =============================================
-- Fix Password Validation and Constraint Issues
-- =============================================

DO $$
DECLARE
    v_user_hk BYTEA;
    v_tenant_hk BYTEA;
    v_current_hash TEXT;
    v_new_password TEXT := 'MyNewSecurePassword123';
    v_new_hash TEXT;
    v_test_passwords TEXT[] := ARRAY['MyNewSecurePassword123', 'SimpleTest123', 'TestPassword123', 'password123'];
    v_password TEXT;
    v_constraint_info RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'PASSWORD AND CONSTRAINT INVESTIGATION';
    RAISE NOTICE '==============================================';
    
    -- Get user info
    SELECT 
        uh.user_hk,
        uh.tenant_hk,
        uas.password_hash::text
    INTO 
        v_user_hk,
        v_tenant_hk,
        v_current_hash
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = 'travisdwoodward72@gmail.com'
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    RAISE NOTICE 'User HK: %', encode(v_user_hk, 'hex');
    RAISE NOTICE 'Current password hash: %...', left(v_current_hash, 50);
    
    -- =============================================
    -- INVESTIGATE PASSWORD ISSUE
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Password Testing ---';
    
    -- Test common passwords against current hash
    FOREACH v_password IN ARRAY v_test_passwords
    LOOP
        IF (crypt(v_password, v_current_hash) = v_current_hash) THEN
            RAISE NOTICE '✅ FOUND WORKING PASSWORD: "%"', v_password;
        ELSE
            RAISE NOTICE '❌ Password "%..." does not match', left(v_password, 10);
        END IF;
    END LOOP;
    
    -- =============================================
    -- INVESTIGATE CONSTRAINT ISSUE  
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Constraint Investigation ---';
    
    -- Check for the problematic constraint
    SELECT 
        conname,
        pg_get_constraintdef(oid) as definition
    INTO v_constraint_info
    FROM pg_constraint 
    WHERE conname = 'idx_user_auth_username_unique';
    
    IF FOUND THEN
        RAISE NOTICE 'Found constraint: %', v_constraint_info.conname;
        RAISE NOTICE 'Definition: %', v_constraint_info.definition;
    ELSE
        RAISE NOTICE 'Constraint idx_user_auth_username_unique not found by name';
        
        -- Look for any unique constraints on auth.user_auth_s
        RAISE NOTICE 'Checking all constraints on auth.user_auth_s:';
        FOR v_constraint_info IN
            SELECT 
                conname,
                pg_get_constraintdef(oid) as definition
            FROM pg_constraint c
            JOIN pg_class t ON c.conrelid = t.oid
            JOIN pg_namespace n ON t.relnamespace = n.oid
            WHERE n.nspname = 'auth' 
            AND t.relname = 'user_auth_s'
            AND contype IN ('u', 'p')  -- unique or primary key
        LOOP
            RAISE NOTICE '  %: %', v_constraint_info.conname, v_constraint_info.definition;
        END LOOP;
    END IF;
    
    -- Check for duplicate username records
    SELECT COUNT(*) as duplicate_count
    FROM auth.user_auth_s
    WHERE username = 'travisdwoodward72@gmail.com'
    AND load_end_date IS NULL;
    
    GET DIAGNOSTICS v_constraint_info.conname = ROW_COUNT;
    RAISE NOTICE 'Active records for username: %', v_constraint_info.conname;
    
    -- =============================================
    -- FIX PASSWORD HASH
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Password Hash Fix ---';
    
    -- Generate new hash for the test password
    v_new_hash := crypt(v_new_password, gen_salt('bf', 12));
    RAISE NOTICE 'Generated new hash for password: %', v_new_password;
    RAISE NOTICE 'New hash: %...', left(v_new_hash, 50);
    
    -- Verify the new hash works
    IF (crypt(v_new_password, v_new_hash) = v_new_hash) THEN
        RAISE NOTICE '✅ New hash verification PASSED';
        
        -- Update the password hash
        BEGIN
            -- End-date current record
            UPDATE auth.user_auth_s
            SET load_end_date = util.current_load_date()
            WHERE user_hk = v_user_hk
            AND load_end_date IS NULL;
            
            -- Insert new record with updated password
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
                util.hash_binary(username || 'PASSWORD_UPDATE' || CURRENT_TIMESTAMP::text),
                username,
                v_new_hash::bytea,
                password_salt,
                last_login_date,
                CURRENT_TIMESTAMP,
                0, -- Reset failed attempts
                FALSE, -- Unlock account
                NULL, -- Clear lockout time
                FALSE, -- No password change required
                util.get_record_source()
            FROM auth.user_auth_s
            WHERE user_hk = v_user_hk
            AND load_end_date = util.current_load_date()
            ORDER BY load_date DESC
            LIMIT 1;
            
            RAISE NOTICE '✅ Password hash updated successfully';
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Password update FAILED: % - %', SQLSTATE, SQLERRM;
        END;
    ELSE
        RAISE NOTICE '❌ New hash verification FAILED';
    END IF;
    
    -- =============================================
    -- TEST UPDATED PASSWORD
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Testing Updated Password ---';
    
    -- Get updated hash
    SELECT uas.password_hash::text
    INTO v_current_hash
    FROM auth.user_auth_s uas
    WHERE uas.user_hk = v_user_hk
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    -- Test the password
    IF (crypt(v_new_password, v_current_hash) = v_current_hash) THEN
        RAISE NOTICE '✅ Password validation now WORKS for: %', v_new_password;
    ELSE
        RAISE NOTICE '❌ Password validation still FAILS';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'INVESTIGATION COMPLETE';
    RAISE NOTICE '==============================================';
    
END $$; 