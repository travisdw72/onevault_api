# ONE VAULT TEMPLATE DATABASE DEPLOYMENT ORDER
**Updated based on database investigation findings**

## Database Investigation Summary ✅

**Investigation Date**: December 6, 2024  
**Database**: `one_vault` (template database)  
**Investigation Results**: [database_investigation_20250612_081301.json](database_investigation_20250612_081301.json)

### What Already Exists ✅
- **🏗️ Core Schemas**: 15 schemas (api, auth, business, util, audit, etc.)
- **📊 Data Vault 2.0 Tables**: 66 existing tables
- **⚙️ Essential Functions**: 162 functions including critical utilities:
  - `util.hash_binary()` ✅ EXISTS
  - `util.current_load_date()` ✅ EXISTS  
  - `util.get_record_source()` ✅ EXISTS
  - `audit.log_security_event()` ✅ EXISTS (our API integration can use this!)
- **👤 Users**: Multiple users including `barn_user` and `app_user`

### What Needs to be Added ❌
- **util.deployment_log table** ❌ MISSING (needed for tracking)
- **AI System Tables** ❌ MISSING (22 new tables to add)
- **Enhanced deployment tracking functions** ❌ MISSING

---

## UPDATED DEPLOYMENT STRATEGY

### Phase 1: Foundation Infrastructure ⚡ **REQUIRED FIRST**
```bash
# Deploy essential missing infrastructure only
psql -d one_vault -f deploy_template_foundation.sql
```

**What this does:**
- ✅ Creates `util.deployment_log` table (required by other scripts)
- ✅ Creates deployment tracking functions
- ✅ Sets up template features and version tracking
- ✅ Ensures `app_user` has proper login capabilities
- ⚠️ **Does NOT recreate existing functions** (investigation found they exist)
- ⚠️ **Does NOT drop or modify existing infrastructure**

### Phase 2: AI Data Vault 2.0 System 🤖 **CORE AI DEPLOYMENT**
```bash
# Deploy complete AI system (22 new tables)
psql -d one_vault -f deploy_ai_data_vault.sql
```

**What this does:**
- 🆕 Creates 22 AI-specific tables (business, audit, util, ref schemas)
- 🆕 Creates AI business functions (store_ai_interaction, create_ai_session, etc.)
- ✅ Uses existing functions (no recreation attempts)
- ✅ Works with or without foundation deployment_log table
- 🔐 Applies security permissions to `app_user`

### Phase 3: Critical Business Schemas 🏢 **BUSINESS SYSTEMS**
```bash
# Deploy business management schemas (health, finance, performance)
psql -d one_vault -f deploy_critical_schemas.sql
```

**Dependencies**: Foundation deployment_log table recommended

### Phase 4: Enhanced AI APIs 🚀 **PRODUCTION AI FEATURES**
```bash
# Deploy production-ready AI API functions (optional enhancement)
psql -d one_vault -f deploy_ai_api_integration.sql
```

**What this includes:**
- 🔒 Rate limiting (10 requests/minute per user)
- 🛡️ Content safety analysis and filtering
- 💰 Cost tracking with GPT-4 Turbo pricing
- 📊 Comprehensive audit logging for compliance

---

## USER MANAGEMENT STRATEGY

### Current State (Investigation Findings)
- ✅ `app_user` exists (no login capability)
- ✅ `barn_user` exists (can login)
- ✅ Multiple other implementation users exist

### Standardization Options

#### Option A: Keep Both Users (Recommended)
```bash
# Make app_user login-capable (foundation script does this)
psql -d one_vault -f deploy_template_foundation.sql

# Optionally clean up barn_user later
psql -d one_vault -f cleanup_barn_user.sql
```

#### Option B: Use Existing barn_user (Alternative)
- **Pros**: No user changes needed
- **Cons**: Name not generic for template database
- **Action**: Update all scripts to use `barn_user` instead of `app_user`

### For Implementation Databases
Use the customization script to rename users appropriately:
```bash
# Example: Creating One Barn implementation
psql -d one_barn_db -f customize_application_users.sql \
  -v implementation_name='barn' \
  -v admin_email='admin@onebarn.com'
```

---

## DETAILED DEPLOYMENT EXAMPLES

### Example 1: Fresh Template Setup
```bash
# Step 1: Deploy foundation (required)
psql -U postgres -d one_vault -f deploy_template_foundation.sql

# Step 2: Deploy AI system
psql -U postgres -d one_vault -f deploy_ai_data_vault.sql

# Step 3: Deploy business schemas
psql -U postgres -d one_vault -f deploy_critical_schemas.sql

# Step 4: Deploy enhanced AI APIs
psql -U postgres -d one_vault -f deploy_ai_api_integration.sql

# Step 5: Standardize users (optional)
psql -U postgres -d one_vault -f cleanup_barn_user.sql
```

### Example 2: AI-Only Deployment (Minimal)
```bash
# Deploy only AI system (foundation will be created automatically)
psql -U postgres -d one_vault -f deploy_template_foundation.sql
psql -U postgres -d one_vault -f deploy_ai_data_vault.sql
psql -U postgres -d one_vault -f deploy_ai_api_integration.sql
```

### Example 3: Validation After Deployment
```bash
# Validate template readiness
psql -U postgres -d one_vault -c "SELECT * FROM util.validate_template_readiness();"

# Check deployment history
psql -U postgres -d one_vault -c "SELECT * FROM util.deployment_log ORDER BY deployment_start DESC LIMIT 5;"

# Verify AI tables
psql -U postgres -d one_vault -c "SELECT COUNT(*) as ai_table_count FROM pg_tables WHERE schemaname IN ('business', 'audit', 'util', 'ref') AND (tablename LIKE '%ai%' OR tablename LIKE '%ai_%');"
```

---

## TROUBLESHOOTING GUIDE

### Common Issues and Solutions

#### Issue: "relation util.deployment_log does not exist"
**Solution**: Run foundation script first
```bash
psql -d one_vault -f deploy_template_foundation.sql
```

#### Issue: "cannot change name of input parameter"
**Cause**: Trying to recreate existing functions  
**Solution**: Updated scripts no longer recreate existing functions ✅

#### Issue: "role barn_user does not exist" 
**Solution A**: Use app_user instead (scripts updated) ✅  
**Solution B**: Create barn_user if needed

#### Issue: "function util.hash_binary does not exist"
**Cause**: Function should exist (investigation confirmed)  
**Solution**: Check if function was accidentally dropped:
```sql
-- Verify function exists
SELECT proname FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'util' AND p.proname = 'hash_binary';
```

---

## SUCCESS CRITERIA

### Template Database Ready When:
- ✅ All essential functions exist (`util.hash_binary`, `util.current_load_date`, etc.)
- ✅ All Data Vault 2.0 foundation tables exist
- ✅ AI system tables exist (22 tables)
- ✅ Deployment tracking is functional
- ✅ User permissions are properly configured
- ✅ Template features are documented

### Validation Commands:
```sql
-- Check template readiness
SELECT * FROM util.validate_template_readiness();

-- Verify AI deployment
SELECT COUNT(*) FROM pg_tables WHERE tablename LIKE '%ai%';

-- Check user configuration
SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname IN ('app_user', 'barn_user');

-- Review deployment history
SELECT deployment_name, deployment_status, deployment_start 
FROM util.deployment_log ORDER BY deployment_start DESC;
```

---

## POST-DEPLOYMENT NOTES

### Template Database Benefits ✅
- **Complete Data Vault 2.0** foundation with temporal tracking
- **Enterprise AI Integration** with audit trails and compliance
- **Zero Trust Security** with comprehensive logging
- **Multi-Tenant Architecture** with complete isolation
- **HIPAA/GDPR Compliance** built-in
- **Production-Ready APIs** with rate limiting and safety controls

### Next Steps for Implementation Databases
1. **Create from Template**: Use `one_vault` as template for new implementations
2. **Customize Users**: Rename `app_user` to implementation-specific names
3. **Configure Business Rules**: Adapt to specific industry requirements
4. **Deploy Applications**: Connect frontend applications to standardized APIs
5. **Monitor and Scale**: Use built-in performance and audit systems

### Architecture Ready For:
- 🐴 **One Barn**: Equestrian management (barn_user, horse-specific features)
- 💰 **One Wealth**: Financial planning (wealth_user, investment tracking)  
- 🏥 **One Health**: Healthcare management (health_user, patient records)
- 🏪 **One Spa**: Spa/wellness (spa_user, appointment systems)
- 🎯 **Any Business**: Generic business optimization platform

---

**Investigation-Based Deployment**: This deployment strategy is based on actual database investigation findings and preserves existing infrastructure while adding only the necessary missing components.

## Validation

After each phase, validate the deployment:

```sql
-- Check foundation readiness
SELECT * FROM util.validate_template_readiness();

-- Check deployment history
SELECT 
    deployment_name,
    deployment_status,
    deployment_start,
    deployment_end
FROM util.deployment_log 
ORDER BY deployment_start DESC;

-- Check template features
SELECT 
    feature_name,
    is_enabled,
    deployment_date
FROM util.template_features 
WHERE is_enabled = true;
```

## Dependency Matrix

| Script | Depends On | Provides | Required For |
|--------|------------|----------|--------------|
| `deploy_template_foundation.sql` | None | `util.deployment_log`, core functions | All other scripts |
| `deploy_ai_data_vault.sql` | Foundation | AI tables, functions | AI API integration |
| `deploy_critical_schemas.sql` | Foundation | Business schemas | Full functionality |
| `deploy_ai_api_integration.sql` | Foundation + AI | Enhanced APIs | Production AI |

## Error Resolution

### Common Error: "relation util.deployment_log does not exist"
**Cause:** Attempting to run scripts without foundation
**Solution:** Run `deploy_template_foundation.sql` first

### Common Error: "function util.hash_binary does not exist"
**Cause:** Missing core utility functions
**Solution:** Run `deploy_template_foundation.sql` first

### Common Error: "schema auth does not exist"
**Cause:** Template database missing core schemas
**Solution:** Ensure base template database is properly created with auth/business schemas

### Common Error: "role [user_name] does not exist"
**Cause:** Scripts trying to grant permissions to non-existent user
**Solution:** Foundation script creates `app_user` automatically, use customization script for specific users

## Template Database Strategy

### Schema and User Management
- **`util` and `audit` schemas**: Created by foundation script (always needed)
- **`app_user` role**: Generic application user created by foundation script
- **Other schemas**: Created by subsequent scripts (`auth`, `business`, `health`, etc.)
- **Permissions**: Set automatically when schemas/tables are created
- **User Customization**: Use `customize_application_users.sql` to rename/create implementation-specific users

### Template Inheritance
When you create an implementation database with `CREATE DATABASE new_db WITH TEMPLATE one_vault`, the new database inherits:
- All schema structures
- All functions and procedures  
- All permissions and roles
- All reference data
- All indexes and constraints

## Architecture Benefits

### Template Database Approach
- ✅ **Consistency:** All implementations identical
- ✅ **Speed:** New systems deploy in seconds
- ✅ **Compliance:** Built-in HIPAA/GDPR compliance
- ✅ **AI Ready:** Every system has enterprise AI capabilities
- ✅ **Maintenance:** Update template, all systems benefit

### Enterprise Features (Built-in)
- ✅ **Data Vault 2.0:** Complete temporal tracking
- ✅ **Zero Trust Security:** Comprehensive audit trails
- ✅ **Multi-Tenant:** Complete tenant isolation
- ✅ **AI Integration:** Production-ready AI with safety controls
- ✅ **Compliance:** HIPAA/GDPR/SOX compliance framework
- ✅ **Performance:** Optimized indexes and materialized views

## Support

For deployment issues or questions:
1. Check deployment logs: `SELECT * FROM util.deployment_log;`
2. Validate readiness: `SELECT * FROM util.validate_template_readiness();`
3. Review this deployment order document
4. Contact: Development Team

---

**Last Updated:** December 2024  
**Version:** 1.0  
**Template Version:** One Vault v1.0.0 