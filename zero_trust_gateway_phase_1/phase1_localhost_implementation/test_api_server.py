"""
Phase 1 Test API Server
Simple FastAPI server for testing Phase 1 zero trust implementation
"""

import asyncio
import time
import uvicorn
from fastapi import FastAPI, HTTPException, Request, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import Optional, Dict, Any
import uuid

# Import Phase 1 components
from config import get_config
from parallel_validation import validate_request
from error_translation import translate_validation_response

# Initialize FastAPI app
app = FastAPI(
    title="Phase 1 Zero Trust Test API",
    description="Test API for Phase 1 zero trust implementation",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
config = get_config()

@app.middleware("http")
async def phase1_validation_middleware(request: Request, call_next):
    """Phase 1 validation middleware"""
    start_time = time.perf_counter()
    
    # Extract authentication info
    authorization = request.headers.get("authorization", "")
    token = authorization.replace("Bearer ", "") if authorization.startswith("Bearer ") else ""
    tenant_id = request.headers.get("x-tenant-id", "")
    
    # Skip validation for health checks and non-API endpoints
    if request.url.path in ["/health", "/", "/docs", "/openapi.json"]:
        response = await call_next(request)
        return response
    
    # Guard clause: Check if token and tenant are provided
    if not token or not tenant_id:
        return JSONResponse(
            status_code=401,
            content={
                "error": "Missing authentication",
                "message": "Bearer token and x-tenant-id header required"
            }
        )
    
    try:
        # Run Phase 1 validation
        validation_result = await validate_request(
            token=token,
            tenant_id=tenant_id,
            api_endpoint=request.url.path,
            user_agent=request.headers.get("user-agent", ""),
            ip_address=request.client.host if request.client else ""
        )
        
        # Check validation result
        if not validation_result.get("p_success", False):
            # Translate error for user-friendly response
            correlation_id = str(uuid.uuid4())
            user_friendly_response = translate_validation_response(
                validation_result, correlation_id
            )
            
            return JSONResponse(
                status_code=403,
                content=user_friendly_response
            )
        
        # Add validation metadata to request
        request.state.validation_result = validation_result
        request.state.validation_duration = int((time.perf_counter() - start_time) * 1000)
        
        # Continue to endpoint
        response = await call_next(request)
        
        # Add Phase 1 metadata to response headers
        response.headers["X-Phase1-Validation"] = "enabled"
        response.headers["X-Phase1-Duration"] = str(request.state.validation_duration)
        if "phase1_cache_hit" in validation_result:
            response.headers["X-Phase1-Cache-Hit"] = str(validation_result["phase1_cache_hit"])
        
        return response
        
    except Exception as e:
        # Handle validation errors gracefully
        correlation_id = str(uuid.uuid4())
        return JSONResponse(
            status_code=500,
            content={
                "error": "Validation service error",
                "message": "Please try again",
                "correlation_id": correlation_id
            }
        )

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Phase 1 Zero Trust Test API",
        "version": config.version,
        "implementation": config.implementation_name
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "phase1_enabled": config.zero_trust.parallel_validation_enabled
    }

@app.get("/api/test")
async def test_endpoint(request: Request):
    """Test endpoint for basic validation"""
    return {
        "message": "Test endpoint successful",
        "validation_duration": getattr(request.state, 'validation_duration', 0),
        "enhanced_available": request.state.validation_result.get("phase1_enhanced_available", False),
        "performance_improvement": request.state.validation_result.get("phase1_performance_improvement_ms", 0),
        "cache_hit": request.state.validation_result.get("phase1_cache_hit", False)
    }

@app.get("/api/patients")
async def get_patients(request: Request):
    """Simulated patients endpoint"""
    return {
        "patients": [
            {"id": 1, "name": "John Doe", "age": 30},
            {"id": 2, "name": "Jane Smith", "age": 25}
        ],
        "total": 2,
        "tenant_id": request.headers.get("x-tenant-id"),
        "validation_metadata": {
            "duration_ms": getattr(request.state, 'validation_duration', 0),
            "cache_hit": request.state.validation_result.get("phase1_cache_hit", False)
        }
    }

@app.get("/api/cross-tenant-test")
async def cross_tenant_test(request: Request):
    """Test cross-tenant access (should be blocked)"""
    return {
        "message": "This should be blocked by cross-tenant protection",
        "tenant_id": request.headers.get("x-tenant-id")
    }

@app.get("/api/performance-test")
async def performance_test(request: Request):
    """Performance testing endpoint"""
    # Simulate some processing time
    await asyncio.sleep(0.01)
    
    return {
        "message": "Performance test completed",
        "validation_duration": getattr(request.state, 'validation_duration', 0),
        "performance_improvement": request.state.validation_result.get("phase1_performance_improvement_ms", 0),
        "cache_hit": request.state.validation_result.get("phase1_cache_hit", False),
        "timestamp": time.time()
    }

@app.get("/api/metrics")
async def get_metrics():
    """Get Phase 1 performance metrics"""
    from parallel_validation import get_middleware
    from cache_manager import get_cache_manager
    
    middleware = get_middleware()
    cache_manager = get_cache_manager()
    
    return {
        "middleware_metrics": middleware.get_performance_metrics(),
        "cache_stats": cache_manager.get_stats(),
        "timestamp": time.time()
    }

@app.post("/api/test-error")
async def test_error_handling():
    """Test error handling and translation"""
    raise HTTPException(
        status_code=400,
        detail="Test error for error translation"
    )

# Custom exception handler for better error responses
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Custom HTTP exception handler with error translation"""
    from error_translation import translate_error
    
    correlation_id = str(uuid.uuid4())
    translated_error = translate_error(
        f"HTTP {exc.status_code}: {exc.detail}",
        correlation_id=correlation_id
    )
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": translated_error.user_message,
            "helpful_action": translated_error.helpful_action,
            "error_code": translated_error.error_code,
            "correlation_id": correlation_id
        }
    )

if __name__ == "__main__":
    # Run the server
    api_config = config.api
    
    print(f"🚀 Starting Phase 1 Test API Server...")
    print(f"   Host: {api_config.test_host}")
    print(f"   Port: {api_config.test_port}")
    print(f"   Debug: {api_config.debug}")
    print(f"   Implementation: {config.implementation_name}")
    print(f"   Parallel validation: {config.zero_trust.parallel_validation_enabled}")
    
    uvicorn.run(
        "test_api_server:app",
        host=api_config.test_host,
        port=api_config.test_port,
        debug=api_config.debug,
        reload=api_config.reload
    ) 