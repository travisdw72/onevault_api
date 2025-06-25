#!/usr/bin/env python3
"""
Debug script to check if api.track_site_event function exists in Neon database
"""
import os
import psycopg2
import json
from datetime import datetime

def test_database_connection():
    """Test database connection and function existence"""
    
    # Get database URL from environment
    database_url = os.getenv('SYSTEM_DATABASE_URL')
    if not database_url:
        print("❌ SYSTEM_DATABASE_URL environment variable not set")
        return False
    
    print(f"🔗 Connecting to database...")
    print(f"Database URL: {database_url[:50]}...")  # Only show first 50 chars for security
    
    try:
        # Connect to database
        conn = psycopg2.connect(database_url)
        cursor = conn.cursor()
        print("✅ Database connection successful")
        
        # Test 1: Check if api schema exists
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name = 'api'
        """)
        result = cursor.fetchone()
        if result:
            print("✅ 'api' schema exists")
        else:
            print("❌ 'api' schema does not exist")
            return False
        
        # Test 2: Check if the specific function exists
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api' 
            AND p.proname = 'track_site_event'
        """)
        functions = cursor.fetchall()
        
        if functions:
            print("✅ Function api.track_site_event found:")
            for func in functions:
                print(f"   Function: {func[0]}")
                print(f"   Arguments: {func[1]}")
                print(f"   Returns: {func[2]}")
        else:
            print("❌ Function api.track_site_event does NOT exist")
            
            # Check what functions DO exist in api schema
            cursor.execute("""
                SELECT p.proname as function_name
                FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid
                WHERE n.nspname = 'api'
            """)
            api_functions = cursor.fetchall()
            if api_functions:
                print("📋 Functions that DO exist in 'api' schema:")
                for func in api_functions:
                    print(f"   - {func[0]}")
            else:
                print("📋 No functions exist in 'api' schema")
            return False
        
        # Test 3: Try to call the function with test data
        print("\n🧪 Testing function call...")
        cursor.execute("""
            SELECT api.track_site_event(
                %s, %s, %s, %s, %s
            )
        """, (
            '192.168.1.100',  # p_ip_address (INET)
            'Test-User-Agent/1.0',  # p_user_agent (TEXT)
            'https://example.com/test',  # p_page_url (TEXT)
            'test_event',  # p_event_type (VARCHAR)
            json.dumps({'test': True})  # p_event_data (JSONB)
        ))
        
        result = cursor.fetchone()
        if result and result[0]:
            print("✅ Function call successful!")
            print(f"   Result: {result[0]}")
        else:
            print("❌ Function call returned no result")
            return False
        
        conn.commit()
        cursor.close()
        conn.close()
        print("✅ All tests passed - function should work!")
        return True
        
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

if __name__ == "__main__":
    print("🔍 OneVault API Database Function Debugger")
    print("=" * 50)
    
    success = test_database_connection()
    
    if success:
        print("\n🎉 Database function is working correctly!")
        print("   The issue is likely in the API code or request format.")
    else:
        print("\n💡 Next steps:")
        print("   1. Check if database migrations have been run")
        print("   2. Verify SYSTEM_DATABASE_URL points to correct database")
        print("   3. Run the site-tracking database scripts") 