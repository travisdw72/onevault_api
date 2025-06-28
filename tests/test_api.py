#!/usr/bin/env python3
"""
Test script to debug OneVault API tracking endpoint
"""
import requests
import json

# Your API configuration
API_BASE_URL = "https://your-render-domain.onrender.com"  # Replace with your actual Render URL
# API_BASE_URL = "http://localhost:8000"  # For local testing

API_TOKEN = "ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f"
CUSTOMER_ID = "one_spa"

def test_health_endpoints():
    """Test all health endpoints"""
    print("🩺 Testing Health Endpoints")
    print("-" * 30)
    
    endpoints = [
        "/health",
        "/health/detailed", 
        "/health/customer/one_spa",
        "/api/v1/platform/info"
    ]
    
    for endpoint in endpoints:
        try:
            response = requests.get(f"{API_BASE_URL}{endpoint}", timeout=10)
            print(f"✅ {endpoint}: {response.status_code}")
            if response.status_code != 200:
                print(f"   Error: {response.text}")
        except Exception as e:
            print(f"❌ {endpoint}: {e}")

def test_customer_config():
    """Test customer config endpoint (requires auth)"""
    print("\n🔧 Testing Customer Config Endpoint")
    print("-" * 40)
    
    headers = {
        "Authorization": f"Bearer {API_TOKEN}",
        "X-Customer-ID": CUSTOMER_ID,
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.get(
            f"{API_BASE_URL}/api/v1/customer/config",
            headers=headers,
            timeout=10
        )
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            print("✅ Customer config endpoint working")
            print(f"Response: {response.json()}")
        else:
            print(f"❌ Error: {response.text}")
    except Exception as e:
        print(f"❌ Exception: {e}")

def test_tracking_endpoint():
    """Test the main tracking endpoint that's failing"""
    print("\n📊 Testing Site Tracking Endpoint")
    print("-" * 40)
    
    headers = {
        "Authorization": f"Bearer {API_TOKEN}",
        "X-Customer-ID": CUSTOMER_ID,
        "Content-Type": "application/json"
    }
    
    # Test data
    test_event = {
        "page_url": "https://test-site.com/page",
        "event_type": "page_view",
        "event_data": {
            "test": True,
            "source": "api_test"
        }
    }
    
    try:
        print(f"Sending POST to: {API_BASE_URL}/api/v1/track")
        print(f"Headers: {headers}")
        print(f"Data: {test_event}")
        
        response = requests.post(
            f"{API_BASE_URL}/api/v1/track",
            headers=headers,
            json=test_event,
            timeout=30
        )
        
        print(f"\nResponse Status: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        print(f"Response Body: {response.text}")
        
        if response.status_code == 200:
            print("✅ Tracking endpoint working!")
            result = response.json()
            print(f"Event ID: {result.get('event_id')}")
        elif response.status_code == 500:
            print("❌ 500 Internal Server Error - Database function issue")
            print("This confirms the database function doesn't exist or has an error")
        elif response.status_code == 401:
            print("❌ 401 Unauthorized - Authentication issue")
        elif response.status_code == 400:
            print("❌ 400 Bad Request - Missing headers or invalid data")
        else:
            print(f"❌ Unexpected status code: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Exception: {e}")

def test_minimal_tracking():
    """Test with minimal data to isolate the issue"""
    print("\n🔬 Testing Minimal Tracking Data")
    print("-" * 40)
    
    headers = {
        "Authorization": f"Bearer {API_TOKEN}",
        "X-Customer-ID": CUSTOMER_ID,
        "Content-Type": "application/json"
    }
    
    # Minimal test data
    minimal_event = {
        "page_url": "https://test.com",
        "event_type": "test"
    }
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/api/v1/track",
            headers=headers,
            json=minimal_event,
            timeout=30
        )
        
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
        
    except Exception as e:
        print(f"❌ Exception: {e}")

if __name__ == "__main__":
    print("🧪 OneVault API Test Suite")
    print("=" * 50)
    print(f"Testing API at: {API_BASE_URL}")
    
    # Update this with your actual Render URL
    if "your-render-domain" in API_BASE_URL:
        print("⚠️  Please update API_BASE_URL with your actual Render domain!")
        exit(1)
    
    test_health_endpoints()
    test_customer_config() 
    test_tracking_endpoint()
    test_minimal_tracking()
    
    print("\n💡 Next Steps:")
    print("1. If health endpoints work but tracking fails with 500:")
    print("   → Database function api.track_site_event() doesn't exist")
    print("2. If tracking fails with 401:")
    print("   → Check API token and headers")
    print("3. If tracking fails with 400:")
    print("   → Check required headers (X-Customer-ID, Authorization)") 