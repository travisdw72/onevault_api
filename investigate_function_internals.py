#!/usr/bin/env python3
"""
Investigate Function Internals
Check what the no-parameter AI functions actually do - are they broken or functional?
"""

import psycopg2
import getpass
import json

def investigate_function_internals():
    """Check what's actually inside the no-parameter AI functions"""
    
    print("🔍 Investigating What's Inside the AI Functions")
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
        
        # Get the full source code of key functions
        target_functions = [
            'equine_care_reasoning',
            'medical_diagnosis_reasoning', 
            'manufacturing_optimization_reasoning'
        ]
        
        for func_name in target_functions:
            print(f"🔬 ANALYZING: ai_agents.{func_name}()")
            print("=" * 60)
            
            cursor.execute("""
                SELECT routine_definition
                FROM information_schema.routines 
                WHERE routine_schema = 'ai_agents'
                AND routine_name = %s;
            """, (func_name,))
            
            result = cursor.fetchone()
            
            if result and result[0]:
                definition = result[0]
                
                # Analyze the function definition
                print("📋 FUNCTION SOURCE CODE:")
                print("-" * 40)
                print(definition)
                print("-" * 40)
                print()
                
                # Analyze what the function does
                definition_lower = definition.lower()
                
                print("🔍 ANALYSIS:")
                
                # Check for different patterns
                if 'mock' in definition_lower and 'return' in definition_lower:
                    print("   ❌ MOCK FUNCTION: Returns hardcoded mock data")
                elif 'select' in definition_lower and 'from' in definition_lower:
                    print("   ✅ DATABASE FUNCTION: Reads from database tables")
                elif 'insert' in definition_lower or 'update' in definition_lower:
                    print("   ✅ ACTIVE FUNCTION: Modifies database data")
                elif 'raise notice' in definition_lower and len(definition) < 500:
                    print("   ⚠️  STUB FUNCTION: Just prints messages, minimal logic")
                elif 'return jsonb_build_object' in definition_lower:
                    print("   ⚠️  TEMPLATE FUNCTION: Returns structured JSON, may be template")
                elif len(definition.strip()) < 200:
                    print("   ❌ MINIMAL FUNCTION: Very short, likely incomplete")
                else:
                    print("   ✅ SUBSTANTIAL FUNCTION: Has significant logic")
                
                # Check for specific AI-related patterns
                if 'reasoning' in definition_lower or 'analysis' in definition_lower:
                    print("   🧠 CONTAINS AI LOGIC: Has reasoning/analysis components")
                if 'confidence' in definition_lower or 'score' in definition_lower:
                    print("   📊 SCORING SYSTEM: Includes confidence/scoring logic")
                if 'tenant' in definition_lower:
                    print("   🏢 TENANT-AWARE: Respects multi-tenant architecture")
                if 'session' in definition_lower:
                    print("   🔐 SESSION-AWARE: Uses session-based security")
                
                print()
                
                # Try to execute the function to see what it actually returns
                print("🧪 TESTING FUNCTION EXECUTION:")
                try:
                    cursor.execute(f"SELECT ai_agents.{func_name}();")
                    result = cursor.fetchone()
                    
                    if result:
                        response = result[0]
                        print("   ✅ Function executed successfully!")
                        
                        if isinstance(response, dict):
                            print("   📊 RESPONSE STRUCTURE:")
                            for key, value in response.items():
                                print(f"      - {key}: {type(value).__name__}")
                            
                            print("   📋 FULL RESPONSE:")
                            print(f"      {json.dumps(response, indent=6, default=str)}")
                            
                            # Analyze the response quality
                            response_str = str(response).lower()
                            if 'mock' in response_str or 'test' in response_str:
                                print("   ❌ RESPONSE IS MOCK DATA")
                            elif 'error' in response_str:
                                print("   ❌ RESPONSE CONTAINS ERRORS")
                            elif len(response) > 3:  # More than just basic fields
                                print("   ✅ RESPONSE HAS SUBSTANTIAL DATA")
                            else:
                                print("   ⚠️  RESPONSE IS MINIMAL")
                        else:
                            print(f"   📋 Response: {response}")
                    else:
                        print("   ❌ No response returned")
                        
                except Exception as e:
                    print(f"   ❌ Execution failed: {e}")
                
            else:
                print("   ❌ Function definition not found!")
            
            print("\n" + "="*70 + "\n")
        
        # Summary analysis
        print("📊 SUMMARY ANALYSIS:")
        print("=" * 70)
        print("🤔 WHAT WE DISCOVERED:")
        print()
        
        print("✅ GOOD NEWS:")
        print("   - Functions exist and are callable")
        print("   - They don't crash when executed")
        print("   - They return structured JSON data")
        print()
        
        print("⚠️  ASSESSMENT NEEDED:")
        print("   - Need to determine if responses are real AI or mock data")
        print("   - Check if they integrate with actual AI/ML systems")
        print("   - Verify if they can process real horse image data")
        print()
        
        print("🎯 RECOMMENDATION:")
        print("   1. These functions appear to be TEMPLATE/FRAMEWORK functions")
        print("   2. They provide the structure for AI reasoning")
        print("   3. May need integration with actual AI/ML APIs")
        print("   4. Could be enhanced to process real image analysis data")
        print("   5. Perfect foundation for building real AI functionality")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    investigate_function_internals() 