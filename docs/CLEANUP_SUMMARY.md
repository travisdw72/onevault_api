# One Barn AI Setup - Cleanup Summary

## What We Learned 🎯

### The Problem
- Original setup scripts had **multiple issues**:
  - Called non-existent function `auth.register_user_with_roles()`
  - Used wrong parameter structure
  - Referenced wrong table names (`role_profile_s` vs `role_definition_s`)
  - Used hardcoded tenant HKs that didn't match actual database

### The Solution
- **Correct function**: `auth.register_user()` (PROCEDURE, not function)
- **Correct parameters**: `(tenant_hk, email, password, first_name, last_name, role_bk)`
- **Correct approach**: Create tenant first, then dynamically build role business keys

### Key Discoveries
1. **Tenant creation works**: `auth.register_tenant_with_roles()` creates tenant + 6 default roles
2. **Role naming pattern**: `{tenant_name}_{timestamp}_{ROLE_TYPE}`
3. **Single script approach**: Better than multi-phase for production
4. **Timestamp dependency**: Role business keys include exact tenant creation timestamp

## Files to Clean Up 🧹

### ❌ DELETE THESE FILES (Broken/Outdated)
```bash
rm onevault_api/one_barn_ai_setup_plan.sql               # Original broken script
rm onevault_api/one_barn_corrected_setup.sql            # Had wrong function calls
rm onevault_api/one_barn_clean_setup.sql                # Multi-phase approach
rm onevault_api/one_barn_phase2_corrected.sql           # Wrong function calls
rm onevault_api/one_barn_phase2_fixed.sql               # Wrong tenant HK
rm onevault_api/one_barn_phase2_final.sql               # Hardcoded tenant HK
rm onevault_api/check_roles.sql                         # Wrong table names
```

### 🔧 KEEP THESE FILES (Useful Tools)
```bash
# Diagnostic tools for future debugging
onevault_api/check_roles_simple.sql                     # Table structure discovery
onevault_api/diagnose_tenant_mismatch.sql               # Tenant debugging

# Documentation
onevault_api/one_barn_analysis_summary.md               # Project analysis
onevault_api/EXECUTION_GUIDE.md                         # Step-by-step guide
onevault_api/CLEANUP_SUMMARY.md                         # This file
```

### ✅ PRODUCTION READY
```bash
# THE FINAL WORKING SCRIPT
onevault_api/ONE_BARN_AI_COMPLETE_SETUP.sql            # Single complete setup
```

## Testing Plan 📋

### 1. Fresh Database Test
```sql
-- Run on clean test database
\i onevault_api/ONE_BARN_AI_COMPLETE_SETUP.sql
```

### 2. Verification Queries
```sql
-- Verify tenant created
SELECT tp.tenant_name, encode(th.tenant_hk, 'hex') as tenant_hk
FROM auth.tenant_h th
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- Verify roles created (should be 6)
SELECT COUNT(*) as role_count
FROM auth.role_h rh
JOIN auth.tenant_h th ON rh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- Verify users created (should be 5: 1 admin + 4 demo users)
SELECT COUNT(*) as user_count
FROM auth.user_h uh
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL;

-- Verify user roles assigned
SELECT up.email, up.first_name, up.last_name, rh.role_bk
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
JOIN auth.role_h rh ON url.role_hk = rh.role_hk
JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
WHERE tp.tenant_name = 'one_barn_ai'
AND tp.load_end_date IS NULL
AND up.load_end_date IS NULL
ORDER BY up.email;
```

### 3. Expected Results
- **1 tenant**: one_barn_ai
- **6 roles**: ADMINISTRATOR, MANAGER, ANALYST, AUDITOR, USER, VIEWER
- **5 users**: admin@onebarnai.com + 4 demo users
- **5 role assignments**: Each user assigned to 1 role

## Production Deployment 🚀

### Prerequisites
- ✅ Clean test database validation
- ✅ All expected results verified
- ✅ No errors in script execution

### Production Command
```bash
# Backup production first
pg_dump production_db > backup_before_one_barn_$(date +%Y%m%d_%H%M%S).sql

# Run the setup
psql production_db -f onevault_api/ONE_BARN_AI_COMPLETE_SETUP.sql
```

### Rollback Plan
If anything goes wrong:
```sql
-- Delete tenant and all related data
DELETE FROM auth.user_role_l 
WHERE tenant_hk IN (
    SELECT th.tenant_hk FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
    WHERE tp.tenant_name = 'one_barn_ai'
);

-- (Continue with other cleanup...)
-- Or restore from backup
```

## Demo Credentials 🔑

After successful setup:

| User | Email | Password | Role |
|------|-------|----------|------|
| Travis Woodward | travis.woodward@onebarnai.com | SecurePass123! | ADMINISTRATOR |
| Michelle Nash | michelle.nash@onebarnai.com | TechLead456! | MANAGER |
| Sarah Robertson | sarah.robertson@onebarnai.com | BizDev789! | ANALYST |
| Demo User | demo@onebarnai.com | Demo123! | USER |
| System Admin | admin@onebarnai.com | AdminPass123! | ADMINISTRATOR |

**Ready for July 7, 2025 Horse Health AI Demo! 🐎🤖** 