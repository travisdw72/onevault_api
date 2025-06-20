# User Guide - Enterprise Database Tracking System

## Overview

The Enterprise Database Tracking System provides comprehensive monitoring and auditing of all database operations in your One Vault environment. This guide shows you how to use the system effectively for daily operations, troubleshooting, and compliance reporting.

## 🚀 Quick Start

### Viewing System Status
```sql
-- Get an overview of your tracking system
SELECT * FROM script_tracking.get_enterprise_dashboard();
```

### Checking Recent Activity
```sql
-- View recent database operations
SELECT 
    script_name,
    script_type,
    execution_status,
    execution_timestamp,
    execution_duration_ms
FROM script_tracking.script_execution_s
WHERE execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY execution_timestamp DESC
LIMIT 20;
```

## 📊 Enterprise Dashboard

### Main Dashboard Function
The enterprise dashboard provides a comprehensive overview of system status, performance metrics, and recent activity.

```sql
-- Complete system overview
SELECT * FROM script_tracking.get_enterprise_dashboard();
```

**Dashboard Components:**
- **Total Operations**: Count of all tracked operations
- **Success Rate**: Percentage of successful operations  
- **Average Duration**: Mean execution time for operations
- **Recent Activity**: Summary of last 24 hours
- **System Health**: Overall system status indicators
- **Performance Trends**: Key performance metrics

### Interpreting Dashboard Results
```sql
-- Sample dashboard output explanation
metric_name              | metric_value | metric_unit | status
------------------------|--------------| ------------|--------
total_operations_24h    | 1,247        | count       | NORMAL
success_rate_24h        | 99.8         | percentage  | EXCELLENT  
avg_duration_ms         | 23.5         | milliseconds| GOOD
failed_operations_24h   | 3            | count       | WARNING
system_health_score     | 98.5         | percentage  | EXCELLENT
```

## 🔄 Manual Operation Tracking

### Basic Manual Tracking
Use manual tracking for maintenance operations, data migrations, and custom procedures.

```sql
-- Pattern 1: Simple operation tracking
DO $$
DECLARE
    operation_id BYTEA;
BEGIN
    -- Start tracking
    operation_id := script_tracking.track_operation('Database Maintenance', 'MAINTENANCE');
    
    -- Your operation here
    VACUUM ANALYZE;
    REINDEX DATABASE one_vault;
    
    -- Mark as completed successfully
    PERFORM script_tracking.complete_operation(operation_id, true);
    
    RAISE NOTICE 'Maintenance operation completed and tracked.';
END $$;
```

```sql
-- Pattern 2: Operation with error handling
DO $$
DECLARE
    operation_id BYTEA;
    operation_success BOOLEAN := false;
BEGIN
    -- Start tracking
    operation_id := script_tracking.track_operation('Data Migration', 'MIGRATION');
    
    BEGIN
        -- Your risky operation here
        INSERT INTO target_table SELECT * FROM source_table;
        operation_success := true;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Operation failed: %', SQLERRM;
        operation_success := false;
    END;
    
    -- Complete with appropriate status
    PERFORM script_tracking.complete_operation(operation_id, operation_success);
END $$;
```

### Advanced Manual Tracking
```sql
-- Track operation with additional metadata
DO $$
DECLARE
    operation_id BYTEA;
    start_time TIMESTAMP;
    record_count INTEGER;
BEGIN
    start_time := CURRENT_TIMESTAMP;
    
    -- Start tracking with metadata
    operation_id := script_tracking.track_operation('Bulk Data Import', 'DATA_IMPORT');
    
    -- Update with additional details
    UPDATE script_tracking.script_execution_s 
    SET metadata = jsonb_build_object(
        'source_file', '/data/import_20240101.csv',
        'batch_size', 10000,
        'estimated_records', 1000000,
        'import_started', start_time
    )
    WHERE script_execution_hk = operation_id AND load_end_date IS NULL;
    
    -- Your bulk operation
    -- ... import logic here ...
    
    GET DIAGNOSTICS record_count = ROW_COUNT;
    
    -- Update final metadata and complete
    UPDATE script_tracking.script_execution_s 
    SET metadata = metadata || jsonb_build_object(
        'records_processed', record_count,
        'processing_rate_per_sec', record_count / EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - start_time))
    )
    WHERE script_execution_hk = operation_id AND load_end_date IS NULL;
    
    PERFORM script_tracking.complete_operation(operation_id, true);
END $$;
```

## 🤖 Automatic DDL Tracking

### Understanding Automatic Tracking
All DDL operations are automatically tracked without any additional code required.

**Automatically Tracked Operations:**
- `CREATE` statements (tables, functions, indexes, etc.)
- `ALTER` statements (schema modifications)
- `DROP` statements (object deletion)
- `GRANT`/`REVOKE` statements (permission changes)

### Viewing Automatic DDL History
```sql
-- View all DDL operations from the last week
SELECT 
    script_name,
    script_type,
    execution_status,
    execution_timestamp,
    affected_objects,
    LEFT(sql_command, 100) as command_preview
FROM script_tracking.script_execution_s
WHERE script_type = 'DDL_AUTO'
AND execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '7 days'
ORDER BY execution_timestamp DESC;
```

### DDL Impact Analysis
```sql
-- Analyze DDL impact by operation type
SELECT 
    CASE 
        WHEN script_name LIKE '%CREATE%' THEN 'CREATE'
        WHEN script_name LIKE '%ALTER%' THEN 'ALTER'
        WHEN script_name LIKE '%DROP%' THEN 'DROP'
        ELSE 'OTHER'
    END as operation_type,
    COUNT(*) as operation_count,
    AVG(execution_duration_ms) as avg_duration_ms,
    SUM(array_length(affected_objects, 1)) as total_objects_affected
FROM script_tracking.script_execution_s
WHERE script_type = 'DDL_AUTO'
AND execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY 1
ORDER BY operation_count DESC;
```

## 📈 Reporting and Analytics

### Performance Reports
```sql
-- Performance trend analysis
SELECT * FROM script_tracking.get_performance_metrics();
```

```sql
-- Custom performance analysis  
WITH daily_stats AS (
    SELECT 
        DATE(execution_timestamp) as operation_date,
        COUNT(*) as daily_operations,
        AVG(execution_duration_ms) as avg_duration,
        COUNT(*) FILTER (WHERE execution_status = 'FAILED') as failed_operations
    FROM script_tracking.script_execution_s
    WHERE execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '30 days'
    GROUP BY DATE(execution_timestamp)
)
SELECT 
    operation_date,
    daily_operations,
    ROUND(avg_duration, 2) as avg_duration_ms,
    failed_operations,
    ROUND((daily_operations - failed_operations)::DECIMAL / daily_operations * 100, 2) as success_rate_pct
FROM daily_stats
ORDER BY operation_date DESC;
```

### Compliance and Audit Reports
```sql
-- Comprehensive audit trail for compliance
SELECT 
    script_name,
    script_type,
    execution_timestamp,
    db_session_user,
    client_ip,
    execution_status,
    affected_objects,
    CASE 
        WHEN execution_duration_ms > 10000 THEN 'LONG_RUNNING'
        WHEN execution_status = 'FAILED' THEN 'FAILED'
        ELSE 'NORMAL'
    END as audit_flag
FROM script_tracking.script_execution_s
WHERE execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '90 days'
ORDER BY execution_timestamp DESC;
```

### Error Analysis
```sql
-- Recent errors and their patterns
SELECT * FROM script_tracking.get_recent_errors(24); -- Last 24 hours
```

```sql
-- Custom error analysis
SELECT 
    script_type,
    LEFT(error_message, 100) as error_summary,
    COUNT(*) as error_count,
    MAX(execution_timestamp) as last_occurrence,
    AVG(execution_duration_ms) as avg_duration_before_failure
FROM script_tracking.script_execution_s
WHERE execution_status = 'FAILED'
AND execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '7 days'
GROUP BY script_type, LEFT(error_message, 100)
ORDER BY error_count DESC;
```

## 🔍 System Health Monitoring

### Health Check Dashboard
```sql
-- Complete system health overview
SELECT * FROM script_tracking.get_system_health();
```

### Custom Health Queries
```sql
-- Monitor operation volume trends
WITH hourly_stats AS (
    SELECT 
        DATE_TRUNC('hour', execution_timestamp) as hour,
        COUNT(*) as operations_per_hour
    FROM script_tracking.script_execution_s
    WHERE execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '24 hours'
    GROUP BY DATE_TRUNC('hour', execution_timestamp)
)
SELECT 
    hour,
    operations_per_hour,
    LAG(operations_per_hour) OVER (ORDER BY hour) as previous_hour,
    CASE 
        WHEN operations_per_hour > LAG(operations_per_hour) OVER (ORDER BY hour) * 2 
        THEN 'SPIKE_DETECTED'
        WHEN operations_per_hour < LAG(operations_per_hour) OVER (ORDER BY hour) * 0.5 
        THEN 'DROP_DETECTED'
        ELSE 'NORMAL'
    END as trend_analysis
FROM hourly_stats
ORDER BY hour DESC;
```

### Performance Monitoring
```sql
-- Identify slow operations
SELECT 
    script_name,
    script_type,
    execution_duration_ms,
    execution_timestamp,
    CASE 
        WHEN execution_duration_ms > 60000 THEN 'VERY_SLOW'
        WHEN execution_duration_ms > 10000 THEN 'SLOW'
        WHEN execution_duration_ms > 1000 THEN 'MODERATE'
        ELSE 'FAST'
    END as performance_category
FROM script_tracking.script_execution_s
WHERE execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '24 hours'
AND execution_duration_ms IS NOT NULL
ORDER BY execution_duration_ms DESC
LIMIT 20;
```

## 🔐 Security and Access Monitoring

### User Activity Tracking
```sql
-- Monitor database user activity
SELECT 
    db_session_user,
    COUNT(*) as total_operations,
    COUNT(*) FILTER (WHERE script_type = 'DDL_AUTO') as ddl_operations,
    COUNT(*) FILTER (WHERE script_type = 'MANUAL') as manual_operations,
    MAX(execution_timestamp) as last_activity,
    COUNT(DISTINCT client_ip) as unique_ip_addresses
FROM script_tracking.script_execution_s
WHERE execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '7 days'
GROUP BY db_session_user
ORDER BY total_operations DESC;
```

### Security Anomaly Detection
```sql
-- Detect unusual activity patterns
WITH user_baselines AS (
    SELECT 
        db_session_user,
        AVG(daily_operations) as avg_daily_operations,
        STDDEV(daily_operations) as stddev_daily_operations
    FROM (
        SELECT 
            db_session_user,
            DATE(execution_timestamp) as operation_date,
            COUNT(*) as daily_operations
        FROM script_tracking.script_execution_s
        WHERE execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '30 days'
        GROUP BY db_session_user, DATE(execution_timestamp)
    ) daily_stats
    GROUP BY db_session_user
),
today_activity AS (
    SELECT 
        db_session_user,
        COUNT(*) as today_operations
    FROM script_tracking.script_execution_s
    WHERE DATE(execution_timestamp) = CURRENT_DATE
    GROUP BY db_session_user
)
SELECT 
    ta.db_session_user,
    ta.today_operations,
    ub.avg_daily_operations,
    CASE 
        WHEN ta.today_operations > ub.avg_daily_operations + (2 * ub.stddev_daily_operations)
        THEN 'ANOMALY_HIGH'
        WHEN ta.today_operations < ub.avg_daily_operations - (2 * ub.stddev_daily_operations)
        THEN 'ANOMALY_LOW'
        ELSE 'NORMAL'
    END as activity_assessment
FROM today_activity ta
JOIN user_baselines ub ON ta.db_session_user = ub.db_session_user
WHERE ub.stddev_daily_operations > 0
ORDER BY ta.today_operations DESC;
```

## 🧹 Data Maintenance

### Cleanup Operations
```sql
-- Clean up old tracking data (retain last 365 days)
SELECT script_tracking.cleanup_old_data(365);
```

### Archive Historical Data
```sql
-- Archive old data to separate table before cleanup
CREATE TABLE script_tracking.script_execution_archive_2024 AS
SELECT * FROM script_tracking.script_execution_s
WHERE execution_timestamp < CURRENT_TIMESTAMP - INTERVAL '365 days';

-- Verify archive
SELECT 
    COUNT(*) as archived_records,
    MIN(execution_timestamp) as oldest_record,
    MAX(execution_timestamp) as newest_record
FROM script_tracking.script_execution_archive_2024;

-- Then cleanup
SELECT script_tracking.cleanup_old_data(365);
```

### System Maintenance
```sql
-- Regular maintenance operations
DO $$
DECLARE
    maintenance_id BYTEA;
BEGIN
    maintenance_id := script_tracking.track_operation('System Maintenance', 'MAINTENANCE');
    
    -- Analyze tracking tables for optimal performance
    ANALYZE script_tracking.script_execution_h;
    ANALYZE script_tracking.script_execution_s;
    
    -- Reindex if needed (run during maintenance windows)
    -- REINDEX TABLE script_tracking.script_execution_s;
    
    -- Update table statistics
    UPDATE pg_stat_user_tables SET n_tup_ins = 0 WHERE schemaname = 'script_tracking';
    
    PERFORM script_tracking.complete_operation(maintenance_id, true);
    
    RAISE NOTICE 'System maintenance completed successfully.';
END $$;
```

## 📋 Best Practices

### 1. Regular Monitoring
- **Daily**: Check dashboard for system health
- **Weekly**: Review performance trends and error patterns  
- **Monthly**: Analyze compliance reports and cleanup old data
- **Quarterly**: Review and optimize tracking configuration

### 2. Operation Naming Conventions
```sql
-- Good naming examples
operation_id := script_tracking.track_operation('User_Migration_Batch_2024Q1', 'MIGRATION');
operation_id := script_tracking.track_operation('Weekly_Index_Maintenance', 'MAINTENANCE');
operation_id := script_tracking.track_operation('Compliance_Report_Generation', 'REPORTING');

-- Avoid generic names
-- operation_id := script_tracking.track_operation('Operation', 'MISC'); -- Too generic
```

### 3. Error Handling
```sql
-- Always handle errors in manual tracking
DO $$
DECLARE
    operation_id BYTEA;
    operation_successful BOOLEAN := false;
BEGIN
    operation_id := script_tracking.track_operation('Risky Operation', 'MAINTENANCE');
    
    BEGIN
        -- Your operation code
        operation_successful := true;
    EXCEPTION WHEN OTHERS THEN
        -- Log the error details
        UPDATE script_tracking.script_execution_s 
        SET error_message = SQLERRM,
            metadata = jsonb_build_object('error_code', SQLSTATE)
        WHERE script_execution_hk = operation_id AND load_end_date IS NULL;
        
        operation_successful := false;
    END;
    
    PERFORM script_tracking.complete_operation(operation_id, operation_successful);
END $$;
```

### 4. Metadata Usage
```sql
-- Use metadata for additional context
operation_id := script_tracking.track_operation('Data Export', 'EXPORT');

UPDATE script_tracking.script_execution_s 
SET metadata = jsonb_build_object(
    'export_format', 'CSV',
    'destination', 's3://bucket/exports/',
    'table_name', 'customer_data',
    'row_count_estimate', 1000000,
    'compression', 'gzip'
)
WHERE script_execution_hk = operation_id AND load_end_date IS NULL;
```

## 🚨 Troubleshooting Common Issues

### Performance Issues
```sql
-- If tracking seems slow, check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE schemaname = 'script_tracking'
ORDER BY idx_scan DESC;
```

### Missing Operations
```sql
-- Verify event triggers are active
SELECT evtname, evtevent, evtenabled 
FROM pg_event_trigger
WHERE evtname LIKE 'et_%';

-- Should show:
-- et_ddl_command_start | ddl_command_start | O
-- et_ddl_command_end   | ddl_command_end   | O  
-- et_sql_drop          | sql_drop          | O
```

### Data Inconsistencies
```sql
-- Check for orphaned records
SELECT COUNT(*) as orphaned_satellites
FROM script_tracking.script_execution_s s
LEFT JOIN script_tracking.script_execution_h h 
    ON s.script_execution_hk = h.script_execution_hk
WHERE h.script_execution_hk IS NULL;
```

## 🎯 Advanced Usage

### Custom Reporting Functions
```sql
-- Create custom views for specific reporting needs
CREATE OR REPLACE VIEW script_tracking.monthly_summary AS
SELECT 
    DATE_TRUNC('month', execution_timestamp) as month,
    script_type,
    COUNT(*) as operation_count,
    AVG(execution_duration_ms) as avg_duration,
    COUNT(*) FILTER (WHERE execution_status = 'FAILED') as failure_count
FROM script_tracking.script_execution_s
GROUP BY DATE_TRUNC('month', execution_timestamp), script_type
ORDER BY month DESC, script_type;
```

### Integration with External Monitoring
```sql
-- Export metrics for external monitoring systems
SELECT 
    'script_tracking.operations_per_hour' as metric_name,
    COUNT(*) as metric_value,
    'operations' as metric_unit,
    DATE_TRUNC('hour', CURRENT_TIMESTAMP) as timestamp
FROM script_tracking.script_execution_s
WHERE execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '1 hour';
```

## 📞 Getting Help

### Self-Service Diagnostics
1. **System Health**: `SELECT * FROM script_tracking.get_system_health()`
2. **Recent Errors**: `SELECT * FROM script_tracking.get_recent_errors(24)`
3. **Performance Check**: `SELECT * FROM script_tracking.get_performance_metrics()`

### Common Query Patterns
- **Find specific operation**: Search by script name pattern
- **Performance analysis**: Group by time periods and analyze trends
- **Error investigation**: Filter by execution_status = 'FAILED'
- **User activity**: Group by db_session_user

**Your enterprise tracking system is now ready for daily operations and comprehensive database monitoring!** 