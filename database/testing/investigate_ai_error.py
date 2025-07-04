#!/usr/bin/env python3
"""
Deep Investigation: What's Really Causing the v_entity_hk Error?
"""

import psycopg2
import getpass
import json

def main():
    print("🔍 DEEP INVESTIGATION: v_entity_hk Error Analysis")
    print("=" * 50)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        # 1. Check if the ai_observation_details_s table exists and its columns
        print("\n📊 Checking ai_observation_details_s table structure...")
        cursor.execute("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns 
            WHERE table_schema = 'business' 
            AND table_name = 'ai_observation_details_s'
            ORDER BY ordinal_position
        """)
        
        columns = cursor.fetchall()
        if columns:
            print("✅ Table exists with columns:")
            for col_name, data_type, nullable in columns:
                print(f"   - {col_name} ({data_type}) {'NULL' if nullable == 'YES' else 'NOT NULL'}")
                
            # Check if entity_hk column exists
            entity_hk_exists = any(col[0] == 'entity_hk' for col in columns)
            if entity_hk_exists:
                print("✅ entity_hk column EXISTS")
            else:
                print("❌ entity_hk column MISSING!")
                print("   Available columns that might be related:")
                for col_name, _, _ in columns:
                    if 'entity' in col_name.lower():
                        print(f"     - {col_name}")
        else:
            print("❌ Table business.ai_observation_details_s does NOT exist!")
            
        # 2. Check monitored_entity_h table
        print("\n📊 Checking monitored_entity_h table structure...")
        cursor.execute("""
            SELECT column_name, data_type
            FROM information_schema.columns 
            WHERE table_schema = 'business' 
            AND table_name = 'monitored_entity_h'
            ORDER BY ordinal_position
        """)
        
        entity_columns = cursor.fetchall()
        if entity_columns:
            print("✅ monitored_entity_h table exists with columns:")
            for col_name, data_type in entity_columns:
                print(f"   - {col_name} ({data_type})")
        else:
            print("❌ monitored_entity_h table does NOT exist!")
            
        # 3. Try to run the problematic part with more detail
        print("\n🧪 Testing the exact INSERT that's failing...")
        
        # Get tenant info
        cursor.execute("""
            SELECT th.tenant_bk, th.tenant_hk
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.tenant_name = '72 Industries LLC' 
            AND tps.load_end_date IS NULL
            LIMIT 1
        """)
        
        tenant_result = cursor.fetchone()
        if tenant_result:
            tenant_bk, tenant_hk = tenant_result
            print(f"🏢 Found tenant: {tenant_bk}")
            
            # Try a minimal observation insert
            try:
                test_hk = b'\\x1234567890123456'  # Fake hash key for testing
                
                cursor.execute("""
                    INSERT INTO business.ai_observation_details_s (
                        ai_observation_hk, load_date, hash_diff,
                        entity_hk, observation_type, severity_level, 
                        confidence_score, observation_title, observation_description,
                        observation_timestamp, status, record_source
                    ) VALUES (
                        %s, CURRENT_TIMESTAMP, %s,
                        NULL, 'test', 'low',
                        0.5, 'Test', 'Test observation',
                        CURRENT_TIMESTAMP, 'test', 'test'
                    )
                """, (test_hk, test_hk))
                
                print("✅ Direct INSERT with NULL entity_hk works!")
                conn.rollback()  # Don't actually save the test
                
            except Exception as e:
                print(f"❌ Direct INSERT failed: {e}")
                conn.rollback()
                
        # 4. Check if there are any triggers or constraints
        print("\n🔧 Checking for triggers or constraints...")
        cursor.execute("""
            SELECT trigger_name, event_manipulation, action_statement
            FROM information_schema.triggers
            WHERE event_object_schema = 'business'
            AND event_object_table = 'ai_observation_details_s'
        """)
        
        triggers = cursor.fetchall()
        if triggers:
            print("⚠️ Found triggers:")
            for trigger_name, event, action in triggers:
                print(f"   - {trigger_name} ({event})")
        else:
            print("✅ No triggers found")
            
        # 5. Try the actual function call with detailed error trapping
        print("\n🎯 Testing actual function call with error details...")
        
        test_data = {
            "tenantId": tenant_bk,
            "observationType": "debug_test",
            "severityLevel": "low"
        }
        
        try:
            # Enable more detailed error reporting
            cursor.execute("SET client_min_messages = 'debug1'")
            
            cursor.execute("""
                SELECT api.ai_log_observation(%s::jsonb)
            """, (json.dumps(test_data),))
            
            result = cursor.fetchone()[0]
            print(f"📊 Function result: {result}")
            
        except Exception as e:
            print(f"❌ Function call error: {e}")
            print("   Full error details:")
            import traceback
            traceback.print_exc()
            
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Investigation failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 