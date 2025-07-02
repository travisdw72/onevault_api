import requests
import json

headers = {
    'X-Customer-ID': 'one_spa',
    'Authorization': 'Bearer ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f',
    'Content-Type': 'application/json'
}

print('🤖 Testing AI Analysis Endpoints...\n')

# Test Business Analysis Agent
business_request = {
    "agent_type": "business_analysis",
    "query": "What are the key factors for business growth in the spa industry?",
    "context": {"demo": True},
    "session_id": "test_business_001"
}

print('1️⃣ Testing Business Analysis Agent (BAA-001)...')
try:
    r = requests.post('https://onevault-api.onrender.com/api/v1/ai/analyze', 
                     headers=headers, json=business_request)
    print(f'Status: {r.status_code}')
    if r.status_code == 200:
        result = r.json()
        print(f'✅ Agent ID: {result["agent_id"]}')
        print(f'✅ Confidence: {result["confidence"]}')
        print(f'✅ Processing Time: {result["processing_time_ms"]}ms')
        print(f'📝 Response Preview: {result["response"][:200]}...\n')
    else:
        print(f'❌ Error: {r.text}\n')
except Exception as e:
    print(f'❌ Exception: {e}\n')

# Test Data Science Agent
data_request = {
    "agent_type": "data_science",
    "query": "Analyze customer behavior patterns and predict trends",
    "session_id": "test_data_001"
}

print('2️⃣ Testing Data Science Agent (DSA-001)...')
try:
    r = requests.post('https://onevault-api.onrender.com/api/v1/ai/analyze', 
                     headers=headers, json=data_request)
    print(f'Status: {r.status_code}')
    if r.status_code == 200:
        result = r.json()
        print(f'✅ Agent ID: {result["agent_id"]}')
        print(f'✅ Sources: {result["sources"]}')
        print(f'📝 Response Preview: {result["response"][:200]}...\n')
    else:
        print(f'❌ Error: {r.text}\n')
except Exception as e:
    print(f'❌ Exception: {e}\n')

# Test Customer Insight Agent
insight_request = {
    "agent_type": "customer_insight",
    "query": "What insights can you provide about customer satisfaction?",
    "session_id": "test_insight_001"
}

print('3️⃣ Testing Customer Insight Agent (CIA-001)...')
try:
    r = requests.post('https://onevault-api.onrender.com/api/v1/ai/analyze', 
                     headers=headers, json=insight_request)
    print(f'Status: {r.status_code}')
    if r.status_code == 200:
        result = r.json()
        print(f'✅ Agent ID: {result["agent_id"]}')
        print(f'✅ Session ID: {result["session_id"]}')
        print(f'📝 Response Preview: {result["response"][:200]}...\n')
    else:
        print(f'❌ Error: {r.text}\n')
except Exception as e:
    print(f'❌ Exception: {e}\n')

print('🏁 AI Analysis Testing Complete!') 