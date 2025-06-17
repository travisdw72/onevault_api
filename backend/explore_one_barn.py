#!/usr/bin/env python3
"""
Explore the one_barn_db database to see what's currently in it
"""

import psycopg2
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def explore_one_barn_db():
    """Explore the one_barn_db database in detail"""
    
    db_params = {
        'host': os.getenv('DB_HOST', '127.0.0.1'),
        'port': os.getenv('DB_PORT', '5432'),
        'user': os.getenv('DB_ADMIN_USER', 'onevault_implementation'),
        'password': os.getenv('DB_ADMIN_PASSWORD', 'Implement2024!Secure#'),
        'database': 'one_barn_db'
    }
    
    try:
        print("=== EXPLORING ONE_BARN_DB DATABASE ===")
        print(f"Connecting to: {db_params['host']}:{db_params['port']}")
        print(f"Database: {db_params['database']}")
        
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
        print(f"\nSchemas found ({len(schemas)}): {schemas}")
        
        # Check for equestrian-specific schemas
        equestrian_schemas = [s for s in schemas if any(keyword in s.lower() for keyword in ['horse', 'barn', 'stable', 'equestrian', 'stall'])]
        if equestrian_schemas:
            print(f"🐎 Equestrian schemas: {equestrian_schemas}")
        else:
            print("❌ No equestrian-specific schemas found")
        
        # Get tables by schema with Data Vault 2.0 classification
        total_tables = 0
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
                
                total_tables += len(tables)
                
                if hub_tables:
                    print(f"  Hub Tables ({len(hub_tables)}):")
                    for table in hub_tables[:10]:  # Show first 10
                        print(f"    - {table}")
                    if len(hub_tables) > 10:
                        print(f"    ... and {len(hub_tables) - 10} more")
                
                if satellite_tables:
                    print(f"  Satellite Tables ({len(satellite_tables)}):")
                    for table in satellite_tables[:10]:  # Show first 10
                        print(f"    - {table}")
                    if len(satellite_tables) > 10:
                        print(f"    ... and {len(satellite_tables) - 10} more")
                
                if link_tables:
                    print(f"  Link Tables ({len(link_tables)}):")
                    for table in link_tables[:10]:  # Show first 10
                        print(f"    - {table}")
                    if len(link_tables) > 10:
                        print(f"    ... and {len(link_tables) - 10} more")
                
                if other_tables:
                    print(f"  Other Tables ({len(other_tables)}):")
                    for table in other_tables[:10]:  # Show first 10
                        print(f"    - {table}")
                    if len(other_tables) > 10:
                        print(f"    ... and {len(other_tables) - 10} more")
        
        print(f"\nTotal tables across all schemas: {total_tables}")
        
        # Check for equestrian-specific tables
        cursor.execute("""
            SELECT table_schema, table_name
            FROM information_schema.tables 
            WHERE table_name ILIKE '%horse%' 
               OR table_name ILIKE '%barn%'
               OR table_name ILIKE '%stall%'
               OR table_name ILIKE '%owner%'
               OR table_name ILIKE '%equestrian%'
               OR table_name ILIKE '%boarding%'
               OR table_name ILIKE '%veterinary%'
               OR table_name ILIKE '%trainer%'
            ORDER BY table_schema, table_name;
        """)
        
        equestrian_tables = cursor.fetchall()
        
        if equestrian_tables:
            print(f"\n🐎 EQUESTRIAN-RELATED TABLES ({len(equestrian_tables)}) ===")
            for schema, table in equestrian_tables:
                print(f"  - {schema}.{table}")
        else:
            print(f"\n❌ NO EQUESTRIAN TABLES FOUND")
            print("This appears to be a generic OneVault database without equestrian customization.")
        
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
            print(f"\n✅ DATA VAULT 2.0 FUNCTIONS FOUND ({len(functions)}) ===")
            for schema, func_name, func_type in functions:
                print(f"  - {schema}.{func_name} ({func_type})")
        else:
            print(f"\n❌ NO DATA VAULT 2.0 FUNCTIONS FOUND")
        
        # Check for tenant data
        cursor.execute("""
            SELECT table_schema, table_name
            FROM information_schema.tables 
            WHERE table_name ILIKE '%tenant%'
            ORDER BY table_schema, table_name;
        """)
        
        tenant_tables = cursor.fetchall()
        
        if tenant_tables:
            print(f"\n🏢 TENANT TABLES FOUND ({len(tenant_tables)}) ===")
            for schema, table in tenant_tables:
                print(f"  - {schema}.{table}")
                
                # Get row count for tenant tables
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM {schema}.{table}")
                    count = cursor.fetchone()[0]
                    print(f"    Rows: {count}")
                    
                    if count > 0 and count < 20:  # Show sample data for small tables
                        cursor.execute(f"SELECT * FROM {schema}.{table} LIMIT 3")
                        rows = cursor.fetchall()
                        
                        # Get column names
                        cursor.execute(f"""
                            SELECT column_name 
                            FROM information_schema.columns 
                            WHERE table_schema = %s AND table_name = %s 
                            ORDER BY ordinal_position
                        """, (schema, table))
                        columns = [row[0] for row in cursor.fetchall()]
                        
                        print(f"    Sample data:")
                        for row in rows:
                            sample_data = dict(zip(columns, row))
                            # Only show first few fields to avoid clutter
                            limited_data = {k: v for i, (k, v) in enumerate(sample_data.items()) if i < 5}
                            print(f"      {limited_data}")
                        
                except Exception as e:
                    print(f"    Error accessing data: {e}")
        
        cursor.close()
        conn.close()
        
        return True
        
    except psycopg2.Error as e:
        print(f"Database connection error: {e}")
        return False

if __name__ == "__main__":
    print("One Barn Database Explorer")
    print("=" * 60)
    
    success = explore_one_barn_db()
    
    if success:
        print("\n" + "=" * 60)
        print("✅ Database exploration complete!")
        print("\nNext steps:")
        print("1. If equestrian tables are missing, run the one_barn schema creation script")
        print("2. If tables exist, verify they match the expected One Barn configuration")
        print("3. Test the application connection to ensure everything works")
    else:
        print("\n❌ Database exploration failed!")
        print("Check database connection and credentials.") 