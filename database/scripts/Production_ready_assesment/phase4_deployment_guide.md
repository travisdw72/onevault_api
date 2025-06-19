# Phase 4 Deployment Guide: Database Locks & Blocking Analysis
## One Vault Multi-Tenant Data Vault 2.0 Platform

### Overview
Phase 4 implements comprehensive database lock monitoring and blocking analysis infrastructure to prevent production performance issues through real-time detection, analysis, and automated resolution of lock contention and deadlocks.

---

## 🎯 **DEPLOYMENT OBJECTIVES**

### Primary Goals
- **Real-time Lock Monitoring**: Capture and analyze all database lock activity
- **Blocking Detection**: Identify sessions causing performance bottlenecks
- **Deadlock Analysis**: Detect and prevent deadlock situations
- **Automated Resolution**: Implement safe automatic intervention for critical blocking
- **Performance Analytics**: Provide actionable insights for optimization

### Success Criteria
- ✅ Lock activity captured within 5 seconds of occurrence
- ✅ Blocking sessions detected within 30 seconds
- ✅ Deadlock detection with <10 second response time
- ✅ Automated resolution for critical blocking situations
- ✅ Comprehensive dashboard for lock analysis

---

## 📋 **PRE-DEPLOYMENT CHECKLIST**

### Prerequisites
- [ ] Phase 1 (Backup & Recovery) completed and operational
- [ ] Phase 2 (Monitoring & Alerting) completed and operational
- [ ] Phase 3 (Performance Optimization) completed and operational
- [ ] PostgreSQL 13+ with required extensions
- [ ] Sufficient disk space for lock monitoring data (estimate 1GB/month)
- [ ] Database user with appropriate monitoring permissions

### Required PostgreSQL Configuration
```ini
# postgresql.conf updates for lock monitoring
log_lock_waits = on                 # Log lock waits
deadlock_timeout = 1s               # Deadlock detection timeout
log_statement = 'ddl'               # Log DDL statements that might cause locks
log_min_duration_statement = 1000   # Log slow queries that might hold locks
```

### Database Permissions
```sql
-- Create monitoring roles
CREATE ROLE lock_monitoring_role;
CREATE ROLE lock_admin_role;

-- Grant necessary permissions
GRANT pg_monitor TO lock_monitoring_role;
GRANT EXECUTE ON FUNCTION pg_terminate_backend(integer) TO lock_admin_role;
```

---

## 🚀 **DEPLOYMENT STEPS**

### Step 1: Deploy Lock Monitoring Infrastructure
```bash
# Execute the lock monitoring schema and tables
psql -d one_vault -f step_7_lock_monitoring.sql

# Verify deployment
psql -d one_vault -c "
SELECT schemaname, tablename, tableowner 
FROM pg_tables 
WHERE schemaname = 'lock_monitoring' 
ORDER BY tablename;
"
```

**Expected Output:**
```
 schemaname    |      tablename       | tableowner
---------------+----------------------+------------
 lock_monitoring | blocking_session_h   | postgres
 lock_monitoring | blocking_session_s   | postgres
 lock_monitoring | deadlock_event_h     | postgres
 lock_monitoring | deadlock_event_s     | postgres
 lock_monitoring | deadlock_involvement_l| postgres
 lock_monitoring | lock_activity_h      | postgres
 lock_monitoring | lock_activity_s      | postgres
 lock_monitoring | lock_blocking_l      | postgres
 lock_monitoring | lock_wait_analysis_h | postgres
 lock_monitoring | lock_wait_analysis_s | postgres
(10 rows)
```

### Step 2: Deploy Blocking Detection Functions
```bash
# Execute the blocking detection and analysis functions
psql -d one_vault -f step_8_blocking_detection.sql

# Verify function deployment
psql -d one_vault -c "
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'lock_monitoring' 
ORDER BY routine_name;
"
```

**Expected Output:**
```
      routine_name       | routine_type
-------------------------+--------------
 analyze_lock_waits      | FUNCTION
 auto_resolve_blocking   | FUNCTION
 capture_lock_activity   | FUNCTION
 cleanup_old_data        | FUNCTION
 detect_blocking_sessions| FUNCTION
 detect_deadlocks        | FUNCTION
 run_lock_monitoring     | FUNCTION
(7 rows)
```

### Step 3: Verify Index Creation
```bash
# Check that all performance indexes were created
psql -d one_vault -c "
SELECT schemaname, tablename, indexname, indexdef 
FROM pg_indexes 
WHERE schemaname = 'lock_monitoring' 
ORDER BY tablename, indexname;
"
```

### Step 4: Test Lock Monitoring Functions
```bash
# Test basic lock capture
psql -d one_vault -c "
SELECT * FROM lock_monitoring.capture_lock_activity() LIMIT 1;
"

# Test blocking detection
psql -d one_vault -c "
SELECT * FROM lock_monitoring.detect_blocking_sessions() LIMIT 5;
"

# Test deadlock detection
psql -d one_vault -c "
SELECT * FROM lock_monitoring.detect_deadlocks() LIMIT 1;
"
```

### Step 5: Configure Automated Monitoring
```bash
# Create monitoring automation script
cat > /opt/one_vault/scripts/lock_monitoring.sh << 'EOF'
#!/bin/bash
# Lock monitoring automation script

PGDATABASE="one_vault"
PGUSER="postgres"
LOG_FILE="/var/log/one_vault/lock_monitoring.log"

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Run comprehensive lock monitoring
log_message "Starting lock monitoring cycle"
psql -d "$PGDATABASE" -U "$PGUSER" -c "
SELECT monitoring_summary, locks_captured, blocking_sessions, deadlocks_detected, critical_issues
FROM lock_monitoring.run_lock_monitoring();
" >> "$LOG_FILE" 2>&1

# Check for critical blocking situations
CRITICAL_BLOCKS=$(psql -d "$PGDATABASE" -U "$PGUSER" -t -c "
SELECT COUNT(*) 
FROM lock_monitoring.blocking_sessions_dashboard 
WHERE blocking_severity = 'CRITICAL';
")

if [ "$CRITICAL_BLOCKS" -gt 0 ]; then
    log_message "ALERT: $CRITICAL_BLOCKS critical blocking sessions detected"
    # Add notification logic here
fi

log_message "Lock monitoring cycle completed"
EOF

chmod +x /opt/one_vault/scripts/lock_monitoring.sh
```

### Step 6: Setup Cron Jobs
```bash
# Add cron jobs for automated monitoring
crontab -e

# Add these lines:
# Run lock monitoring every 5 minutes
*/5 * * * * /opt/one_vault/scripts/lock_monitoring.sh

# Run lock wait analysis every hour
0 * * * * psql -d one_vault -c "SELECT * FROM lock_monitoring.analyze_lock_waits();" >> /var/log/one_vault/lock_analysis.log 2>&1

# Cleanup old data daily at 2 AM
0 2 * * * psql -d one_vault -c "SELECT * FROM lock_monitoring.cleanup_old_data(30);" >> /var/log/one_vault/lock_cleanup.log 2>&1
```

---

## 🔍 **VERIFICATION PROCEDURES**

### Functional Testing

#### Test 1: Lock Activity Capture
```sql
-- Create a test scenario with locks
BEGIN;
SELECT * FROM auth.user_h WHERE user_bk = 'test_user' FOR UPDATE;

-- In another session, run lock monitoring
SELECT * FROM lock_monitoring.capture_lock_activity();

-- Verify lock was captured
SELECT lock_type, lock_mode, relation_name, lock_granted, lock_duration_seconds
FROM lock_monitoring.lock_activity_s 
WHERE load_end_date IS NULL 
ORDER BY load_date DESC 
LIMIT 5;

ROLLBACK;
```

#### Test 2: Blocking Detection
```sql
-- Create a blocking scenario
-- Session 1:
BEGIN;
UPDATE auth.user_profile_s SET first_name = 'Test' WHERE user_hk = (SELECT user_hk FROM auth.user_h LIMIT 1);

-- Session 2 (will be blocked):
UPDATE auth.user_profile_s SET last_name = 'Blocked' WHERE user_hk = (SELECT user_hk FROM auth.user_h LIMIT 1);

-- Session 3 (monitoring):
SELECT * FROM lock_monitoring.detect_blocking_sessions(NULL, 5);

-- Verify blocking detection
SELECT session_pid, blocked_sessions_count, blocking_severity, recommended_action
FROM lock_monitoring.blocking_sessions_dashboard;

-- Clean up
ROLLBACK; -- In session 1
```

#### Test 3: Dashboard Views
```sql
-- Test all dashboard views
SELECT COUNT(*) as lock_activity_count FROM lock_monitoring.lock_activity_dashboard;
SELECT COUNT(*) as blocking_sessions_count FROM lock_monitoring.blocking_sessions_dashboard;
SELECT COUNT(*) as lock_analysis_count FROM lock_monitoring.lock_wait_analysis_dashboard;
SELECT COUNT(*) as deadlock_events_count FROM lock_monitoring.deadlock_events_dashboard;
```

### Performance Testing

#### Test 4: Monitoring Performance Impact
```sql
-- Measure monitoring overhead
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM lock_monitoring.capture_lock_activity();

-- Should complete in <100ms under normal load
```

#### Test 5: Data Volume Testing
```sql
-- Generate test lock activity and measure storage
DO $$
BEGIN
    FOR i IN 1..1000 LOOP
        PERFORM lock_monitoring.capture_lock_activity();
        PERFORM pg_sleep(0.01); -- 10ms delay
    END LOOP;
END $$;

-- Check data volume
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'lock_monitoring'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## 📊 **MONITORING AND ALERTING**

### Key Metrics to Monitor

#### Lock Activity Metrics
```sql
-- Daily lock monitoring summary
SELECT 
    DATE(load_date) as monitoring_date,
    COUNT(*) as total_lock_events,
    COUNT(*) FILTER (WHERE lock_granted = false) as waiting_locks,
    COUNT(*) FILTER (WHERE blocking_pid IS NOT NULL) as blocking_locks,
    AVG(lock_duration_seconds) as avg_lock_duration,
    MAX(lock_duration_seconds) as max_lock_duration
FROM lock_monitoring.lock_activity_s 
WHERE load_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(load_date)
ORDER BY monitoring_date DESC;
```

#### Blocking Session Metrics
```sql
-- Blocking session severity distribution
SELECT 
    blocking_severity,
    COUNT(*) as session_count,
    AVG(blocked_sessions_count) as avg_blocked_sessions,
    AVG(blocking_duration_seconds) as avg_blocking_duration
FROM lock_monitoring.blocking_session_s 
WHERE load_date >= CURRENT_DATE - INTERVAL '24 hours'
AND load_end_date IS NULL
GROUP BY blocking_severity
ORDER BY 
    CASE blocking_severity 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        ELSE 4 
    END;
```

### Alert Thresholds
```sql
-- Configure alert thresholds
INSERT INTO monitoring.alert_configuration_s VALUES (
    util.hash_binary('LOCK_CRITICAL_BLOCKING'),
    util.current_load_date(),
    NULL,
    util.hash_binary('LOCK_CRITICAL_BLOCKING_CONFIG'),
    'Critical Blocking Sessions',
    'LOCK_MONITORING',
    'SELECT COUNT(*) FROM lock_monitoring.blocking_sessions_dashboard WHERE blocking_severity = ''CRITICAL''',
    0, -- warning_threshold
    1, -- critical_threshold (any critical blocking)
    'CRITICAL',
    true, -- is_active
    ARRAY['dba@onevault.com', 'ops@onevault.com'],
    'Immediate intervention required for critical blocking sessions',
    util.get_record_source()
);
```

---

## 🛠️ **TROUBLESHOOTING**

### Common Issues and Solutions

#### Issue 1: High Lock Monitoring Overhead
**Symptoms**: Slow query performance, high CPU usage
**Solution**:
```sql
-- Reduce monitoring frequency
-- Modify cron job to run every 10 minutes instead of 5

-- Optimize monitoring queries
ANALYZE lock_monitoring.lock_activity_s;
ANALYZE lock_monitoring.blocking_session_s;

-- Check for missing indexes
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats 
WHERE schemaname = 'lock_monitoring'
AND n_distinct > 100;
```

#### Issue 2: False Positive Deadlock Detection
**Symptoms**: Deadlocks reported but no actual deadlocks
**Solution**:
```sql
-- Tune deadlock detection sensitivity
-- Increase minimum chain length for deadlock detection
-- Review lock wait chain analysis logic

-- Check for lock wait patterns
SELECT 
    lock_type,
    lock_mode,
    COUNT(*) as frequency,
    AVG(lock_duration_seconds) as avg_duration
FROM lock_monitoring.lock_activity_s 
WHERE load_date >= CURRENT_DATE - INTERVAL '24 hours'
GROUP BY lock_type, lock_mode
ORDER BY frequency DESC;
```

#### Issue 3: Blocking Session Auto-Resolution Not Working
**Symptoms**: Critical blocking sessions not automatically terminated
**Solution**:
```sql
-- Check auto-resolution eligibility
SELECT 
    session_pid,
    blocking_severity,
    auto_kill_eligible,
    kill_threshold_seconds,
    blocking_duration_seconds,
    is_superuser
FROM lock_monitoring.blocking_sessions_dashboard
WHERE blocking_severity = 'CRITICAL';

-- Test auto-resolution in dry-run mode
SELECT * FROM lock_monitoring.auto_resolve_blocking(NULL, 300, true);
```

### Log Analysis
```bash
# Check lock monitoring logs
tail -f /var/log/one_vault/lock_monitoring.log

# Analyze lock patterns
grep "CRITICAL" /var/log/one_vault/lock_monitoring.log | tail -20

# Check PostgreSQL logs for lock waits
grep "lock_wait" /var/log/postgresql/postgresql-*.log | tail -10
```

---

## 📈 **PERFORMANCE OPTIMIZATION**

### Index Optimization
```sql
-- Monitor index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE schemaname = 'lock_monitoring'
ORDER BY idx_scan DESC;

-- Add additional indexes if needed
CREATE INDEX CONCURRENTLY idx_lock_activity_s_user_app 
ON lock_monitoring.lock_activity_s(user_name, application_name) 
WHERE load_end_date IS NULL;
```

### Data Retention Optimization
```sql
-- Implement automated partitioning for large tables
-- Consider partitioning by date for lock_activity_s

-- Optimize cleanup procedures
SELECT * FROM lock_monitoring.cleanup_old_data(7); -- Keep only 7 days for testing
```

---

## 🎯 **SUCCESS VALIDATION**

### Deployment Success Criteria
- [ ] All 10 lock monitoring tables created successfully
- [ ] All 7 monitoring functions deployed and tested
- [ ] All 12 performance indexes created
- [ ] Dashboard views returning data
- [ ] Automated monitoring running every 5 minutes
- [ ] Lock activity being captured in real-time
- [ ] Blocking detection working within 30 seconds
- [ ] Alert integration functional
- [ ] Data cleanup automation operational

### Performance Benchmarks
- Lock capture latency: <5 seconds
- Blocking detection time: <30 seconds
- Dashboard query response: <2 seconds
- Monitoring overhead: <2% CPU impact
- Storage growth: <100MB per day under normal load

---

## 📚 **NEXT STEPS**

### Phase 5 Preparation
After successful Phase 4 deployment:
1. Monitor lock patterns for 1 week
2. Tune alert thresholds based on baseline data
3. Optimize monitoring frequency based on system load
4. Prepare for Phase 5: Capacity Planning & Growth Management

### Ongoing Maintenance
- Weekly review of lock monitoring reports
- Monthly optimization of monitoring queries
- Quarterly review of data retention policies
- Annual assessment of monitoring infrastructure scaling

---

## 🔗 **RELATED DOCUMENTATION**

- [Phase 1 Deployment Guide](phase1_deployment_guide.md) - Backup & Recovery
- [Phase 2 Deployment Guide](phase2_deployment_guide.md) - Monitoring & Alerting  
- [Phase 3 Deployment Guide](phase3_deployment_guide.md) - Performance Optimization
- [Backend Development Plan](backend_development_plan.md) - API Integration
- [Production Enhancement Guide](enhancements_phases.md) - Production Modifications

---

**Deployment Status**: ✅ Ready for Production Deployment
**Estimated Deployment Time**: 4-6 hours
**Required Downtime**: None (online deployment)
**Rollback Time**: <30 minutes 