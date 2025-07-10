# Local Testing Guide - Zero Trust Gateway Phase 1

This guide helps you test the Zero Trust Gateway middleware on **localhost** before deploying to production.

## 🎯 Testing Strategy

**Local First Approach:**
1. **Local API + Local DB** = Safe testing environment ✅
2. **Production API + Production DB** = After local validation ✅

This ensures we catch issues locally before they reach production.

---

## 🛠️ Setup Steps

### 1. Database Setup

Make sure you have a local PostgreSQL instance with your OneVault database:

```bash
# Option A: Use your existing local database
# Database: one_vault_site_testing (default)

# Option B: Import from production backup
# pg_restore -h localhost -d one_vault_site_testing your_backup.backup
```

### 2. Environment Configuration

Set your database password:

```bash
# Set environment variable
export DB_PASSWORD="your_actual_password"

# Or create a .env file
echo "DB_PASSWORD=your_actual_password" > .env
```

### 3. Install Dependencies

```bash
# Install required packages
pip install -r requirements.txt

# Install optional tools for better testing
sudo apt-get install jq  # For JSON formatting (Linux)
brew install jq          # For JSON formatting (Mac)
```

### 4. Test Database Connection

```bash
# Test your local database setup
python local_config.py
```

Expected output:
```
✅ Connected to PostgreSQL
✅ Zero Trust function ai_monitoring.validate_zero_trust_access() found
✅ Auth schema found
✅ API token table auth.api_token_s found
📊 Available API tokens: 3
```

---

## 🚀 Running Local Tests

### Start the Local API Server

```bash
# Terminal 1: Start the API server
python local_api_test.py
```

Expected output:
```
🛡️  OneVault Zero Trust Gateway - Local Test Server
📊 Database: localhost:5432/one_vault_site_testing
📝 API Documentation: http://localhost:8000/docs
🧪 Test Endpoints: /api/v1/test/*
🔑 Authentication Required: Authorization: Bearer <your_api_token>
```

### Run API Tests

```bash
# Terminal 2: Run all tests
bash test_api_locally.sh

# Or run specific test suites
bash test_api_locally.sh quick        # Basic connectivity
bash test_api_locally.sh performance  # Performance benchmark
bash test_api_locally.sh security    # Security validation
```

---

## 🧪 Test Endpoints

### Health & Metrics (No Auth Required)

```bash
# Health check
curl http://localhost:8000/health

# Performance metrics
curl http://localhost:8000/metrics
```

### Authenticated Endpoints (Require API Token)

```bash
# Basic authentication test
curl -H "Authorization: Bearer ovt_prod_your_token" \
     http://localhost:8000/api/v1/test/basic

# Tenant access control
curl -H "Authorization: Bearer ovt_prod_your_token" \
     http://localhost:8000/api/v1/test/tenant/your_tenant_id

# Admin access test
curl -H "Authorization: Bearer ovt_prod_your_token" \
     http://localhost:8000/api/v1/test/admin

# Business resource simulation
curl -H "Authorization: Bearer ovt_prod_your_token" \
     http://localhost:8000/api/v1/test/business/users

# Cross-tenant blocking test
curl -H "Authorization: Bearer ovt_prod_your_token" \
     http://localhost:8000/api/v1/test/cross-tenant/OTHER_TENANT_123

# Performance benchmark
curl -H "Authorization: Bearer ovt_prod_your_token" \
     http://localhost:8000/api/v1/test/performance
```

---

## 🔑 Getting an API Token

You need a valid API token from your database:

```sql
-- Get an active API token
SELECT 
    ath.api_token_bk as token,
    th.tenant_bk as tenant,
    ats.expires_at
FROM auth.api_token_s ats
JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
JOIN auth.user_token_l utl ON ath.api_token_hk = utl.api_token_hk
JOIN auth.user_h uh ON utl.user_hk = uh.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
WHERE ats.is_revoked = false
AND ats.expires_at > CURRENT_TIMESTAMP
AND ats.load_end_date IS NULL
LIMIT 1;
```

Use the `token` value in your API calls:
```bash
export API_TOKEN="ovt_prod_abcd1234..."
```

---

## 📊 Expected Test Results

### ✅ Successful Tests

1. **Basic Auth Test:**
   ```json
   {
     "status": "authenticated",
     "tenant_name": "OneBarn",
     "access_level": "USER",
     "risk_score": 0.85,
     "message": "✅ Zero Trust validation successful"
   }
   ```

2. **Tenant Access Test:**
   ```json
   {
     "status": "authorized",
     "requested_tenant": "OneBarn",
     "actual_tenant": "OneBarn",
     "message": "✅ Access granted to tenant OneBarn"
   }
   ```

3. **Cross-Tenant Blocking (Expected):**
   ```json
   {
     "error": "cross_tenant_access_denied",
     "message": "❌ Access denied to tenant OTHER_TENANT_123",
     "explanation": "Zero Trust Gateway blocks cross-tenant access"
   }
   ```

4. **Performance Test:**
   ```json
   {
     "status": "performance_test_complete",
     "current_request_ms": 45.23,
     "performance_assessment": {
       "current_request": "🟢 FAST",
       "target_ms": 200,
       "actual_ms": 45.23
     }
   }
   ```

### ❌ Common Issues

1. **Database Connection Failed:**
   ```bash
   # Check database is running
   sudo systemctl status postgresql
   
   # Check password
   export DB_PASSWORD="correct_password"
   ```

2. **API Token Invalid:**
   ```bash
   # Verify token in database
   python -c "
   import psycopg2
   conn = psycopg2.connect(host='localhost', database='one_vault_site_testing', user='postgres', password='your_password')
   cur = conn.cursor()
   cur.execute('SELECT COUNT(*) FROM auth.api_token_s WHERE is_revoked = false')
   print(f'Available tokens: {cur.fetchone()[0]}')
   "
   ```

3. **Zero Trust Function Missing:**
   ```bash
   # Check if function exists
   psql -h localhost -d one_vault_site_testing -c "
   SELECT routine_name FROM information_schema.routines 
   WHERE routine_schema = 'ai_monitoring';
   "
   ```

---

## 🎯 Performance Targets

Your local tests should meet these targets:

| Metric | Target | Good | Needs Work |
|--------|--------|------|------------|
| **Response Time** | <200ms | <100ms | >500ms |
| **DB Query Time** | <100ms | <50ms | >200ms |
| **Authentication** | <50ms | <25ms | >100ms |
| **Tenant Resolution** | <25ms | <10ms | >50ms |

---

## 🔄 Integration with Production API

Once local tests pass, integrate with your production API:

### 1. Copy Middleware Files

```bash
# Copy to your production API directory
cp zero_trust_middleware.py /path/to/your/api/middleware/
cp config.py /path/to/your/api/config/
```

### 2. Integrate with FastAPI

```python
# In your main.py or equivalent
from middleware.zero_trust_middleware import ZeroTrustGatewayMiddleware
from config.config import get_config

# Initialize middleware
config = get_config()
zero_trust_middleware = ZeroTrustGatewayMiddleware(
    db_config=config.database.to_dict(),
    redis_url=config.redis.get_connection_string() if config.redis.enabled else None
)

# Add to FastAPI app
app.middleware("http")(zero_trust_middleware)
```

### 3. Add Authentication Decorators

```python
from middleware.zero_trust_middleware import get_zero_trust_context, require_access_level

@app.get("/api/v1/protected-endpoint")
async def protected_endpoint(request: Request):
    context = get_zero_trust_context(request)
    # Your endpoint logic with guaranteed tenant context
    return {"tenant": context.tenant_name, "data": "..."}

@app.get("/api/v1/admin-endpoint")
@require_access_level("ADMIN")
async def admin_endpoint(request: Request):
    # Only users with ADMIN access can reach this
    return {"admin_data": "..."}
```

---

## 🛡️ Security Validation

### Local Security Tests

The test suite validates:

- ✅ **Authentication Required:** Unauthenticated requests blocked
- ✅ **Token Validation:** Invalid tokens rejected  
- ✅ **Tenant Isolation:** Cross-tenant access blocked
- ✅ **Access Levels:** Admin endpoints protected
- ✅ **Performance:** Response times under targets
- ✅ **Audit Logging:** All access logged

### Production Deployment Checklist

Before deploying to production:

- [ ] All local tests pass consistently
- [ ] Performance targets met (average <200ms)
- [ ] Cross-tenant access properly blocked
- [ ] Admin access control working
- [ ] Audit logging functional
- [ ] Error handling graceful
- [ ] Configuration validated
- [ ] Database functions available
- [ ] Redis connection tested (if enabled)
- [ ] Load testing completed

---

## 📞 Support

If you encounter issues:

1. **Check the logs:** Server logs show detailed middleware execution
2. **Validate config:** Run `python local_config.py`
3. **Test database:** Ensure Zero Trust functions exist
4. **Verify tokens:** Check API token validity in database
5. **Performance:** Monitor response times in test output

---

## 🎉 Success Criteria

**Local testing is successful when:**
- ✅ All test endpoints respond correctly
- ✅ Cross-tenant access is blocked
- ✅ Performance targets are met
- ✅ Audit logs are generated
- ✅ No configuration errors

**Ready for production when:**
- ✅ Local tests pass 100% consistently  
- ✅ Load testing shows stable performance
- ✅ Security validation complete
- ✅ Integration testing with your API successful

This local-first approach ensures your Zero Trust Gateway is bulletproof before it touches production! 🛡️ 