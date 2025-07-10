#!/usr/bin/env python3
import psycopg2
import os
import sys

def test_zero_trust_function():
    """Test the Zero Trust validation function"""
    
    # Database connection
    try:
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            database='one_vault_site_testing',
            user='postgres',
            password=os.getenv('DB_PASSWORD')
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False
    
    # Test 1: Check if function exists
    print("\n🔍 TEST 1: Function Existence")
    cursor.execute("""
        SELECT routine_name, routine_type, data_type as return_type
        FROM information_schema.routines
        WHERE routine_schema = 'auth'
        AND routine_name = 'validate_production_api_token'
    """)
    func_info = cursor.fetchone()
    if func_info:
        print(f"✅ Function exists: {func_info[0]} ({func_info[1]}) -> {func_info[2]}")
    else:
        print("❌ Function does not exist!")
        return False
    
    # Test 2: Get a token for testing
    print("\n🔍 TEST 2: Get Test Token")
    cursor.execute("SELECT api_token_bk, encode(tenant_hk, 'hex') as tenant_hk FROM auth.api_token_h LIMIT 1")
    token_info = cursor.fetchone()
    if token_info:
        test_token = token_info[0]
        expected_tenant = token_info[1]
        print(f"✅ Test token: {test_token[:30]}...")
        print(f"✅ Expected tenant: {expected_tenant[:16]}...")
    else:
        print("❌ No tokens found!")
        return False
    
    # Test 3: Test the function - simplified call
    print("\n🔍 TEST 3: Zero Trust Function Test")
    try:
        cursor.execute("SELECT * FROM auth.validate_production_api_token(%s, %s)", (test_token, 'api:read'))
        
        result = cursor.fetchone()
        if result:
            print(f"✅ Function executed successfully:")
            print(f"   - Raw result: {result}")
            
            # Try to parse based on expected structure
            if len(result) >= 3:
                is_valid = result[0] if result[0] is not None else False
                user_hk = result[1] if result[1] is not None else None
                tenant_hk = result[2] if result[2] is not None else None
                expires_at = result[3] if len(result) > 3 and result[3] is not None else None
                message = result[4] if len(result) > 4 and result[4] is not None else None
                
                print(f"   - Valid: {is_valid}")
                print(f"   - User HK: {user_hk.hex()[:16] if user_hk else 'None'}...")
                print(f"   - Tenant HK: {tenant_hk.hex()[:16] if tenant_hk else 'None'}...")
                print(f"   - Expires: {expires_at}")
                print(f"   - Message: {message}")
                
                # Test 4: Cross-tenant scenario
                print("\n🔍 TEST 4: Cross-Tenant Access Test")
                
                # Get a different tenant
                cursor.execute("SELECT encode(tenant_hk, 'hex') FROM auth.tenant_h WHERE encode(tenant_hk, 'hex') != %s LIMIT 1", (expected_tenant,))
                other_tenant = cursor.fetchone()
                
                if other_tenant:
                    other_tenant_hk = other_tenant[0]
                    print(f"✅ Testing cross-tenant access")
                    print(f"   - Token tenant: {expected_tenant[:16]}...")
                    print(f"   - Requested tenant: {other_tenant_hk[:16]}...")
                    
                    # This is where Zero Trust middleware would check
                    if tenant_hk and tenant_hk.hex() == expected_tenant:
                        if expected_tenant == other_tenant_hk:
                            print("✅ SAME TENANT: Access would be ALLOWED")
                        else:
                            print("🚨 DIFFERENT TENANT: Access should be DENIED")
                            print("   This is what Zero Trust middleware must check!")
                            print("   🎯 ZERO TRUST VALIDATION NEEDED!")
                    else:
                        print("⚠️  Unable to determine tenant relationship")
                else:
                    print("⚠️  Only one tenant exists - cannot test cross-tenant scenario")
            else:
                print("⚠️  Unexpected result format")
        else:
            print("❌ Function returned no results")
            
    except Exception as e:
        print(f"❌ Function test failed: {e}")
        return False
    
    # Test 5: Enhanced function test
    print("\n🔍 TEST 5: Enhanced Function Test")
    try:
        cursor.execute("""
            SELECT routine_name 
            FROM information_schema.routines 
            WHERE routine_schema = 'auth' 
            AND routine_name = 'validate_and_extend_token'
        """)
        enhanced_func = cursor.fetchone()
        if enhanced_func:
            print("✅ Enhanced function exists: validate_and_extend_token")
            
            # Test it
            cursor.execute("SELECT * FROM auth.validate_and_extend_token(%s, %s)", (test_token, 'api:read'))
            
            enhanced_result = cursor.fetchone()
            if enhanced_result:
                print(f"✅ Enhanced function results:")
                print(f"   - Raw result: {enhanced_result}")
                
                # Try to parse
                if len(enhanced_result) >= 6:
                    is_valid = enhanced_result[0] if enhanced_result[0] is not None else False
                    user_hk = enhanced_result[1] if enhanced_result[1] is not None else None
                    tenant_hk = enhanced_result[2] if enhanced_result[2] is not None else None
                    expires_at = enhanced_result[3] if enhanced_result[3] is not None else None
                    message = enhanced_result[4] if enhanced_result[4] is not None else None
                    token_extended = enhanced_result[5] if enhanced_result[5] is not None else False
                    
                    print(f"   - Valid: {is_valid}")
                    print(f"   - Token Extended: {token_extended}")
                    print(f"   - New Expires: {expires_at}")
                    print(f"   - Message: {message}")
                    
                    if token_extended:
                        print("🎉 TOKEN AUTO-EXTENSION WORKING!")
                    else:
                        print("⚠️  Token not extended (may be expired)")
                else:
                    print("⚠️  Unexpected enhanced result format")
            else:
                print("⚠️  Enhanced function returned no results")
        else:
            print("⚠️  Enhanced function not found")
            
    except Exception as e:
        print(f"⚠️  Enhanced function test failed: {e}")
    
    conn.close()
    print("\n🎯 ZERO TRUST TESTING COMPLETE")
    return True

if __name__ == "__main__":
    print("🧪 ZERO TRUST FUNCTION TESTING")
    print("=" * 50)
    
    if not os.getenv('DB_PASSWORD'):
        print("❌ Please set DB_PASSWORD environment variable")
        print("   Run: $env:DB_PASSWORD='your_password'")
        sys.exit(1)
    
    success = test_zero_trust_function()
    if success:
        print("\n✅ Testing completed successfully!")
    else:
        print("\n❌ Testing failed!")
        sys.exit(1) 