"""
Zero Trust Middleware - Leveraging Existing Infrastructure
Uses existing ai_monitoring.validate_zero_trust_access() and database tables
"""

import asyncio
import time
from typing import Optional, Dict, Any, List, Tuple
from fastapi import Request, Response
from fastapi.responses import JSONResponse
# import asyncpg  # Removed - not compatible with Python 3.13
import logging
from datetime import datetime, timezone
import json
import ipaddress
from urllib.parse import unquote

from ..config.zero_trust_config import ZeroTrustConfig
from ..utils.database import get_db_connection

logger = logging.getLogger(__name__)

class ExistingInfrastructureZeroTrustMiddleware:
    """
    Zero Trust Middleware leveraging existing database infrastructure:
    - Uses ai_monitoring.validate_zero_trust_access() for validation
    - Leverages existing auth.api_token_s for tenant resolution  
    - Uses existing business schema for resource validation
    - Integrates with existing audit system
    """
    
    def __init__(self):
        self.config = ZeroTrustConfig()
        self.stats = {
            'requests_processed': 0,
            'requests_blocked': 0,
            'tenant_resolutions': 0,
            'validation_time_ms': [],
            'cache_hits': 0,
            'cache_misses': 0
        }
        
    async def __call__(self, request: Request, call_next):
        """Main middleware entry point"""
        start_time = time.time()
        
        try:
            # Extract request context
            context = await self._extract_request_context(request)
            
            # Phase 1: Resolve tenant from API key/token
            tenant_resolution = await self._resolve_tenant_existing_infrastructure(
                context['api_key'], 
                context['session_token']
            )
            
            if not tenant_resolution['success']:
                return self._create_security_response(
                    "TENANT_RESOLUTION_FAILED", 
                    tenant_resolution['message'],
                    context
                )
            
            # Phase 2: Use existing Zero Trust validation function
            zero_trust_result = await self._validate_zero_trust_existing_function(
                tenant_resolution['tenant_hk'],
                tenant_resolution.get('user_hk'),
                context
            )
            
            if not zero_trust_result['access_granted']:
                return self._create_security_response(
                    "ZERO_TRUST_BLOCKED",
                    f"Access denied: {zero_trust_result['message']}",
                    context,
                    tenant_resolution['tenant_hk']
                )
            
            # Phase 3: Resource validation using existing business schema
            if context['resources']:
                resource_validation = await self._validate_resources_existing_schema(
                    tenant_resolution['tenant_hk'],
                    context['resources']
                )
                
                if not resource_validation['all_valid']:
                    return self._create_security_response(
                        "RESOURCE_VALIDATION_FAILED",
                        f"Invalid resources: {resource_validation['invalid_resources']}",
                        context,
                        tenant_resolution['tenant_hk']
                    )
            
            # Add security context to request
            request.state.zero_trust = {
                'tenant_hk': tenant_resolution['tenant_hk'],
                'user_hk': tenant_resolution.get('user_hk'),
                'risk_score': zero_trust_result['risk_score'],
                'access_level': zero_trust_result['access_level'],
                'session_valid': zero_trust_result['session_valid'],
                'validation_time_ms': round((time.time() - start_time) * 1000, 2)
            }
            
            # Continue to next middleware/endpoint
            response = await call_next(request)
            
            # Add security headers
            self._add_security_headers(response, request.state.zero_trust)
            
            # Update stats
            self._update_stats(start_time, 'allowed')
            
            return response
            
        except Exception as e:
            logger.error(f"Zero Trust middleware error: {e}")
            await self._log_security_incident("MIDDLEWARE_ERROR", str(e), context)
            
            # Allow request to continue but log the error
            response = await call_next(request)
            response.headers["X-Security-Status"] = "ERROR"
            return response
    
    async def _extract_request_context(self, request: Request) -> Dict[str, Any]:
        """Extract security context from request"""
        # Get client IP (handle proxies)
        client_ip = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
        if not client_ip:
            client_ip = request.headers.get("x-real-ip", "")
        if not client_ip:
            client_ip = getattr(request.client, "host", "127.0.0.1")
        
        # Extract API key from Authorization header or query param
        api_key = None
        auth_header = request.headers.get("authorization", "")
        if auth_header.startswith("Bearer "):
            api_key = auth_header[7:]
        elif "api_key" in request.query_params:
            api_key = request.query_params["api_key"]
        
        # Extract session token (alternative auth method)
        session_token = request.headers.get("x-session-token") or request.cookies.get("session_token")
        
        # Extract resource IDs from URL path and query params
        resources = self._extract_resource_ids(request)
        
        return {
            'ip_address': client_ip,
            'user_agent': request.headers.get("user-agent", ""),
            'api_key': api_key,
            'session_token': session_token,
            'endpoint': str(request.url.path),
            'method': request.method,
            'resources': resources,
            'timestamp': datetime.now(timezone.utc),
            'request_id': request.headers.get("x-request-id", f"req_{int(time.time())}")
        }
    
    def _extract_resource_ids(self, request: Request) -> List[str]:
        """Extract resource IDs from request for validation"""
        resources = []
        
        # Extract from URL path (e.g., /api/users/123, /api/assets/abc)
        path_parts = request.url.path.strip("/").split("/")
        for i, part in enumerate(path_parts):
            if i > 0 and len(part) > 3:  # Skip 'api' and very short parts
                # Look for UUID-like strings, hash keys, or business keys
                if len(part) >= 8:  # Minimum reasonable ID length
                    resources.append(part)
        
        # Extract from query parameters
        resource_params = ['user_id', 'asset_id', 'entity_id', 'session_id', 'tenant_id']
        for param in resource_params:
            if param in request.query_params:
                resources.append(request.query_params[param])
        
        return list(set(resources))  # Remove duplicates
    
    async def _resolve_tenant_existing_infrastructure(self, api_key: Optional[str], session_token: Optional[str]) -> Dict[str, Any]:
        """
        Resolve tenant using existing auth infrastructure
        Uses auth.api_token_s and auth.session_state_s tables
        """
        if not api_key and not session_token:
            return {'success': False, 'message': 'No authentication token provided'}
        
        try:
            conn = await get_db_connection()
            
            # Try API key resolution first (preferred method)
            if api_key:
                tenant_result = await conn.fetchrow("""
                    SELECT 
                        ats.tenant_hk,
                        ats.token_name,
                        ats.is_active,
                        ats.expires_at,
                        th.tenant_bk,
                        tps.tenant_name
                    FROM auth.api_token_s ats
                    JOIN auth.api_token_h ath ON ats.api_token_hk = ath.api_token_hk
                    JOIN auth.tenant_h th ON ats.tenant_hk = th.tenant_hk
                    LEFT JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk 
                        AND tps.load_end_date IS NULL
                    WHERE ats.token_value = $1 
                    AND ats.load_end_date IS NULL
                    AND ats.is_active = true
                    AND (ats.expires_at IS NULL OR ats.expires_at > CURRENT_TIMESTAMP)
                """, api_key)
                
                if tenant_result:
                    await conn.close()
                    return {
                        'success': True,
                        'tenant_hk': tenant_result['tenant_hk'],
                        'tenant_bk': tenant_result['tenant_bk'],
                        'tenant_name': tenant_result['tenant_name'],
                        'auth_method': 'api_key'
                    }
            
            # Try session token resolution (alternative method)
            if session_token:
                session_result = await conn.fetchrow("""
                    SELECT 
                        sss.tenant_hk,
                        sss.user_hk,
                        sss.session_status,
                        sh.session_bk,
                        th.tenant_bk,
                        tps.tenant_name
                    FROM auth.session_state_s sss
                    JOIN auth.session_h sh ON sss.session_hk = sh.session_hk
                    JOIN auth.tenant_h th ON sss.tenant_hk = th.tenant_hk
                    LEFT JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk 
                        AND tps.load_end_date IS NULL
                    WHERE sss.session_token = $1
                    AND sss.load_end_date IS NULL
                    AND sss.session_status = 'ACTIVE'
                    AND sss.expires_at > CURRENT_TIMESTAMP
                """, session_token)
                
                if session_result:
                    await conn.close()
                    return {
                        'success': True,
                        'tenant_hk': session_result['tenant_hk'],
                        'user_hk': session_result['user_hk'],
                        'tenant_bk': session_result['tenant_bk'],
                        'tenant_name': session_result['tenant_name'],
                        'auth_method': 'session_token'
                    }
            
            await conn.close()
            return {'success': False, 'message': 'Invalid or expired authentication token'}
            
        except Exception as e:
            logger.error(f"Tenant resolution error: {e}")
            return {'success': False, 'message': 'Authentication system error'}
    
    async def _validate_zero_trust_existing_function(
        self, 
        tenant_hk: bytes, 
        user_hk: Optional[bytes], 
        context: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Use existing ai_monitoring.validate_zero_trust_access() function
        This leverages all the existing behavioral analytics and risk assessment
        """
        try:
            conn = await get_db_connection()
            
            # Call existing Zero Trust validation function
            result = await conn.fetchrow("""
                SELECT * FROM ai_monitoring.validate_zero_trust_access(
                    p_tenant_hk := $1,
                    p_user_hk := $2,
                    p_token_value := $3,
                    p_ip_address := $4::inet,
                    p_user_agent := $5,
                    p_requested_resource := $6,
                    p_endpoint := $7
                )
            """, 
                tenant_hk,
                user_hk,
                context['api_key'] or context['session_token'],
                context['ip_address'],
                context['user_agent'],
                ','.join(context['resources']) if context['resources'] else None,
                context['endpoint']
            )
            
            await conn.close()
            
            if result:
                return {
                    'access_granted': result['p_access_granted'],
                    'risk_score': result['p_risk_score'],
                    'access_level': result['p_access_level'],
                    'required_actions': result['p_required_actions'],
                    'session_valid': result['p_session_valid'],
                    'user_context': result['p_user_context'],
                    'message': f"Risk score: {result['p_risk_score']}, Level: {result['p_access_level']}"
                }
            else:
                return {
                    'access_granted': False,
                    'risk_score': 100,
                    'access_level': 'DENIED',
                    'message': 'Zero Trust validation failed'
                }
                
        except Exception as e:
            logger.error(f"Zero Trust validation error: {e}")
            return {
                'access_granted': False,
                'risk_score': 100,
                'access_level': 'ERROR',
                'message': f'Validation system error: {str(e)}'
            }
    
    async def _validate_resources_existing_schema(
        self, 
        tenant_hk: bytes, 
        resource_ids: List[str]
    ) -> Dict[str, Any]:
        """
        Validate resources using existing business schema with tenant_hk isolation
        Checks business.{entity}_h tables to ensure resources belong to tenant
        """
        if not resource_ids:
            return {'all_valid': True, 'invalid_resources': []}
        
        try:
            conn = await get_db_connection()
            invalid_resources = []
            
            # Check each resource against business schema tables
            for resource_id in resource_ids:
                is_valid = await self._check_resource_in_business_schema(
                    conn, tenant_hk, resource_id
                )
                if not is_valid:
                    invalid_resources.append(resource_id)
            
            await conn.close()
            
            return {
                'all_valid': len(invalid_resources) == 0,
                'invalid_resources': invalid_resources,
                'total_checked': len(resource_ids),
                'valid_count': len(resource_ids) - len(invalid_resources)
            }
            
        except Exception as e:
            logger.error(f"Resource validation error: {e}")
            return {
                'all_valid': False,
                'invalid_resources': resource_ids,
                'error': str(e)
            }
    
    async def _check_resource_in_business_schema(
        self, 
        conn,  # asyncpg.Connection - removed type hint for Python 3.13 compatibility
        tenant_hk: bytes, 
        resource_id: str
    ) -> bool:
        """
        Check if resource exists in business schema with correct tenant
        Uses existing business hub tables
        """
        # Define business entity tables to check
        business_tables = [
            'business_entity_h',
            'asset_h', 
            'ai_interaction_h',
            'ai_session_h',
            'monitored_entity_h',
            'site_visitor_h',
            'site_session_h'
        ]
        
        for table in business_tables:
            try:
                # Check if resource exists with correct tenant
                result = await conn.fetchval(f"""
                    SELECT 1 FROM business.{table}
                    WHERE tenant_hk = $1 
                    AND ({table.replace('_h', '_bk')} = $2 
                         OR encode({table.replace('_h', '_hk')}, 'hex') = $2)
                    LIMIT 1
                """, tenant_hk, resource_id)
                
                if result:
                    return True  # Found in this table with correct tenant
                    
            except Exception as e:
                # Table might not exist or query might fail - continue checking
                logger.debug(f"Error checking {table}: {e}")
                continue
        
        return False  # Not found in any business table for this tenant
    
    async def _log_security_incident(
        self, 
        incident_type: str, 
        description: str, 
        context: Dict[str, Any],
        tenant_hk: Optional[bytes] = None
    ):
        """Log security incident using existing audit infrastructure"""
        try:
            conn = await get_db_connection()
            
            # Use existing ai_monitoring.log_security_event function
            await conn.execute("""
                SELECT ai_monitoring.log_security_event(
                    p_tenant_hk := $1,
                    p_event_type := $2,
                    p_severity := $3,
                    p_description := $4,
                    p_source_ip := $5::inet,
                    p_user_agent := $6,
                    p_event_metadata := $7::jsonb
                )
            """, 
                tenant_hk,
                incident_type,
                'HIGH' if 'BLOCKED' in incident_type else 'MEDIUM',
                description,
                context['ip_address'],
                context['user_agent'],
                json.dumps({
                    'endpoint': context['endpoint'],
                    'method': context['method'],
                    'resources': context['resources'],
                    'timestamp': context['timestamp'].isoformat(),
                    'request_id': context['request_id']
                })
            )
            
            await conn.close()
            
        except Exception as e:
            logger.error(f"Failed to log security incident: {e}")
    
    def _create_security_response(
        self, 
        violation_type: str, 
        message: str, 
        context: Dict[str, Any],
        tenant_hk: Optional[bytes] = None
    ) -> JSONResponse:
        """Create standardized security response"""
        
        # Log the violation
        asyncio.create_task(self._log_security_incident(
            violation_type, message, context, tenant_hk
        ))
        
        # Update stats
        self._update_stats(time.time(), 'blocked')
        
        return JSONResponse(
            status_code=403,
            content={
                "error": "Access Denied",
                "message": message,
                "violation_type": violation_type,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "request_id": context['request_id']
            },
            headers={
                "X-Security-Status": "BLOCKED",
                "X-Violation-Type": violation_type,
                "X-Request-ID": context['request_id']
            }
        )
    
    def _add_security_headers(self, response: Response, zero_trust_context: Dict[str, Any]):
        """Add security headers to response"""
        response.headers.update({
            "X-Security-Status": "VALIDATED",
            "X-Risk-Score": str(zero_trust_context['risk_score']),
            "X-Access-Level": zero_trust_context['access_level'],
            "X-Validation-Time": f"{zero_trust_context['validation_time_ms']}ms",
            "X-Tenant-Validated": "true" if zero_trust_context['tenant_hk'] else "false"
        })
    
    def _update_stats(self, start_time: float, result: str):
        """Update middleware statistics"""
        self.stats['requests_processed'] += 1
        if result == 'blocked':
            self.stats['requests_blocked'] += 1
        
        validation_time = round((time.time() - start_time) * 1000, 2)
        self.stats['validation_time_ms'].append(validation_time)
        
        # Keep only last 1000 times for rolling average
        if len(self.stats['validation_time_ms']) > 1000:
            self.stats['validation_time_ms'] = self.stats['validation_time_ms'][-1000:]
    
    def get_stats(self) -> Dict[str, Any]:
        """Get middleware performance statistics"""
        avg_time = sum(self.stats['validation_time_ms']) / len(self.stats['validation_time_ms']) if self.stats['validation_time_ms'] else 0
        
        return {
            **self.stats,
            'avg_validation_time_ms': round(avg_time, 2),
            'success_rate': round((self.stats['requests_processed'] - self.stats['requests_blocked']) / max(self.stats['requests_processed'], 1) * 100, 2)
        } 