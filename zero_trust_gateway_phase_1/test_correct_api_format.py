#!/usr/bin/env python3
"""
Test the API endpoints with the CORRECT format based on validation errors
"""
import requests
import json
from datetime import datetime

def test_correct_api_format():
    """Test with the correct API format"""
    print("🎯 Correct API Format Test")
    print("=" * 40)
    
    base_url = "https://onevault-api.onrender.com"
    production_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
    customer_id = 'one_barn_ai'
    
    headers = {
        'Content-Type': 'application/json',
        'X-Customer-ID': customer_id,
        'User-Agent': 'OneVault-CorrectFormat/1.0'
    }
    
    print(f"🌐 Testing against: {base_url}")
    print(f"🔑 Token: {production_token[:20]}...")
    print(f"🏢 Customer: {customer_id}")
    print()
    
    results = []
    
    # Test 1: Token Validation with session_token in body
    print("🧪 Test 1: Token Validation (Correct Format)")
    print("   📋 Using session_token in request body...")
    
    try:
        validation_payload = {
            'session_token': production_token
        }
        
        response = requests.post(
            f'{base_url}/api/v1/auth/validate',
            headers=headers,
            json=validation_payload,
            timeout=10
        )
        
        result = {
            'test': 'Token Validation',
            'url': f'{base_url}/api/v1/auth/validate',
            'method': 'POST',
            'payload': validation_payload,
            'status_code': response.status_code,
            'success': response.status_code == 200,
            'timestamp': datetime.now().isoformat()
        }
        
        if response.status_code == 200:
            print("   ✅ SUCCESS: Token validation working!")
            try:
                data = response.json()
                result['response_data'] = data
                print(f"   📊 Response: {json.dumps(data, indent=6)}")
                
                # Check for authentication success indicators
                if any(key in data for key in ['valid', 'authenticated', 'user', 'tenant']):
                    print("   🎉 AUTHENTICATION SUCCESS!")
                    result['authentication_success'] = True
                    
            except:
                result['response_text'] = response.text
                print(f"   📄 Raw response: {response.text}")
                
        elif response.status_code == 401:
            print("   🔐 UNAUTHORIZED: Token invalid or expired")
            try:
                error_data = response.json()
                result['error_details'] = error_data
                print(f"   💡 Details: {error_data}")
            except:
                print(f"   💡 Error: {response.text}")
                
        elif response.status_code == 422:
            print("   📝 VALIDATION ERROR: Still missing fields")
            try:
                error_data = response.json()
                result['validation_errors'] = error_data
                print(f"   💡 Missing fields: {error_data}")
            except:
                print(f"   💡 Validation error: {response.text}")
                
        else:
            print(f"   ⚠️  Status: {response.status_code}")
            result['error_message'] = response.text[:200]
            
        results.append(result)
        
    except Exception as e:
        print(f"   ❌ ERROR: {str(e)}")
        results.append({
            'test': 'Token Validation',
            'error': str(e),
            'success': False
        })
    
    print()
    
    # Test 2: Login with username format
    print("🧪 Test 2: Login (Correct Format)")
    print("   📋 Using username instead of email...")
    
    try:
        login_payload = {
            'username': 'api@onevault.com',  # Changed from email to username
            'password': 'test123',
            'tenant_id': customer_id
        }
        
        response = requests.post(
            f'{base_url}/api/v1/auth/login',
            headers=headers,
            json=login_payload,
            timeout=10
        )
        
        result = {
            'test': 'Login',
            'url': f'{base_url}/api/v1/auth/login',
            'method': 'POST',
            'payload': {**login_payload, 'password': '***'},  # Hide password in logs
            'status_code': response.status_code,
            'success': response.status_code == 200,
            'timestamp': datetime.now().isoformat()
        }
        
        if response.status_code == 200:
            print("   ✅ SUCCESS: Login working!")
            try:
                data = response.json()
                result['response_data'] = data
                print(f"   📊 Response: {json.dumps(data, indent=6)}")
                
                # Look for session token in response
                if 'session_token' in data or 'token' in data:
                    print("   🎉 LOGIN SUCCESS! Got session token!")
                    result['login_success'] = True
                    
            except:
                result['response_text'] = response.text
                print(f"   📄 Raw response: {response.text}")
                
        elif response.status_code == 401:
            print("   🔐 UNAUTHORIZED: Invalid credentials")
            try:
                error_data = response.json()
                result['error_details'] = error_data
                print(f"   💡 Details: {error_data}")
            except:
                print(f"   💡 Error: {response.text}")
                
        elif response.status_code == 422:
            print("   📝 VALIDATION ERROR: Still missing fields")
            try:
                error_data = response.json()
                result['validation_errors'] = error_data
                print(f"   💡 Missing fields: {error_data}")
            except:
                print(f"   💡 Validation error: {response.text}")
                
        else:
            print(f"   ⚠️  Status: {response.status_code}")
            result['error_message'] = response.text[:200]
            
        results.append(result)
        
    except Exception as e:
        print(f"   ❌ ERROR: {str(e)}")
        results.append({
            'test': 'Login',
            'error': str(e),
            'success': False
        })
    
    print()
    
    # Test 3: Try alternate token validation formats
    print("🧪 Test 3: Alternative Token Formats")
    
    alternate_formats = [
        {'token': production_token},
        {'api_token': production_token},
        {'bearer_token': production_token},
        {'auth_token': production_token}
    ]
    
    for i, alt_payload in enumerate(alternate_formats, 1):
        field_name = list(alt_payload.keys())[0]
        print(f"   🔍 Trying format {i}: {field_name}")
        
        try:
            response = requests.post(
                f'{base_url}/api/v1/auth/validate',
                headers=headers,
                json=alt_payload,
                timeout=5
            )
            
            if response.status_code == 200:
                print(f"      ✅ SUCCESS with {field_name}!")
                try:
                    data = response.json()
                    print(f"      📊 Response: {json.dumps(data, indent=10)}")
                    results.append({
                        'test': f'Alternative Format: {field_name}',
                        'payload': alt_payload,
                        'status_code': response.status_code,
                        'response_data': data,
                        'success': True
                    })
                    break  # Found working format
                except:
                    print(f"      📄 Raw: {response.text}")
            elif response.status_code != 422:
                print(f"      ⚠️  Status: {response.status_code}")
                
        except:
            pass  # Skip errors for alternate formats
    
    print()
    
    # Summary
    print("🎯 FINAL ANALYSIS")
    print("=" * 25)
    
    successful_tests = [r for r in results if r.get('success', False)]
    auth_success = [r for r in results if r.get('authentication_success', False)]
    login_success = [r for r in results if r.get('login_success', False)]
    
    print(f"✅ Successful requests: {len(successful_tests)}")
    print(f"🔑 Authentication success: {len(auth_success)}")
    print(f"🚪 Login success: {len(login_success)}")
    
    if auth_success:
        print("\n🎉 TOKEN VALIDATION WORKING!")
        print("🚀 Your production token is valid and working!")
        print("🛡️ Zero Trust middleware can now be integrated!")
        
    elif successful_tests:
        print("\n✅ API ENDPOINTS RESPONDING:")
        print("🔧 Need to adjust authentication format")
        
    else:
        print("\n🔧 TROUBLESHOOTING NEEDED:")
        print("   • Check token expiration")
        print("   • Verify API field requirements")
        print("   • Test with fresh credentials")
    
    # Save results
    with open('correct_format_test_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n📄 Results saved to: correct_format_test_results.json")
    
    return results

if __name__ == "__main__":
    results = test_correct_api_format()
    
    if any(r.get('success', False) for r in results):
        print("\n🎉 SUCCESS: Found working API format!")
        print("🚀 Ready to implement Zero Trust middleware integration!")
    else:
        print("\n🔍 Continue investigating API requirements...") 