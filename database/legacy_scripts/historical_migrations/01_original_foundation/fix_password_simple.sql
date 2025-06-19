    -- Corrected Password Fix Script
    -- Fixes the ambiguous 'oid' column reference error
    -- =============================================

    DO $$
    DECLARE
        v_user_hk BYTEA;
        v_current_hash TEXT;
        v_new_password TEXT := 'MyNewSecurePassword123';
        v_new_hash TEXT;
        v_count INTEGER;
        v_constraint_name TEXT;
    BEGIN
        RAISE NOTICE '';
        RAISE NOTICE '==============================================';
        RAISE NOTICE 'PASSWORD FIX - CORRECTED VERSION';
        RAISE NOTICE '==============================================';
        
        -- Get user info
        SELECT 
            uh.user_hk,
            uas.password_hash::text
        INTO 
            v_user_hk,
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
        -- INVESTIGATE CONSTRAINT ISSUE (FIXED)
        -- =============================================
        RAISE NOTICE '';
        RAISE NOTICE '--- Constraint Investigation (Fixed Query) ---';
        
        -- Check unique constraints with proper approach
        SELECT COUNT(*)
        INTO v_count
        FROM information_schema.table_constraints tc
        WHERE tc.table_schema = 'auth'
        AND tc.table_name = 'user_auth_s'
        AND tc.constraint_type = 'UNIQUE';
        
        RAISE NOTICE 'Found % unique constraints on auth.user_auth_s', v_count;
        
        -- Show constraint details using information_schema (safer approach)
        FOR v_constraint_name IN
            SELECT tc.constraint_name
            FROM information_schema.table_constraints tc
            WHERE tc.table_schema = 'auth'
            AND tc.table_name = 'user_auth_s'
            AND tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY')
            ORDER BY tc.constraint_name
        LOOP
            RAISE NOTICE 'Constraint: %', v_constraint_name;
        END LOOP;
        
        -- Check for active records that might cause constraint issues
        SELECT COUNT(*)
        INTO v_count
        FROM auth.user_auth_s
        WHERE username = 'travisdwoodward72@gmail.com'
        AND load_end_date IS NULL;
        
        RAISE NOTICE 'Active records for username: %', v_count;
        
        IF v_count > 1 THEN
            RAISE NOTICE 'WARNING: Multiple active records found - this may cause constraint violations';
        END IF;
        
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
            
            -- Update using proper Data Vault 2.0 historization
            BEGIN
                -- End-date current record FIRST
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
                    util.hash_binary(username || 'PWD_UPDATE_' || CURRENT_TIMESTAMP::text),
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
        
        RAISE NOTICE '';
        RAISE NOTICE '==============================================';
        RAISE NOTICE 'CORRECTED SCRIPT COMPLETE';
        RAISE NOTICE 'Password should now be: %', v_new_password;
        RAISE NOTICE '==============================================';
        
    END $$; 