"""
Database Connection Utilities for Phase 1 Integration
====================================================

Provides database connection utilities for the Zero Trust Gateway Phase 1 integration.
"""

import asyncio
import asyncpg
import psycopg2
from psycopg2.pool import ThreadedConnectionPool
import os
import logging
from typing import Optional, Dict, Any
from contextlib import asynccontextmanager

logger = logging.getLogger(__name__)

class DatabaseConnection:
    """
    Database connection manager that works with both sync and async connections
    """
    
    def __init__(self):
        self.database_url = os.getenv('SYSTEM_DATABASE_URL')
        self.pool = None
        self.async_pool = None
        
        if not self.database_url:
            raise ValueError("SYSTEM_DATABASE_URL environment variable not set")
    
    async def get_async_connection(self) -> asyncpg.Connection:
        """Get an async database connection"""
        try:
            if not self.async_pool:
                self.async_pool = await asyncpg.create_pool(
                    self.database_url,
                    min_size=1,
                    max_size=10,
                    command_timeout=30
                )
            
            return await self.async_pool.acquire()
        except Exception as e:
            logger.error(f"❌ Failed to get async database connection: {e}")
            raise
    
    async def release_async_connection(self, connection: asyncpg.Connection):
        """Release an async database connection"""
        if self.async_pool and connection:
            await self.async_pool.release(connection)
    
    def get_sync_connection(self) -> psycopg2.extensions.connection:
        """Get a sync database connection"""
        try:
            return psycopg2.connect(self.database_url)
        except Exception as e:
            logger.error(f"❌ Failed to get sync database connection: {e}")
            raise
    
    async def close_pools(self):
        """Close all connection pools"""
        if self.async_pool:
            await self.async_pool.close()
        if self.pool:
            self.pool.closeall()

# Global database connection manager
_db_manager = None

def get_db_manager() -> DatabaseConnection:
    """Get the global database connection manager"""
    global _db_manager
    if _db_manager is None:
        _db_manager = DatabaseConnection()
    return _db_manager

async def get_db_connection() -> asyncpg.Connection:
    """
    Get an async database connection
    
    This is the main function used by the middleware
    """
    db_manager = get_db_manager()
    return await db_manager.get_async_connection()

async def release_db_connection(connection: asyncpg.Connection):
    """Release an async database connection"""
    db_manager = get_db_manager()
    await db_manager.release_async_connection(connection)

@asynccontextmanager
async def get_db_connection_context():
    """
    Context manager for database connections
    
    Usage:
        async with get_db_connection_context() as conn:
            result = await conn.fetch("SELECT * FROM table")
    """
    connection = None
    try:
        connection = await get_db_connection()
        yield connection
    finally:
        if connection:
            await release_db_connection(connection)

def get_sync_db_connection() -> psycopg2.extensions.connection:
    """
    Get a sync database connection for compatibility with existing code
    """
    db_manager = get_db_manager()
    return db_manager.get_sync_connection()

async def test_database_connection() -> bool:
    """Test if the database connection is working"""
    try:
        async with get_db_connection_context() as conn:
            result = await conn.fetchval("SELECT 1")
            return result == 1
    except Exception as e:
        logger.error(f"❌ Database connection test failed: {e}")
        return False

async def execute_query(query: str, params: Optional[tuple] = None) -> Optional[Any]:
    """
    Execute a query and return the result
    
    Args:
        query: SQL query to execute
        params: Optional parameters for the query
        
    Returns:
        Query result or None if failed
    """
    try:
        async with get_db_connection_context() as conn:
            if params:
                result = await conn.fetch(query, *params)
            else:
                result = await conn.fetch(query)
            return result
    except Exception as e:
        logger.error(f"❌ Query execution failed: {e}")
        return None

async def execute_fetchone(query: str, params: Optional[tuple] = None) -> Optional[Any]:
    """
    Execute a query and return the first row
    
    Args:
        query: SQL query to execute
        params: Optional parameters for the query
        
    Returns:
        First row of query result or None if failed
    """
    try:
        async with get_db_connection_context() as conn:
            if params:
                result = await conn.fetchrow(query, *params)
            else:
                result = await conn.fetchrow(query)
            return result
    except Exception as e:
        logger.error(f"❌ Query execution failed: {e}")
        return None

async def execute_fetchval(query: str, params: Optional[tuple] = None) -> Optional[Any]:
    """
    Execute a query and return a single value
    
    Args:
        query: SQL query to execute
        params: Optional parameters for the query
        
    Returns:
        Single value from query result or None if failed
    """
    try:
        async with get_db_connection_context() as conn:
            if params:
                result = await conn.fetchval(query, *params)
            else:
                result = await conn.fetchval(query)
            return result
    except Exception as e:
        logger.error(f"❌ Query execution failed: {e}")
        return None

# Cleanup function for graceful shutdown
async def cleanup_database_connections():
    """Cleanup database connections on shutdown"""
    global _db_manager
    if _db_manager:
        await _db_manager.close_pools()
        _db_manager = None 