#!/usr/bin/env python3
"""
Investigate Actual Function in Database
Let's see what the real equine_care_reasoning function looks like
"""

import psycopg2
import getpass
from datetime import datetime

def investigate_actual_function():
    """Get the actual source code of the function from the database"""
    
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
        
        print("🔍 Investigating ACTUAL Function Source Code")
        print("=" * 60)
        
        # Get the actual function source code
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                pg_get_functiondef(p.oid) as function_definition,
                p.prokind as function_kind,
                p.provolatile as volatility,
                p.prosecdef as security_definer
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'ai_agents' 
            AND p.proname = 'equine_care_reasoning';
        """)
        
        function_info = cursor.fetchone()
        if function_info:
            print(f"Function Name: {function_info[0]}")
            print(f"Function Kind: {function_info[2]}")
            print(f"Volatility: {function_info[3]}")
            print(f"Security Definer: {function_info[4]}")
            print()
            print("ACTUAL FUNCTION SOURCE CODE:")
            print("=" * 80)
            print(function_info[1])
            print("=" * 80)
        else:
            print("❌ Function not found!")
            return False
        
        # Also check what other AI agent functions exist
        print("\n🤖 Other AI Agent Functions:")
        print("-" * 40)
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                pg_get_function_arguments(p.oid) as arguments,
                CASE p.prokind
                    WHEN 'f' THEN 'function'
                    WHEN 'p' THEN 'procedure'
                    WHEN 'a' THEN 'aggregate'
                    WHEN 'w' THEN 'window'
                    ELSE 'other'
                END as type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'ai_agents'
            AND p.proname LIKE '%reasoning%'
            ORDER BY p.proname;
        """)
        
        other_functions = cursor.fetchall()
        for func_name, args, func_type in other_functions:
            print(f"   📋 {func_name}({args}) - {func_type}")
        
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
    print("🔎 Real Function Investigation")
    print("=" * 50)
    print(f"Started at: {datetime.now()}")
    print()
    
    success = investigate_actual_function()
    
    print()
    print("=" * 50)
    print(f"Investigation completed at: {datetime.now()}")
    
    if success:
        print("🎉 SUCCESS: Function investigation completed!")
    else:
        print("❌ FAILED: Investigation unsuccessful") 