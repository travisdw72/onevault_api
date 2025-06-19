# Zero Trust AI Agents Examples

This directory contains practical implementations of Zero Trust AI Agents for the One Vault platform, demonstrating how domain-specific AI agents can securely interact with your Data Vault 2.0 database while maintaining complete isolation between domains.

## 🏗️ Architecture Overview

```
Zero Trust AI Agent Architecture
├── Python Implementation (Medical Domain)
│   ├── Medical Diagnosis Agent (MDA-001)
│   ├── Bayesian Inference Engine
│   ├── HIPAA Compliance Framework
│   └── PostgreSQL Integration
│
├── Node.js/TypeScript Implementation (Equine Domain) 
│   ├── Equine Care Agent (ECA-001)
│   ├── Veterinary Expert System
│   ├── Express.js API Server
│   └── Real-time Processing
│
└── Shared Components
    ├── Zero Trust Authentication
    ├── mTLS Certificate Management
    ├── Data Vault 2.0 Integration
    └── Audit & Compliance Logging
```

## 📁 Directory Structure

```
examples/
├── README.md                          # This file
├── USAGE_EXAMPLES.md                  # Comprehensive usage guide
│
├── python/                            # Python Medical Agent Implementation
│   ├── medical_diagnosis_agent.py     # Main MDA-001 implementation
│   ├── requirements.txt               # Python dependencies
│   ├── config/
│   │   └── mda_001_config.json       # Agent configuration
│   └── sample_data/
│       └── patient_case_001.json     # Sample medical case
│
└── node.js/                          # Node.js Equine Agent Implementation
    ├── equine_care_agent.ts          # Main ECA-001 implementation
    ├── package.json                  # Node.js dependencies
    ├── tsconfig.json                 # TypeScript configuration
    ├── config/
    │   └── eca_001_config.json       # Agent configuration
    └── sample_data/
        └── horse_case_001.json       # Sample equine case
```

## 🔑 Key Features

### ✅ **True Domain Isolation**
- **Medical Agent (MDA-001)**: Only processes human medical data, forbidden from equine/manufacturing/financial domains
- **Equine Agent (ECA-001)**: Only processes horse health data, forbidden from human medical/manufacturing/financial domains
- No agent can access or learn from data outside their designated domain

### ✅ **Zero Trust Security**
- **mTLS Authentication**: Every agent authenticated with X.509 certificates
- **Session Management**: 10-minute sessions with continuous validation
- **Network Isolation**: Agents communicate only through Zero Trust Gateway
- **Audit Logging**: Every query and decision immutably logged

### ✅ **AI Reasoning Engines**
- **Medical**: Bayesian inference with clinical guidelines
- **Equine**: Veterinary expert system with breed-specific analysis
- **Evidence-Based**: Each diagnosis includes reasoning chain
- **Confidence Scoring**: Probabilistic assessments with uncertainty handling

### ✅ **Data Vault 2.0 Integration**
- **Tenant Isolation**: Complete multi-tenant data separation
- **Temporal Tracking**: Full history of all diagnoses and decisions
- **Compliance**: HIPAA, GDPR, and veterinary record requirements
- **Performance**: Optimized for scale with strategic indexing

## 🚀 Quick Start

### 1. Python Medical Agent (MDA-001)

```bash
cd python
pip install -r requirements.txt

# Run with sample data
python medical_diagnosis_agent.py \
  --config config/mda_001_config.json \
  --patient-data sample_data/patient_case_001.json
```

**Expected Output:**
```
Diagnosis: Viral Infection
Confidence: 0.87
Risk Assessment: MODERATE_RISK - Follow-up in 24-48 hours
Reasoning: Patient presents with fever, fatigue, and systemic symptoms...
```

### 2. Node.js Equine Agent (ECA-001)

```bash
cd node.js
npm install
npm run build

# Start API server
npm start config/eca_001_config.json
```

**Test API:**
```bash
curl -X POST http://localhost:3001/diagnose \
  -H "Content-Type: application/json" \
  -d @sample_data/horse_case_001.json
```

**Expected Output:**
```json
{
  "success": true,
  "diagnosis": {
    "primary_diagnosis": "Laminitis",
    "confidence": 0.92,
    "urgency": "URGENT",
    "treatment_recommendations": [
      "Immediate box rest with deep bedding",
      "Apply ice boots to affected feet",
      "Anti-inflammatory medication as prescribed"
    ]
  }
}
```

## 🔒 Security Implementation

### Certificate-Based Authentication
Each agent has unique cryptographic identity:

```bash
# Medical Agent Certificate
/etc/ssl/agents/mda-001/
├── agent.crt          # X.509 certificate
├── agent.key          # Private key
└── ca.crt             # Certificate Authority

# Equine Agent Certificate  
/etc/ssl/agents/eca-001/
├── agent.crt          # X.509 certificate
├── agent.key          # Private key
└── ca.crt             # Certificate Authority
```

### Session Management
```sql
-- View active agent sessions
SELECT 
    ah.agent_id,
    ah.domain,
    ases.session_start,
    ases.session_expires,
    ases.permissions
FROM ai_agents.agent_h ah
JOIN ai_agents.agent_session_s ases ON ah.agent_hk = ases.agent_hk
WHERE ases.load_end_date IS NULL;
```

## 🧠 AI Reasoning Examples

### Medical Diagnosis Reasoning Chain
```
1. Patient presents with symptoms: fever, headache, fatigue, nausea
2. Vital signs analysis: Temperature 102.3°F, elevated inflammatory markers
3. Medical history: diabetes, cardiovascular risk factors
4. Bayesian analysis indicates highest probability for: Viral Infection
5. Differential diagnoses: Bacterial Infection (0.75), Inflammatory (0.65)
6. Risk assessment: MODERATE - existing comorbidities increase complexity
7. Recommendations: Supportive care, monitor for complications
```

### Equine Diagnosis Reasoning Chain
```
1. Equine patient (Thoroughbred, 8 years) presents with: lameness, swelling, heat in hoof
2. Vital signs: Heart rate 44 bpm, elevated hoof temperature
3. Behavioral observations: favoring left front, reluctant to move
4. Medical history: previous laminitis episode
5. Veterinary expert system analysis indicates: Laminitis recurrence
6. Urgency assessment: URGENT - progressive condition requiring immediate care
7. Treatment protocol: Box rest, ice therapy, anti-inflammatory management
```

## 📊 Database Integration

### Agent Registration
```sql
-- Agents auto-register on first connection
INSERT INTO ai_agents.agent_h (agent_hk, agent_id, agent_name, domain, tenant_hk)
VALUES (
  util.hash_binary('MDA-001'),
  'MDA-001', 
  'Medical Diagnosis Agent',
  'MEDICAL',
  tenant_hk
);
```

### Diagnosis Storage
```sql
-- Medical diagnoses stored in Data Vault format
SELECT 
  mdh.diagnosis_bk,
  mds.primary_diagnosis,
  mds.confidence_score,
  mds.reasoning_chain,
  mds.load_date
FROM business.medical_diagnosis_h mdh
JOIN business.medical_diagnosis_s mds ON mdh.diagnosis_hk = mds.diagnosis_hk
WHERE mds.load_end_date IS NULL;
```

### Audit Trail
```sql
-- Complete audit trail of agent activities
SELECT 
  ah.agent_name,
  aqls.execution_timestamp,
  aqls.query_type,
  encode(aqls.query_hash, 'hex') as query_signature
FROM ai_agents.agent_h ah  
JOIN ai_agents.agent_query_log_s aqls ON ah.agent_hk = aqls.agent_hk
ORDER BY aqls.execution_timestamp DESC;
```

## 🔍 Monitoring & Observability

### Performance Metrics
```sql
-- Agent performance dashboard
SELECT 
  ah.agent_name,
  COUNT(*) as total_operations,
  AVG(mds.confidence_score) as avg_confidence,
  COUNT(*) FILTER (WHERE mds.load_date >= CURRENT_DATE) as today_operations
FROM ai_agents.agent_h ah
LEFT JOIN business.medical_diagnosis_h mdh ON ah.agent_hk = mdh.agent_hk
LEFT JOIN business.medical_diagnosis_s mds ON mdh.diagnosis_hk = mds.diagnosis_hk
WHERE mds.load_end_date IS NULL
GROUP BY ah.agent_name;
```

### Security Monitoring
```sql
-- Security violations (should be empty)
SELECT 
  ah.agent_name,
  ah.domain,
  ases.permissions,
  ases.session_start
FROM ai_agents.agent_h ah
JOIN ai_agents.agent_session_s ases ON ah.agent_hk = ases.agent_hk
WHERE ases.load_end_date IS NULL
-- Add domain violation detection logic
AND jsonb_array_length(ases.permissions) > 2; -- Should only have 2 domain-specific permissions
```

## 🎯 Next Steps

1. **Deploy Agents**: Follow the deployment guide in `USAGE_EXAMPLES.md`
2. **Add More Domains**: Implement Manufacturing Agent (MFA-001) and Financial Agent (FA-001)
3. **Orchestration**: Build multi-agent orchestration for complex cross-domain insights
4. **Monitoring**: Set up Prometheus metrics and Grafana dashboards
5. **Testing**: Implement comprehensive test suites for each agent

## 🔗 Integration Points

### With Existing Platform
- **Auth System**: Uses existing `auth.tenant_h` for tenant isolation
- **Business Logic**: Extends `business` schema with domain-specific tables
- **Audit Framework**: Integrates with existing audit trails
- **Compliance**: Leverages existing HIPAA/GDPR implementations

### Future Enhancements
- **Real-time Streaming**: Event-driven processing with Kafka integration
- **Advanced ML**: TensorFlow/PyTorch model integration
- **Multi-modal AI**: Support for images, audio, and video analysis
- **Federated Learning**: Secure model updates across tenant boundaries

This implementation demonstrates how AI agents can be both powerful and secure, providing domain expertise while maintaining the highest standards of security, compliance, and data governance. 