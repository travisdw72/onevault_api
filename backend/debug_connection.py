#!/usr/bin/env python3
"""
Debug database connection issues
"""

import psycopg2
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def debug_connection():
    """Debug the database connection step by step"""
    
    print("=== DATABASE CONNECTION DEBUG ===")
    
    # Show environment variables
    print("\nEnvironment Variables:")
    print(f"DB_HOST: {os.getenv('DB_HOST')}")
    print(f"DB_PORT: {os.getenv('DB_PORT')}")
    print(f"DB_ADMIN_USER: {os.getenv('DB_ADMIN_USER')}")
    print(f"DB_ADMIN_PASSWORD: {'*' * len(os.getenv('DB_ADMIN_PASSWORD', '')) if os.getenv('DB_ADMIN_PASSWORD') else 'None'}")
    print(f"DB_NAME: {os.getenv('DB_NAME')}")
    
    # Try different database connections
    databases_to_try = [
        'postgres',
        'testing_one_management_db',  # Updated with _db suffix
        'testing_one_management',     # Try without suffix too
        os.getenv('DB_NAME', 'one_vault'),
        'one_barn_db'
    ]
    
    for db_name in databases_to_try:
        print(f"\n--- Trying to connect to: {db_name} ---")
        
        db_params = {
            'host': os.getenv('DB_HOST', '127.0.0.1'),
            'port': os.getenv('DB_PORT', '5432'),
            'user': os.getenv('DB_ADMIN_USER', 'onevault_implementation'),
            'password': os.getenv('DB_ADMIN_PASSWORD', 'Implement2024!Secure#'),
            'database': db_name
        }
        
        try:
            print(f"Attempting connection with:")
            print(f"  Host: {db_params['host']}")
            print(f"  Port: {db_params['port']}")
            print(f"  User: {db_params['user']}")
            print(f"  Database: {db_params['database']}")
            
            conn = psycopg2.connect(**db_params)
            cursor = conn.cursor()
            
            # Test the connection
            cursor.execute("SELECT current_database(), current_user, version()")
            result = cursor.fetchone()
            
            print(f"✅ SUCCESS!")
            print(f"  Connected to database: {result[0]}")
            print(f"  Connected as user: {result[1]}")
            print(f"  PostgreSQL version: {result[2][:50]}...")
            
            # Get basic info
            cursor.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_type = 'BASE TABLE'")
            table_count = cursor.fetchone()[0]
            print(f"  Total tables: {table_count}")
            
            cursor.close()
            conn.close()
            
            # If we successfully connected to this database, explore it further
            if db_name in ['testing_one_management', 'testing_one_management_db']:
                explore_testing_db_details(db_params)
            
        except psycopg2.OperationalError as e:
            print(f"❌ Connection failed: {e}")
        except psycopg2.Error as e:
            print(f"❌ Database error: {e}")
        except Exception as e:
            print(f"❌ Unexpected error: {e}")

def explore_testing_db_details(db_params):
    """Get more details about the testing database"""
    
    print(f"\n=== DETAILED EXPLORATION OF {db_params['database']} ===")
    
    try:
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
        print(f"Custom schemas: {schemas}")
        
        # Get table counts by schema
        for schema in schemas:
            cursor.execute("""
                SELECT COUNT(*) 
                FROM information_schema.tables 
                WHERE table_schema = %s AND table_type = 'BASE TABLE';
            """, (schema,))
            
            count = cursor.fetchone()[0]
            print(f"  {schema}: {count} tables")
            
            if count > 0 and count <= 20:  # Show table names for smaller schemas
                cursor.execute("""
                    SELECT table_name
                    FROM information_schema.tables 
                    WHERE table_schema = %s AND table_type = 'BASE TABLE'
                    ORDER BY table_name;
                """, (schema,))
                
                tables = [row[0] for row in cursor.fetchall()]
                print(f"    Tables: {', '.join(tables)}")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"Error exploring database: {e}")

if __name__ == "__main__":
    debug_connection() 