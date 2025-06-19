-- =====================================================================================
-- Script: step_2_backup_procedures_fix_temporal_pattern.sql
-- Description: Fix Data Vault 2.0 temporal pattern violation in backup_mgmt.create_full_backup
-- Version: 1.1
-- Date: 2025-06-17
-- Author: One Vault Development Team
-- 
-- Purpose: Fix duplicate key violation in backup_mgmt.create_full_backup function
--          by implementing proper Data Vault 2.0 temporal patterns
-- 
-- Issue: Function was inserting two satellite records with same load_date causing
--        primary key violation on (backup_hk, load_date)
-- 
-- Solution: Use proper end-dating pattern with incremented timestamp for new record
-- =====================================================================================

-- Log the fix being applied
DO $$
BEGIN
    RAISE NOTICE 'Applying fix for backup_mgmt.create_full_backup Data Vault 2.0 temporal pattern violation';
    RAISE NOTICE 'Issue: Duplicate key violation on backup_execution_s primary key (backup_hk, load_date)';
    RAISE NOTICE 'Solution: Proper end-dating with incremented timestamp for completion record';
END $$;

-- Create fixed version of the full backup function
CREATE OR REPLACE FUNCTION backup_mgmt.create_full_backup(
    p_tenant_hk BYTEA DEFAULT NULL,
    p_backup_location TEXT DEFAULT '/backup/full/',
    p_storage_type VARCHAR(50) DEFAULT 'LOCAL',
    p_compression_enabled BOOLEAN DEFAULT true,
    p_verify_backup BOOLEAN DEFAULT true
) RETURNS TABLE (
    backup_id BYTEA,
    backup_status VARCHAR(20),
    backup_size_bytes BIGINT,
    duration_seconds INTEGER,
    verification_status VARCHAR(20),
    error_message TEXT
) AS $$
DECLARE
    v_backup_hk BYTEA;
    v_backup_bk VARCHAR(255);
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_duration INTEGER;
    v_backup_size BIGINT;
    v_compressed_size BIGINT;
    v_compression_ratio DECIMAL(5,2);
    v_checksum VARCHAR(128);
    v_verification_status VARCHAR(20) := 'PENDING';
    v_backup_status VARCHAR(20) := 'COMPLETED';
    v_error_msg TEXT := NULL;
    v_backup_filename VARCHAR(500);
    v_backup_scope VARCHAR(50);
    v_initial_load_date TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Initialize backup process
    v_start_time := CURRENT_TIMESTAMP;
    v_backup_scope := CASE WHEN p_tenant_hk IS NULL THEN 'SYSTEM' ELSE 'TENANT' END;
    v_backup_bk := 'FULL_BACKUP_' || 
                   COALESCE(encode(p_tenant_hk, 'hex'), 'SYSTEM') || '_' ||
                   to_char(v_start_time, 'YYYYMMDD_HH24MISS');
    v_backup_hk := util.hash_binary(v_backup_bk);
    v_backup_filename := v_backup_bk || '.backup';
    
    -- Store the initial load date for proper Data Vault 2.0 temporal tracking
    v_initial_load_date := util.current_load_date();
    
    -- Log backup start
    INSERT INTO backup_mgmt.backup_execution_h VALUES (
        v_backup_hk, v_backup_bk, p_tenant_hk, 
        v_initial_load_date, util.get_record_source()
    );
    
    INSERT INTO backup_mgmt.backup_execution_s VALUES (
        v_backup_hk, v_initial_load_date, NULL,
        util.hash_binary(v_backup_bk || 'STARTING'),
        'FULL', v_backup_scope, 'PG_BASEBACKUP',
        v_start_time, NULL, NULL, 'RUNNING',
        NULL, NULL, NULL,
        p_backup_location, v_backup_filename, p_storage_type,
        '7 years'::INTERVAL, 'STANDARD_7_YEAR', 
        (CURRENT_DATE + '7 years'::INTERVAL),
        'PENDING', NULL, 'SHA256', NULL, false,
        false, NULL, NULL,
        NULL, NULL, 0, 3,
        SESSION_USER, 5, NULL, NULL,
        util.get_record_source()
    );
    
    BEGIN
        -- Execute backup logic (would integrate with actual backup tools)
        -- This is a placeholder for actual backup execution
        
        -- Simulate backup execution time
        PERFORM pg_sleep(1);
        
        -- Calculate simulated backup metrics
        v_backup_size := (SELECT pg_database_size(current_database()));
        v_compressed_size := CASE WHEN p_compression_enabled 
                                 THEN ROUND(v_backup_size * 0.7) 
                                 ELSE v_backup_size END;
        v_compression_ratio := CASE WHEN p_compression_enabled 
                                   THEN ROUND(((v_backup_size - v_compressed_size)::DECIMAL / v_backup_size * 100), 2)
                                   ELSE 0 END;
        
        -- Generate simulated checksum
        v_checksum := encode(util.hash_binary(v_backup_bk || v_backup_size::text), 'hex');
        
        -- Set end time and duration
        v_end_time := CURRENT_TIMESTAMP;
        v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INTEGER;
        
        -- Perform backup verification if requested
        IF p_verify_backup THEN
            -- Simulate verification process
            PERFORM pg_sleep(0.5);
            v_verification_status := 'VERIFIED';
        ELSE
            v_verification_status := 'SKIPPED';
        END IF;
        
    EXCEPTION 
        WHEN OTHERS THEN
            v_backup_status := 'FAILED';
            v_error_msg := SQLERRM;
            v_verification_status := 'FAILED';
            v_end_time := CURRENT_TIMESTAMP;
            v_duration := EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INTEGER;
    END;
    
    -- Data Vault 2.0 Temporal Pattern: End-date the current record and insert new one
    -- Step 1: End-date the current satellite record
    UPDATE backup_mgmt.backup_execution_s 
    SET load_end_date = util.current_load_date()
    WHERE backup_hk = v_backup_hk AND load_end_date IS NULL;
    
    -- Step 2: Insert new satellite record with completion status using incremented timestamp
    INSERT INTO backup_mgmt.backup_execution_s VALUES (
        v_backup_hk, 
        util.current_load_date() + INTERVAL '1 microsecond', -- Ensure different timestamp
        NULL,
        util.hash_binary(v_backup_bk || v_backup_status),
        'FULL', v_backup_scope, 'PG_BASEBACKUP',
        v_start_time, v_end_time, v_duration, v_backup_status,
        v_backup_size, v_compressed_size, v_compression_ratio,
        p_backup_location, v_backup_filename, p_storage_type,
        '7 years'::INTERVAL, 'STANDARD_7_YEAR', 
        (CURRENT_DATE + '7 years'::INTERVAL),
        v_verification_status, CURRENT_TIMESTAMP, 'SHA256', v_checksum, 
        (v_verification_status = 'VERIFIED'),
        false, NULL, NULL,
        v_error_msg, NULL, 0, 3,
        SESSION_USER, 5, NULL, 
        jsonb_build_object(
            'compression_enabled', p_compression_enabled,
            'verification_requested', p_verify_backup,
            'execution_method', 'automated'
        ),
        util.get_record_source()
    );
    
    RETURN QUERY SELECT 
        v_backup_hk,
        v_backup_status,
        v_backup_size,
        v_duration,
        v_verification_status,
        v_error_msg;
        
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Log successful completion
DO $$
BEGIN
    RAISE NOTICE 'Successfully applied fix for backup_mgmt.create_full_backup function';
    RAISE NOTICE 'Function now follows proper Data Vault 2.0 temporal patterns';
    RAISE NOTICE 'Changes:';
    RAISE NOTICE '  1. Added v_initial_load_date variable to store first timestamp';
    RAISE NOTICE '  2. Use stored timestamp for initial hub and satellite inserts';
    RAISE NOTICE '  3. Proper end-dating of initial satellite record';
    RAISE NOTICE '  4. New satellite record with incremented timestamp (+1 microsecond)';
    RAISE NOTICE 'This eliminates the duplicate key violation on (backup_hk, load_date)';
END $$; 