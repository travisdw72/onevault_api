# AI Observation API Contract
## OneVault Enterprise AI Business Intelligence Platform

### Document Type: API Contract Specification
### Version: 1.0  
### Last Updated: July 1, 2025

---

## 📋 **API OVERVIEW**

### Purpose
This document defines the API contract for the OneVault AI Observation System, including function signatures, request/response formats, error codes, and integration examples.

### Base Information
- **Protocol**: PostgreSQL Function Call / HTTP REST API
- **Authentication**: Bearer Token or Direct Database Access
- **Content Type**: `application/json`
- **Tenant Isolation**: Required for all operations

---

## 🔧 **CORE FUNCTIONS**

### 1. AI Observation Logging

#### Function Signature
```sql
FUNCTION api.ai_log_observation(p_request jsonb) RETURNS jsonb
```

#### HTTP Endpoint (when exposed)
```http
POST /api/v1/ai/observations
Content-Type: application/json
Authorization: Bearer <api_token>
X-Tenant-ID: <tenant_id>
```

#### Request Schema
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "title": "AI Observation Request",
  "required": ["tenantId", "observationType", "severityLevel"],
  "properties": {
    "tenantId": {
      "type": "string",
      "description": "Unique tenant identifier",
      "example": "72_Industries_LLC"
    },
    "observationType": {
      "type": "string",
      "enum": ["behavior_anomaly", "health_concern", "safety_concern", "equipment_malfunction", "security_breach"],
      "description": "Type of AI observation detected"
    },
    "severityLevel": {
      "type": "string",
      "enum": ["low", "medium", "high", "critical", "emergency"],
      "description": "Severity level of the observation"
    },
    "confidenceScore": {
      "type": "number",
      "minimum": 0.0,
      "maximum": 1.0,
      "default": 0.75,
      "description": "AI confidence score (0.0 to 1.0)"
    },
    "entityId": {
      "type": "string",
      "description": "Business key of monitored entity (optional)",
      "example": "horse_thunder_bolt_001"
    },
    "sensorId": {
      "type": "string", 
      "description": "Business key of monitoring sensor (optional)",
      "example": "camera_north_pasture_001"
    },
    "observationData": {
      "type": "object",
      "description": "Structured observation data",
      "properties": {
        "symptoms": {
          "type": "array",
          "items": {"type": "string"}
        },
        "duration": {"type": "string"},
        "location": {"type": "string"},
        "environmental_conditions": {"type": "object"}
      }
    },
    "visualEvidence": {
      "type": "object",
      "description": "Visual evidence and detection results",
      "properties": {
        "image_url": {"type": "string"},
        "video_url": {"type": "string"},
        "confidence_map": {
          "type": "array",
          "items": {"type": "number"}
        },
        "detection_boxes": {
          "type": "array",
          "items": {
            "type": "array",
            "items": {"type": "number"},
            "minItems": 4,
            "maxItems": 4
          }
        }
      }
    },
    "recommendedActions": {
      "type": "array",
      "items": {"type": "string"},
      "description": "AI-recommended actions"
    },
    "ip_address": {
      "type": "string",
      "format": "ipv4",
      "default": "127.0.0.1",
      "description": "Source IP address"
    },
    "user_agent": {
      "type": "string",
      "default": "AI System",
      "description": "AI system user agent"
    }
  }
}
```

#### Response Schema
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "title": "AI Observation Response",
  "required": ["success", "message"],
  "properties": {
    "success": {
      "type": "boolean",
      "description": "Operation success status"
    },
    "message": {
      "type": "string", 
      "description": "Human-readable status message"
    },
    "data": {
      "type": "object",
      "description": "Response data (present on success)",
      "properties": {
        "observationId": {
          "type": "string",
          "description": "Unique observation identifier",
          "example": "ai-obs-health_concern-20250701-173851-fb27bdd0"
        },
        "observationType": {
          "type": "string",
          "description": "Confirmed observation type"
        },
        "severityLevel": {
          "type": "string",
          "description": "Confirmed severity level"
        },
        "confidenceScore": {
          "type": "number",
          "description": "Final confidence score"
        },
        "alertCreated": {
          "type": "boolean",
          "description": "Whether an alert was generated"
        },
        "alertId": {
          "type": ["string", "null"],
          "description": "Alert ID if created"
        },
        "escalationRequired": {
          "type": "boolean",
          "description": "Whether immediate escalation is required"
        },
        "timestamp": {
          "type": "string",
          "format": "date-time",
          "description": "Observation timestamp"
        }
      }
    },
    "error_code": {
      "type": "string",
      "description": "Error code (present on failure)"
    },
    "debug_info": {
      "type": "object",
      "description": "Debug information (present on error)"
    }
  }
}
```

---

## 📊 **EXAMPLES**

### Example 1: Basic Health Observation
```http
POST /api/v1/ai/observations
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
X-Tenant-ID: 72_Industries_LLC

{
  "tenantId": "72_Industries_LLC",
  "observationType": "health_concern",
  "severityLevel": "medium",
  "confidenceScore": 0.87,
  "observationData": {
    "symptoms": ["limping", "favoring_left_front_leg"],
    "duration": "observed_for_15_minutes",
    "location": "north_pasture"
  },
  "recommendedActions": [
    "Schedule veterinary examination within 24 hours",
    "Restrict exercise until evaluation"
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "AI observation logged successfully",
  "data": {
    "observationId": "ai-obs-health_concern-20250701-143052-a1b2c3d4",
    "observationType": "health_concern",
    "severityLevel": "medium",
    "confidenceScore": 0.87,
    "alertCreated": false,
    "alertId": null,
    "escalationRequired": false,
    "timestamp": "2025-07-01T14:30:52.123456-07:00"
  }
}
```

### Example 2: Critical Safety Observation with Alert
```http
POST /api/v1/ai/observations
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
X-Tenant-ID: 72_Industries_LLC

{
  "tenantId": "72_Industries_LLC",
  "observationType": "safety_concern",
  "severityLevel": "critical",
  "confidenceScore": 0.95,
  "entityId": "horse_thunder_bolt_001",
  "sensorId": "camera_north_pasture_001",
  "observationData": {
    "incident_type": "fence_entanglement",
    "location": "north_pasture_fence_line",
    "immediate_danger": true
  },
  "visualEvidence": {
    "image_url": "https://storage.onevault.com/alerts/fence_entanglement_20250701_143052.jpg",
    "confidence_map": [0.95, 0.92, 0.88],
    "detection_boxes": [[120, 85, 200, 150]]
  },
  "recommendedActions": [
    "IMMEDIATE: Send personnel to north pasture",
    "URGENT: Ensure horse safety and remove from danger",
    "Follow-up: Inspect fence for damage"
  ],
  "ip_address": "192.168.1.101",
  "user_agent": "OneVault_AI_Vision_System_v2.1"
}
```

**Response:**
```json
{
  "success": true,
  "message": "AI observation logged successfully",
  "data": {
    "observationId": "ai-obs-safety_concern-20250701-143052-x9y8z7w6",
    "observationType": "safety_concern",
    "severityLevel": "critical",
    "confidenceScore": 0.95,
    "alertCreated": true,
    "alertId": "ai-alert-safety_concern-20250701-143052-immediate_response",
    "escalationRequired": true,
    "timestamp": "2025-07-01T14:30:52.123456-07:00"
  }
}
```

### Example 3: Entity Context Observation
```http
POST /api/v1/ai/observations
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
X-Tenant-ID: 72_Industries_LLC

{
  "tenantId": "72_Industries_LLC",
  "observationType": "behavior_anomaly",
  "severityLevel": "high",
  "confidenceScore": 0.92,
  "entityId": "horse_storm_dancer_002",
  "sensorId": "camera_stable_entrance_001",
  "observationData": {
    "behavior_type": "aggressive_interaction",
    "target": "other_horses",
    "duration_minutes": 8,
    "escalation_pattern": "increasing"
  },
  "visualEvidence": {
    "video_url": "https://storage.onevault.com/behavior/aggressive_20250701_143052.mp4",
    "key_frames": [
      "https://storage.onevault.com/behavior/frame_001.jpg",
      "https://storage.onevault.com/behavior/frame_015.jpg"
    ]
  },
  "recommendedActions": [
    "Separate horses immediately",
    "Monitor for continued aggression",
    "Review feeding schedule and territory assignments"
  ]
}
```

---

## ❌ **ERROR CODES**

### Standard Error Responses

#### 400 Bad Request - Missing Parameters
```json
{
  "success": false,
  "message": "Missing required parameters: tenantId, observationType, severityLevel",
  "error_code": "MISSING_PARAMETERS"
}
```

#### 404 Not Found - Invalid Tenant
```json
{
  "success": false,
  "message": "Invalid tenant ID",
  "error_code": "INVALID_TENANT"
}
```

#### 422 Unprocessable Entity - Invalid Data
```json
{
  "success": false,
  "message": "Invalid severity level: must be one of [low, medium, high, critical, emergency]",
  "error_code": "INVALID_SEVERITY_LEVEL"
}
```

#### 500 Internal Server Error - Database Error
```json
{
  "success": false,
  "message": "Error logging AI observation",
  "error_code": "OBSERVATION_ERROR",
  "debug_info": {
    "error": "relation \"business.ai_observation_h\" does not exist"
  }
}
```

### Complete Error Code List

| Error Code | HTTP Status | Description | Resolution |
|------------|-------------|-------------|------------|
| `MISSING_PARAMETERS` | 400 | Required parameters not provided | Include tenantId, observationType, severityLevel |
| `INVALID_TENANT` | 404 | Tenant ID not found | Verify tenant exists and is active |
| `INVALID_OBSERVATION_TYPE` | 422 | Invalid observation type | Use valid enum values |
| `INVALID_SEVERITY_LEVEL` | 422 | Invalid severity level | Use valid enum values |
| `INVALID_CONFIDENCE_SCORE` | 422 | Confidence score out of range | Use value between 0.0 and 1.0 |
| `ENTITY_NOT_FOUND` | 404 | Entity ID not found | Verify entity exists for tenant |
| `SENSOR_NOT_FOUND` | 404 | Sensor ID not found | Verify sensor exists for tenant |
| `OBSERVATION_ERROR` | 500 | Database or system error | Check logs, retry operation |
| `AUDIT_LOGGING_FAILED` | 500 | Audit logging failed | Check audit system status |
| `ALERT_CREATION_FAILED` | 500 | Alert generation failed | Check alert system configuration |

---

## 🔐 **AUTHENTICATION & AUTHORIZATION**

### API Token Authentication
```http
Authorization: Bearer <jwt_token>
```

### Token Requirements
- **Type**: JWT (JSON Web Token)
- **Scope**: `ai:observations:create`
- **Tenant**: Must match X-Tenant-ID header
- **Expiration**: Check token expiration

### Generate API Token
```sql
SELECT auth.generate_api_token(
    p_user_hk => <user_hash_key>,
    p_token_type => 'API_KEY',
    p_scope => 'ai:observations:create',
    p_expires_in => INTERVAL '30 days'
);
```

### Direct Database Access
```sql
-- Function call with proper tenant context
SELECT api.ai_log_observation('{
  "tenantId": "72_Industries_LLC",
  "observationType": "health_concern",
  "severityLevel": "medium",
  "confidenceScore": 0.87
}'::jsonb);
```

---

## 📈 **RATE LIMITS & QUOTAS**

### Standard Limits
- **Observations per minute**: 1,000 per tenant
- **Observations per hour**: 50,000 per tenant  
- **Observations per day**: 1,000,000 per tenant
- **Max request size**: 10MB (including visual evidence)

### Burst Handling
- **Burst capacity**: 5,000 requests in 10 seconds
- **Throttling**: HTTP 429 responses when exceeded
- **Retry-After**: Header indicates when to retry

### Premium Limits
- **Observations per minute**: 10,000 per tenant
- **Observations per hour**: 500,000 per tenant
- **Max request size**: 100MB

---

## 🔄 **INTEGRATION PATTERNS**

### Real-time Integration
```python
import asyncio
import aiohttp
import json

class AIObservationClient:
    def __init__(self, base_url, api_token, tenant_id):
        self.base_url = base_url
        self.api_token = api_token
        self.tenant_id = tenant_id
        self.session = None
    
    async def __aenter__(self):
        self.session = aiohttp.ClientSession(
            headers={
                'Authorization': f'Bearer {self.api_token}',
                'X-Tenant-ID': self.tenant_id,
                'Content-Type': 'application/json'
            }
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.session.close()
    
    async def log_observation(self, observation_data):
        """Log an AI observation asynchronously"""
        async with self.session.post(
            f'{self.base_url}/api/v1/ai/observations',
            json=observation_data
        ) as response:
            return await response.json()

# Usage example
async def main():
    async with AIObservationClient(
        'https://api.onevault.com', 
        'your_api_token_here',
        '72_Industries_LLC'
    ) as client:
        result = await client.log_observation({
            "tenantId": "72_Industries_LLC",
            "observationType": "health_concern",
            "severityLevel": "medium",
            "confidenceScore": 0.87
        })
        print(result)
```

### Batch Processing
```python
def batch_log_observations(observations):
    """Process multiple observations in batch"""
    results = []
    
    for obs in observations:
        try:
            result = api_client.log_observation(obs)
            results.append({
                'observation': obs,
                'result': result,
                'status': 'success'
            })
        except Exception as e:
            results.append({
                'observation': obs,
                'error': str(e),
                'status': 'failed'
            })
    
    return results
```

### Webhook Integration
```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/webhooks/ai-alerts', methods=['POST'])
def handle_ai_alert():
    """Handle AI alert webhook notifications"""
    alert_data = request.json
    
    if alert_data.get('alertCreated'):
        # Process high-priority alert
        send_emergency_notification(alert_data)
    
    return jsonify({'status': 'processed'})

def send_emergency_notification(alert_data):
    """Send emergency notifications for critical alerts"""
    if alert_data['data']['escalationRequired']:
        # Send SMS, email, push notifications
        pass
```

---

## 🧪 **TESTING GUIDELINES**

### Unit Testing
```python
import pytest
import json

class TestAIObservationAPI:
    
    def test_basic_observation_logging(self):
        """Test basic observation logging functionality"""
        request_data = {
            "tenantId": "test_tenant",
            "observationType": "health_concern",
            "severityLevel": "medium",
            "confidenceScore": 0.87
        }
        
        response = api_client.log_observation(request_data)
        
        assert response['success'] == True
        assert 'observationId' in response['data']
        assert response['data']['observationType'] == 'health_concern'
    
    def test_invalid_tenant(self):
        """Test error handling for invalid tenant"""
        request_data = {
            "tenantId": "nonexistent_tenant",
            "observationType": "health_concern", 
            "severityLevel": "medium"
        }
        
        response = api_client.log_observation(request_data)
        
        assert response['success'] == False
        assert response['error_code'] == 'INVALID_TENANT'
    
    def test_alert_generation(self):
        """Test automatic alert generation"""
        request_data = {
            "tenantId": "test_tenant",
            "observationType": "safety_concern",
            "severityLevel": "critical",
            "confidenceScore": 0.95
        }
        
        response = api_client.log_observation(request_data)
        
        assert response['success'] == True
        assert response['data']['alertCreated'] == True
        assert response['data']['escalationRequired'] == True
```

### Load Testing
```python
import asyncio
import time
from concurrent.futures import ThreadPoolExecutor

async def load_test_observations(concurrent_requests=100, total_requests=10000):
    """Load test the AI observation API"""
    
    start_time = time.time()
    results = []
    
    async with AIObservationClient(API_URL, API_TOKEN, TENANT_ID) as client:
        tasks = []
        
        for i in range(total_requests):
            task = client.log_observation({
                "tenantId": TENANT_ID,
                "observationType": "health_concern",
                "severityLevel": "medium",
                "confidenceScore": 0.75 + (i % 25) / 100  # Vary confidence
            })
            tasks.append(task)
            
            if len(tasks) >= concurrent_requests:
                batch_results = await asyncio.gather(*tasks, return_exceptions=True)
                results.extend(batch_results)
                tasks = []
        
        # Process remaining tasks
        if tasks:
            batch_results = await asyncio.gather(*tasks, return_exceptions=True)
            results.extend(batch_results)
    
    end_time = time.time()
    duration = end_time - start_time
    
    success_count = sum(1 for r in results if isinstance(r, dict) and r.get('success'))
    error_count = len(results) - success_count
    
    print(f"Load Test Results:")
    print(f"  Total Requests: {total_requests}")
    print(f"  Successful: {success_count}")
    print(f"  Errors: {error_count}")
    print(f"  Duration: {duration:.2f} seconds")
    print(f"  Requests/second: {total_requests/duration:.2f}")
```

---

## 📊 **MONITORING & OBSERVABILITY**

### Health Check Endpoint
```http
GET /api/v1/ai/observations/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-07-01T14:30:52.123456-07:00",
  "checks": {
    "database": "healthy",
    "audit_system": "healthy",
    "alert_system": "healthy"
  },
  "metrics": {
    "observations_last_hour": 1247,
    "alerts_generated_last_hour": 23,
    "average_response_time_ms": 45
  }
}
```

### Metrics Collection
```python
# Prometheus metrics example
from prometheus_client import Counter, Histogram, Gauge

# Counters
observations_total = Counter('ai_observations_total', 'Total AI observations logged', ['tenant', 'type', 'severity'])
observations_errors = Counter('ai_observations_errors_total', 'Total AI observation errors', ['tenant', 'error_code'])

# Histograms
observation_duration = Histogram('ai_observation_duration_seconds', 'Time to process AI observation')
confidence_scores = Histogram('ai_observation_confidence_scores', 'Distribution of confidence scores')

# Gauges
active_alerts = Gauge('ai_active_alerts', 'Number of active AI alerts', ['tenant', 'severity'])
```

---

## 📋 **CHANGELOG**

### Version 1.0 (July 1, 2025)
- **Initial Release**: Complete AI Observation API implementation
- **Bug Fixes**: Resolved PostgreSQL variable scope and audit parameter order issues
- **Features**: 
  - Real-time observation logging
  - Automatic alert generation
  - Entity and sensor linking
  - Complete audit trail integration
  - Multi-tenant support

### Planned Features (Future Versions)
- **Batch API**: Submit multiple observations in single request
- **GraphQL Support**: Alternative query interface
- **Streaming API**: Real-time observation streaming
- **Advanced Analytics**: Trend analysis and pattern detection

---

## 🔗 **RELATED DOCUMENTATION**

- [AI Observation System Technical Guide](../AI_OBSERVATION_SYSTEM_TECHNICAL_GUIDE.md)
- [Authentication API Contract](./AUTHENTICATION_API_CONTRACT.md)
- [Site Tracking API Contract](./SITE_TRACKING_API_CONTRACT.md)
- [System Health API Contract](./SYSTEM_HEALTH_API_CONTRACT.md)

---

*API Contract Version: 1.0*  
*Last Updated: July 1, 2025*  
*Maintained by: OneVault API Team* 