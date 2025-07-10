# 🐎 ONE BARN AI - API INTEGRATION CONTRACT

**OneVault Platform Integration Guide for Horse Health AI**  
**Production Database Connection Contract**  
**Prepared for July 7, 2025 Demo**

---

## 🔑 AUTHENTICATION CREDENTIALS

### **Platform API Key (PRODUCTION)**
```
API Key: cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237
Tenant: one_barn_ai
Expires: 2026-07-04 17:04:49 UTC (1 year)
Environment: Production
```

### **Available Demo Users**
| User | Email | Password | Role | Purpose |
|------|-------|----------|------|---------|
| **System Administrator** | admin@onebarnai.com | AdminPass123! | ADMINISTRATOR | Platform management |
| **Travis Woodward** | travis.woodward@onebarnai.com | SecurePass123! | ADMINISTRATOR | CEO & Founder |
| **Michelle Nash** | michelle.nash@onebarnai.com | SupportManager456! | MANAGER | Support Manager |
| **Sarah Robertson** | sarah.robertson@onebarnai.com | VPBusinessDev789! | MANAGER | VP Business Development |
| **Demo User** | demo@onebarnai.com | Demo123! | USER | Presentations |

---

## 🏗️ INTEGRATION ARCHITECTURE

### **Recommended: Platform API Key + User Sessions**
```
One Barn AI Platform
    ↓ (uses API Key for platform access)
OneVault Production Database
    ↓ (individual user login/sessions)
Data Vault 2.0 (complete audit trail by user)
```

**Benefits:**
- ✅ Single API key to manage
- ✅ Individual user authentication & authorization
- ✅ Complete audit trail per user
- ✅ Tenant isolation and security
- ✅ Standard SaaS architecture

---

## 🔌 API ENDPOINTS

### **Base URL**
```
Production: https://api.onevault.com
```

### **1. Authentication Flow**

#### **Step 1: User Login**
```http
POST /api/auth_login
Content-Type: application/json
Authorization: Bearer cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237

{
  "username": "travis.woodward@onebarnai.com",
  "password": "SecurePass123!",
  "ip_address": "192.168.1.100",
  "user_agent": "OneBarnAI/1.0",
  "auto_login": true
}
```

**Response (Success):**
```json
{
  "success": true,
  "session_token": "sess_a1b2c3d4e5f6...",
  "user_id": "user_hk_hex",
  "tenant_id": "one_barn_ai",
  "expires_at": "2025-07-05T17:04:49Z",
  "user_info": {
    "email": "travis.woodward@onebarnai.com",
    "first_name": "Travis",
    "last_name": "Woodward",
    "role": "ADMINISTRATOR"
  }
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Invalid credentials",
  "error_code": "AUTH_INVALID_CREDENTIALS"
}
```

#### **Step 2: Session Validation**
```http
POST /api/auth_validate_session
Content-Type: application/json
Authorization: Bearer cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237

{
  "session_token": "sess_a1b2c3d4e5f6...",
  "ip_address": "192.168.1.100",
  "user_agent": "OneBarnAI/1.0"
}
```

#### **Step 3: Logout**
```http
POST /api/auth_logout
Content-Type: application/json
Authorization: Bearer cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237

{
  "session_token": "sess_a1b2c3d4e5f6..."
}
```

### **2. Horse Health AI Endpoints**

#### **Create AI Session**
```http
POST /api/ai_create_session
Content-Type: application/json
Authorization: Bearer cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237

{
  "tenant_id": "one_barn_ai",
  "agent_type": "horse_health_specialist",
  "session_purpose": "health_analysis",
  "metadata": {
    "client_app": "OneBarnAI",
    "feature": "photo_analysis"
  }
}
```

#### **AI Photo Analysis**
```http
POST /api/ai_secure_chat
Content-Type: application/json
Authorization: Bearer cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237

{
  "session_id": "ai_sess_12345",
  "message": "Analyze this horse photo for health issues",
  "context": {
    "image_data": "base64_encoded_image",
    "horse_breed": "thoroughbred",
    "horse_age": 5,
    "analysis_type": "lameness_detection"
  }
}
```

### **3. Event Tracking**

#### **Track Site Events**
```http
POST /api/track_site_event
Content-Type: application/json
Authorization: Bearer cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237

{
  "ip_address": "192.168.1.100",
  "user_agent": "OneBarnAI/1.0",
  "page_url": "https://app.onebarnai.com/analysis",
  "event_type": "horse_analysis_completed",
  "event_data": {
    "horse_id": "horse_123",
    "analysis_result": "healthy",
    "confidence": 0.95
  }
}
```

### **4. System Health**

#### **Health Check**
```http
GET /api/system_health_check
Authorization: Bearer cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237
```

---

## 📋 REQUEST/RESPONSE FORMATS

### **Standard Headers**
```http
Content-Type: application/json
Authorization: Bearer cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237
User-Agent: OneBarnAI/1.0 (horse-health-platform)
```

### **Error Response Format**
```json
{
  "success": false,
  "error": "Error description",
  "error_code": "ERROR_CODE",
  "timestamp": "2025-07-04T17:04:49Z",
  "request_id": "req_abc123"
}
```

### **Success Response Format**
```json
{
  "success": true,
  "data": { /* response data */ },
  "timestamp": "2025-07-04T17:04:49Z",
  "processing_time_ms": 150
}
```

---

## 🔒 SECURITY & COMPLIANCE

### **API Key Security**
- ✅ **Store securely**: Never expose in client-side code
- ✅ **Use HTTPS only**: All API calls must use TLS 1.2+
- ✅ **Rotate regularly**: 1-year expiration (expires July 2026)
- ✅ **Monitor usage**: All API calls are logged and audited

### **Data Vault 2.0 Compliance**
- ✅ **Complete audit trail**: Every action tracked by user
- ✅ **Tenant isolation**: Your data is completely isolated
- ✅ **GDPR/HIPAA ready**: Compliant data handling
- ✅ **Immutable history**: All changes are permanently recorded

### **Rate Limiting**
- **Authentication**: 1000 requests/hour per API key
- **AI Analysis**: 100 requests/hour per session
- **Event Tracking**: 10,000 events/hour per tenant
- **Health Checks**: Unlimited

---

## 🚨 ERROR HANDLING

### **Common Error Codes**
| Code | Meaning | Action |
|------|---------|--------|
| `AUTH_INVALID_API_KEY` | Invalid API key | Check API key value |
| `AUTH_INVALID_CREDENTIALS` | Wrong user/password | Verify user credentials |
| `SESSION_EXPIRED` | Session timeout | Re-authenticate user |
| `TENANT_NOT_FOUND` | Invalid tenant | Contact support |
| `RATE_LIMIT_EXCEEDED` | Too many requests | Implement backoff |
| `AI_SESSION_INVALID` | AI session expired | Create new AI session |

### **HTTP Status Codes**
- **200**: Success
- **400**: Bad request (check request format)
- **401**: Unauthorized (check API key/session)
- **403**: Forbidden (insufficient permissions)
- **429**: Rate limited
- **500**: Server error (contact support)

---

## 🧪 TESTING GUIDE

### **1. Test API Key**
```bash
curl -X GET "https://api.onevault.com/api/system_health_check" \
  -H "Authorization: Bearer cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237"
```

### **2. Test User Authentication**
```bash
curl -X POST "https://api.onevault.com/api/auth_login" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer cc5fd75ab4ba76c5aeb55bb2afb94732dd4869454d53586800b608a601588237" \
  -d '{
    "username": "demo@onebarnai.com",
    "password": "Demo123!",
    "auto_login": true
  }'
```

### **3. Demo User Flow**
1. **Login** with demo@onebarnai.com
2. **Create AI session** for horse analysis
3. **Submit photo** for health analysis
4. **Track events** for user analytics
5. **Logout** when done

---

## 📞 SUPPORT & CONTACT

### **Technical Support**
- **Email**: api-support@onevault.com
- **Documentation**: https://docs.onevault.com
- **Status Page**: https://status.onevault.com

### **Emergency Contact**
- **24/7 Support**: +1-800-ONEVAULT
- **Slack**: #one-barn-ai-support
- **Emergency Email**: emergency@onevault.com

### **Account Management**
- **Primary Contact**: Travis Woodward (travis.woodward@onebarnai.com)
- **Technical Contact**: Michelle Nash (michelle.nash@onebarnai.com)
- **Business Contact**: Sarah Robertson (sarah.robertson@onebarnai.com)

---

## 🎯 JULY 7, 2025 DEMO CHECKLIST

### **Pre-Demo Setup**
- [ ] Test API key connectivity
- [ ] Verify all demo user logins
- [ ] Test horse photo analysis flow
- [ ] Confirm AI session creation
- [ ] Validate event tracking
- [ ] Check system health status

### **Demo Scenarios**
1. **Admin Dashboard**: Login as Travis (CEO)
2. **Photo Analysis**: Upload horse image for AI analysis
3. **User Management**: Show Michelle (Support) capabilities
4. **Business Analytics**: Display Sarah (Business Dev) metrics
5. **Demo Experience**: Use demo user for client simulation

### **Success Metrics**
- ✅ Sub-second authentication response
- ✅ AI analysis completion < 5 seconds
- ✅ 99.9% uptime during demo period
- ✅ Complete audit trail demonstration
- ✅ Multi-role access showcase

---

**🐎🤖 ONE BARN AI: READY TO REVOLUTIONIZE EQUINE HEALTHCARE!**

*This contract is valid for the One Barn AI production environment and supersedes all previous integration documentation.* 