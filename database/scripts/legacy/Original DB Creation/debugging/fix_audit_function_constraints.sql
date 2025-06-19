-- =============================================
-- fix_audit_function_constraints.sql
-- Fixes the VARCHAR constraint issue in audit tables
-- Error: "value too long for type character varying(10)"
-- =============================================

-- Check current audit table constraints
SELECT 
    table_name,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'audit'
ORDER BY table_name, ordinal_position;

-- Check what's causing the constraint violation
DO $$
DECLARE
    v_test_operation VARCHAR(50) := 'LOGIN_ATTEMPT';
    v_test_actor VARCHAR(255) := 'travisdwoodward72@gmail.com';
BEGIN
    RAISE NOTICE 'Testing data lengths:';
    RAISE NOTICE 'Operation length: % chars - "%"', LENGTH(v_test_operation), v_test_operation;
    RAISE NOTICE 'Actor length: % chars - "%"', LENGTH(v_test_actor), v_test_actor;
END $$;

-- Fix any VARCHAR constraints that are too small
DO $$
BEGIN
    -- Check if operation column is too small (likely the issue)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'audit' 
        AND table_name = 'audit_detail_s' 
        AND column_name = 'operation'
        AND character_maximum_length < 50
    ) THEN
        ALTER TABLE audit.audit_detail_s 
        ALTER COLUMN operation TYPE VARCHAR(100);
        RAISE NOTICE 'Extended audit_detail_s.operation to VARCHAR(100)';
    END IF;
    
    -- Check if changed_by column is too small
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'audit' 
        AND table_name = 'audit_detail_s' 
        AND column_name = 'changed_by'
        AND character_maximum_length < 255
    ) THEN
        ALTER TABLE audit.audit_detail_s 
        ALTER COLUMN changed_by TYPE VARCHAR(255);
        RAISE NOTICE 'Extended audit_detail_s.changed_by to VARCHAR(255)';
    END IF;
    
    -- Check if table_name column is too small
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'audit' 
        AND table_name = 'audit_detail_s' 
        AND column_name = 'table_name'
        AND character_maximum_length < 100
    ) THEN
        ALTER TABLE audit.audit_detail_s 
        ALTER COLUMN table_name TYPE VARCHAR(100);
        RAISE NOTICE 'Extended audit_detail_s.table_name to VARCHAR(100)';
    END IF;
END $$;

-- Test the function again
DO $$
DECLARE
    v_result JSONB;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== TESTING FIXED util.log_audit_event FUNCTION ===';
    
    SELECT util.log_audit_event(
        'LOGIN_ATTEMPT',
        'auth.user_auth_s',
        'travisdwoodward72@gmail.com',
        'travisdwoodward72@gmail.com',
        jsonb_build_object(
            'ip_address', '192.168.1.100',
            'user_agent', 'Mozilla/5.0 Test',
            'timestamp', CURRENT_TIMESTAMP
        )
    ) INTO v_result;
    
    RAISE NOTICE 'Test result: %', v_result;
    
    IF (v_result->>'success')::BOOLEAN THEN
        RAISE NOTICE 'SUCCESS: Audit function is now working correctly!';
    ELSE
        RAISE NOTICE 'ERROR: %', v_result->>'error_message';
    END IF;
    RAISE NOTICE '';
END $$; 