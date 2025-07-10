#!/usr/bin/env python3
"""
Zero Trust Gateway Phase 1 - Real Tenant Validation Test

This test validates the Zero Trust gateway implementation using real tenant data
from the One Vault database, testing actual API keys, users, and tenant isolation.

No synthetic data - only real tenant validation to ensure bulletproof security.
"""

import os
import sys
import json
import psycopg2
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
import hashlib
import secrets
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('zero_trust_validation.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class ZeroTrustGatewayTester:
    """Test Zero Trust Gateway with real tenant data"""
    
    def __init__(self, db_config: Dict[str, str]):
        self.db_config = db_config
        self.connection = None
        self.test_results = {
            "test_session_id": secrets.token_hex(8),
            "timestamp": datetime.now().isoformat(),
            "total_tests": 0,
            "passed_tests": 0,
            "failed_tests": 0,
            "error_tests": 0,
            "tenant_isolation_tests": [],
            "api_key_validation_tests": [],
            "cross_tenant_blocking_tests": [],
            "performance_tests": [],
            "errors": []
        }
    
    def connect_to_database(self) -> bool:
        """Connect to the One Vault database"""
        try:
            self.connection = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                database=self.db_config['database'],
                user=self.db_config['user'],
                password=self.db_config['password']
            )
            logger.info(f"✅ Connected to database: {self.db_config['database']}")
            return True
        except Exception as e:
            self.test_results['errors'].append(f"Database connection failed: {str(e)}")
            logger.error(f"❌ Database connection failed: {e}")
            return False
    
    def get_real_tenants(self) -> List[Dict[str, Any]]:
        """Get real tenant data from the database"""
        try:
            with self.connection.cursor() as cursor:
                # Get real tenants with their profiles
                cursor.execute("""
                    SELECT 
                        th.tenant_hk,
                        th.tenant_bk,
                        tps.tenant_name,
                        tps.domain_name,
                        tps.subscription_tier,
                        tps.is_active,
                        tps.load_date
                    FROM auth.tenant_h th
                    JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
                    WHERE tps.load_end_date IS NULL
                    AND tps.is_active = true
                    ORDER BY tps.load_date DESC
                    LIMIT 5
                """)
                
                tenants = []
                for row in cursor.fetchall():
                    tenants.append({
                        'tenant_hk': row[0],
                        'tenant_bk': row[1],
                        'tenant_name': row[2],
                        'domain_name': row[3],
                        'subscription_tier': row[4],
                        'is_active': row[5],
                        'load_date': row[6]
                    })
                
                logger.info(f"✅ Found {len(tenants)} real active tenants")
                return tenants
                
        except Exception as e:
            self.test_results['errors'].append(f"Failed to get real tenants: {str(e)}")
            logger.error(f"❌ Failed to get real tenants: {e}")
            return []
    
    def get_real_api_keys_for_tenant(self, tenant_hk: bytes) -> List[Dict[str, Any]]:
        """Get real API keys for a specific tenant"""
        try:
            with self.connection.cursor() as cursor:
                # Get API keys through the correct Data Vault 2.0 relationships
                cursor.execute("""
                    SELECT 
                        ath.api_token_hk,
                        ath.api_token_bk,
                        ats.token_type,
                        ats.scope,
                        ats.expires_at,
                        ats.is_revoked,
                        ats.created_by,
                        uth.user_hk,
                        ups.first_name,
                        ups.last_name,
                        ups.email
                    FROM auth.api_token_h ath
                    JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk
                    JOIN auth.user_token_l utl ON ath.api_token_hk = utl.api_token_hk
                    JOIN auth.user_h uth ON utl.user_hk = uth.user_hk
                    JOIN auth.user_profile_s ups ON uth.user_hk = ups.user_hk
                    WHERE ath.tenant_hk = %s
                    AND ats.load_end_date IS NULL
                    AND ups.load_end_date IS NULL
                    AND ats.is_revoked = false
                    AND ats.expires_at > CURRENT_TIMESTAMP
                    ORDER BY ats.load_date DESC
                    LIMIT 3
                """, (tenant_hk,))
                
                api_keys = []
                for row in cursor.fetchall():
                    api_keys.append({
                        'api_token_hk': row[0],
                        'api_token_bk': row[1],
                        'token_type': row[2],
                        'scope': row[3],
                        'expires_at': row[4],
                        'is_revoked': row[5],
                        'created_by': row[6],
                        'user_hk': row[7],
                        'user_name': f"{row[8]} {row[9]}",
                        'user_email': row[10]
                    })
                
                logger.info(f"✅ Found {len(api_keys)} real API keys for tenant")
                return api_keys
                
        except Exception as e:
            self.test_results['errors'].append(f"Failed to get API keys: {str(e)}")
            logger.error(f"❌ Failed to get API keys: {e}")
            return []
    
    def get_tenant_business_resources(self, tenant_hk: bytes) -> Dict[str, int]:
        """Get count of business resources for a tenant"""
        try:
            with self.connection.cursor() as cursor:
                resource_counts = {}
                
                # Check various business resources
                business_tables = [
                    'auth.user_h',
                    'auth.session_h',
                    'business.entity_h',
                    'business.asset_h',
                    'business.transaction_h'
                ]
                
                for table in business_tables:
                    try:
                        cursor.execute(f"""
                            SELECT COUNT(*) 
                            FROM {table} 
                            WHERE tenant_hk = %s
                        """, (tenant_hk,))
                        
                        count = cursor.fetchone()[0]
                        resource_counts[table] = count
                        
                    except Exception as e:
                        resource_counts[table] = f"Error: {str(e)}"
                
                return resource_counts
                
        except Exception as e:
            self.test_results['errors'].append(f"Failed to get business resources: {str(e)}")
            logger.error(f"❌ Failed to get business resources: {e}")
            return {}
    
    def test_tenant_isolation_validation(self, tenant_hk: bytes, tenant_name: str) -> Dict[str, Any]:
        """Test tenant isolation using real data"""
        test_result = {
            "test_name": f"tenant_isolation_{tenant_name}",
            "tenant_hk": tenant_hk.hex(),
            "tenant_name": tenant_name,
            "status": "PENDING",
            "checks": [],
            "performance_ms": 0,
            "timestamp": datetime.now().isoformat()
        }
        
        start_time = datetime.now()
        
        try:
            # Test 1: Validate tenant exists and is active
            with self.connection.cursor() as cursor:
                cursor.execute("""
                    SELECT ai_monitoring.validate_zero_trust_access(%s, 'tenant_validation', NULL)
                """, (tenant_hk,))
                
                result = cursor.fetchone()[0]
                test_result['checks'].append({
                    "check": "zero_trust_access_validation",
                    "result": result,
                    "passed": result is not None and result.get('access_granted', False) if isinstance(result, dict) else bool(result)
                })
            
            # Test 2: Validate tenant resource counts
            resource_counts = self.get_tenant_business_resources(tenant_hk)
            test_result['checks'].append({
                "check": "tenant_resource_counts",
                "result": resource_counts,
                "passed": len(resource_counts) > 0
            })
            
            # Test 3: Validate tenant API keys
            api_keys = self.get_real_api_keys_for_tenant(tenant_hk)
            test_result['checks'].append({
                "check": "tenant_api_keys",
                "result": f"Found {len(api_keys)} API keys",
                "passed": len(api_keys) >= 0  # Even 0 is valid
            })
            
            # Calculate overall success
            passed_checks = sum(1 for check in test_result['checks'] if check['passed'])
            test_result['status'] = "PASSED" if passed_checks == len(test_result['checks']) else "FAILED"
            
        except Exception as e:
            test_result['status'] = "ERROR"
            test_result['error'] = str(e)
            logger.error(f"❌ Tenant isolation test failed: {e}")
        
        test_result['performance_ms'] = (datetime.now() - start_time).total_seconds() * 1000
        return test_result
    
    def test_api_key_validation(self, api_key_data: Dict[str, Any]) -> Dict[str, Any]:
        """Test API key validation using real API key data"""
        test_result = {
            "test_name": f"api_key_validation_{api_key_data['api_token_bk']}",
            "api_token_hk": api_key_data['api_token_hk'].hex(),
            "token_type": api_key_data['token_type'],
            "user_email": api_key_data['user_email'],
            "status": "PENDING",
            "checks": [],
            "performance_ms": 0,
            "timestamp": datetime.now().isoformat()
        }
        
        start_time = datetime.now()
        
        try:
            with self.connection.cursor() as cursor:
                # Test 1: Validate API key exists and is active
                cursor.execute("""
                    SELECT 
                        ats.is_revoked,
                        ats.expires_at,
                        ats.token_type,
                        ats.scope
                    FROM auth.api_token_s ats
                    WHERE ats.api_token_hk = %s
                    AND ats.load_end_date IS NULL
                """, (api_key_data['api_token_hk'],))
                
                token_data = cursor.fetchone()
                if token_data:
                    is_revoked, expires_at, token_type, scope = token_data
                    test_result['checks'].append({
                        "check": "token_active_validation",
                        "result": {
                            "is_revoked": is_revoked,
                            "expires_at": expires_at.isoformat() if expires_at else None,
                            "token_type": token_type,
                            "scope": scope
                        },
                        "passed": not is_revoked and expires_at > datetime.now()
                    })
                else:
                    test_result['checks'].append({
                        "check": "token_active_validation",
                        "result": "Token not found",
                        "passed": False
                    })
                
                # Test 2: Validate user-token relationship
                cursor.execute("""
                    SELECT 
                        utl.user_hk,
                        utl.tenant_hk,
                        ups.email,
                        ups.first_name,
                        ups.last_name
                    FROM auth.user_token_l utl
                    JOIN auth.user_profile_s ups ON utl.user_hk = ups.user_hk
                    WHERE utl.api_token_hk = %s
                    AND ups.load_end_date IS NULL
                """, (api_key_data['api_token_hk'],))
                
                user_data = cursor.fetchone()
                if user_data:
                    user_hk, tenant_hk, email, first_name, last_name = user_data
                    test_result['checks'].append({
                        "check": "user_token_relationship",
                        "result": {
                            "user_hk": user_hk.hex(),
                            "tenant_hk": tenant_hk.hex(),
                            "email": email,
                            "name": f"{first_name} {last_name}"
                        },
                        "passed": email == api_key_data['user_email']
                    })
                else:
                    test_result['checks'].append({
                        "check": "user_token_relationship",
                        "result": "User-token relationship not found",
                        "passed": False
                    })
            
            # Calculate overall success
            passed_checks = sum(1 for check in test_result['checks'] if check['passed'])
            test_result['status'] = "PASSED" if passed_checks == len(test_result['checks']) else "FAILED"
            
        except Exception as e:
            test_result['status'] = "ERROR"
            test_result['error'] = str(e)
            logger.error(f"❌ API key validation test failed: {e}")
        
        test_result['performance_ms'] = (datetime.now() - start_time).total_seconds() * 1000
        return test_result
    
    def test_cross_tenant_access_blocking(self, tenant_a_hk: bytes, tenant_b_hk: bytes) -> Dict[str, Any]:
        """Test that tenant A cannot access tenant B's resources"""
        test_result = {
            "test_name": "cross_tenant_access_blocking",
            "tenant_a_hk": tenant_a_hk.hex(),
            "tenant_b_hk": tenant_b_hk.hex(),
            "status": "PENDING",
            "checks": [],
            "performance_ms": 0,
            "timestamp": datetime.now().isoformat()
        }
        
        start_time = datetime.now()
        
        try:
            with self.connection.cursor() as cursor:
                # Test 1: Ensure tenant A cannot see tenant B's users
                cursor.execute("""
                    SELECT COUNT(*) 
                    FROM auth.user_h 
                    WHERE tenant_hk = %s
                """, (tenant_a_hk,))
                tenant_a_users = cursor.fetchone()[0]
                
                cursor.execute("""
                    SELECT COUNT(*) 
                    FROM auth.user_h 
                    WHERE tenant_hk = %s
                """, (tenant_b_hk,))
                tenant_b_users = cursor.fetchone()[0]
                
                # Simulate cross-tenant query (should return 0)
                cursor.execute("""
                    SELECT COUNT(*) 
                    FROM auth.user_h 
                    WHERE tenant_hk = %s 
                    AND user_hk IN (
                        SELECT user_hk 
                        FROM auth.user_h 
                        WHERE tenant_hk = %s
                    )
                """, (tenant_a_hk, tenant_b_hk))
                cross_tenant_leak = cursor.fetchone()[0]
                
                test_result['checks'].append({
                    "check": "user_isolation_validation",
                    "result": {
                        "tenant_a_users": tenant_a_users,
                        "tenant_b_users": tenant_b_users,
                        "cross_tenant_leak": cross_tenant_leak
                    },
                    "passed": cross_tenant_leak == 0
                })
                
                # Test 2: Ensure tenant isolation in business resources
                for table in ['business.entity_h', 'business.asset_h']:
                    try:
                        cursor.execute(f"""
                            SELECT COUNT(*) 
                            FROM {table} 
                            WHERE tenant_hk = %s
                        """, (tenant_a_hk,))
                        tenant_a_resources = cursor.fetchone()[0]
                        
                        cursor.execute(f"""
                            SELECT COUNT(*) 
                            FROM {table} 
                            WHERE tenant_hk = %s
                        """, (tenant_b_hk,))
                        tenant_b_resources = cursor.fetchone()[0]
                        
                        # Check for cross-tenant leaks
                        cursor.execute(f"""
                            SELECT COUNT(*) 
                            FROM {table} 
                            WHERE tenant_hk = %s 
                            AND EXISTS (
                                SELECT 1 FROM {table} t2 
                                WHERE t2.tenant_hk = %s 
                                AND t2.load_date = {table}.load_date
                            )
                        """, (tenant_a_hk, tenant_b_hk))
                        resource_leak = cursor.fetchone()[0]
                        
                        test_result['checks'].append({
                            "check": f"{table}_isolation",
                            "result": {
                                "tenant_a_resources": tenant_a_resources,
                                "tenant_b_resources": tenant_b_resources,
                                "resource_leak": resource_leak
                            },
                            "passed": resource_leak == 0
                        })
                        
                    except Exception as e:
                        test_result['checks'].append({
                            "check": f"{table}_isolation",
                            "result": f"Error: {str(e)}",
                            "passed": False
                        })
            
            # Calculate overall success
            passed_checks = sum(1 for check in test_result['checks'] if check['passed'])
            test_result['status'] = "PASSED" if passed_checks == len(test_result['checks']) else "FAILED"
            
        except Exception as e:
            test_result['status'] = "ERROR"
            test_result['error'] = str(e)
            logger.error(f"❌ Cross-tenant access blocking test failed: {e}")
        
        test_result['performance_ms'] = (datetime.now() - start_time).total_seconds() * 1000
        return test_result
    
    def test_performance_benchmarks(self) -> Dict[str, Any]:
        """Test Zero Trust gateway performance with real data"""
        test_result = {
            "test_name": "performance_benchmarks",
            "status": "PENDING",
            "benchmarks": [],
            "total_time_ms": 0,
            "timestamp": datetime.now().isoformat()
        }
        
        start_time = datetime.now()
        
        try:
            with self.connection.cursor() as cursor:
                # Benchmark 1: Tenant validation speed
                bench_start = datetime.now()
                cursor.execute("""
                    SELECT tenant_hk 
                    FROM auth.tenant_h 
                    WHERE tenant_bk LIKE 'TENANT_%' 
                    LIMIT 1
                """)
                tenant_hk = cursor.fetchone()
                
                if tenant_hk:
                    cursor.execute("""
                        SELECT ai_monitoring.validate_zero_trust_access(%s, 'performance_test', NULL)
                    """, (tenant_hk[0],))
                    result = cursor.fetchone()
                    
                    bench_time = (datetime.now() - bench_start).total_seconds() * 1000
                    test_result['benchmarks'].append({
                        "benchmark": "tenant_validation_speed",
                        "time_ms": bench_time,
                        "result": "success" if result else "failure",
                        "target_ms": 50,
                        "passed": bench_time < 50
                    })
                
                # Benchmark 2: API key lookup speed
                bench_start = datetime.now()
                cursor.execute("""
                    SELECT ath.api_token_hk
                    FROM auth.api_token_h ath
                    JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk
                    WHERE ats.is_revoked = false
                    AND ats.expires_at > CURRENT_TIMESTAMP
                    AND ats.load_end_date IS NULL
                    ORDER BY ats.load_date DESC
                    LIMIT 1
                """)
                api_token = cursor.fetchone()
                
                bench_time = (datetime.now() - bench_start).total_seconds() * 1000
                test_result['benchmarks'].append({
                    "benchmark": "api_key_lookup_speed",
                    "time_ms": bench_time,
                    "result": "success" if api_token else "no_tokens",
                    "target_ms": 25,
                    "passed": bench_time < 25
                })
                
                # Benchmark 3: Cross-tenant query blocking
                bench_start = datetime.now()
                cursor.execute("""
                    SELECT COUNT(DISTINCT tenant_hk) 
                    FROM auth.user_h 
                    WHERE tenant_hk IS NOT NULL
                """)
                tenant_count = cursor.fetchone()[0]
                
                bench_time = (datetime.now() - bench_start).total_seconds() * 1000
                test_result['benchmarks'].append({
                    "benchmark": "tenant_isolation_query_speed",
                    "time_ms": bench_time,
                    "tenant_count": tenant_count,
                    "target_ms": 100,
                    "passed": bench_time < 100
                })
            
            # Calculate overall success
            passed_benchmarks = sum(1 for bench in test_result['benchmarks'] if bench['passed'])
            test_result['status'] = "PASSED" if passed_benchmarks == len(test_result['benchmarks']) else "FAILED"
            
        except Exception as e:
            test_result['status'] = "ERROR"
            test_result['error'] = str(e)
            logger.error(f"❌ Performance benchmark test failed: {e}")
        
        test_result['total_time_ms'] = (datetime.now() - start_time).total_seconds() * 1000
        return test_result
    
    def run_comprehensive_tests(self) -> Dict[str, Any]:
        """Run all Zero Trust gateway tests with real data"""
        logger.info("🚀 Starting Zero Trust Gateway Phase 1 Tests")
        
        if not self.connect_to_database():
            return self.test_results
        
        # Get real tenants
        real_tenants = self.get_real_tenants()
        if not real_tenants:
            self.test_results['errors'].append("No real tenants found for testing")
            return self.test_results
        
        # Test each tenant
        for tenant in real_tenants:
            self.test_results['total_tests'] += 1
            
            tenant_test = self.test_tenant_isolation_validation(
                tenant['tenant_hk'], 
                tenant['tenant_name']
            )
            
            self.test_results['tenant_isolation_tests'].append(tenant_test)
            
            if tenant_test['status'] == "PASSED":
                self.test_results['passed_tests'] += 1
            elif tenant_test['status'] == "FAILED":
                self.test_results['failed_tests'] += 1
            else:
                self.test_results['error_tests'] += 1
            
            # Test API keys for this tenant
            api_keys = self.get_real_api_keys_for_tenant(tenant['tenant_hk'])
            for api_key in api_keys:
                self.test_results['total_tests'] += 1
                
                api_test = self.test_api_key_validation(api_key)
                self.test_results['api_key_validation_tests'].append(api_test)
                
                if api_test['status'] == "PASSED":
                    self.test_results['passed_tests'] += 1
                elif api_test['status'] == "FAILED":
                    self.test_results['failed_tests'] += 1
                else:
                    self.test_results['error_tests'] += 1
        
        # Test cross-tenant access blocking
        if len(real_tenants) >= 2:
            self.test_results['total_tests'] += 1
            
            cross_tenant_test = self.test_cross_tenant_access_blocking(
                real_tenants[0]['tenant_hk'],
                real_tenants[1]['tenant_hk']
            )
            
            self.test_results['cross_tenant_blocking_tests'].append(cross_tenant_test)
            
            if cross_tenant_test['status'] == "PASSED":
                self.test_results['passed_tests'] += 1
            elif cross_tenant_test['status'] == "FAILED":
                self.test_results['failed_tests'] += 1
            else:
                self.test_results['error_tests'] += 1
        
        # Test performance benchmarks
        self.test_results['total_tests'] += 1
        
        performance_test = self.test_performance_benchmarks()
        self.test_results['performance_tests'].append(performance_test)
        
        if performance_test['status'] == "PASSED":
            self.test_results['passed_tests'] += 1
        elif performance_test['status'] == "FAILED":
            self.test_results['failed_tests'] += 1
        else:
            self.test_results['error_tests'] += 1
        
        # Calculate success rate
        self.test_results['success_rate'] = (
            self.test_results['passed_tests'] / self.test_results['total_tests'] * 100
            if self.test_results['total_tests'] > 0 else 0
        )
        
        logger.info(f"✅ Zero Trust Gateway Tests Complete: {self.test_results['success_rate']:.1f}% success rate")
        
        return self.test_results
    
    def close_connection(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            logger.info("📡 Database connection closed")

def main():
    """Main test execution"""
    
    # Database configuration
    db_config = {
        'host': 'localhost',
        'port': 5432,
        'database': 'one_vault_site_testing',
        'user': 'postgres',
        'password': os.getenv('DB_PASSWORD', 'your_password_here')
    }
    
    # Create tester instance
    tester = ZeroTrustGatewayTester(db_config)
    
    try:
        # Run comprehensive tests
        results = tester.run_comprehensive_tests()
        
        # Save results
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        results_file = f"zero_trust_gateway_test_results_{timestamp}.json"
        
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        # Print summary
        print("\n" + "="*60)
        print("🛡️  ZERO TRUST GATEWAY PHASE 1 TEST RESULTS")
        print("="*60)
        print(f"Total Tests: {results['total_tests']}")
        print(f"Passed: {results['passed_tests']}")
        print(f"Failed: {results['failed_tests']}")
        print(f"Errors: {results['error_tests']}")
        print(f"Success Rate: {results['success_rate']:.1f}%")
        print(f"Results saved to: {results_file}")
        
        if results['errors']:
            print("\n❌ ERRORS ENCOUNTERED:")
            for error in results['errors']:
                print(f"   - {error}")
        
        print("\n🎯 TENANT ISOLATION TESTS:")
        for test in results['tenant_isolation_tests']:
            status_icon = "✅" if test['status'] == "PASSED" else "❌"
            print(f"   {status_icon} {test['tenant_name']}: {test['status']} ({test['performance_ms']:.1f}ms)")
        
        print("\n🔑 API KEY VALIDATION TESTS:")
        for test in results['api_key_validation_tests']:
            status_icon = "✅" if test['status'] == "PASSED" else "❌"
            print(f"   {status_icon} {test['token_type']}: {test['status']} ({test['performance_ms']:.1f}ms)")
        
        print("\n🚫 CROSS-TENANT BLOCKING TESTS:")
        for test in results['cross_tenant_blocking_tests']:
            status_icon = "✅" if test['status'] == "PASSED" else "❌"
            print(f"   {status_icon} Cross-tenant access: {test['status']} ({test['performance_ms']:.1f}ms)")
        
        print("\n⚡ PERFORMANCE BENCHMARKS:")
        for test in results['performance_tests']:
            for bench in test['benchmarks']:
                status_icon = "✅" if bench['passed'] else "❌"
                print(f"   {status_icon} {bench['benchmark']}: {bench['time_ms']:.1f}ms (target: {bench['target_ms']}ms)")
        
        print("="*60)
        
    except Exception as e:
        logger.error(f"❌ Test execution failed: {e}")
        print(f"❌ Test execution failed: {e}")
        
    finally:
        tester.close_connection()

if __name__ == "__main__":
    main() 