"""
Phase 1 Performance Cache Manager
Optimizes validation performance through intelligent caching
"""

import time
import hashlib
import logging
import asyncio
import json
from typing import Dict, Any, Optional, List, Union
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from collections import defaultdict
from threading import Lock

from config import get_cache_config, get_database_config

logger = logging.getLogger(__name__)

@dataclass
class CacheEntry:
    """Cache entry with metadata"""
    value: Any
    timestamp: float
    ttl_seconds: int
    access_count: int = 0
    last_access: float = 0.0
    size_bytes: int = 0
    
    def is_expired(self) -> bool:
        """Check if cache entry has expired"""
        return time.time() - self.timestamp > self.ttl_seconds
    
    def access(self):
        """Mark cache entry as accessed"""
        self.access_count += 1
        self.last_access = time.time()

@dataclass
class CacheStats:
    """Cache performance statistics"""
    hits: int = 0
    misses: int = 0
    sets: int = 0
    evictions: int = 0
    total_size_bytes: int = 0
    average_ttl_seconds: float = 0.0
    
    @property
    def hit_rate(self) -> float:
        """Calculate cache hit rate percentage"""
        total = self.hits + self.misses
        return (self.hits / total * 100) if total > 0 else 0.0
    
    @property
    def total_operations(self) -> int:
        """Total cache operations"""
        return self.hits + self.misses + self.sets

class InMemoryCache:
    """High-performance in-memory cache with LRU eviction"""
    
    def __init__(self, max_entries: int, default_ttl: int, name: str = "cache"):
        self.max_entries = max_entries
        self.default_ttl = default_ttl
        self.name = name
        self._cache: Dict[str, CacheEntry] = {}
        self._stats = CacheStats()
        self._lock = Lock()
        
        logger.info(f"💾 {name} cache initialized: max_entries={max_entries}, ttl={default_ttl}s")
    
    def _generate_key(self, *args, prefix: str = "") -> str:
        """Generate cache key from arguments"""
        # Create stable hash from arguments
        key_data = f"{prefix}:{':'.join(str(arg) for arg in args)}"
        return hashlib.sha256(key_data.encode()).hexdigest()[:32]
    
    def _evict_expired(self):
        """Remove expired entries"""
        current_time = time.time()
        expired_keys = [
            key for key, entry in self._cache.items()
            if current_time - entry.timestamp > entry.ttl_seconds
        ]
        
        for key in expired_keys:
            del self._cache[key]
            self._stats.evictions += 1
    
    def _evict_lru(self):
        """Evict least recently used entries when cache is full"""
        if len(self._cache) >= self.max_entries:
            # Sort by last access time (or timestamp if never accessed)
            lru_key = min(
                self._cache.keys(),
                key=lambda k: self._cache[k].last_access or self._cache[k].timestamp
            )
            del self._cache[lru_key]
            self._stats.evictions += 1
    
    def get(self, key: str) -> Optional[Any]:
        """Get value from cache"""
        with self._lock:
            self._evict_expired()
            
            if key in self._cache:
                entry = self._cache[key]
                
                if not entry.is_expired():
                    entry.access()
                    self._stats.hits += 1
                    logger.debug(f"💾 Cache HIT [{self.name}]: {key[:8]}")
                    return entry.value
                else:
                    # Expired entry
                    del self._cache[key]
                    self._stats.evictions += 1
            
            self._stats.misses += 1
            logger.debug(f"💾 Cache MISS [{self.name}]: {key[:8]}")
            return None
    
    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> bool:
        """Set value in cache"""
        if not key or value is None:
            return False
            
        ttl = ttl or self.default_ttl
        
        with self._lock:
            # Clean up expired entries
            self._evict_expired()
            
            # Evict LRU if cache is full
            self._evict_lru()
            
            # Calculate size
            size_bytes = len(json.dumps(value, default=str).encode()) if value else 0
            
            # Create cache entry
            entry = CacheEntry(
                value=value,
                timestamp=time.time(),
                ttl_seconds=ttl,
                size_bytes=size_bytes
            )
            
            self._cache[key] = entry
            self._stats.sets += 1
            self._stats.total_size_bytes += size_bytes
            
            logger.debug(f"💾 Cache SET [{self.name}]: {key[:8]}, size={size_bytes}b, ttl={ttl}s")
            return True
    
    def delete(self, key: str) -> bool:
        """Delete entry from cache"""
        with self._lock:
            if key in self._cache:
                entry = self._cache[key]
                self._stats.total_size_bytes -= entry.size_bytes
                del self._cache[key]
                logger.debug(f"💾 Cache DELETE [{self.name}]: {key[:8]}")
                return True
            return False
    
    def clear(self):
        """Clear all cache entries"""
        with self._lock:
            self._cache.clear()
            self._stats = CacheStats()
            logger.info(f"💾 Cache CLEARED [{self.name}]")
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        with self._lock:
            return {
                'name': self.name,
                'size': len(self._cache),
                'max_entries': self.max_entries,
                'hit_rate': round(self._stats.hit_rate, 2),
                'hits': self._stats.hits,
                'misses': self._stats.misses,
                'sets': self._stats.sets,
                'evictions': self._stats.evictions,
                'total_operations': self._stats.total_operations,
                'total_size_bytes': self._stats.total_size_bytes,
                'average_entry_size': (
                    self._stats.total_size_bytes / len(self._cache) 
                    if len(self._cache) > 0 else 0
                )
            }

class ValidationCacheManager:
    """Manages validation-specific caching"""
    
    def __init__(self, config):
        self.config = config
        
        # Initialize caches
        self.validation_cache = InMemoryCache(
            max_entries=config.validation_max_entries,
            default_ttl=config.validation_ttl_seconds,
            name="validation"
        )
        
        self.tenant_cache = InMemoryCache(
            max_entries=config.tenant_max_entries,
            default_ttl=config.tenant_ttl_seconds,
            name="tenant"
        )
        
        self.permission_cache = InMemoryCache(
            max_entries=config.permission_max_entries,
            default_ttl=config.permission_ttl_seconds,
            name="permission"
        )
        
        # Performance tracking
        self.performance_metrics = defaultdict(list)
        
        logger.info(f"💾 Validation cache manager initialized")
    
    def get_validation_key(self, token: str, tenant_id: str, operation: str = "validate") -> str:
        """Generate validation cache key"""
        # Use hash of token for privacy
        token_hash = hashlib.sha256(token.encode()).hexdigest()[:16]
        return self.validation_cache._generate_key(token_hash, tenant_id, operation, prefix="val")
    
    def get_tenant_key(self, tenant_id: str, operation: str = "info") -> str:
        """Generate tenant cache key"""
        return self.tenant_cache._generate_key(tenant_id, operation, prefix="tenant")
    
    def get_permission_key(self, user_id: str, tenant_id: str, resource: str) -> str:
        """Generate permission cache key"""
        return self.permission_cache._generate_key(user_id, tenant_id, resource, prefix="perm")
    
    def cache_validation_result(self, token: str, tenant_id: str, result: Dict[str, Any], 
                               ttl: Optional[int] = None) -> bool:
        """Cache validation result"""
        if not self.config.validation_enabled:
            return False
            
        # Only cache successful validations
        if not result.get('p_success', False):
            return False
        
        key = self.get_validation_key(token, tenant_id)
        
        # Add cache metadata
        cached_result = {
            **result,
            'cached_at': datetime.now().isoformat(),
            'cache_ttl': ttl or self.config.validation_ttl_seconds
        }
        
        return self.validation_cache.set(key, cached_result, ttl)
    
    def get_cached_validation(self, token: str, tenant_id: str) -> Optional[Dict[str, Any]]:
        """Get cached validation result"""
        if not self.config.validation_enabled:
            return None
            
        key = self.get_validation_key(token, tenant_id)
        result = self.validation_cache.get(key)
        
        if result:
            # Add cache hit metadata
            result['cache_hit'] = True
            result['cache_hit_at'] = datetime.now().isoformat()
        
        return result
    
    def cache_tenant_info(self, tenant_id: str, tenant_info: Dict[str, Any], 
                         ttl: Optional[int] = None) -> bool:
        """Cache tenant information"""
        if not self.config.tenant_enabled:
            return False
            
        key = self.get_tenant_key(tenant_id)
        
        cached_info = {
            **tenant_info,
            'cached_at': datetime.now().isoformat()
        }
        
        return self.tenant_cache.set(key, cached_info, ttl)
    
    def get_cached_tenant_info(self, tenant_id: str) -> Optional[Dict[str, Any]]:
        """Get cached tenant information"""
        if not self.config.tenant_enabled:
            return None
            
        key = self.get_tenant_key(tenant_id)
        return self.tenant_cache.get(key)
    
    def cache_permission_result(self, user_id: str, tenant_id: str, resource: str,
                               has_permission: bool, ttl: Optional[int] = None) -> bool:
        """Cache permission check result"""
        if not self.config.permission_enabled:
            return False
            
        key = self.get_permission_key(user_id, tenant_id, resource)
        
        permission_result = {
            'has_permission': has_permission,
            'cached_at': datetime.now().isoformat(),
            'user_id': user_id,
            'tenant_id': tenant_id,
            'resource': resource
        }
        
        return self.permission_cache.set(key, permission_result, ttl)
    
    def get_cached_permission(self, user_id: str, tenant_id: str, resource: str) -> Optional[bool]:
        """Get cached permission result"""
        if not self.config.permission_enabled:
            return None
            
        key = self.get_permission_key(user_id, tenant_id, resource)
        result = self.permission_cache.get(key)
        
        return result.get('has_permission') if result else None
    
    def invalidate_user_cache(self, user_id: str):
        """Invalidate all cache entries for a user"""
        # This is a simplified version - in production you'd want more efficient indexing
        for cache in [self.validation_cache, self.permission_cache]:
            keys_to_delete = []
            with cache._lock:
                for key, entry in cache._cache.items():
                    if isinstance(entry.value, dict) and entry.value.get('user_id') == user_id:
                        keys_to_delete.append(key)
            
            for key in keys_to_delete:
                cache.delete(key)
        
        logger.info(f"💾 Invalidated cache for user: {user_id}")
    
    def invalidate_tenant_cache(self, tenant_id: str):
        """Invalidate all cache entries for a tenant"""
        for cache in [self.validation_cache, self.tenant_cache, self.permission_cache]:
            keys_to_delete = []
            with cache._lock:
                for key, entry in cache._cache.items():
                    if isinstance(entry.value, dict) and entry.value.get('tenant_id') == tenant_id:
                        keys_to_delete.append(key)
            
            for key in keys_to_delete:
                cache.delete(key)
        
        logger.info(f"💾 Invalidated cache for tenant: {tenant_id}")
    
    def record_performance_metric(self, operation: str, duration_ms: int, cache_hit: bool):
        """Record performance metric for analysis"""
        metric = {
            'operation': operation,
            'duration_ms': duration_ms,
            'cache_hit': cache_hit,
            'timestamp': time.time()
        }
        
        self.performance_metrics[operation].append(metric)
        
        # Keep only recent metrics (last 1000 per operation)
        if len(self.performance_metrics[operation]) > 1000:
            self.performance_metrics[operation] = self.performance_metrics[operation][-1000:]
    
    def get_performance_summary(self) -> Dict[str, Any]:
        """Get performance summary across all operations"""
        summary = {}
        
        for operation, metrics in self.performance_metrics.items():
            if not metrics:
                continue
                
            recent_metrics = [m for m in metrics if time.time() - m['timestamp'] < 3600]  # Last hour
            
            if not recent_metrics:
                continue
            
            cache_hits = [m for m in recent_metrics if m['cache_hit']]
            cache_misses = [m for m in recent_metrics if not m['cache_hit']]
            
            avg_duration_cache_hit = (
                sum(m['duration_ms'] for m in cache_hits) / len(cache_hits)
                if cache_hits else 0
            )
            
            avg_duration_cache_miss = (
                sum(m['duration_ms'] for m in cache_misses) / len(cache_misses)
                if cache_misses else 0
            )
            
            summary[operation] = {
                'total_operations': len(recent_metrics),
                'cache_hit_rate': len(cache_hits) / len(recent_metrics) * 100 if recent_metrics else 0,
                'avg_duration_cache_hit_ms': round(avg_duration_cache_hit, 2),
                'avg_duration_cache_miss_ms': round(avg_duration_cache_miss, 2),
                'performance_improvement_ms': round(avg_duration_cache_miss - avg_duration_cache_hit, 2)
            }
        
        return summary
    
    def get_comprehensive_stats(self) -> Dict[str, Any]:
        """Get comprehensive cache statistics"""
        return {
            'enabled': self.config.enabled,
            'provider': self.config.provider,
            'caches': {
                'validation': self.validation_cache.get_stats(),
                'tenant': self.tenant_cache.get_stats(),
                'permission': self.permission_cache.get_stats()
            },
            'performance_summary': self.get_performance_summary(),
            'total_memory_usage_mb': sum([
                cache.get_stats()['total_size_bytes'] 
                for cache in [self.validation_cache, self.tenant_cache, self.permission_cache]
            ]) / 1024 / 1024
        }
    
    def optimize_cache_performance(self):
        """Optimize cache performance based on usage patterns"""
        stats = self.get_comprehensive_stats()
        
        # Auto-adjust TTL based on hit rates
        for cache_name, cache_stats in stats['caches'].items():
            cache_obj = getattr(self, f"{cache_name}_cache")
            
            if cache_stats['hit_rate'] < 50:  # Low hit rate
                # Increase TTL to keep entries longer
                cache_obj.default_ttl = min(cache_obj.default_ttl * 1.2, 1800)  # Max 30 minutes
                logger.info(f"💾 Increased TTL for {cache_name} cache due to low hit rate")
            elif cache_stats['hit_rate'] > 90:  # Very high hit rate
                # Can decrease TTL slightly to free memory
                cache_obj.default_ttl = max(cache_obj.default_ttl * 0.9, 60)  # Min 1 minute
                logger.info(f"💾 Decreased TTL for {cache_name} cache due to high hit rate")

class PerformanceCacheManager:
    """Main performance cache manager"""
    
    def __init__(self):
        self.config = get_cache_config()
        
        # Guard clause: Check if caching is enabled
        if not self.config.enabled:
            logger.warning("💾 Caching disabled in configuration")
            self.validation_manager = None
            return
        
        self.validation_manager = ValidationCacheManager(self.config)
        
        # Start background optimization task
        self._optimization_task = None
        self._start_optimization_loop()
        
        logger.info(f"💾 Performance cache manager initialized: provider={self.config.provider}")
    
    def _start_optimization_loop(self):
        """Start background cache optimization"""
        async def optimization_loop():
            while True:
                try:
                    await asyncio.sleep(300)  # Optimize every 5 minutes
                    if self.validation_manager:
                        self.validation_manager.optimize_cache_performance()
                except Exception as e:
                    logger.error(f"❌ Cache optimization error: {e}")
        
        try:
            loop = asyncio.get_event_loop()
            self._optimization_task = loop.create_task(optimization_loop())
        except RuntimeError:
            # No event loop running yet
            pass
    
    def is_enabled(self) -> bool:
        """Check if caching is enabled"""
        return self.config.enabled and self.validation_manager is not None
    
    def get_cached_validation(self, token: str, tenant_id: str) -> Optional[Dict[str, Any]]:
        """Get cached validation result"""
        if not self.is_enabled():
            return None
        return self.validation_manager.get_cached_validation(token, tenant_id)
    
    def cache_validation_result(self, token: str, tenant_id: str, result: Dict[str, Any], 
                               ttl: Optional[int] = None) -> bool:
        """Cache validation result"""
        if not self.is_enabled():
            return False
        return self.validation_manager.cache_validation_result(token, tenant_id, result, ttl)
    
    def record_performance(self, operation: str, duration_ms: int, cache_hit: bool):
        """Record performance metric"""
        if not self.is_enabled():
            return
        self.validation_manager.record_performance_metric(operation, duration_ms, cache_hit)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get comprehensive cache statistics"""
        if not self.is_enabled():
            return {'enabled': False, 'message': 'Caching disabled'}
        
        return self.validation_manager.get_comprehensive_stats()
    
    def clear_all_caches(self):
        """Clear all caches"""
        if not self.is_enabled():
            return
        
        self.validation_manager.validation_cache.clear()
        self.validation_manager.tenant_cache.clear()
        self.validation_manager.permission_cache.clear()
        
        logger.info("💾 All caches cleared")

# Global cache manager instance
_cache_manager_instance: Optional[PerformanceCacheManager] = None

def get_cache_manager() -> PerformanceCacheManager:
    """Get global cache manager instance (singleton pattern)"""
    global _cache_manager_instance
    
    if _cache_manager_instance is None:
        _cache_manager_instance = PerformanceCacheManager()
    
    return _cache_manager_instance 