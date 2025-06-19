# Configuration file for One Vault Database Investigation
# Contains database connection settings and SQL queries

# Database connection configuration
DATABASE_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'one_vault',  # Changed to one_barn_db for migration assessment
    'user': 'postgres',
    'password': None  # Will prompt for password
}

# Investigation SQL queries
INVESTIGATION_QUERIES = {
    # =====================================================================
    # DATABASE OVERVIEW & HEALTH ASSESSMENT
    # =====================================================================
    
    # Database size and performance overview
    'database_overview': """
        SELECT 
            pg_database.datname as database_name,
            pg_size_pretty(pg_database_size(pg_database.datname)) as database_size,
            (SELECT count(*) FROM information_schema.schemata WHERE schema_name NOT LIKE 'pg_%' AND schema_name != 'information_schema') as custom_schemas,
            (SELECT count(*) FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'pg_catalog')) as total_tables,
            (SELECT count(*) FROM information_schema.routines WHERE routine_schema NOT IN ('information_schema', 'pg_catalog')) as total_functions,
            (SELECT count(*) FROM pg_roles WHERE rolname NOT LIKE 'pg_%') as custom_roles,
            (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') as active_connections,
            version() as postgresql_version
        FROM pg_database 
        WHERE pg_database.datname = current_database();
    """,
    
    # Database configuration assessment
    'database_config_assessment': """
        SELECT 
            name as setting_name,
            setting as current_value,
            unit,
            context,
            short_desc,
            CASE 
                WHEN name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size') THEN 'PERFORMANCE_CRITICAL'
                WHEN name IN ('log_statement', 'log_min_duration_statement', 'logging_collector') THEN 'AUDIT_LOGGING'
                WHEN name IN ('ssl', 'password_encryption', 'row_security') THEN 'SECURITY'
                WHEN name IN ('max_connections', 'max_worker_processes') THEN 'CAPACITY'
                ELSE 'OTHER'
            END as category
        FROM pg_settings 
        WHERE name IN (
            'shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size',
            'max_connections', 'max_worker_processes', 'log_statement', 
            'log_min_duration_statement', 'logging_collector', 'ssl', 
            'password_encryption', 'row_security', 'default_transaction_isolation'
        )
        ORDER BY category, name;
    """,
    
    # Check for domain-specific schemas that should NOT be in template
    'domain_specific_schemas': """
        SELECT 
            nspname as schema_name,
            pg_get_userbyid(nspowner) as owner,
            CASE 
                WHEN nspname IN ('health', 'finance', 'performance', 'equestrian') THEN 'DOMAIN SPECIFIC - SHOULD NOT BE IN TEMPLATE'
                ELSE 'OK'
            END as template_status
        FROM pg_namespace 
        WHERE nspname IN ('health', 'finance', 'performance', 'equestrian', 'barn', 'horse')
        OR nspname LIKE '%horse%'
        OR nspname LIKE '%barn%'
        OR nspname LIKE '%equestrian%'
        ORDER BY nspname;
    """,
    
    # Check for all schemas to see current state
    'all_schemas': """
        SELECT 
            nspname as schema_name,
            pg_get_userbyid(nspowner) as owner,
            CASE 
                WHEN nspname IN ('auth', 'business', 'audit', 'util', 'api', 'raw', 'staging', 'ref', 'config') THEN 'TEMPLATE CORE'
                WHEN nspname IN ('health', 'finance', 'performance', 'equestrian') THEN 'DOMAIN SPECIFIC'
                WHEN nspname IN ('information_schema', 'pg_catalog', 'pg_toast') THEN 'SYSTEM'
                WHEN nspname LIKE 'pg_temp%' THEN 'TEMP'
                ELSE 'OTHER'
            END as schema_category
        FROM pg_namespace 
        WHERE nspname NOT LIKE 'pg_temp%'
        ORDER BY schema_category, nspname;
    """,
    
    # Check for domain-specific tables
    'domain_specific_tables': """
        SELECT 
            schemaname,
            tablename,
            CASE 
                WHEN tablename LIKE '%horse%' OR tablename LIKE '%barn%' OR tablename LIKE '%equestrian%' 
                     OR tablename LIKE '%practitioner%' OR tablename LIKE '%appointment%' 
                     OR tablename LIKE '%training%' OR tablename LIKE '%competition%' THEN 'DOMAIN SPECIFIC'
                ELSE 'GENERIC'
            END as table_type
        FROM pg_tables 
        WHERE schemaname IN ('health', 'finance', 'performance', 'equestrian', 'business', 'auth')
        AND (tablename LIKE '%horse%' OR tablename LIKE '%barn%' OR tablename LIKE '%equestrian%' 
             OR tablename LIKE '%practitioner%' OR tablename LIKE '%appointment%' 
             OR tablename LIKE '%training%' OR tablename LIKE '%competition%'
             OR schemaname IN ('health', 'finance', 'performance', 'equestrian'))
        ORDER BY schemaname, table_type, tablename;
    """,
    
    # Count tables by schema to see if we have contamination
    'table_counts_by_schema': """
        SELECT 
            schemaname,
            COUNT(*) as table_count,
            CASE 
                WHEN schemaname IN ('health', 'finance', 'performance', 'equestrian') THEN 'SHOULD BE REMOVED'
                WHEN schemaname IN ('auth', 'business', 'audit', 'util', 'api') THEN 'TEMPLATE CORE'
                ELSE 'OTHER'
            END as schema_status
        FROM pg_tables 
        WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
        GROUP BY schemaname
        ORDER BY schema_status, schemaname;
    """,
    
    # Check recent deployment logs for evidence of deployment
    'recent_deployments': """
        SELECT 
            deployment_id,
            deployment_name,
            deployment_start,
            deployment_end,
            deployment_status,
            deployment_notes,
            deployed_by
        FROM util.deployment_log 
        WHERE deployment_name LIKE '%Critical%' 
           OR deployment_name LIKE '%Health%'
           OR deployment_name LIKE '%Finance%'
           OR deployment_name LIKE '%Performance%'
           OR deployment_notes LIKE '%health%'
           OR deployment_notes LIKE '%finance%'
           OR deployment_notes LIKE '%performance%'
        ORDER BY deployment_start DESC;
    """,
    
    # =====================================================================
    # DATA VAULT 2.0 COMPLETENESS ASSESSMENT
    # =====================================================================
    
    # Data Vault 2.0 structure completeness
    'data_vault_completeness': """
        WITH dv_stats AS (
            SELECT 
                'Hubs' as object_type,
                COUNT(*) as count,
                array_agg(schemaname || '.' || tablename) as objects
            FROM pg_tables 
            WHERE tablename LIKE '%_h' 
            AND schemaname NOT IN ('information_schema', 'pg_catalog')
            
            UNION ALL
            
            SELECT 
                'Satellites' as object_type,
                COUNT(*) as count,
                array_agg(schemaname || '.' || tablename) as objects
            FROM pg_tables 
            WHERE tablename LIKE '%_s' 
            AND schemaname NOT IN ('information_schema', 'pg_catalog')
            
            UNION ALL
            
            SELECT 
                'Links' as object_type,
                COUNT(*) as count,
                array_agg(schemaname || '.' || tablename) as objects
            FROM pg_tables 
            WHERE tablename LIKE '%_l' 
            AND schemaname NOT IN ('information_schema', 'pg_catalog')
            
            UNION ALL
            
            SELECT 
                'Reference Tables' as object_type,
                COUNT(*) as count,
                array_agg(schemaname || '.' || tablename) as objects
            FROM pg_tables 
            WHERE tablename LIKE '%_r' 
            AND schemaname NOT IN ('information_schema', 'pg_catalog')
        )
        SELECT 
            object_type,
            count,
            CASE 
                WHEN object_type = 'Hubs' AND count >= 5 THEN 'GOOD'
                WHEN object_type = 'Satellites' AND count >= 10 THEN 'GOOD'
                WHEN object_type = 'Links' AND count >= 3 THEN 'GOOD'
                WHEN object_type = 'Reference Tables' AND count >= 5 THEN 'GOOD'
                WHEN count > 0 THEN 'PARTIAL'
                ELSE 'MISSING'
            END as assessment,
            objects
        FROM dv_stats
        ORDER BY object_type;
    """,
    
    # Data Vault 2.0 naming convention compliance
    'data_vault_naming_compliance': """
        WITH naming_analysis AS (
            -- Check Hub tables
            SELECT 
                'Hub Tables' as category,
                schemaname || '.' || tablename as table_name,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = REPLACE(pt.tablename, '_h', '_hk')
                    ) THEN 'HASH_KEY_OK'
                    ELSE 'MISSING_HASH_KEY'
                END as hash_key_check,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = REPLACE(pt.tablename, '_h', '_bk')
                    ) THEN 'BUSINESS_KEY_OK'
                    ELSE 'MISSING_BUSINESS_KEY'
                END as business_key_check,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = 'tenant_hk'
                    ) THEN 'TENANT_ISOLATION_OK'
                    ELSE 'MISSING_TENANT_ISOLATION'
                END as tenant_isolation_check
            FROM pg_tables pt
            WHERE pt.tablename LIKE '%_h' 
            AND pt.schemaname NOT IN ('information_schema', 'pg_catalog')
            
            UNION ALL
            
            -- Check Satellite tables
            SELECT 
                'Satellite Tables' as category,
                schemaname || '.' || tablename as table_name,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = 'hash_diff'
                    ) THEN 'HASH_DIFF_OK'
                    ELSE 'MISSING_HASH_DIFF'
                END as hash_key_check,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = 'load_date'
                    ) THEN 'LOAD_DATE_OK'
                    ELSE 'MISSING_LOAD_DATE'
                END as business_key_check,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = 'load_end_date'
                    ) THEN 'TEMPORAL_TRACKING_OK'
                    ELSE 'MISSING_TEMPORAL_TRACKING'
                END as tenant_isolation_check
            FROM pg_tables pt
            WHERE pt.tablename LIKE '%_s' 
            AND pt.schemaname NOT IN ('information_schema', 'pg_catalog')
        )
        SELECT 
            category,
            COUNT(*) as total_tables,
            COUNT(CASE WHEN hash_key_check LIKE '%_OK' THEN 1 END) as compliant_hash_keys,
            COUNT(CASE WHEN business_key_check LIKE '%_OK' THEN 1 END) as compliant_business_keys,
            COUNT(CASE WHEN tenant_isolation_check LIKE '%_OK' THEN 1 END) as compliant_tenant_isolation,
            ROUND(
                (COUNT(CASE WHEN hash_key_check LIKE '%_OK' THEN 1 END) + 
                 COUNT(CASE WHEN business_key_check LIKE '%_OK' THEN 1 END) + 
                 COUNT(CASE WHEN tenant_isolation_check LIKE '%_OK' THEN 1 END)) * 100.0 / 
                (COUNT(*) * 3), 2
            ) as compliance_percentage
        FROM naming_analysis
        GROUP BY category
        ORDER BY category;
    """,
    
    # =====================================================================
    # TENANT ISOLATION ASSESSMENT
    # =====================================================================
    
    # Tenant isolation completeness check
    'tenant_isolation_assessment': """
        WITH tenant_isolation_analysis AS (
            -- Check all hub tables for tenant_hk
            SELECT 
                'Hub Tables' as table_type,
                schemaname,
                tablename,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = 'tenant_hk'
                    ) THEN 'HAS_TENANT_ISOLATION'
                    ELSE 'MISSING_TENANT_ISOLATION'
                END as isolation_status
            FROM pg_tables pt
            WHERE pt.tablename LIKE '%_h' 
            AND pt.schemaname NOT IN ('information_schema', 'pg_catalog', 'ref')
            
            UNION ALL
            
            -- Check all link tables for tenant_hk
            SELECT 
                'Link Tables' as table_type,
                schemaname,
                tablename,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = 'tenant_hk'
                    ) THEN 'HAS_TENANT_ISOLATION'
                    ELSE 'MISSING_TENANT_ISOLATION'
                END as isolation_status
            FROM pg_tables pt
            WHERE pt.tablename LIKE '%_l' 
            AND pt.schemaname NOT IN ('information_schema', 'pg_catalog', 'ref')
        )
        SELECT 
            table_type,
            COUNT(*) as total_tables,
            COUNT(CASE WHEN isolation_status = 'HAS_TENANT_ISOLATION' THEN 1 END) as isolated_tables,
            COUNT(CASE WHEN isolation_status = 'MISSING_TENANT_ISOLATION' THEN 1 END) as non_isolated_tables,
            ROUND(
                COUNT(CASE WHEN isolation_status = 'HAS_TENANT_ISOLATION' THEN 1 END) * 100.0 / COUNT(*), 2
            ) as isolation_percentage,
            CASE 
                WHEN COUNT(CASE WHEN isolation_status = 'HAS_TENANT_ISOLATION' THEN 1 END) = COUNT(*) THEN 'PERFECT_ISOLATION'
                WHEN COUNT(CASE WHEN isolation_status = 'HAS_TENANT_ISOLATION' THEN 1 END) > COUNT(*) * 0.8 THEN 'GOOD_ISOLATION'
                WHEN COUNT(CASE WHEN isolation_status = 'HAS_TENANT_ISOLATION' THEN 1 END) > 0 THEN 'PARTIAL_ISOLATION'
                ELSE 'NO_ISOLATION'
            END as assessment
        FROM tenant_isolation_analysis
        GROUP BY table_type
        ORDER BY table_type;
    """,
    
    # Row Level Security policies analysis
    'rls_security_analysis': """
        SELECT 
            schemaname,
            tablename,
            policyname,
            permissive,
            roles,
            cmd as command,
            qual as policy_condition,
            with_check,
            CASE 
                WHEN qual ILIKE '%tenant%' THEN 'TENANT_AWARE'
                WHEN qual ILIKE '%user%' THEN 'USER_AWARE'
                ELSE 'GENERIC'
            END as security_scope
        FROM pg_policies 
        WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY schemaname, tablename, policyname;
    """,
    
    # =====================================================================
    # PERFORMANCE ANALYSIS
    # =====================================================================
    
    # Index analysis for performance
    'performance_index_analysis': """
        WITH index_analysis AS (
            SELECT 
                pi.schemaname,
                pi.tablename,
                pi.indexname,
                pi.indexdef,
                i.indisunique,
                i.indisprimary,
                pg_size_pretty(pg_relation_size(c.oid)) as index_size,
                s.n_tup_ins + s.n_tup_upd + s.n_tup_del as table_modifications,
                ius.idx_tup_read as index_reads,
                ius.idx_tup_fetch as index_fetches,
                CASE 
                    WHEN pi.indexname LIKE '%tenant%hk%' THEN 'TENANT_ISOLATION'
                    WHEN pi.indexname LIKE '%_hk%' THEN 'HASH_KEY'
                    WHEN pi.indexname LIKE '%_bk%' THEN 'BUSINESS_KEY'
                    WHEN pi.indexname LIKE '%load_date%' THEN 'TEMPORAL'
                    WHEN i.indisprimary THEN 'PRIMARY_KEY'
                    WHEN i.indisunique THEN 'UNIQUE_CONSTRAINT'
                    ELSE 'PERFORMANCE'
                END as index_purpose
            FROM pg_indexes pi
            JOIN pg_class c ON c.relname = pi.indexname
            JOIN pg_index i ON i.indexrelid = c.oid
            LEFT JOIN pg_stat_user_tables s ON s.schemaname = pi.schemaname AND s.relname = pi.tablename
            LEFT JOIN pg_stat_user_indexes ius ON ius.schemaname = pi.schemaname AND ius.relname = pi.tablename AND ius.indexrelname = pi.indexname
            WHERE pi.schemaname NOT IN ('information_schema', 'pg_catalog')
            ORDER BY pi.schemaname, pi.tablename, index_purpose
        )
        SELECT 
            index_purpose,
            COUNT(*) as index_count,
            array_agg(DISTINCT schemaname) as schemas_with_indexes,
            SUM(CASE WHEN index_reads > 0 THEN 1 ELSE 0 END) as used_indexes,
            SUM(CASE WHEN index_reads = 0 OR index_reads IS NULL THEN 1 ELSE 0 END) as unused_indexes
        FROM index_analysis
        GROUP BY index_purpose
        ORDER BY index_count DESC;
    """,
    
    # Table size and usage analysis
    'table_usage_analysis': """
        SELECT 
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
            pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
            n_tup_ins as inserts,
            n_tup_upd as updates,
            n_tup_del as deletes,
            n_live_tup as live_rows,
            n_dead_tup as dead_rows,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze,
            CASE 
                WHEN tablename LIKE '%_h' THEN 'HUB'
                WHEN tablename LIKE '%_s' THEN 'SATELLITE'
                WHEN tablename LIKE '%_l' THEN 'LINK'
                WHEN tablename LIKE '%_r' THEN 'REFERENCE'
                ELSE 'OTHER'
            END as table_type
        FROM pg_stat_user_tables
        WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
    """,
    
    # =====================================================================
    # COMPLIANCE & AUDIT ANALYSIS
    # =====================================================================
    
    # HIPAA compliance structure check
    'hipaa_compliance_check': """
        WITH compliance_check AS (
            -- Check for audit schema and tables
            SELECT 
                'Audit Infrastructure' as component,
                CASE 
                    WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'audit') THEN 'PRESENT'
                    ELSE 'MISSING'
                END as status,
                (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'audit') as table_count
            
            UNION ALL
            
            -- Check for PHI protection patterns
            SELECT 
                'PHI Protection' as component,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE column_name ILIKE '%encrypt%' OR column_name ILIKE '%hash%'
                    ) THEN 'PRESENT'
                    ELSE 'MISSING'
                END as status,
                (SELECT COUNT(*) FROM information_schema.columns 
                 WHERE column_name ILIKE '%encrypt%' OR column_name ILIKE '%hash%') as table_count
            
            UNION ALL
            
            -- Check for access logging
            SELECT 
                'Access Logging' as component,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.tables 
                        WHERE table_name ILIKE '%access%' OR table_name ILIKE '%audit%'
                    ) THEN 'PRESENT'
                    ELSE 'MISSING'
                END as status,
                (SELECT COUNT(*) FROM information_schema.tables 
                 WHERE table_name ILIKE '%access%' OR table_name ILIKE '%audit%') as table_count
            
            UNION ALL
            
            -- Check for consent management
            SELECT 
                'Consent Management' as component,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE column_name ILIKE '%consent%' OR column_name ILIKE '%privacy%'
                    ) THEN 'PRESENT'
                    ELSE 'MISSING'
                END as status,
                (SELECT COUNT(*) FROM information_schema.columns 
                 WHERE column_name ILIKE '%consent%' OR column_name ILIKE '%privacy%') as table_count
        )
        SELECT 
            component,
            status,
            table_count,
            CASE 
                WHEN status = 'PRESENT' AND table_count > 0 THEN 'COMPLIANT'
                WHEN status = 'PRESENT' AND table_count = 0 THEN 'PARTIAL'
                ELSE 'NON_COMPLIANT'
            END as compliance_level
        FROM compliance_check
        ORDER BY compliance_level DESC, component;
    """,
    
    # Data retention and archival analysis
    'data_retention_analysis': """
        SELECT 
            t.table_schema,
            t.table_name,
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM information_schema.columns c
                    WHERE c.table_schema = t.table_schema 
                    AND c.table_name = t.table_name 
                    AND c.column_name IN ('load_end_date', 'archive_date', 'retention_date')
                ) THEN 'HAS_RETENTION_COLUMNS'
                ELSE 'NO_RETENTION_COLUMNS'
            END as retention_capability,
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM information_schema.columns c
                    WHERE c.table_schema = t.table_schema 
                    AND c.table_name = t.table_name 
                    AND c.column_name IN ('load_date', 'created_date', 'effective_date')
                ) THEN 'HAS_TEMPORAL_TRACKING'
                ELSE 'NO_TEMPORAL_TRACKING'
            END as temporal_tracking,
            (SELECT string_agg(column_name, ', ') 
             FROM information_schema.columns c
             WHERE c.table_schema = t.table_schema 
             AND c.table_name = t.table_name 
             AND c.column_name ILIKE '%date%') as date_columns
        FROM information_schema.tables t
        WHERE t.table_schema NOT IN ('information_schema', 'pg_catalog')
        AND t.table_type = 'BASE TABLE'
        ORDER BY t.table_schema, t.table_name;
    """,
    
    # =====================================================================
    # API & BUSINESS LOGIC ANALYSIS
    # =====================================================================
    
    # API function coverage analysis
    'api_coverage_analysis': """
        WITH api_analysis AS (
            SELECT 
                n.nspname as schema_name,
                p.proname as function_name,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type,
                CASE 
                    WHEN p.proname ILIKE '%auth%' OR p.proname ILIKE '%login%' THEN 'AUTHENTICATION'
                    WHEN p.proname ILIKE '%user%' OR p.proname ILIKE '%tenant%' THEN 'USER_MANAGEMENT'
                    WHEN p.proname ILIKE '%ai%' OR p.proname ILIKE '%chat%' THEN 'AI_INTEGRATION'
                    WHEN p.proname ILIKE '%audit%' OR p.proname ILIKE '%log%' THEN 'AUDIT_COMPLIANCE'
                    WHEN p.proname ILIKE '%business%' OR p.proname ILIKE '%entity%' THEN 'BUSINESS_LOGIC'
                    WHEN p.proname ILIKE '%data%' OR p.proname ILIKE '%vault%' THEN 'DATA_MANAGEMENT'
                    ELSE 'UTILITY'
                END as function_category
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname IN ('api', 'business', 'auth', 'util')
        )
        SELECT 
            schema_name,
            function_category,
            COUNT(*) as function_count,
            array_agg(function_name ORDER BY function_name) as functions
        FROM api_analysis
        GROUP BY schema_name, function_category
        ORDER BY schema_name, function_count DESC;
    """,
    
    # Business entity analysis
    'business_entity_analysis': """
        WITH entity_analysis AS (
            -- Analyze hub tables to understand business entities
            SELECT 
                schemaname,
                tablename,
                REPLACE(tablename, '_h', '') as entity_name,
                'HUB' as entity_type,
                (SELECT COUNT(*) FROM information_schema.tables ist 
                 WHERE ist.table_schema = pt.schemaname 
                 AND ist.table_name LIKE REPLACE(pt.tablename, '_h', '') || '%_s') as satellite_count,
                (SELECT COUNT(*) FROM information_schema.tables ist 
                 WHERE ist.table_schema = pt.schemaname 
                 AND ist.table_name LIKE '%' || REPLACE(pt.tablename, '_h', '') || '%_l') as link_count
            FROM pg_tables pt
            WHERE pt.tablename LIKE '%_h' 
            AND pt.schemaname NOT IN ('information_schema', 'pg_catalog')
        )
        SELECT 
            schemaname,
            entity_name,
            satellite_count,
            link_count,
            CASE 
                WHEN satellite_count >= 2 AND link_count >= 1 THEN 'WELL_MODELED'
                WHEN satellite_count >= 1 OR link_count >= 1 THEN 'BASIC_MODELING'
                ELSE 'MINIMAL_MODELING'
            END as modeling_completeness,
            satellite_count + link_count as total_related_objects
        FROM entity_analysis
        ORDER BY total_related_objects DESC, schemaname, entity_name;
    """,
    
    # =====================================================================
    # COMPREHENSIVE AUTHENTICATION SYSTEM INVESTIGATION
    # =====================================================================
    
    # Deep dive into authentication tables
    'auth_system_tables': """
        SELECT 
            schemaname,
            tablename,
            obj_description(c.oid) as table_comment,
            CASE 
                WHEN tablename LIKE '%token%' THEN 'TOKEN_MANAGEMENT'
                WHEN tablename LIKE '%session%' THEN 'SESSION_MANAGEMENT'
                WHEN tablename LIKE '%user%' THEN 'USER_MANAGEMENT'
                WHEN tablename LIKE '%tenant%' THEN 'TENANT_MANAGEMENT'
                WHEN tablename LIKE '%security%' THEN 'SECURITY_POLICY'
                WHEN tablename LIKE '%auth%' THEN 'AUTHENTICATION'
                WHEN tablename LIKE '%role%' THEN 'AUTHORIZATION'
                ELSE 'OTHER_AUTH'
            END as auth_component
        FROM pg_tables pt
        JOIN pg_class c ON c.relname = pt.tablename
        JOIN pg_namespace n ON c.relnamespace = n.oid AND n.nspname = pt.schemaname
        WHERE pt.schemaname = 'auth'
        ORDER BY auth_component, tablename;
    """,
    
    # Token system investigation
    'token_system_detailed': """
        SELECT 
            t.table_name,
            c.column_name,
            c.data_type,
            c.character_maximum_length,
            c.is_nullable,
            c.column_default,
            col_description(pgc.oid, c.ordinal_position) as column_comment
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        LEFT JOIN pg_class pgc ON pgc.relname = t.table_name
        LEFT JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid AND pgn.nspname = t.table_schema
        WHERE t.table_schema = 'auth'
        AND (t.table_name LIKE '%token%' OR c.column_name LIKE '%token%')
        ORDER BY t.table_name, c.ordinal_position;
    """,
    
    # Session management investigation
    'session_management_detailed': """
        SELECT 
            t.table_name,
            c.column_name,
            c.data_type,
            c.character_maximum_length,
            c.is_nullable,
            c.column_default,
            col_description(pgc.oid, c.ordinal_position) as column_comment
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        LEFT JOIN pg_class pgc ON pgc.relname = t.table_name
        LEFT JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid AND pgn.nspname = t.table_schema
        WHERE t.table_schema = 'auth'
        AND (t.table_name LIKE '%session%' OR c.column_name LIKE '%session%')
        ORDER BY t.table_name, c.ordinal_position;
    """,
    
    # Authentication functions investigation
    'auth_functions_detailed': """
        SELECT 
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_arguments(p.oid) as arguments,
            pg_get_function_result(p.oid) as return_type,
            l.lanname as language,
            p.prosrc as function_body_sample,
            obj_description(p.oid) as function_comment,
            CASE 
                WHEN p.proname LIKE '%login%' THEN 'LOGIN_AUTHENTICATION'
                WHEN p.proname LIKE '%token%' THEN 'TOKEN_MANAGEMENT'
                WHEN p.proname LIKE '%session%' THEN 'SESSION_MANAGEMENT'
                WHEN p.proname LIKE '%validate%' THEN 'VALIDATION'
                WHEN p.proname LIKE '%generate%' THEN 'GENERATION'
                WHEN p.proname LIKE '%register%' THEN 'USER_REGISTRATION'
                WHEN p.proname LIKE '%password%' THEN 'PASSWORD_MANAGEMENT'
                WHEN p.proname LIKE '%security%' THEN 'SECURITY_POLICY'
                ELSE 'OTHER_AUTH'
            END as auth_function_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        JOIN pg_language l ON p.prolang = l.oid
        WHERE n.nspname = 'auth'
        ORDER BY auth_function_type, p.proname;
    """,
    
    # API authentication functions
    'api_auth_functions': """
        SELECT 
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_arguments(p.oid) as arguments,
            pg_get_function_result(p.oid) as return_type,
            l.lanname as language,
            obj_description(p.oid) as function_comment,
            CASE 
                WHEN p.proname LIKE '%auth%' THEN 'API_AUTHENTICATION'
                WHEN p.proname LIKE '%login%' THEN 'API_LOGIN'
                WHEN p.proname LIKE '%token%' THEN 'API_TOKEN_MANAGEMENT'
                WHEN p.proname LIKE '%validate%' THEN 'API_VALIDATION'
                WHEN p.proname LIKE '%session%' THEN 'API_SESSION'
                ELSE 'OTHER_API'
            END as api_auth_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        JOIN pg_language l ON p.prolang = l.oid
        WHERE n.nspname = 'api'
        AND (p.proname LIKE '%auth%' OR p.proname LIKE '%login%' OR p.proname LIKE '%token%' 
             OR p.proname LIKE '%validate%' OR p.proname LIKE '%session%')
        ORDER BY api_auth_type, p.proname;
    """,
    
    # Security policies and constraints
    'security_policies_investigation': """
        SELECT 
            t.table_name,
            c.constraint_name,
            c.constraint_type,
            c.is_deferrable,
            c.initially_deferred,
            tc.check_clause
        FROM information_schema.tables t
        LEFT JOIN information_schema.table_constraints c ON t.table_name = c.table_name 
                                                         AND t.table_schema = c.table_schema
        LEFT JOIN information_schema.check_constraints tc ON c.constraint_name = tc.constraint_name
        WHERE t.table_schema = 'auth'
        AND (c.constraint_type IN ('CHECK', 'UNIQUE', 'PRIMARY KEY') OR c.constraint_name IS NULL)
        ORDER BY t.table_name, c.constraint_type;
    """,
    
    # Row Level Security policies
    'rls_policies_investigation': """
        SELECT 
            schemaname,
            tablename,
            policyname,
            permissive,
            roles,
            cmd,
            qual,
            with_check
        FROM pg_policies 
        WHERE schemaname = 'auth'
        ORDER BY tablename, policyname;
    """,
    
    # Database roles and permissions for auth
    'auth_roles_permissions': """
        SELECT 
            r.rolname,
            r.rolcanlogin,
            r.rolsuper,
            r.rolcreatedb,
            r.rolcreaterole,
            r.rolreplication,
            array_agg(DISTINCT p.privilege_type) as table_privileges,
            array_agg(DISTINCT rp.privilege_type) as routine_privileges
        FROM pg_roles r
        LEFT JOIN information_schema.table_privileges p ON r.rolname = p.grantee 
                                                        AND p.table_schema = 'auth'
        LEFT JOIN information_schema.routine_privileges rp ON r.rolname = rp.grantee 
                                                           AND rp.routine_schema = 'auth'
        WHERE r.rolname NOT LIKE 'pg_%'
        AND (p.grantee IS NOT NULL OR rp.grantee IS NOT NULL OR r.rolname IN ('app_user', 'authenticated_users'))
        GROUP BY r.rolname, r.rolcanlogin, r.rolsuper, r.rolcreatedb, r.rolcreaterole, r.rolreplication
        ORDER BY r.rolname;
    """,
    
    # Indexes on authentication tables for performance
    'auth_indexes_investigation': """
        SELECT 
            schemaname,
            tablename,
            indexname,
            indexdef,
            indisunique,
            indisprimary
        FROM pg_indexes pi
        JOIN pg_index i ON i.indexrelid = (
            SELECT oid FROM pg_class WHERE relname = pi.indexname
        )
        WHERE schemaname = 'auth'
        AND tablename IN (
            SELECT tablename FROM pg_tables WHERE schemaname = 'auth' 
            AND (tablename LIKE '%token%' OR tablename LIKE '%session%' OR tablename LIKE '%user%')
        )
        ORDER BY tablename, indexname;
    """,
    
    # Triggers on auth tables
    'auth_triggers_investigation': """
        SELECT 
            t.trigger_schema,
            t.trigger_name,
            t.event_manipulation,
            t.event_object_table,
            t.action_timing,
            t.action_statement,
            t.action_orientation
        FROM information_schema.triggers t
        WHERE t.trigger_schema = 'auth'
        ORDER BY t.event_object_table, t.trigger_name;
    """,
    
    # Check for custom token validation logic
    'token_validation_logic': """
        SELECT 
            p.proname as function_name,
            p.prosrc as function_body
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname IN ('auth', 'api', 'util')
        AND (p.proname LIKE '%token%' OR p.proname LIKE '%validate%')
        AND p.prosrc IS NOT NULL
        ORDER BY n.nspname, p.proname;
    """,
    
    # =====================================================================
    # ORIGINAL QUERIES (keeping existing functionality)
    # =====================================================================
    
    # Schema investigation
    'schemas': """
        SELECT 
            n.nspname as schema_name,
            pg_get_userbyid(n.nspowner) as schema_owner,
            array_to_string(n.nspacl, ',') as permissions
        FROM pg_namespace n 
        WHERE n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
        AND n.nspname NOT LIKE 'pg_temp_%'
        AND n.nspname NOT LIKE 'pg_toast_temp_%'
        ORDER BY n.nspname;
    """,
    
    # Auth schema table structure investigation
    'auth_table_columns': """
        SELECT 
            t.table_name,
            c.column_name,
            c.data_type,
            c.character_maximum_length,
            c.is_nullable,
            c.column_default,
            c.ordinal_position
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        WHERE t.table_schema = 'auth'
        AND t.table_name LIKE '%tenant%'
        ORDER BY t.table_name, c.ordinal_position;
    """,
    
    # Specific tenant table structure
    'tenant_tables_detailed': """
        SELECT 
            table_name,
            column_name,
            data_type,
            is_nullable,
            column_default
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
        AND (table_name = 'tenant_h' OR table_name = 'tenant_profile_s' OR table_name = 'tenant_definition_s')
        ORDER BY table_name, ordinal_position;
    """,
    
    # Table investigation  
    'tables': """
        SELECT 
            t.table_schema,
            t.table_name,
            t.table_type,
            pg_get_userbyid(c.relowner) as table_owner
        FROM information_schema.tables t
        JOIN pg_class c ON c.relname = t.table_name
        JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.table_schema
        WHERE t.table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY t.table_schema, t.table_name;
    """,
    
    # Function investigation
    'functions': """
        SELECT 
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_arguments(p.oid) as arguments,
            pg_get_function_result(p.oid) as return_type,
            l.lanname as language,
            pg_get_userbyid(p.proowner) as function_owner
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        JOIN pg_language l ON p.prolang = l.oid
        WHERE n.nspname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY n.nspname, p.proname;
    """,
    
    # Users and roles investigation
    'users_roles': """
        SELECT 
            r.rolname,
            r.rolcanlogin,
            r.rolsuper,
            r.rolcreatedb,
            r.rolcreaterole,
            array(
                SELECT b.rolname
                FROM pg_catalog.pg_auth_members m
                JOIN pg_catalog.pg_roles b ON (m.roleid = b.oid)
                WHERE m.member = r.oid
            ) as member_of
        FROM pg_catalog.pg_roles r
        WHERE r.rolname NOT LIKE 'pg_%'
        ORDER BY r.rolname;
    """,
    
    # Index investigation
    'indexes': """
        SELECT 
            schemaname,
            tablename,
            indexname,
            indexdef,
            indisunique,
            indisprimary
        FROM pg_indexes pi
        JOIN pg_index i ON i.indexrelid = (
            SELECT oid FROM pg_class WHERE relname = pi.indexname
        )
        WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY schemaname, tablename, indexname;
    """,
    
    # Data Vault specific patterns
    'data_vault_hubs': """
        SELECT schemaname, tablename, tableowner 
        FROM pg_tables 
        WHERE tablename LIKE '%_h' 
        AND schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY schemaname, tablename;
    """,
    
    'data_vault_satellites': """
        SELECT schemaname, tablename, tableowner 
        FROM pg_tables 
        WHERE tablename LIKE '%_s' 
        AND schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY schemaname, tablename;
    """,
    
    'data_vault_links': """
        SELECT schemaname, tablename, tableowner 
        FROM pg_tables 
        WHERE tablename LIKE '%_l' 
        AND schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY schemaname, tablename;
    """,
    
    # AI components
    'ai_tables': """
        SELECT schemaname, tablename, tableowner 
        FROM pg_tables 
        WHERE (tablename ILIKE '%ai%' OR tablename ILIKE '%chat%' OR tablename ILIKE '%conversation%')
        AND schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY schemaname, tablename;
    """,
    
    'ai_functions': """
        SELECT 
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_arguments(p.oid) as arguments
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE (p.proname ILIKE '%ai%' OR p.proname ILIKE '%chat%' OR p.proname ILIKE '%conversation%')
        AND n.nspname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY n.nspname, p.proname;
    """,
    
    # Audit and security structures
    'audit_tables': """
        SELECT schemaname, tablename, tableowner 
        FROM pg_tables 
        WHERE (tablename ILIKE '%audit%' OR tablename ILIKE '%log%' OR schemaname = 'audit')
        AND schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY schemaname, tablename;
    """,
    
    # Business schema investigation
    'business_tables': """
        SELECT schemaname, tablename, tableowner 
        FROM pg_tables 
        WHERE schemaname = 'business'
        ORDER BY tablename;
    """,
    
    # Auth schema investigation
    'auth_tables': """
        SELECT tablename, table_type
        FROM information_schema.tables 
        WHERE table_schema = 'auth' 
        AND tablename LIKE '%user%'
        ORDER BY tablename;
    """,
    
    # Util schema investigation
    'util_functions': """
        SELECT 
            p.proname as function_name,
            pg_get_function_arguments(p.oid) as arguments,
            pg_get_function_result(p.oid) as return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'util'
        ORDER BY p.proname;
    """,
    
    # API schema investigation
    'api_functions': """
        SELECT 
            p.proname as function_name,
            pg_get_function_arguments(p.oid) as arguments,
            pg_get_function_result(p.oid) as return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api'
        ORDER BY p.proname;
    """,
    
    # Check for deployment/version tracking
    'deployment_tracking': """
        SELECT 
            t.table_schema,
            t.table_name,
            c.column_name,
            c.data_type
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        WHERE (t.table_name ILIKE '%deployment%' 
            OR t.table_name ILIKE '%version%' 
            OR t.table_name ILIKE '%migration%')
        AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY t.table_schema, t.table_name, c.ordinal_position;
    """,
    
    # Check for tenant isolation structures
    'tenant_structures': """
        SELECT 
            t.table_schema,
            t.table_name,
            c.column_name
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        WHERE c.column_name ILIKE '%tenant%'
        AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY t.table_schema, t.table_name;
    """,
    
    # Check for hash key columns (Data Vault 2.0)
    'hash_key_columns': """
        SELECT 
            t.table_schema,
            t.table_name,
            c.column_name,
            c.data_type
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        WHERE c.column_name ILIKE '%_hk'
        AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY t.table_schema, t.table_name;
    """,
    
    # Check for business key columns (Data Vault 2.0)
    'business_key_columns': """
        SELECT 
            t.table_schema,
            t.table_name,
            c.column_name,
            c.data_type
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        WHERE c.column_name ILIKE '%_bk'
        AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY t.table_schema, t.table_name;
    """,
    
    # Check for load_date columns (Data Vault 2.0 temporal tracking)
    'temporal_columns': """
        SELECT 
            t.table_schema,
            t.table_name,
            c.column_name,
            c.data_type
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        WHERE (c.column_name = 'load_date' 
            OR c.column_name = 'load_end_date'
            OR c.column_name = 'hash_diff')
        AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY t.table_schema, t.table_name, c.column_name;
    """,
    
    # Simple tenant table column investigation
    'tenant_profile_columns': """
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default,
            character_maximum_length
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
        AND table_name = 'tenant_profile_s'
        ORDER BY ordinal_position;
    """,
    
    # Simple tenant definition table column investigation
    'tenant_definition_columns': """
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default,
            character_maximum_length
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
        AND table_name = 'tenant_definition_s'
        ORDER BY ordinal_position;
    """,
    
    # User profile table column investigation
    'user_profile_columns': """
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default,
            character_maximum_length
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
        AND table_name = 'user_profile_s'
        ORDER BY ordinal_position;
    """,
    
    # Check if both tables exist
    'tenant_tables': """
        SELECT table_name, table_type
        FROM information_schema.tables 
        WHERE table_schema = 'auth' 
        AND table_name LIKE '%tenant%'
        ORDER BY table_name;
    """,
    
    # Check for missing AI observation system components
    'missing_ai_observation_tables': """
        SELECT table_name, 'MISSING' as status
        FROM (VALUES 
            ('ai_observation_h'),
            ('ai_observation_details_s'),
            ('ai_alert_h'),
            ('ai_alert_details_s'),
            ('ai_observation_alert_l'),
            ('user_ai_observation_l'),
            ('monitored_entity_h'),
            ('monitored_entity_details_s'),
            ('monitoring_sensor_h'),
            ('monitoring_sensor_details_s')
        ) AS expected_tables(table_name)
        WHERE NOT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'business' 
            AND table_name = expected_tables.table_name
        );
    """,
    
    # Check for missing reference tables
    'missing_ai_reference_tables': """
        SELECT table_name, 'MISSING' as status
        FROM (VALUES 
            ('ai_observation_type_r'),
            ('ai_alert_type_r')
        ) AS expected_ref_tables(table_name)
        WHERE NOT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'ref' 
            AND table_name = expected_ref_tables.table_name
        );
    """,
    
    # Check for missing AI API functions
    'missing_ai_functions': """
        SELECT function_name, 'MISSING' as status
        FROM (VALUES 
            ('ai_log_observation'),
            ('ai_get_observations'),
            ('ai_get_active_alerts'),
            ('ai_acknowledge_alert'),
            ('ai_get_observation_analytics')
        ) AS expected_functions(function_name)
        WHERE NOT EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_schema = 'api' 
            AND routine_name = expected_functions.function_name
        );
    """,
    
    # Check existing AI system deployment status
    'ai_system_status': """
        SELECT 
            'AI Observation Tables' as component,
            COUNT(CASE WHEN t.table_name LIKE '%ai_observation%' OR t.table_name LIKE '%ai_alert%' THEN 1 END) as existing_count,
            10 as expected_count,
            CASE 
                WHEN COUNT(CASE WHEN t.table_name LIKE '%ai_observation%' OR t.table_name LIKE '%ai_alert%' THEN 1 END) >= 10 THEN 'COMPLETE'
                WHEN COUNT(CASE WHEN t.table_name LIKE '%ai_observation%' OR t.table_name LIKE '%ai_alert%' THEN 1 END) > 0 THEN 'PARTIAL'
                ELSE 'MISSING'
            END as status
        FROM information_schema.tables t
        WHERE t.table_schema = 'business'
        
        UNION ALL
        
        SELECT 
            'AI Reference Data' as component,
            COUNT(CASE WHEN t.table_name LIKE '%ai_%_r' THEN 1 END) as existing_count,
            2 as expected_count,
            CASE 
                WHEN COUNT(CASE WHEN t.table_name LIKE '%ai_%_r' THEN 1 END) >= 2 THEN 'COMPLETE'
                WHEN COUNT(CASE WHEN t.table_name LIKE '%ai_%_r' THEN 1 END) > 0 THEN 'PARTIAL'
                ELSE 'MISSING'
            END as status
        FROM information_schema.tables t
        WHERE t.table_schema = 'ref'
        
        UNION ALL
        
        SELECT 
            'AI API Functions' as component,
            COUNT(CASE WHEN r.routine_name LIKE 'ai_%' THEN 1 END) as existing_count,
            5 as expected_count,
            CASE 
                WHEN COUNT(CASE WHEN r.routine_name LIKE 'ai_%' THEN 1 END) >= 5 THEN 'COMPLETE'
                WHEN COUNT(CASE WHEN r.routine_name LIKE 'ai_%' THEN 1 END) > 0 THEN 'PARTIAL'
                ELSE 'MISSING'
            END as status
        FROM information_schema.routines r
        WHERE r.routine_schema = 'api';
    """,
    
    # =====================================================================
    # DEPLOYMENT READINESS ASSESSMENT
    # =====================================================================
    
    # Production readiness checklist
    'production_readiness_assessment': """
        WITH readiness_check AS (
            -- Core Infrastructure
            SELECT 
                'Core Infrastructure' as category,
                'Schemas' as component,
                CASE 
                    WHEN (SELECT COUNT(*) FROM information_schema.schemata 
                          WHERE schema_name IN ('auth', 'business', 'audit', 'util', 'api')) = 5 THEN 'READY'
                    WHEN (SELECT COUNT(*) FROM information_schema.schemata 
                          WHERE schema_name IN ('auth', 'business', 'audit', 'util', 'api')) >= 3 THEN 'PARTIAL'
                    ELSE 'NOT_READY'
                END as status,
                (SELECT COUNT(*) FROM information_schema.schemata 
                 WHERE schema_name IN ('auth', 'business', 'audit', 'util', 'api')) as actual_count,
                5 as required_count
            
            UNION ALL
            
            -- Authentication System
            SELECT 
                'Authentication' as category,
                'Auth Functions' as component,
                CASE 
                    WHEN (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
                          WHERE n.nspname = 'auth' AND p.proname ILIKE '%login%') >= 1 THEN 'READY'
                    ELSE 'NOT_READY'
                END as status,
                (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
                 WHERE n.nspname = 'auth') as actual_count,
                1 as required_count
            
            UNION ALL
            
            -- Data Vault Structure
            SELECT 
                'Data Vault' as category,
                'Hub Tables' as component,
                CASE 
                    WHEN (SELECT COUNT(*) FROM pg_tables WHERE tablename LIKE '%_h' 
                          AND schemaname NOT IN ('information_schema', 'pg_catalog')) >= 3 THEN 'READY'
                    WHEN (SELECT COUNT(*) FROM pg_tables WHERE tablename LIKE '%_h' 
                          AND schemaname NOT IN ('information_schema', 'pg_catalog')) >= 1 THEN 'PARTIAL'
                    ELSE 'NOT_READY'
                END as status,
                (SELECT COUNT(*) FROM pg_tables WHERE tablename LIKE '%_h' 
                 AND schemaname NOT IN ('information_schema', 'pg_catalog')) as actual_count,
                3 as required_count
            
            UNION ALL
            
            -- Tenant Isolation
            SELECT 
                'Security' as category,
                'Tenant Isolation' as component,
                CASE 
                    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'tenant_h') THEN 'READY'
                    ELSE 'NOT_READY'
                END as status,
                CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'tenant_h') THEN 1 ELSE 0 END as actual_count,
                1 as required_count
            
            UNION ALL
            
            -- Audit Framework
            SELECT 
                'Compliance' as category,
                'Audit Tables' as component,
                CASE 
                    WHEN (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'audit') >= 2 THEN 'READY'
                    WHEN (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'audit') >= 1 THEN 'PARTIAL'
                    ELSE 'NOT_READY'
                END as status,
                (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'audit') as actual_count,
                2 as required_count
        )
        SELECT 
            category,
            component,
            status,
            actual_count,
            required_count,
            CASE 
                WHEN status = 'READY' THEN 3
                WHEN status = 'PARTIAL' THEN 2
                ELSE 1
            END as score
        FROM readiness_check
        ORDER BY category, component;
    """,
    
    # Database health metrics
    'database_health_metrics': """
        SELECT 
            'Database Size' as metric_name,
            pg_size_pretty(pg_database_size(current_database())) as metric_value,
            'Storage' as category,
            CASE 
                WHEN pg_database_size(current_database()) < 1024*1024*1024 THEN 'SMALL'
                WHEN pg_database_size(current_database()) < 10*1024*1024*1024 THEN 'MEDIUM'
                ELSE 'LARGE'
            END as assessment
        
        UNION ALL
        
        SELECT 
            'Active Connections' as metric_name,
            (SELECT count(*)::text FROM pg_stat_activity WHERE state = 'active') as metric_value,
            'Performance' as category,
            CASE 
                WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') < 10 THEN 'LOW_USAGE'
                WHEN (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') < 50 THEN 'MODERATE_USAGE'
                ELSE 'HIGH_USAGE'
            END as assessment
        
        UNION ALL
        
        SELECT 
            'Largest Table Size' as metric_name,
            COALESCE((SELECT pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
             FROM pg_tables pt
             WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
             ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 1), 'N/A') as metric_value,
            'Storage' as category,
            'INFO' as assessment
        
        UNION ALL
        
        SELECT 
            'Total Custom Objects' as metric_name,
            (SELECT (
                (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'pg_catalog')) +
                (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema NOT IN ('information_schema', 'pg_catalog'))
            )::text) as metric_value,
            'Development' as category,
            CASE 
                WHEN ((SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'pg_catalog')) +
                      (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema NOT IN ('information_schema', 'pg_catalog'))) > 100 THEN 'COMPLEX'
                WHEN ((SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'pg_catalog')) +
                      (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema NOT IN ('information_schema', 'pg_catalog'))) > 30 THEN 'MODERATE'
                ELSE 'SIMPLE'
            END as assessment
        
        ORDER BY category, metric_name;
    """,
    
    # =====================================================================
    # MISSING COMPONENTS ANALYSIS
    # =====================================================================
    
    # Essential missing components check
    'missing_essential_components': """
        WITH essential_components AS (
            SELECT 'util.hash_binary' as component_name, 'Function' as component_type, 'CRITICAL' as importance,
                   EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
                          WHERE n.nspname = 'util' AND p.proname = 'hash_binary') as exists
            
            UNION ALL
            
            SELECT 'util.current_load_date' as component_name, 'Function' as component_type, 'CRITICAL' as importance,
                   EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
                          WHERE n.nspname = 'util' AND p.proname = 'current_load_date') as exists
            
            UNION ALL
            
            SELECT 'auth.tenant_h' as component_name, 'Table' as component_type, 'CRITICAL' as importance,
                   EXISTS (SELECT 1 FROM information_schema.tables 
                          WHERE table_schema = 'auth' AND table_name = 'tenant_h') as exists
            
            UNION ALL
            
            SELECT 'auth.user_h' as component_name, 'Table' as component_type, 'CRITICAL' as importance,
                   EXISTS (SELECT 1 FROM information_schema.tables 
                          WHERE table_schema = 'auth' AND table_name = 'user_h') as exists
            
            UNION ALL
            
            SELECT 'audit schema' as component_name, 'Schema' as component_type, 'HIGH' as importance,
                   EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'audit') as exists
            
            UNION ALL
            
            SELECT 'api schema' as component_name, 'Schema' as component_type, 'HIGH' as importance,
                   EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'api') as exists
            
            UNION ALL
            
            SELECT 'business schema' as component_name, 'Schema' as component_type, 'MEDIUM' as importance,
                   EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'business') as exists
        )
        SELECT 
            component_name,
            component_type,
            importance,
            CASE WHEN exists THEN 'PRESENT' ELSE 'MISSING' END as status,
            CASE 
                WHEN NOT exists AND importance = 'CRITICAL' THEN 'DEPLOYMENT_BLOCKER'
                WHEN NOT exists AND importance = 'HIGH' THEN 'DEPLOYMENT_RISK'
                WHEN NOT exists AND importance = 'MEDIUM' THEN 'FEATURE_LIMITATION'
                ELSE 'OK'
            END as impact
        FROM essential_components
        ORDER BY 
            CASE importance WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 ELSE 3 END,
            component_name;
    """,
    
    # =====================================================================
    # ENHANCED ANALYSIS QUERIES
    # =====================================================================
    
    # Schema level analysis with enhancements
    'enhanced_schema_analysis': """
        SELECT 
            n.nspname as schema_name,
            pg_get_userbyid(n.nspowner) as schema_owner,
            (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = n.nspname) as table_count,
            (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = n.nspname) as function_count,
            (SELECT COUNT(*) FROM information_schema.sequences WHERE sequence_schema = n.nspname) as sequence_count,
            CASE 
                WHEN n.nspname IN ('auth', 'business', 'audit', 'util', 'api', 'ref', 'config') THEN 'CORE_INFRASTRUCTURE'
                WHEN n.nspname IN ('health', 'finance', 'performance', 'equestrian') THEN 'DOMAIN_SPECIFIC'
                WHEN n.nspname IN ('information_schema', 'pg_catalog', 'pg_toast') THEN 'SYSTEM'
                WHEN n.nspname LIKE 'pg_%' THEN 'POSTGRESQL_INTERNAL'
                ELSE 'CUSTOM'
            END as schema_category,
            pg_size_pretty(
                COALESCE((SELECT SUM(pg_total_relation_size(c.oid))
                 FROM pg_class c
                 WHERE c.relnamespace = n.oid), 0)
            ) as schema_size
        FROM pg_namespace n 
        WHERE n.nspname NOT LIKE 'pg_temp_%'
        AND n.nspname NOT LIKE 'pg_toast_temp_%'
        ORDER BY schema_category, table_count DESC, n.nspname;
    """,
    
    # Enhanced function analysis with categorization
    'enhanced_function_analysis': """
        SELECT 
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_arguments(p.oid) as arguments,
            pg_get_function_result(p.oid) as return_type,
            l.lanname as language,
            CASE p.provolatile
                WHEN 'i' THEN 'IMMUTABLE'
                WHEN 's' THEN 'STABLE'
                WHEN 'v' THEN 'VOLATILE'
            END as volatility,
            CASE 
                WHEN p.proname ILIKE '%auth%' OR p.proname ILIKE '%login%' OR p.proname ILIKE '%token%' THEN 'AUTHENTICATION'
                WHEN p.proname ILIKE '%audit%' OR p.proname ILIKE '%log%' THEN 'AUDIT_LOGGING'
                WHEN p.proname ILIKE '%tenant%' OR p.proname ILIKE '%user%' THEN 'USER_MANAGEMENT'
                WHEN p.proname ILIKE '%hash%' OR p.proname ILIKE '%encrypt%' THEN 'SECURITY'
                WHEN p.proname ILIKE '%api%' OR p.proname ILIKE '%endpoint%' THEN 'API_LAYER'
                WHEN p.proname ILIKE '%business%' OR p.proname ILIKE '%entity%' THEN 'BUSINESS_LOGIC'
                WHEN p.proname ILIKE '%ai%' OR p.proname ILIKE '%chat%' THEN 'AI_INTEGRATION'
                WHEN p.proname ILIKE '%util%' OR p.proname ILIKE '%helper%' THEN 'UTILITY'
                ELSE 'OTHER'
            END as function_category,
            obj_description(p.oid) as function_comment
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        JOIN pg_language l ON p.prolang = l.oid
        WHERE n.nspname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY n.nspname, function_category, p.proname;
    """,
    
    # =====================================================================
    # COMPREHENSIVE AI/ML ANALYSIS QUERIES
    # =====================================================================
    
    # Enhanced AI schema and table detection
    'comprehensive_ai_analysis': """
        WITH ai_components AS (
            -- AI Schemas
            SELECT 
                'AI Schema' as component_type,
                nspname as component_name,
                'SCHEMA' as object_type,
                NULL as table_schema,
                NULL as object_count
            FROM pg_namespace 
            WHERE nspname IN ('ai', 'ml', 'intelligence', 'analytics', 'prediction')
            
            UNION ALL
            
            -- AI Tables (broader detection)
            SELECT 
                'AI Table' as component_type,
                schemaname || '.' || tablename as component_name,
                'TABLE' as object_type,
                schemaname as table_schema,
                1 as object_count
            FROM pg_tables 
            WHERE (tablename ILIKE '%ai%' OR tablename ILIKE '%ml%' OR tablename ILIKE '%machine%' 
                   OR tablename ILIKE '%model%' OR tablename ILIKE '%prediction%' OR tablename ILIKE '%inference%'
                   OR tablename ILIKE '%neural%' OR tablename ILIKE '%algorithm%' OR tablename ILIKE '%training%'
                   OR tablename ILIKE '%chat%' OR tablename ILIKE '%conversation%' OR tablename ILIKE '%message%'
                   OR tablename ILIKE '%interaction%' OR tablename ILIKE '%response%' OR tablename ILIKE '%prompt%'
                   OR tablename ILIKE '%observation%' OR tablename ILIKE '%monitoring%' OR tablename ILIKE '%alert%'
                   OR tablename ILIKE '%analytics%' OR tablename ILIKE '%intelligence%')
            AND schemaname NOT IN ('information_schema', 'pg_catalog')
            
            UNION ALL
            
            -- AI Functions
            SELECT 
                'AI Function' as component_type,
                n.nspname || '.' || p.proname as component_name,
                'FUNCTION' as object_type,
                n.nspname as table_schema,
                1 as object_count
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE (p.proname ILIKE '%ai%' OR p.proname ILIKE '%ml%' OR p.proname ILIKE '%machine%'
                   OR p.proname ILIKE '%model%' OR p.proname ILIKE '%predict%' OR p.proname ILIKE '%inference%'
                   OR p.proname ILIKE '%neural%' OR p.proname ILIKE '%algorithm%' OR p.proname ILIKE '%train%'
                   OR p.proname ILIKE '%chat%' OR p.proname ILIKE '%conversation%' OR p.proname ILIKE '%message%'
                   OR p.proname ILIKE '%interact%' OR p.proname ILIKE '%response%' OR p.proname ILIKE '%prompt%'
                   OR p.proname ILIKE '%observe%' OR p.proname ILIKE '%monitor%' OR p.proname ILIKE '%alert%'
                   OR p.proname ILIKE '%analyt%' OR p.proname ILIKE '%intelligence%')
            AND n.nspname NOT IN ('information_schema', 'pg_catalog')
        )
        SELECT 
            component_type,
            component_name,
            object_type,
            table_schema,
            object_count,
            CASE 
                WHEN component_type LIKE '%AI%' THEN 'AI_CORE'
                WHEN component_name ILIKE '%chat%' OR component_name ILIKE '%conversation%' THEN 'CONVERSATIONAL_AI'
                WHEN component_name ILIKE '%model%' OR component_name ILIKE '%predict%' THEN 'ML_MODELING'
                WHEN component_name ILIKE '%monitor%' OR component_name ILIKE '%observe%' THEN 'AI_MONITORING'
                WHEN component_name ILIKE '%analyt%' OR component_name ILIKE '%intelligence%' THEN 'AI_ANALYTICS'
                ELSE 'AI_OTHER'
            END as ai_category
        FROM ai_components
        ORDER BY ai_category, component_type, component_name;
    """,
    
    # AI Data Vault 2.0 structure analysis - Simplified to detect your actual AI tables
    'ai_data_vault_analysis': """
        SELECT 
            CASE 
                WHEN tablename ILIKE '%interaction%' OR tablename ILIKE '%session%' THEN 'AI_INTERACTIONS'
                WHEN tablename ILIKE '%model%' OR tablename ILIKE '%training%' THEN 'ML_MODELS'
                WHEN tablename ILIKE '%observation%' OR tablename ILIKE '%monitor%' OR tablename ILIKE '%analysis%' THEN 'AI_MONITORING'
                WHEN tablename ILIKE '%alert%' OR tablename ILIKE '%security%' THEN 'AI_ALERTING'
                WHEN tablename ILIKE '%agent%' OR tablename ILIKE '%reasoning%' OR tablename ILIKE '%decision%' THEN 'AI_AGENTS'
                WHEN tablename ILIKE '%performance%' OR tablename ILIKE '%metric%' THEN 'AI_PERFORMANCE'
                WHEN tablename ILIKE '%business%intelligence%' OR tablename ILIKE '%recommendation%' THEN 'AI_BUSINESS_INTELLIGENCE'
                WHEN tablename ILIKE '%feature%' OR tablename ILIKE '%pipeline%' THEN 'AI_FEATURE_ENGINEERING'
                WHEN tablename ILIKE '%video%' OR tablename ILIKE '%media%' OR tablename ILIKE '%retention%' THEN 'AI_MEDIA'
                ELSE 'AI_OTHER'
            END as ai_domain,
            CASE 
                WHEN tablename LIKE '%_h' THEN 'AI Hub'
                WHEN tablename LIKE '%_s' THEN 'AI Satellite'
                WHEN tablename LIKE '%_l' THEN 'AI Link'
                ELSE 'AI Other'
            END as dv_type,
            COUNT(*) as table_count,
            COUNT(*) as compliant_tables,
            array_agg(schemaname || '.' || tablename) as tables
        FROM pg_tables 
        WHERE (tablename ILIKE '%ai%' OR tablename ILIKE '%interaction%' OR tablename ILIKE '%session%'
               OR tablename ILIKE '%model%' OR tablename ILIKE '%observation%' OR tablename ILIKE '%alert%'
               OR tablename ILIKE '%agent%' OR tablename ILIKE '%reasoning%' OR tablename ILIKE '%decision%'
               OR tablename ILIKE '%performance%' OR tablename ILIKE '%monitor%' OR tablename ILIKE '%analysis%'
               OR tablename ILIKE '%business%intelligence%' OR tablename ILIKE '%recommendation%'
               OR tablename ILIKE '%feature%' OR tablename ILIKE '%pipeline%' OR tablename ILIKE '%security%'
               OR tablename ILIKE '%threat%' OR tablename ILIKE '%metric%' OR tablename ILIKE '%health%'
               OR tablename ILIKE '%video%' OR tablename ILIKE '%media%' OR tablename ILIKE '%retention%')
        AND (tablename LIKE '%_h' OR tablename LIKE '%_s' OR tablename LIKE '%_l')
        AND schemaname NOT IN ('information_schema', 'pg_catalog')
        GROUP BY ai_domain, dv_type
        ORDER BY ai_domain, dv_type;
    """,
    
    # AI API endpoint analysis - Updated to recognize actual AI function patterns
    'ai_api_endpoint_analysis': """
        SELECT 
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_arguments(p.oid) as parameters,
            pg_get_function_result(p.oid) as return_type,
            CASE 
                -- Recognize actual AI function patterns
                WHEN p.proname ILIKE '%chat%' OR p.proname ILIKE '%conversation%' THEN 'CHAT_API'
                WHEN p.proname ILIKE '%message%' THEN 'MESSAGE_API'
                WHEN p.proname ILIKE '%predict%' OR p.proname ILIKE '%model%' OR p.proname ILIKE '%inference%' THEN 'ML_PREDICTION_API'
                WHEN p.proname ILIKE '%train%' OR p.proname ILIKE '%learn%' OR p.proname ILIKE '%deployment%' THEN 'ML_TRAINING_API'
                WHEN p.proname ILIKE '%observe%' OR p.proname ILIKE '%monitor%' OR p.proname ILIKE '%analysis%' THEN 'AI_MONITORING_API'
                WHEN p.proname ILIKE '%alert%' OR p.proname ILIKE '%security%' OR p.proname ILIKE '%threat%' THEN 'AI_ALERTING_API'
                WHEN p.proname ILIKE '%analyt%' OR p.proname ILIKE '%intelligence%' OR p.proname ILIKE '%recommendation%' THEN 'AI_ANALYTICS_API'
                WHEN p.proname ILIKE '%agent%' OR p.proname ILIKE '%reasoning%' OR p.proname ILIKE '%decision%' THEN 'AI_AGENT_API'
                WHEN p.proname ILIKE '%session%' OR p.proname ILIKE '%interaction%' THEN 'AI_SESSION_API'
                WHEN p.proname ILIKE '%performance%' OR p.proname ILIKE '%metric%' OR p.proname ILIKE '%health%' THEN 'AI_PERFORMANCE_API'
                WHEN p.proname ILIKE '%feature%' OR p.proname ILIKE '%pipeline%' THEN 'AI_FEATURE_API'
                WHEN p.proname ILIKE '%business%' OR p.proname ILIKE '%optimization%' THEN 'AI_BUSINESS_API'
                WHEN p.proname ILIKE '%video%' OR p.proname ILIKE '%media%' OR p.proname ILIKE '%retention%' THEN 'AI_MEDIA_API'
                ELSE 'AI_OTHER_API'
            END as api_category,
            CASE 
                WHEN pg_get_function_arguments(p.oid) ILIKE '%tenant%' THEN 'TENANT_AWARE'
                ELSE 'TENANT_AGNOSTIC'
            END as tenant_isolation,
            CASE 
                WHEN pg_get_function_result(p.oid) ILIKE '%json%' THEN 'JSON_RESPONSE'
                WHEN pg_get_function_result(p.oid) ILIKE '%table%' THEN 'TABLE_RESPONSE'
                ELSE 'OTHER_RESPONSE'
            END as response_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE (p.proname ILIKE '%ai%' OR p.proname ILIKE '%chat%' OR p.proname ILIKE '%conversation%'
               OR p.proname ILIKE '%message%' OR p.proname ILIKE '%model%' OR p.proname ILIKE '%predict%'
               OR p.proname ILIKE '%train%' OR p.proname ILIKE '%learn%' OR p.proname ILIKE '%observe%'
               OR p.proname ILIKE '%monitor%' OR p.proname ILIKE '%alert%' OR p.proname ILIKE '%analyt%'
               OR p.proname ILIKE '%intelligence%' OR p.proname ILIKE '%ml%' OR p.proname ILIKE '%agent%'
               OR p.proname ILIKE '%session%' OR p.proname ILIKE '%interaction%' OR p.proname ILIKE '%reasoning%'
               OR p.proname ILIKE '%decision%' OR p.proname ILIKE '%deployment%' OR p.proname ILIKE '%inference%'
               OR p.proname ILIKE '%performance%' OR p.proname ILIKE '%analysis%' OR p.proname ILIKE '%recommendation%'
               OR p.proname ILIKE '%feature%' OR p.proname ILIKE '%pipeline%' OR p.proname ILIKE '%security%'
               OR p.proname ILIKE '%threat%' OR p.proname ILIKE '%metric%' OR p.proname ILIKE '%health%'
               OR p.proname ILIKE '%business%' OR p.proname ILIKE '%optimization%' OR p.proname ILIKE '%video%'
               OR p.proname ILIKE '%media%' OR p.proname ILIKE '%retention%')
        AND n.nspname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY api_category, schema_name, function_name;
    """,
    
    # AI configuration and settings analysis - Updated to recognize actual AI config patterns
    'ai_configuration_analysis': """
        SELECT 
            t.table_schema,
            t.table_name,
            c.column_name,
            c.data_type,
            CASE 
                WHEN c.column_name ILIKE '%api_key%' OR c.column_name ILIKE '%token%' OR c.column_name ILIKE '%credential%' THEN 'API_CREDENTIALS'
                WHEN c.column_name ILIKE '%model%' OR c.column_name ILIKE '%algorithm%' OR c.column_name ILIKE '%deployment%' THEN 'ML_MODEL_CONFIG'
                WHEN c.column_name ILIKE '%threshold%' OR c.column_name ILIKE '%limit%' OR c.column_name ILIKE '%score%' THEN 'AI_THRESHOLDS'
                WHEN c.column_name ILIKE '%prompt%' OR c.column_name ILIKE '%template%' OR c.column_name ILIKE '%instruction%' THEN 'AI_PROMPTS'
                WHEN c.column_name ILIKE '%cost%' OR c.column_name ILIKE '%billing%' OR c.column_name ILIKE '%usage%' THEN 'AI_COST_TRACKING'
                WHEN c.column_name ILIKE '%safety%' OR c.column_name ILIKE '%filter%' OR c.column_name ILIKE '%security%' THEN 'AI_SAFETY'
                WHEN c.column_name ILIKE '%rate%' OR c.column_name ILIKE '%quota%' OR c.column_name ILIKE '%frequency%' THEN 'AI_RATE_LIMITING'
                WHEN c.column_name ILIKE '%agent%' OR c.column_name ILIKE '%reasoning%' OR c.column_name ILIKE '%decision%' THEN 'AI_AGENT_CONFIG'
                WHEN c.column_name ILIKE '%performance%' OR c.column_name ILIKE '%metric%' OR c.column_name ILIKE '%health%' THEN 'AI_PERFORMANCE_CONFIG'
                WHEN c.column_name ILIKE '%session%' OR c.column_name ILIKE '%interaction%' OR c.column_name ILIKE '%timeout%' THEN 'AI_SESSION_CONFIG'
                WHEN c.column_name ILIKE '%feature%' OR c.column_name ILIKE '%pipeline%' OR c.column_name ILIKE '%processing%' THEN 'AI_FEATURE_CONFIG'
                WHEN c.column_name ILIKE '%business%' OR c.column_name ILIKE '%optimization%' OR c.column_name ILIKE '%recommendation%' THEN 'AI_BUSINESS_CONFIG'
                ELSE 'AI_OTHER_CONFIG'
            END as config_category
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        WHERE (t.table_name ILIKE '%config%' OR t.table_name ILIKE '%setting%' OR t.table_name ILIKE '%parameter%'
               OR t.table_name ILIKE '%ai%' OR t.table_name ILIKE '%ml%' OR t.table_name ILIKE '%agent%')
        AND (c.column_name ILIKE '%ai%' OR c.column_name ILIKE '%ml%' OR c.column_name ILIKE '%model%'
             OR c.column_name ILIKE '%chat%' OR c.column_name ILIKE '%conversation%' OR c.column_name ILIKE '%prompt%'
             OR c.column_name ILIKE '%api%' OR c.column_name ILIKE '%token%' OR c.column_name ILIKE '%cost%'
             OR c.column_name ILIKE '%threshold%' OR c.column_name ILIKE '%safety%' OR c.column_name ILIKE '%rate%'
             OR c.column_name ILIKE '%agent%' OR c.column_name ILIKE '%session%' OR c.column_name ILIKE '%interaction%'
             OR c.column_name ILIKE '%reasoning%' OR c.column_name ILIKE '%decision%' OR c.column_name ILIKE '%deployment%'
             OR c.column_name ILIKE '%performance%' OR c.column_name ILIKE '%analysis%' OR c.column_name ILIKE '%recommendation%'
             OR c.column_name ILIKE '%feature%' OR c.column_name ILIKE '%pipeline%' OR c.column_name ILIKE '%security%'
             OR c.column_name ILIKE '%threat%' OR c.column_name ILIKE '%metric%' OR c.column_name ILIKE '%health%'
             OR c.column_name ILIKE '%business%' OR c.column_name ILIKE '%optimization%' OR c.column_name ILIKE '%score%'
             OR c.column_name ILIKE '%credential%' OR c.column_name ILIKE '%usage%' OR c.column_name ILIKE '%frequency%'
             OR c.column_name ILIKE '%instruction%' OR c.column_name ILIKE '%timeout%' OR c.column_name ILIKE '%processing%')
        AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY config_category, t.table_schema, t.table_name, c.column_name;
    """,
    
    # AI audit and compliance tracking
    'ai_audit_compliance_analysis': """
        SELECT 
            t.table_schema,
            t.table_name,
            COUNT(CASE WHEN c.column_name ILIKE '%ai%' OR c.column_name ILIKE '%ml%' THEN 1 END) as ai_columns,
            COUNT(CASE WHEN c.column_name ILIKE '%audit%' OR c.column_name ILIKE '%log%' THEN 1 END) as audit_columns,
            COUNT(CASE WHEN c.column_name ILIKE '%compliance%' OR c.column_name ILIKE '%gdpr%' OR c.column_name ILIKE '%hipaa%' THEN 1 END) as compliance_columns,
            string_agg(DISTINCT c.column_name, ', ' ORDER BY c.column_name) FILTER (WHERE c.column_name ILIKE '%ai%' OR c.column_name ILIKE '%ml%') as ai_related_columns,
            CASE 
                WHEN EXISTS (SELECT 1 FROM information_schema.columns ic WHERE ic.table_schema = t.table_schema AND ic.table_name = t.table_name AND ic.column_name = 'load_date') THEN 'HAS_TEMPORAL_TRACKING'
                ELSE 'NO_TEMPORAL_TRACKING'
            END as temporal_tracking,
            CASE 
                WHEN EXISTS (SELECT 1 FROM information_schema.columns ic WHERE ic.table_schema = t.table_schema AND ic.table_name = t.table_name AND ic.column_name = 'tenant_hk') THEN 'TENANT_ISOLATED'
                ELSE 'NOT_TENANT_ISOLATED'
            END as tenant_isolation
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        WHERE (t.table_name ILIKE '%ai%' OR t.table_name ILIKE '%ml%' OR t.table_name ILIKE '%chat%'
               OR t.table_name ILIKE '%conversation%' OR t.table_name ILIKE '%message%' OR t.table_name ILIKE '%model%'
               OR t.table_name ILIKE '%audit%' OR t.table_name ILIKE '%log%')
        AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        GROUP BY t.table_schema, t.table_name
        HAVING COUNT(CASE WHEN c.column_name ILIKE '%ai%' OR c.column_name ILIKE '%ml%' THEN 1 END) > 0
           OR COUNT(CASE WHEN c.column_name ILIKE '%audit%' OR c.column_name ILIKE '%log%' THEN 1 END) > 0
        ORDER BY ai_columns DESC, audit_columns DESC, t.table_schema, t.table_name;
    """,
    
    # AI integration readiness assessment
    'ai_integration_readiness': """
        WITH ai_readiness AS (
            -- Check for AI foundation tables
            SELECT 
                'AI Foundation' as component,
                CASE 
                    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name ILIKE '%ai%' AND table_name LIKE '%_h') THEN 'READY'
                    ELSE 'MISSING'
                END as status,
                (SELECT COUNT(*) FROM information_schema.tables WHERE table_name ILIKE '%ai%' AND table_name LIKE '%_h') as count
            
            UNION ALL
            
            -- Check for chat/conversation infrastructure
            SELECT 
                'Chat Infrastructure' as component,
                CASE 
                    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE (table_name ILIKE '%chat%' OR table_name ILIKE '%conversation%' OR table_name ILIKE '%message%') AND table_name LIKE '%_h') THEN 'READY'
                    ELSE 'MISSING'
                END as status,
                (SELECT COUNT(*) FROM information_schema.tables WHERE (table_name ILIKE '%chat%' OR table_name ILIKE '%conversation%' OR table_name ILIKE '%message%') AND table_name LIKE '%_h') as count
            
            UNION ALL
            
            -- Check for AI API functions
            SELECT 
                'AI API Functions' as component,
                CASE 
                    WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'api' AND p.proname ILIKE '%ai%') THEN 'READY'
                    ELSE 'MISSING'
                END as status,
                (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'api' AND p.proname ILIKE '%ai%') as count
            
            UNION ALL
            
            -- Check for AI business functions
            SELECT 
                'AI Business Logic' as component,
                CASE 
                    WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'business' AND p.proname ILIKE '%ai%') THEN 'READY'
                    ELSE 'MISSING'
                END as status,
                (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'business' AND p.proname ILIKE '%ai%') as count
            
            UNION ALL
            
            -- Check for AI monitoring/observation system
            SELECT 
                'AI Monitoring System' as component,
                CASE 
                    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name ILIKE '%observation%' AND table_name LIKE '%_h') THEN 'READY'
                    ELSE 'MISSING'
                END as status,
                (SELECT COUNT(*) FROM information_schema.tables WHERE table_name ILIKE '%observation%' AND table_name LIKE '%_h') as count
        )
        SELECT 
            component,
            status,
            count,
            CASE 
                WHEN status = 'READY' AND count > 0 THEN 'DEPLOYMENT_READY'
                WHEN status = 'MISSING' THEN 'REQUIRES_DEPLOYMENT'
                ELSE 'NEEDS_INVESTIGATION'
            END as deployment_status
        FROM ai_readiness
        ORDER BY 
            CASE status WHEN 'READY' THEN 1 ELSE 2 END,
            component;
    """,
    
    # =====================================================================
    # ML MODEL MANAGEMENT ANALYSIS
    # =====================================================================
    
    # ML Model lifecycle management assessment
    'ml_model_management_analysis': """
        WITH ml_model_components AS (
            -- Check for ML model registry tables
            SELECT 
                'ML Model Registry' as component_type,
                COUNT(*) as found_count,
                CASE 
                    WHEN COUNT(*) >= 1 THEN 'PRESENT'
                    ELSE 'MISSING'
                END as status,
                array_agg(schemaname || '.' || tablename) as tables
            FROM pg_tables 
            WHERE (tablename ILIKE '%model%' AND (tablename LIKE '%_h' OR tablename LIKE '%_s' OR tablename LIKE '%_l'))
            AND schemaname NOT IN ('information_schema', 'pg_catalog')
            
            UNION ALL
            
            -- Check for model versioning
            SELECT 
                'Model Versioning' as component_type,
                COUNT(*) as found_count,
                CASE 
                    WHEN COUNT(*) >= 1 THEN 'PRESENT'
                    ELSE 'MISSING'
                END as status,
                array_agg(schemaname || '.' || tablename) as tables
            FROM pg_tables 
            WHERE (tablename ILIKE '%version%' OR tablename ILIKE '%deployment%')
            AND (tablename ILIKE '%model%' OR tablename ILIKE '%ml%')
            AND schemaname NOT IN ('information_schema', 'pg_catalog')
            
            UNION ALL
            
            -- Check for model performance tracking
            SELECT 
                'Model Performance' as component_type,
                COUNT(*) as found_count,
                CASE 
                    WHEN COUNT(*) >= 1 THEN 'PRESENT'
                    ELSE 'MISSING'
                END as status,
                array_agg(schemaname || '.' || tablename) as tables
            FROM pg_tables 
            WHERE (tablename ILIKE '%performance%' OR tablename ILIKE '%metric%' OR tablename ILIKE '%accuracy%')
            AND (tablename ILIKE '%model%' OR tablename ILIKE '%ml%' OR tablename ILIKE '%ai%')
            AND schemaname NOT IN ('information_schema', 'pg_catalog')
            
            UNION ALL
            
            -- Check for model training data lineage
            SELECT 
                'Training Data Lineage' as component_type,
                COUNT(*) as found_count,
                CASE 
                    WHEN COUNT(*) >= 1 THEN 'PRESENT'
                    ELSE 'MISSING'
                END as status,
                array_agg(schemaname || '.' || tablename) as tables
            FROM pg_tables 
            WHERE (tablename ILIKE '%training%' OR tablename ILIKE '%dataset%' OR tablename ILIKE '%lineage%')
            AND schemaname NOT IN ('information_schema', 'pg_catalog')
        )
        SELECT 
            component_type,
            found_count,
            status,
            tables,
            CASE 
                WHEN status = 'PRESENT' THEN 'DEPLOYED'
                ELSE 'NEEDS_IMPLEMENTATION'
            END as deployment_status
        FROM ml_model_components
        ORDER BY 
            CASE status WHEN 'PRESENT' THEN 1 ELSE 2 END,
            component_type;
    """,
    
    # ML model metadata and configuration analysis
    'ml_model_metadata_analysis': """
        SELECT 
            t.table_schema,
            t.table_name,
            c.column_name,
            c.data_type,
            CASE 
                WHEN c.column_name ILIKE '%model_name%' OR c.column_name ILIKE '%algorithm%' THEN 'MODEL_IDENTITY'
                WHEN c.column_name ILIKE '%version%' OR c.column_name ILIKE '%build%' THEN 'MODEL_VERSIONING'
                WHEN c.column_name ILIKE '%accuracy%' OR c.column_name ILIKE '%precision%' OR c.column_name ILIKE '%recall%' THEN 'MODEL_METRICS'
                WHEN c.column_name ILIKE '%training%' OR c.column_name ILIKE '%dataset%' THEN 'TRAINING_DATA'
                WHEN c.column_name ILIKE '%config%' OR c.column_name ILIKE '%parameter%' OR c.column_name ILIKE '%hyperparameter%' THEN 'MODEL_CONFIG'
                WHEN c.column_name ILIKE '%endpoint%' OR c.column_name ILIKE '%deployment%' THEN 'MODEL_DEPLOYMENT'
                ELSE 'OTHER_ML'
            END as ml_category
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        WHERE (t.table_name ILIKE '%model%' OR t.table_name ILIKE '%ml%' OR t.table_name ILIKE '%algorithm%')
        AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY ml_category, t.table_schema, t.table_name, c.column_name;
    """,
    
    # =====================================================================
    # COMPREHENSIVE HASH KEY AND TENANT ISOLATION ANALYSIS
    # =====================================================================
    
    # Comprehensive hash key analysis
    'comprehensive_hash_key_analysis': """
        WITH hash_key_analysis AS (
            -- Analyze all tables for hash key patterns
            SELECT 
                t.table_schema,
                t.table_name,
                CASE 
                    WHEN t.table_name LIKE '%_h' THEN 'HUB'
                    WHEN t.table_name LIKE '%_s' THEN 'SATELLITE'
                    WHEN t.table_name LIKE '%_l' THEN 'LINK'
                    WHEN t.table_name LIKE '%_r' THEN 'REFERENCE'
                    ELSE 'OTHER'
                END as table_type,
                -- Check for primary hash key
                EXISTS (
                    SELECT 1 FROM information_schema.columns c
                    WHERE c.table_schema = t.table_schema 
                    AND c.table_name = t.table_name 
                    AND c.column_name = REPLACE(REPLACE(REPLACE(t.table_name, '_h', ''), '_s', ''), '_l', '') || '_hk'
                ) as has_primary_hk,
                -- Check for tenant hash key
                EXISTS (
                    SELECT 1 FROM information_schema.columns c
                    WHERE c.table_schema = t.table_schema 
                    AND c.table_name = t.table_name 
                    AND c.column_name = 'tenant_hk'
                ) as has_tenant_hk,
                -- Get all hash key columns
                (
                    SELECT string_agg(c.column_name, ', ' ORDER BY c.column_name)
                    FROM information_schema.columns c
                    WHERE c.table_schema = t.table_schema 
                    AND c.table_name = t.table_name 
                    AND c.column_name LIKE '%_hk'
                ) as hash_key_columns,
                -- Check if table should have tenant isolation (exclude ref and system tables)
                CASE 
                    WHEN t.table_schema IN ('ref', 'metadata', 'util') THEN false
                    WHEN t.table_name LIKE '%_r' THEN false
                    WHEN t.table_schema = 'public' THEN false
                    ELSE true
                END as should_have_tenant_hk
            FROM information_schema.tables t
            WHERE t.table_type = 'BASE TABLE'
            AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        )
        SELECT 
            table_schema,
            table_name,
            table_type,
            has_primary_hk,
            has_tenant_hk,
            hash_key_columns,
            should_have_tenant_hk,
            CASE 
                WHEN should_have_tenant_hk AND NOT has_tenant_hk THEN 'MISSING_TENANT_ISOLATION'
                WHEN should_have_tenant_hk AND has_tenant_hk THEN 'TENANT_ISOLATED'
                WHEN NOT should_have_tenant_hk THEN 'TENANT_AGNOSTIC'
                ELSE 'UNKNOWN'
            END as tenant_isolation_status,
            CASE 
                WHEN table_type = 'HUB' AND NOT has_primary_hk THEN 'MISSING_PRIMARY_HK'
                WHEN table_type = 'SATELLITE' AND NOT has_primary_hk THEN 'MISSING_PARENT_HK'
                WHEN table_type = 'LINK' AND (hash_key_columns IS NULL OR array_length(string_to_array(hash_key_columns, ', '), 1) < 2) THEN 'INSUFFICIENT_HK'
                WHEN has_primary_hk OR table_type = 'REFERENCE' THEN 'HK_COMPLIANT'
                ELSE 'HK_ISSUE'
            END as hash_key_compliance
        FROM hash_key_analysis
        ORDER BY 
            CASE table_schema 
                WHEN 'auth' THEN 1 
                WHEN 'business' THEN 2 
                WHEN 'ai_monitoring' THEN 3 
                ELSE 4 
            END,
            table_type,
            table_name;
    """,
    
    # Tenant isolation gaps summary
    'tenant_isolation_gaps_summary': """
        WITH isolation_analysis AS (
            SELECT 
                t.table_schema,
                t.table_name,
                CASE 
                    WHEN t.table_name LIKE '%_h' THEN 'HUB'
                    WHEN t.table_name LIKE '%_s' THEN 'SATELLITE'
                    WHEN t.table_name LIKE '%_l' THEN 'LINK'
                    WHEN t.table_name LIKE '%_r' THEN 'REFERENCE'
                    ELSE 'OTHER'
                END as table_type,
                EXISTS (
                    SELECT 1 FROM information_schema.columns c
                    WHERE c.table_schema = t.table_schema 
                    AND c.table_name = t.table_name 
                    AND c.column_name = 'tenant_hk'
                ) as has_tenant_hk,
                CASE 
                    WHEN t.table_schema IN ('ref', 'metadata', 'util', 'public') THEN false
                    WHEN t.table_name LIKE '%_r' THEN false
                    ELSE true
                END as should_have_tenant_hk
            FROM information_schema.tables t
            WHERE t.table_type = 'BASE TABLE'
            AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        )
        SELECT 
            table_schema,
            table_type,
            COUNT(*) as total_tables,
            SUM(CASE WHEN has_tenant_hk THEN 1 ELSE 0 END) as tenant_isolated_tables,
            SUM(CASE WHEN should_have_tenant_hk AND NOT has_tenant_hk THEN 1 ELSE 0 END) as missing_tenant_isolation,
            SUM(CASE WHEN NOT should_have_tenant_hk THEN 1 ELSE 0 END) as exempt_tables,
            ROUND(
                (SUM(CASE WHEN has_tenant_hk THEN 1 ELSE 0 END)::numeric / 
                 NULLIF(SUM(CASE WHEN should_have_tenant_hk THEN 1 ELSE 0 END), 0)) * 100, 2
            ) as isolation_percentage,
            string_agg(
                CASE WHEN should_have_tenant_hk AND NOT has_tenant_hk THEN table_name END, 
                ', ' 
                ORDER BY table_name
            ) as tables_missing_isolation
        FROM isolation_analysis
        GROUP BY table_schema, table_type
        HAVING COUNT(*) > 0
        ORDER BY table_schema, table_type;
    """,
    
    # Hash key generation patterns analysis
    'hash_key_generation_patterns': """
        SELECT 
            t.table_schema,
            t.table_name,
            c.column_name,
            c.data_type,
            c.column_default,
            CASE 
                WHEN c.column_default ILIKE '%util.hash_%' THEN 'USES_UTIL_HASH'
                WHEN c.column_default ILIKE '%hash_%' THEN 'USES_HASH_FUNCTION'
                WHEN c.column_default IS NULL THEN 'NO_DEFAULT'
                ELSE 'OTHER_DEFAULT'
            END as hash_generation_method,
            CASE 
                WHEN c.column_default ILIKE '%tenant_hk%' THEN 'TENANT_DERIVED'
                WHEN c.column_default ILIKE '%tenant%' THEN 'TENANT_RELATED'
                ELSE 'NOT_TENANT_DERIVED'
            END as tenant_derivation
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
                                         AND t.table_schema = c.table_schema
        WHERE c.column_name LIKE '%_hk'
        AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY 
            hash_generation_method,
            tenant_derivation,
            t.table_schema,
            t.table_name,
            c.column_name;
    """,
    
    # ===== ENHANCED INVESTIGATIONS - ADDITIONAL QUERIES =====
    
    # Real-time Performance Monitoring Queries
    'query_performance_live': """
        SELECT 
            query_start,
            state,
            query,
            wait_event_type,
            wait_event,
            client_addr,
            application_name,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - query_start)) as duration_seconds
        FROM pg_stat_activity 
        WHERE state = 'active' AND query NOT LIKE '%pg_stat_activity%'
        ORDER BY duration_seconds DESC;
    """,
    
    'index_usage_efficiency': """
        SELECT 
            schemaname,
            tablename,
            indexname,
            idx_scan,
            idx_tup_read,
            idx_tup_fetch,
            CASE WHEN idx_scan = 0 THEN 'UNUSED'
                 WHEN idx_scan < 100 THEN 'LOW_USAGE'
                 ELSE 'ACTIVE' END as usage_status
        FROM pg_stat_user_indexes
        ORDER BY idx_scan DESC;
    """,
    
    'table_bloat_analysis': """
        SELECT 
            schemaname,
            tablename,
            n_tup_ins,
            n_tup_upd,
            n_tup_del,
            n_dead_tup,
            ROUND(100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1), 2) as bloat_percent
        FROM pg_stat_user_tables
        WHERE n_dead_tup > 0
        ORDER BY bloat_percent DESC;
    """,
    
    # Security Vulnerability Detection Queries
    'weak_passwords_detection': """
        SELECT 
            'Password Security Audit' as audit_type,
            table_schema || '.' || table_name as table_location,
            column_name,
            data_type,
            CASE 
                WHEN column_name LIKE '%password%' AND data_type != 'bytea' THEN 'VULNERABILITY: Plain text password'
                WHEN column_name LIKE '%secret%' AND data_type = 'text' THEN 'VULNERABILITY: Plain text secret'
                WHEN column_name LIKE '%key%' AND data_type = 'text' THEN 'VULNERABILITY: Plain text key'
                WHEN column_name LIKE '%token%' AND data_type = 'text' THEN 'WARNING: Plain text token'
                ELSE 'SECURE'
            END as security_status
        FROM information_schema.columns 
        WHERE (LOWER(column_name) LIKE '%password%'
           OR LOWER(column_name) LIKE '%secret%'
           OR LOWER(column_name) LIKE '%key%'
           OR LOWER(column_name) LIKE '%token%')
        AND table_schema NOT LIKE 'pg_%'
        ORDER BY security_status DESC;
    """,
    
    'privilege_escalation_check': """
        SELECT 
            grantee,
            table_schema,
            table_name,
            privilege_type,
            is_grantable,
            CASE 
                WHEN privilege_type = 'TRIGGER' AND grantee != 'postgres' THEN 'HIGH_RISK'
                WHEN privilege_type = 'REFERENCES' AND is_grantable = 'YES' THEN 'MEDIUM_RISK'
                ELSE 'NORMAL'
            END as risk_level
        FROM information_schema.table_privileges
        WHERE grantee NOT IN ('postgres', 'PUBLIC')
        ORDER BY risk_level DESC;
    """,
    
    'injection_vulnerability_scan': """
        SELECT 
            routine_schema,
            routine_name,
            routine_definition,
            CASE 
                WHEN routine_definition LIKE '%||%' AND routine_definition LIKE '%$%' THEN 'POTENTIAL_SQL_INJECTION'
                WHEN routine_definition LIKE '%EXECUTE%' AND routine_definition LIKE '%$%' THEN 'DYNAMIC_SQL_RISK'
                WHEN routine_definition LIKE '%format(%' THEN 'FORMAT_INJECTION_RISK'
                ELSE 'SAFE'
            END as injection_risk
        FROM information_schema.routines
        WHERE routine_schema NOT IN ('information_schema', 'pg_catalog')
        AND routine_definition IS NOT NULL
        ORDER BY injection_risk DESC;
    """,
    
    # AI Model Drift Detection Queries
    'model_performance_degradation': """
        SELECT 
            model_name,
            model_version,
            AVG(accuracy_score) as avg_accuracy,
            STDDEV(accuracy_score) as accuracy_variance,
            AVG(inference_time_ms) as avg_inference_time,
            COUNT(*) as prediction_count,
            MIN(load_date) as first_prediction,
            MAX(load_date) as last_prediction,
            CASE 
                WHEN AVG(accuracy_score) < 0.85 THEN 'DEGRADED_PERFORMANCE'
                WHEN STDDEV(accuracy_score) > 0.1 THEN 'HIGH_VARIANCE'
                WHEN AVG(inference_time_ms) > 500 THEN 'SLOW_INFERENCE'
                ELSE 'HEALTHY'
            END as health_status
        FROM business.ai_model_performance_s
        WHERE load_end_date IS NULL
        GROUP BY model_name, model_version
        ORDER BY health_status DESC, avg_accuracy ASC;
    """,
    
    'training_data_drift': """
        SELECT 
            feature_name,
            feature_type,
            statistical_drift_score,
            population_stability_index,
            CASE 
                WHEN statistical_drift_score > 0.2 THEN 'SIGNIFICANT_DRIFT'
                WHEN statistical_drift_score > 0.1 THEN 'MODERATE_DRIFT'
                WHEN population_stability_index > 0.25 THEN 'POPULATION_SHIFT'
                ELSE 'STABLE'
            END as drift_status
        FROM business.ai_feature_pipeline_s
        WHERE load_end_date IS NULL
        ORDER BY statistical_drift_score DESC;
    """,
    
    'automated_retraining_triggers': """
        SELECT 
            model_name,
            last_training_date,
            last_accuracy_score,
            accuracy_threshold,
            drift_threshold,
            CASE 
                WHEN last_accuracy_score < accuracy_threshold THEN 'RETRAIN_NEEDED'
                WHEN CURRENT_DATE - last_training_date::date > 30 THEN 'SCHEDULED_RETRAIN'
                ELSE 'NO_ACTION_NEEDED'
            END as retraining_recommendation
        FROM business.ai_deployment_status_s
        WHERE load_end_date IS NULL
        ORDER BY retraining_recommendation DESC;
    """,
    
    # Compliance Automation Queries
    'gdpr_data_subject_rights': """
        SELECT 
            consent_type,
            COUNT(*) as total_consents,
            COUNT(*) FILTER (WHERE consent_given = true) as active_consents,
            COUNT(*) FILTER (WHERE withdrawal_date IS NOT NULL) as withdrawn_consents,
            ROUND(100.0 * COUNT(*) FILTER (WHERE consent_given = true) / COUNT(*), 2) as consent_rate,
            CASE 
                WHEN COUNT(*) FILTER (WHERE CURRENT_DATE - consent_date::date > 365) > 0 THEN 'RENEWAL_REQUIRED'
                ELSE 'CURRENT'
            END as renewal_status
        FROM compliance.patient_consent_s
        WHERE load_end_date IS NULL
        GROUP BY consent_type
        ORDER BY consent_rate DESC;
    """,
    
    'hipaa_audit_trail_completeness': """
        SELECT 
            audit_category,
            COUNT(*) as event_count,
            MIN(event_timestamp) as earliest_event,
            MAX(event_timestamp) as latest_event,
            COUNT(DISTINCT user_hk) as unique_users,
            CASE 
                WHEN COUNT(*) = 0 THEN 'NO_AUDIT_TRAIL'
                WHEN MAX(event_timestamp) < CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 'STALE_AUDIT'
                ELSE 'ACTIVE_MONITORING'
            END as audit_health
        FROM audit.security_event_s
        WHERE load_end_date IS NULL
        GROUP BY audit_category
        ORDER BY event_count DESC;
    """,
    
    'sox_control_effectiveness': """
        SELECT 
            control_type,
            COUNT(*) as total_controls,
            COUNT(*) FILTER (WHERE test_result = 'Effective') as effective_controls,
            COUNT(*) FILTER (WHERE deficiency_severity = 'Material') as material_weaknesses,
            ROUND(100.0 * COUNT(*) FILTER (WHERE test_result = 'Effective') / COUNT(*), 2) as effectiveness_rate
        FROM compliance.sox_control_s  -- This would be a new table
        WHERE load_end_date IS NULL
        GROUP BY control_type
        ORDER BY effectiveness_rate ASC;
    """,
    
    # Cost Optimization Queries
    'storage_optimization': """
        SELECT 
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
            pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size,
            n_tup_ins + n_tup_upd + n_tup_del as total_activity,
            CASE 
                WHEN pg_total_relation_size(schemaname||'.'||tablename) > 1073741824 AND (n_tup_ins + n_tup_upd + n_tup_del) < 1000 THEN 'ARCHIVE_CANDIDATE'
                WHEN n_dead_tup > n_live_tup THEN 'VACUUM_NEEDED'
                ELSE 'OPTIMIZED'
            END as optimization_recommendation
        FROM pg_stat_user_tables
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
    """,
    
    'unused_indexes': """
        SELECT 
            schemaname,
            tablename,
            indexname,
            pg_size_pretty(pg_relation_size(schemaname||'.'||indexname)) as index_size,
            idx_scan,
            CASE 
                WHEN idx_scan = 0 THEN 'DROP_CANDIDATE'
                WHEN idx_scan < 10 THEN 'LOW_USAGE'
                ELSE 'KEEP'
            END as recommendation
        FROM pg_stat_user_indexes
        WHERE idx_scan < 100
        ORDER BY pg_relation_size(schemaname||'.'||indexname) DESC;
    """,
    
    # Zero Trust Readiness Queries
    'micro_segmentation_assessment': """
        SELECT 
            table_schema,
            table_name,
            CASE WHEN table_name LIKE '%tenant%' THEN 'TENANT_ISOLATED'
                 WHEN EXISTS (SELECT 1 FROM information_schema.columns 
                              WHERE table_schema = t.table_schema 
                              AND table_name = t.table_name 
                              AND column_name = 'tenant_hk') THEN 'MULTI_TENANT_READY'
                 ELSE 'ISOLATION_NEEDED'
            END as isolation_status
        FROM information_schema.tables t
        WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY isolation_status;
    """,
    
    'certificate_management_readiness': """
        SELECT 
            table_schema,
            table_name,
            column_name,
            CASE 
                WHEN column_name LIKE '%certificate%' THEN 'CERT_MANAGEMENT'
                WHEN column_name LIKE '%fingerprint%' THEN 'CERT_VALIDATION'
                WHEN column_name LIKE '%private_key%' THEN 'KEY_MANAGEMENT'
                ELSE 'OTHER'
            END as cert_category
        FROM information_schema.columns
        WHERE (column_name LIKE '%certificate%' 
           OR column_name LIKE '%fingerprint%' 
           OR column_name LIKE '%private_key%')
        ORDER BY cert_category;
    """,
    
    # Intelligent Hub Compliance Correction Query
    'intelligent_hub_compliance_analysis': """
        WITH hub_analysis AS (
            SELECT 
                pt.schemaname,
                pt.tablename,
                -- Check for hash key (any column ending with _hk)
                EXISTS(
                    SELECT 1 FROM information_schema.columns c 
                    WHERE c.table_schema = pt.schemaname 
                    AND c.table_name = pt.tablename 
                    AND c.column_name LIKE '%_hk'
                ) as has_hash_key,
                
                -- Check for business key (flexible patterns)
                EXISTS(
                    SELECT 1 FROM information_schema.columns c 
                    WHERE c.table_schema = pt.schemaname 
                    AND c.table_name = pt.tablename 
                    AND (
                        c.column_name LIKE '%_bk' OR
                        c.column_name = 'session_token' OR  -- Valid for session tables
                        c.column_name LIKE '%_id' OR
                        c.column_name LIKE '%_key'
                    )
                ) as has_business_key,
                
                -- Check for tenant isolation (explicit or implicit)
                CASE 
                    WHEN EXISTS(
                        SELECT 1 FROM information_schema.columns c 
                        WHERE c.table_schema = pt.schemaname 
                        AND c.table_name = pt.tablename 
                        AND c.column_name = 'tenant_hk'
                    ) THEN true
                    -- Special case: session tables have implicit tenant isolation via hash key derivation
                    WHEN pt.tablename LIKE '%session%' AND EXISTS(
                        SELECT 1 FROM information_schema.columns c 
                        WHERE c.table_schema = pt.schemaname 
                        AND c.table_name = pt.tablename 
                        AND c.column_name LIKE '%_hk'
                    ) THEN true
                    -- System/utility tables may be tenant-agnostic by design
                    WHEN pt.schemaname IN ('util', 'audit', 'config', 'ref') THEN true
                    ELSE false
                END as has_tenant_isolation
            FROM pg_tables pt 
            WHERE pt.tablename LIKE '%_h'
            AND pt.schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
        )
        SELECT 
            COUNT(*) as total_hubs,
            COUNT(*) FILTER (WHERE has_hash_key) as corrected_hash_keys,
            COUNT(*) FILTER (WHERE has_business_key) as corrected_business_keys,
            COUNT(*) FILTER (WHERE has_tenant_isolation) as corrected_tenant_isolation
        FROM hub_analysis;
    """
}

# Deployment script tracking
DEPLOYMENT_SCRIPTS = {
    'deploy_template_foundation.sql': {
        'description': 'Essential infrastructure for template database',
        'creates': [
            'util.deployment_log table',
            'util.database_version table', 
            'util.template_features table',
            'util.hash_binary function',
            'util.current_load_date function',
            'util.get_record_source function',
            'util.log_deployment_start function',
            'util.log_deployment_complete function',
            'app_user role'
        ],
        'dependencies': ['util schema must exist']
    },
    
    'deploy_ai_data_vault.sql': {
        'description': 'Complete AI system with Data Vault 2.0 integration',
        'creates': [
            'ai schema',
            '22 AI-related tables (hubs, satellites, links)',
            'AI interaction functions',
            'Cost tracking and safety analysis'
        ],
        'dependencies': [
            'util.deployment_log table',
            'util.hash_binary function',
            'auth.tenant_h table'
        ]
    },
    
    'deploy_critical_schemas.sql': {
        'description': 'Health, Finance, and Performance management schemas',
        'creates': [
            'health schema',
            'finance schema', 
            'performance schema',
            'Business management tables and functions'
        ],
        'dependencies': [
            'util.deployment_log table',
            'business schema',
            'Data Vault 2.0 foundation'
        ]
    },
    
    'deploy_ai_api_integration.sql': {
        'description': 'Production-ready AI API functions with enhancements',
        'creates': [
            'api.ai_secure_chat function',
            'api.ai_chat_history function',
            'api.ai_create_session function',
            'Rate limiting and content safety'
        ],
        'dependencies': [
            'AI Data Vault tables',
            'Business AI functions',
            'Audit infrastructure'
        ]
    }
}

# Validation queries for specific objects deployment scripts want to create
OBJECT_VALIDATION_QUERIES = {
    # Foundation script objects
    'util_schema_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name='util')",
    'deployment_log_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='util' AND table_name='deployment_log')",
    'hash_binary_exists': "SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='util' AND p.proname='hash_binary')",
    'current_load_date_exists': "SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='util' AND p.proname='current_load_date')",
    'get_record_source_exists': "SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='util' AND p.proname='get_record_source')",
    'app_user_exists': "SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='app_user')",
    'barn_user_exists': "SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='barn_user')",
    
    # Core schemas
    'auth_schema_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name='auth')",
    'business_schema_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name='business')",
    'audit_schema_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name='audit')",
    'api_schema_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name='api')",
    
    # Key Data Vault 2.0 tables
    'tenant_h_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='auth' AND table_name='tenant_h')",
    'user_h_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='auth' AND table_name='user_h')",
    
    # AI components
    'ai_schema_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name='ai')",
    'ai_conversation_h_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='ai' AND table_name='conversation_h')",
    'ai_message_h_exists': "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='ai' AND table_name='message_h')",
    
    # Business functions
    'store_ai_interaction_exists': "SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='business' AND p.proname='store_ai_interaction')",
    'log_security_event_exists': "SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='audit' AND p.proname='log_security_event')",
    
    # API functions
    'ai_secure_chat_exists': "SELECT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname='api' AND p.proname='ai_secure_chat')",
} 