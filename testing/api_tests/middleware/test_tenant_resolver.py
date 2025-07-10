"""
Tests for TenantResolverMiddleware
=================================

Comprehensive test suite for zero trust tenant resolution:
- API key to tenant_hk resolution
- User session to user_hk resolution
- Resource ID validation against tenant context
- Cross-tenant violation detection
- Security edge cases and attack vectors
"""

import pytest
import json
from unittest.mock import Mock, patch, AsyncMock
from fastapi import Request, HTTPException
from fastapi.testclient import TestClient

from app.middleware.tenant_resolver import TenantResolverMiddleware


class TestTenantResolverMiddleware:
    """Test suite for TenantResolverMiddleware"""
    
    def setup_method(self):
        """Set up test fixtures"""
        self.middleware = TenantResolverMiddleware()
        self.mock_tenant_hk = b'\x01\x02\x03\x04' * 8  # 32 bytes
        self.mock_user_hk = b'\x05\x06\x07\x08' * 8    # 32 bytes
        
    def test_should_skip_validation_excluded_paths(self):
        """Test that excluded paths skip validation"""
        mock_request = Mock()
        mock_request.url.path = "/health"
        
        assert self.middleware._should_skip_validation(mock_request) == True
        
        mock_request.url.path = "/docs"
        assert self.middleware._should_skip_validation(mock_request) == True
        
        mock_request.url.path = "/api/v1/protected"
        assert self.middleware._should_skip_validation(mock_request) == False
    
    def test_extract_api_key_valid_header(self):
        """Test API key extraction from valid Authorization header"""
        mock_request = Mock()
        mock_request.headers = {"Authorization": "Bearer test_api_key_123"}
        
        api_key = self.middleware._extract_api_key(mock_request)
        assert api_key == "test_api_key_123"
    
    def test_extract_api_key_missing_header(self):
        """Test API key extraction fails with missing header"""
        mock_request = Mock()
        mock_request.headers = {}
        
        with pytest.raises(HTTPException) as exc_info:
            self.middleware._extract_api_key(mock_request)
        
        assert exc_info.value.status_code == 401
        assert "Missing or invalid Authorization header" in str(exc_info.value.detail)
    
    def test_extract_api_key_invalid_format(self):
        """Test API key extraction fails with invalid format"""
        mock_request = Mock()
        mock_request.headers = {"Authorization": "Basic invalid_format"}
        
        with pytest.raises(HTTPException) as exc_info:
            self.middleware._extract_api_key(mock_request)
        
        assert exc_info.value.status_code == 401
    
    def test_extract_api_key_empty_token(self):
        """Test API key extraction fails with empty token"""
        mock_request = Mock()
        mock_request.headers = {"Authorization": "Bearer "}
        
        with pytest.raises(HTTPException) as exc_info:
            self.middleware._extract_api_key(mock_request)
        
        assert exc_info.value.status_code == 401
        assert "Empty API key" in str(exc_info.value.detail)
    
    def test_extract_session_token_from_header(self):
        """Test session token extraction from header"""
        mock_request = Mock()
        mock_request.headers = {"X-Session-Token": "sess_test_123"}
        
        session_token = self.middleware._extract_session_token(mock_request)
        assert session_token == "sess_test_123"
    
    def test_extract_session_token_missing(self):
        """Test session token extraction when missing"""
        mock_request = Mock()
        mock_request.headers = {}
        
        session_token = self.middleware._extract_session_token(mock_request)
        assert session_token is None
    
    @pytest.mark.asyncio
    async def test_extract_request_body_valid_json(self):
        """Test request body extraction with valid JSON"""
        mock_request = Mock()
        mock_request.method = "POST"
        mock_request.body = AsyncMock(return_value=b'{"test": "data"}')
        
        body = await self.middleware._extract_request_body(mock_request)
        assert body == {"test": "data"}
    
    @pytest.mark.asyncio
    async def test_extract_request_body_get_request(self):
        """Test request body extraction for GET request"""
        mock_request = Mock()
        mock_request.method = "GET"
        
        body = await self.middleware._extract_request_body(mock_request)
        assert body == {}
    
    @pytest.mark.asyncio
    async def test_extract_request_body_invalid_json(self):
        """Test request body extraction with invalid JSON"""
        mock_request = Mock()
        mock_request.method = "POST"
        mock_request.body = AsyncMock(return_value=b'invalid json')
        
        body = await self.middleware._extract_request_body(mock_request)
        assert body == {}
    
    @pytest.mark.asyncio
    async def test_extract_all_resource_ids_comprehensive(self):
        """Test comprehensive resource ID extraction"""
        mock_request = Mock()
        mock_request.path_params = {"user_id": "user_test_123"}
        mock_request.query_params = {"session": "sess_test_456"}
        
        body = {
            "email": "test@example.com",
            "asset_bk": "asset_test_789",
            "nested": {
                "transaction_bk": "transaction_test_111"
            },
            "items": [
                {"agent_bk": "agent_test_222"}
            ]
        }
        
        resource_ids = await self.middleware._extract_all_resource_ids(mock_request, body)
        
        # Check that all expected resource IDs are extracted
        expected_ids = {
            "user_id:user_test_123",
            "session:sess_test_456", 
            "email:test@example.com",
            "asset_bk:asset_test_789",
            "nested.transaction_bk:transaction_test_111",
            "items[0].agent_bk:agent_test_222"
        }
        
        # All expected IDs should be present
        for expected_id in expected_ids:
            assert any(expected_id in rid for rid in resource_ids), f"Missing: {expected_id}"
    
    def test_extract_resources_from_dict_nested(self):
        """Test resource extraction from nested dictionary"""
        data = {
            "user": {
                "email": "test@example.com",
                "profile": {
                    "user_bk": "user_nested_test"
                }
            },
            "assets": [
                {"asset_bk": "asset_array_1"},
                {"asset_bk": "asset_array_2"}
            ]
        }
        
        resource_ids = set()
        self.middleware._extract_resources_from_dict(data, resource_ids)
        
        # Check nested extraction
        assert any("user.email:test@example.com" in rid for rid in resource_ids)
        assert any("user.profile.user_bk:user_nested_test" in rid for rid in resource_ids)
        assert any("assets[0].asset_bk:asset_array_1" in rid for rid in resource_ids)
        assert any("assets[1].asset_bk:asset_array_2" in rid for rid in resource_ids)
    
    @patch('app.middleware.tenant_resolver.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_resolve_tenant_from_api_key_success(self, mock_connect):
        """Test successful tenant resolution from API key"""
        # Mock database response
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            self.mock_tenant_hk,  # tenant_hk
            "tenant_test_123",    # tenant_bk
            "2024-12-31 23:59:59+00:00",  # expires_at (future)
            True,                 # is_active
            "2024-01-01 00:00:00+00:00"   # created_date
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        api_key = "test_api_key_123"
        tenant_hk = await self.middleware._resolve_tenant_from_api_key(api_key)
        
        assert tenant_hk == self.mock_tenant_hk
        mock_cursor.execute.assert_called_once()
        mock_cursor.close.assert_called_once()
        mock_conn.close.assert_called_once()
    
    @patch('app.middleware.tenant_resolver.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_resolve_tenant_from_api_key_not_found(self, mock_connect):
        """Test tenant resolution failure when API key not found"""
        # Mock database response - no result
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = None
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        api_key = "invalid_api_key"
        
        with pytest.raises(HTTPException) as exc_info:
            await self.middleware._resolve_tenant_from_api_key(api_key)
        
        assert exc_info.value.status_code == 401
        assert "Invalid, expired, or inactive API key" in str(exc_info.value.detail)
    
    @patch('app.middleware.tenant_resolver.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_resolve_tenant_from_api_key_inactive(self, mock_connect):
        """Test tenant resolution failure when API key is inactive"""
        # Mock database response - inactive key
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            self.mock_tenant_hk,
            "tenant_test_123",
            "2024-12-31 23:59:59+00:00",
            False,  # is_active = False
            "2024-01-01 00:00:00+00:00"
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        api_key = "inactive_api_key"
        
        with pytest.raises(HTTPException) as exc_info:
            await self.middleware._resolve_tenant_from_api_key(api_key)
        
        assert exc_info.value.status_code == 401
        assert "API key is deactivated" in str(exc_info.value.detail)
    
    @patch('app.middleware.tenant_resolver.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_resolve_user_from_session_success(self, mock_connect):
        """Test successful user resolution from session token"""
        # Mock database response
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            self.mock_user_hk,      # user_hk
            "user_test_123",        # user_bk
            "ACTIVE",               # session_status
            "2024-12-31 23:59:59+00:00",  # expires_at
            "2024-07-05 10:00:00+00:00"   # last_activity
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        session_token = "sess_test_123"
        user_hk = await self.middleware._resolve_user_from_session(session_token, self.mock_tenant_hk)
        
        assert user_hk == self.mock_user_hk
        mock_cursor.execute.assert_called_once()
        mock_cursor.close.assert_called_once()
        mock_conn.close.assert_called_once()
    
    @patch('app.middleware.tenant_resolver.psycopg2.connect')
    @pytest.mark.asyncio
    async def test_resolve_user_from_session_cross_tenant_blocked(self, mock_connect):
        """Test user resolution blocks cross-tenant session access"""
        # Mock database response - no result (session doesn't belong to tenant)
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = None
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        session_token = "sess_cross_tenant_attack"
        
        with pytest.raises(HTTPException) as exc_info:
            await self.middleware._resolve_user_from_session(session_token, self.mock_tenant_hk)
        
        assert exc_info.value.status_code == 401
        assert "does not belong to authenticated tenant" in str(exc_info.value.detail)
    
    @patch('app.services.resource_validator.ResourceValidationService')
    @pytest.mark.asyncio
    async def test_validate_all_resources_against_tenant_success(self, mock_validator_class):
        """Test successful resource validation against tenant"""
        # Mock validator instance
        mock_validator = Mock()
        mock_validator_class.return_value = mock_validator
        
        # Mock validation methods to return True
        async def mock_verify_user(user_bk, tenant_hk):
            return True
        async def mock_verify_asset(asset_bk, tenant_hk):
            return True
        
        mock_validator.verify_user_belongs_to_tenant = mock_verify_user
        mock_validator.verify_asset_belongs_to_tenant = mock_verify_asset
        
        # Resource IDs to validate
        resource_ids = {
            "user_bk:user_test_123",
            "asset_bk:asset_test_456",
            "page_url:https://example.com"  # Should be skipped
        }
        
        # Should not raise exception
        await self.middleware._validate_all_resources_against_tenant(resource_ids, self.mock_tenant_hk)
    
    @patch('app.services.resource_validator.ResourceValidationService')
    @pytest.mark.asyncio
    async def test_validate_all_resources_cross_tenant_blocked(self, mock_validator_class):
        """Test resource validation blocks cross-tenant access"""
        # Mock validator instance
        mock_validator = Mock()
        mock_validator_class.return_value = mock_validator
        
        # Mock validation to return False (cross-tenant access)
        async def mock_verify_user(user_bk, tenant_hk):
            return False  # Cross-tenant access attempt
        
        mock_validator.verify_user_belongs_to_tenant = mock_verify_user
        
        # Resource IDs to validate
        resource_ids = {"user_bk:cross_tenant_user"}
        
        with pytest.raises(HTTPException) as exc_info:
            await self.middleware._validate_all_resources_against_tenant(resource_ids, self.mock_tenant_hk)
        
        assert exc_info.value.status_code == 403
        assert "not accessible by authenticated tenant" in str(exc_info.value.detail)
    
    @pytest.mark.asyncio
    async def test_validate_single_resource_unknown_type(self):
        """Test validation of unknown resource types"""
        mock_validator = Mock()
        
        result = await self.middleware._validate_single_resource(
            mock_validator, "unknown_type", "test_value", self.mock_tenant_hk
        )
        
        # Unknown types should default to allowing with warning
        assert result == True
    
    @pytest.mark.asyncio
    async def test_validate_single_resource_exception_handling(self):
        """Test validation handles exceptions securely"""
        mock_validator = Mock()
        
        # Mock validator to raise exception
        async def mock_verify_error(user_bk, tenant_hk):
            raise Exception("Database error")
        
        mock_validator.verify_user_belongs_to_tenant = mock_verify_error
        
        result = await self.middleware._validate_single_resource(
            mock_validator, "user_bk", "test_user", self.mock_tenant_hk
        )
        
        # Should fail secure (return False)
        assert result == False
    
    def test_add_security_headers(self):
        """Test security headers are added to response"""
        mock_response = Mock()
        mock_response.headers = {}
        
        self.middleware._add_security_headers(mock_response, self.mock_tenant_hk)
        
        assert mock_response.headers["X-Tenant-Validated"] == "true"
        assert mock_response.headers["X-Zero-Trust-Status"] == "validated"
        assert "X-Validation-Timestamp" in mock_response.headers
    
    @pytest.mark.asyncio
    async def test_log_successful_validation(self):
        """Test successful validation logging"""
        mock_request = Mock()
        mock_request.method = "POST"
        mock_request.url.path = "/api/test"
        mock_request.client.host = "127.0.0.1"
        mock_request.headers = {"user-agent": "test-client"}
        
        # Should not raise exception
        await self.middleware._log_successful_validation(mock_request, self.mock_tenant_hk, self.mock_user_hk)
    
    @pytest.mark.asyncio
    async def test_log_security_violation(self):
        """Test security violation logging"""
        mock_request = Mock()
        mock_request.method = "POST"
        mock_request.url.path = "/api/test"
        mock_request.headers = {"user-agent": "malicious-client"}
        mock_request.client.host = "192.168.1.100"
        
        violation_details = "Cross-tenant access attempt detected"
        
        # Should not raise exception
        await self.middleware._log_security_violation(mock_request, violation_details)


# Integration tests
class TestTenantResolverIntegration:
    """Integration tests for TenantResolverMiddleware"""
    
    @pytest.mark.asyncio
    async def test_full_middleware_flow_success(self):
        """Test complete middleware flow with successful validation"""
        # This would require a test FastAPI app and database
        # Implementation depends on test infrastructure setup
        pass
    
    @pytest.mark.asyncio
    async def test_full_middleware_flow_blocked(self):
        """Test complete middleware flow with blocked access"""
        # This would test the complete flow from API key to resource validation
        # Implementation depends on test infrastructure setup
        pass


if __name__ == "__main__":
    pytest.main([__file__]) 