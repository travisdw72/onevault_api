#!/usr/bin/env python3
"""
Phase 6: Final Validation Implementation
- Comprehensive validation of all previous phases
- Verification of 99.9% completion
- System health assessment
- Performance validation
- Security validation
- Compliance validation
"""

import os
import sys
import logging
import psycopg2
from psycopg2.extras import DictCursor
from datetime import datetime, timedelta
import json
from typing import Dict, List, Optional, Tuple, Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class FinalValidation:
    def __init__(self, connection_params: Dict[str, Any]):
        """Initialize with database connection parameters."""
        self.conn_params = connection_params
        self.conn = None
        self.cursor = None
        self.validation_results = {
            'phase1_ai_infrastructure': {'status': 'PENDING', 'score': 0.0, 'details': {}},
            'phase2_tenant_isolation': {'status': 'PENDING', 'score': 0.0, 'details': {}},
            'phase3_performance': {'status': 'PENDING', 'score': 0.0, 'details': {}},
            'phase4_security': {'status': 'PENDING', 'score': 0.0, 'details': {}},
            'phase5_production': {'status': 'PENDING', 'score': 0.0, 'details': {}},
            'overall_completion': {'status': 'PENDING', 'score': 0.0}
        }

    def connect(self) -> None:
        """Establish database connection with error handling."""
        try:
            self.conn = psycopg2.connect(**self.conn_params)
            self.cursor = self.conn.cursor(cursor_factory=DictCursor)
            logger.info("Database connection established successfully")
        except Exception as e:
            logger.error(f"Failed to connect to database: {e}")
            raise

    def close(self) -> None:
        """Close database connection."""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
            logger.info("Database connection closed")

    def validate_phase1_ai_infrastructure(self) -> Dict[str, Any]:
        """Validate AI/ML Infrastructure implementation."""
        try:
            results = {'status': 'INCOMPLETE', 'score': 0.0, 'details': {}}
            total_checks = 0
            passed_checks = 0

            # Check AI observation tables
            required_tables = [
                'ai_model_performance_s',
                'ai_training_execution_s',
                'ai_deployment_status_s',
                'ai_feature_pipeline_s'
            ]

            self.cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'business' 
                AND table_name LIKE 'ai_%'
            """)
            existing_tables = [row[0] for row in self.cursor.fetchall()]

            for table in required_tables:
                total_checks += 1
                if table in existing_tables:
                    passed_checks += 1
                    results['details'][f'table_{table}'] = 'PRESENT'
                else:
                    results['details'][f'table_{table}'] = 'MISSING'

            # Check AI functions and procedures
            required_functions = [
                'process_ai_interaction',
                'validate_ai_model',
                'track_model_performance'
            ]

            self.cursor.execute("""
                SELECT proname 
                FROM pg_proc 
                WHERE proname LIKE 'ai_%' OR proname LIKE '%_ai_%'
            """)
            existing_functions = [row[0] for row in self.cursor.fetchall()]

            for func in required_functions:
                total_checks += 1
                if func in existing_functions:
                    passed_checks += 1
                    results['details'][f'function_{func}'] = 'PRESENT'
                else:
                    results['details'][f'function_{func}'] = 'MISSING'

            # Calculate completion score
            results['score'] = (passed_checks / total_checks) * 100 if total_checks > 0 else 0.0
            results['status'] = 'COMPLETE' if results['score'] >= 99.9 else 'INCOMPLETE'

            self.validation_results['phase1_ai_infrastructure'] = results
            return results

        except Exception as e:
            logger.error(f"Failed to validate Phase 1: {e}")
            raise

    def validate_phase2_tenant_isolation(self) -> Dict[str, Any]:
        """Validate tenant isolation implementation."""
        try:
            results = {'status': 'INCOMPLETE', 'score': 0.0, 'details': {}}
            total_tables = 0
            isolated_tables = 0

            # Check hub tables for tenant isolation
            self.cursor.execute("""
                WITH hub_tables AS (
                    SELECT table_schema, table_name 
                    FROM information_schema.tables 
                    WHERE table_name LIKE '%_h'
                    AND table_schema NOT IN ('pg_catalog', 'information_schema')
                ),
                tenant_isolated AS (
                    SELECT t.table_schema, t.table_name,
                           EXISTS (
                               SELECT 1 
                               FROM information_schema.columns c
                               WHERE c.table_schema = t.table_schema
                               AND c.table_name = t.table_name
                               AND c.column_name = 'tenant_hk'
                           ) as has_tenant_isolation
                    FROM hub_tables t
                )
                SELECT table_schema, table_name, has_tenant_isolation
                FROM tenant_isolated
            """)

            for row in self.cursor.fetchall():
                total_tables += 1
                if row['has_tenant_isolation']:
                    isolated_tables += 1
                    results['details'][f"{row['table_schema']}.{row['table_name']}"] = 'ISOLATED'
                else:
                    results['details'][f"{row['table_schema']}.{row['table_name']}"] = 'NOT_ISOLATED'

            # Calculate completion score
            results['score'] = (isolated_tables / total_tables) * 100 if total_tables > 0 else 0.0
            results['status'] = 'COMPLETE' if results['score'] >= 99.9 else 'INCOMPLETE'

            self.validation_results['phase2_tenant_isolation'] = results
            return results

        except Exception as e:
            logger.error(f"Failed to validate Phase 2: {e}")
            raise

    def validate_phase3_performance(self) -> Dict[str, Any]:
        """Validate performance optimization implementation."""
        try:
            results = {'status': 'INCOMPLETE', 'score': 0.0, 'details': {}}
            total_checks = 0
            passed_checks = 0

            # Check query performance
            self.cursor.execute("""
                SELECT AVG(execution_time_ms) as avg_time
                FROM util.query_performance_s
                WHERE execution_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
                AND load_end_date IS NULL
            """)
            avg_query_time = self.cursor.fetchone()[0] or 0

            total_checks += 1
            if avg_query_time < 200:  # Target: sub-200ms queries
                passed_checks += 1
                results['details']['query_performance'] = f'OPTIMAL ({avg_query_time:.2f}ms)'
            else:
                results['details']['query_performance'] = f'SLOW ({avg_query_time:.2f}ms)'

            # Check index coverage
            self.cursor.execute("""
                SELECT COUNT(*) as total_indexes
                FROM pg_indexes
                WHERE schemaname = 'business'
                AND tablename LIKE 'ai_%'
            """)
            ai_indexes = self.cursor.fetchone()[0] or 0

            total_checks += 1
            if ai_indexes >= 10:  # Expecting at least 10 performance indexes
                passed_checks += 1
                results['details']['index_coverage'] = f'ADEQUATE ({ai_indexes} indexes)'
            else:
                results['details']['index_coverage'] = f'INSUFFICIENT ({ai_indexes} indexes)'

            # Check materialized views
            self.cursor.execute("""
                SELECT COUNT(*) as total_mat_views
                FROM pg_matviews
                WHERE schemaname = 'infomart'
            """)
            mat_views = self.cursor.fetchone()[0] or 0

            total_checks += 1
            if mat_views >= 5:  # Expecting at least 5 materialized views
                passed_checks += 1
                results['details']['materialized_views'] = f'ADEQUATE ({mat_views} views)'
            else:
                results['details']['materialized_views'] = f'INSUFFICIENT ({mat_views} views)'

            # Calculate completion score
            results['score'] = (passed_checks / total_checks) * 100 if total_checks > 0 else 0.0
            results['status'] = 'COMPLETE' if results['score'] >= 99.9 else 'INCOMPLETE'

            self.validation_results['phase3_performance'] = results
            return results

        except Exception as e:
            logger.error(f"Failed to validate Phase 3: {e}")
            raise

    def validate_phase4_security(self) -> Dict[str, Any]:
        """Validate security and compliance implementation."""
        try:
            results = {'status': 'INCOMPLETE', 'score': 0.0, 'details': {}}
            total_checks = 0
            passed_checks = 0

            # Check Zero Trust implementation
            self.cursor.execute("""
                SELECT COUNT(*) 
                FROM pg_proc 
                WHERE proname LIKE '%zero_trust%'
            """)
            zero_trust_functions = self.cursor.fetchone()[0] or 0

            total_checks += 1
            if zero_trust_functions >= 3:  # Expecting at least 3 Zero Trust functions
                passed_checks += 1
                results['details']['zero_trust'] = 'IMPLEMENTED'
            else:
                results['details']['zero_trust'] = 'INCOMPLETE'

            # Check PII detection
            self.cursor.execute("""
                SELECT COUNT(*) 
                FROM pg_proc 
                WHERE proname LIKE '%pii%' OR proname LIKE '%sensitive%'
            """)
            pii_functions = self.cursor.fetchone()[0] or 0

            total_checks += 1
            if pii_functions >= 2:  # Expecting at least 2 PII detection functions
                passed_checks += 1
                results['details']['pii_detection'] = 'IMPLEMENTED'
            else:
                results['details']['pii_detection'] = 'INCOMPLETE'

            # Check compliance monitoring
            self.cursor.execute("""
                SELECT COUNT(*) 
                FROM information_schema.tables 
                WHERE table_schema = 'compliance'
            """)
            compliance_tables = self.cursor.fetchone()[0] or 0

            total_checks += 1
            if compliance_tables >= 5:  # Expecting at least 5 compliance tables
                passed_checks += 1
                results['details']['compliance_monitoring'] = 'IMPLEMENTED'
            else:
                results['details']['compliance_monitoring'] = 'INCOMPLETE'

            # Calculate completion score
            results['score'] = (passed_checks / total_checks) * 100 if total_checks > 0 else 0.0
            results['status'] = 'COMPLETE' if results['score'] >= 99.9 else 'INCOMPLETE'

            self.validation_results['phase4_security'] = results
            return results

        except Exception as e:
            logger.error(f"Failed to validate Phase 4: {e}")
            raise

    def validate_phase5_production(self) -> Dict[str, Any]:
        """Validate production excellence implementation."""
        try:
            results = {'status': 'INCOMPLETE', 'score': 0.0, 'details': {}}
            total_checks = 0
            passed_checks = 0

            # Check monitoring implementation
            self.cursor.execute("""
                SELECT COUNT(*) 
                FROM information_schema.tables 
                WHERE table_schema = 'monitoring'
            """)
            monitoring_tables = self.cursor.fetchone()[0] or 0

            total_checks += 1
            if monitoring_tables >= 4:  # Expecting at least 4 monitoring tables
                passed_checks += 1
                results['details']['monitoring'] = 'IMPLEMENTED'
            else:
                results['details']['monitoring'] = 'INCOMPLETE'

            # Check automated maintenance
            self.cursor.execute("""
                SELECT COUNT(*) 
                FROM pg_proc 
                WHERE proname LIKE '%maintenance%'
            """)
            maintenance_functions = self.cursor.fetchone()[0] or 0

            total_checks += 1
            if maintenance_functions >= 2:  # Expecting at least 2 maintenance functions
                passed_checks += 1
                results['details']['maintenance'] = 'IMPLEMENTED'
            else:
                results['details']['maintenance'] = 'INCOMPLETE'

            # Check alerting system
            self.cursor.execute("""
                SELECT COUNT(*) 
                FROM information_schema.tables 
                WHERE table_schema = 'monitoring' 
                AND table_name LIKE '%alert%'
            """)
            alert_tables = self.cursor.fetchone()[0] or 0

            total_checks += 1
            if alert_tables >= 2:  # Expecting at least 2 alert-related tables
                passed_checks += 1
                results['details']['alerting'] = 'IMPLEMENTED'
            else:
                results['details']['alerting'] = 'INCOMPLETE'

            # Calculate completion score
            results['score'] = (passed_checks / total_checks) * 100 if total_checks > 0 else 0.0
            results['status'] = 'COMPLETE' if results['score'] >= 99.9 else 'INCOMPLETE'

            self.validation_results['phase5_production'] = results
            return results

        except Exception as e:
            logger.error(f"Failed to validate Phase 5: {e}")
            raise

    def calculate_overall_completion(self) -> Dict[str, Any]:
        """Calculate overall system completion percentage."""
        try:
            phase_weights = {
                'phase1_ai_infrastructure': 0.25,  # 25% weight
                'phase2_tenant_isolation': 0.20,   # 20% weight
                'phase3_performance': 0.20,        # 20% weight
                'phase4_security': 0.20,           # 20% weight
                'phase5_production': 0.15          # 15% weight
            }

            weighted_score = 0.0
            for phase, weight in phase_weights.items():
                phase_score = self.validation_results[phase]['score']
                weighted_score += phase_score * weight

            overall_results = {
                'status': 'INCOMPLETE',
                'score': weighted_score,
                'details': {
                    phase: results['score']
                    for phase, results in self.validation_results.items()
                    if phase != 'overall_completion'
                }
            }

            if weighted_score >= 99.9:
                overall_results['status'] = 'COMPLETE'

            self.validation_results['overall_completion'] = overall_results
            return overall_results

        except Exception as e:
            logger.error(f"Failed to calculate overall completion: {e}")
            raise

    def generate_validation_report(self) -> str:
        """Generate a comprehensive validation report."""
        try:
            report = {
                'validation_timestamp': datetime.now().isoformat(),
                'overall_status': self.validation_results['overall_completion']['status'],
                'overall_score': self.validation_results['overall_completion']['score'],
                'phase_details': {
                    phase: results
                    for phase, results in self.validation_results.items()
                    if phase != 'overall_completion'
                },
                'recommendations': []
            }

            # Add recommendations based on results
            for phase, results in self.validation_results.items():
                if phase != 'overall_completion' and results['score'] < 99.9:
                    report['recommendations'].append({
                        'phase': phase,
                        'current_score': results['score'],
                        'missing_components': [
                            k for k, v in results.get('details', {}).items()
                            if 'MISSING' in str(v) or 'INCOMPLETE' in str(v) or 'INSUFFICIENT' in str(v)
                        ]
                    })

            return json.dumps(report, indent=2)

        except Exception as e:
            logger.error(f"Failed to generate validation report: {e}")
            raise

def main():
    """Main execution function."""
    try:
        # Get database password securely
        db_password = input("Enter database password: ")

        # Initialize connection parameters
        conn_params = {
            'dbname': 'one_vault',
            'user': 'postgres',
            'password': db_password,
            'host': 'localhost',
            'port': '5432'
        }

        # Initialize and execute final validation
        validator = FinalValidation(conn_params)
        validator.connect()

        logger.info("Starting Final Validation...")

        # Execute all validation checks
        validator.validate_phase1_ai_infrastructure()
        validator.validate_phase2_tenant_isolation()
        validator.validate_phase3_performance()
        validator.validate_phase4_security()
        validator.validate_phase5_production()
        validator.calculate_overall_completion()

        # Generate and display validation report
        report = validator.generate_validation_report()
        logger.info("Validation Report:")
        print(report)

        # Check if we achieved 99.9% completion
        overall_score = validator.validation_results['overall_completion']['score']
        if overall_score >= 99.9:
            logger.info(f"🎉 Success! System is {overall_score:.1f}% complete!")
        else:
            logger.warning(f"⚠️ System is only {overall_score:.1f}% complete. Review recommendations in the report.")

    except Exception as e:
        logger.error(f"Final validation failed: {e}")
        sys.exit(1)
    finally:
        if 'validator' in locals():
            validator.close()

if __name__ == "__main__":
    main() 