#!/usr/bin/env python3
"""
Test Validate and Extend Token System
Tests the enhanced validate_and_extend_production_token functionality
"""

import psycopg2
import os
from psycopg2.extras import RealDictCursor
from datetime import datetime
import json

# Database connection
def get_db_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        database=os.getenv('DB_NAME', 'One_Vault'),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASSWORD', 'postgres'),
        port=os.getenv('DB_PORT', 5432),
        cursor_factory=RealDictCursor
    )

def test_functions_exist(conn):
    """Test if all new functions exist"""
    print("\n🔍 Testing if validate and extend functions exist...")
    print("=" * 70)
    
    functions_to_check = [
        'auth.validate_and_extend_production_token',
        'auth.api_extend_token', 
        'auth.get_token_extension_stats'
    ]
    
    for func_name in functions_to_check:
        try:
            with conn.cursor() as cur:
                cur.execute(f"""
                    SELECT EXISTS (
                        SELECT 1 FROM pg_proc p
                        JOIN pg_namespace n ON p.pronamespace = n.oid 
                        WHERE n.nspname = '{func_name.split('.')[0]}'
                        AND p.proname = '{func_name.split('.')[1]}'
                    )
                """)
                exists = cur.fetchone()[0]
                status = "✅ EXISTS" if exists else "❌ MISSING"
                print(f"{status}: {func_name}")
                
        except Exception as e:
            print(f"❌ ERROR checking {func_name}: {e}")

def test_validate_and_extend_basic(conn):
    """Test basic validate and extend functionality"""
    print("\n🧪 Testing Basic Validate and Extend...")
    print("=" * 70)
    
    # Test token (replace with your actual token)
    test_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
    
    try:
        with conn.cursor() as cur:
            # Test basic validation with auto-extend enabled
            cur.execute("""
                SELECT * FROM auth.validate_and_extend_production_token(
                    %s,                    -- token
                    'api:read',           -- required scope
                    '192.168.1.100'::inet, -- client IP
                    'Test-Client/1.0',    -- user agent
                    '/api/v1/test',       -- API endpoint
                    true,                 -- auto extend
                    7,                    -- extend threshold (7 days)
                    30                    -- extension days
                )
            """, (test_token,))
            
            result = cur.fetchone()
            
            if result:
                print("📋 Validation Result:")
                print(f"   ✅ Valid: {result['is_valid']}")
                print(f"   🔑 Token Extended: {result['token_extended']}")
                print(f"   📅 New Expires At: {result['new_expires_at']}")
                print(f"   📊 Days Until Expiry: {result['days_until_expiry']}")
                print(f"   🔄 Extension Reason: {result['extension_reason']}")
                print(f"   📝 Message: {result['validation_message']}")
                print(f"   🆔 Session ID: {result['session_id']}")
                
                if result['extension_audit_id']:
                    print(f"   📋 Audit ID: {result['extension_audit_id']}")
                    
                print(f"   🏢 Tenant HK: {result['tenant_hk'].hex() if result['tenant_hk'] else 'None'}")
                print(f"   👤 User HK: {result['user_hk'].hex() if result['user_hk'] else 'None'}")
                print(f"   🔒 Security Level: {result['security_level']}")
                print(f"   📈 Rate Limit Remaining: {result['rate_limit_remaining']}")
                
            else:
                print("❌ No result returned from validation function")
                
    except Exception as e:
        print(f"❌ Error testing validate and extend: {e}")
        print(f"   SQLSTATE: {getattr(e, 'pgcode', 'Unknown')}")

def test_manual_extension_api(conn):
    """Test manual extension API"""
    print("\n🔧 Testing Manual Extension API...")
    print("=" * 70)
    
    test_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
    
    try:
        with conn.cursor() as cur:
            # Test manual extension
            cur.execute("""
                SELECT * FROM auth.api_extend_token(
                    %s,                    -- token
                    60,                   -- extend by 60 days
                    '10.0.0.1'::inet,     -- client IP
                    'Manual-Extension-Test/1.0' -- user agent
                )
            """, (test_token,))
            
            result = cur.fetchone()
            
            if result:
                print("📋 Manual Extension Result:")
                print(f"   ✅ Success: {result['success']}")
                print(f"   📝 Message: {result['message']}")
                print(f"   📅 New Expires At: {result['expires_at']}")
                print(f"   📊 Days Extended: {result['days_extended']}")
                print(f"   🆔 Audit ID: {result['audit_id']}")
            else:
                print("❌ No result returned from manual extension")
                
    except Exception as e:
        print(f"❌ Error testing manual extension: {e}")

def test_extension_stats(conn):
    """Test extension statistics dashboard"""
    print("\n📊 Testing Extension Statistics...")
    print("=" * 70)
    
    try:
        with conn.cursor() as cur:
            # Get extension stats for last 30 days
            cur.execute("""
                SELECT * FROM auth.get_token_extension_stats(
                    NULL,  -- all tenants
                    30     -- last 30 days
                )
            """)
            
            result = cur.fetchone()
            
            if result:
                print("📊 Extension Statistics (Last 30 Days):")
                print(f"   🔍 Total Validations: {result['total_validations']}")
                print(f"   🤖 Auto Extensions: {result['auto_extensions']}")
                print(f"   🔧 Manual Extensions: {result['manual_extensions']}")
                print(f"   ❌ Extension Failures: {result['extension_failures']}")
                print(f"   📈 Average Days Extended: {result['average_days_extended']}")
                print(f"   🕐 Most Recent Extension: {result['most_recent_extension']}")
            else:
                print("❌ No statistics available")
                
    except Exception as e:
        print(f"❌ Error getting extension statistics: {e}")

def test_validation_with_auto_extend_disabled(conn):
    """Test validation with auto-extend disabled"""
    print("\n🚫 Testing Validation with Auto-Extend DISABLED...")
    print("=" * 70)
    
    test_token = 'ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e'
    
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT * FROM auth.validate_and_extend_production_token(
                    %s,                    -- token
                    'api:read',           -- required scope
                    '192.168.1.101'::inet, -- client IP
                    'Test-NoExtend/1.0',  -- user agent
                    '/api/v1/noextend',   -- API endpoint
                    false,                -- auto extend DISABLED
                    7,                    -- extend threshold
                    30                    -- extension days
                )
            """, (test_token,))
            
            result = cur.fetchone()
            
            if result:
                print("📋 Validation Result (Auto-Extend OFF):")
                print(f"   ✅ Valid: {result['is_valid']}")
                print(f"   🔑 Token Extended: {result['token_extended']} (should be False)")
                print(f"   📅 Expires At: {result['new_expires_at']}")
                print(f"   📊 Days Until Expiry: {result['days_until_expiry']}")
                print(f"   🔄 Extension Reason: {result['extension_reason']}")
                print(f"   📝 Message: {result['validation_message']}")
                
    except Exception as e:
        print(f"❌ Error testing validation with auto-extend disabled: {e}")

def test_invalid_token_handling(conn):
    """Test handling of invalid tokens"""
    print("\n⚠️  Testing Invalid Token Handling...")
    print("=" * 70)
    
    invalid_tokens = [
        'invalid_token_format',
        'ovt_prod_invalid123',
        ''
    ]
    
    for token in invalid_tokens:
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT * FROM auth.validate_and_extend_production_token(
                        %s, 'api:read'
                    )
                """, (token,))
                
                result = cur.fetchone()
                
                print(f"🧪 Token: '{token[:20]}{'...' if len(token) > 20 else ''}'")
                if result:
                    print(f"   ✅ Valid: {result['is_valid']} (should be False)")
                    print(f"   📝 Message: {result['validation_message']}")
                    print(f"   🔄 Extension Reason: {result['extension_reason']}")
                else:
                    print("   ❌ No result returned")
                print()
                
        except Exception as e:
            print(f"   ❌ Error: {e}")
            print()

def main():
    """Run all tests"""
    print("🧪 Validate and Extend Token System - Comprehensive Test")
    print("=" * 70)
    print(f"📅 Test started at: {datetime.now()}")
    
    try:
        conn = get_db_connection()
        print("✅ Database connection established")
        
        # Run all tests
        test_functions_exist(conn)
        test_validate_and_extend_basic(conn)
        test_manual_extension_api(conn)
        test_extension_stats(conn)
        test_validation_with_auto_extend_disabled(conn)
        test_invalid_token_handling(conn)
        
        conn.close()
        print("\n🎉 All tests completed!")
        print("=" * 70)
        
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        print("🔧 Make sure your database is running and environment variables are set")

if __name__ == "__main__":
    main() 