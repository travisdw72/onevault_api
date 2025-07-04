#!/usr/bin/env python3
"""
Comprehensive AI Test - OneVault AI System
Tests all AI schemas and functions with proper tenant handling
"""

import psycopg2
import json
import getpass
from datetime import datetime

def main():
    print("🔍 Comprehensive AI Test - OneVault AI System")
    print("Testing ai_agents, ai_monitoring, and business AI infrastructure")
    print("=" * 70)
    
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
            "schemas": {},
            "functions": {},
            "data_counts": {},
            "test_results": {}
        }
        
        # Test 1: Check ALL AI schemas
        print("\n🔍 Checking AI Schema Infrastructure...")
        ai_schemas = ['ai_agents', 'ai_monitoring', 'business', 'raw', 'staging']
        
        for schema in ai_schemas:
            cursor.execute("""
                SELECT EXISTS(
                    SELECT 1 FROM information_schema.schemata 
                    WHERE schema_name = %s
                )
            """, (schema,))
            exists = cursor.fetchone()[0]
            print(f"   {schema} schema: {'✅' if exists else '❌'}")
            results["schemas"][schema] = exists
            
            if exists:
                # Count tables in each schema
                cursor.execute("""
                    SELECT COUNT(*) FROM information_schema.tables 
                    WHERE table_schema = %s
                """, (schema,))
                table_count = cursor.fetchone()[0]
                print(f"     → {table_count} tables")
                results["schemas"][f"{schema}_table_count"] = table_count
        
        # Test 2: Check AI-specific tables in business schema
        print("\n🤖 Checking AI Tables in Business Schema...")
        ai_business_tables = [
            'ai_observation_h', 'ai_observation_details_s',
            'ai_alert_h', 'ai_alert_details_s',
            'ai_interaction_h', 'ai_interaction_details_s',
            'ai_session_h', 'ai_session_state_s'
        ]
        
        business_ai_tables = []
        for table in ai_business_tables:
            cursor.execute("""
                SELECT EXISTS(
                    SELECT 1 FROM information_schema.tables 
                    WHERE table_schema = 'business' AND table_name = %s
                )
            """, (table,))
            exists = cursor.fetchone()[0]
            if exists:
                business_ai_tables.append(table)
                # Count records
                cursor.execute(f"SELECT COUNT(*) FROM business.{table}")
                count = cursor.fetchone()[0]
                print(f"   {table}: {count} records")
                results["data_counts"][table] = count
        
        print(f"   Found {len(business_ai_tables)} AI tables in business schema")
        results["schemas"]["business_ai_tables"] = business_ai_tables
        
        # Test 3: Check ai_monitoring schema tables
        if results["schemas"]["ai_monitoring"]:
            print("\n📊 Checking AI Monitoring Schema...")
            cursor.execute("""
                SELECT table_name FROM information_schema.tables 
                WHERE table_schema = 'ai_monitoring'
                ORDER BY table_name
            """)
            monitoring_tables = [row[0] for row in cursor.fetchall()]
            print(f"   Found {len(monitoring_tables)} monitoring tables")
            for table in monitoring_tables[:5]:  # Show first 5
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM ai_monitoring.{table}")
                    count = cursor.fetchone()[0]
                    print(f"     {table}: {count} records")
                    results["data_counts"][f"ai_monitoring_{table}"] = count
                except:
                    pass
            results["schemas"]["ai_monitoring_tables"] = monitoring_tables
        
        # Test 4: Check ai_agents schema tables  
        if results["schemas"]["ai_agents"]:
            print("\n🤖 Checking AI Agents Schema...")
            cursor.execute("""
                SELECT table_name FROM information_schema.tables 
                WHERE table_schema = 'ai_agents'
                ORDER BY table_name
            """)
            agent_tables = [row[0] for row in cursor.fetchall()]
            print(f"   Found {len(agent_tables)} agent tables")
            for table in agent_tables[:5]:  # Show first 5
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM ai_agents.{table}")
                    count = cursor.fetchone()[0]
                    print(f"     {table}: {count} records")
                    results["data_counts"][f"ai_agents_{table}"] = count
                except:
                    pass
            results["schemas"]["ai_agents_tables"] = agent_tables
        
        # Test 5: Get correct tenant format for testing
        print("\n🏢 Getting Correct Tenant Data...")
        cursor.execute("""
            SELECT th.tenant_bk, tps.tenant_name 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.load_end_date IS NULL
            LIMIT 1
        """)
        tenant_data = cursor.fetchone()
        if tenant_data:
            test_tenant_bk, test_tenant_name = tenant_data
            print(f"   Tenant BK: {test_tenant_bk}")
            print(f"   Tenant Name: {test_tenant_name}")
            results["test_results"]["test_tenant_bk"] = test_tenant_bk
            results["test_results"]["test_tenant_name"] = test_tenant_name
        
        # Test 6: Test AI observation with correct tenant format
        if test_tenant_bk:
            print("\n🔬 Testing AI Observation (Fixed)...")
            test_request = {
                "tenantId": test_tenant_bk,  # Use tenant_bk instead of tenant_name
                "observationType": "comprehensive_test",
                "severityLevel": "low", 
                "confidenceScore": 0.80,
                "observationData": {
                    "test_type": "comprehensive_verification",
                    "test_timestamp": datetime.now().isoformat(),
                    "schemas_found": len([s for s in results["schemas"].values() if s is True])
                },
                "recommendedActions": ["verify_ai_infrastructure"],
                "ip_address": "127.0.0.1",
                "user_agent": "Comprehensive_Test_Script"
            }
            
            try:
                cursor.execute("SELECT api.ai_log_observation(%s)", (json.dumps(test_request),))
                result = cursor.fetchone()[0]
                
                success = result.get('success', False)
                print(f"   Function executed: {'✅' if success else '❌'}")
                
                if success:
                    obs_id = result.get('data', {}).get('observationId')
                    print(f"   Created observation: {obs_id}")
                    
                    # Verify storage
                    cursor.execute("""
                        SELECT COUNT(*) FROM business.ai_observation_h 
                        WHERE ai_observation_bk = %s
                    """, (obs_id,))
                    stored_count = cursor.fetchone()[0]
                    print(f"   Verified in database: {stored_count} records")
                    
                    results["test_results"]["ai_observation_fixed"] = {
                        "success": True,
                        "observation_id": obs_id,
                        "stored_in_db": stored_count > 0
                    }
                else:
                    error_msg = result.get('message', 'Unknown error')
                    print(f"   Error: {error_msg}")
                    results["test_results"]["ai_observation_fixed"] = {
                        "success": False,
                        "error": error_msg
                    }
                    
            except Exception as e:
                print(f"   ❌ Function call failed: {e}")
                results["test_results"]["ai_observation_fixed"] = {"error": str(e)}
        
        # Test 7: Check AI functions exist
        print("\n⚙️ Checking AI Functions...")
        ai_functions = [
            'ai_log_observation', 'ai_get_observations', 
            'ai_secure_chat', 'ai_monitoring_ingest',
            'ai_create_session', 'ai_chat_history'
        ]
        
        existing_functions = []
        for func in ai_functions:
            cursor.execute("""
                SELECT EXISTS(
                    SELECT 1 FROM information_schema.routines 
                    WHERE routine_schema = 'api' 
                    AND routine_name = %s
                )
            """, (func,))
            exists = cursor.fetchone()[0]
            print(f"   api.{func}: {'✅' if exists else '❌'}")
            if exists:
                existing_functions.append(func)
        
        results["functions"]["existing_functions"] = existing_functions
        
        conn.commit()
        
        # Comprehensive Summary
        print("\n" + "=" * 70)
        print("🎯 COMPREHENSIVE AI INFRASTRUCTURE SUMMARY")
        print("=" * 70)
        
        # Schema Analysis
        schema_score = sum(1 for schema in ['ai_agents', 'ai_monitoring', 'business'] if results["schemas"].get(schema))
        print(f"📊 AI SCHEMAS: {schema_score}/3 core AI schemas found")
        
        # Table Analysis
        total_ai_tables = (
            len(results["schemas"].get("business_ai_tables", [])) +
            len(results["schemas"].get("ai_monitoring_tables", [])) + 
            len(results["schemas"].get("ai_agents_tables", []))
        )
        print(f"📋 AI TABLES: {total_ai_tables} total AI tables found")
        
        # Data Analysis
        total_ai_records = sum(count for key, count in results["data_counts"].items() if isinstance(count, int))
        print(f"📈 AI DATA: {total_ai_records} total AI records found")
        
        # Function Analysis
        function_score = len(existing_functions)
        print(f"⚙️ AI FUNCTIONS: {function_score}/6 AI functions available")
        
        # Test Results
        ai_obs_fixed = results["test_results"].get("ai_observation_fixed", {})
        if ai_obs_fixed.get("success"):
            print("✅ AI OBSERVATION: Fixed and working!")
        else:
            print("❌ AI OBSERVATION: Still needs debugging")
        
        # Overall Score
        overall_score = 0
        if schema_score >= 2: overall_score += 1
        if total_ai_tables >= 10: overall_score += 1  
        if total_ai_records > 0: overall_score += 1
        if function_score >= 4: overall_score += 1
        if ai_obs_fixed.get("success"): overall_score += 1
        
        print(f"\n🏆 OVERALL SCORE: {overall_score}/5")
        
        if overall_score >= 4:
            print("🎉 EXCELLENT - Advanced AI infrastructure confirmed!")
            print("📋 NEXT STEP: Connect Canvas to API - foundation is solid")
        elif overall_score >= 3:
            print("✅ GOOD - AI infrastructure mostly working")
            print("📋 NEXT STEP: Fix remaining issues, then connect Canvas")
        else:
            print("⚠️ NEEDS WORK - AI infrastructure incomplete")
            print("📋 NEXT STEP: Run ai_agents_scripts and ai_ml_99.9_scripts")
        
        # Save comprehensive results
        filename = f"comprehensive_ai_test_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
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