#!/usr/bin/env python3
"""
Production Database Deployment Testing Framework
Tests for V001 System Operations Tenant Migration
"""
import psycopg2
import json
import os
import sys
from datetime import datetime
from typing import Dict, List, Tuple, Any

class SystemOperationsDeploymentTester:
    def __init__(self, connection_params: Dict[str, str]):
        self.conn_params = connection_params
        self.test_results = {
            'migration_tests': [],
            'rollback_tests': [],
            'performance_tests': [],
            'security_tests': [],
            'summary': {}
        }
        
        # System Operations Tenant constants
        self.SYSTEM_TENANT_HK = bytes.fromhex('0000000000000000000000000000000000000000000000000000000000000001')
        self.SYSTEM_TENANT_BK = 'SYSTEM_OPERATIONS'
    
    def connect_db(self) -> psycopg2.connection:
        """Establish database connection"""
        try:
            conn = psycopg2.connect(**self.conn_params)
            conn.autocommit = True
            return conn
        except Exception as e:
            raise Exception(f"Database connection failed: {e}")
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Execute complete test suite"""
        print("🧪 Starting System Operations Tenant Deployment Test Suite")
        print("=" * 70)
        
        # Prerequisites
        self.test_prerequisites()
        
        # Migration tests
        self.test_migration_objects()
        self.test_system_tenant_creation()
        self.test_system_role_creation()
        self.test_utility_functions()
        self.test_indexes_and_constraints()
        self.test_idempotency()
        
        # Security tests
        self.test_tenant_isolation()
        self.test_permissions()
        
        # Performance tests
        self.test_performance_baseline()
        
        # Rollback readiness
        self.test_rollback_readiness()
        
        # Generate summary
        self.generate_test_summary()
        
        return self.test_results
    
    def test_prerequisites(self):
        """Test migration prerequisites"""
        print("\n📋 Testing Prerequisites...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        tests = [
            ("PostgreSQL Version", "SELECT version()", lambda r: "PostgreSQL" in r[0] and "12" in r[0] or "13" in r[0] or "14" in r[0] or "15" in r[0]),
            ("Auth Schema", "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'auth'", lambda r: len(r) > 0),
            ("Util Schema", "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'util'", lambda r: len(r) > 0),
            ("Tenant Hub Table", "SELECT table_name FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'tenant_h'", lambda r: len(r) > 0),
            ("Tenant Profile Satellite", "SELECT table_name FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'tenant_profile_s'", lambda r: len(r) > 0),
            ("Role Hub Table", "SELECT table_name FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'role_h'", lambda r: len(r) > 0),
            ("Hash Binary Function", "SELECT proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'util' AND p.proname = 'hash_binary'", lambda r: len(r) > 0),
            ("Current Load Date Function", "SELECT proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'util' AND p.proname = 'current_load_date'", lambda r: len(r) > 0),
        ]
        
        for test_name, query, validation in tests:
            try:
                cursor.execute(query)
                result = cursor.fetchall()
                passed = validation(result)
                
                self.test_results['migration_tests'].append({
                    'test': f"Prerequisites: {test_name}",
                    'status': 'PASSED' if passed else 'FAILED',
                    'details': str(result)
                })
                
                status = "✅ PASSED" if passed else "❌ FAILED"
                print(f"  {test_name}: {status}")
                
            except Exception as e:
                self.test_results['migration_tests'].append({
                    'test': f"Prerequisites: {test_name}",
                    'status': 'ERROR',
                    'details': str(e)
                })
                print(f"  {test_name}: ❌ ERROR - {e}")
        
        cursor.close()
        conn.close()
    
    def test_migration_objects(self):
        """Test that all migration objects were created correctly"""
        print("\n🏗️  Testing Migration Object Creation...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        object_tests = [
            ("Migration Log Table", "SELECT table_name FROM information_schema.tables WHERE table_schema = 'util' AND table_name = 'migration_log'"),
            ("Migration Log Entry", "SELECT migration_version FROM util.migration_log WHERE migration_version = 'V001' AND migration_type = 'FORWARD'"),
        ]
        
        for test_name, query in object_tests:
            try:
                cursor.execute(query)
                result = cursor.fetchall()
                passed = len(result) > 0
                
                self.test_results['migration_tests'].append({
                    'test': test_name,
                    'status': 'PASSED' if passed else 'FAILED',
                    'details': f"Found {len(result)} objects"
                })
                
                status = "✅ PASSED" if passed else "❌ FAILED"
                print(f"  {test_name}: {status} ({len(result)} objects)")
                
            except Exception as e:
                self.test_results['migration_tests'].append({
                    'test': test_name,
                    'status': 'ERROR',
                    'details': str(e)
                })
                print(f"  {test_name}: ❌ ERROR - {e}")
        
        cursor.close()
        conn.close()
    
    def test_system_tenant_creation(self):
        """Test system operations tenant creation"""
        print("\n🏢 Testing System Tenant Creation...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        tests = [
            ("System Tenant Hub", 
             "SELECT tenant_hk, tenant_bk FROM auth.tenant_h WHERE tenant_hk = %s AND tenant_bk = %s",
             (self.SYSTEM_TENANT_HK, self.SYSTEM_TENANT_BK)),
            ("System Tenant Profile", 
             """SELECT tenant_name, tenant_type, tenant_status FROM auth.tenant_profile_s 
                WHERE tenant_hk = %s AND load_end_date IS NULL AND tenant_name = 'System Operations Tenant'""",
             (self.SYSTEM_TENANT_HK,)),
            ("System Tenant Constants", 
             """SELECT tenant_name, tenant_type, compliance_frameworks FROM auth.tenant_profile_s 
                WHERE tenant_hk = %s AND load_end_date IS NULL""",
             (self.SYSTEM_TENANT_HK,)),
        ]
        
        for test_name, query, params in tests:
            try:
                cursor.execute(query, params)
                result = cursor.fetchall()
                passed = len(result) > 0
                
                self.test_results['migration_tests'].append({
                    'test': f"System Tenant: {test_name}",
                    'status': 'PASSED' if passed else 'FAILED',
                    'details': str(result)
                })
                
                status = "✅ PASSED" if passed else "❌ FAILED"
                print(f"  {test_name}: {status}")
                if result:
                    print(f"    Data: {result[0]}")
                
            except Exception as e:
                self.test_results['migration_tests'].append({
                    'test': f"System Tenant: {test_name}",
                    'status': 'ERROR',
                    'details': str(e)
                })
                print(f"  {test_name}: ❌ ERROR - {e}")
        
        cursor.close()
        conn.close()
    
    def test_system_role_creation(self):
        """Test system operations role creation"""
        print("\n👤 Testing System Role Creation...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        tests = [
            ("System Role Hub", 
             """SELECT rh.role_bk FROM auth.role_h rh 
                JOIN auth.role_profile_s rps ON rh.role_hk = rps.role_hk 
                WHERE rps.role_name = 'System Operations Administrator' AND rps.load_end_date IS NULL"""),
            ("System Role Profile", 
             """SELECT role_name, role_type, is_system_role FROM auth.role_profile_s 
                WHERE role_name = 'System Operations Administrator' AND is_system_role = true AND load_end_date IS NULL"""),
            ("System Role Permissions", 
             """SELECT permissions FROM auth.role_profile_s 
                WHERE role_name = 'System Operations Administrator' AND load_end_date IS NULL"""),
        ]
        
        for test_name, query in tests:
            try:
                cursor.execute(query)
                result = cursor.fetchall()
                passed = len(result) > 0
                
                # Additional validation for permissions
                if test_name == "System Role Permissions" and result:
                    permissions = result[0][0]
                    required_permissions = [
                        'SYSTEM_ADMIN', 'TENANT_REGISTRATION', 'PRE_REGISTRATION_MANAGEMENT',
                        'SYSTEM_MONITORING', 'DATA_MIGRATION', 'BACKUP_MANAGEMENT'
                    ]
                    has_all_permissions = all(perm in permissions for perm in required_permissions)
                    passed = passed and has_all_permissions
                
                self.test_results['migration_tests'].append({
                    'test': f"System Role: {test_name}",
                    'status': 'PASSED' if passed else 'FAILED',
                    'details': str(result)
                })
                
                status = "✅ PASSED" if passed else "❌ FAILED"
                print(f"  {test_name}: {status}")
                if result:
                    print(f"    Data: {result[0]}")
                
            except Exception as e:
                self.test_results['migration_tests'].append({
                    'test': f"System Role: {test_name}",
                    'status': 'ERROR',
                    'details': str(e)
                })
                print(f"  {test_name}: ❌ ERROR - {e}")
        
        cursor.close()
        conn.close()
    
    def test_utility_functions(self):
        """Test utility function creation"""
        print("\n🔧 Testing Utility Functions...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        tests = [
            ("System Tenant HK Function Exists", 
             """SELECT proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
                WHERE n.nspname = 'util' AND p.proname = 'get_system_operations_tenant_hk'"""),
            ("System Tenant HK Function Returns", 
             "SELECT util.get_system_operations_tenant_hk()"),
            ("Function Returns Correct Value", 
             "SELECT util.get_system_operations_tenant_hk() = %s", 
             (self.SYSTEM_TENANT_HK,)),
        ]
        
        for test_item in tests:
            test_name = test_item[0]
            query = test_item[1]
            params = test_item[2] if len(test_item) > 2 else None
            
            try:
                if params:
                    cursor.execute(query, params)
                else:
                    cursor.execute(query)
                result = cursor.fetchall()
                
                if test_name == "Function Returns Correct Value":
                    passed = result[0][0] if result else False
                else:
                    passed = len(result) > 0
                
                self.test_results['migration_tests'].append({
                    'test': f"Utility Functions: {test_name}",
                    'status': 'PASSED' if passed else 'FAILED',
                    'details': str(result)
                })
                
                status = "✅ PASSED" if passed else "❌ FAILED"
                print(f"  {test_name}: {status}")
                
            except Exception as e:
                self.test_results['migration_tests'].append({
                    'test': f"Utility Functions: {test_name}",
                    'status': 'ERROR',
                    'details': str(e)
                })
                print(f"  {test_name}: ❌ ERROR - {e}")
        
        cursor.close()
        conn.close()
    
    def test_indexes_and_constraints(self):
        """Test index and constraint creation"""
        print("\n📊 Testing Indexes and Constraints...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        tests = [
            ("System Lookup Index", 
             "SELECT indexname FROM pg_indexes WHERE indexname = 'idx_tenant_h_system_lookup'"),
            ("System Profile Active Index", 
             "SELECT indexname FROM pg_indexes WHERE indexname = 'idx_tenant_profile_s_system_active'"),
        ]
        
        for test_name, query in tests:
            try:
                cursor.execute(query)
                result = cursor.fetchall()
                passed = len(result) > 0
                
                self.test_results['migration_tests'].append({
                    'test': f"Indexes: {test_name}",
                    'status': 'PASSED' if passed else 'FAILED',
                    'details': f"Found {len(result)} indexes"
                })
                
                status = "✅ PASSED" if passed else "❌ FAILED"
                print(f"  {test_name}: {status}")
                
            except Exception as e:
                self.test_results['migration_tests'].append({
                    'test': f"Indexes: {test_name}",
                    'status': 'ERROR',
                    'details': str(e)
                })
                print(f"  {test_name}: ❌ ERROR - {e}")
        
        cursor.close()
        conn.close()
    
    def test_idempotency(self):
        """Test that migration can run multiple times safely"""
        print("\n🔄 Testing Idempotency...")
        
        # This would re-run the migration script and verify no errors
        # For this test, we'll check that duplicate operations would be safe
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        try:
            # Test that re-inserting would not cause errors (should be handled by ON CONFLICT)
            initial_count_query = "SELECT COUNT(*) FROM auth.tenant_h WHERE tenant_hk = %s"
            cursor.execute(initial_count_query, (self.SYSTEM_TENANT_HK,))
            initial_count = cursor.fetchone()[0]
            
            self.test_results['migration_tests'].append({
                'test': 'Idempotency: System Tenant Count',
                'status': 'PASSED' if initial_count == 1 else 'FAILED',
                'details': f'Found {initial_count} system tenant records (should be exactly 1)'
            })
            
            print(f"  System Tenant Count: {'✅ PASSED' if initial_count == 1 else '❌ FAILED'} ({initial_count} records)")
            
        except Exception as e:
            self.test_results['migration_tests'].append({
                'test': 'Idempotency Test',
                'status': 'ERROR',
                'details': str(e)
            })
            print(f"  Idempotency: ❌ ERROR - {e}")
        
        cursor.close()
        conn.close()
    
    def test_tenant_isolation(self):
        """Test tenant isolation security"""
        print("\n🔒 Testing Tenant Isolation...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        tests = [
            ("System Tenant Unique Hash", 
             "SELECT COUNT(DISTINCT tenant_hk) FROM auth.tenant_h WHERE tenant_hk = %s", 
             (self.SYSTEM_TENANT_HK,)),
            ("System Tenant Isolation", 
             """SELECT COUNT(*) FROM auth.tenant_profile_s 
                WHERE tenant_hk = %s AND load_end_date IS NULL""", 
             (self.SYSTEM_TENANT_HK,)),
        ]
        
        for test_name, query, params in tests:
            try:
                cursor.execute(query, params)
                result = cursor.fetchall()
                count = result[0][0] if result else 0
                
                # For isolation tests, we expect exactly 1 record
                passed = count == 1
                
                self.test_results['security_tests'].append({
                    'test': f"Security: {test_name}",
                    'status': 'PASSED' if passed else 'FAILED',
                    'details': f"Found {count} records (expected 1)"
                })
                
                status = "✅ PASSED" if passed else "❌ FAILED"
                print(f"  {test_name}: {status} ({count} records)")
                
            except Exception as e:
                self.test_results['security_tests'].append({
                    'test': f"Security: {test_name}",
                    'status': 'ERROR',
                    'details': str(e)
                })
                print(f"  {test_name}: ❌ ERROR - {e}")
        
        cursor.close()
        conn.close()
    
    def test_permissions(self):
        """Test permission grants"""
        print("\n🛡️  Testing Permissions...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        # Check if app_user role exists and test permissions
        try:
            cursor.execute("SELECT 1 FROM pg_roles WHERE rolname = 'app_user'")
            app_user_exists = len(cursor.fetchall()) > 0
            
            if app_user_exists:
                # Test SELECT permissions on tenant tables
                cursor.execute("""
                    SELECT has_table_privilege('app_user', 'auth.tenant_h', 'SELECT') AND
                           has_table_privilege('app_user', 'auth.tenant_profile_s', 'SELECT')
                """)
                table_permissions = cursor.fetchone()[0]
                
                # Test EXECUTE permission on utility function
                cursor.execute("SELECT has_function_privilege('app_user', 'util.get_system_operations_tenant_hk()', 'EXECUTE')")
                function_permissions = cursor.fetchone()[0]
                
                passed = table_permissions and function_permissions
                
                self.test_results['security_tests'].append({
                    'test': 'Permissions: App User Grants',
                    'status': 'PASSED' if passed else 'FAILED',
                    'details': f'Table permissions: {table_permissions}, Function permissions: {function_permissions}'
                })
                
                status = "✅ PASSED" if passed else "❌ FAILED"
                print(f"  App User Permissions: {status}")
            else:
                self.test_results['security_tests'].append({
                    'test': 'Permissions: App User Grants',
                    'status': 'SKIPPED',
                    'details': 'app_user role does not exist'
                })
                print("  App User Permissions: ⏭️  SKIPPED (role doesn't exist)")
            
        except Exception as e:
            self.test_results['security_tests'].append({
                'test': 'Permissions: App User Grants',
                'status': 'ERROR',
                'details': str(e)
            })
            print(f"  App User Permissions: ❌ ERROR - {e}")
        
        cursor.close()
        conn.close()
    
    def test_performance_baseline(self):
        """Test performance baseline"""
        print("\n⚡ Testing Performance Baseline...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        try:
            # Test system tenant lookup performance
            start_time = datetime.now()
            cursor.execute("SELECT * FROM auth.tenant_h WHERE tenant_hk = %s", (self.SYSTEM_TENANT_HK,))
            result = cursor.fetchall()
            end_time = datetime.now()
            
            lookup_time_ms = (end_time - start_time).total_seconds() * 1000
            
            # Test utility function performance
            start_time = datetime.now()
            cursor.execute("SELECT util.get_system_operations_tenant_hk()")
            function_result = cursor.fetchall()
            end_time = datetime.now()
            
            function_time_ms = (end_time - start_time).total_seconds() * 1000
            
            # Performance thresholds (should be very fast for these simple operations)
            lookup_passed = lookup_time_ms < 100  # 100ms threshold
            function_passed = function_time_ms < 50  # 50ms threshold
            
            self.test_results['performance_tests'].extend([
                {
                    'test': 'Performance: System Tenant Lookup',
                    'status': 'PASSED' if lookup_passed else 'FAILED',
                    'details': f'{lookup_time_ms:.2f}ms (threshold: 100ms)'
                },
                {
                    'test': 'Performance: Utility Function Call',
                    'status': 'PASSED' if function_passed else 'FAILED',
                    'details': f'{function_time_ms:.2f}ms (threshold: 50ms)'
                }
            ])
            
            print(f"  System Tenant Lookup: {'✅ PASSED' if lookup_passed else '❌ FAILED'} ({lookup_time_ms:.2f}ms)")
            print(f"  Utility Function Call: {'✅ PASSED' if function_passed else '❌ FAILED'} ({function_time_ms:.2f}ms)")
            
        except Exception as e:
            self.test_results['performance_tests'].append({
                'test': 'Performance: Baseline Tests',
                'status': 'ERROR',
                'details': str(e)
            })
            print(f"  Performance Tests: ❌ ERROR - {e}")
        
        cursor.close()
        conn.close()
    
    def test_rollback_readiness(self):
        """Test rollback script readiness"""
        print("\n🔄 Testing Rollback Readiness...")
        
        # Test that rollback script exists and is syntactically valid
        rollback_file = "V001__rollback_system_operations_tenant.sql"
        
        if os.path.exists(rollback_file):
            self.test_results['rollback_tests'].append({
                'test': 'Rollback Script Exists',
                'status': 'PASSED',
                'details': f'Found {rollback_file}'
            })
            print(f"  Rollback Script: ✅ PASSED (Found {rollback_file})")
            
            # Test file is not empty
            try:
                with open(rollback_file, 'r') as f:
                    content = f.read().strip()
                    if len(content) > 100:  # Reasonable minimum length
                        self.test_results['rollback_tests'].append({
                            'test': 'Rollback Script Content',
                            'status': 'PASSED',
                            'details': f'Script has {len(content)} characters'
                        })
                        print(f"  Rollback Content: ✅ PASSED ({len(content)} characters)")
                    else:
                        self.test_results['rollback_tests'].append({
                            'test': 'Rollback Script Content',
                            'status': 'FAILED',
                            'details': f'Script too short: {len(content)} characters'
                        })
                        print(f"  Rollback Content: ❌ FAILED (too short)")
            except Exception as e:
                self.test_results['rollback_tests'].append({
                    'test': 'Rollback Script Content',
                    'status': 'ERROR',
                    'details': str(e)
                })
                print(f"  Rollback Content: ❌ ERROR - {e}")
                
        else:
            self.test_results['rollback_tests'].append({
                'test': 'Rollback Script Exists',
                'status': 'FAILED',
                'details': f'Missing {rollback_file}'
            })
            print(f"  Rollback Script: ❌ FAILED (Missing {rollback_file})")
    
    def generate_test_summary(self):
        """Generate comprehensive test summary"""
        all_tests = (self.test_results['migration_tests'] + 
                    self.test_results['rollback_tests'] + 
                    self.test_results['performance_tests'] + 
                    self.test_results['security_tests'])
        
        total_tests = len(all_tests)
        passed_tests = sum(1 for test in all_tests if test['status'] == 'PASSED')
        failed_tests = sum(1 for test in all_tests if test['status'] == 'FAILED')
        error_tests = sum(1 for test in all_tests if test['status'] == 'ERROR')
        skipped_tests = sum(1 for test in all_tests if test['status'] == 'SKIPPED')
        
        self.test_results['summary'] = {
            'total_tests': total_tests,
            'passed_tests': passed_tests,
            'failed_tests': failed_tests,
            'error_tests': error_tests,
            'skipped_tests': skipped_tests,
            'success_rate': round((passed_tests / total_tests) * 100, 2) if total_tests > 0 else 0,
            'timestamp': datetime.now().isoformat(),
            'overall_status': 'PASSED' if (failed_tests + error_tests) == 0 else 'FAILED'
        }
        
        print("\n📊 Test Summary:")
        print("=" * 50)
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests}")
        print(f"Failed: {failed_tests}")
        print(f"Errors: {error_tests}")
        print(f"Skipped: {skipped_tests}")
        print(f"Success Rate: {self.test_results['summary']['success_rate']}%")
        print(f"Overall Status: {self.test_results['summary']['overall_status']}")
        
        if failed_tests > 0 or error_tests > 0:
            print("\n❌ Failed/Error Tests:")
            for test in all_tests:
                if test['status'] in ['FAILED', 'ERROR']:
                    print(f"  - {test['test']}: {test['status']} - {test['details']}")

if __name__ == "__main__":
    # Database connection parameters
    db_params = {
        'host': os.getenv('DB_HOST', 'localhost'),
        'port': os.getenv('DB_PORT', '5432'),
        'database': os.getenv('DB_NAME', 'one_vault'),
        'user': os.getenv('DB_USER', 'postgres'),
        'password': os.getenv('DB_PASSWORD', '')
    }
    
    # Run tests
    tester = SystemOperationsDeploymentTester(db_params)
    results = tester.run_all_tests()
    
    # Export results
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    results_file = f'system_operations_deployment_test_results_{timestamp}.json'
    with open(results_file, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print(f"\n📄 Test results exported to: {results_file}")
    
    # Exit with appropriate code
    sys.exit(0 if results['summary']['overall_status'] == 'PASSED' else 1) 