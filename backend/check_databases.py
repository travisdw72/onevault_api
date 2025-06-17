#!/usr/bin/env python3
"""
Simple script to check what databases exist on the PostgreSQL server
"""

import psycopg2
from psycopg2 import sql
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def check_databases():
    """Check what databases exist on the PostgreSQL server"""
    
    # Database connection parameters from .env
    db_params = {
        'host': os.getenv('DB_HOST', '127.0.0.1'),
        'port': os.getenv('DB_PORT', '5432'),
        'user': os.getenv('DB_ADMIN_USER', 'onevault_implementation'),
        'password': os.getenv('DB_ADMIN_PASSWORD', 'Implement2024!Secure#'),
        'database': os.getenv('DB_NAME', 'one_vault')  # Connect to configured database
    }
    
    try:
        print("Connecting to PostgreSQL server...")
        print(f"Host: {db_params['host']}:{db_params['port']}")
        print(f"User: {db_params['user']}")
        
        # Connect to PostgreSQL
        conn = psycopg2.connect(**db_params)
        cursor = conn.cursor()
        
        # Get list of databases
        cursor.execute("""
            SELECT datname, pg_size_pretty(pg_database_size(datname)) as size
            FROM pg_database 
            WHERE datistemplate = false
            ORDER BY datname;
        """)
        
        databases = cursor.fetchall()
        
        print("\n=== EXISTING DATABASES ===")
        print(f"{'Database Name':<30} {'Size':<15}")
        print("-" * 50)
        
        for db_name, size in databases:
            print(f"{db_name:<30} {size:<15}")
        
        # Check for OneVault specific databases
        onevault_dbs = [db for db in databases if 'one' in db[0].lower() or 'vault' in db[0].lower()]
        
        if onevault_dbs:
            print("\n=== ONEVAULT RELATED DATABASES ===")
            for db_name, size in onevault_dbs:
                print(f"  - {db_name} ({size})")
        else:
            print("\n=== NO ONEVAULT DATABASES FOUND ===")
            print("You may need to create the databases first.")
        
        cursor.close()
        conn.close()
        
        return databases
        
    except psycopg2.Error as e:
        print(f"Database connection error: {e}")
        print("\nPossible issues:")
        print("1. PostgreSQL server is not running")
        print("2. Database credentials are incorrect")
        print("3. Database server is not accessible")
        return None
    except Exception as e:
        print(f"Unexpected error: {e}")
        return None

def check_specific_database(db_name):
    """Check if a specific database exists and get its schema info"""
    
    db_params = {
        'host': os.getenv('DB_HOST', '127.0.0.1'),
        'port': os.getenv('DB_PORT', '5432'),
        'user': os.getenv('DB_ADMIN_USER', 'onevault_implementation'),
        'password': os.getenv('DB_ADMIN_PASSWORD', 'Implement2024!Secure#'),
        'database': db_name
    }
    
    try:
        print(f"\n=== CHECKING DATABASE: {db_name} ===")
        
        conn = psycopg2.connect(**db_params)
        cursor = conn.cursor()
        
        # Get schemas
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
            ORDER BY schema_name;
        """)
        
        schemas = [row[0] for row in cursor.fetchall()]
        
        print(f"Schemas found: {', '.join(schemas) if schemas else 'None'}")
        
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
                print(f"\n  Schema '{schema}' tables:")
                for table_name, table_type in tables:
                    print(f"    - {table_name} ({table_type})")
            else:
                print(f"\n  Schema '{schema}': No tables found")
        
        # Check for Data Vault 2.0 patterns
        cursor.execute("""
            SELECT table_schema, table_name
            FROM information_schema.tables 
            WHERE table_name LIKE '%_h' OR table_name LIKE '%_s' OR table_name LIKE '%_l'
            ORDER BY table_schema, table_name;
        """)
        
        dv_tables = cursor.fetchall()
        
        if dv_tables:
            print(f"\n  Data Vault 2.0 tables found:")
            for schema, table in dv_tables:
                suffix = table[-2:]
                table_type = {'_h': 'Hub', '_s': 'Satellite', '_l': 'Link'}.get(suffix, 'Unknown')
                print(f"    - {schema}.{table} ({table_type})")
        else:
            print(f"\n  No Data Vault 2.0 tables found")
        
        cursor.close()
        conn.close()
        
        return True
        
    except psycopg2.Error as e:
        print(f"Cannot connect to database '{db_name}': {e}")
        return False

if __name__ == "__main__":
    print("OneVault Database Discovery Tool")
    print("=" * 50)
    
    # Check what databases exist
    databases = check_databases()
    
    if databases:
        # Check specific OneVault databases
        target_databases = ['one_barn_db', 'one_spa_db', 'onevault_system']
        
        for db_name in target_databases:
            if any(db[0] == db_name for db in databases):
                check_specific_database(db_name)
            else:
                print(f"\n=== DATABASE NOT FOUND: {db_name} ===")
                print(f"Database '{db_name}' does not exist on the server.")
    
    print("\n" + "=" * 50)
    print("Database discovery complete!") 