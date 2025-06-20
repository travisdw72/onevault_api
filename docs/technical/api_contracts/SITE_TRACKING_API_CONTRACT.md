# Site Tracking API Contract
## Universal Multi-Tenant Site Tracking System

### Document Information
- **API Version**: 2.0.0
- **Last Updated**: 2024-12-27
- **Status**: Production Ready
- **Authentication**: IP-based rate limiting + Security scoring
- **Data Compliance**: HIPAA, GDPR, CCPA compliant

---

## 🎯 **API Overview**

The Site Tracking API provides enterprise-grade, universal site tracking capabilities with:
- ✅ **Multi-tenant isolation** - Complete data separation between clients
- ✅ **Real-time processing** - Immediate data ingestion and processing
- ✅ **Security monitoring** - Automated threat detection and rate limiting
- ✅ **Privacy compliance** - HIPAA/GDPR compliant data handling
- ✅ **Universal business support** - Works for any industry (e-commerce, SaaS, content, services)

---

## 📡 **Base URL & Endpoints**

### Base URL
```
https://api.onevault.com/v2/tracking
```

### Available Endpoints
| Endpoint | Method | Purpose | Rate Limit |
|----------|--------|---------|------------|
| `/track` | POST | Track site events | 100 req/min |
| `/status` | GET | API health check | 10 req/min |

---

## 🔐 **Authentication & Security**

### Security Model
- **No API keys required** for basic tracking
- **IP-based rate limiting** (100 requests per minute per IP)
- **Automatic security scoring** for fraud detection
- **Tenant isolation** enforced at database level

### Rate Limiting Headers
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 85
X-RateLimit-Reset: 2024-12-27T10:30:00Z
```

### Security Scoring
The API automatically calculates a security score (0.0-1.0) based on:
- IP address patterns
- User agent analysis
- Request frequency
- Known bot patterns

**Score > 0.7** = Flagged as suspicious (still processed but monitored)

---

## 📝 **Primary Endpoint: Track Site Event**

### Endpoint Details
```http
POST /api/track
Content-Type: application/json
```

### Function Signature
```sql
api.track_site_event(
    p_ip_address INET,
    p_user_agent TEXT,
    p_page_url TEXT,
    p_event_type VARCHAR(50) DEFAULT 'page_view',
    p_event_data JSONB DEFAULT '{}'::jsonb
) RETURNS JSONB
```

### Request Parameters

#### Required Parameters
| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `ip_address` | string | Client IP address | `"192.168.1.100"` |
| `user_agent` | string | Browser user agent | `"Mozilla/5.0 (Windows NT 10.0; Win64; x64)..."` |
| `page_url` | string | Full page URL | `"https://mystore.com/products/widget-pro"` |

#### Optional Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `event_type` | string | `"page_view"` | Type of event being tracked |
| `event_data` | object | `{}` | Additional event-specific data |

### Event Types
| Event Type | Description | Common Use Cases |
|------------|-------------|------------------|
| `page_view` | Page view tracking | Website analytics |
| `item_interaction` | Product/service interaction | E-commerce, SaaS features |
| `transaction_step` | Checkout/signup steps | Conversion funnels |
| `contact_interaction` | Contact form, chat, call | Lead generation |
| `content_engagement` | Article read, video play | Content marketing |
| `search` | Site search queries | Search analytics |
| `download` | File downloads | Resource tracking |

### Request Examples

#### Basic Page View
```json
{
  "ip_address": "203.0.113.195",
  "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
  "page_url": "https://mystore.com/homepage",
  "event_type": "page_view"
}
```

#### E-commerce Product View
```json
{
  "ip_address": "203.0.113.195",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15",
  "page_url": "https://mystore.com/products/wireless-headphones",
  "event_type": "item_interaction",
  "event_data": {
    "session_id": "sess_1234567890",
    "user_id": "user_abc123",
    "item_id": "prod_wireless_headphones_v2",
    "item_name": "Wireless Bluetooth Headphones",
    "item_category": "Electronics",
    "item_price": 79.99,
    "item_currency": "USD",
    "action": "view_product",
    "referrer": "https://google.com/search?q=wireless+headphones",
    "utm_source": "google",
    "utm_medium": "organic",
    "utm_campaign": "holiday_sale_2024"
  }
}
```

#### SaaS Feature Interaction
```json
{
  "ip_address": "198.51.100.42",
  "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
  "page_url": "https://myapp.com/dashboard/analytics",
  "event_type": "item_interaction",
  "event_data": {
    "session_id": "sess_enterprise_user_456",
    "user_id": "user_premium_789",
    "feature_name": "Advanced Analytics Dashboard",
    "feature_category": "Analytics",
    "action": "generate_report",
    "plan_type": "Enterprise",
    "report_type": "monthly_summary",
    "data_range": "2024-11-01_to_2024-11-30"
  }
}
```

#### Content Engagement
```json
{
  "ip_address": "192.0.2.146",
  "user_agent": "Mozilla/5.0 (Android 11; Mobile; rv:89.0) Gecko/89.0 Firefox/89.0",
  "page_url": "https://myblog.com/how-to-optimize-conversion-rates",
  "event_type": "content_engagement",
  "event_data": {
    "session_id": "sess_reader_678",
    "article_title": "How to Optimize Conversion Rates in 2024",
    "article_category": "Marketing",
    "author": "Jane Smith",
    "reading_progress": 65,
    "time_on_page": 180,
    "scroll_depth": 75,
    "social_share": false,
    "newsletter_signup": false
  }
}
```

#### Transaction Funnel Step
```json
{
  "ip_address": "203.0.113.195",
  "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  "page_url": "https://mystore.com/checkout/payment",
  "event_type": "transaction_step",
  "event_data": {
    "session_id": "sess_1234567890",
    "user_id": "user_abc123",
    "transaction_id": "txn_winter_2024_001",
    "funnel_step": "payment_method_selection",
    "step_number": 3,
    "total_steps": 5,
    "cart_value": 156.47,
    "currency": "USD",
    "payment_method": "credit_card",
    "shipping_method": "standard",
    "coupon_code": "WINTER20",
    "items_count": 3
  }
}
```

### Response Format

#### Success Response
```json
{
  "success": true,
  "message": "Event tracked successfully",
  "event_id": "7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d",
  "tracking_result": {
    "allowed": true,
    "security_score": 0.1,
    "suspicious": false,
    "rate_limit_remaining": 95
  },
  "audit_logged": true
}
```

#### Rate Limited Response
```json
{
  "success": false,
  "message": "Request rate limited or blocked",
  "tracking_result": {
    "allowed": false,
    "security_score": 0.3,
    "suspicious": false,
    "rate_limit_remaining": 0,
    "reset_time": "2024-12-27T10:30:00Z"
  }
}
```

#### Error Response
```json
{
  "success": false,
  "error": "Failed to track event",
  "error_details": "Invalid IP address format",
  "audit_logged": true
}
```

---

## 📊 **Status Endpoint**

### Endpoint Details
```http
GET /api/status
Content-Type: application/json
```

### Response
```json
{
  "service": "Site Tracking API",
  "status": "operational",
  "version": "2.0.0",
  "features": [
    "rate_limiting",
    "security_scoring",
    "automatic_audit_logging",
    "data_vault_integration",
    "tenant_isolation"
  ],
  "audit_system": "util.log_audit_event",
  "timestamp": "2024-12-27T09:15:30.123Z"
}
```

---

## 🌐 **Universal Business Support**

### Industry Adaptations

#### E-commerce
```json
"event_data": {
  "product_id": "SKU_12345",
  "product_name": "Wireless Bluetooth Headphones",
  "category": "Electronics > Audio",
  "brand": "TechSound",
  "price": 79.99,
  "currency": "USD",
  "inventory_status": "in_stock",
  "variant": "Black, Over-Ear",
  "action": "add_to_cart"
}
```

#### SaaS Platform
```json
"event_data": {
  "feature_id": "advanced_analytics",
  "feature_name": "Advanced Analytics Dashboard",
  "module": "Reporting",
  "user_plan": "Enterprise",
  "usage_limit": 1000,
  "usage_current": 245,
  "action": "generate_report"
}
```

#### Content/Media
```json
"event_data": {
  "content_id": "article_2024_conversion_tips",
  "content_title": "10 Proven Conversion Rate Optimization Tips",
  "content_type": "blog_article",
  "author": "Jane Marketing",
  "category": "Digital Marketing",
  "word_count": 2500,
  "reading_time": 8,
  "action": "article_complete"
}
```

#### Professional Services
```json
"event_data": {
  "service_id": "legal_consultation",
  "service_name": "Business Legal Consultation",
  "practice_area": "Corporate Law",
  "consultation_type": "initial_meeting",
  "duration_minutes": 60,
  "attorney": "John Legal",
  "action": "booking_confirmed"
}
```

#### Healthcare/Wellness
```json
"event_data": {
  "service_id": "annual_checkup",
  "service_name": "Annual Health Checkup",
  "provider": "Dr. Sarah Health",
  "department": "Primary Care",
  "appointment_type": "routine",
  "insurance_accepted": true,
  "action": "appointment_scheduled"
}
```

---

## 📱 **Client Integration Examples**

### JavaScript (Web)
```javascript
// Basic tracking function
async function trackEvent(eventType, eventData = {}) {
  try {
    const response = await fetch('/api/track', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ip_address: await getUserIP(), // Get from your IP detection service
        user_agent: navigator.userAgent,
        page_url: window.location.href,
        event_type: eventType,
        event_data: eventData
      })
    });
    
    const result = await response.json();
    
    if (!result.success) {
      console.warn('Tracking failed:', result.message);
    }
    
    return result;
  } catch (error) {
    console.error('Tracking error:', error);
  }
}

// Usage examples
trackEvent('page_view');

trackEvent('item_interaction', {
  item_id: 'prod_123',
  item_name: 'Wireless Headphones',
  action: 'view_product',
  price: 79.99
});

trackEvent('transaction_step', {
  step: 'payment_confirmation',
  transaction_id: 'txn_456',
  total_value: 156.47
});
```

### Python (Server-side)
```python
import requests
import json
from datetime import datetime

class SiteTracker:
    def __init__(self, api_base_url='https://api.onevault.com/v2/tracking'):
        self.api_base_url = api_base_url
    
    def track_event(self, ip_address, user_agent, page_url, event_type='page_view', event_data=None):
        """Track a site event"""
        if event_data is None:
            event_data = {}
        
        payload = {
            'ip_address': ip_address,
            'user_agent': user_agent,
            'page_url': page_url,
            'event_type': event_type,
            'event_data': event_data
        }
        
        try:
            response = requests.post(
                f"{self.api_base_url}/track",
                json=payload,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            
            result = response.json()
            
            if not result.get('success'):
                print(f"Tracking failed: {result.get('message')}")
            
            return result
            
        except requests.RequestException as e:
            print(f"Tracking error: {e}")
            return {'success': False, 'error': str(e)}

# Usage
tracker = SiteTracker()

# Track page view
tracker.track_event(
    ip_address='203.0.113.195',
    user_agent='Mozilla/5.0...',
    page_url='https://myapp.com/dashboard',
    event_type='page_view'
)

# Track feature usage
tracker.track_event(
    ip_address='203.0.113.195',
    user_agent='Mozilla/5.0...',
    page_url='https://myapp.com/reports',
    event_type='item_interaction',
    event_data={
        'feature_name': 'Analytics Report',
        'action': 'generate_report',
        'user_plan': 'Enterprise'
    }
)
```

### PHP (Server-side)
```php
<?php
class SiteTracker {
    private $apiBaseUrl;
    
    public function __construct($apiBaseUrl = 'https://api.onevault.com/v2/tracking') {
        $this->apiBaseUrl = $apiBaseUrl;
    }
    
    public function trackEvent($ipAddress, $userAgent, $pageUrl, $eventType = 'page_view', $eventData = []) {
        $payload = [
            'ip_address' => $ipAddress,
            'user_agent' => $userAgent,
            'page_url' => $pageUrl,
            'event_type' => $eventType,
            'event_data' => $eventData
        ];
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $this->apiBaseUrl . '/track');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json'
        ]);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200) {
            return json_decode($response, true);
        } else {
            return ['success' => false, 'error' => 'HTTP ' . $httpCode];
        }
    }
}

// Usage
$tracker = new SiteTracker();

// Track e-commerce product view
$result = $tracker->trackEvent(
    $_SERVER['REMOTE_ADDR'],
    $_SERVER['HTTP_USER_AGENT'],
    'https://mystore.com/products/widget-pro',
    'item_interaction',
    [
        'product_id' => 'WIDGET_PRO_001',
        'product_name' => 'Professional Widget Pro',
        'category' => 'Widgets',
        'price' => 299.99,
        'action' => 'view_product'
    ]
);

if ($result['success']) {
    echo "Event tracked successfully!";
} else {
    echo "Tracking failed: " . $result['message'];
}
?>
```

---

## 🔒 **Privacy & Compliance**

### Data Processing
- **Automatic anonymization** of sensitive data
- **GDPR right to be forgotten** support
- **CCPA data portability** compliance
- **HIPAA-compliant** data handling

### Data Retention
- **Raw events**: 90 days
- **Processed analytics**: 7 years (configurable)
- **Audit logs**: 10 years (compliance requirement)

### Privacy Controls
- **IP address hashing** for privacy protection
- **PII detection** and automatic masking
- **Consent management** integration ready
- **Do Not Track** header respect

---

## 🚨 **Error Handling & Troubleshooting**

### Common Error Codes
| Error | Description | Solution |
|-------|-------------|----------|
| `400` | Invalid request format | Check JSON syntax and required fields |
| `429` | Rate limit exceeded | Wait for rate limit reset or implement backoff |
| `500` | Internal server error | Contact support with event_id |

### Best Practices
1. **Implement retry logic** with exponential backoff
2. **Handle rate limiting** gracefully
3. **Validate data locally** before sending
4. **Monitor response status** and adjust accordingly
5. **Use batch processing** for high-volume scenarios

### Debug Mode
Add `debug: true` to event_data for additional logging (development only):
```json
"event_data": {
  "debug": true,
  "product_id": "test_product"
}
```

---

## 📈 **Performance & Scalability**

### Rate Limits
- **Standard**: 100 requests/minute per IP
- **Burst**: Up to 150 requests in 10 seconds
- **Enterprise**: Custom limits available

### Response Times
- **P50**: < 50ms
- **P95**: < 200ms
- **P99**: < 500ms

### Availability
- **SLA**: 99.9% uptime
- **Geographic redundancy**: Multi-region deployment
- **Auto-scaling**: Handles traffic spikes automatically

---

## 🎯 **Next Steps for Developers**

### 1. **Basic Integration** (5 minutes)
- Copy JavaScript tracking code
- Add to your site's header
- Test with a page view event

### 2. **Enhanced Tracking** (30 minutes)
- Implement event-specific tracking
- Add business-specific event_data
- Test conversion funnel tracking

### 3. **Production Deployment** (1 hour)
- Implement error handling
- Add retry logic
- Set up monitoring and alerts

### 4. **Advanced Features** (ongoing)
- Custom event types for your business
- Real-time analytics dashboard integration
- A/B testing event tracking

---

## 📞 **Support & Resources**

### Developer Support
- **Documentation**: `/docs/technical/api_contracts/`
- **Examples**: GitHub repository with integration examples
- **Support Email**: developers@onevault.com
- **Status Page**: https://status.onevault.com

### Change Log
- **v2.0.0**: Initial production release with universal business support
- **v1.x.x**: Beta development versions

---

*This API contract is part of the One Vault Universal Site Tracking System - providing enterprise-grade, privacy-compliant, multi-tenant site tracking for any business vertical.* 