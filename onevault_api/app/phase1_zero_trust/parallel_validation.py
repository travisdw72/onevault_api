"""
Phase 1 Parallel Validation Middleware
Runs enhanced zero trust validation alongside current validation
Zero user disruption with complete logging
"""

import asyncio
import time
import logging
import psycopg2
import json
from typing import Dict, Any, Optional, Tuple, Union
from dataclasses import dataclass
from datetime import datetime
from contextlib import asynccontextmanager

from config import get_config, get_database_config, get_zero_trust_config

# Setup logging
logger = logging.getLogger(__name__)

@dataclass
class ValidationResult:
    """Result of a validation attempt"""
    success: bool
    duration_ms: int
    response: Optional[Dict[str, Any]] = None
    error_message: Optional[str] = None
    token_extended: bool = False
    cross_tenant_blocked: bool = False
    cache_hit: bool = False
    
@dataclass
class ParallelValidationResult:
    """Result of parallel validation comparison"""
    current_result: ValidationResult
    enhanced_result: ValidationResult
    performance_improvement_ms: int
    results_match: bool
    enhanced_faster: bool
    cache_effectiveness: bool
    validation_hk: Optional[bytes] = None

class DatabaseConnectionManager:
    """Manages database connections for validation logging"""
    
    def __init__(self):
        self.config = get_database_config()
        self._connection = None
    
    @asynccontextmanager
    async def get_connection(self):
        """Get database connection with proper cleanup"""
        try:
            if not self._connection or self._connection.closed:
                self._connection = psycopg2.connect(
                    host=self.config.host,
                    port=self.config.port,
                    database=self.config.database,
                    user=self.config.user,
                    password=self.config.password,
                    connect_timeout=self.config.connection_timeout,
                    application_name=self.config.application_name
                )
            
            yield self._connection
            
        except Exception as e:
            logger.error(f"❌ Database connection error: {e}")
            if self._connection:
                self._connection.rollback()
            raise
    
    async def log_validation_attempt(self, result: ParallelValidationResult, 
                                   api_endpoint: str, tenant_hk: Optional[bytes] = None):
        """Log parallel validation attempt to database"""
        try:
            async with self.get_connection() as conn:
                cursor = conn.cursor()
                
                # Call the logging function
                cursor.execute("""
                    SELECT audit.log_parallel_validation(
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    )
                """, (
                    tenant_hk,
                    api_endpoint,
                    result.current_result.success,
                    result.current_result.duration_ms,
                    result.enhanced_result.success,
                    result.enhanced_result.duration_ms,
                    json.dumps(result.enhanced_result.response) if result.enhanced_result.response else None,
                    result.enhanced_result.token_extended,
                    result.enhanced_result.cross_tenant_blocked,
                    result.enhanced_result.cache_hit
                ))
                
                validation_hk = cursor.fetchone()[0]
                conn.commit()
                
                result.validation_hk = validation_hk
                logger.debug(f"✅ Parallel validation logged: {validation_hk.hex()[:16]}")
                
        except Exception as e:
            logger.error(f"❌ Failed to log validation attempt: {e}")

class CacheManager:
    """In-memory cache for validation results"""
    
    def __init__(self):
        self.config = get_config().cache
        self._validation_cache = {}
        self._tenant_cache = {}
        self._permission_cache = {}
        self._cache_stats = {
            'hits': 0,
            'misses': 0,
            'sets': 0
        }
    
    def _generate_cache_key(self, token: str, tenant_id: str, operation: str = "validate") -> str:
        """Generate cache key with privacy protection"""
        # Use hash of sensitive data rather than storing directly
        import hashlib
        combined = f"{operation}:{tenant_id}:{token[:16]}:{token[-16:]}"
        return hashlib.sha256(combined.encode()).hexdigest()[:32]
    
    def get_validation_result(self, token: str, tenant_id: str) -> Optional[ValidationResult]:
        """Get cached validation result"""
        if not self.config.validation_enabled:
            return None
            
        cache_key = self._generate_cache_key(token, tenant_id)
        
        if cache_key in self._validation_cache:
            cached_data = self._validation_cache[cache_key]
            
            # Check TTL
            if time.time() - cached_data['timestamp'] < self.config.validation_ttl_seconds:
                self._cache_stats['hits'] += 1
                logger.debug(f"💾 Cache hit for validation: {cache_key[:8]}")
                
                result = cached_data['result']
                result.cache_hit = True
                return result
            else:
                # Expired
                del self._validation_cache[cache_key]
        
        self._cache_stats['misses'] += 1
        return None
    
    def set_validation_result(self, token: str, tenant_id: str, result: ValidationResult):
        """Cache validation result"""
        if not self.config.validation_enabled:
            return
            
        # Prevent cache from growing too large
        if len(self._validation_cache) >= self.config.validation_max_entries:
            # Remove oldest entry
            oldest_key = min(self._validation_cache.keys(), 
                           key=lambda k: self._validation_cache[k]['timestamp'])
            del self._validation_cache[oldest_key]
        
        cache_key = self._generate_cache_key(token, tenant_id)
        self._validation_cache[cache_key] = {
            'timestamp': time.time(),
            'result': result
        }
        
        self._cache_stats['sets'] += 1
        logger.debug(f"💾 Cached validation result: {cache_key[:8]}")
    
    def get_cache_stats(self) -> Dict[str, Any]:
        """Get cache performance statistics"""
        total_requests = self._cache_stats['hits'] + self._cache_stats['misses']
        hit_rate = (self._cache_stats['hits'] / total_requests * 100) if total_requests > 0 else 0
        
        return {
            'validation_cache_size': len(self._validation_cache),
            'tenant_cache_size': len(self._tenant_cache),
            'permission_cache_size': len(self._permission_cache),
            'cache_hit_rate': round(hit_rate, 2),
            'total_hits': self._cache_stats['hits'],
            'total_misses': self._cache_stats['misses'],
            'total_sets': self._cache_stats['sets']
        }

class EnhancedZeroTrustValidator:
    """Enhanced zero trust validation with improved performance and security"""
    
    def __init__(self):
        self.config = get_zero_trust_config()
        self.db_config = get_database_config()
        self.cache = CacheManager()
        self._connection_pool = []
    
    async def validate_token_enhanced(self, token: str, tenant_id: str, 
                                    user_agent: str = "", ip_address: str = "") -> ValidationResult:
        """Enhanced token validation with caching and improved security"""
        start_time = time.perf_counter()
        
        # Check cache first
        cached_result = self.cache.get_validation_result(token, tenant_id)
        if cached_result:
            return cached_result
        
        try:
            # Enhanced validation with additional security checks
            conn = psycopg2.connect(
                host=self.db_config.host,
                port=self.db_config.port,
                database=self.db_config.database,
                user=self.db_config.user,
                password=self.db_config.password,
                connect_timeout=3,  # Faster timeout for enhanced validation
                application_name="phase1_enhanced_validation"
            )
            
            cursor = conn.cursor()
            
            # Call enhanced validation function with additional context
            cursor.execute("""
                SELECT 
                    auth.validate_and_extend_production_token(%s, %s) as validation_result,
                    CASE 
                        WHEN %s != '' AND position('cross-tenant' in lower(%s)) > 0 
                        THEN TRUE 
                        ELSE FALSE 
                    END as suspicious_request
            """, (token, tenant_id, user_agent, user_agent))
            
            result_row = cursor.fetchone()
            if not result_row:
                raise ValueError("No validation result returned")
            
            validation_result = result_row[0] if result_row[0] else {}
            suspicious_request = result_row[1] if len(result_row) > 1 else False
            
            # Parse validation result
            success = validation_result.get('p_success', False) if validation_result else False
            token_extended = validation_result.get('p_token_extended', False) if validation_result else False
            cross_tenant_blocked = suspicious_request or not success
            
            duration_ms = int((time.perf_counter() - start_time) * 1000)
            
            result = ValidationResult(
                success=success,
                duration_ms=duration_ms,
                response=validation_result,
                token_extended=token_extended,
                cross_tenant_blocked=cross_tenant_blocked,
                cache_hit=False
            )
            
            # Cache successful results
            if success:
                self.cache.set_validation_result(token, tenant_id, result)
            
            logger.debug(f"🛡️ Enhanced validation: success={success}, duration={duration_ms}ms")
            return result
            
        except Exception as e:
            duration_ms = int((time.perf_counter() - start_time) * 1000)
            logger.error(f"❌ Enhanced validation error: {e}")
            
            return ValidationResult(
                success=False,
                duration_ms=duration_ms,
                error_message=str(e),
                cache_hit=False
            )
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()

class CurrentZeroTrustValidator:
    """Current zero trust validation (placeholder for existing system)"""
    
    async def validate_token_current(self, token: str, tenant_id: str, 
                                   user_agent: str = "", ip_address: str = "") -> ValidationResult:
        """Current token validation (simulating existing behavior)"""
        start_time = time.perf_counter()
        
        try:
            # Simulate current validation behavior
            db_config = get_database_config()
            conn = psycopg2.connect(
                host=db_config.host,
                port=db_config.port,
                database=db_config.database,
                user=db_config.user,
                password=db_config.password,
                connect_timeout=db_config.connection_timeout,
                application_name="phase1_current_validation"
            )
            
            cursor = conn.cursor()
            
            # Use existing validation function
            cursor.execute("SELECT auth.validate_production_api_token(%s, %s)", (token, tenant_id))
            validation_result = cursor.fetchone()[0]
            
            success = validation_result.get('p_success', False) if validation_result else False
            duration_ms = int((time.perf_counter() - start_time) * 1000)
            
            return ValidationResult(
                success=success,
                duration_ms=duration_ms,
                response=validation_result,
                cache_hit=False
            )
            
        except Exception as e:
            duration_ms = int((time.perf_counter() - start_time) * 1000)
            logger.error(f"❌ Current validation error: {e}")
            
            return ValidationResult(
                success=False,
                duration_ms=duration_ms,
                error_message=str(e),
                cache_hit=False
            )
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()

class ParallelValidationMiddleware:
    """Main parallel validation middleware - runs both validations simultaneously"""
    
    def __init__(self):
        self.config = get_config()
        self.zero_trust_config = get_zero_trust_config()
        self.current_validator = CurrentZeroTrustValidator()
        self.enhanced_validator = EnhancedZeroTrustValidator()
        self.db_manager = DatabaseConnectionManager()
        
        logger.info(f"🛡️ Parallel Validation Middleware initialized: {self.config.implementation_name}")
    
    async def validate_parallel(self, token: str, tenant_id: str, api_endpoint: str = "",
                              user_agent: str = "", ip_address: str = "") -> ParallelValidationResult:
        """Run parallel validation - both current and enhanced simultaneously"""
        
        # Guard clause: Check if parallel validation is enabled
        if not self.zero_trust_config.parallel_validation_enabled:
            logger.warning("⚠️ Parallel validation disabled - using current validation only")
            current_result = await self.current_validator.validate_token_current(
                token, tenant_id, user_agent, ip_address
            )
            return ParallelValidationResult(
                current_result=current_result,
                enhanced_result=current_result,
                performance_improvement_ms=0,
                results_match=True,
                enhanced_faster=False,
                cache_effectiveness=False
            )
        
        # Guard clause: Validate inputs
        if not token or not tenant_id:
            raise ValueError("❌ Token and tenant_id are required")
        
        try:
            # Run both validations simultaneously with timeout protection
            start_time = time.perf_counter()
            
            # Run validations in parallel with timeout
            current_task = asyncio.create_task(
                self.current_validator.validate_token_current(token, tenant_id, user_agent, ip_address)
            )
            enhanced_task = asyncio.create_task(
                self.enhanced_validator.validate_token_enhanced(token, tenant_id, user_agent, ip_address)
            )
            
            # Wait for both with timeout
            timeout_seconds = self.zero_trust_config.timeout_ms / 1000
            current_result, enhanced_result = await asyncio.wait_for(
                asyncio.gather(current_task, enhanced_task),
                timeout=timeout_seconds
            )
            
            total_duration_ms = int((time.perf_counter() - start_time) * 1000)
            
            # Calculate performance metrics
            performance_improvement_ms = current_result.duration_ms - enhanced_result.duration_ms
            results_match = (current_result.success == enhanced_result.success)
            enhanced_faster = enhanced_result.duration_ms < current_result.duration_ms
            cache_effectiveness = enhanced_result.cache_hit
            
            result = ParallelValidationResult(
                current_result=current_result,
                enhanced_result=enhanced_result,
                performance_improvement_ms=performance_improvement_ms,
                results_match=results_match,
                enhanced_faster=enhanced_faster,
                cache_effectiveness=cache_effectiveness
            )
            
            # Log validation attempt (fire and forget)
            asyncio.create_task(self._log_validation_safely(result, api_endpoint, tenant_id))
            
            # Log performance metrics
            if self.config.logging.log_performance:
                logger.info(f"⚡ Parallel validation completed: "
                          f"current={current_result.duration_ms}ms, "
                          f"enhanced={enhanced_result.duration_ms}ms, "
                          f"improvement={performance_improvement_ms}ms, "
                          f"match={results_match}")
            
            return result
            
        except asyncio.TimeoutError:
            logger.error(f"⏰ Parallel validation timeout after {timeout_seconds}s")
            
            # Return timeout result
            timeout_result = ValidationResult(
                success=False,
                duration_ms=int(timeout_seconds * 1000),
                error_message="Validation timeout",
                cache_hit=False
            )
            
            return ParallelValidationResult(
                current_result=timeout_result,
                enhanced_result=timeout_result,
                performance_improvement_ms=0,
                results_match=True,
                enhanced_faster=False,
                cache_effectiveness=False
            )
            
        except Exception as e:
            logger.error(f"❌ Parallel validation error: {e}")
            
            # Return error result
            error_result = ValidationResult(
                success=False,
                duration_ms=0,
                error_message=str(e),
                cache_hit=False
            )
            
            return ParallelValidationResult(
                current_result=error_result,
                enhanced_result=error_result,
                performance_improvement_ms=0,
                results_match=True,
                enhanced_faster=False,
                cache_effectiveness=False
            )
    
    async def _log_validation_safely(self, result: ParallelValidationResult, 
                                   api_endpoint: str, tenant_id: str):
        """Safely log validation attempt without affecting main flow"""
        try:
            # Convert tenant_id to bytes if needed
            tenant_hk = None
            if tenant_id:
                if isinstance(tenant_id, str):
                    tenant_hk = bytes.fromhex(tenant_id)
                else:
                    tenant_hk = tenant_id
            
            await self.db_manager.log_validation_attempt(result, api_endpoint, tenant_hk)
            
        except Exception as e:
            logger.error(f"❌ Failed to log validation (non-blocking): {e}")
    
    def get_performance_metrics(self) -> Dict[str, Any]:
        """Get current performance metrics"""
        cache_stats = self.enhanced_validator.cache.get_cache_stats()
        
        return {
            'middleware_version': self.config.version,
            'implementation_name': self.config.implementation_name,
            'parallel_validation_enabled': self.zero_trust_config.parallel_validation_enabled,
            'fail_safe_mode': self.zero_trust_config.fail_safe_mode,
            'performance_targets': {
                'total_middleware_ms': self.zero_trust_config.total_middleware_ms,
                'improvement_target_pct': self.zero_trust_config.improvement_target_pct,
                'cache_hit_target_pct': self.zero_trust_config.cache_hit_target_pct
            },
            'cache_performance': cache_stats,
            'timestamp': datetime.now().isoformat()
        }

# Global middleware instance
_middleware_instance: Optional[ParallelValidationMiddleware] = None

def get_middleware() -> ParallelValidationMiddleware:
    """Get global middleware instance (singleton pattern)"""
    global _middleware_instance
    
    if _middleware_instance is None:
        _middleware_instance = ParallelValidationMiddleware()
    
    return _middleware_instance

async def validate_request(token: str, tenant_id: str, api_endpoint: str = "",
                         user_agent: str = "", ip_address: str = "") -> Dict[str, Any]:
    """
    Main validation entry point for Phase 1
    Returns current validation result while logging enhanced validation
    """
    middleware = get_middleware()
    
    try:
        # Run parallel validation
        result = await middleware.validate_parallel(
            token, tenant_id, api_endpoint, user_agent, ip_address
        )
        
        # In fail-safe mode, always return current validation result
        if middleware.zero_trust_config.fail_safe_mode:
            validation_response = result.current_result.response or {}
            validation_response['phase1_enhanced_available'] = result.enhanced_result.success
            validation_response['phase1_performance_improvement_ms'] = result.performance_improvement_ms
            validation_response['phase1_cache_hit'] = result.enhanced_result.cache_hit
            
            return validation_response
        else:
            # Use enhanced result if it's successful, otherwise fall back to current
            primary_result = result.enhanced_result if result.enhanced_result.success else result.current_result
            response = primary_result.response or {}
            
            response['phase1_validation_source'] = 'enhanced' if result.enhanced_result.success else 'current'
            response['phase1_performance_improvement_ms'] = result.performance_improvement_ms
            response['phase1_cache_hit'] = result.enhanced_result.cache_hit
            
            return response
            
    except Exception as e:
        logger.error(f"❌ Validation request failed: {e}")
        
        # Return safe fallback response
        return {
            'p_success': False,
            'p_message': 'Validation service temporarily unavailable',
            'phase1_error': str(e)
        } 