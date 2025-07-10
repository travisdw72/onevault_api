#!/usr/bin/env python3
"""
Database Analysis for One_Barn_AI Enterprise Tenant Setup
"""

import psycopg2
import getpass
from datetime import datetime

def connect_to_database():
    """Connect to the one_vault_site_testing database"""
    try:
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
        
        # Convert to dictionaries for consistent access
        dict_results = [dict(zip(columns, row)) for row in results]
        
        # Print results
        for i, row_dict in enumerate(dict_results[:10]):
            print(f"   {i+1}. {row_dict}")
        
        if len(results) > 10:
            print(f"   ... and {len(results) - 10} more rows")
        
        print(f"   Total rows: {len(results)}")
        return dict_results
        
    except Exception as e:
        print(f"   ❌ Query failed: {e}")
        return []

def check_schema_structure(conn):
    """Check the database schema structure"""
    print("\n🏗️ CHECKING DATABASE SCHEMA STRUCTURE")
    print("=" * 40)
    
    # Check all schemas
    schemas_query = """
    SELECT schema_name 
    FROM information_schema.schemata 
    WHERE schema_name NOT LIKE 'pg_%' 
    AND schema_name != 'information_schema'
    ORDER BY schema_name
    """
    
    run_query(conn, schemas_query, "AVAILABLE SCHEMAS")
    
    # Check auth schema tables
    auth_tables_query = """
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'auth'
    ORDER BY table_name
    """
    
    run_query(conn, auth_tables_query, "AUTH SCHEMA TABLES")
    
    # Check tenant table structure
    tenant_columns_query = """
    SELECT 
        column_name,
        data_type,
        is_nullable
    FROM information_schema.columns 
    WHERE table_schema = 'auth' 
    AND table_name LIKE '%tenant%'
    ORDER BY table_name, ordinal_position
    """
    
    run_query(conn, tenant_columns_query, "TENANT TABLE COLUMNS")

def check_existing_tenants(conn):
    """Check existing tenants with correct column names"""
    print("\n🏢 CHECKING EXISTING TENANTS")
    print("=" * 30)
    
    # First, let's see what's in tenant_h
    tenant_h_query = """
    SELECT * FROM auth.tenant_h 
    ORDER BY load_date DESC 
    LIMIT 5
    """
    
    run_query(conn, tenant_h_query, "TENANT HUB TABLE")
    
    # Check tenant satellite tables
    tenant_s_tables_query = """
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'auth' 
    AND table_name LIKE '%tenant%_s'
    ORDER BY table_name
    """
    
    tenant_s_tables = run_query(conn, tenant_s_tables_query, "TENANT SATELLITE TABLES")
    
    # Check each satellite table structure
    for table_info in tenant_s_tables:
        table_name = table_info['table_name']
        columns_query = f"""
        SELECT column_name, data_type
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
        AND table_name = '{table_name}'
        ORDER BY ordinal_position
        """
        
        run_query(conn, columns_query, f"COLUMNS IN {table_name}")

def check_auth_functions(conn):
    """Check authentication and tenant functions"""
    print("\n🔧 CHECKING AUTH FUNCTIONS")
    print("=" * 28)
    
    # Check all auth functions
    auth_funcs_query = """
    SELECT 
        proname as function_name,
        pg_get_function_result(oid) as returns
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth'
    ORDER BY proname
    """
    
    run_query(conn, auth_funcs_query, "AUTH SCHEMA FUNCTIONS")
    
    # Check API functions
    api_funcs_query = """
    SELECT 
        proname as function_name,
        pg_get_function_result(oid) as returns
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'api'
    ORDER BY proname
    """
    
    run_query(conn, api_funcs_query, "API SCHEMA FUNCTIONS")

def check_ai_infrastructure(conn):
    """Check AI infrastructure"""
    print("\n🤖 CHECKING AI INFRASTRUCTURE")
    print("=" * 30)
    
    # Check AI schemas
    ai_schemas_query = """
    SELECT schema_name 
    FROM information_schema.schemata 
    WHERE schema_name LIKE '%ai%'
    ORDER BY schema_name
    """
    
    run_query(conn, ai_schemas_query, "AI SCHEMAS")
    
    # Check tables with 'ai' in the name
    ai_tables_query = """
    SELECT 
        table_schema,
        table_name
    FROM information_schema.tables 
    WHERE table_name LIKE '%ai%'
    OR table_schema LIKE '%ai%'
    ORDER BY table_schema, table_name
    """
    
    run_query(conn, ai_tables_query, "AI-RELATED TABLES")

def main():
    """Main analysis function"""
    print("🔍 ONE_BARN_AI DATABASE ANALYSIS")
    print("=" * 35)
    print("📅 Analysis Date:", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    
    conn = connect_to_database()
    if not conn:
        return
    
    try:
        # Step-by-step analysis
        check_schema_structure(conn)
        check_existing_tenants(conn)
        check_auth_functions(conn)
        check_ai_infrastructure(conn)
        
        print(f"\n🎯 ANALYSIS COMPLETE")
        print("=" * 20)
        print("✅ Database structure analyzed successfully")
        print("🚀 Ready to proceed with One_Barn_AI tenant creation plan")
        
    finally:
        conn.close()
        print("\n✅ Database connection closed")

if __name__ == "__main__":
    main() 