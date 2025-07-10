"""
Phase 1 Zero Trust Implementation Test Suite
Comprehensive testing with guard clauses and error handling
"""

import asyncio
import time
import json
import psycopg2
from typing import Dict, Any, List

# Import Phase 1 components
from config import get_config, get_database_config
from parallel_validation import get_middleware, validate_request
from cache_manager import get_cache_manager
from error_translation import get_error_service

# Test configuration
TEST_TOKEN = "test_token_abc123"
TEST_TENANT_ID = "518a00fd8cb1b99f"  # one_barn_ai from config

async def test_configuration_system():
    """Test configuration loading and validation"""
    print("\n🧪 Testing Configuration System...")
    
    try:
        config = get_config()
        assert config.implementation_name == "Silent Enhancement"
        assert config.version == "1.0.0"
        assert config.zero_trust.parallel_validation_enabled == True
        print("✅ Configuration system: PASSED")
        return True
    except Exception as e:
        print(f"❌ Configuration system: FAILED - {e}")
        return False

async def test_database_connection():
    """Test database connectivity"""
    print("\n🧪 Testing Database Connection...")
    
    try:
        db_config = get_database_config()
        conn = psycopg2.connect(
            host=db_config.host,
            port=db_config.port,
            database=db_config.database,
            user=db_config.user,
            password=db_config.password,
            connect_timeout=5
        )
        conn.close()
        print("✅ Database connection: PASSED")
        return True
    except Exception as e:
        print(f"❌ Database connection: FAILED - {e}")
        return False

async def test_parallel_validation():
    """Test parallel validation middleware"""
    print("\n🧪 Testing Parallel Validation...")
    
    try:
        middleware = get_middleware()
        
        # Test validation with real tenant
        result = await middleware.validate_parallel(
            token=TEST_TOKEN,
            tenant_id=TEST_TENANT_ID,
            api_endpoint="/api/test",
            user_agent="Phase1TestAgent",
            ip_address="127.0.0.1"
        )
        
        # Verify result structure
        assert hasattr(result, 'current_result')
        assert hasattr(result, 'enhanced_result')
        assert hasattr(result, 'performance_improvement_ms')
        assert hasattr(result, 'results_match')
        
        print(f"✅ Parallel validation: PASSED")
        print(f"   Current duration: {result.current_result.duration_ms}ms")
        print(f"   Enhanced duration: {result.enhanced_result.duration_ms}ms")
        print(f"   Performance improvement: {result.performance_improvement_ms}ms")
        print(f"   Results match: {result.results_match}")
        
        return True
    except Exception as e:
        print(f"❌ Parallel validation: FAILED - {e}")
        return False

async def test_cache_manager():
    """Test cache manager functionality"""
    print("\n🧪 Testing Cache Manager...")
    
    try:
        cache_manager = get_cache_manager()
        
        if not cache_manager.is_enabled():
            print("⚠️ Cache disabled - skipping cache tests")
            return True
        
        # Test caching functionality
        test_result = {"p_success": True, "test": "data"}
        
        # Cache a result
        cached = cache_manager.cache_validation_result(
            TEST_TOKEN, TEST_TENANT_ID, test_result
        )
        
        # Retrieve cached result
        retrieved = cache_manager.get_cached_validation(TEST_TOKEN, TEST_TENANT_ID)
        
        assert retrieved is not None
        assert retrieved["test"] == "data"
        assert retrieved["cache_hit"] == True
        
        # Get cache stats
        stats = cache_manager.get_stats()
        assert "enabled" in stats
        
        print("✅ Cache manager: PASSED")
        print(f"   Cache enabled: {stats.get('enabled', False)}")
        print(f"   Cache provider: {stats.get('caches', {}).get('validation', {}).get('name', 'unknown')}")
        
        return True
    except Exception as e:
        print(f"❌ Cache manager: FAILED - {e}")
        return False

async def test_error_translation():
    """Test error translation service"""
    print("\n🧪 Testing Error Translation...")
    
    try:
        error_service = get_error_service()
        
        # Test various error types
        test_errors = [
            ("Token expired", "production_token_expired"),
            ("Cross-tenant access denied", "cross_tenant_access_denied"),
            ("Database connection failed", "database_connection_error"),
            ("Validation timeout", "validation_timeout")
        ]
        
        for error_msg, expected_type in test_errors:
            translated = error_service.translate_error(error_msg, expected_type)
            
            assert translated.user_message != error_msg  # Should be user-friendly
            assert translated.error_code is not None
            assert translated.helpful_action is not None
            
        print("✅ Error translation: PASSED")
        print(f"   Translations available: {len(error_service.translations)}")
        print(f"   Error patterns: {len(error_service.error_patterns)}")
        
        return True
    except Exception as e:
        print(f"❌ Error translation: FAILED - {e}")
        return False

async def test_performance_benchmarks():
    """Test performance benchmarks"""
    print("\n🧪 Testing Performance Benchmarks...")
    
    try:
        config = get_config()
        target_improvement = config.zero_trust.improvement_target_pct
        max_duration = config.zero_trust.total_middleware_ms
        
        # Run multiple validation tests
        durations = []
        for i in range(5):
            start_time = time.perf_counter()
            
            result = await validate_request(
                token=TEST_TOKEN,
                tenant_id=TEST_TENANT_ID,
                api_endpoint="/api/performance_test"
            )
            
            duration_ms = int((time.perf_counter() - start_time) * 1000)
            durations.append(duration_ms)
        
        avg_duration = sum(durations) / len(durations)
        
        print(f"✅ Performance benchmarks: TESTED")
        print(f"   Average duration: {avg_duration:.1f}ms")
        print(f"   Target max duration: {max_duration}ms")
        print(f"   Performance target: {target_improvement}% improvement")
        print(f"   Within target: {'✅' if avg_duration <= max_duration else '❌'}")
        
        return avg_duration <= max_duration
    except Exception as e:
        print(f"❌ Performance benchmarks: FAILED - {e}")
        return False

async def test_comprehensive_integration():
    """Comprehensive integration test"""
    print("\n🧪 Running Comprehensive Integration Test...")
    
    try:
        # Test full workflow
        start_time = time.perf_counter()
        
        # 1. Validate request with all components
        validation_result = await validate_request(
            token=TEST_TOKEN,
            tenant_id=TEST_TENANT_ID,
            api_endpoint="/api/integration_test",
            user_agent="Phase1IntegrationTest",
            ip_address="127.0.0.1"
        )
        
        total_duration = int((time.perf_counter() - start_time) * 1000)
        
        # 2. Check all components worked
        assert validation_result is not None
        assert "phase1_enhanced_available" in validation_result
        
        # 3. Get metrics from all components
        middleware = get_middleware()
        metrics = middleware.get_performance_metrics()
        
        cache_manager = get_cache_manager()
        cache_stats = cache_manager.get_stats()
        
        error_service = get_error_service()
        error_stats = error_service.get_error_statistics()
        
        print(f"✅ Comprehensive integration: PASSED")
        print(f"   Total request duration: {total_duration}ms")
        print(f"   Middleware version: {metrics.get('middleware_version')}")
        print(f"   Cache enabled: {cache_stats.get('enabled', False)}")
        print(f"   Error translation enabled: {error_stats.get('enabled', False)}")
        
        return True
    except Exception as e:
        print(f"❌ Comprehensive integration: FAILED - {e}")
        return False

async def run_all_tests():
    """Run all Phase 1 tests"""
    print("🚀 PHASE 1 ZERO TRUST IMPLEMENTATION - TEST SUITE")
    print("=" * 60)
    
    tests = [
        ("Configuration System", test_configuration_system),
        ("Database Connection", test_database_connection),
        ("Parallel Validation", test_parallel_validation),
        ("Cache Manager", test_cache_manager),
        ("Error Translation", test_error_translation),
        ("Performance Benchmarks", test_performance_benchmarks),
        ("Comprehensive Integration", test_comprehensive_integration)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            result = await test_func()
            if result:
                passed += 1
        except Exception as e:
            print(f"❌ {test_name}: FAILED with exception - {e}")
    
    print("\n" + "=" * 60)
    print(f"TEST RESULTS: {passed}/{total} PASSED")
    
    if passed == total:
        print("🎉 ALL TESTS PASSED - PHASE 1 READY FOR DEPLOYMENT!")
    else:
        print(f"⚠️ {total - passed} TESTS FAILED - REVIEW REQUIRED")
    
    return passed == total

if __name__ == "__main__":
    # Run tests
    asyncio.run(run_all_tests()) 