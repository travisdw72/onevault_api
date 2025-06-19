Below is the enhanced and generalized version of the **Site Tracking API Contract**, designed to be applicable to a wide range of businesses and websites beyond just a spa. The spa-specific terms have been replaced with generic ones, making it versatile for industries such as e-commerce, SaaS, content platforms, and more, while maintaining the core functionality and structure of the tracking system.

---

# Site Tracking API Contract
## Analytics & Visitor Tracking System

### Overview
This contract defines the analytics and visitor tracking API endpoints for collecting user behavior data, interactions with items or services, and conversion metrics across various types of websites and businesses. The system is privacy-compliant with GDPR/CCPA regulations and respects Do Not Track preferences.

---

## 🔌 **Primary Tracking Endpoints**

### **POST /api/tracking/events.js**
Primary endpoint for collecting all tracking events and user interaction data.

#### Request Headers:
```
Content-Type: application/json
X-Session-ID: session_1234567890_abc123 (optional - generated if not provided)
```

#### Request Format (Single Event):
```json
{
    "evt_type": "page_view|click|scroll_depth|item_interaction|transaction_step|contact_interaction",
    "evt_category": "general|items|transactions|contact|engagement|navigation",
    "evt_action": "view|click|hover|submit|start|progress|complete|abandon",
    "evt_label": "item_name|page_path|button_id|form_name",
    "evt_value": 100,
    
    // Page Context
    "page_url": "https://example.com/items",
    "page_title": "Items - Example Site",
    "page_referrer": "https://google.com/search",
    
    // User Context (Privacy-Safe)
    "viewport_width": 1920,
    "viewport_height": 1080,
    "device_type": "mobile|tablet|desktop",
    "browser_name": "chrome|firefox|safari|edge|other",
    "user_agent": "Mozilla/5.0...",
    
    // Interaction Data
    "scroll_depth": 75,
    "time_on_page": 45000,
    "click_x": 450,
    "click_y": 200,
    
    // Timestamp
    "event_timestamp": "2025-01-15T14:30:22.000Z"
}
```

#### Request Format (Batch Events):
```json
[
    {
        "evt_type": "page_view",
        "evt_category": "navigation",
        "evt_action": "view",
        "page_url": "https://example.com/items",
        "event_timestamp": "2025-01-15T14:30:22.000Z"
    },
    {
        "evt_type": "item_interaction",
        "evt_category": "items",
        "evt_action": "click",
        "evt_label": "item_name",
        "evt_value": 165,
        "event_timestamp": "2025-01-15T14:30:25.000Z"
    }
]
```

#### Response Format (Success):
```json
{
    "success": true,
    "message": "Tracking events processed successfully",
    "data": {
        "session_id": "sess_1703123456789_xyz789",
        "events_processed": 2,
        "timestamp": "2025-01-15T14:30:22.000Z"
    }
}
```

#### Response Format (Error):
```json
{
    "success": false,
    "message": "No events provided",
    "error_code": "INVALID_REQUEST"
}
```

### **GET|POST /api/tracking/test.js**
Health check and testing endpoint for the tracking system.

#### GET Response:
```json
{
    "success": true,
    "message": "Site tracking API is operational",
    "data": {
        "tracking_endpoint": "/api/tracking/events",
        "timestamp": "2025-01-15T14:30:22.000Z",
        "status": "healthy"
    }
}
```

#### POST Test Event:
```json
{
    "success": true,
    "message": "Test tracking event processed successfully",
    "data": {
        "test_event": {...},
        "session_id": "test_session_1703123456789",
        "timestamp": "2025-01-15T14:30:22.000Z"
    }
}
```

---

## 📊 **Event Type Specifications**

### **Page View Events**
```json
{
    "evt_type": "page_view",
    "evt_category": "navigation",
    "evt_action": "view",
    "evt_label": "/items",
    "page_url": "https://example.com/items",
    "page_title": "Items - Example Site",
    "page_referrer": "https://google.com"
}
```

### **Item Interaction Events**
Tracks interactions with products, services, or features.
```json
{
    "evt_type": "item_interaction",
    "evt_category": "items",
    "evt_action": "click|hover|view_details",
    "evt_label": "item_name",
    "evt_value": 165
}
```

### **Transaction Funnel Events**
Tracks steps in a transactional process (e.g., purchases, sign-ups).
```json
{
    "evt_type": "transaction_step",
    "evt_category": "transactions",
    "evt_action": "start|progress|complete|abandon",
    "evt_label": "step_name",
    "evt_value": 100
}
```

### **Contact Interaction Events**
```json
{
    "evt_type": "contact_interaction",
    "evt_category": "contact",
    "evt_action": "form_view|form_submit|phone_click|email_click|map_interaction",
    "evt_value": 25
}
```

### **Scroll Depth Events**
```json
{
    "evt_type": "scroll_depth",
    "evt_category": "engagement",
    "evt_action": "scroll",
    "evt_label": "75%",
    "evt_value": 75,
    "scroll_depth": 75
}
```

### **Click Events**
```json
{
    "evt_type": "click",
    "evt_category": "button_click|link_click|item_interaction",
    "evt_action": "click",
    "evt_label": "button_id|link_id|item_name",
    "click_x": 450,
    "click_y": 200
}
```

---

## 🎯 **Custom Event Categories and Labels**

The API is flexible, allowing businesses to define custom event categories and labels to suit their needs. The `evt_category` and `evt_label` fields accept arbitrary strings.

### **Examples:**
- **E-commerce Site:**
  - `evt_category`: "products"
  - `evt_label`: "product_id" or "product_name"
- **SaaS Platform:**
  - `evt_category`: "features"
  - `evt_label`: "feature_name"
- **Content Website:**
  - `evt_category`: "articles"
  - `evt_label`: "article_title" or "article_id"

### **Transaction Funnel Steps (Generic):**
- `transaction_start`: Initiates a transaction (e.g., add to cart, start sign-up)
- `transaction_progress`: Advances through steps (e.g., selects options, enters details)
- `transaction_complete`: Successfully completes the transaction
- `transaction_abandon`: Abandons the transaction process

### **Conversion Values (Example):**
These are illustrative and can be customized:
- `transaction_value`: 100 points
- `consultation_value`: 50 points
- `contact_form_value`: 25 points
- `phone_click_value`: 15 points
- `newsletter_value`: 10 points

---

## 🔒 **Privacy & Security**

### **Privacy Features**
- **Do Not Track Compliance**: Respects `navigator.doNotTrack === '1'`
- **IP Anonymization**: Client IPs are hashed for privacy
- **Session-Based**: No persistent user identification
- **Opt-Out Support**: Users can disable tracking
- **Data Minimization**: Only essential data collected

### **CORS Headers**
```
Access-Control-Allow-Credentials: true
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: POST,OPTIONS
Access-Control-Allow-Headers: X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, X-Session-ID
```

### **Data Sanitization**
- `evt_label`: Max 255 characters
- `page_url`: Max 500 characters
- `page_title`: Max 255 characters
- `page_referrer`: Max 500 characters
- `user_agent`: Max 500 characters

---

## 📈 **Data Storage & Retention**

### **Current Implementation**
- **Development**: Events logged to browser console
- **Production**: Events logged to server console with structured JSON
- **Future**: Data Vault 2.0 integration for persistent storage

### **Data Structure (Stored)**
```json
{
    "tracking_id": "evt_1703123456789_abc123",
    "session_id": "sess_1703123456789_xyz789",
    "client_ip": "192.168.1.100", // Hashed for privacy
    "timestamp": "2025-01-15T14:30:22.000Z",
    "tenant": "example_site",
    "record_source": "site_tracker",
    
    // Event data (sanitized)
    "evt_type": "item_interaction",
    "evt_category": "items",
    "evt_action": "click",
    "evt_label": "item_name",
    "evt_value": 165,
    
    // Context data
    "page_url": "https://example.com/items",
    "device_type": "mobile",
    "browser_name": "chrome"
}
```

---

## 🔧 **Integration Examples**

### **Frontend JavaScript Integration**
```javascript
// Initialize tracker
window.siteTracker = new SiteTracker({
    api_endpoint: '/api/tracking/events',
    debug_mode: false,
    track_page_views: true,
    track_clicks: true,
    track_scroll: true
});

// Track custom events
window.siteTracker.trackEvent({
    evt_type: 'item_interaction',
    evt_category: 'items',
    evt_action: 'click',
    evt_label: 'item_name',
    evt_value: 165
});

// Track transaction funnel
window.siteTracker.trackTransactionStep('transaction_start', 'start', {
    evt_label: 'item_name'
});
```

### **HTML Data Attributes**
```html
<!-- Item tracking -->
<div class="item-card" data-item="item_name">
    <button class="action-button" data-action="transaction_start" data-item="item_name">
        Take Action
    </button>
</div>

<!-- Contact tracking -->
<form class="contact-form" name="contact">
    <!-- Form fields -->
</form>

<a href="tel:+1234567890">Call Us</a>
<a href="mailto:info@example.com">Email Us</a>
```

---

## 🚨 **Error Codes**

| Code                | HTTP Status | Description                       |
|---------------------|-------------|-----------------------------------|
| `METHOD_NOT_ALLOWED`| 405         | Only POST method accepted         |
| `INVALID_REQUEST`   | 400         | No events provided in request     |
| `PROCESSING_ERROR`  | 500         | Server error processing events    |
| `CORS_ERROR`        | 403         | CORS policy violation             |

---

## 📋 **Testing & Validation**

### **Endpoint Health Check**
```bash
curl -X GET https://example.com/api/tracking/test
```

### **Test Event Submission**
```bash
curl -X POST https://example.com/api/tracking/events \
-H "Content-Type: application/json" \
-d '{
    "evt_type": "test_event",
    "evt_category": "testing",
    "evt_action": "api_test",
    "evt_label": "curl_test"
}'
```

### **Browser Console Testing**
```javascript
// Check if tracking is working
console.log('Tracker status:', !!window.siteTracker);

// Enable debug mode
window.siteTracker = new SiteTracker({ debug_mode: true });

// Watch network requests in DevTools → Network tab
// Look for POST requests to /api/tracking/events
```

---

## 🔄 **Future Enhancements**

### **Planned Features**
1. **Data Vault 2.0 Integration**: Persistent database storage
2. **Real-time Analytics Dashboard**: Live metrics visualization
3. **Advanced Segmentation**: User behavior analysis
4. **Conversion Attribution**: Marketing campaign tracking
5. **A/B Testing Framework**: Presentation optimization

### **API Versioning**
Future versions will follow: `/api/v2/tracking/events`

---

### Key Changes Made
- **Generalized Terminology**: Replaced `service_interaction` with `item_interaction`, `booking_step` with `transaction_step`, and spa-specific labels (e.g., `signature_massage`) with generic placeholders (e.g., `item_name`).
- **Flexible Categories**: Removed spa-specific categories (e.g., `services`, `booking`) and introduced customizable categories like `items` and `transactions`.
- **Customizability**: Added a section on defining custom event categories and labels with examples for different industries.
- **Examples Updated**: Adjusted integration examples to use generic terms applicable to any business.
- **Removed Spa References**: Eliminated all mentions of "The ONE Spa Oregon" and spa-specific contexts.

This updated contract is now versatile, reusable, and adaptable to various business types while preserving its robust tracking and privacy features.