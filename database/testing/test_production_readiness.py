#!/usr/bin/env python3
"""
Production Readiness Test Suite
Tests core functionality including specific user login and API endpoints

This script tests:
1. Database connection and basic queries
2. User existence and authentication
3. Core API functionality 
4. System health checks
"""

import os
import sys
import json
import psycopg2
import bcrypt
from datetime import datetime
from pathlib import Path

# Add the testing directory to Python path for imports
sys.path.append(str(Path(__file__).parent / 'scripts' / 'testing'))

# Test configuration
TEST_CONFIG = {
    'database': {
        'host': 'localhost',
        'port': 5432,
        'database': 'one_vault',
        'user': 'postgres',
        'password': os.getenv('DB_PASSWORD', 'password')  # Set this env var
    },
    'test_user': {
        'email': 'travisdwoodward72@gmail.com',
        'password': 'MySecurePassword321'
    }
}

class ProductionReadinessTest:
    def __init__(self):
        self.connection = None
        self.test_results = {
            'timestamp': datetime.now().isoformat(),
            'tests': [],
            'summary': {
                'total': 0,
                'passed': 0,
                'failed': 0,
                'critical_failures': []
            }
        }
    
    def connect_database(self):
        """Test database connection"""
        print("🔌 Testing database connection...")
        try:
            self.connection = psycopg2.connect(**TEST_CONFIG['database'])
            self.log_test("Database Connection", True, "Successfully connected to database")
            return True
        except Exception as e:
            self.log_test("Database Connection", False, f"Failed to connect: {e}", critical=True)
            return False
    
    def test_user_exists(self):
        """Check if test user exists in database"""
        print("👤 Checking if test user exists...")
        try:
            cursor = self.connection.cursor()
            
            # Query to check if user exists
            query = """
            SELECT 
                up.first_name,
                up.last_name,
                up.email,
                uas.username,
                uas.last_login_date,
                th.tenant_bk
            FROM auth.user_profile_s up
            JOIN auth.user_h uh ON up.user_hk = uh.user_hk
            JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
            JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
            WHERE up.email = %s 
            AND up.load_end_date IS NULL
            AND uas.load_end_date IS NULL
            """
            
            cursor.execute(query, (TEST_CONFIG['test_user']['email'],))
            result = cursor.fetchone()
            
            if result:
                user_info = {
                    'first_name': result[0],
                    'last_name': result[1], 
                    'email': result[2],
                    'username': result[3],
                    'last_login': result[4].isoformat() if result[4] else None,
                    'tenant': result[5]
                }
                self.log_test("User Exists", True, f"User found: {user_info}")
                return user_info
            else:
                self.log_test("User Exists", False, f"User {TEST_CONFIG['test_user']['email']} not found", critical=True)
                return None
                
        except Exception as e:
            self.log_test("User Exists", False, f"Error checking user: {e}", critical=True)
            return None
        finally:
            if cursor:
                cursor.close()
    
    def test_login_functionality(self):
        """Test the actual login function"""
        print("🔐 Testing login functionality...")
        try:
            cursor = self.connection.cursor()
            
            # Call the auth.login_user function directly
            query = """
            SELECT auth.login_user(%s, %s)
            """
            
            cursor.execute(query, (
                TEST_CONFIG['test_user']['email'],
                TEST_CONFIG['test_user']['password']
            ))
            
            result = cursor.fetchone()
            login_result = result[0] if result else None
            
            if login_result and login_result.get('p_success'):
                self.log_test("Login Function", True, f"Login successful: {login_result}")
                return login_result
            else:
                self.log_test("Login Function", False, f"Login failed: {login_result}", critical=True)
                return None
                
        except Exception as e:
            self.log_test("Login Function", False, f"Error during login: {e}", critical=True)
            return None
        finally:
            if cursor:
                cursor.close()
    
    def test_complete_login_with_token(self, login_result):
        """Test the complete login process with token generation"""
        print("🎫 Testing complete login with token...")
        try:
            if not login_result or not login_result.get('p_session_token'):
                self.log_test("Complete Login", False, "No session token from initial login", critical=True)
                return None
            
            cursor = self.connection.cursor()
            
            # Test auth.complete_login function
            query = """
            SELECT auth.complete_login(%s, %s, %s)
            """
            
            cursor.execute(query, (
                login_result['p_user_hk'],
                login_result['p_session_token'],
                '127.0.0.1'  # Test IP
            ))
            
            result = cursor.fetchone()
            complete_result = result[0] if result else None
            
            if complete_result and complete_result.get('p_success'):
                self.log_test("Complete Login", True, f"Complete login successful: {complete_result}")
                return complete_result
            else:
                self.log_test("Complete Login", False, f"Complete login failed: {complete_result}")
                return None
                
        except Exception as e:
            self.log_test("Complete Login", False, f"Error in complete login: {e}")
            return None
        finally:
            if cursor:
                cursor.close()
    
    def test_session_validation(self, session_token):
        """Test session token validation"""
        print("✅ Testing session validation...")
        try:
            cursor = self.connection.cursor()
            
            # Test auth.validate_session function
            query = """
            SELECT auth.validate_session(%s)
            """
            
            cursor.execute(query, (session_token,))
            result = cursor.fetchone()
            validation_result = result[0] if result else None
            
            if validation_result and validation_result.get('valid'):
                self.log_test("Session Validation", True, f"Session valid: {validation_result}")
                return True
            else:
                self.log_test("Session Validation", False, f"Session invalid: {validation_result}")
                return False
                
        except Exception as e:
            self.log_test("Session Validation", False, f"Error validating session: {e}")
            return False
        finally:
            if cursor:
                cursor.close()
    
    def test_database_health(self):
        """Test overall database health"""
        print("🏥 Testing database health...")
        try:
            cursor = self.connection.cursor()
            
            health_checks = {
                'schema_count': "SELECT count(*) FROM information_schema.schemata WHERE schema_name NOT LIKE 'pg_%' AND schema_name != 'information_schema'",
                'table_count': "SELECT count(*) FROM information_schema.tables WHERE table_schema NOT LIKE 'pg_%' AND table_schema != 'information_schema'",
                'function_count': "SELECT count(*) FROM information_schema.routines WHERE routine_schema NOT LIKE 'pg_%' AND routine_schema != 'information_schema'",
                'user_count': "SELECT count(*) FROM auth.user_h",
                'tenant_count': "SELECT count(*) FROM auth.tenant_h"
            }
            
            health_results = {}
            for check_name, query in health_checks.items():
                cursor.execute(query)
                result = cursor.fetchone()
                health_results[check_name] = result[0] if result else 0
            
            # Check if we have reasonable numbers
            critical_issues = []
            if health_results['schema_count'] < 5:
                critical_issues.append(f"Too few schemas: {health_results['schema_count']}")
            if health_results['table_count'] < 20:
                critical_issues.append(f"Too few tables: {health_results['table_count']}")
            if health_results['function_count'] < 10:
                critical_issues.append(f"Too few functions: {health_results['function_count']}")
            
            if critical_issues:
                self.log_test("Database Health", False, f"Health issues: {critical_issues}", critical=True)
            else:
                self.log_test("Database Health", True, f"Database healthy: {health_results}")
            
            return health_results
            
        except Exception as e:
            self.log_test("Database Health", False, f"Error checking health: {e}", critical=True)
            return None
        finally:
            if cursor:
                cursor.close()
    
    def test_audit_system(self):
        """Test audit system functionality"""
        print("📋 Testing audit system...")
        try:
            cursor = self.connection.cursor()
            
            # Check if audit schema exists and has tables
            query = """
            SELECT count(*) 
            FROM information_schema.tables 
            WHERE table_schema = 'audit'
            """
            
            cursor.execute(query)
            result = cursor.fetchone()
            audit_table_count = result[0] if result else 0
            
            if audit_table_count >= 3:  # Expecting multiple audit tables
                self.log_test("Audit System", True, f"Audit system active with {audit_table_count} tables")
                return True
            else:
                self.log_test("Audit System", False, f"Audit system incomplete: {audit_table_count} tables")
                return False
                
        except Exception as e:
            self.log_test("Audit System", False, f"Error checking audit system: {e}")
            return False
        finally:
            if cursor:
                cursor.close()
    
    def log_test(self, test_name, passed, message, critical=False):
        """Log test result"""
        result = {
            'test': test_name,
            'passed': passed,
            'message': message,
            'critical': critical,
            'timestamp': datetime.now().isoformat()
        }
        
        self.test_results['tests'].append(result)
        self.test_results['summary']['total'] += 1
        
        if passed:
            self.test_results['summary']['passed'] += 1
            print(f"  ✅ {test_name}: {message}")
        else:
            self.test_results['summary']['failed'] += 1
            print(f"  ❌ {test_name}: {message}")
            if critical:
                self.test_results['summary']['critical_failures'].append(test_name)
    
    def run_all_tests(self):
        """Run all production readiness tests"""
        print("🚀 Starting Production Readiness Test Suite")
        print("=" * 60)
        
        # Test 1: Database Connection
        if not self.connect_database():
            print("\n❌ CRITICAL: Cannot connect to database. Stopping tests.")
            return self.test_results
        
        # Test 2: User Existence
        user_info = self.test_user_exists()
        if not user_info:
            print("\n⚠️  WARNING: Test user not found. Cannot test login functionality.")
        
        # Test 3: Login Functionality
        login_result = None
        if user_info:
            login_result = self.test_login_functionality()
        
        # Test 4: Complete Login Process
        complete_result = None
        if login_result:
            complete_result = self.test_complete_login_with_token(login_result)
        
        # Test 5: Session Validation
        if complete_result and complete_result.get('p_session_token'):
            self.test_session_validation(complete_result['p_session_token'])
        
        # Test 6: Database Health
        self.test_database_health()
        
        # Test 7: Audit System
        self.test_audit_system()
        
        # Final Summary
        self.print_summary()
        return self.test_results
    
    def print_summary(self):
        """Print test summary"""
        summary = self.test_results['summary']
        
        print("\n" + "=" * 60)
        print("🎯 PRODUCTION READINESS TEST SUMMARY")
        print("=" * 60)
        print(f"📊 Total Tests: {summary['total']}")
        print(f"✅ Passed: {summary['passed']}")
        print(f"❌ Failed: {summary['failed']}")
        
        if summary['critical_failures']:
            print(f"🚨 Critical Failures: {len(summary['critical_failures'])}")
            for failure in summary['critical_failures']:
                print(f"   • {failure}")
        
        # Production readiness assessment
        if summary['failed'] == 0:
            print("\n🚀 STATUS: READY FOR PRODUCTION! 🎉")
            print("All tests passed. System is ready to go live.")
        elif len(summary['critical_failures']) == 0:
            print("\n⚠️  STATUS: MOSTLY READY")
            print("Minor issues found but no critical failures.")
        else:
            print("\n❌ STATUS: NOT READY FOR PRODUCTION")
            print("Critical failures must be resolved before going live.")
        
        # Login-specific assessment
        login_tests = [t for t in self.test_results['tests'] if 'login' in t['test'].lower()]
        login_passed = all(t['passed'] for t in login_tests)
        
        if login_passed and any(t['test'] == 'Login Function' for t in login_tests):
            print(f"\n🔐 LOGIN STATUS: ✅ WORKING!")
            print(f"✅ User 'travisdwoodward72@gmail.com' can successfully login!")
            print(f"✅ Password 'MySecurePassword321' is accepted!")
            print(f"🎯 This means the authentication system is LIVE and working!")
        else:
            print(f"\n🔐 LOGIN STATUS: ❌ Issues found")
            print(f"The specified credentials may not work for production login.")
    
    def save_results(self):
        """Save test results to file"""
        results_file = Path('database/test_results') / f'production_readiness_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
        results_file.parent.mkdir(exist_ok=True)
        
        with open(results_file, 'w') as f:
            json.dump(self.test_results, f, indent=2)
        
        print(f"\n📋 Test results saved: {results_file}")
        return results_file
    
    def cleanup(self):
        """Cleanup database connection"""
        if self.connection:
            self.connection.close()

def main():
    """Main test execution"""
    # Check environment
    if not os.getenv('DB_PASSWORD'):
        print("⚠️  Warning: DB_PASSWORD environment variable not set.")
        print("Using default from config. Set this for production!")
    
    # Run tests
    tester = ProductionReadinessTest()
    
    try:
        results = tester.run_all_tests()
        results_file = tester.save_results()
        
        # Quick assessment for user
        if results['summary']['failed'] == 0:
            print("\n🚀 RECOMMENDATION: GO LIVE TODAY! System is ready!")
        else:
            print(f"\n⚠️  RECOMMENDATION: Review {results['summary']['failed']} failed test(s) before going live.")
        
        return results
        
    except KeyboardInterrupt:
        print("\n\n⏹️  Test interrupted by user")
        return None
    except Exception as e:
        print(f"\n❌ FATAL ERROR: {e}")
        return None
    finally:
        tester.cleanup()

if __name__ == "__main__":
    results = main()
    
    # Exit with appropriate code
    if results and results['summary']['critical_failures']:
        sys.exit(1)  # Critical failures
    elif results and results['summary']['failed'] > 0:
        sys.exit(2)  # Minor failures
    else:
        sys.exit(0)  # All good! 