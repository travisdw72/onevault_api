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

from fastapi import FastAPI, HTTPException, Depends, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List

# Phase 1 Zero Trust Gateway Integration
from app.middleware.phase1_integration import ProductionZeroTrustMiddleware
from app.routers.phase1_monitoring import phase1_router, set_middleware_instance

# Pydantic models for authentication
class LoginRequest(BaseModel):
    username: str
    password: str
    auto_login: Optional[bool] = True

# AI Agent Pydantic models
class AIAgentRequest(BaseModel):
    agent_type: str  # 'business_analysis', 'data_science', 'customer_insight'
    query: str
    context: Optional[Dict[str, Any]] = {}
    session_id: Optional[str] = None

class AIAgentResponse(BaseModel):
    agent_id: str
    response: str
    confidence: float
    sources: List[str] = []
    session_id: str
    processing_time_ms: int
    timestamp: str

class PhotoAnalysisRequest(BaseModel):
    image_data: str  # base64 encoded
    image_type: str
    analysis_type: str = "horse_health"
    session_id: Optional[str] = None

# Database-compatible models (matching exact API contract)
class DatabaseLoginRequest(BaseModel):
    username: str
    password: str
    ip_address: Optional[str] = "127.0.0.1"
    user_agent: Optional[str] = "OneVault-API"
    auto_login: Optional[bool] = True

class DatabaseCompleteLoginRequest(BaseModel):
    session_token: Optional[str] = None
    mfa_code: Optional[str] = None
    tenant_selection: Optional[str] = None

class DatabaseValidateSessionRequest(BaseModel):
    session_token: str
    ip_address: Optional[str] = "127.0.0.1"
    user_agent: Optional[str] = "OneVault-API"

class DatabaseLogoutRequest(BaseModel):
    session_token: str

class DatabaseAICreateSessionRequest(BaseModel):
    tenant_id: Optional[str] = None
    agent_type: str = "business_intelligence_agent"
    session_purpose: str = "canvas_integration"
    metadata: Optional[Dict[str, Any]] = {}

class DatabaseAIChatRequest(BaseModel):
    session_id: str
    message: str
    context: Optional[Dict[str, Any]] = {}

class DatabaseTrackSiteEventRequest(BaseModel):
    ip_address: Optional[str] = "127.0.0.1"
    user_agent: Optional[str] = "OneVault-API"
    page_url: Optional[str] = "https://canvas.onevault.com"
    event_type: str
    event_data: Optional[Dict[str, Any]] = {}

class CompleteLoginRequest(BaseModel):
    username: str
    tenant_id: str

class ValidateSessionRequest(BaseModel):
    session_token: str

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

# 🚀 Phase 1 Zero Trust Gateway Integration (Fail-Safe Mode)
# Initialize and add Phase 1 middleware for parallel validation
try:
    phase1_middleware = ProductionZeroTrustMiddleware()
    app.add_middleware(ProductionZeroTrustMiddleware)
    set_middleware_instance(phase1_middleware)
    logger.info("🛡️ Phase 1 Zero Trust Gateway activated in FAIL-SAFE mode")
except Exception as e:
    logger.error(f"❌ Phase 1 integration failed: {e}")
    # Continue without Phase 1 - production remains unaffected

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

# Background processing function
def process_site_tracking_background():
    """Background task for processing site tracking events"""
    try:
        logger.info("🔄 Background processing: Starting site tracking pipeline...")
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Call the smart processing function
        cursor.execute("SELECT staging.auto_process_if_needed()")
        result = cursor.fetchone()
        conn.commit()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            logger.info(f"✅ Background processing completed: {result[0]}")
        else:
            logger.info("ℹ️ Background processing: No work needed")
            
    except Exception as e:
        logger.error(f"❌ Background processing failed: {e}")
        # Don't raise - background tasks should be silent

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
    """User authentication endpoint"""
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

# Legacy PHP-style endpoints for frontend compatibility
@app.post("/api/auth/validate.php")
async def validate_session_php(request: Request, validate_data: ValidateSessionRequest):
    """Legacy PHP-style session validation endpoint for frontend compatibility"""
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

class RefreshSessionRequest(BaseModel):
    session_token: str

@app.post("/api/auth/refresh.php")
async def refresh_session_php(request: Request, refresh_data: RefreshSessionRequest):
    """Legacy PHP-style session refresh endpoint for frontend compatibility"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # First validate the current session
        validate_request_data = {
            "session_token": refresh_data.session_token,
            "ip_address": request.client.host if request.client else "127.0.0.1",
            "user_agent": request.headers.get('User-Agent', 'Unknown')
        }
        
        # Call the validation function first
        cursor.execute("SELECT api.auth_validate_session(%s)", (json.dumps(validate_request_data),))
        validation_result = cursor.fetchone()
        
        if not validation_result or not validation_result[0]:
            cursor.close()
            conn.close()
            raise HTTPException(status_code=401, detail="Invalid session token")
        
        validation_data = validation_result[0]
        
        # If validation successful, return the same session (refresh logic can be enhanced later)
        if validation_data.get('success', False):
            cursor.close()
            conn.close()
            return {
                "success": True,
                "message": "Session refreshed successfully",
                "data": {
                    "session_token": refresh_data.session_token,
                    "user_data": validation_data.get('data', {}),
                    "expires_at": datetime.utcnow().isoformat() + "Z"
                }
            }
        else:
            cursor.close()
            conn.close()
            raise HTTPException(status_code=401, detail="Session validation failed")
            
    except psycopg2.Error as e:
        if "function api.auth_validate_session" in str(e):
            raise HTTPException(status_code=501, detail="Session validation function not available in database")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except HTTPException:
        raise  # Re-raise HTTP exceptions
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")

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
    """Track site events for customers with automatic processing"""
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
        
        # 🚀 AUTOMATIC PROCESSING: Trigger site tracking pipeline after event ingestion
        try:
            logger.info("🔄 Triggering automatic site tracking processing...")
            cursor.execute("SELECT staging.auto_process_if_needed()")
            processing_result = cursor.fetchone()
            conn.commit()
            
            if processing_result and processing_result[0]:
                logger.info(f"✅ Processing result: {processing_result[0]}")
            else:
                logger.info("ℹ️ No processing needed - all events up to date")
                
        except Exception as processing_error:
            # Don't fail the main request if processing fails
            logger.warning(f"⚠️ Site tracking processing failed (non-critical): {processing_error}")
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]  # This is already a dict from JSONB
            return {
                "success": response_data.get('success', False),
                "message": response_data.get('message', 'Event tracked'),
                "event_id": response_data.get('event_id'),
                "timestamp": datetime.utcnow().isoformat(),
                "processing": "automatic"  # Indicate automatic processing is enabled
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to track event")
            
    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Authentication or tracking failed")

# Alternative tracking endpoint with background processing
@app.post("/api/v1/track/async")
async def track_site_event_async(
    background_tasks: BackgroundTasks,
    request: Request,
    event_data: Dict[str, Any],
    customer_id: str = Depends(validate_customer_header),
    token: str = Depends(validate_auth_token)
):
    """Track site events with background processing (faster response)"""
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
        
        # 🚀 BACKGROUND PROCESSING: Schedule processing in background
        background_tasks.add_task(process_site_tracking_background)
        
        if result and result[0]:
            response_data = result[0]  # This is already a dict from JSONB
            return {
                "success": response_data.get('success', False),
                "message": response_data.get('message', 'Event tracked'),
                "event_id": response_data.get('event_id'),
                "timestamp": datetime.utcnow().isoformat(),
                "processing": "background"  # Indicate background processing is scheduled
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to track event")
            
    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Authentication or tracking failed")

# Site tracking management endpoints
@app.get("/api/v1/track/status")
async def get_tracking_status(
    customer_id: str = Depends(validate_customer_header),
    token: str = Depends(validate_auth_token)
):
    """Get site tracking pipeline status"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get pipeline status
        cursor.execute("SELECT * FROM staging.get_pipeline_status()")
        status_result = cursor.fetchone()
        
        # Get recent events from dashboard view
        cursor.execute("""
            SELECT * FROM staging.pipeline_dashboard 
            ORDER BY raw_load_date DESC 
            LIMIT 10
        """)
        recent_events = cursor.fetchall()
        
        # Get column names for the dashboard
        cursor.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_schema = 'staging' 
            AND table_name = 'pipeline_dashboard'
            ORDER BY ordinal_position
        """)
        column_names = [row[0] for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()
        
        # Format recent events
        events_list = []
        for event in recent_events:
            event_dict = dict(zip(column_names, event))
            events_list.append(event_dict)
        
        return {
            "status": "success",
            "pipeline_status": status_result[0] if status_result else None,
            "recent_events": events_list,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get tracking status: {str(e)}")

@app.post("/api/v1/track/process")
async def trigger_processing(
    customer_id: str = Depends(validate_customer_header),
    token: str = Depends(validate_auth_token)
):
    """Manually trigger site tracking processing"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Trigger processing
        cursor.execute("SELECT staging.trigger_pipeline_now()")
        result = cursor.fetchone()
        conn.commit()
        
        cursor.close()
        conn.close()
        
        return {
            "status": "success",
            "message": "Processing triggered successfully",
            "result": result[0] if result else None,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to trigger processing: {str(e)}")

@app.get("/api/v1/track/dashboard")
async def get_tracking_dashboard(
    customer_id: str = Depends(validate_customer_header),
    token: str = Depends(validate_auth_token),
    limit: int = 20
):
    """Get comprehensive tracking dashboard data"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get dashboard data
        cursor.execute(f"""
            SELECT * FROM staging.pipeline_dashboard 
            ORDER BY raw_load_date DESC 
            LIMIT {limit}
        """)
        dashboard_data = cursor.fetchall()
        
        # Get column names
        cursor.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_schema = 'staging' 
            AND table_name = 'pipeline_dashboard'
            ORDER BY ordinal_position
        """)
        column_names = [row[0] for row in cursor.fetchall()]
        
        # Get summary statistics
        cursor.execute("""
            SELECT 
                COUNT(*) as total_events,
                COUNT(CASE WHEN staging_status = 'PROCESSED' THEN 1 END) as processed_to_staging,
                COUNT(CASE WHEN business_status = '✅ Complete Pipeline' THEN 1 END) as processed_to_business,
                MAX(raw_load_date) as latest_event
            FROM staging.pipeline_dashboard
        """)
        stats = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        # Format dashboard data
        events_list = []
        for event in dashboard_data:
            event_dict = dict(zip(column_names, event))
            # Convert datetime objects to ISO strings
            for key, value in event_dict.items():
                if hasattr(value, 'isoformat'):
                    event_dict[key] = value.isoformat()
            events_list.append(event_dict)
        
        return {
            "status": "success",
            "summary": {
                "total_events": stats[0] if stats else 0,
                "processed_to_staging": stats[1] if stats else 0,
                "processed_to_business": stats[2] if stats else 0,
                "latest_event": stats[3].isoformat() if stats and stats[3] else None
            },
            "events": events_list,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get dashboard data: {str(e)}")

# =============================================================================
# AI AGENT ENDPOINTS - OneVault Canvas Integration
# =============================================================================

@app.get("/api/v1/ai/agents/status")
async def get_ai_agents_status(
    customer_id: str = Depends(validate_customer_header),
    token: str = Depends(validate_auth_token)
):
    """Get status of all AI agents for customer dashboard"""
    try:
        # Agent definitions with demo data
        agents = {
            "BAA-001": {
                "name": "Business Analysis Agent",
                "type": "business_analysis", 
                "status": "active",
                "health": "excellent",
                "last_analysis": "2025-07-02T15:30:00Z",
                "specialties": ["Financial Planning", "Risk Assessment", "Market Analysis"]
            },
            "DSA-001": {
                "name": "Data Science Agent",
                "type": "data_science",
                "status": "active", 
                "health": "excellent",
                "last_analysis": "2025-07-02T15:25:00Z",
                "specialties": ["Predictive Analytics", "Pattern Recognition", "Statistical Analysis"]
            },
            "CIA-001": {
                "name": "Customer Insight Agent", 
                "type": "customer_insight",
                "status": "active",
                "health": "excellent", 
                "last_analysis": "2025-07-02T15:28:00Z",
                "specialties": ["Behavior Analysis", "Sentiment Analysis", "Trend Prediction"]
            }
        }
        
        return {
            "customer_id": customer_id,
            "agents": agents,
            "total_agents": len(agents),
            "active_agents": sum(1 for a in agents.values() if a["status"] == "active"),
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ AI agents status failed: {e}")
        raise HTTPException(status_code=500, detail=f"Could not get AI agents status: {str(e)}")

@app.post("/api/v1/ai/analyze")
async def analyze_with_ai(
    request: Request,
    ai_request: AIAgentRequest,
    customer_id: str = Depends(validate_customer_header),
    token: str = Depends(validate_auth_token)
):
    """Main AI analysis endpoint - routes to appropriate AI agent"""
    start_time = datetime.utcnow()
    
    try:
        # Map agent types to agent IDs
        agent_mapping = {
            "business_analysis": "BAA-001",
            "data_science": "DSA-001", 
            "customer_insight": "CIA-001"
        }
        
        agent_id = agent_mapping.get(ai_request.agent_type, "UNKNOWN")
        
        if agent_id == "UNKNOWN":
            raise HTTPException(status_code=400, detail=f"Unknown agent type: {ai_request.agent_type}")
        
        # Generate session ID if not provided
        session_id = ai_request.session_id or f"{customer_id}_{int(datetime.utcnow().timestamp())}"
        
        # Demo AI responses based on agent type
        if ai_request.agent_type == "business_analysis":
            demo_response = f"""Based on your query "{ai_request.query}", here's my business analysis:

📊 **Key Insights:**
- Market opportunity identified in your sector
- Risk factors: Market volatility (15%), Competition (12%)
- Projected ROI: 18-22% over 24 months

💡 **Recommendations:**
1. Diversify revenue streams
2. Invest in customer retention (current churn: 8%)
3. Consider expansion into adjacent markets

📈 **Financial Impact:**
- Short-term: Increased operational costs by 12%
- Long-term: Revenue growth potential of 25-30%

*Analysis powered by OneVault Business Intelligence Engine*"""

        elif ai_request.agent_type == "data_science":
            demo_response = f"""Data Science Analysis for: "{ai_request.query}"

🔬 **Statistical Findings:**
- Correlation coefficient: 0.847 (strong positive)
- Data completeness: 94.2%
- Anomaly detection: 3 outliers identified

📊 **Predictive Model Results:**
- Accuracy: 91.3%
- Precision: 89.7%
- F1-Score: 0.905

🎯 **Recommendations:**
1. Implement real-time monitoring for top 5 KPIs
2. Address data quality issues in customer demographics
3. Deploy predictive model for early warning system

*Powered by OneVault Advanced Analytics*"""

        else:  # customer_insight
            demo_response = f"""Customer Insight Analysis: "{ai_request.query}"

👥 **Customer Behavior Patterns:**
- Peak engagement: Tuesday-Thursday (2-4 PM)
- Conversion rate: 12.3% (above industry average)
- Customer satisfaction: 8.7/10

💭 **Sentiment Analysis:**
- Positive sentiment: 67%
- Neutral sentiment: 28% 
- Negative sentiment: 5%

🎯 **Actionable Insights:**
1. Optimize content delivery for peak hours
2. Address top 3 pain points (identified from reviews)
3. Implement personalization for 15% conversion boost

*OneVault Customer Intelligence Platform*"""

        # Calculate processing time
        processing_time = int((datetime.utcnow() - start_time).total_seconds() * 1000)
        
        # 🔥 STORE AI INTERACTION IN DATABASE
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Call database function to store AI interaction
            cursor.execute("""
                SELECT business.store_ai_interaction(
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
            """, (
                customer_id,                    # p_tenant_identifier
                ai_request.query,               # p_question_text  
                demo_response,                  # p_response_text
                0.87,                           # p_confidence_score
                ai_request.agent_type,          # p_context_type
                f"gpt-4-{agent_id}",           # p_model_used
                processing_time,                # p_processing_time_ms
                len(ai_request.query.split()),  # p_token_count_input (estimate)
                len(demo_response.split()),     # p_token_count_output (estimate)
                session_id                      # p_session_id
            ))
            
            db_result = cursor.fetchone()
            conn.commit()
            cursor.close()
            conn.close()
            
            logger.info(f"✅ AI interaction stored in database: {db_result}")
            
        except Exception as db_error:
            logger.warning(f"⚠️ Failed to store AI interaction in database: {db_error}")
            # Don't fail the request if database storage fails
        
        return AIAgentResponse(
            agent_id=agent_id,
            response=demo_response,
            confidence=0.87,
            sources=[f"OneVault-{agent_id}", "Data Vault 2.0", f"Customer-{customer_id}"],
            session_id=session_id,
            processing_time_ms=processing_time,
            timestamp=datetime.utcnow().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ AI analysis failed: {e}")
        processing_time = int((datetime.utcnow() - start_time).total_seconds() * 1000)
        
        # Return graceful error response
        return AIAgentResponse(
            agent_id="ERROR",
            response=f"I apologize, but I encountered an error processing your request: {str(e)}. Please try again or contact support.",
            confidence=0.0,
            sources=["error_handler"],
            session_id=ai_request.session_id or "error_session",
            processing_time_ms=processing_time,
            timestamp=datetime.utcnow().isoformat()
        )

@app.post("/api/v1/ai/photo-analysis")
async def analyze_photo(
    request: Request,
    photo_request: PhotoAnalysisRequest,
    customer_id: str = Depends(validate_customer_header),
    token: str = Depends(validate_auth_token)  
):
    """AI-powered photo analysis endpoint"""
    start_time = datetime.utcnow()
    
    try:
        session_id = photo_request.session_id or f"photo_{customer_id}_{int(datetime.utcnow().timestamp())}"
        
        # Demo photo analysis response
        demo_response = f"""📸 **Photo Analysis Complete**

🔍 **Visual Analysis Results:**
- Image Quality: High (94% clarity)
- Subject Detection: 3 primary subjects identified
- Lighting Conditions: Optimal (natural daylight)
- Composition Score: 8.2/10

🎯 **Key Findings:**
1. **Subject Health Assessment**: Excellent condition observed
2. **Environmental Factors**: Clean, well-maintained environment
3. **Attention Areas**: Minor concern in lower-left quadrant

📊 **Confidence Metrics:**
- Overall Analysis: 91.2% confidence
- Health Assessment: 88.7% confidence
- Environmental Analysis: 94.3% confidence

💡 **Recommendations:**
- Continue current care routine
- Monitor identified area for 7-14 days
- Consider follow-up photo in 1 week

*Analysis powered by OneVault Vision AI*"""

        processing_time = int((datetime.utcnow() - start_time).total_seconds() * 1000)
        
        # 🔥 STORE PHOTO ANALYSIS IN DATABASE
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Store photo analysis as AI interaction
            cursor.execute("""
                SELECT business.store_ai_interaction(
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
            """, (
                customer_id,                                    # p_tenant_identifier
                f"Photo analysis: {photo_request.analysis_type}", # p_question_text
                demo_response,                                  # p_response_text
                0.912,                                          # p_confidence_score
                'photo_analysis',                               # p_context_type
                "vision-ai-v1",                                 # p_model_used
                processing_time,                                # p_processing_time_ms
                50,                                             # p_token_count_input (estimate for image)
                len(demo_response.split()),                     # p_token_count_output
                session_id                                      # p_session_id
            ))
            
            db_result = cursor.fetchone()
            conn.commit()
            cursor.close()
            conn.close()
            
            logger.info(f"✅ Photo analysis stored in database: {db_result}")
            
        except Exception as db_error:
            logger.warning(f"⚠️ Failed to store photo analysis in database: {db_error}")
            # Don't fail the request if database storage fails
        
        return {
            "analysis_id": f"PA_{session_id}",
            "customer_id": customer_id,
            "analysis_type": photo_request.analysis_type,
            "image_type": photo_request.image_type,
            "analysis_result": demo_response,
            "confidence_score": 0.912,
            "processing_time_ms": processing_time,
            "session_id": session_id,
            "timestamp": datetime.utcnow().isoformat(),
            "next_steps": [
                "Save analysis to customer dashboard",
                "Schedule follow-up if needed", 
                "Export detailed report"
            ]
        }
        
    except Exception as e:
        logger.error(f"❌ Photo analysis failed: {e}")
        raise HTTPException(status_code=500, detail=f"Photo analysis failed: {str(e)}")

# =============================================================================
# DATABASE-COMPATIBLE ENDPOINTS (Production API Contract)
# =============================================================================

@app.post("/api/auth_login")
async def database_auth_login(request: Request, login_data: DatabaseLoginRequest):
    """Database-compatible authentication endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get client IP and user agent
        client_ip = request.client.host if request.client else login_data.ip_address
        user_agent = request.headers.get('User-Agent', login_data.user_agent)
        
        # Prepare request data exactly as database expects
        request_data = {
            "username": login_data.username,
            "password": login_data.password,
            "ip_address": client_ip,
            "user_agent": user_agent,
            "auto_login": login_data.auto_login
        }
        
        # Call the database function
        cursor.execute("SELECT api.auth_login(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            logger.info(f"✅ Database auth_login successful for user: {login_data.username}")
            return response_data
        else:
            raise HTTPException(status_code=401, detail="Authentication failed")
            
    except Exception as e:
        logger.error(f"❌ Database auth_login error: {e}")
        raise HTTPException(status_code=500, detail=f"Authentication error: {str(e)}")

@app.post("/api/auth_complete_login")
async def database_auth_complete_login(request: Request, complete_data: DatabaseCompleteLoginRequest):
    """Database-compatible complete login endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Prepare request data
        request_data = {
            "session_token": complete_data.session_token,
            "mfa_code": complete_data.mfa_code,
            "tenant_selection": complete_data.tenant_selection
        }
        
        # Call the database function
        cursor.execute("SELECT api.auth_complete_login(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            logger.info("✅ Database auth_complete_login successful")
            return response_data
        else:
            raise HTTPException(status_code=401, detail="Complete login failed")
            
    except Exception as e:
        logger.error(f"❌ Database auth_complete_login error: {e}")
        raise HTTPException(status_code=500, detail=f"Complete login error: {str(e)}")

@app.post("/api/auth_validate_session")
async def database_auth_validate_session(request: Request, validate_data: DatabaseValidateSessionRequest):
    """Database-compatible session validation endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get client IP and user agent
        client_ip = request.client.host if request.client else validate_data.ip_address
        user_agent = request.headers.get('User-Agent', validate_data.user_agent)
        
        # Prepare request data
        request_data = {
            "session_token": validate_data.session_token,
            "ip_address": client_ip,
            "user_agent": user_agent
        }
        
        # Call the database function
        cursor.execute("SELECT api.auth_validate_session(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            logger.info("✅ Database auth_validate_session successful")
            return response_data
        else:
            raise HTTPException(status_code=401, detail="Session validation failed")
            
    except Exception as e:
        logger.error(f"❌ Database auth_validate_session error: {e}")
        raise HTTPException(status_code=500, detail=f"Session validation error: {str(e)}")

@app.post("/api/auth_logout")
async def database_auth_logout(request: Request, logout_data: DatabaseLogoutRequest):
    """Database-compatible logout endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Prepare request data
        request_data = {
            "session_token": logout_data.session_token
        }
        
        # Call the database function
        cursor.execute("SELECT api.auth_logout(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            logger.info("✅ Database auth_logout successful")
            return response_data
        else:
            raise HTTPException(status_code=500, detail="Logout failed")
            
    except Exception as e:
        logger.error(f"❌ Database auth_logout error: {e}")
        raise HTTPException(status_code=500, detail=f"Logout error: {str(e)}")

@app.post("/api/ai_create_session")
async def database_ai_create_session(request: Request, ai_data: DatabaseAICreateSessionRequest):
    """Database-compatible AI session creation endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Prepare request data
        request_data = {
            "tenant_id": ai_data.tenant_id or "default_tenant",
            "agent_type": ai_data.agent_type,
            "session_purpose": ai_data.session_purpose,
            "metadata": {
                "canvas_integration": True,
                **ai_data.metadata
            }
        }
        
        # Call the database function
        cursor.execute("SELECT api.ai_create_session(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            logger.info(f"✅ Database ai_create_session successful for agent: {ai_data.agent_type}")
            return response_data
        else:
            raise HTTPException(status_code=500, detail="AI session creation failed")
            
    except Exception as e:
        logger.error(f"❌ Database ai_create_session error: {e}")
        raise HTTPException(status_code=500, detail=f"AI session creation error: {str(e)}")

@app.post("/api/ai_secure_chat")
async def database_ai_secure_chat(request: Request, chat_data: DatabaseAIChatRequest):
    """Database-compatible AI chat endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Prepare request data
        request_data = {
            "session_id": chat_data.session_id,
            "message": chat_data.message,
            "context": chat_data.context
        }
        
        # Call the database function
        cursor.execute("SELECT api.ai_secure_chat(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            logger.info(f"✅ Database ai_secure_chat successful for session: {chat_data.session_id}")
            return response_data
        else:
            raise HTTPException(status_code=500, detail="AI chat failed")
            
    except Exception as e:
        logger.error(f"❌ Database ai_secure_chat error: {e}")
        raise HTTPException(status_code=500, detail=f"AI chat error: {str(e)}")

@app.post("/api/track_site_event")
async def database_track_site_event(request: Request, event_data: DatabaseTrackSiteEventRequest):
    """Database-compatible site event tracking endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get client IP and user agent
        client_ip = request.client.host if request.client else event_data.ip_address
        user_agent = request.headers.get('User-Agent', event_data.user_agent)
        
        # Prepare request data
        request_data = {
            "ip_address": client_ip,
            "user_agent": user_agent,
            "page_url": event_data.page_url,
            "event_type": event_data.event_type,
            "event_data": {
                "timestamp": datetime.utcnow().isoformat(),
                **event_data.event_data
            }
        }
        
        # Call the database function
        cursor.execute("SELECT api.track_site_event(%s)", (json.dumps(request_data),))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            logger.info(f"✅ Database track_site_event successful for event: {event_data.event_type}")
            return response_data
        else:
            raise HTTPException(status_code=500, detail="Site event tracking failed")
            
    except Exception as e:
        logger.error(f"❌ Database track_site_event error: {e}")
        raise HTTPException(status_code=500, detail=f"Site event tracking error: {str(e)}")

@app.get("/api/system_health_check")
async def database_system_health_check():
    """Database-compatible system health check endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Call the database function
        cursor.execute("SELECT api.system_health_check()")
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            logger.info("✅ Database system_health_check successful")
            return response_data
        else:
            raise HTTPException(status_code=500, detail="System health check failed")
            
    except Exception as e:
        logger.error(f"❌ Database system_health_check error: {e}")
        raise HTTPException(status_code=500, detail=f"System health check error: {str(e)}")

# Include Phase 1 Zero Trust monitoring endpoints
app.include_router(phase1_router)

# Error handler
@app.exception_handler(404)
async def not_found_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=404,
        content={
            "error": "Not Found",
            "message": f"The requested endpoint {request.url.path} was not found",
            "available_endpoints": [
                "/health",
                "/api/auth_login",
                "/api/auth_validate_session", 
                "/api/ai_create_session",
                "/api/ai_secure_chat",
                "/api/track_site_event",
                "/api/system_health_check",
                "/api/v1/auth/login",
                "/api/v1/track",
                "/api/v1/ai/analyze",
                "/api/v1/phase1/status",
                "/api/v1/phase1/health",
                "/api/v1/phase1/metrics"
            ],
            "documentation": "https://docs.onevault.com/api"
        }
    )

# For local development
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 