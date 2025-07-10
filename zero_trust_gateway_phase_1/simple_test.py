#!/usr/bin/env python3
"""
Simple test script for Zero Trust Gateway API
"""
import requests
import json

def test_endpoint(url, headers=None, description=""):
    """Test an endpoint and show detailed results"""
    print(f"\n🧪 Testing: {description}")
    print(f"   URL: {url}")
    if headers:
        print(f"   Headers: {headers}")
    
    try:
        response = requests.get(url, headers=headers or {})
        
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.text[:200]}...")
        
        if response.status_code == 200:
            print("   ✅ SUCCESS")
        else:
            print("   ❌ FAILED")
            
        return response
        
    except Exception as e:
        print(f"   💥 ERROR: {e}")
        return None

def main():
    """Run API tests"""
    base_url = "http://localhost:8000"
    
    print("🛡️ Zero Trust Gateway API Test")
    print("=" * 40)
    
    # Test 1: Health check (should work)
    test_endpoint(f"{base_url}/health", description="Health check (no auth)")
    
    # Test 2: Protected endpoint without auth (should fail with 401)
    test_endpoint(f"{base_url}/api/v1/test/basic", description="Protected endpoint without auth")
    
    # Test 3: Protected endpoint with invalid token (should fail with 401)
    test_endpoint(
        f"{base_url}/api/v1/test/basic", 
        headers={"Authorization": "Bearer invalid_token"},
        description="Protected endpoint with invalid token"
    )
    
    # Test 4: Protected endpoint with real token (should work)
    real_token = "7691a495fad262a6cff66d80d8b20ccf7f3736c7fbbd2aa234ef25cdc08f57f8"
    test_endpoint(
        f"{base_url}/api/v1/test/basic", 
        headers={"Authorization": f"Bearer {real_token}"},
        description="Protected endpoint with real token"
    )
    
    print("\n🏁 Tests complete!")

if __name__ == "__main__":
    main() 