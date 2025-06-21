# ⚡ Quick Setup Guide - System Operations Tenant

## 🚀 **One-Time Setup (Run These Once)**

Copy and paste these scripts into pgAdmin **in order**:

### **Step 1: Create System Operations Tenant**
```bash
# File: 01_create_system_operations_tenant.sql
# Run this first to create the system tenant
```

### **Step 2: Create System Admin User**
```bash
# File: 02_create_system_admin_user.sql  
# Run this second to create the system admin
```

### **Step 3: Verify Setup**
```bash
# File: 03_verify_system_setup.sql
# Run this third to verify everything works
```

## 🎯 **Expected Results**

After successful setup, you should see:

### **From Script 1:**
```
🏗️  Starting System Operations Tenant Creation...
✅ System Operations Tenant Hub created successfully
✅ System Operations Tenant Profile created successfully
✅ Verification successful!
🎉 System Operations Tenant creation completed successfully!
```

### **From Script 2:**
```
👤 Starting System Admin User Creation...
✅ System Operations Tenant verified
✅ System Admin User Hub created successfully
✅ System Admin User Profile created successfully
✅ System Admin Authentication created successfully
🎉 System Admin User creation completed successfully!
```

### **From Script 3:**
```
🔍 SYSTEM OPERATIONS SETUP VERIFICATION
✅ System Operations Tenant EXISTS
✅ System Admin User EXISTS
✅ System tenant hash key format correct (32 bytes)
🎉 SUCCESS: System Operations setup is PERFECT!
```

## 🔐 **Default Credentials**

After setup, you'll have:

- **Username**: `system.admin@onevault.com`
- **Password**: `SystemAdmin2024!@#`
- **⚠️ IMPORTANT**: Change this password immediately!

## 🧪 **Test Your Setup**

After running the setup scripts, test your tenant registration:

```sql
-- Test the updated API function
SELECT api.tenant_register_elt('{
  "tenant_name": "Test Company", 
  "admin_email": "admin@testcompany.com",
  "admin_password": "TestPassword123!",
  "admin_first_name": "Admin",
  "admin_last_name": "User"
}'::jsonb);
```

**Expected Result:**
```json
{
  "success": true,
  "message": "Tenant registered successfully via ELT pipeline",
  "data": {
    "tenant_id": "Test Company_2024...",
    "admin_user_id": "admin@testcompany.com_ADMIN_...",
    "elt_pipeline": "COMPLETED"
  }
}
```

## 🔧 **If Something Goes Wrong**

### **Common Issues:**

1. **"System Operations Tenant already exists"**
   - ✅ **This is fine!** The script detected an existing tenant and skipped creation
   - Continue to the next script

2. **"System Admin User already exists"**
   - ✅ **This is fine!** The script detected an existing admin and skipped creation
   - Continue to verification

3. **"Missing auth tables"**
   - ❌ **Problem**: Your database schema isn't complete
   - **Solution**: Run your main database migration scripts first

4. **"Function api.tenant_register_elt does not exist"**
   - ❌ **Problem**: The API function hasn't been updated
   - **Solution**: Run the updated `api.tenant_register.sql` script

### **Need to Start Over?**

If you need to completely recreate the system tenant:

```sql
-- DANGER: Only run if you need to start over
-- This will delete the system tenant and all its data

-- Delete system tenant (this cascades to users)
DELETE FROM auth.tenant_h 
WHERE tenant_bk = 'SYSTEM_OPERATIONS';

-- Then re-run setup scripts 1, 2, 3
```

## 🎉 **Success! What's Next?**

Once setup is complete:

1. **✅ System Operations Tenant is ready**
2. **✅ Tenant registration uses proper ELT pipeline**  
3. **✅ No more system tenant creation during business operations**
4. **✅ Clean architectural separation**

Now you can:
- Register new business tenants cleanly
- Expand system operations safely
- Maintain proper tenant isolation
- Add new system features easily

---

**🚀 Ready to go! Your system operations foundation is enterprise-ready.** 