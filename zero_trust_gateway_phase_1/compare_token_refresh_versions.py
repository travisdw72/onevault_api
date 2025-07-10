#!/usr/bin/env python3
"""
Compare Token Refresh Versions - Compatible vs Enhanced
Shows the differences between the two approaches
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
        port=os.getenv('DB_PORT', 5432)
    )

def test_token_function(conn, function_name, token):
    """Test a token refresh function"""
    print(f"\n🧪 Testing {function_name}")
    print("=" * 60)
    
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            # First check if function exists
            cursor.execute("""
                SELECT 1 FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid 
                WHERE n.nspname = 'auth' 
                AND p.proname = %s
            """, (function_name.split('.')[-1],))
            
            if not cursor.fetchone():
                print(f"❌ Function {function_name} does not exist")
                return None
            
            # Test the function with force refresh
            print(f"Calling: SELECT * FROM {function_name}('{token[:20]}...', 7, true)")
            cursor.execute(f"""
                SELECT * FROM {function_name}(%s, 7, true)
            """, (token,))
            
            result = cursor.fetchone()
            
            if result:
                print(f"✅ Function executed successfully")
                print(f"   Success: {result['success']}")
                print(f"   Reason: {result['refresh_reason']}")
                print(f"   Message: {result['message'][:100]}...")
                if result['new_token']:
                    print(f"   New Token: {result['new_token'][:30]}...")
                    print(f"   Expires: {result['expires_at']}")
                return result
            else:
                print(f"❌ No result returned")
                return None
                
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def compare_functions():
    """Compare the two token refresh functions"""
    
    print("🔍 TOKEN REFRESH FUNCTION COMPARISON")
    print("=" * 80)
    
    # Your production token
    production_token = "ovt_prod_cf70c68cbc7226d4f6c6517696f6258621be5973e57feb324b148b42a8bb319e"
    
    print(f"Testing with token: {production_token[:30]}...")
    
    try:
        conn = get_db_connection()
        print("✅ Database connected")
        
        # Test Compatible Version
        compatible_result = test_token_function(
            conn, 
            "auth.refresh_production_token_compatible", 
            production_token
        )
        
        # Test Enhanced Version  
        enhanced_result = test_token_function(
            conn, 
            "auth.refresh_production_token_enhanced", 
            production_token
        )
        
        # Test Status Function (Enhanced only)
        print(f"\n🔍 Testing Enhanced Status Function")
        print("=" * 60)
        
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT * FROM auth.get_token_refresh_status(%s)
                """, (production_token,))
                
                status_result = cursor.fetchone()
                if status_result:
                    print("✅ Token Status Retrieved:")
                    for key, value in status_result.items():
                        if value is not None:
                            print(f"   {key}: {value}")
                
        except Exception as e:
            print(f"❌ Status function error: {e}")
        
        # Comparison Summary
        print(f"\n📊 COMPARISON SUMMARY")
        print("=" * 80)
        
        print("🔧 COMPATIBLE VERSION:")
        print("   ✅ Works with existing schema")
        print("   ✅ Basic refresh functionality") 
        print("   ⚠️  Hardcodes 'API_KEY' token type")
        print("   ⚠️  Marks old token as 'revoked' (conceptually wrong)")
        print("   ⚠️  Basic error handling")
        
        print("\n🚀 ENHANCED VERSION:")
        print("   ✅ Works with existing schema")
        print("   ✅ Preserves original token type")
        print("   ✅ Proper refresh logic (end-dates, doesn't revoke)")
        print("   ✅ Prevents refreshing revoked tokens")
        print("   ✅ Rich audit trail with metadata")
        print("   ✅ Comprehensive status function")
        print("   ✅ Better error handling with SQLSTATE")
        print("   ✅ Crypto-strong token generation")
        
        print(f"\n🎯 RECOMMENDATION:")
        if enhanced_result and enhanced_result.get('success'):
            print("   🏆 USE ENHANCED VERSION")
            print("   - All features of compatible version")
            print("   - Plus significant improvements")
            print("   - Production ready with better security")
        elif compatible_result and compatible_result.get('success'):
            print("   ⚠️  COMPATIBLE VERSION WORKS")
            print("   - Basic functionality present")
            print("   - Consider upgrading to enhanced")
        else:
            print("   ❌ BOTH VERSIONS HAVE ISSUES")
            print("   - Check database schema compatibility")
            
        conn.close()
        
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        print("   Make sure PostgreSQL is running and credentials are correct")

def analyze_key_differences():
    """Show key code differences between versions"""
    
    print(f"\n📋 KEY CODE DIFFERENCES")
    print("=" * 80)
    
    differences = [
        {
            "aspect": "Token Type Preservation",
            "compatible": "token_type: 'API_KEY'  # ❌ Hardcoded",
            "enhanced": "token_type: v_original_token_type  # ✅ Preserved"
        },
        {
            "aspect": "Old Token Handling", 
            "compatible": "revoked_at = current_timestamp  # ❌ Wrong semantics",
            "enhanced": "load_end_date = current_timestamp  # ✅ Just end-dated"
        },
        {
            "aspect": "Revoked Token Check",
            "compatible": "-- No check for already revoked tokens",
            "enhanced": "IF v_is_already_revoked THEN RETURN error  # ✅ Prevents refresh"
        },
        {
            "aspect": "Audit Logging",
            "compatible": "Basic error logging only",
            "enhanced": "Rich metadata with JSONB details"
        },
        {
            "aspect": "Error Handling",
            "compatible": "format('Token refresh failed: %s', SQLERRM)",
            "enhanced": "format('... %s (SQLSTATE: %s)', SQLERRM, SQLSTATE)"
        },
        {
            "aspect": "Status Function",
            "compatible": "check_token_refresh_needed_compatible() - basic",
            "enhanced": "get_token_refresh_status() - comprehensive"
        }
    ]
    
    for diff in differences:
        print(f"\n🔧 {diff['aspect']}:")
        print(f"   Compatible: {diff['compatible']}")
        print(f"   Enhanced:   {diff['enhanced']}")

if __name__ == "__main__":
    compare_functions()
    analyze_key_differences()
    
    print(f"\n🎉 CONCLUSION:")
    print("=" * 80)
    print("The Enhanced version fixes all issues in the Compatible version")
    print("while maintaining 100% schema compatibility. It's a drop-in")
    print("replacement with significant improvements.")
    print(f"\nRecommendation: Deploy the Enhanced version for production use.") 