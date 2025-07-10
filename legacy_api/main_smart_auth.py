"""
OneVault API - SMART AUTHENTICATION VERSION
==========================================
Uses intelligent tenant resolution from API tokens instead of requiring
users to manually send tenant_hk. Much cleaner and user-friendly!

Key Improvements:
- Users only send: username, password, api_token
- Tenant context automatically resolved from API token  
- No more silly tenant_hk requirements
- Maintains all security protections
"""

from fastapi import FastAPI, HTTPException, Depends, Request, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, Any, Optional
import os
import psycopg2
from datetime import datetime
import json
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Pydantic models for smart authentication
class SmartLoginRequest(BaseModel):
    username: str
    password: str
    api_token: str                  # 🧠 SMART: Only need API token, not tenant_hk!
    auto_login: Optional[bool] = True

class ValidateSessionRequest(BaseModel):
    session_token: str

# FastAPI app setup
app = FastAPI(
    title="OneVault API - Smart Authentication",
    description="Multi-tenant business optimization platform with intelligent authentication",
    version="2.1.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database configuration
DATABASE_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'one_vault_dev'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', '')
}

def get_db_connection():
    """Get database connection"""
    try:
        conn = psycopg2.connect(**DATABASE_CONFIG)
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        raise HTTPException(status_code=500, detail="Database connection failed")

def extract_api_token(request: Request) -> Optional[str]:
    """Extract API token from various sources"""
    # Try Authorization header first
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        return auth_header[7:]
    
    # Try OVT-API-Token header
    ovt_token = request.headers.get('OVT-API-Token')
    if ovt_token:
        return ovt_token
    
    # Try X-API-Token header
    x_token = request.headers.get('X-API-Token')
    if x_token:
        return x_token
    
    return None

@app.get("/")
async def health_check():
    """Basic health check"""
    return {
        "status": "healthy",
        "service": "OneVault API - Smart Authentication",
        "version": "2.1.0",
        "timestamp": datetime.now().isoformat(),
        "authentication": "smart_tenant_resolution"
    }

@app.get("/health")
async def detailed_health():
    """Detailed health check"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Test database connectivity
        cursor.execute("SELECT version()")
        db_version = cursor.fetchone()[0]
        
        # Check smart authentication availability
        cursor.execute("""
            SELECT COUNT(*) FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api' AND p.proname = 'auth_login_smart'
        """)
        smart_auth_available = cursor.fetchone()[0] > 0
        
        # Check API token system
        cursor.execute("""
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = 'auth' 
            AND table_name IN ('api_token_h', 'api_token_s')
        """)
        token_system_ready = cursor.fetchone()[0] >= 2
        
        cursor.close()
        conn.close()
        
        return {
            "status": "healthy",
            "database": {
                "connected": True,
                "version": db_version
            },
            "authentication": {
                "smart_auth_available": smart_auth_available,
                "token_system_ready": token_system_ready,
                "tenant_resolution": "automatic_from_api_token"
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }

@app.get("/health/tokens")
async def token_health():
    """Check API token system health"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get token statistics
        cursor.execute("""
            SELECT 
                COUNT(*) as total_tokens,
                COUNT(*) FILTER (WHERE ats.is_active = true) as active_tokens,
                COUNT(*) FILTER (WHERE ats.expires_at IS NULL OR ats.expires_at > CURRENT_TIMESTAMP) as valid_tokens,
                MAX(ats.last_used_at) as last_token_usage
            FROM auth.api_token_h ath
            JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk
            WHERE ats.load_end_date IS NULL
        """)
        
        stats = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        return {
            "token_system": {
                "total_tokens": stats[0],
                "active_tokens": stats[1], 
                "valid_tokens": stats[2],
                "last_usage": stats[3].isoformat() if stats[3] else None
            },
            "status": "healthy" if stats[1] > 0 else "no_active_tokens",
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Token health check failed: {e}")
        raise HTTPException(status_code=500, detail=f"Token system check failed: {e}")

@app.post("/api/v1/auth/login")
async def smart_login(request: SmartLoginRequest, req: Request):
    """
    🧠 SMART AUTHENTICATION ENDPOINT
    
    Users only need to provide:
    - username
    - password  
    - api_token
    
    Tenant context is automatically resolved from the API token!
    No more silly tenant_hk requirements.
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get client info
        client_ip = req.client.host
        user_agent = req.headers.get('user-agent', 'Unknown')
        
        # Prepare request for smart authentication
        auth_request = {
            "username": request.username,
            "password": request.password,
            "api_token": request.api_token,
            "ip_address": client_ip,
            "user_agent": user_agent,
            "auto_login": request.auto_login
        }
        
        # Call smart authentication function
        cursor.execute(
            "SELECT api.auth_login_smart(%s)",
            (json.dumps(auth_request),)
        )
        
        result = cursor.fetchone()[0]
        cursor.close()
        conn.close()
        
        # Return the result from the database function
        if result.get('success'):
            logger.info(f"Smart authentication successful for {request.username}")
            return result
        else:
            logger.warning(f"Smart authentication failed for {request.username}: {result.get('message')}")
            # Return 401 for auth failures, but include the detailed response
            raise HTTPException(
                status_code=401, 
                detail=result
            )
            
    except psycopg2.Error as e:
        logger.error(f"Database error during smart authentication: {e}")
        raise HTTPException(
            status_code=500, 
            detail={
                "success": False,
                "message": "Database error during authentication",
                "error_code": "DATABASE_ERROR"
            }
        )
    except Exception as e:
        logger.error(f"Unexpected error during smart authentication: {e}")
        raise HTTPException(
            status_code=500,
            detail={
                "success": False,
                "message": "System error during authentication", 
                "error_code": "SYSTEM_ERROR"
            }
        )

@app.post("/api/v1/auth/validate-session")
async def validate_session(request: ValidateSessionRequest):
    """Validate session token"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Call session validation (this would use existing function)
        cursor.execute(
            "SELECT auth.validate_session(%s)",
            (request.session_token,)
        )
        
        result = cursor.fetchone()[0]
        cursor.close()
        conn.close()
        
        return result
        
    except Exception as e:
        logger.error(f"Session validation error: {e}")
        raise HTTPException(status_code=500, detail="Session validation failed")

@app.get("/api/v1/auth/tokens")
async def list_api_tokens(api_token: str = Header(..., alias="OVT-API-Token")):
    """
    List API tokens for the authenticated tenant
    Requires valid API token in OVT-API-Token header
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Resolve tenant from provided API token
        cursor.execute("SELECT auth.resolve_tenant_from_token(%s)", (api_token,))
        tenant_hk = cursor.fetchone()[0]
        
        if not tenant_hk:
            raise HTTPException(status_code=401, detail="Invalid API token")
        
        # Get tokens for this tenant
        cursor.execute("""
            SELECT 
                ath.api_token_bk,
                ats.token_name,
                ats.token_type,
                ats.is_active,
                ats.created_by,
                ats.expires_at,
                ats.last_used_at,
                ats.usage_count,
                ats.load_date
            FROM auth.api_token_h ath
            JOIN auth.api_token_s ats ON ath.api_token_hk = ats.api_token_hk
            WHERE ath.tenant_hk = %s
            AND ats.load_end_date IS NULL
            ORDER BY ats.load_date DESC
        """, (tenant_hk.tobytes(),))
        
        tokens = []
        for row in cursor.fetchall():
            tokens.append({
                "token_id": row[0][:12] + "...",  # Masked for security
                "token_name": row[1],
                "token_type": row[2], 
                "is_active": row[3],
                "created_by": row[4],
                "expires_at": row[5].isoformat() if row[5] else None,
                "last_used_at": row[6].isoformat() if row[6] else None,
                "usage_count": row[7],
                "created_at": row[8].isoformat()
            })
        
        cursor.close()
        conn.close()
        
        return {
            "tokens": tokens,
            "total_count": len(tokens),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Token listing error: {e}")
        raise HTTPException(status_code=500, detail="Failed to list API tokens")

@app.post("/api/v1/auth/tokens")
async def create_api_token(
    token_name: str,
    expires_days: Optional[int] = None,
    api_token: str = Header(..., alias="OVT-API-Token")
):
    """
    Create a new API token for the authenticated tenant
    Requires valid API token in OVT-API-Token header
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Resolve tenant from provided API token
        cursor.execute("SELECT auth.resolve_tenant_from_token(%s)", (api_token,))
        tenant_hk = cursor.fetchone()[0]
        
        if not tenant_hk:
            raise HTTPException(status_code=401, detail="Invalid API token")
        
        # Get tenant business key
        cursor.execute("SELECT tenant_bk FROM auth.tenant_h WHERE tenant_hk = %s", (tenant_hk.tobytes(),))
        tenant_bk = cursor.fetchone()[0]
        
        # Create new token
        cursor.execute(
            "SELECT auth.register_api_token(%s, %s, %s)",
            (tenant_bk, token_name, expires_days)
        )
        
        new_token = cursor.fetchone()[0]
        cursor.close()
        conn.close()
        
        return {
            "success": True,
            "message": "API token created successfully",
            "token": new_token,
            "token_name": token_name,
            "expires_days": expires_days,
            "created_at": datetime.now().isoformat(),
            "warning": "Store this token securely - it cannot be retrieved again"
        }
        
    except Exception as e:
        logger.error(f"Token creation error: {e}")
        raise HTTPException(status_code=500, detail="Failed to create API token")

# Legacy compatibility endpoint (for gradual migration)
@app.post("/api/v1/auth/login-legacy")
async def legacy_login_with_warning(request: dict, req: Request):
    """
    Legacy authentication endpoint with deprecation warning
    Automatically extracts API token and calls smart authentication
    """
    # Try to extract API token from headers
    api_token = extract_api_token(req)
    
    if not api_token:
        return {
            "success": False,
            "message": "API token required. Please update to use smart authentication.",
            "migration_help": {
                "new_endpoint": "/api/v1/auth/login",
                "required_fields": ["username", "password", "api_token"],
                "removed_fields": ["tenant_hk"],
                "benefits": "Automatic tenant resolution, cleaner API, better security"
            }
        }
    
    # Convert to smart login request
    smart_request = SmartLoginRequest(
        username=request.get('username'),
        password=request.get('password'),
        api_token=api_token,
        auto_login=request.get('auto_login', True)
    )
    
    # Call smart login with deprecation warning
    result = await smart_login(smart_request, req)
    
    # Add deprecation warning to response
    if isinstance(result, dict):
        result['deprecation_warning'] = {
            "message": "This endpoint is deprecated. Please migrate to /api/v1/auth/login",
            "migration_deadline": "2025-12-31",
            "new_endpoint": "/api/v1/auth/login"
        }
    
    return result

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 