#!/usr/bin/env python3
"""
Zero Trust Gateway Phase 1 - Validation Runner

Simple script to run Zero Trust Gateway validation tests using real tenant data
from the One Vault database.
"""

import os
import sys
import json
from datetime import datetime
from test_real_tenant_validation import ZeroTrustGatewayTester
from config import get_config, validate_config, print_config_summary

def main():
    """Main validation runner"""
    
    print("🛡️  Zero Trust Gateway Phase 1 - Validation Runner")
    print("=" * 60)
    
    # Load and validate configuration
    config = get_config()
    print_config_summary()
    
    # Check configuration errors
    config_errors = validate_config()
    if config_errors:
        print("\n❌ Configuration errors found:")
        for error in config_errors:
            print(f"   - {error}")
        print("\nPlease fix configuration errors before running validation.")
        return 1
    
    print("\n✅ Configuration is valid")
    
    # Check database password
    if config.database.password == 'your_password_here':
        password = input("\n🔐 Enter database password: ")
        config.database.password = password
    
    # Create tester instance
    tester = ZeroTrustGatewayTester(config.database.to_dict())
    
    print("\n🚀 Starting Zero Trust Gateway validation tests...")
    print("   Using real tenant data from database")
    print("   No synthetic test data will be created")
    
    try:
        # Run comprehensive tests
        results = tester.run_comprehensive_tests()
        
        # Generate timestamp for results
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        results_file = f"zero_trust_validation_results_{timestamp}.json"
        
        # Save results
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        # Print detailed results
        print_validation_results(results, results_file)
        
        # Return appropriate exit code
        return 0 if results['success_rate'] >= 90.0 else 1
        
    except Exception as e:
        print(f"\n❌ Validation failed: {e}")
        return 1
        
    finally:
        tester.close_connection()

def print_validation_results(results: dict, results_file: str):
    """Print detailed validation results"""
    
    print("\n" + "="*60)
    print("🎯 ZERO TRUST GATEWAY VALIDATION RESULTS")
    print("="*60)
    
    # Overall summary
    print(f"📊 SUMMARY:")
    print(f"   Total Tests: {results['total_tests']}")
    print(f"   Passed: {results['passed_tests']} ✅")
    print(f"   Failed: {results['failed_tests']} ❌")
    print(f"   Errors: {results['error_tests']} 🚨")
    print(f"   Success Rate: {results['success_rate']:.1f}%")
    
    # Success indicator
    if results['success_rate'] >= 95.0:
        print("   Status: 🟢 EXCELLENT - Ready for production")
    elif results['success_rate'] >= 90.0:
        print("   Status: 🟡 GOOD - Minor issues to address")
    elif results['success_rate'] >= 80.0:
        print("   Status: 🟠 NEEDS WORK - Several issues found")
    else:
        print("   Status: 🔴 CRITICAL - Major issues require attention")
    
    print(f"\n📁 Results saved to: {results_file}")
    
    # Detailed test results
    if results.get('tenant_isolation_tests'):
        print(f"\n🏢 TENANT ISOLATION TESTS ({len(results['tenant_isolation_tests'])}):")
        for test in results['tenant_isolation_tests']:
            status_icon = "✅" if test['status'] == "PASSED" else ("❌" if test['status'] == "FAILED" else "🚨")
            print(f"   {status_icon} {test['tenant_name']}")
            print(f"      Status: {test['status']}")
            print(f"      Performance: {test['performance_ms']:.1f}ms")
            if test['status'] != "PASSED":
                print(f"      Checks: {len([c for c in test['checks'] if c['passed']])}/{len(test['checks'])} passed")
    
    if results.get('api_key_validation_tests'):
        print(f"\n🔑 API KEY VALIDATION TESTS ({len(results['api_key_validation_tests'])}):")
        for test in results['api_key_validation_tests']:
            status_icon = "✅" if test['status'] == "PASSED" else ("❌" if test['status'] == "FAILED" else "🚨")
            print(f"   {status_icon} {test.get('token_type', 'Unknown')} token")
            print(f"      User: {test.get('user_email', 'Unknown')}")
            print(f"      Status: {test['status']}")
            print(f"      Performance: {test['performance_ms']:.1f}ms")
    
    if results.get('cross_tenant_blocking_tests'):
        print(f"\n🚫 CROSS-TENANT BLOCKING TESTS ({len(results['cross_tenant_blocking_tests'])}):")
        for test in results['cross_tenant_blocking_tests']:
            status_icon = "✅" if test['status'] == "PASSED" else ("❌" if test['status'] == "FAILED" else "🚨")
            print(f"   {status_icon} Cross-tenant isolation")
            print(f"      Status: {test['status']}")
            print(f"      Performance: {test['performance_ms']:.1f}ms")
            print(f"      Isolation checks: {len([c for c in test['checks'] if c['passed']])}/{len(test['checks'])} passed")
    
    if results.get('performance_tests'):
        print(f"\n⚡ PERFORMANCE BENCHMARKS:")
        for test in results['performance_tests']:
            for bench in test.get('benchmarks', []):
                status_icon = "✅" if bench['passed'] else "❌"
                print(f"   {status_icon} {bench['benchmark']}")
                print(f"      Time: {bench['time_ms']:.1f}ms (target: {bench['target_ms']}ms)")
                print(f"      Result: {bench.get('result', 'Unknown')}")
    
    # Errors
    if results.get('errors'):
        print(f"\n🚨 ERRORS ENCOUNTERED:")
        for i, error in enumerate(results['errors'], 1):
            print(f"   {i}. {error}")
    
    # Recommendations
    print(f"\n💡 RECOMMENDATIONS:")
    
    if results['success_rate'] < 100:
        print("   - Review failed test details in the results file")
        print("   - Check database connectivity and permissions")
        print("   - Verify existing ai_monitoring.validate_zero_trust_access function")
        print("   - Ensure tenant data is properly configured")
    
    if any(test.get('performance_ms', 0) > 200 for test in results.get('tenant_isolation_tests', [])):
        print("   - Consider database query optimization")
        print("   - Enable Redis caching for better performance")
        print("   - Review database indexes on tenant_hk columns")
    
    if results['failed_tests'] > 0:
        print("   - Fix failed validation checks before production deployment")
        print("   - Test with different tenant configurations")
        print("   - Validate Data Vault 2.0 table relationships")
    
    if results['success_rate'] >= 95:
        print("   - ✨ Excellent! Zero Trust Gateway is ready for integration")
        print("   - Consider implementing Phase 2: Token Lifecycle Management")
        print("   - Monitor performance metrics in production")
    
    print("="*60)

def quick_test():
    """Run a quick connectivity test"""
    print("🔍 Quick connectivity test...")
    
    config = get_config()
    
    if config.database.password == 'your_password_here':
        password = input("🔐 Enter database password: ")
        config.database.password = password
    
    tester = ZeroTrustGatewayTester(config.database.to_dict())
    
    try:
        if tester.connect_to_database():
            print("✅ Database connection successful")
            
            # Test basic queries
            tenants = tester.get_real_tenants()
            print(f"✅ Found {len(tenants)} active tenants")
            
            if tenants:
                tenant = tenants[0]
                api_keys = tester.get_real_api_keys_for_tenant(tenant['tenant_hk'])
                print(f"✅ Found {len(api_keys)} API keys for tenant: {tenant['tenant_name']}")
            
            print("✅ Quick test passed - ready for full validation")
            return True
        else:
            print("❌ Database connection failed")
            return False
            
    except Exception as e:
        print(f"❌ Quick test failed: {e}")
        return False
        
    finally:
        tester.close_connection()

if __name__ == "__main__":
    
    # Check command line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] == "quick":
            exit_code = 0 if quick_test() else 1
        elif sys.argv[1] == "config":
            print_config_summary()
            exit_code = 0 if not validate_config() else 1
        else:
            print("Usage: python run_validation.py [quick|config]")
            print("  quick  - Run quick connectivity test")
            print("  config - Show configuration summary")
            print("  (no args) - Run full validation")
            exit_code = 1
    else:
        # Run full validation
        exit_code = main()
    
    sys.exit(exit_code) 