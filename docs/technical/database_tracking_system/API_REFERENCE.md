# API Reference - Enterprise Database Tracking System

## Overview

This document provides complete API documentation for the Enterprise Database Tracking System, including all functions, procedures, views, and data structures.

## 📋 Table of Contents

- [Core Tracking Functions](#core-tracking-functions)
- [Enterprise Dashboard Functions](#enterprise-dashboard-functions)
- [System Health Functions](#system-health-functions)
- [Authentication Wrapper Functions](#authentication-wrapper-functions)
- [Utility Functions](#utility-functions)
- [Data Structures](#data-structures)
- [Event Triggers](#event-triggers)
- [Views](#views)

---

## 🔧 Core Tracking Functions

### `script_tracking.track_operation()`

**Purpose**: Start tracking a manual operation

**Signature**:
```sql
script_tracking.track_operation(
    p_script_name VARCHAR(255),
    p_script_type VARCHAR(50) DEFAULT 'MANUAL'
) RETURNS BYTEA
```

**Parameters**:
- `p_script_name` (VARCHAR): Name/description of the operation being tracked
- `p_script_type` (VARCHAR): Type classification (MANUAL, MAINTENANCE, MIGRATION, etc.)

**Returns**: `BYTEA` - Hash key identifying the tracked operation

**Example**:
```sql
-- Start tracking a maintenance operation
DECLARE
    operation_id BYTEA;
BEGIN
    operation_id := script_tracking.track_operation('Weekly Database Maintenance', 'MAINTENANCE');
    -- Use operation_id to complete the operation later
END;
```

**Notes**:
- Creates a new tracking record in RUNNING status
- Automatically captures session user, IP address, and timestamp
- Returns unique hash key for operation completion

---

### `script_tracking.complete_operation()`

**Purpose**: Mark a tracked operation as completed

**Signature**:
```sql
script_tracking.complete_operation(
    p_execution_hk BYTEA,
    p_success BOOLEAN DEFAULT true,
    p_error_message TEXT DEFAULT NULL
) RETURNS BOOLEAN
```

**Parameters**:
- `p_execution_hk` (BYTEA): Hash key from `track_operation()`
- `p_success` (BOOLEAN): Whether operation succeeded
- `p_error_message` (TEXT): Error details if operation failed

**Returns**: `BOOLEAN` - True if completion was recorded successfully

**Example**:
```sql
-- Complete an operation successfully
PERFORM script_tracking.complete_operation(operation_id, true);

-- Complete an operation with failure
PERFORM script_tracking.complete_operation(operation_id, false, 'Connection timeout');
```

**Notes**:
- Updates execution status to COMPLETED or FAILED
- Records execution duration automatically
- Closes the temporal tracking record

---

## 📊 Enterprise Dashboard Functions

### `script_tracking.get_enterprise_dashboard()`

**Purpose**: Get comprehensive system overview and metrics

**Signature**:
```sql
script_tracking.get_enterprise_dashboard()
RETURNS TABLE (
    metric_name VARCHAR(100),
    metric_value DECIMAL(15,2),
    metric_unit VARCHAR(20),
    status VARCHAR(20),
    last_updated TIMESTAMP WITH TIME ZONE
)
```

**Returns**: Table with system metrics and status information

**Example**:
```sql
-- Get complete dashboard
SELECT * FROM script_tracking.get_enterprise_dashboard();

-- Filter specific metrics
SELECT metric_name, metric_value, status 
FROM script_tracking.get_enterprise_dashboard()
WHERE metric_name LIKE '%success_rate%';
```

**Sample Output**:
```
metric_name              | metric_value | metric_unit | status
------------------------|--------------| ------------|--------
total_operations_24h    | 1,247        | count       | NORMAL
success_rate_24h        | 99.8         | percentage  | EXCELLENT  
avg_duration_ms         | 23.5         | milliseconds| GOOD
failed_operations_24h   | 3            | count       | WARNING
system_health_score     | 98.5         | percentage  | EXCELLENT
```

---

### `script_tracking.get_execution_history()`

**Purpose**: Get historical execution data for analysis

**Signature**:
```sql
script_tracking.get_execution_history(
    p_days INTEGER DEFAULT 7
)
RETURNS TABLE (
    script_name VARCHAR(255),
    script_type VARCHAR(50),
    execution_status VARCHAR(20),
    execution_timestamp TIMESTAMP WITH TIME ZONE,
    execution_duration_ms INTEGER,
    db_session_user VARCHAR(100),
    affected_objects TEXT[]
)
```

**Parameters**:
- `p_days` (INTEGER): Number of days of history to return

**Example**:
```sql
-- Get last 30 days of execution history
SELECT * FROM script_tracking.get_execution_history(30)
ORDER BY execution_timestamp DESC;
```

---

### `script_tracking.get_performance_metrics()`

**Purpose**: Get detailed performance metrics and trends

**Signature**:
```sql
script_tracking.get_performance_metrics()
RETURNS TABLE (
    metric_category VARCHAR(50),
    metric_name VARCHAR(100),
    current_value DECIMAL(15,2),
    trend_direction VARCHAR(10),
    performance_rating VARCHAR(20)
)
```

**Example**:
```sql
-- Get performance analysis
SELECT * FROM script_tracking.get_performance_metrics()
WHERE performance_rating IN ('POOR', 'WARNING');
```

---

## 🔍 System Health Functions

### `script_tracking.get_system_health()`

**Purpose**: Get comprehensive system health status

**Signature**:
```sql
script_tracking.get_system_health()
RETURNS TABLE (
    health_category VARCHAR(50),
    health_metric VARCHAR(100),
    current_status VARCHAR(20),
    details TEXT,
    last_checked TIMESTAMP WITH TIME ZONE
)
```

**Example**:
```sql
-- Check overall system health
SELECT * FROM script_tracking.get_system_health();

-- Check specific health categories
SELECT * FROM script_tracking.get_system_health()
WHERE health_category = 'PERFORMANCE';
```

---

### `script_tracking.get_recent_errors()`

**Purpose**: Get recent error details for troubleshooting

**Signature**:
```sql
script_tracking.get_recent_errors(
    p_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
    script_name VARCHAR(255),
    error_message TEXT,
    execution_timestamp TIMESTAMP WITH TIME ZONE,
    db_session_user VARCHAR(100),
    client_ip INET,
    affected_objects TEXT[],
    metadata JSONB
)
```

**Parameters**:
- `p_hours` (INTEGER): Number of hours to look back for errors

**Example**:
```sql
-- Get errors from last 8 hours
SELECT * FROM script_tracking.get_recent_errors(8)
ORDER BY execution_timestamp DESC;
```

---

### `script_tracking.cleanup_old_data()`

**Purpose**: Remove old tracking data beyond retention period

**Signature**:
```sql
script_tracking.cleanup_old_data(
    p_retention_days INTEGER DEFAULT 365
) RETURNS INTEGER
```

**Parameters**:
- `p_retention_days` (INTEGER): Number of days to retain data

**Returns**: `INTEGER` - Number of records deleted

**Example**:
```sql
-- Clean up data older than 180 days
SELECT script_tracking.cleanup_old_data(180);
```

---

## 🔐 Authentication Wrapper Functions

### `auth.login_user_tracking()`

**Purpose**: Enhanced user login with tracking

**Signature**:
```sql
auth.login_user_tracking(
    p_email VARCHAR(255),
    p_password VARCHAR(255),
    p_tenant_hk BYTEA
) RETURNS JSONB
```

**Parameters**:
- `p_email` (VARCHAR): User email address
- `p_password` (VARCHAR): User password
- `p_tenant_hk` (BYTEA): Tenant context

**Returns**: `JSONB` - Login result with tracking information

**Example**:
```sql
-- Login with tracking
SELECT * FROM auth.login_user_tracking(
    'user@example.com', 
    'password123', 
    '\x123456789abcdef'::bytea
);
```

---

### `auth.register_user_tracking()`

**Purpose**: Enhanced user registration with tracking

**Signature**:
```sql
auth.register_user_tracking(
    p_user_data JSONB
) RETURNS JSONB
```

**Parameters**:
- `p_user_data` (JSONB): User registration data

**Returns**: `JSONB` - Registration result with tracking information

**Example**:
```sql
-- Register user with tracking
SELECT * FROM auth.register_user_tracking(
    '{"email": "new@example.com", "password": "secure123", "tenant_id": "123"}'::jsonb
);
```

---

## 🛠️ Utility Functions

### `script_tracking.generate_unique_script_name()`

**Purpose**: Generate unique script name with timestamp

**Signature**:
```sql
script_tracking.generate_unique_script_name(
    p_base_name VARCHAR(200)
) RETURNS VARCHAR(255)
```

**Parameters**:
- `p_base_name` (VARCHAR): Base name for the script

**Returns**: `VARCHAR(255)` - Unique script name

**Example**:
```sql
-- Generate unique name
SELECT script_tracking.generate_unique_script_name('Database Backup');
-- Returns: 'Database Backup_2024-01-15_14:30:25.123456_abc123'
```

---

### `script_tracking.calculate_hash_key()`

**Purpose**: Calculate SHA-256 hash key for business key

**Signature**:
```sql
script_tracking.calculate_hash_key(
    p_business_key VARCHAR(255)
) RETURNS BYTEA
```

**Parameters**:
- `p_business_key` (VARCHAR): Business key to hash

**Returns**: `BYTEA` - SHA-256 hash

**Example**:
```sql
-- Calculate hash key
SELECT script_tracking.calculate_hash_key('SCRIPT_20240115_143025');
```

---

### `script_tracking.run_migration_enterprise()`

**Purpose**: Execute database migration with full tracking

**Signature**:
```sql
script_tracking.run_migration_enterprise(
    p_migration_file VARCHAR(255),
    p_migration_version VARCHAR(50)
) RETURNS TABLE (
    migration_status VARCHAR(20),
    execution_time_ms INTEGER,
    objects_affected INTEGER,
    error_details TEXT
)
```

**Parameters**:
- `p_migration_file` (VARCHAR): Migration file path
- `p_migration_version` (VARCHAR): Migration version identifier

**Example**:
```sql
-- Run migration with tracking
SELECT * FROM script_tracking.run_migration_enterprise(
    '/migrations/V001_add_user_table.sql',
    'V001'
);
```

---

## 📁 Data Structures

### Hub Table: `script_tracking.script_execution_h`

```sql
CREATE TABLE script_tracking.script_execution_h (
    script_execution_hk BYTEA PRIMARY KEY,
    script_execution_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    record_source VARCHAR(100) NOT NULL
);
```

**Columns**:
- `script_execution_hk`: SHA-256 hash key (primary key)
- `script_execution_bk`: Business key (script name + timestamp)
- `tenant_hk`: Tenant isolation key (nullable for system operations)
- `load_date`: Data Vault temporal tracking
- `record_source`: Source system identifier

---

### Satellite Table: `script_tracking.script_execution_s`

```sql
CREATE TABLE script_tracking.script_execution_s (
    script_execution_hk BYTEA NOT NULL,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
    load_end_date TIMESTAMP WITH TIME ZONE,
    hash_diff BYTEA NOT NULL,
    version_number BIGINT DEFAULT nextval('script_tracking.version_sequence'),
    script_name VARCHAR(255) NOT NULL,
    script_type VARCHAR(50) DEFAULT 'MANUAL',
    execution_status VARCHAR(20) DEFAULT 'RUNNING',
    execution_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    execution_duration_ms INTEGER,
    db_session_user VARCHAR(100) DEFAULT SESSION_USER,
    client_ip INET DEFAULT inet_client_addr(),
    affected_objects TEXT[],
    sql_command TEXT,
    error_message TEXT,
    metadata JSONB,
    record_source VARCHAR(100) NOT NULL,
    PRIMARY KEY (script_execution_hk, load_date)
);
```

**Key Columns**:
- `execution_status`: RUNNING, COMPLETED, FAILED
- `script_type`: MANUAL, DDL_AUTO, MAINTENANCE, MIGRATION, etc.
- `metadata`: Flexible JSONB field for additional data
- `affected_objects`: Array of database objects modified

---

## ⚡ Event Triggers

### `et_ddl_command_start`

**Purpose**: Captures DDL operation initiation

**Events**: `ddl_command_start`

**Function**: `script_tracking.event_trigger_ddl_start()`

**Behavior**:
- Automatically tracks all DDL operations
- Records operation start time
- Captures SQL command text

---

### `et_ddl_command_end`

**Purpose**: Records DDL operation completion

**Events**: `ddl_command_end`

**Function**: `script_tracking.event_trigger_ddl_end()`

**Behavior**:
- Updates operation with completion status
- Records affected objects
- Calculates execution duration

---

### `et_sql_drop`

**Purpose**: Tracks DROP operations

**Events**: `sql_drop`

**Function**: `script_tracking.event_trigger_sql_drop()`

**Behavior**:
- Specifically handles DROP statements
- Records objects being dropped
- Provides additional drop-specific metadata

---

## 📊 Views and Reporting

### Status Constants

**Execution Status Values**:
- `RUNNING`: Operation in progress
- `COMPLETED`: Operation finished successfully
- `FAILED`: Operation failed with error

**Script Type Values**:
- `MANUAL`: Manually tracked operation
- `DDL_AUTO`: Automatically tracked DDL
- `MAINTENANCE`: System maintenance
- `MIGRATION`: Database migration
- `BACKUP`: Backup operation
- `REPORTING`: Report generation

**Performance Rating Values**:
- `EXCELLENT`: >95% success rate, <100ms avg duration
- `GOOD`: >90% success rate, <500ms avg duration
- `WARNING`: >80% success rate, <1000ms avg duration
- `POOR`: <80% success rate or >1000ms avg duration

---

## 🔗 Function Dependencies

### Required Functions
The tracking system depends on these existing functions:
- `util.current_load_date()`: Data Vault temporal function
- `util.log_audit_event()`: External audit logging
- `util.hash_binary()`: Hash key generation

### Extension Dependencies
- `pgcrypto`: For SHA-256 hash generation
- Standard PostgreSQL functions for temporal and networking operations

---

## 📝 Usage Patterns

### Basic Operation Tracking
```sql
-- Manual operation pattern
operation_id := script_tracking.track_operation('Operation Name', 'OPERATION_TYPE');
-- ... perform operation ...
PERFORM script_tracking.complete_operation(operation_id, success_flag);
```

### Dashboard Monitoring
```sql
-- Regular monitoring pattern
SELECT * FROM script_tracking.get_enterprise_dashboard();
SELECT * FROM script_tracking.get_system_health();
SELECT * FROM script_tracking.get_recent_errors(24);
```

### Performance Analysis
```sql
-- Performance analysis pattern
SELECT * FROM script_tracking.get_performance_metrics();
SELECT * FROM script_tracking.get_execution_history(30);
```

---

## 🚨 Error Handling

### Common Error Codes
- `23505`: Duplicate key violation (temporary, retry)
- `42883`: Function does not exist (missing dependencies)
- `42501`: Permission denied (insufficient privileges)

### Error Response Format
```json
{
  "success": false,
  "error_code": "23505",
  "error_message": "Operation failed due to constraint violation",
  "details": {
    "operation_id": "abc123...",
    "timestamp": "2024-01-15T14:30:25Z",
    "suggestions": ["Retry operation", "Check for concurrent operations"]
  }
}
```

---

## 📋 API Usage Guidelines

### Best Practices
1. **Always handle errors** in manual tracking operations
2. **Use descriptive names** for tracked operations
3. **Include metadata** for complex operations
4. **Monitor system health** regularly
5. **Clean up old data** periodically

### Performance Considerations
- Dashboard functions are optimized for frequent calls
- History functions may be slower for large date ranges
- Cleanup operations should run during maintenance windows
- Event triggers add minimal overhead (<5ms per DDL)

### Security Notes
- All tracking preserves user session information
- IP addresses are captured for audit trails
- Tenant isolation is enforced at all levels
- Sensitive data should not be stored in metadata

**Complete API documentation for the Enterprise Database Tracking System. All functions are tested and production-ready.** 