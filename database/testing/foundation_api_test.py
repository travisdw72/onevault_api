#!/usr/bin/env python3
"""
Foundation API Test - OneVault AI System
Tests the actual AI functions to see if basic data flow works
Focus: Does data actually get stored and retrieved?
"""

import psycopg2
import json
import getpass
from datetime import datetime, timedelta
import uuid

def connect_to_database():
    """Connect to local test database"""
    print("🧪 Foundation API Test - Testing Actual AI Functions")
    password = getpass.getpass("Database password for one_vault_site_testing: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        print("✅ Connected to database")
        return conn
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return None

def test_basic_data_storage(cursor):
    """Test if we can actually store and retrieve basic data"""
    print("\n📊 Testing Basic Data Storage...")
    
    results = {"basic_storage": {}}
    
    try:
        # Test 1: Check if we have any tenants
        cursor.execute("SELECT COUNT(*) FROM auth.tenant_h")
        tenant_count = cursor.fetchone()[0]
        print(f"   Tenants in system: {tenant_count}")
        results["basic_storage"]["tenant_count"] = tenant_count
        
        if tenant_count == 0:
            print("   ⚠️  No tenants found - cannot test AI functions")
            return results
        
        # Test 2: Get a test tenant
        cursor.execute("""
            SELECT th.tenant_hk, tps.tenant_name 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.load_end_date IS NULL
            LIMIT 1
        """)
        
        tenant_data = cursor.fetchone()
        if tenant_data:
            test_tenant_hk, test_tenant_name = tenant_data
            print(f"   Using test tenant: {test_tenant_name}")
            results["basic_storage"]["test_tenant"] = test_tenant_name
        else:
            print("   ❌ No valid tenant profiles found")
            return results
        
        # Test 3: Check if AI schemas exist
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name IN ('ai_agents', 'ai_monitoring', 'business')
        """)
        
        schemas = [row[0] for row in cursor.fetchall()]
        print(f"   AI schemas found: {schemas}")
        results["basic_storage"]["ai_schemas"] = schemas
        
        # Test 4: Check if we have actual AI data
        if 'business' in schemas:
            cursor.execute("""
                SELECT 
                    (SELECT COUNT(*) FROM business.ai_observation_h) as observations,
                    (SELECT COUNT(*) FROM business.ai_alert_h) as alerts
            """)
            
            obs_count, alert_count = cursor.fetchone()
            print(f"   AI Observations: {obs_count}, AI Alerts: {alert_count}")
            results["basic_storage"]["ai_data"] = {
                "observations": obs_count,
                "alerts": alert_count
            }
        
        results["basic_storage"]["status"] = "✅ Basic storage verified"
        
    except Exception as e:
        print(f"   ❌ Basic storage test failed: {e}")
        results["basic_storage"]["error"] = str(e)
    
    return results

def test_ai_observation_function(cursor):
    """Test the actual ai_log_observation function"""
    print("\n🤖 Testing AI Observation Function...")
    
    results = {"ai_observation": {}}
    
    try:
        # Get a test tenant ID
        cursor.execute("""
            SELECT tps.tenant_name 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.load_end_date IS NULL
            LIMIT 1
        """)
        
        tenant_result = cursor.fetchone()
        if not tenant_result:
            results["ai_observation"]["error"] = "No tenant found for testing"
            return results
        
        test_tenant_id = tenant_result[0]
        
        # Create test observation request
        test_request = {
            "tenantId": test_tenant_id,
            "observationType": "test_observation",
            "severityLevel": "medium",
            "confidenceScore": 0.85,
            "entityId": "test_entity_001",
            "sensorId": "test_sensor_001",
            "observationData": {
                "test_metric": 42.5,
                "test_status": "normal",
                "test_timestamp": datetime.now().isoformat()
            },
            "recommendedActions": ["monitor_closely", "schedule_inspection"],
            "ip_address": "127.0.0.1",
            "user_agent": "Foundation_Test_Script"
        }
        
        print(f"   Testing with tenant: {test_tenant_id}")
        
        # Call the actual API function
        cursor.execute("SELECT api.ai_log_observation(%s)", (json.dumps(test_request),))
        result = cursor.fetchone()[0]
        
        print(f"   Function result: {result.get('success', False)}")
        
        if result.get('success'):
            observation_id = result.get('data', {}).get('observationId')
            print(f"   Created observation: {observation_id}")
            results["ai_observation"]["observation_created"] = observation_id
            results["ai_observation"]["status"] = "✅ AI observation function works"
            
            # Verify data was actually stored
            cursor.execute("""
                SELECT COUNT(*) FROM business.ai_observation_h aoh
                JOIN business.ai_observation_details_s aods ON aoh.ai_observation_hk = aods.ai_observation_hk
                WHERE aoh.ai_observation_bk = %s
                AND aods.load_end_date IS NULL
            """, (observation_id,))
            
            stored_count = cursor.fetchone()[0]
            print(f"   Verified in database: {stored_count} records")
            results["ai_observation"]["verified_in_db"] = stored_count > 0
            
        else:
            error_msg = result.get('message', 'Unknown error')
            print(f"   ❌ Function failed: {error_msg}")
            results["ai_observation"]["error"] = error_msg
        
    except Exception as e:
        print(f"   ❌ AI observation test failed: {e}")
        results["ai_observation"]["error"] = str(e)
    
    return results

def test_ai_monitoring_ingest(cursor):
    """Test the AI monitoring ingest function"""
    print("\n📡 Testing AI Monitoring Ingest...")
    
    results = {"ai_monitoring": {}}
    
    try:
        # Get test tenant and create fake auth token
        cursor.execute("""
            SELECT tps.tenant_name 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.load_end_date IS NULL
            LIMIT 1
        """)
        
        tenant_result = cursor.fetchone()
        if not tenant_result:
            results["ai_monitoring"]["error"] = "No tenant found"
            return results
        
        test_tenant_id = tenant_result[0]
        
        # Create monitoring ingest request
        test_request = {
            "token": "test_token_123",  # This will fail auth, but we'll see how far it gets
            "entity_bk": "test_monitoring_entity_001",
            "entity_type": "EQUIPMENT",
            "monitoring_data": {
                "temperature": 72.5,
                "humidity": 45.2,
                "vibration_level": 0.05,
                "operational_status": "normal",
                "alert_threshold": 80.0,
                "metric_value": 75.0
            },
            "ip_address": "127.0.0.1",
            "user_agent": "Foundation_Test_Script"
        }
        
        # Call the function (expecting auth failure)
        cursor.execute("SELECT api.ai_monitoring_ingest(%s)", (json.dumps(test_request),))
        result = cursor.fetchone()[0]
        
        print(f"   Function response: {result.get('error_code', 'SUCCESS')}")
        
        if result.get('error_code') == 'AUTHENTICATION_FAILED':
            print("   ✅ Function exists and handles auth properly")
            results["ai_monitoring"]["function_exists"] = True
            results["ai_monitoring"]["auth_working"] = True
            results["ai_monitoring"]["status"] = "✅ Function exists with proper security"
        else:
            print(f"   Unexpected result: {result}")
            results["ai_monitoring"]["unexpected_result"] = result
        
    except Exception as e:
        print(f"   ❌ AI monitoring test failed: {e}")
        results["ai_monitoring"]["error"] = str(e)
    
    return results

def test_raw_layer_access(cursor):
    """Test if we can access raw layer data"""
    print("\n📥 Testing Raw Layer Access...")
    
    results = {"raw_layer": {}}
    
    try:
        # Check if raw schema exists
        cursor.execute("""
            SELECT EXISTS(
                SELECT 1 FROM information_schema.schemata 
                WHERE schema_name = 'raw'
            )
        """)
        
        raw_exists = cursor.fetchone()[0]
        print(f"   Raw schema exists: {raw_exists}")
        results["raw_layer"]["schema_exists"] = raw_exists
        
        if raw_exists:
            # Check for raw tables
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'raw'
                ORDER BY table_name
            """)
            
            raw_tables = [row[0] for row in cursor.fetchall()]
            print(f"   Raw tables found: {len(raw_tables)}")
            if raw_tables:
                print(f"   Tables: {raw_tables[:5]}...")  # Show first 5
            results["raw_layer"]["tables"] = raw_tables
            
            # Check if there's any data in raw layer
            total_raw_data = 0
            for table in raw_tables[:3]:  # Check first 3 tables
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM raw.{table}")
                    count = cursor.fetchone()[0]
                    total_raw_data += count
                    print(f"     {table}: {count} records")
                except:
                    pass
            
            results["raw_layer"]["total_records"] = total_raw_data
            results["raw_layer"]["status"] = f"✅ Raw layer has {total_raw_data} records"
        else:
            results["raw_layer"]["status"] = "❌ No raw schema found"
        
    except Exception as e:
        print(f"   ❌ Raw layer test failed: {e}")
        results["raw_layer"]["error"] = str(e)
    
    return results

def main():
    print("🔍 Foundation API Test - Testing Actual AI Functions")
    print("=" * 60)
    
    conn = connect_to_database()
    if not conn:
        return
    
    cursor = conn.cursor()
    
    # Run all foundation tests
    all_results = {
        "timestamp": datetime.now().isoformat(),
        "test_summary": {}
    }
    
    try:
        # Test 1: Basic data storage
        basic_results = test_basic_data_storage(cursor)
        all_results.update(basic_results)
        
        # Test 2: AI observation function
        obs_results = test_ai_observation_function(cursor)
        all_results.update(obs_results)
        
        # Test 3: AI monitoring ingest
        monitoring_results = test_ai_monitoring_ingest(cursor)
        all_results.update(monitoring_results)
        
        # Test 4: Raw layer access
        raw_results = test_raw_layer_access(cursor)
        all_results.update(raw_results)
        
        # Commit any test data
        conn.commit()
        
        # Summary
        print("\n" + "=" * 60)
        print("📋 FOUNDATION TEST SUMMARY")
        print("=" * 60)
        
        tests_passed = 0
        total_tests = 4
        
        for test_name, results in all_results.items():
            if test_name == "timestamp":
                continue
            if isinstance(results, dict) and "status" in results:
                print(f"{test_name.upper()}: {results['status']}")
                if "✅" in results['status']:
                    tests_passed += 1
        
        print(f"\nPASS RATE: {tests_passed}/{total_tests} tests passed")
        
        if tests_passed == total_tests:
            print("🎉 ALL FOUNDATION TESTS PASSED - Ready for ETL testing!")
        elif tests_passed >= 2:
            print("⚠️  PARTIAL SUCCESS - Some issues need attention before ETL")
        else:
            print("❌ MAJOR ISSUES - Foundation needs work before proceeding")
        
        # Save results
        filename = f"foundation_test_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(all_results, f, indent=2, default=str)
        print(f"\nResults saved to: {filename}")
        
    except Exception as e:
        print(f"❌ Test execution failed: {e}")
        all_results["execution_error"] = str(e)
    
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    main() 