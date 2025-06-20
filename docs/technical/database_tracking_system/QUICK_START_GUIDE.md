# Quick Start Guide - Database Tracking System
## For Non-Database Engineers

### What This System Does
- **Automatically tracks** every database change (CREATE TABLE, ALTER, etc.)
- **Manually tracks** your operations (backups, maintenance, reports)
- **Shows you a dashboard** of what's happening in your database
- **Alerts you** when things go wrong

---

## 🚀 **Option 1: Just Look at What's Happening (Read Only)**

### See What's Been Tracked
```sql
-- Copy/paste this in your database tool
SELECT * FROM script_tracking.get_enterprise_dashboard();
```

**You'll see output like:**
```
metric_category | metric_name              | metric_value | metric_trend | alert_level
----------------|--------------------------|--------------|--------------|------------
OPERATIONS      | Total Operations         | 1,247        | INCREASING   | LOW
OPERATIONS      | Successful Operations    | 1,244        | STABLE       | LOW
OPERATIONS      | Failed Operations        | 3            | DECREASING   | LOW
PERFORMANCE     | Avg Operation Duration   | 23           | STABLE       | LOW
```

### See Recent Operations (Raw Data)
```sql
-- Copy/paste this to see recent tracking data
SELECT 
    script_name,
    script_type,
    execution_status,
    execution_timestamp,
    execution_duration_ms
FROM script_tracking.script_execution_s 
WHERE execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY execution_timestamp DESC
LIMIT 10;
```

### See Any Problems
```sql
-- Copy/paste this to see recent errors
SELECT 
    script_name,
    execution_status,
    error_message,
    execution_timestamp
FROM script_tracking.script_execution_s 
WHERE execution_status = 'FAILED'
AND execution_timestamp > CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY execution_timestamp DESC;
```

**That's it!** The system is already working automatically.

---

## 🛠️ **Option 2: Track Your Own Operations**

### Basic Pattern (Copy/Paste Template)
```sql
-- Step 1: Start tracking something
DO $$
DECLARE
    operation_id BYTEA;
BEGIN
    -- 🔹 CHANGE THIS: Put your operation name here
    operation_id := track_operation('My Weekly Backup', 'MAINTENANCE');
    
    -- 🔹 YOUR WORK GOES HERE
    -- Example: VACUUM ANALYZE; or any other operations
    
    -- Step 2: Mark it as completed
    PERFORM complete_operation(operation_id, true);
    
    RAISE NOTICE 'Operation completed successfully!';
END $$;
```

### Real Example: Track a Backup
```sql
-- Copy/paste this example
DO $$
DECLARE
    backup_id BYTEA;
BEGIN
    -- Start tracking
    backup_id := track_operation('Weekly Database Backup', 'BACKUP');
    
    -- Do your backup work
    RAISE NOTICE 'Running backup...';
    -- Your backup commands would go here
    
    -- Mark as complete
    PERFORM complete_operation(backup_id, true);
    
    RAISE NOTICE 'Backup tracked successfully!';
END $$;
```

### Example: Track Something That Failed
```sql
DO $$
DECLARE
    operation_id BYTEA;
BEGIN
    operation_id := track_operation('Data Export', 'REPORTING');
    
    BEGIN
        -- Try to do something that might fail
        -- Your risky operation here
        
        -- If we get here, it worked
        PERFORM complete_operation(operation_id, true);
        
    EXCEPTION WHEN OTHERS THEN
        -- If it failed, track the failure
        PERFORM complete_operation(operation_id, false, SQLERRM);
        RAISE NOTICE 'Operation failed but was tracked: %', SQLERRM;
    END;
END $$;
```

---

## 📱 **Option 3: Use From Your Application (JavaScript)**

### If you have a web app, use the REST API:

#### Track an Operation
```javascript
// Start tracking
const response = await fetch('/api/v1/tracking/operations/start', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${yourToken}`,
    'X-Tenant-ID': yourTenantId,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    script_name: 'User Report Generation',
    script_type: 'REPORTING'
  })
});

const { operation_id } = (await response.json()).data;

// Do your work...

// Complete tracking
await fetch('/api/v1/tracking/operations/complete', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${yourToken}`,
    'X-Tenant-ID': yourTenantId,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    operation_id,
    success: true
  })
});
```

#### Get Dashboard Data
```javascript
const response = await fetch('/api/v1/tracking/dashboard', {
  headers: {
    'Authorization': `Bearer ${yourToken}`,
    'X-Tenant-ID': yourTenantId
  }
});

const dashboard = await response.json();
console.log('Success Rate:', dashboard.data.summary.success_rate + '%');
```

---

## 🎯 **Common Use Cases**

### 1. Track Weekly Maintenance
```sql
DO $$
DECLARE
    maintenance_id BYTEA;
BEGIN
    maintenance_id := track_operation('Weekly Maintenance', 'MAINTENANCE');
    
    -- Your maintenance tasks
    VACUUM ANALYZE;
    REINDEX DATABASE your_database_name;
    
    PERFORM complete_operation(maintenance_id, true);
END $$;
```

### 2. Track Data Exports
```sql
DO $$
DECLARE
    export_id BYTEA;
BEGIN
    export_id := track_operation('Monthly User Report', 'REPORTING');
    
    -- Your export logic
    COPY (SELECT * FROM users WHERE created_date >= '2024-01-01') TO '/tmp/users.csv' CSV HEADER;
    
    PERFORM complete_operation(export_id, true);
END $$;
```

### 3. Track Migrations
```sql
DO $$
DECLARE
    migration_id BYTEA;
BEGIN
    migration_id := track_operation('Add user preferences table', 'MIGRATION');
    
    -- Your migration
    CREATE TABLE user_preferences (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        preference_key VARCHAR(100),
        preference_value TEXT
    );
    
    PERFORM complete_operation(migration_id, true);
END $$;
```

---

## 📊 **Monitoring Dashboard**

### Check System Health
```sql
-- Is everything working well?
SELECT * FROM script_tracking.get_system_health();
```

### Get Performance Metrics
```sql
-- How fast are operations running?
SELECT * FROM script_tracking.get_performance_metrics();
```

### See What Failed Recently
```sql
-- What broke in the last day?
SELECT 
    script_name,
    error_message,
    execution_timestamp
FROM script_tracking.get_recent_errors(24)
ORDER BY execution_timestamp DESC;
```

---

## ⚠️ **Important Notes**

### ✅ What You DON'T Need to Do:
- **Don't track CREATE TABLE, ALTER TABLE, etc.** - These are tracked automatically
- **Don't track user logins** - The auth system already does this
- **Don't track every tiny operation** - Only track significant operations

### ✅ What You SHOULD Track:
- **Backups** - So you know when they run and if they succeed
- **Data exports** - Track when reports are generated
- **Maintenance** - Track routine maintenance tasks
- **Migrations** - Track when you add/change database structure
- **Imports** - Track when you load data from external sources

### 🔒 Security:
- **Everything is logged** - All tracking creates audit trails
- **Tenant isolated** - Each tenant only sees their own data
- **Error handling** - Failed operations are tracked too

---

## 🚨 **What to Do When Things Go Wrong**

### If You See Errors:
```sql
-- Check what failed recently
SELECT * FROM script_tracking.get_recent_errors(48);
```

### If Performance is Slow:
```sql
-- Check performance metrics
SELECT * FROM script_tracking.get_performance_metrics()
WHERE performance_rating IN ('POOR', 'WARNING');
```

### If You Need Help:
```sql
-- Get overall system status
SELECT * FROM script_tracking.get_enterprise_dashboard();
```

---

**That's it! Start with Option 1 (just looking) and work your way up to tracking your own operations when you're comfortable.** 