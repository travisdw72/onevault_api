# Database Tracking API Contract
## Enterprise Database Operations Tracking System

### Document Information
- **API Version**: 1.0.0
- **Last Updated**: 2024-01-15
- **Status**: Production Ready
- **Authentication**: Session-based with tenant isolation
- **Data Compliance**: HIPAA, GDPR compliant

---

## 🎯 **API Overview**

The Database Tracking API provides enterprise-grade database operation tracking with:
- ✅ **Automatic DDL tracking** - All database changes tracked automatically
- ✅ **Manual operation tracking** - Track maintenance, migrations, and custom operations
- ✅ **Real-time dashboard** - Live system health and performance metrics
- ✅ **Tenant isolation** - Complete data separation between tenants
- ✅ **Audit compliance** - Full audit trail for regulatory compliance

---

## 📡 **Base URL & Endpoints**

### Base URL
```
https://api.onevault.com/v1/tracking
```

### Available Endpoints
| Endpoint | Method | Purpose | Rate Limit |
|----------|--------|---------|------------|
| `/operations/start` | POST | Start tracking an operation | 100 req/min |
| `/operations/complete` | POST | Complete a tracked operation | 100 req/min |
| `/dashboard` | GET | Get system dashboard | 50 req/min |
| `/history` | GET | Get operation history | 25 req/min |
| `/health` | GET | System health status | 10 req/min |
| `/status` | GET | API health check | 10 req/min |

---

## 🔐 **Authentication & Security**

### Headers Required
```http
Authorization: Bearer <session_token>
X-Tenant-ID: <tenant_hash_key>
Content-Type: application/json
```

### Error Response Format
```json
{
  "success": false,
  "error": "Authentication failed",
  "error_code": "AUTH_FAILED",
  "timestamp": "2024-01-15T14:30:22.000Z"
}
```

---

## 📝 **Endpoint Details**

### 1. Start Operation Tracking

#### Endpoint
```http
POST /api/v1/tracking/operations/start
```

#### Request Body
```json
{
  "script_name": "Weekly Database Maintenance",
  "script_type": "MAINTENANCE"
}
```

#### Request Parameters
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `script_name` | string | Yes | - | Descriptive name of the operation |
| `script_type` | string | No | "MANUAL" | Operation type (MANUAL, MAINTENANCE, MIGRATION, etc.) |

#### Response (Success)
```json
{
  "success": true,
  "message": "Operation tracking started",
  "data": {
    "operation_id": "7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d",
    "script_name": "Weekly Database Maintenance",
    "script_type": "MAINTENANCE",
    "status": "RUNNING",
    "started_at": "2024-01-15T14:30:22.000Z"
  }
}
```

#### Usage Example (JavaScript)
```javascript
const response = await fetch('/api/v1/tracking/operations/start', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${sessionToken}`,
    'X-Tenant-ID': tenantId,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    script_name: 'User Data Export',
    script_type: 'REPORTING'
  })
});

const result = await response.json();
const operationId = result.data.operation_id;
```

---

### 2. Complete Operation Tracking

#### Endpoint
```http
POST /api/v1/tracking/operations/complete
```

#### Request Body
```json
{
  "operation_id": "7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d",
  "success": true,
  "error_message": null
}
```

#### Request Parameters
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `operation_id` | string | Yes | - | Operation ID from start endpoint |
| `success` | boolean | No | true | Whether operation succeeded |
| `error_message` | string | No | null | Error details if operation failed |

#### Response (Success)
```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": {
    "operation_id": "7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d",
    "status": "COMPLETED",
    "duration_ms": 15420,
    "completed_at": "2024-01-15T14:30:37.420Z"
  }
}
```

#### Usage Example (JavaScript)
```javascript
// Complete successfully
await fetch('/api/v1/tracking/operations/complete', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${sessionToken}`,
    'X-Tenant-ID': tenantId,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    operation_id: operationId,
    success: true
  })
});

// Complete with error
await fetch('/api/v1/tracking/operations/complete', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${sessionToken}`,
    'X-Tenant-ID': tenantId,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    operation_id: operationId,
    success: false,
    error_message: 'Database connection timeout'
  })
});
```

---

### 3. System Dashboard

#### Endpoint
```http
GET /api/v1/tracking/dashboard
```

#### Query Parameters
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `hours` | integer | No | 24 | Hours of data to include |

#### Response
```json
{
  "success": true,
  "message": "Dashboard data retrieved",
  "data": {
    "metrics": [
      {
        "metric_name": "total_operations_24h",
        "metric_value": 1247,
        "metric_unit": "count",
        "status": "NORMAL",
        "last_updated": "2024-01-15T14:30:22.000Z"
      },
      {
        "metric_name": "success_rate_24h",
        "metric_value": 99.8,
        "metric_unit": "percentage",
        "status": "EXCELLENT",
        "last_updated": "2024-01-15T14:30:22.000Z"
      },
      {
        "metric_name": "avg_duration_ms",
        "metric_value": 23.5,
        "metric_unit": "milliseconds",
        "status": "GOOD",
        "last_updated": "2024-01-15T14:30:22.000Z"
      }
    ],
    "summary": {
      "system_health": "EXCELLENT",
      "total_operations": 1247,
      "success_rate": 99.8,
      "failed_operations": 3
    }
  }
}
```

#### Usage Example (JavaScript)
```javascript
const response = await fetch('/api/v1/tracking/dashboard?hours=48', {
  headers: {
    'Authorization': `Bearer ${sessionToken}`,
    'X-Tenant-ID': tenantId
  }
});

const dashboard = await response.json();
console.log('Success Rate:', dashboard.data.summary.success_rate + '%');
```

---

### 4. Operation History

#### Endpoint
```http
GET /api/v1/tracking/history
```

#### Query Parameters
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `days` | integer | No | 7 | Days of history to retrieve |
| `type` | string | No | null | Filter by operation type |
| `status` | string | No | null | Filter by status (COMPLETED, FAILED) |
| `limit` | integer | No | 100 | Maximum records to return |

#### Response
```json
{
  "success": true,
  "message": "Operation history retrieved",
  "data": {
    "operations": [
      {
        "script_name": "Weekly Database Maintenance",
        "script_type": "MAINTENANCE",
        "execution_status": "COMPLETED",
        "execution_timestamp": "2024-01-15T14:30:22.000Z",
        "execution_duration_ms": 15420,
        "db_session_user": "admin_user",
        "affected_objects": ["users", "sessions", "audit_logs"]
      }
    ],
    "pagination": {
      "total_records": 156,
      "returned_records": 100,
      "has_more": true
    }
  }
}
```

#### Usage Example (JavaScript)
```javascript
// Get failed operations from last 30 days
const response = await fetch('/api/v1/tracking/history?days=30&status=FAILED', {
  headers: {
    'Authorization': `Bearer ${sessionToken}`,
    'X-Tenant-ID': tenantId
  }
});

const history = await response.json();
console.log('Failed operations:', history.data.operations.length);
```

---

### 5. System Health

#### Endpoint
```http
GET /api/v1/tracking/health
```

#### Response
```json
{
  "success": true,
  "message": "System health retrieved",
  "data": {
    "overall_status": "EXCELLENT",
    "health_checks": [
      {
        "health_category": "PERFORMANCE",
        "health_metric": "Average Response Time",
        "current_status": "GOOD",
        "details": "23.5ms average response time",
        "last_checked": "2024-01-15T14:30:22.000Z"
      },
      {
        "health_category": "RELIABILITY",
        "health_metric": "Success Rate",
        "current_status": "EXCELLENT",
        "details": "99.8% success rate over 24 hours",
        "last_checked": "2024-01-15T14:30:22.000Z"
      }
    ],
    "system_score": 98.5
  }
}
```

---

### 6. API Status Check

#### Endpoint
```http
GET /api/v1/tracking/status
```

#### Response
```json
{
  "service": "Database Tracking API",
  "status": "operational",
  "version": "1.0.0",
  "features": [
    "automatic_ddl_tracking",
    "manual_operation_tracking",
    "enterprise_dashboard",
    "real_time_monitoring",
    "tenant_isolation"
  ],
  "timestamp": "2024-01-15T14:30:22.000Z"
}
```

---

## 🔧 **Implementation Notes**

### Backend Implementation
Each REST endpoint calls the corresponding database function:

```sql
-- POST /operations/start calls:
SELECT script_tracking.track_operation(p_script_name, p_script_type);

-- POST /operations/complete calls:
SELECT script_tracking.complete_operation(p_execution_hk, p_success, p_error_message);

-- GET /dashboard calls:
SELECT * FROM script_tracking.get_enterprise_dashboard();

-- GET /history calls:
SELECT * FROM script_tracking.get_execution_history(p_days);

-- GET /health calls:
SELECT * FROM script_tracking.get_system_health();
```

### Error Handling
All endpoints return consistent error format:
```json
{
  "success": false,
  "error": "Descriptive error message",
  "error_code": "ERROR_TYPE",
  "timestamp": "2024-01-15T14:30:22.000Z"
}
```

Common error codes:
- `AUTH_FAILED`: Authentication/authorization failed
- `INVALID_REQUEST`: Missing or invalid parameters
- `OPERATION_NOT_FOUND`: Operation ID not found
- `DATABASE_ERROR`: Database operation failed
- `RATE_LIMITED`: Too many requests

---

## 📊 **Usage Patterns**

### Pattern 1: Track Manual Operations
```javascript
// Start operation
const startResponse = await fetch('/api/v1/tracking/operations/start', {
  method: 'POST',
  headers: { 
    'Authorization': `Bearer ${token}`,
    'X-Tenant-ID': tenantId,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    script_name: 'Data Migration Script',
    script_type: 'MIGRATION'
  })
});

const { operation_id } = (await startResponse.json()).data;

// Do your work here...

// Complete operation
await fetch('/api/v1/tracking/operations/complete', {
  method: 'POST',
  headers: { 
    'Authorization': `Bearer ${token}`,
    'X-Tenant-ID': tenantId,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    operation_id,
    success: true
  })
});
```

### Pattern 2: Monitor System Health
```javascript
// Get dashboard every 30 seconds
setInterval(async () => {
  const response = await fetch('/api/v1/tracking/dashboard', {
    headers: {
      'Authorization': `Bearer ${token}`,
      'X-Tenant-ID': tenantId
    }
  });
  
  const dashboard = await response.json();
  updateUI(dashboard.data);
}, 30000);
```

### Pattern 3: View Recent Errors
```javascript
// Get recent errors for troubleshooting
const response = await fetch('/api/v1/tracking/history?status=FAILED&days=1', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'X-Tenant-ID': tenantId
  }
});

const errors = await response.json();
console.log('Recent errors:', errors.data.operations);
```

---

**This REST API contract allows your frontend applications to interact with the Enterprise Database Tracking System through standard HTTP endpoints while maintaining full tenant isolation and audit compliance.** 