# Zero Trust AI Agents - Usage Examples

This document demonstrates how to deploy and use the Zero Trust AI Agents with your Data Vault 2.0 platform.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Data Sources  │───▶│ Zero Trust       │───▶│ Domain Specialist   │
│                 │    │ Gateway          │    │ AI Agents           │
│ • Medical Data  │    │                  │    │                     │
│ • Horse Health  │    │ • mTLS Auth      │    │ • MDA-001 (Python) │
│ • Manufacturing │    │ • Session Mgmt   │    │ • ECA-001 (Node.js) │
│ • Financial     │    │ • Deep Inspection│    │ • MFA-001           │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │ Data Vault 2.0   │
                       │ PostgreSQL       │
                       │                  │
                       │ • Tenant Isolation│
                       │ • Audit Trails   │
                       │ • Compliance     │
                       └──────────────────┘
```

## 🐍 Python Medical Diagnosis Agent (MDA-001)

### Installation

```bash
cd database/scripts/ai_agents_scripts/examples/python
pip install -r requirements.txt
```

### Configuration

Create `/etc/ssl/agents/mda-001/` directory and place certificates:
- `agent.crt` - Agent X.509 certificate
- `agent.key` - Agent private key

### Usage

```python
from medical_diagnosis_agent import MedicalDiagnosisAgent

# Initialize agent
agent = MedicalDiagnosisAgent('config/mda_001_config.json')

if agent.initialize():
    # Process medical case
    patient_data = {
        'patient_id': 'PATIENT_12345',
        'symptoms': ['fever', 'headache', 'fatigue', 'nausea'],
        'vital_signs': {
            'temperature': 102.3,
            'heart_rate': 95,
            'blood_pressure': '130/85'
        },
        'medical_history': ['hypertension', 'diabetes_type_2'],
        'risk_factors': ['age_over_65', 'diabetes']
    }
    
    # Get diagnosis
    diagnosis = agent.process_medical_case(patient_data)
    
    print(f"Primary Diagnosis: {diagnosis.primary_diagnosis}")
    print(f"Confidence: {diagnosis.confidence_score:.2f}")
    print(f"Risk Assessment: {diagnosis.risk_assessment}")
    
    # Get patient history
    history = agent.get_diagnosis_history('PATIENT_12345')
    for record in history:
        print(f"{record['load_date']}: {record['primary_diagnosis']}")
    
    agent.shutdown()
```

### Command Line Usage

```bash
# Process single case
python medical_diagnosis_agent.py \
    --config config/mda_001_config.json \
    --patient-data cases/patient_case_001.json

# Start API server mode
python medical_diagnosis_agent.py \
    --config config/mda_001_config.json \
    --server-mode \
    --port 8001
```

### API Endpoints (when in server mode)

```bash
# Health check
curl https://mda-001.onevault.com:8001/health

# Process diagnosis
curl -X POST https://mda-001.onevault.com:8001/diagnose \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SESSION_TOKEN" \
  --cert /etc/ssl/agents/mda-001/agent.crt \
  --key /etc/ssl/agents/mda-001/agent.key \
  -d @patient_case.json
```

## 🐴 Node.js Equine Care Agent (ECA-001)

### Installation

```bash
cd database/scripts/ai_agents_scripts/examples/node.js
npm install
npm run build
```

### Configuration

Update `config/eca_001_config.json` with your tenant information and certificate paths.

### Usage

```bash
# Start the agent
npm start config/eca_001_config.json

# Development mode with auto-reload
npm run dev
```

### API Usage Examples

```bash
# Health check
curl https://eca-001.onevault.com:3001/health

# Equine diagnosis
curl -X POST https://eca-001.onevault.com:3001/diagnose \
  -H "Content-Type: application/json" \
  --cert /etc/ssl/agents/eca-001/agent.crt \
  --key /etc/ssl/agents/eca-001/agent.key \
  -d '{
    "horseId": "HORSE_789",
    "breed": "Thoroughbred",
    "age": 8,
    "symptoms": ["lameness", "swelling", "heat_in_hoof"],
    "vitalSigns": {
      "heartRate": 44,
      "respiratoryRate": 16,
      "temperature": 100.8
    },
    "behaviorObservations": ["favoring_left_front", "reluctant_to_move"],
    "medicalHistory": ["previous_laminitis"],
    "vaccinationRecord": [
      {
        "vaccine": "Eastern_Western_Encephalitis",
        "date": "2023-04-15",
        "veterinarian": "Dr. Smith"
      }
    ]
  }'

# Get horse history
curl https://eca-001.onevault.com:3001/history/HORSE_789 \
  --cert /etc/ssl/agents/eca-001/agent.crt \
  --key /etc/ssl/agents/eca-001/agent.key
```

## 🔒 Zero Trust Security Implementation

### Certificate Generation

```bash
# Generate CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 365 -key ca.key -out ca.crt

# Generate agent certificates
# Medical Agent (MDA-001)
openssl genrsa -out mda-001.key 2048
openssl req -new -key mda-001.key -out mda-001.csr \
  -subj "/C=US/ST=CA/L=SF/O=OneVault/OU=AI-Agents/CN=MDA-001"
openssl x509 -req -in mda-001.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out mda-001.crt -days 365

# Equine Agent (ECA-001)
openssl genrsa -out eca-001.key 2048
openssl req -new -key eca-001.key -out eca-001.csr \
  -subj "/C=US/ST=CA/L=SF/O=OneVault/OU=AI-Agents/CN=ECA-001"
openssl x509 -req -in eca-001.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out eca-001.crt -days 365
```

### Database Integration

The agents automatically integrate with your existing Data Vault 2.0 schema:

```sql
-- Agents register themselves
SELECT * FROM ai_agents.agent_h WHERE agent_id IN ('MDA-001', 'ECA-001');

-- View agent sessions
SELECT 
    ah.agent_id,
    ah.agent_name,
    ases.session_token,
    ases.session_start,
    ases.session_expires,
    ases.permissions
FROM ai_agents.agent_h ah
JOIN ai_agents.agent_session_s ases ON ah.agent_hk = ases.agent_hk
WHERE ases.load_end_date IS NULL;

-- View diagnosis results
SELECT 
    ah.agent_name,
    mdh.diagnosis_bk,
    mds.primary_diagnosis,
    mds.confidence_score,
    mds.load_date
FROM ai_agents.agent_h ah
JOIN business.medical_diagnosis_h mdh ON ah.agent_hk = mdh.agent_hk
JOIN business.medical_diagnosis_s mds ON mdh.diagnosis_hk = mds.diagnosis_hk
WHERE mds.load_end_date IS NULL
ORDER BY mds.load_date DESC;
```

## 🏗️ Multi-Agent Orchestration Example

Here's how multiple agents work together while maintaining domain isolation:

```python
# Agent Orchestrator Example
from medical_diagnosis_agent import MedicalDiagnosisAgent
from equine_care_agent import EquineCareAgent  # If Python version existed
import asyncio

class AgentOrchestrator:
    def __init__(self):
        self.medical_agent = MedicalDiagnosisAgent('config/mda_001_config.json')
        # Note: In practice, you'd use HTTP calls to Node.js ECA-001
        
    async def process_cross_domain_case(self, case_data):
        """
        Process a case that might need multiple domain expertise
        Each agent only sees data relevant to their domain
        """
        results = {}
        
        # Medical analysis (human)
        if case_data.get('human_patient'):
            medical_result = self.medical_agent.process_medical_case(
                case_data['human_patient']
            )
            results['medical'] = {
                'diagnosis': medical_result.primary_diagnosis,
                'confidence': medical_result.confidence_score,
                'agent': 'MDA-001'
            }
        
        # Equine analysis (via HTTP API to Node.js agent)
        if case_data.get('horse_patient'):
            import requests
            response = requests.post(
                'https://eca-001.onevault.com:3001/diagnose',
                json=case_data['horse_patient'],
                cert=('/etc/ssl/agents/orchestrator/cert.crt', 
                      '/etc/ssl/agents/orchestrator/key.key'),
                timeout=30
            )
            if response.status_code == 200:
                equine_result = response.json()
                results['equine'] = {
                    'diagnosis': equine_result['diagnosis']['primary_diagnosis'],
                    'confidence': equine_result['diagnosis']['confidence'],
                    'agent': 'ECA-001'
                }
        
        return results

# Usage
orchestrator = AgentOrchestrator()
case_data = {
    'human_patient': {
        'patient_id': 'HUMAN_123',
        'symptoms': ['fever', 'joint_pain'],
        # ... medical data
    },
    'horse_patient': {
        'horseId': 'HORSE_456', 
        'symptoms': ['lameness', 'swelling'],
        # ... equine data
    }
}

results = await orchestrator.process_cross_domain_case(case_data)
print("Cross-domain analysis results:", results)
```

## 🔍 Monitoring and Audit

### Agent Performance Monitoring

```sql
-- Agent query performance
SELECT 
  ah.agent_name,
  COUNT(*) as total_queries,
  AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - aqls.execution_timestamp))) as avg_response_time,
  COUNT(*) FILTER (WHERE aqls.execution_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour') as queries_last_hour
FROM ai_agents.agent_h ah
JOIN ai_agents.agent_query_log_s aqls ON ah.agent_hk = aqls.agent_hk
WHERE aqls.load_end_date IS NULL
GROUP BY ah.agent_name;

-- Diagnosis accuracy tracking (would need feedback mechanism)
SELECT 
  ah.agent_name,
  mds.primary_diagnosis,
  AVG(mds.confidence_score) as avg_confidence,
  COUNT(*) as diagnosis_count
FROM ai_agents.agent_h ah
JOIN business.medical_diagnosis_h mdh ON ah.agent_hk = mdh.agent_hk  
JOIN business.medical_diagnosis_s mds ON mdh.diagnosis_hk = mds.diagnosis_hk
WHERE mds.load_end_date IS NULL
AND mds.load_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY ah.agent_name, mds.primary_diagnosis
ORDER BY avg_confidence DESC;
```

### Security Audit

```sql
-- Session security audit
SELECT 
  ah.agent_name,
  ases.session_start,
  ases.session_expires,
  CASE 
    WHEN ases.session_expires < CURRENT_TIMESTAMP THEN 'EXPIRED'
    ELSE 'ACTIVE'
  END as session_status,
  ases.permissions
FROM ai_agents.agent_h ah
JOIN ai_agents.agent_session_s ases ON ah.agent_hk = ases.agent_hk
WHERE ases.load_end_date IS NULL
ORDER BY ases.session_start DESC;

-- Cross-domain access violations (should be empty)
SELECT 
  ah.agent_name,
  ah.domain,
  aqls.query_hash,
  aqls.execution_timestamp
FROM ai_agents.agent_h ah
JOIN ai_agents.agent_query_log_s aqls ON ah.agent_hk = aqls.agent_hk
WHERE aqls.load_end_date IS NULL
-- Add logic to detect cross-domain queries
AND aqls.execution_timestamp >= CURRENT_DATE - INTERVAL '7 days';
```

## 📊 Performance Benchmarks

### Expected Performance Metrics

| Agent | Avg Response Time | Throughput (req/min) | Memory Usage | CPU Usage |
|-------|-------------------|---------------------|--------------|-----------|
| MDA-001 (Python) | 250ms | 50 | 512MB | 15% |
| ECA-001 (Node.js) | 180ms | 80 | 256MB | 12% |

### Load Testing

```bash
# Python Medical Agent Load Test
ab -n 1000 -c 10 -p patient_case.json -T application/json \
  -E /etc/ssl/agents/test/cert.crt \
  https://mda-001.onevault.com:8001/diagnose

# Node.js Equine Agent Load Test  
ab -n 1000 -c 10 -p horse_case.json -T application/json \
  -E /etc/ssl/agents/test/cert.crt \
  https://eca-001.onevault.com:3001/diagnose
```

## 🚀 Deployment

### Docker Deployment

```dockerfile
# Medical Agent Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8001
CMD ["python", "medical_diagnosis_agent.py", "--config", "config/mda_001_config.json", "--server-mode"]

# Equine Agent Dockerfile  
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3001
CMD ["npm", "start"]
```

### Kubernetes Deployment

```yaml
# medical-agent-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: medical-diagnosis-agent
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mda-001
  template:
    metadata:
      labels:
        app: mda-001
    spec:
      containers:
      - name: mda-001
        image: onevault/medical-diagnosis-agent:v1.0.0
        ports:
        - containerPort: 8001
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        volumeMounts:
        - name: agent-certs
          mountPath: /etc/ssl/agents/mda-001
          readOnly: true
      volumes:
      - name: agent-certs
        secret:
          secretName: mda-001-certs
```

## 🔐 Security Best Practices

1. **Certificate Rotation**: Rotate agent certificates every 90 days
2. **Session Management**: 10-minute session timeouts with max 3 renewals
3. **Network Isolation**: Each agent runs in its own network namespace
4. **Audit Logging**: All queries and decisions are logged immutably
5. **Domain Isolation**: Agents cannot access data outside their domain
6. **Input Validation**: All inputs are validated against strict schemas
7. **Rate Limiting**: API endpoints are rate-limited per agent
8. **Monitoring**: Real-time monitoring for anomalous behavior

## 📝 Troubleshooting

### Common Issues

1. **Certificate Errors**
   ```bash
   # Verify certificate validity
   openssl x509 -in /etc/ssl/agents/mda-001/agent.crt -text -noout
   
   # Check certificate chain
   openssl verify -CAfile /etc/ssl/ca/ca.crt /etc/ssl/agents/mda-001/agent.crt
   ```

2. **Database Connection Issues**
   ```bash
   # Test database connection
   psql "host=postgres.onevault.com port=5432 dbname=one_vault user=postgres sslmode=require"
   
   # Check agent registration
   SELECT * FROM ai_agents.agent_h WHERE agent_id = 'MDA-001';
   ```

3. **Session Expiration**
   ```sql
   -- Check session status
   SELECT 
     agent_id,
     session_expires,
     CASE WHEN session_expires < CURRENT_TIMESTAMP THEN 'EXPIRED' ELSE 'VALID' END
   FROM ai_agents.agent_h ah
   JOIN ai_agents.agent_session_s ases ON ah.agent_hk = ases.agent_hk
   WHERE ases.load_end_date IS NULL;
   ```

This comprehensive guide shows how your Zero Trust AI Agents integrate seamlessly with your existing Data Vault 2.0 platform while maintaining complete domain isolation and enterprise-grade security. 