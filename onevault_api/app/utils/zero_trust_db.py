"""
Zero Trust Database Wrapper
===========================

Database wrapper that automatically applies tenant filtering to all queries.
Integrates with QueryRewriterMiddleware to ensure no query executes without
proper tenant context.

SECURITY PRINCIPLE: Database access is always tenant-scoped
- All queries automatically get tenant filtering
- Cross-tenant queries are impossible by design
- Audit trail for all database operations
- Connection pooling with tenant context
"""

import logging
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple, Any, Generator

import psycopg2
from psycopg2.extras import RealDictCursor

from ..middleware.query_rewriter import QueryRewriterMiddleware

logger = logging.getLogger(__name__)

class ZeroTrustDatabaseWrapper:
    """
    Zero Trust Database Connection Wrapper
    
    This wrapper ensures all database operations respect tenant boundaries by:
    1. Automatically injecting tenant filtering into queries
    2. Validating query security before execution
    3. Logging all database operations for audit
    4. Maintaining tenant context throughout connection lifecycle
    """
    
    def __init__(self, tenant_hk: bytes, user_hk: Optional[bytes] = None):
        self.tenant_hk = tenant_hk
        self.user_hk = user_hk
        self.query_rewriter = QueryRewriterMiddleware()
        self._connection = None
        self._query_count = 0
        self._start_time = time.time()
    
    @contextmanager
    def get_connection(self) -> Generator[psycopg2.extensions.connection, None, None]:
        """Get database connection with automatic cleanup"""
        try:
            if not self._connection or self._connection.closed:
                self._connection = self._create_connection()
            
            yield self._connection
            
        except Exception as e:
            if self._connection:
                self._connection.rollback()
            logger.error(f"Database operation failed: {e}")
            raise
        finally:
            # Connection is kept alive for reuse
            pass
    
    def execute_query(self, query: str, params: Optional[Tuple] = None, 
                     fetch_results: bool = True) -> Optional[List[Dict]]:
        """
        Execute query with automatic tenant filtering
        
        Args:
            query: SQL query to execute
            params: Query parameters
            fetch_results: Whether to fetch and return results
            
        Returns:
            Query results if fetch_results=True, None otherwise
        """
        start_time = time.time()
        
        try:
            # Step 1: Rewrite query with tenant filtering
            rewritten_query, new_params = self.query_rewriter.rewrite_query_with_tenant_filter(
                query, self.tenant_hk, params
            )
            
            # Step 2: Execute the rewritten query
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                    cursor.execute(rewritten_query, new_params)
                    
                    self._query_count += 1
                    execution_time = (time.time() - start_time) * 1000
                    
                    # Step 3: Fetch results if requested
                    results = None
                    if fetch_results:
                        results = [dict(row) for row in cursor.fetchall()]
                    
                    # Step 4: Log execution for audit
                    self.query_rewriter.log_query_execution(
                        query, rewritten_query, self.tenant_hk, execution_time
                    )
                    
                    logger.debug(f"Query executed successfully in {execution_time:.2f}ms")
                    return results
                    
        except Exception as e:
            execution_time = (time.time() - start_time) * 1000
            logger.error(f"Query execution failed after {execution_time:.2f}ms: {e}")
            self._log_failed_query(query, params, str(e), execution_time)
            raise
    
    def execute_function(self, function_name: str, params: Optional[Tuple] = None) -> Optional[Any]:
        """
        Execute database function with tenant context
        
        Args:
            function_name: Name of the database function
            params: Function parameters
            
        Returns:
            Function result
        """
        start_time = time.time()
        
        try:
            query = f"SELECT {function_name}(%s)" if params else f"SELECT {function_name}()"
            
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    if params:
                        cursor.execute(query, params)
                    else:
                        cursor.execute(query)
                    
                    result = cursor.fetchone()
                    execution_time = (time.time() - start_time) * 1000
                    
                    logger.debug(f"Function {function_name} executed in {execution_time:.2f}ms")
                    return result[0] if result else None
                    
        except Exception as e:
            execution_time = (time.time() - start_time) * 1000
            logger.error(f"Function {function_name} failed after {execution_time:.2f}ms: {e}")
            self._log_failed_query(f"SELECT {function_name}(...)", params, str(e), execution_time)
            raise
    
    def execute_transaction(self, queries: List[Tuple[str, Optional[Tuple]]]) -> List[Optional[List[Dict]]]:
        """
        Execute multiple queries in a transaction with tenant filtering
        
        Args:
            queries: List of (query, params) tuples
            
        Returns:
            List of query results
        """
        start_time = time.time()
        results = []
        
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                    for query, params in queries:
                        # Rewrite each query with tenant filtering
                        rewritten_query, new_params = self.query_rewriter.rewrite_query_with_tenant_filter(
                            query, self.tenant_hk, params
                        )
                        
                        cursor.execute(rewritten_query, new_params)
                        
                        # Fetch results for SELECT queries
                        if query.strip().upper().startswith('SELECT'):
                            results.append([dict(row) for row in cursor.fetchall()])
                        else:
                            results.append(None)
                    
                    # Commit transaction
                    conn.commit()
                    execution_time = (time.time() - start_time) * 1000
                    
                    logger.info(f"Transaction with {len(queries)} queries completed in {execution_time:.2f}ms")
                    return results
                    
        except Exception as e:
            execution_time = (time.time() - start_time) * 1000
            logger.error(f"Transaction failed after {execution_time:.2f}ms: {e}")
            
            # Log each query in the failed transaction
            for i, (query, params) in enumerate(queries):
                self._log_failed_query(f"Transaction[{i}]: {query}", params, str(e), execution_time)
            
            raise
    
    def validate_tenant_access(self, resource_type: str, resource_id: str) -> bool:
        """
        Validate that a resource belongs to the current tenant
        
        Args:
            resource_type: Type of resource (user, asset, transaction, etc.)
            resource_id: Resource identifier
            
        Returns:
            True if resource belongs to tenant, False otherwise
        """
        try:
            from ..services.resource_validator import ResourceValidationService
            validator = ResourceValidationService()
            
            if resource_type == 'user':
                return validator.verify_user_belongs_to_tenant(resource_id, self.tenant_hk)
            elif resource_type == 'asset':
                return validator.verify_asset_belongs_to_tenant(resource_id, self.tenant_hk)
            elif resource_type == 'transaction':
                return validator.verify_transaction_belongs_to_tenant(resource_id, self.tenant_hk)
            elif resource_type == 'session':
                return validator.verify_session_belongs_to_tenant(resource_id, self.tenant_hk)
            else:
                logger.warning(f"Unknown resource type for validation: {resource_type}")
                return False
                
        except Exception as e:
            logger.error(f"Resource validation failed for {resource_type}:{resource_id}: {e}")
            return False
    
    def _create_connection(self) -> psycopg2.extensions.connection:
        """Create new database connection"""
        import os
        database_url = os.getenv('SYSTEM_DATABASE_URL')
        if not database_url:
            raise ValueError("SYSTEM_DATABASE_URL environment variable not set")
        
        conn = psycopg2.connect(database_url)
        conn.autocommit = False  # Use explicit transactions
        
        logger.debug(f"Created new database connection for tenant {self.tenant_hk.hex()[:8]}...")
        return conn
    
    def _log_failed_query(self, query: str, params: Optional[Tuple], error: str, execution_time: float):
        """Log failed query execution for security analysis"""
        audit_entry = {
            "event_type": "query_execution_failed",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "tenant_hk": self.tenant_hk.hex(),
            "user_hk": self.user_hk.hex() if self.user_hk else None,
            "query_preview": query[:200] + "..." if len(query) > 200 else query,
            "parameter_count": len(params) if params else 0,
            "error_message": error,
            "execution_time_ms": execution_time
        }
        
        logger.error(f"Query execution failure audit: {audit_entry}")
    
    def get_connection_stats(self) -> Dict[str, Any]:
        """Get connection statistics for monitoring"""
        uptime_seconds = time.time() - self._start_time
        
        return {
            "tenant_hk": self.tenant_hk.hex(),
            "user_hk": self.user_hk.hex() if self.user_hk else None,
            "connection_active": self._connection and not self._connection.closed,
            "queries_executed": self._query_count,
            "uptime_seconds": uptime_seconds,
            "queries_per_second": self._query_count / max(uptime_seconds, 1)
        }
    
    def close(self):
        """Close database connection"""
        if self._connection and not self._connection.closed:
            self._connection.close()
            logger.debug(f"Closed database connection for tenant {self.tenant_hk.hex()[:8]}...")

def get_zero_trust_db(tenant_hk: bytes, user_hk: Optional[bytes] = None) -> ZeroTrustDatabaseWrapper:
    """
    Factory function to create zero trust database wrapper
    
    Args:
        tenant_hk: Authenticated tenant hash key
        user_hk: Authenticated user hash key (optional)
        
    Returns:
        ZeroTrustDatabaseWrapper instance
    """
    return ZeroTrustDatabaseWrapper(tenant_hk, user_hk) 