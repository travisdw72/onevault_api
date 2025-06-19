# 📋 **V001 Site Tracking Raw Layer - Deployment Checklist**

## **🎯 DEPLOYMENT INFORMATION**
- **Migration Version:** V001  
- **Feature:** Universal Site Tracking Raw Layer
- **Estimated Deployment Time:** 2-5 minutes
- **Risk Level:** LOW (new feature, no existing dependencies)
- **Rollback Time:** 1-2 minutes

---

## **🔍 PRE-DEPLOYMENT CHECKS**

### **Environment Validation**
- [ ] **Database Environment Confirmed**
  - [ ] DEV/TEST/STAGING/PRODUCTION environment verified
  - [ ] Correct database server and instance
  - [ ] Database backup completed (if production)
  - [ ] Maintenance window scheduled (if production)

### **Prerequisites Verification**
- [ ] **PostgreSQL Version**
  - [ ] PostgreSQL 12+ confirmed
  - [ ] JSONB support available
  - [ ] Required extensions installed

- [ ] **Database Permissions**
  - [ ] Schema creation permissions
  - [ ] Table creation permissions  
  - [ ] Function creation permissions
  - [ ] Index creation permissions

- [ ] **Dependencies Check**
  - [ ] `auth.tenant_h` table exists (optional for development)
  - [ ] `util.hash_binary` function exists (optional for development)
  - [ ] `util.log_audit_event` function exists (optional for development)

### **Migration Files Ready**
- [ ] **Required Files Present**
  - [ ] `V001__create_site_tracking_raw_layer.sql` - Main migration
  - [ ] `V001__rollback_site_tracking_raw_layer.sql` - Rollback script
  - [ ] `test_site_tracking_deployment.py` - Automated tests
  - [ ] `deployment_checklist.md` - This checklist

- [ ] **File Integrity**
  - [ ] SQL syntax validated
  - [ ] Rollback script tested in development
  - [ ] Test script configured with correct connection parameters

---

## **🚀 DEPLOYMENT EXECUTION**

### **Step 1: Pre-Migration Snapshot**
```sql
-- Document current state
SELECT 
    'PRE_MIGRATION' as phase,
    COUNT(*) as table_count 
FROM information_schema.tables 
WHERE table_schema = 'raw';

SELECT 
    'PRE_MIGRATION' as phase,
    COUNT(*) as function_count 
FROM information_schema.routines 
WHERE routine_schema = 'raw';
```
- [ ] **Current state documented**
- [ ] **Baseline metrics captured**

### **Step 2: Execute Migration**
```sql
-- Run the migration script
\i V001__create_site_tracking_raw_layer.sql
```
- [ ] **Migration script executed successfully**
- [ ] **No error messages in output**
- [ ] **Success messages confirmed**

### **Step 3: Post-Migration Validation**
```sql
-- Verify objects created
SELECT 'raw' as schema_name, COUNT(*) as tables_created
FROM information_schema.tables 
WHERE table_schema = 'raw';

SELECT 'raw' as schema_name, COUNT(*) as functions_created
FROM information_schema.routines 
WHERE routine_schema = 'raw';

-- Test basic functionality
SELECT 'site_tracking_events_r' as table_name, 
       COUNT(*) as column_count
FROM information_schema.columns
WHERE table_schema = 'raw' AND table_name = 'site_tracking_events_r';
```
- [ ] **Schema `raw` created**
- [ ] **Table `site_tracking_events_r` created**
- [ ] **Function `ingest_tracking_event` created**
- [ ] **Indexes created successfully**

### **Step 4: Automated Testing**
```bash
# Run automated test suite
python test_site_tracking_deployment.py
```
- [ ] **All automated tests passed**
- [ ] **Test results file generated**
- [ ] **No critical errors in test output**

---

## **🧪 FUNCTIONAL TESTING**

### **Data Operations Test**
```sql
-- Test data insertion (replace with real tenant_hk if available)
DO $$
DECLARE
    test_tenant_hk BYTEA := '\x1234567890abcdef';
    event_id INTEGER;
BEGIN
    -- Insert test event
    INSERT INTO raw.site_tracking_events_r (
        tenant_hk, raw_payload, record_source
    ) VALUES (
        test_tenant_hk,
        '{"evt_type": "test", "page_url": "/test"}',
        'deployment_test'
    ) RETURNING raw_event_id INTO event_id;
    
    RAISE NOTICE 'Test event inserted with ID: %', event_id;
END $$;
```
- [ ] **Test data insertion successful**
- [ ] **Data retrieval working**
- [ ] **Constraints functioning correctly**

### **Function Testing** (if dependencies available)
```sql
-- Test ingestion function (only if util functions available)
SELECT raw.ingest_tracking_event(
    '\x1234567890abcdef'::bytea,
    NULL,
    '192.168.1.100'::inet,
    'Test User Agent',
    '{"evt_type": "page_view", "page_url": "/test"}'::jsonb
);
```
- [ ] **Function execution successful** (or marked N/A if dependencies missing)
- [ ] **Return value valid**
- [ ] **No exceptions thrown**

---

## **🛡️ SECURITY VALIDATION**

### **Permissions Check**
```sql
-- Verify object ownership and permissions
SELECT 
    table_schema, table_name, table_owner
FROM information_schema.tables 
WHERE table_schema = 'raw';

-- Check role permissions (if roles exist)
SELECT 
    grantee, privilege_type 
FROM information_schema.table_privileges 
WHERE table_schema = 'raw' AND table_name = 'site_tracking_events_r';
```
- [ ] **Correct object ownership**
- [ ] **Appropriate permissions granted**
- [ ] **No unauthorized access possible**

### **Data Security**
- [ ] **Tenant isolation enforced** (tenant_hk required)
- [ ] **Input validation working** (constraints active)
- [ ] **Audit logging enabled** (if util.log_audit_event available)

---

## **⚡ PERFORMANCE VALIDATION**

### **Index Effectiveness**
```sql
-- Check index creation
SELECT 
    schemaname, tablename, indexname, indexdef
FROM pg_indexes 
WHERE schemaname = 'raw' AND tablename = 'site_tracking_events_r';

-- Test query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT COUNT(*) 
FROM raw.site_tracking_events_r 
WHERE processing_status = 'PENDING';
```
- [ ] **All expected indexes created**
- [ ] **Query execution plans optimal**
- [ ] **No performance red flags**

---

## **🔄 ROLLBACK READINESS**

### **Rollback Preparation**
- [ ] **Rollback script syntax validated**
- [ ] **Rollback dependencies checked**
- [ ] **Data backup confirmed** (if production data exists)

### **Rollback Test** (Development Only)
```sql
-- Test rollback script (ONLY in development environment)
\i V001__rollback_site_tracking_raw_layer.sql
```
- [ ] **Rollback script tested in development** ✅
- [ ] **Clean rollback confirmed** ✅
- [ ] **Re-deployment after rollback successful** ✅

---

## **📊 MONITORING SETUP**

### **Deployment Metrics**
- [ ] **Migration logged in migration_log table**
- [ ] **Deployment metrics captured**
- [ ] **Monitoring alerts configured**

### **Operational Readiness**
- [ ] **Health check queries defined**
- [ ] **Alert thresholds set**
- [ ] **Documentation updated**

---

## **✅ DEPLOYMENT SIGN-OFF**

### **Technical Validation**
- [ ] All migration objects created successfully
- [ ] Automated tests passed
- [ ] Manual functional tests completed
- [ ] Performance validation passed
- [ ] Security validation passed
- [ ] Rollback readiness confirmed

### **Approvals**
- [ ] **Database Administrator:** _________________________ Date: _________
- [ ] **Development Lead:** _________________________ Date: _________  
- [ ] **DevOps Engineer:** _________________________ Date: _________ (if production)

---

## **🚨 EMERGENCY PROCEDURES**

### **If Deployment Fails**
1. **Stop deployment immediately**
2. **Run rollback script:** `\i V001__rollback_site_tracking_raw_layer.sql`
3. **Verify rollback success**
4. **Document failure reason**
5. **Schedule remediation**

### **Emergency Contacts**
- **Database Team:** [Contact Information]
- **Development Team:** [Contact Information]
- **On-Call Engineer:** [Contact Information]

---

## **📝 POST-DEPLOYMENT TASKS**

### **Documentation Updates**
- [ ] **Deployment log updated**
- [ ] **Architecture documentation updated**
- [ ] **Monitoring dashboards updated**
- [ ] **Team notifications sent**

### **Cleanup Tasks**
- [ ] **Test data removed** (if appropriate)
- [ ] **Temporary files cleaned up**
- [ ] **Development environment synchronized**

---

## **🎉 DEPLOYMENT COMPLETE**

**Migration V001 - Universal Site Tracking Raw Layer**
- **Status:** ✅ SUCCESSFUL  
- **Deployed By:** _________________________
- **Deployment Date:** _____________________
- **Notes:** ________________________________

**The foundation for Universal Site Tracking is now in place!** 🚀 