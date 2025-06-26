# One Vault API Functions Reference
## Quick Reference for Database Functions

### Document Information
- **Last Updated**: 2024-12-28
- **Status**: Production Ready
- **Database**: PostgreSQL with Neon support

---

## 🔑 **Authentication Functions**

### `auth.generate_production_api_token()`
**Purpose**: Generate customer API keys with production-grade security

```sql
SELECT * FROM auth.generate_production_api_token(
    (SELECT user_hk FROM auth.user_profile_s 
     WHERE email = 'customer@example.com' AND load_end_date IS NULL),
    'API',                                    -- Token type
    ARRAY['api:read', 'api:write', 'tracking:full'], -- Permissions
    '30 days',                               -- Expiration
    'Customer site tracking API key'         -- Description
);
```

**Returns**: `token_value`, `expires_at`, `token_id`, `security_level`, `rate_limit_per_hour`

---

### `auth.validate_production_api_token()`
**Purpose**: Validate API keys and return permissions

```sql
SELECT * FROM auth.validate_production_api_token(
    'ovt_prod_abc123...',                    -- API key to validate
    'api:write',                             -- Required permission
    '192.168.1.100'::inet,                  -- Client IP
    'Mozilla/5.0...',                       -- User agent
    'api.track_site_event'                  -- Endpoint being accessed
);
```

**Returns**: `is_valid`, `user_hk`, `tenant_hk`, `scope`, `rate_limit_remaining`

---

## 📊 **Site Tracking Functions**

### `api.track_site_event()`
**Purpose**: Universal site tracking for any business type

```sql
SELECT api.track_site_event(
    '192.168.1.100'::inet,                  -- Client IP
    'Mozilla/5.0 (Windows NT 10.0...)...',  -- User agent
    'https://mystore.com/products/widget',  -- Page URL
    'item_interaction',                     -- Event type
    '{"action": "view_product", "item_id": "widget_pro", "price": 99.99}'::jsonb
);
```

**Event Types**: `pageview`, `item_interaction`, `transaction_step`, `contact_interaction`, `content_engagement`, `feature_usage`

---

## 🏢 **Tenant Management Functions**

### `api.tenant_register_elt()`
**Purpose**: Register new tenants via ELT pipeline

```sql
SELECT api.tenant_register_elt(jsonb_build_object(
    'company_name', 'New Customer Co',
    'domain', 'newcustomer.com',
    'admin_email', 'admin@newcustomer.com',
    'admin_first_name', 'John',
    'admin_last_name', 'Admin',
    'industry', 'E-commerce',
    'subscription_plan', 'Business'
));
```

---

### `auth.auth_login()`
**Purpose**: User authentication with tenant selection

```sql
SELECT auth.auth_login(
    'user@example.com',                     -- Email
    'user_password',                        -- Password
    'a1b2c3d4e5f6...'                      -- Tenant ID (hex)
);
```

---

## 📈 **Monitoring Functions**

### `api.get_tracking_status()`
**Purpose**: Check API health and status

```sql
SELECT api.get_tracking_status();
```

**Returns**: Service status, version, features, timestamp

---

## 🔍 **Quick Queries**

### Get User Hash Key for API Generation
```sql
SELECT user_hk, tenant_hk, email, first_name, last_name
FROM auth.user_profile_s ups
JOIN auth.user_h uh ON ups.user_hk = uh.user_hk
WHERE ups.email = 'customer@example.com'
AND ups.load_end_date IS NULL;
```

### Check Existing API Tokens
```sql
SELECT 
    token_type,
    security_level,
    expires_at,
    usage_count,
    last_used,
    description
FROM auth.api_token_s ats
JOIN auth.user_token_l utl ON ats.api_token_hk = utl.api_token_hk
JOIN auth.user_profile_s ups ON utl.user_hk = ups.user_hk
WHERE ups.email = 'customer@example.com'
AND ats.load_end_date IS NULL
AND ats.is_revoked = FALSE;
```

### View Recent Site Tracking Events
```sql
SELECT 
    event_type,
    page_url,
    event_timestamp,
    event_data
FROM raw.site_tracking_events_r
WHERE tenant_hk = :tenant_hk
AND event_timestamp >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY event_timestamp DESC
LIMIT 100;
```

---

## 🌐 **JavaScript Integration Examples**

### Basic Website Tracking
```html
<!-- Include in your website's <head> -->
<script>
(function() {
  const tracker = new OneVaultTracker('ovt_prod_your_api_key_here');
  
  // Auto-track page views
  tracker.trackPageView();
  
  // Track specific events
  document.addEventListener('click', function(e) {
    if (e.target.classList.contains('purchase-button')) {
      tracker.track('item_interaction', {
        action: 'purchase_intent',
        item_id: e.target.dataset.itemId,
        price: e.target.dataset.price
      });
    }
  });
})();
</script>
```

### Environment Configuration
```javascript
// .env file
ONEVAULT_API_KEY=ovt_prod_your_api_key_here
ONEVAULT_ENDPOINT=https://your-project.neon.tech/api/v1/track
```

---

## 🛠️ **Deployment Checklist**

### For New Customer Setup
1. **Register Tenant**: Use `api.tenant_register_elt()`
2. **Generate API Key**: Use `auth.generate_production_api_token()`
3. **Provide Integration Code**: Share JavaScript tracker
4. **Test Connection**: Verify events are being tracked
5. **Monitor Usage**: Check API usage and rate limits

### For Neon Database Deployment
1. **Update Connection String**: Point to Neon database
2. **Update API Endpoint**: Change from localhost to Neon URL
3. **Test Functions**: Verify all functions work correctly
4. **Update Customer Configs**: Provide new endpoints
5. **Monitor Performance**: Check response times and errors

---

## ⚠️ **Important Notes**

- **API Keys**: Always use `ovt_prod_` prefixed keys for customers
- **Rate Limits**: Standard users get 1000 requests/hour
- **Tenant Isolation**: All data is automatically isolated by tenant
- **HIPAA Compliance**: Session tokens expire in 15 minutes
- **Error Handling**: Always check `is_valid` flag in validation responses

---

*This reference guide provides quick access to all essential API functions and usage patterns.* 