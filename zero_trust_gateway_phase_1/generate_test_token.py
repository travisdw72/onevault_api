#!/usr/bin/env python3
"""
Generate a fresh API token for testing
"""
import psycopg2
import os
from datetime import datetime, timedelta

def generate_fresh_api_token():
    """Generate a fresh, non-expired, non-revoked API token"""
    try:
        conn = psycopg2.connect(
            host='localhost', 
            port=5432, 
            database='one_vault_site_testing', 
            user='postgres', 
            password='password'
        )
        cur = conn.cursor()

        print('🔧 Generating fresh API token...')
        print('=' * 50)

        # Get a tenant for the token
        cur.execute("""
        SELECT tenant_hk, tenant_bk 
        FROM auth.tenant_h 
        WHERE load_date IS NOT NULL
        LIMIT 1
        """)
        
        tenant_info = cur.fetchone()
        if not tenant_info:
            print("❌ No tenants found")
            return
        
        tenant_hk, tenant_bk = tenant_info
        print(f"📋 Using tenant: {tenant_bk}")
        print(f"   Tenant HK: {tenant_hk.hex()[:16]}...")

        # Generate a new API token using the existing function
        print("\n🎯 Calling generate_api_token function...")
        try:
            cur.execute("""
            SELECT auth.generate_api_token(%s, %s, %s, %s, %s)
            """, (
                tenant_hk,                              # p_tenant_hk
                None,                                   # p_user_hk (optional)
                'test_api_token_for_zero_trust',       # p_token_name
                '{"api:read", "api:write"}',           # p_scope
                (datetime.now() + timedelta(days=30)).isoformat()  # p_expires_at (30 days from now)
            ))
            
            result = cur.fetchone()
            if result and result[0]:
                token_data = result[0]
                print(f"✅ Token generated successfully!")
                print(f"   Token: {token_data}")
                
                # Test the generated token
                print(f"\n🧪 Testing generated token...")
                test_token = token_data
                
                # Look up the token in the database
                cur.execute("""
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
                WHERE ats.token_hash = util.hash_binary(%s)
                AND ats.load_end_date IS NULL
                """, (test_token,))
                
                token_info = cur.fetchone()
                if token_info:
                    api_token_hk, token_type, expires_at, is_revoked, scope, stored_tenant_hk, stored_hash = token_info
                    print(f"✅ Token found in database:")
                    print(f"   Type: {token_type}")
                    print(f"   Expires: {expires_at}")
                    print(f"   Revoked: {is_revoked}")
                    print(f"   Scope: {scope}")
                    print(f"   Hash: {stored_hash}")
                    
                    print(f"\n🎉 USE THIS TOKEN FOR TESTING:")
                    print(f"   Authorization: Bearer {test_token}")
                    
                else:
                    print("❌ Generated token not found in database")
                    
            else:
                print("❌ Token generation failed")
                
        except Exception as e:
            print(f"❌ Error generating token: {e}")
            
            # Try alternative approach - check if any non-revoked tokens exist
            print(f"\n🔍 Looking for existing non-revoked tokens...")
            cur.execute("""
            SELECT 
                ath.api_token_bk,
                th.tenant_bk,
                ats.token_type,
                ats.expires_at,
                ats.is_revoked,
                encode(ats.token_hash, 'hex') as stored_hash
            FROM auth.api_token_h ath 
            JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk
            JOIN auth.tenant_h th ON ath.tenant_hk = th.tenant_hk
            WHERE ats.load_end_date IS NULL 
            AND ats.is_revoked = FALSE
            ORDER BY ats.expires_at DESC
            LIMIT 3
            """)
            
            active_tokens = cur.fetchall()
            if active_tokens:
                print(f"✅ Found {len(active_tokens)} non-revoked tokens:")
                for token_bk, tenant_bk, token_type, expires_at, is_revoked, stored_hash in active_tokens:
                    print(f"   Tenant: {tenant_bk}")
                    print(f"   Token BK: {token_bk}")
                    print(f"   Type: {token_type}")
                    print(f"   Expires: {expires_at}")
                    print(f"   Hash: {stored_hash}")
                    
                    # Extract the potential token from the business key
                    # The BK format appears to be {tenant_hk}_TOKEN_{hash}
                    if '_TOKEN_' in token_bk:
                        potential_token = token_bk.split('_TOKEN_')[1]
                        print(f"   🧪 Try this token: {potential_token}")
                    print()
            else:
                print("❌ No non-revoked tokens found")

        conn.close()
        print('\n🏁 Token generation complete!')
        
    except Exception as e:
        print(f'💥 Error: {e}')
        import traceback
        print(traceback.format_exc())

if __name__ == "__main__":
    generate_fresh_api_token() 