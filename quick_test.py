import requests

headers = {
    'X-Customer-ID': 'one_spa',
    'Authorization': 'Bearer ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f'
}

print('Testing existing endpoints...')

# Test platform info
try:
    r = requests.get('https://onevault-api.onrender.com/api/v1/platform/info', headers=headers)
    print(f'Platform info: {r.status_code}')
    if r.status_code == 200:
        print(f'Response: {r.json()}')
except Exception as e:
    print(f'Platform error: {e}')

# Test customer config  
try:
    r = requests.get('https://onevault-api.onrender.com/api/v1/customer/config', headers=headers)
    print(f'Customer config: {r.status_code}')
    if r.status_code == 200:
        print(f'Response preview: {str(r.json())[:200]}...')
except Exception as e:
    print(f'Config error: {e}')

# Test our AI endpoint (should be 404 if not deployed)
try:
    r = requests.get('https://onevault-api.onrender.com/api/v1/ai/agents/status', headers=headers)
    print(f'AI agents: {r.status_code}')
    if r.status_code == 200:
        print('🎉 AI ENDPOINTS ARE LIVE!')
        print(f'Response: {r.json()}')
    else:
        print('❌ AI endpoints still not deployed')
except Exception as e:
    print(f'AI endpoint error: {e}') 