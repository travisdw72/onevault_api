#!/usr/bin/env python3
"""
Test the exact INSERT scenario to find where v_entity_hk error occurs
"""

import psycopg2
import getpass
import json

def main():
    print("🎯 TESTING EXACT INSERT SCENARIO")
    print("=" * 40)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        # Get correct tenant business key
        cursor.execute("""
            SELECT th.tenant_bk
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.tenant_name = '72 Industries LLC' 
            AND tps.load_end_date IS NULL
            LIMIT 1
        """)
        
        tenant_result = cursor.fetchone()
        if not tenant_result:
            print("❌ Could not find tenant")
            return
            
        tenant_bk = tenant_result[0]
        print(f"🏢 Using tenant: {tenant_bk}")
        
        # Test 1: Minimal working case (should reach the INSERT)
        print("\n🧪 Test 1: Minimal case with all required fields...")
        test_data = {
            "tenantId": tenant_bk,
            "observationType": "test_debug",
            "severityLevel": "low",
            "confidenceScore": 0.75
        }
        
        try:
            cursor.execute("""
                SELECT api.ai_log_observation(%s::jsonb)
            """, (json.dumps(test_data),))
            
            result = cursor.fetchone()[0]
            print(f"📊 Result: {result}")
            
            if result.get('success'):
                print("🎉 SUCCESS! Function worked!")
            else:
                print(f"❌ Function failed: {result.get('message')}")
                if 'v_entity_hk' in str(result):
                    print("🐛 Found the v_entity_hk error!")
                    
        except Exception as e:
            print(f"❌ Exception during function call: {e}")
            if 'v_entity_hk' in str(e):
                print("🐛 v_entity_hk error in exception!")
            
        # Test 2: Add optional entity ID (this might trigger the entity lookup)
        print("\n🧪 Test 2: With entity ID (might trigger entity lookup)...")
        test_data_with_entity = {
            "tenantId": tenant_bk,
            "observationType": "test_with_entity",
            "severityLevel": "low",
            "entityId": "nonexistent_entity_123"  # This should be NULL in lookup
        }
        
        try:
            cursor.execute("""
                SELECT api.ai_log_observation(%s::jsonb)
            """, (json.dumps(test_data_with_entity),))
            
            result = cursor.fetchone()[0]
            print(f"📊 Result: {result}")
            
        except Exception as e:
            print(f"❌ Exception: {e}")
            
        # Test 3: Try to create the table structure manually
        print("\n🔍 Test 3: Checking table structure again...")
        cursor.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_schema = 'business' 
            AND table_name = 'ai_observation_details_s'
            AND column_name LIKE '%entity%'
            ORDER BY ordinal_position
        """)
        
        entity_columns = cursor.fetchall()
        print("Entity-related columns:")
        for col in entity_columns:
            print(f"   - {col[0]}")
            
        # Test 4: Check if there's some kind of SQL injection or prepared statement issue
        print("\n🧪 Test 4: Testing direct INSERT to isolate the issue...")
        try:
            # Try the exact INSERT from the function
            cursor.execute("""
                DO $$
                DECLARE
                    v_observation_hk BYTEA := '\\x1234567890123456';
                    v_entity_hk BYTEA := NULL;
                    v_sensor_hk BYTEA := NULL;
                BEGIN
                    INSERT INTO business.ai_observation_details_s (
                        ai_observation_hk, load_date, load_end_date, hash_diff,
                        entity_hk, sensor_hk, observation_type, observation_category,
                        severity_level, confidence_score, observation_title, observation_description,
                        observation_data, visual_evidence, observation_timestamp,
                        recommended_actions, status, record_source
                    ) VALUES (
                        v_observation_hk, CURRENT_TIMESTAMP, NULL,
                        '\\x9876543210987654',
                        v_entity_hk, v_sensor_hk, 'test_direct',
                        'general',
                        'low', 0.75,
                        'Direct Test', 'Testing direct insert',
                        '{}'::jsonb, NULL, CURRENT_TIMESTAMP,
                        ARRAY[]::TEXT[], 'detected', 'test'
                    );
                    ROLLBACK;  -- Don't actually save
                END $$;
            """)
            print("✅ Direct INSERT works!")
            
        except Exception as e:
            print(f"❌ Direct INSERT failed: {e}")
            if 'v_entity_hk' in str(e):
                print("🐛 v_entity_hk error in direct INSERT!")
                
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 