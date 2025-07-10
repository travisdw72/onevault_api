#!/usr/bin/env python3
"""
Local Configuration for Zero Trust Gateway Testing

This configuration file is specifically for localhost testing.
It overrides the main config.py for local development.
"""

import os
from dataclasses import dataclass
from typing import Dict, Any, Optional, List

@dataclass
class LocalDatabaseConfig:
    """Local database configuration for testing"""
    host: str = "localhost"
    port: int = 5432
    database: str = "one_vault_site_testing"  # Your local test database
    user: str = "postgres"
    password: str = "your_password_here"  # Will be overridden by env var
    
    def __post_init__(self):
        # Override with environment variables
        self.host = os.getenv("DB_HOST", self.host)
        self.port = int(os.getenv("DB_PORT", str(self.port)))
        self.database = os.getenv("DB_NAME", self.database)
        self.user = os.getenv("DB_USER", self.user)
        self.password = os.getenv("DB_PASSWORD", self.password)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for database connections"""
        return {
            "host": self.host,
            "port": self.port,
            "database": self.database,
            "user": self.user,
            "password": self.password
        }
    
    def get_connection_string(self) -> str:
        """Get PostgreSQL connection string"""
        return f"postgresql://{self.user}:{self.password}@{self.host}:{self.port}/{self.database}"

@dataclass
class LocalRedisConfig:
    """Local Redis configuration (disabled for local testing)"""
    enabled: bool = False
    host: str = "localhost"
    port: int = 6379
    password: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            "enabled": self.enabled,
            "host": self.host,
            "port": self.port,
            "password": self.password
        }

@dataclass
class LocalZeroTrustConfig:
    """Local Zero Trust configuration"""
    environment: str = "development"
    debug: bool = True
    performance_targets: Dict[str, float] = None
    
    def __post_init__(self):
        if self.performance_targets is None:
            self.performance_targets = {
                "max_response_time_ms": 200.0,
                "max_db_query_time_ms": 100.0,
                "max_cache_lookup_time_ms": 10.0,
                "target_throughput_rps": 1000.0
            }
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            "environment": self.environment,
            "debug": self.debug,
            "performance_targets": self.performance_targets
        }

@dataclass
class LocalConfig:
    """Complete local configuration"""
    database: LocalDatabaseConfig
    redis: LocalRedisConfig
    zero_trust: LocalZeroTrustConfig
    
    def __init__(self):
        self.database = LocalDatabaseConfig()
        self.redis = LocalRedisConfig()
        self.zero_trust = LocalZeroTrustConfig()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            "database": self.database.to_dict(),
            "redis": self.redis.to_dict(),
            "zero_trust": self.zero_trust.to_dict()
        }

def get_local_config() -> LocalConfig:
    """Get local configuration instance"""
    return LocalConfig()

def validate_local_config() -> List[str]:
    """Validate local configuration and return errors"""
    errors = []
    config = get_local_config()
    
    # Database validation
    if config.database.password == "your_password_here":
        errors.append("Database password not set. Use DB_PASSWORD environment variable.")
    
    if not config.database.host:
        errors.append("Database host cannot be empty")
    
    if not config.database.database:
        errors.append("Database name cannot be empty")
    
    if not config.database.user:
        errors.append("Database user cannot be empty")
    
    if config.database.port < 1 or config.database.port > 65535:
        errors.append(f"Invalid database port: {config.database.port}")
    
    return errors

def print_local_config():
    """Print local configuration for debugging"""
    config = get_local_config()
    
    print("🏠 Local Zero Trust Gateway Configuration")
    print("=" * 50)
    print(f"Environment: {config.zero_trust.environment}")
    print(f"Debug Mode: {config.zero_trust.debug}")
    print()
    print("📊 Database Configuration:")
    print(f"  Host: {config.database.host}")
    print(f"  Port: {config.database.port}")
    print(f"  Database: {config.database.database}")
    print(f"  User: {config.database.user}")
    print(f"  Password: {'*' * len(config.database.password) if config.database.password != 'your_password_here' else 'NOT SET'}")
    print()
    print("🔴 Redis Configuration:")
    print(f"  Enabled: {config.redis.enabled}")
    print(f"  Host: {config.redis.host}")
    print(f"  Port: {config.redis.port}")
    print()
    print("🎯 Performance Targets:")
    for key, value in config.zero_trust.performance_targets.items():
        print(f"  {key}: {value}")
    print()
    
    # Validation
    errors = validate_local_config()
    if errors:
        print("❌ Configuration Errors:")
        for error in errors:
            print(f"  - {error}")
    else:
        print("✅ Configuration Valid")
    print("=" * 50)

# Environment setup helper
def setup_local_environment():
    """Set up local environment variables if not already set"""
    env_vars = {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "one_vault_site_testing",
        "DB_USER": "postgres",
        "ENVIRONMENT": "development"
    }
    
    for key, default_value in env_vars.items():
        if not os.getenv(key):
            os.environ[key] = default_value
            print(f"Set {key} = {default_value}")

# Test database connection
def test_local_database_connection():
    """Test connection to local database"""
    try:
        import psycopg2
        config = get_local_config()
        
        print("🔌 Testing local database connection...")
        print(f"Connecting to: {config.database.host}:{config.database.port}/{config.database.database}")
        
        conn = psycopg2.connect(**config.database.to_dict())
        cursor = conn.cursor()
        
        # Test basic query
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        print(f"✅ Connected to PostgreSQL: {version[0]}")
        
        # Test Zero Trust function exists
        cursor.execute("""
            SELECT EXISTS(
                SELECT 1 FROM information_schema.routines 
                WHERE routine_schema = 'ai_monitoring' 
                AND routine_name = 'validate_zero_trust_access'
            );
        """)
        
        function_exists = cursor.fetchone()[0]
        if function_exists:
            print("✅ Zero Trust function ai_monitoring.validate_zero_trust_access() found")
        else:
            print("❌ Zero Trust function ai_monitoring.validate_zero_trust_access() NOT found")
        
        # Test auth schema exists
        cursor.execute("""
            SELECT EXISTS(
                SELECT 1 FROM information_schema.schemata 
                WHERE schema_name = 'auth'
            );
        """)
        
        auth_exists = cursor.fetchone()[0]
        if auth_exists:
            print("✅ Auth schema found")
        else:
            print("❌ Auth schema NOT found")
        
        # Test API token table exists
        cursor.execute("""
            SELECT EXISTS(
                SELECT 1 FROM information_schema.tables 
                WHERE table_schema = 'auth' 
                AND table_name = 'api_token_s'
            );
        """)
        
        token_table_exists = cursor.fetchone()[0]
        if token_table_exists:
            print("✅ API token table auth.api_token_s found")
            
            # Count available tokens
            cursor.execute("""
                SELECT COUNT(*) 
                FROM auth.api_token_s 
                WHERE is_revoked = false 
                AND expires_at > CURRENT_TIMESTAMP 
                AND load_end_date IS NULL
            """)
            
            token_count = cursor.fetchone()[0]
            print(f"📊 Available API tokens: {token_count}")
            
        else:
            print("❌ API token table auth.api_token_s NOT found")
        
        cursor.close()
        conn.close()
        
        print("✅ Database connection test successful")
        return True
        
    except ImportError:
        print("❌ psycopg2 not installed. Run: pip install psycopg2-binary")
        return False
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False

if __name__ == "__main__":
    print("🏠 OneVault Zero Trust Gateway - Local Configuration")
    print()
    
    # Setup environment
    setup_local_environment()
    
    # Print configuration
    print_local_config()
    
    # Test database connection
    print()
    test_local_database_connection()
    
    print()
    print("🚀 To start local testing:")
    print("1. Set DB_PASSWORD environment variable")
    print("2. Run: python local_api_test.py")
    print("3. In another terminal: bash test_api_locally.sh") 