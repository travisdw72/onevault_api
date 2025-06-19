"""
Production Readiness Assessment Configuration
Single source of truth for all PRA SQL scripts and configurations.

This module provides centralized configuration management for the Production
Readiness Assessment suite, integrating with the OneVault Data Vault 2.0
multi-tenant architecture and compliance frameworks.
"""

import os
import json
from pathlib import Path
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field
from datetime import datetime, timedelta
import hashlib

# =====================================================================================
# CORE CONFIGURATION CLASSES
# =====================================================================================

@dataclass
class SQLScriptConfig:
    """Configuration for individual SQL scripts."""
    script_name: str
    file_path: str
    description: str
    version: str
    dependencies: List[str] = field(default_factory=list)
    schemas_created: List[str] = field(default_factory=list)
    tables_created: List[str] = field(default_factory=list)
    functions_created: List[str] = field(default_factory=list)
    views_created: List[str] = field(default_factory=list)
    indexes_created: List[str] = field(default_factory=list)
    execution_order: int = 0
    estimated_duration_minutes: int = 5
    compliance_frameworks: List[str] = field(default_factory=list)
    tenant_isolation_required: bool = True
    backup_required_before: bool = True

@dataclass
class ComplianceFrameworkConfig:
    """Configuration for compliance frameworks."""
    framework_name: str
    enabled: bool
    required_schemas: List[str]
    audit_retention_years: int
    encryption_required: bool
    real_time_monitoring: bool
    automated_reporting: bool
    notification_channels: List[str] = field(default_factory=list)

@dataclass
class MonitoringConfig:
    """Configuration for monitoring and alerting."""
    metric_collection_interval_seconds: int = 300
    alert_evaluation_frequency_minutes: int = 5
    data_retention_days: int = 365
    notification_channels: List[str] = field(default_factory=list)
    escalation_enabled: bool = True
    auto_remediation_enabled: bool = False

@dataclass
class PerformanceConfig:
    """Configuration for performance optimization."""
    query_analysis_enabled: bool = True
    index_optimization_enabled: bool = True
    connection_pool_optimization: bool = True
    cache_optimization_enabled: bool = True
    automated_maintenance_enabled: bool = True
    performance_baseline_retention_days: int = 90

# =====================================================================================
# PRODUCTION READINESS ASSESSMENT CONFIGURATION
# =====================================================================================

class PRAConfig:
    """Central configuration for Production Readiness Assessment."""
    
    def __init__(self, environment: str = 'development', tenant_id: Optional[str] = None):
        self.environment = environment
        self.tenant_id = tenant_id
        self.base_path = Path(__file__).parent
        self.config_version = "1.0.0"
        self.deployment_timestamp = datetime.now()
        
        # Initialize configurations
        self._init_sql_scripts()
        self._init_compliance_frameworks()
        self._init_monitoring_config()
        self._init_performance_config()
        self._init_database_config()
        self._init_security_config()
    
    def _init_sql_scripts(self):
        """Initialize SQL script configurations in execution order."""
        self.sql_scripts = [
            SQLScriptConfig(
                script_name="backup_recovery_infrastructure",
                file_path="step_1_backup_recovery_infrastructure_corrected.sql",
                description="Backup & Recovery Infrastructure Implementation - Phase 1 (CORRECTED)",
                version="1.1",
                dependencies=[],
                schemas_created=["backup_mgmt"],
                tables_created=[
                    "backup_mgmt.backup_execution_h",
                    "backup_mgmt.backup_execution_s", 
                    "backup_mgmt.recovery_operation_h",
                    "backup_mgmt.recovery_operation_s",
                    "backup_mgmt.backup_schedule_h",
                    "backup_mgmt.backup_schedule_s",
                    "backup_mgmt.backup_dependency_l",
                    "backup_mgmt.schedule_execution_l",
                    "backup_mgmt.recovery_backup_l"
                ],
                execution_order=1,
                estimated_duration_minutes=3,
                compliance_frameworks=["SOX", "HIPAA", "GDPR"],
                backup_required_before=False
            ),
            SQLScriptConfig(
                script_name="backup_procedures",
                file_path="step_2_backup_procedures.sql",
                description="Backup & Recovery Procedures and Functions - Phase 1 Continued",
                version="1.0",
                dependencies=["backup_recovery_infrastructure"],
                functions_created=[
                    "backup_mgmt.create_full_backup",
                    "backup_mgmt.create_incremental_backup",
                    "backup_mgmt.initiate_point_in_time_recovery",
                    "backup_mgmt.create_backup_schedule",
                    "backup_mgmt.get_next_scheduled_backups",
                    "backup_mgmt.verify_backup_integrity",
                    "backup_mgmt.cleanup_expired_backups"
                ],
                execution_order=2,
                estimated_duration_minutes=5,
                compliance_frameworks=["SOX", "HIPAA", "GDPR"]
            ),
            SQLScriptConfig(
                script_name="monitoring_infrastructure",
                file_path="step_3_monitoring_infrastructure.sql",
                description="Monitoring & Alerting Infrastructure Implementation - Phase 2 Part 1",
                version="1.0",
                dependencies=["backup_procedures"],
                schemas_created=["monitoring"],
                execution_order=3,
                estimated_duration_minutes=4,
                compliance_frameworks=["SOC2", "ISO27001"]
            ),
            SQLScriptConfig(
                script_name="alerting_system",
                file_path="step_4_alerting_system.sql",
                description="Monitoring & Alerting Infrastructure Implementation - Phase 2 Part 2",
                version="1.0",
                dependencies=["monitoring_infrastructure"],
                execution_order=4,
                estimated_duration_minutes=6,
                compliance_frameworks=["SOC2", "ISO27001", "NIST"]
            ),
            SQLScriptConfig(
                script_name="performance_optimization",
                file_path="step_5_performance_optimization.sql",
                description="Performance Optimization Infrastructure Implementation - Phase 3 Part 1",
                version="1.0",
                dependencies=["alerting_system"],
                schemas_created=["performance"],
                execution_order=5,
                estimated_duration_minutes=7,
                compliance_frameworks=["SOC2"]
            ),
            SQLScriptConfig(
                script_name="automated_maintenance",
                file_path="step_6_automated_maintenance.sql",
                description="Automated Maintenance Infrastructure Implementation",
                version="1.0",
                dependencies=["performance_optimization"],
                schemas_created=["maintenance"],
                execution_order=6,
                estimated_duration_minutes=8,
                compliance_frameworks=["SOC2", "ISO27001"]
            ),
            SQLScriptConfig(
                script_name="lock_monitoring",
                file_path="step_7_lock_monitoring.sql",
                description="Lock Monitoring Infrastructure Implementation",
                version="1.0",
                dependencies=["automated_maintenance"],
                schemas_created=["lock_monitoring"],
                execution_order=7,
                estimated_duration_minutes=4,
                compliance_frameworks=["SOC2"]
            ),
            SQLScriptConfig(
                script_name="blocking_detection",
                file_path="step_8_blocking_detection.sql",
                description="Blocking Detection Functions Implementation",
                version="1.0",
                dependencies=["lock_monitoring"],
                execution_order=8,
                estimated_duration_minutes=3,
                compliance_frameworks=["SOC2"]
            ),
            SQLScriptConfig(
                script_name="capacity_planning",
                file_path="step_9_capacity_planning.sql",
                description="Capacity Planning Infrastructure Implementation",
                version="1.0",
                dependencies=["blocking_detection"],
                schemas_created=["capacity_planning"],
                execution_order=9,
                estimated_duration_minutes=6,
                compliance_frameworks=["SOC2", "ISO27001"]
            ),
            SQLScriptConfig(
                script_name="growth_forecasting",
                file_path="step_10_growth_forecasting.sql",
                description="Growth Forecasting Functions Implementation",
                version="1.0",
                dependencies=["capacity_planning"],
                execution_order=10,
                estimated_duration_minutes=4,
                compliance_frameworks=["SOC2"]
            ),
            SQLScriptConfig(
                script_name="security_hardening",
                file_path="step_11_security_hardening.sql",
                description="Security Hardening Infrastructure Implementation",
                version="1.0",
                dependencies=["growth_forecasting"],
                schemas_created=["security_hardening"],
                execution_order=11,
                estimated_duration_minutes=5,
                compliance_frameworks=["ISO27001", "NIST", "SOC2"]
            ),
            SQLScriptConfig(
                script_name="compliance_automation",
                file_path="step_12_compliance_automation.sql",
                description="Compliance Automation Infrastructure Implementation",
                version="1.0",
                dependencies=["security_hardening"],
                schemas_created=["compliance_automation"],
                execution_order=12,
                estimated_duration_minutes=7,
                compliance_frameworks=["HIPAA", "GDPR", "SOX", "SOC2"]
            ),
            SQLScriptConfig(
                script_name="sox_compliance_automation",
                file_path="step_13_sox_compliance_automation_fixed.sql",
                description="SOX Compliance Automation Implementation (FIXED)",
                version="1.1",
                dependencies=["compliance_automation"],
                schemas_created=["compliance"],
                execution_order=13,
                estimated_duration_minutes=8,
                compliance_frameworks=["SOX"]
            ),
            SQLScriptConfig(
                script_name="gdpr_compliance_rights",
                file_path="step_14_gdpr_compliance_rights_fixed.sql",
                description="GDPR Compliance Rights Implementation (FIXED)",
                version="1.1",
                dependencies=["sox_compliance_automation"],
                execution_order=14,
                estimated_duration_minutes=6,
                compliance_frameworks=["GDPR"]
            ),
            SQLScriptConfig(
                script_name="unified_compliance_deployment",
                file_path="step_15_unified_compliance_deployment.sql",
                description="Unified Compliance Deployment Implementation",
                version="1.0",
                dependencies=["gdpr_compliance_rights"],
                execution_order=15,
                estimated_duration_minutes=5,
                compliance_frameworks=["SOX", "GDPR", "HIPAA"]
            ),
            SQLScriptConfig(
                script_name="api_data_vault_flow_retrofit",
                file_path="step_16_api_data_vault_flow_retrofit.sql",
                description="API Data Vault Flow Retrofit Implementation",
                version="1.0",
                dependencies=["unified_compliance_deployment"],
                execution_order=16,
                estimated_duration_minutes=4,
                compliance_frameworks=["HIPAA", "GDPR"]
            )
        ]
    
    def _init_compliance_frameworks(self):
        """Initialize compliance framework configurations."""
        self.compliance_frameworks = {
            "HIPAA": ComplianceFrameworkConfig(
                framework_name="HIPAA",
                enabled=True,
                required_schemas=["audit", "compliance", "security_hardening"],
                audit_retention_years=7,
                encryption_required=True,
                real_time_monitoring=True,
                automated_reporting=True,
                notification_channels=["EMAIL", "SLACK"]
            ),
            "GDPR": ComplianceFrameworkConfig(
                framework_name="GDPR",
                enabled=True,
                required_schemas=["compliance", "audit"],
                audit_retention_years=7,
                encryption_required=True,
                real_time_monitoring=True,
                automated_reporting=True,
                notification_channels=["EMAIL", "SLACK"]
            ),
            "SOX": ComplianceFrameworkConfig(
                framework_name="SOX",
                enabled=True,
                required_schemas=["compliance", "audit", "backup_mgmt"],
                audit_retention_years=7,
                encryption_required=True,
                real_time_monitoring=True,
                automated_reporting=True,
                notification_channels=["EMAIL", "SLACK", "WEBHOOK"]
            ),
            "SOC2": ComplianceFrameworkConfig(
                framework_name="SOC2",
                enabled=True,
                required_schemas=["monitoring", "performance", "security_hardening"],
                audit_retention_years=3,
                encryption_required=True,
                real_time_monitoring=True,
                automated_reporting=True,
                notification_channels=["EMAIL", "SLACK"]
            )
        }
    
    def _init_monitoring_config(self):
        """Initialize monitoring configuration."""
        self.monitoring = MonitoringConfig(
            metric_collection_interval_seconds=300,
            alert_evaluation_frequency_minutes=5,
            data_retention_days=365,
            notification_channels=["EMAIL", "SLACK", "WEBHOOK"],
            escalation_enabled=True,
            auto_remediation_enabled=False
        )
    
    def _init_performance_config(self):
        """Initialize performance optimization configuration."""
        self.performance = PerformanceConfig(
            query_analysis_enabled=True,
            index_optimization_enabled=True,
            connection_pool_optimization=True,
            cache_optimization_enabled=True,
            automated_maintenance_enabled=True,
            performance_baseline_retention_days=90
        )
    
    def _init_database_config(self):
        """Initialize database-specific configuration."""
        self.database_config = {
            "backup_retention_years": 7,
            "backup_compression_enabled": True,
            "backup_verification_required": True,
            "point_in_time_recovery_enabled": True,
            "automated_backup_schedule": {
                "full_backup_frequency": "weekly",
                "incremental_backup_frequency": "daily",
                "backup_window_start": "02:00",
                "backup_window_end": "04:00",
                "timezone": "UTC"
            },
            "performance_thresholds": {
                "max_query_execution_time_ms": 5000,
                "max_connection_utilization_pct": 85,
                "min_cache_hit_ratio_pct": 95,
                "max_lock_wait_time_seconds": 30
            },
            "maintenance_windows": {
                "preferred_day": "sunday",
                "start_time": "02:00",
                "duration_hours": 4,
                "timezone": "UTC"
            }
        }
    
    def _init_security_config(self):
        """Initialize security configuration."""
        self.security_config = {
            "encryption": {
                "data_at_rest": True,
                "data_in_transit": True,
                "algorithm": "AES-256-GCM",
                "key_rotation_days": 90
            },
            "access_control": {
                "role_based_access": True,
                "tenant_isolation_required": True,
                "audit_all_access": True,
                "failed_login_threshold": 5
            },
            "threat_detection": {
                "enabled": True,
                "real_time_monitoring": True,
                "anomaly_detection": True,
                "automated_blocking": False
            }
        }
    
    # =====================================================================================
    # CONFIGURATION ACCESS METHODS
    # =====================================================================================
    
    def get_script_by_name(self, script_name: str) -> Optional[SQLScriptConfig]:
        """Get SQL script configuration by name."""
        for script in self.sql_scripts:
            if script.script_name == script_name:
                return script
        return None
    
    def get_scripts_by_compliance_framework(self, framework: str) -> List[SQLScriptConfig]:
        """Get all scripts related to a compliance framework."""
        return [
            script for script in self.sql_scripts
            if framework in script.compliance_frameworks
        ]
    
    def get_execution_order(self) -> List[SQLScriptConfig]:
        """Get scripts in execution order."""
        return sorted(self.sql_scripts, key=lambda x: x.execution_order)
    
    def get_total_estimated_duration(self) -> int:
        """Get total estimated execution time in minutes."""
        return sum(script.estimated_duration_minutes for script in self.sql_scripts)
    
    def get_schemas_created(self) -> List[str]:
        """Get all schemas that will be created."""
        schemas = set()
        for script in self.sql_scripts:
            schemas.update(script.schemas_created)
        return sorted(list(schemas))
    
    def validate_dependencies(self) -> Dict[str, List[str]]:
        """Validate that all script dependencies are satisfied."""
        validation_results = {}
        script_names = {script.script_name for script in self.sql_scripts}
        
        for script in self.sql_scripts:
            missing_deps = []
            for dep in script.dependencies:
                if dep not in script_names:
                    missing_deps.append(dep)
            if missing_deps:
                validation_results[script.script_name] = missing_deps
        
        return validation_results
    
    def get_compliance_summary(self) -> Dict[str, Any]:
        """Get compliance framework implementation summary."""
        summary = {}
        for framework_name, framework_config in self.compliance_frameworks.items():
            implementing_scripts = self.get_scripts_by_compliance_framework(framework_name)
            summary[framework_name] = {
                "enabled": framework_config.enabled,
                "implementing_scripts": len(implementing_scripts),
                "script_names": [script.script_name for script in implementing_scripts],
                "audit_retention_years": framework_config.audit_retention_years,
                "encryption_required": framework_config.encryption_required,
                "real_time_monitoring": framework_config.real_time_monitoring
            }
        return summary
    
    def generate_deployment_plan(self) -> Dict[str, Any]:
        """Generate comprehensive deployment plan."""
        dependency_validation = self.validate_dependencies()
        
        deployment_plan = {
            "plan_metadata": {
                "generated_at": datetime.now().isoformat(),
                "config_version": self.config_version,
                "environment": self.environment,
                "tenant_id": self.tenant_id
            },
            "validation_status": {
                "dependencies_valid": len(dependency_validation) == 0,
                "missing_dependencies": dependency_validation,
                "total_scripts": len(self.sql_scripts),
                "estimated_duration_minutes": self.get_total_estimated_duration()
            },
            "execution_phases": {
                "phase_1_infrastructure": [script.script_name for script in self.sql_scripts[0:6]],
                "phase_2_monitoring": [script.script_name for script in self.sql_scripts[6:10]],
                "phase_3_compliance": [script.script_name for script in self.sql_scripts[10:16]]
            },
            "compliance_coverage": self.get_compliance_summary(),
            "resource_requirements": {
                "schemas_created": len(self.get_schemas_created()),
                "estimated_storage_mb": len(self.sql_scripts) * 50,
                "backup_space_required": True,
                "monitoring_overhead_pct": 5
            }
        }
        
        return deployment_plan

# Factory functions
def create_pra_config(environment: str = 'development', tenant_id: Optional[str] = None) -> PRAConfig:
    """Factory function to create PRA configuration."""
    return PRAConfig(environment=environment, tenant_id=tenant_id)

# Default configuration instance
DEFAULT_CONFIG = PRAConfig()
PRA_VERSION = "1.0.0"
SUPPORTED_ENVIRONMENTS = ["development", "staging", "production"]

if __name__ == "__main__":
    config = create_pra_config('development')
    print(f"Total Scripts: {len(config.sql_scripts)}")
    print(f"Estimated Duration: {config.get_total_estimated_duration()} minutes")
    print(f"Schemas to Create: {', '.join(config.get_schemas_created())}") 