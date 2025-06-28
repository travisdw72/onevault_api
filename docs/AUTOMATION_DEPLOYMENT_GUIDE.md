# Site Tracking Automation - Deployment Guide

## 🚀 Overview

This guide covers the deployment of the enhanced site tracking API with automatic processing capabilities. The automation ensures that raw site events are immediately processed through the complete Data Vault 2.0 pipeline (Raw → Staging → Business) without manual intervention.

## 📋 Prerequisites

### Database Requirements
- ✅ Site tracking deployment scripts (01-08) must be deployed
- ✅ Automation layer (08_create_automation_layer_NO_CRON.sql) must be deployed
- ✅ All required functions must be available:
  - `api.track_site_event()`
  - `staging.auto_process_if_needed()`
  - `staging.trigger_pipeline_now()`
  - `staging.get_pipeline_status()`

### API Requirements
- ✅ FastAPI application with updated main.py
- ✅ Database connection configured via `SYSTEM_DATABASE_URL`
- ✅ Customer authentication configured

## 🔧 New API Endpoints

### 1. Enhanced Tracking Endpoint (Automatic Processing)
```
POST /api/v1/track
```
**Changes**: Now includes automatic processing after event ingestion
**Processing**: Synchronous - processes immediately after tracking
**Response Time**: Slightly slower (~100-200ms additional)
**Use Case**: When you need immediate processing and can accept slightly slower response

### 2. New Async Tracking Endpoint (Background Processing)
```
POST /api/v1/track/async
```
**Processing**: Asynchronous - schedules processing in background
**Response Time**: Faster response (~50ms faster)
**Use Case**: High-volume tracking where response speed is critical

### 3. Status Monitoring Endpoint
```
GET /api/v1/track/status
```
**Purpose**: Monitor pipeline status and recent events
**Returns**: Pipeline status, recent events (last 10)

### 4. Dashboard Endpoint
```
GET /api/v1/track/dashboard?limit=20
```
**Purpose**: Comprehensive dashboard data
**Returns**: Summary statistics, event details, processing status

### 5. Manual Processing Trigger
```
POST /api/v1/track/process
```
**Purpose**: Manually trigger processing (useful for testing)
**Returns**: Processing result and status

## 🏗️ Deployment Steps

### Step 1: Backup Current API
```bash
# Backup current main.py
cp onevault_api/app/main.py onevault_api/app/main.py.backup
```

### Step 2: Deploy Enhanced API
The enhanced `main.py` is already updated with:
- ✅ Automatic processing in `/api/v1/track`
- ✅ Background processing in `/api/v1/track/async`
- ✅ Management endpoints for monitoring and control
- ✅ Comprehensive error handling
- ✅ Detailed logging

### Step 3: Verify Database Functions
Run this SQL to verify required functions exist:
```sql
-- Check required functions
SELECT 
    schemaname, 
    functionname,
    'Available' as status
FROM pg_catalog.pg_functions 
WHERE schemaname IN ('api', 'staging')
AND functionname IN (
    'track_site_event',
    'auto_process_if_needed', 
    'trigger_pipeline_now',
    'get_pipeline_status'
)
ORDER BY schemaname, functionname;
```

### Step 4: Test Deployment
```bash
# Run the comprehensive test suite
cd onevault_api
python test_automation.py
```

### Step 5: Production Configuration
Update environment variables for production:
```bash
# Production database URL
export SYSTEM_DATABASE_URL="postgresql://user:pass@prod-host:5432/database"

# Optional: Enable debug logging for initial deployment
export LOG_LEVEL="DEBUG"
```

## 🧪 Testing Strategy

### Automated Testing
Use the provided test script:
```bash
python onevault_api/test_automation.py
```

This tests:
- ✅ Health checks
- ✅ Database connectivity
- ✅ Automatic processing endpoint
- ✅ Background processing endpoint
- ✅ Status monitoring
- ✅ Dashboard data
- ✅ Manual triggers

### Manual Testing
1. **Send Test Event (Automatic)**:
```bash
curl -X POST "http://localhost:8000/api/v1/track" \
  -H "X-Customer-ID: one_spa" \
  -H "Authorization: Bearer ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f" \
  -H "Content-Type: application/json" \
  -d '{
    "page_url": "http://localhost/test",
    "event_type": "test_event",
    "event_data": {"test": true}
  }'
```

2. **Check Status**:
```bash
curl -X GET "http://localhost:8000/api/v1/track/status" \
  -H "X-Customer-ID: one_spa" \
  -H "Authorization: Bearer ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f"
```

3. **View Dashboard**:
```bash
curl -X GET "http://localhost:8000/api/v1/track/dashboard?limit=5" \
  -H "X-Customer-ID: one_spa" \
  -H "Authorization: Bearer ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f"
```

## 📊 Monitoring & Observability

### Log Messages to Monitor
- `🔄 Triggering automatic site tracking processing...`
- `✅ Processing result: {...}`
- `ℹ️ No processing needed - all events up to date`
- `⚠️ Site tracking processing failed (non-critical): {...}`
- `🔄 Background processing: Starting site tracking pipeline...`

### Key Metrics
Monitor these in your dashboard:
- **Total Events**: Count of raw events received
- **Processing Rate**: Events processed to staging
- **Pipeline Completion**: Events processed to business layer
- **Processing Latency**: Time from raw to business layer
- **Error Rate**: Failed processing attempts

### Health Check Endpoints
- `GET /health` - Basic health
- `GET /health/detailed` - Detailed health with DB
- `GET /health/db` - Database function availability
- `GET /api/v1/track/status` - Pipeline status

## 🚨 Troubleshooting

### Common Issues

#### 1. "Function staging.auto_process_if_needed() does not exist"
**Solution**: Deploy the automation layer:
```sql
-- Run this SQL file
\i database/scripts/site-tracking-scripts/08_create_automation_layer_NO_CRON.sql
```

#### 2. "No processing needed" messages
**Status**: Normal - indicates all events are already processed
**Action**: No action needed

#### 3. High response times on /api/v1/track
**Solution**: Switch to async endpoint:
```javascript
// Change from:
fetch('/api/v1/track', {...})

// To:
fetch('/api/v1/track/async', {...})
```

#### 4. Processing errors in logs
**Check**: Database connectivity and function availability
**Debug**: Use manual trigger endpoint to test processing

### Error Recovery
If processing fails:
1. Check database connectivity
2. Verify all functions exist
3. Use manual trigger: `POST /api/v1/track/process`
4. Check logs for specific error messages

## 🔄 Rollback Procedure

If you need to rollback:

### 1. Restore Previous API
```bash
cp onevault_api/app/main.py.backup onevault_api/app/main.py
```

### 2. Remove Automation Layer (if needed)
```sql
\i database/scripts/site-tracking-scripts/08_create_automation_layer_ROLLBACK.sql
```

### 3. Restart API Service
```bash
# Restart your API service
systemctl restart onevault-api  # or your service name
```

## 📈 Performance Considerations

### Automatic Processing (Synchronous)
- **Pros**: Immediate processing, consistent state
- **Cons**: Slightly slower response times
- **Best for**: Low to medium volume, when immediate processing is required

### Background Processing (Asynchronous)
- **Pros**: Fast response times, better for high volume
- **Cons**: Slight delay in processing (typically <1 second)
- **Best for**: High volume tracking, when response speed is critical

### Recommendations
- **Low Volume (<100 events/min)**: Use automatic processing
- **High Volume (>100 events/min)**: Use background processing
- **Mixed**: Use background processing with periodic status checks

## 🎯 Success Criteria

Deployment is successful when:
- ✅ All test script tests pass
- ✅ Events are automatically processed to business layer
- ✅ Dashboard shows complete pipeline status
- ✅ No critical errors in logs
- ✅ Response times meet performance requirements

## 📞 Support

### Log Analysis
Check these log patterns for issues:
```bash
# Success patterns
grep "✅ Processing result" /var/log/onevault-api.log

# Error patterns  
grep "❌\|⚠️" /var/log/onevault-api.log

# Processing activity
grep "🔄" /var/log/onevault-api.log
```

### Database Queries for Debugging
```sql
-- Check recent processing activity
SELECT * FROM staging.pipeline_dashboard 
ORDER BY raw_load_date DESC 
LIMIT 10;

-- Check for stuck events
SELECT 
    COUNT(*) as raw_events,
    COUNT(CASE WHEN staging_status = 'PROCESSED' THEN 1 END) as staged,
    COUNT(CASE WHEN business_status = '✅ Complete Pipeline' THEN 1 END) as completed
FROM staging.pipeline_dashboard;
```

## 🎉 Conclusion

The site tracking automation provides:
- **Real-time Processing**: Events processed immediately or in background
- **Complete Visibility**: Dashboard and status endpoints for monitoring
- **Flexible Control**: Both automatic and manual processing options
- **Production Ready**: Comprehensive error handling and logging
- **Scalable**: Choose synchronous or asynchronous based on volume

The system is now fully automated while maintaining complete observability and control for production operations. 