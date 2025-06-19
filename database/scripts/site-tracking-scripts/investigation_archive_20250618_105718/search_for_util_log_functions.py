#!/usr/bin/env python3
"""
Search for util.log_audit_event and similar functions
====================================================
Quick focused search for the specific auto audit function you remember.
"""

import psycopg2
import getpass
import json
from datetime import datetime

def search_for_log_functions():
    """Search specifically for log_audit_event and similar patterns"""
    
    print("🔍 SEARCHING FOR util.log_audit_event AND SIMILAR FUNCTIONS")
    print("=" * 65)
    
    # Get password securely
    password = getpass.getpass('Enter PostgreSQL password: ')
    
    try:
        # Connect to database
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            database='one_vault',
            user='postgres',
            password=password
        )
        cursor = conn.cursor()
        
        search_results = {}
        
        print("🎯 SEARCHING FOR SPECIFIC FUNCTION PATTERNS:")
        print("-" * 50)
        
        # Search patterns based on what you mentioned
        search_patterns = [
            'log_audit_event',
            'log_audit',
            'audit_log',
            'log_event',
            'create_audit',
            'audit_event',
            'log_activity',
            'audit_activity'
        ]
        
        found_functions = []
        
        for pattern in search_patterns:
            print(f"🔍 Searching for functions like '*{pattern}*'...")
            
            cursor.execute("""
                SELECT 
                    n.nspname as schema_name,
                    p.proname as function_name,
                    pg_get_function_arguments(p.oid) as arguments,
                    pg_get_function_result(p.oid) as return_type,
                    p.pronargs as num_args,
                    obj_description(p.oid) as description
                FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid
                WHERE LOWER(p.proname) LIKE LOWER(%s)
                AND n.nspname IN ('util', 'auth', 'business', 'api', 'audit', 'public')
                ORDER BY n.nspname, p.proname
            """, (f'%{pattern}%',))
            
            results = cursor.fetchall()
            
            if results:
                print(f"   ✅ Found {len(results)} functions matching '{pattern}':")
                for schema, func_name, args, return_type, num_args, description in results:
                    full_name = f"{schema}.{func_name}"
                    print(f"      • {full_name}({args}) → {return_type}")
                    if description:
                        print(f"        Description: {description}")
                    
                    found_functions.append({
                        'pattern': pattern,
                        'schema': schema,
                        'function_name': func_name,
                        'full_name': full_name,
                        'arguments': args,
                        'return_type': return_type,
                        'num_args': num_args,
                        'description': description
                    })
            else:
                print(f"   ❌ No functions found matching '{pattern}'")
            
            print()
        
        print("🧪 TESTING SUSPECTED AUTO AUDIT FUNCTIONS:")
        print("-" * 50)
        
        # Test the most likely candidates
        likely_functions = [
            'util.log_audit_event',
            'util.audit_log', 
            'audit.log_audit_event',
            'util.create_audit_event',
            'util.log_event'
        ]
        
        working_functions = []
        
        for func_name in likely_functions:
            print(f"🔬 Testing {func_name}...")
            
            # Test if function exists first
            schema, function = func_name.split('.')
            cursor.execute("""
                SELECT COUNT(*) 
                FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid
                WHERE n.nspname = %s AND p.proname = %s
            """, (schema, function))
            
            exists = cursor.fetchone()[0] > 0
            
            if exists:
                print(f"   ✅ Function exists! Testing parameter patterns...")
                
                # Test different parameter patterns for audit functions
                test_patterns = [
                    # Simple event logging
                    (f"SELECT {func_name}('site_tracking_test')", "Simple event"),
                    
                    # Event with details
                    (f"SELECT {func_name}('site_tracking_test', 'Testing auto audit function')", "Event + details"),
                    
                    # With tenant (common pattern)
                    (f"SELECT {func_name}('\\\\x1234567890abcdef'::bytea, 'site_tracking_test', 'Testing with tenant')", "Tenant + event + details"),
                    
                    # Table + operation + data (Data Vault pattern)
                    (f"SELECT {func_name}('raw.site_tracking_events', 'INSERT', '{{\"test\": \"data\"}}'::jsonb)", "Table + operation + data"),
                    
                    # Full audit pattern
                    (f"SELECT {func_name}('\\\\x1234567890abcdef'::bytea, 'raw.site_tracking_events', 'INSERT', '{{\"test\": \"data\"}}'::jsonb)", "Full audit pattern"),
                    
                    # Alternative naming
                    (f"SELECT {func_name}('site_tracking', 'page_view', '{{\"url\": \"/test\", \"user_agent\": \"test\"}}'::jsonb)", "Event type + action + data")
                ]
                
                for sql, description in test_patterns:
                    try:
                        cursor.execute(sql)
                        result = cursor.fetchone()
                        print(f"      ✅ {description}: SUCCESS! Result: {result}")
                        
                        working_functions.append({
                            'function': func_name,
                            'pattern': sql,
                            'description': description,
                            'result': str(result) if result else 'NULL'
                        })
                        conn.commit()
                        break  # Found working pattern
                        
                    except Exception as e:
                        conn.rollback()
                        continue
                
                if not any(wf['function'] == func_name for wf in working_functions):
                    print(f"      ❌ No working parameter patterns found")
                    
            else:
                print(f"   ❌ Function does not exist")
            
            print()
        
        print("📋 EXAMINING FUNCTION DEFINITIONS:")
        print("-" * 50)
        
        # Get full definitions of found functions
        for func in found_functions:
            if func['num_args'] > 0:  # Only examine functions that take parameters
                print(f"🔧 **{func['full_name']}**")
                print(f"   Parameters: {func['arguments']}")
                print(f"   Returns: {func['return_type']}")
                
                # Get the function definition
                cursor.execute("""
                    SELECT pg_get_functiondef(p.oid)
                    FROM pg_proc p
                    JOIN pg_namespace n ON p.pronamespace = n.oid
                    WHERE n.nspname = %s AND p.proname = %s
                """, (func['schema'], func['function_name']))
                
                definition = cursor.fetchone()
                if definition:
                    lines = definition[0].split('\n')
                    print(f"   📄 Definition preview:")
                    for i, line in enumerate(lines[:8], 1):
                        clean_line = line.strip()
                        if clean_line:
                            print(f"   {i:2d}: {clean_line}")
                    
                    if len(lines) > 8:
                        print(f"   ... ({len(lines) - 8} more lines)")
                
                print()
        
        # Save results
        search_results = {
            'search_date': datetime.now().isoformat(),
            'found_functions': found_functions,
            'working_functions': working_functions,
            'total_patterns_searched': len(search_patterns),
            'total_functions_found': len(found_functions),
            'working_functions_count': len(working_functions)
        }
        
        with open('util_log_functions_search.json', 'w') as f:
            json.dump(search_results, f, indent=2, default=str)
        
        print("🎯 FINAL RESULTS:")
        print("-" * 30)
        
        if working_functions:
            print(f"🎉 SUCCESS! Found {len(working_functions)} working auto audit functions:")
            for func in working_functions:
                print(f"   ✅ {func['function']}")
                print(f"      Pattern: {func['pattern']}")
                print(f"      Use case: {func['description']}")
                print()
                
            print("🔄 RECOMMENDATION: Update site tracking scripts to use these functions!")
            
        elif found_functions:
            print(f"⚠️  Found {len(found_functions)} potential functions but none tested successfully")
            print("💡 These functions exist but may need different parameters:")
            for func in found_functions:
                if func['num_args'] > 0:
                    print(f"   • {func['full_name']}({func['arguments']})")
            
        else:
            print("❌ No automatic audit functions found matching expected patterns")
            print("✅ Continue with current manual audit approach")
        
        print(f"\n📁 Search results saved to: util_log_functions_search.json")
        
        cursor.close()
        conn.close()
        
        return search_results
        
    except Exception as e:
        print(f"❌ Search failed: {e}")
        return {'status': 'ERROR', 'error': str(e)}

if __name__ == "__main__":
    print("🎯 Searching for the auto audit function you remember!")
    print("   This will specifically look for util.log_audit_event and similar")
    print()
    
    results = search_for_log_functions()
    
    if results and 'working_functions_count' in results:
        count = results['working_functions_count']
        if count > 0:
            print(f"\n🎉 FOUND {count} WORKING AUTO AUDIT FUNCTIONS!")
            print(f"   ✅ You were right - there ARE automatic audit functions!")
            print(f"   🔄 We should update the site tracking scripts to use these instead of manual audit tables")
        else:
            print(f"\n🤔 No working auto audit functions found")
            print(f"   📝 Either they don't exist or use different parameter patterns than tested")
    else:
        print(f"\n❌ Search incomplete") 