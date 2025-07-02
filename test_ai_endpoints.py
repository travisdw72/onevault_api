#!/usr/bin/env python3
"""
🤖 OneVault AI Endpoints Test Script
Tests the deployed AI endpoints on Render
"""

import requests
import json
import time

# Configuration
API_BASE = "https://onevault-api.onrender.com"
HEADERS = {
    "X-Customer-ID": "one_spa",
    "Authorization": "Bearer ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f",
    "Content-Type": "application/json"
}

def test_endpoint(endpoint, method="GET", data=None):
    """Test a single endpoint"""
    url = f"{API_BASE}{endpoint}"
    print(f"\n🧪 Testing: {method} {url}")
    
    try:
        if method == "GET":
            response = requests.get(url, headers=HEADERS, timeout=30)
        elif method == "POST":
            response = requests.post(url, headers=HEADERS, json=data, timeout=30)
        
        print(f"📊 Status Code: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ SUCCESS!")
            try:
                result = response.json()
                print(f"📋 Response Preview: {json.dumps(result, indent=2)[:500]}...")
            except:
                print(f"📄 Raw Response: {response.text[:500]}...")
        else:
            print(f"❌ FAILED: {response.status_code}")
            print(f"📄 Error: {response.text}")
        
        return response.status_code == 200
        
    except Exception as e:
        print(f"💥 EXCEPTION: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 OneVault AI Endpoints Test Suite")
    print("=" * 50)
    
    # Test basic health first
    print("\n1️⃣ BASIC HEALTH CHECKS")
    test_endpoint("/health")
    test_endpoint("/health/db")
    
    # Test AI endpoints
    print("\n2️⃣ AI AGENT ENDPOINTS")
    
    # Test AI agents status
    test_endpoint("/api/v1/ai/agents/status")
    
    # Test AI analysis
    ai_request = {
        "agent_type": "business_analysis",
        "query": "What are the key factors for business growth?",
        "context": {"test": True},
        "session_id": "test_session_001"
    }
    test_endpoint("/api/v1/ai/analyze", "POST", ai_request)
    
    # Test photo analysis
    photo_request = {
        "image_data": "base64_test_data_here",
        "image_type": "jpeg",
        "analysis_type": "horse_health",
        "session_id": "photo_test_001"
    }
    test_endpoint("/api/v1/ai/photo-analysis", "POST", photo_request)
    
    print("\n🏁 Test Suite Complete!")

if __name__ == "__main__":
    main() 