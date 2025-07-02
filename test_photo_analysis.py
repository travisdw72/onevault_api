import requests
import json

headers = {
    'X-Customer-ID': 'one_spa',
    'Authorization': 'Bearer ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f',
    'Content-Type': 'application/json'
}

photo_request = {
    'image_data': 'data:image/jpeg;base64,/9j/4AAQSkZJRgABA...',
    'image_type': 'jpeg',
    'analysis_type': 'horse_health',
    'session_id': 'photo_demo_001'
}

print('📸 Testing Photo Analysis Endpoint...')
try:
    r = requests.post('https://onevault-api.onrender.com/api/v1/ai/photo-analysis', 
                     headers=headers, json=photo_request)
    print(f'Status: {r.status_code}')
    if r.status_code == 200:
        result = r.json()
        print(f'✅ Analysis ID: {result["analysis_id"]}')
        print(f'✅ Confidence: {result["confidence_score"]}')
        print(f'✅ Processing Time: {result["processing_time_ms"]}ms')
        print(f'📝 Analysis Preview: {result["analysis_result"][:200]}...')
    else:
        print(f'❌ Error: {r.text}')
except Exception as e:
    print(f'❌ Exception: {e}') 