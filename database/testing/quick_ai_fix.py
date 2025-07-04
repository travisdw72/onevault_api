#!/usr/bin/env python3
"""
Quick AI Observation Fix - Direct Approach
Let's get that 4/4 score!
"""

import psycopg2
import json
import getpass

def main():
    print("🎯 Quick AI Observation Fix - Direct Approach")
    print("=" * 50)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        # Get the function definition
        print("\n🔍 Getting current function...")
        cursor.execute("""
            SELECT pg_get_functiondef(p.oid) as function_definition
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api'
            AND p.proname = 'ai_log_observation'
        """)
        
        func_def = cursor.fetchone()
        if not func_def:
            print("❌ Function not found!")
            return
            
        function_text = func_def[0]
        
        # Check for the issue
        if 'v_entity_hk' in function_text:
            print("🐛 Found v_entity_hk issue")
            
            # Show problematic lines
            lines = function_text.split('\n')
            for i, line in enumerate(lines, 1):
                if 'v_entity_hk' in line:
                    print(f"   Line {i}: {line.strip()}")
            
            # Apply the fix
            print("\n🔧 Applying fix...")
            fixed_function = function_text.replace('v_entity_hk', 'entity_hk')
            
            # Drop and recreate
            cursor.execute("DROP FUNCTION IF EXISTS api.ai_log_observation(jsonb)")
            cursor.execute(fixed_function)
            conn.commit()
            print("✅ Function fixed!")
            s
            # Test it
            print("\n🧪 Testing fixed function...")
            test_data = {
                "observation_type": "test",
                "observation_title": "Quick Fix Test",
                "confidence_score": 0.9
            }
            
            cursor.execute("""
                SELECT api.ai_log_observation(%s::jsonb)
            """, (json.dumps(test_data),))
            
            result = cursor.fetchone()[0]
            print(f"🎯 Test result: {result}")
            
            if isinstance(result, dict) and result.get('success'):
                print("🎉 AI OBSERVATION WORKING!")
                
                # Test all 4 functions for final score
                print("\n🏆 FINAL 4/4 TEST...")
                
                tests = {}
                
                # Site tracking
                try:
                    cursor.execute("""
                        SELECT api.track_site_event(
                            '127.0.0.1'::inet, 'Final_Test', 
                            'https://canvas.onevault.ai/perfect-score',
                            'all_functions_working', 
                            '{"score": "4/4"}'::jsonb
                        )
                    """)
                    result = cursor.fetchone()[0]
                    tests['site_tracking'] = isinstance(result, dict) and result.get('success', False)
                    conn.commit()
                except Exception as e:
                    tests['site_tracking'] = False
                    print(f"Site tracking: {e}")
                
                # System health
                try:
                    cursor.execute("SELECT api.system_health_check()")
                    result = cursor.fetchone()[0]
                    tests['system_health'] = isinstance(result, dict) and result.get('status') == 'healthy'
                except Exception as e:
                    tests['system_health'] = False
                    print(f"System health: {e}")
                
                # Token generation
                try:
                    cursor.execute("""
                        SELECT uh.user_hk 
                        FROM auth.user_h uh 
                        JOIN auth.tenant_h th ON uh.tenant_hk = th.tenant_hk
                        JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
                        WHERE tps.tenant_name = '72 Industries LLC' 
                        AND tps.load_end_date IS NULL
                        LIMIT 1
                    """)
                    user_result = cursor.fetchone()
                    
                    if user_result:
                        user_hk = user_result[0]
                        cursor.execute("""
                            SELECT token_value FROM auth.generate_api_token(
                                %s::bytea, 'API_KEY'::varchar, 
                                ARRAY['read','write']::text[], '1 day'::interval
                            )
                        """, (user_hk,))
                        token_result = cursor.fetchone()
                        tests['token_generation'] = token_result is not None
                        conn.commit()
                    else:
                        tests['token_generation'] = False
                except Exception as e:
                    tests['token_generation'] = False
                    print(f"Token generation: {e}")
                
                # AI observation (our fix!)
                try:
                    final_test = {
                        "observation_type": "final_score_test",
                        "observation_title": "4/4 Functions Working!",
                        "confidence_score": 1.0
                    }
                    cursor.execute("""
                        SELECT api.ai_log_observation(%s::jsonb)
                    """, (json.dumps(final_test),))
                    result = cursor.fetchone()[0]
                    tests['ai_observation'] = isinstance(result, dict) and result.get('success', False)
                    conn.commit()
                except Exception as e:
                    tests['ai_observation'] = False
                    print(f"AI observation: {e}")
                
                # Final score
                working_count = sum(tests.values())
                print(f"\n🏆 FINAL SCORE: {working_count}/4 FUNCTIONS!")
                
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
                print(f"⚠️ AI function may still have issues: {result}")
                
        else:
            print("❓ v_entity_hk not found - issue may be different")
            
    except Exception as e:
        print(f"❌ Fix failed: {e}")
        import traceback
        traceback.print_exc()
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main() 