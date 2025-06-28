"""
OneVault API - Enhanced Site Tracking Implementation
==================================================
Consolidates best features with customer configuration support
"""

from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional, List
import os
import psycopg2
import yaml
from datetime import datetime
import json
import logging

# Enhanced Pydantic models
class TrackingEventRequest(BaseModel):
    event_type: str = Field(..., description="Type of event")
    page_url: Optional[str] = Field(None, description="URL where event occurred")
    event_data: Dict[str, Any] = Field(default_factory=dict, description="Additional event data")
    location_id: Optional[str] = Field(None, description="Specific location")
    user_id: Optional[str] = Field(None, description="User identifier")
    session_id: Optional[str] = Field(None, description="Session identifier")

class BulkTrackingRequest(BaseModel):
    events: List[TrackingEventRequest] = Field(..., description="Multiple events")
    batch_id: Optional[str] = Field(None, description="Batch identifier")

# Customer configuration cache
customer_configs = {}

def load_customer_config(customer_id: str) -> Dict[str, Any]:
    """Load customer configuration from YAML files"""
    if customer_id in customer_configs:
        return customer_configs[customer_id]
    
    try:
        config_path = f"example-customers/configurations/{customer_id}/config.yaml"
        features_path = f"example-customers/configurations/{customer_id}/features.yaml"
        
        config = {}
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                config.update(yaml.safe_load(f))
        
        if os.path.exists(features_path):
            with open(features_path, 'r') as f:
                features = yaml.safe_load(f)
                config['features'] = features
        
        customer_configs[customer_id] = config
        return config
    except Exception as e:
        logging.warning(f"Could not load config for customer {customer_id}: {e}")
        return {}

# Create FastAPI app
app = FastAPI(
    title="OneVault Enhanced Tracking API",
    version="2.0.0",
    description="Multi-tenant site tracking with customer configuration support"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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

async def validate_customer_header(request: Request) -> tuple[str, Dict[str, Any]]:
    """Validate customer ID and return customer config"""
    customer_id = request.headers.get('X-Customer-ID')
    if not customer_id:
        raise HTTPException(status_code=400, detail="Missing X-Customer-ID header")
    
    config = load_customer_config(customer_id)
    if not config:
        raise HTTPException(status_code=404, detail=f"Customer configuration not found for {customer_id}")
    
    return customer_id, config

async def validate_auth_token(request: Request, customer_id: str, config: Dict[str, Any]) -> str:
    """Validate Bearer token with customer-specific logic"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    
    token = auth_header.replace('Bearer ', '')
    
    # Customer-specific token validation
    if customer_id == "one_spa":
        valid_tokens = [
            "ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f",
            config.get('technical', {}).get('api_token')
        ]
        if token not in [t for t in valid_tokens if t]:
            raise HTTPException(status_code=401, detail="Invalid API token")
    
    return token

@app.get("/health/{customer_id}")
async def customer_health_check(customer_id: str):
    """Customer-specific health check with configuration"""
    config = load_customer_config(customer_id)
    
    if not config:
        raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")
    
    tracking_features = []
    if config.get('features', {}).get('analytics', {}).get('business_intelligence', {}).get('enabled'):
        tracking_features.append("business_intelligence")
    if config.get('features', {}).get('spa_wellness', {}).get('member_management', {}).get('enabled'):
        tracking_features.append("member_tracking")
    if config.get('features', {}).get('spa_wellness', {}).get('appointment_scheduling', {}).get('enabled'):
        tracking_features.append("appointment_tracking")
    
    return {
        "status": "healthy",
        "customer_id": customer_id,
        "customer_name": config.get('customer', {}).get('name', 'Unknown'),
        "service": "Enhanced Site Tracking API",
        "tracking_features": tracking_features,
        "rate_limit": config.get('technical', {}).get('api_rate_limit', 1000),
        "locations": len(config.get('customer', {}).get('locations', [])),
        "compliance": {
            "hipaa_required": config.get('customer', {}).get('compliance', {}).get('hipaa_required', False),
            "data_residency": config.get('customer', {}).get('compliance', {}).get('data_residency', 'US')
        },
        "timestamp": datetime.utcnow().isoformat()
    }

@app.post("/api/v1/track")
async def track_site_event(request: Request, event_request: TrackingEventRequest):
    """Enhanced site event tracking with customer configuration support"""
    try:
        customer_id, config = await validate_customer_header(request)
        token = await validate_auth_token(request, customer_id, config)
        
        rate_limit = config.get('technical', {}).get('api_rate_limit', 1000)
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        enhanced_event_data = {
            **event_request.event_data,
            "customer_id": customer_id,
            "location_id": event_request.location_id,
            "user_id": event_request.user_id,
            "session_id": event_request.session_id,
            "tracking_context": {
                "api_version": "2.0.0",
                "customer_config_version": config.get('metadata', {}).get('version'),
                "features_enabled": list(config.get('features', {}).keys())
            }
        }
        
        cursor.execute("""
            SELECT api.track_site_event(
                %s, %s, %s, %s, %s
            )
        """, (
            request.client.host if request.client else '127.0.0.1',
            request.headers.get('User-Agent', 'Unknown'),
            event_request.page_url,
            event_request.event_type,
            json.dumps(enhanced_event_data)
        ))
        
        result = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        if result and result[0]:
            response_data = result[0]
            return {
                "success": response_data.get('success', False),
                "message": response_data.get('message', 'Event tracked'),
                "event_id": response_data.get('event_id'),
                "customer_id": customer_id,
                "timestamp": datetime.utcnow().isoformat()
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to track event")
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 