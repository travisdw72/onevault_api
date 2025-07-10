#!/usr/bin/env python3
"""
Test Secure Authentication Implementation
========================================
Tests the new OVT-API-Token tenant isolation security
"""
import requests
import json
from datetime import datetime

# Test against the secure API version (once deployed)
API_BASE_URL = "https://onevault-api.onrender.com"

# Sample OVT-API-Tokens (these would be real tokens from database)
SAMPLE_TOKENS = {
    "one_spa": "ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f",
    "personal_spa": "ovt_dev_abc123def456ghi789jkl012mno345pqr678stu901vwx234yzab567cdef890",
    "invalid_token": "ovt_invalid_token_should_fail"
}

def test_secure_authentication():
    """Test the secure authentication with OVT-API-Token"""
    print("🔒 TESTING SECURE AUTHENTICATION")
    print("=" * 60)
    
    test_cases = [
        {
            "name": "Valid Token + Valid User",
            "token": SAMPLE_TOKENS["one_spa"],
            "username": "travis@theonespaoregon.com",
            "password": "test_password",
            "expected": "SUCCESS",
            "description": "User logging into their own tenant"
        },
        {
            "name": "Valid Token + Cross-Tenant User",
            "token": SAMPLE_TOKENS["one_spa"],
            "username": "travisdwoodward72@gmail.com",  # Different tenant's user
            "password": "test_password",
            "expected": "BLOCKED",
            "description": "Cross-tenant attack should be blocked"
        },
        {
            "name": "Invalid Token",
            "token": SAMPLE_TOKENS["invalid_token"],
            "username": "travis@theonespaoregon.com",
            "password": "test_password", 
            "expected": "BLOCKED",
            "description": "Invalid token should be rejected"
        },
        {
            "name": "Missing Token",
            "token": None,
            "username": "travis@theonespaoregon.com", 
            "password": "test_password",
            "expected": "BLOCKED",
            "description": "Missing token should be rejected"
        }
    ]
    
    for test_case in test_cases:
        print(f"\n📍 {test_case['name']}")
        print(f"   Description: {test_case['description']}")
        print(f"   Expected: {test_case['expected']}")
        
        headers = {"Content-Type": "application/json"}
        if test_case['token']:
            headers["OVT-API-Token"] = test_case['token']
        
        try:
            response = requests.post(
                f"{API_BASE_URL}/api/v1/auth/login",
                headers=headers,
                json={
                    "username": test_case['username'],
                    "password": test_case['password']
                },
                timeout=15
            )
            
            print(f"   Status: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                security_info = data.get('security', {})
                print(f"   ✅ Authentication succeeded")
                print(f"   → Tenant: {security_info.get('tenant_name', 'Unknown')}")
                print(f"   → Token validated: {security_info.get('token_validated', False)}")
                
                if test_case['expected'] == "BLOCKED":
                    print(f"   🚨 SECURITY ISSUE: This should have been blocked!")
                else:
                    print(f"   ✅ Security working as expected")
                    
            elif response.status_code == 401:
                print(f"   🛡️ Authentication blocked (401)")
                if test_case['expected'] == "BLOCKED":
                    print(f"   ✅ Security working correctly")
                else:
                    print(f"   ❌ Unexpected block")
                    
            elif response.status_code == 403:
                print(f"   🛡️ Access forbidden (403)")
                if test_case['expected'] == "BLOCKED":
                    print(f"   ✅ Security working correctly") 
                else:
                    print(f"   ❌ Unexpected block")
                    
            else:
                print(f"   ❌ Unexpected status: {response.status_code}")
                print(f"   Response: {response.text[:200]}")
                
        except Exception as e:
            print(f"   ❌ Test error: {e}")

def test_fallback_security():
    """Test that fallback security filtering works"""
    print(f"\n🔄 TESTING FALLBACK SECURITY")
    print("=" * 60)
    
    # Test with the original insecure endpoint to show the difference
    print("\n📍 Testing original insecure endpoint")
    try:
        response = requests.post(
            f"{API_BASE_URL}/api/v1/auth/login-insecure",
            headers={"Content-Type": "application/json"},
            json={
                "username": "test@example.com",
                "password": "test_password"
            },
            timeout=15
        )
        
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"Warning: {data.get('warning', 'No warning')}")
            print(f"Security Risk: {data.get('security_risk', 'Unknown')}")
        
    except Exception as e:
        print(f"Error: {e}")

def demonstrate_attack_prevention():
    """Demonstrate how the new system prevents cross-tenant attacks"""
    print(f"\n🛡️ ATTACK PREVENTION DEMONSTRATION")
    print("=" * 60)
    
    attack_scenarios = [
        {
            "scenario": "Attacker with One Spa token tries to access personal spa user",
            "attacker_token": SAMPLE_TOKENS["one_spa"],
            "target_username": "travisdwoodward72@gmail.com",
            "expected_result": "Should be blocked by tenant verification"
        },
        {
            "scenario": "Attacker without token tries to access any user",
            "attacker_token": None,
            "target_username": "travis@theonespaoregon.com", 
            "expected_result": "Should be blocked by missing token validation"
        }
    ]
    
    for i, scenario in enumerate(attack_scenarios, 1):
        print(f"\n🎯 Attack Scenario {i}")
        print(f"   {scenario['scenario']}")
        print(f"   Expected: {scenario['expected_result']}")
        
        headers = {"Content-Type": "application/json"}
        if scenario['attacker_token']:
            headers["OVT-API-Token"] = scenario['attacker_token']
        
        try:
            response = requests.post(
                f"{API_BASE_URL}/api/v1/auth/login",
                headers=headers,
                json={
                    "username": scenario['target_username'],
                    "password": "attacker_password"
                },
                timeout=15
            )
            
            if response.status_code in [401, 403]:
                print(f"   ✅ ATTACK BLOCKED: {response.status_code}")
                print(f"   → Security system working correctly")
            elif response.status_code == 200:
                print(f"   🚨 SECURITY FAILURE: Attack succeeded!")
                print(f"   → This indicates a security vulnerability")
            else:
                print(f"   ❓ Unexpected response: {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ Test error: {e}")

def main():
    """Run all security tests"""
    print("🛡️ ONEVAULT SECURE AUTHENTICATION TESTS")
    print("=" * 60)
    print(f"Testing API: {API_BASE_URL}")
    print(f"Timestamp: {datetime.now().isoformat()}")
    
    test_secure_authentication()
    test_fallback_security()
    demonstrate_attack_prevention()
    
    print(f"\n📋 SECURITY TEST SUMMARY")
    print("=" * 60)
    print("✅ If attacks are blocked (401/403): Security is working")
    print("🚨 If attacks succeed (200): Security vulnerability exists")
    print("\n🎯 NEXT STEPS:")
    print("1. Deploy secure API version")
    print("2. Update database functions to include tenant filtering")
    print("3. Update frontend to include OVT-API-Token headers")
    print("4. Deprecate insecure endpoints")

if __name__ == "__main__":
    main() 