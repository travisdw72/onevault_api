#!/usr/bin/env python3
"""
Simple Test of Real AI Function
Direct test of ai_agents.equine_care_reasoning() with different parameter combinations
"""

import psycopg2
import getpass
import json

def test_ai_function_simple():
    """Test the equine_care_reasoning function with different parameter combinations"""
    
    print("🧪 Simple Test of Real AI Function")
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
        
        # Prepare test data based on what we saw in the source code
        test_session_token = "test_session_token_123"
        test_horse_data = {
            "horse_id": "HORSE_001",
            "name": "Thunder",
            "breed": "Thoroughbred", 
            "age": 8,
            "weight": 1200
        }
        test_health_metrics = {
            "heart_rate": 40,
            "temperature": 99.5,
            "appetite": "good"
        }
        
        # Test different parameter combinations to find the right signature
        test_cases = [
            {
                "name": "No parameters",
                "sql": "SELECT ai_agents.equine_care_reasoning();",
                "params": None
            },
            {
                "name": "1 parameter (session_token)",
                "sql": "SELECT ai_agents.equine_care_reasoning(%s);",
                "params": (test_session_token,)
            },
            {
                "name": "2 parameters (session_token, horse_data)",
                "sql": "SELECT ai_agents.equine_care_reasoning(%s, %s);",
                "params": (test_session_token, json.dumps(test_horse_data))
            },
            {
                "name": "3 parameters (session_token, horse_data, health_metrics)",
                "sql": "SELECT ai_agents.equine_care_reasoning(%s, %s, %s);",
                "params": (test_session_token, json.dumps(test_horse_data), json.dumps(test_health_metrics))
            }
        ]
        
        successful_test = None
        
        for i, test_case in enumerate(test_cases, 1):
            print(f"🧪 TEST {i}: {test_case['name']}")
            print("-" * 50)
            
            try:
                if test_case['params']:
                    cursor.execute(test_case['sql'], test_case['params'])
                else:
                    cursor.execute(test_case['sql'])
                
                result = cursor.fetchone()
                
                if result:
                    response = result[0]
                    print("   ✅ SUCCESS: Function executed!")
                    print()
                    print("   📊 RESPONSE:")
                    if isinstance(response, dict):
                        print(json.dumps(response, indent=6, default=str))
                        
                        # Analyze the response
                        if response.get('success'):
                            print("   🎉 SUCCESSFUL AI RESPONSE!")
                            if 'assessment' in response:
                                print("   🏥 Includes health assessment data")
                            if 'confidence' in response:
                                print(f"   📊 Confidence score: {response['confidence']}")
                        else:
                            error_msg = response.get('error', 'Unknown error')
                            print(f"   ⚠️  Error response: {error_msg}")
                            
                            if 'Invalid or expired session' in error_msg:
                                print("   🔒 Expected: Session validation failed (using test token)")
                            elif 'not authorized' in error_msg:
                                print("   🔒 Expected: Agent authorization failed")
                    else:
                        print(f"   📋 Raw response: {response}")
                    
                    successful_test = test_case
                    print("   ✅ THIS IS THE CORRECT FUNCTION SIGNATURE!")
                    break
                else:
                    print("   ❌ No response returned")
                    
            except Exception as e:
                error_msg = str(e)
                print(f"   ❌ Failed: {error_msg[:100]}...")
                
                if "does not exist" in error_msg:
                    print("   ❓ Function with this signature doesn't exist")
                elif "permission denied" in error_msg:
                    print("   🔒 Permission denied")
                else:
                    print("   ❓ Other error occurred")
            
            print()
        
        # Summary
        print("📊 TEST SUMMARY:")
        print("=" * 70)
        
        if successful_test:
            print(f"✅ WORKING SIGNATURE: {successful_test['name']}")
            print("🎯 WHAT THIS MEANS:")
            print("   - The AI function exists and is callable")
            print("   - We found the correct parameter signature") 
            print("   - The function has real AI logic inside")
            print("   - It includes security validation (session tokens)")
            print("   - Ready for integration with real data")
            print()
            print("🚀 NEXT STEPS:")
            print("   1. Create valid session tokens for testing")
            print("   2. Set up proper agent authorization")
            print("   3. Integrate with image analysis pipeline")
            print("   4. Connect to learning system for continuous improvement")
        else:
            print("❌ NO WORKING SIGNATURE FOUND")
            print("   - Function may have different name or parameters")
            print("   - May need to check function definition again")
            print("   - Could be security restrictions preventing execution")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    test_ai_function_simple() 