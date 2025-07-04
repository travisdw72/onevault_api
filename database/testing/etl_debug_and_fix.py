#!/usr/bin/env python3
"""
ETL Debug and Fix - OneVault Data Pipeline
Finds and fixes the $100 bug preventing data flow
Tests: Raw → Staging → Business → AI Functions
"""

import psycopg2
import json
import getpass
from datetime import datetime, timedelta
import uuid

def main():
    print("🔧 ETL Debug and Fix - OneVault Data Pipeline")
    print("Finding the $100 bug that's blocking $10M+ AI infrastructure")
    print("=" * 70)
    
    password = getpass.getpass("Database password for one_vault_site_testing: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        debug_results = {
            "timestamp": datetime.now().isoformat(),
            "pipeline_tests": {},
            "root_cause": None,
            "fix_applied": False,
            "recommendations": []
        }
        
        # Get test tenant info
        cursor.execute("""
            SELECT th.tenant_hk, th.tenant_bk, tps.tenant_name 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.load_end_date IS NULL
            LIMIT 1
        """)
        tenant_data = cursor.fetchone()
        
        if not tenant_data:
            print("❌ No tenant data found - this might be the issue!")
            return
            
        tenant_hk, tenant_bk, tenant_name = tenant_data
        print(f"🏢 Using tenant: {tenant_name} (BK: {tenant_bk})")
        
        # TEST 1: Can we insert into RAW layer?
        print("\n🔍 TEST 1: Raw Layer Data Insert...")
        test_raw_id = str(uuid.uuid4())
        
        try:
            # Test raw insertion
            cursor.execute("""
                INSERT INTO raw.external_data_h (
                    external_data_hk, external_data_bk, tenant_hk, 
                    load_date, record_source
                ) VALUES (
                    %s, %s, %s, %s, %s
                )
            """, (
                tenant_hk[:32],  # Use tenant_hk as test hash
                f"ETL_TEST_{test_raw_id}",
                tenant_hk,
                datetime.now(),
                "ETL_DEBUG_SCRIPT"
            ))
            
            cursor.execute("""
                INSERT INTO raw.external_data_s (
                    external_data_hk, load_date, hash_diff,
                    source_system, data_type, raw_data,
                    processing_status, record_source
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s
                )
            """, (
                tenant_hk[:32],
                datetime.now(),
                tenant_hk[:32],  # Use as hash_diff
                "ETL_DEBUG",
                "TEST_DATA",
                '{"test": "data", "timestamp": "' + datetime.now().isoformat() + '"}',
                "PENDING",
                "ETL_DEBUG_SCRIPT"
            ))
            
            conn.commit()
            print("   ✅ Raw layer insert: SUCCESS")
            debug_results["pipeline_tests"]["raw_insert"] = True
            
        except Exception as e:
            print(f"   ❌ Raw layer insert: FAILED - {e}")
            debug_results["pipeline_tests"]["raw_insert"] = False
            debug_results["root_cause"] = f"Raw layer insertion failed: {e}"
            conn.rollback()
        
        # TEST 2: Can we process RAW → STAGING?
        print("\n🔍 TEST 2: Raw → Staging Processing...")
        
        try:
            # Check if staging processing functions exist
            cursor.execute("""
                SELECT EXISTS(
                    SELECT 1 FROM information_schema.routines 
                    WHERE routine_schema = 'staging' 
                    AND routine_name LIKE '%process%'
                )
            """)
            staging_functions_exist = cursor.fetchone()[0]
            
            if staging_functions_exist:
                print("   ✅ Staging processing functions found")
                # Try to find specific staging processing function
                cursor.execute("""
                    SELECT routine_name FROM information_schema.routines 
                    WHERE routine_schema = 'staging' 
                    AND routine_name LIKE '%process%'
                    LIMIT 3
                """)
                staging_funcs = cursor.fetchall()
                print(f"   📋 Available functions: {[f[0] for f in staging_funcs]}")
                
            else:
                print("   ⚠️ No staging processing functions found")
                debug_results["recommendations"].append("Implement staging processing functions")
            
            debug_results["pipeline_tests"]["staging_functions"] = staging_functions_exist
            
        except Exception as e:
            print(f"   ❌ Staging check failed: {e}")
            debug_results["pipeline_tests"]["staging_functions"] = False
        
        # TEST 3: Test AI Observation Function in Detail
        print("\n🔍 TEST 3: AI Observation Function Deep Debug...")
        
        # Test with minimal parameters first
        minimal_test = {
            "tenantId": tenant_bk,
            "observationType": "test",
            "severityLevel": "low",
            "confidenceScore": 0.5,
            "observationData": {"test": True},
            "recommendedActions": ["test"],
            "ip_address": "127.0.0.1",
            "user_agent": "ETL_Debug"
        }
        
        try:
            cursor.execute("SELECT api.ai_log_observation(%s)", (json.dumps(minimal_test),))
            result = cursor.fetchone()[0]
            
            print(f"   📋 Function result: {result}")
            
            if isinstance(result, dict):
                success = result.get('success', False)
                message = result.get('message', 'No message')
                data = result.get('data', {})
                
                print(f"   Success: {success}")
                print(f"   Message: {message}")
                print(f"   Data: {data}")
                
                if success:
                    print("   ✅ AI Observation: SUCCESS!")
                    debug_results["pipeline_tests"]["ai_observation"] = True
                    
                    # Check if data actually got stored
                    obs_id = data.get('observationId')
                    if obs_id:
                        cursor.execute("""
                            SELECT COUNT(*) FROM business.ai_observation_h 
                            WHERE ai_observation_bk = %s
                        """, (obs_id,))
                        stored_count = cursor.fetchone()[0]
                        print(f"   💾 Records stored: {stored_count}")
                        debug_results["pipeline_tests"]["data_stored"] = stored_count > 0
                else:
                    print(f"   ❌ AI Observation failed: {message}")
                    debug_results["pipeline_tests"]["ai_observation"] = False
                    debug_results["root_cause"] = f"AI observation failed: {message}"
            else:
                print(f"   ❌ Unexpected result format: {type(result)}")
                debug_results["pipeline_tests"]["ai_observation"] = False
                
        except Exception as e:
            print(f"   ❌ AI Observation function error: {e}")
            debug_results["pipeline_tests"]["ai_observation"] = False
            debug_results["root_cause"] = f"AI observation function error: {e}"
            
            # Get more details about the error
            cursor.execute("ROLLBACK")
            
        # TEST 4: Check for constraint violations
        print("\n🔍 TEST 4: Database Constraint Analysis...")
        
        try:
            # Check foreign key constraints on AI tables
            cursor.execute("""
                SELECT 
                    tc.constraint_name,
                    tc.table_name,
                    kcu.column_name,
                    ccu.table_name AS foreign_table_name,
                    ccu.column_name AS foreign_column_name
                FROM information_schema.table_constraints AS tc 
                JOIN information_schema.key_column_usage AS kcu
                    ON tc.constraint_name = kcu.constraint_name
                JOIN information_schema.constraint_column_usage AS ccu
                    ON ccu.constraint_name = tc.constraint_name
                WHERE tc.constraint_type = 'FOREIGN KEY' 
                AND tc.table_schema = 'business'
                AND tc.table_name LIKE 'ai_%'
                LIMIT 5
            """)
            
            fk_constraints = cursor.fetchall()
            print(f"   📋 Found {len(fk_constraints)} foreign key constraints on AI tables")
            
            for constraint in fk_constraints:
                print(f"     {constraint[1]}.{constraint[2]} → {constraint[3]}.{constraint[4]}")
            
            debug_results["pipeline_tests"]["constraints_checked"] = True
            
        except Exception as e:
            print(f"   ❌ Constraint analysis failed: {e}")
            debug_results["pipeline_tests"]["constraints_checked"] = False
        
        # TEST 5: Test Site Tracking Pipeline (Known working?)
        print("\n🔍 TEST 5: Site Tracking Pipeline Test...")
        
        try:
            # Test site tracking function
            tracking_test = {
                "tenant_id": tenant_bk,
                "event_type": "etl_debug_test",
                "event_data": {
                    "test_id": test_raw_id,
                    "timestamp": datetime.now().isoformat()
                },
                "user_agent": "ETL_Debug_Script",
                "ip_address": "127.0.0.1"
            }
            
            cursor.execute("SELECT api.track_event(%s)", (json.dumps(tracking_test),))
            track_result = cursor.fetchone()[0]
            
            print(f"   📋 Site tracking result: {track_result}")
            
            if isinstance(track_result, dict) and track_result.get('success'):
                print("   ✅ Site tracking: SUCCESS")
                debug_results["pipeline_tests"]["site_tracking"] = True
            else:
                print("   ❌ Site tracking: FAILED")
                debug_results["pipeline_tests"]["site_tracking"] = False
                
        except Exception as e:
            print(f"   ❌ Site tracking test failed: {e}")
            debug_results["pipeline_tests"]["site_tracking"] = False
            cursor.execute("ROLLBACK")
        
        # ANALYSIS AND RECOMMENDATIONS
        print("\n" + "=" * 70)
        print("🎯 ETL DEBUG ANALYSIS")
        print("=" * 70)
        
        # Count successes
        successful_tests = sum(1 for test, result in debug_results["pipeline_tests"].items() if result)
        total_tests = len(debug_results["pipeline_tests"])
        
        print(f"📊 Pipeline Tests: {successful_tests}/{total_tests} passing")
        
        # Determine root cause and fix
        if not debug_results["pipeline_tests"].get("raw_insert"):
            debug_results["root_cause"] = "Raw layer insertion blocked - check permissions/constraints"
            debug_results["recommendations"].extend([
                "Check raw schema table permissions",
                "Verify tenant_hk format and constraints",
                "Test with simpler data structures"
            ])
        
        elif not debug_results["pipeline_tests"].get("ai_observation"):
            debug_results["root_cause"] = "AI observation function validation failing"
            debug_results["recommendations"].extend([
                "Check ai_log_observation function parameters",
                "Verify tenant_bk format requirements",
                "Test with minimal JSON payload",
                "Check business schema foreign key constraints"
            ])
        
        elif not debug_results["pipeline_tests"].get("data_stored"):
            debug_results["root_cause"] = "Function succeeds but data not persisted"
            debug_results["recommendations"].extend([
                "Check transaction commit issues",
                "Verify business layer insert triggers",
                "Test manual business table insertion"
            ])
        
        else:
            debug_results["root_cause"] = "Pipeline may be working - need more data"
            debug_results["recommendations"].extend([
                "Generate test dataset",
                "Test with higher volume",
                "Verify ETL scheduling/automation"
            ])
        
        print(f"\n🔍 ROOT CAUSE: {debug_results['root_cause']}")
        print("\n📋 RECOMMENDATIONS:")
        for i, rec in enumerate(debug_results["recommendations"], 1):
            print(f"   {i}. {rec}")
        
        # Save results
        filename = f"etl_debug_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(debug_results, f, indent=2, default=str)
        print(f"\n💾 Debug results saved to: {filename}")
        
        # Next steps
        print("\n🚀 IMMEDIATE NEXT STEPS:")
        if successful_tests >= 3:
            print("1. Fix identified issues above")
            print("2. Re-run comprehensive AI test")
            print("3. Connect Canvas to API")
        else:
            print("1. Check database permissions")
            print("2. Verify tenant setup")
            print("3. Test individual functions manually")
        
    except Exception as e:
        print(f"❌ Debug script failed: {e}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main() 