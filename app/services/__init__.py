"""
Zero Trust Services Package
===========================

Core services for implementing zero trust security:
- ResourceValidationService: Cross-tenant resource validation
- TokenLifecycleManager: Advanced token management
- AuditPipeline: Comprehensive audit trail
"""

from .resource_validator import ResourceValidationService

__all__ = [
    'ResourceValidationService'
] 