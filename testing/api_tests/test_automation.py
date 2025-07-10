#!/usr/bin/env python3
"""
Site Tracking Automation API Test Script
========================================
Tests the new automated site tracking endpoints to ensure they work correctly.
"""

import requests
import json
import time
from datetime import datetime
from typing import Dict, Any

# Configuration
API_BASE_URL = "http://localhost:8000"  # Change for production
CUSTOMER_ID = "one_spa"
API_TOKEN = "ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f"

# Headers for all requests
HEADERS = {
    "X-Customer-ID": CUSTOMER_ID,
    "Authorization": f"Bearer {API_TOKEN}",
    "Content-Type": "application/json"
}

def print_section(title: str):
    """Print a formatted section header"""
    print(f"\n{'='*60}")
    print(f"🧪 {title}")
    print(f"{'='*60}")

def print_result(test_name: str, success: bool, details: str = ""):
    """Print test result"""
    status = "✅ PASS" if success else "❌ FAIL"
    print(f"{status} {test_name}")
    if details:
        print(f"   {details}")

def test_health_check():
    """Test basic health check"""
    print_section("Health Check Tests")
    
    try:
        response = requests.get(f"{API_BASE_URL}/health")
        success = response.status_code == 200
        print_result("Basic Health Check", success, f"Status: {response.status_code}")
        
        if success:
            data = response.json()
            print(f"   Service: {data.get('service')}")
            print(f"   Status: {data.get('status')}")
        
        return success
    except Exception as e:
        print_result("Basic Health Check", False, f"Error: {e}")
        return False

def test_database_health():
    """Test database connectivity"""
    try:
        response = requests.get(f"{API_BASE_URL}/health/db")
        success = response.status_code == 200
        print_result("Database Health Check", success, f"Status: {response.status_code}")
        
        if success:
            data = response.json()
            print(f"   Database: {data.get('database')}")
            print(f"   Track Site Event Available: {data.get('auth_functions_available', {}).get('track_site_event', False)}")
        
        return success
    except Exception as e:
        print_result("Database Health Check", False, f"Error: {e}")
        return False

def send_test_event(event_type: str = "test_automation", endpoint: str = "/api/v1/track") -> Dict[str, Any]:
    """Send a test site tracking event"""
    event_data = {
        "page_url": f"http://localhost/test/automation/{int(time.time())}",
        "event_type": event_type,
        "event_data": {
            "test_id": f"automation_test_{int(time.time())}",
            "timestamp": datetime.utcnow().isoformat(),
            "automation": True,
            "endpoint_used": endpoint
        }
    }
    
    try:
        response = requests.post(
            f"{API_BASE_URL}{endpoint}",
            headers=HEADERS,
            json=event_data
        )
        
        return {
            "success": response.status_code == 200,
            "status_code": response.status_code,
            "data": response.json() if response.status_code == 200 else None,
            "error": response.text if response.status_code != 200 else None
        }
    except Exception as e:
        return {
            "success": False,
            "status_code": 0,
            "data": None,
            "error": str(e)
        }

def test_automatic_processing():
    """Test the automatic processing endpoint"""
    print_section("Automatic Processing Tests")
    
    # Send test event with automatic processing
    result = send_test_event("automatic_test", "/api/v1/track")
    
    success = result["success"]
    print_result("Send Event with Automatic Processing", success, 
                f"Status: {result['status_code']}")
    
    if success and result["data"]:
        data = result["data"]
        print(f"   Event ID: {data.get('event_id')}")
        print(f"   Processing: {data.get('processing')}")
        print(f"   Message: {data.get('message')}")
        
        # Check if processing is marked as automatic
        processing_automatic = data.get('processing') == 'automatic'
        print_result("Processing Mode Set to Automatic", processing_automatic)
        
        return True
    else:
        print(f"   Error: {result.get('error')}")
        return False

def test_background_processing():
    """Test the background processing endpoint"""
    print_section("Background Processing Tests")
    
    # Send test event with background processing
    result = send_test_event("background_test", "/api/v1/track/async")
    
    success = result["success"]
    print_result("Send Event with Background Processing", success, 
                f"Status: {result['status_code']}")
    
    if success and result["data"]:
        data = result["data"]
        print(f"   Event ID: {data.get('event_id')}")
        print(f"   Processing: {data.get('processing')}")
        print(f"   Message: {data.get('message')}")
        
        # Check if processing is marked as background
        processing_background = data.get('processing') == 'background'
        print_result("Processing Mode Set to Background", processing_background)
        
        return True
    else:
        print(f"   Error: {result.get('error')}")
        return False

def test_status_endpoint():
    """Test the status monitoring endpoint"""
    print_section("Status Monitoring Tests")
    
    try:
        response = requests.get(
            f"{API_BASE_URL}/api/v1/track/status",
            headers=HEADERS
        )
        
        success = response.status_code == 200
        print_result("Get Tracking Status", success, f"Status: {response.status_code}")
        
        if success:
            data = response.json()
            print(f"   Pipeline Status Available: {data.get('pipeline_status') is not None}")
            print(f"   Recent Events Count: {len(data.get('recent_events', []))}")
            
            # Show recent events
            recent_events = data.get('recent_events', [])
            if recent_events:
                print(f"   Latest Event: {recent_events[0].get('raw_event_type', 'Unknown')}")
        
        return success
    except Exception as e:
        print_result("Get Tracking Status", False, f"Error: {e}")
        return False

def test_dashboard_endpoint():
    """Test the dashboard endpoint"""
    print_section("Dashboard Tests")
    
    try:
        response = requests.get(
            f"{API_BASE_URL}/api/v1/track/dashboard",
            headers=HEADERS,
            params={"limit": 5}
        )
        
        success = response.status_code == 200
        print_result("Get Dashboard Data", success, f"Status: {response.status_code}")
        
        if success:
            data = response.json()
            summary = data.get('summary', {})
            print(f"   Total Events: {summary.get('total_events', 0)}")
            print(f"   Processed to Staging: {summary.get('processed_to_staging', 0)}")
            print(f"   Processed to Business: {summary.get('processed_to_business', 0)}")
            print(f"   Latest Event: {summary.get('latest_event', 'None')}")
        
        return success
    except Exception as e:
        print_result("Get Dashboard Data", False, f"Error: {e}")
        return False

def test_manual_trigger():
    """Test manual processing trigger"""
    print_section("Manual Trigger Tests")
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/api/v1/track/process",
            headers=HEADERS
        )
        
        success = response.status_code == 200
        print_result("Manual Processing Trigger", success, f"Status: {response.status_code}")
        
        if success:
            data = response.json()
            print(f"   Message: {data.get('message')}")
            print(f"   Result: {data.get('result')}")
        
        return success
    except Exception as e:
        print_result("Manual Processing Trigger", False, f"Error: {e}")
        return False

def run_comprehensive_test():
    """Run all tests and provide summary"""
    print_section("🚀 Site Tracking Automation API Test Suite")
    print(f"Testing API at: {API_BASE_URL}")
    print(f"Customer ID: {CUSTOMER_ID}")
    print(f"Timestamp: {datetime.utcnow().isoformat()}")
    
    tests = [
        ("Health Check", test_health_check),
        ("Database Health", test_database_health),
        ("Automatic Processing", test_automatic_processing),
        ("Background Processing", test_background_processing),
        ("Status Monitoring", test_status_endpoint),
        ("Dashboard Data", test_dashboard_endpoint),
        ("Manual Trigger", test_manual_trigger)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print_result(test_name, False, f"Exception: {e}")
            results.append((test_name, False))
        
        # Small delay between tests
        time.sleep(1)
    
    # Summary
    print_section("📊 Test Results Summary")
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"{status} {test_name}")
    
    print(f"\n🎯 Overall Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 ALL TESTS PASSED! Site tracking automation is working correctly.")
    else:
        print("⚠️  Some tests failed. Please check the API configuration and database connectivity.")
    
    return passed == total

if __name__ == "__main__":
    run_comprehensive_test() 