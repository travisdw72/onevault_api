#!/usr/bin/env python3
"""
Investigate Audit Track Functions
=================================
Deep dive into util.audit_track_* functions to understand their
actual signatures and usage patterns for proper integration.
"""

import psycopg2
import getpass
import json
from datetime import datetime

def investigate_audit_functions():
    """Investigate the actual audit_track function signatures and usage"""
    
    print("🔍 INVESTIGATING UTIL.AUDIT_TRACK_* FUNCTIONS")
    print("=" * 60)
    print("Deep dive into function signatures and usage patterns")
    print(f"Investigation started: {datetime.now()}")
    print()
    
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
        
        investigation_results = {}
        
        print("📋 DISCOVERING ALL AUDIT_TRACK FUNCTIONS:")
        print("-" * 50)
        
        # Get all audit_track functions with full details
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type,
                p.pronargs as num_args,
                obj_description(p.oid) as description
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'util' 
            AND p.proname LIKE 'audit_track_%'
            ORDER BY p.proname
        """)
        
        functions = cursor.fetchall()
        
        if not functions:
            print("❌ No audit_track functions found!")
            return
        
        print(f"Found {len(functions)} audit_track functions:")
        print()
        
        function_details = {}
        
        for func_name, args, return_type, num_args, description in functions:
            print(f"🔧 **{func_name}**")
            print(f"   Parameters: {args if args else '(no parameters)'}")
            print(f"   Returns: {return_type}")
            print(f"   Arg Count: {num_args}")
            if description:
                print(f"   Description: {description}")
            else:
                print("   Description: (none provided)")
            
            function_details[func_name] = {
                'arguments': args,
                'return_type': return_type,
                'num_args': num_args,
                'description': description
            }
            print()
        
        print("🔎 GETTING FUNCTION DEFINITIONS:")
        print("-" * 50)
        
        # Get the actual function definitions for the key functions
        key_functions = ['audit_track_default', 'audit_track_satellite', 'audit_track_hub']
        
        for func_name in key_functions:
            if func_name in function_details:
                print(f"📄 **Function: {func_name}**")
                try:
                    cursor.execute("""
                        SELECT pg_get_functiondef(p.oid) as definition
                        FROM pg_proc p
                        JOIN pg_namespace n ON p.pronamespace = n.oid
                        WHERE n.nspname = 'util' 
                        AND p.proname = %s
                        LIMIT 1
                    """, (func_name,))
                    
                    definition = cursor.fetchone()
                    if definition:
                        def_lines = definition[0].split('\n')
                        print("   Definition (first 20 lines):")
                        for i, line in enumerate(def_lines[:20], 1):
                            print(f"   {i:2d}: {line}")
                        if len(def_lines) > 20:
                            print(f"   ... ({len(def_lines) - 20} more lines)")
                        
                        function_details[func_name]['definition_preview'] = def_lines[:20]
                    else:
                        print("   ❌ Could not retrieve definition")
                        
                except Exception as e:
                    print(f"   ❌ Error getting definition: {e}")
                
                print()
        
        print("🧪 TESTING FUNCTION CALLS:")
        print("-" * 50)
        
        # Test different calling patterns for audit_track_default
        if 'audit_track_default' in function_details:
            print("🔬 Testing audit_track_default with different parameters...")
            
            test_patterns = [
                # Pattern 1: Single text parameter
                ("Single text", "SELECT util.audit_track_default('test_call')"),
                
                # Pattern 2: Two text parameters  
                ("Two text", "SELECT util.audit_track_default('test_event', 'test_details')"),
                
                # Pattern 3: Text + JSONB
                ("Text + JSONB", "SELECT util.audit_track_default('test_event', '{\"key\": \"value\"}'::jsonb)"),
                
                # Pattern 4: Text + Text + additional params
                ("Three params", "SELECT util.audit_track_default('test_event', 'test_table', 'test_details')"),
                
                # Pattern 5: Check if it expects specific audit types
                ("Audit type", "SELECT util.audit_track_default('INSERT', 'test_table', 'test_details')"),
            ]
            
            working_patterns = []
            
            for pattern_name, sql in test_patterns:
                try:
                    cursor.execute(sql)
                    result = cursor.fetchone()
                    print(f"   ✅ {pattern_name}: Works! Result: {result}")
                    working_patterns.append({
                        'pattern': pattern_name,
                        'sql': sql,
                        'result': str(result) if result else 'NULL'
                    })
                    conn.commit()  # Commit successful test
                    
                except Exception as e:
                    print(f"   ❌ {pattern_name}: {str(e)[:100]}...")
                    conn.rollback()  # Rollback failed test
            
            function_details['audit_track_default']['working_patterns'] = working_patterns
        
        # Test audit_track_satellite if it exists
        if 'audit_track_satellite' in function_details:
            print("\n🔬 Testing audit_track_satellite...")
            
            satellite_patterns = [
                ("Basic satellite", "SELECT util.audit_track_satellite('test_table', '\\\\x1234'::bytea, '{\"test\": \"data\"}'::jsonb)"),
                ("Text params", "SELECT util.audit_track_satellite('test_table', 'test_key', 'test_data')"),
            ]
            
            working_satellite_patterns = []
            
            for pattern_name, sql in satellite_patterns:
                try:
                    cursor.execute(sql)
                    result = cursor.fetchone()
                    print(f"   ✅ {pattern_name}: Works! Result: {result}")
                    working_satellite_patterns.append({
                        'pattern': pattern_name,
                        'sql': sql,
                        'result': str(result) if result else 'NULL'
                    })
                    conn.commit()
                    
                except Exception as e:
                    print(f"   ❌ {pattern_name}: {str(e)[:100]}...")
                    conn.rollback()
            
            function_details['audit_track_satellite']['working_patterns'] = working_satellite_patterns
        
        print("\n📊 ANALYSIS AND RECOMMENDATIONS:")
        print("-" * 50)
        
        # Analyze what we found
        recommendations = []
        
        if 'audit_track_default' in function_details:
            working = function_details['audit_track_default'].get('working_patterns', [])
            if working:
                best_pattern = working[0]  # First working pattern
                print(f"✅ audit_track_default: Use pattern '{best_pattern['pattern']}'")
                print(f"   Example: {best_pattern['sql']}")
                recommendations.append({
                    'function': 'audit_track_default',
                    'recommended_pattern': best_pattern['sql'],
                    'description': f"Use {best_pattern['pattern']} pattern"
                })
            else:
                print("⚠️ audit_track_default: No working patterns found - may need investigation")
                recommendations.append({
                    'function': 'audit_track_default',
                    'issue': 'No working patterns found',
                    'action': 'Manual investigation needed'
                })
        
        if 'audit_track_satellite' in function_details:
            working = function_details['audit_track_satellite'].get('working_patterns', [])
            if working:
                best_pattern = working[0]
                print(f"✅ audit_track_satellite: Use pattern '{best_pattern['pattern']}'")
                print(f"   Example: {best_pattern['sql']}")
                recommendations.append({
                    'function': 'audit_track_satellite',
                    'recommended_pattern': best_pattern['sql'],
                    'description': f"Use {best_pattern['pattern']} pattern"
                })
            else:
                print("⚠️ audit_track_satellite: No working patterns found - may need investigation")
        
        # Summary
        investigation_results = {
            'investigation_date': datetime.now().isoformat(),
            'total_functions_found': len(functions),
            'function_details': function_details,
            'recommendations': recommendations,
            'status': 'COMPLETE'
        }
        
        # Save results
        with open('audit_functions_investigation.json', 'w') as f:
            json.dump(investigation_results, f, indent=2, default=str)
        
        print(f"\n📁 Detailed investigation saved to: audit_functions_investigation.json")
        
        cursor.close()
        conn.close()
        
        return investigation_results
        
    except Exception as e:
        print(f"❌ Investigation failed: {e}")
        return {'status': 'ERROR', 'error': str(e)}

if __name__ == "__main__":
    print("🎯 This will help us understand the exact function signatures")
    print("   so we can update our scripts to call them correctly!")
    print()
    
    results = investigate_audit_functions()
    
    if results and results.get('status') == 'COMPLETE':
        recs = results.get('recommendations', [])
        if recs:
            print(f"\n🔧 NEXT STEPS:")
            print("Update our scripts with the correct function call patterns:")
            for i, rec in enumerate(recs, 1):
                if 'recommended_pattern' in rec:
                    print(f"{i}. {rec['function']}: {rec['description']}")
        else:
            print(f"\n⚠️ May need to adjust our audit function usage approach")
    else:
        print(f"\n❌ Investigation incomplete - check the results") 