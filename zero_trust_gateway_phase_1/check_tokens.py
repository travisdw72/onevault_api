#!/usr/bin/env python3
"""
Check what API tokens exist in the database
"""
import psycopg2
import os

def check_database_tokens():
    """Check what tokens exist in the database"""
    try:
        conn = psycopg2.connect(
            host='localhost', 
            port=5432, 
            database='one_vault_site_testing', 
            user='postgres', 
            password='password'
        )
        cur = conn.cursor()

        print('🔍 Checking for API tokens in database...')
        print('=' * 50)

        # Check for production tokens
        print('\n1️⃣ Looking for production tokens...')
        cur.execute("""
        SELECT 
            ath.api_token_bk,
            th.tenant_bk,
            ats.token_type,
            ats.is_revoked,
            ats.expires_at,
            encode(ats.token_hash, 'hex') as stored_hash
        FROM auth.api_token_h ath 
        JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk
        JOIN auth.tenant_h th ON ath.tenant_hk = th.tenant_hk
        WHERE ats.load_end_date IS NULL 
        AND ats.token_type = 'production'
        LIMIT 5
        """)
        
        prod_tokens = cur.fetchall()
        if prod_tokens:
            print('✅ Production tokens found:')
            for token_bk, tenant_bk, token_type, is_revoked, expires_at, stored_hash in prod_tokens:
                print(f'  Tenant: {tenant_bk}')
                print(f'  Token BK: {token_bk}')
                print(f'  Type: {token_type}')
                print(f'  Revoked: {is_revoked}')
                print(f'  Expires: {expires_at}')
                print(f'  Hash: {stored_hash}')
                print()
        else:
            print('❌ No production tokens found')
        
        # Check all token types
        print('\n2️⃣ All token types in database:')
        cur.execute("""
        SELECT DISTINCT token_type, COUNT(*)
        FROM auth.api_token_s ats
        WHERE ats.load_end_date IS NULL
        GROUP BY token_type
        """)
        token_types = cur.fetchall()
        for token_type, count in token_types:
            print(f'  {token_type}: {count} tokens')

        # Check specific hash we were trying to use
        print('\n3️⃣ Looking for our test hash...')
        test_hash = '7691a495fad262a6cff66d80d8b20ccf7f3736c7fbbd2aa234ef25cdc08f57f8'
        cur.execute("""
        SELECT 
            ath.api_token_bk,
            th.tenant_bk,
            ats.token_type,
            encode(ats.token_hash, 'hex') as stored_hash
        FROM auth.api_token_h ath 
        JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk
        JOIN auth.tenant_h th ON ath.tenant_hk = th.tenant_hk
        WHERE encode(ats.token_hash, 'hex') = %s
        AND ats.load_end_date IS NULL 
        """, (test_hash,))
        
        match = cur.fetchone()
        if match:
            token_bk, tenant_bk, token_type, stored_hash = match
            print(f'✅ Found matching token:')
            print(f'  Tenant: {tenant_bk}')
            print(f'  Token BK: {token_bk}')
            print(f'  Type: {token_type}')
            print(f'  Hash: {stored_hash}')
        else:
            print(f'❌ No token found with hash: {test_hash}')

        # Test hash computation for different token formats
        print('\n4️⃣ Testing token hash computation...')
        
        test_tokens = [
            f'ovt_prod_{test_hash}',
            test_hash,
            f'prod_{test_hash}',
            'test_token_123'
        ]
        
        for test_token in test_tokens:
            cur.execute('SELECT encode(util.hash_binary(%s), \'hex\') as computed_hash', (test_token,))
            computed_hash = cur.fetchone()[0]
            print(f'  Token: {test_token[:30]}...')
            print(f'  Hash:  {computed_hash}')
            
            # Check if this hash exists in database
            cur.execute("""
            SELECT COUNT(*) 
            FROM auth.api_token_s ats
            WHERE encode(ats.token_hash, 'hex') = %s
            AND ats.load_end_date IS NULL 
            """, (computed_hash,))
            count = cur.fetchone()[0]
            print(f'  Found: {count} matches in database')
            print()

        conn.close()
        print('🏁 Token check complete!')
        
    except Exception as e:
        print(f'💥 Error: {e}')
        import traceback
        print(traceback.format_exc())

if __name__ == "__main__":
    check_database_tokens() 