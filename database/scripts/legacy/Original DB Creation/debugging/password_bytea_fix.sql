-- =============================================
-- Fix Password BYTEA vs TEXT Issue
-- The problem is bcrypt hashes are TEXT but stored as BYTEA
-- =============================================

DO $$
DECLARE
    v_user_hk BYTEA;
    v_current_hash_bytea BYTEA;
    v_current_hash_text TEXT;
    v_new_password TEXT := 'MyNewSecurePassword123';
    v_new_hash TEXT;
    v_column_type TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'INVESTIGATING BYTEA vs TEXT ISSUE';
    RAISE NOTICE '==============================================';
    
    -- Check the actual column type
    SELECT data_type 
    INTO v_column_type
    FROM information_schema.columns 
    WHERE table_schema = 'auth' 
    AND table_name = 'user_auth_s' 
    AND column_name = 'password_hash';
    
    RAISE NOTICE 'password_hash column type: %', v_column_type;
    
    -- Get user info
    SELECT 
        uh.user_hk,
        uas.password_hash,
        uas.password_hash::text
    INTO 
        v_user_hk,
        v_current_hash_bytea,
        v_current_hash_text
    FROM auth.user_h uh
    JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE uas.username = 'travisdwoodward72@gmail.com'
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    RAISE NOTICE 'User HK: %', encode(v_user_hk, 'hex');
    RAISE NOTICE 'Hash as BYTEA: %...', left(v_current_hash_bytea::text, 50);
    RAISE NOTICE 'Hash as TEXT: %...', left(v_current_hash_text, 50);
    
    -- Try to convert bytea back to proper text
    DECLARE
        v_converted_hash TEXT;
    BEGIN
        -- Convert bytea to text (decode the hex)
        v_converted_hash := convert_from(v_current_hash_bytea, 'UTF8');
        RAISE NOTICE 'Converted hash: %...', left(v_converted_hash, 50);
        
        -- Test password against converted hash
        IF (crypt(v_new_password, v_converted_hash) = v_converted_hash) THEN
            RAISE NOTICE '✅ Password validation WORKS with converted hash!';
        ELSE
            RAISE NOTICE '❌ Password validation still fails with converted hash';
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Error converting bytea to text: %', SQLERRM;
    END;
    
    -- =============================================
    -- FIX: Store hash as TEXT, not BYTEA
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Fixing Storage Issue ---';
    
    -- Generate new hash
    v_new_hash := crypt(v_new_password, gen_salt('bf', 12));
    RAISE NOTICE 'Generated new hash: %...', left(v_new_hash, 50);
    
    -- Store it properly (the column might expect text stored as bytea)
    BEGIN
        -- End-date current record
        UPDATE auth.user_auth_s
        SET load_end_date = util.current_load_date()
        WHERE user_hk = v_user_hk
        AND load_end_date IS NULL;
        
        -- Insert new record with hash stored correctly
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
            util.hash_binary(username || 'PWD_BYTEA_FIX_' || CURRENT_TIMESTAMP::text),
            username,
            convert_to(v_new_hash, 'UTF8'), -- Store text as bytea properly
            password_salt,
            last_login_date,
            CURRENT_TIMESTAMP,
            0, -- Reset failed attempts
            FALSE, -- Unlock account
            NULL, -- Clear lockout time
            FALSE,
            util.get_record_source()
        FROM auth.user_auth_s
        WHERE user_hk = v_user_hk
        AND load_end_date = util.current_load_date()
        ORDER BY load_date DESC
        LIMIT 1;
        
        RAISE NOTICE '✅ Password stored with proper text-to-bytea conversion';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Error storing password: % - %', SQLSTATE, SQLERRM;
    END;
    
    -- =============================================
    -- TEST THE FIX
    -- =============================================
    RAISE NOTICE '';
    RAISE NOTICE '--- Testing Fixed Password ---';
    
    -- Get the newly stored hash
    SELECT 
        uas.password_hash,
        convert_from(uas.password_hash, 'UTF8') as hash_as_text
    INTO 
        v_current_hash_bytea,
        v_current_hash_text
    FROM auth.user_auth_s uas
    WHERE uas.user_hk = v_user_hk
    AND uas.load_end_date IS NULL
    ORDER BY uas.load_date DESC
    LIMIT 1;
    
    RAISE NOTICE 'New stored hash (as text): %...', left(v_current_hash_text, 50);
    
    -- Test password validation
    IF v_current_hash_text IS NOT NULL THEN
        IF (crypt(v_new_password, v_current_hash_text) = v_current_hash_text) THEN
            RAISE NOTICE '✅ Password validation now WORKS!';
            RAISE NOTICE '✅ BYTEA storage issue FIXED';
        ELSE
            RAISE NOTICE '❌ Password validation still fails';
        END IF;
    ELSE
        RAISE NOTICE '❌ Could not retrieve converted hash';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'BYTEA FIX COMPLETE';
    RAISE NOTICE 'Password: %', v_new_password;
    RAISE NOTICE 'Storage: TEXT converted to BYTEA with convert_to()';
    RAISE NOTICE 'Validation: BYTEA converted to TEXT with convert_from()';
    RAISE NOTICE '==============================================';
    
END $$; 