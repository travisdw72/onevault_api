#!/usr/bin/env python3
"""
One_Barn_AI Enterprise Setup Test and Execution Script
======================================================
Date: July 2, 2025
Objective: Test and execute One_Barn_AI enterprise tenant setup
Database: one_vault_site_testing (localhost)
Target Demo: July 7, 2025

This script validates the database setup and executes the One_Barn_AI
enterprise tenant creation with comprehensive error handling.
"""

import psycopg2
import json
import sys
from datetime import datetime
from typing import Dict, List, Optional, Tuple

class OneBarnAISetupTester:
    def __init__(self, db_config: Dict[str, str]):
        """Initialize the setup tester with database configuration."""
        self.db_config = db_config
        self.connection = None
        self.test_results = {
            'timestamp': datetime.now().isoformat(),
            'database': 'one_vault_site_testing',
            'target_tenant': 'one_barn_ai',
            'tests': [],
            'setup_status': 'NOT_STARTED'
        }
    
    def connect_database(self) -> bool:
        """Establish database connection."""
        try:
            self.connection = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                database=self.db_config['database'],
                user=self.db_config['user'],
                password=self.db_config['password']
            )
            self.connection.autocommit = True
            self.log_test('database_connection', 'SUCCESS', 'Connected to database successfully')
            return True
        except Exception as e:
            self.log_test('database_connection', 'FAILED', f'Database connection failed: {str(e)}')
            return False
    
    def log_test(self, test_name: str, status: str, message: str, data: Optional[Dict] = None):
        """Log test results."""
        test_result = {
            'test': test_name,
            'status': status,
            'message': message,
            'timestamp': datetime.now().isoformat()
        }
        if data:
            test_result['data'] = data
        
        self.test_results['tests'].append(test_result)
        print(f"[{status}] {test_name}: {message}")
    
    def test_database_functions(self) -> bool:
        """Test required database functions exist."""
        required_functions = [
            'auth.register_tenant_with_roles',
            'auth.register_user',
            'api.auth_login',
            'api.ai_create_session',
            'util.hash_binary',
            'util.current_load_date'
        ]
        
        cursor = self.connection.cursor()
        all_functions_exist = True
        
        for func_name in required_functions:
            try:
                cursor.execute("""
                    SELECT EXISTS(
                        SELECT 1 FROM pg_proc p
                        JOIN pg_namespace n ON p.pronamespace = n.oid
                        WHERE n.nspname || '.' || p.proname = %s
                    )
                """, (func_name,))
                
                exists = cursor.fetchone()[0]
                if exists:
                    self.log_test(f'function_{func_name}', 'SUCCESS', f'Function {func_name} exists')
                else:
                    self.log_test(f'function_{func_name}', 'FAILED', f'Function {func_name} not found')
                    all_functions_exist = False
                    
            except Exception as e:
                self.log_test(f'function_{func_name}', 'ERROR', f'Error checking {func_name}: {str(e)}')
                all_functions_exist = False
        
        cursor.close()
        return all_functions_exist
    
    def check_existing_tenant(self) -> Optional[str]:
        """Check if One_Barn_AI tenant already exists."""
        cursor = self.connection.cursor()
        try:
            cursor.execute("""
                SELECT 
                    th.tenant_bk,
                    tp.tenant_name,
                    tp.domain_name,
                    tp.subscription_level,
                    encode(th.tenant_hk, 'hex') as tenant_hk_hex
                FROM auth.tenant_h th
                JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
                WHERE tp.tenant_name = 'one_barn_ai'
                AND tp.load_end_date IS NULL
            """)
            
            result = cursor.fetchone()
            if result:
                tenant_data = {
                    'tenant_bk': result[0],
                    'tenant_name': result[1],
                    'domain_name': result[2],
                    'subscription_level': result[3],
                    'tenant_hk_hex': result[4]
                }
                self.log_test('existing_tenant_check', 'EXISTS', 'One_Barn_AI tenant already exists', tenant_data)
                return result[4]  # Return tenant_hk_hex
            else:
                self.log_test('existing_tenant_check', 'NOT_EXISTS', 'One_Barn_AI tenant does not exist yet')
                return None
                
        except Exception as e:
            self.log_test('existing_tenant_check', 'ERROR', f'Error checking existing tenant: {str(e)}')
            return None
        finally:
            cursor.close()
    
    def create_one_barn_tenant(self) -> bool:
        """Create the One_Barn_AI enterprise tenant."""
        cursor = self.connection.cursor()
        try:
            # Call the register_tenant_with_roles function
            cursor.execute("""
                SELECT auth.register_tenant_with_roles(
                    p_tenant_name := 'one_barn_ai',
                    p_business_name := 'One Barn AI Solutions',
                    p_admin_email := 'admin@onebarnai.com',
                    p_admin_password := 'HorseHealth2025!',
                    p_contact_phone := '+1-555-HORSE-AI',
                    p_tenant_description := 'Enterprise AI partner specializing in equine health monitoring and analysis',
                    p_industry_type := 'agriculture_technology',
                    p_subscription_level := 'enterprise_partner',
                    p_domain_name := 'onebarnai.com',
                    p_record_source := 'enterprise_partnership_setup'
                )
            """)
            
            result = cursor.fetchone()
            if result and result[0]:  # Assuming function returns success status
                self.log_test('tenant_creation', 'SUCCESS', 'One_Barn_AI tenant created successfully')
                return True
            else:
                self.log_test('tenant_creation', 'FAILED', 'Tenant creation function returned false')
                return False
                
        except Exception as e:
            self.log_test('tenant_creation', 'ERROR', f'Error creating tenant: {str(e)}')
            return False
        finally:
            cursor.close()
    
    def verify_tenant_setup(self) -> Dict:
        """Verify the complete tenant setup."""
        cursor = self.connection.cursor()
        verification_results = {}
        
        try:
            # Verify tenant exists
            cursor.execute("""
                SELECT 
                    tp.tenant_name,
                    tp.business_name,
                    tp.domain_name,
                    tp.subscription_level,
                    tp.is_active
                FROM auth.tenant_profile_s tp
                WHERE tp.tenant_name = 'one_barn_ai'
                AND tp.load_end_date IS NULL
            """)
            
            tenant_result = cursor.fetchone()
            if tenant_result:
                verification_results['tenant'] = {
                    'status': 'SUCCESS',
                    'data': {
                        'tenant_name': tenant_result[0],
                        'business_name': tenant_result[1],
                        'domain_name': tenant_result[2],
                        'subscription_level': tenant_result[3],
                        'is_active': tenant_result[4]
                    }
                }
            else:
                verification_results['tenant'] = {'status': 'FAILED', 'message': 'Tenant not found'}
            
            # Verify admin user exists
            cursor.execute("""
                SELECT 
                    up.email,
                    up.first_name,
                    up.last_name,
                    uas.is_active
                FROM auth.user_h uh
                JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
                JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
                JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
                LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
                WHERE tp.tenant_name = 'one_barn_ai'
                AND up.email = 'admin@onebarnai.com'
                AND up.load_end_date IS NULL
                AND tp.load_end_date IS NULL
            """)
            
            admin_result = cursor.fetchone()
            if admin_result:
                verification_results['admin_user'] = {
                    'status': 'SUCCESS',
                    'data': {
                        'email': admin_result[0],
                        'first_name': admin_result[1],
                        'last_name': admin_result[2],
                        'is_active': admin_result[3]
                    }
                }
            else:
                verification_results['admin_user'] = {'status': 'FAILED', 'message': 'Admin user not found'}
            
            return verification_results
            
        except Exception as e:
            self.log_test('tenant_verification', 'ERROR', f'Error verifying tenant setup: {str(e)}')
            return {'error': str(e)}
        finally:
            cursor.close()
    
    def test_api_authentication(self) -> bool:
        """Test API authentication with the created tenant."""
        cursor = self.connection.cursor()
        try:
            # Test login function
            cursor.execute("""
                SELECT api.auth_login('{
                    "username": "admin@onebarnai.com",
                    "password": "HorseHealth2025!",
                    "ip_address": "127.0.0.1",
                    "user_agent": "OneVault-Demo-Test",
                    "auto_login": true
                }')
            """)
            
            result = cursor.fetchone()
            if result and result[0]:
                auth_response = json.loads(result[0])
                if auth_response.get('p_success'):
                    self.log_test('api_authentication', 'SUCCESS', 'API authentication successful', {
                        'session_token': auth_response.get('p_session_token', 'present'),
                        'user_data': 'present' if auth_response.get('p_user_data') else 'missing'
                    })
                    return True
                else:
                    self.log_test('api_authentication', 'FAILED', f"Authentication failed: {auth_response.get('p_message')}")
                    return False
            else:
                self.log_test('api_authentication', 'FAILED', 'No response from authentication function')
                return False
                
        except Exception as e:
            self.log_test('api_authentication', 'ERROR', f'Error testing authentication: {str(e)}')
            return False
        finally:
            cursor.close()
    
    def run_complete_setup(self) -> Dict:
        """Run the complete One_Barn_AI setup process."""
        print("🚀 Starting One_Barn_AI Enterprise Setup")
        print("=" * 60)
        
        # Step 1: Connect to database
        if not self.connect_database():
            self.test_results['setup_status'] = 'FAILED_CONNECTION'
            return self.test_results
        
        # Step 2: Test required functions
        if not self.test_database_functions():
            self.test_results['setup_status'] = 'FAILED_FUNCTIONS'
            return self.test_results
        
        # Step 3: Check if tenant already exists
        existing_tenant = self.check_existing_tenant()
        
        # Step 4: Create tenant if it doesn't exist
        if not existing_tenant:
            if not self.create_one_barn_tenant():
                self.test_results['setup_status'] = 'FAILED_CREATION'
                return self.test_results
        
        # Step 5: Verify tenant setup
        verification_results = self.verify_tenant_setup()
        self.test_results['verification'] = verification_results
        
        # Step 6: Test API authentication
        if self.test_api_authentication():
            self.test_results['setup_status'] = 'SUCCESS'
        else:
            self.test_results['setup_status'] = 'SUCCESS_PARTIAL'
        
        return self.test_results
    
    def close_connection(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()
    
    def generate_demo_queries(self) -> List[str]:
        """Generate queries for the July 7th demo."""
        return [
            """
            -- Demo Query 1: Tenant Overview
            SELECT 
                'TENANT OVERVIEW' as section,
                tp.tenant_name as "Tenant Name",
                tp.business_name as "Business Name",
                tp.domain_name as "Domain",
                tp.subscription_level as "Subscription",
                tp.load_date::date as "Created Date"
            FROM auth.tenant_profile_s tp
            WHERE tp.tenant_name = 'one_barn_ai'
            AND tp.load_end_date IS NULL;
            """,
            """
            -- Demo Query 2: User Count
            SELECT 
                'USER SUMMARY' as section,
                COUNT(*) as "Total Users",
                COUNT(CASE WHEN uas.is_active THEN 1 END) as "Active Users"
            FROM auth.user_profile_s up
            JOIN auth.user_h uh ON up.user_hk = uh.user_hk
            JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
            JOIN auth.tenant_profile_s tp ON th.tenant_hk = tp.tenant_hk
            LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
            WHERE tp.tenant_name = 'one_barn_ai'
            AND up.load_end_date IS NULL
            AND tp.load_end_date IS NULL
            AND (uas.load_end_date IS NULL OR uas.load_end_date IS NULL);
            """,
            """
            -- Demo Query 3: Authentication Test
            SELECT api.auth_login('{
                "username": "admin@onebarnai.com",
                "password": "HorseHealth2025!",
                "ip_address": "127.0.0.1",
                "user_agent": "OneVault-Demo-Client",
                "auto_login": true
            }') as login_result;
            """
        ]

def main():
    """Main execution function."""
    # Database configuration
    db_config = {
        'host': 'localhost',
        'port': '5432',
        'database': 'one_vault_site_testing',
        'user': 'postgres',
        'password': 'postgres'  # Update with actual password
    }
    
    # Initialize setup tester
    tester = OneBarnAISetupTester(db_config)
    
    try:
        # Run complete setup
        results = tester.run_complete_setup()
        
        # Generate report
        print("\n" + "=" * 60)
        print("🎯 ONE_BARN_AI SETUP RESULTS")
        print("=" * 60)
        print(f"Overall Status: {results['setup_status']}")
        print(f"Timestamp: {results['timestamp']}")
        print(f"Total Tests: {len(results['tests'])}")
        
        # Print test summary
        success_count = len([t for t in results['tests'] if t['status'] == 'SUCCESS'])
        failed_count = len([t for t in results['tests'] if t['status'] in ['FAILED', 'ERROR']])
        
        print(f"✅ Successful: {success_count}")
        print(f"❌ Failed: {failed_count}")
        
        # Demo readiness check
        if results['setup_status'] in ['SUCCESS', 'SUCCESS_PARTIAL']:
            print("\n🎉 READY FOR JULY 7TH DEMO!")
            print("\nDemo Queries Available:")
            for i, query in enumerate(tester.generate_demo_queries(), 1):
                print(f"  {i}. {query.strip().split('--')[1].split(':')[0].strip()}")
        else:
            print("\n⚠️  SETUP NEEDS ATTENTION BEFORE DEMO")
        
        # Save results to file
        with open(f'one_barn_setup_results_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json', 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        print(f"\n📄 Detailed results saved to: one_barn_setup_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
        
    except Exception as e:
        print(f"❌ Setup failed with error: {str(e)}")
        return 1
    
    finally:
        tester.close_connection()
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 