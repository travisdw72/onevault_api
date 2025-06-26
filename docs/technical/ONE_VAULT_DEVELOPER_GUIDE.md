# One Vault Platform - Developer Guide
## Enterprise Multi-Tenant Data Vault 2.0 SaaS Platform

### Document Information
- **Platform Version**: 2.0.0
- **Last Updated**: 2024-12-28
- **Status**: Production Ready
- **Architecture**: Data Vault 2.0 with Multi-Tenant Isolation
- **Compliance**: HIPAA, GDPR, CCPA, SOX compliant
- **Database**: PostgreSQL with Neon Cloud support

---

## 🎯 **Platform Overview**

The One Vault Platform is an enterprise-grade, multi-tenant SaaS platform built on Data Vault 2.0 methodology providing:

- ✅ **Complete Tenant Isolation** - Data Vault 2.0 with tenant hash keys
- ✅ **Production-Grade APIs** - RESTful APIs with comprehensive rate limiting
- ✅ **Site Tracking System** - Universal analytics for any business type
- ✅ **Authentication & Authorization** - Role-based access with API tokens
- ✅ **Audit & Compliance** - Full HIPAA/GDPR compliance with audit trails
- ✅ **Database Functions** - Direct PostgreSQL function access
- ✅ **Scalable Architecture** - Cloud-native with Neon PostgreSQL

---

## 🏗️ **Architecture Overview**

### Data Flow Architecture
```
[Customer Website] 
    ↓ (API Key Authentication)
[One Vault API Gateway]
    ↓ (Tenant Isolation)
[PostgreSQL Functions]
    ↓ (Data Vault 2.0 Processing)
[Raw → Staging → Business Layers]
    ↓ (Real-time Analytics)
[Dashboard & Reporting]
```

### Database Schema Organization
```sql
-- Core Schemas
auth        -- Authentication, users, roles, sessions, API tokens
raw         -- Raw data ingestion (ELT landing zone)
staging     -- Data validation and processing
business    -- Business entities and processed data
util        -- Utility functions and procedures
audit       -- Audit trails and compliance tracking
api         -- Public API functions
ref         -- Reference data and lookups
```

---

## 🔐 **Authentication & API Key Management**

### API Key Types
| Type | Format | Purpose | Default Duration | Rate Limit |
|------|--------|---------|------------------|------------|
| **Production API** | `ovt_prod_...` | Customer integrations | 30 days | Role-based |
| **Session Token** | Standard hash | Web dashboard access | 15 minutes (HIPAA) | Session-based |
| **Development** | Standard hash | Testing/development | 24 hours | Limited |

### 1. Generate Production API Key

#### Function Signature
```sql
auth.generate_production_api_token(
    p_user_hk BYTEA,                                    -- User hash key
    p_token_type VARCHAR(50) DEFAULT 'API',             -- Token type
    p_scope TEXT[] DEFAULT ARRAY['api:access'],         -- Permissions scope
    p_expires_in INTERVAL DEFAULT '24 hours',           -- Expiration time
    p_description TEXT DEFAULT 'Production API Token'   -- Human description
) RETURNS TABLE (
    token_value TEXT,                    -- The actual API key
    expires_at TIMESTAMP WITH TIME ZONE, -- When it expires
    token_id BYTEA,                      -- For tracking/revocation
    security_level VARCHAR(20),          -- HIGH/MEDIUM/STANDARD
    rate_limit_per_hour INTEGER          -- Requests per hour allowed
)
```

#### Usage Example
```sql
-- Generate API key for The ONE Spa
SELECT * FROM auth.generate_production_api_token(
    (SELECT user_hk FROM auth.user_profile_s 
     WHERE email = 'travis@theonespaoregon.com' 
     AND load_end_date IS NULL),
    'API',
    ARRAY['api:read', 'api:write', 'tracking:full'],
    '30 days',
    'Site tracking for The ONE Spa website'
);

-- Returns:
-- token_value: "ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e"
-- expires_at: "2025-01-28 10:30:00+00"
-- token_id: \x1a2b3c4d5e6f...
-- security_level: "STANDARD"
-- rate_limit_per_hour: 1000
```

#### JavaScript Implementation
```javascript
// Generate API key via backend service
async function generateCustomerAPIKey(customerEmail, description) {
  const response = await fetch('/api/admin/generate-token', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${adminSessionToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      customer_email: customerEmail,
      token_type: 'API',
      scope: ['api:read', 'api:write', 'tracking:full'],
      expires_in: '30 days',
      description: description
    })
  });
  
  const result = await response.json();
  return result.data.token_value; // ovt_prod_...
}
```

### 2. Validate API Token

#### Function Signature
```sql
auth.validate_production_api_token(
    p_token_value TEXT,                 -- API key to validate
    p_required_scope TEXT DEFAULT 'api:read',  -- Required permission
    p_client_ip INET DEFAULT NULL,      -- Client IP for logging
    p_user_agent TEXT DEFAULT NULL,     -- User agent for logging
    p_api_endpoint TEXT DEFAULT NULL    -- Endpoint being accessed
) RETURNS TABLE (
    is_valid BOOLEAN,                   -- True if token is valid
    user_hk BYTEA,                      -- User who owns the token
    tenant_hk BYTEA,                    -- Tenant the user belongs to
    token_hk BYTEA,                     -- Token identifier
    scope TEXT[],                       -- Token permissions
    security_level VARCHAR(20),         -- Security level
    rate_limit_remaining INTEGER,       -- Requests remaining this hour
    rate_limit_reset_time TIMESTAMP WITH TIME ZONE, -- When limit resets
    validation_message TEXT             -- Human-readable result
)
```

#### Usage Example
```sql
-- Validate customer's API key
SELECT * FROM auth.validate_production_api_token(
    'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e',
    'api:write',
    '192.168.1.100'::inet,
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64)...',
    'api.track_site_event'
);
```

---

## 📊 **Site Tracking API**

### Overview
Universal site tracking system that works for any business type - e-commerce, SaaS, content sites, service businesses, etc.

### 1. Track Site Event (Main Function)

#### Function Signature
```sql
api.track_site_event(
    p_ip_address INET,              -- Client IP address
    p_user_agent TEXT,              -- Browser user agent
    p_page_url TEXT,                -- Full page URL
    p_event_type VARCHAR(100),      -- Type of event
    p_event_data JSONB DEFAULT NULL -- Additional event data
) RETURNS JSONB                     -- Success/failure response
```

#### Event Types & Use Cases
| Event Type | Description | Business Types | Common Data Fields |
|------------|-------------|----------------|-------------------|
| `pageview` | Page view tracking | All | `referrer`, `utm_params` |
| `item_interaction` | Product/service interaction | E-commerce, SaaS | `item_id`, `action`, `price` |
| `transaction_step` | Conversion funnel steps | E-commerce, Lead Gen | `step`, `value`, `items` |
| `contact_interaction` | Contact forms, calls | Service, B2B | `form_type`, `lead_score` |
| `content_engagement` | Content consumption | Media, Education | `time_spent`, `completion` |
| `feature_usage` | SaaS feature usage | SaaS, Apps | `feature`, `plan_type` |

#### Implementation Examples

##### Basic JavaScript Integration
```javascript
// Simple tracking for any website
class OneVaultTracker {
  constructor(apiKey, endpoint = 'https://api.onevault.com/v1/track') {
    this.apiKey = apiKey;
    this.endpoint = endpoint;
  }
  
  async track(eventType, eventData = {}) {
    try {
      const response = await fetch(this.endpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          ip_address: await this.getClientIP(),
          user_agent: navigator.userAgent,
          page_url: window.location.href,
          event_type: eventType,
          event_data: {
            timestamp: new Date().toISOString(),
            session_id: this.getSessionId(),
            ...eventData
          }
        })
      });
      
      return await response.json();
    } catch (error) {
      console.error('OneVault tracking error:', error);
      return { success: false, error: error.message };
    }
  }
  
  // Auto-track page views
  trackPageView(additionalData = {}) {
    return this.track('pageview', {
      referrer: document.referrer,
      title: document.title,
      ...additionalData
    });
  }
  
  // Track e-commerce events
  trackPurchase(transactionData) {
    return this.track('transaction_step', {
      step: 'purchase_complete',
      transaction_id: transactionData.transaction_id,
      total_value: transactionData.total,
      items: transactionData.items,
      currency: transactionData.currency || 'USD'
    });
  }
  
  // Track SaaS feature usage
  trackFeatureUsage(featureName, planType, additionalData = {}) {
    return this.track('feature_usage', {
      feature_name: featureName,
      plan_type: planType,
      user_tier: additionalData.user_tier,
      ...additionalData
    });
  }
}

// Usage Examples
const tracker = new OneVaultTracker('ovt_prod_your_api_key_here');

// Auto-track page views
tracker.trackPageView();

// E-commerce tracking
tracker.track('item_interaction', {
  item_id: 'prod_wireless_headphones',
  item_name: 'Wireless Bluetooth Headphones',
  action: 'add_to_cart',
  price: 79.99,
  category: 'Electronics'
});

// SaaS feature tracking
tracker.trackFeatureUsage('advanced_analytics', 'enterprise', {
  user_tier: 'admin',
  feature_complexity: 'high'
});

// Service business tracking
tracker.track('contact_interaction', {
  form_type: 'consultation_request',
  service_type: 'web_design',
  lead_score: 85,
  budget_range: '5000-10000'
});
```

---

## 🌐 **Deployment & Environment Configuration**

### Neon Database Deployment

When you deploy your database to Neon, your API endpoint would look like:

#### Environment Variables
```bash
# Production Environment (.env)
# Database Connection
DATABASE_URL="postgresql://username:password@your-project.neon.tech/one_vault_production?sslmode=require"
DB_HOST="your-project.neon.tech"
DB_NAME="one_vault_production"
DB_USER="username"
DB_PASSWORD="your_secure_password"

# API Configuration
API_BASE_URL="https://api.yourdomain.com"
API_VERSION="v1"

# Security
SESSION_SECRET="your_session_secret_here"
JWT_SECRET="your_jwt_secret_here"

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000  # 1 minute
RATE_LIMIT_MAX_REQUESTS=100  # per window
```

#### Customer Environment Setup
```bash
# Customer Integration (.env)
# For The ONE Spa
ONEVAULT_API_KEY="ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e"
ONEVAULT_ENDPOINT="https://your-project.neon.tech/api/v1/track"
ONEVAULT_ENVIRONMENT="production"

# Optional: Enhanced tracking
ONEVAULT_AUTO_PAGEVIEW=true
ONEVAULT_SESSION_TRACKING=true
ONEVAULT_ERROR_REPORTING=true
```

---

## 🧪 **Testing & Development**

### API Testing Examples

#### cURL Commands
```bash
# Test API key validation
curl -X POST https://your-project.neon.tech/api/v1/track \
  -H "Authorization: Bearer ovt_prod_your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "page_url": "https://test.com/page",
    "event_type": "pageview",
    "event_data": {"test": true}
  }'

# Health check
curl https://your-project.neon.tech/api/v1/status
```

### Database Testing
```sql
-- Test API token generation
SELECT * FROM auth.generate_production_api_token(
    (SELECT user_hk FROM auth.user_profile_s 
     WHERE email = 'travis@theonespaoregon.com' 
     AND load_end_date IS NULL),
    'API',
    ARRAY['api:read', 'api:write', 'tracking:full'],
    '30 days',
    'Test API key for development'
);

-- Test site tracking
SELECT api.track_site_event(
    '192.168.1.100'::inet,
    'Mozilla/5.0 Test Browser',
    'https://theonespaoregon.com/services',
    'pageview',
    '{"test_mode": true}'::jsonb
);
```

---

## 📋 **Quick Start Guide**

### For New Developers

1. **Database Setup**: Ensure you have access to the One Vault database
2. **Generate API Key**: Use the `auth.generate_production_api_token()` function
3. **Test Connection**: Use cURL or Postman to test the API
4. **Integrate**: Add the JavaScript tracker to your website
5. **Monitor**: Check the database for tracked events

### For Customer Integration

1. **Get API Key**: Contact your One Vault administrator
2. **Add Tracking Code**: Include the JavaScript tracker on your website
3. **Configure Events**: Set up tracking for your specific business needs
4. **Test**: Verify events are being tracked correctly
5. **Monitor**: Use the dashboard to view analytics

---

## 🔄 **API Function Summary**

### Currently Available Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `auth.generate_production_api_token()` | Generate customer API keys | Token details |
| `auth.validate_production_api_token()` | Validate API keys | Validation status |
| `api.track_site_event()` | Track website events | Success/failure |
| `api.tenant_register_elt()` | Register new tenants | Registration status |
| `auth.auth_login()` | User authentication | Login status |

### Function Comparison: Enhanced vs Production

**RECOMMENDATION: Use `auth.generate_production_api_token()`**

The production function is better because:
- ✅ **Professional token format** - `ovt_prod_` prefix for recognition
- ✅ **Enhanced security** - Built-in security levels and rate limiting
- ✅ **Better tracking** - Returns token_id for management
- ✅ **Production-ready** - Designed for customer-facing use
- ✅ **Rate limiting** - Automatic per-hour limits based on user level

---

*This guide provides everything needed for developers and customers to integrate with the One Vault platform successfully.* 