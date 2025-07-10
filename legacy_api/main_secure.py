"""
OneVault API - SECURE VERSION with OVT-API-Token Tenant Isolation
===============================================================
"""

from fastapi import FastAPI, HTTPException, Depends, Request
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
    title="OneVault API - SECURE",
    version="2.0.0-secure",
    description="Multi-tenant business analytics API with OVT-API-Token security"
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

# OVT-API-Token validation
async def validate_ovt_api_token(request: Request) -> Dict[str, Any]:
    """Validate OVT-API-Token and return tenant context"""
    ovt_token = request.headers.get('OVT-API-Token')
    
    if not ovt_token:
        logger.warning(f"Missing OVT-API-Token from {request.client.host}")
        raise HTTPException(
            status_code=401, 
            detail="Missing OVT-API-Token header. Each tenant must provide their unique API token."
        )
    
    if not ovt_token.startswith('ovt_'):
        logger.warning(f"Invalid OVT-API-Token format from {request.client.host}")
        raise HTTPException(
            status_code=401,
            detail="Invalid OVT-API-Token format. Token must start with 'ovt_'"
        )
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Validate token and get tenant context
        cursor.execute("""
            SELECT 
                tenant_hk,
                tenant_bk,
                company_name,
                is_active,
                token_expires_at
            FROM auth.api_token_s ats
            JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
            JOIN auth.tenant_h th ON ath.tenant_hk = th.tenant_hk
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE ats.token_value = %s 
            AND ats.load_end_date IS NULL
            AND tps.load_end_date IS NULL
            AND ats.is_active = true
            AND (ats.token_expires_at IS NULL OR ats.token_expires_at > CURRENT_TIMESTAMP)
        """, (ovt_token,))
        
        result = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not result:
            logger.warning(f"Invalid or expired OVT-API-Token: {ovt_token[:20]}...")
            raise HTTPException(
                status_code=401,
                detail="Invalid or expired OVT-API-Token"
            )
        
        tenant_hk, tenant_bk, company_name, is_active, expires_at = result
        
        if not is_active:
            logger.warning(f"Inactive tenant attempted access: {company_name}")
            raise HTTPException(
                status_code=403,
                detail="Tenant account is inactive"
            )
        
        logger.info(f"Valid OVT-API-Token for tenant: {company_name}")
        
        return {
            "tenant_hk": tenant_hk,
            "tenant_bk": tenant_bk,
            "company_name": company_name,
            "token": ovt_token,
            "expires_at": expires_at
        }
        
    except psycopg2.Error as e:
        logger.error(f"Database error validating token: {e}")
        raise HTTPException(status_code=500, detail="Token validation failed")
    except HTTPException:
        raise  # Re-raise HTTP exceptions
    except Exception as e:
        logger.error(f"Unexpected error validating token: {e}")
        raise HTTPException(status_code=500, detail="Token validation failed")

# Health check
@app.get("/")
@app.get("/health")
async def health_check():
    """Basic health check"""
    return {
        "status": "healthy",
        "service": "OneVault API - SECURE",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "2.0.0-secure",
        "security": "OVT-API-Token required for authentication"
    }

# SECURE Authentication endpoints
@app.post("/api/v1/auth/login")
async def secure_login(
    request: Request, 
    login_data: LoginRequest,
    tenant_context: Dict[str, Any] = Depends(validate_ovt_api_token)
):
    """SECURE: Authenticate user within tenant context only"""
    logger.info(f"Secure login attempt for {login_data.username} in tenant {tenant_context['company_name']}")
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Prepare SECURE request data with tenant context
        request_data = {
            "username": login_data.username,
            "password": login_data.password,
            "tenant_hk": tenant_context["tenant_hk"].hex(),  # CRITICAL: Tenant filtering
            "ip_address": request.client.host if request.client else "127.0.0.1",
            "user_agent": request.headers.get('User-Agent', 'Unknown'),
            "auto_login": login_data.auto_login,
            "api_token": tenant_context["token"]  # Include for audit
        }
        
        # Call SECURE database function with tenant filtering
        cursor.execute("SELECT api.auth_login_secure(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            
            # Add security audit info
            response_data["security"] = {
                "tenant_verified": True,
                "tenant_name": tenant_context["company_name"],
                "token_validated": True
            }
            
            logger.info(f"Secure login successful for {login_data.username} in {tenant_context['company_name']}")
            return response_data
        else:
            logger.warning(f"Secure login failed for {login_data.username} in {tenant_context['company_name']}")
            raise HTTPException(status_code=401, detail="Authentication failed")
            
    except psycopg2.Error as e:
        if "function api.auth_login_secure" in str(e):
            logger.error("Secure auth function not deployed - falling back to insecure version")
            # Fallback to regular function with tenant filtering
            return await fallback_secure_login(request, login_data, tenant_context)
        logger.error(f"Database error in secure login: {e}")
        raise HTTPException(status_code=500, detail=f"Authentication error: {str(e)}")
    except Exception as e:
        logger.error(f"Unexpected error in secure login: {e}")
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")

async def fallback_secure_login(
    request: Request,
    login_data: LoginRequest, 
    tenant_context: Dict[str, Any]
):
    """Fallback to existing function with manual tenant filtering"""
    logger.info("Using fallback secure login with manual tenant filtering")
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Use existing function but verify tenant afterward
        request_data = {
            "username": login_data.username,
            "password": login_data.password,
            "ip_address": request.client.host if request.client else "127.0.0.1",
            "user_agent": request.headers.get('User-Agent', 'Unknown'),
            "auto_login": login_data.auto_login
        }
        
        cursor.execute("SELECT api.auth_login(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        if result and result[0]:
            response_data = result[0]
            
            # CRITICAL: Verify user belongs to the token's tenant
            if response_data.get("success"):
                user_data = response_data.get("data", {}).get("user_data", {})
                user_id = user_data.get("user_id")
                
                if user_id:
                    # Check if user belongs to this tenant
                    cursor.execute("""
                        SELECT 1 FROM auth.user_h uh
                        WHERE uh.user_hk = %s::bytea
                        AND uh.tenant_hk = %s::bytea
                    """, (bytes.fromhex(user_id), tenant_context["tenant_hk"]))
                    
                    tenant_match = cursor.fetchone()
                    
                    if not tenant_match:
                        logger.warning(f"SECURITY VIOLATION: User {login_data.username} attempted cross-tenant access")
                        cursor.close()
                        conn.close()
                        raise HTTPException(
                            status_code=403, 
                            detail="Access denied: User not authorized for this tenant"
                        )
                    
                    # Add security verification
                    response_data["security"] = {
                        "tenant_verified": True,
                        "tenant_name": tenant_context["company_name"],
                        "cross_tenant_blocked": True
                    }
                    
                    logger.info(f"Fallback secure login successful - tenant verified")
        
        cursor.close()
        conn.close()
        return response_data
        
    except Exception as e:
        logger.error(f"Fallback secure login error: {e}")
        raise HTTPException(status_code=500, detail="Authentication failed")

@app.post("/api/v1/auth/complete-login")
async def secure_complete_login(
    request: Request, 
    complete_data: CompleteLoginRequest,
    tenant_context: Dict[str, Any] = Depends(validate_ovt_api_token)
):
    """SECURE: Complete login process with tenant verification"""
    logger.info(f"Secure complete login for {complete_data.username} in tenant {tenant_context['company_name']}")
    
    # Verify the tenant_id matches the token's tenant
    if complete_data.tenant_id != tenant_context["tenant_bk"]:
        logger.warning(f"Tenant ID mismatch: requested {complete_data.tenant_id}, token for {tenant_context['tenant_bk']}")
        raise HTTPException(
            status_code=403,
            detail="Tenant ID does not match API token"
        )
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        request_data = {
            "username": complete_data.username,
            "tenant_id": complete_data.tenant_id,
            "tenant_hk": tenant_context["tenant_hk"].hex(),  # Add tenant context
            "ip_address": request.client.host if request.client else "127.0.0.1",
            "user_agent": request.headers.get('User-Agent', 'Unknown')
        }
        
        cursor.execute("SELECT api.auth_complete_login(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            response_data["security"] = {
                "tenant_verified": True,
                "tenant_name": tenant_context["company_name"]
            }
            return response_data
        else:
            raise HTTPException(status_code=500, detail="Complete login failed")
            
    except Exception as e:
        logger.error(f"Secure complete login error: {e}")
        raise HTTPException(status_code=500, detail=f"Complete login error: {str(e)}")

# Original insecure endpoints (for comparison/migration)
@app.post("/api/v1/auth/login-insecure")
async def insecure_login(request: Request, login_data: LoginRequest):
    """INSECURE: Original authentication endpoint - DO NOT USE IN PRODUCTION"""
    logger.warning("INSECURE authentication endpoint used - implement OVT-API-Token!")
    
    # Add warning headers
    return {
        "warning": "This endpoint is insecure and allows cross-tenant attacks",
        "recommendation": "Use /api/v1/auth/login with OVT-API-Token header",
        "security_risk": "HIGH - Cross-tenant login possible"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 