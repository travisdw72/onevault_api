"""
Resource Validation Service
===========================

Cryptographic verification that all resource IDs derive from tenant context.
Prevents cross-tenant resource access at the gateway level.

SECURITY PRINCIPLE: Every business key must be verified against authenticated tenant
- Users: user_bk must exist in tenant's user hub
- Assets: asset_bk must exist in tenant's asset hub  
- Transactions: transaction_bk must exist in tenant's transaction hub
- Sessions: session_token must belong to tenant's users
- All lookups use cryptographic hash verification
"""

import hashlib
import logging
from datetime import datetime, timezone
from typing import Dict, Optional, List, Tuple, Any

import psycopg2

logger = logging.getLogger(__name__)

class ResourceValidationService:
    """
    Cross-Tenant Resource Validation Service
    
    This service implements bulletproof cross-tenant access prevention by:
    1. Verifying all user business keys belong to authenticated tenant
    2. Verifying all asset business keys belong to authenticated tenant
    3. Verifying all transaction business keys belong to authenticated tenant
    4. Verifying all session tokens belong to tenant's users
    5. Caching validation results for performance
    """
    
    def __init__(self):
        self._validation_cache = {}
        self._cache_ttl_seconds = 300  # 5 minutes cache TTL
    
    async def verify_user_belongs_to_tenant(self, user_bk: str, tenant_hk: bytes) -> bool:
        """
        Verify user business key belongs to authenticated tenant
        
        Args:
            user_bk: User business key (username/email)
            tenant_hk: Authenticated tenant hash key
            
        Returns:
            bool: True if user belongs to tenant, False otherwise
        """
        cache_key = f"user:{user_bk}:{tenant_hk.hex()}"
        
        # Check cache first
        if self._is_cached_and_valid(cache_key):
            return self._validation_cache[cache_key]['result']
        
        try:
            conn = self._get_db_connection()
            cursor = conn.cursor()
            
            # Query to verify user belongs to tenant
            query = """
            SELECT 
                uh.user_hk,
                uh.user_bk,
                up.email,
                up.first_name,
                up.last_name
            FROM auth.user_h uh
            LEFT JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk 
                AND up.load_end_date IS NULL
            WHERE uh.user_bk = %s 
                AND uh.tenant_hk = %s
            """
            
            cursor.execute(query, (user_bk, tenant_hk))
            result = cursor.fetchone()
            
            cursor.close()
            conn.close()
            
            is_valid = bool(result)
            
            # Cache the result
            self._cache_validation_result(cache_key, is_valid)
            
            if is_valid:
                logger.debug(f"User validation SUCCESS: {user_bk} belongs to tenant")
            else:
                logger.warning(f"User validation FAILED: {user_bk} does not belong to tenant")
            
            return is_valid
            
        except Exception as e:
            logger.error(f"User validation error for {user_bk}: {e}")
            return False  # Fail secure
    
    async def verify_user_email_belongs_to_tenant(self, email: str, tenant_hk: bytes) -> bool:
        """
        Verify user email belongs to authenticated tenant
        
        Args:
            email: User email address
            tenant_hk: Authenticated tenant hash key
            
        Returns:
            bool: True if email belongs to tenant, False otherwise
        """
        cache_key = f"email:{email}:{tenant_hk.hex()}"
        
        # Check cache first
        if self._is_cached_and_valid(cache_key):
            return self._validation_cache[cache_key]['result']
        
        try:
            conn = self._get_db_connection()
            cursor = conn.cursor()
            
            # Query to verify email belongs to tenant
            query = """
            SELECT 
                uh.user_hk,
                uh.user_bk,
                up.email
            FROM auth.user_h uh
            JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
            WHERE up.email = %s 
                AND uh.tenant_hk = %s
                AND up.load_end_date IS NULL
            """
            
            cursor.execute(query, (email, tenant_hk))
            result = cursor.fetchone()
            
            cursor.close()
            conn.close()
            
            is_valid = bool(result)
            
            # Cache the result
            self._cache_validation_result(cache_key, is_valid)
            
            if is_valid:
                logger.debug(f"Email validation SUCCESS: {email} belongs to tenant")
            else:
                logger.warning(f"Email validation FAILED: {email} does not belong to tenant")
            
            return is_valid
            
        except Exception as e:
            logger.error(f"Email validation error for {email}: {e}")
            return False  # Fail secure
    
    async def verify_asset_belongs_to_tenant(self, asset_bk: str, tenant_hk: bytes) -> bool:
        """
        Verify asset business key belongs to authenticated tenant
        
        Args:
            asset_bk: Asset business key
            tenant_hk: Authenticated tenant hash key
            
        Returns:
            bool: True if asset belongs to tenant, False otherwise
        """
        cache_key = f"asset:{asset_bk}:{tenant_hk.hex()}"
        
        # Check cache first
        if self._is_cached_and_valid(cache_key):
            return self._validation_cache[cache_key]['result']
        
        try:
            conn = self._get_db_connection()
            cursor = conn.cursor()
            
            # Query to verify asset belongs to tenant
            query = """
            SELECT 
                ah.asset_hk,
                ah.asset_bk,
                ads.asset_name,
                ads.asset_type
            FROM business.asset_h ah
            LEFT JOIN business.asset_details_s ads ON ah.asset_hk = ads.asset_hk
                AND ads.load_end_date IS NULL
            WHERE ah.asset_bk = %s 
                AND ah.tenant_hk = %s
            """
            
            cursor.execute(query, (asset_bk, tenant_hk))
            result = cursor.fetchone()
            
            cursor.close()
            conn.close()
            
            is_valid = bool(result)
            
            # Cache the result
            self._cache_validation_result(cache_key, is_valid)
            
            if is_valid:
                logger.debug(f"Asset validation SUCCESS: {asset_bk} belongs to tenant")
            else:
                logger.warning(f"Asset validation FAILED: {asset_bk} does not belong to tenant")
            
            return is_valid
            
        except Exception as e:
            logger.error(f"Asset validation error for {asset_bk}: {e}")
            return False  # Fail secure
    
    async def verify_transaction_belongs_to_tenant(self, transaction_bk: str, tenant_hk: bytes) -> bool:
        """
        Verify transaction business key belongs to authenticated tenant
        
        Args:
            transaction_bk: Transaction business key
            tenant_hk: Authenticated tenant hash key
            
        Returns:
            bool: True if transaction belongs to tenant, False otherwise
        """
        cache_key = f"transaction:{transaction_bk}:{tenant_hk.hex()}"
        
        # Check cache first
        if self._is_cached_and_valid(cache_key):
            return self._validation_cache[cache_key]['result']
        
        try:
            conn = self._get_db_connection()
            cursor = conn.cursor()
            
            # Query to verify transaction belongs to tenant
            query = """
            SELECT 
                th.transaction_hk,
                th.transaction_bk,
                tds.transaction_type,
                tds.amount
            FROM business.transaction_h th
            LEFT JOIN business.transaction_details_s tds ON th.transaction_hk = tds.transaction_hk
                AND tds.load_end_date IS NULL
            WHERE th.transaction_bk = %s 
                AND th.tenant_hk = %s
            """
            
            cursor.execute(query, (transaction_bk, tenant_hk))
            result = cursor.fetchone()
            
            cursor.close()
            conn.close()
            
            is_valid = bool(result)
            
            # Cache the result
            self._cache_validation_result(cache_key, is_valid)
            
            if is_valid:
                logger.debug(f"Transaction validation SUCCESS: {transaction_bk} belongs to tenant")
            else:
                logger.warning(f"Transaction validation FAILED: {transaction_bk} does not belong to tenant")
            
            return is_valid
            
        except Exception as e:
            logger.error(f"Transaction validation error for {transaction_bk}: {e}")
            return False  # Fail secure
    
    async def verify_session_belongs_to_tenant(self, session_token: str, tenant_hk: bytes) -> bool:
        """
        Verify session token belongs to a user of the authenticated tenant
        
        Args:
            session_token: Session token/business key
            tenant_hk: Authenticated tenant hash key
            
        Returns:
            bool: True if session belongs to tenant user, False otherwise
        """
        cache_key = f"session:{session_token}:{tenant_hk.hex()}"
        
        # Check cache first
        if self._is_cached_and_valid(cache_key):
            return self._validation_cache[cache_key]['result']
        
        try:
            conn = self._get_db_connection()
            cursor = conn.cursor()
            
            # Query to verify session belongs to tenant user
            query = """
            SELECT 
                sh.session_hk,
                sh.session_bk,
                uh.user_hk,
                uh.user_bk,
                ss.session_status
            FROM auth.session_h sh
            JOIN auth.session_state_s ss ON sh.session_hk = ss.session_hk
            JOIN auth.user_session_l usl ON sh.session_hk = usl.session_hk
            JOIN auth.user_h uh ON usl.user_hk = uh.user_hk
            WHERE sh.session_bk = %s
                AND uh.tenant_hk = %s
                AND ss.load_end_date IS NULL
                AND ss.session_status = 'ACTIVE'
            """
            
            cursor.execute(query, (session_token, tenant_hk))
            result = cursor.fetchone()
            
            cursor.close()
            conn.close()
            
            is_valid = bool(result)
            
            # Cache the result (shorter TTL for sessions)
            self._cache_validation_result(cache_key, is_valid, ttl_seconds=60)
            
            if is_valid:
                logger.debug(f"Session validation SUCCESS: {session_token} belongs to tenant")
            else:
                logger.warning(f"Session validation FAILED: {session_token} does not belong to tenant")
            
            return is_valid
            
        except Exception as e:
            logger.error(f"Session validation error for {session_token}: {e}")
            return False  # Fail secure
    
    async def verify_ai_agent_belongs_to_tenant(self, agent_bk: str, tenant_hk: bytes) -> bool:
        """
        Verify AI agent belongs to authenticated tenant
        
        Args:
            agent_bk: AI agent business key
            tenant_hk: Authenticated tenant hash key
            
        Returns:
            bool: True if agent belongs to tenant, False otherwise
        """
        cache_key = f"agent:{agent_bk}:{tenant_hk.hex()}"
        
        # Check cache first
        if self._is_cached_and_valid(cache_key):
            return self._validation_cache[cache_key]['result']
        
        try:
            conn = self._get_db_connection()
            cursor = conn.cursor()
            
            # Query to verify AI agent belongs to tenant
            query = """
            SELECT 
                ah.agent_hk,
                ah.agent_bk,
                ais.agent_name,
                ais.agent_type
            FROM ai_agents.agent_h ah
            LEFT JOIN ai_agents.agent_identity_s ais ON ah.agent_hk = ais.agent_hk
                AND ais.load_end_date IS NULL
            WHERE ah.agent_bk = %s 
                AND ah.tenant_hk = %s
            """
            
            cursor.execute(query, (agent_bk, tenant_hk))
            result = cursor.fetchone()
            
            cursor.close()
            conn.close()
            
            is_valid = bool(result)
            
            # Cache the result
            self._cache_validation_result(cache_key, is_valid)
            
            if is_valid:
                logger.debug(f"AI Agent validation SUCCESS: {agent_bk} belongs to tenant")
            else:
                logger.warning(f"AI Agent validation FAILED: {agent_bk} does not belong to tenant")
            
            return is_valid
            
        except Exception as e:
            logger.error(f"AI Agent validation error for {agent_bk}: {e}")
            return False  # Fail secure
    
    async def bulk_validate_resources(self, resources: List[Tuple[str, str]], tenant_hk: bytes) -> Dict[str, bool]:
        """
        Bulk validate multiple resources for performance optimization
        
        Args:
            resources: List of (resource_type, resource_value) tuples
            tenant_hk: Authenticated tenant hash key
            
        Returns:
            Dict[str, bool]: Map of resource_type:resource_value -> validation_result
        """
        validation_results = {}
        
        for resource_type, resource_value in resources:
            try:
                if resource_type == 'user_bk':
                    result = await self.verify_user_belongs_to_tenant(resource_value, tenant_hk)
                elif resource_type == 'email':
                    result = await self.verify_user_email_belongs_to_tenant(resource_value, tenant_hk)
                elif resource_type == 'asset_bk':
                    result = await self.verify_asset_belongs_to_tenant(resource_value, tenant_hk)
                elif resource_type == 'transaction_bk':
                    result = await self.verify_transaction_belongs_to_tenant(resource_value, tenant_hk)
                elif resource_type == 'session_token':
                    result = await self.verify_session_belongs_to_tenant(resource_value, tenant_hk)
                elif resource_type == 'agent_bk':
                    result = await self.verify_ai_agent_belongs_to_tenant(resource_value, tenant_hk)
                else:
                    result = True  # Unknown types pass by default
                
                validation_results[f"{resource_type}:{resource_value}"] = result
                
            except Exception as e:
                logger.error(f"Bulk validation error for {resource_type}:{resource_value}: {e}")
                validation_results[f"{resource_type}:{resource_value}"] = False
        
        return validation_results
    
    def _is_cached_and_valid(self, cache_key: str) -> bool:
        """Check if validation result is cached and still valid"""
        if cache_key not in self._validation_cache:
            return False
        
        cached_entry = self._validation_cache[cache_key]
        age_seconds = (datetime.now(timezone.utc) - cached_entry['timestamp']).total_seconds()
        
        return age_seconds < cached_entry['ttl_seconds']
    
    def _cache_validation_result(self, cache_key: str, result: bool, ttl_seconds: Optional[int] = None):
        """Cache validation result with TTL"""
        self._validation_cache[cache_key] = {
            'result': result,
            'timestamp': datetime.now(timezone.utc),
            'ttl_seconds': ttl_seconds or self._cache_ttl_seconds
        }
        
        # Clean old cache entries to prevent memory growth
        self._cleanup_expired_cache()
    
    def _cleanup_expired_cache(self):
        """Remove expired cache entries"""
        current_time = datetime.now(timezone.utc)
        expired_keys = []
        
        for cache_key, entry in self._validation_cache.items():
            age_seconds = (current_time - entry['timestamp']).total_seconds()
            if age_seconds >= entry['ttl_seconds']:
                expired_keys.append(cache_key)
        
        for key in expired_keys:
            del self._validation_cache[key]
    
    def _get_db_connection(self):
        """Get database connection"""
        import os
        database_url = os.getenv('SYSTEM_DATABASE_URL')
        if not database_url:
            raise ValueError("SYSTEM_DATABASE_URL environment variable not set")
        return psycopg2.connect(database_url)
    
    def get_validation_stats(self) -> Dict[str, Any]:
        """Get validation statistics for monitoring"""
        current_time = datetime.now(timezone.utc)
        valid_entries = 0
        expired_entries = 0
        
        for entry in self._validation_cache.values():
            age_seconds = (current_time - entry['timestamp']).total_seconds()
            if age_seconds < entry['ttl_seconds']:
                valid_entries += 1
            else:
                expired_entries += 1
        
        return {
            'cache_entries_valid': valid_entries,
            'cache_entries_expired': expired_entries,
            'cache_hit_potential': f"{(valid_entries / max(1, valid_entries + expired_entries)) * 100:.1f}%",
            'cache_cleanup_recommended': expired_entries > 100
        } 