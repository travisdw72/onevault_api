# Phase 5 Deployment Guide: Capacity Planning & Growth Management
## One Vault Multi-Tenant Data Vault 2.0 Platform

### Overview
Phase 5 implements comprehensive capacity planning and growth management infrastructure with predictive forecasting, automated threshold monitoring, and proactive capacity management capabilities.

---

## 📋 **PRE-DEPLOYMENT CHECKLIST**

### Prerequisites
- [ ] PostgreSQL 14+ with required extensions
- [ ] Phases 1-4 successfully deployed and operational
- [ ] Monitoring infrastructure from Phase 2 active
- [ ] Performance optimization from Phase 3 implemented
- [ ] Administrative access to database
- [ ] Backup completed before deployment

### Required Extensions
```sql
-- Verify required extensions are available
SELECT name, installed_version, default_version 
FROM pg_available_extensions 
WHERE name IN ('pg_stat_statements', 'pgcrypto');

-- Install if not present
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

### System Requirements
- **CPU**: 4+ cores recommended for growth analysis
- **Memory**: 16GB+ RAM for forecasting calculations
- **Storage**: Additional 10GB for capacity planning data
- **Network**: Stable connection for real-time monitoring

---

## 🚀 **DEPLOYMENT STEPS**

### Step 1: Deploy Capacity Planning Infrastructure
```bash
# Navigate to deployment directory
cd database/scripts/Production_ready_assesment/

# Deploy capacity planning schema and tables
psql -h localhost -U postgres -d one_vault -f step_9_capacity_planning.sql

# Verify deployment
psql -h localhost -U postgres -d one_vault -c "
SELECT schemaname, tablename, tableowner 
FROM pg_tables 
WHERE schemaname = 'capacity_planning' 
ORDER BY tablename;"
```

**Expected Output:**
```
 schemaname      |        tablename         | tableowner 
-----------------+--------------------------+------------
 capacity_planning | capacity_forecast_h      | postgres
 capacity_planning | capacity_forecast_s      | postgres
 capacity_planning | capacity_threshold_h     | postgres
 capacity_planning | capacity_threshold_s     | postgres
 capacity_planning | forecast_utilization_l   | postgres
 capacity_planning | growth_pattern_h         | postgres
 capacity_planning | growth_pattern_s         | postgres
 capacity_planning | pattern_forecast_l       | postgres
 capacity_planning | resource_utilization_h   | postgres
 capacity_planning | resource_utilization_s   | postgres
(10 rows)
```

### Step 2: Deploy Growth Forecasting System
```bash
# Deploy growth forecasting procedures
psql -h localhost -U postgres -d one_vault -f step_10_growth_forecasting.sql

# Verify functions are created
psql -h localhost -U postgres -d one_vault -c "
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'capacity_planning' 
ORDER BY routine_name;"
```

**Expected Output:**
```
        routine_name         | routine_type 
-----------------------------+--------------
 analyze_growth_patterns     | FUNCTION
 capture_resource_utilization| FUNCTION
 create_capacity_threshold   | FUNCTION
 evaluate_capacity_thresholds| FUNCTION
 run_capacity_analysis       | PROCEDURE
(5 rows)
```

### Step 3: Verify Index Creation
```bash
# Check that all performance indexes are created
psql -h localhost -U postgres -d one_vault -c "
SELECT schemaname, tablename, indexname, indexdef 
FROM pg_indexes 
WHERE schemaname = 'capacity_planning' 
ORDER BY tablename, indexname;"
```

**Expected Output:** Should show 20+ indexes across all capacity planning tables.

### Step 4: Initialize Default Configuration
```bash
# Run initial capacity analysis to populate baseline data
psql -h localhost -U postgres -d one_vault -c "
CALL capacity_planning.run_capacity_analysis(NULL, true);"
```

**Expected Output:**
```
NOTICE:  Capturing current resource utilization...
NOTICE:  Analyzing growth patterns...
NOTICE:  Resource: STORAGE, Pattern: LINEAR, Growth Rate: 2.5000%, Days to Capacity: 180
NOTICE:  Resource: CONNECTIONS, Pattern: STABLE, Growth Rate: 0.8000%, Days to Capacity: 450
NOTICE:  Creating default capacity thresholds...
NOTICE:  Evaluating capacity thresholds...
NOTICE:  Capacity analysis completed successfully
CALL
```

---

## 🔧 **CONFIGURATION**

### Environment-Specific Settings

#### Development Environment
```sql
-- Adjust monitoring frequency for development
UPDATE capacity_planning.capacity_threshold_s 
SET evaluation_frequency_minutes = 15,
    suppression_duration_minutes = 120
WHERE load_end_date IS NULL;

-- Set lower thresholds for testing
UPDATE capacity_planning.capacity_threshold_s 
SET threshold_percentage = threshold_percentage * 0.8
WHERE threshold_type = 'WARNING' 
AND load_end_date IS NULL;
```

#### Production Environment
```sql
-- Set aggressive monitoring for production
UPDATE capacity_planning.capacity_threshold_s 
SET evaluation_frequency_minutes = 5,
    suppression_duration_minutes = 60,
    escalation_enabled = true,
    escalation_delay_minutes = 15
WHERE threshold_type = 'CRITICAL' 
AND load_end_date IS NULL;

-- Enable business hours restrictions for non-critical alerts
UPDATE capacity_planning.capacity_threshold_s 
SET business_hours_only = true
WHERE threshold_type = 'WARNING' 
AND load_end_date IS NULL;
```

### Notification Configuration
```sql
-- Configure notification channels
UPDATE capacity_planning.capacity_threshold_s 
SET notification_channels = ARRAY['EMAIL', 'SLACK', 'PAGERDUTY'],
    escalation_contacts = ARRAY['admin@onevault.com', 'ops@onevault.com']
WHERE threshold_type = 'CRITICAL' 
AND load_end_date IS NULL;

-- Set up alert message templates
UPDATE capacity_planning.capacity_threshold_s 
SET alert_message_template = 
    'ALERT: ' || resource_type || ' utilization has exceeded ' || 
    threshold_percentage || '% threshold. Current usage: {current_usage}%. ' ||
    'Immediate attention required.'
WHERE threshold_type = 'CRITICAL' 
AND load_end_date IS NULL;
```

---

## ✅ **VERIFICATION PROCEDURES**

### 1. Schema Verification
```sql
-- Verify all tables exist with correct structure
SELECT 
    t.table_name,
    COUNT(c.column_name) as column_count,
    COUNT(CASE WHEN c.is_nullable = 'NO' THEN 1 END) as required_columns
FROM information_schema.tables t
LEFT JOIN information_schema.columns c ON t.table_name = c.table_name 
    AND t.table_schema = c.table_schema
WHERE t.table_schema = 'capacity_planning'
GROUP BY t.table_name
ORDER BY t.table_name;
```

**Expected Results:**
- capacity_forecast_h: 4 columns, 4 required
- capacity_forecast_s: 35+ columns, 10+ required
- resource_utilization_h: 4 columns, 4 required
- resource_utilization_s: 40+ columns, 10+ required

### 2. Function Testing
```sql
-- Test resource utilization capture
SELECT * FROM capacity_planning.capture_resource_utilization(NULL);

-- Test growth pattern analysis
SELECT * FROM capacity_planning.analyze_growth_patterns(NULL, 'STORAGE', 7);

-- Test threshold evaluation
SELECT * FROM capacity_planning.evaluate_capacity_thresholds(NULL);
```

### 3. Data Quality Verification
```sql
-- Check that data is being captured correctly
SELECT 
    resource_type,
    COUNT(*) as measurement_count,
    AVG(utilization_percentage) as avg_utilization,
    MAX(measurement_timestamp) as latest_measurement
FROM capacity_planning.resource_utilization_s 
WHERE load_end_date IS NULL
GROUP BY resource_type;
```

### 4. View Verification
```sql
-- Test dashboard views
SELECT * FROM capacity_planning.current_capacity_status LIMIT 5;
SELECT * FROM capacity_planning.growth_forecast_summary LIMIT 5;
SELECT * FROM capacity_planning.capacity_alerts LIMIT 5;
```

---

## 📊 **MONITORING SETUP**

### Automated Capacity Analysis
```sql
-- Create function to run regular capacity analysis
CREATE OR REPLACE FUNCTION capacity_planning.scheduled_capacity_analysis()
RETURNS void AS $$
BEGIN
    -- Capture current utilization
    PERFORM capacity_planning.capture_resource_utilization(NULL);
    
    -- Run growth analysis for all tenants
    PERFORM capacity_planning.analyze_growth_patterns(NULL, NULL, 30);
    
    -- Evaluate thresholds
    PERFORM capacity_planning.evaluate_capacity_thresholds(NULL);
    
    -- Log completion
    RAISE NOTICE 'Scheduled capacity analysis completed at %', CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;
```

### Cron Job Setup (Linux/Unix)
```bash
# Add to crontab for automated execution
crontab -e

# Add these lines:
# Run capacity analysis every 15 minutes
*/15 * * * * psql -h localhost -U postgres -d one_vault -c "SELECT capacity_planning.scheduled_capacity_analysis();" >> /var/log/capacity_analysis.log 2>&1

# Run comprehensive analysis daily at 2 AM
0 2 * * * psql -h localhost -U postgres -d one_vault -c "CALL capacity_planning.run_capacity_analysis(NULL, false);" >> /var/log/capacity_analysis.log 2>&1
```

### Windows Task Scheduler
```batch
# Create batch file: capacity_analysis.bat
@echo off
psql -h localhost -U postgres -d one_vault -c "SELECT capacity_planning.scheduled_capacity_analysis();" >> C:\logs\capacity_analysis.log 2>&1

# Schedule in Task Scheduler:
# - Trigger: Every 15 minutes
# - Action: Start program capacity_analysis.bat
# - Settings: Run whether user is logged on or not
```

---

## 🎯 **PERFORMANCE TUNING**

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
WHERE schemaname = 'capacity_planning'
ORDER BY idx_scan DESC;

-- Add additional indexes if needed based on query patterns
CREATE INDEX CONCURRENTLY idx_capacity_forecast_s_time_range 
ON capacity_planning.capacity_forecast_s(forecast_timestamp, resource_type) 
WHERE load_end_date IS NULL;
```

### Query Performance
```sql
-- Monitor slow queries in capacity planning
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
WHERE query LIKE '%capacity_planning%'
ORDER BY mean_time DESC
LIMIT 10;
```

### Memory Configuration
```sql
-- Adjust work_mem for complex forecasting queries
SET work_mem = '256MB';

-- For large datasets, consider increasing
SET maintenance_work_mem = '1GB';
```

---

## 🚨 **TROUBLESHOOTING**

### Common Issues and Solutions

#### Issue 1: High Memory Usage During Analysis
**Symptoms:** Out of memory errors during growth analysis
**Solution:**
```sql
-- Reduce analysis window for large datasets
SELECT * FROM capacity_planning.analyze_growth_patterns(NULL, 'STORAGE', 14); -- Use 14 days instead of 30

-- Process tenants individually
DO $$
DECLARE
    tenant_record RECORD;
BEGIN
    FOR tenant_record IN SELECT tenant_hk FROM auth.tenant_h LOOP
        PERFORM capacity_planning.analyze_growth_patterns(tenant_record.tenant_hk, NULL, 30);
        PERFORM pg_sleep(1); -- Brief pause between tenants
    END LOOP;
END $$;
```

#### Issue 2: Slow Forecasting Performance
**Symptoms:** Long execution times for growth analysis
**Solution:**
```sql
-- Check for missing indexes
SELECT 
    schemaname, 
    tablename, 
    attname, 
    n_distinct, 
    correlation
FROM pg_stats 
WHERE schemaname = 'capacity_planning' 
AND n_distinct > 100;

-- Update table statistics
ANALYZE capacity_planning.resource_utilization_s;
ANALYZE capacity_planning.capacity_forecast_s;
```

#### Issue 3: Inaccurate Growth Predictions
**Symptoms:** Forecasts don't match actual growth
**Solution:**
```sql
-- Increase data points for analysis
SELECT * FROM capacity_planning.analyze_growth_patterns(NULL, NULL, 60); -- Use 60 days

-- Check for data quality issues
SELECT 
    resource_type,
    COUNT(*) as total_measurements,
    COUNT(CASE WHEN current_value > 0 THEN 1 END) as valid_measurements,
    AVG(data_quality_score) as avg_quality
FROM capacity_planning.resource_utilization_s 
WHERE load_end_date IS NULL
GROUP BY resource_type;
```

#### Issue 4: False Positive Alerts
**Symptoms:** Too many threshold alerts for normal usage
**Solution:**
```sql
-- Adjust threshold percentages
UPDATE capacity_planning.capacity_threshold_s 
SET threshold_percentage = threshold_percentage + 5.0
WHERE false_positive_rate > 20.0 
AND load_end_date IS NULL;

-- Enable suppression for noisy thresholds
UPDATE capacity_planning.capacity_threshold_s 
SET suppression_enabled = true,
    suppression_duration_minutes = 120
WHERE trigger_count_24h > 10 
AND load_end_date IS NULL;
```

---

## 📈 **SUCCESS METRICS**

### Key Performance Indicators
```sql
-- Capacity planning effectiveness dashboard
SELECT 
    'Forecast Accuracy' as metric,
    ROUND(AVG(confidence_level), 2) as value,
    '%' as unit
FROM capacity_planning.capacity_forecast_s 
WHERE load_end_date IS NULL

UNION ALL

SELECT 
    'Threshold Effectiveness',
    ROUND(AVG(threshold_effectiveness_score), 2),
    '%'
FROM capacity_planning.capacity_threshold_s 
WHERE load_end_date IS NULL

UNION ALL

SELECT 
    'Alert Response Time',
    ROUND(AVG(average_resolution_time_minutes), 0),
    'minutes'
FROM capacity_planning.capacity_threshold_s 
WHERE average_resolution_time_minutes IS NOT NULL

UNION ALL

SELECT 
    'Growth Pattern Detection',
    COUNT(*)::DECIMAL,
    'patterns'
FROM capacity_planning.growth_pattern_s 
WHERE load_end_date IS NULL 
AND pattern_confidence > 80.0;
```

### Success Criteria
- [ ] **Forecast Accuracy**: >85% confidence in 30-day forecasts
- [ ] **Alert Effectiveness**: <10% false positive rate
- [ ] **Response Time**: <30 minutes average alert resolution
- [ ] **Coverage**: 100% of critical resources monitored
- [ ] **Automation**: 95% of capacity analysis automated
- [ ] **Proactive Planning**: 90+ days advance warning for capacity issues

---

## 📚 **MAINTENANCE PROCEDURES**

### Daily Maintenance
```sql
-- Check capacity analysis execution
SELECT 
    MAX(forecast_timestamp) as last_forecast,
    COUNT(*) as active_forecasts
FROM capacity_planning.capacity_forecast_s 
WHERE load_end_date IS NULL;

-- Review critical alerts
SELECT * FROM capacity_planning.capacity_alerts 
WHERE alert_severity = 'CRITICAL' 
AND trigger_count_24h > 0;
```

### Weekly Maintenance
```sql
-- Update growth model accuracy
UPDATE capacity_planning.capacity_forecast_s 
SET model_accuracy = 
    CASE 
        WHEN forecast_timestamp < CURRENT_TIMESTAMP - INTERVAL '7 days' THEN
            -- Calculate actual vs predicted accuracy
            GREATEST(0, 100 - ABS(projected_usage_7d - current_usage) / current_usage * 100)
        ELSE model_accuracy
    END
WHERE load_end_date IS NULL;

-- Clean up old utilization data
DELETE FROM capacity_planning.resource_utilization_s 
WHERE measurement_timestamp < CURRENT_TIMESTAMP - INTERVAL '90 days';
```

### Monthly Maintenance
```sql
-- Review and tune thresholds
SELECT 
    threshold_name,
    resource_type,
    threshold_percentage,
    false_positive_rate,
    true_positive_rate,
    CASE 
        WHEN false_positive_rate > 20 THEN 'INCREASE_THRESHOLD'
        WHEN true_positive_rate < 80 THEN 'DECREASE_THRESHOLD'
        ELSE 'OPTIMAL'
    END as recommendation
FROM capacity_planning.capacity_threshold_s 
WHERE load_end_date IS NULL
ORDER BY false_positive_rate DESC;

-- Archive old forecast data
INSERT INTO capacity_planning.capacity_forecast_archive 
SELECT * FROM capacity_planning.capacity_forecast_s 
WHERE forecast_timestamp < CURRENT_TIMESTAMP - INTERVAL '6 months';
```

---

## 🎉 **DEPLOYMENT COMPLETION**

### Final Verification Checklist
- [ ] All tables created successfully
- [ ] All functions and procedures operational
- [ ] Indexes created and optimized
- [ ] Initial data populated
- [ ] Dashboard views accessible
- [ ] Automated monitoring configured
- [ ] Alert thresholds tuned
- [ ] Performance benchmarks established
- [ ] Documentation updated
- [ ] Team trained on new capabilities

### Next Steps
1. **Monitor Performance**: Watch system performance for 48 hours
2. **Tune Thresholds**: Adjust alert thresholds based on initial data
3. **Validate Forecasts**: Compare initial forecasts with actual usage
4. **Document Procedures**: Update operational runbooks
5. **Train Team**: Conduct training on capacity planning features

### Phase 6 Preparation
Phase 5 completion enables:
- **Disaster Recovery Planning**: Use capacity data for DR sizing
- **Auto-scaling Integration**: Implement automated capacity responses
- **Cost Optimization**: Optimize resource allocation based on forecasts
- **Business Planning**: Support business growth planning with data

**Phase 5 Status: COMPLETE** ✅

The capacity planning and growth management infrastructure is now operational and ready to support proactive capacity management for the One Vault platform. 