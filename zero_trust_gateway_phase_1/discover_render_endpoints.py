#!/usr/bin/env python3
"""
Discover what endpoints actually exist on the Render deployment
"""
import requests
import json
from urllib.parse import urljoin

def discover_render_endpoints():
    """Discover available endpoints on Render"""
    print("🔍 Render Endpoint Discovery")
    print("=" * 40)
    
    api_base_url = "https://onevault-api.onrender.com"
    production_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
    
    headers = {
        'Authorization': f'Bearer {production_token}',
        'Content-Type': 'application/json',
        'X-Customer-ID': 'one_barn_ai',
        'User-Agent': 'OneVault-Discovery/1.0'
    }
    
    # Common API patterns to try
    endpoint_patterns = [
        # Root level
        '/',
        '/docs',
        '/openapi.json',
        '/swagger',
        '/api',
        '/api/docs',
        '/api/v1',
        
        # Health and status
        '/health',
        '/status',
        '/ping',
        '/version',
        
        # Auth patterns
        '/auth',
        '/auth/login',
        '/auth/validate',
        '/auth/token',
        '/api/auth',
        '/api/v1/auth',
        '/api/v1/auth/validate',
        '/api/v1/auth/me',
        '/api/v1/auth/tokens',
        
        # Canvas patterns  
        '/canvas',
        '/api/canvas',
        '/api/v1/canvas',
        '/api/v1/canvas/workflows',
        '/api/v1/canvas/nodes',
        
        # AI patterns
        '/ai',
        '/api/ai',
        '/api/v1/ai',
        '/api/v1/ai/agents',
        '/api/v1/ai/models',
        
        # Database patterns
        '/db',
        '/database',
        '/api/v1/db',
        '/api/v1/database',
        
        # Admin patterns
        '/admin',
        '/api/admin',
        '/api/v1/admin',
        
        # Common FastAPI patterns
        '/redoc',
        '/openapi.json',
        '/api/v1/docs',
    ]
    
    discovered = []
    
    print(f"🌐 Testing {len(endpoint_patterns)} potential endpoints...")
    print()
    
    for pattern in endpoint_patterns:
        url = urljoin(api_base_url, pattern)
        
        try:
            # Try both GET and OPTIONS
            for method in ['GET', 'OPTIONS']:
                try:
                    if method == 'GET':
                        response = requests.get(url, headers=headers, timeout=5, allow_redirects=False)
                    else:
                        response = requests.options(url, headers=headers, timeout=5)
                    
                    if response.status_code in [200, 301, 302, 307, 308]:
                        print(f"✅ {method} {pattern}: {response.status_code}")
                        
                        endpoint_info = {
                            'pattern': pattern,
                            'url': url,
                            'method': method,
                            'status_code': response.status_code,
                            'content_type': response.headers.get('content-type', ''),
                            'content_length': len(response.content)
                        }
                        
                        # Try to get response preview
                        try:
                            if 'application/json' in response.headers.get('content-type', ''):
                                data = response.json()
                                endpoint_info['response_preview'] = str(data)[:200]
                            else:
                                endpoint_info['response_preview'] = response.text[:200]
                        except:
                            endpoint_info['response_preview'] = 'Could not parse response'
                        
                        discovered.append(endpoint_info)
                        break  # Don't test OPTIONS if GET worked
                        
                    elif response.status_code == 405:
                        print(f"⚠️  {method} {pattern}: 405 (Method Not Allowed - endpoint exists!)")
                        
                        endpoint_info = {
                            'pattern': pattern,
                            'url': url,
                            'method': method,
                            'status_code': response.status_code,
                            'note': 'Endpoint exists but wrong method',
                            'allowed_methods': response.headers.get('allow', '')
                        }
                        discovered.append(endpoint_info)
                        
                except requests.exceptions.Timeout:
                    pass  # Skip timeouts silently
                except requests.exceptions.RequestException:
                    pass  # Skip connection errors silently
                    
        except Exception:
            pass  # Skip all other errors silently
    
    print()
    print("🎯 DISCOVERY RESULTS")
    print("=" * 30)
    
    if discovered:
        print(f"Found {len(discovered)} working endpoints:")
        print()
        
        for endpoint in discovered:
            print(f"✅ {endpoint['method']} {endpoint['pattern']}")
            print(f"   Status: {endpoint['status_code']}")
            print(f"   Content-Type: {endpoint.get('content_type', 'Unknown')}")
            if endpoint.get('allowed_methods'):
                print(f"   Allowed Methods: {endpoint['allowed_methods']}")
            if endpoint.get('response_preview'):
                print(f"   Preview: {endpoint['response_preview'][:100]}...")
            print()
    else:
        print("❌ No additional endpoints discovered")
        print("   Only /health appears to be working")
    
    # Check for API documentation
    doc_endpoints = [ep for ep in discovered if any(doc in ep['pattern'].lower() 
                    for doc in ['docs', 'swagger', 'openapi', 'redoc'])]
    
    if doc_endpoints:
        print("📚 API DOCUMENTATION FOUND:")
        for doc in doc_endpoints:
            print(f"   📖 {doc['url']}")
    
    # Save results
    with open('render_endpoint_discovery.json', 'w') as f:
        json.dump(discovered, f, indent=2)
    
    print(f"\n📄 Full results saved to: render_endpoint_discovery.json")
    
    return discovered

if __name__ == "__main__":
    discovered = discover_render_endpoints()
    
    if discovered:
        print("\n🚀 NEXT STEPS:")
        print("1. Check API documentation endpoints")
        print("2. Test discovered endpoints with your token")
        print("3. Deploy Zero Trust middleware to these paths")
    else:
        print("\n🔧 NEXT STEPS:")
        print("1. Deploy your Zero Trust endpoints to Render")
        print("2. Connect database functions")
        print("3. Test token validation") 