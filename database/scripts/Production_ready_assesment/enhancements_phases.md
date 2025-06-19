# Production Enhancement Phases
## Code Modifications Required for Production Deployment

### Overview

This document identifies all specific code locations and modifications required to transform our current implementation from development/demonstration code to production-ready infrastructure. Each enhancement is categorized by priority and includes exact file locations, code changes, and integration requirements.

---

## 🚨 **CRITICAL PRODUCTION MODIFICATIONS**

### 1. Real System Monitoring Integration

#### **File**: `step_3_monitoring_infrastructure.sql`
**Lines**: 450-520 (collect_system_health_metrics function)

**Current Code (Development)**:
```sql
-- Simulate disk usage (would need actual disk monitoring in production)
v_disk_usage := 45.2; -- Placeholder - integrate with actual disk monitoring
```

**Required Production Changes**:
```sql
-- PRODUCTION: Real disk usage monitoring
SELECT 
    ROUND((used_bytes::DECIMAL / total_bytes) * 100, 2) INTO v_disk_usage
FROM (
    SELECT 
        pg_database_size(current_database()) as used_bytes,
        (SELECT setting::BIGINT FROM pg_settings WHERE name = 'data_directory_size_limit') as total_bytes
) disk_stats;

-- Alternative: Use system function for actual disk monitoring
SELECT 
    ROUND(((total_size - available_size)::DECIMAL / total_size) * 100, 2) INTO v_disk_usage
FROM pg_stat_file_system('/var/lib/postgresql/data');
```

**Integration Required**:
- Install `pg_stat_file_system` extension
- Configure disk monitoring permissions
- Set up disk space alerts at 80% and 95% thresholds

---

#### **File**: `step_3_monitoring_infrastructure.sql`
**Lines**: 480-490 (WAL size monitoring)

**Current Code (Development)**:
```sql
-- WAL size (approximate)
SELECT COALESCE(SUM(size), 0) INTO v_wal_size
FROM pg_ls_waldir();
```

**Required Production Changes**:
```sql
-- PRODUCTION: Enhanced WAL monitoring with archive status
WITH wal_stats AS (
    SELECT 
        SUM(size) as current_wal_size,
        COUNT(*) as wal_file_count,
        COUNT(*) FILTER (WHERE modification > CURRENT_TIMESTAMP - INTERVAL '1 hour') as recent_wal_files
    FROM pg_ls_waldir()
),
archive_stats AS (
    SELECT 
        archived_count,
        failed_count,
        last_archived_wal,
        last_archived_time
    FROM pg_stat_archiver
)
SELECT 
    ws.current_wal_size,
    ws.wal_file_count,
    ws.recent_wal_files,
    as_.failed_count as archive_failures
INTO v_wal_size, v_wal_file_count, v_recent_wal_files, v_archive_failures
FROM wal_stats ws, archive_stats as_;

-- Alert if archive failures > 0
IF v_archive_failures > 0 THEN
    -- Trigger critical alert for WAL archive failures
    PERFORM monitoring.create_critical_alert('WAL_ARCHIVE_FAILURE', v_archive_failures);
END IF;
```

---

#### **File**: `step_3_monitoring_infrastructure.sql`
**Lines**: 520-580 (performance metrics collection)

**Current Code (Development)**:
```sql
-- Average query execution time from pg_stat_statements
SELECT COALESCE(AVG(mean_exec_time), 0) INTO v_avg_query_time
FROM pg_stat_statements 
WHERE calls > 10; -- Only consider queries with meaningful sample size
```

**Required Production Changes**:
```sql
-- PRODUCTION: Enhanced query performance monitoring
WITH query_stats AS (
    SELECT 
        AVG(mean_exec_time) as avg_exec_time,
        MAX(mean_exec_time) as max_exec_time,
        COUNT(*) FILTER (WHERE mean_exec_time > 1000) as slow_query_count,
        COUNT(*) FILTER (WHERE mean_exec_time > 5000) as critical_query_count,
        SUM(calls) as total_calls,
        SUM(total_exec_time) as total_exec_time
    FROM pg_stat_statements 
    WHERE calls > 10
    AND last_seen >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
),
connection_stats AS (
    SELECT 
        COUNT(*) as total_connections,
        COUNT(*) FILTER (WHERE state = 'active') as active_connections,
        COUNT(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction,
        COUNT(*) FILTER (WHERE query_start < CURRENT_TIMESTAMP - INTERVAL '5 minutes' AND state = 'active') as long_running_queries
    FROM pg_stat_activity
    WHERE backend_type = 'client backend'
)
SELECT 
    qs.avg_exec_time,
    qs.slow_query_count,
    qs.critical_query_count,
    cs.total_connections,
    cs.active_connections,
    cs.idle_in_transaction,
    cs.long_running_queries
INTO v_avg_query_time, v_slow_queries, v_critical_queries, 
     v_total_conn, v_active_conn, v_idle_in_txn, v_long_running
FROM query_stats qs, connection_stats cs;

-- Production alerts for performance issues
IF v_critical_queries > 0 THEN
    PERFORM monitoring.create_alert('CRITICAL_SLOW_QUERIES', v_critical_queries);
END IF;

IF v_long_running_queries > 5 THEN
    PERFORM monitoring.create_alert('LONG_RUNNING_QUERIES', v_long_running_queries);
END IF;

IF v_idle_in_txn > 20 THEN
    PERFORM monitoring.create_alert('EXCESSIVE_IDLE_TRANSACTIONS', v_idle_in_txn);
END IF;
```

---

### 2. Security Event Detection Enhancement

#### **File**: `step_4_alerting_system.sql`
**Lines**: 850-920 (detect_security_events function)

**Current Code (Development)**:
```sql
-- Detect failed login attempts (simulate with auth system integration)
SELECT COUNT(*) INTO v_failed_logins
FROM auth.user_auth_s 
WHERE failed_login_attempts > 5
AND last_failed_login > CURRENT_TIMESTAMP - INTERVAL '1 hour'
AND load_end_date IS NULL;
```

**Required Production Changes**:
```sql
-- PRODUCTION: Real security event detection
WITH security_events AS (
    -- Failed login attempts from auth system
    SELECT 
        'FAILED_LOGIN' as event_type,
        COUNT(*) as event_count,
        'HIGH' as severity,
        array_agg(DISTINCT source_ip) as source_ips,
        array_agg(DISTINCT username) as affected_users
    FROM auth.user_auth_s uas
    JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
    WHERE uas.failed_login_attempts > 5
    AND uas.last_failed_login > CURRENT_TIMESTAMP - INTERVAL '1 hour'
    AND uas.load_end_date IS NULL
    
    UNION ALL
    
    -- Suspicious database queries
    SELECT 
        'SUSPICIOUS_QUERY' as event_type,
        COUNT(*) as event_count,
        CASE WHEN COUNT(*) > 10 THEN 'CRITICAL' ELSE 'MEDIUM' END as severity,
        array_agg(DISTINCT client_addr::text) as source_ips,
        array_agg(DISTINCT usename) as affected_users
    FROM pg_stat_activity
    WHERE query ILIKE ANY(ARRAY[
        '%DROP TABLE%', '%DELETE FROM%', '%TRUNCATE%', 
        '%ALTER USER%', '%GRANT%', '%REVOKE%',
        '%pg_read_file%', '%pg_ls_dir%', '%COPY%'
    ])
    AND query_start > CURRENT_TIMESTAMP - INTERVAL '1 hour'
    AND usename NOT IN ('postgres', 'monitoring_user')
    
    UNION ALL
    
    -- Unauthorized schema access attempts
    SELECT 
        'UNAUTHORIZED_ACCESS' as event_type,
        COUNT(*) as event_count,
        'HIGH' as severity,
        array_agg(DISTINCT client_addr::text) as source_ips,
        array_agg(DISTINCT usename) as affected_users
    FROM pg_stat_activity
    WHERE query ILIKE '%information_schema%'
    OR query ILIKE '%pg_catalog%'
    AND usename NOT IN ('postgres', 'monitoring_user', 'backup_user')
    AND query_start > CURRENT_TIMESTAMP - INTERVAL '1 hour'
    
    UNION ALL
    
    -- Multiple tenant access violations
    SELECT 
        'TENANT_VIOLATION' as event_type,
        COUNT(*) as event_count,
        'CRITICAL' as severity,
        ARRAY[]::text[] as source_ips,
        array_agg(DISTINCT username) as affected_users
    FROM (
        SELECT DISTINCT 
            uas.username,
            COUNT(DISTINCT uh.tenant_hk) as tenant_count
        FROM auth.user_auth_s uas
        JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
        JOIN auth.user_session_l usl ON uh.user_hk = usl.user_hk
        JOIN auth.session_state_s sss ON usl.session_hk = sss.session_hk
        WHERE sss.session_start > CURRENT_TIMESTAMP - INTERVAL '1 hour'
        AND uas.load_end_date IS NULL
        AND sss.load_end_date IS NULL
        GROUP BY uas.username
        HAVING COUNT(DISTINCT uh.tenant_hk) > 1
    ) tenant_violations
)
SELECT event_type, event_count, severity, source_ips, affected_users
FROM security_events
WHERE event_count > 0;
```

---

### 3. Notification System Integration

#### **File**: `step_4_alerting_system.sql`
**Lines**: 650-750 (send_alert_notifications function)

**Current Code (Development)**:
```sql
-- Insert notification log satellite
INSERT INTO monitoring.notification_log_s VALUES (
    v_notification_log_hk,
    util.current_load_date(),
    NULL,
    util.hash_binary(v_notification_log_bk || 'PENDING'),
    CURRENT_TIMESTAMP,
    'PENDING',
    v_notification_config.channel_name,
    NULL, -- recipient_address - would be populated from config
    'ALERT: ' || v_alert_definition.alert_name || ' - ' || v_alert_definition.alert_description,
    false, -- delivery_confirmation_received
    NULL, -- delivery_confirmation_timestamp
    NULL, -- failure_reason
    0, -- retry_count
    NULL, -- delivery_duration_ms
    NULL, -- external_message_id
    'NOTIFICATION_DELIVERY'
);
```

**Required Production Changes**:
```sql
-- PRODUCTION: Real notification delivery
DECLARE
    v_notification_result RECORD;
    v_delivery_start TIMESTAMP WITH TIME ZONE;
    v_delivery_end TIMESTAMP WITH TIME ZONE;
    v_external_message_id VARCHAR(255);
    v_delivery_status VARCHAR(20);
    v_failure_reason TEXT;
BEGIN
    v_delivery_start := CURRENT_TIMESTAMP;
    
    -- Call external notification service based on channel type
    CASE v_notification_config.channel_type
        WHEN 'EMAIL' THEN
            SELECT * INTO v_notification_result 
            FROM monitoring.send_email_notification(
                (v_notification_config.configuration->>'to_addresses')::text[],
                'ALERT: ' || v_alert_definition.alert_name,
                monitoring.format_alert_email(v_alert_instance, v_alert_definition),
                v_notification_config.configuration
            );
            
        WHEN 'SLACK' THEN
            SELECT * INTO v_notification_result 
            FROM monitoring.send_slack_notification(
                v_notification_config.configuration->>'webhook_url',
                monitoring.format_alert_slack(v_alert_instance, v_alert_definition),
                v_notification_config.configuration
            );
            
        WHEN 'SMS' THEN
            SELECT * INTO v_notification_result 
            FROM monitoring.send_sms_notification(
                (v_notification_config.configuration->>'phone_numbers')::text[],
                monitoring.format_alert_sms(v_alert_instance, v_alert_definition),
                v_notification_config.configuration
            );
            
        WHEN 'WEBHOOK' THEN
            SELECT * INTO v_notification_result 
            FROM monitoring.send_webhook_notification(
                v_notification_config.configuration->>'webhook_url',
                monitoring.format_alert_webhook(v_alert_instance, v_alert_definition),
                v_notification_config.configuration
            );
            
        WHEN 'PAGERDUTY' THEN
            SELECT * INTO v_notification_result 
            FROM monitoring.send_pagerduty_notification(
                v_notification_config.configuration->>'integration_key',
                monitoring.format_alert_pagerduty(v_alert_instance, v_alert_definition),
                v_notification_config.configuration
            );
    END CASE;
    
    v_delivery_end := CURRENT_TIMESTAMP;
    v_delivery_status := v_notification_result.status;
    v_external_message_id := v_notification_result.message_id;
    v_failure_reason := v_notification_result.error_message;
    
    -- Insert actual delivery results
    INSERT INTO monitoring.notification_log_s VALUES (
        v_notification_log_hk,
        util.current_load_date(),
        NULL,
        util.hash_binary(v_notification_log_bk || v_delivery_status),
        v_delivery_start,
        v_delivery_status,
        v_notification_config.channel_name,
        v_notification_result.recipient_address,
        v_notification_result.message_content,
        v_notification_result.delivery_confirmed,
        v_notification_result.confirmation_timestamp,
        v_failure_reason,
        0, -- retry_count
        EXTRACT(EPOCH FROM (v_delivery_end - v_delivery_start)) * 1000,
        v_external_message_id,
        'NOTIFICATION_DELIVERY'
    );
END;
```

**Additional Files Required**:
```sql
-- Create: monitoring_notification_functions.sql
-- Functions for each notification channel:
-- - monitoring.send_email_notification()
-- - monitoring.send_slack_notification()
-- - monitoring.send_sms_notification()
-- - monitoring.send_webhook_notification()
-- - monitoring.send_pagerduty_notification()
-- - monitoring.format_alert_email()
-- - monitoring.format_alert_slack()
-- - monitoring.format_alert_sms()
-- - monitoring.format_alert_webhook()
-- - monitoring.format_alert_pagerduty()
```

---

## 🔧 **INFRASTRUCTURE INTEGRATION REQUIREMENTS**

### 4. External System Monitoring

#### **File**: `step_1_backup_recovery_infrastructure.sql`
**Lines**: 200-250 (backup execution)

**Current Code (Development)**:
```sql
-- Execute backup logic would go here
-- This would integrate with your actual backup solution
```

**Required Production Changes**:
```sql
-- PRODUCTION: Real backup execution
DECLARE
    v_backup_command TEXT;
    v_backup_result INTEGER;
    v_backup_output TEXT;
    v_backup_size BIGINT;
BEGIN
    -- Construct backup command based on type
    CASE p_backup_type
        WHEN 'FULL' THEN
            v_backup_command := format(
                'pg_dump -h %s -p %s -U %s -d %s -f %s --verbose --format=custom --compress=9',
                current_setting('listen_addresses'),
                current_setting('port'),
                current_user,
                current_database(),
                v_backup_location
            );
            
        WHEN 'INCREMENTAL' THEN
            v_backup_command := format(
                'pg_basebackup -h %s -p %s -U %s -D %s -Ft -z -P -v',
                current_setting('listen_addresses'),
                current_setting('port'),
                current_user,
                v_backup_location
            );
            
        WHEN 'WAL_ARCHIVE' THEN
            v_backup_command := format(
                'pg_receivewal -h %s -p %s -U %s -D %s -v',
                current_setting('listen_addresses'),
                current_setting('port'),
                current_user,
                v_backup_location || '/wal'
            );
    END CASE;
    
    -- Execute backup command
    SELECT INTO v_backup_result, v_backup_output
        system_command_result, system_command_output
    FROM monitoring.execute_system_command(v_backup_command, 3600); -- 1 hour timeout
    
    -- Check backup file size
    SELECT INTO v_backup_size
        file_size
    FROM monitoring.get_file_info(v_backup_location);
    
    -- Update backup status based on results
    IF v_backup_result = 0 AND v_backup_size > 0 THEN
        v_backup_status := 'COMPLETED';
        
        -- Verify backup integrity
        PERFORM backup_mgmt.verify_backup_integrity(v_backup_hk);
    ELSE
        v_backup_status := 'FAILED';
        v_error_message := v_backup_output;
    END IF;
END;
```

**Additional Functions Required**:
```sql
-- Create: system_integration_functions.sql
CREATE OR REPLACE FUNCTION monitoring.execute_system_command(
    p_command TEXT,
    p_timeout_seconds INTEGER DEFAULT 300
) RETURNS TABLE (
    system_command_result INTEGER,
    system_command_output TEXT
) AS $$
-- Implementation using plpython3u or external script execution
$$;

CREATE OR REPLACE FUNCTION monitoring.get_file_info(
    p_file_path TEXT
) RETURNS TABLE (
    file_size BIGINT,
    file_modified TIMESTAMP WITH TIME ZONE,
    file_exists BOOLEAN
) AS $$
-- Implementation for file system integration
$$;
```

---

### 5. Real-time Dashboard Data

#### **File**: `step_3_monitoring_infrastructure.sql`
**Lines**: 750-850 (system_dashboard view)

**Current Code (Development)**:
```sql
CREATE OR REPLACE VIEW monitoring.system_dashboard AS
SELECT 
    'System Health' as dashboard_section,
    shms.metric_name,
    shms.metric_value,
    shms.metric_unit,
    shms.status,
    shms.threshold_warning,
    shms.threshold_critical,
    shms.measurement_timestamp,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - shms.measurement_timestamp)) as age_seconds
FROM monitoring.system_health_metric_h shmh
JOIN monitoring.system_health_metric_s shms ON shmh.health_metric_hk = shms.health_metric_hk
WHERE shms.load_end_date IS NULL
AND shms.measurement_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
```

**Required Production Changes**:
```sql
-- PRODUCTION: Enhanced real-time dashboard with caching
CREATE MATERIALIZED VIEW monitoring.system_dashboard_cache AS
WITH real_time_metrics AS (
    SELECT 
        'System Health' as dashboard_section,
        shms.metric_name,
        shms.metric_value,
        shms.metric_unit,
        shms.status,
        shms.threshold_warning,
        shms.threshold_critical,
        shms.measurement_timestamp,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - shms.measurement_timestamp)) as age_seconds,
        ROW_NUMBER() OVER (PARTITION BY shms.metric_name ORDER BY shms.measurement_timestamp DESC) as rn
    FROM monitoring.system_health_metric_h shmh
    JOIN monitoring.system_health_metric_s shms ON shmh.health_metric_hk = shms.health_metric_hk
    WHERE shms.load_end_date IS NULL
    AND shms.measurement_timestamp >= CURRENT_TIMESTAMP - INTERVAL '6 hours'
),
performance_summary AS (
    SELECT 
        'Performance' as dashboard_section,
        'query_performance_score' as metric_name,
        ROUND(
            100 - (COUNT(*) FILTER (WHERE performance_rating IN ('POOR', 'CRITICAL')) * 100.0 / NULLIF(COUNT(*), 0))
        , 2) as metric_value,
        'score' as metric_unit,
        CASE 
            WHEN COUNT(*) FILTER (WHERE performance_rating = 'CRITICAL') > 0 THEN 'CRITICAL'
            WHEN COUNT(*) FILTER (WHERE performance_rating = 'POOR') > 5 THEN 'WARNING'
            ELSE 'NORMAL'
        END as status,
        80.0 as threshold_warning,
        60.0 as threshold_critical,
        MAX(pms.measurement_period_end) as measurement_timestamp,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(pms.measurement_period_end))) as age_seconds,
        1 as rn
    FROM monitoring.performance_metric_h pmh
    JOIN monitoring.performance_metric_s pms ON pmh.performance_metric_hk = pms.performance_metric_hk
    WHERE pms.load_end_date IS NULL
    AND pms.measurement_period_end >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
),
security_summary AS (
    SELECT 
        'Security' as dashboard_section,
        'security_threat_level' as metric_name,
        COUNT(*) FILTER (WHERE ses.event_severity IN ('HIGH', 'CRITICAL')) as metric_value,
        'events' as metric_unit,
        CASE 
            WHEN COUNT(*) FILTER (WHERE ses.event_severity = 'CRITICAL') > 0 THEN 'CRITICAL'
            WHEN COUNT(*) FILTER (WHERE ses.event_severity = 'HIGH') > 5 THEN 'WARNING'
            ELSE 'NORMAL'
        END as status,
        5.0 as threshold_warning,
        1.0 as threshold_critical,
        COALESCE(MAX(ses.event_timestamp), CURRENT_TIMESTAMP - INTERVAL '1 hour') as measurement_timestamp,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(MAX(ses.event_timestamp), CURRENT_TIMESTAMP - INTERVAL '1 hour'))) as age_seconds,
        1 as rn
    FROM monitoring.security_event_h seh
    JOIN monitoring.security_event_s ses ON seh.security_event_hk = ses.security_event_hk
    WHERE ses.load_end_date IS NULL
    AND ses.event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
),
backup_summary AS (
    SELECT 
        'Backup' as dashboard_section,
        'backup_health_score' as metric_name,
        CASE 
            WHEN COUNT(*) FILTER (WHERE bes.backup_status = 'FAILED') > 0 THEN 0
            WHEN COUNT(*) FILTER (WHERE bes.backup_status = 'COMPLETED') = 0 THEN 50
            ELSE 100
        END as metric_value,
        'score' as metric_unit,
        CASE 
            WHEN COUNT(*) FILTER (WHERE bes.backup_status = 'FAILED') > 0 THEN 'CRITICAL'
            WHEN COUNT(*) FILTER (WHERE bes.backup_status = 'COMPLETED') = 0 THEN 'WARNING'
            ELSE 'NORMAL'
        END as status,
        90.0 as threshold_warning,
        50.0 as threshold_critical,
        COALESCE(MAX(bes.backup_start_time), CURRENT_TIMESTAMP - INTERVAL '24 hours') as measurement_timestamp,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(MAX(bes.backup_start_time), CURRENT_TIMESTAMP - INTERVAL '24 hours'))) as age_seconds,
        1 as rn
    FROM backup_mgmt.backup_execution_h beh
    JOIN backup_mgmt.backup_execution_s bes ON beh.backup_hk = bes.backup_hk
    WHERE bes.load_end_date IS NULL
    AND bes.backup_start_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
)
SELECT * FROM real_time_metrics WHERE rn = 1
UNION ALL SELECT * FROM performance_summary
UNION ALL SELECT * FROM security_summary  
UNION ALL SELECT * FROM backup_summary
ORDER BY dashboard_section, metric_name;

-- Create index for fast dashboard queries
CREATE UNIQUE INDEX idx_system_dashboard_cache_section_metric 
ON monitoring.system_dashboard_cache (dashboard_section, metric_name);

-- Auto-refresh materialized view every 5 minutes
CREATE OR REPLACE FUNCTION monitoring.refresh_dashboard_cache()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY monitoring.system_dashboard_cache;
END;
$$ LANGUAGE plpgsql;

-- Schedule dashboard refresh
SELECT cron.schedule('refresh-dashboard', '*/5 * * * *', 'SELECT monitoring.refresh_dashboard_cache();');
```

---

## 📊 **CONFIGURATION MANAGEMENT ENHANCEMENTS**

### 6. Environment-Specific Configuration

#### **File**: `database/config/postgresql_production.conf`
**Lines**: 1-50 (connection settings)

**Current Code (Development)**:
```conf
# Connection Settings
max_connections = 200                   # Maximum concurrent connections
shared_buffers = 256MB                  # Shared memory for caching
```

**Required Production Changes**:
```conf
# PRODUCTION: Environment-specific connection settings
# Calculate based on available RAM: shared_buffers = 25% of RAM
shared_buffers = 2GB                    # For 8GB RAM server
max_connections = 500                   # For high-traffic production

# Connection pooling (requires pgbouncer)
# pgbouncer.pool_mode = transaction
# pgbouncer.max_client_conn = 1000
# pgbouncer.default_pool_size = 100

# Memory settings for production workload
work_mem = 16MB                         # Per-operation memory
maintenance_work_mem = 512MB            # For maintenance operations
effective_cache_size = 6GB              # OS cache estimate

# Checkpoint settings for production
checkpoint_completion_target = 0.9      # Spread checkpoints over 90% of interval
checkpoint_timeout = 15min              # Checkpoint every 15 minutes
max_wal_size = 4GB                      # Maximum WAL size before checkpoint
min_wal_size = 1GB                      # Minimum WAL size

# Logging for production monitoring
log_min_duration_statement = 1000       # Log queries taking > 1 second
log_checkpoints = on                    # Log checkpoint activity
log_connections = on                    # Log new connections
log_disconnections = on                 # Log disconnections
log_lock_waits = on                     # Log lock waits
log_temp_files = 10MB                   # Log large temp files

# Autovacuum tuning for production
autovacuum_max_workers = 6              # More workers for large databases
autovacuum_naptime = 30s                # More frequent autovacuum
autovacuum_vacuum_scale_factor = 0.1    # Vacuum when 10% of table changes
autovacuum_analyze_scale_factor = 0.05  # Analyze when 5% of table changes

# Replication settings (if using streaming replication)
wal_level = replica                     # Enable replication
max_wal_senders = 10                    # Maximum replication connections
wal_keep_segments = 64                  # Keep WAL segments for replicas
hot_standby = on                        # Enable read queries on standby
```

---

### 7. Backup Configuration Enhancement

#### **File**: `step_1_backup_recovery_infrastructure.sql`
**Lines**: 100-150 (backup configuration)

**Current Code (Development)**:
```sql
backup_location TEXT,
retention_period INTERVAL DEFAULT '7 years', -- For compliance
```

**Required Production Changes**:
```sql
-- PRODUCTION: Environment-specific backup configuration
backup_location TEXT,
backup_storage_type VARCHAR(50) DEFAULT 'LOCAL', -- LOCAL, S3, AZURE, GCS
backup_encryption_enabled BOOLEAN DEFAULT true,
backup_compression_level INTEGER DEFAULT 9, -- 1-9, 9 = maximum compression
retention_period INTERVAL DEFAULT '7 years', -- HIPAA/SOX compliance
archive_to_cold_storage_after INTERVAL DEFAULT '90 days',
backup_verification_required BOOLEAN DEFAULT true,
backup_offsite_copy_required BOOLEAN DEFAULT true,
backup_storage_configuration JSONB DEFAULT jsonb_build_object(
    'local_path', '/backup/postgresql',
    's3_bucket', 'onevault-backups-prod',
    's3_region', 'us-east-1',
    'azure_container', 'onevault-backups',
    'gcs_bucket', 'onevault-backups-prod',
    'encryption_key_id', 'backup-encryption-key-prod'
),
```

**Additional Configuration Required**:
```sql
-- Create: backup_storage_functions.sql
CREATE OR REPLACE FUNCTION backup_mgmt.upload_to_cloud_storage(
    p_backup_hk BYTEA,
    p_local_path TEXT,
    p_storage_type VARCHAR(50),
    p_storage_config JSONB
) RETURNS BOOLEAN AS $$
-- Implementation for cloud storage upload
-- Supports S3, Azure Blob Storage, Google Cloud Storage
$$;

CREATE OR REPLACE FUNCTION backup_mgmt.verify_backup_integrity(
    p_backup_hk BYTEA
) RETURNS TABLE (
    integrity_check_passed BOOLEAN,
    checksum_verified BOOLEAN,
    restore_test_passed BOOLEAN,
    verification_details JSONB
) AS $$
-- Implementation for backup verification
-- Includes checksum verification and restore testing
$$;
```

---

## 🔐 **SECURITY ENHANCEMENTS**

### 8. Authentication Integration

#### **File**: Backend API files (when created)
**Location**: `backend/src/middleware/auth/TenantIsolationMiddleware.ts`

**Required Production Implementation**:
```typescript
// PRODUCTION: Real authentication integration
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';
import { AuthService } from '../services/AuthService';

export class TenantIsolationMiddleware {
    private authService: AuthService;
    
    constructor() {
        this.authService = new AuthService();
    }
    
    async validateTenantAccess(req: Request, res: Response, next: NextFunction) {
        try {
            const token = req.headers.authorization?.replace('Bearer ', '');
            const tenantId = req.headers['x-tenant-id'] as string;
            
            if (!token || !tenantId) {
                return res.status(401).json({
                    success: false,
                    error: 'Missing authentication token or tenant ID'
                });
            }
            
            // Verify JWT token
            const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
            
            // Validate session in database
            const sessionValid = await this.authService.validateSession(
                token, 
                tenantId
            );
            
            if (!sessionValid) {
                return res.status(401).json({
                    success: false,
                    error: 'Invalid session or tenant access denied'
                });
            }
            
            // Check tenant access permissions
            const hasAccess = await this.authService.checkTenantAccess(
                decoded.userId,
                tenantId
            );
            
            if (!hasAccess) {
                // Log security event
                await this.authService.logSecurityEvent({
                    eventType: 'UNAUTHORIZED_TENANT_ACCESS',
                    userId: decoded.userId,
                    tenantId: tenantId,
                    sourceIp: req.ip,
                    userAgent: req.headers['user-agent']
                });
                
                return res.status(403).json({
                    success: false,
                    error: 'Access denied for specified tenant'
                });
            }
            
            // Add user and tenant context to request
            req.user = {
                userId: decoded.userId,
                tenantId: tenantId,
                permissions: decoded.permissions
            };
            
            next();
        } catch (error) {
            return res.status(401).json({
                success: false,
                error: 'Authentication failed'
            });
        }
    }
}
```

---

### 9. Encryption and Data Protection

#### **File**: `step_3_monitoring_infrastructure.sql`
**Lines**: Various locations storing sensitive data

**Current Code (Development)**:
```sql
source_ip INET,
user_agent TEXT,
username VARCHAR(100),
```

**Required Production Changes**:
```sql
-- PRODUCTION: Encrypt sensitive data
source_ip_encrypted BYTEA, -- Encrypted IP address
user_agent_hash BYTEA,     -- Hashed user agent
username_hash BYTEA,       -- Hashed username for privacy
original_data_encrypted BYTEA, -- Encrypted original data
encryption_key_id VARCHAR(100), -- Key management reference
```

**Additional Functions Required**:
```sql
-- Create: encryption_functions.sql
CREATE OR REPLACE FUNCTION util.encrypt_sensitive_data(
    p_data TEXT,
    p_key_id VARCHAR(100) DEFAULT 'default-encryption-key'
) RETURNS BYTEA AS $$
-- Implementation using pgcrypto or external key management
$$;

CREATE OR REPLACE FUNCTION util.decrypt_sensitive_data(
    p_encrypted_data BYTEA,
    p_key_id VARCHAR(100)
) RETURNS TEXT AS $$
-- Implementation for decryption with proper access controls
$$;

CREATE OR REPLACE FUNCTION util.hash_pii_data(
    p_data TEXT,
    p_salt TEXT DEFAULT NULL
) RETURNS BYTEA AS $$
-- Implementation for one-way hashing of PII data
$$;
```

---

## 📈 **PERFORMANCE OPTIMIZATIONS**

### 10. Query Optimization for Production Scale

#### **File**: `step_3_monitoring_infrastructure.sql`
**Lines**: 650-750 (monitoring queries)

**Current Code (Development)**:
```sql
-- Basic monitoring queries
SELECT * FROM monitoring.system_health_metric_s 
WHERE load_end_date IS NULL;
```

**Required Production Changes**:
```sql
-- PRODUCTION: Optimized queries with partitioning
-- Partition monitoring tables by date for performance
CREATE TABLE monitoring.system_health_metric_s_y2024m01 
PARTITION OF monitoring.system_health_metric_s
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE monitoring.system_health_metric_s_y2024m02 
PARTITION OF monitoring.system_health_metric_s
FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Optimized query with partition pruning
SELECT shms.metric_name, shms.metric_value, shms.status
FROM monitoring.system_health_metric_s shms
WHERE shms.measurement_timestamp >= CURRENT_DATE - INTERVAL '7 days'
AND shms.load_end_date IS NULL
AND shms.metric_category = 'PERFORMANCE'
ORDER BY shms.measurement_timestamp DESC
LIMIT 1000;

-- Create automated partition management
CREATE OR REPLACE FUNCTION monitoring.create_monthly_partitions()
RETURNS VOID AS $$
DECLARE
    v_start_date DATE;
    v_end_date DATE;
    v_table_name TEXT;
BEGIN
    -- Create partitions for next 3 months
    FOR i IN 0..2 LOOP
        v_start_date := date_trunc('month', CURRENT_DATE + (i || ' months')::INTERVAL);
        v_end_date := v_start_date + INTERVAL '1 month';
        v_table_name := 'system_health_metric_s_y' || 
                       to_char(v_start_date, 'YYYY') || 'm' || 
                       to_char(v_start_date, 'MM');
        
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS monitoring.%I PARTITION OF monitoring.system_health_metric_s
             FOR VALUES FROM (%L) TO (%L)',
            v_table_name, v_start_date, v_end_date
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Schedule partition creation
SELECT cron.schedule('create-partitions', '0 0 1 * *', 'SELECT monitoring.create_monthly_partitions();');
```

---

## 🚀 **DEPLOYMENT AUTOMATION**

### 11. Environment Detection and Configuration

#### **File**: All SQL files
**Location**: Throughout all scripts

**Required Production Changes**:
```sql
-- Add to beginning of all scripts
DO $$
DECLARE
    v_environment VARCHAR(20);
    v_is_production BOOLEAN;
BEGIN
    -- Detect environment
    SELECT COALESCE(current_setting('app.environment', true), 'development') INTO v_environment;
    v_is_production := (v_environment = 'production');
    
    -- Set environment-specific configurations
    IF v_is_production THEN
        -- Production settings
        PERFORM set_config('app.backup_retention_days', '2555', false); -- 7 years
        PERFORM set_config('app.monitoring_frequency_seconds', '300', false); -- 5 minutes
        PERFORM set_config('app.alert_suppression_minutes', '60', false);
        PERFORM set_config('app.encryption_required', 'true', false);
        PERFORM set_config('app.audit_level', 'FULL', false);
    ELSE
        -- Development/staging settings
        PERFORM set_config('app.backup_retention_days', '30', false);
        PERFORM set_config('app.monitoring_frequency_seconds', '60', false); -- 1 minute
        PERFORM set_config('app.alert_suppression_minutes', '5', false);
        PERFORM set_config('app.encryption_required', 'false', false);
        PERFORM set_config('app.audit_level', 'BASIC', false);
    END IF;
    
    RAISE NOTICE 'Environment: %, Production: %', v_environment, v_is_production;
END
$$;
```

---

### 12. Health Check Endpoints

#### **File**: Backend API files (when created)
**Location**: `backend/src/routes/health/healthRoutes.ts`

**Required Production Implementation**:
```typescript
// PRODUCTION: Comprehensive health checks
import { Router } from 'express';
import { HealthCheckService } from '../services/HealthCheckService';

const router = Router();
const healthService = new HealthCheckService();

// Basic health check
router.get('/health', async (req, res) => {
    try {
        const health = await healthService.getBasicHealth();
        res.status(health.status === 'healthy' ? 200 : 503).json(health);
    } catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            timestamp: new Date().toISOString(),
            error: 'Health check failed'
        });
    }
});

// Detailed health check for monitoring systems
router.get('/health/detailed', async (req, res) => {
    try {
        const health = await healthService.getDetailedHealth();
        res.status(health.overall_status === 'healthy' ? 200 : 503).json(health);
    } catch (error) {
        res.status(503).json({
            overall_status: 'unhealthy',
            timestamp: new Date().toISOString(),
            error: 'Detailed health check failed'
        });
    }
});

// Readiness probe for Kubernetes
router.get('/ready', async (req, res) => {
    try {
        const ready = await healthService.checkReadiness();
        res.status(ready ? 200 : 503).json({
            ready,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(503).json({
            ready: false,
            timestamp: new Date().toISOString(),
            error: 'Readiness check failed'
        });
    }
});

// Liveness probe for Kubernetes
router.get('/live', async (req, res) => {
    try {
        const alive = await healthService.checkLiveness();
        res.status(alive ? 200 : 503).json({
            alive,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(503).json({
            alive: false,
            timestamp: new Date().toISOString(),
            error: 'Liveness check failed'
        });
    }
});

export default router;
```

---

## 📋 **IMPLEMENTATION CHECKLIST**

### Critical Production Modifications (Week 1)
- [ ] **Real disk space monitoring** - Replace simulated disk usage with actual system calls
- [ ] **WAL archive monitoring** - Implement WAL archive failure detection
- [ ] **Performance query optimization** - Add connection monitoring and long-running query detection
- [ ] **Security event detection** - Implement real failed login and suspicious query detection
- [ ] **Backup execution integration** - Replace placeholder with actual pg_dump/pg_basebackup commands

### Infrastructure Integration (Week 2)
- [ ] **Notification system integration** - Implement actual email, Slack, SMS, webhook delivery
- [ ] **Cloud storage integration** - Add S3/Azure/GCS backup storage support
- [ ] **Encryption implementation** - Add data encryption for sensitive monitoring data
- [ ] **Authentication middleware** - Implement production JWT validation and tenant isolation
- [ ] **Health check endpoints** - Create comprehensive health monitoring for load balancers

### Performance Optimization (Week 3)
- [ ] **Table partitioning** - Implement date-based partitioning for monitoring tables
- [ ] **Query optimization** - Add partition pruning and optimized indexes
- [ ] **Dashboard caching** - Implement materialized view caching for real-time dashboards
- [ ] **Connection pooling** - Configure pgbouncer for production connection management
- [ ] **Automated maintenance** - Schedule partition creation and cleanup

### Environment Configuration (Week 4)
- [ ] **Environment detection** - Add environment-specific configuration throughout all scripts
- [ ] **Production PostgreSQL config** - Tune all settings for production workload
- [ ] **Backup configuration** - Configure retention, encryption, and cloud storage
- [ ] **Monitoring automation** - Set up cron jobs for metric collection and reporting
- [ ] **Security hardening** - Implement encryption, access controls, and audit logging

---

## 🎯 **SUCCESS CRITERIA**

### Production Readiness Validation
1. **Real System Integration**: All simulated/placeholder code replaced with actual system integration
2. **Performance at Scale**: System handles 500+ concurrent connections with <100ms monitoring query response
3. **Security Compliance**: All sensitive data encrypted, audit trails complete, access controls enforced
4. **Operational Excellence**: Automated monitoring, alerting, backup, and recovery procedures functional
5. **Environment Flexibility**: Single codebase deploys correctly across dev/staging/production environments

### Monitoring and Alerting Validation
1. **Real-time Metrics**: System health, performance, security, and compliance metrics collected every 5 minutes
2. **Alert Effectiveness**: <5 minute alert response time, <10% false positive rate
3. **Notification Delivery**: >99% notification delivery success across all channels
4. **Incident Management**: Automated incident creation and correlation from multiple alerts
5. **Dashboard Performance**: Real-time dashboards load in <2 seconds with current data

---

## 🔧 **PHASE 3 PRODUCTION ENHANCEMENTS**

### 13. Performance Monitoring Integration

#### **File**: `step_5_performance_optimization.sql`
**Lines**: 576-650 (connection pool analysis)

**Current Code (Development)**:
```sql
-- Get current connection statistics
SELECT 
    current_setting('max_connections')::INTEGER,
    COUNT(*),
    COUNT(*) FILTER (WHERE state = 'active'),
    COUNT(*) FILTER (WHERE state = 'idle'),
    0 -- waiting connections - would need pgbouncer integration
INTO v_max_connections, v_current_connections, v_active_connections, 
     v_idle_connections, v_waiting_connections
FROM pg_stat_activity
WHERE backend_type = 'client backend';
```

**Required Production Changes**:
```sql
-- PRODUCTION: Real connection pool monitoring with pgbouncer integration
WITH connection_stats AS (
    SELECT 
        current_setting('max_connections')::INTEGER as max_connections,
        COUNT(*) as current_connections,
        COUNT(*) FILTER (WHERE state = 'active') as active_connections,
        COUNT(*) FILTER (WHERE state = 'idle') as idle_connections,
        COUNT(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction,
        COUNT(*) FILTER (WHERE query_start < CURRENT_TIMESTAMP - INTERVAL '5 minutes' AND state = 'active') as long_running_queries,
        AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - query_start))) FILTER (WHERE state = 'active') as avg_query_duration
    FROM pg_stat_activity
    WHERE backend_type = 'client backend'
),
pgbouncer_stats AS (
    -- Integration with pgbouncer stats (requires dblink or external monitoring)
    SELECT 
        COALESCE(waiting_clients, 0) as waiting_connections,
        COALESCE(pool_size, 0) as pool_size,
        COALESCE(active_clients, 0) as active_clients,
        COALESCE(waiting_clients, 0) as waiting_clients
    FROM performance.get_pgbouncer_stats() -- External function to query pgbouncer
)
SELECT 
    cs.max_connections,
    cs.current_connections,
    cs.active_connections,
    cs.idle_connections,
    cs.idle_in_transaction,
    cs.long_running_queries,
    cs.avg_query_duration,
    ps.waiting_connections,
    ps.pool_size,
    ps.active_clients
INTO v_max_connections, v_current_connections, v_active_connections, 
     v_idle_connections, v_idle_in_txn, v_long_running, v_avg_duration,
     v_waiting_connections, v_pool_size, v_active_clients
FROM connection_stats cs, pgbouncer_stats ps;

-- Production alerts for connection issues
IF v_idle_in_txn > 20 THEN
    PERFORM monitoring.create_alert('EXCESSIVE_IDLE_TRANSACTIONS', v_idle_in_txn);
END IF;

IF v_long_running > 10 THEN
    PERFORM monitoring.create_alert('LONG_RUNNING_QUERIES', v_long_running);
END IF;

IF v_waiting_connections > 50 THEN
    PERFORM monitoring.create_alert('CONNECTION_POOL_SATURATION', v_waiting_connections);
END IF;
```

**Additional Functions Required**:
```sql
-- Create: pgbouncer_integration_functions.sql
CREATE OR REPLACE FUNCTION performance.get_pgbouncer_stats()
RETURNS TABLE (
    pool_name TEXT,
    pool_size INTEGER,
    active_clients INTEGER,
    waiting_clients INTEGER,
    pool_mode TEXT
) AS $$
-- Implementation to query pgbouncer SHOW POOLS via dblink or external script
$$;
```

---

### 14. Resource Usage Monitoring Enhancement

#### **File**: `step_6_automated_maintenance.sql`
**Lines**: 400-450 (maintenance execution tracking)

**Current Code (Development)**:
```sql
NULL, -- cpu_usage_percent
NULL, -- memory_usage_mb
NULL, -- disk_io_mb
```

**Required Production Changes**:
```sql
-- PRODUCTION: Real resource usage monitoring during maintenance
DECLARE
    v_cpu_usage DECIMAL(5,2);
    v_memory_usage DECIMAL(10,2);
    v_disk_io DECIMAL(10,2);
    v_before_stats JSONB;
    v_after_stats JSONB;
BEGIN
    -- Capture before stats
    SELECT jsonb_build_object(
        'cpu_user', (SELECT cpu_user FROM pg_stat_bgwriter),
        'cpu_system', (SELECT cpu_system FROM pg_stat_bgwriter),
        'buffers_checkpoint', (SELECT buffers_checkpoint FROM pg_stat_bgwriter),
        'buffers_clean', (SELECT buffers_clean FROM pg_stat_bgwriter),
        'buffers_backend', (SELECT buffers_backend FROM pg_stat_bgwriter),
        'shared_buffers_size', pg_size_pretty(current_setting('shared_buffers')::bigint * 8192),
        'work_mem_size', current_setting('work_mem'),
        'maintenance_work_mem', current_setting('maintenance_work_mem')
    ) INTO v_before_stats;
    
    -- Execute maintenance task with resource monitoring
    -- ... task execution code ...
    
    -- Capture after stats and calculate usage
    SELECT jsonb_build_object(
        'cpu_user', (SELECT cpu_user FROM pg_stat_bgwriter),
        'cpu_system', (SELECT cpu_system FROM pg_stat_bgwriter),
        'buffers_checkpoint', (SELECT buffers_checkpoint FROM pg_stat_bgwriter),
        'buffers_clean', (SELECT buffers_clean FROM pg_stat_bgwriter),
        'buffers_backend', (SELECT buffers_backend FROM pg_stat_bgwriter)
    ) INTO v_after_stats;
    
    -- Calculate resource usage (simplified - would need system integration)
    v_cpu_usage := maintenance.calculate_cpu_usage(v_before_stats, v_after_stats, v_duration);
    v_memory_usage := maintenance.calculate_memory_usage(v_task_record.task_type, v_rows_affected);
    v_disk_io := maintenance.calculate_disk_io(v_before_stats, v_after_stats);
    
    -- Store actual resource usage
    v_cpu_usage, -- cpu_usage_percent
    v_memory_usage, -- memory_usage_mb  
    v_disk_io, -- disk_io_mb
```

**Additional Functions Required**:
```sql
-- Create: resource_monitoring_functions.sql
CREATE OR REPLACE FUNCTION maintenance.calculate_cpu_usage(
    p_before_stats JSONB,
    p_after_stats JSONB,
    p_duration_seconds INTEGER
) RETURNS DECIMAL(5,2) AS $$
-- Implementation for CPU usage calculation
$$;

CREATE OR REPLACE FUNCTION maintenance.calculate_memory_usage(
    p_task_type VARCHAR(50),
    p_rows_affected INTEGER
) RETURNS DECIMAL(10,2) AS $$
-- Implementation for memory usage estimation
$$;

CREATE OR REPLACE FUNCTION maintenance.calculate_disk_io(
    p_before_stats JSONB,
    p_after_stats JSONB
) RETURNS DECIMAL(10,2) AS $$
-- Implementation for disk I/O calculation
$$;
```

---

### 15. Index Column Analysis Enhancement

#### **File**: `step_5_performance_optimization.sql`
**Lines**: 520-530 (index optimization)

**Current Code (Development)**:
```sql
ARRAY[]::TEXT[], -- index_columns - would need additional query to populate
```

**Required Production Changes**:
```sql
-- PRODUCTION: Real index column analysis
DECLARE
    v_index_columns TEXT[];
    v_index_definition TEXT;
    v_index_type VARCHAR(20);
BEGIN
    -- Get actual index columns and definition
    SELECT 
        array_agg(a.attname ORDER BY ic.attpos),
        pg_get_indexdef(i.indexrelid),
        am.amname
    INTO v_index_columns, v_index_definition, v_index_type
    FROM pg_index i
    JOIN pg_class c ON i.indexrelid = c.oid
    JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
    JOIN pg_am am ON c.relam = am.oid
    LEFT JOIN (
        SELECT indexrelid, generate_subscripts(indkey, 1) AS attpos, unnest(indkey) AS attnum
        FROM pg_index
    ) ic ON i.indexrelid = ic.indexrelid AND a.attnum = ic.attnum
    WHERE c.relname = v_index_record.indexrelname
    AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = v_index_record.schemaname)
    GROUP BY i.indexrelid, pg_get_indexdef(i.indexrelid), am.amname;
    
    -- Store actual index information
    v_index_columns, -- index_columns
    v_index_type, -- index_type
    -- ... rest of the record ...
    v_index_definition, -- recommended_index_definition
```

---

### 16. Automated Optimization Execution

#### **File**: `step_6_automated_maintenance.sql`
**Lines**: 526-650 (automated database optimization)

**Current Code (Development)**:
```sql
-- Auto-vacuum tables with high update/delete activity
FOR v_table_record IN 
    SELECT 
        schemaname,
        tablename,
        n_tup_upd + n_tup_del as modifications,
        pg_relation_size(schemaname||'.'||tablename) as table_size
    FROM pg_stat_user_tables
    WHERE (n_tup_upd + n_tup_del) > 1000
    AND schemaname NOT IN ('information_schema', 'pg_catalog')
    AND (p_tenant_hk IS NULL OR schemaname IN ('auth', 'business', 'audit'))
    ORDER BY (n_tup_upd + n_tup_del) DESC
    LIMIT 20
```

**Required Production Changes**:
```sql
-- PRODUCTION: Enhanced automated optimization with safety checks
FOR v_table_record IN 
    WITH table_stats AS (
        SELECT 
            schemaname,
            tablename,
            n_tup_upd + n_tup_del as modifications,
            n_tup_ins + n_tup_upd + n_tup_del as total_activity,
            pg_relation_size(schemaname||'.'||tablename) as table_size,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze,
            vacuum_count,
            autovacuum_count,
            analyze_count,
            autoanalyze_count,
            n_dead_tup,
            n_live_tup,
            CASE 
                WHEN n_live_tup > 0 THEN (n_dead_tup::DECIMAL / n_live_tup) * 100
                ELSE 0
            END as dead_tuple_pct
        FROM pg_stat_user_tables
        WHERE schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
        AND (p_tenant_hk IS NULL OR schemaname IN ('auth', 'business', 'audit', 'monitoring', 'performance', 'maintenance'))
    ),
    optimization_candidates AS (
        SELECT *,
            CASE 
                WHEN dead_tuple_pct > 20 AND table_size > 100*1024*1024 THEN 'VACUUM_FULL' -- >100MB with >20% dead tuples
                WHEN dead_tuple_pct > 10 OR modifications > 10000 THEN 'VACUUM'
                WHEN last_analyze < CURRENT_DATE - INTERVAL '7 days' THEN 'ANALYZE'
                WHEN modifications > 1000 THEN 'VACUUM_ANALYZE'
                ELSE 'SKIP'
            END as optimization_action,
            CASE 
                WHEN dead_tuple_pct > 30 THEN 'HIGH'
                WHEN dead_tuple_pct > 15 THEN 'MEDIUM'
                ELSE 'LOW'
            END as priority
        FROM table_stats
        WHERE modifications > 100 -- Only tables with meaningful activity
        AND table_size > 1024*1024 -- Only tables > 1MB
    )
    SELECT *
    FROM optimization_candidates
    WHERE optimization_action != 'SKIP'
    ORDER BY 
        CASE priority WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
        dead_tuple_pct DESC,
        modifications DESC
    LIMIT 50 -- Increased limit but with better prioritization
LOOP
    v_before_size := v_table_record.table_size;
    
    BEGIN
        -- Safety check: Don't vacuum during peak hours unless critical
        IF EXTRACT(HOUR FROM CURRENT_TIME) BETWEEN 8 AND 18 
           AND v_table_record.priority != 'HIGH' THEN
            CONTINUE; -- Skip non-critical maintenance during business hours
        END IF;
        
        -- Execute appropriate optimization action
        CASE v_table_record.optimization_action
            WHEN 'VACUUM_FULL' THEN
                -- Only during maintenance windows
                IF CURRENT_TIME BETWEEN TIME '02:00' AND TIME '05:00' THEN
                    EXECUTE format('VACUUM FULL ANALYZE %I.%I', v_table_record.schemaname, v_table_record.tablename);
                    v_vacuum_count := v_vacuum_count + 1;
                END IF;
                
            WHEN 'VACUUM_ANALYZE' THEN
                EXECUTE format('VACUUM ANALYZE %I.%I', v_table_record.schemaname, v_table_record.tablename);
                v_vacuum_count := v_vacuum_count + 1;
                v_analyze_count := v_analyze_count + 1;
                
            WHEN 'VACUUM' THEN
                EXECUTE format('VACUUM %I.%I', v_table_record.schemaname, v_table_record.tablename);
                v_vacuum_count := v_vacuum_count + 1;
                
            WHEN 'ANALYZE' THEN
                EXECUTE format('ANALYZE %I.%I', v_table_record.schemaname, v_table_record.tablename);
                v_analyze_count := v_analyze_count + 1;
        END CASE;
        
        -- Calculate space reclaimed
        SELECT pg_relation_size(v_table_record.schemaname||'.'||v_table_record.tablename) 
        INTO v_after_size;
        
        v_space_reclaimed := v_space_reclaimed + GREATEST(0, v_before_size - v_after_size);
        
        -- Log optimization action
        INSERT INTO maintenance.optimization_log (
            table_name, 
            optimization_action, 
            before_size, 
            after_size, 
            space_reclaimed,
            execution_time
        ) VALUES (
            v_table_record.schemaname || '.' || v_table_record.tablename,
            v_table_record.optimization_action,
            v_before_size,
            v_after_size,
            v_before_size - v_after_size,
            CURRENT_TIMESTAMP
        );
        
    EXCEPTION WHEN OTHERS THEN
        -- Enhanced error logging
        INSERT INTO maintenance.optimization_errors (
            table_name,
            optimization_action,
            error_message,
            error_timestamp,
            table_size,
            dead_tuple_pct
        ) VALUES (
            v_table_record.schemaname || '.' || v_table_record.tablename,
            v_table_record.optimization_action,
            SQLERRM,
            CURRENT_TIMESTAMP,
            v_table_record.table_size,
            v_table_record.dead_tuple_pct
        );
        
        RAISE NOTICE 'Failed to optimize table %.%: %', 
            v_table_record.schemaname, v_table_record.tablename, SQLERRM;
    END;
END LOOP;
```

**Additional Tables Required**:
```sql
-- Create: maintenance_logging_tables.sql
CREATE TABLE maintenance.optimization_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(200) NOT NULL,
    optimization_action VARCHAR(50) NOT NULL,
    before_size BIGINT,
    after_size BIGINT,
    space_reclaimed BIGINT,
    execution_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE maintenance.optimization_errors (
    error_id SERIAL PRIMARY KEY,
    table_name VARCHAR(200) NOT NULL,
    optimization_action VARCHAR(50) NOT NULL,
    error_message TEXT,
    error_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    table_size BIGINT,
    dead_tuple_pct DECIMAL(5,2)
);
```

---

## 📋 **PHASE 3 IMPLEMENTATION CHECKLIST**

### Performance Optimization Enhancements (Week 1)
- [ ] **Connection pool monitoring** - Integrate with pgbouncer for real connection pool statistics
- [ ] **Resource usage tracking** - Implement CPU, memory, and disk I/O monitoring during operations
- [ ] **Index column analysis** - Add real index structure analysis and optimization recommendations
- [ ] **Query plan analysis** - Integrate with pg_stat_statements for execution plan optimization
- [ ] **Cache efficiency monitoring** - Add buffer cache and query cache performance analysis

### Automated Maintenance Enhancements (Week 2)
- [ ] **Smart optimization scheduling** - Add business hours awareness and priority-based scheduling
- [ ] **Safety checks implementation** - Add table lock detection and maintenance window enforcement
- [ ] **Resource impact monitoring** - Track CPU, memory, and I/O impact of maintenance operations
- [ ] **Optimization logging** - Implement comprehensive logging of all maintenance actions and results
- [ ] **Error handling enhancement** - Add detailed error tracking and recovery procedures

### Integration Requirements (Week 3)
- [ ] **pgbouncer integration** - Set up connection pool monitoring and statistics collection
- [ ] **System resource monitoring** - Integrate with OS-level monitoring for CPU, memory, disk usage
- [ ] **Maintenance window management** - Implement dynamic maintenance window scheduling
- [ ] **Performance baseline tracking** - Establish performance baselines and improvement tracking
- [ ] **Automated alerting** - Connect performance and maintenance systems to alerting infrastructure

### Production Validation (Week 4)
- [ ] **Performance impact testing** - Validate that monitoring doesn't impact system performance
- [ ] **Maintenance safety testing** - Test all safety checks and rollback procedures
- [ ] **Resource usage validation** - Verify accurate resource usage tracking and limits
- [ ] **Integration testing** - Test all external system integrations (pgbouncer, OS monitoring)
- [ ] **Documentation completion** - Complete all production deployment and operational documentation

---

---

## 🔒 **PHASE 4 PRODUCTION ENHANCEMENTS**

### 17. Real Lock Detection Integration

#### **File**: `step_7_lock_monitoring.sql`
**Lines**: 245-320 (capture_lock_activity function)

**Current Code (Development)**:
```sql
-- Simulated lock detection - needs real pg_locks integration
SELECT 
    'relation'::VARCHAR(50) as lock_type,
    'AccessShareLock'::VARCHAR(50) as lock_mode,
    'auth.user_h'::VARCHAR(200) as relation_name,
    true as lock_granted,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - CURRENT_TIMESTAMP))::INTEGER as lock_duration_seconds
```

**Production Code Required**:
```sql
-- Real lock detection from pg_locks and pg_stat_activity
SELECT 
    pl.locktype,
    pl.mode,
    COALESCE(c.relname, pl.locktype) as relation_name,
    pl.granted,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(sa.query_start, sa.xact_start)))::INTEGER as lock_duration_seconds,
    sa.pid,
    sa.usename,
    sa.application_name,
    sa.client_addr,
    sa.query,
    sa.state
FROM pg_locks pl
LEFT JOIN pg_stat_activity sa ON pl.pid = sa.pid
LEFT JOIN pg_class c ON pl.relation = c.oid
WHERE sa.backend_type = 'client backend'
AND sa.pid != pg_backend_pid()
```

### 18. Blocking Session Detection Enhancement

#### **File**: `step_8_blocking_detection.sql`
**Lines**: 45-120 (detect_blocking_sessions function)

**Current Code (Development)**:
```sql
-- Basic blocking detection - needs enhancement for production
AND (p_tenant_hk IS NULL OR EXISTS (
    SELECT 1 FROM auth.user_h uh 
    WHERE uh.tenant_hk = p_tenant_hk 
    AND uh.user_bk = blocking.usename
))
```

**Production Code Required**:
```sql
-- Enhanced tenant-aware blocking detection with user validation
AND (p_tenant_hk IS NULL OR EXISTS (
    SELECT 1 FROM auth.user_h uh
    JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
    WHERE uh.tenant_hk = p_tenant_hk 
    AND ups.username = blocking.usename
    AND ups.load_end_date IS NULL
    AND ups.is_active = true
))
-- Add application filtering for known system processes
AND blocking.application_name NOT IN ('pg_dump', 'pg_restore', 'maintenance_worker')
-- Add query pattern filtering to avoid false positives
AND NOT (blocking.query LIKE 'VACUUM%' OR blocking.query LIKE 'ANALYZE%')
```

### 19. Deadlock Detection Accuracy

#### **File**: `step_8_blocking_detection.sql`
**Lines**: 180-280 (detect_deadlocks function)

**Current Code (Development)**:
```sql
-- Simplified deadlock detection - needs real cycle detection
WHERE lc.blocker_pid = lc.original_waiter -- Cycle detected
```

**Production Code Required**:
```sql
-- Enhanced deadlock cycle detection with validation
WHERE lc.blocker_pid = lc.original_waiter -- Cycle detected
AND lc.chain_length >= 2 -- Minimum valid deadlock chain
AND NOT EXISTS (
    -- Exclude false positives from maintenance operations
    SELECT 1 FROM pg_stat_activity sa 
    WHERE sa.pid = ANY(lc.pid_chain)
    AND (sa.application_name LIKE '%maintenance%' 
         OR sa.query LIKE 'VACUUM%'
         OR sa.query LIKE 'REINDEX%')
)
-- Validate that all sessions in chain are still active
AND (SELECT COUNT(*) FROM pg_stat_activity sa WHERE sa.pid = ANY(lc.pid_chain)) = array_length(lc.pid_chain, 1)
```

### 20. Lock Impact Scoring Enhancement

#### **File**: `step_7_lock_monitoring.sql`
**Lines**: 420-480 (lock impact calculation)

**Current Code (Development)**:
```sql
-- Basic impact scoring - needs business context
v_impact_score := LEAST(100.0, GREATEST(0.0,
    (v_lock_duration * 2.0) + -- Duration impact
    (CASE WHEN v_lock_granted = false THEN 20.0 ELSE 0.0 END) -- Waiting penalty
));
```

**Production Code Required**:
```sql
-- Enhanced impact scoring with business context
v_impact_score := LEAST(100.0, GREATEST(0.0,
    (v_lock_duration * 2.0) + -- Duration impact
    (CASE WHEN v_lock_granted = false THEN 20.0 ELSE 0.0 END) + -- Waiting penalty
    (CASE WHEN v_table_name IN ('user_profile_s', 'transaction_details_s', 'asset_details_s') THEN 15.0 ELSE 5.0 END) + -- Business critical tables
    (CASE WHEN v_lock_mode IN ('AccessExclusiveLock', 'ExclusiveLock') THEN 25.0 ELSE 0.0 END) + -- Exclusive lock penalty
    (CASE WHEN EXTRACT(HOUR FROM CURRENT_TIMESTAMP) BETWEEN 8 AND 18 THEN 10.0 ELSE 0.0 END) + -- Business hours impact
    (CASE WHEN v_user_name IN (SELECT username FROM auth.user_profile_s WHERE user_type = 'ADMIN') THEN -5.0 ELSE 0.0 END) -- Admin user adjustment
));
```

### 21. Auto-Resolution Safety Enhancement

#### **File**: `step_8_blocking_detection.sql`
**Lines**: 520-600 (auto_resolve_blocking function)

**Current Code (Development)**:
```sql
-- Basic safety check - needs production safeguards
AND bss.is_superuser = false -- Don't auto-kill superuser sessions
```

**Production Code Required**:
```sql
-- Enhanced safety checks for production
AND bss.is_superuser = false -- Don't auto-kill superuser sessions
AND bss.user_name NOT IN (
    SELECT username FROM auth.user_profile_s ups
    JOIN auth.user_role_l url ON ups.user_hk = url.user_hk
    JOIN auth.role_h rh ON url.role_hk = rh.role_hk
    WHERE rh.role_bk IN ('SYSTEM_ADMIN', 'DATABASE_ADMIN', 'BACKUP_OPERATOR')
    AND ups.load_end_date IS NULL
) -- Don't auto-kill admin users
AND bss.application_name NOT IN ('pgAdmin', 'DataGrip', 'psql', 'pg_dump', 'pg_restore') -- Don't auto-kill admin tools
AND bss.current_query NOT LIKE 'BACKUP%' -- Don't interrupt backup operations
AND bss.current_query NOT LIKE 'RESTORE%' -- Don't interrupt restore operations
AND EXTRACT(HOUR FROM CURRENT_TIMESTAMP) NOT BETWEEN 2 AND 6 -- Avoid maintenance window
AND EXISTS (
    -- Verify blocking is still occurring
    SELECT 1 FROM pg_stat_activity sa WHERE sa.pid = bss.session_pid AND sa.state = 'active'
)
```

### 22. Lock Monitoring Performance Optimization

#### **File**: `step_7_lock_monitoring.sql`
**Lines**: 150-200 (monitoring frequency)

**Current Code (Development)**:
```sql
-- Capture all lock activity - may be too frequent for production
SELECT * FROM pg_locks pl
JOIN pg_stat_activity sa ON pl.pid = sa.pid
```

**Production Code Required**:
```sql
-- Optimized lock monitoring with filtering
SELECT * FROM pg_locks pl
JOIN pg_stat_activity sa ON pl.pid = sa.pid
WHERE sa.backend_type = 'client backend'
AND sa.state IN ('active', 'idle in transaction')
AND (
    pl.granted = false -- Always capture waiting locks
    OR pl.mode IN ('AccessExclusiveLock', 'ExclusiveLock', 'ShareUpdateExclusiveLock') -- Capture potentially blocking locks
    OR EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(sa.query_start, sa.xact_start))) > 30 -- Capture long-running locks
)
-- Add sampling for high-frequency monitoring
AND (EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::INTEGER % 5 = 0 OR pl.granted = false) -- Sample every 5 seconds unless waiting
```

### 23. Dashboard Query Optimization

#### **File**: `step_7_lock_monitoring.sql`
**Lines**: 650-750 (dashboard views)

**Current Code (Development)**:
```sql
-- Basic dashboard queries - need optimization for production
FROM lock_monitoring.lock_activity_h lah
JOIN lock_monitoring.lock_activity_s las ON lah.lock_activity_hk = las.lock_activity_hk
WHERE las.load_end_date IS NULL
```

**Production Code Required**:
```sql
-- Optimized dashboard queries with proper indexing and filtering
FROM lock_monitoring.lock_activity_h lah
JOIN lock_monitoring.lock_activity_s las ON lah.lock_activity_hk = las.lock_activity_hk
WHERE las.load_end_date IS NULL
AND las.lock_acquired_time >= CURRENT_TIMESTAMP - INTERVAL '1 hour' -- Limit time window
AND (las.lock_granted = false OR las.lock_impact_score > 20) -- Focus on significant locks
-- Add tenant filtering for multi-tenant dashboards
AND (CURRENT_SETTING('app.current_tenant_id', true) IS NULL 
     OR lah.tenant_hk = decode(CURRENT_SETTING('app.current_tenant_id'), 'hex'))
```

### 24. Alert Integration Enhancement

#### **File**: `step_7_lock_monitoring.sql`
**Lines**: 800-850 (alert generation)

**Current Code (Development)**:
```sql
-- Basic alert generation - needs integration with monitoring system
IF v_critical_issues > 10 THEN
    v_recommendations := array_append(v_recommendations, 'Critical lock contention - consider emergency intervention');
END IF;
```

**Production Code Required**:
```sql
-- Enhanced alert integration with monitoring system
IF v_critical_issues > 10 THEN
    v_recommendations := array_append(v_recommendations, 'Critical lock contention - consider emergency intervention');
    
    -- Integrate with monitoring system alerts
    INSERT INTO monitoring.alert_instance_s (
        alert_instance_hk, load_date, load_end_date, hash_diff,
        alert_configuration_hk, alert_timestamp, alert_severity,
        alert_message, alert_value, threshold_exceeded,
        notification_sent, escalation_level, acknowledgment_required,
        auto_resolution_attempted, affected_tenants, additional_context,
        record_source
    ) VALUES (
        util.hash_binary('LOCK_CRITICAL_' || CURRENT_TIMESTAMP::text),
        util.current_load_date(), NULL,
        util.hash_binary('LOCK_CRITICAL_ALERT'),
        (SELECT alert_configuration_hk FROM monitoring.alert_configuration_h WHERE alert_configuration_bk = 'LOCK_CRITICAL_BLOCKING'),
        CURRENT_TIMESTAMP, 'CRITICAL',
        'Critical lock contention detected: ' || v_critical_issues || ' critical blocking situations',
        v_critical_issues, true, false, 3, true, false,
        ARRAY[COALESCE(encode(p_tenant_hk, 'hex'), 'SYSTEM')],
        jsonb_build_object('blocking_sessions', v_total_blocking, 'deadlocks', v_total_deadlocks),
        'LOCK_MONITOR'
    );
END IF;
```

---

## 📋 **PHASE 4 IMPLEMENTATION PRIORITY**

### **Critical Production Modifications (Week 1)**
1. **Real Lock Detection Integration** - Replace simulated lock data with actual pg_locks queries
2. **Enhanced Blocking Detection** - Add tenant validation and application filtering
3. **Auto-Resolution Safety** - Implement comprehensive safety checks for session termination
4. **Performance Optimization** - Add filtering and sampling to reduce monitoring overhead

### **Important Enhancements (Week 2)**
1. **Deadlock Detection Accuracy** - Enhance cycle detection with validation
2. **Lock Impact Scoring** - Add business context and table criticality
3. **Dashboard Optimization** - Optimize queries for production performance
4. **Alert Integration** - Connect with existing monitoring and alerting infrastructure

### **Monitoring Integration (Week 3)**
1. **Real-time Metrics** - Integrate with system monitoring tools
2. **Notification Channels** - Connect to email, Slack, and PagerDuty systems
3. **Automated Reporting** - Generate daily/weekly lock analysis reports
4. **Capacity Planning** - Add trending and forecasting capabilities

### **Production Validation (Week 4)**
1. **Load Testing** - Validate performance under production load
2. **Failover Testing** - Test monitoring during database failover scenarios
3. **Security Validation** - Ensure proper access controls and audit logging
4. **Documentation** - Complete operational runbooks and troubleshooting guides

---

This comprehensive enhancement guide ensures all development/demonstration code is properly converted to production-ready implementation with real system integration, proper security, and operational excellence. 