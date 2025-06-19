#!/usr/bin/env python3
"""
Auto Audit Functions Investigation
=================================
Investigate if there are automatic audit functions like util.log_audit_event
that handle auditing centrally without requiring triggers on every table.
"""

import psycopg2
import getpass
import json
from datetime import datetime

def investigate_auto_audit_functions():
    """Investigate automatic audit functions and their capabilities"""
    
    print("🔍 INVESTIGATING AUTOMATIC AUDIT FUNCTIONS")
    print("=" * 60)
    print("Looking for centralized audit functions that work without table triggers")
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
        
        print("🔧 DISCOVERING ALL AUDIT-RELATED FUNCTIONS:")
        print("-" * 50)
        
        # Get all audit-related functions
        cursor.execute("""
            SELECT 
                n.nspname as schema_name,
                p.proname as function_name,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type,
                p.pronargs as num_args,
                obj_description(p.oid) as description,
                pg_get_functiondef(p.oid) as function_definition
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE (p.proname LIKE '%audit%' OR p.proname LIKE '%log%')
            AND n.nspname IN ('util', 'auth', 'business', 'api', 'audit')
            AND p.proname NOT LIKE 'audit_track_%'  -- Exclude trigger functions
            ORDER BY n.nspname, p.proname
        """)
        
        audit_functions = cursor.fetchall()
        
        print(f"Found {len(audit_functions)} potential audit functions:")
        print()
        
        auto_audit_functions = []
        
        for schema, func_name, args, return_type, num_args, description, definition in audit_functions:
            print(f"🔧 **{schema}.{func_name}**")
            print(f"   Parameters: {args if args else '(no parameters)'}")
            print(f"   Returns: {return_type}")
            print(f"   Arg Count: {num_args}")
            if description:
                print(f"   Description: {description}")
            
            # Check if this looks like an auto audit function
            if any(keyword in func_name.lower() for keyword in ['log', 'audit', 'track']) and num_args > 0:
                auto_audit_functions.append({
                    'schema': schema,
                    'name': func_name,
                    'full_name': f"{schema}.{func_name}",
                    'arguments': args,
                    'return_type': return_type,
                    'num_args': num_args,
                    'description': description,
                    'definition': definition
                })
                print(f"   🎯 POTENTIAL AUTO AUDIT FUNCTION!")
            
            print()
        
        investigation_results['potential_auto_audit_functions'] = auto_audit_functions
        
        print("🧪 TESTING AUTO AUDIT FUNCTIONS:")
        print("-" * 50)
        
        # Test key functions that might be auto audit functions
        test_functions = [
            'util.log_audit_event',
            'audit.log_audit_event', 
            'util.audit_log',
            'auth.log_audit_event',
            'business.log_audit_event'
        ]
        
        working_auto_functions = []
        
        for func_name in test_functions:
            print(f"🔬 Testing {func_name}...")
            try:
                # Try different parameter patterns
                test_patterns = [
                    # Pattern 1: Simple event logging
                    f"SELECT {func_name}('test_event')",
                    
                    # Pattern 2: Event with details
                    f"SELECT {func_name}('test_event', 'test_details')",
                    
                    # Pattern 3: Event with tenant
                    f"SELECT {func_name}('\\\\x1234'::bytea, 'test_event', 'test_details')",
                    
                    # Pattern 4: Full audit pattern
                    f"SELECT {func_name}('test_table', 'INSERT', '{\"test\": \"data\"}'::jsonb)",
                    
                    # Pattern 5: With tenant and table
                    f"SELECT {func_name}('\\\\x1234'::bytea, 'test_table', 'INSERT', '{\"test\": \"data\"}'::jsonb)"
                ]
                
                for i, sql in enumerate(test_patterns, 1):
                    try:
                        cursor.execute(sql)
                        result = cursor.fetchone()
                        print(f"   ✅ Pattern {i}: Works! Result: {result}")
                        
                        working_auto_functions.append({
                            'function': func_name,
                            'working_pattern': sql,
                            'result': str(result) if result else 'NULL'
                        })
                        conn.commit()
                        break  # Found working pattern, move to next function
                        
                    except Exception as e:
                        conn.rollback()
                        continue  # Try next pattern
                
                if not any(wf['function'] == func_name for wf in working_auto_functions):
                    print(f"   ❌ Function not found or no working patterns")
                    
            except Exception as e:
                print(f"   ❌ Function not accessible: {str(e)[:50]}...")
                conn.rollback()
        
        print()
        
        # Deep dive into the functions we found
        print("📋 ANALYZING FOUND AUTO AUDIT FUNCTIONS:")
        print("-" * 50)
        
        for func_info in auto_audit_functions:
            func_name = func_info['full_name']
            print(f"🔧 **{func_name}**")
            
            # Analyze the function definition for capabilities
            definition = func_info['definition']
            
            capabilities = []
            
            if 'tenant_hk' in definition.lower():
                capabilities.append("Tenant-aware")
            if 'insert into audit' in definition.lower():
                capabilities.append("Creates audit records")
            if 'jsonb' in definition.lower():
                capabilities.append("Supports JSON data")
            if 'current_timestamp' in definition.lower():
                capabilities.append("Timestamps events")
            if 'session_user' in definition.lower():
                capabilities.append("Tracks user")
            if 'data vault' in definition.lower() or 'hash_binary' in definition.lower():
                capabilities.append("Data Vault 2.0 compatible")
            
            if capabilities:
                print(f"   🎯 Capabilities: {', '.join(capabilities)}")
            
            # Show key parts of the function
            lines = definition.split('\n')
            print(f"   📄 Function preview (first 10 lines):")
            for i, line in enumerate(lines[:10], 1):
                clean_line = line.strip()
                if clean_line:
                    print(f"   {i:2d}: {clean_line}")
            
            if len(lines) > 10:
                print(f"   ... ({len(lines) - 10} more lines)")
            
            print()
        
        print("🔄 CHECKING FOR TABLE-AGNOSTIC AUDIT SYSTEMS:")
        print("-" * 50)
        
        # Check for audit systems that work across all tables
        cursor.execute("""
            SELECT 
                t.schemaname,
                t.tablename,
                'audit.' || t.tablename as potential_audit_table,
                EXISTS(
                    SELECT 1 FROM pg_tables pt 
                    WHERE pt.schemaname = 'audit' 
                    AND pt.tablename = t.tablename
                ) as has_audit_table
            FROM pg_tables t
            WHERE t.schemaname IN ('auth', 'business', 'raw', 'staging')
            AND (t.tablename LIKE '%_h' OR t.tablename LIKE '%_s' OR t.tablename LIKE '%_l')
            ORDER BY t.schemaname, t.tablename
            LIMIT 10
        """)
        
        table_audit_check = cursor.fetchall()
        
        print("Sample table audit coverage:")
        for schema, table, audit_table, has_audit in table_audit_check:
            status = "✅ HAS AUDIT TABLE" if has_audit else "❌ NO AUDIT TABLE"
            print(f"   {schema}.{table} → {audit_table}: {status}")
        
        print()
        
        print("🎯 TESTING AUTOMATIC AUDIT SCENARIOS:")
        print("-" * 50)
        
        # Test if we can audit any table automatically
        test_scenarios = [
            {
                'name': 'Manual audit logging',
                'description': 'Test if we can log audit events for any table without triggers',
                'tests': working_auto_functions[:3] if working_auto_functions else []
            }
        ]
        
        scenario_results = []
        
        for scenario in test_scenarios:
            print(f"📊 {scenario['name']}")
            print(f"   {scenario['description']}")
            
            if scenario['tests']:
                for test in scenario['tests']:
                    print(f"   ✅ Working: {test['function']}")
                    scenario_results.append({
                        'scenario': scenario['name'],
                        'status': 'WORKING',
                        'function': test['function']
                    })
            else:
                print(f"   ❌ No working functions found")
                scenario_results.append({
                    'scenario': scenario['name'],
                    'status': 'NOT_WORKING',
                    'function': None
                })
        
        print()
        
        print("📊 SUMMARY AND RECOMMENDATIONS:")
        print("-" * 50)
        
        summary = {
            'total_audit_functions_found': len(audit_functions),
            'potential_auto_audit_functions': len(auto_audit_functions),
            'working_auto_functions': len(working_auto_functions),
            'recommendation': 'UNKNOWN'
        }
        
        if working_auto_functions:
            print(f"✅ Found {len(working_auto_functions)} working auto audit functions!")
            print(f"📋 Recommended functions:")
            for func in working_auto_functions:
                print(f"   • {func['function']} - Use pattern: {func['working_pattern']}")
            summary['recommendation'] = 'USE_AUTO_FUNCTIONS'
            
        elif auto_audit_functions:
            print(f"⚠️  Found {len(auto_audit_functions)} potential auto audit functions but none tested successfully")
            print(f"💡 May need parameter adjustment or different approach")
            summary['recommendation'] = 'INVESTIGATE_FURTHER'
            
        else:
            print(f"❌ No automatic audit functions found")
            print(f"✅ Current manual approach (triggers + audit tables) is correct")
            summary['recommendation'] = 'MANUAL_APPROACH_CORRECT'
        
        # Save detailed results
        investigation_results.update({
            'investigation_date': datetime.now().isoformat(),
            'summary': summary,
            'working_auto_functions': working_auto_functions,
            'scenario_results': scenario_results,
            'all_audit_functions': [
                {
                    'schema': schema, 'name': func_name, 'args': args, 
                    'return_type': return_type, 'description': description
                }
                for schema, func_name, args, return_type, _, description, _ in audit_functions
            ]
        })
        
        with open('auto_audit_functions_investigation.json', 'w') as f:
            json.dump(investigation_results, f, indent=2, default=str)
        
        print(f"\n📁 Detailed investigation saved to: auto_audit_functions_investigation.json")
        
        cursor.close()
        conn.close()
        
        return investigation_results
        
    except Exception as e:
        print(f"❌ Investigation failed: {e}")
        return {'status': 'ERROR', 'error': str(e)}

if __name__ == "__main__":
    print("🎯 This will help us discover if there are automatic audit functions")
    print("   that work without requiring triggers on every table!")
    print()
    
    results = investigate_auto_audit_functions()
    
    if results and 'summary' in results:
        summary = results['summary']
        recommendation = summary.get('recommendation', 'UNKNOWN')
        
        print(f"\n🎯 FINAL RECOMMENDATION:")
        
        if recommendation == 'USE_AUTO_FUNCTIONS':
            print(f"   🎉 Use the discovered auto audit functions!")
            print(f"   📝 Update site tracking scripts to use these instead of manual audit tables")
            
        elif recommendation == 'INVESTIGATE_FURTHER':
            print(f"   🔍 Further investigation needed")
            print(f"   💡 Potential auto functions found but need parameter tuning")
            
        elif recommendation == 'MANUAL_APPROACH_CORRECT':
            print(f"   ✅ Current manual approach is the right way")
            print(f"   🔧 Continue with audit tables + triggers approach")
            
        else:
            print(f"   ❓ Unable to determine best approach")
    else:
        print(f"\n❌ Investigation incomplete - check the results") 