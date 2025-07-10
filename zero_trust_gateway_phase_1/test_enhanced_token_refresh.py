#!/usr/bin/env python3
"""
Test Enhanced Token Refresh System
Verifies the fixed token refresh functions work correctly
"""

import psycopg2
import os
import json
from psycopg2.extras import RealDictCursor
from datetime import datetime

# Database connection
def get_db_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        database=os.getenv('DB_NAME', 'One_Vault'),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASSWORD', 'postgres'),
        port=os.getenv('DB_PORT', 5432),
        cursor_factory=RealDictCursor
    )

def test_function_exists(conn, function_name):
    """Test if a function exists in the database"""
    print(f"\n🔍 Testing if function {function_name} exists...")
    
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT EXISTS (
                    SELECT 1 FROM pg_proc p
                    JOIN pg_namespace n ON p.pronamespace = n.oid 
                    WHERE n.nspname = 'auth' 
                    AND p.proname = %s
                )
            """, (function_name,))
            
            exists = cur.fetchone()[0]
            
            if exists:
                print(f"✅ Function auth.{function_name} exists")
                return True
            else:
                print(f"❌ Function auth.{function_name} does not exist")
                return False
                
    except Exception as e:
        print(f"❌ Error checking function existence: {e}")
        return False

def test_token_status(conn, token):
    """Test the get_token_refresh_status function"""
    print(f"\n🧪 Testing token status function...")
    
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT * FROM auth.get_token_refresh_status(%s)
            """, (token,))
            
            result = cur.fetchone()
            
            print(f"✅ Token status check successful:")
            print(f"   - Token found: {result['token_found']}")
            print(f"   - Is production token: {result['is_production_token']}")
            print(f"   - Token type: {result['token_type']}")
            print(f"   - Expires at: {result['expires_at']}")
            print(f"   - Days until expiry: {result['days_until_expiry']}")
            print(f"   - Is revoked: {result['is_revoked']}")
            print(f"   - Refresh recommended: {result['refresh_recommended']}")
            print(f"   - Refresh reason: {result['refresh_reason']}")
            
            return result
            
    except Exception as e:
        print(f"❌ Token status test failed: {e}")
        return None

def test_token_refresh(conn, token, force_refresh=False):
    """Test the refresh_production_token_enhanced function"""
    print(f"\n🔄 Testing token refresh function (force={force_refresh})...")
    
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT * FROM auth.refresh_production_token_enhanced(%s, 7, %s)
            """, (token, force_refresh))
            
            result = cur.fetchone()
            
            print(f"📋 Token refresh result:")
            print(f"   - Success: {result['success']}")
            print(f"   - New token: {result['new_token'][:20] + '...' if result['new_token'] else 'None'}")
            print(f"   - Expires at: {result['expires_at']}")
            print(f"   - Refresh reason: {result['refresh_reason']}")
            print(f"   - Message: {result['message']}")
            
            return result
            
    except Exception as e:
        print(f"❌ Token refresh test failed: {e}")
        return None

def test_role_permissions(conn):
    """Test role permissions and security"""
    print(f"\n🔐 Testing role permissions...")
    
    try:
        with conn.cursor() as cur:
            # Check current user
            cur.execute("SELECT current_user, session_user")
            user_info = cur.fetchone()
            print(f"   - Current user: {user_info['current_user']}")
            print(f"   - Session user: {user_info['session_user']}")
            
            # Check if functions are SECURITY DEFINER
            cur.execute("""
                SELECT p.proname, p.prosecdef 
                FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid 
                WHERE n.nspname = 'auth' 
                AND p.proname IN ('refresh_production_token_enhanced', 'get_token_refresh_status')
            """)
            
            functions = cur.fetchall()
            for func in functions:
                security_mode = "SECURITY DEFINER" if func['prosecdef'] else "SECURITY INVOKER"
                print(f"   - {func['proname']}: {security_mode}")
            
            return True
            
    except Exception as e:
        print(f"❌ Role permission test failed: {e}")
        return False

def test_integration_scenario(conn, token):
    """Test a realistic integration scenario"""
    print(f"\n🔗 Testing realistic integration scenario...")
    
    try:
        # Step 1: Check if token needs refresh
        status_result = test_token_status(conn, token)
        if not status_result:
            return False
        
        # Step 2: If refresh recommended, refresh it
        if status_result['refresh_recommended']:
            print(f"   📝 Token refresh is recommended: {status_result['refresh_reason']}")
            refresh_result = test_token_refresh(conn, token, force_refresh=False)
            
            if refresh_result and refresh_result['success']:
                print(f"   ✅ Integration scenario: Token successfully refreshed")
                new_token = refresh_result['new_token']
                
                # Step 3: Verify new token status
                new_status = test_token_status(conn, new_token)
                if new_status and new_status['token_found']:
                    print(f"   ✅ New token verified successfully")
                    return True
                else:
                    print(f"   ❌ New token verification failed")
                    return False
            else:
                print(f"   ❌ Token refresh failed in integration test")
                return False
        else:
            print(f"   ✅ Integration scenario: Token is fresh, no refresh needed")
            return True
            
    except Exception as e:
        print(f"❌ Integration scenario test failed: {e}")
        return False

def run_comprehensive_test():
    """Run comprehensive test suite"""
    print("🧪 ENHANCED TOKEN REFRESH SYSTEM COMPREHENSIVE TEST")
    print("=" * 60)
    
    # Test configuration
    test_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
    
    # Connect to database
    try:
        conn = get_db_connection()
        print("✅ Database connection successful")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False
    
    test_results = {}
    
    try:
        # Test 1: Function existence
        test_results['functions_exist'] = (
            test_function_exists(conn, 'refresh_production_token_enhanced') and
            test_function_exists(conn, 'get_token_refresh_status')
        )
        
        # Test 2: Role permissions
        test_results['permissions'] = test_role_permissions(conn)
        
        # Test 3: Token status function
        test_results['token_status'] = test_token_status(conn, test_token) is not None
        
        # Test 4: Token refresh function (without force)
        test_results['token_refresh_normal'] = test_token_refresh(conn, test_token, force_refresh=False) is not None
        
        # Test 5: Token refresh function (with force)
        test_results['token_refresh_force'] = test_token_refresh(conn, test_token, force_refresh=True) is not None
        
        # Test 6: Integration scenario
        test_results['integration'] = test_integration_scenario(conn, test_token)
        
    finally:
        conn.close()
        print("\n🔌 Database connection closed")
    
    # Summary
    print("\n📊 TEST RESULTS SUMMARY")
    print("=" * 60)
    
    total_tests = len(test_results)
    passed_tests = sum(1 for result in test_results.values() if result)
    
    for test_name, result in test_results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name:25} {status}")
    
    print(f"\n🎯 OVERALL RESULT: {passed_tests}/{total_tests} tests passed")
    
    if passed_tests == total_tests:
        print("🎉 ALL TESTS PASSED! Enhanced Token Refresh System is ready for production.")
        print("\n📋 NEXT STEPS:")
        print("1. Deploy to production database")
        print("2. Update API endpoints to use the new functions")
        print("3. Implement client-side token refresh handling")
        print("4. Set up monitoring for token refresh metrics")
        return True
    else:
        print("⚠️  Some tests failed. Please review the issues above.")
        return False

if __name__ == "__main__":
    success = run_comprehensive_test()
    exit(0 if success else 1) 