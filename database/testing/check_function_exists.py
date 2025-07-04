#!/usr/bin/env python3
"""
Quick check if we still have the ai_log_observation function
"""

import psycopg2
import getpass
import json

def main():
    print("🔍 Checking if ai_log_observation function exists...")
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        
        # Check if function exists
        cursor.execute("""
            SELECT EXISTS(
                SELECT 1 FROM pg_proc p 
                JOIN pg_namespace n ON p.pronamespace = n.oid 
                WHERE n.nspname = 'api' AND p.proname = 'ai_log_observation'
            )
        """)
        
        exists = cursor.fetchone()[0]
        
        if exists:
            print("✅ Function still exists - we are SAFE!")
            
            # Quick test to see if it works
            print("\n🧪 Testing function with minimal parameters...")
            test_data = {
                "tenantId": "72-industries-llc",
                "observationType": "test_check", 
                "severityLevel": "low"
            }
            
            cursor.execute("""
                SELECT api.ai_log_observation(%s::jsonb)
            """, (json.dumps(test_data),))
            
            result = cursor.fetchone()[0]
            print(f"📊 Result: {result}")
            
            if isinstance(result, dict) and result.get('success'):
                print("🎉 Function is working perfectly!")
                print("🏆 AI OBSERVATION: ✅ WORKING!")
            else:
                print("⚠️ Function exists but may have issues")
                print(f"Debug: {result}")
                
        else:
            print("❌ OH NO! Function was dropped and needs restoration!")
            
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 