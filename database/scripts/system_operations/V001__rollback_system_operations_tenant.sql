-- =============================================================================
-- Rollback: V001__rollback_system_operations_tenant.sql
-- Description: Safely rollback System Operations Tenant creation
-- Author: OneVault Development Team
-- Date: 2024-12-19
-- Dependencies: Must have util.migration_log table
-- Version: V001 ROLLBACK
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '🔄 Starting rollback V001: System Operations Tenant';
    
    -- Ensure migration log table exists
    CREATE TABLE IF NOT EXISTS util.migration_log (
        migration_version VARCHAR(10) NOT NULL,
        migration_name VARCHAR(200) NOT NULL,
        migration_type VARCHAR(20) NOT NULL, -- FORWARD, ROLLBACK
        started_at TIMESTAMP WITH TIME ZONE NOT NULL,
        completed_at TIMESTAMP WITH TIME ZONE,
        executed_by VARCHAR(100) NOT NULL,
        status VARCHAR(20) DEFAULT 'RUNNING', -- RUNNING, SUCCESS, FAILED
        error_message TEXT,
        PRIMARY KEY (migration_version, migration_type)
    );
    
    INSERT INTO util.migration_log (
        migration_version,
        migration_name,
        migration_type,
        started_at,
        executed_by
    ) VALUES (
        'V001',
        'rollback_system_operations_tenant',
        'ROLLBACK',
        CURRENT_TIMESTAMP,
        SESSION_USER
    ) ON CONFLICT (migration_version, migration_type) DO NOTHING;
END $$;

-- 1. PRE-ROLLBACK VALIDATION
DO $$
DECLARE
    v_system_tenant_hk BYTEA := '\x0000000000000000000000000000000000000000000000000000000000000001';
    v_dependent_users INTEGER := 0;
    v_dependent_sessions INTEGER := 0;
    v_dependent_registrations INTEGER := 0;
    v_system_tenant_exists BOOLEAN := FALSE;
BEGIN
    -- Check if system tenant exists
    SELECT EXISTS (
        SELECT 1 FROM auth.tenant_h 
        WHERE tenant_hk = v_system_tenant_hk
    ) INTO v_system_tenant_exists;
    
    IF NOT v_system_tenant_exists THEN
        RAISE NOTICE 'ℹ️  System Operations Tenant does not exist - rollback not needed';
        RETURN;
    END IF;
    
    -- Check for dependent users
    SELECT COUNT(*) INTO v_dependent_users
    FROM auth.user_h 
    WHERE tenant_hk = v_system_tenant_hk;
    
    -- Check for dependent sessions
    SELECT COUNT(*) INTO v_dependent_sessions
    FROM auth.session_h 
    WHERE tenant_hk = v_system_tenant_hk;
    
    -- Check for dependent tenant registration requests (if raw/staging tables exist)
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_schema = 'raw' AND table_name = 'tenant_registration_request_r') THEN
            EXECUTE format('SELECT COUNT(*) FROM raw.tenant_registration_request_r WHERE tenant_hk = $1') 
            INTO v_dependent_registrations USING v_system_tenant_hk;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_dependent_registrations := 0;
    END;
    
    RAISE NOTICE '🔍 Rollback Validation:';
    RAISE NOTICE '   System Tenant Exists: %', CASE WHEN v_system_tenant_exists THEN 'YES' ELSE 'NO' END;
    RAISE NOTICE '   Dependent Users: %', v_dependent_users;
    RAISE NOTICE '   Dependent Sessions: %', v_dependent_sessions;
    RAISE NOTICE '   Dependent Registrations: %', v_dependent_registrations;
    
    IF v_dependent_users > 0 THEN
        RAISE WARNING '⚠️  Found % dependent users - rollback will remove system admin accounts', v_dependent_users;
    END IF;
    
    IF v_dependent_sessions > 0 THEN
        RAISE WARNING '⚠️  Found % dependent sessions - rollback will invalidate active sessions', v_dependent_sessions;
    END IF;
    
    IF v_dependent_registrations > 0 THEN
        RAISE WARNING '⚠️  Found % dependent registration requests - consider data backup', v_dependent_registrations;
    END IF;
    
    -- Allow rollback to continue with warnings
    RAISE NOTICE '📋 Pre-rollback validation completed - proceeding with rollback';
END $$;

-- 2. OPTIONAL DATA BACKUP
DO $$
DECLARE
    v_system_tenant_hk BYTEA := '\x0000000000000000000000000000000000000000000000000000000000000001';
    v_backup_timestamp TEXT := to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS');
    v_backup_schema TEXT := 'system_backup_' || v_backup_timestamp;
    v_tenant_records INTEGER := 0;
    v_profile_records INTEGER := 0;
    v_role_records INTEGER := 0;
BEGIN
    -- Create backup schema
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', v_backup_schema);
    
    RAISE NOTICE '💾 Creating backup in schema: %', v_backup_schema;
    
    -- Backup tenant hub data
    IF EXISTS (SELECT 1 FROM auth.tenant_h WHERE tenant_hk = v_system_tenant_hk) THEN
        EXECUTE format('CREATE TABLE %I.tenant_h_backup AS SELECT * FROM auth.tenant_h WHERE tenant_hk = $1', 
                      v_backup_schema) USING v_system_tenant_hk;
        
        EXECUTE format('SELECT COUNT(*) FROM %I.tenant_h_backup', v_backup_schema) INTO v_tenant_records;
        RAISE NOTICE '   Backed up % tenant records', v_tenant_records;
    END IF;
    
    -- Backup tenant profile data
    IF EXISTS (SELECT 1 FROM auth.tenant_profile_s WHERE tenant_hk = v_system_tenant_hk) THEN
        EXECUTE format('CREATE TABLE %I.tenant_profile_s_backup AS SELECT * FROM auth.tenant_profile_s WHERE tenant_hk = $1', 
                      v_backup_schema) USING v_system_tenant_hk;
        
        EXECUTE format('SELECT COUNT(*) FROM %I.tenant_profile_s_backup', v_backup_schema) INTO v_profile_records;
        RAISE NOTICE '   Backed up % profile records', v_profile_records;
    END IF;
    
    -- Backup system role data
    BEGIN
        EXECUTE format('CREATE TABLE %I.role_h_backup AS 
                       SELECT rh.* FROM auth.role_h rh 
                       JOIN auth.role_profile_s rps ON rh.role_hk = rps.role_hk 
                       WHERE rps.is_system_role = true AND rps.load_end_date IS NULL', 
                      v_backup_schema);
        
        EXECUTE format('CREATE TABLE %I.role_profile_s_backup AS 
                       SELECT * FROM auth.role_profile_s 
                       WHERE is_system_role = true AND load_end_date IS NULL', 
                      v_backup_schema);
        
        EXECUTE format('SELECT COUNT(*) FROM %I.role_h_backup', v_backup_schema) INTO v_role_records;
        RAISE NOTICE '   Backed up % role records', v_role_records;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠️  Role backup failed: %', SQLERRM;
    END;
    
    RAISE NOTICE '✅ Backup completed in schema: %', v_backup_schema;
    RAISE NOTICE 'ℹ️  To restore: Copy data back from backup schema before dropping';
END $$;

-- 3. SAFE OBJECT REMOVAL

-- Remove utility function
DO $$
BEGIN
    DROP FUNCTION IF EXISTS util.get_system_operations_tenant_hk() CASCADE;
    RAISE NOTICE '🗑️  Removed function: util.get_system_operations_tenant_hk';
END $$;

-- Remove indexes (gracefully)
DO $$
BEGIN
    DROP INDEX IF EXISTS auth.idx_tenant_h_system_lookup;
    DROP INDEX IF EXISTS auth.idx_tenant_profile_s_system_active;
    RAISE NOTICE '🗑️  Removed system operations indexes';
END $$;

-- Remove system role data (gracefully)
DO $$
DECLARE
    v_system_role_hk BYTEA;
    v_deleted_profiles INTEGER := 0;
    v_deleted_roles INTEGER := 0;
BEGIN
    -- Get system role hash key
    SELECT rh.role_hk INTO v_system_role_hk
    FROM auth.role_h rh
    JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
    WHERE rds.role_name = 'System Operations Administrator'
    AND rds.is_system_role = true
    AND rds.load_end_date IS NULL
    LIMIT 1;
    
    IF v_system_role_hk IS NOT NULL THEN
        -- Remove role definitions
        DELETE FROM auth.role_definition_s 
        WHERE role_hk = v_system_role_hk;
        GET DIAGNOSTICS v_deleted_profiles = ROW_COUNT;
        
        -- Remove role hub
        DELETE FROM auth.role_h 
        WHERE role_hk = v_system_role_hk;
        GET DIAGNOSTICS v_deleted_roles = ROW_COUNT;
        
        RAISE NOTICE '🗑️  Removed % role profiles and % role hubs', v_deleted_profiles, v_deleted_roles;
    ELSE
        RAISE NOTICE 'ℹ️  System role not found - skipping removal';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️  Role removal failed: %', SQLERRM;
END $$;

-- Remove system tenant data (gracefully)
DO $$
DECLARE
    v_system_tenant_hk BYTEA := '\x0000000000000000000000000000000000000000000000000000000000000001';
    v_deleted_profiles INTEGER := 0;
    v_deleted_tenants INTEGER := 0;
BEGIN
    -- Remove tenant profiles
    DELETE FROM auth.tenant_profile_s 
    WHERE tenant_hk = v_system_tenant_hk;
    GET DIAGNOSTICS v_deleted_profiles = ROW_COUNT;
    
    -- Remove tenant hub
    DELETE FROM auth.tenant_h 
    WHERE tenant_hk = v_system_tenant_hk;
    GET DIAGNOSTICS v_deleted_tenants = ROW_COUNT;
    
    RAISE NOTICE '🗑️  Removed % tenant profiles and % tenant hubs', v_deleted_profiles, v_deleted_tenants;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️  Tenant removal failed: %', SQLERRM;
END $$;

-- 4. ROLLBACK VALIDATION AND COMPLETION
DO $$
DECLARE
    v_system_tenant_hk BYTEA := '\x0000000000000000000000000000000000000000000000000000000000000001';
    v_system_tenant_exists BOOLEAN := FALSE;
    v_system_profile_exists BOOLEAN := FALSE;
    v_system_role_exists BOOLEAN := FALSE;
    v_system_function_exists BOOLEAN := FALSE;
    v_system_indexes_exist INTEGER := 0;
BEGIN
    -- Validate system tenant removal
    SELECT EXISTS (
        SELECT 1 FROM auth.tenant_h 
        WHERE tenant_hk = v_system_tenant_hk
    ) INTO v_system_tenant_exists;
    
    -- Validate system profile removal
    SELECT EXISTS (
        SELECT 1 FROM auth.tenant_profile_s 
        WHERE tenant_hk = v_system_tenant_hk 
        AND load_end_date IS NULL
        AND tenant_name = 'System Operations Tenant'
    ) INTO v_system_profile_exists;
    
    -- Validate system role removal
    SELECT EXISTS (
        SELECT 1 FROM auth.role_h rh
        JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
        WHERE rds.role_name = 'System Operations Administrator'
        AND rds.is_system_role = true
        AND rds.load_end_date IS NULL
    ) INTO v_system_role_exists;
    
    -- Validate utility function removal
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'util' 
        AND p.proname = 'get_system_operations_tenant_hk'
    ) INTO v_system_function_exists;
    
    -- Count remaining indexes
    SELECT COUNT(*) INTO v_system_indexes_exist
    FROM pg_indexes 
    WHERE indexname IN ('idx_tenant_h_system_lookup', 'idx_tenant_profile_s_system_active');
    
    -- Report rollback validation results
    RAISE NOTICE '📊 Rollback V001 Validation Results:';
    RAISE NOTICE '   System Tenant Removed: %', CASE WHEN NOT v_system_tenant_exists THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE '   System Profile Removed: %', CASE WHEN NOT v_system_profile_exists THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE '   System Role Removed: %', CASE WHEN NOT v_system_role_exists THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE '   Utility Function Removed: %', CASE WHEN NOT v_system_function_exists THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE '   Indexes Removed: % remaining (should be 0)', v_system_indexes_exist;
    
    -- Validate overall rollback success
    IF NOT v_system_tenant_exists AND NOT v_system_profile_exists AND NOT v_system_role_exists 
       AND NOT v_system_function_exists AND v_system_indexes_exist = 0 THEN
        
        -- Update migration log
        UPDATE util.migration_log 
        SET completed_at = CURRENT_TIMESTAMP,
            status = 'SUCCESS'
        WHERE migration_version = 'V001' 
        AND migration_type = 'ROLLBACK';
        
        RAISE NOTICE '🎉 Rollback V001 completed successfully!';
        RAISE NOTICE '📋 System Operations Tenant has been completely removed';
        RAISE NOTICE '💾 Backup data is available in timestamped schema';
        
    ELSE
        -- Log rollback failure
        UPDATE util.migration_log 
        SET completed_at = CURRENT_TIMESTAMP,
            status = 'FAILED',
            error_message = 'Rollback validation failed - some objects still exist'
        WHERE migration_version = 'V001' 
        AND migration_type = 'ROLLBACK';
        
        RAISE EXCEPTION '❌ Rollback V001 validation failed - some objects still exist!';
    END IF;
END $$;

-- End of Rollback V001
DO $$
BEGIN
    RAISE NOTICE '✅ Rollback V001__rollback_system_operations_tenant.sql completed';
END $$; 