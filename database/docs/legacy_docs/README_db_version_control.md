# Database Version Control - Complete Guide
## "Git for Databases" - Managing Your One Vault Foundation

Your One Vault database is **production-ready** (97% health score, 382 tables, Data Vault 2.0 compliant). This system helps you manage changes safely as you build on top of this amazing foundation.

## 🚀 **Quick Start - 5 Minutes to First Migration**

### **1. Check Your Current Database Status:**
```bash
python database/tools/db_version_manager.py status
```

**Expected Output:**
```
🏠 One Vault Database Status
========================================
📍 Current Version: 1.0.0
📝 Name: Initial Data Vault 2.0 Foundation
📅 Deployed: 2024-01-15 14:30:00

🏗️ Database Structure:
   📊 auth: 15 tables
   📊 business: 45 tables
   📊 util: 12 tables
   📊 audit: 8 tables
   ...

📈 Total: 29 schemas, 382 tables
```

### **2. Create Your First Migration:**
```bash
python database/tools/db_version_manager.py create 1.1.0 "Add customer analytics"
```

**This Creates Two Files:**
- `📄 database/migrations/V1.1.0__Add_customer_analytics.sql` (forward migration)
- `↩️ database/rollback/V1.1.0__Add_customer_analytics_rollback.sql` (rollback script)

### **3. Edit the Migration File:**
Open `database/migrations/V1.1.0__Add_customer_analytics.sql` and add your changes:

```sql
-- Migration: Add customer analytics
-- Version: 1.1.0
-- Created: 2024-01-15T15:45:00
-- Description: Add customer analytics tables

-- =============================================================================
-- FORWARD MIGRATION
-- =============================================================================

-- Create analytics hub table
CREATE TABLE business.customer_analytics_h (
    customer_analytics_hk BYTEA PRIMARY KEY,
    customer_analytics_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- Create analytics satellite table
CREATE TABLE business.customer_analytics_s (
    customer_analytics_hk BYTEA NOT NULL REFERENCES business.customer_analytics_h(customer_analytics_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    monthly_revenue DECIMAL(15,2),
    transaction_count INTEGER,
    last_activity_date DATE,
    engagement_score DECIMAL(5,2),
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (customer_analytics_hk, load_date)
);

-- Create indexes for performance
CREATE INDEX idx_customer_analytics_h_tenant ON business.customer_analytics_h(tenant_hk);
CREATE INDEX idx_customer_analytics_s_engagement ON business.customer_analytics_s(engagement_score) WHERE load_end_date IS NULL;

-- Log deployment
SELECT util.log_deployment_start(
    'Add customer analytics (v1.1.0)',
    'Customer analytics tables with tenant isolation and Data Vault 2.0 compliance'
);
```

### **4. Edit the Rollback File:**
Open `database/rollback/V1.1.0__Add_customer_analytics_rollback.sql`:

```sql
-- Rollback: Add customer analytics
-- Version: 1.1.0
-- Created: 2024-01-15T15:45:00

-- =============================================================================
-- ROLLBACK MIGRATION - UNDO ALL CHANGES
-- =============================================================================

-- Drop indexes first
DROP INDEX IF EXISTS business.idx_customer_analytics_s_engagement;
DROP INDEX IF EXISTS business.idx_customer_analytics_h_tenant;

-- Drop tables (satellite first, then hub)
DROP TABLE IF EXISTS business.customer_analytics_s CASCADE;
DROP TABLE IF EXISTS business.customer_analytics_h CASCADE;

-- Log rollback
SELECT util.log_deployment_start(
    'ROLLBACK: Add customer analytics (v1.1.0)',
    'Rolling back customer analytics tables'
);
```

### **5. Test Your Migration (Dry Run):**
```bash
python database/tools/db_version_manager.py migrate --dry-run
```

**Expected Output:**
```
🧪 DRY RUN MODE
   📋 Would execute: V1.1.0__Add_customer_analytics.sql
```

### **6. Apply the Migration:**
```bash
python database/tools/db_version_manager.py migrate
```

**Expected Output:**
```
🚀 Executing: V1.1.0__Add_customer_analytics.sql
   ✅ Completed successfully
```

### **7. Create a Schema Snapshot (Optional but Recommended):**
```bash
python database/tools/db_version_manager.py snapshot 1.1.0
```

**Creates:**
```
📸 Creating schema snapshot: database/schema_snapshots/schema_v1.1.0.sql
```

## 🔄 **Complete Git + Database Workflow**

### **Enterprise Development Process:**

#### **Step 1: Start Feature Development**
```bash
# 1. Create feature branch
git checkout -b feature/customer-analytics

# 2. Create database migration
python database/tools/db_version_manager.py create 1.1.0 "Add customer analytics"

# 3. Edit migration files (see examples above)

# 4. Create frontend components
mkdir frontend/src/components/analytics/
# ... develop React components

# 5. Create backend API endpoints  
# ... develop Python/FastAPI endpoints
```

#### **Step 2: Test Everything Locally**
```bash
# 1. Test database migration
python database/tools/db_version_manager.py migrate --dry-run
python database/tools/db_version_manager.py migrate

# 2. Test application
npm run dev          # Start frontend
python backend/main.py  # Start backend

# 3. Test rollback (important!)
# ... test rollback script works
```

#### **Step 3: Commit and Push**
```bash
# Commit everything together
git add database/migrations/V1.1.0__Add_customer_analytics.sql
git add database/rollback/V1.1.0__Add_customer_analytics_rollback.sql
git add frontend/src/components/analytics/
git add backend/app/routes/analytics.py
git commit -m "Add customer analytics feature - v1.1.0

- Database: Analytics tables with Data Vault 2.0 compliance
- Frontend: Analytics dashboard with charts
- Backend: Analytics API with tenant isolation
- Tests: Unit and integration tests included
"

git push origin feature/customer-analytics
```

#### **Step 4: Code Review & Deployment**
```bash
# 1. Create Pull Request on GitHub
# Reviewers check:
# ✅ Database migration follows Data Vault 2.0 standards
# ✅ Rollback script tested and working
# ✅ Code quality and security
# ✅ Performance impact acceptable

# 2. Merge to develop → Auto-deploy to STAGING
git checkout develop
git merge feature/customer-analytics

# 3. Test in staging environment
# Run full integration tests

# 4. Merge to main → Deploy to PRODUCTION  
git checkout main
git merge develop
```

## 📁 **Directory Structure Explained**

```
database/
├── migrations/                    # ← Forward migration SQL files
│   ├── V1.0.0__Initial_Foundation.sql
│   ├── V1.1.0__Add_customer_analytics.sql
│   └── V1.2.0__Enhanced_reporting.sql
│
├── rollback/                      # ← Rollback SQL files (CRITICAL!)
│   ├── V1.0.0__Initial_Foundation_rollback.sql
│   ├── V1.1.0__Add_customer_analytics_rollback.sql
│   └── V1.2.0__Enhanced_reporting_rollback.sql
│
├── schema_snapshots/              # ← Point-in-time database states
│   ├── schema_v1.0.0.sql         # Baseline snapshot
│   ├── schema_v1.1.0.sql         # After analytics added
│   └── schema_current.sql         # Latest state
│
├── version_control/               # ← Enhanced enterprise features
│   ├── enhanced_database_version_control.sql
│   └── database_version_control_guide.md
│
├── config/                        # ← Configuration files
│   ├── db_config.yaml
│   └── postgresql_production.conf
│
└── tools/                         # ← Management tools
    ├── db_version_manager.py      # Main tool
    └── database_version_manager.py # Enhanced version
```

## 🏷️ **Migration Naming Convention**

**Pattern:** `V{version}__{description}.sql`

### **Version Numbering (Semantic Versioning):**
- **MAJOR.MINOR.PATCH** (e.g., 2.1.5)
- **MAJOR** (2.0.0): Breaking changes, major schema refactors
- **MINOR** (1.1.0): New features, new tables, backwards compatible
- **PATCH** (1.0.1): Bug fixes, small changes, hotfixes

### **Good Examples:**
```
V1.1.0__Add_User_Preferences.sql        # New feature
V1.1.1__Fix_User_Email_Constraint.sql   # Bug fix
V1.2.0__Enhanced_Reporting_Tables.sql   # New feature
V2.0.0__Major_Schema_Refactor.sql       # Breaking change
V2.0.1__Hotfix_Performance_Issue.sql    # Critical fix
```

### **Bad Examples:**
```
❌ migration1.sql                        # No version
❌ V1__stuff.sql                        # Vague description
❌ V1.1.0_add_tables.sql                # Underscore instead of double underscore
❌ V1.1.0__add-user-stuff.sql           # Hyphens not underscores
```

## ⚡ **Best Practices & Pro Tips**

### **1. Always Create Rollback Scripts** ⚠️
**Every migration MUST have a tested rollback script:**
```sql
-- In rollback file, reverse the order:
-- 1. Drop indexes first
-- 2. Drop foreign key constraints  
-- 3. Drop tables (satellites before hubs)
-- 4. Drop functions/procedures
-- 5. Drop schemas last
```

### **2. Follow Data Vault 2.0 Standards** 📐
```sql
-- ✅ Good - Follows Data Vault 2.0 pattern
CREATE TABLE business.new_feature_h (
    new_feature_hk BYTEA PRIMARY KEY,              -- Hash key
    new_feature_bk VARCHAR(255) NOT NULL,          -- Business key
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk), -- Tenant isolation
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);

-- ❌ Bad - Missing tenant isolation and Data Vault structure
CREATE TABLE new_feature (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);
```

### **3. Test Migrations Thoroughly** 🧪
```bash
# Always test in this order:
1. python database/tools/db_version_manager.py migrate --dry-run  # Check syntax
2. python database/tools/db_version_manager.py migrate            # Apply changes
3. # Test application functionality
4. # Test rollback script
5. # Test migration on copy of production data
```

### **4. Use Descriptive Comments** 📝
```sql
-- ✅ Good - Clear purpose and context
-- Migration: Add customer analytics
-- Purpose: Support new analytics dashboard feature
-- Dependencies: Requires auth.tenant_h and business.customer_h
-- Performance: Adds 2 new tables, minimal impact expected
-- Rollback: Safe to rollback, no existing data dependencies

-- ❌ Bad - No context
-- Add some tables
```

### **5. Performance Considerations** ⚡
```sql
-- Add indexes for performance
CREATE INDEX CONCURRENTLY idx_customer_analytics_h_tenant 
ON business.customer_analytics_h(tenant_hk);

-- Use CONCURRENTLY for large tables (PostgreSQL)
-- Check execution time for large migrations
-- Consider maintenance windows for major changes
```

## 🌍 **Environment Variables**

### **Required Environment Variables:**
```bash
# Database connection
export DB_PASSWORD=your_database_password

# Optional - override defaults
export DB_HOST=localhost
export DB_PORT=5432  
export DB_NAME=one_vault
export DB_USER=postgres
```

### **Setting Up Environment Variables:**

#### **Windows (PowerShell):**
```powershell
$env:DB_PASSWORD="your_password"
```

#### **macOS/Linux (Bash):**
```bash
export DB_PASSWORD="your_password"
```

#### **Using .env file (Recommended):**
```bash
# Create .env file in project root
echo "DB_PASSWORD=your_password" > .env

# Python will automatically load it
```

## 🔄 **Integration with Git - Enterprise Workflow**

### **Branching Strategy:**
```
main (production)
├── develop (staging)
│   ├── feature/customer-analytics    # Your feature branch
│   ├── feature/enhanced-reporting    # Other features
│   └── hotfix/performance-fix        # Emergency fixes
```

### **Git Hooks (Optional but Recommended):**
```bash
# .git/hooks/pre-commit
#!/bin/bash
# Check migration syntax before commit
python database/tools/db_version_manager.py migrate --dry-run
```

### **Pull Request Template:**
```markdown
## Database Changes
- [ ] Migration file created and tested
- [ ] Rollback script created and tested  
- [ ] Follows Data Vault 2.0 standards
- [ ] Performance impact assessed
- [ ] Tenant isolation maintained

## Testing
- [ ] Local migration successful
- [ ] Rollback tested
- [ ] Application functionality verified
- [ ] Integration tests pass
```

## 🎯 **Advanced Features & Enterprise Tools**

### **For Production Scale:**

#### **Flyway Integration (Optional):**
```bash
# Install Flyway
npm install -g flyway

# Configure flyway.conf
flyway.url=jdbc:postgresql://localhost:5432/one_vault
flyway.user=postgres  
flyway.schemas=auth,business,util,audit
flyway.locations=filesystem:./database/migrations

# Use Flyway commands
flyway info      # Check status
flyway migrate   # Apply migrations
flyway validate  # Verify consistency
```

#### **CI/CD Pipeline Integration:**
```yaml
# .github/workflows/database.yml
name: Database Migration
on:
  push:
    branches: [develop, main]
    
jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run migrations
        run: python database/tools/db_version_manager.py migrate
```

## 📊 **Your Current Database Status - Production Ready!**

### **Health Score: 97% ✅**
- **29 schemas** with comprehensive organization
- **382 tables** following Data Vault 2.0 methodology  
- **351 functions** providing robust API and business logic
- **Complete HIPAA/GDPR compliance** framework
- **Multi-tenant isolation** and security
- **Performance optimized** with strategic indexing

### **What This Means:**
You have an **enterprise-grade database foundation** that most companies would pay millions to build. This version control system helps you:

1. **Safely add new features** without breaking existing functionality
2. **Collaborate with team members** on database changes
3. **Deploy confidently** with tested rollback procedures
4. **Maintain compliance** with full audit trails
5. **Scale efficiently** as your business grows

## 🚀 **Your Next Steps**

### **Immediate (This Week):**
1. **Create your first migration** following the examples above
2. **Practice the workflow** with a simple table addition
3. **Test rollback procedures** to build confidence

### **Short Term (This Month):**
1. **Set up CI/CD integration** for automated deployments
2. **Train team members** on the workflow
3. **Document your specific conventions** for your team

### **Long Term (This Quarter):**
1. **Consider Flyway integration** for additional enterprise features
2. **Implement monitoring** of migration performance
3. **Set up staging environment** for testing

## 💡 **Need Help?**

### **Common Issues & Solutions:**

#### **"Connection failed" Error:**
```bash
# Check environment variable
echo $DB_PASSWORD

# Test connection manually
psql -h localhost -U postgres -d one_vault
```

#### **"Migration already exists" Error:**
```bash
# Check existing migrations
ls database/migrations/

# Use different version number
python database/tools/db_version_manager.py create 1.1.1 "Different feature"
```

#### **Performance Issues:**
```sql
-- Add CONCURRENTLY for large tables
CREATE INDEX CONCURRENTLY idx_name ON table_name(column);

-- Check execution time
\timing  -- In psql
```

### **Getting Advanced Help:**
- Check `database/version_control/database_version_control_guide.md` for detailed options
- Review `ENTERPRISE_DATABASE_GIT_WORKFLOW.md` for team processes
- Consider professional consultation for complex migrations

---

**🎉 Congratulations!** You now have enterprise-grade database version control. Your One Vault foundation is ready to scale to any size business! 🚀
