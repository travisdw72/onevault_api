import requests

def test_endpoint(url):
    try:
        r = requests.get(url)
        print(f"URL: {url}")
        print(f"Status: {r.status_code}")
        print(f"Response: {r.text[:200]}...")
        print("-" * 50)
    except Exception as e:
        print(f"Error testing {url}: {e}")

# Test endpoints
test_endpoint("https://onevault-api.onrender.com/health")
test_endpoint("https://onevault-api.onrender.com/health/detailed")
test_endpoint("https://onevault-api.onrender.com/api/v1/platform/info") 