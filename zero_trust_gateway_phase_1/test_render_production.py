#!/usr/bin/env python3
"""
Test the production token against the ACTUAL Render production API
"""
import requests
import json
import time
from datetime import datetime

def test_render_production_api():
    """Test the real production token against the actual Render API"""
    print("🎯 Render Production API Token Test")
    print("=" * 50)
    
    # Production API details from your .env
    api_base_url = "https://onevault-api.onrender.com"
    production_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
    customer_id = 'one_barn_ai'
    
    headers = {
        'Authorization': f'Bearer {production_token}',
        'Content-Type': 'application/json',
        'X-Customer-ID': customer_id,
        'User-Agent': 'OneVault-ZeroTrust/1.0'
    }
    
    print(f"🌐 Testing against: {api_base_url}")
    print(f"🔑 Token: {production_token[:20]}...")
    print(f"🏢 Customer: {customer_id}")
    print()
    
    # Test endpoints in order of complexity
    test_endpoints = [
        {
            'name': 'Health Check',
            'method': 'GET',
            'url': f'{api_base_url}/health',
            'description': 'Basic API availability'
        },
        {
            'name': 'Token Validation',
            'method': 'GET', 
            'url': f'{api_base_url}/api/v1/auth/validate',
            'description': 'Token authentication check'
        },
        {
            'name': 'User Profile',
            'method': 'GET',
            'url': f'{api_base_url}/api/v1/auth/me',
            'description': 'Current user information'
        },
        {
            'name': 'Canvas Workflows',
            'method': 'GET',
            'url': f'{api_base_url}/api/v1/canvas/workflows',
            'description': 'Available workflows'
        },
        {
            'name': 'AI Agents',
            'method': 'GET', 
            'url': f'{api_base_url}/api/v1/ai/agents',
            'description': 'Available AI agents'
        }
    ]
    
    results = []
    
    for test in test_endpoints:
        print(f"🧪 Testing {test['name']}: {test['description']}")
        
        try:
            start_time = time.time()
            
            if test['method'] == 'GET':
                response = requests.get(test['url'], headers=headers, timeout=10)
            elif test['method'] == 'POST':
                response = requests.post(test['url'], headers=headers, json={}, timeout=10)
            
            end_time = time.time()
            response_time = round((end_time - start_time) * 1000, 2)
            
            result = {
                'endpoint': test['name'],
                'url': test['url'],
                'status_code': response.status_code,
                'response_time_ms': response_time,
                'success': response.status_code < 400,
                'timestamp': datetime.now().isoformat()
            }
            
            if response.status_code == 200:
                print(f"   ✅ SUCCESS: {response.status_code} ({response_time}ms)")
                try:
                    data = response.json()
                    result['response_data'] = data
                    print(f"   📊 Response: {json.dumps(data, indent=6)[:200]}...")
                except:
                    result['response_text'] = response.text[:200]
                    print(f"   📄 Response: {response.text[:100]}...")
                    
            elif response.status_code == 401:
                print(f"   🔐 AUTH REQUIRED: {response.status_code}")
                result['auth_error'] = True
                
            elif response.status_code == 403:
                print(f"   🚫 FORBIDDEN: {response.status_code}")
                result['permission_error'] = True
                
            elif response.status_code == 404:
                print(f"   🔍 NOT FOUND: {response.status_code}")
                result['endpoint_missing'] = True
                
            else:
                print(f"   ⚠️  UNEXPECTED: {response.status_code}")
                result['error_message'] = response.text[:200]
                
        except requests.exceptions.ConnectionError:
            print(f"   🔌 CONNECTION ERROR: Cannot reach {api_base_url}")
            result = {
                'endpoint': test['name'],
                'url': test['url'],
                'error': 'CONNECTION_ERROR',
                'success': False
            }
            
        except requests.exceptions.Timeout:
            print(f"   ⏰ TIMEOUT: Request took longer than 10 seconds")
            result = {
                'endpoint': test['name'],
                'url': test['url'],
                'error': 'TIMEOUT',
                'success': False
            }
            
        except Exception as e:
            print(f"   ❌ ERROR: {str(e)}")
            result = {
                'endpoint': test['name'],
                'url': test['url'],
                'error': str(e),
                'success': False
            }
        
        results.append(result)
        print()
    
    # Summary
    print("🎯 TEST SUMMARY")
    print("=" * 30)
    
    successful_tests = [r for r in results if r.get('success', False)]
    failed_tests = [r for r in results if not r.get('success', False)]
    
    print(f"✅ Successful: {len(successful_tests)}")
    print(f"❌ Failed: {len(failed_tests)}")
    print(f"📊 Success Rate: {len(successful_tests)}/{len(results)} ({len(successful_tests)/len(results)*100:.1f}%)")
    
    if successful_tests:
        print("\n🎉 WORKING ENDPOINTS:")
        for test in successful_tests:
            print(f"   ✅ {test['endpoint']}: {test['status_code']} ({test.get('response_time_ms', 'N/A')}ms)")
    
    if failed_tests:
        print("\n🔧 NEEDS ATTENTION:")
        for test in failed_tests:
            error_type = test.get('error', 'HTTP_ERROR')
            print(f"   ❌ {test['endpoint']}: {error_type}")
    
    print()
    
    # Token validation conclusion
    auth_working = any(r.get('success') and r['endpoint'] in ['Token Validation', 'User Profile'] for r in results)
    
    if auth_working:
        print("🎉 TOKEN VALIDATION: ✅ YOUR TOKEN IS WORKING!")
        print("🚀 Zero Trust middleware should work perfectly on Render!")
    else:
        print("🔐 TOKEN VALIDATION: ⚠️  Authentication endpoints not responding")
        print("   This could mean:")
        print("   - Token is expired")
        print("   - Endpoints are different")
        print("   - API is down")
    
    return results

if __name__ == "__main__":
    results = test_render_production_api()
    
    # Save results for analysis
    with open('render_production_test_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n📄 Results saved to: render_production_test_results.json") 