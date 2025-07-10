#!/usr/bin/env python3
import psycopg2
import os

def test_valid_token():
    conn = psycopg2.connect(
        host='localhost',
        port=5432,
        database='one_vault_site_testing',
        user='postgres',
        password=os.getenv('DB_PASSWORD')
    )
    cursor = conn.cursor()

    print('🧪 ZERO TRUST TEST WITH VALID TOKEN')
    print('='*50)

    # Get the valid token
    cursor.execute("""
        SELECT ath.api_token_bk, encode(ath.tenant_hk, 'hex') as tenant_hk 
        FROM auth.api_token_h ath 
        JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk 
        WHERE ats.load_end_date IS NULL 
        AND ats.expires_at > CURRENT_TIMESTAMP 
        AND ats.token_type = 'API_KEY' 
        LIMIT 1
    """)
    
    token_info = cursor.fetchone()
    
    if token_info:
        valid_token = token_info[0]
        token_tenant = token_info[1]
        print(f'✅ Valid token: {valid_token[:30]}...')
        print(f'✅ Token tenant: {token_tenant[:16]}...')
        
        # Test the function
        cursor.execute("SELECT * FROM auth.validate_production_api_token(%s, %s)", (valid_token, 'api:read'))
        result = cursor.fetchone()
        
        if result:
            print(f'✅ Function result: {result}')
            
            # Parse the result
            if len(result) >= 3:
                is_valid = result[0]
                user_hk = result[1]
                tenant_hk = result[2]
                expires_at = result[3] if len(result) > 3 else None
                message = result[8] if len(result) > 8 else None
                
                print(f'📊 PARSED RESULTS:')
                print(f'   - Valid: {is_valid}')
                print(f'   - User HK: {user_hk.hex()[:16] if user_hk else "None"}...')
                print(f'   - Tenant HK: {tenant_hk.hex()[:16] if tenant_hk else "None"}...')
                print(f'   - Expires: {expires_at}')
                print(f'   - Message: {message}')
                
                if is_valid and tenant_hk:
                    print(f'🎉 ZERO TRUST VALIDATION SUCCESSFUL!')
                    print(f'   - Token is valid')
                    print(f'   - Tenant HK returned: {tenant_hk.hex()[:16]}...')
                    print(f'   - Expected tenant: {token_tenant[:16]}...')
                    
                    if tenant_hk.hex() == token_tenant:
                        print(f'✅ TENANT MATCH: Perfect tenant isolation!')
                    else:
                        print(f'❌ TENANT MISMATCH: Something is wrong!')
                        
                    # Test cross-tenant scenario
                    print(f'\n🚨 CROSS-TENANT TEST:')
                    cursor.execute("SELECT encode(tenant_hk, 'hex') FROM auth.tenant_h WHERE encode(tenant_hk, 'hex') != %s LIMIT 1", (token_tenant,))
                    other_tenant = cursor.fetchone()
                    
                    if other_tenant:
                        other_tenant_hk = other_tenant[0]
                        print(f'   - Current token tenant: {token_tenant[:16]}...')
                        print(f'   - Different tenant: {other_tenant_hk[:16]}...')
                        print(f'   - Zero Trust check: IF {tenant_hk.hex()[:16]} == {other_tenant_hk[:16]} THEN ALLOW ELSE DENY')
                        
                        if tenant_hk.hex() == other_tenant_hk:
                            print(f'   ✅ SAME TENANT: Access would be ALLOWED')
                        else:
                            print(f'   🚨 DIFFERENT TENANT: Access should be DENIED')
                            print(f'   🎯 THIS IS WHAT YOUR ZERO TRUST MIDDLEWARE MUST CHECK!')
                    else:
                        print(f'   ⚠️  Only one tenant exists')
                        
                else:
                    print(f'❌ Token validation failed')
            else:
                print(f'⚠️  Unexpected result format')
        else:
            print(f'❌ Function returned no results')
    else:
        print('❌ No valid tokens found')

    conn.close()

if __name__ == "__main__":
    test_valid_token() 