#!/usr/bin/env python3
"""
Direct middleware test without FastAPI
"""
import os
import asyncio
from zero_trust_middleware import ZeroTrustGatewayMiddleware
from local_config import get_local_config

class MockRequest:
    """Mock request object for testing"""
    def __init__(self, headers=None, path="/api/v1/test/basic"):
        self.headers = headers or {}
        self.method = "GET"
        self.url = MockURL(path)
        self.client = MockClient()
        self.state = MockState()
    
    def header(self, name, default=None):
        return self.headers.get(name, default)

class MockURL:
    def __init__(self, path):
        self.path = path
    
    def __str__(self):
        return f"http://localhost:8000{self.path}"

class MockClient:
    def __init__(self):
        self.host = "127.0.0.1"

class MockState:
    def __init__(self):
        pass

async def mock_call_next(request):
    """Mock next function in middleware chain"""
    return {"status": "success", "message": "Request processed"}

async def test_middleware_directly():
    """Test the middleware directly without FastAPI"""
    print("🔧 Direct Middleware Test")
    print("=" * 40)
    
    # Set environment variable
    os.environ['DB_PASSWORD'] = 'password'
    
    try:
        # Initialize middleware
        print("1️⃣ Initializing middleware...")
        config = get_local_config()
        middleware = ZeroTrustGatewayMiddleware(
            db_config=config.database.to_dict(),
            redis_url=None
        )
        print("✅ Middleware initialized")
        
        # Test 1: No authentication
        print("\n2️⃣ Testing without authentication...")
        request_no_auth = MockRequest()
        try:
            result = await middleware(request_no_auth, mock_call_next)
            print(f"❌ Should have failed, but got: {result}")
        except Exception as e:
            print(f"✅ Correctly failed: {e}")
        
        # Test 2: Invalid token
        print("\n3️⃣ Testing with invalid token...")
        request_invalid = MockRequest(headers={"Authorization": "Bearer invalid_token"})
        try:
            result = await middleware(request_invalid, mock_call_next)
            print(f"❌ Should have failed, but got: {result}")
        except Exception as e:
            print(f"✅ Correctly failed: {e}")
        
        # Test 3: Valid token
        print("\n4️⃣ Testing with valid token...")
        valid_token = "7691a495fad262a6cff66d80d8b20ccf7f3736c7fbbd2aa234ef25cdc08f57f8"
        request_valid = MockRequest(headers={"Authorization": f"Bearer {valid_token}"})
        try:
            result = await middleware(request_valid, mock_call_next)
            print(f"✅ Success: {result}")
            
            # Check if context was set
            if hasattr(request_valid.state, 'zero_trust_context'):
                context = request_valid.state.zero_trust_context
                print(f"   Context: Tenant={context.tenant_name}, User={context.user_email}")
            else:
                print("   ⚠️ No Zero Trust context set")
                
        except Exception as e:
            print(f"❌ Failed with valid token: {e}")
            import traceback
            print(f"   Traceback: {traceback.format_exc()}")
        
        # Test 4: Credential extraction
        print("\n5️⃣ Testing credential extraction...")
        try:
            token, token_type = await middleware.extract_credentials(request_valid)
            print(f"✅ Extracted: token={token[:20]}..., type={token_type}")
        except Exception as e:
            print(f"❌ Credential extraction failed: {e}")
        
        # Test 5: Direct token validation
        print("\n6️⃣ Testing direct token validation...")
        try:
            context = await middleware.validate_api_token(valid_token)
            if context:
                print(f"✅ Token validation successful:")
                print(f"   Tenant: {context.tenant_name}")
                print(f"   User: {context.user_email}")
                print(f"   Access Level: {context.access_level}")
            else:
                print("❌ Token validation returned None")
        except Exception as e:
            print(f"❌ Token validation failed: {e}")
            import traceback
            print(f"   Traceback: {traceback.format_exc()}")
        
    except Exception as e:
        print(f"💥 Middleware initialization failed: {e}")
        import traceback
        print(f"   Traceback: {traceback.format_exc()}")
    
    print("\n🏁 Direct test complete!")

if __name__ == "__main__":
    asyncio.run(test_middleware_directly()) 