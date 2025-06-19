# Configuration Formats Guide
## Single Source of Truth Best Practices

This guide explains different configuration formats and when to use each one for your "single source of truth" configuration strategy.

## 📊 **FORMAT COMPARISON TABLE**

| Feature | JSON | YAML | TOML | Python |
|---------|------|------|------|--------|
| **Comments** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Multi-line strings** | ⚠️ Escaped | ✅ Native | ✅ Native | ✅ Native |
| **Environment variables** | ❌ No | ⚠️ External tools | ⚠️ External tools | ✅ Built-in |
| **Logic/calculations** | ❌ No | ❌ No | ❌ No | ✅ Full power |
| **Type safety** | ⚠️ Basic | ⚠️ Basic | ✅ Strong | ✅ Full |
| **IDE support** | ✅ Excellent | ✅ Excellent | ✅ Good | ✅ Excellent |
| **Human readable** | ⚠️ Verbose | ✅ Excellent | ✅ Good | ✅ Good |
| **Industry adoption** | ✅ Universal | ✅ DevOps standard | ⚠️ Growing | ✅ Python ecosystem |
| **Validation** | ⚠️ Schema tools | ⚠️ Schema tools | ⚠️ Limited | ✅ Built-in |
| **Performance** | ✅ Fast | ⚠️ Slower | ✅ Fast | ✅ Fast |

## 🏆 **RECOMMENDATIONS BY USE CASE**

### 1. **Simple Applications** → **YAML**
```yaml
# Best for: Small to medium projects, DevOps, CI/CD
database:
  host: localhost
  port: 5432
  database: one_vault

queries:
  get_users: |
    SELECT * FROM users 
    WHERE active = true
```

**Why YAML?**
- ✅ Human readable and writable
- ✅ Comments for documentation
- ✅ Multi-line SQL queries
- ✅ Industry standard for DevOps
- ✅ Great tool ecosystem

### 2. **Complex Applications** → **Python**
```python
# Best for: Large applications, dynamic configuration, complex logic
import os

DATABASE = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 5432)),
    'connection_pool': {
        'min': 1 if os.getenv('ENV') == 'dev' else 5,
        'max': 10 if os.getenv('ENV') == 'dev' else 50,
    }
}

def get_query(name: str) -> str:
    return QUERIES[name].strip()
```

**Why Python?**
- ✅ Full programming language power
- ✅ Environment-specific logic
- ✅ Type hints and validation
- ✅ Import other modules
- ✅ Runtime configuration changes

### 3. **API/Web Services** → **YAML or TOML**
```toml
# Best for: Modern web services, microservices
[database]
host = "localhost"
port = 5432

[api.rate_limiting]
requests_per_minute = 100
burst_limit = 50
```

### 4. **Legacy/Integration** → **JSON**
```json
{
  "database": {
    "host": "localhost",
    "port": 5432
  }
}
```

**Why JSON?**
- ✅ Universal support
- ✅ Fast parsing
- ✅ Simple structure
- ⚠️ Use only when forced by external requirements

## 🎯 **SINGLE SOURCE OF TRUTH PRINCIPLES**

### 1. **One Configuration File Per Environment**
```
config/
├── development.yaml    # Dev environment
├── staging.yaml       # Staging environment
├── production.yaml    # Production environment
└── local.yaml         # Local overrides (gitignored)
```

### 2. **Environment Variable Override Pattern**
```python
# config.py - Single source of truth with environment overrides
DATABASE = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 5432)),
    'database': os.getenv('DB_NAME', 'one_vault'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD'),  # Required in production
}
```

### 3. **Hierarchical Configuration Loading**
```python
def load_config():
    # 1. Load base configuration
    config = load_yaml('config/base.yaml')
    
    # 2. Override with environment-specific
    env_config = load_yaml(f'config/{ENVIRONMENT}.yaml')
    config.update(env_config)
    
    # 3. Override with environment variables
    config['database']['host'] = os.getenv('DB_HOST', config['database']['host'])
    
    return config
```

## 🔧 **IMPLEMENTATION PATTERNS**

### Pattern 1: **YAML + Environment Variables**
```yaml
# config.yaml
database:
  host: ${DB_HOST:-localhost}
  port: ${DB_PORT:-5432}
  database: ${DB_NAME:-one_vault}
  
queries:
  get_user_by_email: |
    SELECT first_name, last_name, email
    FROM auth.user_profile_s 
    WHERE email = %s 
    AND load_end_date IS NULL
```

```python
# config_loader.py
import yaml
import os
import re

def load_config_with_env_substitution(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Replace ${VAR:-default} with environment variables
    def replace_env_var(match):
        var_expr = match.group(1)
        if ':-' in var_expr:
            var_name, default = var_expr.split(':-', 1)
            return os.getenv(var_name, default)
        else:
            return os.getenv(var_expr, '')
    
    content = re.sub(r'\$\{([^}]+)\}', replace_env_var, content)
    return yaml.safe_load(content)
```

### Pattern 2: **Python Configuration with Validation**
```python
# config.py
from typing import Dict, List, Optional
from dataclasses import dataclass
import os

@dataclass
class DatabaseConfig:
    host: str
    port: int
    database: str
    user: str
    password: Optional[str] = None
    
    def __post_init__(self):
        if not self.password:
            raise ValueError("Database password is required")
        if not (1 <= self.port <= 65535):
            raise ValueError(f"Invalid port: {self.port}")

@dataclass
class AppConfig:
    database: DatabaseConfig
    environment: str
    debug: bool
    
    @classmethod
    def from_env(cls) -> 'AppConfig':
        return cls(
            database=DatabaseConfig(
                host=os.getenv('DB_HOST', 'localhost'),
                port=int(os.getenv('DB_PORT', 5432)),
                database=os.getenv('DB_NAME', 'one_vault'),
                user=os.getenv('DB_USER', 'postgres'),
                password=os.getenv('DB_PASSWORD')
            ),
            environment=os.getenv('ENVIRONMENT', 'development'),
            debug=os.getenv('DEBUG', 'false').lower() == 'true'
        )

# Usage
config = AppConfig.from_env()
```

### Pattern 3: **Multi-Format Support**
```python
# universal_config.py
class ConfigLoader:
    def __init__(self, config_path: str):
        self.config_path = config_path
        self.format = self._detect_format()
    
    def load(self) -> Dict[str, Any]:
        if self.format == 'yaml':
            return self._load_yaml()
        elif self.format == 'json':
            return self._load_json()
        elif self.format == 'python':
            return self._load_python()
        else:
            raise ValueError(f"Unsupported format: {self.format}")
```

## 📋 **BEST PRACTICES CHECKLIST**

### ✅ **Configuration Design**
- [ ] One configuration file per environment
- [ ] Environment variables for secrets and deployment-specific values
- [ ] Default values for all optional settings
- [ ] Validation at application startup
- [ ] Clear documentation for all configuration options

### ✅ **Security**
- [ ] Never commit passwords or secrets to version control
- [ ] Use environment variables for sensitive data
- [ ] Separate configuration from code
- [ ] Validate all configuration inputs
- [ ] Use secure defaults

### ✅ **Maintainability**
- [ ] Comments explaining complex configuration
- [ ] Consistent naming conventions
- [ ] Logical grouping of related settings
- [ ] Version control for configuration files
- [ ] Change tracking and rollback capability

### ✅ **Operations**
- [ ] Easy to deploy across environments
- [ ] Runtime configuration reloading (if needed)
- [ ] Configuration validation tools
- [ ] Monitoring for configuration changes
- [ ] Backup and recovery procedures

## 🚀 **GETTING STARTED**

### Step 1: Choose Your Format
```bash
# For most projects, start with YAML
cp config_examples/config.yaml my_config.yaml

# For complex projects, use Python
cp config_examples/config.py my_config.py
```

### Step 2: Test Your Configuration
```bash
# Test with the universal runner
python universal_config_runner.py my_config.yaml

# Or test Python config directly
python my_config.py
```

### Step 3: Add Environment Variables
```bash
# Set environment variables
export DB_PASSWORD="your_secure_password"
export ENVIRONMENT="production"

# Test with environment overrides
python universal_config_runner.py my_config.yaml
```

## 🎯 **FINAL RECOMMENDATION**

For your One Vault project, I recommend:

1. **Start with YAML** for simplicity and readability
2. **Add Python configuration** when you need complex logic
3. **Use environment variables** for secrets and deployment-specific values
4. **Implement validation** to catch configuration errors early
5. **Document everything** so your future self (and team) understands the configuration

The universal configuration runner I created supports all formats, so you can start simple and evolve your configuration strategy as your project grows! 