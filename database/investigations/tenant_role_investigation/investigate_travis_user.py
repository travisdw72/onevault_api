#!/usr/bin/env python3
"""
Tenant Role Investigation Script
================================

This script investigates why travis@theonespaoregon.com doesn't have a role
and analyzes the tenant registration process to identify gaps.

Investigation Goals:
1. Check current state of travis@theonespaoregon.com user
2. Identify why no role was created during tenant registration
3. Compare current auth.register_tenant with historical versions
4. Create appropriate roles for the user
"""

import psycopg2
import json
from datetime import datetime
import getpass
import sys
import os

# Database connection configuration
DB_CONFIG = {
    'host': 'localhost',
    'database': 'one_vault_dev',
    'user': 'postgres',  # Will be prompted for password
    'port': 5432
}

class TenantRoleInvestigator:
    def __init__(self):
        self.conn = None
        self.investigation_results = {
            'timestamp': datetime.now().isoformat(),
            'target_user': 'travis@theonespaoregon.com',
            'findings': {},
            'recommendations': []
        }
    
    def connect_to_database(self):
        """Connect to the database with password prompt"""
        password = getpass.getpass(f"Enter password for PostgreSQL user '{DB_CONFIG['user']}': ")
        
        try:
            self.conn = psycopg2.connect(
                host=DB_CONFIG['host'],
                database=DB_CONFIG['database'],
                user=DB_CONFIG['user'],
                password=password,
                port=DB_CONFIG['port']
            )
            print(f"✅ Connected to database: {DB_CONFIG['database']}")
            return True
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def execute_query(self, query, params=None):
        """Execute a query and return results"""
        try:
            cursor = self.conn.cursor()
            cursor.execute(query, params)
            if cursor.description:
                columns = [desc[0] for desc in cursor.description]
                rows = cursor.fetchall()
                return [dict(zip(columns, row)) for row in rows]
            return []
        except Exception as e:
            print(f"❌ Query execution failed: {e}")
            return None
    
    def investigate_travis_user(self):
        """Investigate the current state of travis@theonespaoregon.com"""
        print("\n" + "="*60)
        print("🔍 INVESTIGATING TRAVIS USER")
        print("="*60)
        
        # Check if user exists
        user_query = """
        SELECT 
            encode(uh.user_hk, 'hex') as user_hk,
            uh.user_bk,
            encode(uh.tenant_hk, 'hex') as tenant_hk,
            ups.first_name,
            ups.last_name,
            ups.email,
            ups.is_active,
            ups.created_date,
            th.tenant_bk,
            tps.tenant_name
        FROM auth.user_h uh
        JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
        JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
        JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
        WHERE ups.email = %s
        AND ups.load_end_date IS NULL
        AND tps.load_end_date IS NULL
        ORDER BY ups.load_date DESC
        """
        
        user_results = self.execute_query(user_query, ('travis@theonespaoregon.com',))
        
        if not user_results:
            print("❌ User travis@theonespaoregon.com NOT FOUND")
            self.investigation_results['findings']['user_exists'] = False
            return
        
        user_info = user_results[0]
        print(f"✅ User found: {user_info['first_name']} {user_info['last_name']}")
        print(f"   Email: {user_info['email']}")
        print(f"   Tenant: {user_info['tenant_name']} ({user_info['tenant_bk']})")
        print(f"   Created: {user_info['created_date']}")
        print(f"   Active: {user_info['is_active']}")
        
        self.investigation_results['findings']['user_exists'] = True
        self.investigation_results['findings']['user_info'] = user_info
        
        # Check for roles
        role_query = """
        SELECT 
            encode(rh.role_hk, 'hex') as role_hk,
            rh.role_bk,
            rds.role_name,
            rds.role_description,
            rds.permissions,
            rds.is_system_role,
            url.load_date as role_assigned_date
        FROM auth.user_role_l url
        JOIN auth.role_h rh ON url.role_hk = rh.role_hk
        JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
        WHERE url.user_hk = decode(%s, 'hex')
        AND rds.load_end_date IS NULL
        ORDER BY url.load_date DESC
        """
        
        role_results = self.execute_query(role_query, (user_info['user_hk'],))
        
        if not role_results:
            print("❌ NO ROLES ASSIGNED TO USER")
            self.investigation_results['findings']['has_roles'] = False
            self.investigation_results['recommendations'].append(
                "CRITICAL: User has no roles assigned - needs administrator role for tenant"
            )
        else:
            print(f"✅ User has {len(role_results)} role(s):")
            for role in role_results:
                print(f"   - {role['role_name']}: {role['role_description']}")
            self.investigation_results['findings']['has_roles'] = True
            self.investigation_results['findings']['roles'] = role_results
    
    def investigate_tenant_structure(self):
        """Investigate the tenant structure and available roles"""
        print("\n" + "="*60)
        print("🏢 INVESTIGATING TENANT STRUCTURE")
        print("="*60)
        
        # Get tenant info for theonespaoregon.com
        tenant_query = """
        SELECT 
            encode(th.tenant_hk, 'hex') as tenant_hk,
            th.tenant_bk,
            tps.tenant_name,
            tps.tenant_description,
            tps.contact_email,
            tps.max_users,
            tps.subscription_level,
            tps.created_date,
            tps.is_active
        FROM auth.tenant_h th
        JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
        WHERE tps.contact_email LIKE '%theonespaoregon.com%'
        AND tps.load_end_date IS NULL
        ORDER BY tps.load_date DESC
        """
        
        tenant_results = self.execute_query(tenant_query)
        
        if not tenant_results:
            print("❌ No tenant found for theonespaoregon.com domain")
            return
        
        tenant_info = tenant_results[0]
        print(f"✅ Tenant found: {tenant_info['tenant_name']}")
        print(f"   Contact: {tenant_info['contact_email']}")
        print(f"   Subscription: {tenant_info['subscription_level']}")
        print(f"   Max Users: {tenant_info['max_users']}")
        print(f"   Created: {tenant_info['created_date']}")
        
        self.investigation_results['findings']['tenant_info'] = tenant_info
        
        # Check for available roles in this tenant
        tenant_roles_query = """
        SELECT 
            encode(rh.role_hk, 'hex') as role_hk,
            rh.role_bk,
            rds.role_name,
            rds.role_description,
            rds.permissions,
            rds.is_system_role,
            rds.created_date
        FROM auth.role_h rh
        JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
        WHERE rh.tenant_hk = decode(%s, 'hex')
        AND rds.load_end_date IS NULL
        ORDER BY rds.created_date DESC
        """
        
        tenant_roles = self.execute_query(tenant_roles_query, (tenant_info['tenant_hk'],))
        
        print(f"\n📋 Available roles in tenant ({len(tenant_roles)} found):")
        if tenant_roles:
            for role in tenant_roles:
                print(f"   - {role['role_name']}: {role['role_description']}")
                print(f"     System Role: {role['is_system_role']}")
        else:
            print("❌ NO ROLES DEFINED FOR THIS TENANT")
            self.investigation_results['recommendations'].append(
                "CRITICAL: Tenant has no roles defined - need to create default role structure"
            )
        
        self.investigation_results['findings']['tenant_roles'] = tenant_roles
    
    def analyze_register_tenant_procedure(self):
        """Analyze the current auth.register_tenant procedure"""
        print("\n" + "="*60)
        print("🔧 ANALYZING REGISTER_TENANT PROCEDURE")
        print("="*60)
        
        # Get the current procedure definition
        procedure_query = """
        SELECT 
            p.proname,
            pg_get_functiondef(p.oid) as definition
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'auth' 
        AND p.proname = 'register_tenant'
        """
        
        procedure_results = self.execute_query(procedure_query)
        
        if procedure_results:
            procedure_def = procedure_results[0]['definition']
            print("✅ Found auth.register_tenant procedure")
            
            # Analyze what the procedure does
            creates_roles = 'role_h' in procedure_def.lower()
            creates_role_assignments = 'user_role_l' in procedure_def.lower()
            
            print(f"   Creates roles: {'✅' if creates_roles else '❌'}")
            print(f"   Creates role assignments: {'✅' if creates_role_assignments else '❌'}")
            
            if not creates_roles or not creates_role_assignments:
                print("\n❌ FOUND THE PROBLEM:")
                print("   The current auth.register_tenant procedure does NOT create roles or role assignments!")
                print("   This explains why travis@theonespaoregon.com has no role.")
                
                self.investigation_results['findings']['procedure_analysis'] = {
                    'creates_roles': creates_roles,
                    'creates_role_assignments': creates_role_assignments,
                    'issue_identified': True
                }
                
                self.investigation_results['recommendations'].extend([
                    "Update auth.register_tenant to include role creation",
                    "Add default role assignment for admin user",
                    "Implement role template system for new tenants"
                ])
        else:
            print("❌ auth.register_tenant procedure not found")
    
    def check_system_roles(self):
        """Check if system-level roles exist"""
        print("\n" + "="*60)
        print("🌐 CHECKING SYSTEM ROLES")
        print("="*60)
        
        system_roles_query = """
        SELECT 
            th.tenant_bk,
            rh.role_bk,
            rds.role_name,
            rds.role_description,
            rds.is_system_role
        FROM auth.tenant_h th
        JOIN auth.role_h rh ON th.tenant_hk = rh.tenant_hk
        JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
        WHERE th.tenant_bk = 'SYSTEM_ADMIN'
        AND rds.load_end_date IS NULL
        ORDER BY rds.role_name
        """
        
        system_roles = self.execute_query(system_roles_query)
        
        if system_roles:
            print(f"✅ Found {len(system_roles)} system roles:")
            for role in system_roles:
                print(f"   - {role['role_name']}")
        else:
            print("❌ No system roles found")
            self.investigation_results['recommendations'].append(
                "Consider implementing system-wide role templates"
            )
        
        self.investigation_results['findings']['system_roles'] = system_roles
    
    def generate_fix_script(self):
        """Generate a script to fix the identified issues"""
        print("\n" + "="*60)
        print("🛠️  GENERATING FIX SCRIPT")
        print("="*60)
        
        fix_script = """-- Fix Script for Travis User Role Assignment
-- Generated on: {timestamp}
-- Target User: {target_user}

-- Step 1: Create Administrator Role for Tenant (if not exists)
DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_role_hk BYTEA;
    v_role_bk VARCHAR(255);
    v_user_hk BYTEA;
BEGIN
    -- Get tenant hash key for theonespaoregon.com
    SELECT th.tenant_hk INTO v_tenant_hk
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
    WHERE tps.contact_email LIKE '%theonespaoregon.com%'
    AND tps.load_end_date IS NULL
    LIMIT 1;
    
    IF v_tenant_hk IS NULL THEN
        RAISE EXCEPTION 'Tenant not found for theonespaoregon.com';
    END IF;
    
    -- Create Administrator role if it doesn't exist
    v_role_bk := 'ADMIN_ROLE_' || substring(encode(v_tenant_hk, 'hex'), 1, 8);
    v_role_hk := util.hash_binary(v_role_bk);
    
    -- Create role hub
    INSERT INTO auth.role_h (
        role_hk,
        role_bk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        v_role_hk,
        v_role_bk,
        v_tenant_hk,
        util.current_load_date(),
        'manual_fix_script'
    ) ON CONFLICT (role_hk) DO NOTHING;
    
    -- Create role definition
    INSERT INTO auth.role_definition_s (
        role_hk,
        load_date,
        hash_diff,
        role_name,
        role_description,
        is_system_role,
        permissions,
        created_date,
        record_source
    ) VALUES (
        v_role_hk,
        util.current_load_date(),
        util.hash_binary('Administrator' || 'Full tenant access'),
        'Administrator',
        'Complete administrative access for tenant operations and user management',
        FALSE,
        jsonb_build_object(
            'user_management', true,
            'system_administration', true,
            'data_access_level', 'full',
            'reporting_access', true,
            'security_management', true,
            'audit_access', true
        ),
        CURRENT_TIMESTAMP,
        'manual_fix_script'
    ) ON CONFLICT (role_hk, load_date) DO NOTHING;
    
    -- Get travis user hash key
    SELECT uh.user_hk INTO v_user_hk
    FROM auth.user_h uh
    JOIN auth.user_profile_s ups ON uh.user_hk = ups.user_hk
    WHERE ups.email = '{target_user}'
    AND uh.tenant_hk = v_tenant_hk
    AND ups.load_end_date IS NULL
    LIMIT 1;
    
    IF v_user_hk IS NULL THEN
        RAISE EXCEPTION 'User {target_user} not found in tenant';
    END IF;
    
    -- Assign administrator role to travis
    INSERT INTO auth.user_role_l (
        link_user_role_hk,
        user_hk,
        role_hk,
        tenant_hk,
        load_date,
        record_source
    ) VALUES (
        util.hash_binary(v_user_hk::text || v_role_hk::text),
        v_user_hk,
        v_role_hk,
        v_tenant_hk,
        util.current_load_date(),
        'manual_fix_script'
    ) ON CONFLICT (link_user_role_hk) DO NOTHING;
    
    RAISE NOTICE 'SUCCESS: Administrator role assigned to {target_user}';
    RAISE NOTICE 'Role HK: %', encode(v_role_hk, 'hex');
    RAISE NOTICE 'User HK: %', encode(v_user_hk, 'hex');
END $$;

-- Step 2: Verify the assignment
SELECT 
    ups.email,
    ups.first_name,
    ups.last_name,
    rds.role_name,
    rds.role_description,
    url.load_date as role_assigned_date
FROM auth.user_profile_s ups
JOIN auth.user_h uh ON ups.user_hk = uh.user_hk
JOIN auth.user_role_l url ON uh.user_hk = url.user_hk
JOIN auth.role_h rh ON url.role_hk = rh.role_hk
JOIN auth.role_definition_s rds ON rh.role_hk = rds.role_hk
WHERE ups.email = '{target_user}'
AND ups.load_end_date IS NULL
AND rds.load_end_date IS NULL;
""".format(
            timestamp=self.investigation_results['timestamp'],
            target_user=self.investigation_results['target_user']
        )
        
        # Save fix script
        fix_script_path = 'database/investigations/tenant_role_investigation/fix_travis_user_role.sql'
        with open(fix_script_path, 'w') as f:
            f.write(fix_script)
        
        print(f"✅ Fix script generated: {fix_script_path}")
        return fix_script_path
    
    def run_investigation(self):
        """Run the complete investigation"""
        print("🚀 Starting Tenant Role Investigation")
        print(f"Target User: {self.investigation_results['target_user']}")
        print(f"Database: {DB_CONFIG['database']} on {DB_CONFIG['host']}")
        
        if not self.connect_to_database():
            return False
        
        try:
            # Run all investigation steps
            self.investigate_travis_user()
            self.investigate_tenant_structure()
            self.analyze_register_tenant_procedure()
            self.check_system_roles()
            
            # Generate fix script
            fix_script_path = self.generate_fix_script()
            
            # Save investigation results
            results_path = 'database/investigations/tenant_role_investigation/investigation_results.json'
            with open(results_path, 'w') as f:
                json.dump(self.investigation_results, f, indent=2, default=str)
            
            print("\n" + "="*60)
            print("📊 INVESTIGATION SUMMARY")
            print("="*60)
            
            print(f"User Exists: {'✅' if self.investigation_results['findings'].get('user_exists') else '❌'}")
            print(f"Has Roles: {'✅' if self.investigation_results['findings'].get('has_roles') else '❌'}")
            
            if self.investigation_results['recommendations']:
                print(f"\n🎯 RECOMMENDATIONS ({len(self.investigation_results['recommendations'])}):")
                for i, rec in enumerate(self.investigation_results['recommendations'], 1):
                    print(f"   {i}. {rec}")
            
            print(f"\n📁 Files Generated:")
            print(f"   - Investigation Results: {results_path}")
            print(f"   - Fix Script: {fix_script_path}")
            
            return True
            
        except Exception as e:
            print(f"❌ Investigation failed: {e}")
            return False
        finally:
            if self.conn:
                self.conn.close()
                print("\n✅ Database connection closed")

def main():
    investigator = TenantRoleInvestigator()
    success = investigator.run_investigation()
    
    if success:
        print("\n🎉 Investigation completed successfully!")
        print("\nNext steps:")
        print("1. Review the generated fix script")
        print("2. Execute the fix script against the database")
        print("3. Update the auth.register_tenant procedure to prevent future issues")
        return 0
    else:
        print("\n❌ Investigation failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 