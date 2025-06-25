"""
OneVault API - Simplified Vercel Deployment
==========================================
"""

from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, Any, Optional
import os
import psycopg2
from datetime import datetime
import json

# Pydantic models for authentication
class LoginRequest(BaseModel):
    username: str
    password: str
    auto_login: Optional[bool] = True

class CompleteLoginRequest(BaseModel):
    username: str
    tenant_id: str

class ValidateSessionRequest(BaseModel):
    session_token: str

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

# Enhanced health check for database functions
@app.get("/health/db")
async def health_check_database():
    """Check database connectivity and function availability"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check available API functions
        cursor.execute("""
            SELECT p.proname as function_name
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api'
            ORDER BY p.proname
        """)
        
        functions = [row[0] for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()
        
        return {
            "status": "healthy",
            "database": "connected",
            "api_functions": functions,
            "auth_functions_available": {
                "auth_login": "auth_login" in functions,
                "auth_complete_login": "auth_complete_login" in functions,
                "auth_validate_session": "auth_validate_session" in functions,
                "track_site_event": "track_site_event" in functions
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {
            "status": "unhealthy",
            "database": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }

# Authentication endpoints
@app.post("/api/v1/auth/login")
async def login(request: Request, login_data: LoginRequest):
    """Authenticate user and return session information"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Prepare request data for database function
        request_data = {
            "username": login_data.username,
            "password": login_data.password,
            "ip_address": request.client.host if request.client else "127.0.0.1",
            "user_agent": request.headers.get('User-Agent', 'Unknown'),
            "auto_login": login_data.auto_login
        }
        
        # Call the database function
        cursor.execute("SELECT api.auth_login(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            return result[0]  # Return the JSONB response directly
        else:
            raise HTTPException(status_code=500, detail="Authentication function returned no result")
            
    except psycopg2.Error as e:
        if "function api.auth_login" in str(e):
            raise HTTPException(status_code=501, detail="Authentication function not available in database")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")

@app.post("/api/v1/auth/complete-login")
async def complete_login(request: Request, complete_data: CompleteLoginRequest):
    """Complete login process for multi-tenant scenarios"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Prepare request data for database function
        request_data = {
            "username": complete_data.username,
            "tenant_id": complete_data.tenant_id,
            "ip_address": request.client.host if request.client else "127.0.0.1",
            "user_agent": request.headers.get('User-Agent', 'Unknown')
        }
        
        # Call the database function
        cursor.execute("SELECT api.auth_complete_login(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            return result[0]  # Return the JSONB response directly
        else:
            raise HTTPException(status_code=500, detail="Complete login function returned no result")
            
    except psycopg2.Error as e:
        if "function api.auth_complete_login" in str(e):
            raise HTTPException(status_code=501, detail="Complete login function not available in database")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")

@app.post("/api/v1/auth/validate")
async def validate_session(request: Request, validate_data: ValidateSessionRequest):
    """Validate session token"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Prepare request data for database function
        request_data = {
            "session_token": validate_data.session_token,
            "ip_address": request.client.host if request.client else "127.0.0.1",
            "user_agent": request.headers.get('User-Agent', 'Unknown')
        }
        
        # Call the database function
        cursor.execute("SELECT api.auth_validate_session(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            return result[0]  # Return the JSONB response directly
        else:
            raise HTTPException(status_code=500, detail="Session validation function returned no result")
            
    except psycopg2.Error as e:
        if "function api.auth_validate_session" in str(e):
            raise HTTPException(status_code=501, detail="Session validation function not available in database")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")

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
                "authentication",
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