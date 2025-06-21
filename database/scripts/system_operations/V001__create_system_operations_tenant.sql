-- =============================================================================
-- Migration: V001__create_system_operations_tenant.sql
-- Description: Create System Operations Tenant for multi-tenant Data Vault 2.0 platform
-- Author: OneVault Development Team
-- Date: 2024-12-19
-- Dependencies: auth schema, util functions, tenant isolation framework
-- Version: V001
-- =============================================================================

-- Migration Metadata Logging
DO $$
BEGIN
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
        'create_system_operations_tenant',
        'FORWARD',
        CURRENT_TIMESTAMP,
        SESSION_USER
    ) ON CONFLICT (migration_version, migration_type) DO NOTHING;
    
    RAISE NOTICE '🚀 Starting migration V001: System Operations Tenant';
END $$;

-- 1. PREREQUISITE VALIDATION (Backwards Compatible)
DO $$
DECLARE
    v_auth_schema_exists BOOLEAN := FALSE;
    v_util_functions_exist BOOLEAN := FALSE;
    v_tenant_table_exists BOOLEAN := FALSE;
BEGIN
    -- Check auth schema exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.schemata 
        WHERE schema_name = 'auth'
    ) INTO v_auth_schema_exists;
    
    -- Check util functions exist
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'util' AND p.proname = 'hash_binary'
    ) INTO v_util_functions_exist;
    
    -- Check tenant_h table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'auth' AND table_name = 'tenant_h'
    ) INTO v_tenant_table_exists;
    
    RAISE NOTICE '📋 Prerequisites Check:';
    RAISE NOTICE '   Auth Schema: %', CASE WHEN v_auth_schema_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    RAISE NOTICE '   Util Functions: %', CASE WHEN v_util_functions_exist THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    RAISE NOTICE '   Tenant Table: %', CASE WHEN v_tenant_table_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    
    IF NOT v_auth_schema_exists THEN
        RAISE EXCEPTION '❌ Prerequisites failed: auth schema is required';
    END IF;
    
    IF NOT v_util_functions_exist THEN
        RAISE EXCEPTION '❌ Prerequisites failed: util.hash_binary function is required';
    END IF;
    
    IF NOT v_tenant_table_exists THEN
        RAISE EXCEPTION '❌ Prerequisites failed: auth.tenant_h table is required';
    END IF;
    
    RAISE NOTICE '✅ All prerequisites validated successfully';
END $$;

-- 2. SYSTEM OPERATIONS TENANT CREATION (Idempotent)
DO $$
DECLARE
    v_system_tenant_hk BYTEA := '\x0000000000000000000000000000000000000000000000000000000000000001';
    v_system_tenant_bk VARCHAR(255) := 'SYSTEM_OPERATIONS';
    v_existing_tenant_count INTEGER;
BEGIN
    -- Check if system operations tenant already exists
    SELECT COUNT(*) INTO v_existing_tenant_count
    FROM auth.tenant_h 
    WHERE tenant_hk = v_system_tenant_hk 
    OR tenant_bk = v_system_tenant_bk;
    
    IF v_existing_tenant_count > 0 THEN
        RAISE NOTICE 'ℹ️  System Operations Tenant already exists - skipping creation';
    ELSE
        -- Create system operations tenant hub
        INSERT INTO auth.tenant_h (
            tenant_hk,
            tenant_bk,
            load_date,
            record_source
        ) VALUES (
            v_system_tenant_hk,
            v_system_tenant_bk,
            util.current_load_date(),
            'SYSTEM_MIGRATION_V001'
        );
        
        RAISE NOTICE '✅ Created System Operations Tenant Hub';
    END IF;
END $$;

-- 3. SYSTEM TENANT PROFILE SATELLITE (Idempotent)
DO $$
DECLARE
    v_system_tenant_hk BYTEA := '\x0000000000000000000000000000000000000000000000000000000000000001';
    v_existing_profile_count INTEGER;
    v_hash_diff BYTEA;
BEGIN
    -- Check if active profile already exists
    SELECT COUNT(*) INTO v_existing_profile_count
    FROM auth.tenant_profile_s 
    WHERE tenant_hk = v_system_tenant_hk 
    AND load_end_date IS NULL;
    
    IF v_existing_profile_count > 0 THEN
        RAISE NOTICE 'ℹ️  System Operations Tenant Profile already exists - skipping creation';
    ELSE
        -- Generate hash_diff for profile data
        v_hash_diff := util.hash_binary(
            'System Operations Tenant' || 
            'system.operations@onevault.tech' ||
            'Internal system operations and pre-registration activities' ||
            'true'
        );
        
        -- Create system operations tenant profile (using only existing columns)
        INSERT INTO auth.tenant_profile_s (
            tenant_hk,
            load_date,
            load_end_date,
            hash_diff,
            tenant_name,
            tenant_description,
            contact_email,
            is_active,
            subscription_level,
            max_users,
            record_source
        ) VALUES (
            v_system_tenant_hk,
            util.current_load_date(),
            NULL,
            v_hash_diff,
            'System Operations Tenant',
            'Internal system operations and pre-registration activities',
            'system.operations@onevault.tech',
            true,
            'enterprise',
            999,
            'SYSTEM_MIGRATION_V001'
        );
        
        RAISE NOTICE '✅ Created System Operations Tenant Profile';
    END IF;
END $$;

-- 4. SYSTEM OPERATIONS ROLE CREATION (Idempotent)
DO $$
DECLARE
    v_system_tenant_hk BYTEA := '\x0000000000000000000000000000000000000000000000000000000000000001';
    v_system_ops_role_hk BYTEA;
    v_system_ops_role_bk VARCHAR(255) := 'SYSTEM_OPERATIONS_ADMIN';
    v_existing_role_count INTEGER;
BEGIN
    -- Generate system operations role hash key
    v_system_ops_role_hk := util.hash_binary(v_system_ops_role_bk);
    
    -- Check if role already exists
    SELECT COUNT(*) INTO v_existing_role_count
    FROM auth.role_h 
    WHERE role_hk = v_system_ops_role_hk;
    
    IF v_existing_role_count > 0 THEN
        RAISE NOTICE 'ℹ️  System Operations Role already exists - skipping creation';
    ELSE
        -- Create system operations role hub (including required tenant_hk)
        INSERT INTO auth.role_h (
            role_hk,
            role_bk,
            tenant_hk,
            load_date,
            record_source
        ) VALUES (
            v_system_ops_role_hk,
            v_system_ops_role_bk,
            v_system_tenant_hk,
            util.current_load_date(),
            'SYSTEM_MIGRATION_V001'
        );
        
        -- Create role definition satellite (using correct table name)
        INSERT INTO auth.role_definition_s (
            role_hk,
            load_date,
            load_end_date,
            hash_diff,
            role_name,
            role_description,
            is_system_role,
            permissions,
            created_date,
            record_source
        ) VALUES (
            v_system_ops_role_hk,
            util.current_load_date(),
            NULL,
            util.hash_binary('System Operations Administrator' || 'SYSTEM' || 'true'),
            'System Operations Administrator',
            'Full administrative access to system operations and tenant pre-registration',
            true,
            jsonb_build_object(
                'SYSTEM_ADMIN', true,
                'TENANT_REGISTRATION', true,
                'PRE_REGISTRATION_MANAGEMENT', true,
                'SYSTEM_MONITORING', true,
                'DATA_MIGRATION', true,
                'BACKUP_MANAGEMENT', true
            ),
            CURRENT_TIMESTAMP,
            'SYSTEM_MIGRATION_V001'
        );
        
        RAISE NOTICE '✅ Created System Operations Role';
    END IF;
END $$;

-- 5. INDEXES FOR SYSTEM OPERATIONS (Idempotent)
DO $$
BEGIN
    CREATE INDEX IF NOT EXISTS idx_tenant_h_system_lookup 
        ON auth.tenant_h(tenant_bk) 
        WHERE tenant_bk = 'SYSTEM_OPERATIONS';

    CREATE INDEX IF NOT EXISTS idx_tenant_profile_s_system_active 
        ON auth.tenant_profile_s(tenant_hk, load_end_date) 
        WHERE load_end_date IS NULL;

    RAISE NOTICE '✅ Created System Operations Indexes';
END $$;

-- 6. SYSTEM OPERATIONS CONSTANTS FUNCTION (Idempotent)
CREATE OR REPLACE FUNCTION util.get_system_operations_tenant_hk()
RETURNS BYTEA AS $$
BEGIN
    RETURN '\x0000000000000000000000000000000000000000000000000000000000000001'::BYTEA;
END;
$$ LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER;

COMMENT ON FUNCTION util.get_system_operations_tenant_hk() IS 
'Returns the fixed hash key for the System Operations Tenant used for pre-registration and system-level activities';

DO $$
BEGIN
    RAISE NOTICE '✅ Created System Operations Utility Function';
END $$;

-- 7. PERMISSIONS (Safe grants)
DO $$
BEGIN
    -- Grant permissions if roles exist
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
        GRANT SELECT ON auth.tenant_h TO app_user;
        GRANT SELECT ON auth.tenant_profile_s TO app_user;
        GRANT EXECUTE ON FUNCTION util.get_system_operations_tenant_hk() TO app_user;
        RAISE NOTICE '✅ Granted permissions to app_user';
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'api_user') THEN
        GRANT SELECT ON auth.tenant_h TO api_user;
        GRANT SELECT ON auth.tenant_profile_s TO api_user;
        GRANT EXECUTE ON FUNCTION util.get_system_operations_tenant_hk() TO api_user;
        RAISE NOTICE '✅ Granted permissions to api_user';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️  Permission grant failed: %', SQLERRM;
END $$;

-- 8. COMPREHENSIVE VALIDATION AND COMPLETION
DO $$
DECLARE
    v_system_tenant_exists BOOLEAN := FALSE;
    v_system_profile_exists BOOLEAN := FALSE;
    v_system_role_exists BOOLEAN := FALSE;
    v_system_function_exists BOOLEAN := FALSE;
    v_index_count INTEGER := 0;
    v_system_tenant_hk BYTEA := '\x0000000000000000000000000000000000000000000000000000000000000001';
BEGIN
    -- Validate system tenant creation
    SELECT EXISTS (
        SELECT 1 FROM auth.tenant_h 
        WHERE tenant_hk = v_system_tenant_hk 
        AND tenant_bk = 'SYSTEM_OPERATIONS'
    ) INTO v_system_tenant_exists;
    
    -- Validate system profile creation
    SELECT EXISTS (
        SELECT 1 FROM auth.tenant_profile_s 
        WHERE tenant_hk = v_system_tenant_hk 
        AND load_end_date IS NULL
        AND tenant_name = 'System Operations Tenant'
        AND is_active = true
    ) INTO v_system_profile_exists;
    
    -- Validate system role creation
    SELECT EXISTS (
        SELECT 1 FROM auth.role_h rh
        JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
        WHERE rds.role_name = 'System Operations Administrator'
        AND rds.is_system_role = true
        AND rds.load_end_date IS NULL
    ) INTO v_system_role_exists;
    
    -- Validate utility function creation
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'util' 
        AND p.proname = 'get_system_operations_tenant_hk'
    ) INTO v_system_function_exists;
    
    -- Count indexes created
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes 
    WHERE indexname IN ('idx_tenant_h_system_lookup', 'idx_tenant_profile_s_system_active');
    
    -- Report validation results
    RAISE NOTICE '📊 Migration V001 Validation Results:';
    RAISE NOTICE '   System Tenant Created: %', CASE WHEN v_system_tenant_exists THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE '   System Profile Created: %', CASE WHEN v_system_profile_exists THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE '   System Role Created: %', CASE WHEN v_system_role_exists THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE '   Utility Function Created: %', CASE WHEN v_system_function_exists THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE '   Indexes Created: % of 2', v_index_count;
    
    -- Validate overall success
    IF v_system_tenant_exists AND v_system_profile_exists AND v_system_role_exists 
       AND v_system_function_exists AND v_index_count = 2 THEN
        
        -- Update migration log
        UPDATE util.migration_log 
        SET completed_at = CURRENT_TIMESTAMP,
            status = 'SUCCESS'
        WHERE migration_version = 'V001' 
        AND migration_type = 'FORWARD';
        
        RAISE NOTICE '🎉 Migration V001 completed successfully!';
        RAISE NOTICE '📋 System Operations Tenant is ready for use';
        RAISE NOTICE '🔑 System Tenant HK: %', encode(v_system_tenant_hk, 'hex');
        
    ELSE
        -- Log failure
        UPDATE util.migration_log 
        SET completed_at = CURRENT_TIMESTAMP,
            status = 'FAILED',
            error_message = 'Validation failed - not all objects created successfully'
        WHERE migration_version = 'V001' 
        AND migration_type = 'FORWARD';
        
        RAISE EXCEPTION '❌ Migration V001 validation failed!';
    END IF;
END $$;

-- End of Migration V001
DO $$
BEGIN
    RAISE NOTICE '✅ Migration V001__create_system_operations_tenant.sql completed';
END $$; 