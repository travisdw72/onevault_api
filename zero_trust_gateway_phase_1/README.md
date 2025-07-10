# Zero Trust Gateway Phase 1 Implementation

## Overview

This is the **Phase 1: Core Tenant Validation** implementation of the Zero Trust Gateway for OneVault's multi-tenant AI platform. This implementation provides bulletproof tenant isolation using your existing Data Vault 2.0 infrastructure and AI monitoring functions.

**Key Benefits:**
- ✅ Uses existing `ai_monitoring.validate_zero_trust_access()` function
- ✅ No new database tables required
- ✅ Real tenant data validation (no synthetic test data)
- ✅ Performance targets: <200ms total middleware overhead
- ✅ Comprehensive audit trail integration
- ✅ Production-ready caching and optimization

## 🏗️ Architecture

### Components

```
📁 zero_trust_gateway_phase_1/
├── 🛡️ zero_trust_middleware.py    # Main middleware implementation
├── 🧪 test_real_tenant_validation.py # Comprehensive test suite
├── ⚙️ config.py                    # Configuration management
├── 🚀 run_validation.py            # Test runner script
└── 📚 README.md                    # This documentation
```

### Existing Infrastructure Used

The implementation leverages your existing Data Vault 2.0 infrastructure:

**Database Functions:**
- `ai_monitoring.validate_zero_trust_access()` - Core Zero Trust validation
- `auth.validate_production_api_token()` - API token validation
- `auth.validate_token_and_session()` - Session validation

**Database Tables:**
- `auth.tenant_h` / `auth.tenant_profile_s` - Tenant management
- `auth.api_token_h` / `auth.api_token_s` - API token storage
- `auth.user_token_l` - User-token relationships
- `auth.session_h` / `auth.session_state_s` - Session management
- `audit.audit_event_h` / `audit.audit_detail_s` - Audit logging

## 🚀 Quick Start

### Option 1: Local API Testing (Recommended for Development)

Test the Zero Trust Gateway on localhost before production deployment:

#### Windows Quick Start
```cmd
# Double-click to run
start_local_testing.bat

# Or manually set password and run
set DB_PASSWORD=your_password
python local_api_test.py

# In another terminal:
powershell .\test_api_locally.ps1
```

#### Linux/Mac Quick Start  
```bash
# Set your database password
export DB_PASSWORD="your_password"

# Start local API server
python local_api_test.py

# In another terminal, run tests
bash test_api_locally.sh
```

**Local Testing Benefits:**
- ✅ Safe testing environment (localhost only)
- ✅ Full Zero Trust Gateway API simulation
- ✅ Performance benchmarking
- ✅ Cross-tenant blocking validation
- ✅ No impact on production systems

📚 **See [LOCAL_TESTING_GUIDE.md](LOCAL_TESTING_GUIDE.md) for detailed instructions**

### Option 2: Direct Database Validation

### 1. Environment Setup

```bash
# Set environment variables
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=one_vault_site_testing
export DB_USER=postgres
export DB_PASSWORD=your_actual_password
export ENVIRONMENT=development
```

### 2. Install Dependencies

```bash
pip install psycopg2-binary redis fastapi
```

### 3. Run Configuration Check

```bash
cd zero_trust_gateway_phase_1
python run_validation.py config
```

### 4. Run Quick Connectivity Test

```bash
python run_validation.py quick
```

### 5. Run Full Validation

```bash
python run_validation.py
```

## 🧪 Testing Strategy

### Real Tenant Validation

Unlike traditional testing approaches that use synthetic data, this implementation tests with **real tenant data** from your database:

✅ **What it tests:**
- Real tenant isolation across actual customer data
- Existing API keys and session tokens
- Cross-tenant access prevention with real resources
- Performance under actual data volumes
- Integration with existing AI monitoring functions

❌ **What it doesn't do:**
- Create synthetic test tenants
- Generate fake API keys
- Modify existing data
- Impact production operations

### Test Categories

1. **🏢 Tenant Isolation Tests**
   - Validates each real tenant can access only their data
   - Tests `ai_monitoring.validate_zero_trust_access()` function
   - Verifies tenant resource ownership

2. **🔑 API Key Validation Tests**
   - Tests real API keys from `auth.api_token_s`
   - Validates user-token relationships via `auth.user_token_l`
   - Checks token expiration and revocation status

3. **🚫 Cross-Tenant Blocking Tests**
   - Ensures tenant A cannot access tenant B's resources
   - Tests data isolation across business schema tables
   - Validates hash key derivation prevents leaks

4. **⚡ Performance Benchmarks**
   - Tenant validation: <50ms target
   - API key lookup: <25ms target
   - Total middleware: <200ms target

## 📊 Sample Test Results

```
🛡️  Zero Trust Gateway Phase 1 - Validation Runner
==============================================================
🛡️  Zero Trust Gateway Configuration Summary
==================================================
Environment: development
Debug Mode: False
Database: localhost:5432/one_vault_site_testing
Redis Enabled: False
Audit Enabled: True
Monitoring Enabled: True
Performance Target: 500ms
Rate Limit: 100/minute
Access Levels: RESTRICTED, STANDARD, ELEVATED, ADMIN
==================================================
✅ Configuration is valid

🚀 Starting Zero Trust Gateway validation tests...
   Using real tenant data from database
   No synthetic test data will be created

============================================================
🎯 ZERO TRUST GATEWAY VALIDATION RESULTS
============================================================
📊 SUMMARY:
   Total Tests: 8
   Passed: 8 ✅
   Failed: 0 ❌
   Errors: 0 🚨
   Success Rate: 100.0%
   Status: 🟢 EXCELLENT - Ready for production
```

## 🛡️ Zero Trust Middleware Usage

### FastAPI Integration

```python
from fastapi import FastAPI, Request
from zero_trust_middleware import ZeroTrustGatewayMiddleware, get_zero_trust_context
from config import get_config

app = FastAPI()

# Initialize Zero Trust middleware
config = get_config()
zero_trust = ZeroTrustGatewayMiddleware(
    db_config=config.database.to_dict(),
    redis_url=config.redis.url if config.redis.enabled else None
)

# Add middleware to FastAPI
app.middleware("http")(zero_trust)

@app.get("/api/v1/tenants/{tenant_id}/users")
async def get_tenant_users(tenant_id: str, request: Request):
    # Get authenticated Zero Trust context
    context = get_zero_trust_context(request)
    
    # Middleware automatically validates:
    # - Valid API key or session token
    # - Tenant isolation (context.tenant_hk)
    # - User permissions (context.access_level)
    # - Risk scoring (context.risk_score)
    
    # Your business logic here...
    return {"tenant": context.tenant_name, "users": []}
```

### Zero Trust Context

The middleware provides rich context about the authenticated request:

```python
@dataclass
class ZeroTrustContext:
    tenant_hk: bytes           # Tenant hash key (Data Vault 2.0)
    tenant_bk: str            # Tenant business key
    tenant_name: str          # Human-readable tenant name
    user_hk: bytes            # User hash key (if available)
    user_email: str           # Authenticated user email
    api_token_hk: bytes       # API token hash key (if API auth)
    session_hk: bytes         # Session hash key (if session auth)
    risk_score: float         # AI-calculated risk score (0.0-1.0)
    access_level: str         # RESTRICTED|STANDARD|ELEVATED|ADMIN
    validated_at: datetime    # When validation occurred
    expires_at: datetime      # When credentials expire
```

### Access Control Decorators

```python
from zero_trust_middleware import require_tenant_access, require_access_level

@app.get("/api/v1/admin/settings")
@require_access_level("ADMIN")
async def admin_settings(request: Request):
    """Only ADMIN level users can access"""
    pass

@app.get("/api/v1/tenants/{tenant_id}/sensitive-data")
@require_tenant_access("{tenant_id}")
@require_access_level("ELEVATED")
async def sensitive_data(tenant_id: str, request: Request):
    """Requires access to specific tenant AND elevated permissions"""
    pass
```

## 🔧 Configuration Options

### Database Configuration

```python
@dataclass
class DatabaseConfig:
    host: str = "localhost"
    port: int = 5432
    database: str = "one_vault_site_testing"
    user: str = "postgres"
    password: str = "your_password_here"
    min_connections: int = 2
    max_connections: int = 10
    connection_timeout: int = 5
```

### Security Configuration

```python
@dataclass
class SecurityConfig:
    # Performance targets (milliseconds)
    tenant_validation_target_ms: int = 50
    api_key_lookup_target_ms: int = 25
    total_middleware_target_ms: int = 200
    
    # Rate limiting
    requests_per_minute: int = 1000
    burst_limit: int = 100
    
    # Risk scoring thresholds
    low_risk_threshold: float = 0.3
    medium_risk_threshold: float = 0.6
    high_risk_threshold: float = 0.8
```

### Redis Caching (Optional)

```python
@dataclass
class RedisConfig:
    url: str = "redis://localhost:6379/0"
    enabled: bool = True
    api_token_ttl: int = 300      # 5 minutes
    session_token_ttl: int = 300  # 5 minutes
    tenant_data_ttl: int = 600    # 10 minutes
```

## 📈 Performance Monitoring

### Built-in Metrics

The middleware tracks comprehensive performance metrics:

```python
# Get performance metrics
metrics = zero_trust.get_performance_metrics()

# Example output:
{
    "total_requests": 1523,
    "authenticated_requests": 1467,
    "failed_requests": 56,
    "avg_response_time_ms": 127.3,
    "cache_hits": 982,
    "cache_misses": 541,
    "cache_hit_rate": 0.645,
    "targets": {
        "tenant_validation_ms": 50,
        "api_key_lookup_ms": 25,
        "total_middleware_ms": 200
    }
}
```

### Performance Optimization

1. **Enable Redis Caching**
   ```bash
   export REDIS_ENABLED=true
   export REDIS_URL=redis://localhost:6379/0
   ```

2. **Database Connection Pooling**
   ```python
   config.database.max_connections = 20  # Increase for high load
   ```

3. **Index Optimization**
   ```sql
   -- Ensure these indexes exist for optimal performance
   CREATE INDEX IF NOT EXISTS idx_tenant_profile_active 
   ON auth.tenant_profile_s(tenant_hk) WHERE is_active = true;
   
   CREATE INDEX IF NOT EXISTS idx_api_token_active
   ON auth.api_token_s(api_token_hk) WHERE is_revoked = false;
   ```

## 🔍 Troubleshooting

### Common Issues

**1. Database Connection Failed**
```bash
# Check connection
python run_validation.py quick

# Common fixes:
export DB_PASSWORD=your_actual_password
# Ensure PostgreSQL is running
# Check firewall/network access
```

**2. No Tenants Found**
```sql
-- Verify tenant data exists
SELECT COUNT(*) FROM auth.tenant_h;
SELECT COUNT(*) FROM auth.tenant_profile_s WHERE is_active = true;
```

**3. API Token Validation Fails**
```sql
-- Check if ai_monitoring.validate_zero_trust_access function exists
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'ai_monitoring' 
AND routine_name = 'validate_zero_trust_access';
```

**4. Performance Issues**
```python
# Enable debug logging
export DEBUG=true
python run_validation.py

# Check slow queries in logs
# Consider enabling Redis caching
# Review database indexes
```

### Validation Failures

If tests fail, check:

1. **Database Schema**: Ensure all Data Vault 2.0 tables exist
2. **Function Availability**: Verify AI monitoring functions are deployed
3. **Data Integrity**: Check that tenant relationships are properly maintained
4. **Permissions**: Ensure database user has SELECT access to all required tables

## 🔄 Integration with Existing Systems

### OneVault Canvas Integration

The Zero Trust Gateway works seamlessly with your existing OneVault Canvas:

```javascript
// Frontend API calls automatically include tenant context
const response = await fetch('/api/v1/canvas/workflows', {
    headers: {
        'Authorization': `Bearer ${apiToken}`,
        'Content-Type': 'application/json'
    }
});

// Response includes Zero Trust headers:
// X-Zero-Trust-Tenant: TENANT_ABC123
// X-Zero-Trust-Risk-Score: 0.2
// X-Zero-Trust-Access-Level: STANDARD
```

### Existing API Functions

Your current API functions continue to work unchanged:

```python
# Existing code continues to work
@app.post("/api/v1/auth/login")
async def login(credentials: LoginRequest):
    # Existing auth.auth_login function still works
    result = await auth_service.auth_login(...)
    return result

# New Zero Trust protection is automatic for protected endpoints
@app.get("/api/v1/protected-resource")
async def protected_resource(request: Request):
    # Zero Trust middleware validates automatically
    context = get_zero_trust_context(request)
    # Your existing business logic here
    pass
```

## 🛣️ Next Steps - Phase 2

After successful Phase 1 validation, consider implementing:

**Phase 2: Token Lifecycle Management**
- Activity-based token renewal (30-day rolling)
- Inactivity expiration (90-day unused revocation)
- Security-triggered revocation
- Token scope management

**Phase 3: Double Audit Trail**
- API request audit trail
- Database access audit trail
- Audit gap detection
- Compliance reporting (HIPAA/GDPR/SOC 2)

**Phase 4: Behavioral Analytics Engine**
- Real-time risk scoring (location, time, device)
- Dynamic policy enforcement
- AI-powered anomaly detection
- Automated response system

## 📋 Validation Checklist

Before production deployment:

- [ ] All validation tests pass (>95% success rate)
- [ ] Performance targets met (<200ms middleware overhead)
- [ ] Real tenant data tested successfully
- [ ] Cross-tenant isolation verified
- [ ] API key validation working with existing tokens
- [ ] Session validation working with existing sessions
- [ ] Audit logging capturing all access attempts
- [ ] Error handling tested with invalid credentials
- [ ] Redis caching configured (if using)
- [ ] Database indexes optimized for performance
- [ ] Environment variables configured for production
- [ ] Monitoring alerts configured

## 🆘 Support

For issues with Zero Trust Gateway Phase 1:

1. **Check Logs**: Review validation output and error messages
2. **Run Diagnostics**: Use `python run_validation.py quick`
3. **Verify Database**: Ensure all Data Vault 2.0 tables and functions exist
4. **Test Configuration**: Use `python run_validation.py config`
5. **Performance Analysis**: Review metrics from validation results

---

**Zero Trust Gateway Phase 1** provides bulletproof tenant isolation using your existing infrastructure. No new database tables required - just enhanced security for your multi-tenant AI platform. 