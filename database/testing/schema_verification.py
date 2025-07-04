#!/usr/bin/env python3
"""
Schema Verification - OneVault Database
Checks actual vs expected database structure
"""

import psycopg2
import json
import getpass
from datetime import datetime

def main():
    print("🔍 Schema Verification - OneVault Database")
    print("=" * 60)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected")
        
        # Check raw.external_data_s structure
        print("\n🔍 Raw Schema Check...")
        cursor.execute("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_schema = 'raw' AND table_name = 'external_data_s'
        """)
        raw_cols = [row[0] for row in cursor.fetchall()]
        print(f"   Columns: {raw_cols}")
        
        expected = ['data_type', 'raw_data', 'source_system']
        missing = [col for col in expected if col not in raw_cols]
        if missing:
            print(f"   ❌ Missing: {missing}")
        else:
            print("   ✅ Structure OK")
        
        # Check API functions
        print("\n🔍 API Functions Check...")
        cursor.execute("""
            SELECT routine_name FROM information_schema.routines 
            WHERE routine_schema = 'api'
        """)
        api_funcs = [row[0] for row in cursor.fetchall()]
        print(f"   Functions: {api_funcs}")
        
        # Check tenants and tokens
        print("\n🔍 Tenant Analysis...")
        cursor.execute("""
            SELECT tenant_bk, tenant_name 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.load_end_date IS NULL
        """)
        tenants = cursor.fetchall()
        for tenant in tenants:
            print(f"   {tenant[1]}: {tenant[0]}")
        
        print("\n🎯 RECOMMENDATIONS:")
        if missing:
            print("1. Fix raw schema structure")
        if 'track_event' not in api_funcs:
            print("2. Deploy track_event function")
        if len(tenants) > 0 and 'prod' not in str(tenants).lower():
            print("3. Generate ovt_prod_token for production tenant")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main() 