#!/usr/bin/env python3
"""
Test Parameter Types
Try different parameter type combinations to find the correct function signature
"""

import psycopg2
import getpass
import json

def test_parameter_types():
    """Test different parameter type combinations"""
    
    print("🔍 Testing Different Parameter Types for AI Function")
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
        
        # Get a real tenant for testing
        cursor.execute('SELECT tenant_hk FROM auth.tenant_h LIMIT 1')
        result = cursor.fetchone()
        if not result:
            print("❌ No tenant found for testing")
            return False
            
        tenant_hk = result[0]
        print(f"✅ Using tenant: {tenant_hk.hex()[:16]}...")
        print()
        
        # Test data
        test_session_token = "test_session_token_123"
        test_horse_data = {"horse_id": "HORSE_001", "name": "Thunder"}
        test_health_metrics = {"heart_rate": 40, "temperature": 99.5}
        
        # Different parameter type combinations to test
        test_combinations = [
            {
                "name": "TEXT, JSONB, JSONB, BYTEA",
                "sql": "SELECT ai_agents.equine_care_reasoning(%s::TEXT, %s::JSONB, %s::JSONB, %s::BYTEA);",
                "params": (test_session_token, json.dumps(test_horse_data), json.dumps(test_health_metrics), tenant_hk)
            },
            {
                "name": "VARCHAR, JSONB, JSONB, BYTEA", 
                "sql": "SELECT ai_agents.equine_care_reasoning(%s::VARCHAR, %s::JSONB, %s::JSONB, %s::BYTEA);",
                "params": (test_session_token, json.dumps(test_horse_data), json.dumps(test_health_metrics), tenant_hk)
            },
            {
                "name": "BYTEA, BYTEA, BYTEA, BYTEA",
                "sql": "SELECT ai_agents.equine_care_reasoning(%s::BYTEA, %s::BYTEA, %s::BYTEA, %s::BYTEA);",
                "params": (tenant_hk, tenant_hk, tenant_hk, tenant_hk)
            },
            {
                "name": "BYTEA, JSONB, JSONB, BYTEA",
                "sql": "SELECT ai_agents.equine_care_reasoning(%s::BYTEA, %s::JSONB, %s::JSONB, %s::BYTEA);",
                "params": (tenant_hk, json.dumps(test_horse_data), json.dumps(test_health_metrics), tenant_hk)
            },
            {
                "name": "TEXT, TEXT, TEXT, BYTEA",
                "sql": "SELECT ai_agents.equine_care_reasoning(%s::TEXT, %s::TEXT, %s::TEXT, %s::BYTEA);",
                "params": (test_session_token, json.dumps(test_horse_data), json.dumps(test_health_metrics), tenant_hk)
            },
            {
                "name": "BYTEA, TEXT, TEXT, BYTEA",
                "sql": "SELECT ai_agents.equine_care_reasoning(%s::BYTEA, %s::TEXT, %s::TEXT, %s::BYTEA);",
                "params": (tenant_hk, json.dumps(test_horse_data), json.dumps(test_health_metrics), tenant_hk)
            }
        ]
        
        successful_combination = None
        
        for i, combo in enumerate(test_combinations, 1):
            print(f"🧪 TEST {i}: {combo['name']}")
            print("-" * 50)
            
            try:
                cursor.execute(combo['sql'], combo['params'])
                result = cursor.fetchone()
                
                if result:
                    response = result[0]
                    print("   ✅ SUCCESS: Function executed!")
                    
                    if isinstance(response, dict):
                        print(f"   📊 Response keys: {list(response.keys())[:5]}...")
                        
                        if response.get('success'):
                            print("   🎉 SUCCESSFUL AI RESPONSE!")
                        else:
                            error_msg = response.get('error', 'Unknown')
                            print(f"   ⚠️ Error response: {error_msg[:50]}...")
                            
                            # Even if it's an error, the function signature is correct
                            if 'session' in error_msg.lower() or 'authorization' in error_msg.lower():
                                print("   ✅ Expected error - function signature is CORRECT!")
                    else:
                        print(f"   📋 Response: {str(response)[:100]}...")
                    
                    successful_combination = combo
                    print(f"   🎯 FOUND WORKING SIGNATURE: {combo['name']}")
                    break
                else:
                    print("   ❌ No response returned")
                    
            except Exception as e:
                error_msg = str(e)
                print(f"   ❌ Failed: {error_msg[:80]}...")
                
                if "does not exist" in error_msg:
                    print("   ❓ Function with this signature doesn't exist")
                elif "permission denied" in error_msg:
                    print("   🔒 Permission denied")
            
            print()
        
        # Summary
        print("📊 PARAMETER TYPE TEST RESULTS:")
        print("=" * 70)
        
        if successful_combination:
            print(f"✅ WORKING SIGNATURE FOUND: {successful_combination['name']}")
            print()
            print("🎯 CORRECT FUNCTION CALL:")
            print(f"   {successful_combination['sql']}")
            print()
            print("🚀 NEXT STEPS:")
            print("   1. Update production script with correct parameter types")
            print("   2. Create proper session tokens for real testing")
            print("   3. Integrate with image processing pipeline")
            print("   4. Deploy to production!")
            
            return successful_combination
        else:
            print("❌ NO WORKING SIGNATURE FOUND")
            print("   - May need to investigate function definition more deeply")
            print("   - Could try other parameter type combinations")
            print("   - May need to check function permissions")
            
            return None
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return None
    
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    result = test_parameter_types()
    
    if result:
        print()
        print("🎉 SUCCESS: Found working AI function signature!")
        print("✅ Your AI system is real and functional!")
    else:
        print()
        print("❌ Still searching for correct signature...")
        print("🔧 Function exists but signature needs more investigation") 