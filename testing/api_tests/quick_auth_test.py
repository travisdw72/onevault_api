#!/usr/bin/env python3
"""
Quick Authentication Diagnostic Script
=====================================
Tests OneVault API authentication endpoints to identify issues
"""
import requests
import json
from datetime import datetime

# API Configuration
API_BASE_URL = "https://onevault-api.onrender.com"

def test_health_endpoints():
    """Test basic health endpoints"""
    print("🩺 TESTING HEALTH ENDPOINTS")
    print("=" * 50)
    
    endpoints = [
        ("/", "Basic Health"),
        ("/health", "Health Check"),
        ("/health/db", "Database Health")
    ]
    
    for endpoint, description in endpoints:
        try:
            print(f"\n📍 Testing: {description}")
            response = requests.get(f"{API_BASE_URL}{endpoint}", timeout=10)
            print(f"   Status: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                print(f"   ✅ SUCCESS")
                if endpoint == "/health/db":
                    # Special handling for database health
                    print(f"   Database: {data.get('database_connection', 'unknown')}")
                    print(f"   Schemas: {data.get('schemas_found', [])}")
                    print(f"   Auth Function Exists: {data.get('api_function_exists', False)}")
            else:
                print(f"   ❌ FAILED: {response.text[:200]}")
                
        except Exception as e:
            print(f"   ❌ ERROR: {e}")

def test_auth_login():
    """Test authentication login endpoint"""
    print("\n🔑 TESTING AUTHENTICATION LOGIN")
    print("=" * 50)
    
    # Test data - using common test credentials
    test_cases = [
        {
            "name": "Travis Login Test",
            "data": {
                "username": "travisdwoodward72@gmail.com",
                "password": "MySecurePassword321"
            }
        },
        {
            "name": "Spa Login Test", 
            "data": {
                "username": "travis@theonespaoregon.com",
                "password": "!@m1cor1013oS"
            }
        }
    ]
    
    for test_case in test_cases:
        print(f"\n📍 Testing: {test_case['name']}")
        try:
            response = requests.post(
                f"{API_BASE_URL}/api/v1/auth/login",
                headers={"Content-Type": "application/json"},
                json=test_case['data'],
                timeout=15
            )
            
            print(f"   Status: {response.status_code}")
            print(f"   Response: {response.text[:300]}")
            
            if response.status_code == 200:
                print("   ✅ LOGIN ENDPOINT WORKING")
            elif response.status_code == 501:
                print("   ❌ DATABASE FUNCTION NOT FOUND")
                print("   → api.auth_login() function missing from database")
            elif response.status_code == 500:
                print("   ❌ INTERNAL SERVER ERROR")
                print("   → Check database connection or function errors")
            elif response.status_code == 422:
                print("   ❌ VALIDATION ERROR")
                print("   → Check request format")
            else:
                print(f"   ❌ UNEXPECTED ERROR: {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ CONNECTION ERROR: {e}")

def test_complete_login():
    """Test complete login endpoint"""
    print("\n🔐 TESTING COMPLETE LOGIN")
    print("=" * 50)
    
    test_data = {
        "username": "test@example.com",
        "tenant_id": "test_tenant"
    }
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/api/v1/auth/complete-login",
            headers={"Content-Type": "application/json"},
            json=test_data,
            timeout=15
        )
        
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text[:300]}")
        
        if response.status_code == 501:
            print("❌ api.auth_complete_login() function missing from database")
        elif response.status_code == 500:
            print("❌ Database error or function issue")
        
    except Exception as e:
        print(f"❌ ERROR: {e}")

def test_session_validate():
    """Test session validation endpoint"""
    print("\n🛡️ TESTING SESSION VALIDATION")
    print("=" * 50)
    
    test_data = {
        "session_token": "test_token_123"
    }
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/api/v1/auth/validate",
            headers={"Content-Type": "application/json"},
            json=test_data,
            timeout=15
        )
        
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text[:300]}")
        
        if response.status_code == 501:
            print("❌ api.auth_validate_session() function missing from database")
        
    except Exception as e:
        print(f"❌ ERROR: {e}")

def main():
    """Run all diagnostic tests"""
    print("🧪 ONEVAULT API AUTHENTICATION DIAGNOSTICS")
    print("=" * 60)
    print(f"Testing API: {API_BASE_URL}")
    print(f"Timestamp: {datetime.now().isoformat()}")
    
    # Run tests in order
    test_health_endpoints()
    test_auth_login()
    test_complete_login()
    test_session_validate()
    
    print("\n📋 DIAGNOSTIC SUMMARY")
    print("=" * 60)
    print("1. If health/db shows 'api_function_exists: false':")
    print("   → Database functions not deployed - need to run migration scripts")
    print("\n2. If auth endpoints return 501 errors:")
    print("   → Specific auth functions missing from database")
    print("\n3. If auth endpoints return 500 errors:")
    print("   → Database connection issues or function runtime errors")
    print("\n4. If validation errors (422):")
    print("   → Request format issues - check Pydantic models")
    
    print(f"\n🎯 NEXT STEPS:")
    print("Run this diagnostic, then we'll fix the specific issues found!")

if __name__ == "__main__":
    main() 