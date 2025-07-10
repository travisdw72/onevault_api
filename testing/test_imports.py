#!/usr/bin/env python3
"""
Test script to verify all imports work correctly
"""

import sys
import traceback

def test_imports():
    """Test all critical imports"""
    
    tests = [
        ("app.middleware.phase1_integration", "ProductionZeroTrustMiddleware"),
        ("app.routers.phase1_monitoring", "phase1_router"),
        ("app.config.zero_trust_config", "ZeroTrustConfig"),
        ("app.utils.database", "get_db_connection"),
        ("app.main", "app"),
    ]
    
    print("🧪 Testing imports...")
    
    for module, item in tests:
        try:
            exec(f"from {module} import {item}")
            print(f"✅ {module}.{item} - SUCCESS")
        except Exception as e:
            print(f"❌ {module}.{item} - FAILED: {e}")
            traceback.print_exc()
            return False
    
    print("\n🎉 All imports successful!")
    return True

def test_app_creation():
    """Test FastAPI app creation"""
    try:
        from app.main import app
        print("✅ FastAPI app created successfully")
        print(f"📱 App title: {app.title}")
        print(f"🔢 App version: {app.version}")
        return True
    except Exception as e:
        print(f"❌ FastAPI app creation failed: {e}")
        traceback.print_exc()
        return False

def test_middleware_integration():
    """Test middleware integration"""
    try:
        from app.middleware.phase1_integration import ProductionZeroTrustMiddleware
        middleware = ProductionZeroTrustMiddleware()
        stats = middleware.get_integration_stats()
        print(f"✅ Middleware integration successful")
        print(f"📊 Initial stats: {stats}")
        return True
    except Exception as e:
        print(f"❌ Middleware integration failed: {e}")
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🚀 OneVault API - Import Test Suite")
    print("=" * 50)
    
    success = True
    
    success &= test_imports()
    success &= test_app_creation()
    success &= test_middleware_integration()
    
    if success:
        print("\n🎉 All tests passed! Ready for deployment.")
        sys.exit(0)
    else:
        print("\n❌ Some tests failed. Please fix before deployment.")
        sys.exit(1) 