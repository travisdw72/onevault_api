#!/usr/bin/env python3
"""
Local API Test Server with Zero Trust Gateway

This creates a local FastAPI server for testing Zero Trust Gateway
middleware against a localhost database before deploying to production.
"""

import os
import sys
import uvicorn
from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import logging
from datetime import datetime
from typing import Dict, Any

# Import our Zero Trust components
from zero_trust_middleware import (
    ZeroTrustGatewayMiddleware, 
    get_zero_trust_context,
    require_access_level,
    require_tenant_access,
    ZeroTrustContext
)
from config import get_config, validate_config

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="OneVault Zero Trust Gateway - Local Test",
    description="Local testing environment for Zero Trust Gateway middleware",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add CORS for local testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables for middleware
zero_trust_middleware = None

# Zero Trust middleware function
@app.middleware("http")
async def zero_trust_middleware_handler(request: Request, call_next):
    """Zero Trust middleware handler"""
    global zero_trust_middleware
    
    print(f"🔍 Middleware called for: {request.url.path}")
    
    # Skip middleware for health and docs endpoints
    if request.url.path in ["/health", "/metrics", "/docs", "/openapi.json", "/redoc"]:
        print(f"⏭️ Skipping auth for: {request.url.path}")
        return await call_next(request)
    
    # If middleware not initialized yet, skip (during startup)
    if zero_trust_middleware is None:
        print("⚠️ Middleware not initialized yet")
        return await call_next(request)
    
    try:
        print("🛡️ Running Zero Trust validation...")
        # Use the middleware instance
        result = await zero_trust_middleware(request, call_next)
        print("✅ Zero Trust validation completed")
        return result
    except Exception as e:
        print(f"❌ Zero Trust middleware error: {e}")
        print(f"   Error type: {type(e)}")
        import traceback
        print(f"   Traceback: {traceback.format_exc()}")
        raise

@app.on_event("startup")
async def startup_event():
    """Initialize Zero Trust middleware on startup"""
    global zero_trust_middleware
    
    logger.info("🚀 Starting OneVault Zero Trust Gateway - Local Test Server")
    
    # Load configuration
    config = get_config()
    
    # Override for localhost testing
    config.database.host = "localhost"
    config.database.database = "one_vault_site_testing"  # Use your local test DB
    config.redis.enabled = False  # Disable Redis for local testing
    config.environment = "development"
    
    # Validate configuration
    config_errors = validate_config()
    if config_errors:
        logger.error("❌ Configuration errors:")
        for error in config_errors:
            logger.error(f"   - {error}")
        raise Exception("Invalid configuration")
    
    # Check database password
    if config.database.password == 'your_password_here':
        logger.warning("⚠️  Using default database password - set DB_PASSWORD environment variable")
    
    # Initialize Zero Trust middleware
    zero_trust_middleware = ZeroTrustGatewayMiddleware(
        db_config=config.database.to_dict(),
        redis_url=None  # No Redis for local testing
    )
    
    logger.info("✅ Zero Trust Gateway middleware initialized")
    logger.info(f"📊 Database: {config.database.host}:{config.database.port}/{config.database.database}")
    logger.info("🌐 Server ready for local testing")

# Health check endpoint (no authentication required)
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "zero_trust_gateway_local_test",
        "version": "1.0.0"
    }

# Metrics endpoint (no authentication required)
@app.get("/metrics")
async def get_metrics():
    """Get Zero Trust middleware performance metrics"""
    if zero_trust_middleware:
        return zero_trust_middleware.get_performance_metrics()
    else:
        return {"error": "Middleware not initialized"}

# Test endpoint - Basic Zero Trust validation
@app.get("/api/v1/test/basic")
async def test_basic_auth(request: Request):
    """Basic authentication test - just validates Zero Trust context"""
    try:
        context = get_zero_trust_context(request)
        
        return {
            "status": "authenticated",
            "tenant_name": context.tenant_name,
            "tenant_hk": context.tenant_hk.hex(),
            "user_email": context.user_email,
            "access_level": context.access_level,
            "risk_score": context.risk_score,
            "auth_type": "api_token" if context.api_token_hk else "session",
            "validated_at": context.validated_at.isoformat(),
            "message": "✅ Zero Trust validation successful"
        }
        
    except Exception as e:
        logger.error(f"❌ Basic auth test failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Test endpoint - Tenant-specific access
@app.get("/api/v1/test/tenant/{tenant_id}")
async def test_tenant_access(tenant_id: str, request: Request):
    """Test tenant-specific access control"""
    try:
        context = get_zero_trust_context(request)
        
        # Validate tenant access
        if context.tenant_bk != tenant_id and context.access_level != 'ADMIN':
            raise HTTPException(
                status_code=403,
                detail=f"Access denied to tenant {tenant_id}. Your tenant: {context.tenant_bk}"
            )
        
        return {
            "status": "authorized",
            "requested_tenant": tenant_id,
            "actual_tenant": context.tenant_bk,
            "tenant_name": context.tenant_name,
            "access_level": context.access_level,
            "message": f"✅ Access granted to tenant {tenant_id}"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Tenant access test failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Test endpoint - Access level requirements
@app.get("/api/v1/test/admin")
async def test_admin_access(request: Request):
    """Test admin-level access requirements"""
    try:
        context = get_zero_trust_context(request)
        
        # Check admin access
        if context.access_level != 'ADMIN':
            raise HTTPException(
                status_code=403,
                detail=f"Admin access required. Current level: {context.access_level}"
            )
        
        return {
            "status": "admin_authorized",
            "user_email": context.user_email,
            "access_level": context.access_level,
            "tenant_name": context.tenant_name,
            "message": "✅ Admin access granted"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Admin access test failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Test endpoint - Simulate business resource access
@app.get("/api/v1/test/business/{resource_type}")
async def test_business_resource_access(resource_type: str, request: Request):
    """Test access to business resources with tenant isolation"""
    try:
        context = get_zero_trust_context(request)
        
        # Simulate business resource query with tenant isolation
        valid_resources = ['users', 'entities', 'assets', 'transactions']
        if resource_type not in valid_resources:
            raise HTTPException(status_code=404, detail=f"Resource type '{resource_type}' not found")
        
        return {
            "status": "resource_access_granted",
            "resource_type": resource_type,
            "tenant_context": {
                "tenant_hk": context.tenant_hk.hex(),
                "tenant_name": context.tenant_name,
                "tenant_bk": context.tenant_bk
            },
            "user_context": {
                "user_email": context.user_email,
                "access_level": context.access_level,
                "risk_score": context.risk_score
            },
            "simulated_query": f"SELECT * FROM business.{resource_type}_h WHERE tenant_hk = '{context.tenant_hk.hex()}'",
            "message": f"✅ Access granted to {resource_type} for tenant {context.tenant_name}"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Business resource access test failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Test endpoint - Performance benchmark
@app.get("/api/v1/test/performance")
async def test_performance(request: Request):
    """Test Zero Trust middleware performance"""
    try:
        start_time = datetime.now()
        context = get_zero_trust_context(request)
        processing_time = (datetime.now() - start_time).total_seconds() * 1000
        
        # Get middleware metrics
        metrics = zero_trust_middleware.get_performance_metrics() if zero_trust_middleware else {}
        
        return {
            "status": "performance_test_complete",
            "current_request_ms": round(processing_time, 2),
            "middleware_metrics": metrics,
            "performance_assessment": {
                "current_request": "🟢 FAST" if processing_time < 50 else ("🟡 MEDIUM" if processing_time < 200 else "🔴 SLOW"),
                "target_ms": 200,
                "actual_ms": round(processing_time, 2)
            },
            "tenant_context": {
                "tenant_name": context.tenant_name,
                "access_level": context.access_level,
                "risk_score": context.risk_score
            }
        }
        
    except Exception as e:
        logger.error(f"❌ Performance test failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Test endpoint - Cross-tenant validation
@app.get("/api/v1/test/cross-tenant/{other_tenant_id}")
async def test_cross_tenant_blocking(other_tenant_id: str, request: Request):
    """Test that cross-tenant access is properly blocked"""
    try:
        context = get_zero_trust_context(request)
        
        # This should fail unless user has ADMIN access
        if context.tenant_bk == other_tenant_id:
            return {
                "status": "same_tenant",
                "message": f"✅ Access to own tenant {other_tenant_id}",
                "tenant_bk": context.tenant_bk
            }
        elif context.access_level == 'ADMIN':
            return {
                "status": "admin_cross_tenant_access",
                "message": f"✅ Admin access granted to tenant {other_tenant_id}",
                "your_tenant": context.tenant_bk,
                "requested_tenant": other_tenant_id,
                "access_level": context.access_level
            }
        else:
            raise HTTPException(
                status_code=403,
                detail={
                    "error": "cross_tenant_access_denied",
                    "message": f"❌ Access denied to tenant {other_tenant_id}",
                    "your_tenant": context.tenant_bk,
                    "your_access_level": context.access_level,
                    "explanation": "Zero Trust Gateway blocks cross-tenant access"
                }
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Cross-tenant test failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Error handler for authentication failures
@app.exception_handler(401)
async def auth_exception_handler(request: Request, exc: HTTPException):
    """Custom handler for authentication failures"""
    return JSONResponse(
        status_code=401,
        content={
            "error": "authentication_required",
            "message": "Zero Trust Gateway: Authentication required",
            "details": exc.detail,
            "instructions": {
                "api_key": "Include 'Authorization: Bearer <api_key>' header",
                "session": "Include valid session token in cookies",
                "example": "curl -H 'Authorization: Bearer ovt_prod_...' http://localhost:8000/api/v1/test/basic"
            }
        }
    )

# Error handler for authorization failures
@app.exception_handler(403)
async def authz_exception_handler(request: Request, exc: HTTPException):
    """Custom handler for authorization failures"""
    return JSONResponse(
        status_code=403,
        content={
            "error": "authorization_denied",
            "message": "Zero Trust Gateway: Insufficient permissions",
            "details": exc.detail,
            "timestamp": datetime.now().isoformat()
        }
    )

def main():
    """Run the local test server"""
    
    # Check environment
    print("🛡️  OneVault Zero Trust Gateway - Local Test Server")
    print("=" * 60)
    print("🏠 Running on localhost for safe testing")
    print("📡 Connects to localhost database")
    print("🚀 Ready for API endpoint testing")
    print("=" * 60)
    
    # Configuration check
    config = get_config()
    if config.database.password == 'your_password_here':
        print("⚠️  WARNING: Using default database password")
        print("   Set DB_PASSWORD environment variable or update config.py")
    
    print(f"📊 Database: {config.database.host}:{config.database.port}/{config.database.database}")
    print("📝 API Documentation: http://localhost:8000/docs")
    print("🔍 Health Check: http://localhost:8000/health")
    print("📈 Metrics: http://localhost:8000/metrics")
    print()
    print("🧪 Test Endpoints:")
    print("   Basic Auth: GET /api/v1/test/basic")
    print("   Tenant Access: GET /api/v1/test/tenant/{tenant_id}")
    print("   Admin Access: GET /api/v1/test/admin")
    print("   Business Resources: GET /api/v1/test/business/{resource_type}")
    print("   Performance: GET /api/v1/test/performance")
    print("   Cross-Tenant: GET /api/v1/test/cross-tenant/{other_tenant_id}")
    print()
    print("🔑 Authentication Required:")
    print("   Include: Authorization: Bearer <your_api_token>")
    print("   Or: Session token in cookies")
    print("=" * 60)
    
    # Start server
    uvicorn.run(
        "local_api_test:app",
        host="127.0.0.1",
        port=8000,
        log_level="info",
        reload=True,  # Auto-reload on code changes
        access_log=True
    )

if __name__ == "__main__":
    main() 