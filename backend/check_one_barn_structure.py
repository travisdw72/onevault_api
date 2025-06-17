#!/usr/bin/env python3
"""
Check One Barn Database Structure and Users
"""
import psycopg2
from psycopg2.extras import RealDictCursor

def check_database():
    try:
        # Connect to one_barn_db
        conn = psycopg2.connect(
            host='127.0.0.1',
            port=5432,
            database='one_barn_db',
            user='onevault_implementation',
            password='Implement2024!Secure#'
        )
        
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        print("=== ONE BARN DATABASE STRUCTURE CHECK ===")
        print(f"Connected to: one_barn_db")
        
        # Check current user and permissions
        cur.execute("SELECT current_user, session_user;")
        user_info = cur.fetchone()
        print(f"Current user: {user_info['current_user']}")
        print(f"Session user: {user_info['session_user']}")
        
        # Check existing schemas
        cur.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
            ORDER BY schema_name;
        """)
        schemas = [row['schema_name'] for row in cur.fetchall()]
        print(f"\nExisting schemas: {schemas}")
        
        # Check if equestrian schema exists
        if 'equestrian' in schemas:
            print("✅ Equestrian schema exists")
            
            # Check equestrian tables
            cur.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'equestrian'
                ORDER BY table_name;
            """)
            equestrian_tables = [row['table_name'] for row in cur.fetchall()]
            print(f"Equestrian tables: {equestrian_tables}")
        else:
            print("❌ Equestrian schema missing")
        
        # Check if health, finance, performance schemas exist
        missing_schemas = []
        for schema in ['health', 'finance', 'performance', 'equestrian']:
            if schema not in schemas:
                missing_schemas.append(schema)
        
        if missing_schemas:
            print(f"❌ Missing schemas: {missing_schemas}")
        else:
            print("✅ All business schemas exist")
        
        # Check database users
        cur.execute("""
            SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin 
            FROM pg_roles 
            WHERE rolname NOT LIKE 'pg_%'
            ORDER BY rolname;
        """)
        users = cur.fetchall()
        print(f"\nDatabase users:")
        for user in users:
            print(f"  - {user['rolname']}: super={user['rolsuper']}, login={user['rolcanlogin']}")
        
        # Check if barn_user exists
        cur.execute("SELECT 1 FROM pg_roles WHERE rolname = 'barn_user';")
        barn_user_exists = cur.fetchone() is not None
        print(f"\nBarn user exists: {barn_user_exists}")
        
        # Check table counts per schema
        print(f"\nTable counts per schema:")
        for schema in schemas:
            cur.execute("""
                SELECT COUNT(*) as table_count
                FROM information_schema.tables 
                WHERE table_schema = %s;
            """, (schema,))
            count = cur.fetchone()['table_count']
            print(f"  {schema}: {count} tables")
        
        conn.close()
        
        # Recommendations
        print(f"\n=== RECOMMENDATIONS ===")
        if missing_schemas:
            print(f"1. Need to add missing schemas: {missing_schemas}")
        if not barn_user_exists:
            print(f"2. Need to create barn_user for application access")
        if 'equestrian' not in schemas:
            print(f"3. Need to add equestrian schema for horse management")
        
        return {
            'schemas': schemas,
            'missing_schemas': missing_schemas,
            'barn_user_exists': barn_user_exists,
            'equestrian_exists': 'equestrian' in schemas
        }
        
    except Exception as e:
        print(f"Error: {e}")
        return None

if __name__ == "__main__":
    check_database() 