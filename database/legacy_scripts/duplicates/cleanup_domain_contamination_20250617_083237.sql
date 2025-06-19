-- =====================================================
-- DOMAIN CONTAMINATION CLEANUP SCRIPT
-- Removes domain-specific schemas from one_barn_db to create clean template
-- =====================================================

-- Connect to one_barn_db
-- \c one_barn_db;

-- Start transaction for atomic cleanup
BEGIN;

-- Set session variables for cleanup tracking
SET work_mem = '256MB';

-- =====================================================
-- BACKUP DOMAIN DATA (Optional - Create before cleanup)
-- =====================================================

-- IMPORTANT: Before running this cleanup, consider backing up data if needed:
-- pg_dump -U postgres -h localhost one_barn_db --schema=equestrian --data-only > equestrian_data_backup.sql
-- pg_dump -U postgres -h localhost one_barn_db --schema=finance --data-only > finance_data_backup.sql
-- pg_dump -U postgres -h localhost one_barn_db --schema=health --data-only > health_data_backup.sql
-- pg_dump -U postgres -h localhost one_barn_db --schema=performance --data-only > performance_data_backup.sql

-- =====================================================
-- LOG CLEANUP START
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'util' AND table_name = 'deployment_log') THEN
        INSERT INTO util.deployment_log (
            deployment_name,
            deployment_start,
            deployment_status,
            deployment_notes,
            deployed_by,
            rollback_script
        ) VALUES (
            'Domain Contamination Cleanup v1.0',
            CURRENT_TIMESTAMP,
            'RUNNING',
            'Removing domain-specific schemas (equestrian, finance, health, performance) to create clean template database',
            SESSION_USER,
            'Restore from backup files if needed: equestrian_data_backup.sql, finance_data_backup.sql, health_data_backup.sql, performance_data_backup.sql'
        );
        
        RAISE NOTICE '✅ Cleanup logged in util.deployment_log';
    ELSE
        RAISE NOTICE '⚠️ util.deployment_log table not found - cleanup not logged';
    END IF;
END $$;

-- =====================================================
-- DOMAIN-SPECIFIC SCHEMA REMOVAL
-- =====================================================

-- Remove equestrian schema (10 tables: horse_h, horse_details_s, etc.)
RAISE NOTICE '🚨 Removing equestrian schema...';
DROP SCHEMA IF EXISTS equestrian CASCADE;
RAISE NOTICE '✅ Equestrian schema removed';

-- Remove finance schema (9 tables: horse_transaction_l, financial data)  
RAISE NOTICE '🚨 Removing finance schema...';
DROP SCHEMA IF EXISTS finance CASCADE;
RAISE NOTICE '✅ Finance schema removed';

-- Remove health schema (12 tables: health-specific data)
RAISE NOTICE '🚨 Removing health schema...';
DROP SCHEMA IF EXISTS health CASCADE;
RAISE NOTICE '✅ Health schema removed';

-- Remove performance schema (6 tables: performance tracking)
RAISE NOTICE '🚨 Removing performance schema...';
DROP SCHEMA IF EXISTS performance CASCADE;
RAISE NOTICE '✅ Performance schema removed';

-- =====================================================
-- AUDIT BUSINESS SCHEMA FOR DOMAIN-SPECIFIC TABLES
-- =====================================================

-- Check for domain-specific tables in business schema that need removal
DO $$
DECLARE
    domain_table RECORD;
    tables_removed INTEGER := 0;
BEGIN
    RAISE NOTICE '🔍 Auditing business schema for domain-specific tables...';
    
    -- Check for tables with domain-specific naming patterns
    FOR domain_table IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'business' 
        AND (
            table_name LIKE '%horse%' OR
            table_name LIKE '%barn%' OR
            table_name LIKE '%stable%' OR
            table_name LIKE '%equine%' OR
            table_name LIKE '%veterinary%' OR
            table_name LIKE '%feed%' OR
            table_name LIKE '%pasture%' OR
            table_name LIKE '%farrier%' OR
            table_name LIKE '%breeding%' OR
            table_name LIKE '%race%' OR
            table_name LIKE '%gallop%'
        )
    LOOP
        RAISE NOTICE '🚨 Removing domain-specific table: business.%', domain_table.table_name;
        EXECUTE format('DROP TABLE IF EXISTS business.%I CASCADE', domain_table.table_name);
        tables_removed := tables_removed + 1;
    END LOOP;
    
    IF tables_removed > 0 THEN
        RAISE NOTICE '✅ Removed % domain-specific tables from business schema', tables_removed;
    ELSE
        RAISE NOTICE '✅ No domain-specific tables found in business schema';
    END IF;
END $$;

-- =====================================================
-- REMOVE DOMAIN-SPECIFIC REFERENCE DATA
-- =====================================================

-- Clean up reference tables that might contain domain-specific data
DO $$
DECLARE
    ref_cleanup_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔍 Cleaning domain-specific reference data...';
    
    -- Remove horse/barn specific reference entries (if any exist)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'ref' AND table_name LIKE '%horse%') THEN
        DROP TABLE IF EXISTS ref.horse_breed_r CASCADE;
        ref_cleanup_count := ref_cleanup_count + 1;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'ref' AND table_name LIKE '%stable%') THEN
        DROP TABLE IF EXISTS ref.stable_type_r CASCADE;
        ref_cleanup_count := ref_cleanup_count + 1;
    END IF;
    
    -- Clean up entity types that are domain-specific
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'ref' AND table_name = 'entity_type_r') THEN
        DELETE FROM ref.entity_type_r 
        WHERE entity_type_code IN ('horse', 'stable', 'barn', 'pasture', 'equine');
        
        GET DIAGNOSTICS ref_cleanup_count = ROW_COUNT;
        IF ref_cleanup_count > 0 THEN
            RAISE NOTICE '✅ Removed % domain-specific entity types', ref_cleanup_count;
        END IF;
    END IF;
    
    RAISE NOTICE '✅ Reference data cleanup completed';
END $$;

-- =====================================================
-- VERIFY CLEANUP SUCCESS
-- =====================================================

-- Verification queries
DO $$
DECLARE
    remaining_schemas INTEGER;
    remaining_domain_tables INTEGER;
    remaining_schemas_list TEXT[];
BEGIN
    RAISE NOTICE '🔍 Verifying cleanup success...';
    
    -- Check for remaining domain schemas
    SELECT COUNT(*), array_agg(schema_name) 
    INTO remaining_schemas, remaining_schemas_list
    FROM information_schema.schemata 
    WHERE schema_name IN ('equestrian', 'finance', 'health', 'performance');
    
    IF remaining_schemas > 0 THEN
        RAISE WARNING '⚠️ Some domain schemas still exist: %', remaining_schemas_list;
    ELSE
        RAISE NOTICE '✅ All domain-specific schemas successfully removed';
    END IF;
    
    -- Check for remaining domain tables in business schema
    SELECT COUNT(*) 
    INTO remaining_domain_tables
    FROM information_schema.tables 
    WHERE table_schema = 'business' 
    AND (
        table_name LIKE '%horse%' OR
        table_name LIKE '%barn%' OR
        table_name LIKE '%stable%' OR
        table_name LIKE '%equine%'
    );
    
    IF remaining_domain_tables > 0 THEN
        RAISE WARNING '⚠️ % domain-specific tables still exist in business schema', remaining_domain_tables;
    ELSE
        RAISE NOTICE '✅ No domain-specific tables remain in business schema';
    END IF;
    
    RAISE NOTICE '🎯 Cleanup verification completed';
END $$;

-- =====================================================
-- GENERATE CLEANUP SUMMARY
-- =====================================================

-- Display final status
SELECT 
    'DOMAIN CONTAMINATION CLEANUP COMPLETED' as status,
    'Removed domain-specific schemas: equestrian, finance, health, performance' as action_taken,
    'Database is now ready for AI observation system deployment' as next_step,
    CURRENT_TIMESTAMP as completed_at,
    SESSION_USER as cleaned_by;

-- Show remaining schemas (should be clean template schemas only)
SELECT 
    'Remaining Schemas After Cleanup' as summary_type,
    string_agg(schema_name, ', ' ORDER BY schema_name) as schema_list
FROM information_schema.schemata 
WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1');

-- Show table counts by schema  
SELECT 
    s.schema_name,
    COUNT(t.table_name) as table_count,
    CASE 
        WHEN s.schema_name IN ('auth', 'business', 'audit', 'util') THEN 'TEMPLATE CORE'
        WHEN s.schema_name IN ('ref', 'staging', 'raw', 'metadata') THEN 'TEMPLATE SUPPORT'
        ELSE 'OTHER'
    END as classification
FROM information_schema.schemata s
LEFT JOIN information_schema.tables t ON s.schema_name = t.table_schema
WHERE s.schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
GROUP BY s.schema_name
ORDER BY s.schema_name;

-- =====================================================
-- LOG CLEANUP COMPLETION
-- =====================================================

DO $$
DECLARE
    deployment_id INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'util' AND table_name = 'deployment_log') THEN
        -- Get the deployment ID for this cleanup
        SELECT deployment_id INTO deployment_id
        FROM util.deployment_log 
        WHERE deployment_name = 'Domain Contamination Cleanup v1.0'
        AND deployment_status = 'RUNNING'
        ORDER BY deployment_start DESC 
        LIMIT 1;
        
        IF deployment_id IS NOT NULL THEN
            UPDATE util.deployment_log 
            SET 
                deployment_end = CURRENT_TIMESTAMP,
                deployment_status = 'COMPLETED',
                deployment_notes = deployment_notes || ' | CLEANUP SUCCESSFUL: Removed 4 domain schemas (equestrian, finance, health, performance) and cleaned business schema'
            WHERE deployment_id = deployment_id;
            
            RAISE NOTICE '✅ Cleanup completion logged in util.deployment_log';
        END IF;
    END IF;
END $$;

-- Commit the cleanup transaction
COMMIT;

-- Final success message
RAISE NOTICE '🎉 DOMAIN CONTAMINATION CLEANUP SUCCESSFUL!';
RAISE NOTICE '✅ Database one_barn_db is now a clean template';
RAISE NOTICE '🚀 Ready for AI observation system deployment';
RAISE NOTICE '📋 Next step: Run deploy_ai_observation_system.sql'; 