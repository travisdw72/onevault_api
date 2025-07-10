#!/usr/bin/env python3
"""
Test Database-Compatible API Endpoints
=====================================
Tests the new database-compatible endpoints that match the production API contract.
"""

import requests
import json
import time

# API Configuration
BASE_URL = "https://onevault-api.onrender.com"
# BASE_URL = "http://localhost:8000"  # For local testing

def test_endpoint(method, endpoint, data=None, description=""):
    """Test an API endpoint and return the result"""
    url = f"{BASE_URL}{endpoint}"
    
    print(f"\n🧪 Testing: {description}")
    print(f"📍 {method} {url}")
    
    try:
        if method == "GET":
            response = requests.get(url, timeout=30)
        elif method == "POST":
            response = requests.post(url, json=data, timeout=30)
        else:
            print(f"❌ Unsupported method: {method}")
            return False
        
        print(f"📊 Status: {response.status_code}")
        
        if response.status_code == 200:
            try:
                result = response.json()
                print(f"✅ SUCCESS: {json.dumps(result, indent=2)[:200]}...")
                return True
            except:
                print(f"✅ SUCCESS: {response.text[:200]}...")
                return True
        else:
            print(f"❌ FAILED: {response.text[:200]}...")
            return False
            
    except Exception as e:
        print(f"❌ ERROR: {str(e)}")
        return False

def main():
    """Run all endpoint tests"""
    print("🚀 TESTING DATABASE-COMPATIBLE API ENDPOINTS")
    print("=" * 50)
    
    # Wait for deployment
    print("⏳ Waiting 30 seconds for deployment to complete...")
    time.sleep(30)
    
    tests = []
    
    # Test 1: System Health Check (no auth required)
    tests.append(test_endpoint(
        "GET", 
        "/api/system_health_check",
        description="Database System Health Check"
    ))
    
    # Test 2: Authentication Login
    tests.append(test_endpoint(
        "POST",
        "/api/auth_login",
        {
            "username": "john.doe@72industries.com",
            "password": "TempPassword123!",
            "ip_address": "127.0.0.1",
            "user_agent": "Test-Client/1.0",
            "auto_login": True
        },
        description="Database Authentication Login"
    ))
    
    # Test 3: Site Event Tracking
    tests.append(test_endpoint(
        "POST",
        "/api/track_site_event",
        {
            "ip_address": "127.0.0.1",
            "user_agent": "Test-Client/1.0",
            "page_url": "https://test.onevault.com",
            "event_type": "api_endpoint_test",
            "event_data": {
                "test_type": "database_compatibility",
                "timestamp": "2025-07-01T15:00:00Z"
            }
        },
        description="Database Site Event Tracking"
    ))
    
    # Test 4: AI Session Creation
    tests.append(test_endpoint(
        "POST",
        "/api/ai_create_session",
        {
            "tenant_id": "test_tenant",
            "agent_type": "business_intelligence_agent",
            "session_purpose": "canvas_integration_test",
            "metadata": {
                "test_mode": True,
                "api_version": "database_compatible"
            }
        },
        description="Database AI Session Creation"
    ))
    
    # Test Results Summary
    print("\n🎯 TEST RESULTS SUMMARY")
    print("=" * 30)
    
    passed = sum(tests)
    total = len(tests)
    
    print(f"✅ Passed: {passed}/{total}")
    print(f"❌ Failed: {total - passed}/{total}")
    
    if passed == total:
        print("\n🎉 ALL TESTS PASSED! Database-compatible endpoints are working!")
        print("✅ Canvas integration is ready for deployment")
        print("✅ July 7th demo mission endpoints are operational")
    else:
        print(f"\n⚠️ {total - passed} tests failed. Check deployment status.")
    
    # Additional endpoint info
    print("\n📋 AVAILABLE DATABASE-COMPATIBLE ENDPOINTS:")
    endpoints = [
        "GET  /api/system_health_check",
        "POST /api/auth_login",
        "POST /api/auth_complete_login",
        "POST /api/auth_validate_session", 
        "POST /api/auth_logout",
        "POST /api/ai_create_session",
        "POST /api/ai_secure_chat",
        "POST /api/track_site_event"
    ]
    
    for endpoint in endpoints:
        print(f"  🔗 {BASE_URL}{endpoint.split()[1]}")

if __name__ == "__main__":
    main() 