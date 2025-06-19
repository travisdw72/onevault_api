#!/usr/bin/env python3
"""
Python Configuration - Most Powerful and Flexible
Allows logic, calculations, imports, and dynamic configuration
"""

import os
from datetime import timedelta
from typing import Dict, List, Any

# Environment detection
ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')
IS_PRODUCTION = ENVIRONMENT == 'production'
IS_DEVELOPMENT = ENVIRONMENT == 'development'

# Database configuration with environment-specific overrides
DATABASE = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 5432)),
    'database': os.getenv('DB_NAME', 'one_vault'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD'),  # Must be set in environment
    'connection_pool': {
        'min_connections': 1 if IS_DEVELOPMENT else 5,
        'max_connections': 10 if IS_DEVELOPMENT else 50,
        'timeout_seconds': 30,
    }
}

# Environment-specific settings with logic
ENVIRONMENTS = {
    'development': {
        'debug': True,
        'log_level': 'DEBUG',
        'auto_create_tables': True,
        'enable_sql_logging': True,
    },
    'production': {
        'debug': False,
        'log_level': 'INFO',
        'auto_create_tables': False,
        'enable_sql_logging': False,
    }
}

# Current environment settings
CURRENT_ENV = ENVIRONMENTS[ENVIRONMENT]

# Security settings with calculations
SECURITY = {
    'password_min_length': 12,
    'session_timeout_minutes': 30 if IS_DEVELOPMENT else 15,
    'max_login_attempts': 10 if IS_DEVELOPMENT else 5,
    'password_requirements': {
        'uppercase': True,
        'lowercase': True,
        'numbers': True,
        'special_chars': True,
        'min_length': 12,
    },
    # Calculate session timeout in seconds
    'session_timeout_seconds': (30 if IS_DEVELOPMENT else 15) * 60,
}

# SQL queries with proper formatting and comments
QUERIES = {
    'get_user_by_email': """
        -- Get user profile with authentication data
        SELECT 
            up.first_name,
            up.last_name,
            up.email,
            uas.username,
            uas.last_login_date,
            uas.password_last_changed,
            EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - uas.password_last_changed)) as password_age_days
        FROM auth.user_profile_s up
        JOIN auth.user_h uh ON up.user_hk = uh.user_hk
        JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
        WHERE up.email = %s 
        AND up.load_end_date IS NULL
        AND uas.load_end_date IS NULL
    """,
    
    'get_tenant_stats': """
        -- Get comprehensive tenant statistics
        SELECT 
            COUNT(DISTINCT uh.user_hk) as user_count,
            COUNT(DISTINCT CASE WHEN ss.session_status = 'ACTIVE' THEN sh.session_hk END) as active_sessions,
            MAX(uas.last_login_date) as last_activity,
            COUNT(DISTINCT CASE WHEN uas.last_login_date >= CURRENT_DATE - INTERVAL '7 days' 
                                THEN uh.user_hk END) as weekly_active_users,
            COUNT(DISTINCT CASE WHEN uas.last_login_date >= CURRENT_DATE - INTERVAL '30 days' 
                                THEN uh.user_hk END) as monthly_active_users
        FROM auth.user_h uh
        LEFT JOIN auth.user_session_l usl ON uh.user_hk = usl.user_hk
        LEFT JOIN auth.session_h sh ON usl.session_hk = sh.session_hk
        LEFT JOIN auth.session_state_s ss ON sh.session_hk = ss.session_hk AND ss.load_end_date IS NULL
        LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk AND uas.load_end_date IS NULL
        WHERE uh.tenant_hk = %s
        GROUP BY uh.tenant_hk
    """,
    
    'audit_password_security': """
        -- Comprehensive password security audit
        SELECT 
            'PASSWORD SECURITY AUDIT' as audit_type,
            table_schema || '.' || table_name as table_location,
            column_name,
            data_type,
            CASE 
                WHEN column_name LIKE '%hash%' AND data_type = 'bytea' THEN '✅ SECURE HASH'
                WHEN column_name LIKE '%salt%' AND data_type = 'bytea' THEN '✅ SECURE SALT'
                WHEN column_name LIKE '%indicator%' THEN '✅ SAFE INDICATOR'
                WHEN column_name LIKE '%password%' AND data_type = 'bytea' THEN '✅ SECURE BINARY'
                WHEN column_name LIKE '%password%' AND data_type != 'bytea' THEN '⚠️ REVIEW NEEDED'
                ELSE '📋 OTHER'
            END as security_status
        FROM information_schema.columns 
        WHERE (LOWER(column_name) LIKE '%password%'
           OR LOWER(column_name) LIKE '%hash%'
           OR LOWER(column_name) LIKE '%salt%')
        AND table_schema NOT LIKE 'pg_%'
        AND table_schema != 'information_schema'
        ORDER BY 
            CASE WHEN column_name LIKE '%password%' AND data_type != 'bytea' THEN 1 ELSE 2 END,
            table_schema, 
            table_name, 
            column_name
    """
}

# Dynamic query generation based on environment
if IS_DEVELOPMENT:
    QUERIES['debug_show_all_tables'] = """
        SELECT schemaname, tablename, tableowner 
        FROM pg_tables 
        WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY schemaname, tablename
    """

# Feature flags based on environment
FEATURES = {
    'enable_debug_queries': IS_DEVELOPMENT,
    'enable_performance_monitoring': True,
    'enable_audit_logging': True,
    'enable_ai_monitoring': IS_PRODUCTION,
    'enable_real_time_alerts': IS_PRODUCTION,
}

# Logging configuration
LOGGING = {
    'level': CURRENT_ENV['log_level'],
    'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    'handlers': ['console'] if IS_DEVELOPMENT else ['console', 'file'],
    'file_path': '/var/log/one_vault/app.log' if IS_PRODUCTION else './app.log',
}

# API configuration with rate limiting
API = {
    'rate_limiting': {
        'enabled': True,
        'requests_per_minute': 1000 if IS_DEVELOPMENT else 100,
        'burst_limit': 50,
    },
    'cors': {
        'enabled': IS_DEVELOPMENT,
        'origins': ['http://localhost:3000'] if IS_DEVELOPMENT else [],
    }
}

# Validation functions
def validate_config():
    """Validate configuration at startup"""
    errors = []
    
    if not DATABASE['password']:
        errors.append("DB_PASSWORD environment variable must be set")
    
    if DATABASE['port'] < 1 or DATABASE['port'] > 65535:
        errors.append(f"Invalid database port: {DATABASE['port']}")
    
    if SECURITY['password_min_length'] < 8:
        errors.append("Password minimum length must be at least 8")
    
    return errors

# Helper functions for dynamic configuration
def get_database_url() -> str:
    """Generate database URL from configuration"""
    return f"postgresql://{DATABASE['user']}:{DATABASE['password']}@{DATABASE['host']}:{DATABASE['port']}/{DATABASE['database']}"

def get_query(query_name: str) -> str:
    """Get a query by name with validation"""
    if query_name not in QUERIES:
        raise ValueError(f"Query '{query_name}' not found")
    return QUERIES[query_name].strip()

def get_feature_flag(feature_name: str) -> bool:
    """Get feature flag value"""
    return FEATURES.get(feature_name, False)

# Export configuration as a single object
CONFIG = {
    'database': DATABASE,
    'environment': ENVIRONMENT,
    'current_env': CURRENT_ENV,
    'security': SECURITY,
    'queries': QUERIES,
    'features': FEATURES,
    'logging': LOGGING,
    'api': API,
}

# Advantages of Python configuration:
ADVANTAGES = [
    "Full programming language power",
    "Environment variable support built-in",
    "Logic and calculations",
    "Dynamic configuration based on conditions",
    "Type hints and validation",
    "Import other modules",
    "Comments and documentation",
    "Complex data transformations",
    "Runtime configuration changes",
    "IDE support with autocomplete",
]

if __name__ == "__main__":
    # Validate configuration when run directly
    errors = validate_config()
    if errors:
        print("Configuration errors:")
        for error in errors:
            print(f"  - {error}")
    else:
        print("✅ Configuration is valid")
        print(f"Environment: {ENVIRONMENT}")
        print(f"Database: {DATABASE['host']}:{DATABASE['port']}/{DATABASE['database']}")
        print(f"Debug mode: {CURRENT_ENV['debug']}")
        print(f"Available queries: {list(QUERIES.keys())}") 