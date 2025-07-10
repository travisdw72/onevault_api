#!/usr/bin/env python3
"""
Test Token Extension Function
Verifies that token extension preserves the token value and only changes expiration
"""

import psycopg2
import os
from psycopg2.extras import RealDictCursor
from datetime import datetime

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

def test_extension_function_exists(conn):
    """Test if the extension function exists in the database"""
    print("\n🔍 Testing if extension function exists...")
    print("=" * 60)
    
    with conn.cursor() as cursor:
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                n.nspname as schema_name,
                pg_get_function_result(p.oid) as return_type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid 
            WHERE n.nspname = 'auth' 
            AND p.proname = 'extend_token_expiration'
        """)
        
        functions = cursor.fetchall()
        
        if functions:
            print("✅ Extension function found:")
            for func in functions:
                print(f"   - {func['schema_name']}.{func['function_name']}")
                print(f"     Returns: {func['return_type']}")
            return True
        else:
            print("❌ Extension function NOT found")
            return False

def test_check_function_exists(conn):
    """Test if the check extension needed function exists"""
    print("\n🔍 Testing if check extension function exists...")
    print("=" * 60)
    
    with conn.cursor() as cursor:
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                n.nspname as schema_name
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid 
            WHERE n.nspname = 'auth' 
            AND p.proname = 'check_token_extension_needed'
        """)
        
        functions = cursor.fetchall()
        
        if functions:
            print("✅ Check extension function found:")
            for func in functions:
                print(f"   - {func['schema_name']}.{func['function_name']}")
            return True
        else:
            print("❌ Check extension function NOT found")
            return False

def test_token_status_check(conn, token):
    """Test checking if a token needs extension"""
    print(f"\n🔍 Testing token status check...")
    print("=" * 60)
    
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT * FROM auth.check_token_extension_needed(%s)",
                (token,)
            )
            
            result = cursor.fetchone()
            
            if result:
                print("✅ Token status check successful:")
                print(f"   Token Found: {result['token_found']}")
                print(f"   Current Expires: {result['current_expires_at']}")
                print(f"   Days Until Expiry: {result['days_until_expiry']}")
                print(f"   Extension Recommended: {result['extension_recommended']}")
                print(f"   Reason: {result['reason']}")
                return result
            else:
                print("❌ No result returned from token status check")
                return None
                
    except Exception as e:
        print(f"❌ Token status check failed: {e}")
        return None

def test_token_extension(conn, token, extension_days=30):
    """Test extending a token's expiration"""
    print(f"\n🔄 Testing token extension (extend by {extension_days} days)...")
    print("=" * 60)
    
    # First, get the current token state
    print("📋 Before extension:")
    before_status = test_token_status_check(conn, token)
    
    if not before_status or not before_status['token_found']:
        print("❌ Cannot test extension - token not found")
        return False
    
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT * FROM auth.extend_token_expiration(%s, %s)",
                (token, extension_days)
            )
            
            result = cursor.fetchone()
            
            if result:
                print("\n🎉 Token extension result:")
                print(f"   Success: {result['success']}")
                print(f"   Token Unchanged: {result['token_unchanged']}")
                print(f"   New Expires At: {result['new_expires_at']}")
                print(f"   Extension Reason: {result['extension_reason']}")
                print(f"   Message: {result['message']}")
                
                # Verify token value is unchanged
                if result['token_unchanged'] == token:
                    print("✅ VERIFIED: Token value is UNCHANGED")
                else:
                    print(f"❌ ERROR: Token value changed!")
                    print(f"   Original: {token}")
                    print(f"   Returned: {result['token_unchanged']}")
                
                # Check status after extension
                print("\n📋 After extension:")
                after_status = test_token_status_check(conn, token)
                
                if after_status and before_status:
                    if after_status['current_expires_at'] > before_status['current_expires_at']:
                        print("✅ VERIFIED: Expiration date was extended")
                    else:
                        print("❌ ERROR: Expiration date was not extended")
                
                return result['success']
            else:
                print("❌ No result returned from token extension")
                return False
                
    except Exception as e:
        print(f"❌ Token extension failed: {e}")
        return False

def test_with_production_token(conn):
    """Test with your actual production token"""
    production_token = "ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e"
    
    print(f"\n🧪 Testing with production token...")
    print("=" * 60)
    print(f"Token: {production_token[:20]}...")
    
    # Check current status
    status = test_token_status_check(conn, production_token)
    
    if status and status['token_found']:
        # Try extension if recommended or if we want to test
        if status['extension_recommended']:
            print(f"\n💡 Extension recommended: {status['reason']}")
            test_token_extension(conn, production_token)
        else:
            print(f"\n💡 Extension not currently recommended: {status['reason']}")
            print("   But we can test with force extension...")
            # You could still test extension even if not recommended
            # test_token_extension(conn, production_token)
    else:
        print("❌ Production token not found or invalid")

def main():
    """Main test function"""
    print("🚀 OneVault Token Extension System Test")
    print("=" * 60)
    print(f"Time: {datetime.now()}")
    
    try:
        # Connect to database
        conn = get_db_connection()
        print("✅ Database connection established")
        
        # Test 1: Check if functions exist
        extension_exists = test_extension_function_exists(conn)
        check_exists = test_check_function_exists(conn)
        
        if not (extension_exists and check_exists):
            print("\n❌ Required functions not found. Deploy token_extend_expiration.sql first")
            return
        
        # Test 2: Test with production token
        test_with_production_token(conn)
        
        print(f"\n🎉 Test completed at {datetime.now()}")
        
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()
            print("🔌 Database connection closed")

if __name__ == "__main__":
    main() 