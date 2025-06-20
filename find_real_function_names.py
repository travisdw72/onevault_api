#!/usr/bin/env python3
"""
Find Real Function Names
Check what AI functions actually exist and can be executed in the database
"""

import psycopg2
import getpass
import json

def find_real_functions():
    """Find what AI functions actually exist and work"""
    
    print("🔍 Finding Real AI Functions That Actually Exist")
    print("=" * 70)
    
    # Get password securely
    db_password = getpass.getpass("Enter database password: ")
    
    try:
        # Connect to database
        conn = psycopg2.connect(
            host="localhost",
            port="5432", 
            database="one_vault",
            user="postgres",
            password=db_password
        )
        cursor = conn.cursor()
        
        print("✅ Connected to database successfully")
        print()
        
        # Get ALL functions in ai_agents schema that actually exist
        print("🔍 FINDING ALL AI_AGENTS FUNCTIONS:")
        print("-" * 50)
        
        cursor.execute("""
            SELECT proname, pronargs
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'ai_agents'
            ORDER BY proname;
        """)
        
        functions = cursor.fetchall()
        
        if functions:
            print("   📋 Found functions:")
            for func_name, arg_count in functions:
                print(f"      - {func_name}() - {arg_count} arguments")
            
            print()
            
            # Now test each function to see which ones actually work
            print("🧪 TESTING EACH FUNCTION:")
            print("-" * 50)
            
            working_functions = []
            
            for func_name, arg_count in functions:
                print(f"   Testing: ai_agents.{func_name}()")
                
                try:
                    if arg_count == 0:
                        # No parameters
                        cursor.execute(f"SELECT ai_agents.{func_name}();")
                    else:
                        # Skip functions with parameters for now
                        print("      ⏭️  Skipped (has parameters)")
                        continue
                    
                    result = cursor.fetchone()
                    
                    if result:
                        response = result[0]
                        print("      ✅ SUCCESS!")
                        
                        if isinstance(response, dict):
                            # Pretty print first few keys
                            keys = list(response.keys())[:3]
                            print(f"      📊 Returns: {keys}...")
                            
                            if 'success' in response:
                                if response.get('success'):
                                    print("      🎉 Returns successful response!")
                                else:
                                    print("      ⚠️  Returns error response")
                            
                        working_functions.append((func_name, arg_count, response))
                    else:
                        print("      ❌ No response")
                        
                except Exception as e:
                    error_msg = str(e)[:100]
                    print(f"      ❌ Failed: {error_msg}...")
                
                print()
            
            # Summary of working functions
            print("📊 WORKING FUNCTIONS SUMMARY:")
            print("=" * 70)
            
            if working_functions:
                print("✅ FUNCTIONS THAT ACTUALLY WORK:")
                
                for func_name, arg_count, response in working_functions:
                    print(f"\n🔧 ai_agents.{func_name}():")
                    print(f"   - Arguments: {arg_count}")
                    
                    if isinstance(response, dict):
                        if response.get('success'):
                            print("   - Status: ✅ Working")
                            if 'assessment' in response:
                                print("   - Type: 🏥 Health Assessment Function")
                            elif 'reasoning' in str(response).lower():
                                print("   - Type: 🧠 AI Reasoning Function")
                            else:
                                print("   - Type: 🔧 Utility Function")
                        else:
                            print("   - Status: ⚠️  Returns errors (may need setup)")
                            error = response.get('error', 'Unknown')
                            if 'session' in error.lower():
                                print("   - Issue: 🔒 Needs session setup")
                            elif 'authorization' in error.lower():
                                print("   - Issue: 🔐 Needs authorization setup")
                    else:
                        print(f"   - Returns: {type(response).__name__}")
                
                print()
                print("🎯 RECOMMENDATIONS:")
                
                # Look for the best function to use
                reasoning_functions = [f for f in working_functions if 'reasoning' in f[0] or 'care' in f[0]]
                
                if reasoning_functions:
                    best_func = reasoning_functions[0]
                    print(f"   1. Use ai_agents.{best_func[0]}() as your main AI function")
                    print("   2. Set up proper sessions for full functionality")
                    print("   3. Create wrapper that handles session management")
                    print("   4. Integrate with your image processing pipeline")
                else:
                    print("   1. Functions exist but may need session/auth setup")
                    print("   2. Check authentication and session requirements")
                    print("   3. May need to create proper AI agent sessions first")
                
            else:
                print("❌ NO WORKING FUNCTIONS FOUND")
                print("   - All functions failed to execute")
                print("   - May need authentication/session setup")
                print("   - Check database permissions")
            
        else:
            print("   ❌ No functions found in ai_agents schema")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    find_real_functions() 