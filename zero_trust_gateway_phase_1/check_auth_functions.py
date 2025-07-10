#!/usr/bin/env python3
"""
Check what authentication functions exist
"""
import psycopg2

def check_auth_functions():
    """Check authentication functions in the database"""
    try:
        conn = psycopg2.connect(
            host='localhost', 
            port=5432, 
            database='one_vault_site_testing', 
            user='postgres', 
            password='password'
        )
        cur = conn.cursor()

        print('🔍 Looking for authentication functions...')
        print('=' * 50)

        # Get all auth functions
        cur.execute("""
        SELECT routine_name
        FROM information_schema.routines 
        WHERE routine_schema = 'auth' 
        AND (routine_name LIKE '%validate%'
        OR routine_name LIKE '%token%'
        OR routine_name LIKE '%api%')
        ORDER BY routine_name
        """)

        functions = cur.fetchall()
        print('📋 Available auth functions:')
        for func_name, in functions:
            print(f'  ✅ {func_name}')
        
        # Test if a non-production validation function exists
        print('\n🧪 Testing function calls...')
        
        # Test if there's a validate_api_token function
        try:
            cur.execute("SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'auth' AND routine_name = 'validate_api_token'")
            if cur.fetchone():
                print('✅ Found validate_api_token function')
                
                # Test it with our hash
                test_hash = '7691a495fad262a6cff66d80d8b20ccf7f3736c7fbbd2aa234ef25cdc08f57f8'
                cur.execute("SELECT * FROM auth.validate_api_token(%s)", (test_hash,))
                result = cur.fetchone()
                print(f'   Result: {result}')
            else:
                print('❌ No validate_api_token function found')
        except Exception as e:
            print(f'❌ Error testing validate_api_token: {e}')
        
        # Check if validate_token_and_session exists
        try:
            cur.execute("SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'auth' AND routine_name = 'validate_token_and_session'")
            if cur.fetchone():
                print('✅ Found validate_token_and_session function')
                
                # Test it 
                test_hash = '7691a495fad262a6cff66d80d8b20ccf7f3736c7fbbd2aa234ef25cdc08f57f8'
                cur.execute("SELECT * FROM auth.validate_token_and_session(%s, %s)", (test_hash, None))
                result = cur.fetchone()
                print(f'   Result: {result}')
            else:
                print('❌ No validate_token_and_session function found')
        except Exception as e:
            print(f'❌ Error testing validate_token_and_session: {e}')

        # Let's also look at the API_KEY tokens directly
        print('\n📊 API_KEY tokens in database:')
        cur.execute("""
        SELECT 
            ath.api_token_bk,
            th.tenant_bk,
            ats.token_type,
            ats.expires_at,
            ats.is_revoked,
            encode(ats.token_hash, 'hex') as token_hash
        FROM auth.api_token_h ath 
        JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk
        JOIN auth.tenant_h th ON ath.tenant_hk = th.tenant_hk
        WHERE ats.load_end_date IS NULL 
        AND ats.token_type = 'API_KEY'
        LIMIT 3
        """)
        
        api_tokens = cur.fetchall()
        for token_bk, tenant_bk, token_type, expires_at, is_revoked, token_hash in api_tokens:
            print(f'  Tenant: {tenant_bk}')
            print(f'  Token BK: {token_bk}')
            print(f'  Hash: {token_hash}')
            print(f'  Expires: {expires_at}')
            print(f'  Revoked: {is_revoked}')
            print()

        conn.close()
        print('🏁 Function check complete!')
        
    except Exception as e:
        print(f'💥 Error: {e}')
        import traceback
        print(traceback.format_exc())

if __name__ == "__main__":
    check_auth_functions() 