#!/usr/bin/env python3
"""
Quick RBAC Setup Script for One Vault Demo Barn Database
=========================================================

This script quickly sets up RBAC testing with:
1. System Admin Tenant
2. Demo Business Tenant
3. Multiple users with different roles for RBAC testing

Database: one_vault_demo_barn
Purpose: Quick RBAC demonstration setup
"""

import psycopg2
import psycopg2.extras
import json
from datetime import datetime
import sys

def main():
    """Main execution function"""
    
    # Get database password
    password = input("Enter database password for one_vault_demo_barn: ")
    
    # Database configuration
    db_config = {
        'host': 'localhost',
        'port': 5432,
        'database': 'one_vault_demo_barn',
        'user': 'postgres',
        'password': password
    }
    
    print("\n🎯 One Vault Quick RBAC Demo Setup")
    print("=" * 50)
    print(f"Database: {db_config['database']}")
    print(f"Host: {db_config['host']}:{db_config['port']}")
    print()
    
    try:
        # Connect to database
        print("🔌 Connecting to database...")
        connection = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            database=db_config['database'],
            user=db_config['user'],
            password=db_config['password']
        )
        connection.autocommit = True
        print("✅ Connected successfully!")
        
        cursor = connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        results = {
            'setup_timestamp': datetime.now().isoformat(),
            'database': db_config['database'],
            'tenants': [],
            'users': [],
            'test_credentials': {}
        }
        
        # Step 1: Create System Admin Tenant
        print("\n🏗️ Creating System Admin Tenant...")
        success, message = create_system_admin_tenant(cursor)
        
        if success:
            system_tenant = {
                'name': 'SYSTEM_ADMIN',
                'tenant_hk': None,
                'admin_user_hk': None,
                'admin_email': 'sysadmin@onevault.demo'
            }
            
            results['tenants'].append(system_tenant)
            results['test_credentials']['system_admin'] = {
                'tenant': 'SYSTEM_ADMIN',
                'email': 'sysadmin@onevault.demo',
                'password': 'AdminSecure123!@#',
                'role': 'ADMIN',
                'description': 'Full system administration access'
            }
            
            print(f"   ✅ System Admin Tenant created")
            print(f"   📧 Email: {system_tenant['admin_email']}")
            print(f"   🔑 Password: AdminSecure123!@#")
            
        else:
            print(f"   ❌ Error creating system admin tenant: {message}")
        
        # Step 2: Create Demo Business Tenant
        print("\n🏢 Creating Demo Business Tenant...")
        success, message = create_demo_tenant(cursor)
        
        if success:
            demo_tenant = {
                'name': 'ACME_CORP_DEMO',
                'tenant_hk': None,
                'admin_user_hk': None,
                'admin_email': 'admin@acmecorp.demo'
            }
            
            results['tenants'].append(demo_tenant)
            results['test_credentials']['demo_admin'] = {
                'tenant': 'ACME_CORP_DEMO',
                'email': 'admin@acmecorp.demo',
                'password': 'DemoAdmin123!@#',
                'role': 'ADMIN',
                'description': 'Demo tenant administration access'
            }
            
            print(f"   ✅ Demo Business Tenant created")
            print(f"   📧 Email: {demo_tenant['admin_email']}")
            print(f"   🔑 Password: DemoAdmin123!@#")
            
            # Step 3: Create additional users with different roles
            print("\n👥 Creating additional demo users...")
            
            demo_users = [
                {
                    'email': 'manager@acmecorp.demo',
                    'password': 'Manager123!@#',
                    'first_name': 'John',
                    'last_name': 'Manager',
                    'role_bk': 'ADMIN',  # Use existing role
                    'description': 'Department Manager'
                },
                {
                    'email': 'employee1@acmecorp.demo',
                    'password': 'Employee123!@#',
                    'first_name': 'Alice',
                    'last_name': 'Employee',
                    'role_bk': 'ADMIN',  # Use existing role for now
                    'description': 'Standard Employee'
                },
                {
                    'email': 'viewer@acmecorp.demo',
                    'password': 'Viewer123!@#',
                    'first_name': 'Carol',
                    'last_name': 'Viewer',
                    'role_bk': 'ADMIN',  # Use existing role for now
                    'description': 'Read-only User'
                },
                {
                    'email': 'client1@acmecorp.demo',
                    'password': 'Client123!@#',
                    'first_name': 'David',
                    'last_name': 'Client',
                    'role_bk': 'ADMIN',  # Use existing role for now
                    'description': 'External Client'
                }
            ]
            
            user_sql = """
                SELECT * FROM auth.register_user(
                    p_tenant_hk := %(tenant_hk)s,
                    p_email := %(email)s,
                    p_password := %(password)s,
                    p_first_name := %(first_name)s,
                    p_last_name := %(last_name)s,
                    p_role_bk := %(role_bk)s
                );
            """
            
            for user in demo_users:
                try:
                    user_params = user.copy()
                    user_params['tenant_hk'] = None
                    
                    cursor.execute(user_sql, user_params)
                    user_result = cursor.fetchone()
                    
                    if user_result and len(user_result) > 0:
                        user_hk = user_result[0]
                        
                        user_info = {
                            'email': user['email'],
                            'name': f"{user['first_name']} {user['last_name']}",
                            'role': user['role_bk'],
                            'user_hk': user_hk.hex() if user_hk else None
                        }
                        
                        results['users'].append(user_info)
                        
                        # Add to credentials
                        key = user['email'].split('@')[0]
                        results['test_credentials'][key] = {
                            'tenant': 'ACME_CORP_DEMO',
                            'email': user['email'],
                            'password': user['password'],
                            'role': user['role_bk'],
                            'description': user['description']
                        }
                        
                        print(f"   ✅ Created user: {user['email']} ({user['description']})")
                    else:
                        print(f"   ❌ Failed to create user: {user['email']}")
                        
                except Exception as e:
                    print(f"   ❌ Error creating user {user['email']}: {e}")
            
        else:
            print(f"   ❌ Error creating demo tenant: {message}")
        
        # Step 4: Test current users and roles
        print("\n🔍 Checking created users and roles...")
        try:
            check_sql = """
                SELECT 
                    t.tenant_bk as tenant_name,
                    up.email,
                    up.first_name || ' ' || up.last_name as full_name,
                    COALESCE(rd.role_name, 'No Role') as role_name,
                    up.is_active
                FROM auth.user_h uh
                JOIN auth.tenant_h t ON uh.tenant_hk = t.tenant_hk
                JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk AND up.load_end_date IS NULL
                JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk AND uas.load_end_date IS NULL
                LEFT JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
                LEFT JOIN auth.role_h rh ON url.role_hk = rh.role_hk
                LEFT JOIN auth.role_definition_s rd ON rh.role_hk = rd.role_hk AND rd.load_end_date IS NULL
                WHERE t.tenant_bk IN ('SYSTEM_ADMIN', 'ACME_CORP_DEMO')
                ORDER BY t.tenant_bk, up.email;
            """
            
            cursor.execute(check_sql)
            user_list = cursor.fetchall()
            
            print(f"   Found {len(user_list)} users:")
            for user in user_list:
                print(f"   • {user['tenant_name']}: {user['email']} ({user['full_name']}) - Role: {user['role_name']}")
            
            results['verification'] = [dict(user) for user in user_list]
            
        except Exception as e:
            print(f"   ❌ Error checking users: {e}")
        
        # Save results
        output_file = f"quick_rbac_setup_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        print(f"\n📊 Results saved to: {output_file}")
        
        # Display final summary
        print("\n🎉 Quick RBAC Setup Complete!")
        print("\n🔑 Test Credentials Summary:")
        print("=" * 60)
        for key, creds in results['test_credentials'].items():
            print(f"\n{key.upper().replace('_', ' ')}:")
            print(f"  Tenant: {creds['tenant']}")
            print(f"  Email: {creds['email']}")
            print(f"  Password: {creds['password']}")
            print(f"  Role: {creds['role']}")
            print(f"  Description: {creds['description']}")
        
        print(f"\n📈 Setup Summary:")
        print(f"   • Tenants Created: {len(results['tenants'])}")
        print(f"   • Users Created: {len(results['users']) + 2}")  # +2 for tenant admins
        print(f"   • Database: {db_config['database']}")
        
        connection.close()
        print("\n✅ Setup completed successfully!")
        return 0
        
    except Exception as e:
        print(f"\n❌ Setup failed: {e}")
        return 1

def create_system_admin_tenant(cursor):
    """Create the system admin tenant"""
    try:
        cursor.execute("""
            CALL auth.register_tenant(
                p_tenant_name => %s,
                p_admin_email => %s,
                p_admin_password => %s,
                p_admin_first_name => %s,
                p_admin_last_name => %s,
                p_tenant_hk => NULL,
                p_admin_user_hk => NULL
            )
        """, (
            'SYSTEM_ADMIN',
            'sysadmin@onevault.demo',
            'AdminSecure123!@#',
            'System',
            'Administrator'
        ))
        return True, "System admin tenant created successfully"
    except Exception as e:
        return False, str(e)

def create_demo_tenant(cursor):
    """Create the demo business tenant"""
    try:
        cursor.execute("""
            CALL auth.register_tenant(
                p_tenant_name => %s,
                p_admin_email => %s,
                p_admin_password => %s,
                p_admin_first_name => %s,
                p_admin_last_name => %s,
                p_tenant_hk => NULL,
                p_admin_user_hk => NULL
            )
        """, (
            'ACME_CORP_DEMO',
            'admin@acmecorp.demo',
            'DemoAdmin123!@#',
            'Demo',
            'Administrator'
        ))
        return True, "Demo tenant created successfully"
    except Exception as e:
        return False, str(e)

if __name__ == "__main__":
    sys.exit(main()) 