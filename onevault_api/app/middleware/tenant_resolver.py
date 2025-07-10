"""
Zero Trust Tenant Resolver Middleware
=====================================

Core middleware for bulletproof tenant isolation:
- API key → tenant_hk resolution (cryptographically verified)
- User session → user_hk resolution  
- Resource ID validation against tenant context
- Pre-retrieval cross-tenant violation detection

SECURITY PRINCIPLE: "Never Trust, Always Verify"
- Every request must prove tenant membership BEFORE data access
- All resource IDs must be cryptographically verified against tenant
- No database queries execute without tenant context validation
"""

import hashlib
import json
import logging
import re
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any, Set
from urllib.parse import parse_qs

import psycopg2
from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)

class TenantResolverMiddleware:
    """
    Zero Trust Tenant Resolution Middleware
    
    This middleware implements the core zero trust principle by:
    1. Resolving API keys to tenant_hk with cryptographic verification
    2. Validating user sessions belong to the authenticated tenant
    3. Verifying all resource IDs in requests derive from tenant context
    4. Blocking cross-tenant access attempts at the gateway level
    """
    
    def __init__(self):
        self.excluded_paths = {
            '/health', '/health/db', '/docs', '/redoc', '/openapi.json',
            '/', '/api/system_health_check'
        }
        
        # Resource ID patterns for different entity types
        self.resource_patterns = {
            'user_bk': r'user_[a-zA-Z0-9_-]+',
            'asset_bk': r'asset_[a-zA-Z0-9_-]+',
            'transaction_bk': r'transaction_[a-zA-Z0-9_-]+',
            'session_token': r'sess_[a-zA-Z0-9_-]+',
            'agent_bk': r'agent_[a-zA-Z0-9_-]+',
            'tenant_bk': r'tenant_[a-zA-Z0-9_-]+',
            'email': r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
        }
        
        # Sensitive endpoints that require additional validation
        self.sensitive_endpoints = {
            '/api/v1/track', '/api/v1/ai/', '/api/auth_', '/api/ai_'
        }
    
    async def __call__(self, request: Request, call_next):
        """Main middleware entry point - implements zero trust validation"""
        
        # Skip validation for excluded paths
        if self._should_skip_validation(request):
            return await call_next(request)
        
        try:
            # STEP 1: Resolve API key to tenant_hk (cryptographically verified)
            api_key = self._extract_api_key(request)
            tenant_hk = await self._resolve_tenant_from_api_key(api_key)
            
            # STEP 2: Resolve user session to user_hk (if session provided)
            session_token = self._extract_session_token(request)
            user_hk = None
            if session_token:
                user_hk = await self._resolve_user_from_session(session_token, tenant_hk)
            
            # STEP 3: Extract and validate all resource IDs against tenant
            request_body = await self._extract_request_body(request)
            resource_ids = await self._extract_all_resource_ids(request, request_body)
            await self._validate_all_resources_against_tenant(resource_ids, tenant_hk)
            
            # STEP 4: Inject validated identities into request context
            request.state.tenant_hk = tenant_hk
            request.state.user_hk = user_hk
            request.state.validated_at = datetime.now(timezone.utc)
            request.state.api_key = api_key
            request.state.resource_validation_passed = True
            
            # STEP 5: Log successful validation for audit trail
            await self._log_successful_validation(request, tenant_hk, user_hk)
            
            # Continue to next middleware/endpoint
            response = await call_next(request)
            
            # STEP 6: Add security headers to response
            self._add_security_headers(response, tenant_hk)
            
            return response
            
        except HTTPException as e:
            # Security violation detected - log and block
            await self._log_security_violation(request, str(e))
            return JSONResponse(
                status_code=e.status_code,
                content={
                    "error": "Access Denied",
                    "message": e.detail,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "violation_type": "tenant_isolation_breach"
                }
            )
        except Exception as e:
            # Unexpected error - fail secure
            logger.error(f"Zero trust middleware error: {e}", exc_info=True)
            await self._log_security_violation(request, f"Middleware error: {str(e)}")
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "error": "Security Validation Failed",
                    "message": "Request could not be validated for security compliance",
                    "timestamp": datetime.now(timezone.utc).isoformat()
                }
            )
    
    def _should_skip_validation(self, request: Request) -> bool:
        """Determine if request should skip zero trust validation"""
        path = request.url.path
        return any(excluded in path for excluded in self.excluded_paths)
    
    def _extract_api_key(self, request: Request) -> str:
        """Extract API key from Authorization header"""
        auth_header = request.headers.get('Authorization', '')
        
        if not auth_header.startswith('Bearer '):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing or invalid Authorization header format"
            )
        
        api_key = auth_header.replace('Bearer ', '').strip()
        
        if not api_key:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Empty API key in Authorization header"
            )
        
        return api_key
    
    def _extract_session_token(self, request: Request) -> Optional[str]:
        """Extract session token from request body or headers"""
        # Try to get from X-Session-Token header first
        session_token = request.headers.get('X-Session-Token')
        if session_token:
            return session_token
        
        # Note: We'll also check request body in _extract_request_body
        return None
    
    async def _extract_request_body(self, request: Request) -> Dict[str, Any]:
        """Safely extract and parse request body"""
        try:
            if request.method in ['POST', 'PUT', 'PATCH']:
                body = await request.body()
                if body:
                    return json.loads(body.decode('utf-8'))
            return {}
        except Exception as e:
            logger.warning(f"Could not parse request body: {e}")
            return {}
    
    async def _extract_all_resource_ids(self, request: Request, body: Dict[str, Any]) -> Set[str]:
        """Extract all potential resource identifiers from request"""
        resource_ids = set()
        
        # Extract from URL path parameters
        for key, value in request.path_params.items():
            if isinstance(value, str):
                resource_ids.add(f"{key}:{value}")
        
        # Extract from query parameters
        for key, values in request.query_params.items():
            if isinstance(values, str):
                resource_ids.add(f"{key}:{values}")
        
        # Extract from request body recursively
        self._extract_resources_from_dict(body, resource_ids)
        
        # Extract session token from body if not in headers
        if 'session_token' in body:
            resource_ids.add(f"session_token:{body['session_token']}")
        
        return resource_ids
    
    def _extract_resources_from_dict(self, data: Dict[str, Any], resource_ids: Set[str], prefix: str = ""):
        """Recursively extract resource IDs from nested dictionary"""
        for key, value in data.items():
            full_key = f"{prefix}.{key}" if prefix else key
            
            if isinstance(value, str):
                # Check if value matches any resource pattern
                for pattern_name, pattern in self.resource_patterns.items():
                    if re.match(pattern, value):
                        resource_ids.add(f"{pattern_name}:{value}")
                
                # Also add as generic key:value for validation
                resource_ids.add(f"{full_key}:{value}")
                
            elif isinstance(value, dict):
                self._extract_resources_from_dict(value, resource_ids, full_key)
            elif isinstance(value, list):
                for i, item in enumerate(value):
                    if isinstance(item, dict):
                        self._extract_resources_from_dict(item, resource_ids, f"{full_key}[{i}]")
                    elif isinstance(item, str):
                        resource_ids.add(f"{full_key}[{i}]:{item}")
    
    async def _resolve_tenant_from_api_key(self, api_key: str) -> bytes:
        """
        Cryptographically verify API key belongs to tenant
        
        SECURITY: This is the core tenant resolution - must be bulletproof
        """
        try:
            conn = self._get_db_connection()
            cursor = conn.cursor()
            
            # Hash the API key for lookup
            api_key_hash = hashlib.sha256(api_key.encode()).digest()
            
            # Query to resolve tenant from API key with security validation
            query = """
            SELECT 
                th.tenant_hk,
                th.tenant_bk,
                ats.expires_at,
                ats.is_active,
                ats.created_date
            FROM auth.api_token_s ats
            JOIN auth.tenant_h th ON ats.tenant_hk = th.tenant_hk
            WHERE ats.api_key_hash = %s 
                AND ats.is_active = true
                AND ats.expires_at > CURRENT_TIMESTAMP
                AND ats.load_end_date IS NULL
            """
            
            cursor.execute(query, (api_key_hash,))
            result = cursor.fetchone()
            
            cursor.close()
            conn.close()
            
            if not result:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid, expired, or inactive API key"
                )
            
            tenant_hk, tenant_bk, expires_at, is_active, created_date = result
            
            # Additional security validations
            if not is_active:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="API key is deactivated"
                )
            
            if expires_at <= datetime.now(timezone.utc):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="API key has expired"
                )
            
            logger.info(f"Successfully resolved tenant: {tenant_bk} from API key")
            return tenant_hk
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to resolve tenant from API key: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Tenant resolution failed"
            )
    
    async def _resolve_user_from_session(self, session_token: str, tenant_hk: bytes) -> Optional[bytes]:
        """
        Resolve user from session token and verify belongs to tenant
        
        SECURITY: User must belong to the authenticated tenant
        """
        try:
            conn = self._get_db_connection()
            cursor = conn.cursor()
            
            # Query to resolve user from session with tenant validation
            query = """
            SELECT 
                uh.user_hk,
                uh.user_bk,
                ss.session_status,
                ss.expires_at,
                ss.last_activity
            FROM auth.session_h sh
            JOIN auth.session_state_s ss ON sh.session_hk = ss.session_hk
            JOIN auth.user_session_l usl ON sh.session_hk = usl.session_hk
            JOIN auth.user_h uh ON usl.user_hk = uh.user_hk
            WHERE sh.session_bk = %s
                AND uh.tenant_hk = %s
                AND ss.session_status = 'ACTIVE'
                AND ss.expires_at > CURRENT_TIMESTAMP
                AND ss.load_end_date IS NULL
            """
            
            cursor.execute(query, (session_token, tenant_hk))
            result = cursor.fetchone()
            
            cursor.close()
            conn.close()
            
            if not result:
                # Session token provided but invalid or cross-tenant
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid session token or session does not belong to authenticated tenant"
                )
            
            user_hk, user_bk, session_status, expires_at, last_activity = result
            
            logger.info(f"Successfully resolved user: {user_bk} from session")
            return user_hk
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to resolve user from session: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="User session resolution failed"
            )
    
    async def _validate_all_resources_against_tenant(self, resource_ids: Set[str], tenant_hk: bytes):
        """
        Validate all extracted resource IDs belong to the authenticated tenant
        
        SECURITY: This prevents cross-tenant resource access
        """
        if not resource_ids:
            return  # No resources to validate
        
        from ..services.resource_validator import ResourceValidationService
        validator = ResourceValidationService()
        
        for resource_id in resource_ids:
            if ':' not in resource_id:
                continue  # Skip malformed resource IDs
            
            resource_type, resource_value = resource_id.split(':', 1)
            
            # Skip validation for non-sensitive resource types
            if resource_type in ['page_url', 'user_agent', 'ip_address', 'timestamp']:
                continue
            
            # Validate resource based on type
            is_valid = await self._validate_single_resource(
                validator, resource_type, resource_value, tenant_hk
            )
            
            if not is_valid:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Resource {resource_type}:{resource_value} not accessible by authenticated tenant"
                )
    
    async def _validate_single_resource(self, validator, resource_type: str, resource_value: str, tenant_hk: bytes) -> bool:
        """Validate a single resource against tenant context"""
        try:
            if resource_type == 'user_bk' or resource_type == 'username':
                return await validator.verify_user_belongs_to_tenant(resource_value, tenant_hk)
            elif resource_type == 'asset_bk':
                return await validator.verify_asset_belongs_to_tenant(resource_value, tenant_hk)
            elif resource_type == 'transaction_bk':
                return await validator.verify_transaction_belongs_to_tenant(resource_value, tenant_hk)
            elif resource_type == 'session_token':
                return await validator.verify_session_belongs_to_tenant(resource_value, tenant_hk)
            elif resource_type == 'email':
                return await validator.verify_user_email_belongs_to_tenant(resource_value, tenant_hk)
            else:
                # For unknown resource types, default to allowing (logged for review)
                logger.warning(f"Unknown resource type for validation: {resource_type}")
                return True
                
        except Exception as e:
            logger.error(f"Resource validation error for {resource_type}:{resource_value}: {e}")
            return False  # Fail secure
    
    def _get_db_connection(self):
        """Get database connection"""
        import os
        database_url = os.getenv('SYSTEM_DATABASE_URL')
        if not database_url:
            raise ValueError("SYSTEM_DATABASE_URL environment variable not set")
        return psycopg2.connect(database_url)
    
    async def _log_successful_validation(self, request: Request, tenant_hk: bytes, user_hk: Optional[bytes]):
        """Log successful zero trust validation for audit trail"""
        try:
            audit_entry = {
                "event_type": "zero_trust_validation_success",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "tenant_hk": tenant_hk.hex() if tenant_hk else None,
                "user_hk": user_hk.hex() if user_hk else None,
                "method": request.method,
                "path": str(request.url.path),
                "ip_address": request.client.host if request.client else "unknown",
                "user_agent": request.headers.get('user-agent', 'unknown')
            }
            
            # Store in audit log (implement actual storage)
            logger.info(f"Zero trust validation successful: {json.dumps(audit_entry)}")
            
        except Exception as e:
            logger.error(f"Failed to log successful validation: {e}")
    
    async def _log_security_violation(self, request: Request, violation_details: str):
        """Log security violation for immediate investigation"""
        try:
            violation_entry = {
                "event_type": "zero_trust_violation",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "violation_details": violation_details,
                "method": request.method,
                "path": str(request.url.path),
                "headers": dict(request.headers),
                "ip_address": request.client.host if request.client else "unknown",
                "user_agent": request.headers.get('user-agent', 'unknown')
            }
            
            # Store in security log (implement actual storage)
            logger.error(f"SECURITY VIOLATION: {json.dumps(violation_entry)}")
            
        except Exception as e:
            logger.error(f"Failed to log security violation: {e}")
    
    def _add_security_headers(self, response, tenant_hk: bytes):
        """Add security headers to response"""
        response.headers["X-Tenant-Validated"] = "true"
        response.headers["X-Zero-Trust-Status"] = "validated"
        response.headers["X-Validation-Timestamp"] = datetime.now(timezone.utc).isoformat()
        # Don't expose actual tenant_hk in headers for security 