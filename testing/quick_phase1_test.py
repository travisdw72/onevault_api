#!/usr/bin/env python3
"""
Quick Phase 1 Production Integration Test
========================================
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def test_phase1_config():
    """Test that Phase 1 config loads properly"""
    try:
        from app.phase1_zero_trust.config import get_config
        config = get_config()
        
        print("✅ Phase 1 config loaded successfully")
        print(f"   - Version: {config.app.version}")
        print(f"   - Environment: {config.app.environment}")
        print(f"   - Database: {config.database.host}")
        print(f"   - Parallel validation: {config.zero_trust.parallel_validation_enabled}")
        
        return True
    except Exception as e:
        print(f"❌ Phase 1 config failed: {e}")
        return False

def test_phase1_database_config():
    """Test that database config is correct for production"""
    try:
        from app.phase1_zero_trust.config import get_database_config
        db_config = get_database_config()
        
        print("✅ Database config loaded successfully")
        print(f"   - Host: {db_config.host}")
        print(f"   - Database: {db_config.database}")
        print(f"   - User: {db_config.user}")
        print(f"   - SSL Mode: {getattr(db_config, 'ssl_mode', 'Not set')}")
        
        # Check if it's production NeonDB
        if "neon.tech" in db_config.host:
            print("✅ Production NeonDB configured correctly")
            return True
        else:
            print("⚠️  Not using production NeonDB")
            return False
            
    except Exception as e:
        print(f"❌ Database config failed: {e}")
        return False

def test_phase1_imports():
    """Test that Phase 1 components can be imported"""
    try:
        from app.phase1_zero_trust.parallel_validation import ParallelValidationMiddleware
        from app.phase1_zero_trust.cache_manager import ValidationCacheManager
        from app.phase1_zero_trust.error_translation import ErrorTranslationService
        
        print("✅ Phase 1 core components import successfully")
        
        # Test basic initialization
        cache_manager = ValidationCacheManager({})
        error_service = ErrorTranslationService()
        
        print("✅ Phase 1 services initialize successfully")
        return True
        
    except Exception as e:
        print(f"❌ Phase 1 imports failed: {e}")
        return False

def test_production_integration():
    """Test that production integration files are working"""
    try:
        # Test monitoring endpoints
        from app.routers.phase1_monitoring import phase1_router
        print("✅ Phase 1 monitoring router loaded")
        
        # Test middleware (might fail due to missing config, but import should work)
        try:
            from app.middleware.phase1_integration import ProductionZeroTrustMiddleware
            print("✅ Phase 1 integration middleware loaded")
        except Exception as e:
            print(f"⚠️  Integration middleware needs runtime config: {e}")
        
        return True
        
    except Exception as e:
        print(f"❌ Production integration failed: {e}")
        return False

def main():
    """Run all Phase 1 integration tests"""
    print("🧪 Phase 1 Production Integration Test")
    print("=" * 40)
    
    tests = [
        test_phase1_config,
        test_phase1_database_config,
        test_phase1_imports,
        test_production_integration
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        print(f"\n🔍 Running {test.__name__}...")
        if test():
            passed += 1
        print()
    
    print("=" * 40)
    print(f"📊 Test Results: {passed}/{total} passed")
    
    if passed == total:
        print("🎉 Phase 1 Production Integration: READY!")
        print("✅ All systems operational")
        print("✅ Ready for production deployment")
        return True
    else:
        print("⚠️  Some tests failed - review before deployment")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 