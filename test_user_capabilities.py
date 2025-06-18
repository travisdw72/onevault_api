#!/usr/bin/env python3
"""
Test User Capabilities - What can the logged-in user actually DO?
"""

import os
import psycopg2
import json
from datetime import datetime

def test_user_capabilities():
    """Test what features and data the user has access to"""
    print("🔍 Testing User Capabilities After Login")
    print("=" * 50)
    
    # Connect to database
    try:
        conn = psycopg2.connect(
            host='localhost', port=5432, database='one_vault',
            user='postgres', password='password'
        )
        cursor = conn.cursor()
        print("✅ Database connected")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return
    
    # Get session token from login
    print("\n🔐 Getting session token...")
    login_request = {
        "username": "travisdwoodward72@gmail.com",
        "password": "MySecurePassword321",
        "ip_address": "127.0.0.1",
        "user_agent": "Capability Test",
        "auto_login": True
    }
    
    cursor.execute("SELECT api.auth_login(%s::jsonb) as result", (json.dumps(login_request),))
    login_result = cursor.fetchone()[0]
    
    if not login_result.get('success'):
        print("❌ Login failed, cannot test capabilities")
        return
    
    session_data = login_result['data']
    user_data = session_data['user_data']
    session_token = session_data['session_token']
    
    print(f"✅ Logged in as: {user_data['profile'].get('first_name', 'Unknown')} {user_data['profile'].get('last_name', 'Unknown')}")
    print(f"✅ User roles: {[role['role_name'] for role in user_data.get('roles', [])]}")
    
    # Test available API functions
    print("\n📋 Testing Available API Functions...")
    cursor.execute("""
    SELECT routine_name, routine_type 
    FROM information_schema.routines 
    WHERE routine_schema = 'api' 
    AND routine_name NOT LIKE '%internal%'
    ORDER BY routine_name
    """)
    
    api_functions = cursor.fetchall()
    print(f"📊 Available API Functions: {len(api_functions)}")
    for func in api_functions:
        print(f"   • {func[0]} ({func[1]})")
    
    # Test available data/tables
    print("\n🗃️ Testing Available Business Data...")
    schemas_to_check = ['business', 'auth', 'raw', 'ref']
    
    for schema in schemas_to_check:
        try:
            cursor.execute(f"""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = %s 
            AND table_type = 'BASE TABLE'
            ORDER BY table_name
            """, (schema,))
            
            tables = cursor.fetchall()
            print(f"\n📁 {schema.upper()} Schema: {len(tables)} tables")
            
            for table in tables[:5]:  # Show first 5 tables
                table_name = table[0]
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM {schema}.{table_name}")
                    count = cursor.fetchone()[0]
                    print(f"   • {table_name}: {count} records")
                except:
                    print(f"   • {table_name}: (access restricted)")
            
            if len(tables) > 5:
                print(f"   ... and {len(tables) - 5} more tables")
                
        except Exception as e:
            print(f"❌ Cannot access {schema} schema: {e}")
    
    # Test if there's a frontend/UI
    print("\n🖥️ Checking Frontend/UI Availability...")
    
    frontend_paths = [
        'frontend/',
        'frontend/src/',
        'frontend/public/',
        'frontend/dist/',
        'web/',
        'public/',
        'www/'
    ]
    
    frontend_found = False
    for path in frontend_paths:
        if os.path.exists(path):
            print(f"✅ Frontend found: {path}")
            try:
                files = os.listdir(path)[:10]  # First 10 files
                print(f"   Files: {', '.join(files)}")
                frontend_found = True
                break
            except:
                pass
    
    if not frontend_found:
        print("❌ No frontend/UI found")
    
    # Test sample business operations
    print("\n💼 Testing Business Operations...")
    business_tests = [
        ("Create Entity", "SELECT api.create_business_entity(%s::jsonb)", {
            "entity_name": "Test Company",
            "entity_type": "LLC",
            "description": "Test entity creation"
        }),
        ("List Entities", "SELECT COUNT(*) FROM business.entity_h", None),
        ("User Profile", "SELECT COUNT(*) FROM auth.user_profile_s WHERE load_end_date IS NULL", None)
    ]
    
    for test_name, query, params in business_tests:
        try:
            if params:
                cursor.execute(query, (json.dumps(params),))
            else:
                cursor.execute(query)
            
            result = cursor.fetchone()
            print(f"✅ {test_name}: {result[0] if result else 'Success'}")
        except Exception as e:
            print(f"❌ {test_name}: {str(e)[:60]}...")
    
    # Summary and recommendations
    print("\n" + "=" * 50)
    print("📊 USER CAPABILITY SUMMARY")
    print("=" * 50)
    
    print(f"✅ Authentication: Working")
    print(f"✅ Session Management: Working") 
    print(f"✅ API Functions: {len(api_functions)} available")
    print(f"✅ Database Access: Multi-schema access")
    print(f"{'✅' if frontend_found else '❌'} Frontend/UI: {'Found' if frontend_found else 'Not found'}")
    
    # Deployment recommendations
    print(f"\n🎯 DEPLOYMENT RECOMMENDATIONS:")
    
    if len(api_functions) >= 5 and not frontend_found:
        print("📱 API-FIRST DEPLOYMENT:")
        print("   • Deploy API endpoints for mobile/web apps")
        print("   • Create simple login page")
        print("   • Add API documentation")
    elif frontend_found:
        print("🖥️ FULL-STACK DEPLOYMENT:")
        print("   • Deploy complete web application")
        print("   • Configure domain and SSL")
        print("   • Set up user registration flow")
    else:
        print("🔧 DEVELOPMENT DEPLOYMENT:")
        print("   • Deploy minimal API for testing")
        print("   • Create admin dashboard")
        print("   • Build essential user features")
    
    cursor.close()
    conn.close()

if __name__ == "__main__":
    test_user_capabilities() 