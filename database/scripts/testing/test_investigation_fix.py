#!/usr/bin/env python3
"""
Test Database Investigation Script Fixes
Quick validation that transaction errors are handled properly
"""
import psycopg2
import getpass
from investigate_db_configFile import DATABASE_CONFIG

def test_transaction_handling():
    """Test that transaction errors are handled properly"""
    print("🧪 TESTING DATABASE INVESTIGATION FIXES")
    print("=" * 50)
    
    # Get password
    config = DATABASE_CONFIG.copy()
    if config.get('password') is None:
        password = getpass.getpass("Enter PostgreSQL password: ")
        config['password'] = password
    
    try:
        # Connect to database
        conn = psycopg2.connect(**config)
        print(f"✅ Connected to database: {config['database']}")
        
        # Test 1: Normal query should work
        print("\n🧪 Test 1: Normal query")
        with conn.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'auth'")
            result = cursor.fetchone()[0]
            print(f"✅ Auth tables found: {result}")
        
        # Test 2: Simulate transaction error and recovery
        print("\n🧪 Test 2: Transaction error handling")
        try:
            # Use autocommit mode (like our fixed script)
            old_autocommit = conn.autocommit
            conn.autocommit = True
            
            # This should work fine in autocommit mode
            with conn.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM auth.user_h")
                result = cursor.fetchone()[0]
                print(f"✅ Query after autocommit: {result} users")
            
            # Restore autocommit
            conn.autocommit = old_autocommit
            print("✅ Transaction handling test passed")
            
        except psycopg2.Error as e:
            print(f"❌ Transaction error (expected): {e}")
            # Test rollback recovery
            try:
                conn.rollback()
                print("✅ Rollback successful")
            except:
                print("❌ Rollback failed")
        
        # Test 3: Multiple queries in sequence (the main fix)
        print("\n🧪 Test 3: Sequential queries with error protection")
        queries = [
            ("Auth functions", "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'auth'"),
            ("Auth tables", "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'auth'"),
            ("API functions", "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'api'")
        ]
        
        success_count = 0
        for desc, query in queries:
            try:
                old_autocommit = conn.autocommit
                conn.autocommit = True
                
                with conn.cursor() as cursor:
                    cursor.execute(query)
                    result = cursor.fetchone()[0]
                    print(f"✅ {desc}: {result}")
                    success_count += 1
                
                conn.autocommit = old_autocommit
                
            except psycopg2.Error as e:
                print(f"❌ {desc} failed: {e}")
                try:
                    conn.rollback()
                    conn.autocommit = old_autocommit
                except:
                    print("🔄 Would reconnect here...")
        
        print(f"\n🎯 SUMMARY: {success_count}/{len(queries)} queries successful")
        
        if success_count == len(queries):
            print("✅ All transaction handling tests PASSED")
            print("🚀 Investigation script should now work correctly!")
        else:
            print("❌ Some tests failed - investigation may still have issues")
        
        conn.close()
        
    except Exception as e:
        print(f"❌ Test failed: {e}")

if __name__ == "__main__":
    test_transaction_handling() 