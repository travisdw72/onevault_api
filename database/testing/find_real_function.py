#!/usr/bin/env python3
"""
Find the REAL ai_log_observation function that's causing the error
"""

import psycopg2
import getpass

def main():
    print("🕵️ FINDING THE REAL FUNCTION")
    print("=" * 40)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        # 1. Find ALL functions named ai_log_observation
        print("\n🔍 Finding ALL ai_log_observation functions...")
        cursor.execute("""
            SELECT 
                n.nspname as schema_name,
                p.proname as function_name,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type,
                p.oid as function_oid
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE p.proname = 'ai_log_observation'
            ORDER BY n.nspname, p.proname
        """)
        
        functions = cursor.fetchall()
        print(f"Found {len(functions)} function(s):")
        for schema, name, args, ret_type, oid in functions:
            print(f"   📋 {schema}.{name}({args}) -> {ret_type} [OID: {oid}]")
        
        # 2. Get the EXACT source code that's currently deployed
        if functions:
            for schema, name, args, ret_type, oid in functions:
                print(f"\n📜 Source code for {schema}.{name}:")
                cursor.execute("""
                    SELECT pg_get_functiondef(%s)
                """, (oid,))
                
                source = cursor.fetchone()[0]
                
                # Look for v_entity_hk in the source
                if 'v_entity_hk' in source:
                    print("🐛 FOUND v_entity_hk in source code!")
                    lines = source.split('\n')
                    for i, line in enumerate(lines, 1):
                        if 'v_entity_hk' in line:
                            print(f"   Line {i}: {line.strip()}")
                else:
                    print("✅ No v_entity_hk found in source")
                
                # Check for entity_hk references
                entity_refs = [line for line in source.split('\n') if 'entity_hk' in line]
                print(f"📊 Found {len(entity_refs)} lines with 'entity_hk':")
                for i, line in enumerate(entity_refs[:5]):  # Show first 5
                    print(f"   {i+1}: {line.strip()}")
                if len(entity_refs) > 5:
                    print(f"   ... and {len(entity_refs) - 5} more")
        
        # 3. Check if there's a search path issue
        print("\n🛤️ Checking search path...")
        cursor.execute("SHOW search_path")
        search_path = cursor.fetchone()[0]
        print(f"Current search_path: {search_path}")
        
        # 4. Test calling the function with explicit schema
        print("\n🧪 Testing with explicit schema reference...")
        try:
            test_data = '{"tenantId": "test", "observationType": "test", "severityLevel": "low"}'
            cursor.execute("""
                SELECT api.ai_log_observation(%s::jsonb)
            """, (test_data,))
            result = cursor.fetchone()[0]
            print(f"📊 Explicit api.ai_log_observation result: {result}")
        except Exception as e:
            print(f"❌ Explicit call failed: {e}")
        
        # 5. Check for any views or aliases
        print("\n👁️ Checking for views or aliases...")
        cursor.execute("""
            SELECT schemaname, viewname, definition
            FROM pg_views
            WHERE viewname LIKE '%ai_log%' OR definition LIKE '%ai_log_observation%'
        """)
        
        views = cursor.fetchall()
        if views:
            print("Found related views:")
            for schema, view, definition in views:
                print(f"   📄 {schema}.{view}")
        else:
            print("✅ No related views found")
            
        # 6. Check current user and permissions
        print("\n👤 Checking user context...")
        cursor.execute("SELECT current_user, session_user")
        user_info = cursor.fetchone()
        print(f"Current user: {user_info[0]}, Session user: {user_info[1]}")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Investigation failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 