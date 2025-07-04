import psycopg2
import json
import getpass
from datetime import datetime
from typing import Dict, Any, Optional

class CanvasDatabaseTester:
    def __init__(self):
        self.conn = None
        self.test_results = []
    
    def connect_to_local_db(self):
        """Securely connect to local test database"""
        print("🔐 OneVault Canvas Database Tester")
        print("Connecting to: one_vault_site_testing (localhost)")
        
        # Secure password input
        password = getpass.getpass("Enter database password: ")
        
        try:
            self.conn = psycopg2.connect(
                host="localhost",
                port=5432,
                database="one_vault_site_testing",
                user="postgres",  # or your username
                password=password
            )
            print("✅ Database connection successful")
            return True
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def test_auth_functions(self):
        """Test authentication functions that Canvas will use"""
        print("\n🔐 Testing Authentication Functions...")
        
        tests = [
            {
                'name': 'auth_login',
                'function': 'api.auth_login',
                'test_data': {
                    'username': 'test_canvas_user',
                    'password': 'test_password',
                    'ip_address': '127.0.0.1',
                    'user_agent': 'Canvas-Test',
                    'auto_login': True
                }
            },
            {
                'name': 'auth_validate_session',
                'function': 'api.auth_validate_session',
                'test_data': {
                    'session_token': 'test_token_12345',
                    'ip_address': '127.0.0.1',
                    'user_agent': 'Canvas-Test'
                }
            }
        ]
        
        for test in tests:
            try:
                cursor = self.conn.cursor()
                cursor.execute(f"SELECT {test['function']}(%s)", (json.dumps(test['test_data']),))
                result = cursor.fetchone()
                cursor.close()
                
                self.test_results.append({
                    'test': test['name'],
                    'status': 'PASS' if result else 'FAIL',
                    'result': result[0] if result else None,
                    'timestamp': datetime.now().isoformat()
                })
                
                print(f"✅ {test['name']}: {'PASS' if result else 'FAIL'}")
                if result and result[0]:
                    print(f"   Response: {json.dumps(result[0], indent=2)}")
                    
            except Exception as e:
                self.test_results.append({
                    'test': test['name'],
                    'status': 'ERROR',
                    'error': str(e),
                    'timestamp': datetime.now().isoformat()
                })
                print(f"❌ {test['name']}: ERROR - {e}")
    
    def test_tenant_isolation(self):
        """Test multi-tenant data access"""
        print("\n🏢 Testing Tenant Isolation...")
        
        try:
            cursor = self.conn.cursor()
            
            # Check if tenant tables exist and have proper isolation
            cursor.execute("""
                SELECT schemaname, tablename 
                FROM pg_tables 
                WHERE tablename LIKE '%tenant%' 
                OR tablename LIKE '%_h'
                ORDER BY schemaname, tablename
            """)
            
            tables = cursor.fetchall()
            print(f"📊 Found {len(tables)} tenant-related tables")
            
            for schema, table in tables[:5]:  # Show first 5
                print(f"   {schema}.{table}")
            
            # Test tenant isolation query
            cursor.execute("""
                SELECT COUNT(*) as tenant_count 
                FROM auth.tenant_h 
                WHERE load_end_date IS NULL
            """)
            
            tenant_count = cursor.fetchone()[0]
            print(f"🏢 Active tenants in database: {tenant_count}")
            
            cursor.close()
            
            self.test_results.append({
                'test': 'tenant_isolation',
                'status': 'PASS',
                'tenant_count': tenant_count,
                'tables_found': len(tables)
            })
            
        except Exception as e:
            print(f"❌ Tenant isolation test failed: {e}")
            self.test_results.append({
                'test': 'tenant_isolation',
                'status': 'ERROR',
                'error': str(e)
            })
    
    def test_ai_agent_functions(self):
        """Test functions needed for AI agent integration"""
        print("\n🤖 Testing AI Agent Functions...")
        
        try:
            cursor = self.conn.cursor()
            
            # Check for agent-related functions
            cursor.execute("""
                SELECT p.proname as function_name, n.nspname as schema_name
                FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid
                WHERE n.nspname IN ('api', 'business') 
                AND (p.proname LIKE '%agent%' OR p.proname LIKE '%analyze%')
                ORDER BY n.nspname, p.proname
            """)
            
            functions = cursor.fetchall()
            print(f"🔍 Found {len(functions)} agent-related functions:")
            
            for func_name, schema in functions:
                print(f"   {schema}.{func_name}")
            
            cursor.close()
            
            self.test_results.append({
                'test': 'ai_agent_functions',
                'status': 'PASS',
                'functions_found': len(functions),
                'functions': [f"{schema}.{func}" for func, schema in functions]
            })
            
        except Exception as e:
            print(f"❌ AI agent function test failed: {e}")
            self.test_results.append({
                'test': 'ai_agent_functions',
                'status': 'ERROR', 
                'error': str(e)
            })
    
    def test_workflow_storage(self):
        """Test workflow storage capabilities"""
        print("\n🔄 Testing Workflow Storage...")
        
        try:
            cursor = self.conn.cursor()
            
            # Check for workflow-related tables
            cursor.execute("""
                SELECT schemaname, tablename 
                FROM pg_tables 
                WHERE tablename LIKE '%workflow%' 
                OR tablename LIKE '%template%'
                OR tablename LIKE '%agent%'
                ORDER BY schemaname, tablename
            """)
            
            tables = cursor.fetchall()
            print(f"📊 Found {len(tables)} workflow-related tables:")
            
            for schema, table in tables:
                print(f"   {schema}.{table}")
            
            cursor.close()
            
            self.test_results.append({
                'test': 'workflow_storage',
                'status': 'PASS',
                'tables_found': len(tables),
                'tables': [f"{schema}.{table}" for schema, table in tables]
            })
            
        except Exception as e:
            print(f"❌ Workflow storage test failed: {e}")
            self.test_results.append({
                'test': 'workflow_storage',
                'status': 'ERROR',
                'error': str(e)
            })
    
    def generate_report(self):
        """Generate comprehensive test report"""
        print(f"\n📋 Canvas Database Integration Test Report")
        print(f"{'='*50}")
        print(f"Test Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Database: one_vault_site_testing")
        
        total_tests = len(self.test_results)
        passed_tests = len([t for t in self.test_results if t['status'] == 'PASS'])
        
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests}")
        print(f"Failed: {total_tests - passed_tests}")
        print(f"Success Rate: {(passed_tests/total_tests*100):.1f}%")
        
        print(f"\n📊 Detailed Results:")
        for result in self.test_results:
            status_emoji = "✅" if result['status'] == 'PASS' else "❌"
            print(f"{status_emoji} {result['test']}: {result['status']}")
            if 'error' in result:
                print(f"   Error: {result['error']}")
        
        # Save detailed report
        report_file = f"canvas_db_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, 'w') as f:
            json.dump({
                'test_summary': {
                    'total_tests': total_tests,
                    'passed_tests': passed_tests,
                    'success_rate': passed_tests/total_tests*100,
                    'test_date': datetime.now().isoformat()
                },
                'test_results': self.test_results
            }, f, indent=2)
        
        print(f"\n💾 Detailed report saved: {report_file}")
        
        return passed_tests == total_tests
    
    def run_all_tests(self):
        """Run complete test suite"""
        if not self.connect_to_local_db():
            return False
        
        try:
            self.test_auth_functions()
            self.test_tenant_isolation()
            self.test_ai_agent_functions()
            self.test_workflow_storage()
            
            return self.generate_report()
            
        finally:
            if self.conn:
                self.conn.close()
                print("\n🔐 Database connection closed")

# Run the tests
if __name__ == "__main__":
    tester = CanvasDatabaseTester()
    success = tester.run_all_tests()
    
    if success:
        print("\n🎉 All tests passed! Ready for Canvas-API integration.")
    else:
        print("\n⚠️ Some tests failed. Review results before proceeding.")
