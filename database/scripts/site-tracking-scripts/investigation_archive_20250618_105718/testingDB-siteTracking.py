#!/usr/bin/env python3
"""
Site Tracking Database Testing Script
Tests current database state and validates readiness for site tracking SQL scripts
"""

import sys
import json
import getpass
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
from pathlib import Path
import traceback
from typing import Dict, List, Tuple, Any

# Import our configuration
from testingDBConfig import (
    DB_CONFIG, SQL_SCRIPTS, SCHEMA_CHECK_QUERIES, PREREQUISITE_CHECKS,
    CONFLICT_CHECK_QUERIES, VALIDATION_QUERIES, TEST_DATA, COMMON_ISSUES,
    DEPLOYMENT_CONFIG, REPORT_CONFIG
)

class SiteTrackingDBTester:
    """Main testing class for site tracking database readiness"""
    
    def __init__(self):
        self.connection = None
        self.test_results = {
            'timestamp': datetime.now().isoformat(),
            'database': DB_CONFIG['database'],
            'tests_run': 0,
            'tests_passed': 0,
            'tests_failed': 0,
            'critical_issues': [],
            'warnings': [],
            'recommendations': [],
            'schema_status': {},
            'prerequisite_status': {},
            'conflict_status': {},
            'script_readiness': {},
            'overall_status': 'UNKNOWN'
        }
    
    def connect_to_database(self) -> bool:
        """Establish database connection with password prompt"""
        try:
            print("🔐 Site Tracking Database Connection")
            print("=" * 50)
            print(f"Host: {DB_CONFIG['host']}")
            print(f"Port: {DB_CONFIG['port']}")
            print(f"Database: {DB_CONFIG['database']}")
            print(f"User: {DB_CONFIG['user']}")
            print()
            
            # Securely prompt for password
            password = getpass.getpass("Enter PostgreSQL password: ")
            
            # Establish connection
            conn_config = DB_CONFIG.copy()
            conn_config['password'] = password
            
            print("\n🔄 Connecting to database...")
            self.connection = psycopg2.connect(**conn_config)
            
            # Test connection
            with self.connection.cursor() as cursor:
                cursor.execute("SELECT version(), current_database(), current_user")
                version, database, user = cursor.fetchone()
                
            print(f"✅ Connected successfully!")
            print(f"   PostgreSQL Version: {version.split(',')[0]}")
            print(f"   Database: {database}")
            print(f"   User: {user}")
            print()
            
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Database connection failed: {e}")
            self.test_results['critical_issues'].append(f"Database connection failed: {e}")
            return False
        except Exception as e:
            print(f"❌ Unexpected error: {e}")
            self.test_results['critical_issues'].append(f"Unexpected connection error: {e}")
            return False
    
    def run_query(self, query: str, description: str = "") -> Tuple[bool, Any]:
        """Execute a query and return success status and results"""
        try:
            with self.connection.cursor(cursor_factory=RealDictCursor) as cursor:
                cursor.execute(query)
                if cursor.description:  # Query returns data
                    results = cursor.fetchall()
                    return True, results
                else:  # Query doesn't return data (INSERT, UPDATE, etc.)
                    return True, None
        except psycopg2.Error as e:
            print(f"   ❌ Query failed: {e}")
            if description:
                self.test_results['warnings'].append(f"{description}: {e}")
            return False, str(e)
        except Exception as e:
            print(f"   ❌ Unexpected error: {e}")
            return False, str(e)
    
    def check_schemas(self) -> None:
        """Check for existence of required schemas"""
        print("📋 Checking Database Schemas")
        print("=" * 50)
        
        for schema_name, query in SCHEMA_CHECK_QUERIES.items():
            self.test_results['tests_run'] += 1
            success, results = self.run_query(query, f"Schema check: {schema_name}")
            
            exists = success and len(results) > 0
            self.test_results['schema_status'][schema_name] = {
                'exists': exists,
                'required': True
            }
            
            if exists:
                print(f"   ✅ Schema '{schema_name}' exists")
                self.test_results['tests_passed'] += 1
            else:
                print(f"   ⚠️ Schema '{schema_name}' missing (will be created by scripts)")
                self.test_results['tests_failed'] += 1
                self.test_results['warnings'].append(f"Schema '{schema_name}' does not exist")
        
        print()
    
    def check_prerequisites(self) -> None:
        """Check for required existing database objects"""
        print("🔍 Checking Prerequisites")
        print("=" * 50)
        
        for check_name, check_config in PREREQUISITE_CHECKS.items():
            self.test_results['tests_run'] += 1
            success, results = self.run_query(check_config['query'], f"Prerequisite: {check_name}")
            
            exists = success and len(results) > 0
            self.test_results['prerequisite_status'][check_name] = {
                'exists': exists,
                'critical': check_config['critical'],
                'description': check_config['description']
            }
            
            if exists:
                print(f"   ✅ {check_config['description']}")
                if check_name == 'util_functions':
                    print(f"      Found functions: {[r['routine_name'] for r in results]}")
                self.test_results['tests_passed'] += 1
            else:
                status = "❌" if check_config['critical'] else "⚠️"
                print(f"   {status} {check_config['description']}")
                
                if check_config['critical']:
                    self.test_results['tests_failed'] += 1
                    self.test_results['critical_issues'].append(
                        f"Critical prerequisite missing: {check_config['description']}"
                    )
                else:
                    self.test_results['tests_failed'] += 1
                    self.test_results['warnings'].append(f"Optional prerequisite missing: {check_name}")
        
        print()
    
    def check_conflicts(self) -> None:
        """Check for potential naming conflicts"""
        print("⚡ Checking for Potential Conflicts")
        print("=" * 50)
        
        for conflict_name, query in CONFLICT_CHECK_QUERIES.items():
            self.test_results['tests_run'] += 1
            success, results = self.run_query(query, f"Conflict check: {conflict_name}")
            
            conflicts = []
            if success and results:
                conflicts = [f"{r.get('table_schema', r.get('routine_schema'))}.{r.get('table_name', r.get('routine_name'))}" for r in results]
            
            self.test_results['conflict_status'][conflict_name] = {
                'conflicts_found': len(conflicts),
                'conflicts': conflicts
            }
            
            if conflicts:
                print(f"   ⚠️ {conflict_name.replace('_', ' ').title()}: {len(conflicts)} potential conflicts")
                for conflict in conflicts[:5]:  # Show first 5
                    print(f"      - {conflict}")
                if len(conflicts) > 5:
                    print(f"      ... and {len(conflicts) - 5} more")
                
                self.test_results['warnings'].append(
                    f"Potential conflicts in {conflict_name}: {len(conflicts)} objects"
                )
                self.test_results['tests_failed'] += 1
            else:
                print(f"   ✅ {conflict_name.replace('_', ' ').title()}: No conflicts")
                self.test_results['tests_passed'] += 1
        
        print()
    
    def validate_sql_scripts(self) -> None:
        """Validate that SQL scripts exist and can be read"""
        print("📄 Validating SQL Scripts")
        print("=" * 50)
        
        for script in SQL_SCRIPTS:
            self.test_results['tests_run'] += 1
            script_path = script['path']
            
            script_status = {
                'exists': False,
                'readable': False,
                'size_bytes': 0,
                'errors': []
            }
            
            try:
                if script_path.exists():
                    script_status['exists'] = True
                    script_status['size_bytes'] = script_path.stat().st_size
                    
                    # Try to read the script
                    with open(script_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        script_status['readable'] = True
                        
                        # Basic validation checks
                        if 'tenant_bk' in content and script['order'] > 1:
                            script_status['errors'].append("Uses tenant_bk instead of tenant_hk")
                        
                        if 'CREATE SCHEMA' in content and 'IF NOT EXISTS' not in content:
                            script_status['errors'].append("Schema creation without IF NOT EXISTS")
                    
                    print(f"   ✅ {script['name']}: {script_status['size_bytes']:,} bytes")
                    if script_status['errors']:
                        for error in script_status['errors']:
                            print(f"      ⚠️ Warning: {error}")
                        self.test_results['warnings'].extend([f"{script['name']}: {e}" for e in script_status['errors']])
                    
                    self.test_results['tests_passed'] += 1
                else:
                    print(f"   ❌ {script['name']}: File not found at {script_path}")
                    script_status['errors'].append("File not found")
                    self.test_results['critical_issues'].append(f"Missing script: {script['file']}")
                    self.test_results['tests_failed'] += 1
                    
            except Exception as e:
                print(f"   ❌ {script['name']}: Error reading file - {e}")
                script_status['errors'].append(f"Read error: {e}")
                self.test_results['critical_issues'].append(f"Cannot read script {script['file']}: {e}")
                self.test_results['tests_failed'] += 1
            
            self.test_results['script_readiness'][script['file']] = script_status
        
        print()
    
    def test_sample_operations(self) -> None:
        """Test basic operations with sample data"""
        print("🧪 Testing Sample Operations")
        print("=" * 50)
        
        # Test tenant lookup
        self.test_results['tests_run'] += 1
        success, results = self.run_query(TEST_DATA['tenant_lookup'], "Tenant lookup test")
        
        if success and results:
            tenant_data = results[0]
            print(f"   ✅ Found test tenant: {tenant_data['tenant_bk']}")
            print(f"      tenant_hk: {tenant_data['tenant_hk'].hex()}")
            self.test_results['tests_passed'] += 1
            
            # Store for potential testing
            self.test_results['test_tenant'] = {
                'tenant_hk': tenant_data['tenant_hk'].hex(),
                'tenant_bk': tenant_data['tenant_bk']
            }
        else:
            print("   ⚠️ No test tenant found - will need to create one for testing")
            self.test_results['warnings'].append("No test tenant available for validation")
            self.test_results['tests_failed'] += 1
        
        # Test utility functions if they exist
        util_tests = [
            ("SELECT util.current_load_date()", "current_load_date function"),
            ("SELECT util.hash_binary('test')", "hash_binary function"),
        ]
        
        for query, description in util_tests:
            self.test_results['tests_run'] += 1
            success, results = self.run_query(query, description)
            
            if success:
                print(f"   ✅ {description} works")
                self.test_results['tests_passed'] += 1
            else:
                print(f"   ❌ {description} failed")
                self.test_results['tests_failed'] += 1
        
        print()
    
    def analyze_readiness(self) -> str:
        """Analyze overall readiness for deployment"""
        print("📊 Deployment Readiness Analysis")
        print("=" * 50)
        
        # Count critical issues
        critical_count = len(self.test_results['critical_issues'])
        warning_count = len(self.test_results['warnings'])
        
        # Check prerequisites
        critical_prerequisites_missing = sum(
            1 for status in self.test_results['prerequisite_status'].values()
            if status['critical'] and not status['exists']
        )
        
        # Determine overall status
        if critical_count > 0 or critical_prerequisites_missing > 0:
            overall_status = "NOT_READY"
            status_icon = "❌"
        elif warning_count > 5:
            overall_status = "CAUTION"
            status_icon = "⚠️"
        else:
            overall_status = "READY"
            status_icon = "✅"
        
        self.test_results['overall_status'] = overall_status
        
        print(f"{status_icon} Overall Status: {overall_status}")
        print()
        print(f"📈 Test Summary:")
        print(f"   Total tests run: {self.test_results['tests_run']}")
        print(f"   Tests passed: {self.test_results['tests_passed']}")
        print(f"   Tests failed: {self.test_results['tests_failed']}")
        if self.test_results['tests_run'] > 0:
            print(f"   Success rate: {(self.test_results['tests_passed'] / self.test_results['tests_run'] * 100):.1f}%")
        print()
        
        if critical_count > 0:
            print("🚨 Critical Issues:")
            for issue in self.test_results['critical_issues']:
                print(f"   ❌ {issue}")
            print()
        
        if warning_count > 0:
            print("⚠️ Warnings:")
            for warning in self.test_results['warnings'][:10]:  # Show first 10
                print(f"   ⚠️ {warning}")
            if warning_count > 10:
                print(f"   ... and {warning_count - 10} more warnings")
            print()
        
        # Recommendations
        recommendations = []
        
        if critical_prerequisites_missing > 0:
            recommendations.append("Deploy auth and util schemas before running site tracking scripts")
        
        if overall_status == "READY":
            recommendations.append("Database is ready for site tracking deployment!")
            recommendations.append("Run scripts in order: 01 → 02 → 03 → 04 → 05 → 06")
        elif overall_status == "CAUTION":
            recommendations.append("Database can be deployed with caution - review warnings")
            recommendations.append("Consider backing up database before deployment")
        else:
            recommendations.append("Resolve critical issues before attempting deployment")
            recommendations.append("Check prerequisite installations")
        
        if self.test_results['conflict_status'].get('site_tracking_tables', {}).get('conflicts_found', 0) > 0:
            recommendations.append("Review table name conflicts - may need to drop existing objects")
        
        self.test_results['recommendations'] = recommendations
        
        print("💡 Recommendations:")
        for rec in recommendations:
            print(f"   • {rec}")
        print()
        
        return overall_status
    
    def export_results(self) -> None:
        """Export detailed results to JSON file"""
        if REPORT_CONFIG['export_results']:
            try:
                results_file = Path(REPORT_CONFIG['results_file'])
                with open(results_file, 'w') as f:
                    json.dump(self.test_results, f, indent=2, default=str)
                print(f"📁 Detailed results exported to: {results_file}")
            except Exception as e:
                print(f"⚠️ Failed to export results: {e}")
    
    def cleanup(self) -> None:
        """Clean up database connection"""
        if self.connection:
            self.connection.close()
            print("🔒 Database connection closed")
    
    def run_full_test_suite(self) -> bool:
        """Run the complete test suite"""
        print("🚀 Site Tracking Database Readiness Test")
        print("=" * 60)
        print(f"Testing database readiness for site tracking implementation")
        print(f"Test started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        try:
            # Connect to database
            if not self.connect_to_database():
                return False
            
            # Run all test phases
            self.check_schemas()
            self.check_prerequisites()
            self.check_conflicts()
            self.validate_sql_scripts()
            self.test_sample_operations()
            overall_status = self.analyze_readiness()
            
            # Export results
            self.export_results()
            
            print("=" * 60)
            print(f"✅ Test suite completed successfully!")
            print(f"🔍 Overall status: {overall_status}")
            
            return overall_status in ['READY', 'CAUTION']
            
        except Exception as e:
            print(f"\n❌ Test suite failed with error: {e}")
            print(f"Stack trace:\n{traceback.format_exc()}")
            self.test_results['critical_issues'].append(f"Test suite error: {e}")
            return False
        
        finally:
            self.cleanup()

def main():
    """Main execution function"""
    try:
        # Initialize tester
        tester = SiteTrackingDBTester()
        
        # Run the full test suite
        success = tester.run_full_test_suite()
        
        # Exit with appropriate code
        if success:
            print("\n🎉 Database testing completed successfully!")
            if tester.test_results['overall_status'] == 'READY':
                print("✅ Database is READY for site tracking deployment!")
            else:
                print("⚠️ Database deployment possible with CAUTION - review warnings")
            sys.exit(0)
        else:
            print("\n❌ Database testing failed!")
            print("🚨 Critical issues must be resolved before deployment")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n\n⏹️ Test interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        print(f"Stack trace:\n{traceback.format_exc()}")
        sys.exit(1)

if __name__ == "__main__":
    main() 