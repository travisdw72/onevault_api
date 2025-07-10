#!/usr/bin/env python3
"""
Quick Functions Check for One_Barn_AI Setup
"""

import psycopg2
import getpass

def connect_to_database():
    try:
        password = getpass.getpass("Enter database password: ")
        conn = psycopg2.connect(
            dbname='one_vault_site_testing',
            user='postgres', 
            password=password,
            host='localhost',
            port='5432'
        )
        print("✅ Connected successfully")
        return conn
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return None

def check_functions(conn):
    """Check critical functions for tenant and AI setup"""
    
    # Check auth functions
    print("\n🔧 AUTH FUNCTIONS:")
    cursor = conn.cursor()
    cursor.execute("""
    SELECT p.proname 
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth'
    ORDER BY p.proname
    """)
    
    auth_functions = [row[0] for row in cursor.fetchall()]
    for func in auth_functions:
        print(f"   - {func}")
    
    # Check API functions
    print("\n🔗 API FUNCTIONS:")
    cursor.execute("""
    SELECT p.proname 
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'api'
    ORDER BY p.proname
    """)
    
    api_functions = [row[0] for row in cursor.fetchall()]
    for func in api_functions:
        print(f"   - {func}")
    
    # Check critical functions
    critical_functions = [
        'register_tenant',
        'create_tenant', 
        'auth_login',
        'ai_create_session'
    ]
    
    print(f"\n🎯 CRITICAL FUNCTIONS CHECK:")
    all_functions = auth_functions + api_functions
    for func in critical_functions:
        found = any(func in f for f in all_functions)
        status = "✅ FOUND" if found else "❌ MISSING"
        matches = [f for f in all_functions if func in f]
        print(f"   - {func}: {status}")
        if matches:
            print(f"     Matches: {matches}")
    
    cursor.close()

def main():
    print("🔧 FUNCTION CHECK FOR ONE_BARN_AI SETUP")
    print("=" * 40)
    
    conn = connect_to_database()
    if not conn:
        return
    
    try:
        check_functions(conn)
    finally:
        conn.close()

if __name__ == "__main__":
    main() 