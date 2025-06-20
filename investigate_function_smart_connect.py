#!/usr/bin/env python3
"""
Smart Database Connection and Function Investigation
Uses multiple password attempts like the working test_login_ready.py script
"""

import os
import psycopg2
import json
from datetime import datetime

# Common database passwords from the project
COMMON_PASSWORDS = [
    'password',
    'postgres', 
    'ReadOnly2024!Secure#',
    'Implement2024!Secure#',
    'your_postgres_password_here',
    os.getenv('DB_PASSWORD', ''),
    '',  # Empty password
]

def try_database_connection():
    """Try connecting with common passwords"""
    print("🔌 Trying database connection with common passwords...")
    
    for password in COMMON_PASSWORDS:
        if not password:  # Skip empty passwords
            continue
            
        try:
            print(f"   Trying password: {'*' * min(len(password), 10)}...")
            conn = psycopg2.connect(
                host='localhost',
                port=5432,
                database='one_vault',
                user='postgres',
                password=password
            )
            print(f"✅ Database connection successful!")
            return conn, password
        except Exception as e:
            print(f"   ❌ Failed: {str(e)[:50]}...")
            continue
    
    print("❌ None of the common passwords worked")
    return None, None

def investigate_equine_function():
    """Investigate the actual equine care reasoning function"""
    print("🔍 AI Function Investigation with Smart Connection")
    print("=" * 60)
    
    # Try database connection
    conn, db_password = try_database_connection()
    if not conn:
        print("\n❌ Could not connect to database with any known passwords.")
        print("Please set DB_PASSWORD environment variable or update the script.")
        return False
    
    try:
        cursor = conn.cursor()
        
        print("\n📋 Step 1: Get Function Source Code")
        print("-" * 40)
        
        # Get the actual function definition
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                pg_get_functiondef(p.oid) as function_definition,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'ai_agents' 
            AND p.proname = 'equine_care_reasoning';
        """)
        
        function_info = cursor.fetchone()
        if function_info:
            print(f"✅ Function Found: {function_info[0]}")
            print(f"📝 Arguments: {function_info[2]}")
            print(f"📤 Returns: {function_info[3]}")
            print()
            print("🔍 FULL FUNCTION SOURCE CODE:")
            print("=" * 80)
            print(function_info[1])
            print("=" * 80)
        else:
            print("❌ Function not found!")
            return False
        
        print("\n📋 Step 2: Check Agent Session Tables Structure")
        print("-" * 40)
        
        # Check agent_session_h structure
        cursor.execute("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'ai_agents' 
            AND table_name = 'agent_session_h'
            ORDER BY ordinal_position;
        """)
        
        h_columns = cursor.fetchall()
        print("🏢 agent_session_h columns:")
        for col_name, data_type, nullable in h_columns:
            print(f"   📋 {col_name}: {data_type} {'(nullable)' if nullable == 'YES' else '(not null)'}")
        
        # Check agent_session_s structure  
        cursor.execute("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'ai_agents' 
            AND table_name = 'agent_session_s'
            ORDER BY ordinal_position;
        """)
        
        s_columns = cursor.fetchall()
        print("\n📊 agent_session_s columns:")
        for col_name, data_type, nullable in s_columns:
            print(f"   📋 {col_name}: {data_type} {'(nullable)' if nullable == 'YES' else '(not null)'}")
        
        print("\n📋 Step 3: Check for Sample Session Data")
        print("-" * 40)
        
        # Check if there are any sessions
        cursor.execute("""
            SELECT COUNT(*) as session_count
            FROM ai_agents.agent_session_h;
        """)
        
        session_count = cursor.fetchone()[0]
        print(f"📊 Total sessions in database: {session_count}")
        
        if session_count > 0:
            cursor.execute("""
                SELECT 
                    sh.session_hk,
                    encode(sh.session_hk, 'hex') as session_hk_hex,
                    sh.session_bk,
                    ss.session_token,
                    ss.session_status,
                    ss.session_expires
                FROM ai_agents.agent_session_h sh
                JOIN ai_agents.agent_session_s ss ON sh.session_hk = ss.session_hk
                WHERE ss.load_end_date IS NULL
                LIMIT 3;
            """)
            
            sample_sessions = cursor.fetchall()
            print(f"📋 Sample active sessions:")
            for session in sample_sessions:
                print(f"   🔑 Session: {session[1][:16]}... ({session[4]}) expires: {session[5]}")
        
        print("\n📋 Step 4: Test Function Call with Mock Data")
        print("-" * 40)
        
        # Test the function with proper parameter types
        test_data = {
            "session_token": "test_session_token_123",
            "horse_data": {
                "horse_id": "test_horse_001",
                "breed": "Arabian",
                "age": 8,
                "weight": 1100,
                "height": "15.2 hands"
            },
            "health_metrics": {
                "temperature": 99.5,
                "heart_rate": 40,
                "respiratory_rate": 16,
                "capillary_refill": 2
            },
            "behavior_observations": {
                "energy_level": "normal",
                "appetite": "good", 
                "gait": "normal",
                "alertness": "alert"
            }
        }
        
        try:
            # Call the function
            cursor.execute("""
                SELECT ai_agents.equine_care_reasoning(
                    %s::character varying,
                    %s::jsonb,
                    %s::jsonb,
                    %s::jsonb
                ) as result;
            """, (
                test_data["session_token"],
                json.dumps(test_data["horse_data"]),
                json.dumps(test_data["health_metrics"]), 
                json.dumps(test_data["behavior_observations"])
            ))
            
            result = cursor.fetchone()
            function_result = result[0] if result else None
            
            print("🎯 FUNCTION CALL RESULT:")
            print("=" * 40)
            if function_result:
                # Pretty print the JSON result
                if isinstance(function_result, dict):
                    print(json.dumps(function_result, indent=2))
                else:
                    print(function_result)
                print("=" * 40)
                
                # Analyze the result
                if isinstance(function_result, dict):
                    success = function_result.get('success', False)
                    error = function_result.get('error', None)
                    
                    if success:
                        print("🎉 Function executed successfully!")
                    else:
                        print(f"⚠️  Function returned controlled error: {error}")
                        if 'session' in error.lower():
                            print("   💡 This is expected - we used a fake session token")
                        elif 'unauthorized' in error.lower():
                            print("   💡 This is expected - security validation working")
                else:
                    print("📊 Function returned non-JSON result")
            else:
                print("❌ No result returned from function")
                
        except Exception as e:
            print(f"❌ Function call failed: {e}")
            print("   💡 This might be due to parameter type mismatches")
        
        return True
        
    except Exception as e:
        print(f"❌ Investigation failed: {e}")
        return False
    
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

if __name__ == "__main__":
    print("🔎 Smart AI Function Investigation")
    print("=" * 50)
    print(f"Started at: {datetime.now()}")
    print()
    
    success = investigate_equine_function()
    
    print()
    print("=" * 50)
    print(f"Investigation completed at: {datetime.now()}")
    
    if success:
        print("🎉 SUCCESS: Function investigation completed!")
    else:
        print("❌ FAILED: Investigation unsuccessful") 