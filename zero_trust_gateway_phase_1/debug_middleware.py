#!/usr/bin/env python3
"""
Debug script for Zero Trust middleware issues
"""
import os
import psycopg2
from local_config import get_local_config

def test_database_connection():
    """Test basic database connectivity"""
    try:
        config = get_local_config()
        print("🔌 Testing database connection...")
        
        conn = psycopg2.connect(
            host=config.database.host,
            port=config.database.port,
            database=config.database.database,
            user=config.database.user,
            password=config.database.password
        )
        
        cursor = conn.cursor()
        cursor.execute("SELECT version()")
        version = cursor.fetchone()[0]
        print(f"✅ Database connected: {version}")
        
        # Test the zero trust function exists
        cursor.execute("SELECT 1 FROM information_schema.routines WHERE routine_schema = 'ai_monitoring' AND routine_name = 'validate_zero_trust_access'")
        result = cursor.fetchone()
        if result:
            print("✅ Zero Trust function ai_monitoring.validate_zero_trust_access() exists")
        else:
            print("❌ Zero Trust function ai_monitoring.validate_zero_trust_access() NOT FOUND")
            
        cursor.close()
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False

def test_middleware_import():
    """Test middleware imports"""
    try:
        print("📦 Testing middleware imports...")
        
        from zero_trust_middleware import ZeroTrustGatewayMiddleware
        print("✅ ZeroTrustGatewayMiddleware imported successfully")
        
        from zero_trust_middleware import get_zero_trust_context
        print("✅ get_zero_trust_context imported successfully")
        
        return True
        
    except Exception as e:
        print(f"❌ Middleware import failed: {e}")
        return False

def test_middleware_initialization():
    """Test middleware initialization"""
    try:
        print("🛠️ Testing middleware initialization...")
        
        config = get_local_config()
        
        from zero_trust_middleware import ZeroTrustGatewayMiddleware
        middleware = ZeroTrustGatewayMiddleware(
            db_config=config.database.to_dict(),
            redis_url=None
        )
        
        print("✅ ZeroTrustGatewayMiddleware initialized successfully")
        return middleware
        
    except Exception as e:
        print(f"❌ Middleware initialization failed: {e}")
        return None

def test_token_validation():
    """Test token validation directly"""
    try:
        print("🔑 Testing token validation...")
        
        config = get_local_config()
        
        # Test with a known token hash
        test_token = "7691a495fad262a6cff66d80d8b20ccf7f3736c7fbbd2aa234ef25cdc08f57f8"
        
        conn = psycopg2.connect(
            host=config.database.host,
            port=config.database.port,
            database=config.database.database,
            user=config.database.user,
            password=config.database.password
        )
        
        cursor = conn.cursor()
        
        # Check if this token exists
        cursor.execute("""
            SELECT ath.api_token_bk, th.tenant_bk, encode(ath.tenant_hk, 'hex')
            FROM auth.api_token_h ath
            JOIN auth.tenant_h th ON ath.tenant_hk = th.tenant_hk
            WHERE ath.api_token_bk LIKE %s
        """, (f"%{test_token}%",))
        
        result = cursor.fetchone()
        if result:
            token_bk, tenant_bk, tenant_hk = result
            print(f"✅ Token found in database:")
            print(f"   Token BK: {token_bk}")
            print(f"   Tenant: {tenant_bk}")
            print(f"   Tenant HK: {tenant_hk}")
        else:
            print(f"❌ Token {test_token} not found in database")
            
        cursor.close()
        conn.close()
        return result is not None
        
    except Exception as e:
        print(f"❌ Token validation test failed: {e}")
        return False

def main():
    """Run all debug tests"""
    print("🛡️ Zero Trust Gateway Middleware Debug")
    print("=" * 50)
    
    # Set password if not set
    if not os.getenv('DB_PASSWORD'):
        os.environ['DB_PASSWORD'] = 'password'
        print("🔑 Set DB_PASSWORD for testing")
    
    # Run tests
    tests = [
        ("Database Connection", test_database_connection),
        ("Middleware Imports", test_middleware_import),
        ("Middleware Initialization", test_middleware_initialization),
        ("Token Validation", test_token_validation),
    ]
    
    for test_name, test_func in tests:
        print(f"\n🧪 {test_name}")
        print("-" * 30)
        try:
            result = test_func()
            if result:
                print(f"✅ {test_name} PASSED")
            else:
                print(f"❌ {test_name} FAILED")
        except Exception as e:
            print(f"💥 {test_name} CRASHED: {e}")
    
    print("\n🏁 Debug tests complete!")

if __name__ == "__main__":
    main() 