#!/usr/bin/env python3
"""
Investigation Script: What Agent Functions Actually Exist?
Investigates actual schemas and functions to fix the production script
"""

import psycopg2
import json
from datetime import datetime
import getpass

def investigate_agent_functions():
    """Investigate what agent functions actually exist in the database"""
    
    # Get database connection details
    print("🔍 Investigating actual agent functions in database...")
    print("=" * 60)
    
    # Get password securely
    db_password = getpass.getpass("Enter database password: ")
    
    try:
        # Connect to database
        conn = psycopg2.connect(
            host="localhost",
            port="5432",
            database="one_vault",
            user="postgres",
            password=db_password
        )
        cursor = conn.cursor()
        
        print("✅ Connected to database successfully")
        print()
        
        # 1. Check what schemas exist with 'agent' in the name
        print("1. SCHEMAS WITH 'AGENT' IN NAME:")
        print("-" * 40)
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name ILIKE '%agent%'
            ORDER BY schema_name;
        """)
        schemas = cursor.fetchall()
        
        if schemas:
            for schema in schemas:
                print(f"   ✅ {schema[0]}")
        else:
            print("   ❌ No schemas found with 'agent' in name")
        print()
        
        # 2. Check what functions exist with 'agent' in the name
        print("2. FUNCTIONS WITH 'AGENT' IN NAME:")
        print("-" * 40)
        cursor.execute("""
            SELECT 
                routine_schema,
                routine_name,
                routine_type,
                data_type as return_type
            FROM information_schema.routines 
            WHERE routine_name ILIKE '%agent%'
            AND routine_schema NOT IN ('information_schema', 'pg_catalog')
            ORDER BY routine_schema, routine_name;
        """)
        functions = cursor.fetchall()
        
        if functions:
            for func in functions:
                schema, name, type_, return_type = func
                print(f"   ✅ {schema}.{name}() - {type_} returning {return_type}")
        else:
            print("   ❌ No functions found with 'agent' in name")
        print()
        
        # 3. Check specifically for the functions we're trying to call
        print("3. CHECKING SPECIFIC FUNCTIONS WE'RE CALLING:")
        print("-" * 40)
        target_functions = [
            'process_agent_request',
            'vet_agent_process'
        ]
        
        for func_name in target_functions:
            cursor.execute("""
                SELECT 
                    routine_schema,
                    routine_name,
                    routine_type,
                    data_type as return_type,
                    external_language
                FROM information_schema.routines 
                WHERE routine_name = %s
                AND routine_schema NOT IN ('information_schema', 'pg_catalog')
                ORDER BY routine_schema;
            """, (func_name,))
            
            results = cursor.fetchall()
            
            print(f"   🔍 {func_name}:")
            if results:
                for result in results:
                    schema, name, type_, return_type, language = result
                    print(f"      ✅ Found: {schema}.{name}() - {type_} in {language}")
            else:
                print(f"      ❌ NOT FOUND anywhere in database")
        print()
        
        # 4. Check business schema for AI/ML functions
        print("4. BUSINESS SCHEMA AI/ML FUNCTIONS:")
        print("-" * 40)
        cursor.execute("""
            SELECT 
                routine_name,
                routine_type,
                data_type as return_type
            FROM information_schema.routines 
            WHERE routine_schema = 'business'
            AND (routine_name ILIKE '%ai%' OR routine_name ILIKE '%learn%')
            ORDER BY routine_name;
        """)
        business_functions = cursor.fetchall()
        
        if business_functions:
            for func in business_functions:
                name, type_, return_type = func
                print(f"   ✅ business.{name}() - {type_} returning {return_type}")
        else:
            print("   ❌ No AI/ML functions found in business schema")
        print()
        
        # 5. Check what's actually in ai_agents schema
        print("5. AI_AGENTS SCHEMA COMPLETE INVENTORY:")
        print("-" * 40)
        cursor.execute("""
            SELECT 
                routine_name,
                routine_type,
                data_type as return_type,
                external_language
            FROM information_schema.routines 
            WHERE routine_schema = 'ai_agents'
            ORDER BY routine_name;
        """)
        ai_agent_functions = cursor.fetchall()
        
        if ai_agent_functions:
            for func in ai_agent_functions:
                name, type_, return_type, language = func
                print(f"   ✅ ai_agents.{name}() - {type_} in {language}")
        else:
            print("   ❌ No functions found in ai_agents schema")
        print()
        
        # 6. Look for any horse-related functions
        print("6. HORSE-RELATED FUNCTIONS:")
        print("-" * 40)
        cursor.execute("""
            SELECT 
                routine_schema,
                routine_name,
                routine_type,
                data_type as return_type
            FROM information_schema.routines 
            WHERE routine_name ILIKE '%horse%'
            AND routine_schema NOT IN ('information_schema', 'pg_catalog')
            ORDER BY routine_schema, routine_name;
        """)
        horse_functions = cursor.fetchall()
        
        if horse_functions:
            for func in horse_functions:
                schema, name, type_, return_type = func
                print(f"   ✅ {schema}.{name}() - {type_} returning {return_type}")
        else:
            print("   ❌ No horse-related functions found")
        print()
        
        # 7. Generate the investigation summary
        print("7. INVESTIGATION SUMMARY & RECOMMENDATIONS:")
        print("=" * 60)
        
        # Check if we have the schemas we expect
        schema_names = [s[0] for s in schemas]
        has_ai_agents = 'ai_agents' in schema_names
        has_agents = 'agents' in schema_names
        
        print(f"Schema Status:")
        print(f"   - ai_agents schema: {'✅ EXISTS' if has_ai_agents else '❌ MISSING'}")
        print(f"   - agents schema: {'✅ EXISTS' if has_agents else '❌ MISSING'}")
        print()
        
        # Check if we have the functions we're trying to call
        all_functions = [f[1] for f in functions]
        has_process_agent = 'process_agent_request' in all_functions
        has_vet_agent = 'vet_agent_process' in all_functions
        
        print(f"Required Function Status:")
        print(f"   - process_agent_request(): {'✅ EXISTS' if has_process_agent else '❌ MISSING'}")
        print(f"   - vet_agent_process(): {'✅ EXISTS' if has_vet_agent else '❌ MISSING'}")
        print()
        
        # Generate recommendations
        print("RECOMMENDATIONS:")
        if not has_agents and not has_process_agent:
            print("   🚨 CRITICAL: We're calling agents.process_agent_request() but:")
            print("      - No 'agents' schema exists")
            print("      - No 'process_agent_request' function exists anywhere")
            print("   ")
            print("   💡 SOLUTION OPTIONS:")
            print("      A) Create the missing agents schema and functions")
            print("      B) Use different existing functions")
            print("      C) Create mock functions for testing")
            print("      D) Modify our script to use what actually exists")
        
        if not has_vet_agent:
            print("   🚨 CRITICAL: We're calling agents.vet_agent_process() but it doesn't exist")
            
        print()
        print("Next steps: Review the actual functions available and modify the production script accordingly")
        
    except Exception as e:
        print(f"❌ Error during investigation: {e}")
        return False
    
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()
    
    return True

if __name__ == "__main__":
    print("Agent Function Investigation")
    print("=" * 60)
    investigate_agent_functions() 