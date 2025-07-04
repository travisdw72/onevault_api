# 🚀 One_Barn_AI Demo - Quick Validation Commands

## Copy-Paste Commands for pgAdmin Testing

### 1. Execute Setup Script First
```sql
-- Run this file in pgAdmin:
-- mission_7_7_25/one_barn_ai_final_setup.sql
```

### 2. Validate Tenant Creation
```sql
SELECT 
    '✅ TENANT VALIDATION' as test_type,
    tp.tenant_name,
    tp.business_name,
    tp.subscription_level,
    CASE WHEN tp.is_active THEN '✅ ACTIVE' ELSE '❌ INACTIVE' END as status
FROM auth.tenant_profile_s tp
WHERE tp.tenant_name = 'one_barn_ai' 
AND tp.load_end_date IS NULL;
```

### 3. Test Admin Authentication
```sql
SELECT 
    '✅ AUTH TEST' as test_type,
    api.auth_login('{
        "username": "admin@onebarnai.com",
        "password": "HorseHealth2025!",
        "ip_address": "127.0.0.1",
        "user_agent": "OneVault-July7-Demo",
        "auto_login": true
    }') as login_result;
```

### 4. Verify Demo Users
```sql
SELECT 
    '✅ DEMO USERS' as test_type,
    up.email,
    up.first_name || ' ' || up.last_name as name,
    up.job_title,
    CASE WHEN uas.is_active THEN '✅ ACTIVE' ELSE '❌ INACTIVE' END as status
FROM auth.user_profile_s up
JOIN auth.user_h uh ON up.user_hk = uh.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND up.load_end_date IS NULL
AND tp.load_end_date IS NULL
ORDER BY up.email;
```

### 5. Check Demo Horses
```sql
SELECT 
    '🐴 DEMO HORSES' as test_type,
    ed.entity_name,
    ed.entity_metadata->>'breed' as breed,
    ed.entity_metadata->>'demo_scenario' as scenario,
    ed.entity_metadata->>'health_status' as health_status
FROM business.entity_details_s ed
JOIN business.entity_h eh ON ed.entity_hk = eh.entity_hk
JOIN auth.tenant_h th ON eh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND ed.entity_type = 'horse'
AND ed.load_end_date IS NULL
AND tp.load_end_date IS NULL
ORDER BY ed.entity_name;
```

### 6. System Health Check
```sql
SELECT 
    '🔧 SYSTEM HEALTH' as test_type,
    api.system_health_check('{}') as health_result;
```

### 7. Complete Demo Readiness Report
```sql
-- FINAL VALIDATION SUMMARY
SELECT 
    'DEMO READINESS REPORT - JULY 7TH, 2025' as report_title,
    CURRENT_TIMESTAMP as generated_at;

-- Tenant Status
SELECT 
    '1. TENANT' as component,
    CASE WHEN COUNT(*) > 0 THEN '✅ READY' ELSE '❌ MISSING' END as status
FROM auth.tenant_profile_s 
WHERE tenant_name = 'one_barn_ai' 
AND load_end_date IS NULL;

-- User Count
SELECT 
    '2. USERS' as component,
    COUNT(*)::text || ' users created' as status
FROM auth.user_profile_s up
JOIN auth.user_h uh ON up.user_hk = uh.user_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND up.load_end_date IS NULL
AND tp.load_end_date IS NULL;

-- Demo Data
SELECT 
    '3. HORSES' as component,
    COUNT(*)::text || ' demo horses ready' as status
FROM business.entity_details_s ed
JOIN business.entity_h eh ON ed.entity_hk = eh.entity_hk
JOIN auth.tenant_h th ON eh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND ed.entity_type = 'horse'
AND ed.load_end_date IS NULL
AND tp.load_end_date IS NULL;
```

## Expected Results

### ✅ Success Indicators
- **Tenant**: 1 active tenant named 'one_barn_ai'
- **Users**: 4 users (admin, vet, tech, business)
- **Horses**: 2 demo horses (Buttercup, Thunder)
- **Auth**: JSON response with p_success: true
- **Health**: System health check returns status data

### ❌ Failure Indicators
- **No tenant found**: Re-run setup script
- **Auth failure**: Check password/username
- **Missing horses**: Verify business schema exists
- **No users**: Check user creation in setup script

## Demo Credentials (For Testing)
```
Admin: admin@onebarnai.com / HorseHealth2025!
Vet: vet@onebarnai.com / VetSpecialist2025!
Tech: tech@onebarnai.com / TechLead2025!
Business: business@onebarnai.com / BizDev2025!
```

## 🎯 Quick Success Checklist
- [ ] SQL setup script executed without errors
- [ ] Tenant query returns one_barn_ai
- [ ] Auth test returns success JSON
- [ ] 4 users found in user query
- [ ] 2 horses found in demo data
- [ ] System health check responds

**If all checks pass: 🎉 READY FOR JULY 7TH DEMO!** 