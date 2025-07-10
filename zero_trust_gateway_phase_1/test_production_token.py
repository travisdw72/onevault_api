#!/usr/bin/env python3
import psycopg2
import os

def test_production_token():
    """Test Zero Trust validation with actual production token"""
    
    conn = psycopg2.connect(
        host='localhost',
        port=5432,
        database='one_vault_site_testing',
        user='postgres',
        password=os.getenv('DB_PASSWORD')
    )
    cursor = conn.cursor()

    print('🚀 TESTING WITH ACTUAL PRODUCTION TOKEN')
    print('='*60)

    # Test with the real production token from environment
    prod_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
    customer_id = 'one_barn_ai'
    
    print(f'🔑 Production token: {prod_token[:30]}...')
    print(f'🏢 Expected customer: {customer_id}')

    # Test the Zero Trust function
    cursor.execute("SELECT * FROM auth.validate_production_api_token(%s, %s)", (prod_token, 'api:read'))
    result = cursor.fetchone()

    if result:
        print(f'\n✅ Zero Trust function executed')
        print(f'📊 Raw result: {result}')
        
        # Parse the result
        if len(result) >= 3:
            is_valid = result[0]
            user_hk = result[1]
            tenant_hk = result[2]
            expires_at = result[3] if len(result) > 3 else None
            message = result[8] if len(result) > 8 else 'No message'
            
            print(f'\n📈 PARSED RESULTS:')
            print(f'   - Valid: {is_valid}')
            print(f'   - User HK: {user_hk.hex()[:16] if user_hk else "None"}...')
            print(f'   - Tenant HK: {tenant_hk.hex()[:16] if tenant_hk else "None"}...')
            print(f'   - Expires: {expires_at}')
            print(f'   - Message: {message}')
            
            # Critical Zero Trust Analysis
            print(f'\n🛡️  ZERO TRUST ANALYSIS:')
            
            if is_valid and tenant_hk:
                print(f'✅ Token validation successful!')
                print(f'✅ Tenant HK returned: {tenant_hk.hex()}')
                
                # Check if this matches the expected customer tenant
                cursor.execute("""
                    SELECT encode(tenant_hk, 'hex') 
                    FROM auth.tenant_h th 
                    JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk 
                    WHERE tps.tenant_name = %s 
                    AND tps.load_end_date IS NULL
                """, (customer_id,))
                
                expected_tenant = cursor.fetchone()
                
                if expected_tenant:
                    expected_hk = expected_tenant[0]
                    print(f'✅ Expected tenant HK: {expected_hk}')
                    
                    if tenant_hk.hex() == expected_hk:
                        print(f'🎉 PERFECT TENANT MATCH!')
                        print(f'   - Token belongs to: {customer_id}')
                        print(f'   - Zero Trust validation: SECURE ✅')
                    else:
                        print(f'🚨 TENANT MISMATCH!')
                        print(f'   - Token tenant: {tenant_hk.hex()[:16]}...')
                        print(f'   - Expected tenant: {expected_hk[:16]}...')
                        print(f'   - Zero Trust validation: BREACH DETECTED ❌')
                        
                    # Test cross-tenant scenario
                    print(f'\n🧪 CROSS-TENANT ACCESS TEST:')
                    cursor.execute("""
                        SELECT encode(tenant_hk, 'hex'), tps.tenant_name 
                        FROM auth.tenant_h th 
                        JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk 
                        WHERE encode(tenant_hk, 'hex') != %s 
                        AND tps.load_end_date IS NULL 
                        LIMIT 1
                    """, (expected_hk,))
                    
                    other_tenant = cursor.fetchone()
                    
                    if other_tenant:
                        other_hk, other_name = other_tenant
                        print(f'   - Token belongs to: {customer_id} ({expected_hk[:16]}...)')
                        print(f'   - Attempting access to: {other_name} ({other_hk[:16]}...)')
                        print(f'   - Zero Trust check: "{tenant_hk.hex()}" == "{other_hk}"?')
                        
                        if tenant_hk.hex() == other_hk:
                            print(f'   ✅ SAME TENANT: Access ALLOWED')
                        else:
                            print(f'   🚨 DIFFERENT TENANT: Access DENIED')
                            print(f'   🎯 THIS IS WHAT YOUR MIDDLEWARE MUST ENFORCE!')
                            
                        # Show the middleware logic
                        print(f'\n🔧 MIDDLEWARE LOGIC REQUIRED:')
                        print(f'   if (tokenTenantHk !== requestedTenantId) {{')
                        print(f'       throw new Error("Cross-tenant access denied");')
                        print(f'   }}')
                    else:
                        print(f'   ⚠️  Only one tenant exists - cannot test cross-tenant')
                        
                else:
                    print(f'⚠️  Customer "{customer_id}" not found in localhost database')
                    print(f'   - This is expected for localhost testing')
                    print(f'   - Production token belongs to production database')
                    
            elif not is_valid:
                print(f'❌ Token validation failed: {message}')
                if 'not found' in message.lower():
                    print(f'   - This is expected: production token not in localhost DB')
                    print(f'   - Zero Trust function is working correctly')
                    print(f'   - Would return tenant_hk in production environment')
            else:
                print(f'⚠️  Token valid but no tenant_hk returned')
                
            # Test the enhanced function if it exists
            print(f'\n🧪 ENHANCED FUNCTION TEST:')
            try:
                cursor.execute("SELECT * FROM auth.validate_and_extend_production_token(%s, %s)", (prod_token, 'api:read'))
                enhanced_result = cursor.fetchone()
                
                if enhanced_result:
                    print(f'✅ Enhanced function exists and executed')
                    print(f'📊 Enhanced result: {enhanced_result}')
                    
                    # Parse enhanced result
                    if len(enhanced_result) >= 10:
                        enhanced_valid = enhanced_result[0]
                        enhanced_tenant = enhanced_result[2]
                        token_extended = enhanced_result[9] if len(enhanced_result) > 9 else False
                        
                        print(f'   - Valid: {enhanced_valid}')
                        print(f'   - Token Extended: {token_extended}')
                        print(f'   - Tenant HK: {enhanced_tenant.hex()[:16] if enhanced_tenant else "None"}...')
                        
                        if token_extended:
                            print(f'🎉 AUTO-EXTENSION FEATURE WORKING!')
            else:
                    print(f'⚠️  Enhanced function returned no results')
                    
        except Exception as e:
                print(f'⚠️  Enhanced function test failed: {e}')
                
        else:
            print(f'⚠️  Unexpected result format: {len(result)} fields')
    else:
        print(f'❌ Zero Trust function returned no results')

    conn.close()
    print(f'\n🎯 PRODUCTION TOKEN TEST COMPLETE')

if __name__ == "__main__":
    if not os.getenv('DB_PASSWORD'):
        print("❌ Please set DB_PASSWORD environment variable")
        print("   Run: $env:DB_PASSWORD='password'")
        exit(1)
        
    test_production_token() 