"""
OneVault API - Simplified Vercel Deployment
==========================================
"""

from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, Any
import os
import psycopg2
from datetime import datetime
import json

# Create FastAPI app
app = FastAPI(
    title="OneVault API",
    version="1.0.0",
    description="Multi-tenant business analytics and site tracking API"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly for production
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

# Health check
@app.get("/")
@app.get("/health")
async def health_check():
    """Basic health check"""
    return {
        "status": "healthy",
        "service": "OneVault API",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }

# Site tracking endpoint
@app.post("/api/v1/track")
async def track_site_event(
    request: Request,
    event_data: Dict[str, Any],
    customer_id: str = Depends(validate_customer_header)
):
    """Track site events for customers"""
    try:
        # Get authorization header
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
        
        token = auth_header.replace('Bearer ', '')
        
        # Connect to database
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Call the database function (simplified version)
        cursor.execute("""
            SELECT api.track_site_event(
                %s, %s, %s, %s, %s, %s, %s, %s
            )
        """, (
            token,  # p_api_token
            customer_id,  # p_customer_id
            event_data.get('session_id'),  # p_session_id
            event_data.get('page_url'),  # p_page_url
            event_data.get('event_type', 'page_view'),  # p_event_type
            json.dumps(event_data.get('event_data', {})),  # p_event_data
            event_data.get('user_agent'),  # p_user_agent
            request.client.host if request.client else None  # p_ip_address
        ))
        
        result = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            return {
                "success": response_data.get('p_success', False),
                "message": response_data.get('p_message', 'Event tracked'),
                "event_id": response_data.get('p_event_id'),
                "timestamp": datetime.utcnow().isoformat()
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to track event")
            
    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")

# Platform info endpoint
@app.get("/api/v1/platform/info")
async def platform_info():
    """Get platform information"""
    return {
        "platform": {
            "name": "OneVault",
            "version": "1.0.0",
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

# For Vercel
def handler(request, context):
    return app

# For local development
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 