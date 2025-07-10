#!/usr/bin/env python3
"""
🔍 Database Analysis for One_Barn_AI Enterprise Tenant Setup
==========================================================
Analyze current database state to plan One_Barn_AI tenant creation
"""

import psycopg2
import getpass
from datetime import datetime
import json

def connect_to_database():
    """Connect to the one_vault_site_testing database"""
    try:
        # Get password securely
        password = getpass.getpass("Enter database password for localhost/one_vault_site_testing: ")
        
        conn = psycopg2.connect(
            dbname='one_vault_site_testing',
            user='postgres', 
            password=password,
            host='localhost',
            port='5432'
        )
        
        print("✅ Connected to one_vault_site_testing database successfully")
        return conn
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return None

def run_query(conn, query, description):
    """Run a query and display results"""
    print(f"\n🔍 {description}")
    print("=" * (len(description) + 4))
    
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        results = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        cursor.close()
        
        if not results:
            print("   No data found")
            return []
        
        # Print column headers
        print("   " + " | ".join(f"{col:<20}" for col in columns))
        print("   " + "-" * (len(columns) * 23))
        
        # Print rows (limit to 10 for readability)
        for i, row in enumerate(results[:10]):
            row_str = []
            for val in row:
                if val is None:
                    row_str.append("NULL".ljust(20))
                elif isinstance(val, datetime):
                    row_str.append(str(val)[:19].ljust(20))
                else:
                    row_str.append(str(val)[:20].ljust(20))
            print("   " + " | ".join(row_str))
        
        if len(results) > 10:
            print(f"   ... and {len(results) - 10} more rows")
        
        print(f"   Total rows: {len(results)}")
        return results
        
    except Exception as e:
        print(f"   ❌ Query failed: {e}")
        return []

def analyze_tenant_system(conn):
    """Analyze the current tenant system"""
    print("\n🏢 ANALYZING CURRENT TENANT SYSTEM")
    print("=" * 40)
    
    # Check if auth.register_tenant function exists
    tenants_query = """
    SELECT 
        t.tenant_name,
        t.business_name,
        t.tenant_type,
        t.is_active,
        t.load_date as created_date
    FROM auth.tenant_h th
    JOIN auth.tenant_profile_s t ON th.tenant_hk = t.tenant_hk
    WHERE t.load_end_date IS NULL
    ORDER BY t.load_date DESC
    """
    
    existing_tenants = run_query(conn, tenants_query, "EXISTING TENANTS")
    
    # Check tenant management functions
    functions_query = """
    SELECT 
        p.proname as function_name,
        p.proargtypes,
        pg_get_function_result(p.oid) as returns
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth'
    AND p.proname LIKE '%tenant%'
    ORDER BY p.proname
    """
    
    run_query(conn, functions_query, "TENANT MANAGEMENT FUNCTIONS")
    
    return existing_tenants

def analyze_ai_infrastructure(conn):
    """Analyze AI agent infrastructure"""
    print("\n🤖 ANALYZING AI INFRASTRUCTURE")
    print("=" * 35)
    
    # Check AI schemas and tables
    ai_tables_query = """
    SELECT 
        table_schema,
        table_name,
        'TABLE' as object_type
    FROM information_schema.tables
    WHERE table_schema LIKE '%ai%'
    OR table_name LIKE '%ai%'
    ORDER BY table_schema, table_name
    """
    
    run_query(conn, ai_tables_query, "AI-RELATED TABLES")
    
    # Check existing AI agents
    try:
        ai_agents_query = """
        SELECT 
            a.agent_name,
            a.agent_type,
            a.description,
            a.is_active,
            t.tenant_name
        FROM ai.agent_h ah
        JOIN ai.agent_s a ON ah.agent_hk = a.agent_hk
        LEFT JOIN auth.tenant_h th ON ah.tenant_hk = th.tenant_hk
        LEFT JOIN auth.tenant_profile_s t ON th.tenant_hk = t.tenant_hk
        WHERE a.load_end_date IS NULL
        AND (t.load_end_date IS NULL OR t.load_end_date IS NULL)
        ORDER BY a.load_date DESC
        """
        
        run_query(conn, ai_agents_query, "EXISTING AI AGENTS")
    except Exception as e:
        print(f"   ⚠️ AI agent tables might not exist yet: {e}")
    
    # Check AI functions
    ai_functions_query = """
    SELECT 
        p.proname as function_name,
        n.nspname as schema_name
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE (n.nspname LIKE '%ai%' OR p.proname LIKE '%ai%')
    AND p.proname NOT LIKE 'pg_%'
    ORDER BY n.nspname, p.proname
    """
    
    run_query(conn, ai_functions_query, "AI-RELATED FUNCTIONS")

def analyze_authentication_system(conn):
    """Analyze authentication and role system"""
    print("\n🔐 ANALYZING AUTHENTICATION SYSTEM")
    print("=" * 38)
    
    # Check user management
    users_query = """
    SELECT 
        up.email,
        up.first_name,
        up.last_name,
        t.tenant_name,
        uas.last_login_date
    FROM auth.user_h uh
    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
    JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
    JOIN auth.tenant_profile_s t ON th.tenant_hk = t.tenant_hk
    LEFT JOIN auth.user_auth_s uas ON uh.user_hk = uas.user_hk
    WHERE up.load_end_date IS NULL
    AND t.load_end_date IS NULL
    AND (uas.load_end_date IS NULL OR uas.load_end_date IS NULL)
    ORDER BY up.load_date DESC
    LIMIT 20
    """
    
    run_query(conn, users_query, "EXISTING USERS")
    
    # Check role system
    roles_query = """
    SELECT 
        r.role_name,
        r.role_description,
        t.tenant_name,
        r.is_active
    FROM auth.role_h rh
    JOIN auth.role_s r ON rh.role_hk = r.role_hk
    LEFT JOIN auth.tenant_h th ON rh.tenant_hk = th.tenant_hk
    LEFT JOIN auth.tenant_profile_s t ON th.tenant_hk = t.tenant_hk
    WHERE r.load_end_date IS NULL
    AND (t.load_end_date IS NULL OR t.load_end_date IS NULL)
    ORDER BY t.tenant_name, r.role_name
    """
    
    run_query(conn, roles_query, "EXISTING ROLES")

def check_api_functions(conn):
    """Check available API functions"""
    print("\n🔗 ANALYZING API FUNCTIONS")
    print("=" * 28)
    
    api_functions_query = """
    SELECT 
        p.proname as function_name,
        pg_get_function_result(p.oid) as returns,
        p.pronargs as arg_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'api'
    ORDER BY p.proname
    """
    
    api_functions = run_query(conn, api_functions_query, "AVAILABLE API FUNCTIONS")
    
    # Specifically check for functions we'll need
    needed_functions = [
        'auth_login',
        'auth_complete_login', 
        'auth_validate_session',
        'ai_create_session',
        'ai_secure_chat',
        'system_health_check'
    ]
    
    print(f"\n   🎯 CRITICAL FUNCTIONS CHECK:")
    available_func_names = [func[0] for func in api_functions]
    for func in needed_functions:
        status = "✅ AVAILABLE" if func in available_func_names else "❌ MISSING"
        print(f"   - {func}: {status}")

def analyze_hash_utilities(conn):
    """Check hash utility functions for Data Vault 2.0"""
    print("\n🔐 ANALYZING HASH UTILITIES")
    print("=" * 30)
    
    util_functions_query = """
    SELECT 
        p.proname as function_name,
        pg_get_function_result(p.oid) as returns
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'util'
    AND (p.proname LIKE '%hash%' OR p.proname LIKE '%current%')
    ORDER BY p.proname
    """
    
    run_query(conn, util_functions_query, "HASH AND UTILITY FUNCTIONS")

def main():
    """Main analysis function"""
    print("🔍 ONE_BARN_AI ENTERPRISE TENANT SETUP - DATABASE ANALYSIS")
    print("=" * 65)
    print("📅 Analysis Date:", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    print("🎯 Objective: Prepare database for One_Barn_AI enterprise tenant creation")
    
    conn = connect_to_database()
    if not conn:
        return
    
    try:
        # Run comprehensive analysis
        existing_tenants = analyze_tenant_system(conn)
        analyze_ai_infrastructure(conn)
        analyze_authentication_system(conn)
        check_api_functions(conn)
        analyze_hash_utilities(conn)
        
        # Summary and recommendations
        print(f"\n🎯 ANALYSIS SUMMARY")
        print("=" * 20)
        print(f"✅ Database connection: SUCCESSFUL")
        print(f"🏢 Existing tenants: {len(existing_tenants) if existing_tenants else 0}")
        print(f"🔧 Ready for One_Barn_AI setup: Checking requirements...")
        
        # Check if one_barn_ai already exists
        existing_barn_tenants = [t for t in existing_tenants if 'barn' in str(t[0]).lower()]
        if existing_barn_tenants:
            print(f"⚠️  One_Barn_AI may already exist: {existing_barn_tenants}")
        else:
            print(f"✅ One_Barn_AI tenant name available")
            
        print(f"\n🚀 NEXT STEPS:")
        print(f"1. Verify auth.register_tenant() function exists")
        print(f"2. Create One_Barn_AI tenant with horse health specialization")
        print(f"3. Set up Horse Health AI agent")
        print(f"4. Test API endpoints with new tenant")
        print(f"5. Prepare demo data and scenarios")
        
    finally:
        conn.close()
        print("\n✅ Database analysis complete!")

if __name__ == "__main__":
    main() 