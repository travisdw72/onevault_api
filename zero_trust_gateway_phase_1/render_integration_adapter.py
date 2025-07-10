#!/usr/bin/env python3
"""
Render Integration Adapter
Connects Zero Trust middleware with Render's specific API format
"""
import requests
import json
import asyncio
from typing import Optional, Dict, Any
from zero_trust_middleware import ZeroTrustGatewayMiddleware, ZeroTrustContext

class RenderIntegrationAdapter:
    """Adapter to integrate Zero Trust middleware with Render's API format"""
    
    def __init__(self, render_base_url: str, db_config: Dict[str, Any]):
        self.render_base_url = render_base_url
        self.zero_trust = ZeroTrustGatewayMiddleware(db_config=db_config)
        
    async def validate_session_token(
        self, 
        session_token: str,
        customer_id: str,
        user_ip: Optional[str] = None,
        user_agent: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Validate session token using Render's API format
        Returns Zero Trust context
        """
        try:
            # Step 1: Use Zero Trust middleware for validation
            zt_context = await self.zero_trust.validate_api_token(
                token=session_token,
                required_scope=['api:read'],
                user_ip=user_ip,
                user_agent=user_agent
            )
            
            if zt_context and zt_context.is_valid:
                return {
                    'success': True,
                    'authenticated': True,
                    'user': {
                        'user_id': zt_context.user_id,
                        'tenant_id': zt_context.tenant_id,
                        'access_level': zt_context.access_level
                    },
                    'tenant': {
                        'tenant_id': zt_context.tenant_id,
                        'tenant_name': zt_context.tenant_name
                    },
                    'security': {
                        'security_level': zt_context.security_level,
                        'rate_limit_remaining': zt_context.rate_limit_remaining,
                        'session_expires_at': zt_context.session_expires_at
                    },
                    'validation_message': zt_context.validation_message
                }
            else:
                return {
                    'success': False,
                    'authenticated': False,
                    'error': 'Token validation failed',
                    'validation_message': zt_context.validation_message if zt_context else 'Invalid token'
                }
                
        except Exception as e:
            return {
                'success': False,
                'authenticated': False,
                'error': f'Validation error: {str(e)}'
            }
    
    async def handle_auth_validate_request(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Handle POST /api/v1/auth/validate requests in Render's format
        """
        session_token = request_data.get('session_token')
        if not session_token:
            return {
                'success': False,
                'authenticated': False,
                'error': 'session_token is required'
            }
        
        # Extract additional context if available
        customer_id = request_data.get('customer_id', 'unknown')
        user_ip = request_data.get('user_ip')
        user_agent = request_data.get('user_agent')
        
        return await self.validate_session_token(
            session_token=session_token,
            customer_id=customer_id,
            user_ip=user_ip,
            user_agent=user_agent
        )
    
    async def refresh_token_if_needed(self, session_token: str) -> Dict[str, Any]:
        """
        Check if token needs refresh and refresh if necessary
        Uses the database function we created
        """
        try:
            # Call the database refresh function
            result = await self.zero_trust._execute_db_function(
                'auth.refresh_production_token',
                (session_token, 7, False)  # 7-day threshold, not forced
            )
            
            if result and len(result) >= 5:
                success, new_token, expires_at, refresh_reason, message = result
                
                if success:
                    return {
                        'refresh_needed': refresh_reason != 'NO_REFRESH_NEEDED',
                        'new_token': new_token,
                        'expires_at': expires_at,
                        'refresh_reason': refresh_reason,
                        'message': message
                    }
                else:
                    return {
                        'refresh_needed': False,
                        'error': message
                    }
            else:
                return {
                    'refresh_needed': False,
                    'error': 'Token refresh function failed'
                }
                
        except Exception as e:
            return {
                'refresh_needed': False,
                'error': f'Token refresh error: {str(e)}'
            }

# FastAPI Integration Example
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()
adapter = RenderIntegrationAdapter(
    render_base_url="https://onevault-api.onrender.com",
    db_config=get_database_config()
)

class TokenValidationRequest(BaseModel):
    session_token: str
    customer_id: Optional[str] = None
    user_ip: Optional[str] = None
    user_agent: Optional[str] = None

@app.post("/api/v1/auth/validate")
async def validate_token(request: TokenValidationRequest):
    result = await adapter.handle_auth_validate_request(request.dict())
    
    if result['success']:
        return result
    else:
        raise HTTPException(status_code=401, detail=result)

@app.post("/api/v1/auth/refresh")  
async def refresh_token(request: TokenValidationRequest):
    result = await adapter.refresh_token_if_needed(request.session_token)
    return result
"""

# Testing the adapter
async def test_adapter():
    """Test the Render integration adapter"""
    from local_config import get_local_config
    
    config = get_local_config()
    adapter = RenderIntegrationAdapter(
        render_base_url="https://onevault-api.onrender.com",
        db_config=config.database.to_dict()
    )
    
    # Test token validation
    test_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
    
    print("🧪 Testing Render Integration Adapter")
    print("=" * 40)
    
    # Test validation
    print("1️⃣ Testing token validation...")
    result = await adapter.validate_session_token(
        session_token=test_token,
        customer_id='one_barn_ai'
    )
    print(f"✅ Validation result: {json.dumps(result, indent=2)}")
    
    # Test refresh check
    print("\n2️⃣ Testing token refresh check...")
    refresh_result = await adapter.refresh_token_if_needed(test_token)
    print(f"✅ Refresh result: {json.dumps(refresh_result, indent=2)}")
    
    return result

if __name__ == "__main__":
    asyncio.run(test_adapter()) 