# 🔒 V017 Security Testing Guide
**Testing the Cross-Tenant Authentication Fix**

## 🎯 **What We Expect to Happen**

Based on your successful V017 migration output, here's what should happen during testing:

### ✅ **Expected SUCCESS Cases:**
1. **Valid Tenant Authentication** - `travis@gmail.com` with correct tenant token should work
2. **Backward Compatibility** - Existing API token formats should continue working  
3. **Authorization Header Support** - Tokens from Authorization headers should work

### ❌ **Expected FAILURE Cases (Security Tests):**
1. **Cross-Tenant Attack** - `travis@gmail.com` with wrong tenant's token should FAIL
2. **Invalid API Tokens** - Malformed tokens should be rejected
3. **Missing API Tokens** - Requests without tokens should fail
4. **Wrong Passwords** - Invalid credentials should be rejected

---

## 🧪 **Testing Options**

### Option 1: Quick Function Verification
**File:** `verify_v017_functions.sql`
**Purpose:** Verify all V017 functions were created correctly

```sql
-- Run this first to confirm V017 migration worked
\i verify_v017_functions.sql
```

**Expected Output:** All items should show `✅ EXISTS/COMPLETED`

### Option 2: Manual SQL Testing  
**File:** `test_v017_security_manual.sql`
**Purpose:** Manual security validation with real tokens

**Steps:**
1. Run the script in your database client
2. Copy the API tokens from the first query
3. Replace placeholder tokens in the test queries
4. Execute each test and verify results

```sql
-- Run the manual test suite
\i test_v017_security_manual.sql
```

### Option 3: Automated Python Testing
**File:** `test_v017_security_validation.py`
**Purpose:** Comprehensive automated testing

**Requirements:** Update database credentials in the script
```python
DB_CONFIG = {
    'host': 'localhost',
    'database': 'one_vault_dev', 
    'user': 'postgres',
    'password': 'YOUR_PASSWORD_HERE'  # Update this
}
```

```bash
python test_v017_security_validation.py
```

---

## 🔍 **Critical Test Results to Watch For**

### 🚨 **SECURITY CRITICAL - Must FAIL:**

#### Test 2: Cross-Tenant Attack
```sql
-- This MUST return success = false
SELECT api.auth_login(jsonb_build_object(
    'username', 'travis@gmail.com',
    'password', 'Tr@vis123',
    'authorization_token', 'OTHER_TENANT_TOKEN',  -- Wrong tenant!
    'ip_address', '127.0.0.1'
));
```
**Expected:** `{"success": false, "message": "Invalid username or password"}`
**⚠️ If this returns success=true, DO NOT DEPLOY - security vulnerability exists!**

#### Test 3: Invalid Token
```sql
-- This MUST return success = false  
SELECT api.auth_login(jsonb_build_object(
    'username', 'travis@gmail.com',
    'password', 'Tr@vis123',
    'authorization_token', 'ovt_invalid_token_123456789'
));
```
**Expected:** `{"success": false, "message": "Invalid API token"}`

### ✅ **FUNCTIONALITY CRITICAL - Must SUCCEED:**

#### Test 1: Valid Authentication
```sql
-- This MUST return success = true
SELECT api.auth_login(jsonb_build_object(
    'username', 'travis@gmail.com', 
    'password', 'Tr@vis123',
    'authorization_token', 'CORRECT_TENANT_TOKEN',
    'ip_address', '127.0.0.1'
));
```
**Expected:** `{"success": true, "data": {"session_token": "...", "user_data": {...}}}`

#### Test 5: Backward Compatibility  
```sql
-- This MUST return success = true (token in body instead of header)
SELECT api.auth_login(jsonb_build_object(
    'username', 'travis@gmail.com',
    'password', 'Tr@vis123', 
    'api_token', 'CORRECT_TENANT_TOKEN',  -- In body, not authorization_token
    'ip_address', '127.0.0.1'
));
```
**Expected:** `{"success": true, "data": {"session_token": "...", "user_data": {...}}}`

---

## 📊 **Audit Log Verification**

After running tests, check the audit logs:

```sql
-- Check successful authentications
SELECT 
    encode(user_hk, 'hex') as user_id,
    encode(tenant_hk, 'hex') as tenant_id,
    auth_method,
    ip_address,
    load_date
FROM audit.auth_success_s 
WHERE load_date >= CURRENT_DATE
ORDER BY load_date DESC;

-- Check failed attempts (should include blocked cross-tenant attacks)
SELECT 
    attempted_username,
    failure_reason,
    encode(tenant_hk, 'hex') as tenant_id,
    ip_address,
    load_date
FROM audit.auth_failure_s 
WHERE load_date >= CURRENT_DATE
ORDER BY load_date DESC;
```

**Look for:**
- ✅ Successful logins with `auth_method = 'SECURE_LOGIN'`
- ❌ Failed attempts with `failure_reason = 'USER_NOT_IN_TENANT'` (cross-tenant blocks)
- ❌ Failed attempts with `failure_reason = 'INVALID_PASSWORD'`

---

## 🎯 **Production Readiness Checklist**

Before deploying V017 to production, verify:

- [ ] **Function Verification:** All V017 functions exist (`verify_v017_functions.sql`)
- [ ] **Valid Auth Works:** Test 1 and Test 5 return `success: true`
- [ ] **Cross-Tenant Blocked:** Test 2 returns `success: false` with proper error
- [ ] **Invalid Tokens Rejected:** Test 3 and Test 4 return `success: false`
- [ ] **Wrong Passwords Rejected:** Test 6 returns `success: false`
- [ ] **Audit Logging:** Security events properly logged in audit tables
- [ ] **No Breaking Changes:** Existing clients continue working without modifications

---

## 🚨 **Red Flags - DO NOT DEPLOY IF:**

1. **Cross-tenant attack succeeds** (Test 2 returns success=true)
2. **Invalid tokens accepted** (Test 3 returns success=true)  
3. **Valid authentication fails** (Test 1 returns success=false)
4. **Backward compatibility broken** (Test 5 returns success=false)
5. **Audit logging not working** (No entries in audit tables)

---

## ✅ **Success Criteria**

**V017 is ready for production when:**
- All security tests FAIL as expected (blocking attacks)
- All functionality tests SUCCEED as expected (preserving features)
- Audit logging captures all authentication attempts
- Zero breaking changes for existing clients

---

## 🔄 **Next Steps After Testing**

### If All Tests Pass:
1. Deploy V017 to production database
2. Update production API servers with new authentication flow
3. Monitor production logs for security events
4. Validate production authentication is working

### If Tests Fail:
1. **Security tests passing** = CRITICAL - Do not deploy, investigate immediately
2. **Functionality tests failing** = Fix issues before deployment
3. Review migration logs and function definitions
4. Re-run V017 migration if necessary

---

## 📞 **Support Information**

- **Migration File:** `database/organized_migrations/03_auth_system/V017__simple_secure_auth_fix.sql`
- **Rollback File:** `database/organized_migrations/03_auth_system/V017__rollback_simple_secure_auth_fix.sql`
- **Test Files:** `test_v017_security_manual.sql`, `verify_v017_functions.sql`
- **Documentation:** `V017_SECURITY_RELEASE_SUMMARY.md`

**Remember:** V017 fixes a critical cross-tenant security vulnerability. Thorough testing is essential before production deployment! 