#!/usr/bin/env python3
"""
Check Password Indicator Columns
"""

import psycopg2
import getpass

def check_password_indicators():
    try:
        password = getpass.getpass("Enter PostgreSQL password: ")
        conn = psycopg2.connect(
            host='localhost',
            database='one_vault',
            user='postgres',
            password=password
        )
        conn.autocommit = True
        cur = conn.cursor()
        
        print("🔍 Checking password_indicator columns...")
        
        # Check raw.login_attempt_s
        print("\n📋 raw.login_attempt_s.password_indicator:")
        cur.execute("""
            SELECT password_indicator, COUNT(*) 
            FROM raw.login_attempt_s 
            GROUP BY password_indicator 
            ORDER BY COUNT(*) DESC 
            LIMIT 10;
        """)
        results = cur.fetchall()
        for indicator, count in results:
            print(f"  '{indicator}' - {count} records")
        
        # Check raw.login_details_s
        print("\n📋 raw.login_details_s.password_indicator:")
        cur.execute("""
            SELECT password_indicator, COUNT(*) 
            FROM raw.login_details_s 
            GROUP BY password_indicator 
            ORDER BY COUNT(*) DESC 
            LIMIT 10;
        """)
        results = cur.fetchall()
        for indicator, count in results:
            print(f"  '{indicator}' - {count} records")
        
        # Check actual password hashes
        print("\n🔐 auth.user_auth_s.password_hash sample:")
        cur.execute("""
            SELECT 
                LEFT(encode(password_hash, 'hex'), 20) || '...' as hash_sample,
                LENGTH(encode(password_hash, 'hex')) as hex_length,
                LENGTH(password_hash) as binary_length
            FROM auth.user_auth_s 
            WHERE password_hash IS NOT NULL 
            LIMIT 3;
        """)
        results = cur.fetchall()
        for hash_sample, hex_len, bin_len in results:
            print(f"  Hash: {hash_sample} (hex_len: {hex_len}, bin_len: {bin_len})")
        
        cur.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    check_password_indicators() 