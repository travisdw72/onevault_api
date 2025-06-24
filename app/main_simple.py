"""
OneVault Platform - Simplified Enterprise API for Render
=======================================================
"""

import logging
from datetime import datetime
from typing import Dict, Any, Optional

from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .core.config_simple import settings, customer_config_manager

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI application
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Multi-customer SaaS platform with complete database isolation"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Customer validation dependency
async def validate_customer_header(request: Request) -> str:
    """Validate and extract customer ID from request headers"""
    customer_id = request.headers.get('X-Customer-ID')
    
    if not customer_id:
        raise HTTPException(
            status_code=400,
            detail="Missing X-Customer-ID header"
        )
    
    if not customer_config_manager.is_valid_customer(customer_id):
        raise HTTPException(
            status_code=404,
            detail=f"Customer not found: {customer_id}"
        )
    
    return customer_id

# Health check endpoints
@app.get("/")
@app.get("/health")
async def health_check():
    """Basic health check"""
    return {
        "status": "healthy",
        "service": "OneVault Platform",  # This identifies it as enterprise API
        "timestamp": datetime.utcnow().isoformat(),
        "version": settings.APP_VERSION
    }

@app.get("/health/detailed")
async def detailed_health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "service": "OneVault Platform",
        "timestamp": datetime.utcnow().isoformat(),
        "version": settings.APP_VERSION,
        "database_status": "connected",
        "features": {
            "site_tracking": True,
            "multi_tenant": True,
            "data_vault": True,
            "compliance": True
        },
        "supported_industries": ["Health & Wellness", "Professional Services"],
        "compliance_frameworks": ["HIPAA", "GDPR"]
    }

@app.get("/health/customer/{customer_id}")
async def customer_health_check(customer_id: str):
    """Health check for specific customer"""
    if not customer_config_manager.is_valid_customer(customer_id):
        raise HTTPException(status_code=404, detail=f"Customer not found: {customer_id}")
    
    customer_config = customer_config_manager.get_customer_config(customer_id)
    
    return {
        "customer_id": customer_id,
        "customer_name": customer_config["customer"]["name"],
        "industry": customer_config["customer"]["industry"],
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "database_status": "connected",
        "compliance_enabled": customer_config["compliance"]
    }

# Platform info endpoint
@app.get("/api/v1/platform/info")
async def platform_info():
    """Get platform information"""
    return {
        "platform": {
            "name": settings.APP_NAME,
            "version": settings.APP_VERSION,
            "architecture": "multi-tenant",
            "features": [
                "site_tracking",
                "multi_tenant_isolation", 
                "data_vault_2_0",
                "hipaa_compliance"
            ]
        },
        "timestamp": datetime.utcnow().isoformat()
    }

# Customer configuration endpoint
@app.get("/api/v1/customer/config")
async def get_customer_config(customer_id: str = Depends(validate_customer_header)):
    """Get customer configuration"""
    config = customer_config_manager.get_customer_config(customer_id)
    
    return {
        "customer_id": customer_id,
        "config": config,
        "timestamp": datetime.utcnow().isoformat()
    }

# Site tracking endpoint
@app.post("/api/v1/track")
async def track_site_event(
    request: Request,
    event_data: Dict[str, Any],
    customer_id: str = Depends(validate_customer_header)
):
    """Track site events"""
    # Get authorization header
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    
    token = auth_header.replace('Bearer ', '')
    
    # Validate token (simplified)
    if token != "ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f":
        raise HTTPException(status_code=401, detail="Invalid API token")
    
    # Log the event (simplified)
    logger.info(f"Site event tracked for {customer_id}: {event_data.get('event_type', 'unknown')}")
    
    return {
        "success": True,
        "message": "Event tracked successfully",
        "event_id": f"evt_{customer_id}_{int(datetime.utcnow().timestamp())}",
        "customer_id": customer_id,
        "timestamp": datetime.utcnow().isoformat()
    }

# Startup event
@app.on_event("startup")
async def startup_event():
    """Application startup"""
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"Available customers: {customer_config_manager.get_all_customer_ids()}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 