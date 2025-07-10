# 🚀 ONE BARN AI SETUP - EXECUTION GUIDE

## Quick Start Instructions

### **STEP 1: Choose Your Approach**

#### **Option A: PgAdmin (RECOMMENDED) 👑**
- ✅ **Safer** - run section by section
- ✅ **Easier debugging** - see errors immediately  
- ✅ **Visual feedback** - results displayed clearly
- ✅ **Incremental** - stop/fix issues as they occur

#### **Option B: API Layer**
- ✅ **Production-like** - tests full stack
- ⚠️ **More complex** - requires API configuration
- ⚠️ **Harder debugging** - errors buried in logs

---

## 🎯 **RECOMMENDED: PgAdmin Step-by-Step**

### **Prerequisites:**
- PgAdmin connected to `localhost`
- Database: `one_vault_site_testing`
- Your existing working credentials

### **Execution Steps:**

#### **1. Open the Corrected Script**
```sql
-- File: onevault_api/one_barn_corrected_setup.sql
-- This replaces the broken original script
```

#### **2. Run Phase 1 - Tenant Creation**
```sql
-- Copy and execute PHASE 1 section
-- Watch for SUCCESS notices:
-- "One_Barn_AI tenant created successfully"
-- "Tenant HK: [hex_value]"
-- "Admin User HK: [hex_value]"
```

#### **3. Verify Tenant Creation**
```sql
-- Run the verification queries in PHASE 1
-- Should show one_barn_ai tenant with active status
```

#### **4. Run Phase 3 - User Creation**
```sql
-- Copy and execute PHASE 3 section  
-- Watch for 3 user creation notices:
-- "Created veterinary specialist user"
-- "Created technical lead user" 
-- "Created business development user"
```

#### **5. Run Final Verification**
```sql
-- Execute the final verification queries
-- Should show 4 total users created
-- All users should be active
```

#### **6. Test API Authentication**
```sql
-- Run the authentication test command
-- Should return success JSON with session token
SELECT api.auth_login('{"username": "admin@onebarnai.com", "password": "HorseHealth2025!", "ip_address": "127.0.0.1", "user_agent": "OneVault-Demo-Client", "auto_login": true}');
```

---

## 🎭 **Demo Scenarios Ready After Setup**

### **1. Enterprise Admin Dashboard**
- **Login**: admin@onebarnai.com
- **Role**: Full system access
- **Demo**: Tenant management, user oversight

### **2. Veterinary Specialist**  
- **Login**: vet@onebarnai.com
- **Role**: Administrator level
- **Demo**: AI health analysis, emergency detection

### **3. Technical Lead**
- **Login**: tech@onebarnai.com  
- **Role**: Manager level
- **Demo**: API integrations, system monitoring

### **4. Business Development**
- **Login**: business@onebarnai.com
- **Role**: User level  
- **Demo**: Analytics, ROI reporting

---

## 🛠️ **Alternative: API Layer Setup**

### **If you want to test the full stack:**

#### **1. Configure API Connection**
```python
# In onevault_api/config.py or main.py
DB_HOST = "localhost"
DB_NAME = "one_vault_site_testing"
DB_USER = "[your_username]"  
DB_PASSWORD = "[your_password]"
```

#### **2. Test Database Connection**
```bash
# Run your API
python main.py

# Test health check
GET http://localhost:8000/health/db
```

#### **3. Execute via API**
```python
# Use the Python scripts to run setup
python one_barn_analysis.py
python test_one_barn_setup.py
```

---

## ⚡ **Quick Success Check**

### **After Setup, Verify:**
- [ ] 1 tenant created (One_Barn_AI)
- [ ] 4 users created (Admin, Vet, Tech, Business)  
- [ ] API login works for admin user
- [ ] All users show as active
- [ ] No error messages in execution

### **If Everything Works:**
**🎉 You're ready for July 7th demo!**

### **If Issues Occur:**
1. **Check function signatures** - use corrected script
2. **Run incrementally** - one phase at a time  
3. **Check error messages** - they're descriptive
4. **Verify database connection** - test with simple query first

---

## 📅 **July 7th Demo Flow**

### **Live Demo Sequence:**
1. **Start with admin login** - show enterprise setup
2. **Switch to veterinarian** - demonstrate AI analysis  
3. **Show technical integration** - API endpoints  
4. **Present business value** - ROI & partnership model

### **Partnership Discussion:**
- Revenue sharing (60/40 split)
- Technical requirements
- Scaling strategy
- Next steps

**This setup creates a complete enterprise demo environment! 🏆** 