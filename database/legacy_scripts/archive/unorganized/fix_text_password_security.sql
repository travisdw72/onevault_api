-- ============================================================================
-- CRITICAL SECURITY FIX: Remove Plaintext Passwords
-- ============================================================================

DO $$ BEGIN
    RAISE NOTICE '🚨 CRITICAL SECURITY FIX: Removing plaintext passwords...';
END $$;

-- STEP 1: IMMEDIATE DATA SANITIZATION
UPDATE raw.login_details_s 
SET password_indicator = 'PASSWORD_PROVIDED'
WHERE password_indicator NOT IN ('PASSWORD_PROVIDED', 'HASH_PROVIDED', 'NO_PASSWORD');

-- STEP 2: ADD SECURITY CONSTRAINTS
ALTER TABLE raw.login_details_s 
ADD CONSTRAINT chk_password_indicator_secure 
CHECK (password_indicator IN ('PASSWORD_PROVIDED', 'HASH_PROVIDED', 'NO_PASSWORD', 'INVALID_FORMAT'));

ALTER TABLE raw.login_attempt_s 
ADD CONSTRAINT chk_password_indicator_secure 
CHECK (password_indicator IN ('PASSWORD_PROVIDED', 'HASH_PROVIDED', 'NO_PASSWORD', 'INVALID_FORMAT'));

-- STEP 3: VERIFICATION
DO $$ 
DECLARE
    v_plaintext_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_plaintext_count
    FROM raw.login_details_s 
    WHERE password_indicator NOT IN ('PASSWORD_PROVIDED', 'HASH_PROVIDED', 'NO_PASSWORD', 'INVALID_FORMAT');
    
    RAISE NOTICE '🔍 Remaining plaintext passwords: %', v_plaintext_count;
    
    IF v_plaintext_count = 0 THEN
        RAISE NOTICE '✅ SUCCESS: Security vulnerability fixed!';
    ELSE
        RAISE NOTICE '❌ WARNING: % plaintext passwords still exist!', v_plaintext_count;
    END IF;
END $$;