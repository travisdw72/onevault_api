# Site Tracking Database Testing Scripts

## Overview
These Python scripts test the current database state and validate readiness for deploying our site tracking SQL scripts.

## Files Created

### 1. `testingDBConfig.py` - Configuration File
**Single source of truth** for all testing parameters including:
- Database connection settings
- SQL script paths and execution order
- Validation queries for schema and prerequisite checks
- Conflict detection queries
- Test data and sample operations

### 2. `testingDB-siteTracking.py` - Main Testing Script
Comprehensive testing script that validates:
- **Database Connection**: Tests connection with secure password prompt
- **Schema Validation**: Checks for required schemas (raw, staging, business, api, etc.)
- **Prerequisites**: Validates existing auth system, util functions, tenant structure
- **Script Readiness**: Validates all 6 SQL scripts exist and are syntactically correct
- **Conflict Detection**: Checks for potential naming conflicts
- **Overall Assessment**: Provides deployment readiness status

## How to Run

### Prerequisites
- Python 3.6+ with psycopg2 installed
- PostgreSQL database access
- Database credentials

### Install Required Dependencies
```bash
pip install psycopg2-binary
```

### Run the Test Suite
```bash
python testingDB-siteTracking.py
```

## What the Script Tests

### 🔐 **Database Connection**
- Securely prompts for PostgreSQL password
- Tests connection to `one_vault` database
- Validates user permissions and database access

### 📋 **Schema Validation**
Checks for existence of required schemas:
- ✅ `auth` - Authentication system (should exist)
- ✅ `business` - Business logic layer (should exist)
- ⚠️ `raw` - Raw data ingestion (may not exist, will be created)
- ⚠️ `staging` - Data staging layer (may not exist, will be created)
- ⚠️ `api` - API endpoints (may not exist, will be created)
- ✅ `util` - Utility functions (should exist)
- ✅ `audit` - Audit logging (should exist)

### 🔍 **Prerequisite Checks**
Validates critical existing components:
- **Auth System**: `auth.tenant_h` table with proper structure
- **Util Functions**: `hash_binary()`, `current_load_date()` functions
- **Tenant Structure**: Validates tenant isolation architecture
- **Data Vault Foundation**: Checks for proper hash key and business key patterns

### 📄 **SQL Script Validation**
Validates all 6 site tracking scripts:
1. `01_create_raw_layer.sql` - Raw data ingestion layer
2. `02_create_staging_layer.sql` - Data staging and validation layer
3. `03_create_business_hubs.sql` - Data Vault 2.0 business hubs
4. `04_create_business_links.sql` - Data Vault 2.0 relationship links
5. `05_create_business_satellites.sql` - Data Vault 2.0 descriptive attributes
6. `06_create_api_layer.sql` - API endpoints and authentication

### ⚡ **Conflict Detection**
Checks for potential naming conflicts:
- Existing tables that might conflict with site tracking tables
- Function names that might conflict with new procedures
- Schema objects that might need to be addressed

## Expected Results

### ✅ **READY Status**
- All critical prerequisites exist
- Scripts are valid and readable
- Minimal conflicts detected
- Database ready for immediate deployment

### ⚠️ **CAUTION Status**
- Minor issues or warnings present
- Deployment possible but review warnings first
- Some conflicts may need manual resolution

### ❌ **NOT_READY Status**
- Critical prerequisites missing
- Major conflicts detected
- Database requires preparation before deployment

## Sample Output

```
🚀 Site Tracking Database Readiness Test
============================================================
Testing database readiness for site tracking implementation
Test started: 2024-01-15 14:30:25

🔐 Site Tracking Database Connection
==================================================
Host: localhost
Port: 5432
Database: one_vault
User: postgres

Enter PostgreSQL password: ********

🔄 Connecting to database...
✅ Connected successfully!
   PostgreSQL Version: PostgreSQL 15.2
   Database: one_vault
   User: postgres

📋 Checking Database Schemas
==================================================
   ✅ Schema 'auth' exists
   ✅ Schema 'business' exists
   ⚠️ Schema 'raw' missing (will be created by scripts)
   ⚠️ Schema 'staging' missing (will be created by scripts)
   ⚠️ Schema 'api' missing (will be created by scripts)
   ✅ Schema 'util' exists
   ✅ Schema 'audit' exists

🔍 Checking Prerequisites
==================================================
   ✅ Auth tenant system exists and properly configured
      Found functions: ['hash_binary', 'current_load_date', 'get_record_source']
   ✅ Utility functions available
   ✅ Tenant isolation architecture in place

📄 Validating SQL Scripts
==================================================
   ✅ Raw Layer Script: 8,100 bytes
   ✅ Staging Layer Script: 14,300 bytes
   ✅ Business Hubs Script: 13,200 bytes
   ✅ Business Links Script: 26,500 bytes
   ✅ Business Satellites Script: 41,800 bytes
   ✅ API Layer Script: 21,400 bytes

📊 Deployment Readiness Analysis
==================================================
✅ Overall Status: READY

📈 Test Summary:
   Total tests run: 18
   Tests passed: 16
   Tests failed: 2
   Success rate: 88.9%

⚠️ Warnings:
   ⚠️ Schema 'raw' does not exist
   ⚠️ Schema 'staging' does not exist

============================================================
✅ Test suite completed successfully!
🔍 Overall status: READY

🔒 Database connection closed

🎉 Database testing completed successfully!
✅ Database is READY for site tracking deployment!
```

## Troubleshooting

### Common Issues

#### "Database connection failed"
- Verify PostgreSQL is running
- Check host, port, database name in `testingDBConfig.py`
- Verify user has proper permissions
- Ensure password is correct

#### "Critical prerequisite missing"
- Auth system may not be deployed
- Util functions may be missing
- Run auth system deployment first

#### "Script validation failed"
- Check file paths in `testingDBConfig.py`
- Ensure all 6 SQL scripts exist in the directory
- Verify file encoding (should be UTF-8)

### Manual Fixes

If the test reports **NOT_READY**:

1. **Deploy Auth System First**:
   ```sql
   -- Run auth system migrations first
   \\i ../organized_migrations/03_auth_system/*.sql
   ```

2. **Deploy Util Functions**:
   ```sql
   -- Ensure util schema and functions exist
   \\i ../organized_migrations/06_functions_procedures/util_*.sql
   ```

3. **Resolve Conflicts**:
   - Review conflicting objects reported by the script
   - Backup existing objects if needed
   - Consider renaming conflicts before deployment

## Next Steps

### If Status is **READY** ✅
```bash
# Deploy site tracking scripts
python testingDB-siteTracking.py
# If READY, run deployment:
psql -U postgres -d one_vault -f DEPLOY_ALL.sql
```

### If Status is **CAUTION** ⚠️
1. Review warnings in test output
2. Address any critical issues
3. Run deployment with caution
4. Monitor for issues during deployment

### If Status is **NOT_READY** ❌
1. Address all critical issues first
2. Deploy missing prerequisites
3. Re-run test until status improves
4. Do NOT attempt deployment until READY or CAUTION

## Configuration Customization

Edit `testingDBConfig.py` to customize:
- Database connection parameters
- Add additional validation queries
- Modify script paths if different
- Add custom prerequisite checks
- Adjust conflict detection rules

This testing framework ensures safe, validated deployment of site tracking functionality into your existing One Vault database. 