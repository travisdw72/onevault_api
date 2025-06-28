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