-- =============================================
-- Fix Password Validation and Constraint Issues (CORRECTED VERSION)
-- Fixes the ambiguous 'oid' column reference error
-- =============================================

DO $$
DECLARE
    v_user_hk BYTEA;
    v_tenant_hk BYTEA;
    v_current_hash TEXT;
    v_new_password TEXT := 'MyNewSecurePassword123';
    v_new_hash TEXT;
    v_test_passwords TEXT[] := ARRAY[
        'MyNewSecurePassword123', 
        'SimpleTest123', 
        'TestPassword123', 
        'password123',
        'Password123',
        'test123',
        'admin123',
        'user123',
        'securepass',
        'defaultpass',
        'TestPass123',
        'UserPassword',
        'welcome123',
        'database123'
    ];
    v_password TEXT;
    v_constraint_info RECORD;
    v_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'PASSWORD AND CONSTRAINT INVESTIGATION (FIXED)';
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
    RAISE NOTICE 'Full hash length: % characters', length(v_current_hash);
    
    -- Check if it's a bcrypt hash (should start with $2a$, $2b$, or $2y$)
    IF v_current_hash LIKE '$2%' THEN
        RAISE NOTICE '✅ Hash appears to be bcrypt format';
    ELSE
        RAISE NOTICE '❌ Hash format not recognized as bcrypt';
    END IF;
    
    -- =============================================
    -- INVESTIGATE PASSWORD ISSUE
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Password Testing (Extended List) ---';
    
    -- Test common passwords against current hash
    FOREACH v_password IN ARRAY v_test_passwords
    LOOP
        BEGIN
            IF (crypt(v_password, v_current_hash) = v_current_hash) THEN
                RAISE NOTICE '✅ FOUND WORKING PASSWORD: "%"', v_password;
                RETURN; -- Exit early if we find the working password
            ELSE
                RAISE NOTICE '❌ Password "%..." does not match', left(v_password, 10);
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Error testing password "%...": %', left(v_password, 10), SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE 'No matching password found. Will create new hash.';
    
    -- =============================================
    -- INVESTIGATE CONSTRAINT ISSUE (FIXED QUERY)
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Constraint Investigation ---';
    
    -- Check for the problematic constraint (FIXED: qualify the oid column properly)
    BEGIN
        SELECT 
            c.conname,
            pg_get_constraintdef(c.oid) as definition
        INTO v_constraint_info
        FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE c.conname = 'idx_user_auth_username_unique'
        AND n.nspname = 'auth' 
        AND t.relname = 'user_auth_s';
        
        IF FOUND THEN
            RAISE NOTICE 'Found constraint: %', v_constraint_info.conname;
            RAISE NOTICE 'Definition: %', v_constraint_info.definition;
        ELSE
            RAISE NOTICE 'Constraint idx_user_auth_username_unique not found by exact name';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error checking specific constraint: %', SQLERRM;
    END;
    
    -- Look for any unique constraints on auth.user_auth_s (FIXED QUERY)
    RAISE NOTICE 'Checking all constraints on auth.user_auth_s:';
    BEGIN
        FOR v_constraint_info IN
            SELECT 
                c.conname,
                pg_get_constraintdef(c.oid) as definition,
                c.contype
            FROM pg_constraint c
            JOIN pg_class t ON c.conrelid = t.oid
            JOIN pg_namespace n ON t.relnamespace = n.oid
            WHERE n.nspname = 'auth' 
            AND t.relname = 'user_auth_s'
            AND c.contype IN ('u', 'p')  -- unique or primary key
        LOOP
            RAISE NOTICE '  %: % (type: %)', 
                v_constraint_info.conname, 
                v_constraint_info.definition,
                CASE v_constraint_info.contype 
                    WHEN 'u' THEN 'UNIQUE'
                    WHEN 'p' THEN 'PRIMARY KEY'
                    ELSE v_constraint_info.contype
                END;
        END LOOP;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error listing constraints: %', SQLERRM;
    END;
    
    -- Check for duplicate username records
    SELECT COUNT(*)
    INTO v_count
    FROM auth.user_auth_s
    WHERE username = 'travisdwoodward72@gmail.com'
    AND load_end_date IS NULL;
    
    RAISE NOTICE 'Active records for username: %', v_count;
    
    -- Show all records for this username to understand the history
    RAISE NOTICE '';
    RAISE NOTICE '--- Username History ---';
    SELECT COUNT(*) INTO v_count
    FROM auth.user_auth_s
    WHERE username = 'travisdwoodward72@gmail.com';
    
    RAISE NOTICE 'Total records (including historical): %', v_count;
    
    -- =============================================
    -- FIX PASSWORD HASH
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Password Hash Fix ---';
    
    -- Generate new hash for the test password using bcrypt with cost 12
    v_new_hash := crypt(v_new_password, gen_salt('bf', 12));
    RAISE NOTICE 'Generated new bcrypt hash for password: %', v_new_password;
    RAISE NOTICE 'New hash: %...', left(v_new_hash, 50);
    RAISE NOTICE 'New hash full length: %', length(v_new_hash);
    
    -- Verify the new hash works
    IF (crypt(v_new_password, v_new_hash) = v_new_hash) THEN
        RAISE NOTICE '✅ New hash verification PASSED';
        
        -- Update the password hash using proper Data Vault 2.0 historization
        BEGIN
            -- End-date current record
            UPDATE auth.user_auth_s
            SET load_end_date = util.current_load_date()
            WHERE user_hk = v_user_hk
            AND load_end_date IS NULL;
            
            RAISE NOTICE 'End-dated current auth record';
            
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
                CURRENT_TIMESTAMP, -- Update password_last_changed
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
            RAISE NOTICE 'Error detail: %', SQLSTATE;
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
    IF v_current_hash IS NOT NULL THEN
        IF (crypt(v_new_password, v_current_hash) = v_current_hash) THEN
            RAISE NOTICE '✅ Password validation now WORKS for: %', v_new_password;
        ELSE
            RAISE NOTICE '❌ Password validation still FAILS';
            RAISE NOTICE 'Updated hash: %...', left(v_current_hash, 50);
        END IF;
    ELSE
        RAISE NOTICE '❌ Could not retrieve updated password hash';
    END IF;
    
    -- =============================================
    -- FINAL VERIFICATION
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Final Verification ---';
    
    -- Check current user state
    FOR v_constraint_info IN
        SELECT 
            uas.username,
            uas.account_locked,
            COALESCE(uas.failed_login_attempts, 0) as failed_attempts,
            uas.load_date,
            CASE WHEN uas.load_end_date IS NULL THEN 'ACTIVE' ELSE 'HISTORICAL' END as status
        FROM auth.user_auth_s uas
        WHERE uas.user_hk = v_user_hk
        ORDER BY uas.load_date DESC
        LIMIT 3
    LOOP
        RAISE NOTICE 'Record: % | Locked: % | Failed: % | Date: % | Status: %',
            v_constraint_info.username,
            v_constraint_info.account_locked,
            v_constraint_info.failed_attempts,
            v_constraint_info.load_date,
            v_constraint_info.status;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'INVESTIGATION COMPLETE';
    RAISE NOTICE 'Password should now be: %', v_new_password;
    RAISE NOTICE '==============================================';
    
END $$; 