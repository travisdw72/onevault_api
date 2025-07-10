#!/usr/bin/env python3
"""
Test API_KEY validation specifically
"""
import os
import asyncio
import hashlib
from zero_trust_middleware import ZeroTrustGatewayMiddleware
from local_config import get_local_config

async def test_api_key_validation():
    """Test the new API_KEY validation method directly"""
    print("🔧 API_KEY Validation Test")
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
        
        # Test token from our database
        test_token = '7691a495fad262a6cff66d80d8b20ccf7f3736c7fbbd2aa234ef25cdc08f57f8'
        token_hash = hashlib.sha256(test_token.encode()).digest()
        
        print(f"\n2️⃣ Testing token hash computation...")
        print(f"   Token: {test_token}")
        print(f"   Hash (hex): {token_hash.hex()}")
        
        # Test direct database query
        print(f"\n3️⃣ Testing direct database query...")
        query = """
        SELECT 
            ats.api_token_hk,
            ats.token_type,
            ats.expires_at,
            ats.is_revoked,
            ats.scope,
            ath.tenant_hk,
            encode(ats.token_hash, 'hex') as stored_hash
        FROM auth.api_token_s ats
        JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
        WHERE ats.token_hash = %s
        AND ats.load_end_date IS NULL
        AND ats.token_type = 'API_KEY'
        """
        
        result = await middleware._execute_db_query(query, (token_hash,))
        
        if result:
            print(f"✅ Found {len(result)} matching token(s)")
            for row in result:
                api_token_hk, token_type, expires_at, is_revoked, scope, tenant_hk, stored_hash = row
                print(f"   Token Type: {token_type}")
                print(f"   Expires: {expires_at}")
                print(f"   Revoked: {is_revoked}")
                print(f"   Stored Hash: {stored_hash}")
                print(f"   Computed Hash: {token_hash.hex()}")
                print(f"   Hash Match: {stored_hash == token_hash.hex()}")
        else:
            print("❌ No matching tokens found")
            
            # Let's check what hashes actually exist
            print("\n🔍 Checking what token hashes exist in database...")
            check_query = """
            SELECT 
                ats.token_type,
                encode(ats.token_hash, 'hex') as stored_hash,
                ats.expires_at,
                ats.is_revoked
            FROM auth.api_token_s ats
            WHERE ats.load_end_date IS NULL
            LIMIT 5
            """
            
            existing_tokens = await middleware._execute_db_query(check_query, ())
            if existing_tokens:
                print("📋 Existing tokens:")
                for token_type, stored_hash, expires_at, is_revoked in existing_tokens:
                    print(f"   Type: {token_type}, Hash: {stored_hash[:20]}..., Expires: {expires_at}, Revoked: {is_revoked}")
            else:
                print("❌ No tokens found at all")
        
        # Test the API_KEY validation method
        print(f"\n4️⃣ Testing validate_api_key_token method...")
        try:
            context = await middleware.validate_api_key_token(test_token)
            if context:
                print(f"✅ API_KEY validation successful!")
                print(f"   Tenant: {context.tenant_name}")
                print(f"   User: {context.user_email}")
                print(f"   Access Level: {context.access_level}")
                print(f"   Risk Score: {context.risk_score}")
            else:
                print("❌ API_KEY validation returned None")
        except Exception as e:
            print(f"❌ API_KEY validation failed: {e}")
            import traceback
            print(f"   Traceback: {traceback.format_exc()}")
        
        # Test the main validate_api_token method
        print(f"\n5️⃣ Testing main validate_api_token method...")
        try:
            context = await middleware.validate_api_token(test_token)
            if context:
                print(f"✅ Main validation successful!")
                print(f"   Tenant: {context.tenant_name}")
                print(f"   User: {context.user_email}")
                print(f"   Access Level: {context.access_level}")
            else:
                print("❌ Main validation returned None")
        except Exception as e:
            print(f"❌ Main validation failed: {e}")
            import traceback
            print(f"   Traceback: {traceback.format_exc()}")
        
    except Exception as e:
        print(f"💥 Test failed: {e}")
        import traceback
        print(f"   Traceback: {traceback.format_exc()}")
    
    print("\n🏁 API_KEY validation test complete!")

if __name__ == "__main__":
    asyncio.run(test_api_key_validation()) 