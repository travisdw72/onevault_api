"""
AI Agent Investigation Configuration
Single Source of Truth for Database Investigation Scripts

This module contains all SQL queries, configuration settings, and constants
needed to investigate the current AI agent implementation in the One Vault database.
"""

import os
from typing import Dict, List, Any

# Database Configuration
DATABASE_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'one_vault',
    'user': 'postgres',
    # Password will be requested at runtime
}

# Actual One Vault Schemas
ACTUAL_SCHEMAS = [
    'ai_monitoring',
    'api', 
    'archive',
    'audit',
    'auth',
    'automation',
    'business',  # Fixed the typo from "busines"
    'compliance',
    'config',
    'debug',
    'infomart',
    'media',
    'metadata',
    'public',
    'raw',
    'ref',
    'security',
    'staging',
    'util',
    'validation'
]

# Investigation Categories
INVESTIGATION_CATEGORIES = [
    'SCHEMA_ANALYSIS',
    'AI_AGENT_STRUCTURES', 
    'ZERO_TRUST_SECURITY',
    'LEARNING_LOOPS',
    'AUGMENTED_LEARNING',
    'API_GATEWAY',
    'PERFORMANCE_MONITORING',
    'COMPLIANCE_TRACKING'
]

# SQL Queries for Investigation
SQL_QUERIES = {
    
    # ===== SCHEMA ANALYSIS =====
    'SCHEMA_ANALYSIS': {
        'all_schemas': """
            SELECT 
                schema_name,
                CASE 
                    WHEN schema_name IN ('ai_monitoring', 'automation') THEN 'AI_RELATED'
                    WHEN schema_name IN ('api') THEN 'API_RELATED'
                    WHEN schema_name IN ('auth', 'business', 'audit', 'util', 'compliance', 'security') THEN 'CORE_SYSTEM'
                    WHEN schema_name IN ('raw', 'staging', 'infomart', 'archive') THEN 'DATA_VAULT'
                    WHEN schema_name IN ('config', 'ref', 'metadata', 'validation') THEN 'CONFIGURATION'
                    WHEN schema_name IN ('debug', 'media', 'public') THEN 'SUPPORT'
                    WHEN schema_name LIKE 'pg_%' OR schema_name = 'information_schema' THEN 'SYSTEM'
                    ELSE 'OTHER'
                END as schema_category,
                (SELECT COUNT(*) FROM information_schema.tables t WHERE t.table_schema = s.schema_name) as table_count,
                CASE 
                    WHEN schema_name = ANY(ARRAY['ai_monitoring', 'automation', 'api', 'auth', 'business', 'audit', 'util', 'compliance', 'security', 'raw', 'staging', 'infomart', 'archive', 'config', 'ref', 'metadata', 'validation', 'debug', 'media', 'public']) 
                    THEN 'EXPECTED' 
                    ELSE 'UNEXPECTED' 
                END as schema_status
            FROM information_schema.schemata s
            WHERE schema_name NOT LIKE 'pg_%' 
            AND schema_name != 'information_schema'
            ORDER BY schema_category, schema_name;
        """,
        
        'ai_related_tables': """
            SELECT 
                table_schema,
                table_name,
                table_type,
                CASE 
                    WHEN table_name LIKE '%agent%' THEN 'AGENT_RELATED'
                    WHEN table_name LIKE '%ai%' OR table_name LIKE '%ml%' THEN 'AI_ML_RELATED'
                    WHEN table_name LIKE '%learn%' OR table_name LIKE '%pattern%' THEN 'LEARNING_RELATED'
                    WHEN table_name LIKE '%gateway%' OR table_name LIKE '%api%' THEN 'API_RELATED'
                    WHEN table_name LIKE '%zero_trust%' OR table_name LIKE '%security%' THEN 'SECURITY_RELATED'
                    ELSE 'OTHER_POTENTIAL'
                END as ai_category
            FROM information_schema.tables
            WHERE (
                table_name ILIKE '%agent%' OR 
                table_name ILIKE '%ai%' OR 
                table_name ILIKE '%ml%' OR 
                table_name ILIKE '%learn%' OR 
                table_name ILIKE '%pattern%' OR 
                table_name ILIKE '%gateway%' OR 
                table_name ILIKE '%api%' OR
                table_name ILIKE '%zero_trust%' OR
                table_name ILIKE '%reasoning%' OR
                table_name ILIKE '%intelligence%'
            )
            AND table_schema NOT LIKE 'pg_%'
            AND table_schema != 'information_schema'
            ORDER BY ai_category, table_schema, table_name;
        """,
        
        'data_vault_ai_structures': """
            SELECT 
                table_schema,
                table_name,
                CASE 
                    WHEN table_name LIKE '%_h' THEN 'HUB'
                    WHEN table_name LIKE '%_s' THEN 'SATELLITE'
                    WHEN table_name LIKE '%_l' THEN 'LINK'
                    WHEN table_name LIKE '%_r' THEN 'REFERENCE'
                    ELSE 'OTHER'
                END as data_vault_type,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = t.table_schema 
                 AND c.table_name = t.table_name) as column_count
            FROM information_schema.tables t
            WHERE (
                table_name ILIKE '%agent%' OR 
                table_name ILIKE '%ai%' OR 
                table_name ILIKE '%learn%'
            )
            AND table_name ~ '_(h|s|l|r)$'
            AND table_schema IN ('ai_monitoring', 'automation', 'api', 'business', 'raw', 'staging', 'infomart')
            ORDER BY data_vault_type, table_schema, table_name;
        """,
        
        'ai_monitoring_schema_analysis': """
            SELECT 
                table_name,
                table_type,
                CASE 
                    WHEN table_name LIKE '%_h' THEN 'HUB'
                    WHEN table_name LIKE '%_s' THEN 'SATELLITE'
                    WHEN table_name LIKE '%_l' THEN 'LINK'
                    ELSE 'OTHER'
                END as data_vault_type,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = 'ai_monitoring' 
                 AND c.table_name = t.table_name) as column_count,
                (SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) 
                 FROM information_schema.columns c 
                 WHERE c.table_schema = 'ai_monitoring' 
                 AND c.table_name = t.table_name 
                 AND c.ordinal_position <= 5) as first_5_columns
            FROM information_schema.tables t
            WHERE t.table_schema = 'ai_monitoring'
            ORDER BY data_vault_type, table_name;
        """,
        
        'automation_schema_analysis': """
            SELECT 
                table_name,
                table_type,
                CASE 
                    WHEN table_name LIKE '%_h' THEN 'HUB'
                    WHEN table_name LIKE '%_s' THEN 'SATELLITE'
                    WHEN table_name LIKE '%_l' THEN 'LINK'
                    ELSE 'OTHER'
                END as data_vault_type,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = 'automation' 
                 AND c.table_name = t.table_name) as column_count,
                (SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) 
                 FROM information_schema.columns c 
                 WHERE c.table_schema = 'automation' 
                 AND c.table_name = t.table_name 
                 AND c.ordinal_position <= 5) as first_5_columns
            FROM information_schema.tables t
            WHERE t.table_schema = 'automation'
            ORDER BY data_vault_type, table_name;
        """
    },
    
    # ===== AI AGENT STRUCTURES =====
    'AI_AGENT_STRUCTURES': {
        'agent_hub_tables': """
            SELECT 
                t.table_schema,
                t.table_name,
                c.column_name,
                c.data_type,
                c.is_nullable,
                c.column_default
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_schema = c.table_schema 
                                              AND t.table_name = c.table_name
            WHERE (t.table_name LIKE '%agent%_h' OR t.table_name LIKE '%ai%_h')
            AND t.table_schema IN ('ai_monitoring', 'automation', 'api', 'business', 'security')
            ORDER BY t.table_schema, t.table_name, c.ordinal_position;
        """,
        
        'agent_satellite_tables': """
            SELECT 
                t.table_schema,
                t.table_name,
                c.column_name,
                c.data_type,
                c.character_maximum_length,
                c.is_nullable
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_schema = c.table_schema 
                                              AND t.table_name = c.table_name
            WHERE (t.table_name LIKE '%agent%_s' OR t.table_name LIKE '%ai%_s')
            AND t.table_schema IN ('ai_monitoring', 'automation', 'api', 'business', 'security')
            ORDER BY t.table_schema, t.table_name, c.ordinal_position;
        """,
        
        'agent_functions': """
            SELECT 
                n.nspname as schema_name,
                p.proname as function_name,
                pg_get_function_result(p.oid) as return_type,
                pg_get_function_arguments(p.oid) as arguments
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE (
                p.proname ILIKE '%agent%' OR 
                p.proname ILIKE '%ai%' OR 
                p.proname ILIKE '%reasoning%'
            )
            AND n.nspname NOT LIKE 'pg_%'
            AND n.nspname != 'information_schema'
            ORDER BY n.nspname, p.proname;
        """
    },
    
    # ===== ZERO TRUST SECURITY =====
    'ZERO_TRUST_SECURITY': {
        'security_schema_analysis': """
            SELECT 
                table_name,
                table_type,
                CASE 
                    WHEN table_name LIKE '%_h' THEN 'HUB'
                    WHEN table_name LIKE '%_s' THEN 'SATELLITE'
                    WHEN table_name LIKE '%_l' THEN 'LINK'
                    ELSE 'OTHER'
                END as data_vault_type,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = 'security' 
                 AND c.table_name = t.table_name) as column_count,
                (SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) 
                 FROM information_schema.columns c 
                 WHERE c.table_schema = 'security' 
                 AND c.table_name = t.table_name 
                 AND c.ordinal_position <= 6) as first_6_columns
            FROM information_schema.tables t
            WHERE t.table_schema = 'security'
            ORDER BY data_vault_type, table_name;
        """,
        
        'auth_schema_analysis': """
            SELECT 
                table_name,
                table_type,
                CASE 
                    WHEN table_name LIKE '%_h' THEN 'HUB'
                    WHEN table_name LIKE '%_s' THEN 'SATELLITE'
                    WHEN table_name LIKE '%_l' THEN 'LINK'
                    ELSE 'OTHER'
                END as data_vault_type,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = 'auth' 
                 AND c.table_name = t.table_name) as column_count,
                (SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) 
                 FROM information_schema.columns c 
                 WHERE c.table_schema = 'auth' 
                 AND c.table_name = t.table_name 
                 AND c.ordinal_position <= 6) as first_6_columns
            FROM information_schema.tables t
            WHERE t.table_schema = 'auth'
            ORDER BY data_vault_type, table_name;
        """,
        
        'security_tables': """
            SELECT 
                table_schema,
                table_name,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = t.table_schema 
                 AND c.table_name = t.table_name
                 AND (c.column_name ILIKE '%certificate%' OR 
                      c.column_name ILIKE '%key%' OR 
                      c.column_name ILIKE '%auth%' OR
                      c.column_name ILIKE '%trust%' OR
                      c.column_name ILIKE '%security%')) as security_columns
            FROM information_schema.tables t
            WHERE (
                table_name ILIKE '%security%' OR
                table_name ILIKE '%certificate%' OR
                table_name ILIKE '%auth%' OR
                table_name ILIKE '%trust%' OR
                table_name ILIKE '%session%'
            )
            AND table_schema IN ('security', 'auth', 'compliance')
            ORDER BY security_columns DESC, table_schema, table_name;
        """,
        
        'certificate_management': """
            SELECT 
                t.table_schema,
                t.table_name,
                c.column_name,
                c.data_type,
                c.character_maximum_length
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_schema = c.table_schema 
                                              AND t.table_name = c.table_name
            WHERE (
                c.column_name ILIKE '%certificate%' OR
                c.column_name ILIKE '%cert%' OR
                c.column_name ILIKE '%key%' OR
                c.column_name ILIKE '%pki%'
            )
            AND t.table_schema NOT LIKE 'pg_%'
            ORDER BY t.table_schema, t.table_name, c.ordinal_position;
        """,
        
        'session_management': """
            SELECT 
                t.table_schema,
                t.table_name,
                c.column_name,
                c.data_type,
                c.is_nullable
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_schema = c.table_schema 
                                              AND t.table_name = c.table_name
            WHERE t.table_name ILIKE '%session%'
            AND t.table_schema NOT LIKE 'pg_%'
            ORDER BY t.table_schema, t.table_name, c.ordinal_position;
        """
    },
    
    # ===== LEARNING LOOPS =====
    'LEARNING_LOOPS': {
        'learning_tables': """
            SELECT 
                table_schema,
                table_name,
                table_type,
                (SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) 
                 FROM information_schema.columns c 
                 WHERE c.table_schema = t.table_schema 
                 AND c.table_name = t.table_name
                 AND (c.column_name ILIKE '%learn%' OR 
                      c.column_name ILIKE '%pattern%' OR 
                      c.column_name ILIKE '%feedback%' OR
                      c.column_name ILIKE '%outcome%')) as learning_columns
            FROM information_schema.tables t
            WHERE (
                table_name ILIKE '%learn%' OR
                table_name ILIKE '%pattern%' OR
                table_name ILIKE '%feedback%' OR
                table_name ILIKE '%loop%' OR
                table_name ILIKE '%training%'
            )
            AND table_schema NOT LIKE 'pg_%'
            AND table_schema != 'information_schema'
            ORDER BY table_schema, table_name;
        """,
        
        'pattern_recognition': """
            SELECT 
                t.table_schema,
                t.table_name,
                c.column_name,
                c.data_type,
                CASE 
                    WHEN c.data_type = 'jsonb' THEN 'STRUCTURED_DATA'
                    WHEN c.data_type = 'text' THEN 'TEXT_DATA'
                    WHEN c.data_type IN ('integer', 'bigint', 'decimal', 'numeric') THEN 'NUMERIC_DATA'
                    WHEN c.data_type LIKE '%timestamp%' THEN 'TEMPORAL_DATA'
                    ELSE 'OTHER'
                END as data_category
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_schema = c.table_schema 
                                              AND t.table_name = c.table_name
            WHERE (
                c.column_name ILIKE '%pattern%' OR
                c.column_name ILIKE '%recognition%' OR
                c.column_name ILIKE '%analysis%' OR
                c.column_name ILIKE '%insight%'
            )
            AND t.table_schema NOT LIKE 'pg_%'
            ORDER BY t.table_schema, t.table_name, c.ordinal_position;
        """,
        
        'feedback_mechanisms': """
            SELECT 
                t.table_schema,
                t.table_name,
                COUNT(*) as total_columns,
                COUNT(CASE WHEN c.column_name ILIKE '%feedback%' THEN 1 END) as feedback_columns,
                COUNT(CASE WHEN c.column_name ILIKE '%outcome%' THEN 1 END) as outcome_columns,
                COUNT(CASE WHEN c.column_name ILIKE '%score%' THEN 1 END) as score_columns
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_schema = c.table_schema 
                                              AND t.table_name = c.table_name
            WHERE EXISTS (
                SELECT 1 FROM information_schema.columns c2
                WHERE c2.table_schema = t.table_schema
                AND c2.table_name = t.table_name
                AND (c2.column_name ILIKE '%feedback%' OR 
                     c2.column_name ILIKE '%outcome%' OR 
                     c2.column_name ILIKE '%score%')
            )
            AND t.table_schema NOT LIKE 'pg_%'
            GROUP BY t.table_schema, t.table_name
            ORDER BY (feedback_columns + outcome_columns + score_columns) DESC;
        """
    },
    
    # ===== AUGMENTED LEARNING =====
    'AUGMENTED_LEARNING': {
        'augmented_structures': """
            SELECT 
                table_schema,
                table_name,
                table_type,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = t.table_schema 
                 AND c.table_name = t.table_name) as column_count
            FROM information_schema.tables t
            WHERE (
                table_name ILIKE '%augment%' OR
                table_name ILIKE '%enhance%' OR
                table_name ILIKE '%intelligent%' OR
                table_name ILIKE '%adaptive%' OR
                table_name ILIKE '%cognitive%'
            )
            AND table_schema NOT LIKE 'pg_%'
            AND table_schema != 'information_schema'
            ORDER BY table_schema, table_name;
        """,
        
        'ml_model_storage': """
            SELECT 
                t.table_schema,
                t.table_name,
                c.column_name,
                c.data_type,
                c.character_maximum_length
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_schema = c.table_schema 
                                              AND t.table_name = c.table_name
            WHERE (
                c.column_name ILIKE '%model%' OR
                c.column_name ILIKE '%algorithm%' OR
                c.column_name ILIKE '%weight%' OR
                c.column_name ILIKE '%parameter%' OR
                c.column_name ILIKE '%training%'
            )
            AND t.table_schema NOT LIKE 'pg_%'
            ORDER BY t.table_schema, t.table_name, c.ordinal_position;
        """,
        
        'adaptive_learning': """
            SELECT 
                n.nspname as schema_name,
                p.proname as function_name,
                pg_get_function_result(p.oid) as return_type,
                d.description
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            LEFT JOIN pg_description d ON p.oid = d.objoid
            WHERE (
                p.proname ILIKE '%adapt%' OR 
                p.proname ILIKE '%learn%' OR 
                p.proname ILIKE '%train%' OR
                p.proname ILIKE '%optimize%'
            )
            AND n.nspname NOT LIKE 'pg_%'
            AND n.nspname != 'information_schema'
            ORDER BY n.nspname, p.proname;
        """
    },
    
    # ===== API GATEWAY =====
    'API_GATEWAY': {
        'api_schema_complete_analysis': """
            SELECT 
                table_name,
                table_type,
                CASE 
                    WHEN table_name LIKE '%_h' THEN 'HUB'
                    WHEN table_name LIKE '%_s' THEN 'SATELLITE'
                    WHEN table_name LIKE '%_l' THEN 'LINK'
                    ELSE 'OTHER'
                END as data_vault_type,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = 'api' 
                 AND c.table_name = t.table_name) as column_count,
                (SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) 
                 FROM information_schema.columns c 
                 WHERE c.table_schema = 'api' 
                 AND c.table_name = t.table_name 
                 AND c.ordinal_position <= 8) as first_8_columns
            FROM information_schema.tables t
            WHERE t.table_schema = 'api'
            ORDER BY data_vault_type, table_name;
        """,
        
        'gateway_tables': """
            SELECT 
                table_schema,
                table_name,
                table_type,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = t.table_schema 
                 AND c.table_name = t.table_name
                 AND (c.column_name ILIKE '%api%' OR 
                      c.column_name ILIKE '%gateway%' OR 
                      c.column_name ILIKE '%provider%' OR
                      c.column_name ILIKE '%routing%')) as api_columns
            FROM information_schema.tables t
            WHERE (
                table_name ILIKE '%api%' OR
                table_name ILIKE '%gateway%' OR
                table_name ILIKE '%provider%' OR
                table_name ILIKE '%routing%' OR
                table_name ILIKE '%request%'
            )
            AND table_schema IN ('api', 'business', 'automation', 'ai_monitoring')
            ORDER BY api_columns DESC, table_schema, table_name;
        """,
        
        'provider_management': """
            SELECT 
                t.table_schema,
                t.table_name,
                c.column_name,
                c.data_type,
                c.is_nullable
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_schema = c.table_schema 
                                              AND t.table_name = c.table_name
            WHERE (
                c.column_name ILIKE '%provider%' OR
                c.column_name ILIKE '%openai%' OR
                c.column_name ILIKE '%anthropic%' OR
                c.column_name ILIKE '%google%' OR
                c.column_name ILIKE '%model%'
            )
            AND t.table_schema NOT LIKE 'pg_%'
            ORDER BY t.table_schema, t.table_name, c.ordinal_position;
        """
    },
    
    # ===== PERFORMANCE MONITORING =====
    'PERFORMANCE_MONITORING': {
        'monitoring_tables': """
            SELECT 
                table_schema,
                table_name,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = t.table_schema 
                 AND c.table_name = t.table_name
                 AND (c.column_name ILIKE '%performance%' OR 
                      c.column_name ILIKE '%metric%' OR 
                      c.column_name ILIKE '%monitor%' OR
                      c.column_name ILIKE '%latency%' OR
                      c.column_name ILIKE '%throughput%')) as performance_columns
            FROM information_schema.tables t
            WHERE (
                table_name ILIKE '%monitor%' OR
                table_name ILIKE '%metric%' OR
                table_name ILIKE '%performance%' OR
                table_name ILIKE '%health%' OR
                table_name ILIKE '%stats%'
            )
            AND table_schema NOT LIKE 'pg_%'
            AND table_schema != 'information_schema'
            ORDER BY performance_columns DESC, table_schema, table_name;
        """,
        
        'ai_performance_metrics': """
            SELECT 
                t.table_schema,
                t.table_name,
                c.column_name,
                c.data_type,
                CASE 
                    WHEN c.column_name ILIKE '%latency%' OR c.column_name ILIKE '%time%' THEN 'TIMING'
                    WHEN c.column_name ILIKE '%accuracy%' OR c.column_name ILIKE '%score%' THEN 'QUALITY'
                    WHEN c.column_name ILIKE '%throughput%' OR c.column_name ILIKE '%rate%' THEN 'VOLUME'
                    WHEN c.column_name ILIKE '%cost%' OR c.column_name ILIKE '%price%' THEN 'COST'
                    ELSE 'OTHER'
                END as metric_category
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_schema = c.table_schema 
                                              AND t.table_name = c.table_name
            WHERE (
                (t.table_name ILIKE '%performance%' OR t.table_name ILIKE '%metric%') AND
                (t.table_name ILIKE '%ai%' OR t.table_name ILIKE '%agent%')
            ) OR (
                c.column_name ILIKE '%ai_%' OR 
                c.column_name ILIKE '%agent_%' OR
                c.column_name ILIKE '%model_%'
            )
            AND t.table_schema NOT LIKE 'pg_%'
            ORDER BY metric_category, t.table_schema, t.table_name;
        """
    },
    
    # ===== COMPLIANCE TRACKING =====
    'COMPLIANCE_TRACKING': {
        'compliance_tables': """
            SELECT 
                table_schema,
                table_name,
                (SELECT COUNT(*) FROM information_schema.columns c 
                 WHERE c.table_schema = t.table_schema 
                 AND c.table_name = t.table_name
                 AND (c.column_name ILIKE '%hipaa%' OR 
                      c.column_name ILIKE '%gdpr%' OR 
                      c.column_name ILIKE '%compliance%' OR
                      c.column_name ILIKE '%audit%' OR
                      c.column_name ILIKE '%privacy%')) as compliance_columns
            FROM information_schema.tables t
            WHERE (
                table_name ILIKE '%compliance%' OR
                table_name ILIKE '%audit%' OR
                table_name ILIKE '%privacy%' OR
                table_name ILIKE '%hipaa%' OR
                table_name ILIKE '%gdpr%'
            )
            AND table_schema NOT LIKE 'pg_%'
            AND table_schema != 'information_schema'
            ORDER BY compliance_columns DESC, table_schema, table_name;
        """,
        
        'ai_audit_trails': """
            SELECT 
                t.table_schema,
                t.table_name,
                c.column_name,
                c.data_type
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_schema = c.table_schema 
                                              AND t.table_name = c.table_name
            WHERE (
                t.table_name ILIKE '%audit%' AND 
                (t.table_name ILIKE '%ai%' OR t.table_name ILIKE '%agent%')
            ) OR (
                c.column_name ILIKE '%audit%' AND
                (c.column_name ILIKE '%ai%' OR c.column_name ILIKE '%agent%')
            )
            AND t.table_schema NOT LIKE 'pg_%'
            ORDER BY t.table_schema, t.table_name, c.ordinal_position;
        """
    },
    
    # ===== SUMMARY QUERIES =====
    'SUMMARY': {
        'ai_implementation_summary': """
            SELECT 
                'TOTAL_AI_TABLES' as metric_name,
                COUNT(*) as value
            FROM information_schema.tables
            WHERE (
                table_name ILIKE '%agent%' OR 
                table_name ILIKE '%ai%' OR 
                table_name ILIKE '%ml%' OR 
                table_name ILIKE '%learn%'
            )
            AND table_schema NOT LIKE 'pg_%'
            AND table_schema != 'information_schema'
            
            UNION ALL
            
            SELECT 
                'AI_FUNCTIONS' as metric_name,
                COUNT(*) as value
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE (
                p.proname ILIKE '%agent%' OR 
                p.proname ILIKE '%ai%' OR 
                p.proname ILIKE '%reasoning%'
            )
            AND n.nspname NOT LIKE 'pg_%'
            
            UNION ALL
            
            SELECT 
                'SECURITY_STRUCTURES' as metric_name,
                COUNT(*) as value
            FROM information_schema.tables
            WHERE (
                table_name ILIKE '%security%' OR
                table_name ILIKE '%certificate%' OR
                table_name ILIKE '%auth%' OR
                table_name ILIKE '%trust%'
            )
            AND table_schema NOT LIKE 'pg_%'
            AND table_schema != 'information_schema'
            
            ORDER BY metric_name;
        """,
        
        'data_vault_ai_compliance': """
            SELECT 
                CASE 
                    WHEN table_name LIKE '%_h' THEN 'HUB_TABLES'
                    WHEN table_name LIKE '%_s' THEN 'SATELLITE_TABLES'
                    WHEN table_name LIKE '%_l' THEN 'LINK_TABLES'
                    ELSE 'NON_DATA_VAULT'
                END as structure_type,
                COUNT(*) as table_count,
                STRING_AGG(table_schema || '.' || table_name, ', ' ORDER BY table_schema, table_name) as table_list
            FROM information_schema.tables
            WHERE (
                table_name ILIKE '%agent%' OR 
                table_name ILIKE '%ai%' OR 
                table_name ILIKE '%learn%'
            )
            AND table_schema IN ('ai_monitoring', 'automation', 'api', 'business', 'security', 'auth')
            GROUP BY structure_type
            ORDER BY structure_type;
        """,
        
        'cross_schema_ai_analysis': """
            SELECT 
                table_schema,
                COUNT(*) as total_tables,
                COUNT(CASE WHEN table_name LIKE '%_h' THEN 1 END) as hub_tables,
                COUNT(CASE WHEN table_name LIKE '%_s' THEN 1 END) as satellite_tables,
                COUNT(CASE WHEN table_name LIKE '%_l' THEN 1 END) as link_tables,
                COUNT(CASE WHEN table_name ILIKE '%agent%' OR table_name ILIKE '%ai%' THEN 1 END) as ai_related_tables,
                STRING_AGG(DISTINCT 
                    CASE WHEN table_name ILIKE '%agent%' OR table_name ILIKE '%ai%' 
                    THEN table_name END, ', ') as ai_table_names
            FROM information_schema.tables
            WHERE table_schema IN ('ai_monitoring', 'automation', 'api', 'business', 'security', 'auth', 'compliance')
            GROUP BY table_schema
            ORDER BY ai_related_tables DESC, total_tables DESC;
        """,
        
        'function_analysis_by_schema': """
            SELECT 
                n.nspname as schema_name,
                COUNT(*) as total_functions,
                COUNT(CASE WHEN p.proname ILIKE '%agent%' OR p.proname ILIKE '%ai%' THEN 1 END) as ai_functions,
                STRING_AGG(DISTINCT 
                    CASE WHEN p.proname ILIKE '%agent%' OR p.proname ILIKE '%ai%' 
                    THEN p.proname END, ', ') as ai_function_names
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname IN ('ai_monitoring', 'automation', 'api', 'business', 'security', 'auth', 'util', 'compliance')
            GROUP BY n.nspname
            ORDER BY ai_functions DESC, total_functions DESC;
        """
    }
}

# Investigation Output Configuration
OUTPUT_CONFIG = {
    'report_sections': [
        'Executive Summary',
        'Schema Analysis', 
        'AI Agent Structures',
        'Zero Trust Security',
        'Learning Loops',
        'Augmented Learning',
        'API Gateway',
        'Performance Monitoring', 
        'Compliance Tracking',
        'Implementation Gaps',
        'Recommendations'
    ],
    
    'output_formats': ['CONSOLE', 'HTML', 'JSON', 'CSV'],
    'default_format': 'CONSOLE',
    
    'file_paths': {
        'html_report': 'ai_agent_investigation_report.html',
        'json_export': 'ai_agent_investigation_data.json',
        'csv_export': 'ai_agent_investigation_summary.csv'
    }
}

# Analysis Thresholds and Scoring
ANALYSIS_CONFIG = {
    'completeness_thresholds': {
        'ai_agent_structures': 0.7,      # 70% of expected structures should exist
        'zero_trust_security': 0.8,     # 80% of security components required
        'learning_loops': 0.6,          # 60% of learning components expected
        'api_gateway': 0.5,              # 50% of gateway components needed
        'performance_monitoring': 0.7,   # 70% of monitoring expected
        'compliance_tracking': 0.9       # 90% of compliance components required
    },
    
    'scoring_weights': {
        'data_vault_compliance': 0.25,   # 25% of total score
        'security_implementation': 0.25, # 25% of total score
        'ai_functionality': 0.20,       # 20% of total score
        'monitoring_coverage': 0.15,    # 15% of total score
        'compliance_coverage': 0.15     # 15% of total score
    },
    
    'expected_structures': {
        'agent_hubs': ['ai_agent_h', 'agent_identity_h', 'agent_domain_h'],
        'agent_satellites': ['ai_agent_config_s', 'agent_identity_s', 'agent_performance_s'],
        'security_tables': ['certificate_h', 'certificate_s', 'session_h', 'session_state_s'],
        'learning_structures': ['learning_loop_h', 'pattern_recognition_s', 'feedback_s'],
        'gateway_tables': ['api_provider_h', 'api_request_h', 'routing_rule_s']
    }
}

# Color coding for console output
CONSOLE_COLORS = {
    'HEADER': '\033[95m',
    'BLUE': '\033[94m', 
    'CYAN': '\033[96m',
    'GREEN': '\033[92m',
    'WARNING': '\033[93m',
    'FAIL': '\033[91m',
    'END': '\033[0m',
    'BOLD': '\033[1m',
    'UNDERLINE': '\033[4m'
}

# Report Templates
REPORT_TEMPLATES = {
    'section_header': """
{color}{'='*80}
{title}
{'='*80}{end_color}
    """,
    
    'subsection_header': """
{color}{'-'*60}
{title}
{'-'*60}{end_color}
    """,
    
    'table_row': "| {:<30} | {:<15} | {:<30} |",
    'table_separator': "|{:-<32}|{:-<17}|{:-<32}|"
}

# Expected structures for comparison
EXPECTED_STRUCTURES = {
    'agent_hubs': ['ai_agent_h', 'agent_identity_h', 'agent_domain_h'],
    'agent_satellites': ['ai_agent_config_s', 'agent_identity_s', 'agent_performance_s'],
    'security_tables': ['certificate_h', 'certificate_s', 'session_h', 'session_state_s'],
    'learning_structures': ['learning_loop_h', 'pattern_recognition_s', 'feedback_s'],
    'gateway_tables': ['api_provider_h', 'api_request_h', 'routing_rule_s']
} 
