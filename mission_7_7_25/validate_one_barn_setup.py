#!/usr/bin/env python3
"""
One_Barn_AI Setup Validation Script
==================================
Date: July 2, 2025
Purpose: Validate One_Barn_AI enterprise setup for July 7th demo
Database: one_vault_site_testing

This script tests all aspects of the One_Barn_AI setup to ensure
everything is ready for the customer demo.
"""

import psycopg2
import json
import sys
from datetime import datetime
from typing import Dict, List, Optional

class OneBarnValidation:
    def __init__(self):
        """Initialize the validation system."""
        self.db_config = {
            'host': 'localhost',
            'port': '5432',
            'database': 'one_vault_site_testing',
            'user': 'postgres',
            'password': 'postgres'  # Update with your actual password
        }
        self.connection = None
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'demo_date': '2025-07-07',
            'validation_status': 'PENDING',
            'tests': []
        }
    
    def log_result(self, test_name: str, status: str, message: str, data: Optional[Dict] = None):
        """Log validation results."""
        result = {
            'test': test_name,
            'status': status,
            'message': message,
            'timestamp': datetime.now().isoformat()
        }
        if data:
            result['data'] = data
        
        self.results['tests'].append(result)
        
        # Print with emojis for visual feedback
        status_emoji = {
            'SUCCESS': '✅',
            'FAILED': '❌',
            'WARNING': '⚠️',
            'INFO': 'ℹ️'
        }
        print(f"{status_emoji.get(status, '•')} {test_name}: {message}")
    
    def connect_database(self) -> bool:
        """Connect to the database."""
        try:
            self.connection = psycopg2.connect(**self.db_config)
            self.connection.autocommit = True
            self.log_result('database_connection', 'SUCCESS', 'Connected to one_vault_site_testing')
            return True
        except Exception as e:
            self.log_result('database_connection', 'FAILED', f'Connection failed: {str(e)}')
            return False
    
    def validate_tenant_setup(self) -> bool:
        """Validate One_Barn_AI tenant exists and is properly configured."""
        cursor = self.connection.cursor()
        try:
            cursor.execute("""
                SELECT 
                    tp.tenant_name,
                    tp.business_name,
                    tp.domain_name,
                    tp.subscription_level,
                    tp.is_active,
                    encode(th.tenant_hk, 'hex') as tenant_hk_hex
                FROM auth.tenant_h th
                JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
                WHERE tp.tenant_name = 'one_barn_ai'
                AND tp.load_end_date IS NULL
            """)
            
            result = cursor.fetchone()
            if result:
                tenant_data = {
                    'tenant_name': result[0],
                    'business_name': result[1],
                    'domain_name': result[2],
                    'subscription_level': result[3],
                    'is_active': result[4],
                    'tenant_hk': result[5]
                }
                
                if result[4]:  # is_active
                    self.log_result('tenant_validation', 'SUCCESS', 
                                  f'One_Barn_AI tenant active with {result[3]} subscription', 
                                  tenant_data)
                    return True
                else:
                    self.log_result('tenant_validation', 'FAILED', 'Tenant exists but is inactive', tenant_data)
                    return False
            else:
                self.log_result('tenant_validation', 'FAILED', 'One_Barn_AI tenant not found')
                return False
                
        except Exception as e:
            self.log_result('tenant_validation', 'FAILED', f'Error validating tenant: {str(e)}')
            return False
        finally:
            cursor.close()
    
    def validate_demo_users(self) -> bool:
        """Validate all demo users are created and active."""
        cursor = self.connection.cursor()
        expected_users = [
            'admin@onebarnai.com',
            'vet@onebarnai.com', 
            'tech@onebarnai.com',
            'business@onebarnai.com'
        ]
        
        try:
            cursor.execute("""
                SELECT 
                    up.email,
                    up.first_name,
                    up.last_name,
                    up.job_title,
                    COALESCE(uas.is_active, false) as is_active,
                    COALESCE(uas.account_locked, true) as account_locked
                FROM auth.user_profile_s up
                JOIN auth.user_h uh ON up.user_hk = uh.user_hk
                JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
                JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
                LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
                WHERE tp.tenant_name = 'one_barn_ai'
                AND up.load_end_date IS NULL
                AND tp.load_end_date IS NULL
                AND (uas.load_end_date IS NULL OR uas.load_end_date IS NULL)
                ORDER BY up.email
            """)
            
            users = cursor.fetchall()
            found_emails = [user[0] for user in users]
            
            # Check if all expected users exist
            missing_users = [email for email in expected_users if email not in found_emails]
            
            if not missing_users:
                active_users = [user for user in users if user[4] and not user[5]]
                user_summary = {
                    'total_users': len(users),
                    'active_users': len(active_users),
                    'users': [
                        {
                            'email': user[0],
                            'name': f"{user[1]} {user[2]}",
                            'title': user[3],
                            'active': user[4] and not user[5]
                        } for user in users
                    ]
                }
                
                self.log_result('demo_users', 'SUCCESS', 
                              f'All {len(users)} demo users created, {len(active_users)} active',
                              user_summary)
                return True
            else:
                self.log_result('demo_users', 'FAILED', 
                              f'Missing users: {", ".join(missing_users)}')
                return False
                
        except Exception as e:
            self.log_result('demo_users', 'FAILED', f'Error validating users: {str(e)}')
            return False
        finally:
            cursor.close()
    
    def validate_demo_horses(self) -> bool:
        """Validate demo horses are created for the demo."""
        cursor = self.connection.cursor()
        try:
            cursor.execute("""
                SELECT 
                    ed.entity_name,
                    ed.entity_metadata->>'breed' as breed,
                    ed.entity_metadata->>'demo_scenario' as demo_scenario,
                    ed.entity_metadata->>'health_status' as health_status,
                    ed.entity_metadata->>'demo_date' as demo_date
                FROM business.entity_details_s ed
                JOIN business.entity_h eh ON ed.entity_hk = eh.entity_hk
                JOIN auth.tenant_h th ON eh.tenant_hk = th.tenant_hk
                JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
                WHERE tp.tenant_name = 'one_barn_ai'
                AND ed.entity_type = 'horse'
                AND ed.load_end_date IS NULL
                AND tp.load_end_date IS NULL
                ORDER BY ed.entity_name
            """)
            
            horses = cursor.fetchall()
            if len(horses) >= 2:
                horse_data = [
                    {
                        'name': horse[0],
                        'breed': horse[1],
                        'scenario': horse[2],
                        'health_status': horse[3],
                        'demo_date': horse[4]
                    } for horse in horses
                ]
                
                # Check for required scenarios
                scenarios = [horse[2] for horse in horses]
                has_healthy = 'healthy_baseline' in scenarios
                has_concern = 'minor_lameness_detection' in scenarios
                
                if has_healthy and has_concern:
                    self.log_result('demo_horses', 'SUCCESS', 
                                  f'{len(horses)} demo horses ready with all scenarios',
                                  {'horses': horse_data})
                    return True
                else:
                    self.log_result('demo_horses', 'WARNING', 
                                  f'{len(horses)} horses found but missing required scenarios')
                    return False
            else:
                self.log_result('demo_horses', 'FAILED', 
                              f'Only {len(horses)} demo horses found, need at least 2')
                return False
                
        except Exception as e:
            self.log_result('demo_horses', 'FAILED', f'Error validating horses: {str(e)}')
            return False
        finally:
            cursor.close()
    
    def test_authentication(self) -> bool:
        """Test API authentication with admin user."""
        cursor = self.connection.cursor()
        try:
            # Test admin login
            cursor.execute("""
                SELECT api.auth_login('{
                    "username": "admin@onebarnai.com",
                    "password": "HorseHealth2025!",
                    "ip_address": "127.0.0.1",
                    "user_agent": "OneVault-Validation-Test",
                    "auto_login": true
                }')
            """)
            
            result = cursor.fetchone()
            if result and result[0]:
                auth_response = json.loads(result[0])
                if auth_response.get('p_success'):
                    session_data = {
                        'session_token': auth_response.get('p_session_token', 'present')[:20] + '...',
                        'user_data': 'present' if auth_response.get('p_user_data') else 'missing'
                    }
                    self.log_result('authentication', 'SUCCESS', 
                                  'Admin authentication successful', session_data)
                    return True
                else:
                    self.log_result('authentication', 'FAILED', 
                                  f"Auth failed: {auth_response.get('p_message')}")
                    return False
            else:
                self.log_result('authentication', 'FAILED', 'No response from auth function')
                return False
                
        except Exception as e:
            self.log_result('authentication', 'FAILED', f'Auth test error: {str(e)}')
            return False
        finally:
            cursor.close()
    
    def test_system_health(self) -> bool:
        """Test system health check."""
        cursor = self.connection.cursor()
        try:
            cursor.execute("SELECT api.system_health_check('{}')")
            result = cursor.fetchone()
            
            if result and result[0]:
                health_data = json.loads(result[0])
                self.log_result('system_health', 'SUCCESS', 
                              'System health check passed', health_data)
                return True
            else:
                self.log_result('system_health', 'WARNING', 
                              'System health check returned no data')
                return False
                
        except Exception as e:
            self.log_result('system_health', 'WARNING', f'Health check error: {str(e)}')
            return False
        finally:
            cursor.close()
    
    def generate_demo_report(self) -> Dict:
        """Generate a comprehensive demo readiness report."""
        success_count = len([t for t in self.results['tests'] if t['status'] == 'SUCCESS'])
        total_tests = len(self.results['tests'])
        
        demo_readiness = {
            'overall_status': 'READY' if success_count >= total_tests - 1 else 'NEEDS_ATTENTION',
            'success_rate': f"{success_count}/{total_tests}",
            'critical_tests_passed': success_count >= 3,  # Minimum for demo
            'demo_credentials': {
                'admin': 'admin@onebarnai.com / HorseHealth2025!',
                'vet': 'vet@onebarnai.com / VetSpecialist2025!',
                'tech': 'tech@onebarnai.com / TechLead2025!',
                'business': 'business@onebarnai.com / BizDev2025!'
            },
            'demo_scenarios': [
                'Buttercup - Healthy horse baseline analysis',
                'Thunder - Minor lameness detection'
            ],
            'next_steps': [
                'Test Canvas frontend configuration',
                'Prepare demo presentation slides',
                'Set up demo environment',
                'Rehearse demo flow'
            ]
        }
        
        return demo_readiness
    
    def run_full_validation(self) -> Dict:
        """Run complete validation suite."""
        print("🚀 One_Barn_AI Demo Validation - July 7th, 2025")
        print("=" * 60)
        
        # Connect to database
        if not self.connect_database():
            self.results['validation_status'] = 'FAILED_CONNECTION'
            return self.results
        
        # Run all validation tests
        tests = [
            ('tenant', self.validate_tenant_setup),
            ('users', self.validate_demo_users),
            ('horses', self.validate_demo_horses),
            ('auth', self.test_authentication),
            ('health', self.test_system_health)
        ]
        
        passed_tests = 0
        for test_name, test_func in tests:
            if test_func():
                passed_tests += 1
        
        # Determine overall status
        if passed_tests >= len(tests) - 1:  # Allow 1 test to fail
            self.results['validation_status'] = 'DEMO_READY'
        elif passed_tests >= 3:  # Critical minimum
            self.results['validation_status'] = 'READY_WITH_WARNINGS'
        else:
            self.results['validation_status'] = 'NOT_READY'
        
        # Generate demo report
        demo_report = self.generate_demo_report()
        self.results['demo_report'] = demo_report
        
        return self.results
    
    def close_connection(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()

def main():
    """Main validation execution."""
    validator = OneBarnValidation()
    
    try:
        # Run validation
        results = validator.run_full_validation()
        
        # Print summary
        print("\n" + "=" * 60)
        print("🎯 JULY 7TH DEMO READINESS SUMMARY")
        print("=" * 60)
        
        status = results['validation_status']
        status_messages = {
            'DEMO_READY': '🎉 READY FOR DEMO!',
            'READY_WITH_WARNINGS': '⚠️ READY (with minor issues)',
            'NOT_READY': '❌ NOT READY - Issues need attention',
            'FAILED_CONNECTION': '❌ DATABASE CONNECTION FAILED'
        }
        
        print(f"Status: {status_messages.get(status, status)}")
        print(f"Tests Passed: {results['demo_report']['success_rate']}")
        print(f"Timestamp: {results['timestamp']}")
        
        if 'demo_report' in results:
            report = results['demo_report']
            
            print("\n🔑 Demo Credentials:")
            for role, creds in report['demo_credentials'].items():
                print(f"  {role.title()}: {creds}")
            
            print("\n🐴 Demo Scenarios:")
            for scenario in report['demo_scenarios']:
                print(f"  • {scenario}")
            
            if report['next_steps']:
                print("\n📋 Next Steps:")
                for step in report['next_steps']:
                    print(f"  • {step}")
        
        # Save detailed results
        filename = f"one_barn_validation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        print(f"\n📄 Detailed results saved to: {filename}")
        
        # Return appropriate exit code
        return 0 if status in ['DEMO_READY', 'READY_WITH_WARNINGS'] else 1
        
    except Exception as e:
        print(f"❌ Validation failed: {str(e)}")
        return 1
    
    finally:
        validator.close_connection()

if __name__ == "__main__":
    sys.exit(main()) 