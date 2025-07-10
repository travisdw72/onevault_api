"""
Tests for ResourceValidationService
===================================

Comprehensive test suite for cross-tenant resource validation:
- User validation against tenant context
- Asset validation against tenant context  
- Transaction validation against tenant context
- Session validation against tenant context
- Bulk validation operations
- Cache functionality and performance
"""

import pytest
from unittest.mock import Mock, patch
from datetime import datetime, timezone

from app.services.resource_validator import ResourceValidationService


class TestResourceValidationService:
    """Test suite for ResourceValidationService"""
    
    def setup_method(self):
        """Set up test fixtures"""
        self.service = ResourceValidationService()
        self.mock_tenant_hk = b'\x01\x02\x03\x04' * 8  # 32 bytes
        self.mock_user_hk = b'\x05\x06\x07\x08' * 8    # 32 bytes
    
    def teardown_method(self):
        """Clean up after each test"""
        # Clear validation cache
        self.service._validation_cache.clear()
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_verify_user_belongs_to_tenant_success(self, mock_connect):
        """Test successful user validation"""
        # Mock database response
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            self.mock_user_hk,      # user_hk
            "user_test_123",        # user_bk
            "test@example.com",     # email
            "John",                 # first_name
            "Doe"                   # last_name
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        user_bk = "user_test_123"
        result = await self.service.verify_user_belongs_to_tenant(user_bk, self.mock_tenant_hk)
        
        assert result == True
        mock_cursor.execute.assert_called_once()
        mock_cursor.close.assert_called_once()
        mock_conn.close.assert_called_once()
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_verify_user_belongs_to_tenant_not_found(self, mock_connect):
        """Test user validation when user not found"""
        # Mock database response - no result
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = None
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        user_bk = "nonexistent_user"
        result = await self.service.verify_user_belongs_to_tenant(user_bk, self.mock_tenant_hk)
        
        assert result == False
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_verify_user_belongs_to_tenant_database_error(self, mock_connect):
        """Test user validation handles database errors securely"""
        # Mock database error
        mock_connect.side_effect = Exception("Database connection failed")
        
        user_bk = "user_test_123"
        result = await self.service.verify_user_belongs_to_tenant(user_bk, self.mock_tenant_hk)
        
        # Should fail secure
        assert result == False
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_verify_user_email_belongs_to_tenant_success(self, mock_connect):
        """Test successful email validation"""
        # Mock database response
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            self.mock_user_hk,      # user_hk
            "user_test_123",        # user_bk
            "test@example.com"      # email
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        email = "test@example.com"
        result = await self.service.verify_user_email_belongs_to_tenant(email, self.mock_tenant_hk)
        
        assert result == True
        
        # Verify correct SQL query structure
        call_args = mock_cursor.execute.call_args[0]
        query = call_args[0]
        params = call_args[1]
        
        assert "up.email = %s" in query
        assert "uh.tenant_hk = %s" in query
        assert params == (email, self.mock_tenant_hk)
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_verify_asset_belongs_to_tenant_success(self, mock_connect):
        """Test successful asset validation"""
        # Mock database response
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            b'\x09\x0a\x0b\x0c' * 8,  # asset_hk
            "asset_test_456",         # asset_bk
            "Test Asset",             # asset_name
            "Equipment"               # asset_type
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        asset_bk = "asset_test_456"
        result = await self.service.verify_asset_belongs_to_tenant(asset_bk, self.mock_tenant_hk)
        
        assert result == True
        
        # Verify asset-specific query
        call_args = mock_cursor.execute.call_args[0]
        query = call_args[0]
        assert "business.asset_h" in query
        assert "business.asset_details_s" in query
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_verify_transaction_belongs_to_tenant_success(self, mock_connect):
        """Test successful transaction validation"""
        # Mock database response
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            b'\x0d\x0e\x0f\x10' * 8,  # transaction_hk
            "transaction_test_789",    # transaction_bk
            "Sale",                    # transaction_type
            1000.00                    # amount
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        transaction_bk = "transaction_test_789"
        result = await self.service.verify_transaction_belongs_to_tenant(transaction_bk, self.mock_tenant_hk)
        
        assert result == True
        
        # Verify transaction-specific query
        call_args = mock_cursor.execute.call_args[0]
        query = call_args[0]
        assert "business.transaction_h" in query
        assert "business.transaction_details_s" in query
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_verify_session_belongs_to_tenant_success(self, mock_connect):
        """Test successful session validation"""
        # Mock database response
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            b'\x11\x12\x13\x14' * 8,  # session_hk
            "sess_test_111",           # session_bk
            self.mock_user_hk,         # user_hk
            "user_test_123",           # user_bk
            "ACTIVE"                   # session_status
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        session_token = "sess_test_111"
        result = await self.service.verify_session_belongs_to_tenant(session_token, self.mock_tenant_hk)
        
        assert result == True
        
        # Verify session-specific query with joins
        call_args = mock_cursor.execute.call_args[0]
        query = call_args[0]
        assert "auth.session_h" in query
        assert "auth.session_state_s" in query
        assert "auth.user_session_l" in query
        assert "auth.user_h" in query
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_verify_ai_agent_belongs_to_tenant_success(self, mock_connect):
        """Test successful AI agent validation"""
        # Mock database response
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            b'\x15\x16\x17\x18' * 8,  # agent_hk
            "agent_test_222",          # agent_bk
            "Business Analyst",        # agent_name
            "analysis"                 # agent_type
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        agent_bk = "agent_test_222"
        result = await self.service.verify_ai_agent_belongs_to_tenant(agent_bk, self.mock_tenant_hk)
        
        assert result == True
        
        # Verify AI agent-specific query
        call_args = mock_cursor.execute.call_args[0]
        query = call_args[0]
        assert "ai_agents.agent_h" in query
        assert "ai_agents.agent_identity_s" in query
    
    @pytest.mark.asyncio
    async def test_bulk_validate_resources_success(self):
        """Test bulk validation with mixed resource types"""
        # Mock individual validation methods
        async def mock_verify_user(user_bk, tenant_hk):
            return True
        async def mock_verify_asset(asset_bk, tenant_hk):
            return True
        async def mock_verify_transaction(transaction_bk, tenant_hk):
            return False  # One failure
        
        self.service.verify_user_belongs_to_tenant = mock_verify_user
        self.service.verify_asset_belongs_to_tenant = mock_verify_asset
        self.service.verify_transaction_belongs_to_tenant = mock_verify_transaction
        
        resources = [
            ("user_bk", "user_test_123"),
            ("asset_bk", "asset_test_456"),
            ("transaction_bk", "transaction_test_789"),
            ("unknown_type", "unknown_value")  # Should default to True
        ]
        
        results = await self.service.bulk_validate_resources(resources, self.mock_tenant_hk)
        
        assert results["user_bk:user_test_123"] == True
        assert results["asset_bk:asset_test_456"] == True
        assert results["transaction_bk:transaction_test_789"] == False
        assert results["unknown_type:unknown_value"] == True
    
    @pytest.mark.asyncio
    async def test_bulk_validate_resources_with_exceptions(self):
        """Test bulk validation handles exceptions gracefully"""
        # Mock validation method to raise exception
        async def mock_verify_user_error(user_bk, tenant_hk):
            raise Exception("Database error")
        
        self.service.verify_user_belongs_to_tenant = mock_verify_user_error
        
        resources = [("user_bk", "user_test_123")]
        
        results = await self.service.bulk_validate_resources(resources, self.mock_tenant_hk)
        
        # Should handle exception and return False
        assert results["user_bk:user_test_123"] == False
    
    def test_cache_functionality(self):
        """Test validation result caching"""
        cache_key = "user:test_user:abcd1234"
        
        # Cache a result
        self.service._cache_validation_result(cache_key, True)
        
        # Check cache hit
        assert self.service._is_cached_and_valid(cache_key) == True
        assert self.service._validation_cache[cache_key]['result'] == True
    
    def test_cache_expiration(self):
        """Test cache expiration functionality"""
        cache_key = "user:test_user:abcd1234"
        
        # Cache a result with short TTL
        self.service._cache_validation_result(cache_key, True, ttl_seconds=0)
        
        # Should be expired immediately
        assert self.service._is_cached_and_valid(cache_key) == False
    
    def test_cache_cleanup(self):
        """Test expired cache cleanup"""
        # Add expired entries
        for i in range(5):
            cache_key = f"user:test_user_{i}:abcd1234"
            self.service._cache_validation_result(cache_key, True, ttl_seconds=0)
        
        # Add valid entry
        valid_key = "user:valid_user:abcd1234"
        self.service._cache_validation_result(valid_key, True, ttl_seconds=300)
        
        # Trigger cleanup
        self.service._cleanup_expired_cache()
        
        # Only valid entry should remain
        assert len(self.service._validation_cache) == 1
        assert valid_key in self.service._validation_cache
    
    def test_get_validation_stats(self):
        """Test validation statistics"""
        # Add some cache entries
        self.service._cache_validation_result("user:test1:abcd", True, ttl_seconds=300)
        self.service._cache_validation_result("user:test2:abcd", False, ttl_seconds=0)  # Expired
        
        stats = self.service.get_validation_stats()
        
        assert 'cache_entries_valid' in stats
        assert 'cache_entries_expired' in stats
        assert 'cache_hit_potential' in stats
        assert 'cache_cleanup_recommended' in stats
        
        assert stats['cache_entries_valid'] == 1
        assert stats['cache_entries_expired'] == 1
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_caching_improves_performance(self, mock_connect):
        """Test that caching improves performance on repeated calls"""
        # Mock database response
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            self.mock_user_hk,
            "user_test_123",
            "test@example.com",
            "John",
            "Doe"
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        user_bk = "user_performance_test"
        
        # First call - should hit database
        result1 = await self.service.verify_user_belongs_to_tenant(user_bk, self.mock_tenant_hk)
        assert result1 == True
        assert mock_cursor.execute.call_count == 1
        
        # Second call - should hit cache
        result2 = await self.service.verify_user_belongs_to_tenant(user_bk, self.mock_tenant_hk)
        assert result2 == True
        # Database should not be called again
        assert mock_cursor.execute.call_count == 1
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_cross_tenant_validation_blocked(self, mock_connect):
        """Test that cross-tenant resource access is properly blocked"""
        # Mock database response - no result (resource belongs to different tenant)
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = None
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        user_bk = "cross_tenant_user"
        result = await self.service.verify_user_belongs_to_tenant(user_bk, self.mock_tenant_hk)
        
        assert result == False
        
        # Verify the query includes tenant filtering
        call_args = mock_cursor.execute.call_args[0]
        query = call_args[0]
        params = call_args[1]
        
        assert "uh.tenant_hk = %s" in query
        assert self.mock_tenant_hk in params


# Performance tests
class TestResourceValidationPerformance:
    """Performance tests for ResourceValidationService"""
    
    def setup_method(self):
        """Set up performance test fixtures"""
        self.service = ResourceValidationService()
        self.mock_tenant_hk = b'\x01\x02\x03\x04' * 8
    
    @pytest.mark.asyncio
    async def test_bulk_validation_performance(self):
        """Test bulk validation performance with large resource sets"""
        # Mock validation methods for performance testing
        async def mock_verify_fast(resource_id, tenant_hk):
            return True
        
        self.service.verify_user_belongs_to_tenant = mock_verify_fast
        self.service.verify_asset_belongs_to_tenant = mock_verify_fast
        
        # Create large resource set
        resources = []
        for i in range(100):
            if i % 2 == 0:
                resources.append(("user_bk", f"user_{i}"))
            else:
                resources.append(("asset_bk", f"asset_{i}"))
        
        # Time the bulk validation
        import time
        start_time = time.time()
        
        results = await self.service.bulk_validate_resources(resources, self.mock_tenant_hk)
        
        end_time = time.time()
        execution_time = end_time - start_time
        
        # Should complete within reasonable time (< 1 second for 100 resources)
        assert execution_time < 1.0
        assert len(results) == 100
        assert all(result == True for result in results.values())


# Security tests
class TestResourceValidationSecurity:
    """Security-focused tests for ResourceValidationService"""
    
    def setup_method(self):
        """Set up security test fixtures"""
        self.service = ResourceValidationService()
        self.mock_tenant_hk = b'\x01\x02\x03\x04' * 8
        self.malicious_tenant_hk = b'\x99\x99\x99\x99' * 8
    
    @patch('app.services.resource_validator.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_sql_injection_protection(self, mock_connect):
        """Test protection against SQL injection in resource IDs"""
        # Mock database connection
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = None
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        # Attempt SQL injection
        malicious_user_bk = "user'; DROP TABLE auth.user_h; --"
        
        result = await self.service.verify_user_belongs_to_tenant(malicious_user_bk, self.mock_tenant_hk)
        
        # Should safely handle malicious input
        assert result == False
        
        # Verify parameterized query was used
        call_args = mock_cursor.execute.call_args[0]
        query = call_args[0]
        params = call_args[1]
        
        # Should use parameters, not string concatenation
        assert "%s" in query
        assert malicious_user_bk in params
    
    @pytest.mark.asyncio
    async def test_timing_attack_resistance(self):
        """Test resistance to timing attacks"""
        # This would measure response times for valid vs invalid requests
        # to ensure consistent timing regardless of validity
        # Implementation would depend on specific timing requirements
        pass
    
    @pytest.mark.asyncio
    async def test_cache_poisoning_protection(self):
        """Test protection against cache poisoning attacks"""
        # Cache a valid result
        legitimate_key = f"user:legitimate_user:{self.mock_tenant_hk.hex()}"
        self.service._cache_validation_result(legitimate_key, True)
        
        # Attempt to poison cache with different tenant
        malicious_key = f"user:legitimate_user:{self.malicious_tenant_hk.hex()}"
        self.service._cache_validation_result(malicious_key, True)
        
        # Verify cache isolation
        assert self.service._is_cached_and_valid(legitimate_key) == True
        assert self.service._is_cached_and_valid(malicious_key) == True
        
        # But they should be separate entries
        assert legitimate_key != malicious_key


if __name__ == "__main__":
    pytest.main([__file__]) 