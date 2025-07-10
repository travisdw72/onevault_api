"""
Phase 1 Error Translation Service
Converts technical errors into user-friendly messages
Maintains security by hiding technical details
"""

import logging
import json
from typing import Dict, Any, Optional, Union, List
from dataclasses import dataclass
from datetime import datetime
from enum import Enum

from config import get_config

logger = logging.getLogger(__name__)

class ErrorSeverity(Enum):
    """Error severity levels"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class ErrorCategory(Enum):
    """Error categories for better handling"""
    AUTHENTICATION = "authentication"
    AUTHORIZATION = "authorization"
    VALIDATION = "validation"
    SYSTEM = "system"
    NETWORK = "network"
    DATABASE = "database"
    TIMEOUT = "timeout"
    RATE_LIMIT = "rate_limit"

@dataclass
class TranslatedError:
    """Translated error message with metadata"""
    user_message: str
    helpful_action: str
    error_code: str
    severity: ErrorSeverity
    category: ErrorCategory
    log_message: str
    technical_details: Optional[str] = None
    timestamp: str = ""
    correlation_id: Optional[str] = None
    
    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = datetime.now().isoformat()

class ErrorTranslationService:
    """Service for translating technical errors into user-friendly messages"""
    
    def __init__(self):
        self.config = get_config()
        self.translations = self._load_translations()
        self.enabled = self.config.error_translation.enabled
        self.hide_technical_details = self.config.error_translation.technical_details_hidden
        
        # Error pattern matchers
        self.error_patterns = self._build_error_patterns()
        
        logger.info(f"🔄 Error translation service initialized: enabled={self.enabled}")
    
    def _load_translations(self) -> Dict[str, Dict[str, str]]:
        """Load error translations from configuration"""
        base_translations = {
            'cross_tenant_access_denied': {
                'user_message': 'Resource not found',
                'helpful_action': 'Try searching for what you\'re looking for',
                'log_message': 'Cross-tenant access attempt blocked',
                'error_code': 'ACCESS_DENIED_001',
                'severity': 'medium',
                'category': 'authorization'
            },
            'production_token_expired': {
                'user_message': 'Please log in again',
                'helpful_action': 'Click here to refresh your session',
                'log_message': 'Token expiry handled gracefully',
                'error_code': 'AUTH_EXPIRED_001',
                'severity': 'low',
                'category': 'authentication'
            },
            'insufficient_permissions': {
                'user_message': 'Access not available for your account',
                'helpful_action': 'Contact your administrator if you need access',
                'log_message': 'Permission-based access control enforced',
                'error_code': 'PERM_DENIED_001',
                'severity': 'medium',
                'category': 'authorization'
            },
            'validation_timeout': {
                'user_message': 'Service temporarily unavailable',
                'helpful_action': 'Please try again in a moment',
                'log_message': 'Enhanced validation timeout - fallback used',
                'error_code': 'TIMEOUT_001',
                'severity': 'high',
                'category': 'timeout'
            },
            'database_connection_error': {
                'user_message': 'Service temporarily unavailable',
                'helpful_action': 'Please try again in a few minutes',
                'log_message': 'Database connection failed',
                'error_code': 'DB_CONN_001',
                'severity': 'critical',
                'category': 'database'
            },
            'invalid_token_format': {
                'user_message': 'Please log in again',
                'helpful_action': 'Your session may have been corrupted',
                'log_message': 'Invalid token format detected',
                'error_code': 'AUTH_FORMAT_001',
                'severity': 'medium',
                'category': 'authentication'
            },
            'rate_limit_exceeded': {
                'user_message': 'Too many requests',
                'helpful_action': 'Please wait a moment before trying again',
                'log_message': 'Rate limit exceeded for user',
                'error_code': 'RATE_LIMIT_001',
                'severity': 'medium',
                'category': 'rate_limit'
            },
            'system_overload': {
                'user_message': 'System is busy',
                'helpful_action': 'Please try again in a few minutes',
                'log_message': 'System overload detected',
                'error_code': 'SYS_OVERLOAD_001',
                'severity': 'high',
                'category': 'system'
            }
        }
        
        # Merge with config translations
        config_translations = self.config.error_translation.translations
        for key, translation in config_translations.items():
            if key in base_translations:
                base_translations[key].update(translation)
            else:
                base_translations[key] = translation
        
        return base_translations
    
    def _build_error_patterns(self) -> Dict[str, str]:
        """Build error pattern matchers for automatic detection"""
        return {
            # Database patterns
            r'psycopg2\.OperationalError.*connection.*refused': 'database_connection_error',
            r'psycopg2\.OperationalError.*timeout': 'validation_timeout',
            r'role.*does not exist': 'database_connection_error',
            
            # Authentication patterns
            r'Token.*expired': 'production_token_expired',
            r'Invalid.*token': 'invalid_token_format',
            r'Authentication.*failed': 'invalid_token_format',
            r'No.*password.*supplied': 'invalid_token_format',
            
            # Authorization patterns
            r'Access.*denied': 'insufficient_permissions',
            r'Permission.*denied': 'insufficient_permissions',
            r'Cross.*tenant.*access': 'cross_tenant_access_denied',
            r'Tenant.*isolation.*violation': 'cross_tenant_access_denied',
            
            # System patterns
            r'TimeoutError': 'validation_timeout',
            r'Connection.*timeout': 'validation_timeout',
            r'Rate.*limit': 'rate_limit_exceeded',
            r'Too.*many.*requests': 'rate_limit_exceeded',
            r'System.*overload': 'system_overload',
            r'Memory.*error': 'system_overload',
            
            # Validation patterns
            r'Validation.*failed': 'validation_timeout',
            r'Hash.*key.*missing': 'invalid_token_format',
            r'Business.*key.*invalid': 'invalid_token_format'
        }
    
    def _detect_error_type(self, error_message: str, exception_type: str = "") -> Optional[str]:
        """Automatically detect error type from message and exception"""
        import re
        
        # Guard clause: Check if detection is needed
        if not error_message:
            return None
        
        full_error_text = f"{exception_type} {error_message}".lower()
        
        # Check patterns
        for pattern, error_type in self.error_patterns.items():
            if re.search(pattern.lower(), full_error_text):
                logger.debug(f"🔍 Detected error type '{error_type}' from pattern: {pattern}")
                return error_type
        
        # Check for specific keywords
        if any(keyword in full_error_text for keyword in ['tenant', 'cross-tenant']):
            return 'cross_tenant_access_denied'
        
        if any(keyword in full_error_text for keyword in ['token', 'session', 'auth']):
            return 'production_token_expired'
        
        if any(keyword in full_error_text for keyword in ['permission', 'access', 'denied']):
            return 'insufficient_permissions'
        
        if any(keyword in full_error_text for keyword in ['timeout', 'slow', 'unavailable']):
            return 'validation_timeout'
        
        if any(keyword in full_error_text for keyword in ['database', 'connection', 'psycopg']):
            return 'database_connection_error'
        
        return None
    
    def translate_error(self, error: Union[Exception, str, Dict[str, Any]], 
                       error_type: Optional[str] = None,
                       correlation_id: Optional[str] = None,
                       additional_context: Optional[Dict[str, Any]] = None) -> TranslatedError:
        """
        Translate error into user-friendly message
        
        Args:
            error: Exception, error message, or error dict
            error_type: Optional explicit error type
            correlation_id: Optional correlation ID for tracking
            additional_context: Additional context for error handling
        """
        
        # Guard clause: Check if translation is enabled
        if not self.enabled:
            return self._create_fallback_error(error, correlation_id)
        
        # Parse error information
        if isinstance(error, Exception):
            error_message = str(error)
            exception_type = type(error).__name__
        elif isinstance(error, dict):
            error_message = error.get('message', str(error))
            exception_type = error.get('type', 'Unknown')
        else:
            error_message = str(error)
            exception_type = 'String'
        
        # Detect error type if not provided
        if not error_type:
            error_type = self._detect_error_type(error_message, exception_type)
        
        # Get translation or use fallback
        if error_type and error_type in self.translations:
            translation = self.translations[error_type]
        else:
            logger.warning(f"⚠️ No translation found for error type: {error_type}")
            return self._create_generic_error(error_message, correlation_id)
        
        # Build translated error
        try:
            translated_error = TranslatedError(
                user_message=translation.get('user_message', 'An error occurred'),
                helpful_action=translation.get('helpful_action', 'Please try again'),
                error_code=translation.get('error_code', 'UNKNOWN_001'),
                severity=ErrorSeverity(translation.get('severity', 'medium')),
                category=ErrorCategory(translation.get('category', 'system')),
                log_message=translation.get('log_message', f'Error: {error_message}'),
                technical_details=error_message if not self.hide_technical_details else None,
                correlation_id=correlation_id
            )
            
            # Add additional context if provided
            if additional_context:
                translated_error.helpful_action = self._enhance_helpful_action(
                    translated_error.helpful_action, additional_context
                )
            
            # Log the error appropriately
            self._log_translated_error(translated_error, error_message)
            
            return translated_error
            
        except Exception as e:
            logger.error(f"❌ Error during translation: {e}")
            return self._create_fallback_error(error, correlation_id)
    
    def _create_fallback_error(self, error: Any, correlation_id: Optional[str] = None) -> TranslatedError:
        """Create fallback error when translation fails"""
        return TranslatedError(
            user_message="Something went wrong",
            helpful_action="Please try again or contact support",
            error_code="FALLBACK_001",
            severity=ErrorSeverity.MEDIUM,
            category=ErrorCategory.SYSTEM,
            log_message=f"Fallback error: {str(error)}",
            technical_details=str(error) if not self.hide_technical_details else None,
            correlation_id=correlation_id
        )
    
    def _create_generic_error(self, error_message: str, correlation_id: Optional[str] = None) -> TranslatedError:
        """Create generic error for unrecognized errors"""
        return TranslatedError(
            user_message="Service temporarily unavailable",
            helpful_action="Please try again in a moment",
            error_code="GENERIC_001",
            severity=ErrorSeverity.MEDIUM,
            category=ErrorCategory.SYSTEM,
            log_message=f"Generic error: {error_message}",
            technical_details=error_message if not self.hide_technical_details else None,
            correlation_id=correlation_id
        )
    
    def _enhance_helpful_action(self, base_action: str, context: Dict[str, Any]) -> str:
        """Enhance helpful action with contextual information"""
        
        # Add refresh link for authentication errors
        if context.get('add_refresh_link') and 'log in' in base_action.lower():
            return f"{base_action} [Refresh Session](/auth/refresh)"
        
        # Add contact info for permission errors
        if context.get('support_contact') and 'administrator' in base_action.lower():
            return f"{base_action} ({context['support_contact']})"
        
        # Add retry timing for timeout errors
        if context.get('retry_after_seconds') and 'try again' in base_action.lower():
            return f"{base_action} (retry in {context['retry_after_seconds']} seconds)"
        
        return base_action
    
    def _log_translated_error(self, translated_error: TranslatedError, original_message: str):
        """Log translated error with appropriate level"""
        log_message = (
            f"[{translated_error.error_code}] {translated_error.log_message} "
            f"(correlation_id: {translated_error.correlation_id})"
        )
        
        if translated_error.severity == ErrorSeverity.CRITICAL:
            logger.error(log_message)
        elif translated_error.severity == ErrorSeverity.HIGH:
            logger.warning(log_message)
        elif translated_error.severity == ErrorSeverity.MEDIUM:
            logger.info(log_message)
        else:
            logger.debug(log_message)
        
        # Log technical details separately if hidden from user
        if self.hide_technical_details and original_message:
            logger.debug(f"Technical details for {translated_error.error_code}: {original_message}")
    
    def translate_validation_response(self, response: Dict[str, Any], 
                                    correlation_id: Optional[str] = None) -> Dict[str, Any]:
        """Translate validation response errors into user-friendly format"""
        
        # Guard clause: Check if response contains error
        if response.get('p_success', True):
            return response
        
        error_message = response.get('p_message', 'Unknown error')
        
        # Detect error type from response
        error_type = None
        if 'cross-tenant' in error_message.lower():
            error_type = 'cross_tenant_access_denied'
        elif 'expired' in error_message.lower():
            error_type = 'production_token_expired'
        elif 'permission' in error_message.lower():
            error_type = 'insufficient_permissions'
        elif 'timeout' in error_message.lower():
            error_type = 'validation_timeout'
        
        # Translate the error
        translated = self.translate_error(error_message, error_type, correlation_id)
        
        # Create user-friendly response
        user_response = {
            'success': False,
            'message': translated.user_message,
            'helpful_action': translated.helpful_action,
            'error_code': translated.error_code,
            'timestamp': translated.timestamp
        }
        
        # Add correlation ID if provided
        if correlation_id:
            user_response['correlation_id'] = correlation_id
        
        # Add technical details in development
        if not self.hide_technical_details:
            user_response['technical_details'] = translated.technical_details
        
        return user_response
    
    def get_error_statistics(self) -> Dict[str, Any]:
        """Get error translation statistics"""
        return {
            'enabled': self.enabled,
            'hide_technical_details': self.hide_technical_details,
            'available_translations': len(self.translations),
            'error_categories': [category.value for category in ErrorCategory],
            'severity_levels': [severity.value for severity in ErrorSeverity],
            'translation_coverage': list(self.translations.keys())
        }
    
    def add_custom_translation(self, error_type: str, translation: Dict[str, str]) -> bool:
        """Add custom error translation"""
        try:
            # Validate required fields
            required_fields = ['user_message', 'helpful_action', 'log_message']
            for field in required_fields:
                if field not in translation:
                    raise ValueError(f"Missing required field: {field}")
            
            # Add defaults
            translation.setdefault('error_code', f'CUSTOM_{len(self.translations)+1:03d}')
            translation.setdefault('severity', 'medium')
            translation.setdefault('category', 'system')
            
            self.translations[error_type] = translation
            logger.info(f"✅ Added custom translation for: {error_type}")
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to add custom translation: {e}")
            return False

# Global error translation service instance
_error_service_instance: Optional[ErrorTranslationService] = None

def get_error_service() -> ErrorTranslationService:
    """Get global error translation service instance (singleton pattern)"""
    global _error_service_instance
    
    if _error_service_instance is None:
        _error_service_instance = ErrorTranslationService()
    
    return _error_service_instance

def translate_error(error: Union[Exception, str, Dict[str, Any]], 
                   error_type: Optional[str] = None,
                   correlation_id: Optional[str] = None) -> TranslatedError:
    """Convenience function for error translation"""
    return get_error_service().translate_error(error, error_type, correlation_id)

def translate_validation_response(response: Dict[str, Any], 
                                correlation_id: Optional[str] = None) -> Dict[str, Any]:
    """Convenience function for validation response translation"""
    return get_error_service().translate_validation_response(response, correlation_id) 