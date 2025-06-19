"""
Production Readiness Assessment Investigation
Comprehensive testing, validation, and investigation module for PRA SQL scripts.

This module provides testing capabilities, database investigation tools, and
validation frameworks for the Production Readiness Assessment suite.
"""

import os
import sys
import json
import time
import logging
import traceback
import psycopg2
import psycopg2.extras
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple, Union
from pathlib import Path
from dataclasses import dataclass, asdict
import hashlib
import subprocess

# Import PRA configuration
from praConfig import (
    PRAConfig, SQLScriptConfig, create_pra_config, 
    get_production_config, get_development_config
)

# =====================================================================================
# INVESTIGATION FRAMEWORK CLASSES
# =====================================================================================

@dataclass
class ExecutionResult:
    """Result of SQL script execution."""
    script_name: str
    success: bool
    execution_time_seconds: float
    rows_affected: Optional[int] = None
    error_message: Optional[str] = None
    error_code: Optional[str] = None
    schemas_created: List[str] = None
    tables_created: List[str] = None
    functions_created: List[str] = None
    views_created: List[str] = None
    warnings: List[str] = None

@dataclass
class ValidationResult:
    """Result of validation check."""
    check_name: str
    status: str  # PASS, FAIL, WARNING, SKIP
    message: str
    details: Optional[Dict[str, Any]] = None
    execution_time_seconds: Optional[float] = None

@dataclass
class InvestigationReport:
    """Comprehensive investigation report."""
    investigation_id: str
    start_time: datetime
    end_time: Optional[datetime]
    environment: str
    tenant_id: Optional[str]
    total_scripts: int
    successful_executions: int
    failed_executions: int
    total_execution_time_seconds: float
    validation_results: List[ValidationResult]
    execution_results: List[ExecutionResult]
    compliance_status: Dict[str, str]
    performance_metrics: Dict[str, Any]
    recommendations: List[str]

# =====================================================================================
# DATABASE CONNECTION AND UTILITIES
# =====================================================================================

class DatabaseConnector:
    """Enhanced database connector for PRA investigations."""
    
    def __init__(self, config: PRAConfig):
        self.config = config
        self.connection = None
        self.logger = self._setup_logging()
    
    def _setup_logging(self) -> logging.Logger:
        """Setup logging for investigation."""
        logger = logging.getLogger(f'pra_investigation_{self.config.environment}')
        logger.setLevel(logging.DEBUG if self.config.environment == 'development' else logging.INFO)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
        
        return logger
    
    def connect(self) -> bool:
        """Establish database connection."""
        try:
            # Get connection parameters from environment
            connection_params = {
                'host': os.getenv('DB_HOST', 'localhost'),
                'port': int(os.getenv('DB_PORT', 5432)),
                'database': os.getenv('DB_NAME', 'one_vault'),
                'user': os.getenv('DB_USER', 'postgres'),
                'password': os.getenv('DB_PASSWORD'),
                'connect_timeout': 30
            }
            
            self.connection = psycopg2.connect(**connection_params)
            self.connection.autocommit = False  # Manual transaction control
            
            self.logger.info(f"✅ Connected to database: {connection_params['database']}")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Database connection failed: {e}")
            return False
    
    def disconnect(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()
            self.connection = None
            self.logger.info("🔌 Database connection closed")
    
    def execute_query(self, query: str, params: Optional[List] = None, fetch: bool = True) -> Tuple[bool, Any, Optional[str]]:
        """Execute SQL query with error handling."""
        if not self.connection:
            return False, None, "No database connection"
        
        try:
            cursor = self.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            start_time = time.time()
            
            cursor.execute(query, params)
            execution_time = time.time() - start_time
            
            if fetch and cursor.description:
                results = cursor.fetchall()
            else:
                results = cursor.rowcount
            
            cursor.close()
            self.logger.debug(f"Query executed in {execution_time:.3f}s")
            
            return True, results, None
            
        except Exception as e:
            self.logger.error(f"Query execution failed: {e}")
            if cursor:
                cursor.close()
            return False, None, str(e)
    
    def execute_script_file(self, script_path: str) -> ExecutionResult:
        """Execute SQL script file and return detailed results."""
        script_name = Path(script_path).stem
        start_time = time.time()
        
        try:
            # Read script content
            with open(script_path, 'r', encoding='utf-8') as f:
                script_content = f.read()
            
            # Begin transaction
            cursor = self.connection.cursor()
            
            # Execute script
            cursor.execute(script_content)
            
            # Commit transaction
            self.connection.commit()
            cursor.close()
            
            execution_time = time.time() - start_time
            
            self.logger.info(f"✅ Script executed successfully: {script_name} ({execution_time:.2f}s)")
            
            return ExecutionResult(
                script_name=script_name,
                success=True,
                execution_time_seconds=execution_time
            )
            
        except Exception as e:
            # Rollback transaction on error
            self.connection.rollback()
            if cursor:
                cursor.close()
            
            execution_time = time.time() - start_time
            error_msg = str(e)
            
            self.logger.error(f"❌ Script execution failed: {script_name} - {error_msg}")
            
            return ExecutionResult(
                script_name=script_name,
                success=False,
                execution_time_seconds=execution_time,
                error_message=error_msg,
                error_code=getattr(e, 'pgcode', None)
            )

# =====================================================================================
# PRA INVESTIGATION ENGINE
# =====================================================================================

class PRAInvestigator:
    """Main investigation engine for Production Readiness Assessment."""
    
    def __init__(self, config: PRAConfig):
        self.config = config
        self.db = DatabaseConnector(config)
        self.logger = self.db.logger
        self.investigation_id = self._generate_investigation_id()
        self.start_time = datetime.now()
        
        # Results tracking
        self.execution_results: List[ExecutionResult] = []
        self.validation_results: List[ValidationResult] = []
        self.performance_metrics: Dict[str, Any] = {}
        
    def _generate_investigation_id(self) -> str:
        """Generate unique investigation ID."""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        hash_input = f"{self.config.environment}_{timestamp}_{self.config.tenant_id}"
        hash_suffix = hashlib.md5(hash_input.encode()).hexdigest()[:8]
        return f"PRA_INV_{timestamp}_{hash_suffix}"
    
    # =====================================================================================
    # CORE INVESTIGATION METHODS
    # =====================================================================================
    
    def run_full_investigation(self) -> InvestigationReport:
        """Run complete PRA investigation suite."""
        self.logger.info(f"🔍 Starting PRA Investigation: {self.investigation_id}")
        self.logger.info(f"Environment: {self.config.environment}")
        
        try:
            # Step 1: Connect to database
            if not self.db.connect():
                raise Exception("Failed to connect to database")
            
            # Step 2: Pre-execution validation
            self._run_pre_execution_validation()
            
            # Step 3: Execute SQL scripts
            self._execute_pra_scripts()
            
            # Step 4: Post-execution validation
            self._run_post_execution_validation()
            
            # Step 5: Performance analysis
            self._analyze_performance()
            
            # Step 6: Compliance verification
            self._verify_compliance()
            
            # Step 7: Generate recommendations
            recommendations = self._generate_recommendations()
            
        except Exception as e:
            self.logger.error(f"Investigation failed: {e}")
            self.validation_results.append(
                ValidationResult(
                    check_name="investigation_execution",
                    status="FAIL",
                    message=f"Investigation failed: {e}"
                )
            )
            recommendations = ["Investigation failed - review logs for details"]
        
        finally:
            self.db.disconnect()
        
        # Generate final report
        end_time = datetime.now()
        total_execution_time = (end_time - self.start_time).total_seconds()
        
        report = InvestigationReport(
            investigation_id=self.investigation_id,
            start_time=self.start_time,
            end_time=end_time,
            environment=self.config.environment,
            tenant_id=self.config.tenant_id,
            total_scripts=len(self.config.sql_scripts),
            successful_executions=sum(1 for r in self.execution_results if r.success),
            failed_executions=sum(1 for r in self.execution_results if not r.success),
            total_execution_time_seconds=total_execution_time,
            validation_results=self.validation_results,
            execution_results=self.execution_results,
            compliance_status=self._get_compliance_status(),
            performance_metrics=self.performance_metrics,
            recommendations=recommendations
        )
        
        self.logger.info(f"✅ Investigation completed: {self.investigation_id}")
        return report
    
    def _run_pre_execution_validation(self):
        """Run validation checks before script execution."""
        self.logger.info("🔍 Running pre-execution validation...")
        
        # Check database version
        self._validate_database_version()
        
        # Check required extensions
        self._validate_extensions()
        
        # Check existing schemas
        self._validate_existing_schemas()
        
        # Check dependencies
        self._validate_script_dependencies()
        
        # Check permissions
        self._validate_permissions()
        
        # Check disk space
        self._validate_disk_space()
    
    def _execute_pra_scripts(self):
        """Execute PRA SQL scripts in order."""
        self.logger.info("🚀 Executing PRA SQL scripts...")
        
        scripts_to_execute = self.config.get_execution_order()
        
        for script_config in scripts_to_execute:
            self.logger.info(f"Executing: {script_config.script_name}")
            
            script_path = self.config.base_path / script_config.file_path
            
            if not script_path.exists():
                result = ExecutionResult(
                    script_name=script_config.script_name,
                    success=False,
                    execution_time_seconds=0,
                    error_message=f"Script file not found: {script_path}"
                )
            else:
                result = self.db.execute_script_file(str(script_path))
            
            self.execution_results.append(result)
            
            # Stop on failure if in production
            if not result.success and self.config.environment == 'production':
                self.logger.error(f"Stopping execution due to failure in production: {script_config.script_name}")
                break
    
    def _run_post_execution_validation(self):
        """Run validation checks after script execution."""
        self.logger.info("🔍 Running post-execution validation...")
        
        # Validate schema creation
        self._validate_schema_creation()
        
        # Validate table creation
        self._validate_table_creation()
        
        # Validate function creation
        self._validate_function_creation()
        
        # Validate indexes
        self._validate_index_creation()
        
        # Test basic functionality
        self._test_basic_functionality()
    
    def _analyze_performance(self):
        """Analyze performance metrics."""
        self.logger.info("📊 Analyzing performance metrics...")
        
        # Database size analysis
        self._analyze_database_size()
        
        # Query performance analysis
        self._analyze_query_performance()
        
        # Connection analysis
        self._analyze_connections()
        
        # Index usage analysis
        self._analyze_index_usage()
    
    def _verify_compliance(self):
        """Verify compliance framework implementation."""
        self.logger.info("📋 Verifying compliance implementation...")
        
        for framework_name, framework_config in self.config.compliance_frameworks.items():
            if framework_config.enabled:
                self._verify_compliance_framework(framework_name, framework_config)
    
    # =====================================================================================
    # VALIDATION METHODS
    # =====================================================================================
    
    def _validate_database_version(self):
        """Validate PostgreSQL version."""
        success, result, error = self.db.execute_query("SELECT version()")
        
        if success and result:
            version_string = result[0]['version']
            self.validation_results.append(
                ValidationResult(
                    check_name="database_version",
                    status="PASS",
                    message=f"Database version: {version_string}",
                    details={"version_string": version_string}
                )
            )
        else:
            self.validation_results.append(
                ValidationResult(
                    check_name="database_version",
                    status="FAIL",
                    message=f"Failed to get database version: {error}"
                )
            )
    
    def _validate_extensions(self):
        """Validate required PostgreSQL extensions."""
        success, result, error = self.db.execute_query(
            "SELECT extname FROM pg_extension WHERE extname = ANY(%s)",
            [['uuid-ossp', 'pg_stat_statements', 'pg_buffercache', 'pgstattuple']]
        )
        
        if success:
            installed_extensions = [row['extname'] for row in result]
            required_extensions = ['uuid-ossp', 'pg_stat_statements', 'pg_buffercache', 'pgstattuple']
            missing_extensions = [ext for ext in required_extensions if ext not in installed_extensions]
            
            if not missing_extensions:
                self.validation_results.append(
                    ValidationResult(
                        check_name="required_extensions",
                        status="PASS",
                        message="All required extensions are installed",
                        details={"installed": installed_extensions}
                    )
                )
            else:
                self.validation_results.append(
                    ValidationResult(
                        check_name="required_extensions",
                        status="WARNING",
                        message=f"Missing extensions: {missing_extensions}",
                        details={"missing": missing_extensions, "installed": installed_extensions}
                    )
                )
    
    def _validate_existing_schemas(self):
        """Validate existing database schemas."""
        success, result, error = self.db.execute_query(
            "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT LIKE 'pg_%' AND schema_name != 'information_schema'"
        )
        
        if success:
            existing_schemas = [row['schema_name'] for row in result]
            self.validation_results.append(
                ValidationResult(
                    check_name="existing_schemas",
                    status="PASS",
                    message=f"Found {len(existing_schemas)} existing schemas",
                    details={"schemas": existing_schemas}
                )
            )
        else:
            self.validation_results.append(
                ValidationResult(
                    check_name="existing_schemas",
                    status="FAIL",
                    message=f"Failed to query existing schemas: {error}"
                )
            )
    
    def _validate_script_dependencies(self):
        """Validate script dependencies."""
        dependency_issues = self.config.validate_dependencies()
        
        if not dependency_issues:
            self.validation_results.append(
                ValidationResult(
                    check_name="script_dependencies",
                    status="PASS",
                    message="All script dependencies are satisfied"
                )
            )
        else:
            self.validation_results.append(
                ValidationResult(
                    check_name="script_dependencies",
                    status="FAIL",
                    message="Missing script dependencies found",
                    details={"missing_dependencies": dependency_issues}
                )
            )
    
    def _validate_permissions(self):
        """Validate database permissions."""
        # Check if current user can create schemas
        success, result, error = self.db.execute_query(
            "SELECT has_database_privilege(current_user, current_database(), 'CREATE')"
        )
        
        if success and result[0]['has_database_privilege']:
            self.validation_results.append(
                ValidationResult(
                    check_name="create_permissions",
                    status="PASS",
                    message="User has CREATE permissions on database"
                )
            )
        else:
            self.validation_results.append(
                ValidationResult(
                    check_name="create_permissions",
                    status="FAIL",
                    message="User lacks CREATE permissions on database"
                )
            )
    
    def _validate_disk_space(self):
        """Validate available disk space."""
        success, result, error = self.db.execute_query(
            "SELECT pg_database_size(current_database()) as db_size"
        )
        
        if success:
            db_size_bytes = result[0]['db_size']
            db_size_mb = db_size_bytes / (1024 * 1024)
            
            # Estimate space needed (rough calculation)
            estimated_space_needed_mb = len(self.config.sql_scripts) * 50
            
            if db_size_mb > estimated_space_needed_mb * 10:  # 10x buffer
                status = "PASS"
                message = f"Sufficient disk space available (DB: {db_size_mb:.1f}MB)"
            else:
                status = "WARNING"
                message = f"Limited disk space (DB: {db_size_mb:.1f}MB, Estimated need: {estimated_space_needed_mb}MB)"
            
            self.validation_results.append(
                ValidationResult(
                    check_name="disk_space",
                    status=status,
                    message=message,
                    details={"current_db_size_mb": db_size_mb, "estimated_need_mb": estimated_space_needed_mb}
                )
            )
    
    def _validate_schema_creation(self):
        """Validate that required schemas were created."""
        expected_schemas = self.config.get_schemas_created()
        
        success, result, error = self.db.execute_query(
            "SELECT schema_name FROM information_schema.schemata WHERE schema_name = ANY(%s)",
            [expected_schemas]
        )
        
        if success:
            created_schemas = [row['schema_name'] for row in result]
            missing_schemas = [schema for schema in expected_schemas if schema not in created_schemas]
            
            if not missing_schemas:
                self.validation_results.append(
                    ValidationResult(
                        check_name="schema_creation",
                        status="PASS",
                        message=f"All {len(expected_schemas)} schemas created successfully",
                        details={"created_schemas": created_schemas}
                    )
                )
            else:
                self.validation_results.append(
                    ValidationResult(
                        check_name="schema_creation",
                        status="FAIL",
                        message=f"Missing schemas: {missing_schemas}",
                        details={"missing": missing_schemas, "created": created_schemas}
                    )
                )
    
    def _validate_table_creation(self):
        """Validate table creation."""
        # Count tables in PRA schemas
        pra_schemas = self.config.get_schemas_created()
        
        success, result, error = self.db.execute_query(
            """
            SELECT schemaname, COUNT(*) as table_count 
            FROM pg_tables 
            WHERE schemaname = ANY(%s) 
            GROUP BY schemaname
            """,
            [pra_schemas]
        )
        
        if success:
            table_counts = {row['schemaname']: row['table_count'] for row in result}
            total_tables = sum(table_counts.values())
            
            self.validation_results.append(
                ValidationResult(
                    check_name="table_creation",
                    status="PASS",
                    message=f"Created {total_tables} tables across {len(table_counts)} schemas",
                    details={"table_counts_by_schema": table_counts}
                )
            )
    
    def _validate_function_creation(self):
        """Validate function creation."""
        pra_schemas = self.config.get_schemas_created()
        
        success, result, error = self.db.execute_query(
            """
            SELECT n.nspname as schema_name, COUNT(*) as function_count
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = ANY(%s)
            GROUP BY n.nspname
            """,
            [pra_schemas]
        )
        
        if success:
            function_counts = {row['schema_name']: row['function_count'] for row in result}
            total_functions = sum(function_counts.values())
            
            self.validation_results.append(
                ValidationResult(
                    check_name="function_creation",
                    status="PASS",
                    message=f"Created {total_functions} functions across {len(function_counts)} schemas",
                    details={"function_counts_by_schema": function_counts}
                )
            )
    
    def _validate_index_creation(self):
        """Validate index creation."""
        pra_schemas = self.config.get_schemas_created()
        
        success, result, error = self.db.execute_query(
            """
            SELECT schemaname, COUNT(*) as index_count
            FROM pg_indexes
            WHERE schemaname = ANY(%s)
            GROUP BY schemaname
            """,
            [pra_schemas]
        )
        
        if success:
            index_counts = {row['schemaname']: row['index_count'] for row in result}
            total_indexes = sum(index_counts.values())
            
            self.validation_results.append(
                ValidationResult(
                    check_name="index_creation",
                    status="PASS",
                    message=f"Created {total_indexes} indexes across {len(index_counts)} schemas",
                    details={"index_counts_by_schema": index_counts}
                )
            )
    
    def _test_basic_functionality(self):
        """Test basic functionality of created components."""
        test_queries = [
            ("backup_mgmt_test", "SELECT COUNT(*) FROM backup_mgmt.backup_execution_h LIMIT 1"),
            ("monitoring_test", "SELECT COUNT(*) FROM monitoring.system_health_metric_h LIMIT 1"),
            ("performance_test", "SELECT COUNT(*) FROM performance.query_performance_h LIMIT 1"),
            ("compliance_test", "SELECT COUNT(*) FROM compliance.sox_control_h LIMIT 1")
        ]
        
        successful_tests = 0
        for test_name, query in test_queries:
            success, result, error = self.db.execute_query(query)
            if success:
                successful_tests += 1
            else:
                self.logger.debug(f"Basic test failed: {test_name} - {error}")
        
        if successful_tests == len(test_queries):
            status = "PASS"
            message = "All basic functionality tests passed"
        elif successful_tests > 0:
            status = "WARNING"
            message = f"{successful_tests}/{len(test_queries)} basic functionality tests passed"
        else:
            status = "FAIL"
            message = "All basic functionality tests failed"
        
        self.validation_results.append(
            ValidationResult(
                check_name="basic_functionality",
                status=status,
                message=message,
                details={"successful_tests": successful_tests, "total_tests": len(test_queries)}
            )
        )
    
    # =====================================================================================
    # ANALYSIS METHODS
    # =====================================================================================
    
    def _analyze_database_size(self):
        """Analyze database size impact."""
        success, result, error = self.db.execute_query(
            """
            SELECT 
                pg_database_size(current_database()) as total_size,
                pg_size_pretty(pg_database_size(current_database())) as total_size_pretty
            """
        )
        
        if success:
            self.performance_metrics['database_size'] = {
                'total_size_bytes': result[0]['total_size'],
                'total_size_pretty': result[0]['total_size_pretty']
            }
    
    def _analyze_query_performance(self):
        """Analyze query performance impact."""
        success, result, error = self.db.execute_query(
            """
            SELECT 
                COUNT(*) as total_queries,
                AVG(mean_exec_time) as avg_exec_time,
                MAX(mean_exec_time) as max_exec_time,
                SUM(calls) as total_calls
            FROM pg_stat_statements
            WHERE last_seen >= NOW() - INTERVAL '1 hour'
            """
        )
        
        if success and result:
            self.performance_metrics['query_performance'] = {
                'total_queries': result[0]['total_queries'],
                'avg_exec_time_ms': float(result[0]['avg_exec_time'] or 0),
                'max_exec_time_ms': float(result[0]['max_exec_time'] or 0),
                'total_calls': result[0]['total_calls']
            }
    
    def _analyze_connections(self):
        """Analyze connection usage."""
        success, result, error = self.db.execute_query(
            """
            SELECT 
                COUNT(*) as total_connections,
                COUNT(*) FILTER (WHERE state = 'active') as active_connections,
                COUNT(*) FILTER (WHERE state = 'idle') as idle_connections
            FROM pg_stat_activity
            """
        )
        
        if success:
            self.performance_metrics['connections'] = {
                'total_connections': result[0]['total_connections'],
                'active_connections': result[0]['active_connections'],
                'idle_connections': result[0]['idle_connections']
            }
    
    def _analyze_index_usage(self):
        """Analyze index usage patterns."""
        pra_schemas = self.config.get_schemas_created()
        
        success, result, error = self.db.execute_query(
            """
            SELECT 
                schemaname,
                COUNT(*) as total_indexes,
                COUNT(*) FILTER (WHERE idx_scan = 0) as unused_indexes,
                AVG(idx_scan) as avg_index_scans
            FROM pg_stat_user_indexes
            WHERE schemaname = ANY(%s)
            GROUP BY schemaname
            """,
            [pra_schemas]
        )
        
        if success:
            self.performance_metrics['index_usage'] = [
                {
                    'schema': row['schemaname'],
                    'total_indexes': row['total_indexes'],
                    'unused_indexes': row['unused_indexes'],
                    'avg_index_scans': float(row['avg_index_scans'] or 0)
                }
                for row in result
            ]
    
    def _verify_compliance_framework(self, framework_name: str, framework_config):
        """Verify specific compliance framework implementation."""
        # This is a simplified verification - would be expanded based on specific requirements
        required_schemas = framework_config.required_schemas
        
        success, result, error = self.db.execute_query(
            "SELECT schema_name FROM information_schema.schemata WHERE schema_name = ANY(%s)",
            [required_schemas]
        )
        
        if success:
            found_schemas = [row['schema_name'] for row in result]
            missing_schemas = [schema for schema in required_schemas if schema not in found_schemas]
            
            if not missing_schemas:
                status = "PASS"
                message = f"{framework_name} compliance schemas are present"
            else:
                status = "FAIL"
                message = f"{framework_name} missing required schemas: {missing_schemas}"
            
            self.validation_results.append(
                ValidationResult(
                    check_name=f"compliance_{framework_name.lower()}",
                    status=status,
                    message=message,
                    details={"required": required_schemas, "found": found_schemas, "missing": missing_schemas}
                )
            )
    
    def _get_compliance_status(self) -> Dict[str, str]:
        """Get overall compliance status by framework."""
        compliance_status = {}
        
        for framework_name in self.config.compliance_frameworks.keys():
            # Find related validation results
            framework_validations = [
                v for v in self.validation_results 
                if f"compliance_{framework_name.lower()}" in v.check_name
            ]
            
            if framework_validations:
                # Determine overall status
                if all(v.status == "PASS" for v in framework_validations):
                    compliance_status[framework_name] = "COMPLIANT"
                elif any(v.status == "FAIL" for v in framework_validations):
                    compliance_status[framework_name] = "NON_COMPLIANT"
                else:
                    compliance_status[framework_name] = "PARTIALLY_COMPLIANT"
            else:
                compliance_status[framework_name] = "NOT_EVALUATED"
        
        return compliance_status
    
    def _generate_recommendations(self) -> List[str]:
        """Generate recommendations based on investigation results."""
        recommendations = []
        
        # Analyze execution results
        failed_executions = [r for r in self.execution_results if not r.success]
        if failed_executions:
            recommendations.append(
                f"Review and fix {len(failed_executions)} failed script executions before production deployment"
            )
        
        # Analyze validation results
        failed_validations = [v for v in self.validation_results if v.status == "FAIL"]
        if failed_validations:
            recommendations.append(
                f"Address {len(failed_validations)} failed validation checks"
            )
        
        warning_validations = [v for v in self.validation_results if v.status == "WARNING"]
        if warning_validations:
            recommendations.append(
                f"Review {len(warning_validations)} validation warnings"
            )
        
        # Performance recommendations
        if 'query_performance' in self.performance_metrics:
            avg_time = self.performance_metrics['query_performance']['avg_exec_time_ms']
            if avg_time > 100:  # More than 100ms average
                recommendations.append(
                    f"Average query execution time is {avg_time:.1f}ms - consider query optimization"
                )
        
        # Compliance recommendations
        non_compliant_frameworks = [
            fw for fw, status in self._get_compliance_status().items() 
            if status == "NON_COMPLIANT"
        ]
        if non_compliant_frameworks:
            recommendations.append(
                f"Address compliance issues for: {', '.join(non_compliant_frameworks)}"
            )
        
        # Environment-specific recommendations
        if self.config.environment == 'production':
            recommendations.append("Schedule regular backup verification and disaster recovery testing")
            recommendations.append("Implement 24/7 monitoring and alerting")
            recommendations.append("Establish incident response procedures")
        
        if not recommendations:
            recommendations.append("All checks passed - system is ready for deployment")
        
        return recommendations
    
    # =====================================================================================
    # REPORTING METHODS
    # =====================================================================================
    
    def save_investigation_report(self, report: InvestigationReport, output_path: str) -> str:
        """Save investigation report to file."""
        output_file = Path(output_path) / f"pra_investigation_report_{report.investigation_id}.json"
        
        # Convert report to dictionary for JSON serialization
        report_dict = asdict(report)
        
        # Handle datetime serialization
        for key, value in report_dict.items():
            if isinstance(value, datetime):
                report_dict[key] = value.isoformat()
        
        with open(output_file, 'w') as f:
            json.dump(report_dict, f, indent=2, default=str)
        
        return str(output_file)
    
    def print_investigation_summary(self, report: InvestigationReport):
        """Print investigation summary to console."""
        print("\n" + "="*80)
        print(f"🔍 PRA INVESTIGATION SUMMARY: {report.investigation_id}")
        print("="*80)
        
        print(f"📊 Execution Overview:")
        print(f"   • Environment: {report.environment}")
        print(f"   • Total Scripts: {report.total_scripts}")
        print(f"   • Successful: {report.successful_executions}")
        print(f"   • Failed: {report.failed_executions}")
        print(f"   • Total Time: {report.total_execution_time_seconds:.1f} seconds")
        
        print(f"\n✅ Validation Results:")
        passed = sum(1 for v in report.validation_results if v.status == "PASS")
        failed = sum(1 for v in report.validation_results if v.status == "FAIL")
        warnings = sum(1 for v in report.validation_results if v.status == "WARNING")
        
        print(f"   • Passed: {passed}")
        print(f"   • Failed: {failed}")
        print(f"   • Warnings: {warnings}")
        
        if failed > 0:
            print(f"\n❌ Failed Validations:")
            for v in report.validation_results:
                if v.status == "FAIL":
                    print(f"   • {v.check_name}: {v.message}")
        
        print(f"\n📋 Compliance Status:")
        for framework, status in report.compliance_status.items():
            status_icon = "✅" if status == "COMPLIANT" else "❌" if status == "NON_COMPLIANT" else "⚠️"
            print(f"   • {framework}: {status_icon} {status}")
        
        print(f"\n💡 Recommendations:")
        for i, rec in enumerate(report.recommendations, 1):
            print(f"   {i}. {rec}")
        
        print("\n" + "="*80)

# =====================================================================================
# CONVENIENCE FUNCTIONS
# =====================================================================================

def run_development_investigation() -> InvestigationReport:
    """Run investigation with development configuration."""
    config = get_development_config()
    investigator = PRAInvestigator(config)
    return investigator.run_full_investigation()

def run_production_investigation(tenant_id: str) -> InvestigationReport:
    """Run investigation with production configuration."""
    config = get_production_config(tenant_id)
    investigator = PRAInvestigator(config)
    return investigator.run_full_investigation()

def quick_validation_check() -> Dict[str, Any]:
    """Quick validation check without full execution."""
    config = create_pra_config('development')
    investigator = PRAInvestigator(config)
    
    if not investigator.db.connect():
        return {"status": "FAIL", "message": "Cannot connect to database"}
    
    try:
        investigator._run_pre_execution_validation()
        
        validation_summary = {
            "status": "PASS" if all(v.status == "PASS" for v in investigator.validation_results) else "FAIL",
            "total_checks": len(investigator.validation_results),
            "passed": sum(1 for v in investigator.validation_results if v.status == "PASS"),
            "failed": sum(1 for v in investigator.validation_results if v.status == "FAIL"),
            "warnings": sum(1 for v in investigator.validation_results if v.status == "WARNING"),
            "details": [
                {"check": v.check_name, "status": v.status, "message": v.message}
                for v in investigator.validation_results
            ]
        }
        
        return validation_summary
        
    finally:
        investigator.db.disconnect()

# =====================================================================================
# MAIN EXECUTION
# =====================================================================================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="PRA Investigation Tool")
    parser.add_argument("--environment", choices=["development", "production"], 
                       default="development", help="Environment to investigate")
    parser.add_argument("--tenant-id", help="Tenant ID for production investigation")
    parser.add_argument("--quick", action="store_true", 
                       help="Run quick validation check only")
    parser.add_argument("--output-dir", default="./", 
                       help="Output directory for reports")
    
    args = parser.parse_args()
    
    if args.quick:
        print("🔍 Running quick validation check...")
        result = quick_validation_check()
        print(json.dumps(result, indent=2))
    else:
        print(f"🔍 Starting PRA Investigation in {args.environment} environment...")
        
        if args.environment == "production":
            if not args.tenant_id:
                print("❌ Tenant ID required for production investigation")
                sys.exit(1)
            report = run_production_investigation(args.tenant_id)
        else:
            report = run_development_investigation()
        
        # Print summary
        investigator = PRAInvestigator(create_pra_config(args.environment, args.tenant_id))
        investigator.print_investigation_summary(report)
        
        # Save detailed report
        report_file = investigator.save_investigation_report(report, args.output_dir)
        print(f"\n📄 Detailed report saved: {report_file}") 