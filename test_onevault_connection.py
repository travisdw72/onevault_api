#!/usr/bin/env python3
"""
OneVault API Connection Test Suite
=================================
Test connection to deployed OneVault API on Render with actual customer credentials.

Customer: The One Spa Oregon (one_spa)
API Base URL: https://onevault-api.onrender.com
"""

import requests
import json
import time
from datetime import datetime
from typing import Dict, Any, Optional

# Customer Configuration
API_BASE_URL = "https://onevault-api.onrender.com"
API_TOKEN = "ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f"
CUSTOMER_ID = "one_spa"
TENANT_HK = "6cd30f42d1ccfb4fa6a571db8c2fb43b3fb9dd80b0b4b092ece55b06c3c7b6f5"

class OneVaultAPITester:
    def __init__(self):
        self.base_url = API_BASE_URL
        self.api_token = API_TOKEN
        self.customer_id = CUSTOMER_ID
        self.tenant_hk = TENANT_HK
        self.test_results = []
        
    def log_test_result(self, test_name: str, success: bool, details: Any = None, error: str = None):
        """Log test result"""
        result = {
            "test_name": test_name,
            "success": success,
            "timestamp": datetime.utcnow().isoformat(),
            "details": details,
            "error": error
        }
        self.test_results.append(result)
        
        status = "✅ PASSED" if success else "❌ FAILED"
        print(f"{status} - {test_name}")
        if error:
            print(f"   Error: {error}")
        if details and isinstance(details, dict):
            print(f"   Details: {json.dumps(details, indent=2)}")
        print()

    def test_basic_connectivity(self):
        """Test 1: Basic API connectivity"""
        try:
            response = requests.get(f"{self.base_url}/health", timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                self.log_test_result(
                    "Basic Connectivity", 
                    True, 
                    {
                        "status_code": response.status_code,
                        "response_data": data,
                        "response_time_ms": response.elapsed.total_seconds() * 1000
                    }
                )
            else:
                self.log_test_result(
                    "Basic Connectivity",
                    False,
                    {"status_code": response.status_code},
                    f"HTTP {response.status_code}: {response.text}"
                )
                
        except Exception as e:
            self.log_test_result("Basic Connectivity", False, error=str(e))

    def test_detailed_health_check(self):
        """Test 2: Detailed platform health check"""
        try:
            response = requests.get(f"{self.base_url}/health/detailed", timeout=15)
            
            if response.status_code == 200:
                data = response.json()
                self.log_test_result(
                    "Detailed Health Check",
                    True,
                    {
                        "platform_status": data.get("status"),
                        "database_status": data.get("database_status"),
                        "features": data.get("features"),
                        "supported_industries": data.get("supported_industries"),
                        "compliance_frameworks": data.get("compliance_frameworks")
                    }
                )
            else:
                self.log_test_result(
                    "Detailed Health Check",
                    False,
                    {"status_code": response.status_code},
                    f"HTTP {response.status_code}: {response.text}"
                )
                
        except Exception as e:
            self.log_test_result("Detailed Health Check", False, error=str(e))

    def test_customer_health_check(self):
        """Test 3: Customer-specific health check"""
        try:
            response = requests.get(
                f"{self.base_url}/health/customer/{self.customer_id}", 
                timeout=15
            )
            
            if response.status_code == 200:
                data = response.json()
                self.log_test_result(
                    "Customer Health Check",
                    True,
                    {
                        "customer_id": data.get("customer_id"),
                        "customer_name": data.get("customer_name"),
                        "status": data.get("status"),
                        "database_status": data.get("database_status"),
                        "industry": data.get("industry"),
                        "monthly_cost": data.get("monthly_cost")
                    }
                )
            else:
                self.log_test_result(
                    "Customer Health Check",
                    False,
                    {"status_code": response.status_code},
                    f"HTTP {response.status_code}: {response.text}"
                )
                
        except Exception as e:
            self.log_test_result("Customer Health Check", False, error=str(e))

    def test_platform_info(self):
        """Test 4: Platform information endpoint"""
        try:
            response = requests.get(f"{self.base_url}/api/v1/platform/info", timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                self.log_test_result(
                    "Platform Info",
                    True,
                    {
                        "platform_name": data.get("platform", {}).get("name"),
                        "version": data.get("platform", {}).get("version"),
                        "architecture": data.get("platform", {}).get("architecture"),
                        "features": data.get("platform", {}).get("features", [])
                    }
                )
            else:
                self.log_test_result(
                    "Platform Info",
                    False,
                    {"status_code": response.status_code},
                    f"HTTP {response.status_code}: {response.text}"
                )
                
        except Exception as e:
            self.log_test_result("Platform Info", False, error=str(e))

    def test_customer_config(self):
        """Test 5: Customer configuration retrieval"""
        try:
            headers = {
                "Authorization": f"Bearer {self.api_token}",
                "X-Customer-ID": self.customer_id,
                "Content-Type": "application/json"
            }
            
            response = requests.get(
                f"{self.base_url}/api/v1/customer/config",
                headers=headers,
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                self.log_test_result(
                    "Customer Configuration",
                    True,
                    {
                        "customer_id": data.get("customer_id"),
                        "has_config": bool(data.get("config")),
                        "config_summary": data.get("config_summary", {})
                    }
                )
            else:
                self.log_test_result(
                    "Customer Configuration",
                    False,
                    {"status_code": response.status_code},
                    f"HTTP {response.status_code}: {response.text}"
                )
                
        except Exception as e:
            self.log_test_result("Customer Configuration", False, error=str(e))

    def test_site_tracking_authentication(self):
        """Test 6: Site tracking endpoint with authentication"""
        try:
            headers = {
                "Authorization": f"Bearer {self.api_token}",
                "X-Customer-ID": self.customer_id,
                "Content-Type": "application/json",
                "User-Agent": "OneVault-Connection-Test/1.0"
            }
            
            # Test payload - realistic site tracking data
            payload = {
                "session_id": f"test_session_{int(time.time())}",
                "page_url": "https://theonespaoregon.com/test-connection",
                "event_type": "connection_test",
                "event_data": {
                    "test_run": True,
                    "timestamp": datetime.utcnow().isoformat(),
                    "source": "api_connection_test"
                },
                "referrer_url": "https://theonespaoregon.com"
            }
            
            response = requests.post(
                f"{self.base_url}/api/v1/track",
                headers=headers,
                json=payload,
                timeout=15
            )
            
            if response.status_code == 200:
                data = response.json()
                self.log_test_result(
                    "Site Tracking Authentication",
                    True,
                    {
                        "success": data.get("success"),
                        "event_id": data.get("event_id"),
                        "message": data.get("message"),
                        "response_time_ms": response.elapsed.total_seconds() * 1000
                    }
                )
            else:
                self.log_test_result(
                    "Site Tracking Authentication",
                    False,
                    {
                        "status_code": response.status_code,
                        "response_text": response.text[:500]  # Truncate long error messages
                    },
                    f"HTTP {response.status_code}: Authentication or tracking failed"
                )
                
        except Exception as e:
            self.log_test_result("Site Tracking Authentication", False, error=str(e))

    def test_invalid_authentication(self):
        """Test 7: Invalid authentication handling"""
        try:
            headers = {
                "Authorization": "Bearer invalid_token_test",
                "X-Customer-ID": self.customer_id,
                "Content-Type": "application/json"
            }
            
            payload = {
                "session_id": "test_invalid_auth",
                "page_url": "https://test.com",
                "event_type": "test"
            }
            
            response = requests.post(
                f"{self.base_url}/api/v1/track",
                headers=headers,
                json=payload,
                timeout=10
            )
            
            # Should fail with 401 or similar
            if response.status_code in [401, 403]:
                self.log_test_result(
                    "Invalid Authentication Handling",
                    True,
                    {
                        "status_code": response.status_code,
                        "correctly_rejected": True
                    }
                )
            else:
                # If it succeeds with invalid token, that's a problem
                self.log_test_result(
                    "Invalid Authentication Handling",
                    False,
                    {"status_code": response.status_code},
                    "Invalid token was accepted - security issue!"
                )
                
        except Exception as e:
            self.log_test_result("Invalid Authentication Handling", False, error=str(e))

    def test_missing_customer_header(self):
        """Test 8: Missing customer header handling"""
        try:
            headers = {
                "Authorization": f"Bearer {self.api_token}",
                "Content-Type": "application/json"
                # Intentionally missing X-Customer-ID
            }
            
            payload = {
                "session_id": "test_missing_header",
                "page_url": "https://test.com",
                "event_type": "test"
            }
            
            response = requests.post(
                f"{self.base_url}/api/v1/track",
                headers=headers,
                json=payload,
                timeout=10
            )
            
            # Should fail with 400
            if response.status_code == 400:
                self.log_test_result(
                    "Missing Customer Header Handling",
                    True,
                    {
                        "status_code": response.status_code,
                        "correctly_rejected": True
                    }
                )
            else:
                self.log_test_result(
                    "Missing Customer Header Handling",
                    False,
                    {"status_code": response.status_code},
                    "Missing customer header was not properly rejected"
                )
                
        except Exception as e:
            self.log_test_result("Missing Customer Header Handling", False, error=str(e))

    def run_all_tests(self):
        """Run complete test suite"""
        print("=" * 60)
        print("🧪 OneVault API Connection Test Suite")
        print("=" * 60)
        print(f"API Base URL: {self.base_url}")
        print(f"Customer ID: {self.customer_id}")
        print(f"Test Time: {datetime.utcnow().isoformat()}")
        print("=" * 60)
        print()
        
        # Run all tests
        self.test_basic_connectivity()
        self.test_detailed_health_check()
        self.test_customer_health_check()
        self.test_platform_info()
        self.test_customer_config()
        self.test_site_tracking_authentication()
        self.test_invalid_authentication()
        self.test_missing_customer_header()
        
        # Generate summary
        self.generate_summary()
        
        return self.test_results

    def generate_summary(self):
        """Generate test summary"""
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results if result["success"])
        failed_tests = total_tests - passed_tests
        
        success_rate = (passed_tests / total_tests) * 100 if total_tests > 0 else 0
        
        print("=" * 60)
        print("📊 TEST SUMMARY")
        print("=" * 60)
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests}")
        print(f"Failed: {failed_tests}")
        print(f"Success Rate: {success_rate:.1f}%")
        print()
        
        if failed_tests > 0:
            print("❌ FAILED TESTS:")
            for result in self.test_results:
                if not result["success"]:
                    print(f"   - {result['test_name']}: {result.get('error', 'Unknown error')}")
            print()
        
        overall_status = "🎉 ALL TESTS PASSED!" if failed_tests == 0 else "⚠️  SOME TESTS FAILED"
        print(f"Overall Status: {overall_status}")
        print("=" * 60)

    def save_results(self, filename: str = None):
        """Save detailed test results to JSON file"""
        if not filename:
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            filename = f"onevault_test_results_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump({
                "test_run_info": {
                    "api_base_url": self.base_url,
                    "customer_id": self.customer_id,
                    "test_timestamp": datetime.utcnow().isoformat(),
                    "total_tests": len(self.test_results),
                    "passed_tests": sum(1 for r in self.test_results if r["success"]),
                    "failed_tests": sum(1 for r in self.test_results if not r["success"])
                },
                "test_results": self.test_results
            }, f, indent=2)
        
        print(f"📄 Detailed results saved to: {filename}")

if __name__ == "__main__":
    tester = OneVaultAPITester()
    results = tester.run_all_tests()
    tester.save_results() 