#!/usr/bin/env python3
"""
Extended RBAC Demo Setup Script for One Vault Demo Barn Database
================================================================

This script sets up a comprehensive RBAC testing scenario with:
1. System Admin Tenant
2. Regular Demo Tenant with multiple user roles
3. Multiple demo users with different access levels
4. Comprehensive role-based access control testing

Database: one_vault_demo_barn
Purpose: Complete RBAC demonstration and testing
"""

import psycopg2
import psycopg2.extras
import json
from datetime import datetime
import sys
import logging
from typing import Dict, List, Optional, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'rbac_demo_extended_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class ExtendedRBACDemoSetup:
    """Extended RBAC Demo Setup and Testing Class"""
    
    def __init__(self, db_config: Dict[str, str]):
        """Initialize with database configuration"""
        self.db_config = db_config
        self.connection = None
        self.results = {
            'system_admin_tenant': {},
            'demo_tenant': {},
            'roles_created': [],
            'users_created': [],
            'rbac_tests': [],
            'setup_summary': {}
        }
    
    def connect_database(self) -> bool:
        """Establish database connection"""
        try:
            self.connection = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                database=self.db_config['database'],
                user=self.db_config['user'],
                password=self.db_config['password']
            )
            self.connection.autocommit = True
            logger.info(f"✅ Connected to database: {self.db_config['database']}")
            return True
        except Exception as e:
            logger.error(f"❌ Database connection failed: {e}")
            return False
    
    def setup_system_admin_tenant(self) -> Dict:
        """Set up the system admin tenant"""
        logger.info("🏗️ Setting up System Admin Tenant...")
        
        system_admin_config = {
            'tenant_name': 'SYSTEM_ADMIN',
            'admin_email': 'sysadmin@onevault.demo',
            'admin_password': 'AdminSecure123!@#',
            'admin_first_name': 'System',
            'admin_last_name': 'Administrator'
        }
        
        try:
            cursor = self.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            call_sql = """
                SELECT * FROM auth.register_tenant(
                    p_tenant_name := %(tenant_name)s,
                    p_admin_email := %(admin_email)s,
                    p_admin_password := %(admin_password)s,
                    p_admin_first_name := %(admin_first_name)s,
                    p_admin_last_name := %(admin_last_name)s
                );
            """
            
            cursor.execute(call_sql, system_admin_config)
            result = cursor.fetchone()
            
            if result and len(result) >= 2:
                tenant_hk = result[0]
                admin_user_hk = result[1]
                
                system_result = {
                    'success': True,
                    'tenant_hk': tenant_hk.hex() if tenant_hk else None,
                    'admin_user_hk': admin_user_hk.hex() if admin_user_hk else None,
                    'config': system_admin_config
                }
                
                logger.info(f"✅ System Admin Tenant created successfully")
                logger.info(f"   Tenant HK: {system_result['tenant_hk']}")
                
                self.results['system_admin_tenant'] = system_result
                return system_result
            else:
                raise Exception("Invalid result from register_tenant")
                
        except Exception as e:
            logger.error(f"❌ Failed to create system admin tenant: {e}")
            return {'success': False, 'error': str(e)}
    
    def setup_demo_tenant(self) -> Dict:
        """Set up the demo business tenant"""
        logger.info("🏢 Setting up Demo Business Tenant...")
        
        demo_tenant_config = {
            'tenant_name': 'ACME_CORP_DEMO',
            'admin_email': 'admin@acmecorp.demo',
            'admin_password': 'DemoAdmin123!@#',
            'admin_first_name': 'Jane',
            'admin_last_name': 'BusinessAdmin'
        }
        
        try:
            cursor = self.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            call_sql = """
                SELECT * FROM auth.register_tenant(
                    p_tenant_name := %(tenant_name)s,
                    p_admin_email := %(admin_email)s,
                    p_admin_password := %(admin_password)s,
                    p_admin_first_name := %(admin_first_name)s,
                    p_admin_last_name := %(admin_last_name)s
                );
            """
            
            cursor.execute(call_sql, demo_tenant_config)
            result = cursor.fetchone()
            
            if result and len(result) >= 2:
                tenant_hk = result[0]
                admin_user_hk = result[1]
                
                demo_result = {
                    'success': True,
                    'tenant_hk': tenant_hk.hex() if tenant_hk else None,
                    'admin_user_hk': admin_user_hk.hex() if admin_user_hk else None,
                    'tenant_hk_bytes': tenant_hk,  # Keep bytes for further operations
                    'config': demo_tenant_config
                }
                
                logger.info(f"✅ Demo Business Tenant created successfully")
                logger.info(f"   Tenant HK: {demo_result['tenant_hk']}")
                
                self.results['demo_tenant'] = demo_result
                return demo_result
            else:
                raise Exception("Invalid result from register_tenant")
                
        except Exception as e:
            logger.error(f"❌ Failed to create demo tenant: {e}")
            return {'success': False, 'error': str(e)}
    
    def create_demo_roles(self, tenant_hk: bytes) -> List[Dict]:
        """Create demo roles for RBAC testing"""
        logger.info("🎭 Creating demo roles...")
        
        # Define roles with different access levels
        roles_config = [
            {
                'role_bk': 'MANAGER',
                'role_name': 'Manager',
                'role_description': 'Management access with reporting capabilities',
                'permissions': ['CREATE', 'READ', 'UPDATE', 'VIEW_REPORTS'],
                'access_level': 'MANAGEMENT'
            },
            {
                'role_bk': 'EMPLOYEE',
                'role_name': 'Employee',
                'role_description': 'Standard employee access',
                'permissions': ['CREATE', 'READ', 'UPDATE'],
                'access_level': 'STANDARD'
            },
            {
                'role_bk': 'VIEWER',
                'role_name': 'Viewer',
                'role_description': 'Read-only access for monitoring',
                'permissions': ['READ'],
                'access_level': 'LIMITED'
            },
            {
                'role_bk': 'CLIENT',
                'role_name': 'Client',
                'role_description': 'Client/Patient access to own data only',
                'permissions': ['READ'],
                'access_level': 'PERSONAL'
            }
        ]
        
        created_roles = []
        
        try:
            cursor = self.connection.cursor()
            
            for role_config in roles_config:
                try:
                    # Generate role hash key
                    role_hk_sql = "SELECT util.hash_binary(%(role_bk)s || %(tenant_hk)s)"
                    cursor.execute(role_hk_sql, {
                        'role_bk': role_config['role_bk'],
                        'tenant_hk': tenant_hk.hex()
                    })
                    role_hk = cursor.fetchone()[0]
                    
                    # Insert role hub
                    hub_sql = """
                        INSERT INTO auth.role_h (role_hk, role_bk, tenant_hk, load_date, record_source)
                        VALUES (%(role_hk)s, %(role_bk)s, %(tenant_hk)s, util.current_load_date(), 'RBAC_DEMO_SETUP')
                        ON CONFLICT (role_hk) DO NOTHING;
                    """
                    cursor.execute(hub_sql, {
                        'role_hk': role_hk,
                        'role_bk': role_config['role_bk'],
                        'tenant_hk': tenant_hk
                    })
                    
                    # Generate hash diff for satellite
                    hash_diff_input = f"{role_config['role_name']}{role_config['role_description']}{role_config['access_level']}"
                    hash_diff_sql = "SELECT util.hash_binary(%(input)s)"
                    cursor.execute(hash_diff_sql, {'input': hash_diff_input})
                    hash_diff = cursor.fetchone()[0]
                    
                    # Insert role definition satellite
                    sat_sql = """
                        INSERT INTO auth.role_definition_s (
                            role_hk, load_date, load_end_date, hash_diff,
                            role_name, role_description, permissions, access_level,
                            is_active, created_by, record_source
                        ) VALUES (
                            %(role_hk)s, util.current_load_date(), NULL, %(hash_diff)s,
                            %(role_name)s, %(role_description)s, %(permissions)s, %(access_level)s,
                            true, 'RBAC_DEMO_SETUP', 'RBAC_DEMO_SETUP'
                        );
                    """
                    cursor.execute(sat_sql, {
                        'role_hk': role_hk,
                        'hash_diff': hash_diff,
                        'role_name': role_config['role_name'],
                        'role_description': role_config['role_description'],
                        'permissions': role_config['permissions'],
                        'access_level': role_config['access_level']
                    })
                    
                    role_result = {
                        'success': True,
                        'role_hk': role_hk.hex(),
                        'role_bk': role_config['role_bk'],
                        'role_name': role_config['role_name'],
                        'access_level': role_config['access_level']
                    }
                    
                    created_roles.append(role_result)
                    logger.info(f"   ✅ Created role: {role_config['role_name']} ({role_config['role_bk']})")
                    
                except Exception as e:
                    logger.error(f"   ❌ Failed to create role {role_config['role_bk']}: {e}")
                    created_roles.append({
                        'success': False,
                        'role_bk': role_config['role_bk'],
                        'error': str(e)
                    })
            
            logger.info(f"✅ Created {len([r for r in created_roles if r.get('success')])} roles successfully")
            self.results['roles_created'] = created_roles
            return created_roles
            
        except Exception as e:
            logger.error(f"❌ Failed to create demo roles: {e}")
            return []
    
    def create_demo_users(self, tenant_hk: bytes) -> List[Dict]:
        """Create demo users with different roles"""
        logger.info("👥 Creating demo users...")
        
        demo_users = [
            {
                'email': 'manager@acmecorp.demo',
                'password': 'Manager123!@#',
                'first_name': 'John',
                'last_name': 'Manager',
                'role_bk': 'MANAGER',
                'description': 'Department Manager'
            },
            {
                'email': 'employee1@acmecorp.demo',
                'password': 'Employee123!@#',
                'first_name': 'Alice',
                'last_name': 'Employee',
                'role_bk': 'EMPLOYEE',
                'description': 'Standard Employee'
            },
            {
                'email': 'employee2@acmecorp.demo',
                'password': 'Employee456!@#',
                'first_name': 'Bob',
                'last_name': 'Worker',
                'role_bk': 'EMPLOYEE',
                'description': 'Standard Employee'
            },
            {
                'email': 'viewer@acmecorp.demo',
                'password': 'Viewer123!@#',
                'first_name': 'Carol',
                'last_name': 'Viewer',
                'role_bk': 'VIEWER',
                'description': 'Read-only User'
            },
            {
                'email': 'client1@acmecorp.demo',
                'password': 'Client123!@#',
                'first_name': 'David',
                'last_name': 'ClientUser',
                'role_bk': 'CLIENT',
                'description': 'External Client'
            },
            {
                'email': 'patient1@acmecorp.demo',
                'password': 'Patient123!@#',
                'first_name': 'Emma',
                'last_name': 'PatientUser',
                'role_bk': 'CLIENT',
                'description': 'Healthcare Patient'
            }
        ]
        
        created_users = []
        
        try:
            cursor = self.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            for user in demo_users:
                try:
                    call_sql = """
                        SELECT * FROM auth.register_user(
                            p_tenant_hk := %(tenant_hk)s,
                            p_email := %(email)s,
                            p_password := %(password)s,
                            p_first_name := %(first_name)s,
                            p_last_name := %(last_name)s,
                            p_role_bk := %(role_bk)s
                        );
                    """
                    
                    user_params = user.copy()
                    user_params['tenant_hk'] = tenant_hk
                    
                    cursor.execute(call_sql, user_params)
                    result = cursor.fetchone()
                    
                    if result and len(result) > 0:
                        user_hk = result[0]
                        
                        user_result = {
                            'success': True,
                            'user_hk': user_hk.hex() if user_hk else None,
                            'email': user['email'],
                            'name': f"{user['first_name']} {user['last_name']}",
                            'role': user['role_bk'],
                            'description': user['description'],
                            'password': user['password']  # Include for demo purposes
                        }
                        
                        created_users.append(user_result)
                        logger.info(f"   ✅ Created user: {user['email']} ({user['role_bk']})")
                    else:
                        raise Exception("No result from register_user")
                    
                except Exception as e:
                    logger.error(f"   ❌ Failed to create user {user['email']}: {e}")
                    created_users.append({
                        'success': False,
                        'email': user['email'],
                        'error': str(e)
                    })
            
            logger.info(f"✅ Created {len([u for u in created_users if u.get('success')])} users successfully")
            self.results['users_created'] = created_users
            return created_users
            
        except Exception as e:
            logger.error(f"❌ Failed to create demo users: {e}")
            return []
    
    def test_rbac_permissions(self, tenant_hk: bytes) -> List[Dict]:
        """Test RBAC permissions for different roles"""
        logger.info("🔒 Testing RBAC permissions...")
        
        test_results = []
        
        try:
            cursor = self.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Test 1: List all users and their roles
            test_sql = """
                SELECT 
                    up.email,
                    up.first_name || ' ' || up.last_name as full_name,
                    COALESCE(rd.role_name, 'No Role') as role_name,
                    COALESCE(rd.access_level, 'NONE') as access_level,
                    COALESCE(rd.permissions, ARRAY[]::TEXT[]) as permissions,
                    uas.last_login_date
                FROM auth.user_h uh
                JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk AND up.load_end_date IS NULL
                JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk AND uas.load_end_date IS NULL
                LEFT JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
                LEFT JOIN auth.role_h rh ON url.role_hk = rh.role_hk
                LEFT JOIN auth.role_definition_s rd ON rh.role_hk = rd.role_hk AND rd.load_end_date IS NULL
                WHERE uh.tenant_hk = %(tenant_hk)s
                ORDER BY rd.access_level DESC NULLS LAST, up.email;
            """
            
            cursor.execute(test_sql, {'tenant_hk': tenant_hk})
            users_with_roles = cursor.fetchall()
            
            test_results.append({
                'test_name': 'User Role Assignment Verification',
                'success': True,
                'data': [dict(row) for row in users_with_roles],
                'summary': f"Found {len(users_with_roles)} users with assigned roles"
            })
            
            # Test 2: Role hierarchy verification
            hierarchy_sql = """
                SELECT 
                    rd.role_name,
                    rd.access_level,
                    rd.permissions,
                    COUNT(url.user_hk) as user_count
                FROM auth.role_h rh
                JOIN auth.role_definition_s rd ON rh.role_hk = rd.role_hk AND rd.load_end_date IS NULL
                LEFT JOIN auth.user_role_l url ON rh.role_hk = url.role_hk
                WHERE rh.tenant_hk = %(tenant_hk)s
                GROUP BY rd.role_name, rd.access_level, rd.permissions
                ORDER BY 
                    CASE rd.access_level 
                        WHEN 'FULL' THEN 1
                        WHEN 'MANAGEMENT' THEN 2
                        WHEN 'STANDARD' THEN 3
                        WHEN 'LIMITED' THEN 4
                        WHEN 'PERSONAL' THEN 5
                        ELSE 6
                    END;
            """
            
            cursor.execute(hierarchy_sql, {'tenant_hk': tenant_hk})
            role_hierarchy = cursor.fetchall()
            
            test_results.append({
                'test_name': 'Role Hierarchy Verification',
                'success': True,
                'data': [dict(row) for row in role_hierarchy],
                'summary': f"Verified {len(role_hierarchy)} roles in hierarchy"
            })
            
            # Test 3: Permission matrix
            permissions_sql = """
                SELECT 
                    rd.role_name,
                    rd.access_level,
                    CASE 
                        WHEN 'CREATE' = ANY(rd.permissions) THEN 'Yes' 
                        ELSE 'No' 
                    END as can_create,
                    CASE 
                        WHEN 'READ' = ANY(rd.permissions) THEN 'Yes' 
                        ELSE 'No' 
                    END as can_read,
                    CASE 
                        WHEN 'UPDATE' = ANY(rd.permissions) THEN 'Yes' 
                        ELSE 'No' 
                    END as can_update,
                    CASE 
                        WHEN 'DELETE' = ANY(rd.permissions) THEN 'Yes' 
                        ELSE 'No' 
                    END as can_delete,
                    CASE 
                        WHEN 'MANAGE_USERS' = ANY(rd.permissions) THEN 'Yes' 
                        ELSE 'No' 
                    END as can_manage_users,
                    CASE 
                        WHEN 'VIEW_REPORTS' = ANY(rd.permissions) THEN 'Yes' 
                        ELSE 'No' 
                    END as can_view_reports
                FROM auth.role_h rh
                JOIN auth.role_definition_s rd ON rh.role_hk = rd.role_hk AND rd.load_end_date IS NULL
                WHERE rh.tenant_hk = %(tenant_hk)s
                ORDER BY 
                    CASE rd.access_level 
                        WHEN 'FULL' THEN 1
                        WHEN 'MANAGEMENT' THEN 2
                        WHEN 'STANDARD' THEN 3
                        WHEN 'LIMITED' THEN 4
                        WHEN 'PERSONAL' THEN 5
                        ELSE 6
                    END;
            """
            
            cursor.execute(permissions_sql, {'tenant_hk': tenant_hk})
            permission_matrix = cursor.fetchall()
            
            test_results.append({
                'test_name': 'Permission Matrix',
                'success': True,
                'data': [dict(row) for row in permission_matrix],
                'summary': f"Generated permission matrix for {len(permission_matrix)} roles"
            })
            
            logger.info(f"✅ Completed {len(test_results)} RBAC tests successfully")
            self.results['rbac_tests'] = test_results
            return test_results
            
        except Exception as e:
            logger.error(f"❌ RBAC testing failed: {e}")
            return [{'test_name': 'RBAC Testing', 'success': False, 'error': str(e)}]
    
    def generate_credentials_summary(self) -> Dict:
        """Generate comprehensive credentials summary"""
        logger.info("🔑 Generating test credentials summary...")
        
        credentials = {}
        
        # Add system admin
        if 'system_admin_tenant' in self.results and self.results['system_admin_tenant'].get('success'):
            credentials['system_admin'] = {
                'tenant': self.results['system_admin_tenant']['config']['tenant_name'],
                'email': self.results['system_admin_tenant']['config']['admin_email'],
                'password': self.results['system_admin_tenant']['config']['admin_password'],
                'role': 'ADMIN',
                'description': 'Full system administration access'
            }
        
        # Add demo tenant admin
        if 'demo_tenant' in self.results and self.results['demo_tenant'].get('success'):
            credentials['demo_tenant_admin'] = {
                'tenant': self.results['demo_tenant']['config']['tenant_name'],
                'email': self.results['demo_tenant']['config']['admin_email'],
                'password': self.results['demo_tenant']['config']['admin_password'],
                'role': 'ADMIN',
                'description': 'Demo tenant administration access'
            }
        
        # Add created users
        for user in self.results.get('users_created', []):
            if user.get('success'):
                key = f"{user['role'].lower()}_{user['email'].split('@')[0]}"
                credentials[key] = {
                    'tenant': 'ACME_CORP_DEMO',
                    'email': user['email'],
                    'password': user['password'],
                    'role': user['role'],
                    'description': user['description']
                }
        
        return credentials
    
    def run_complete_setup(self) -> Dict:
        """Run complete extended RBAC demo setup"""
        logger.info("🚀 Starting complete extended RBAC demo setup...")
        
        if not self.connect_database():
            return {'success': False, 'error': 'Database connection failed'}
        
        try:
            # Step 1: Setup System Admin Tenant
            system_result = self.setup_system_admin_tenant()
            if not system_result.get('success'):
                return {'success': False, 'error': f"System admin tenant setup failed: {system_result.get('error')}"}
            
            # Step 2: Setup Demo Business Tenant
            demo_result = self.setup_demo_tenant()
            if not demo_result.get('success'):
                return {'success': False, 'error': f"Demo tenant setup failed: {demo_result.get('error')}"}
            
            # Get tenant HK for subsequent operations
            demo_tenant_hk = demo_result['tenant_hk_bytes']
            
            # Step 3: Create Demo Roles
            roles = self.create_demo_roles(demo_tenant_hk)
            if not any(r.get('success') for r in roles):
                return {'success': False, 'error': 'Demo roles creation failed'}
            
            # Step 4: Create Demo Users
            users = self.create_demo_users(demo_tenant_hk)
            if not any(u.get('success') for u in users):
                return {'success': False, 'error': 'Demo users creation failed'}
            
            # Step 5: Test RBAC Permissions
            rbac_tests = self.test_rbac_permissions(demo_tenant_hk)
            
            # Step 6: Generate credentials summary
            credentials = self.generate_credentials_summary()
            
            # Compile final results
            final_results = {
                'success': True,
                'setup_timestamp': datetime.now().isoformat(),
                'database': self.db_config['database'],
                'system_admin_tenant': system_result,
                'demo_tenant': demo_result,
                'roles_created': len([r for r in roles if r.get('success')]),
                'users_created': len([u for u in users if u.get('success')]),
                'rbac_tests_passed': len([t for t in rbac_tests if t.get('success')]),
                'test_credentials': credentials,
                'detailed_results': self.results
            }
            
            logger.info("🎉 Extended RBAC Demo Setup completed successfully!")
            logger.info(f"✅ System Admin Tenant: {system_result['config']['tenant_name']}")
            logger.info(f"✅ Demo Tenant: {demo_result['config']['tenant_name']}")
            logger.info(f"✅ Roles Created: {final_results['roles_created']}")
            logger.info(f"✅ Users Created: {final_results['users_created']}")
            logger.info(f"✅ RBAC Tests Passed: {final_results['rbac_tests_passed']}")
            
            return final_results
            
        except Exception as e:
            logger.error(f"❌ Extended setup failed: {e}")
            return {'success': False, 'error': str(e)}
        
        finally:
            if self.connection:
                self.connection.close()

def main():
    """Main execution function"""
    # Database configuration for one_vault_demo_barn
    db_config = {
        'host': 'localhost',
        'port': 5432,
        'database': 'one_vault_demo_barn',
        'user': 'postgres',
        'password': input("Enter database password: ")
    }
    
    print("🎯 One Vault Extended RBAC Demo Setup")
    print("=" * 60)
    print(f"Database: {db_config['database']}")
    print(f"Host: {db_config['host']}:{db_config['port']}")
    print()
    
    # Initialize and run setup
    setup = ExtendedRBACDemoSetup(db_config)
    results = setup.run_complete_setup()
    
    # Save results to file
    output_file = f"rbac_demo_extended_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print(f"\n📊 Detailed results saved to: {output_file}")
    
    if results.get('success'):
        print("\n🎉 Extended RBAC Demo Setup Complete!")
        print("\n📈 Setup Summary:")
        print(f"   • System Admin Tenant: ✅")
        print(f"   • Demo Business Tenant: ✅")
        print(f"   • Roles Created: {results['roles_created']}")
        print(f"   • Users Created: {results['users_created']}")
        print(f"   • RBAC Tests Passed: {results['rbac_tests_passed']}")
        
        print("\n🔑 Test Credentials:")
        print("-" * 50)
        for role_key, creds in results['test_credentials'].items():
            print(f"{role_key.upper().replace('_', ' ')}:")
            print(f"  Tenant: {creds['tenant']}")
            print(f"  Email: {creds['email']}")
            print(f"  Password: {creds['password']}")
            print(f"  Role: {creds['role']}")
            print(f"  Description: {creds['description']}")
            print()
            
        print("🧪 RBAC Testing Results:")
        print("-" * 30)
        for test in results['detailed_results'].get('rbac_tests', []):
            status = "✅" if test.get('success') else "❌"
            print(f"{status} {test['test_name']}: {test.get('summary', 'N/A')}")
            
    else:
        print(f"\n❌ Setup failed: {results.get('error')}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 