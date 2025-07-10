# Step-by-Step One Barn AI Setup Guide

🎯 **Purpose**: Break down the setup into individual steps to isolate and fix the persistent audit constraint issues.

## Current Issue
The `auth.register_user` procedure is generating **duplicate audit hash keys**, causing this error:
```
ERROR: duplicate key value violates unique constraint "audit_event_h_pkey"
```

## Step-by-Step Approach

### Step 1: Create Tenant Only ✅
**File**: `step1_create_tenant.sql`

Run this first to create the tenant and admin user. This usually works fine.

Expected output:
- ✅ Tenant HK: [some hash]
- ✅ Admin User HK: [some hash] 
- Roles created: ADMINISTRATOR, MANAGER, ANALYST, USER, etc.

### Step 2: Clear Audit Events 🧹
**File**: `step2_clear_audit.sql`

This clears audit events that might be causing conflicts.

Expected output:
- ✅ Deleted X audit events from today
- ✅ Deleted X audit events with problematic hash key

### Step 3: Create Travis Woodward (CEO) 👤
**File**: `step3_create_travis.sql`

This is where the error usually occurs. Run this to test if the audit clearing worked.

**If successful**:
- ✅ SUCCESS: Travis Woodward created!
- User HK: [some hash]

**If it fails**:
- ❌ FAILED to create Travis Woodward
- Error details will be shown

### Step 4: Create Michelle Nash (Support Manager) 👤
**File**: `step4_create_michelle.sql`

Only run this if Step 3 succeeded.

### Step 5: Create Sarah Robertson (VP Business Development) 👤
**File**: `step5_create_sarah.sql`

VP Business Development with MANAGER role.

### Step 6: Create Demo User (For Presentations) 👤
**File**: `step6_create_demo.sql`

Demo account with USER role for presentations.

### Step 7: Final Verification & Demo Credentials 🎉
**File**: `step7_final_verification.sql`

Comprehensive verification and credential summary.

## Troubleshooting Options

### If Step 3 Fails Again

1. **Check the specific audit hash key causing conflicts**:
   ```sql
   SELECT audit_event_hk, load_date, event_type 
   FROM audit.audit_event_h 
   WHERE audit_event_hk = '\x68e1c221b227205d5b2a3e581951eeb190cd7bd0a4bedf6817f335ae4f5eebc0';
   ```

2. **Clear ALL audit events** (more aggressive):
   ```sql
   DELETE FROM audit.audit_event_h WHERE load_date >= CURRENT_DATE - INTERVAL '7 days';
   ```

3. **Check if the audit system is generating predictable hashes**:
   The Admin User HK is always the same: `e5d44ba2149c3fe0c32f45a6db561427299d8d3b40b046c7b4781120ce490b35`
   This suggests the audit hash generation might be deterministic based on user data.

### Alternative Approach: Manual User Creation

If the audit system continues to fail, we can create users manually without going through `auth.register_user`:

1. Insert directly into `auth.user_h`
2. Insert directly into `auth.user_profile_s` 
3. Insert directly into `auth.user_auth_s`
4. Insert directly into `auth.user_role_l`
5. Skip the audit system entirely

## Current Status

✅ **Tenant Creation**: Works reliably  
❌ **User Creation**: Failing due to audit conflicts  
🔧 **Solution**: Step-by-step approach with audit clearing

## Next Steps

1. Run `step1_create_tenant.sql` 
2. Run `step2_clear_audit.sql`
3. Run `step3_create_travis.sql`
4. Run `step4_create_michelle.sql`
5. Run `step5_create_sarah.sql`
6. Run `step6_create_demo.sql`
7. Run `step7_final_verification.sql`

If any step fails, we can investigate the audit system deeper or create a manual user creation approach.

The goal is to get all 5 demo users created for the July 7, 2025 presentation. 