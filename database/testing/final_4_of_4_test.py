#!/usr/bin/env python3
"""
Final 4/4 Functions Test - Confirming Perfect Score!
"""

import psycopg2
import getpass
import json

def main():
    print("🏆 FINAL 4/4 FUNCTIONS TEST")
    print("=" * 40)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        # Get the correct tenant business key
        cursor.execute("""
            SELECT th.tenant_bk, uh.user_hk
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            LEFT JOIN auth.user_h uh ON th.tenant_hk = uh.tenant_hk
            WHERE tps.tenant_name = '72 Industries LLC' 
            AND tps.load_end_date IS NULL
            LIMIT 1
        """)
        
        tenant_result = cursor.fetchone()
        if not tenant_result:
            print("❌ Could not find 72 Industries LLC tenant")
            return
            
        tenant_bk, user_hk = tenant_result
        print(f"🏢 Using tenant: {tenant_bk}")
        
        tests = {}
        
        # Test 1: Site Tracking ✅
        print("\n1️⃣ Testing Site Tracking...")
        try:
            cursor.execute("""
                SELECT api.track_site_event(
                    '127.0.0.1'::inet, 'Final_4_of_4_Test', 
                    'https://canvas.onevault.ai/perfect-score',
                    'all_functions_working', 
                    '{"score": "4/4"}'::jsonb
                )
            """)
            result = cursor.fetchone()[0]
            tests['site_tracking'] = isinstance(result, dict) and result.get('success', False)
            conn.commit()
            print(f"   Result: {'✅ PASS' if tests['site_tracking'] else '❌ FAIL'}")
        except Exception as e:
            tests['site_tracking'] = False
            print(f"   ❌ FAIL: {e}")
        
        # Test 2: System Health ✅
        print("\n2️⃣ Testing System Health...")
        try:
            cursor.execute("SELECT api.system_health_check()")
            result = cursor.fetchone()[0]
            tests['system_health'] = isinstance(result, dict) and result.get('status') == 'healthy'
            print(f"   Result: {'✅ PASS' if tests['system_health'] else '❌ FAIL'}")
        except Exception as e:
            tests['system_health'] = False
            print(f"   ❌ FAIL: {e}")
        
        # Test 3: Token Generation ✅
        print("\n3️⃣ Testing Token Generation...")
        try:
            if user_hk:
                cursor.execute("""
                    SELECT token_value FROM auth.generate_api_token(
                        %s::bytea, 'API_KEY'::varchar, 
                        ARRAY['read','write']::text[], '1 day'::interval
                    )
                """, (user_hk,))
                token_result = cursor.fetchone()
                tests['token_generation'] = token_result is not None
                conn.commit()
                print(f"   Result: {'✅ PASS' if tests['token_generation'] else '❌ FAIL'}")
            else:
                tests['token_generation'] = False
                print("   ❌ FAIL: No user found")
        except Exception as e:
            tests['token_generation'] = False
            print(f"   ❌ FAIL: {e}")
        
        # Test 4: AI Observation ✅ (The function we saved!)
        print("\n4️⃣ Testing AI Observation...")
        try:
            test_data = {
                "tenantId": tenant_bk,  # Using the correct tenant business key!
                "observationType": "final_test",
                "severityLevel": "low",
                "confidenceScore": 0.95
            }
            
            cursor.execute("""
                SELECT api.ai_log_observation(%s::jsonb)
            """, (json.dumps(test_data),))
            
            result = cursor.fetchone()[0]
            tests['ai_observation'] = isinstance(result, dict) and result.get('success', False)
            conn.commit()
            print(f"   Result: {'✅ PASS' if tests['ai_observation'] else '❌ FAIL'}")
            if not tests['ai_observation']:
                print(f"   Debug: {result}")
        except Exception as e:
            tests['ai_observation'] = False
            print(f"   ❌ FAIL: {e}")
        
        # Final Score
        working_count = sum(tests.values())
        print(f"\n🏆 FINAL SCORE: {working_count}/4 FUNCTIONS!")
        print("=" * 40)
        
        for test_name, status in tests.items():
            icon = "✅" if status else "❌"
            print(f"   {icon} {test_name.replace('_', ' ').title()}")
        
        if working_count == 4:
            print("\n🎉 PERFECT SCORE! ALL SYSTEMS OPERATIONAL!")
            print("🚀 CANVAS READY FOR FULL PRODUCTION!")
        elif working_count >= 3:
            print(f"\n🎊 EXCELLENT! {working_count}/4 working")
            print("🎯 Canvas production ready!")
        else:
            print(f"\n⚠️ {working_count}/4 working - needs attention")
            
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 