# Token Refresh Trigger Mechanisms
## How to Actually Use the Token Refresh Functions

The `refresh_production_token_enhanced()` function is a **tool** - something needs to call it. Here are the practical implementation approaches for your OneVault system:

---

## 🎯 **Recommended: On-Demand API Validation Trigger**

### **Modify Existing Validation Function**

Since you already have `auth.validate_production_api_token()`, enhance it to automatically refresh when needed:

```sql
-- Enhanced validation with automatic refresh
CREATE OR REPLACE FUNCTION auth.validate_and_refresh_api_token(
    p_token TEXT,
    p_required_scope TEXT DEFAULT 'api:read'
) RETURNS TABLE (
    is_valid BOOLEAN,
    user_hk BYTEA,
    tenant_hk BYTEA,
    scope TEXT[],
    expires_at TIMESTAMP WITH TIME ZONE,
    new_token TEXT,                          -- ✅ NEW: Returns new token if refreshed
    was_refreshed BOOLEAN,                   -- ✅ NEW: Indicates if refresh occurred
    refresh_reason VARCHAR(100),             -- ✅ NEW: Why it was refreshed
    message TEXT
) AS $$
DECLARE
    v_validation_result RECORD;
    v_refresh_result RECORD;
    v_days_until_expiry INTEGER;
    v_should_refresh BOOLEAN := false;
BEGIN
    -- Step 1: Normal validation
    SELECT * INTO v_validation_result
    FROM auth.validate_production_api_token(p_token, p_required_scope);
    
    -- If token is invalid, return early
    IF NOT v_validation_result.is_valid THEN
        RETURN QUERY SELECT 
            v_validation_result.is_valid,
            v_validation_result.user_hk,
            v_validation_result.tenant_hk,
            v_validation_result.scope,
            v_validation_result.expires_at,
            NULL::TEXT,                      -- no new token
            false,                           -- not refreshed
            'TOKEN_INVALID'::VARCHAR(100),
            v_validation_result.message;
        RETURN;
    END IF;
    
    -- Step 2: Check if refresh is needed (7 days threshold)
    v_days_until_expiry := EXTRACT(DAY FROM (v_validation_result.expires_at - CURRENT_TIMESTAMP));
    
    IF v_days_until_expiry <= 7 THEN
        v_should_refresh := true;
    END IF;
    
    -- Step 3: Refresh if needed
    IF v_should_refresh THEN
        SELECT * INTO v_refresh_result
        FROM auth.refresh_production_token_enhanced(p_token, 7, false);
        
        IF v_refresh_result.success THEN
            -- Return validation success + new token
            RETURN QUERY SELECT 
                true,                        -- still valid
                v_validation_result.user_hk,
                v_validation_result.tenant_hk,
                v_validation_result.scope,
                v_refresh_result.expires_at, -- updated expiry
                v_refresh_result.new_token,  -- ✅ NEW TOKEN
                true,                        -- was refreshed
                v_refresh_result.refresh_reason,
                ('Token valid and refreshed: ' || v_refresh_result.message)::TEXT;
        ELSE
            -- Refresh failed, but token is still valid for now
            RETURN QUERY SELECT 
                true,                        -- still valid
                v_validation_result.user_hk,
                v_validation_result.tenant_hk,
                v_validation_result.scope,
                v_validation_result.expires_at,
                NULL::TEXT,                  -- no new token
                false,                       -- refresh failed
                'REFRESH_FAILED'::VARCHAR(100),
                ('Token valid but refresh failed: ' || v_refresh_result.message)::TEXT;
        END IF;
    ELSE
        -- No refresh needed
        RETURN QUERY SELECT 
            true,                            -- valid
            v_validation_result.user_hk,
            v_validation_result.tenant_hk,
            v_validation_result.scope,
            v_validation_result.expires_at,
            NULL::TEXT,                      -- no new token
            false,                           -- not refreshed
            'NO_REFRESH_NEEDED'::VARCHAR(100),
            ('Token valid for ' || v_days_until_expiry || ' more days')::TEXT;
    END IF;
    
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### **API Integration Example**

Update your API endpoints to handle token refresh:

```python
# In your API middleware/routes
async def validate_api_request(request):
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    
    # Call enhanced validation
    result = await db.fetch_one("""
        SELECT * FROM auth.validate_and_refresh_api_token($1, $2)
    """, token, 'api:read')
    
    if not result['is_valid']:
        raise HTTPException(401, "Invalid token")
    
    # If token was refreshed, return new token to client
    if result['was_refreshed']:
        response.headers['X-New-Token'] = result['new_token']
        response.headers['X-Token-Expires'] = result['expires_at'].isoformat()
        response.headers['X-Refresh-Reason'] = result['refresh_reason']
        
        # Log the refresh for monitoring
        logger.info(f"Token auto-refreshed: {result['refresh_reason']}")
    
    # Set user context for request
    request.state.user_hk = result['user_hk']
    request.state.tenant_hk = result['tenant_hk']
    
    return result
```

---

## 🕐 **Background Job for Unused Tokens**

For tokens that don't get used frequently, set up a scheduled job:

### **PostgreSQL Cron Job (if pg_cron available)**

```sql
-- Install pg_cron extension (if not already installed)
-- CREATE EXTENSION pg_cron;

-- Batch refresh function
CREATE OR REPLACE FUNCTION auth.refresh_expiring_tokens_batch()
RETURNS TABLE(
    tokens_found INTEGER,
    tokens_refreshed INTEGER,
    tokens_failed INTEGER,
    details JSONB
) AS $$
DECLARE
    v_token_record RECORD;
    v_refresh_result RECORD;
    v_found_count INTEGER := 0;
    v_success_count INTEGER := 0;
    v_fail_count INTEGER := 0;
    v_details JSONB := '[]'::JSONB;
BEGIN
    -- Find tokens expiring within 7 days
    FOR v_token_record IN 
        SELECT 
            encode(ats.token_hash, 'hex') as token_hash_hex,
            ats.expires_at,
            ats.token_type,
            EXTRACT(DAY FROM (ats.expires_at - CURRENT_TIMESTAMP)) as days_left
        FROM auth.api_token_s ats
        WHERE ats.expires_at <= CURRENT_TIMESTAMP + INTERVAL '7 days'
        AND ats.expires_at > CURRENT_TIMESTAMP
        AND ats.load_end_date IS NULL
        AND ats.is_revoked = false
        AND ats.token_type IN ('API', 'PRODUCTION', 'API_KEY')
        ORDER BY ats.expires_at ASC
    LOOP
        v_found_count := v_found_count + 1;
        
        -- Note: We can't get the actual token value from hash, 
        -- so this approach only works if you store tokens differently
        -- or have a separate tracking mechanism
        
        -- For now, just log what we found
        v_details := v_details || jsonb_build_object(
            'token_hash', v_token_record.token_hash_hex,
            'expires_at', v_token_record.expires_at,
            'days_left', v_token_record.days_left,
            'status', 'FOUND_BUT_CANNOT_REFRESH_FROM_HASH'
        );
    END LOOP;
    
    RETURN QUERY SELECT 
        v_found_count,
        v_success_count,
        v_fail_count,
        v_details;
END;
$$ LANGUAGE plpgsql;

-- Schedule to run every 6 hours
-- SELECT cron.schedule('token-refresh-check', '0 */6 * * *', $$
--   SELECT auth.refresh_expiring_tokens_batch();
-- $$);
```

### **External Service Approach (Recommended)**

Since we can't refresh from hash alone, use an external service:

```python
# token_refresh_service.py
import asyncio
import asyncpg
import logging
from datetime import datetime, timedelta

class TokenRefreshService:
    def __init__(self, db_url):
        self.db_url = db_url
        self.logger = logging.getLogger(__name__)
    
    async def find_and_refresh_expiring_tokens(self):
        """Find and refresh tokens that are expiring soon"""
        conn = await asyncpg.connect(self.db_url)
        
        try:
            # Get tokens from your application's token storage
            # (This assumes you have a separate mechanism to track actual token values)
            
            tokens_to_check = await self.get_tracked_tokens(conn)
            
            refreshed_count = 0
            failed_count = 0
            
            for token_info in tokens_to_check:
                token_value = token_info['token_value']
                
                # Check if refresh is needed
                status = await conn.fetchrow("""
                    SELECT * FROM auth.get_token_refresh_status($1)
                """, token_value)
                
                if status['refresh_recommended']:
                    # Refresh the token
                    result = await conn.fetchrow("""
                        SELECT * FROM auth.refresh_production_token_enhanced($1)
                    """, token_value)
                    
                    if result['success']:
                        refreshed_count += 1
                        await self.update_stored_token(token_info['id'], result['new_token'])
                        self.logger.info(f"Refreshed token {token_info['id']}: {result['refresh_reason']}")
                    else:
                        failed_count += 1
                        self.logger.error(f"Failed to refresh token {token_info['id']}: {result['message']}")
            
            self.logger.info(f"Batch refresh complete: {refreshed_count} refreshed, {failed_count} failed")
            
        finally:
            await conn.close()
    
    async def get_tracked_tokens(self, conn):
        """Get tokens that need to be checked (implement based on your storage)"""
        # This would query your application's token storage
        # For example, from a cache, config file, or separate tracking table
        return []
    
    async def update_stored_token(self, token_id, new_token):
        """Update the stored token value (implement based on your storage)"""
        # Update your application's token storage with the new token
        pass

# Run as a service
async def main():
    service = TokenRefreshService("postgresql://user:pass@localhost/One_Vault")
    
    while True:
        try:
            await service.find_and_refresh_expiring_tokens()
            await asyncio.sleep(3600)  # Check every hour
        except Exception as e:
            logging.error(f"Token refresh service error: {e}")
            await asyncio.sleep(300)  # Wait 5 minutes on error

if __name__ == "__main__":
    asyncio.run(main())
```

---

## 🌐 **API Gateway Middleware (Advanced)**

For high-traffic scenarios, implement at the gateway level:

```javascript
// token-refresh-middleware.js
const { Pool } = require('pg');

class TokenRefreshMiddleware {
  constructor(dbConfig) {
    this.db = new Pool(dbConfig);
  }
  
  async handleRequest(req, res, next) {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token || !token.startsWith('ovt_prod_')) {
      return res.status(401).json({ error: 'Invalid token format' });
    }
    
    try {
      // Validate and potentially refresh token
      const result = await this.db.query(`
        SELECT * FROM auth.validate_and_refresh_api_token($1, $2)
      `, [token, 'api:read']);
      
      const validation = result.rows[0];
      
      if (!validation.is_valid) {
        return res.status(401).json({ 
          error: 'Invalid token',
          message: validation.message 
        });
      }
      
      // Set user context
      req.user_hk = validation.user_hk;
      req.tenant_hk = validation.tenant_hk;
      
      // If token was refreshed, add headers
      if (validation.was_refreshed) {
        res.set({
          'X-New-Token': validation.new_token,
          'X-Token-Expires': validation.expires_at,
          'X-Refresh-Reason': validation.refresh_reason
        });
        
        console.log(`Token auto-refreshed: ${validation.refresh_reason}`);
      }
      
      next();
      
    } catch (error) {
      console.error('Token validation error:', error);
      return res.status(500).json({ error: 'Token validation failed' });
    }
  }
}

module.exports = TokenRefreshMiddleware;
```

---

## 📊 **Implementation Recommendation**

### **Phase 1: Start Simple (On-Demand)**
1. ✅ Deploy the enhanced refresh function (fixed version)
2. ✅ Modify your existing `validate_production_api_token` 
3. ✅ Update API endpoints to handle token refresh headers
4. ✅ Test with your existing production token

### **Phase 2: Add Monitoring**
1. Create dashboard to track refresh metrics
2. Set up alerts for refresh failures
3. Monitor token usage patterns

### **Phase 3: Advanced Automation**
1. Add background service for unused tokens
2. Implement predictive refresh based on usage patterns
3. Add client-side automatic token update logic

---

## 🧪 **Quick Test Implementation**

To test immediately, create a simple validation endpoint:

```sql
-- Test function
CREATE OR REPLACE FUNCTION auth.test_token_refresh_system(p_token TEXT)
RETURNS TABLE(
    step TEXT,
    result TEXT,
    details JSONB
) AS $$
BEGIN
    -- Step 1: Check current status
    RETURN QUERY 
    SELECT 
        'STEP_1_STATUS'::TEXT,
        'Checking token status'::TEXT,
        to_jsonb(status.*) as details
    FROM auth.get_token_refresh_status(p_token) status;
    
    -- Step 2: Test refresh (force refresh for testing)
    RETURN QUERY
    SELECT 
        'STEP_2_REFRESH'::TEXT,
        'Testing refresh function'::TEXT,
        to_jsonb(refresh.*) as details
    FROM auth.refresh_production_token_enhanced(p_token, 7, true) refresh;
    
END;
$$ LANGUAGE plpgsql;
```

Test with your production token:
```sql
SELECT * FROM auth.test_token_refresh_system('ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e');
```

---

## 🎯 **Next Steps**

1. **Deploy the fixed version**: Run `token_refresh_enhanced_FIXED.sql`
2. **Test basic functionality**: Use the test function above
3. **Choose trigger approach**: Start with on-demand API validation
4. **Implement gradually**: Begin with manual testing, then automate

Which approach would you like to implement first? 