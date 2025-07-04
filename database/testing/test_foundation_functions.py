#!/usr/bin/env python3
"""
Foundation Function Test - OneVault AI System
Tests the actual AI functions to verify basic data flow works
"""

import psycopg2
import json
import getpass
from datetime import datetime

def main():
    print("🔍 Foundation Function Test - OneVault AI System")
    print("Testing actual AI functions from api.AI.functions.sql")
    print("=" * 60)
    
    password = getpass.getpass("Database password for one_vault_site_testing: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        results = {
            "timestamp": datetime.now().isoformat(),
            "tests": {}
        }
        
        # Test 1: Check we have tenants to work with
        print("\n📊 Testing Basic Data Prerequisites...")
        cursor.execute("SELECT COUNT(*) FROM auth.tenant_h")
        tenant_count = cursor.fetchone()[0]
        print(f"   Tenants in system: {tenant_count}")
        results["tests"]["tenant_count"] = tenant_count
        
        if tenant_count == 0:
            print("   ❌ No tenants - cannot test AI functions")
            return
        
        # Get a test tenant
        cursor.execute("""
            SELECT tps.tenant_name 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.load_end_date IS NULL 
            LIMIT 1
        """)
        test_tenant = cursor.fetchone()[0]
        print(f"   Using test tenant: {test_tenant}")
        
        # Test 2: Check if AI functions exist
        print("\n🔍 Checking AI Function Existence...")
        ai_functions = [
            'api.ai_log_observation',
            'api.ai_get_observations', 
            'api.ai_secure_chat',
            'api.ai_monitoring_ingest'
        ]
        
        existing_functions = []
        for func in ai_functions:
            cursor.execute("""
                SELECT EXISTS(
                    SELECT 1 FROM information_schema.routines 
                    WHERE routine_schema = 'api' 
                    AND routine_name = %s
                )
            """, (func.split('.')[-1],))
            
            exists = cursor.fetchone()[0]
            print(f"   {func}: {'✅' if exists else '❌'}")
            if exists:
                existing_functions.append(func)
        
        results["tests"]["existing_functions"] = existing_functions
        
        # Test 3: Try AI Observation Function (your most basic one)
        if 'api.ai_log_observation' in existing_functions:
            print("\n🤖 Testing AI Observation Function...")
            
            test_request = {
                "tenantId": test_tenant,
                "observationType": "foundation_test",
                "severityLevel": "low", 
                "confidenceScore": 0.75,
                "observationData": {
                    "test_type": "foundation_verification",
                    "test_timestamp": datetime.now().isoformat()
                },
                "recommendedActions": ["verify_system"],
                "ip_address": "127.0.0.1",
                "user_agent": "Foundation_Test_Script"
            }
            
            try:
                cursor.execute("SELECT api.ai_log_observation(%s)", (json.dumps(test_request),))
                result = cursor.fetchone()[0]
                
                success = result.get('success', False)
                print(f"   Function executed: {'✅' if success else '❌'}")
                
                if success:
                    obs_id = result.get('data', {}).get('observationId')
                    print(f"   Created observation: {obs_id}")
                    
                    # Verify it was stored
                    cursor.execute("""
                        SELECT COUNT(*) FROM business.ai_observation_h 
                        WHERE ai_observation_bk = %s
                    """, (obs_id,))
                    stored_count = cursor.fetchone()[0]
                    print(f"   Verified in database: {stored_count} records")
                    
                    results["tests"]["ai_observation"] = {
                        "success": True,
                        "observation_id": obs_id,
                        "stored_in_db": stored_count > 0
                    }
                else:
                    error_msg = result.get('message', 'Unknown error')
                    print(f"   Error: {error_msg}")
                    results["tests"]["ai_observation"] = {
                        "success": False,
                        "error": error_msg
                    }
                    
            except Exception as e:
                print(f"   ❌ Function call failed: {e}")
                results["tests"]["ai_observation"] = {"error": str(e)}
        
        # Test 4: Check Raw Layer
        print("\n📥 Testing Raw Layer...")
        cursor.execute("""
            SELECT EXISTS(
                SELECT 1 FROM information_schema.schemata 
                WHERE schema_name = 'raw'
            )
        """)
        raw_exists = cursor.fetchone()[0]
        print(f"   Raw schema exists: {'✅' if raw_exists else '❌'}")
        results["tests"]["raw_schema_exists"] = raw_exists
        
        if raw_exists:
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'raw'
                ORDER BY table_name
                LIMIT 5
            """)
            raw_tables = [row[0] for row in cursor.fetchall()]
            print(f"   Sample raw tables: {raw_tables}")
            results["tests"]["raw_tables_sample"] = raw_tables
        
        # Test 5: Check Staging Layer
        print("\n🔄 Testing Staging Layer...")
        cursor.execute("""
            SELECT EXISTS(
                SELECT 1 FROM information_schema.schemata 
                WHERE schema_name = 'staging'
            )
        """)
        staging_exists = cursor.fetchone()[0]
        print(f"   Staging schema exists: {'✅' if staging_exists else '❌'}")
        results["tests"]["staging_schema_exists"] = staging_exists
        
        # Test 6: Check Business Layer Data
        print("\n🏢 Testing Business Layer...")
        cursor.execute("""
            SELECT 
                (SELECT COUNT(*) FROM business.ai_observation_h) as observations,
                (SELECT COUNT(*) FROM business.ai_alert_h) as alerts
        """)
        obs_count, alert_count = cursor.fetchone()
        print(f"   AI Observations: {obs_count}")
        print(f"   AI Alerts: {alert_count}")
        results["tests"]["business_layer_data"] = {
            "observations": obs_count,
            "alerts": alert_count
        }
        
        conn.commit()
        
        # Summary
        print("\n" + "=" * 60)
        print("🎯 FOUNDATION TEST SUMMARY")
        print("=" * 60)
        
        working_components = 0
        total_components = 6
        
        if results["tests"]["tenant_count"] > 0:
            print("✅ TENANTS: Have test data")
            working_components += 1
        else:
            print("❌ TENANTS: No test data")
        
        if len(results["tests"]["existing_functions"]) >= 2:
            print("✅ FUNCTIONS: AI functions exist")
            working_components += 1
        else:
            print("❌ FUNCTIONS: Missing AI functions")
        
        ai_obs_result = results["tests"].get("ai_observation", {})
        if ai_obs_result.get("success"):
            print("✅ AI OBSERVATION: Function works and stores data")
            working_components += 1
        else:
            print("❌ AI OBSERVATION: Function failed")
        
        if results["tests"]["raw_schema_exists"]:
            print("✅ RAW LAYER: Schema exists")
            working_components += 1
        else:
            print("❌ RAW LAYER: No schema found")
        
        if results["tests"]["staging_schema_exists"]:
            print("✅ STAGING LAYER: Schema exists")
            working_components += 1
        else:
            print("❌ STAGING LAYER: No schema found")
        
        biz_data = results["tests"]["business_layer_data"]
        if biz_data["observations"] > 0 or biz_data["alerts"] > 0:
            print("✅ BUSINESS LAYER: Has AI data")
            working_components += 1
        else:
            print("❌ BUSINESS LAYER: No AI data")
        
        print(f"\n📊 SCORE: {working_components}/{total_components} components working")
        
        if working_components >= 5:
            print("🎉 EXCELLENT - System ready for ETL testing!")
            next_step = "Run ETL pipeline test"
        elif working_components >= 3:
            print("⚠️  GOOD - Core functions work, minor issues to address")
            next_step = "Fix issues then test ETL"
        else:
            print("❌ POOR - Major foundation issues need fixing")
            next_step = "Fix basic functions before ETL"
        
        print(f"📋 NEXT STEP: {next_step}")
        
        # Save results
        filename = f"foundation_test_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\n💾 Results saved to: {filename}")
        
    except Exception as e:
        print(f"❌ Test execution failed: {e}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main() 