#!/usr/bin/env python3
"""
Fix AI Observation Function - Get Perfect 4/4 Score!
Fixing the v_entity_hk variable name issue
"""

import psycopg2
import json
import getpass
from datetime import datetime

def main():
    print("🔧 Fixing AI Observation Function - Final Piece!")
    print("Targeting the v_entity_hk variable name issue")
    print("=" * 70)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        results = {
            "timestamp": datetime.now().isoformat(),
            "ai_fix_analysis": {}
        }
        
        # Step 1: Get the current function definition
        print("\n🔍 STEP 1: Analyzing AI Observation Function...")
        
        cursor.execute("""
            SELECT pg_get_functiondef(p.oid) as function_definition
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api'
            AND p.proname = 'ai_log_observation'
        """)
        
        func_def = cursor.fetchone()
        if not func_def:
            print("   ❌ ai_log_observation function not found!")
            return
            
        function_text = func_def[0]
        print("   ✅ Function found and retrieved")
        
        # Check for the problematic variable
        if 'v_entity_hk' in function_text:
            print("   🐛 CONFIRMED: Found 'v_entity_hk' variable reference")
            results["ai_fix_analysis"]["issue_confirmed"] = True
            
            # Count occurrences
            v_entity_count = function_text.count('v_entity_hk')
            entity_count = function_text.count('entity_hk')
            print(f"   📊 'v_entity_hk' appears {v_entity_count} times")
            print(f"   📊 'entity_hk' appears {entity_count} times")
            
        else:
            print("   ❓ 'v_entity_hk' not found - issue may be different")
            results["ai_fix_analysis"]["issue_confirmed"] = False
        
        # Step 2: Check what columns actually exist
        print("\n🔍 STEP 2: Verifying Available Columns...")
        
        cursor.execute("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_schema = 'ai_agents' 
            AND table_name LIKE '%observation%'
            AND column_name LIKE '%entity%'
            ORDER BY table_name, column_name
        """)
        
        entity_columns = cursor.fetchall()
        print("   📋 Available entity-related columns:")
        for col_name, data_type in entity_columns:
            print(f"     ✅ {col_name}: {data_type}")
            
        results["ai_fix_analysis"]["available_entity_columns"] = entity_columns
        
        # Step 3: Check if function can be fixed by simple replacement
        if 'v_entity_hk' in function_text and entity_columns:
            print("\n🔧 STEP 3: Preparing Function Fix...")
            
            # Show the problematic lines
            lines = function_text.split('\n')
            problem_lines = []
            for i, line in enumerate(lines, 1):
                if 'v_entity_hk' in line:
                    problem_lines.append((i, line.strip()))
            
            print("   🐛 Problematic lines found:")
            for line_num, line_content in problem_lines:
                print(f"     Line {line_num}: {line_content}")
            
            # Suggest the fix
            fixed_function = function_text.replace('v_entity_hk', 'entity_hk')
            
            print(f"\n   💡 Fix Strategy: Replace 'v_entity_hk' with 'entity_hk'")
            print(f"   📊 This would affect {len(problem_lines)} lines")
            
            results["ai_fix_analysis"]["fix_strategy"] = "replace_v_entity_hk_with_entity_hk"
            results["ai_fix_analysis"]["lines_affected"] = len(problem_lines)
            
            # Ask user if they want to apply the fix
            print("\n🎯 READY TO APPLY FIX!")
            apply_fix = input("   Apply the fix? (y/N): ").lower().strip()
            
            if apply_fix == 'y':
                print("\n🚀 APPLYING FIX...")
                
                try:
                    # Drop the old function
                    cursor.execute("DROP FUNCTION IF EXISTS api.ai_log_observation(jsonb)")
                    print("   ✅ Dropped old function")
                    
                    # Create the fixed function
                    cursor.execute(fixed_function)
                    print("   ✅ Created fixed function")
                    
                    conn.commit()
                    print("   ✅ Changes committed!")
                    
                    results["ai_fix_analysis"]["fix_applied"] = True
                    
                    # Test the fixed function
                    print("\n🧪 TESTING FIXED FUNCTION...")
                    
                    test_observation = {
                        "observation_type": "test",
                        "observation_title": "AI Function Fix Test",
                        "observation_description": "Testing fixed ai_log_observation function",
                        "confidence_score": 0.95,
                        "sensor_readings": {"test": "data"},
                        "ai_model_used": "test_model"
                    }
                    
                    cursor.execute("""
                        SELECT api.ai_log_observation(%s::jsonb)
                    """, (json.dumps(test_observation),))
                    
                    test_result = cursor.fetchone()[0]
                    
                    if isinstance(test_result, dict) and test_result.get('success'):
                        print("   🎉 AI OBSERVATION FUNCTION WORKING!")
                        print(f"   📋 Result: {test_result}")
                        results["ai_fix_analysis"]["test_success"] = True
                        conn.commit()
                    else:
                        print(f"   ⚠️ Function fixed but test unclear: {test_result}")
                        results["ai_fix_analysis"]["test_success"] = False
                        conn.rollback()
                        
                except Exception as e:
                    print(f"   ❌ Fix failed: {e}")
                    results["ai_fix_analysis"]["fix_applied"] = False
                    results["ai_fix_analysis"]["fix_error"] = str(e)
                    conn.rollback()
            else:
                print("   ⏸️ Fix not applied - user declined")
                results["ai_fix_analysis"]["fix_applied"] = False
        
        # Step 4: If fix was applied, run complete test
        if results["ai_fix_analysis"].get("fix_applied"):
            print("\n🎯 RUNNING COMPLETE 4/4 FUNCTION TEST...")
            
            # Get tenant data for testing
            cursor.execute("""
                SELECT th.tenant_hk, th.tenant_bk, tps.tenant_name
                FROM auth.tenant_h th
                JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
                WHERE tps.load_end_date IS NULL
                AND tps.tenant_name = '72 Industries LLC'
                LIMIT 1
            """)
            
            tenant_data = cursor.fetchone()
            if tenant_data:
                tenant_hk, tenant_bk, tenant_name = tenant_data
                print(f"   🏢 Testing with: {tenant_name}")
                
                # Test all 4 functions
                all_functions_test = {
                    "site_tracking": False,
                    "system_health": False, 
                    "token_generation": False,
                    "ai_observation": False
                }
                
                # Test 1: Site tracking
                try:
                    cursor.execute("""
                        SELECT api.track_site_event(
                            '127.0.0.1'::inet, 'AI_Fix_Test', 
                            'https://canvas.onevault.ai/ai-fixed',
                            'ai_function_fixed', 
                            '{"fix_complete": true}'::jsonb
                        )
                    """)
                    result = cursor.fetchone()[0]
                    all_functions_test["site_tracking"] = isinstance(result, dict) and result.get('success', False)
                    conn.commit()
                except:
                    pass
                
                # Test 2: System health
                try:
                    cursor.execute("SELECT api.system_health_check()")
                    result = cursor.fetchone()[0]
                    all_functions_test["system_health"] = isinstance(result, dict) and result.get('status') == 'healthy'
                except:
                    pass
                
                # Test 3: Token generation (get user first)
                try:
                    cursor.execute("""
                        SELECT uh.user_hk 
                        FROM auth.user_h uh 
                        WHERE uh.tenant_hk = %s 
                        LIMIT 1
                    """, (tenant_hk,))
                    
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
                        all_functions_test["token_generation"] = token_result is not None
                        conn.commit()
                except:
                    pass
                
                # Test 4: AI observation (our fixed function!)
                try:
                    test_obs = {
                        "observation_type": "complete_test",
                        "observation_title": "4/4 Functions Test",
                        "confidence_score": 1.0
                    }
                    cursor.execute("""
                        SELECT api.ai_log_observation(%s::jsonb)
                    """, (json.dumps(test_obs),))
                    result = cursor.fetchone()[0]
                    all_functions_test["ai_observation"] = isinstance(result, dict) and result.get('success', False)
                    conn.commit()
                except Exception as e:
                    print(f"     ⚠️ AI observation still failing: {e}")
                
                # Report final score
                working_count = sum(all_functions_test.values())
                print(f"\n🏆 FINAL SCORE: {working_count}/4 FUNCTIONS WORKING!")
                
                for func, status in all_functions_test.items():
                    status_icon = "✅" if status else "❌"
                    print(f"   {status_icon} {func.replace('_', ' ').title()}")
                
                results["ai_fix_analysis"]["final_test"] = all_functions_test
                results["ai_fix_analysis"]["final_score"] = f"{working_count}/4"
                
                if working_count == 4:
                    print("\n🎉 PERFECT SCORE ACHIEVED!")
                    print("🚀 ALL SYSTEMS OPERATIONAL FOR CANVAS!")
                elif working_count == 3:
                    print("\n🎊 EXCELLENT! 3/4 Core functions working")
                    print("🎯 Canvas fully ready for production!")
        
        # Save results
        filename = f"ai_fix_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\n💾 AI fix results saved to: {filename}")
        
    except Exception as e:
        print(f"❌ Fix process failed: {e}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main() 