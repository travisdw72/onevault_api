#!/usr/bin/env python3
"""
Check what audit functions exist in the database
"""

import psycopg2
import getpass

def main():
    print("🔍 CHECKING AUDIT FUNCTIONS")
    print("=" * 40)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        
        # Check all functions in audit schema
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'audit'
            ORDER BY p.proname
        """)
        
        functions = cursor.fetchall()
        
        if functions:
            print("📋 Found audit functions:")
            for func_name, args, return_type in functions:
                print(f"   • {func_name}({args}) → {return_type}")
        else:
            print("❌ No audit functions found!")
            
        # Check if we need to comment out the audit call
        print(f"\n🔧 SOLUTION OPTIONS:")
        print("   A) Comment out audit call (quick fix)")
        print("   B) Create missing audit function") 
        print("   C) Use existing audit function with correct signature")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main() 