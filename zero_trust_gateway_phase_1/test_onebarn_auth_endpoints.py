#!/usr/bin/env python3
"""
Test the specific oneBarn authentication endpoints that are known to work
"""
import requests
import json
from datetime import datetime

def test_onebarn_auth_endpoints():
    """Test the actual working oneBarn authentication endpoints"""
    print("🎯 OneBarn Authentication Endpoints Test")
    print("=" * 50)
    
    # Production API details
    base_url = "https://onevault-api.onrender.com"
    production_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
    customer_id = 'one_barn_ai'
    
    # Headers for authenticated requests
    auth_headers = {
        'Authorization': f'Bearer {production_token}',
        'Content-Type': 'application/json',
        'X-Customer-ID': customer_id,
        'User-Agent': 'OneVault-OneBarn/1.0'
    }
    
    # Headers for login (no token needed)
    login_headers = {
        'Content-Type': 'application/json',
        'X-Customer-ID': customer_id,
        'User-Agent': 'OneVault-OneBarn/1.0'
    }
    
    print(f"🌐 Testing against: {base_url}")
    print(f"🔑 Token: {production_token[:20]}...")
    print(f"🏢 Customer: {customer_id}")
    print()
    
    # Test the specific endpoints from oneBarn
    test_cases = [
        {
            'name': 'Token Validation (Short Path)',
            'url': f'{base_url}/validate',
            'methods': ['GET', 'POST', 'PUT'],
            'headers': auth_headers,
            'description': 'Direct validate endpoint'
        },
        {
            'name': 'Token Validation (API v1)',
            'url': f'{base_url}/api/v1/auth/validate',
            'methods': ['GET', 'POST', 'PUT'],
            'headers': auth_headers,
            'description': 'Full API v1 validate endpoint'
        },
        {
            'name': 'Login Endpoint',
            'url': f'{base_url}/api/v1/auth/login',
            'methods': ['POST'],
            'headers': login_headers,
            'description': 'Authentication login endpoint',
            'payload': {
                'email': 'api@onevault.com',
                'password': 'test123',
                'tenant_id': customer_id
            }
        }
    ]
    
    results = []
    
    for test_case in test_cases:
        print(f"🧪 Testing {test_case['name']}: {test_case['description']}")
        
        for method in test_case['methods']:
            try:
                print(f"   🔍 Trying {method}...")
                
                # Prepare request parameters
                request_params = {
                    'url': test_case['url'],
                    'headers': test_case['headers'],
                    'timeout': 10
                }
                
                # Add payload for POST requests
                if method == 'POST' and test_case.get('payload'):
                    request_params['json'] = test_case['payload']
                elif method == 'POST':
                    request_params['json'] = {}
                
                # Make the request
                if method == 'GET':
                    response = requests.get(**request_params)
                elif method == 'POST':
                    response = requests.post(**request_params)
                elif method == 'PUT':
                    response = requests.put(**request_params)
                
                result = {
                    'test_name': test_case['name'],
                    'method': method,
                    'url': test_case['url'],
                    'status_code': response.status_code,
                    'success': response.status_code < 400,
                    'timestamp': datetime.now().isoformat()
                }
                
                if response.status_code == 200:
                    print(f"      ✅ SUCCESS: {response.status_code}")
                    try:
                        data = response.json()
                        result['response_data'] = data
                        print(f"      📊 Response: {json.dumps(data, indent=10)[:300]}...")
                        
                        # Check if this is a successful token validation
                        if 'valid' in data or 'authenticated' in data or 'user' in data:
                            print(f"      🎉 TOKEN VALIDATION SUCCESS!")
                            result['token_validation_success'] = True
                            
                    except:
                        result['response_text'] = response.text[:200]
                        print(f"      📄 Response: {response.text[:150]}...")
                        
                elif response.status_code == 401:
                    print(f"      🔐 UNAUTHORIZED: {response.status_code}")
                    result['auth_required'] = True
                    try:
                        error_data = response.json()
                        result['error_details'] = error_data
                        print(f"      💡 Error: {error_data}")
                    except:
                        print(f"      💡 Error: {response.text[:100]}")
                        
                elif response.status_code == 403:
                    print(f"      🚫 FORBIDDEN: {response.status_code}")
                    result['permission_error'] = True
                    
                elif response.status_code == 404:
                    print(f"      🔍 NOT FOUND: {response.status_code}")
                    result['endpoint_missing'] = True
                    
                elif response.status_code == 405:
                    print(f"      ⚠️  METHOD NOT ALLOWED: {response.status_code}")
                    result['wrong_method'] = True
                    allowed_methods = response.headers.get('allow', '')
                    if allowed_methods:
                        print(f"      💡 Allowed methods: {allowed_methods}")
                        result['allowed_methods'] = allowed_methods
                        
                elif response.status_code == 422:
                    print(f"      📝 VALIDATION ERROR: {response.status_code}")
                    result['validation_error'] = True
                    try:
                        error_data = response.json()
                        result['validation_details'] = error_data
                        print(f"      💡 Validation details: {error_data}")
                    except:
                        print(f"      💡 Validation error: {response.text[:100]}")
                        
                else:
                    print(f"      ⚠️  UNEXPECTED: {response.status_code}")
                    result['unexpected_status'] = True
                    result['error_message'] = response.text[:200]
                
                results.append(result)
                
                # If we got a successful response, no need to try other methods
                if response.status_code == 200:
                    print(f"      🎯 Found working method: {method}")
                    break
                    
            except requests.exceptions.ConnectionError:
                print(f"      🔌 CONNECTION ERROR")
                result = {
                    'test_name': test_case['name'],
                    'method': method,
                    'url': test_case['url'],
                    'error': 'CONNECTION_ERROR',
                    'success': False
                }
                results.append(result)
                
            except requests.exceptions.Timeout:
                print(f"      ⏰ TIMEOUT")
                result = {
                    'test_name': test_case['name'],
                    'method': method,
                    'url': test_case['url'],
                    'error': 'TIMEOUT',
                    'success': False
                }
                results.append(result)
                
            except Exception as e:
                print(f"      ❌ ERROR: {str(e)}")
                result = {
                    'test_name': test_case['name'],
                    'method': method,
                    'url': test_case['url'],
                    'error': str(e),
                    'success': False
                }
                results.append(result)
        
        print()
    
    # Analysis
    print("🎯 ANALYSIS")
    print("=" * 20)
    
    successful_tests = [r for r in results if r.get('success', False)]
    token_validation_success = [r for r in results if r.get('token_validation_success', False)]
    
    print(f"✅ Successful requests: {len(successful_tests)}")
    print(f"🔑 Token validations: {len(token_validation_success)}")
    
    if token_validation_success:
        print("\n🎉 TOKEN VALIDATION WORKING!")
        for test in token_validation_success:
            print(f"   ✅ {test['method']} {test['test_name']}: {test['status_code']}")
            if 'response_data' in test:
                print(f"      📊 Data: {test['response_data']}")
        
        print("\n🚀 ZERO TRUST MIDDLEWARE INTEGRATION:")
        print("   Your Zero Trust middleware can now integrate with these working endpoints!")
        
    elif successful_tests:
        print("\n✅ ENDPOINTS WORKING:")
        for test in successful_tests:
            print(f"   ✅ {test['method']} {test['test_name']}: {test['status_code']}")
    else:
        print("\n🔧 NEXT STEPS:")
        print("   1. Check if endpoints need different authentication")
        print("   2. Verify token format/structure")
        print("   3. Check API documentation")
    
    # Check for method errors
    method_errors = [r for r in results if r.get('wrong_method', False)]
    if method_errors:
        print("\n💡 METHOD SUGGESTIONS:")
        for error in method_errors:
            if 'allowed_methods' in error:
                print(f"   🔄 {error['url']}: Try {error['allowed_methods']}")
    
    # Save detailed results
    with open('onebarn_auth_test_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n📄 Detailed results saved to: onebarn_auth_test_results.json")
    
    return results

if __name__ == "__main__":
    results = test_onebarn_auth_endpoints()
    
    # Quick summary
    success_count = len([r for r in results if r.get('success', False)])
    total_count = len(results)
    
    print(f"\n📈 FINAL SUMMARY: {success_count}/{total_count} successful")
    
    if success_count > 0:
        print("🎉 Your production token and endpoints are working!")
        print("🚀 Ready to integrate Zero Trust middleware!")
    else:
        print("🔧 Need to investigate authentication requirements further") 