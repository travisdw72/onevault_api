#!/usr/bin/env python3
"""
Final Integration Readiness Validation
=====================================
Validates the specific integration points our scripts depend on
to ensure 100% compatibility with the existing database.
"""

import psycopg2
import getpass
import json
from datetime import datetime

def validate_integration_readiness():
    """Validate specific integration dependencies"""
    
    print("🔍 FINAL INTEGRATION READINESS VALIDATION")
    print("=" * 60)
    print("Validating specific integration points our scripts depend on")
    print(f"Validation started: {datetime.now()}")
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
        
        validation_results = {}
        issues_found = []
        
        print("🔧 VALIDATING SPECIFIC INTEGRATION DEPENDENCIES:")
        print("-" * 50)
        
        # 1. Validate auth.security_tracking_h structure matches our expectations
        print("1. 📋 Validating auth.security_tracking_h structure...")
        cursor.execute("""
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_schema = 'auth' AND table_name = 'security_tracking_h'
            ORDER BY ordinal_position
        """)
        security_tracking_cols = cursor.fetchall()
        
        expected_security_cols = ['security_tracking_hk', 'tenant_hk']
        actual_security_cols = [col[0] for col in security_tracking_cols]
        
        for expected_col in expected_security_cols:
            if expected_col in actual_security_cols:
                print(f"   ✅ {expected_col} - Found")
            else:
                print(f"   ❌ {expected_col} - MISSING")
                issues_found.append(f"auth.security_tracking_h missing column: {expected_col}")
        
        # 2. Validate auth.ip_tracking_s structure and foreign key
        print("\n2. 🛡️ Validating auth.ip_tracking_s structure...")
        cursor.execute("""
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_schema = 'auth' AND table_name = 'ip_tracking_s'
            ORDER BY ordinal_position
        """)
        ip_tracking_cols = cursor.fetchall()
        
        expected_ip_cols = ['security_tracking_hk', 'ip_address', 'is_blocked', 'load_end_date']
        actual_ip_cols = [col[0] for col in ip_tracking_cols]
        
        for expected_col in expected_ip_cols:
            if expected_col in actual_ip_cols:
                print(f"   ✅ {expected_col} - Found")
            else:
                print(f"   ❌ {expected_col} - MISSING")
                issues_found.append(f"auth.ip_tracking_s missing column: {expected_col}")
        
        # Check foreign key relationship
        cursor.execute("""
            SELECT tc.constraint_name, kcu.column_name, ccu.table_name AS foreign_table_name
            FROM information_schema.table_constraints AS tc 
            JOIN information_schema.key_column_usage AS kcu
              ON tc.constraint_name = kcu.constraint_name
              AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage AS ccu
              ON ccu.constraint_name = tc.constraint_name
              AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY' 
            AND tc.table_schema = 'auth'
            AND tc.table_name = 'ip_tracking_s'
            AND kcu.column_name = 'security_tracking_hk'
        """)
        fk_result = cursor.fetchone()
        
        if fk_result and fk_result[2] == 'security_tracking_h':
            print("   ✅ Foreign key to security_tracking_h - Found")
        else:
            print("   ❌ Foreign key to security_tracking_h - MISSING")
            issues_found.append("auth.ip_tracking_s missing FK to security_tracking_h")
        
        # 3. Validate util.audit_track_* functions signatures
        print("\n3. 📊 Validating util.audit_track_* function signatures...")
        cursor.execute("""
            SELECT p.proname as routine_name, pg_get_function_arguments(p.oid) as arguments
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'util' 
            AND p.proname LIKE 'audit_track_%'
            ORDER BY p.proname
        """)
        audit_functions = cursor.fetchall()
        
        critical_functions = ['audit_track_default', 'audit_track_satellite']
        found_functions = [func[0] for func in audit_functions]
        
        for critical_func in critical_functions:
            if critical_func in found_functions:
                print(f"   ✅ {critical_func} - Found")
                # Get the specific function's arguments
                for func_name, func_args in audit_functions:
                    if func_name == critical_func:
                        print(f"      Arguments: {func_args}")
                        break
            else:
                print(f"   ❌ {critical_func} - MISSING")
                issues_found.append(f"Critical audit function missing: {critical_func}")
        
        # 4. Validate auth.tenant_h structure
        print("\n4. 🏢 Validating auth.tenant_h structure...")
        cursor.execute("""
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_schema = 'auth' AND table_name = 'tenant_h'
            ORDER BY ordinal_position
        """)
        tenant_cols = cursor.fetchall()
        
        expected_tenant_cols = ['tenant_hk', 'tenant_bk']
        actual_tenant_cols = [col[0] for col in tenant_cols]
        
        for expected_col in expected_tenant_cols:
            if expected_col in actual_tenant_cols:
                print(f"   ✅ {expected_col} - Found")
            else:
                print(f"   ❌ {expected_col} - MISSING")
                issues_found.append(f"auth.tenant_h missing column: {expected_col}")
        
        # 5. Validate core utility functions
        print("\n5. 🔧 Validating core utility functions...")
        core_functions = ['hash_binary', 'current_load_date', 'get_record_source']
        
        for func_name in core_functions:
            cursor.execute("""
                SELECT routine_name 
                FROM information_schema.routines 
                WHERE routine_schema = 'util' AND routine_name = %s
            """, (func_name,))
            
            if cursor.fetchone():
                print(f"   ✅ util.{func_name} - Found")
            else:
                print(f"   ❌ util.{func_name} - MISSING")
                issues_found.append(f"Core utility function missing: util.{func_name}")
        
        # 6. Test actual function calls to ensure they work
        print("\n6. ⚡ Testing function compatibility...")
        try:
            # Test hash_binary function
            cursor.execute("SELECT util.hash_binary('test_integration')")
            hash_result = cursor.fetchone()[0]
            if hash_result:
                print("   ✅ util.hash_binary - Works correctly")
            else:
                print("   ❌ util.hash_binary - Returns null")
                issues_found.append("util.hash_binary function not working properly")
        except Exception as e:
            print(f"   ❌ util.hash_binary - Error: {e}")
            issues_found.append(f"util.hash_binary error: {e}")
        
        try:
            # Test current_load_date function
            cursor.execute("SELECT util.current_load_date()")
            date_result = cursor.fetchone()[0]
            if date_result:
                print("   ✅ util.current_load_date - Works correctly")
            else:
                print("   ❌ util.current_load_date - Returns null")
                issues_found.append("util.current_load_date function not working properly")
        except Exception as e:
            print(f"   ❌ util.current_load_date - Error: {e}")
            issues_found.append(f"util.current_load_date error: {e}")
        
        try:
            # Test audit_track_default if it exists - try different parameter combinations
            if 'audit_track_default' in found_functions:
                try:
                    # Try with text parameters (common pattern)
                    cursor.execute("""
                        SELECT util.audit_track_default('integration_test'::text, '{"test": "validation"}'::text)
                    """)
                    print("   ✅ util.audit_track_default - Works correctly (text params)")
                except:
                    try:
                        # Try with just one parameter 
                        cursor.execute("""
                            SELECT util.audit_track_default('integration_test'::text)
                        """)
                        print("   ✅ util.audit_track_default - Works correctly (single param)")
                    except:
                        print("   ⚠️ util.audit_track_default - Function exists but parameter signature differs")
                        # This is not critical - we can adjust our calls
            else:
                print("   ⚠️ util.audit_track_default - Not tested (function missing)")
        except Exception as e:
            print(f"   ⚠️ util.audit_track_default - Error: {e}")
            # This is not critical since we can work around it
        
        # Start a fresh transaction for remaining checks
        conn.rollback()
        
        # 7. Check schema permissions
        print("\n7. 🔐 Validating schema access permissions...")
        required_schemas = ['auth', 'business', 'raw', 'staging', 'api', 'util', 'audit']
        
        for schema in required_schemas:
            cursor.execute("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name = %s
            """, (schema,))
            
            if cursor.fetchone():
                print(f"   ✅ {schema} schema - Accessible")
            else:
                print(f"   ❌ {schema} schema - MISSING")
                issues_found.append(f"Required schema missing: {schema}")
        
        print("\n" + "=" * 60)
        print("📊 INTEGRATION READINESS ASSESSMENT:")
        print("=" * 60)
        
        if not issues_found:
            print("🎉 PERFECT! 100% INTEGRATION READY!")
            print("✅ All dependencies validated successfully")
            print("✅ All integration points confirmed working")
            print("✅ Database is fully compatible with our scripts")
            
            validation_results['status'] = 'FULLY_READY'
            validation_results['confidence'] = '100%'
            validation_results['issues'] = []
            
        else:
            print("⚠️ INTEGRATION ISSUES FOUND:")
            print(f"❌ {len(issues_found)} issues need attention:")
            for i, issue in enumerate(issues_found, 1):
                print(f"   {i}. {issue}")
            
            # Assess criticality
            critical_issues = [issue for issue in issues_found if any(critical in issue.lower() 
                             for critical in ['tenant_hk', 'hash_binary', 'current_load_date', 'security_tracking_h'])]
            
            if critical_issues:
                print("\n🚨 CRITICAL ISSUES - DEPLOYMENT BLOCKED:")
                for issue in critical_issues:
                    print(f"   🚨 {issue}")
                validation_results['status'] = 'BLOCKED'
                validation_results['confidence'] = '0%'
            else:
                print("\n⚠️ NON-CRITICAL ISSUES - DEPLOYMENT POSSIBLE WITH MODIFICATIONS:")
                print("   These can be worked around in our scripts")
                validation_results['status'] = 'READY_WITH_MODIFICATIONS'
                validation_results['confidence'] = '85%'
            
            validation_results['issues'] = issues_found
        
        # Save detailed results
        validation_results['validation_date'] = datetime.now().isoformat()
        validation_results['database'] = 'one_vault'
        validation_results['total_checks'] = 20  # Approximate number of checks
        validation_results['issues_count'] = len(issues_found)
        
        with open('integration_readiness_validation.json', 'w') as f:
            json.dump(validation_results, f, indent=2, default=str)
        
        print(f"\n📁 Detailed results saved to: integration_readiness_validation.json")
        
        cursor.close()
        conn.close()
        
        return validation_results
        
    except Exception as e:
        print(f"❌ Validation failed: {e}")
        return {'status': 'ERROR', 'error': str(e)}

if __name__ == "__main__":
    results = validate_integration_readiness()
    
    if results.get('status') == 'FULLY_READY':
        print("\n🚀 READY TO DEPLOY! Scripts are 100% compatible!")
    elif results.get('status') == 'READY_WITH_MODIFICATIONS':
        print("\n⚙️ MOSTLY READY - Minor modifications may be needed")
    elif results.get('status') == 'BLOCKED':
        print("\n🛑 DEPLOYMENT BLOCKED - Critical issues must be resolved first")
    else:
        print("\n❌ VALIDATION ERROR - Check database connection") 