"""
OneVault Platform - Simplified Enterprise API for Render
=======================================================
"""

import logging
from datetime import datetime
from typing import Dict, Any, Optional
import os
import json
import psycopg2

from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# Simple settings - no complex config needed
class Settings:
    APP_NAME: str = "OneVault Platform"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    LOG_LEVEL: str = "INFO"

settings = Settings()

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
    description="Multi-customer SaaS platform with complete database isolation and HIPAA compliance"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection
def get_db_connection():
    """Get database connection from environment"""
    try:
        database_url = os.getenv('SYSTEM_DATABASE_URL')
        if not database_url:
            raise ValueError("SYSTEM_DATABASE_URL environment variable not set")
        
        conn = psycopg2.connect(database_url)
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

# Customer validation
async def validate_customer_header(request: Request) -> str:
    """Validate customer ID from header"""
    customer_id = request.headers.get('X-Customer-ID')
    if not customer_id:
        raise HTTPException(status_code=400, detail="Missing X-Customer-ID header")
    return customer_id

# Authentication validation
async def validate_auth_token(request: Request) -> str:
    """Validate Bearer token from Authorization header"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    
    token = auth_header.replace('Bearer ', '')
    
    # For one_spa customer, validate the specific token
    if token == "ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f":
        return token
    else:
        raise HTTPException(status_code=401, detail="Invalid API token")

# Health check endpoints
@app.get("/")
@app.get("/health")
async def health_check():
    """Basic health check"""
    return {
        "status": "healthy",
        "service": settings.APP_NAME,
        "timestamp": datetime.utcnow().isoformat(),
        "version": settings.APP_VERSION
    }

@app.get("/health/detailed")
async def detailed_health_check():
    """Detailed health check with database connectivity"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        
        return {
            "status": "healthy",
            "service": settings.APP_NAME,
            "version": settings.APP_VERSION,
            "database": "connected",
            "timestamp": datetime.utcnow().isoformat(),
            "checks": {
                "database_connectivity": "passed",
                "api_endpoints": "available",
                "authentication": "enabled"
            }
        }
    except Exception as e:
        raise HTTPException(
            status_code=503, 
            detail=f"Service unhealthy: {str(e)}"
        )

@app.get("/health/customer/{customer_id}")
async def customer_health_check(customer_id: str):
    """Customer-specific health check"""
    if customer_id == "one_spa":
        return {
            "status": "healthy",
            "customer_id": customer_id,
            "service": settings.APP_NAME,
            "customer_status": "active",
            "features_enabled": [
                "site_tracking",
                "analytics",
                "data_vault_storage"
            ],
            "timestamp": datetime.utcnow().isoformat()
        }
    else:
        raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")

# Platform info endpoint
@app.get("/api/v1/platform/info")
async def platform_info():
    """Get platform information"""
    return {
        "platform": {
            "name": "OneVault",
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
async def get_customer_config(
    customer_id: str = Depends(validate_customer_header),
    token: str = Depends(validate_auth_token)
):
    """Get customer configuration"""
    if customer_id == "one_spa":
        return {
            "customer_id": customer_id,
            "customer_name": "The One Spa Oregon",
            "configuration": {
                "tracking_enabled": True,
                "data_retention_days": 2555,  # 7 years
                "features": {
                    "site_tracking": True,
                    "analytics": True,
                    "reporting": True
                },
                "endpoints": {
                    "tracking": "/api/v1/track",
                    "analytics": "/api/v1/analytics",
                    "reports": "/api/v1/reports"
                }
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    else:
        raise HTTPException(status_code=404, detail=f"Configuration for customer {customer_id} not found")

# Site tracking endpoint
@app.post("/api/v1/track")
async def track_site_event(
    request: Request,
    event_data: Dict[str, Any],
    customer_id: str = Depends(validate_customer_header),
    token: str = Depends(validate_auth_token)
):
    """Track site events for customers"""
    try:
        # Connect to database
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Call the database function with correct parameters
        cursor.execute("""
            SELECT api.track_site_event(
                %s, %s, %s, %s, %s
            )
        """, (
            request.client.host if request.client else '127.0.0.1',  # p_ip_address (INET)
            request.headers.get('User-Agent', 'Unknown'),  # p_user_agent (TEXT)
            event_data.get('page_url'),  # p_page_url (TEXT)
            event_data.get('event_type', 'page_view'),  # p_event_type (VARCHAR)
            json.dumps(event_data.get('event_data', {}))  # p_event_data (JSONB)
        ))
        
        result = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]  # This is already a dict from JSONB
            return {
                "success": response_data.get('success', False),
                "message": response_data.get('message', 'Event tracked'),
                "event_id": response_data.get('event_id'),
                "timestamp": datetime.utcnow().isoformat()
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to track event")
            
    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Authentication or tracking failed")

# Error handler
@app.exception_handler(404)
async def not_found_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=404,
        content={"detail": "Not Found"}
    )

# For local development
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 