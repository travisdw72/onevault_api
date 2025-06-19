"""
Site Tracking Database Testing Configuration
Single source of truth for all database testing parameters and SQL scripts
"""

import os
from pathlib import Path

# =============================================================================
# DATABASE CONNECTION CONFIGURATION
# =============================================================================

DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'one_vault',
    'user': 'postgres',
    # Password will be requested at runtime for security
    'options': '-c search_path=public,auth,business,staging,raw,api,util,audit'
}

# =============================================================================
# SCRIPT PATHS AND EXECUTION ORDER
# =============================================================================

SCRIPT_DIR = Path(__file__).parent
SQL_SCRIPTS = [
    {
        'order': 0,
        'name': 'Integration Strategy',
        'file': '00_integration_strategy.sql',
        'path': SCRIPT_DIR / '00_integration_strategy.sql',
        'description': 'Validates integration with existing security and audit infrastructure',
        'required_schemas': ['util', 'auth'],
        'creates_tables': [],
        'creates_functions': ['util.validate_security_integration'],
        'creates_views': ['util.web_tracking_integration_guide']
    },
    {
        'order': 1,
        'name': 'Raw Layer',
        'file': '01_create_raw_layer.sql',
        'path': SCRIPT_DIR / '01_create_raw_layer.sql',
        'description': 'Simple ETL landing zone for tracking events',
        'required_schemas': ['raw'],
        'creates_tables': ['raw.web_tracking_events_r'],
        'creates_functions': ['raw.ingest_tracking_event', 'raw.ingest_tracking_events_batch', 'raw.get_processing_stats']
    },
    {
        'order': 2,
        'name': 'Staging Layer',
        'file': '02_create_staging_layer.sql',
        'path': SCRIPT_DIR / '02_create_staging_layer.sql',
        'description': 'Simple ETL processing layer for validation and enrichment',
        'required_schemas': ['staging'],
        'creates_tables': ['staging.web_tracking_events_s'],
        'creates_functions': ['staging.validate_and_enrich_event', 'staging.extract_utm_param', 'staging.url_decode', 
                             'staging.get_processing_stats', 'staging.process_raw_events_batch']
    },
    {
        'order': 3,
        'name': 'Business Hubs',
        'file': '03_create_business_hubs.sql',
        'path': SCRIPT_DIR / '03_create_business_hubs.sql',
        'description': 'Data Vault 2.0 hub tables for business entities',
        'required_schemas': ['business'],
        'creates_tables': ['business.site_session_h', 'business.site_visitor_h', 'business.site_event_h', 
                          'business.site_page_h', 'business.business_item_h'],
        'creates_functions': ['business.get_or_create_site_session_hk', 'business.get_or_create_site_visitor_hk',
                             'business.get_or_create_site_event_hk', 'business.get_or_create_site_page_hk',
                             'business.get_or_create_business_item_hk', 'business.normalize_page_url',
                             'business.get_hub_statistics']
    },
    {
        'order': 4,
        'name': 'Business Links',
        'file': '04_create_business_links.sql',
        'path': SCRIPT_DIR / '04_create_business_links.sql',
        'description': 'Data Vault 2.0 link tables for entity relationships',
        'required_schemas': ['business'],
        'creates_tables': ['business.session_visitor_l', 'business.event_session_l', 'business.event_page_l',
                          'business.event_business_item_l', 'business.session_page_l', 'business.visitor_business_item_l'],
        'creates_functions': ['business.get_or_create_session_visitor_link', 'business.get_or_create_event_session_link',
                             'business.get_or_create_event_page_link', 'business.get_or_create_event_business_item_link',
                             'business.get_or_create_session_page_link', 'business.get_or_create_visitor_business_item_link',
                             'business.create_tracking_event_links', 'business.get_link_statistics',
                             'business.analyze_visitor_journey_patterns']
    },
    {
        'order': 5,
        'name': 'Business Satellites',
        'file': '05_create_business_satellites.sql',
        'path': SCRIPT_DIR / '05_create_business_satellites.sql',
        'description': 'Data Vault 2.0 satellite tables for descriptive attributes',
        'required_schemas': ['business'],
        'creates_tables': ['business.site_session_details_s', 'business.site_visitor_details_s', 
                          'business.site_event_details_s', 'business.site_page_details_s', 
                          'business.business_item_details_s'],
        'creates_functions': ['business.update_session_details', 'business.update_visitor_details',
                             'business.insert_event_details', 'business.process_staging_to_satellites',
                             'business.get_satellite_statistics']
    },
    {
        'order': 6,
        'name': 'API Layer',
        'file': '06_create_api_layer.sql',
        'path': SCRIPT_DIR / '06_create_api_layer.sql',
        'description': 'API endpoints following auth_login pattern with tenant_hk usage',
        'required_schemas': ['api', 'auth'],
        'creates_tables': ['auth.site_tracking_api_keys_h', 'auth.site_tracking_api_key_details_s',
                          'auth.site_tracking_api_key_usage_s'],
        'creates_functions': ['api.track_event', 'api.check_rate_limit', 'api.update_api_key_usage',
                             'api.log_tracking_attempt', 'api.create_site_tracking_api_key']
    }
]

# =============================================================================
# DATABASE VALIDATION QUERIES
# =============================================================================

# Check for existing schemas
SCHEMA_CHECK_QUERIES = {
    'auth': "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'auth'",
    'business': "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'business'",
    'raw': "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'raw'",
    'staging': "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'staging'",
    'api': "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'api'",
    'util': "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'util'",
    'audit': "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'audit'"
}

# Check for required existing tables/functions
PREREQUISITE_CHECKS = {
    'tenant_hub': {
        'query': "SELECT table_name FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'tenant_h'",
        'description': 'Auth tenant hub table (required for tenant_hk references)',
        'critical': True
    },
    'util_functions': {
        'query': """
            SELECT routine_name FROM information_schema.routines 
            WHERE routine_schema = 'util' 
            AND routine_name IN ('hash_binary', 'current_load_date', 'get_record_source')
        """,
        'description': 'Utility functions for Data Vault 2.0 operations',
        'critical': True
    },
    'audit_schema': {
        'query': "SELECT table_name FROM information_schema.tables WHERE table_schema = 'audit'",
        'description': 'Audit schema for logging API activities',
        'critical': False
    }
}

# Check for conflicts with existing tables
CONFLICT_CHECK_QUERIES = {
    'site_tracking_tables': """
        SELECT table_schema, table_name 
        FROM information_schema.tables 
        WHERE table_name LIKE '%site_%' OR table_name LIKE '%tracking%'
        ORDER BY table_schema, table_name
    """,
    'site_tracking_functions': """
        SELECT routine_schema, routine_name 
        FROM information_schema.routines 
        WHERE routine_name LIKE '%track%' OR routine_name LIKE '%site_%'
        ORDER BY routine_schema, routine_name
    """,
    'api_endpoints': """
        SELECT routine_schema, routine_name 
        FROM information_schema.routines 
        WHERE routine_schema = 'api' AND routine_name LIKE '%track%'
        ORDER BY routine_name
    """
}

# Post-deployment validation queries
VALIDATION_QUERIES = {
    'table_counts': """
        SELECT 
            schemaname,
            tablename,
            CASE 
                WHEN tablename LIKE '%_h' THEN 'Hub'
                WHEN tablename LIKE '%_l' THEN 'Link'
                WHEN tablename LIKE '%_s' THEN 'Satellite'
                WHEN tablename LIKE '%_r' THEN 'Raw ETL'
                ELSE 'Other'
            END as table_type
        FROM pg_tables 
        WHERE schemaname IN ('raw', 'staging', 'business', 'auth')
        AND (tablename LIKE '%site_%' OR tablename LIKE '%tracking%')
        ORDER BY schemaname, table_type, tablename
    """,
    'function_counts': """
        SELECT 
            routine_schema,
            COUNT(*) as function_count,
            array_agg(routine_name ORDER BY routine_name) as functions
        FROM information_schema.routines 
        WHERE routine_schema IN ('raw', 'staging', 'business', 'api')
        AND (routine_name LIKE '%track%' OR routine_name LIKE '%site_%')
        GROUP BY routine_schema
        ORDER BY routine_schema
    """,
    'tenant_isolation_check': """
        SELECT 
            t.table_schema,
            t.table_name,
            CASE WHEN c.column_name IS NOT NULL THEN 'YES' ELSE 'NO' END as has_tenant_hk
        FROM information_schema.tables t
        LEFT JOIN information_schema.columns c ON (
            t.table_schema = c.table_schema 
            AND t.table_name = c.table_name 
            AND c.column_name = 'tenant_hk'
        )
        WHERE t.table_schema IN ('raw', 'staging', 'business', 'auth')
        AND (t.table_name LIKE '%site_%' OR t.table_name LIKE '%tracking%')
        ORDER BY t.table_schema, t.table_name
    """
}

# =============================================================================
# TEST DATA CONFIGURATION
# =============================================================================

# Sample test data for validation
TEST_DATA = {
    'tenant_lookup': """
        SELECT tenant_hk, tenant_bk 
        FROM auth.tenant_h 
        WHERE tenant_bk LIKE '%test%' OR tenant_bk LIKE '%demo%'
        LIMIT 1
    """,
    'sample_tracking_event': {
        'evt_type': 'page_view',
        'session_id': 'test_session_123',
        'user_id': 'test_user_456',
        'page_url': 'https://example.com/test-page',
        'page_title': 'Test Page',
        'timestamp': '2024-01-15T10:00:00Z',
        'device_type': 'desktop',
        'browser_name': 'Chrome'
    }
}

# =============================================================================
# ERROR PATTERNS AND FIXES
# =============================================================================

COMMON_ISSUES = {
    'missing_tenant_table': {
        'pattern': 'relation "auth.tenant_h" does not exist',
        'fix': 'The auth.tenant_h table is required. Please ensure your auth schema is properly deployed.'
    },
    'missing_util_functions': {
        'pattern': 'function util.hash_binary does not exist',
        'fix': 'Utility functions are required. Please ensure your util schema is properly deployed.'
    },
    'schema_missing': {
        'pattern': 'schema ".*" does not exist',
        'fix': 'Required schema is missing. The script should create it with CREATE SCHEMA IF NOT EXISTS.'
    },
    'tenant_hk_vs_tenant_bk': {
        'pattern': 'column "tenant_bk" does not exist',
        'fix': 'Script is using tenant_bk instead of tenant_hk. All internal operations should use tenant_hk.'
    }
}

# =============================================================================
# DEPLOYMENT CONFIGURATION
# =============================================================================

DEPLOYMENT_CONFIG = {
    'dry_run': True,  # Set to False for actual deployment
    'rollback_on_error': True,
    'create_backup': True,
    'log_file': 'site_tracking_deployment.log',
    'batch_size': 1000,  # For large data operations
    'timeout_seconds': 300  # Per script timeout
}

# =============================================================================
# REPORTING CONFIGURATION
# =============================================================================

REPORT_CONFIG = {
    'output_format': 'console',  # console, json, html
    'detail_level': 'full',  # minimal, summary, full
    'export_results': True,
    'results_file': 'site_tracking_validation_results.json'
} 