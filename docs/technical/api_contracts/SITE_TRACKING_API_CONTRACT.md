# Site Tracking API Contract
## Enhanced Multi-Tenant Site Tracking System with Customer Configuration

### Document Information
- **API Version**: 2.0.0
- **Last Updated**: 2024-12-28
- **Status**: Production Ready with Enhanced Features
- **Authentication**: Bearer Token + Customer ID Headers
- **Data Compliance**: HIPAA, GDPR, CCPA compliant with Data Vault 2.0
- **Base Implementation**: FastAPI with PostgreSQL Data Vault 2.0 backend

---

## 🎯 **API Overview**

The Enhanced Site Tracking API provides enterprise-grade, customer-configurable site tracking capabilities with:

- ✅ **Customer Configuration Support** - YAML-based customer-specific settings
- ✅ **Multi-tenant isolation** - Complete data separation with tenant_hk enforcement
- ✅ **Real-time processing** - Immediate data ingestion with Data Vault 2.0 structures
- ✅ **Enhanced Security** - Bearer token authentication with customer validation
- ✅ **Customer-Specific Rate Limiting** - Configurable API limits per customer
- ✅ **Business Intelligence Ready** - Data Vault 2.0 with historical tracking
- ✅ **Privacy Compliance** - HIPAA/GDPR with configurable data residency
- ✅ **Universal Business Support** - Industry-agnostic with customer customization

---

## 📡 **Base URL & Endpoints**

### Base URL
```
https://api.onevault.com/v2
```

### Available Endpoints
| Endpoint | Method | Purpose | Authentication | Rate Limit |
|----------|--------|---------|---------------|------------|
| `/api/v1/track` | POST | Enhanced site event tracking | Bearer + Customer ID | Customer configurable |
| `/api/v1/track/bulk` | POST | Bulk event tracking | Bearer + Customer ID | Customer configurable |
| `/health/{customer_id}` | GET | Customer-specific health check | Customer ID only | 10 req/min |
| `/api/v1/customer/{customer_id}/tracking-config` | GET | Customer tracking configuration | Bearer + Customer ID | 100 req/min |

---

## 🔐 **Authentication & Security**

### Enhanced Authentication Model
The API requires two authentication components:

#### 1. Customer Identification Header
```http
X-Customer-ID: {customer_id}
```

#### 2. Bearer Token Authentication
```http
Authorization: Bearer {api_token}
```

### Customer Configuration Loading
The API automatically loads customer-specific configuration from:
- `example-customers/configurations/{customer_id}/config.yaml`
- `example-customers/configurations/{customer_id}/features.yaml`

### Security Features
- **Customer-specific token validation**
- **Configurable rate limiting per customer**
- **Enhanced security scoring and threat detection**
- **Automatic audit logging for compliance**
- **Data residency enforcement based on customer settings**

### Rate Limiting (Customer Configurable)
Default rate limits can be overridden per customer:
```yaml
# Customer config.yaml
technical:
  api_rate_limit: 5000  # requests per hour
```

Response headers:
```http
X-RateLimit-Limit: 5000
X-RateLimit-Remaining: 4850
X-RateLimit-Reset: 2024-12-28T11:00:00Z
X-Customer-ID: one_spa
```

---

## 📝 **Primary Endpoint: Enhanced Site Event Tracking**

### Endpoint Details
```http
POST /api/v1/track
Content-Type: application/json
X-Customer-ID: {customer_id}
Authorization: Bearer {api_token}
```

### Enhanced Request Model
```python
class TrackingEventRequest:
    event_type: str                    # Required
    page_url: Optional[str] = None     # URL where event occurred
    event_data: Dict[str, Any] = {}    # Additional event data
    location_id: Optional[str] = None  # Customer location identifier
    user_id: Optional[str] = None      # User identifier
    session_id: Optional[str] = None   # Session identifier
```

### Database Function Signature
```sql
api.track_site_event_enhanced(
    p_ip_address INET,
    p_user_agent TEXT,
    p_page_url TEXT,
    p_event_type VARCHAR(50) DEFAULT 'page_view',
    p_event_data JSONB DEFAULT '{}'::jsonb,
    p_customer_id VARCHAR(100) DEFAULT NULL,
    p_rate_limit INTEGER DEFAULT 1000
) RETURNS JSONB
```

### Event Types & Business Applications

#### E-commerce & Retail
| Event Type | Description | Use Cases |
|------------|-------------|-----------|
| `page_view` | Page/product view | Analytics, funnel analysis |
| `item_interaction` | Product interaction | Product performance, recommendations |
| `transaction_step` | Checkout progression | Conversion optimization |
| `search` | Product/site search | Search optimization |
| `cart_action` | Cart modifications | Cart abandonment analysis |

#### SaaS & Software
| Event Type | Description | Use Cases |
|------------|-------------|-----------|
| `feature_usage` | Feature interaction | Product analytics, user onboarding |
| `onboarding_step` | User onboarding progress | Onboarding optimization |
| `subscription_event` | Plan changes, billing | Revenue analytics |
| `integration_usage` | Third-party integrations | Integration performance |

#### Healthcare & Wellness (HIPAA Compliant)
| Event Type | Description | Use Cases |
|------------|-------------|-----------|
| `appointment_interaction` | Booking, scheduling | Appointment optimization |
| `member_activity` | Member portal usage | Engagement tracking |
| `treatment_engagement` | Treatment plan interaction | Treatment effectiveness |
| `wellness_tracking` | Health metrics input | Wellness program analytics |

#### Content & Media
| Event Type | Description | Use Cases |
|------------|-------------|-----------|
| `content_engagement` | Article/video consumption | Content performance |
| `social_interaction` | Shares, comments, likes | Social engagement |
| `subscription_action` | Newsletter, premium content | Subscription optimization |

### Enhanced Request Examples

#### Basic Page View with Customer Context
```json
{
  "event_type": "page_view",
  "page_url": "https://onespa.com/services/massage-therapy",
  "event_data": {
    "session_id": "sess_spa_customer_123",
    "location_id": "spa_downtown_location",
    "page_category": "services",
    "service_type": "massage_therapy"
  }
}
```

#### E-commerce Product Interaction
```json
{
  "event_type": "item_interaction",
  "page_url": "https://mystore.com/products/organic-skincare-set",
  "event_data": {
    "session_id": "sess_ecom_456",
    "user_id": "customer_789",
    "action": "add_to_cart",
    "product_id": "skincare_set_organic_001",
    "product_name": "Organic Skincare Essentials Set",
    "product_category": "beauty_skincare",
    "product_price": 129.99,
    "product_currency": "USD",
    "quantity": 1,
    "variant": "sensitive_skin",
    "utm_source": "instagram",
    "utm_campaign": "holiday_beauty_2024"
  }
}
```

#### SaaS Feature Usage with Business Context
```json
{
  "event_type": "feature_usage",
  "page_url": "https://myapp.com/dashboard/analytics/reports",
  "event_data": {
    "session_id": "sess_saas_enterprise_001",
    "user_id": "user_premium_456",
    "feature_name": "Advanced Analytics Dashboard",
    "feature_category": "analytics",
    "action": "generate_custom_report",
    "report_type": "conversion_funnel",
    "date_range": "last_30_days",
    "data_sources": ["website", "app", "email"],
    "export_format": "pdf",
    "plan_tier": "enterprise",
    "company_size": "500_1000_employees"
  }
}
```

#### Healthcare Appointment Booking (HIPAA Compliant)
```json
{
  "event_type": "appointment_interaction",
  "page_url": "https://healthcenter.com/book-appointment",
  "location_id": "clinic_north_branch",
  "event_data": {
    "session_id": "sess_patient_portal_789",
    "user_id": "patient_hashed_abc123",  // Hashed patient ID for privacy
    "action": "appointment_booked",
    "service_type": "annual_physical",
    "provider_type": "family_medicine",
    "appointment_duration": 60,
    "preferred_time": "morning",
    "insurance_verified": true,
    "new_patient": false,
    "booking_source": "patient_portal"
  }
}
```

#### Content Engagement with Tracking Context
```json
{
  "event_type": "content_engagement",
  "page_url": "https://myblog.com/ultimate-guide-digital-marketing-2024",
  "event_data": {
    "session_id": "sess_content_reader_321",
    "action": "article_completion",
    "article_id": "marketing_guide_2024_001",
    "article_title": "Ultimate Guide to Digital Marketing in 2024",
    "article_category": "marketing",
    "article_author": "Sarah Johnson",
    "reading_time_seconds": 480,
    "scroll_percentage": 95,
    "social_shares": 1,
    "newsletter_signup": true,
    "lead_magnet_downloaded": "marketing_checklist_2024",
    "utm_source": "linkedin",
    "referrer_domain": "linkedin.com"
  }
}
```

#### Multi-Location Business Event
```json
{
  "event_type": "transaction_step",
  "page_url": "https://retailchain.com/checkout/payment",
  "location_id": "store_sf_union_square",
  "event_data": {
    "session_id": "sess_omnichannel_456",
    "user_id": "loyalty_member_789",
    "transaction_id": "txn_holiday_2024_001",
    "funnel_step": "payment_processing",
    "step_number": 4,
    "total_steps": 6,
    "cart_value": 234.50,
    "cart_currency": "USD",
    "payment_method": "credit_card",
    "shipping_method": "store_pickup",
    "loyalty_points_used": 500,
    "promo_codes": ["HOLIDAY20", "NEWCUSTOMER"],
    "store_associate_id": "emp_001",
    "channel": "online_for_pickup"
  }
}
```

### Enhanced Response Format

#### Successful Response
```json
{
  "success": true,
  "message": "Event tracked successfully with customer configuration",
  "event_id": "7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f",
  "customer_id": "one_spa",
  "tenant_hk": "a1b2c3d4e5f6789012345678901234567890abcdef",
  "timestamp": "2024-12-28T10:30:00Z",
  "tracking_result": {
    "allowed": true,
    "security_score": 95.5,
    "suspicious": false,
    "rate_limit_remaining": 4850
  },
  "audit_logged": true
}
```

#### Rate Limited Response
```json
{
  "success": false,
  "message": "Request rate limited or blocked",
  "customer_id": "one_spa",
  "timestamp": "2024-12-28T10:30:00Z",
  "tracking_result": {
    "allowed": false,
    "security_score": 45.2,
    "suspicious": true,
    "rate_limit_remaining": 0,
    "reason": "Rate limit exceeded for IP"
  }
}
```

#### Error Response
```json
{
  "success": false,
  "error": "Missing or invalid Authorization header",
  "customer_id": "one_spa",
  "timestamp": "2024-12-28T10:30:00Z",
  "audit_logged": true
}
```

---

## 📊 **Bulk Event Tracking**

### Endpoint Details
```http
POST /api/v1/track/bulk
Content-Type: application/json
X-Customer-ID: {customer_id}
Authorization: Bearer {api_token}
```

### Bulk Request Model
```python
class BulkTrackingRequest:
    events: List[TrackingEventRequest]  # Multiple events
    batch_id: Optional[str] = None      # Batch identifier
```

### Bulk Request Example
```json
{
  "batch_id": "batch_holiday_campaign_001",
  "events": [
    {
      "event_type": "page_view",
      "page_url": "https://store.com/homepage",
      "event_data": {
        "session_id": "sess_001",
        "utm_campaign": "holiday_2024"
      }
    },
    {
      "event_type": "item_interaction",
      "page_url": "https://store.com/products/gift-set",
      "event_data": {
        "session_id": "sess_001",
        "action": "product_view",
        "product_id": "gift_set_001"
      }
    }
  ]
}
```

### Bulk Response Format
```json
{
  "success": true,
  "message": "Bulk events processed",
  "customer_id": "retail_chain",
  "batch_id": "batch_holiday_campaign_001",
  "events_processed": 150,
  "events_failed": 2,
  "timestamp": "2024-12-28T10:30:00Z",
  "processing_summary": {
    "total_events": 152,
    "successful_events": 150,
    "failed_events": 2,
    "average_processing_time_ms": 45
  }
}
```

---

## 🏥 **Customer Health Check**

### Endpoint Details
```http
GET /health/{customer_id}
```

### Response Example
```json
{
  "status": "healthy",
  "customer_id": "one_spa",
  "customer_name": "OneSpa Wellness Centers",
  "service": "Enhanced Site Tracking API",
  "tracking_features": [
    "business_intelligence",
    "member_tracking",
    "appointment_tracking"
  ],
  "rate_limit": 5000,
  "locations": 3,
  "compliance": {
    "hipaa_required": true,
    "data_residency": "US"
  },
  "timestamp": "2024-12-28T10:30:00Z"
}
```

---

## ⚙️ **Customer Configuration API**

### Endpoint Details
```http
GET /api/v1/customer/{customer_id}/tracking-config
X-Customer-ID: {customer_id}
Authorization: Bearer {api_token}
```

### Configuration Response
```json
{
  "success": true,
  "config": {
    "customer_id": "one_spa",
    "tenant_hk": "a1b2c3d4e5f6789012345678901234567890abcdef",
    "tracking_settings": {
      "rate_limit": 5000,
      "storage_quota_gb": 500,
      "backup_retention_days": 2555,
      "hipaa_compliance": true
    },
    "enabled_features": {
      "site_tracking": true,
      "member_tracking": true,
      "appointment_tracking": true,
      "treatment_tracking": true,
      "staff_tracking": true,
      "inventory_tracking": true,
      "pos_tracking": true,
      "marketing_tracking": true
    },
    "api_endpoints": {
      "track_event": "/api/v1/track",
      "bulk_track": "/api/v1/track/bulk",
      "get_config": "/api/v1/customer/one_spa/tracking-config"
    },
    "timestamp": "2024-12-28T10:30:00Z"
  },
  "audit_logged": true
}
```

---

## 🗄️ **Data Vault 2.0 Integration**

### Database Layer Architecture

#### Raw Layer
- **Table**: `raw.site_tracking_events_r`
- **Purpose**: Immediate event ingestion with complete tenant isolation
- **Key Fields**: `tenant_hk`, `raw_payload`, `processing_status`

#### Business Layer Hubs
- **Site Event Hub**: `business.site_event_h`
- **Site Session Hub**: `business.site_session_h` 
- **Site Visitor Hub**: `business.site_visitor_h`
- **Site Page Hub**: `business.site_page_h`
- **Business Item Hub**: `business.business_item_h`

#### Business Layer Satellites
- **Event Details**: `business.site_event_details_s`
- **Session Details**: `business.site_session_details_s`
- **Visitor Details**: `business.site_visitor_details_s`
- **Page Details**: `business.site_page_details_s`

#### Link Tables
- **Session-Visitor**: `business.session_visitor_l`
- **Event-Session**: `business.event_session_l`
- **Event-Page**: `business.event_page_l`
- **Event-Business Item**: `business.event_business_item_l`

### Enhanced Data Processing
1. **Raw Ingestion**: Events land in `raw.site_tracking_events_r`
2. **Staging Validation**: Data validation and enrichment
3. **Business Processing**: Data Vault 2.0 hub/satellite/link creation
4. **Real-time Analytics**: Point-in-time tables for performance

---

## 🔒 **Privacy & Compliance**

### HIPAA Compliance Features
- **PHI Protection**: Automatic PHI detection and encryption
- **Audit Logging**: Complete audit trail for all data access
- **Data Minimization**: Only necessary data collected
- **Right to Deletion**: Support for data removal requests

### GDPR Compliance Features
- **Consent Management**: Configurable consent tracking
- **Data Portability**: Export capabilities
- **Right to be Forgotten**: Complete data removal
- **Privacy by Design**: Default privacy protection

### Configurable Privacy Settings
```yaml
# Customer privacy configuration
privacy:
  ip_address_hashing: true
  user_agent_truncation: true
  pii_detection: enabled
  data_retention_days: 2555  # 7 years
  geographic_restrictions: ["EU", "US"]
  consent_required: true
```

---

## 📈 **Performance & Scalability**

### Performance Features
- **Async Processing**: Non-blocking event ingestion
- **Batch Processing**: Optimized for high-volume events
- **Indexing Strategy**: Optimized database indexes for fast queries
- **Caching**: Customer configuration caching
- **Connection Pooling**: Efficient database connections

### Scalability Metrics
- **Event Volume**: Handles 10,000+ events/minute per customer
- **Response Time**: < 100ms average response time
- **Data Storage**: Unlimited with configurable retention
- **Customer Capacity**: Supports 1000+ concurrent customers

---

## 🚨 **Error Handling & Monitoring**

### Standard Error Codes
| Code | Type | Description | Action |
|------|------|-------------|--------|
| 400 | `INVALID_REQUEST` | Malformed request data | Check request format |
| 401 | `UNAUTHORIZED` | Invalid/missing token | Verify authentication |
| 403 | `FORBIDDEN` | Customer access denied | Check customer configuration |
| 404 | `CUSTOMER_NOT_FOUND` | Customer configuration missing | Verify customer setup |
| 429 | `RATE_LIMITED` | Rate limit exceeded | Reduce request frequency |
| 500 | `INTERNAL_ERROR` | Server processing error | Contact support |

### Enhanced Monitoring
- **Real-time Metrics**: Event processing rates, error rates
- **Customer Analytics**: Per-customer usage analytics
- **Performance Monitoring**: Response times, database performance
- **Security Monitoring**: Threat detection, unusual patterns
- **Compliance Monitoring**: Privacy regulation adherence

### Audit Logging
All API interactions are logged with:
- Customer identification
- Event details
- Processing outcomes
- Security assessments
- Compliance markers

---

## 📚 **Integration Examples**

### JavaScript/TypeScript Client
```typescript
interface TrackingEvent {
  event_type: string;
  page_url?: string;
  event_data?: Record<string, any>;
  location_id?: string;
  user_id?: string;
  session_id?: string;
}

class OneVaultTracker {
  private apiToken: string;
  private customerId: string;
  private baseUrl: string;

  constructor(customerId: string, apiToken: string) {
    this.customerId = customerId;
    this.apiToken = apiToken;
    this.baseUrl = 'https://api.onevault.com/v2';
  }

  async trackEvent(event: TrackingEvent): Promise<any> {
    const response = await fetch(`${this.baseUrl}/api/v1/track`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Customer-ID': this.customerId,
        'Authorization': `Bearer ${this.apiToken}`
      },
      body: JSON.stringify(event)
    });

    return response.json();
  }

  async trackPageView(pageUrl: string, additionalData?: any): Promise<any> {
    return this.trackEvent({
      event_type: 'page_view',
      page_url: pageUrl,
      event_data: {
        timestamp: new Date().toISOString(),
        ...additionalData
      }
    });
  }
}

// Usage example
const tracker = new OneVaultTracker('one_spa', 'ovt_prod_...');

// Track page view
await tracker.trackPageView('https://onespa.com/services');

// Track custom event
await tracker.trackEvent({
  event_type: 'appointment_interaction',
  page_url: 'https://onespa.com/book',
  location_id: 'spa_downtown',
  event_data: {
    action: 'appointment_booked',
    service_type: 'massage_therapy',
    duration: 60
  }
});
```

### Python Client Example
```python
import requests
from typing import Dict, Any, Optional

class OneVaultTracker:
    def __init__(self, customer_id: str, api_token: str):
        self.customer_id = customer_id
        self.api_token = api_token
        self.base_url = 'https://api.onevault.com/v2'
        self.headers = {
            'Content-Type': 'application/json',
            'X-Customer-ID': customer_id,
            'Authorization': f'Bearer {api_token}'
        }
    
    def track_event(self, event_data: Dict[str, Any]) -> Dict[str, Any]:
        """Track a single event"""
        response = requests.post(
            f'{self.base_url}/api/v1/track',
            json=event_data,
            headers=self.headers
        )
        return response.json()
    
    def track_bulk_events(self, events: list, batch_id: Optional[str] = None) -> Dict[str, Any]:
        """Track multiple events in a single request"""
        bulk_data = {
            'events': events,
            'batch_id': batch_id
        }
        response = requests.post(
            f'{self.base_url}/api/v1/track/bulk',
            json=bulk_data,
            headers=self.headers
        )
        return response.json()

# Usage example
tracker = OneVaultTracker('retail_chain', 'ovt_prod_...')

# Track e-commerce event
result = tracker.track_event({
    'event_type': 'item_interaction',
    'page_url': 'https://store.com/products/widget',
    'event_data': {
        'action': 'add_to_cart',
        'product_id': 'widget_001',
        'price': 29.99
    }
})
```

---

## 🎯 **Best Practices**

### Event Naming Conventions
- Use descriptive, consistent event types
- Include business context in event_data
- Maintain consistent session_id throughout user journey
- Use location_id for multi-location businesses

### Data Quality Guidelines
- Include all relevant business context
- Use consistent data types and formats
- Implement client-side validation before sending
- Handle network failures with retry logic

### Privacy Best Practices
- Hash or encrypt PII before transmission
- Implement user consent mechanisms
- Provide data deletion capabilities
- Regular privacy impact assessments

### Performance Optimization
- Use bulk tracking for high-volume events
- Implement client-side queuing for offline scenarios
- Monitor API response times and error rates
- Cache customer configurations appropriately

---

## 📞 **Support & Resources**

### Documentation
- **Developer Guide**: Complete implementation guide
- **Schema Reference**: Detailed data models
- **Configuration Examples**: Customer setup templates

### Support Channels
- **Email**: api-support@onevault.com
- **Documentation**: https://docs.onevault.com
- **Status Page**: https://status.onevault.com

### SLA Commitments
- **Uptime**: 99.9% availability
- **Response Time**: < 100ms average
- **Data Retention**: Customer configurable (up to 7 years)
- **Support Response**: < 4 hours for critical issues

---

## 📋 **Changelog**

### Version 2.0.0 (2024-12-28)
- ✅ Added customer configuration support
- ✅ Enhanced authentication with Bearer tokens
- ✅ Improved Data Vault 2.0 integration
- ✅ Added bulk event tracking
- ✅ Customer-specific rate limiting
- ✅ Enhanced privacy and compliance features
- ✅ Improved error handling and monitoring
- ✅ Added multi-location business support

### Version 1.0.0 (2024-12-27)
- ✅ Initial API implementation
- ✅ Basic site tracking functionality
- ✅ Multi-tenant support
- ✅ Security and rate limiting

---

This API contract reflects the current enhanced implementation with customer configuration support, Data Vault 2.0 integration, and comprehensive business intelligence capabilities for any industry vertical. 