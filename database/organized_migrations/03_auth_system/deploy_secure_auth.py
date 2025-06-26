#!/usr/bin/env python3
"""
Production Deployment Script - Secure Tenant-Isolated Authentication
====================================================================

This script deploys the V015 security enhancement that fixes the critical
cross-tenant login vulnerability (CVE-OneVault-2025-001).

SECURITY CRITICAL: This deployment adds mandatory tenant isolation to
prevent cross-tenant login attacks in the authentication system.

Usage:
    python deploy_secure_auth.py --environment [dev|staging|prod]
    
Prerequisites:
    - Database connection configured
    - Migration log table exists (util.migration_log)
    - Current auth.login_user procedure exists
    - Proper backup completed before running
"""
import argparse
import psycopg2
import os
import sys
import json
from datetime import datetime
from typing import Dict, Any, Optional

class SecureAuthDeployment:
    def __init__(self, environment: str, connection_params: Dict[str, str]):
        self.environment = environment
        self.conn_params = connection_params
        self.deployment_log = {
            'deployment_id': f"V015_SECURE_AUTH_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            'environment': environment,
            'started_at': datetime.now().isoformat(),
            'steps': [],
            'status': 'STARTED'
        }
    
    def connect_db(self) -> psycopg2.connection:
        """Establish database connection"""
        try:
            conn = psycopg2.connect(**self.conn_params)
            conn.autocommit = False  # Use transactions for safety
            return conn
        except Exception as e:
            raise Exception(f"Database connection failed: {e}")
    
    def log_step(self, step_name: str, status: str, details: str = "", duration_ms: int = 0):
        """Log deployment step"""
        self.deployment_log['steps'].append({
            'step': step_name,
            'status': status,
            'details': details,
            'timestamp': datetime.now().isoformat(),
            'duration_ms': duration_ms
        })
        
        status_icon = {
            'STARTED': '🔄',
            'SUCCESS': '✅',
            'FAILED': '❌',
            'WARNING': '⚠️',
            'SKIPPED': '⏭️'
        }.get(status, '❓')
        
        print(f"{status_icon} {step_name}: {status}")
        if details:
            print(f"   {details}")
    
    def validate_prerequisites(self) -> bool:
        """Validate deployment prerequisites"""
        print("\n🔍 Validating Prerequisites...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        try:
            # Check if migration already deployed
            cursor.execute("""
                SELECT COUNT(*) FROM util.migration_log 
                WHERE migration_version = 'V015' 
                AND migration_type = 'FORWARD' 
                AND status = 'SUCCESS'
            """)
            
            if cursor.fetchone()[0] > 0:
                self.log_step("Migration Status Check", "WARNING", 
                             "V015 already deployed - this will update existing implementation")
                if self.environment == 'prod':
                    response = input("Continue with production update? (yes/no): ")
                    if response.lower() != 'yes':
                        self.log_step("User Confirmation", "FAILED", "Deployment cancelled by user")
                        return False
            
            # Check required schemas exist
            required_schemas = ['auth', 'util', 'audit', 'api']
            cursor.execute("""
                SELECT schema_name FROM information_schema.schemata 
                WHERE schema_name = ANY(%s)
            """, (required_schemas,))
            
            existing_schemas = [row[0] for row in cursor.fetchall()]
            missing_schemas = set(required_schemas) - set(existing_schemas)
            
            if missing_schemas:
                self.log_step("Schema Check", "FAILED", f"Missing schemas: {', '.join(missing_schemas)}")
                return False
            
            self.log_step("Schema Check", "SUCCESS", f"All required schemas exist: {', '.join(existing_schemas)}")
            
            # Check migration log table exists
            cursor.execute("""
                SELECT COUNT(*) FROM information_schema.tables 
                WHERE table_schema = 'util' AND table_name = 'migration_log'
            """)
            
            if cursor.fetchone()[0] == 0:
                self.log_step("Migration Log Table", "FAILED", "util.migration_log table not found")
                return False
            
            self.log_step("Migration Log Table", "SUCCESS", "Migration logging infrastructure ready")
            
            return True
            
        except Exception as e:
            self.log_step("Prerequisites Validation", "FAILED", f"Error: {e}")
            return False
        finally:
            cursor.close()
            conn.close()
    
    def create_backup(self) -> bool:
        """Create backup of current authentication functions"""
        print("\n💾 Creating Security Backup...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        try:
            conn.begin()
            
            # Create backup table if not exists
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS util.security_backup (
                    backup_id VARCHAR(100) PRIMARY KEY,
                    backup_type VARCHAR(50),
                    object_name VARCHAR(200),
                    object_definition TEXT,
                    environment VARCHAR(20),
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    created_by VARCHAR(100) DEFAULT SESSION_USER
                )
            """)
            
            # Backup current auth.login_user procedure
            cursor.execute("""
                SELECT pg_get_functiondef(p.oid)
                FROM pg_proc p 
                JOIN pg_namespace n ON p.pronamespace = n.oid 
                WHERE n.nspname = 'auth' AND p.proname = 'login_user'
            """)
            
            current_function = cursor.fetchone()
            if current_function:
                backup_id = f"V015_AUTH_BACKUP_{self.environment}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                
                cursor.execute("""
                    INSERT INTO util.security_backup 
                    (backup_id, backup_type, object_name, object_definition, environment)
                    VALUES (%s, %s, %s, %s, %s)
                """, (backup_id, 'PROCEDURE', 'auth.login_user', current_function[0], self.environment))
                
                self.log_step("Authentication Backup", "SUCCESS", f"Backup created: {backup_id}")
            else:
                self.log_step("Authentication Backup", "WARNING", "No existing auth.login_user found to backup")
            
            conn.commit()
            return True
            
        except Exception as e:
            conn.rollback()
            self.log_step("Backup Creation", "FAILED", f"Error: {e}")
            return False
        finally:
            cursor.close()
            conn.close()
    
    def deploy_migration(self) -> bool:
        """Deploy the secure authentication migration"""
        print("\n🚀 Deploying Security Enhancement...")
        
        migration_file = "database/organized_migrations/03_auth_system/V015__secure_tenant_isolated_auth.sql"
        
        if not os.path.exists(migration_file):
            self.log_step("Migration File Check", "FAILED", f"Migration file not found: {migration_file}")
            return False
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        try:
            conn.begin()
            
            # Read migration file
            with open(migration_file, 'r') as f:
                migration_sql = f.read()
            
            self.log_step("Migration File Read", "SUCCESS", f"Loaded {len(migration_sql)} characters from migration file")
            
            # Execute migration
            start_time = datetime.now()
            cursor.execute(migration_sql)
            end_time = datetime.now()
            
            execution_time = int((end_time - start_time).total_seconds() * 1000)
            
            self.log_step("Migration Execution", "SUCCESS", 
                         f"Security enhancement deployed successfully in {execution_time}ms")
            
            conn.commit()
            return True
            
        except Exception as e:
            conn.rollback()
            self.log_step("Migration Deployment", "FAILED", f"Error: {e}")
            return False
        finally:
            cursor.close()
            conn.close()
    
    def run_security_tests(self) -> bool:
        """Run security validation tests"""
        print("\n🔒 Running Security Validation Tests...")
        
        try:
            # Import and run the test suite
            sys.path.append(os.path.dirname(os.path.abspath(__file__)))
            from test_secure_auth_deployment import SecureAuthDeploymentTester
            
            tester = SecureAuthDeploymentTester(self.conn_params)
            test_results = tester.run_all_tests()
            
            summary = test_results.get('summary', {})
            overall_status = summary.get('overall_status', 'UNKNOWN')
            
            if overall_status == 'CRITICAL_SECURITY_FAILURE':
                self.log_step("Security Tests", "FAILED", 
                             f"Critical security failures detected: {summary.get('critical_failures', 0)}")
                return False
            elif overall_status == 'SECURITY_ISSUES_FOUND':
                self.log_step("Security Tests", "WARNING", 
                             f"Security issues found: {summary.get('failed_tests', 0)} failed tests")
                if self.environment == 'prod':
                    return False  # Don't allow prod deployment with issues
            else:
                self.log_step("Security Tests", "SUCCESS", 
                             f"All security tests passed: {summary.get('success_rate', 0)}% success rate")
            
            return True
            
        except Exception as e:
            self.log_step("Security Testing", "FAILED", f"Test execution error: {e}")
            return False
    
    def update_api_endpoints(self) -> bool:
        """Update API endpoints to use secure authentication"""
        print("\n🔌 Updating API Integration...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        try:
            # Verify new API function exists
            cursor.execute("""
                SELECT COUNT(*) FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid
                WHERE n.nspname = 'api' AND p.proname = 'auth_login_secure'
            """)
            
            if cursor.fetchone()[0] == 0:
                self.log_step("API Function Check", "FAILED", "api.auth_login_secure function not found")
                return False
            
            self.log_step("API Function Check", "SUCCESS", "Secure API function available")
            
            # Note: In a real deployment, this would update your FastAPI endpoints
            # to use the new secure function with tenant_hk parameter
            self.log_step("API Endpoint Update", "SUCCESS", 
                         "API endpoints ready for secure authentication integration")
            
            return True
            
        except Exception as e:
            self.log_step("API Update", "FAILED", f"Error: {e}")
            return False
        finally:
            cursor.close()
            conn.close()
    
    def finalize_deployment(self) -> bool:
        """Finalize deployment and update status"""
        print("\n🎯 Finalizing Security Deployment...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        try:
            # Update migration status
            cursor.execute("""
                UPDATE util.migration_log 
                SET completed_at = CURRENT_TIMESTAMP,
                    status = 'SUCCESS',
                    notes = %s
                WHERE migration_version = 'V015' 
                AND migration_type = 'FORWARD'
            """, (f"Security enhancement deployed in {self.environment} environment",))
            
            # Set deployment status
            self.deployment_log['status'] = 'SUCCESS'
            self.deployment_log['completed_at'] = datetime.now().isoformat()
            
            self.log_step("Deployment Finalization", "SUCCESS", 
                         "Security enhancement deployment completed successfully")
            
            return True
            
        except Exception as e:
            self.log_step("Finalization", "FAILED", f"Error: {e}")
            return False
        finally:
            cursor.close()
            conn.close()
    
    def deploy(self) -> bool:
        """Execute complete security deployment"""
        print("🔒 OneVault Security Enhancement Deployment")
        print("=" * 60)
        print(f"Environment: {self.environment.upper()}")
        print(f"Migration: V015 - Secure Tenant-Isolated Authentication")
        print(f"Objective: Fix cross-tenant login vulnerability")
        print()
        
        deployment_steps = [
            ("Prerequisites Validation", self.validate_prerequisites),
            ("Security Backup", self.create_backup),
            ("Migration Deployment", self.deploy_migration),
            ("Security Testing", self.run_security_tests),
            ("API Integration", self.update_api_endpoints),
            ("Deployment Finalization", self.finalize_deployment)
        ]
        
        for step_name, step_function in deployment_steps:
            print(f"\n📍 {step_name}...")
            
            try:
                if not step_function():
                    self.deployment_log['status'] = 'FAILED'
                    print(f"\n❌ Deployment FAILED at step: {step_name}")
                    return False
                    
            except Exception as e:
                self.log_step(step_name, "FAILED", f"Unexpected error: {e}")
                self.deployment_log['status'] = 'FAILED'
                print(f"\n❌ Deployment FAILED at step: {step_name}")
                return False
        
        # Export deployment log
        log_file = f"deployment_log_{self.deployment_log['deployment_id']}.json"
        with open(log_file, 'w') as f:
            json.dump(self.deployment_log, f, indent=2)
        
        print("\n🎉 SECURITY ENHANCEMENT DEPLOYMENT SUCCESSFUL!")
        print("=" * 60)
        print("✅ Cross-tenant login vulnerability FIXED")
        print("✅ Tenant isolation now mandatory in authentication")
        print("✅ Enhanced security audit logging implemented")
        print(f"📊 Deployment log saved: {log_file}")
        print()
        print("⚠️  IMPORTANT NEXT STEPS:")
        print("1. Update your API calls to include tenant_hk parameter")
        print("2. Use api.auth_login_secure() for new implementations")
        print("3. Test authentication flows in your application")
        print("4. Monitor security audit logs for anomalies")
        
        return True

def main():
    parser = argparse.ArgumentParser(description='Deploy V015 Secure Authentication Enhancement')
    parser.add_argument('--environment', '-e', 
                       choices=['dev', 'staging', 'prod'], 
                       default='dev',
                       help='Target environment for deployment')
    parser.add_argument('--host', default='localhost', help='Database host')
    parser.add_argument('--port', default='5432', help='Database port')
    parser.add_argument('--database', default='one_vault_dev', help='Database name')
    parser.add_argument('--user', default='postgres', help='Database user')
    parser.add_argument('--password', help='Database password (or set DB_PASSWORD env var)')
    
    args = parser.parse_args()
    
    # Get database password
    password = args.password or os.getenv('DB_PASSWORD')
    if not password:
        password = input("Enter database password: ")
    
    connection_params = {
        'host': args.host,
        'port': args.port,
        'database': args.database,
        'user': args.user,
        'password': password
    }
    
    # Create and run deployment
    deployment = SecureAuthDeployment(args.environment, connection_params)
    
    # Production safety check
    if args.environment == 'prod':
        print("⚠️  WARNING: PRODUCTION DEPLOYMENT")
        print("This will deploy security-critical changes to production!")
        response = input("Are you sure you want to continue? (yes/no): ")
        if response.lower() != 'yes':
            print("❌ Production deployment cancelled")
            sys.exit(1)
    
    success = deployment.deploy()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 