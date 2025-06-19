-- =============================================
-- METADATA INFRASTRUCTURE FIX FOR PROJECT GOAL 3
-- =============================================
-- This script creates the missing metadata tables and functions that are required
-- for the authentication system to work properly.

-- =============================================
-- Step 1: Create metadata.record_source table
-- =============================================

-- Create the record_source table with the column name that util.get_record_source() expects
CREATE TABLE IF NOT EXISTS metadata.record_source (
    record_source_hk BYTEA PRIMARY KEY,
    record_source_code VARCHAR(50) NOT NULL UNIQUE,  -- Using record_source_code as expected by util.get_record_source()
    record_source_name VARCHAR(100),                 -- Also include record_source_name for compatibility
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) DEFAULT 'system',
    CONSTRAINT valid_record_source_code CHECK (record_source_code ~ '^[a-z_]+$')
);

-- Create a procedure to manage record source insertion
CREATE OR REPLACE PROCEDURE metadata.upsert_record_source(
    p_record_source_code VARCHAR(50),
    p_record_source_name VARCHAR(100),
    p_description TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert or update the record source
    INSERT INTO metadata.record_source (
        record_source_hk,
        record_source_code,
        record_source_name,
        description,
        load_date,
        record_source
    )
    VALUES (
        util.hash_binary(p_record_source_code),
        p_record_source_code,
        p_record_source_name,
        p_description,
        util.current_load_date(),
        'system'
    )
    ON CONFLICT (record_source_hk) 
    DO UPDATE SET
        record_source_name = EXCLUDED.record_source_name,
        description = EXCLUDED.description,
        load_date = util.current_load_date();
END;
$$;

-- =============================================
-- Step 2: Initialize standard record sources
-- =============================================

-- Insert the standard record sources that the system expects
CALL metadata.upsert_record_source(
    'web_application', 
    'Web Application', 
    'Main web application interface for user interactions'
);

CALL metadata.upsert_record_source(
    'mobile_app', 
    'Mobile Application', 
    'Mobile application interface'
);

CALL metadata.upsert_record_source(
    'api', 
    'API Access', 
    'Direct API access for integrations'
);

CALL metadata.upsert_record_source(
    'system', 
    'System Process', 
    'Internal system processes and automated tasks'
);

CALL metadata.upsert_record_source(
    'migration', 
    'Data Migration', 
    'Data migration and import processes'
);

-- =============================================
-- Step 3: Verify the setup
-- =============================================

-- Test that util.get_record_source() works now
CREATE OR REPLACE FUNCTION util.test_record_source()
RETURNS TEXT AS $$
DECLARE
    v_record_source VARCHAR(100);
BEGIN
    v_record_source := util.get_record_source();
    
    IF v_record_source IS NOT NULL THEN
        RETURN 'SUCCESS: Record source function working. Returns: ' || v_record_source;
    ELSE
        RETURN 'ERROR: Record source function returned NULL';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RETURN 'ERROR: ' || SQLSTATE || ' - ' || SQLERRM;
END $$ LANGUAGE plpgsql;

-- =============================================
-- Step 4: Verification and Status
-- =============================================

DO $$ 
DECLARE
    v_count INTEGER;
BEGIN
    -- Check if record sources were created
    SELECT COUNT(*) INTO v_count FROM metadata.record_source;
    
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'METADATA SETUP COMPLETE!';
    RAISE NOTICE 'Record sources created: %', v_count;
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Test the setup with:';
    RAISE NOTICE '1. SELECT * FROM metadata.record_source;';
    RAISE NOTICE '2. SELECT util.test_record_source();';
    RAISE NOTICE '3. SELECT util.test_registration();';
    RAISE NOTICE '===========================================';
END $$; 