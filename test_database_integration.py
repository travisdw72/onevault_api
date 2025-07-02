#!/usr/bin/env python3
"""
🔥 Test Database Integration - Verify AI endpoints store data
"""

import requests
import json
import time

API_BASE = "https://onevault-api.onrender.com"
HEADERS = {
    "X-Customer-ID": "one_spa",
    "Authorization": "Bearer ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f",
    "Content-Type": "application/json"
}

def test_ai_analyze_with_db_storage():
    """Test that AI analyze endpoint stores data in database"""
    print("🧪 TESTING AI ANALYZE WITH DATABASE STORAGE")
    print("=" * 50)
    
    url = f"{API_BASE}/api/v1/ai/analyze"
    
    test_cases = [
        {
            "agent_type": "business_analysis",
            "query": "DATABASE TEST: What's our market position?",
            "context": {"test": "database_integration_test"},
            "session_id": f"db_test_business_{int(time.time())}"
        },
        {
            "agent_type": "data_science", 
            "query": "DATABASE TEST: Analyze our customer data trends",
            "context": {"test": "database_integration_test"},
            "session_id": f"db_test_data_{int(time.time())}"
        },
        {
            "agent_type": "customer_insight",
            "query": "DATABASE TEST: What are customer satisfaction levels?",
            "context": {"test": "database_integration_test"},
            "session_id": f"db_test_insight_{int(time.time())}"
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n🔍 Test {i}: {test_case['agent_type']}")
        
        response = requests.post(url, headers=HEADERS, json=test_case)
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ API Response: {data['agent_id']} - {data['confidence']}")
            print(f"📝 Session ID: {data['session_id']}")
            print(f"⏱️ Processing Time: {data['processing_time_ms']}ms")
        else:
            print(f"❌ Failed: {response.status_code} - {response.text}")
        
        time.sleep(1)  # Brief pause between requests

def test_photo_analysis_with_db_storage():
    """Test that photo analysis endpoint stores data in database"""
    print("\n\n📸 TESTING PHOTO ANALYSIS WITH DATABASE STORAGE")
    print("=" * 50)
    
    url = f"{API_BASE}/api/v1/ai/photo-analysis"
    
    test_data = {
        "image_data": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k=",
        "image_type": "jpeg",
        "analysis_type": "DATABASE_TEST",
        "session_id": f"db_test_photo_{int(time.time())}"
    }
    
    response = requests.post(url, headers=HEADERS, json=test_data)
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Photo Analysis: {data['analysis_id']}")
        print(f"🎯 Confidence: {data['confidence_score']}")
        print(f"📝 Session ID: {data['session_id']}")
        print(f"⏱️ Processing Time: {data['processing_time_ms']}ms")
    else:
        print(f"❌ Failed: {response.status_code} - {response.text}")

def main():
    print("🔥 TESTING DATABASE INTEGRATION")
    print("Testing if AI endpoints now store interactions in database")
    print("=" * 60)
    
    # Test API health first
    health_response = requests.get(f"{API_BASE}/health")
    if health_response.status_code != 200:
        print("❌ API is not responding. Check deployment status.")
        return
    
    print("✅ API is responding")
    
    # Test AI endpoints with database storage
    test_ai_analyze_with_db_storage()
    test_photo_analysis_with_db_storage()
    
    print("\n" + "=" * 60)
    print("🎯 NEXT STEPS:")
    print("1. Run database query to check if data was stored")
    print("2. Use: python check_database_data.py")
    print("3. Look for recent AI interactions with 'DATABASE TEST' in queries")

if __name__ == "__main__":
    main() 