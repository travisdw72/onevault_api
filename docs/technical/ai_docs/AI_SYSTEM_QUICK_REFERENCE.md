# OneVault AI System - Quick Reference Guide
## Developer Quick Start & API Reference

### Purpose: Get AI observations working in 5 minutes 🚀

---

## ⚡ **QUICK START**

### 1. Generate API Token
```sql
SELECT auth.generate_api_token(
    p_user_hk => <your_user_hash_key>,
    p_token_type => 'API_KEY',
    p_scope => 'ai:observations:create',
    p_expires_in => INTERVAL '30 days'
);
```

### 2. Log Your First AI Observation
```python
import requests

response = requests.post('https://api.onevault.com/ai/observations', 
    json={
        "tenantId": "your_tenant_id",
        "observationType": "health_concern",
        "severityLevel": "medium",
        "confidenceScore": 0.87
    },
    headers={
        'Authorization': 'Bearer your_api_token',
        'X-Tenant-ID': 'your_tenant_id'
    }
)
print(response.json())
```

### 3. Expected Response
```json
{
  "success": true,
  "message": "AI observation logged successfully",
  "data": {
    "observationId": "ai-obs-health_concern-20250701-143052-a1b2c3d4",
    "alertCreated": false,
    "timestamp": "2025-07-01T14:30:52.123456-07:00"
  }
}
```

---

## 📋 **API REFERENCE**

### Endpoint
```
POST /api/v1/ai/observations
Content-Type: application/json
Authorization: Bearer <token>
X-Tenant-ID: <tenant_id>
```

### Required Fields
```json
{
  "tenantId": "string",
  "observationType": "behavior_anomaly|health_concern|safety_concern|equipment_malfunction|security_breach",
  "severityLevel": "low|medium|high|critical|emergency"
}
```

### Optional Fields
```json
{
  "confidenceScore": 0.0-1.0,
  "entityId": "horse_thunder_bolt_001",
  "sensorId": "camera_north_pasture_001",
  "observationData": {...},
  "visualEvidence": {...},
  "recommendedActions": [...]
}
```

---

## 🔧 **DATABASE FUNCTION**

### Direct Database Call
```sql
SELECT api.ai_log_observation('{
  "tenantId": "72_Industries_LLC",
  "observationType": "health_concern",
  "severityLevel": "medium",
  "confidenceScore": 0.87,
  "entityId": "horse_thunder_bolt_001",
  "sensorId": "camera_north_pasture_001"
}'::jsonb);
```

---

## 🚨 **ALERT GENERATION RULES**

| Severity | Confidence | Alert Created | Escalation |
|----------|------------|---------------|------------|
| Emergency | Any | ✅ Always | Immediate |
| Critical | Any | ✅ Always | Immediate |
| High | ≥85% | ✅ Yes | 1 Hour |
| Medium | ≥90% | ✅ Yes | Same Day |
| Low | Any | ❌ No | N/A |

**Special Cases:**
- Safety concerns: Alert if confidence ≥80%
- Security breaches: Alert if confidence ≥80%

---

## ❌ **COMMON ERROR CODES**

| Error Code | Fix |
|------------|-----|
| `MISSING_PARAMETERS` | Include tenantId, observationType, severityLevel |
| `INVALID_TENANT` | Check tenant exists in auth.tenant_h |
| `INVALID_OBSERVATION_TYPE` | Use valid enum values |
| `INVALID_SEVERITY_LEVEL` | Use: low, medium, high, critical, emergency |
| `ENTITY_NOT_FOUND` | Verify entityId exists for your tenant |

---

## 🐍 **PYTHON INTEGRATION**

### Simple Integration
```python
class OneVaultAI:
    def __init__(self, api_token, tenant_id, base_url="https://api.onevault.com"):
        self.api_token = api_token
        self.tenant_id = tenant_id
        self.base_url = base_url
    
    def log_observation(self, observation_type, severity, confidence=0.75, **kwargs):
        payload = {
            "tenantId": self.tenant_id,
            "observationType": observation_type,
            "severityLevel": severity,
            "confidenceScore": confidence,
            **kwargs
        }
        
        response = requests.post(
            f"{self.base_url}/api/v1/ai/observations",
            json=payload,
            headers={
                "Authorization": f"Bearer {self.api_token}",
                "X-Tenant-ID": self.tenant_id
            }
        )
        return response.json()

# Usage
ai = OneVaultAI("your_token", "your_tenant")
result = ai.log_observation("health_concern", "medium", 0.87)
```

### Async Integration
```python
import aiohttp
import asyncio

async def log_observation_async(session, observation_data):
    async with session.post('/api/v1/ai/observations', json=observation_data) as response:
        return await response.json()

async def main():
    headers = {
        'Authorization': 'Bearer your_token',
        'X-Tenant-ID': 'your_tenant'
    }
    
    async with aiohttp.ClientSession(headers=headers) as session:
        result = await log_observation_async(session, {
            "tenantId": "your_tenant",
            "observationType": "health_concern",
            "severityLevel": "medium"
        })
        print(result)
```

---

## 🧪 **TESTING**

### Unit Test Example
```python
def test_ai_observation():
    ai = OneVaultAI("test_token", "test_tenant")
    
    result = ai.log_observation(
        observation_type="health_concern",
        severity="medium",
        confidence=0.87,
        entityId="horse_test_001"
    )
    
    assert result['success'] == True
    assert 'observationId' in result['data']
```

### Load Test
```python
import concurrent.futures
import time

def load_test_observations(num_requests=1000):
    ai = OneVaultAI("your_token", "your_tenant")
    
    start_time = time.time()
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
        futures = [
            executor.submit(ai.log_observation, "health_concern", "medium", 0.75)
            for _ in range(num_requests)
        ]
        
        results = [future.result() for future in futures]
    
    duration = time.time() - start_time
    success_count = sum(1 for r in results if r.get('success'))
    
    print(f"Processed {num_requests} requests in {duration:.2f}s")
    print(f"Success rate: {success_count/num_requests*100:.1f}%")
    print(f"Requests/second: {num_requests/duration:.1f}")
```

---

## 📊 **MONITORING & DEBUGGING**

### Health Check
```python
def check_ai_system_health():
    response = requests.get(
        "https://api.onevault.com/api/v1/ai/observations/health",
        headers={"Authorization": f"Bearer {api_token}"}
    )
    return response.json()
```

### Audit Trail Check
```sql
-- Check recent AI observations
SELECT 
    observation_type,
    severity_level,
    confidence_score,
    observation_timestamp
FROM business.ai_observation_details_s 
WHERE load_end_date IS NULL 
ORDER BY observation_timestamp DESC 
LIMIT 10;

-- Check audit events
SELECT 
    event_type,
    event_description,
    event_timestamp
FROM audit.security_event_s 
WHERE event_type = 'AI_OBSERVATION_LOGGED'
AND load_end_date IS NULL
ORDER BY event_timestamp DESC 
LIMIT 10;
```

---

## 🔍 **ENTITY & SENSOR LINKING**

### Horse/Equipment Context
```python
# Log observation with specific horse and camera
result = ai.log_observation(
    observation_type="behavior_anomaly",
    severity="high",
    confidence=0.92,
    entityId="horse_thunder_bolt_001",      # Specific horse
    sensorId="camera_north_pasture_001",    # Specific camera
    observationData={
        "behavior_type": "aggressive_interaction",
        "duration_minutes": 8,
        "location": "north_pasture"
    }
)
```

### Equipment Monitoring
```python
# Equipment malfunction detection
result = ai.log_observation(
    observation_type="equipment_malfunction",
    severity="critical",
    confidence=0.98,
    entityId="water_pump_north_001",
    sensorId="pressure_sensor_001",
    observationData={
        "malfunction_type": "pressure_drop",
        "current_pressure": 15.2,
        "expected_pressure": 45.0
    }
)
```

---

## 🚀 **PRODUCTION TIPS**

### Best Practices
1. **Always include confidence scores** - helps with alert accuracy
2. **Use entity/sensor IDs** - enables business intelligence
3. **Include observationData** - provides context for analysis
4. **Handle errors gracefully** - implement retry logic for transient failures
5. **Monitor performance** - track response times and success rates

### Performance Optimization
- **Batch observations** when possible (coming in v1.1)
- **Use async calls** for high-volume applications
- **Cache entity/sensor lookups** to reduce database calls
- **Set reasonable timeouts** (5-10 seconds recommended)

### Security
- **Rotate API tokens** regularly (30-day expiration recommended)
- **Validate input data** before sending to API
- **Use HTTPS only** - never send tokens over HTTP
- **Log security events** for audit compliance

---

## 📚 **COMPLETE DOCUMENTATION**

- **[Full Technical Guide](./AI_OBSERVATION_SYSTEM_TECHNICAL_GUIDE.md)** - Complete implementation details
- **[API Contract](./api_contracts/AI_OBSERVATION_API_CONTRACT.md)** - Full API specification
- **[System Overview](./AI_SYSTEM_COMPLETE_OVERVIEW.md)** - Architecture and business context

---

## 🔗 **RELATED APIS**

### Other OneVault APIs
```python
# Site tracking
api.track_site_event(tenant_id, user_id, event_type, event_data)

# System health
api.get_system_health()

# Token generation
auth.generate_api_token(user_hk, token_type, scope, expires_in)
```

---

## ⚡ **TL;DR - Copy & Paste Example**

```python
import requests

# Configure
API_TOKEN = "your_api_token_here"
TENANT_ID = "your_tenant_id_here"
BASE_URL = "https://api.onevault.com"

# Log AI observation
response = requests.post(f"{BASE_URL}/api/v1/ai/observations", 
    json={
        "tenantId": TENANT_ID,
        "observationType": "health_concern",
        "severityLevel": "medium",
        "confidenceScore": 0.87,
        "entityId": "horse_thunder_bolt_001",
        "observationData": {
            "symptoms": ["limping"],
            "location": "north_pasture"
        }
    },
    headers={
        "Authorization": f"Bearer {API_TOKEN}",
        "X-Tenant-ID": TENANT_ID
    }
)

result = response.json()
print(f"Success: {result['success']}")
if result['success']:
    print(f"Observation ID: {result['data']['observationId']}")
    print(f"Alert Created: {result['data']['alertCreated']}")
```

---

*Quick Reference Version: 1.0*  
*Last Updated: July 1, 2025*  
*For detailed documentation see: [Complete System Overview](./AI_SYSTEM_COMPLETE_OVERVIEW.md)* 