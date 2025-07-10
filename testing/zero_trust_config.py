"""
Zero Trust Configuration
========================

Configuration settings for Phase 1 zero trust implementation:
- Middleware settings
- Cache configuration  
- Security thresholds
- Monitoring settings
"""

import os
from typing import List, Dict, Any
from datetime import timedelta

class ZeroTrustConfig:
    """Zero Trust configuration settings"""
    
    # ================================
    # CORE SECURITY SETTINGS
    # ================================
    
    # Enable/disable zero trust features
    ZERO_TRUST_ENABLED: bool = True
    PHASE_1_COMPLETE: bool = True
    
    # Tenant validation settings
    TENANT_VALIDATION_ENABLED: bool = True
    RESOURCE_VALIDATION_ENABLED: bool = True
    CROSS_TENANT_BLOCKING_ENABLED: bool = True
    
    # ================================
    # MIDDLEWARE CONFIGURATION
    # ================================
    
    # Paths that skip zero trust validation
    EXCLUDED_PATHS: List[str] = [
        "/",
        "/health",
        "/health/detailed", 
        "/health/zero-trust",
        "/docs",
        "/redoc",
        "/openapi.json",
        "/favicon.ico"
    ]
    
    # API key validation
    API_KEY_CACHE_TTL_SECONDS: int = 300  # 5 minutes
    API_KEY_VALIDATION_TIMEOUT_SECONDS: int = 10
    
    # Session validation
    SESSION_VALIDATION_ENABLED: bool = True
    SESSION_CACHE_TTL_SECONDS: int = 60   # 1 minute
    
    # ================================
    # RESOURCE VALIDATION SETTINGS
    # ================================
    
    # Validation cache configuration
    VALIDATION_CACHE_ENABLED: bool = True
    VALIDATION_CACHE_TTL_SECONDS: int = 300  # 5 minutes
    VALIDATION_CACHE_MAX_SIZE: int = 10000
    VALIDATION_CACHE_CLEANUP_INTERVAL_SECONDS: int = 600  # 10 minutes
    
    # Resource types to validate
    VALIDATED_RESOURCE_TYPES: List[str] = [
        "user_bk",
        "user_id", 
        "email",
        "username",
        "asset_bk",
        "asset_id",
        "transaction_bk",
        "transaction_id",
        "session_token",
        "session_id",
        "agent_bk",
        "agent_id"
    ]
    
    # Resource types to skip validation (safe public data)
    SKIPPED_RESOURCE_TYPES: List[str] = [
        "page_url",
        "event_type",
        "user_agent",
        "ip_address",
        "timestamp",
        "version",
        "api_version"
    ]
    
    # ================================
    # QUERY REWRITER SETTINGS
    # ================================
    
    # SQL query rewriting
    QUERY_REWRITER_ENABLED: bool = True
    AUTO_TENANT_FILTERING: bool = True
    SQL_INJECTION_PROTECTION: bool = True
    
    # Tables that require tenant filtering
    TENANT_FILTERED_TABLES: List[str] = [
        "auth.user_h",
        "auth.session_h", 
        "business.asset_h",
        "business.transaction_h",
        "ai_agents.agent_h"
    ]
    
    # Query execution limits
    MAX_QUERY_EXECUTION_TIME_SECONDS: int = 30
    MAX_QUERY_RESULT_SIZE: int = 10000
    
    # ================================
    # AUDIT AND LOGGING SETTINGS
    # ================================
    
    # Audit logging
    AUDIT_LOGGING_ENABLED: bool = True
    SECURITY_VIOLATION_LOGGING: bool = True
    VALIDATION_SUCCESS_LOGGING: bool = True
    
    # Log levels for different events
    VALIDATION_SUCCESS_LOG_LEVEL: str = "INFO"
    SECURITY_VIOLATION_LOG_LEVEL: str = "WARNING"
    SYSTEM_ERROR_LOG_LEVEL: str = "ERROR"
    
    # ================================
    # PERFORMANCE THRESHOLDS
    # ================================
    
    # Performance monitoring
    TENANT_RESOLUTION_MAX_TIME_MS: int = 100
    RESOURCE_VALIDATION_MAX_TIME_MS: int = 50
    QUERY_REWRITING_MAX_TIME_MS: int = 25
    TOTAL_MIDDLEWARE_MAX_TIME_MS: int = 200
    
    # Threshold violations
    PERFORMANCE_WARNING_THRESHOLD_MS: int = 150
    PERFORMANCE_ERROR_THRESHOLD_MS: int = 250
    
    # ================================
    # DATABASE SETTINGS
    # ================================
    
    # Connection settings
    DB_CONNECTION_TIMEOUT_SECONDS: int = 10
    DB_QUERY_TIMEOUT_SECONDS: int = 30
    DB_CONNECTION_POOL_SIZE: int = 20
    
    # Database functions
    REQUIRED_DB_FUNCTIONS: List[str] = [
        "api.auth_login",
        "api.auth_validate_session",
        "api.ai_secure_chat",
        "api.track_site_event"
    ]
    
    # ================================
    # SECURITY HEADERS
    # ================================
    
    # Security headers to add to responses
    SECURITY_HEADERS: Dict[str, str] = {
        "X-Zero-Trust-Status": "validated",
        "X-Tenant-Validated": "true",
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block"
    }
    
    # ================================
    # ENVIRONMENT OVERRIDES
    # ================================
    
    @classmethod
    def load_from_environment(cls) -> 'ZeroTrustConfig':
        """Load configuration with environment variable overrides"""
        config = cls()
        
        # Override from environment variables
        config.ZERO_TRUST_ENABLED = cls._get_bool_env("ZERO_TRUST_ENABLED", config.ZERO_TRUST_ENABLED)
        config.TENANT_VALIDATION_ENABLED = cls._get_bool_env("TENANT_VALIDATION_ENABLED", config.TENANT_VALIDATION_ENABLED)
        config.RESOURCE_VALIDATION_ENABLED = cls._get_bool_env("RESOURCE_VALIDATION_ENABLED", config.RESOURCE_VALIDATION_ENABLED)
        
        # Cache settings
        config.VALIDATION_CACHE_TTL_SECONDS = cls._get_int_env("VALIDATION_CACHE_TTL_SECONDS", config.VALIDATION_CACHE_TTL_SECONDS)
        config.VALIDATION_CACHE_MAX_SIZE = cls._get_int_env("VALIDATION_CACHE_MAX_SIZE", config.VALIDATION_CACHE_MAX_SIZE)
        
        # Performance thresholds
        config.TOTAL_MIDDLEWARE_MAX_TIME_MS = cls._get_int_env("TOTAL_MIDDLEWARE_MAX_TIME_MS", config.TOTAL_MIDDLEWARE_MAX_TIME_MS)
        
        return config
    
    @staticmethod
    def _get_bool_env(key: str, default: bool) -> bool:
        """Get boolean environment variable"""
        value = os.getenv(key)
        if value is None:
            return default
        return value.lower() in ('true', '1', 'yes', 'on')
    
    @staticmethod
    def _get_int_env(key: str, default: int) -> int:
        """Get integer environment variable"""
        value = os.getenv(key)
        if value is None:
            return default
        try:
            return int(value)
        except ValueError:
            return default
    
    @staticmethod
    def _get_list_env(key: str, default: List[str]) -> List[str]:
        """Get list environment variable (comma-separated)"""
        value = os.getenv(key)
        if value is None:
            return default
        return [item.strip() for item in value.split(',') if item.strip()]
    
    # ================================
    # VALIDATION METHODS
    # ================================
    
    def validate_config(self) -> List[str]:
        """Validate configuration settings and return any errors"""
        errors = []
        
        # Check required settings
        if not isinstance(self.ZERO_TRUST_ENABLED, bool):
            errors.append("ZERO_TRUST_ENABLED must be boolean")
        
        if self.VALIDATION_CACHE_TTL_SECONDS <= 0:
            errors.append("VALIDATION_CACHE_TTL_SECONDS must be positive")
        
        if self.VALIDATION_CACHE_MAX_SIZE <= 0:
            errors.append("VALIDATION_CACHE_MAX_SIZE must be positive")
        
        if self.TOTAL_MIDDLEWARE_MAX_TIME_MS <= 0:
            errors.append("TOTAL_MIDDLEWARE_MAX_TIME_MS must be positive")
        
        # Check paths
        if not isinstance(self.EXCLUDED_PATHS, list):
            errors.append("EXCLUDED_PATHS must be a list")
        
        # Check database settings
        if self.DB_CONNECTION_TIMEOUT_SECONDS <= 0:
            errors.append("DB_CONNECTION_TIMEOUT_SECONDS must be positive")
        
        return errors
    
    def get_config_summary(self) -> Dict[str, Any]:
        """Get configuration summary for monitoring/debugging"""
        return {
            "zero_trust_enabled": self.ZERO_TRUST_ENABLED,
            "phase_1_complete": self.PHASE_1_COMPLETE,
            "tenant_validation_enabled": self.TENANT_VALIDATION_ENABLED,
            "resource_validation_enabled": self.RESOURCE_VALIDATION_ENABLED,
            "validation_cache_enabled": self.VALIDATION_CACHE_ENABLED,
            "audit_logging_enabled": self.AUDIT_LOGGING_ENABLED,
            "excluded_paths_count": len(self.EXCLUDED_PATHS),
            "validated_resource_types_count": len(self.VALIDATED_RESOURCE_TYPES),
            "performance_thresholds": {
                "tenant_resolution_max_ms": self.TENANT_RESOLUTION_MAX_TIME_MS,
                "resource_validation_max_ms": self.RESOURCE_VALIDATION_MAX_TIME_MS,
                "total_middleware_max_ms": self.TOTAL_MIDDLEWARE_MAX_TIME_MS
            }
        }

# Global configuration instance
zero_trust_config = ZeroTrustConfig.load_from_environment()

# Validate configuration on import
config_errors = zero_trust_config.validate_config()
if config_errors:
    import logging
    logger = logging.getLogger(__name__)
    logger.error(f"Zero Trust configuration errors: {config_errors}")
    raise ValueError(f"Invalid zero trust configuration: {'; '.join(config_errors)}")

# Export for easy importing
__all__ = ['ZeroTrustConfig', 'zero_trust_config'] 