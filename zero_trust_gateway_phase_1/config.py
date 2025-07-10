#!/usr/bin/env python3
"""
Zero Trust Gateway Configuration

Configuration settings for Zero Trust Gateway Phase 1 implementation
that leverages existing Data Vault 2.0 infrastructure.
"""

import os
from typing import Dict, List, Optional
from dataclasses import dataclass
from datetime import timedelta

@dataclass
class DatabaseConfig:
    """Database connection configuration"""
    host: str = os.getenv('DB_HOST', 'localhost')
    port: int = int(os.getenv('DB_PORT', '5432'))
    database: str = os.getenv('DB_NAME', 'one_vault_site_testing')
    user: str = os.getenv('DB_USER', 'postgres')
    password: str = os.getenv('DB_PASSWORD', 'your_password_here')
    
    # Connection pool settings
    min_connections: int = 2
    max_connections: int = 10
    connection_timeout: int = 5
    
    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary for psycopg2"""
        return {
            'host': self.host,
            'port': str(self.port),
            'database': self.database,
            'user': self.user,
            'password': self.password
        }

@dataclass
class RedisConfig:
    """Redis cache configuration"""
    url: str = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
    enabled: bool = os.getenv('REDIS_ENABLED', 'true').lower() == 'true'
    
    # Cache TTL settings
    api_token_ttl: int = 300  # 5 minutes
    session_token_ttl: int = 300  # 5 minutes
    tenant_data_ttl: int = 600  # 10 minutes

@dataclass
class SecurityConfig:
    """Security configuration settings"""
    # Performance targets (milliseconds)
    tenant_validation_target_ms: int = 50
    api_key_lookup_target_ms: int = 25
    total_middleware_target_ms: int = 200
    
    # Rate limiting
    requests_per_minute: int = 1000
    burst_limit: int = 100
    
    # Token validation
    api_token_max_age_days: int = 30
    session_token_max_age_hours: int = 24
    
    # Risk scoring thresholds
    low_risk_threshold: float = 0.3
    medium_risk_threshold: float = 0.6
    high_risk_threshold: float = 0.8
    
    # Access levels
    access_levels: List[str] = None
    
    def __post_init__(self):
        if self.access_levels is None:
            self.access_levels = ['RESTRICTED', 'STANDARD', 'ELEVATED', 'ADMIN']

@dataclass
class AuditConfig:
    """Audit logging configuration"""
    enabled: bool = True
    log_all_requests: bool = True
    log_failed_attempts: bool = True
    log_performance_metrics: bool = True
    
    # Audit retention
    audit_retention_days: int = 2555  # 7 years for compliance
    performance_metrics_retention_days: int = 90
    
    # Log levels
    success_log_level: str = 'INFO'
    failure_log_level: str = 'WARNING'
    error_log_level: str = 'ERROR'

@dataclass
class MonitoringConfig:
    """Monitoring and alerting configuration"""
    enabled: bool = True
    
    # Performance alerting thresholds
    avg_response_time_alert_ms: int = 250
    error_rate_alert_percent: float = 5.0
    cache_hit_rate_alert_percent: float = 80.0
    
    # Health check settings
    health_check_interval_seconds: int = 30
    health_check_timeout_seconds: int = 5
    
    # Metrics collection
    collect_detailed_metrics: bool = True
    metrics_batch_size: int = 100

@dataclass
class ZeroTrustConfig:
    """Complete Zero Trust Gateway configuration"""
    # Environment
    environment: str = os.getenv('ENVIRONMENT', 'development')
    debug: bool = os.getenv('DEBUG', 'false').lower() == 'true'
    
    # Component configurations
    database: DatabaseConfig = None
    redis: RedisConfig = None
    security: SecurityConfig = None
    audit: AuditConfig = None
    monitoring: MonitoringConfig = None
    
    # Existing Data Vault 2.0 functions to use
    zero_trust_function: str = 'ai_monitoring.validate_zero_trust_access'
    api_token_validation_function: str = 'auth.validate_production_api_token'
    session_validation_function: str = 'auth.validate_token_and_session'
    
    # Existing schemas and tables
    tenant_hub_table: str = 'auth.tenant_h'
    tenant_profile_table: str = 'auth.tenant_profile_s'
    api_token_hub_table: str = 'auth.api_token_h'
    api_token_satellite_table: str = 'auth.api_token_s'
    user_token_link_table: str = 'auth.user_token_l'
    session_hub_table: str = 'auth.session_h'
    session_state_table: str = 'auth.session_state_s'
    user_session_link_table: str = 'auth.user_session_l'
    audit_event_hub_table: str = 'audit.audit_event_h'
    audit_detail_table: str = 'audit.audit_detail_s'
    
    # Bypass paths (no authentication required)
    bypass_paths: List[str] = None
    
    def __post_init__(self):
        # Initialize component configs if not provided
        if self.database is None:
            self.database = DatabaseConfig()
        if self.redis is None:
            self.redis = RedisConfig()
        if self.security is None:
            self.security = SecurityConfig()
        if self.audit is None:
            self.audit = AuditConfig()
        if self.monitoring is None:
            self.monitoring = MonitoringConfig()
        
        # Default bypass paths
        if self.bypass_paths is None:
            self.bypass_paths = [
                '/health',
                '/metrics',
                '/docs',
                '/openapi.json',
                '/favicon.ico',
                '/static/',
                '/public/'
            ]
    
    def is_production(self) -> bool:
        """Check if running in production environment"""
        return self.environment.lower() == 'production'
    
    def is_development(self) -> bool:
        """Check if running in development environment"""
        return self.environment.lower() == 'development'
    
    def get_log_level(self) -> str:
        """Get appropriate log level for environment"""
        if self.is_production():
            return 'INFO'
        elif self.debug:
            return 'DEBUG'
        else:
            return 'INFO'

# Global configuration instance
config = ZeroTrustConfig()

# Environment-specific overrides
if config.is_production():
    # Production optimizations
    config.security.total_middleware_target_ms = 100  # Stricter in production
    config.security.requests_per_minute = 5000  # Higher limits in production
    config.redis.enabled = True  # Always use Redis in production
    config.database.max_connections = 20  # More connections in production
    config.audit.log_all_requests = True  # Full audit trail in production
    config.monitoring.collect_detailed_metrics = True
    
elif config.is_development():
    # Development conveniences
    config.security.total_middleware_target_ms = 500  # More relaxed in dev
    config.security.requests_per_minute = 100  # Lower limits in dev
    config.redis.enabled = False  # Optional Redis in development
    config.database.max_connections = 5  # Fewer connections in dev
    config.audit.log_all_requests = False  # Minimal audit in dev
    config.monitoring.collect_detailed_metrics = False

def get_config() -> ZeroTrustConfig:
    """Get the global configuration instance"""
    return config

def validate_config() -> List[str]:
    """Validate configuration and return any errors"""
    errors = []
    
    # Validate database configuration
    if not config.database.host:
        errors.append("Database host is required")
    if not config.database.database:
        errors.append("Database name is required")
    if not config.database.user:
        errors.append("Database user is required")
    if not config.database.password or config.database.password == 'your_password_here':
        errors.append("Database password must be set")
    
    # Validate Redis configuration if enabled
    if config.redis.enabled and not config.redis.url:
        errors.append("Redis URL is required when Redis is enabled")
    
    # Validate security settings
    if config.security.total_middleware_target_ms < 10:
        errors.append("Total middleware target time must be at least 10ms")
    if config.security.requests_per_minute < 1:
        errors.append("Requests per minute must be at least 1")
    
    # Validate thresholds
    if not (0 <= config.security.low_risk_threshold <= 1):
        errors.append("Low risk threshold must be between 0 and 1")
    if not (0 <= config.security.medium_risk_threshold <= 1):
        errors.append("Medium risk threshold must be between 0 and 1")
    if not (0 <= config.security.high_risk_threshold <= 1):
        errors.append("High risk threshold must be between 0 and 1")
    
    # Validate environment
    if config.environment not in ['development', 'staging', 'production']:
        errors.append("Environment must be one of: development, staging, production")
    
    return errors

def print_config_summary():
    """Print a summary of the current configuration"""
    print("🛡️  Zero Trust Gateway Configuration Summary")
    print("=" * 50)
    print(f"Environment: {config.environment}")
    print(f"Debug Mode: {config.debug}")
    print(f"Database: {config.database.host}:{config.database.port}/{config.database.database}")
    print(f"Redis Enabled: {config.redis.enabled}")
    print(f"Audit Enabled: {config.audit.enabled}")
    print(f"Monitoring Enabled: {config.monitoring.enabled}")
    print(f"Performance Target: {config.security.total_middleware_target_ms}ms")
    print(f"Rate Limit: {config.security.requests_per_minute}/minute")
    print(f"Access Levels: {', '.join(config.security.access_levels)}")
    print("=" * 50)
    
    # Validate and show any errors
    errors = validate_config()
    if errors:
        print("❌ Configuration Errors:")
        for error in errors:
            print(f"   - {error}")
    else:
        print("✅ Configuration is valid")

if __name__ == "__main__":
    print_config_summary() 