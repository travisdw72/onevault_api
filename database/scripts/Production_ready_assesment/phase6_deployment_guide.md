# Phase 6 Deployment Guide: Security Hardening & Compliance Automation
## Multi-Tenant Data Vault 2.0 SaaS Platform - Production Ready

### Overview
Phase 6 implements advanced security hardening infrastructure and automated compliance management for enterprise-grade security posture and regulatory compliance automation.

---

## 🎯 **PHASE 6 COMPONENTS**

### Step 11: Security Hardening Infrastructure
- **Advanced threat detection and response**
- **Security policy management and enforcement**
- **Vulnerability management with CVSS scoring**
- **Security incident response automation**
- **Comprehensive security audit trail**

### Step 12: Compliance Automation System
- **Automated compliance rule evaluation**
- **Multi-framework compliance assessment (HIPAA, GDPR, SOX, PCI DSS, SOC2)**
- **Automated compliance reporting**
- **Remediation workflow management**
- **Real-time compliance monitoring**

---

## 📋 **PRE-DEPLOYMENT CHECKLIST**

### Prerequisites
- [ ] Phase 1-5 successfully deployed and operational
- [ ] PostgreSQL 13+ with required extensions
- [ ] Monitoring and alerting system active
- [ ] Backup and recovery system operational
- [ ] Performance optimization implemented

### Required Permissions
```sql
-- Verify required database permissions
SELECT 
    has_schema_privilege('security_hardening', 'CREATE') as security_schema_create,
    has_schema_privilege('compliance_automation', 'CREATE') as compliance_schema_create,
    has_function_privilege('util.hash_binary(text)', 'EXECUTE') as hash_function_access;
```

### System Requirements
- **CPU**: 8+ cores recommended for security processing
- **Memory**: 32GB+ RAM for threat analysis
- **Storage**: 500GB+ for security logs and compliance data
- **Network**: Secure network configuration with IDS/IPS

---

## 🚀 **DEPLOYMENT STEPS**

### Step 1: Deploy Security Hardening Infrastructure

```bash
# 1. Execute security hardening schema creation
psql -d one_vault -f step_11_security_hardening.sql

# 2. Verify schema creation
psql -d one_vault -c "
SELECT schemaname, tablename, tableowner 
FROM pg_tables 
WHERE schemaname = 'security_hardening' 
ORDER BY tablename;"

# 3. Check table structure
psql -d one_vault -c "
SELECT 
    t.table_name,
    COUNT(c.column_name) as column_count,
    COUNT(CASE WHEN c.is_nullable = 'NO' THEN 1 END) as required_columns
FROM information_schema.tables t
LEFT JOIN information_schema.columns c ON t.table_name = c.table_name
WHERE t.table_schema = 'security_hardening'
GROUP BY t.table_name
ORDER BY t.table_name;"
```

### Step 2: Deploy Compliance Automation System

```bash
# 1. Execute compliance automation schema creation
psql -d one_vault -f step_12_compliance_automation.sql

# 2. Verify schema creation
psql -d one_vault -c "
SELECT schemaname, tablename, tableowner 
FROM pg_tables 
WHERE schemaname = 'compliance_automation' 
ORDER BY tablename;"

# 3. Verify indexes creation
psql -d one_vault -c "
SELECT 
    schemaname, 
    tablename, 
    indexname, 
    indexdef 
FROM pg_indexes 
WHERE schemaname IN ('security_hardening', 'compliance_automation')
ORDER BY schemaname, tablename, indexname;"
```

### Step 3: Configure Security Policies

```sql
-- Create default security policies for tenant
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_policy_hk BYTEA;
BEGIN
    -- Get tenant hash key (replace with actual tenant)
    SELECT tenant_hk INTO v_tenant_hk 
    FROM auth.tenant_h 
    WHERE tenant_bk = 'DEFAULT_TENANT' 
    LIMIT 1;
    
    IF v_tenant_hk IS NOT NULL THEN
        -- Create password policy
        SELECT security_hardening.create_security_policy(
            v_tenant_hk,
            'Strong Password Policy',
            'AUTHENTICATION',
            'PREVENTIVE',
            '{"min_length": 12, "require_uppercase": true, "require_lowercase": true, "require_numbers": true, "require_special": true}'::jsonb,
            'STRICT'
        ) INTO v_policy_hk;
        
        RAISE NOTICE 'Created password policy: %', encode(v_policy_hk, 'hex');
        
        -- Create access control policy
        SELECT security_hardening.create_security_policy(
            v_tenant_hk,
            'Multi-Factor Authentication',
            'ACCESS_CONTROL',
            'PREVENTIVE',
            '{"require_mfa": true, "mfa_methods": ["TOTP", "SMS"], "grace_period_hours": 24}'::jsonb,
            'STRICT'
        ) INTO v_policy_hk;
        
        RAISE NOTICE 'Created MFA policy: %', encode(v_policy_hk, 'hex');
    END IF;
END $$;
```

### Step 4: Configure Compliance Rules

```sql
-- Create default compliance rules
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_rule_hk BYTEA;
BEGIN
    -- Get tenant hash key
    SELECT tenant_hk INTO v_tenant_hk 
    FROM auth.tenant_h 
    WHERE tenant_bk = 'DEFAULT_TENANT' 
    LIMIT 1;
    
    IF v_tenant_hk IS NOT NULL THEN
        -- Create HIPAA compliance rule
        SELECT compliance_automation.create_compliance_rule(
            v_tenant_hk,
            'HIPAA Access Control Audit',
            'HIPAA',
            '164.312(a)(1)',
            'SELECT COUNT(*) FROM auth.user_auth_s WHERE password_last_changed < CURRENT_DATE - INTERVAL ''90 days''',
            'HIGH'
        ) INTO v_rule_hk;
        
        RAISE NOTICE 'Created HIPAA rule: %', encode(v_rule_hk, 'hex');
        
        -- Create GDPR compliance rule
        SELECT compliance_automation.create_compliance_rule(
            v_tenant_hk,
            'GDPR Data Retention Check',
            'GDPR',
            'Art. 5(1)(e)',
            'SELECT COUNT(*) FROM business.customer_profile_s WHERE load_date < CURRENT_DATE - INTERVAL ''7 years''',
            'CRITICAL'
        ) INTO v_rule_hk;
        
        RAISE NOTICE 'Created GDPR rule: %', encode(v_rule_hk, 'hex');
    END IF;
END $$;
```

---

## ✅ **VERIFICATION PROCEDURES**

### 1. Security Infrastructure Verification

```sql
-- Verify security hardening tables
SELECT 
    'Security Tables' as component,
    COUNT(*) as table_count,
    COUNT(*) FILTER (WHERE table_type = 'BASE TABLE') as base_tables
FROM information_schema.tables 
WHERE table_schema = 'security_hardening';

-- Verify security functions
SELECT 
    'Security Functions' as component,
    COUNT(*) as function_count
FROM information_schema.routines 
WHERE routine_schema = 'security_hardening';

-- Test threat detection logging
SELECT security_hardening.log_threat_detection(
    (SELECT tenant_hk FROM auth.tenant_h LIMIT 1),
    'BRUTE_FORCE',
    'HIGH',
    '192.168.1.100',
    '{"failed_attempts": 5, "time_window": "5 minutes"}'::jsonb
) as threat_detection_test;
```

### 2. Compliance Automation Verification

```sql
-- Verify compliance automation tables
SELECT 
    'Compliance Tables' as component,
    COUNT(*) as table_count,
    COUNT(*) FILTER (WHERE table_type = 'BASE TABLE') as base_tables
FROM information_schema.tables 
WHERE table_schema = 'compliance_automation';

-- Test compliance assessment
SELECT * FROM compliance_automation.run_compliance_assessment(
    (SELECT tenant_hk FROM auth.tenant_h LIMIT 1),
    'HIPAA'
) LIMIT 5;

-- Verify compliance dashboard
SELECT * FROM compliance_automation.compliance_dashboard;
```

### 3. Performance Verification

```sql
-- Check index usage for security tables
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE schemaname IN ('security_hardening', 'compliance_automation')
ORDER BY idx_scan DESC;

-- Monitor query performance
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
WHERE query LIKE '%security_hardening%' 
   OR query LIKE '%compliance_automation%'
ORDER BY total_time DESC
LIMIT 10;
```

---

## 🔧 **CONFIGURATION**

### Security Configuration

```sql
-- Configure security monitoring intervals
UPDATE security_hardening.security_policy_s 
SET next_review_date = CURRENT_DATE + INTERVAL '30 days'
WHERE load_end_date IS NULL;

-- Configure threat detection sensitivity
UPDATE security_hardening.threat_detection_s 
SET confidence_score = 90.0
WHERE threat_type = 'BRUTE_FORCE' 
AND load_end_date IS NULL;
```

### Compliance Configuration

```sql
-- Configure compliance evaluation frequency
UPDATE compliance_automation.compliance_rule_s 
SET evaluation_frequency = '1 day'::INTERVAL,
    next_evaluation = CURRENT_TIMESTAMP + INTERVAL '1 day'
WHERE compliance_framework IN ('HIPAA', 'GDPR')
AND load_end_date IS NULL;

-- Configure notification recipients
UPDATE compliance_automation.compliance_rule_s 
SET notification_recipients = ARRAY[
    'security@onevault.com',
    'compliance@onevault.com',
    'admin@onevault.com'
]
WHERE severity_level IN ('HIGH', 'CRITICAL')
AND load_end_date IS NULL;
```

---

## 🔄 **AUTOMATION SETUP**

### 1. Security Monitoring Automation

```bash
# Create security monitoring cron job
cat > /etc/cron.d/security-monitoring << 'EOF'
# Security threat detection - every 5 minutes
*/5 * * * * postgres psql -d one_vault -c "SELECT security_hardening.log_threat_detection((SELECT tenant_hk FROM auth.tenant_h LIMIT 1), 'SYSTEM_SCAN', 'LOW', 'SYSTEM', '{\"scan_type\": \"automated\"}'::jsonb);" > /dev/null 2>&1

# Security audit cleanup - daily at 2 AM
0 2 * * * postgres psql -d one_vault -c "DELETE FROM security_hardening.security_audit_s WHERE audit_timestamp < CURRENT_TIMESTAMP - INTERVAL '1 year' AND load_end_date IS NOT NULL;" > /dev/null 2>&1
EOF

# Enable cron service
systemctl enable cron
systemctl start cron
```

### 2. Compliance Assessment Automation

```bash
# Create compliance assessment cron job
cat > /etc/cron.d/compliance-automation << 'EOF'
# Daily compliance assessment - 3 AM
0 3 * * * postgres psql -d one_vault -c "SELECT compliance_automation.run_compliance_assessment();" > /dev/null 2>&1

# Weekly compliance report generation - Sunday 4 AM
0 4 * * 0 postgres psql -d one_vault -c "SELECT compliance_automation.generate_compliance_report((SELECT tenant_hk FROM auth.tenant_h LIMIT 1), 'HIPAA', 'WEEKLY');" > /dev/null 2>&1

# Monthly compliance report generation - 1st of month 5 AM
0 5 1 * * postgres psql -d one_vault -c "SELECT compliance_automation.generate_compliance_report((SELECT tenant_hk FROM auth.tenant_h LIMIT 1), 'GDPR', 'MONTHLY');" > /dev/null 2>&1
EOF
```

### 3. Systemd Service Configuration

```bash
# Create security monitoring service
cat > /etc/systemd/system/security-monitoring.service << 'EOF'
[Unit]
Description=One Vault Security Monitoring Service
After=postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=postgres
ExecStart=/usr/bin/psql -d one_vault -c "SELECT security_hardening.log_threat_detection((SELECT tenant_hk FROM auth.tenant_h LIMIT 1), 'SERVICE_START', 'LOW', 'SYSTEM', '{\"event\": \"service_startup\"}'::jsonb);"
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable security-monitoring.service
systemctl start security-monitoring.service
```

---

## 📊 **MONITORING & ALERTING**

### Security Monitoring Queries

```sql
-- Monitor security threats in real-time
CREATE VIEW security_hardening.active_threats AS
SELECT 
    td.threat_type,
    td.threat_severity,
    td.threat_source,
    td.detection_timestamp,
    td.investigation_status,
    td.confidence_score
FROM security_hardening.threat_detection_s td
JOIN security_hardening.threat_detection_h th ON td.threat_detection_hk = th.threat_detection_hk
WHERE td.detection_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
AND td.investigation_status IN ('PENDING', 'INVESTIGATING')
AND td.load_end_date IS NULL
ORDER BY td.detection_timestamp DESC;

-- Monitor compliance violations
CREATE VIEW compliance_automation.active_violations AS
SELECT 
    cr.rule_name,
    ca.assessment_result,
    ca.compliance_score,
    ca.risk_level,
    ca.assessment_timestamp,
    ca.remediation_required
FROM compliance_automation.compliance_assessment_s ca
JOIN compliance_automation.compliance_assessment_h cah ON ca.assessment_hk = cah.assessment_hk
JOIN compliance_automation.compliance_rule_s cr ON ca.compliance_rule_hk = cr.compliance_rule_hk
WHERE ca.assessment_result = 'NON_COMPLIANT'
AND ca.assessment_timestamp >= CURRENT_DATE - INTERVAL '7 days'
AND ca.load_end_date IS NULL
AND cr.load_end_date IS NULL
ORDER BY ca.risk_level DESC, ca.assessment_timestamp DESC;
```

### Alert Configuration

```sql
-- Configure security alerts
INSERT INTO monitoring.alert_definition_s (
    alert_definition_hk, load_date, hash_diff,
    alert_name, alert_description, alert_type, severity_level,
    condition_sql, threshold_value, evaluation_frequency,
    notification_channels, is_active, record_source
) VALUES (
    util.hash_binary('SECURITY_CRITICAL_THREAT'),
    util.current_load_date(),
    util.hash_binary('SECURITY_CRITICAL_THREAT_ALERT'),
    'Critical Security Threat Detected',
    'Alert when critical security threats are detected',
    'SECURITY', 'CRITICAL',
    'SELECT COUNT(*) FROM security_hardening.threat_detection_s WHERE threat_severity = ''CRITICAL'' AND detection_timestamp >= CURRENT_TIMESTAMP - INTERVAL ''5 minutes'' AND load_end_date IS NULL',
    0, '5 minutes',
    ARRAY['EMAIL', 'SLACK', 'PAGERDUTY'], true,
    'SECURITY_ALERT_SYSTEM'
);

-- Configure compliance alerts
INSERT INTO monitoring.alert_definition_s (
    alert_definition_hk, load_date, hash_diff,
    alert_name, alert_description, alert_type, severity_level,
    condition_sql, threshold_value, evaluation_frequency,
    notification_channels, is_active, record_source
) VALUES (
    util.hash_binary('COMPLIANCE_VIOLATION'),
    util.current_load_date(),
    util.hash_binary('COMPLIANCE_VIOLATION_ALERT'),
    'Compliance Violation Detected',
    'Alert when compliance violations are detected',
    'COMPLIANCE', 'HIGH',
    'SELECT COUNT(*) FROM compliance_automation.compliance_assessment_s WHERE assessment_result = ''NON_COMPLIANT'' AND risk_level IN (''HIGH'', ''CRITICAL'') AND assessment_timestamp >= CURRENT_TIMESTAMP - INTERVAL ''1 hour'' AND load_end_date IS NULL',
    0, '1 hour',
    ARRAY['EMAIL', 'SLACK'], true,
    'COMPLIANCE_ALERT_SYSTEM'
);
```

---

## 🧪 **TESTING PROCEDURES**

### 1. Security Testing

```sql
-- Test threat detection
DO $$
DECLARE
    v_threat_hk BYTEA;
BEGIN
    -- Simulate brute force attack
    SELECT security_hardening.log_threat_detection(
        (SELECT tenant_hk FROM auth.tenant_h LIMIT 1),
        'BRUTE_FORCE',
        'CRITICAL',
        '192.168.1.100',
        '{"failed_attempts": 10, "time_window": "2 minutes", "target_user": "admin"}'::jsonb
    ) INTO v_threat_hk;
    
    RAISE NOTICE 'Test threat logged: %', encode(v_threat_hk, 'hex');
    
    -- Verify threat was logged
    IF EXISTS (
        SELECT 1 FROM security_hardening.threat_detection_s 
        WHERE threat_detection_hk = v_threat_hk
    ) THEN
        RAISE NOTICE 'Threat detection test: PASSED';
    ELSE
        RAISE EXCEPTION 'Threat detection test: FAILED';
    END IF;
END $$;
```

### 2. Compliance Testing

```sql
-- Test compliance assessment
DO $$
DECLARE
    v_assessment_results RECORD;
    v_test_passed BOOLEAN := true;
BEGIN
    -- Run compliance assessment
    FOR v_assessment_results IN 
        SELECT * FROM compliance_automation.run_compliance_assessment(
            (SELECT tenant_hk FROM auth.tenant_h LIMIT 1),
            'HIPAA'
        )
    LOOP
        RAISE NOTICE 'Assessment: % - Result: % - Score: %', 
                     v_assessment_results.rule_name,
                     v_assessment_results.assessment_result,
                     v_assessment_results.compliance_score;
        
        IF v_assessment_results.compliance_score IS NULL THEN
            v_test_passed := false;
        END IF;
    END LOOP;
    
    IF v_test_passed THEN
        RAISE NOTICE 'Compliance assessment test: PASSED';
    ELSE
        RAISE EXCEPTION 'Compliance assessment test: FAILED';
    END IF;
END $$;
```

### 3. Performance Testing

```bash
# Test security query performance
psql -d one_vault -c "
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM security_hardening.security_dashboard;
"

# Test compliance query performance
psql -d one_vault -c "
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM compliance_automation.compliance_dashboard;
"

# Load test with concurrent security events
for i in {1..100}; do
    psql -d one_vault -c "
    SELECT security_hardening.log_security_audit(
        (SELECT tenant_hk FROM auth.tenant_h LIMIT 1),
        'LOGIN',
        'test_user_$i',
        '/api/auth/login',
        'LOGIN',
        'SUCCESS',
        '192.168.1.$((i % 255 + 1))'::inet
    );" &
done
wait
```

---

## 🚨 **TROUBLESHOOTING**

### Common Issues

#### 1. Security Function Errors
```sql
-- Check function permissions
SELECT 
    routine_name,
    routine_type,
    security_type,
    security_definer
FROM information_schema.routines 
WHERE routine_schema = 'security_hardening';

-- Fix permission issues
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA security_hardening TO postgres;
```

#### 2. Compliance Assessment Failures
```sql
-- Check compliance rule syntax
SELECT 
    rule_name,
    rule_logic,
    LENGTH(rule_logic) as logic_length
FROM compliance_automation.compliance_rule_s 
WHERE is_active = true 
AND load_end_date IS NULL;

-- Test rule logic manually
-- (Replace with actual rule logic)
SELECT COUNT(*) FROM auth.user_auth_s 
WHERE password_last_changed < CURRENT_DATE - INTERVAL '90 days';
```

#### 3. Performance Issues
```sql
-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read
FROM pg_stat_user_indexes 
WHERE schemaname IN ('security_hardening', 'compliance_automation')
AND idx_scan = 0;

-- Analyze table statistics
ANALYZE security_hardening.threat_detection_s;
ANALYZE compliance_automation.compliance_assessment_s;
```

---

## 📈 **SUCCESS METRICS**

### Security Metrics
- **Threat Detection Rate**: > 95% of security events detected
- **False Positive Rate**: < 5% of threat detections
- **Incident Response Time**: < 15 minutes for critical threats
- **Security Policy Compliance**: > 98% adherence

### Compliance Metrics
- **Overall Compliance Score**: > 95% across all frameworks
- **Assessment Frequency**: 100% of rules evaluated on schedule
- **Remediation Time**: < 30 days for high-risk violations
- **Report Generation**: 100% automated report delivery

### Performance Metrics
- **Security Query Response**: < 200ms average
- **Compliance Assessment Time**: < 5 minutes per framework
- **Dashboard Load Time**: < 2 seconds
- **System Resource Usage**: < 10% CPU overhead

---

## 🎉 **DEPLOYMENT COMPLETION**

### Final Verification Checklist
- [ ] All security hardening tables created and indexed
- [ ] All compliance automation tables created and indexed
- [ ] Security policies configured and active
- [ ] Compliance rules configured and scheduled
- [ ] Monitoring and alerting configured
- [ ] Automation services running
- [ ] Performance metrics within acceptable ranges
- [ ] Security testing completed successfully
- [ ] Compliance testing completed successfully
- [ ] Documentation updated

### Next Steps
1. **Monitor security dashboard** for threat detection
2. **Review compliance reports** for regulatory adherence
3. **Configure additional security policies** as needed
4. **Set up integration** with external security tools
5. **Train security team** on new capabilities
6. **Schedule regular security assessments**
7. **Plan compliance audit preparation**

---

## 📞 **SUPPORT**

For deployment issues or questions:
- **Technical Support**: tech-support@onevault.com
- **Security Team**: security@onevault.com
- **Compliance Team**: compliance@onevault.com
- **Documentation**: https://docs.onevault.com/phase6-deployment

**Phase 6 deployment provides enterprise-grade security hardening and automated compliance management, completing the production-ready infrastructure for the One Vault Multi-Tenant Data Vault 2.0 Platform.** 