# One_Barn_AI Enterprise Demo Setup Guide
## July 7, 2025 Demo Preparation

### Prerequisites ✅
- Database: `one_vault_site_testing` (localhost)
- 55/56 database functions operational
- API endpoint: `https://onevault-api.onrender.com`
- Canvas frontend ready

### Execution Steps

#### Step 1: Execute SQL Setup Plan
Run your existing `one_barn_ai_setup_plan.sql` in pgAdmin:

```sql
-- This will create:
-- ✅ one_barn_ai tenant (enterprise_partner)
-- ✅ admin@onebarnai.com user
-- ✅ Horse Health Specialist AI agent
-- ✅ Demo horses (Buttercup & Thunder)
-- ✅ Additional team users
```

#### Step 2: Test Authentication
```sql
SELECT api.auth_login('{
    "username": "admin@onebarnai.com",
    "password": "HorseHealth2025!",
    "ip_address": "127.0.0.1",
    "user_agent": "OneVault-Demo-Client",
    "auto_login": true
}');
```

#### Step 3: Test AI Session Creation
```sql
SELECT api.ai_create_session('{
    "tenant_id": "one_barn_ai",
    "agent_type": "horse_health_specialist",
    "session_purpose": "demo_preparation"
}');
```

### Demo Scenarios Ready 🎭

1. **Healthy Horse Analysis** (Buttercup)
   - Thoroughbred mare, 8 years old
   - Excellent health baseline

2. **Minor Concern Detection** (Thunder)
   - Quarter Horse gelding, 12 years old
   - Grade 1 lameness demonstration

### API Endpoints for Demo 🔗

1. **Authentication**: `/api/v1/auth/login`
2. **AI Analysis**: `/api/v1/ai/analyze`
3. **Horse Records**: `/api/v1/entities/horses`
4. **Health Reports**: `/api/v1/reports/health`

### Success Metrics 📊

- ✅ Tenant isolation working
- ✅ AI agent responding
- ✅ API returning tenant-scoped data
- ✅ Canvas shows admin interface

### Demo Day Checklist 📋

- [ ] Database connection tested
- [ ] One_Barn_AI tenant active
- [ ] Admin login working
- [ ] AI agent responsive
- [ ] Canvas app configured
- [ ] Demo data loaded
- [ ] API endpoints tested

### Revenue Model Presentation 💰

**Partnership Benefits:**
- Custom AI agents vs generic services
- OneVault handles infrastructure
- One_Barn_AI focuses on horse expertise
- Revenue sharing model
- Faster time to market

**Technical Advantages:**
- Data Vault 2.0 for historical analysis
- Multi-tenant isolation
- Enterprise-grade security
- Scalable AI infrastructure
- Custom learning capabilities 