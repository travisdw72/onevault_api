"""
Zero Trust Configuration for Phase 1 Integration
===============================================

Basic configuration for the Zero Trust Gateway Phase 1 integration.
"""

import os
from typing import Optional, Dict, Any
from pydantic import BaseModel

class AppConfig(BaseModel):
    """Application configuration"""
    name: str = "OneVault Platform"
    version: str = "1.0.0"
    debug: bool = False
    environment: str = "production"
    
class DatabaseConfig(BaseModel):
    """Database configuration"""
    url: Optional[str] = None
    max_connections: int = 10
    connection_timeout: int = 30
    
    def __init__(self, **data):
        super().__init__(**data)
        if not self.url:
            self.url = os.getenv('SYSTEM_DATABASE_URL', 'postgresql://localhost:5432/one_vault')

class CacheConfig(BaseModel):
    """Cache configuration"""
    ttl_seconds: int = 300
    max_size: int = 1000
    enabled: bool = True

class SecurityConfig(BaseModel):
    """Security configuration"""
    max_request_size: int = 1024 * 1024  # 1MB
    rate_limit_per_minute: int = 60
    token_expiry_seconds: int = 3600
    
class ZeroTrustConfig:
    """
    Zero Trust Configuration Manager
    
    Manages all configuration for the Zero Trust Gateway Phase 1 integration.
    """
    
    def __init__(self):
        self.app = AppConfig()
        self.database = DatabaseConfig()
        self.cache = CacheConfig()
        self.security = SecurityConfig()
        
        # Environment-specific overrides
        if os.getenv('ENVIRONMENT') == 'development':
            self.app.debug = True
            self.app.environment = 'development'
        
        # Load from environment variables
        self._load_from_env()
    
    def _load_from_env(self):
        """Load configuration from environment variables"""
        # App config
        if os.getenv('APP_DEBUG'):
            self.app.debug = os.getenv('APP_DEBUG').lower() == 'true'
        
        # Database config
        if os.getenv('DATABASE_MAX_CONNECTIONS'):
            self.database.max_connections = int(os.getenv('DATABASE_MAX_CONNECTIONS'))
        
        # Cache config
        if os.getenv('CACHE_TTL_SECONDS'):
            self.cache.ttl_seconds = int(os.getenv('CACHE_TTL_SECONDS'))
        
        if os.getenv('CACHE_MAX_SIZE'):
            self.cache.max_size = int(os.getenv('CACHE_MAX_SIZE'))
        
        # Security config
        if os.getenv('RATE_LIMIT_PER_MINUTE'):
            self.security.rate_limit_per_minute = int(os.getenv('RATE_LIMIT_PER_MINUTE'))
    
    def get_config_dict(self) -> Dict[str, Any]:
        """Get all configuration as a dictionary"""
        return {
            'app': self.app.dict(),
            'database': self.database.dict(),
            'cache': self.cache.dict(),
            'security': self.security.dict()
        }
    
    def is_production(self) -> bool:
        """Check if running in production environment"""
        return self.app.environment == 'production'
    
    def is_debug(self) -> bool:
        """Check if debug mode is enabled"""
        return self.app.debug 