"""
OneVault API - DEBUG VERSION with Enhanced Error Logging
"""

from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, Any
import os
import psycopg2
from datetime import datetime
import json
import logging
import traceback

# Enhanced logging setup
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="OneVault API - DEBUG",
    version="1.0.0",
    description="DEBUG VERSION: Multi-tenant business analytics and site tracking API"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection with enhanced debugging
def get_db_connection():
    """Get database connection from environment with detailed debugging"""
    try:
        database_url = os.getenv('SYSTEM_DATABASE_URL')
        logger.info(f"Database URL (first 50 chars): {database_url[:50] if database_url else 'None'}...")
        
        if not database_url:
            logger.error("SYSTEM_DATABASE_URL environment variable not set")
            raise ValueError("SYSTEM_DATABASE_URL environment variable not set")
        
        logger.info("Attempting database connection...")
        conn = psycopg2.connect(database_url)
        logger.info("Database connection successful")
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        logger.error(f"Exception type: {type(e)}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

# Customer validation
async def validate_customer_header(request: Request) -> str:
    """Validate customer ID from header"""
    customer_id = request.headers.get('X-Customer-ID')
    logger.info(f"Customer ID from header: {customer_id}")
    
    if not customer_id:
        logger.error("Missing X-Customer-ID header")
        raise HTTPException(status_code=400, detail="Missing X-Customer-ID header")
    return customer_id

# Health check
@app.get("/")
@app.get("/health")
async def health_check():
    """Basic health check"""
    return {
        "status": "healthy",
        "service": "OneVault API - DEBUG",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0-debug"
    }

# Enhanced health check with database test
@app.get("/health/db")
async def database_health_check():
    """Test database connection and function existence"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Test 1: Basic query
        cursor.execute("SELECT 1")
        basic_result = cursor.fetchone()
        logger.info(f"Basic database query result: {basic_result}")
        
        # Test 2: Check schemas
        cursor.execute("SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('api', 'auth', 'util', 'raw')")
        schemas = cursor.fetchall()
        logger.info(f"Available schemas: {schemas}")
        
        # Test 3: Check if api.track_site_event function exists
        cursor.execute("""
            SELECT p.proname, pg_get_function_arguments(p.oid) 
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api' AND p.proname = 'track_site_event'
        """)
        functions = cursor.fetchall()
        logger.info(f"api.track_site_event function: {functions}")
        
        cursor.close()
        conn.close()
        
        return {
            "status": "healthy",
            "database_connection": "ok",
            "basic_query": "ok",
            "schemas_found": [s[0] for s in schemas],
            "api_function_exists": len(functions) > 0,
            "function_details": functions[0] if functions else None
        }
        
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=503, detail=f"Database health check failed: {str(e)}")

# Site tracking endpoint with enhanced debugging
@app.post("/api/v1/track")
async def track_site_event(
    request: Request,
    event_data: Dict[str, Any],
    customer_id: str = Depends(validate_customer_header)
):
    """Track site events for customers - DEBUG VERSION"""
    logger.info("=== TRACKING REQUEST START ===")
    logger.info(f"Customer ID: {customer_id}")
    logger.info(f"Event data: {event_data}")
    logger.info(f"Request headers: {dict(request.headers)}")
    logger.info(f"Client IP: {request.client.host if request.client else 'Unknown'}")
    
    try:
        # Get authorization header
        auth_header = request.headers.get('Authorization')
        logger.info(f"Authorization header: {auth_header[:20]}..." if auth_header else "None")
        
        if not auth_header or not auth_header.startswith('Bearer '):
            logger.error("Missing or invalid Authorization header")
            raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
        
        token = auth_header.replace('Bearer ', '')
        logger.info(f"Token (first 20 chars): {token[:20]}...")
        
        # Connect to database
        logger.info("Connecting to database...")
        conn = get_db_connection()
        cursor = conn.cursor()
        logger.info("Database connection established")
        
        # Prepare parameters
        params = (
            request.client.host if request.client else '127.0.0.1',  # p_ip_address (INET)
            request.headers.get('User-Agent', 'Unknown'),  # p_user_agent (TEXT)
            event_data.get('page_url'),  # p_page_url (TEXT)
            event_data.get('event_type', 'page_view'),  # p_event_type (VARCHAR)
            json.dumps(event_data.get('event_data', {}))  # p_event_data (JSONB)
        )
        logger.info(f"Function parameters: {params}")
        
        # Call the database function with enhanced error catching
        logger.info("Executing database function...")
        cursor.execute("""
            SELECT api.track_site_event(
                %s, %s, %s, %s, %s
            )
        """, params)
        
        result = cursor.fetchone()
        logger.info(f"Database function result: {result}")
        
        conn.commit()
        cursor.close()
        conn.close()
        logger.info("Database connection closed")
        
        if result and result[0]:
            response_data = result[0]  # This is already a dict from JSONB
            logger.info(f"Parsed response data: {response_data}")
            
            final_response = {
                "success": response_data.get('success', False),
                "message": response_data.get('message', 'Event tracked'),
                "event_id": response_data.get('event_id'),
                "timestamp": datetime.utcnow().isoformat()
            }
            logger.info(f"Final response: {final_response}")
            return final_response
        else:
            logger.error("Database function returned no result")
            raise HTTPException(status_code=500, detail="Failed to track event - no result returned")
            
    except psycopg2.Error as e:
        logger.error(f"PostgreSQL error: {e}")
        logger.error(f"SQLSTATE: {e.pgcode}")
        logger.error(f"Error details: {e.pgerror}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        logger.error(f"Exception type: {type(e)}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")
    finally:
        logger.info("=== TRACKING REQUEST END ===")

# Platform info endpoint
@app.get("/api/v1/platform/info")
async def platform_info():
    """Get platform information"""
    return {
        "platform": {
            "name": "OneVault - DEBUG",
            "version": "1.0.0-debug",
            "architecture": "multi-tenant",
            "features": [
                "site_tracking",
                "multi_tenant_isolation",
                "data_vault_2_0",
                "hipaa_compliance",
                "debug_logging"
            ]
        },
        "timestamp": datetime.utcnow().isoformat()
    }

# Debug endpoint to test database function directly
@app.post("/debug/test-db-function")
async def test_db_function_directly():
    """Test the database function directly with fixed parameters"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Test parameters
        test_params = (
            '192.168.1.100',  # p_ip_address
            'Debug-Test-Agent/1.0',  # p_user_agent
            'https://debug.test.com/page',  # p_page_url
            'debug_test',  # p_event_type
            json.dumps({'debug': True, 'test': 'direct_call'})  # p_event_data
        )
        
        logger.info(f"Testing function with parameters: {test_params}")
        
        cursor.execute("""
            SELECT api.track_site_event(
                %s, %s, %s, %s, %s
            )
        """, test_params)
        
        result = cursor.fetchone()
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return {
            "success": True,
            "message": "Database function test completed",
            "result": result[0] if result else None,
            "test_params": test_params
        }
        
    except Exception as e:
        logger.error(f"Direct function test failed: {e}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        return {
            "success": False,
            "error": str(e),
            "error_type": str(type(e))
        }

# For Vercel
def handler(request, context):
    return app

# For local development
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="debug") 