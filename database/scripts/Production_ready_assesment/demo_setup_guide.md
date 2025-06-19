# Demo Setup Guide - Localhost
## Quick Production Demo Preparation

### Pre-Demo Checklist (30 minutes)

#### 1. Database Setup ✅
```bash
# Start PostgreSQL
brew services start postgresql
# or
sudo systemctl start postgresql

# Verify connection
psql -d one_vault -c "SELECT version();"
```

#### 2. Load Demo Data 🎯
```sql
-- Connect to database
psql -d one_vault

-- Verify all production schemas exist
\dn+

-- Quick data check
SELECT 
    schemaname,
    tablename,
    n_tup_ins as "Rows Inserted"
FROM pg_stat_user_tables 
WHERE schemaname IN ('auth', 'business', 'backup_mgmt', 'monitoring')
ORDER BY schemaname, tablename;
```

#### 3. Demo Data Population 📊
```sql
-- Sample tenant data for demo
INSERT INTO auth.tenant_h (tenant_hk, tenant_bk, load_date, record_source)
VALUES (
    util.hash_binary('DEMO_TENANT_001'),
    'DEMO_TENANT_001',
    util.current_load_date(),
    'DEMO_SETUP'
);

-- Sample monitoring metrics
SELECT monitoring.collect_system_metrics(util.hash_binary('DEMO_TENANT_001'));

-- Sample backup execution  
CALL backup_mgmt.execute_backup('INCREMENTAL', util.hash_binary('DEMO_TENANT_001'));
```

#### 4. Demo Highlights to Show 🎪

##### **A. Multi-Tenant Data Vault 2.0**
- Show tenant isolation: `SELECT * FROM auth.tenant_h;`
- Demonstrate temporal tracking: `SELECT * FROM auth.user_profile_s WHERE load_end_date IS NULL;`
- Hash key system: `SELECT encode(tenant_hk, 'hex') FROM auth.tenant_h;`

##### **B. Production Backup System**
- Live backup: `CALL backup_mgmt.execute_backup('FULL');`
- Recovery options: `SELECT * FROM backup_mgmt.backup_execution_s;`
- Retention policies: Show 7-year compliance retention

##### **C. Real-Time Monitoring**
- System metrics: `SELECT * FROM monitoring.system_health_s ORDER BY measurement_timestamp DESC LIMIT 10;`
- Alert definitions: `SELECT * FROM monitoring.alert_definition_s WHERE is_active = true;`
- Performance tracking: `SELECT * FROM monitoring.performance_metric_s ORDER BY load_date DESC LIMIT 5;`

##### **D. HIPAA/GDPR Compliance**
- Audit trails: `SELECT * FROM audit.audit_detail_s ORDER BY load_date DESC LIMIT 10;`
- Data classification: Show tenant isolation and encryption
- Compliance metrics: `SELECT * FROM monitoring.compliance_metric_s;`

#### 5. Performance Demo 🚀
```sql
-- Show query performance
EXPLAIN ANALYZE SELECT 
    up.first_name,
    up.last_name,
    uas.last_login_date
FROM auth.user_profile_s up
JOIN auth.user_h uh ON up.user_hk = uh.user_hk  
JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
WHERE up.load_end_date IS NULL
AND uas.load_end_date IS NULL;

-- Show indexing effectiveness
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as "Index Uses"
FROM pg_stat_user_indexes 
WHERE idx_scan > 0
ORDER BY idx_scan DESC;
```

### Demo Flow Suggestion 📋

#### **Opening (5 minutes)**
1. **Platform Overview**: "Multi-tenant SaaS with Data Vault 2.0 architecture"
2. **Compliance Ready**: "HIPAA, GDPR, IRS compliant from day one"
3. **Production Infrastructure**: "Enterprise backup, monitoring, alerting systems"

#### **Technical Deep Dive (15 minutes)**
1. **Data Architecture**: Show Data Vault 2.0 structure and tenant isolation
2. **Backup & Recovery**: Demonstrate live backup and recovery capabilities  
3. **Real-time Monitoring**: Show system health and performance metrics
4. **Security & Compliance**: Demonstrate audit trails and data protection

#### **Business Value (10 minutes)**
1. **Scalability**: "Handles unlimited tenants with complete isolation"
2. **Reliability**: "Enterprise-grade backup and monitoring systems"
3. **Compliance**: "Built-in HIPAA/GDPR compliance reduces risk"
4. **Performance**: "Optimized for high-volume business operations"

### Troubleshooting Quick Fixes 🔧

```bash
# If PostgreSQL isn't responding
sudo systemctl restart postgresql

# If demo data is missing
psql -d one_vault -f database/scripts/Production_ready_assesment/step_3_monitoring_infrastructure.sql

# Clear and reload monitoring data
DELETE FROM monitoring.system_health_s WHERE measurement_timestamp < CURRENT_TIMESTAMP - INTERVAL '1 hour';
SELECT monitoring.collect_system_metrics();
```

### Demo URLs & Access 🌐
- **Database**: `localhost:5432/one_vault`
- **API** (when ready): `http://localhost:3000/api/v1`
- **Frontend** (when ready): `http://localhost:5173`

### Key Talking Points 💡
- **"Production Ready"**: Complete backup, monitoring, alerting infrastructure
- **"Enterprise Architecture"**: Data Vault 2.0 with full temporal tracking
- **"Compliance Built-in"**: HIPAA, GDPR, IRS ready from day one
- **"Infinite Scale"**: Multi-tenant with complete isolation
- **"Business Focused"**: Multi-entity optimization platform

**Good luck with your demo! 🚀** 