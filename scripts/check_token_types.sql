-- ========================================================================
-- CHECK VALID API TOKEN TYPES
-- ========================================================================
-- Investigates the check constraint on api_token_s.token_type to see valid values

DO $$
DECLARE
    v_constraint_definition TEXT;
BEGIN
    RAISE NOTICE '🔍 === CHECKING API TOKEN TYPE CONSTRAINTS ===';
    RAISE NOTICE '';
    
    -- Get the check constraint definition
    SELECT pg_get_constraintdef(c.oid) INTO v_constraint_definition
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE n.nspname = 'auth'
    AND t.relname = 'api_token_s'
    AND c.conname = 'chk_token_type';
    
    IF v_constraint_definition IS NOT NULL THEN
        RAISE NOTICE '✅ Found token_type constraint:';
        RAISE NOTICE '%', v_constraint_definition;
        RAISE NOTICE '';
    ELSE
        RAISE NOTICE '❌ No chk_token_type constraint found!';
        RAISE NOTICE '';
    END IF;
    
    -- Also check if there are any existing tokens to see what types are used
    RAISE NOTICE '📊 Checking existing API tokens for valid types...';
    
    PERFORM 1 FROM information_schema.tables 
    WHERE table_schema = 'auth' AND table_name = 'api_token_s';
    
    IF FOUND THEN
        RAISE NOTICE '✅ Found api_token_s table, checking existing token types...';
        
        -- Check if there are any existing tokens
        IF EXISTS (SELECT 1 FROM auth.api_token_s WHERE load_end_date IS NULL) THEN
            RAISE NOTICE '📋 Existing token types in database:';
            FOR v_constraint_definition IN 
                SELECT DISTINCT token_type 
                FROM auth.api_token_s 
                WHERE load_end_date IS NULL
                ORDER BY token_type
            LOOP
                RAISE NOTICE '   • %', v_constraint_definition;
            END LOOP;
        ELSE
            RAISE NOTICE '📋 No existing tokens found in database';
        END IF;
        
    ELSE
        RAISE NOTICE '❌ api_token_s table not found!';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍 === CONSTRAINT CHECK COMPLETE ===';
    
END $$;

-- Also show all constraints on the api_token_s table
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(c.oid) as constraint_definition
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE n.nspname = 'auth'
AND t.relname = 'api_token_s'
AND contype = 'c'  -- check constraints only
ORDER BY conname; 