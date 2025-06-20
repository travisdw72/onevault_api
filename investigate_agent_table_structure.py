#!/usr/bin/env python3
"""
Investigate AI Agents Table Structure
Understanding the real schema structure for agent testing
"""

import psycopg2
import getpass
from datetime import datetime

def investigate_ai_agents_schema():
    """Investigate the actual structure of ai_agents tables"""
    
    try:
        # Get password securely
        print("🔐 One Vault Database Connection")
        print("=" * 40)
        password = getpass.getpass("Enter PostgreSQL password: ")
        
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            database='one_vault',
            user='postgres',
            password=password
        )
        cursor = conn.cursor()
        
        print("✅ Connected to database successfully")
        print()
        
        print("🔍 Investigating AI Agents Schema Structure")
        print("=" * 60)
        
        # 1. Get all tables in ai_agents schema
        print("1. Tables in ai_agents schema:")
        print("-" * 40)
        cursor.execute("""
            SELECT table_name, table_type
            FROM information_schema.tables 
            WHERE table_schema = 'ai_agents'
            ORDER BY table_name;
        """)
        
        tables = cursor.fetchall()
        for table_name, table_type in tables:
            print(f"   📋 {table_name} ({table_type})")
        
        print(f"\nFound {len(tables)} tables/views in ai_agents schema")
        
        # 2. Investigate agent_session tables specifically
        print("\n2. Agent Session Tables Structure:")
        print("-" * 40)
        
        session_tables = [t[0] for t in tables if 'session' in t[0]]
        for table_name in session_tables:
            print(f"\n📊 Table: {table_name}")
            cursor.execute("""
                SELECT 
                    column_name,
                    data_type,
                    is_nullable,
                    column_default
                FROM information_schema.columns 
                WHERE table_schema = 'ai_agents' 
                AND table_name = %s
                ORDER BY ordinal_position;
            """, (table_name,))
            
            columns = cursor.fetchall()
            for col_name, data_type, nullable, default in columns:
                print(f"   🔹 {col_name}: {data_type} {'(nullable)' if nullable == 'YES' else '(not null)'}")
                if default:
                    print(f"      Default: {default}")
        
        # 3. Get the exact function signature again
        print("\n3. Equine Care Reasoning Function Signature:")
        print("-" * 50)
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                p.pronargs as num_args,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type,
                pg_get_function_identity_arguments(p.oid) as identity_args
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'ai_agents' 
            AND p.proname = 'equine_care_reasoning';
        """)
        
        function_info = cursor.fetchone()
        if function_info:
            print(f"Function: {function_info[0]}")
            print(f"Number of Args: {function_info[1]}")
            print(f"Arguments: {function_info[2]}")
            print(f"Return Type: {function_info[3]}")
            print(f"Identity Args: {function_info[4]}")
        else:
            print("❌ Function not found!")
        
        # 4. Check if we need to understand agent identity table structure
        print("\n4. Agent Identity Tables Structure:")
        print("-" * 40)
        
        identity_tables = [t[0] for t in tables if 'identity' in t[0]]
        for table_name in identity_tables:
            print(f"\n📊 Table: {table_name}")
            cursor.execute("""
                SELECT 
                    column_name,
                    data_type,
                    is_nullable
                FROM information_schema.columns 
                WHERE table_schema = 'ai_agents' 
                AND table_name = %s
                ORDER BY ordinal_position;
            """, (table_name,))
            
            columns = cursor.fetchall()
            for col_name, data_type, nullable in columns:
                print(f"   🔹 {col_name}: {data_type} {'(nullable)' if nullable == 'YES' else '(not null)'}")
        
        # 5. Check knowledge domain tables
        print("\n5. Knowledge Domain Tables Structure:")
        print("-" * 40)
        
        domain_tables = [t[0] for t in tables if 'domain' in t[0]]
        for table_name in domain_tables:
            print(f"\n📊 Table: {table_name}")
            cursor.execute("""
                SELECT 
                    column_name,
                    data_type,
                    is_nullable
                FROM information_schema.columns 
                WHERE table_schema = 'ai_agents' 
                AND table_name = %s
                ORDER BY ordinal_position;
            """, (table_name,))
            
            columns = cursor.fetchall()
            for col_name, data_type, nullable in columns:
                print(f"   🔹 {col_name}: {data_type} {'(nullable)' if nullable == 'YES' else '(not null)'}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    print("🔎 AI Agents Schema Investigation")
    print("=" * 50)
    print(f"Started at: {datetime.now()}")
    print()
    
    success = investigate_ai_agents_schema()
    
    print()
    print("=" * 50)
    print(f"Investigation completed at: {datetime.now()}")
    
    if success:
        print("🎉 SUCCESS: Schema investigation completed!")
    else:
        print("❌ FAILED: Investigation unsuccessful") 