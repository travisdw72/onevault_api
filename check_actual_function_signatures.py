#!/usr/bin/env python3
"""
Check Actual Function Signatures
Find out what functions actually exist and their exact parameter signatures
"""

import psycopg2
import getpass

def check_function_signatures():
    """Check actual function signatures in ai_agents schema"""
    
    print("🔍 Checking Actual Function Signatures in ai_agents Schema")
    print("=" * 70)
    
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
        
        # Get all functions in ai_agents schema with their parameters
        cursor.execute("""
            SELECT 
                r.routine_name,
                r.data_type as return_type,
                p.parameter_name,
                p.data_type as param_type,
                p.ordinal_position
            FROM information_schema.routines r
            LEFT JOIN information_schema.parameters p 
                ON r.routine_schema = p.specific_schema 
                AND r.routine_name = p.specific_name
            WHERE r.routine_schema = 'ai_agents'
            AND r.routine_type = 'FUNCTION'
            ORDER BY r.routine_name, p.ordinal_position;
        """)
        
        results = cursor.fetchall()
        
        if results:
            print("📋 ALL AI_AGENTS FUNCTIONS WITH SIGNATURES:")
            print("-" * 70)
            
            current_function = None
            parameters = []
            
            for row in results:
                func_name, return_type, param_name, param_type, position = row
                
                if func_name != current_function:
                    # Print previous function if exists
                    if current_function:
                        param_str = ", ".join(parameters) if parameters else "no parameters"
                        print(f"   {current_function}({param_str}) RETURNS {prev_return_type}")
                    
                    # Start new function
                    current_function = func_name
                    prev_return_type = return_type
                    parameters = []
                
                if param_name:  # Some functions have no parameters
                    parameters.append(f"{param_name} {param_type}")
            
            # Don't forget the last function
            if current_function:
                param_str = ", ".join(parameters) if parameters else "no parameters"
                print(f"   {current_function}({param_str}) RETURNS {prev_return_type}")
            
            print()
            
            # Now check specifically for equine-related functions
            print("🐴 EQUINE-RELATED FUNCTIONS:")
            print("-" * 70)
            
            cursor.execute("""
                SELECT 
                    r.routine_name,
                    r.data_type as return_type,
                    string_agg(
                        COALESCE(p.parameter_name, 'no_params') || ' ' || COALESCE(p.data_type, ''),
                        ', ' ORDER BY p.ordinal_position
                    ) as parameters
                FROM information_schema.routines r
                LEFT JOIN information_schema.parameters p 
                    ON r.routine_schema = p.specific_schema 
                    AND r.routine_name = p.specific_name
                    AND p.parameter_mode = 'IN'
                WHERE r.routine_schema = 'ai_agents'
                AND r.routine_type = 'FUNCTION'
                AND (r.routine_name ILIKE '%equine%' 
                     OR r.routine_name ILIKE '%horse%'
                     OR r.routine_name ILIKE '%care%'
                     OR r.routine_name ILIKE '%vet%'
                     OR r.routine_name ILIKE '%medical%')
                GROUP BY r.routine_name, r.data_type
                ORDER BY r.routine_name;
            """)
            
            equine_functions = cursor.fetchall()
            
            for func in equine_functions:
                name, return_type, params = func
                print(f"   ✅ {name}({params}) RETURNS {return_type}")
            
            print()
            
            # Check what our corrected function is actually trying to call
            print("🎯 WHAT OUR CORRECTED FUNCTION SHOULD CALL:")
            print("-" * 70)
            
            if equine_functions:
                print("   Based on available functions, we should be calling:")
                for func in equine_functions:
                    name, return_type, params = func
                    print(f"   ai_agents.{name}() with proper parameters")
            else:
                print("   ❌ No equine-related functions found!")
                print("   ⚠️  This explains why our test 'succeeded' but didn't actually work")
            
        else:
            print("❌ No functions found in ai_agents schema")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    check_function_signatures() 