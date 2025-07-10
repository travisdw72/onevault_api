"""
Phase 1 Zero Trust Configuration Manager
Single source of truth for all Phase 1 components
"""

import os
import yaml
import logging
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, field
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class DatabaseConfig:
    """Database configuration with validation"""
    host: str
    port: int
    database: str
    user: str
    password: str
    connection_timeout: int = 5
    application_name: str = "phase1_zero_trust"
    max_connections: int = 10

@dataclass
class ZeroTrustConfig:
    """Zero Trust configuration"""
    parallel_validation_enabled: bool = True
    log_all_attempts: bool = True
    fail_safe_mode: bool = True
    timeout_ms: int = 5000
    
    # Performance targets
    total_middleware_ms: int = 200
    tenant_validation_ms: int = 50
    api_key_lookup_ms: int = 25
    cache_hit_target_pct: int = 60
    improvement_target_pct: int = 20
    
    # Security settings
    tenant_isolation: bool = True
    cross_tenant_blocking: bool = True
    auto_token_extension: bool = True
    risk_scoring: bool = True
    audit_all_events: bool = True

@dataclass
class CacheConfig:
    """Cache configuration"""
    enabled: bool = True
    provider: str = "memory"
    redis_url: Optional[str] = None
    
    # Cache type configurations
    validation_ttl_seconds: int = 300
    validation_max_entries: int = 1000
    validation_enabled: bool = True
    
    tenant_ttl_seconds: int = 600
    tenant_max_entries: int = 100
    tenant_enabled: bool = True
    
    permission_ttl_seconds: int = 180
    permission_max_entries: int = 500
    permission_enabled: bool = True

@dataclass
class APIConfig:
    """API configuration"""
    test_host: str = "localhost"
    test_port: int = 8000
    debug: bool = True
    reload: bool = True
    
    endpoints: List[str] = field(default_factory=lambda: [
        "/api/patients", "/api/users", "/api/tenants", 
        "/api/dashboard", "/api/reports"
    ])
    
    bearer_tokens: bool = True
    api_keys: bool = True
    session_cookies: bool = True
    query_parameters: bool = False

@dataclass
class LoggingConfig:
    """Logging configuration"""
    level: str = "INFO"
    format: str = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    
    # Parallel validation logging
    parallel_validation_enabled: bool = True
    log_performance: bool = True
    log_cache_hits: bool = True
    log_discrepancies: bool = True
    
    # Audit logging
    audit_enabled: bool = True
    log_all_requests: bool = True
    log_security_events: bool = True
    log_performance_metrics: bool = True
    
    # Log files
    validation_log: str = "logs/phase1_validation.log"
    performance_log: str = "logs/phase1_performance.log"
    security_log: str = "logs/phase1_security.log"
    error_log: str = "logs/phase1_errors.log"

@dataclass
class TestingConfig:
    """Testing configuration"""
    tenants: Dict[str, str] = field(default_factory=dict)
    
    # Test scenarios
    legitimate_access: bool = True
    cross_tenant_access: bool = True
    token_extension: bool = True
    performance_comparison: bool = True
    cache_effectiveness: bool = True
    
    # Performance benchmarks
    baseline_response_ms: int = 150
    target_improvement_pct: int = 20
    max_acceptable_ms: int = 200
    cache_hit_rate_target: int = 60

@dataclass
class ErrorTranslationConfig:
    """Error translation configuration"""
    enabled: bool = True
    user_friendly_messages: bool = True
    technical_details_hidden: bool = True
    translations: Dict[str, Dict[str, str]] = field(default_factory=dict)

@dataclass
class SuccessCriteria:
    """Success criteria for Phase 1"""
    zero_user_disruption: int = 100
    enhanced_validation_success: int = 95
    performance_improvement: int = 20
    complete_logging: int = 100
    cross_tenant_protection: int = 100
    token_extension_success: int = 90
    error_translation_coverage: int = 100

class Phase1Config:
    """
    Phase 1 Configuration Manager - Single Source of Truth
    Uses guard clauses and fail-fast validation
    """
    
    def __init__(self, config_file: Optional[str] = None):
        """Initialize configuration with validation"""
        self.config_file = config_file or self._find_config_file()
        self.raw_config = self._load_config()
        
        # Validate configuration immediately
        self._validate_configuration()
        
        # Build typed configuration objects
        self.database = self._build_database_config()
        self.zero_trust = self._build_zero_trust_config()
        self.cache = self._build_cache_config()
        self.api = self._build_api_config()
        self.logging = self._build_logging_config()
        self.testing = self._build_testing_config()
        self.error_translation = self._build_error_translation_config()
        self.success_criteria = self._build_success_criteria()
        
        # Phase 1 metadata
        self.implementation_name = self.raw_config.get('phase1', {}).get('implementation_name', 'Silent Enhancement')
        self.version = self.raw_config.get('phase1', {}).get('version', '1.0.0')
        self.environment = self.raw_config.get('phase1', {}).get('environment', 'localhost')
        
        logger.info(f"🛡️ Phase 1 Configuration loaded: {self.implementation_name} v{self.version}")
    
    def _find_config_file(self) -> str:
        """Find configuration file with fallback options"""
        possible_paths = [
            "config.yaml",
            "zero_trust_gateway_phase_1/phase1_localhost_implementation/config.yaml",
            os.path.join(os.path.dirname(__file__), "config.yaml")
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                return path
                
        raise FileNotFoundError(f"❌ Configuration file not found in any of: {possible_paths}")
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        if not os.path.exists(self.config_file):
            raise FileNotFoundError(f"❌ Configuration file not found: {self.config_file}")
        
        try:
            with open(self.config_file, 'r') as f:
                config = yaml.safe_load(f)
                
            if not config:
                raise ValueError("❌ Configuration file is empty")
                
            return config
            
        except yaml.YAMLError as e:
            raise ValueError(f"❌ Invalid YAML syntax in {self.config_file}: {e}")
        except Exception as e:
            raise ValueError(f"❌ Failed to load configuration: {e}")
    
    def _validate_configuration(self):
        """Validate configuration with guard clauses"""
        # Check required sections
        required_sections = ['database', 'zero_trust', 'cache', 'api', 'logging']
        for section in required_sections:
            if section not in self.raw_config:
                raise ValueError(f"❌ Required configuration section missing: {section}")
        
        # Check database password environment variable
        if not os.getenv('DB_PASSWORD'):
            raise EnvironmentError("❌ DB_PASSWORD environment variable not set")
        
        # Validate database configuration
        db_config = self.raw_config.get('database', {})
        if not db_config.get('host'):
            raise ValueError("❌ Database host not configured")
        if not isinstance(db_config.get('port'), int):
            raise ValueError("❌ Database port must be an integer")
        if not db_config.get('database'):
            raise ValueError("❌ Database name not configured")
        if not db_config.get('user'):
            raise ValueError("❌ Database user not configured")
        
        # Validate zero trust configuration
        zt_config = self.raw_config.get('zero_trust', {})
        if not isinstance(zt_config.get('parallel_validation', {}).get('enabled'), bool):
            raise ValueError("❌ Parallel validation enabled setting must be boolean")
        
        logger.info("✅ Configuration validation passed")
    
    def _build_database_config(self) -> DatabaseConfig:
        """Build database configuration object"""
        db_config = self.raw_config['database']
        
        return DatabaseConfig(
            host=db_config['host'],
            port=db_config['port'],
            database=db_config['database'],
            user=db_config['user'],
            password=os.getenv('DB_PASSWORD'),
            connection_timeout=db_config.get('connection_timeout', 5),
            application_name=db_config.get('application_name', 'phase1_zero_trust'),
            max_connections=db_config.get('max_connections', 10)
        )
    
    def _build_zero_trust_config(self) -> ZeroTrustConfig:
        """Build zero trust configuration object"""
        zt_config = self.raw_config['zero_trust']
        parallel_config = zt_config.get('parallel_validation', {})
        performance_config = zt_config.get('performance_targets', {})
        security_config = zt_config.get('security', {})
        
        return ZeroTrustConfig(
            parallel_validation_enabled=parallel_config.get('enabled', True),
            log_all_attempts=parallel_config.get('log_all_attempts', True),
            fail_safe_mode=parallel_config.get('fail_safe_mode', True),
            timeout_ms=parallel_config.get('timeout_ms', 5000),
            
            total_middleware_ms=performance_config.get('total_middleware_ms', 200),
            tenant_validation_ms=performance_config.get('tenant_validation_ms', 50),
            api_key_lookup_ms=performance_config.get('api_key_lookup_ms', 25),
            cache_hit_target_pct=performance_config.get('cache_hit_target_pct', 60),
            improvement_target_pct=performance_config.get('improvement_target_pct', 20),
            
            tenant_isolation=security_config.get('tenant_isolation', True),
            cross_tenant_blocking=security_config.get('cross_tenant_blocking', True),
            auto_token_extension=security_config.get('auto_token_extension', True),
            risk_scoring=security_config.get('risk_scoring', True),
            audit_all_events=security_config.get('audit_all_events', True)
        )
    
    def _build_cache_config(self) -> CacheConfig:
        """Build cache configuration object"""
        cache_config = self.raw_config['cache']
        validation_cache = cache_config.get('validation_cache', {})
        tenant_cache = cache_config.get('tenant_cache', {})
        permission_cache = cache_config.get('permission_cache', {})
        
        return CacheConfig(
            enabled=cache_config.get('enabled', True),
            provider=cache_config.get('provider', 'memory'),
            redis_url=cache_config.get('redis_url'),
            
            validation_ttl_seconds=validation_cache.get('ttl_seconds', 300),
            validation_max_entries=validation_cache.get('max_entries', 1000),
            validation_enabled=validation_cache.get('enabled', True),
            
            tenant_ttl_seconds=tenant_cache.get('ttl_seconds', 600),
            tenant_max_entries=tenant_cache.get('max_entries', 100),
            tenant_enabled=tenant_cache.get('enabled', True),
            
            permission_ttl_seconds=permission_cache.get('ttl_seconds', 180),
            permission_max_entries=permission_cache.get('max_entries', 500),
            permission_enabled=permission_cache.get('enabled', True)
        )
    
    def _build_api_config(self) -> APIConfig:
        """Build API configuration object"""
        api_config = self.raw_config['api']
        test_server = api_config.get('test_server', {})
        auth_config = api_config.get('authentication', {})
        
        return APIConfig(
            test_host=test_server.get('host', 'localhost'),
            test_port=test_server.get('port', 8000),
            debug=test_server.get('debug', True),
            reload=test_server.get('reload', True),
            
            endpoints=api_config.get('endpoints', []),
            
            bearer_tokens=auth_config.get('bearer_tokens', True),
            api_keys=auth_config.get('api_keys', True),
            session_cookies=auth_config.get('session_cookies', True),
            query_parameters=auth_config.get('query_parameters', False)
        )
    
    def _build_logging_config(self) -> LoggingConfig:
        """Build logging configuration object"""
        log_config = self.raw_config['logging']
        parallel_config = log_config.get('parallel_validation', {})
        audit_config = log_config.get('audit', {})
        files_config = log_config.get('files', {})
        
        return LoggingConfig(
            level=log_config.get('level', 'INFO'),
            format=log_config.get('format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s'),
            
            parallel_validation_enabled=parallel_config.get('enabled', True),
            log_performance=parallel_config.get('log_performance', True),
            log_cache_hits=parallel_config.get('log_cache_hits', True),
            log_discrepancies=parallel_config.get('log_discrepancies', True),
            
            audit_enabled=audit_config.get('enabled', True),
            log_all_requests=audit_config.get('log_all_requests', True),
            log_security_events=audit_config.get('log_security_events', True),
            log_performance_metrics=audit_config.get('log_performance_metrics', True),
            
            validation_log=files_config.get('validation_log', 'logs/phase1_validation.log'),
            performance_log=files_config.get('performance_log', 'logs/phase1_performance.log'),
            security_log=files_config.get('security_log', 'logs/phase1_security.log'),
            error_log=files_config.get('error_log', 'logs/phase1_errors.log')
        )
    
    def _build_testing_config(self) -> TestingConfig:
        """Build testing configuration object"""
        test_config = self.raw_config.get('testing', {})
        scenarios = test_config.get('test_scenarios', {})
        benchmarks = test_config.get('performance_benchmarks', {})
        
        return TestingConfig(
            tenants=test_config.get('tenants', {}),
            
            legitimate_access=scenarios.get('legitimate_access', True),
            cross_tenant_access=scenarios.get('cross_tenant_access', True),
            token_extension=scenarios.get('token_extension', True),
            performance_comparison=scenarios.get('performance_comparison', True),
            cache_effectiveness=scenarios.get('cache_effectiveness', True),
            
            baseline_response_ms=benchmarks.get('baseline_response_ms', 150),
            target_improvement_pct=benchmarks.get('target_improvement_pct', 20),
            max_acceptable_ms=benchmarks.get('max_acceptable_ms', 200),
            cache_hit_rate_target=benchmarks.get('cache_hit_rate_target', 60)
        )
    
    def _build_error_translation_config(self) -> ErrorTranslationConfig:
        """Build error translation configuration object"""
        error_config = self.raw_config.get('error_translation', {})
        
        return ErrorTranslationConfig(
            enabled=error_config.get('enabled', True),
            user_friendly_messages=error_config.get('user_friendly_messages', True),
            technical_details_hidden=error_config.get('technical_details_hidden', True),
            translations=error_config.get('translations', {})
        )
    
    def _build_success_criteria(self) -> SuccessCriteria:
        """Build success criteria object"""
        criteria = self.raw_config.get('success_criteria', {})
        
        return SuccessCriteria(
            zero_user_disruption=criteria.get('zero_user_disruption', 100),
            enhanced_validation_success=criteria.get('enhanced_validation_success', 95),
            performance_improvement=criteria.get('performance_improvement', 20),
            complete_logging=criteria.get('complete_logging', 100),
            cross_tenant_protection=criteria.get('cross_tenant_protection', 100),
            token_extension_success=criteria.get('token_extension_success', 90),
            error_translation_coverage=criteria.get('error_translation_coverage', 100)
        )
    
    def validate_environment(self) -> bool:
        """Validate runtime environment"""
        try:
            # Check database connection
            import psycopg2
            conn = psycopg2.connect(
                host=self.database.host,
                port=self.database.port,
                database=self.database.database,
                user=self.database.user,
                password=self.database.password,
                connect_timeout=5
            )
            conn.close()
            logger.info("✅ Database connection validated")
            
            # Create log directories
            for log_file in [self.logging.validation_log, self.logging.performance_log, 
                           self.logging.security_log, self.logging.error_log]:
                log_dir = os.path.dirname(log_file)
                if log_dir and not os.path.exists(log_dir):
                    os.makedirs(log_dir, exist_ok=True)
            logger.info("✅ Log directories created")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Environment validation failed: {e}")
            return False
    
    def get_tenant_hk(self, tenant_name: str) -> Optional[str]:
        """Get tenant hash key by name"""
        return self.testing.tenants.get(tenant_name)
    
    def is_production_ready(self) -> bool:
        """Check if configuration is production ready"""
        prod_config = self.raw_config.get('production', {})
        return all([
            prod_config.get('deployment_ready', False),
            prod_config.get('migration_scripts_ready', False),
            prod_config.get('monitoring_configured', False),
            prod_config.get('alerts_configured', False),
            prod_config.get('rollback_plan_tested', False)
        ])

# Global configuration instance
_config_instance: Optional[Phase1Config] = None

def get_config() -> Phase1Config:
    """Get global configuration instance (singleton pattern)"""
    global _config_instance
    
    if _config_instance is None:
        _config_instance = Phase1Config()
        
    return _config_instance

def reload_config() -> Phase1Config:
    """Reload configuration from file"""
    global _config_instance
    _config_instance = None
    return get_config()

# Convenience functions for common configuration access
def get_database_config() -> DatabaseConfig:
    """Get database configuration"""
    return get_config().database

def get_zero_trust_config() -> ZeroTrustConfig:
    """Get zero trust configuration"""
    return get_config().zero_trust

def get_cache_config() -> CacheConfig:
    """Get cache configuration"""
    return get_config().cache

def is_parallel_validation_enabled() -> bool:
    """Check if parallel validation is enabled"""
    return get_config().zero_trust.parallel_validation_enabled

def should_fail_safe() -> bool:
    """Check if fail-safe mode is enabled"""
    return get_config().zero_trust.fail_safe_mode 