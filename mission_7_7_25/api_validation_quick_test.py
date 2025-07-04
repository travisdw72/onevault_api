#!/usr/bin/env python3
"""
One_Barn_AI API Quick Validation Test
====================================
Date: July 2, 2025
Purpose: Quick validation of One_Barn_AI API setup for July 7th demo
Usage: python api_validation_quick_test.py

This script performs rapid validation of the API-based setup to ensure
all endpoints are working correctly for the customer demo.
"""

import requests
import json
import sys
from datetime import datetime

def test_api_health(api_base: str) -> tuple[bool, dict]:
    """Test API health and availability."""
    try:
        response = requests.get(f"{api_base}/api/system_health_check", timeout=10)
        if response.status_code == 200:
            return True, response.json()
        else:
            return False, {"error": f"HTTP {response.status_code}", "details": response.text}
    except Exception as e:
        return False, {"error": "Connection failed", "details": str(e)}

def test_authentication(api_base: str) -> tuple[bool, dict]:
    """Test One_Barn_AI admin authentication."""
    try:
        auth_data = {
            "username": "admin@onebarnai.com",
            "password": "HorseHealth2025!",
            "ip_address": "127.0.0.1",
            "user_agent": "OneVault-QuickTest",
            "auto_login": True
        }
        
        response = requests.post(f"{api_base}/api/auth_login", 
                               json=auth_data, timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                return True, {
                    "session_token": result.get('data', {}).get('session_token', '')[:20] + '...',
                    "user_data": "present" if result.get('data', {}).get('user_data') else "missing",
                    "tenant_list": len(result.get('data', {}).get('tenant_list', []))
                }
            else:
                return False, {"error": "Auth failed", "message": result.get('message')}
        else:
            return False, {"error": f"HTTP {response.status_code}", "details": response.text}
    except Exception as e:
        return False, {"error": "Auth test failed", "details": str(e)}

def test_demo_user_auth(api_base: str, email: str, password: str) -> tuple[bool, dict]:
    """Test demo user authentication."""
    try:
        auth_data = {
            "username": email,
            "password": password,
            "ip_address": "127.0.0.1",
            "user_agent": "OneVault-DemoTest",
            "auto_login": True
        }
        
        response = requests.post(f"{api_base}/api/auth_login", 
                               json=auth_data, timeout=5)
        
        if response.status_code == 200:
            result = response.json()
            return result.get('success', False), {
                "email": email,
                "auth_success": result.get('success', False),
                "message": result.get('message', 'No message')
            }
        else:
            return False, {"email": email, "error": f"HTTP {response.status_code}"}
    except Exception as e:
        return False, {"email": email, "error": str(e)}

def main():
    """Execute quick validation tests."""
    print("🚀 One_Barn_AI API Quick Validation")
    print("=" * 50)
    print(f"Test Time: {datetime.now().isoformat()}")
    print()
    
    # API Configuration - Support localhost testing
    import sys
    import os
    
    # Check command line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] in ['--help', '-h']:
            print("Usage: python api_validation_quick_test.py [API_URL]")
            print("")
            print("Options:")
            print("  API_URL    API endpoint to test (default: production)")
            print("  --help     Show this help message")
            print("")
            print("Examples:")
            print("  python api_validation_quick_test.py")
            print("  python api_validation_quick_test.py http://localhost:8000")
            print("  python api_validation_quick_test.py https://staging-api.onevault.com")
            return 0
        else:
            api_base = sys.argv[1]
    else:
        # Check environment variable
        api_base = os.getenv('ONEVAULT_API_URL', 'https://onevault-api.onrender.com')
    
    print(f"🎯 Testing API: {api_base}")
    print()
    
    # Demo users to test
    demo_users = [
        ("admin@onebarnai.com", "HorseHealth2025!"),
        ("vet@onebarnai.com", "VetSpecialist2025!"),
        ("tech@onebarnai.com", "TechLead2025!"),
        ("business@onebarnai.com", "BizDev2025!")
    ]
    
    results = []
    
    # Test 1: API Health
    print("🔍 Testing API Health...")
    health_success, health_data = test_api_health(api_base)
    results.append(("API Health", health_success))
    
    if health_success:
        print("✅ API is operational")
        print(f"   Status: {health_data.get('status', 'unknown')}")
        if 'components' in health_data:
            components = health_data['components']
            print(f"   Database: {components.get('database', {}).get('status', 'unknown')}")
            print(f"   API Functions: {components.get('api_functions', {}).get('available', 'unknown')}")
    else:
        print("❌ API health check failed")
        print(f"   Error: {health_data.get('error')}")
    
    print()
    
    # Test 2: Admin Authentication
    print("🔐 Testing Admin Authentication...")
    auth_success, auth_data = test_authentication(api_base)
    results.append(("Admin Auth", auth_success))
    
    if auth_success:
        print("✅ Admin authentication successful")
        print(f"   Session Token: {auth_data.get('session_token')}")
        print(f"   Tenant Count: {auth_data.get('tenant_list')}")
    else:
        print("❌ Admin authentication failed")
        print(f"   Error: {auth_data.get('error')}")
        print(f"   Details: {auth_data.get('message', auth_data.get('details'))}")
    
    print()
    
    # Test 3: Demo User Authentication
    print("👥 Testing Demo User Authentication...")
    demo_auth_results = []
    
    for email, password in demo_users:
        user_success, user_data = test_demo_user_auth(api_base, email, password)
        demo_auth_results.append(user_success)
        
        if user_success:
            print(f"✅ {email}: Authentication successful")
        else:
            print(f"❌ {email}: Authentication failed")
            print(f"   Error: {user_data.get('error', 'Unknown error')}")
    
    all_demo_users_working = all(demo_auth_results)
    results.append(("Demo Users", all_demo_users_working))
    
    print()
    
    # Summary
    print("=" * 50)
    print("📊 VALIDATION SUMMARY")
    print("=" * 50)
    
    success_count = sum(1 for _, success in results if success)
    total_tests = len(results)
    
    overall_success = success_count == total_tests
    
    print(f"Overall Status: {'🎉 DEMO READY' if overall_success else '⚠️ ISSUES DETECTED'}")
    print(f"Tests Passed: {success_count}/{total_tests}")
    print()
    
    print("Test Results:")
    for test_name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"  {test_name}: {status}")
    
    print()
    
    if overall_success:
        print("🎯 Demo Readiness: CONFIRMED")
        print("   • API endpoints responding correctly")
        print("   • Authentication flow working")
        print("   • All demo users can login")
        print("   • System ready for July 7th demo")
        print()
        print("🔑 Demo Credentials Validated:")
        for email, _ in demo_users:
            print(f"   • {email}")
    else:
        print("⚠️ Demo Readiness: NEEDS ATTENTION")
        print("   • Some API endpoints may not be working")
        print("   • Check setup and try running full API setup again")
        print("   • Consider fallback demo options")
    
    print()
    print(f"API Endpoint: {api_base}")
    print(f"Validation completed at: {datetime.now().isoformat()}")
    
    return 0 if overall_success else 1

if __name__ == "__main__":
    sys.exit(main())
