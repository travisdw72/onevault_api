# 🔒 pgAdmin V017 Testing - Step by Step Guide

## 🎯 **Testing V017 Security Fix in pgAdmin**

This guide walks you through testing the V017 cross-tenant security fix using pgAdmin, one step at a time.

---

## 📋 **STEP 1: Get API Tokens**

**Copy and run this query in pgAdmin:**

```sql
SELECT 
    th.tenant_bk as tenant_name,
    SUBSTRING(ats.token_value, 1, 20) || '...' as token_preview,
    ats.token_value as full_token
FROM auth.api_token_s ats
JOIN auth.tenant_h th ON ats.tenant_hk = th.tenant_hk
WHERE ats.load_end_date IS NULL
ORDER BY th.tenant_bk;
```

**Expected Result:** You should see tokens for different tenants
- Copy the `full_token` value for `theonespaoregon` 
- Copy the `full_token` value for any other tenant

---

## 🧪 **STEP 2: TEST 1 - Valid Authentication (Should SUCCEED)**

**Replace `YOUR_THEONESPAOREGON_TOKEN_HERE` with the actual theonespaoregon token:**

```sql
SELECT 
    'TEST 1: Valid Authentication' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = true THEN '✅ PASS - Authentication successful'
        ELSE '❌ FAIL - Should have succeeded'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'Tr@vis123',
        'authorization_token', 'YOUR_THEONESPAOREGON_TOKEN_HERE',  -- Replace with actual token
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test'
    )) as result
) t;
```

**Expected Result:** `success = true` and `test_result = ✅ PASS - Authentication successful`

---

## 🚨 **STEP 3: TEST 2 - Cross-Tenant Attack (MUST FAIL)**

**⚠️ CRITICAL SECURITY TEST - This MUST fail!**

**Replace `YOUR_OTHER_TENANT_TOKEN_HERE` with a DIFFERENT tenant's token:**

```sql
SELECT 
    'TEST 2: Cross-Tenant Attack' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = false THEN '✅ PASS - Attack blocked'
        ELSE '🚨 FAIL - SECURITY VULNERABILITY!'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'Tr@vis123',
        'authorization_token', 'YOUR_OTHER_TENANT_TOKEN_HERE',  -- Replace with different tenant token
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test-ATTACK'
    )) as result
) t;
```

**Expected Result:** `success = false` and `test_result = ✅ PASS - Attack blocked`
**🚨 If this shows success=true, DO NOT DEPLOY - security vulnerability exists!**

---

## 🧪 **STEP 4: TEST 3 - Invalid Token (Should FAIL)**

```sql
SELECT 
    'TEST 3: Invalid Token' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = false THEN '✅ PASS - Invalid token rejected'
        ELSE '❌ FAIL - Should have failed'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'Tr@vis123',
        'authorization_token', 'ovt_invalid_token_123456789',
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test'
    )) as result
) t;
```

**Expected Result:** `success = false` and `test_result = ✅ PASS - Invalid token rejected`

---

## 🧪 **STEP 5: TEST 4 - Missing Token (Should FAIL)**

```sql
SELECT 
    'TEST 4: Missing Token' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = false THEN '✅ PASS - Missing token rejected'
        ELSE '❌ FAIL - Should have failed'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'Tr@vis123',
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test'
    )) as result
) t;
```

**Expected Result:** `success = false` and `test_result = ✅ PASS - Missing token rejected`

---

## 🧪 **STEP 6: TEST 5 - Backward Compatibility (Should SUCCEED)**

**Replace `YOUR_THEONESPAOREGON_TOKEN_HERE` with the actual theonespaoregon token:**

```sql
SELECT 
    'TEST 5: Backward Compatibility' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = true THEN '✅ PASS - Backward compatibility works'
        ELSE '❌ FAIL - Backward compatibility broken'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'Tr@vis123',
        'api_token', 'YOUR_THEONESPAOREGON_TOKEN_HERE',  -- In body instead of authorization_token
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test'
    )) as result
) t;
```

**Expected Result:** `success = true` and `test_result = ✅ PASS - Backward compatibility works`

---

## 🧪 **STEP 7: TEST 6 - Wrong Password (Should FAIL)**

**Replace `YOUR_THEONESPAOREGON_TOKEN_HERE` with the actual theonespaoregon token:**

```sql
SELECT 
    'TEST 6: Wrong Password' as test_name,
    (result->>'success')::boolean as success,
    result->>'message' as message,
    CASE 
        WHEN (result->>'success')::boolean = false THEN '✅ PASS - Wrong password rejected'
        ELSE '❌ FAIL - Should have failed'
    END as test_result
FROM (
    SELECT api.auth_login(jsonb_build_object(
        'username', 'travis@gmail.com',
        'password', 'WrongPassword123',
        'authorization_token', 'YOUR_THEONESPAOREGON_TOKEN_HERE',  -- Replace with actual token
        'ip_address', '127.0.0.1',
        'user_agent', 'V017-Security-Test'
    )) as result
) t;
```

**Expected Result:** `success = false` and `test_result = ✅ PASS - Wrong password rejected`

---

## 📊 **STEP 8: Check Audit Logs**

**Run these queries to verify audit logging is working:**

```sql
-- Check successful authentications
SELECT 
    'Recent Auth Attempts' as log_type,
    COUNT(*) as total_attempts,
    COUNT(*) FILTER (WHERE record_source = 'AUTH_LOGIN_SECURE') as secure_attempts,
    MAX(load_date) as last_attempt
FROM audit.auth_success_s 
WHERE load_date >= CURRENT_DATE;

-- Check failed attempts (should include blocked cross-tenant attacks)
SELECT 
    'Recent Auth Failures' as log_type,
    COUNT(*) as total_failures,
    COUNT(*) FILTER (WHERE failure_reason = 'USER_NOT_IN_TENANT') as cross_tenant_blocks,
    COUNT(*) FILTER (WHERE failure_reason = 'INVALID_PASSWORD') as password_failures
FROM audit.auth_failure_s 
WHERE load_date >= CURRENT_DATE;
```

**Expected Result:** You should see entries for your test attempts

---

## ✅ **SUCCESS CRITERIA**

**V017 is ready for production when ALL of these are true:**

- [x] **TEST 1:** `success = true` (Valid auth works)
- [x] **TEST 2:** `success = false` (Cross-tenant attack blocked) 🚨 **CRITICAL**
- [x] **TEST 3:** `success = false` (Invalid token rejected)
- [x] **TEST 4:** `success = false` (Missing token rejected)
- [x] **TEST 5:** `success = true` (Backward compatibility works)
- [x] **TEST 6:** `success = false` (Wrong password rejected)
- [x] **Audit logs show entries for your test attempts**

---

## 🚨 **RED FLAGS - DO NOT DEPLOY IF:**

1. **TEST 2 shows success=true** - Cross-tenant attack succeeded (CRITICAL!)
2. **TEST 1 shows success=false** - Valid authentication broken
3. **TEST 5 shows success=false** - Backward compatibility broken
4. **No audit log entries** - Audit logging not working

---

## 🎉 **If All Tests Pass:**

**Your V017 security fix is working correctly and ready for production deployment!**

The cross-tenant vulnerability has been successfully fixed while maintaining backward compatibility. 