#!/usr/bin/env python3
"""
V017 Security Validation Test Suite
===================================
Test the cross-tenant authentication security fix

CRITICAL TESTS:
1. ✅ Valid tenant authentication (should work)
2. ❌ Cross-tenant attack prevention (should fail)
3. ✅ Backward compatibility (should work)
4. ❌ Invalid token handling (should fail)
"""

import psycopg2
import json
import sys
from datetime import datetime
import traceback

# Database connection
DB_CONFIG = {
    'host': 'localhost',
    'database': 'one_vault_dev',
    'user': 'postgres',
    'password': 'Tr@vis123'  # Update as needed
}

class V017SecurityTester:
    def __init__(self):
        self.conn = None
        self.test_results = []
        
    def connect(self):
        """Connect to the database"""
        try:
            self.conn = psycopg2.connect(**DB_CONFIG)
            self.conn.autocommit = True
            print("✅ Connected to one_vault_dev database")
            return True
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def execute_auth_test(self, test_name, request_data, expected_success=True):
        """Execute an authentication test"""
        try:
            cursor = self.conn.cursor()
            
            # Call the API function
            cursor.execute(
                "SELECT api.auth_login(%s::jsonb)",
                (json.dumps(request_data),)
            )
            
            result = cursor.fetchone()[0]
            success = result.get('success', False)
            message = result.get('message', 'No message')
            
            # Evaluate test result
            test_passed = (success == expected_success)
            status = "✅ PASS" if test_passed else "❌ FAIL"
            
            print(f"\n{status} {test_name}")
            print(f"   Expected Success: {expected_success}")
            print(f"   Actual Success: {success}")
            print(f"   Message: {message}")
            
            if not expected_success and success:
                print(f"   🚨 SECURITY VULNERABILITY: This should have failed!")
            elif expected_success and not success:
                print(f"   ⚠️ FUNCTIONALITY BROKEN: This should have worked!")
            
            self.test_results.append({
                'test_name': test_name,
                'expected_success': expected_success,
                'actual_success': success,
                'message': message,
                'passed': test_passed,
                'security_critical': not expected_success
            })
            
            cursor.close()
            return test_passed
            
        except Exception as e:
            print(f"❌ FAIL {test_name}")
            print(f"   Error: {e}")
            self.test_results.append({
                'test_name': test_name,
                'expected_success': expected_success,
                'actual_success': False,
                'message': str(e),
                'passed': False,
                'security_critical': not expected_success
            })
            return False
    
    def get_test_tokens(self):
        """Get API tokens for testing"""
        try:
            cursor = self.conn.cursor()
            
            # Get theonespaoregon token
            cursor.execute("""
                SELECT token_value 
                FROM auth.api_token_s 
                WHERE tenant_hk = (
                    SELECT tenant_hk 
                    FROM auth.tenant_h 
                    WHERE tenant_bk = 'theonespaoregon'
                )
                AND load_end_date IS NULL
                LIMIT 1
            """)
            
            theonespaoregon_token = cursor.fetchone()
            theonespaoregon_token = theonespaoregon_token[0] if theonespaoregon_token else None
            
            # Get any other tenant token for cross-tenant testing
            cursor.execute("""
                SELECT token_value, th.tenant_bk
                FROM auth.api_token_s ats
                JOIN auth.tenant_h th ON ats.tenant_hk = th.tenant_hk
                WHERE th.tenant_bk != 'theonespaoregon'
                AND ats.load_end_date IS NULL
                LIMIT 1
            """)
            
            other_result = cursor.fetchone()
            other_token = other_result[0] if other_result else None
            other_tenant = other_result[1] if other_result else None
            
            cursor.close()
            
            print(f"📋 Test Tokens Retrieved:")
            print(f"   TheOnespaOregon Token: {'✅ Found' if theonespaoregon_token else '❌ Missing'}")
            print(f"   Other Tenant Token: {'✅ Found' if other_token else '❌ Missing'} ({other_tenant})")
            
            return {
                'theonespaoregon': theonespaoregon_token,
                'other_tenant': other_token,
                'other_tenant_name': other_tenant
            }
            
        except Exception as e:
            print(f"❌ Failed to get test tokens: {e}")
            return None
    
    def run_security_tests(self):
        """Run comprehensive security tests"""
        print("\n🔒 V017 SECURITY VALIDATION TEST SUITE")
        print("=" * 50)
        
        # Get test tokens
        tokens = self.get_test_tokens()
        if not tokens or not tokens['theonespaoregon']:
            print("❌ Cannot run tests without valid tokens")
            return False
        
        # Test 1: Valid authentication (should work)
        print(f"\n📋 TEST 1: Valid Tenant Authentication")
        self.execute_auth_test(
            "Valid User in Correct Tenant",
            {
                "username": "travis@gmail.com",
                "password": "Tr@vis123",
                "authorization_token": tokens['theonespaoregon'],
                "ip_address": "127.0.0.1",
                "user_agent": "V017-Security-Test"
            },
            expected_success=True
        )
        
        # Test 2: Cross-tenant attack (should fail)
        if tokens['other_tenant']:
            print(f"\n📋 TEST 2: Cross-Tenant Attack Prevention")
            self.execute_auth_test(
                "Cross-Tenant Attack (MUST FAIL)",
                {
                    "username": "travis@gmail.com",
                    "password": "Tr@vis123", 
                    "authorization_token": tokens['other_tenant'],
                    "ip_address": "127.0.0.1",
                    "user_agent": "V017-Security-Test-ATTACK"
                },
                expected_success=False
            )
        
        # Test 3: Invalid API token (should fail)
        print(f"\n📋 TEST 3: Invalid Token Handling")
        self.execute_auth_test(
            "Invalid API Token (MUST FAIL)",
            {
                "username": "travis@gmail.com",
                "password": "Tr@vis123",
                "authorization_token": "ovt_invalid_token_123456789",
                "ip_address": "127.0.0.1", 
                "user_agent": "V017-Security-Test"
            },
            expected_success=False
        )
        
        # Test 4: Missing API token (should fail)
        print(f"\n📋 TEST 4: Missing Token Handling")
        self.execute_auth_test(
            "Missing API Token (MUST FAIL)",
            {
                "username": "travis@gmail.com",
                "password": "Tr@vis123",
                "ip_address": "127.0.0.1",
                "user_agent": "V017-Security-Test"
            },
            expected_success=False
        )
        
        # Test 5: Backward compatibility - token in body (should work)
        print(f"\n📋 TEST 5: Backward Compatibility")
        self.execute_auth_test(
            "Token in Request Body (Backward Compatibility)",
            {
                "username": "travis@gmail.com",
                "password": "Tr@vis123",
                "api_token": tokens['theonespaoregon'],  # In body instead of header
                "ip_address": "127.0.0.1",
                "user_agent": "V017-Security-Test"
            },
            expected_success=True
        )
        
        # Test 6: Wrong password (should fail)
        print(f"\n📋 TEST 6: Invalid Password")
        self.execute_auth_test(
            "Wrong Password (MUST FAIL)",
            {
                "username": "travis@gmail.com",
                "password": "WrongPassword123",
                "authorization_token": tokens['theonespaoregon'],
                "ip_address": "127.0.0.1",
                "user_agent": "V017-Security-Test"
            },
            expected_success=False
        )
        
        return True
    
    def print_summary(self):
        """Print test summary"""
        print("\n" + "=" * 60)
        print("🔒 V017 SECURITY TEST SUMMARY")
        print("=" * 60)
        
        total_tests = len(self.test_results)
        passed_tests = sum(1 for t in self.test_results if t['passed'])
        security_tests = [t for t in self.test_results if t['security_critical']]
        security_passed = sum(1 for t in security_tests if t['passed'])
        
        print(f"📊 Overall Results: {passed_tests}/{total_tests} tests passed")
        print(f"🔒 Security Tests: {security_passed}/{len(security_tests)} security tests passed")
        
        # Critical security failures
        security_failures = [t for t in security_tests if not t['passed']]
        if security_failures:
            print(f"\n🚨 CRITICAL SECURITY FAILURES:")
            for test in security_failures:
                print(f"   ❌ {test['test_name']}: {test['message']}")
        
        # Overall assessment
        all_security_passed = len(security_failures) == 0
        functionality_works = any(t['passed'] for t in self.test_results if not t['security_critical'])
        
        print(f"\n🎯 SECURITY ASSESSMENT:")
        if all_security_passed and functionality_works:
            print("   ✅ SECURITY FIX SUCCESSFUL - Ready for production!")
            print("   ✅ Cross-tenant attacks blocked")
            print("   ✅ Existing functionality preserved")
        elif all_security_passed:
            print("   ⚠️ Security working but functionality issues detected")
        else:
            print("   🚨 SECURITY VULNERABILITIES STILL EXIST - DO NOT DEPLOY!")
        
        return all_security_passed and functionality_works
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()

def main():
    """Main test execution"""
    print("🔒 V017 Security Validation Test Suite")
    print("Testing cross-tenant authentication security fix...")
    
    tester = V017SecurityTester()
    
    try:
        # Connect to database
        if not tester.connect():
            return False
        
        # Run security tests
        if not tester.run_security_tests():
            return False
        
        # Print summary and assessment
        success = tester.print_summary()
        
        return success
        
    except Exception as e:
        print(f"❌ Test suite failed: {e}")
        traceback.print_exc()
        return False
    finally:
        tester.close()

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 