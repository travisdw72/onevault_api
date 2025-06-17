#!/usr/bin/env python3
"""
Explore the existing testing_one_management database to understand what we have
"""

import psycopg2
from psycopg2 import sql
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def explore_testing_database():
    """Explore the testing_one_management database"""
    
    # Try connecting to the database that's actually being accessed
    db_params = {
        'host': os.getenv('DB_HOST', '127.0.0.1'),
        'port': os.getenv('DB_PORT', '5432'),
        'user': os.getenv('DB_ADMIN_USER', 'onevault_implementation'),
        'password': os.getenv('DB_ADMIN_PASSWORD', 'Implement2024!Secure#'),
        'database': 'testing_one_management'  # Connect to the actual database being accessed
    }
    
    try:
        print("=== EXPLORING TESTING_ONE_MANAGEMENT DATABASE ===")
        print(f"Connecting to: {db_params['host']}:{db_params['port']}")
        print(f"Database: {db_params['database']}")
        print(f"User: {db_params['user']}")
        
        conn = psycopg2.connect(**db_params)
        cursor = conn.cursor()
        
        # Get database size
        cursor.execute("SELECT pg_size_pretty(pg_database_size(current_database()))")
        db_size = cursor.fetchone()[0]
        print(f"Database size: {db_size}")
        
        # Get schemas
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
            ORDER BY schema_name;
        """)
        
        schemas = [row[0] for row in cursor.fetchall()]
        print(f"\nSchemas found: {schemas}")
        
        # Get tables by schema
        for schema in schemas:
            cursor.execute("""
                SELECT table_name, table_type
                FROM information_schema.tables 
                WHERE table_schema = %s
                ORDER BY table_name;
            """, (schema,))
            
            tables = cursor.fetchall()
            
            if tables:
                print(f"\n=== SCHEMA: {schema} ===")
                hub_tables = []
                satellite_tables = []
                link_tables = []
                other_tables = []
                
                for table_name, table_type in tables:
                    if table_name.endswith('_h'):
                        hub_tables.append(table_name)
                    elif table_name.endswith('_s'):
                        satellite_tables.append(table_name)
                    elif table_name.endswith('_l'):
                        link_tables.append(table_name)
                    else:
                        other_tables.append(table_name)
                
                if hub_tables:
                    print(f"  Hub Tables ({len(hub_tables)}):")
                    for table in hub_tables:
                        print(f"    - {table}")
                
                if satellite_tables:
                    print(f"  Satellite Tables ({len(satellite_tables)}):")
                    for table in satellite_tables:
                        print(f"    - {table}")
                
                if link_tables:
                    print(f"  Link Tables ({len(link_tables)}):")
                    for table in link_tables:
                        print(f"    - {table}")
                
                if other_tables:
                    print(f"  Other Tables ({len(other_tables)}):")
                    for table in other_tables:
                        print(f"    - {table}")
        
        # Check for Data Vault 2.0 utility functions
        cursor.execute("""
            SELECT routine_schema, routine_name, routine_type
            FROM information_schema.routines
            WHERE routine_schema NOT IN ('information_schema', 'pg_catalog')
            AND routine_name IN ('hash_binary', 'current_load_date', 'get_record_source')
            ORDER BY routine_schema, routine_name;
        """)
        
        functions = cursor.fetchall()
        
        if functions:
            print(f"\n=== DATA VAULT 2.0 FUNCTIONS ===")
            for schema, func_name, func_type in functions:
                print(f"  - {schema}.{func_name} ({func_type})")
        
        # Check for any horse/equestrian related tables
        cursor.execute("""
            SELECT table_schema, table_name
            FROM information_schema.tables 
            WHERE table_name ILIKE '%horse%' 
               OR table_name ILIKE '%barn%'
               OR table_name ILIKE '%stall%'
               OR table_name ILIKE '%owner%'
               OR table_name ILIKE '%equestrian%'
            ORDER BY table_schema, table_name;
        """)
        
        equestrian_tables = cursor.fetchall()
        
        if equestrian_tables:
            print(f"\n=== EQUESTRIAN-RELATED TABLES ===")
            for schema, table in equestrian_tables:
                print(f"  - {schema}.{table}")
        else:
            print(f"\n=== NO EQUESTRIAN TABLES FOUND ===")
            print("This appears to be a different type of database.")
        
        # Get a sample of data from a few tables to understand the structure
        print(f"\n=== SAMPLE DATA ANALYSIS ===")
        for schema in schemas[:2]:  # Check first 2 schemas
            cursor.execute("""
                SELECT table_name
                FROM information_schema.tables 
                WHERE table_schema = %s
                AND table_type = 'BASE TABLE'
                LIMIT 3;
            """, (schema,))
            
            sample_tables = [row[0] for row in cursor.fetchall()]
            
            for table in sample_tables:
                try:
                    cursor.execute(f"""
                        SELECT COUNT(*) FROM {schema}.{table};
                    """)
                    count = cursor.fetchone()[0]
                    print(f"  {schema}.{table}: {count} rows")
                    
                    if count > 0 and count < 1000:  # Only show columns for smaller tables
                        cursor.execute(f"""
                            SELECT column_name, data_type
                            FROM information_schema.columns
                            WHERE table_schema = %s AND table_name = %s
                            ORDER BY ordinal_position
                            LIMIT 10;
                        """, (schema, table))
                        
                        columns = cursor.fetchall()
                        print(f"    Columns: {', '.join([f'{col[0]}({col[1]})' for col in columns])}")
                        
                except Exception as e:
                    print(f"    Error accessing {schema}.{table}: {e}")
        
        cursor.close()
        conn.close()
        
        return True
        
    except psycopg2.Error as e:
        print(f"Database connection error: {e}")
        return False

def list_all_databases():
    """List all databases on the server"""
    
    db_params = {
        'host': os.getenv('DB_HOST', '127.0.0.1'),
        'port': os.getenv('DB_PORT', '5432'),
        'user': os.getenv('DB_ADMIN_USER', 'onevault_implementation'),
        'password': os.getenv('DB_ADMIN_PASSWORD', 'Implement2024!Secure#'),
        'database': 'postgres'  # Connect to default postgres database
    }
    
    try:
        print("\n=== ALL DATABASES ON SERVER ===")
        
        conn = psycopg2.connect(**db_params)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT datname, pg_size_pretty(pg_database_size(datname)) as size,
                   datcollate, datctype
            FROM pg_database 
            WHERE datistemplate = false
            ORDER BY datname;
        """)
        
        databases = cursor.fetchall()
        
        print(f"{'Database Name':<30} {'Size':<15} {'Collation':<15}")
        print("-" * 65)
        
        for db_name, size, collate, ctype in databases:
            print(f"{db_name:<30} {size:<15} {collate:<15}")
        
        # Look for OneVault related databases
        onevault_dbs = [db for db in databases if 'one' in db[0].lower() or 'vault' in db[0].lower() or 'barn' in db[0].lower()]
        
        if onevault_dbs:
            print(f"\n=== ONEVAULT/BARN RELATED DATABASES ===")
            for db_name, size, collate, ctype in onevault_dbs:
                print(f"  - {db_name} ({size})")
        
        cursor.close()
        conn.close()
        
        return databases
        
    except psycopg2.Error as e:
        print(f"Error listing databases: {e}")
        return None

if __name__ == "__main__":
    print("OneVault Database Explorer")
    print("=" * 60)
    
    # First, list all databases
    databases = list_all_databases()
    
    # Then explore the testing database
    if databases:
        explore_testing_database()
    
    print("\n" + "=" * 60)
    print("Database exploration complete!") 