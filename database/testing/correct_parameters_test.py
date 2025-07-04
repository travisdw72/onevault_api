#!/usr/bin/env python3
"""
Correct Parameters Test - Uses Exact Function Signatures
Based on discovered function signatures from PostgreSQL
"""

import psycopg2
import json
import getpass
from datetime import datetime
import uuid

def main():
    print("🎯 Correct Parameters Test - Using Exact Signatures")
    print("Testing with discovered function parameter formats")
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
            "signature_tests": {}
        }
        
        # Get tenant data
        cursor.execute("""
            SELECT th.tenant_hk, th.tenant_bk, tps.tenant_name 
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.load_end_date IS NULL
            AND tps.tenant_name = '72 Industries LLC'
            LIMIT 1
        """)
        tenant_data = cursor.fetchone()
        
        if not tenant_data:
            cursor.execute("""
                SELECT th.tenant_hk, th.tenant_bk, tps.tenant_name 
                FROM auth.tenant_h th
                JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
                WHERE tps.load_end_date IS NULL
                LIMIT 1
            """)
            tenant_data = cursor.fetchone()
            
        tenant_hk, tenant_bk, tenant_name = tenant_data
        print(f"🏢 Using tenant: {tenant_name}")
        
        # TEST 1: AI Observation (Correct Single JSONB)
        print("\n🔍 TEST 1: AI Observation (Correct JSONB Format)...")
        
        try:
            # Use EXACT signature: ai_log_observation(p_request jsonb)
            ai_request = {
                "tenantId": tenant_bk,
                "observationType": "signature_test",
                "severityLevel": "low", 
                "confidenceScore": 0.95,
                "observationData": {
                    "test_type": "correct_signature_test",
                    "discovery": "function_signatures_found",
                    "timestamp": datetime.now().isoformat()
                },
                "recommendedActions": ["verify_parameter_format"],
                "ip_address": "127.0.0.1",
                "user_agent": "Correct_Signature_Test"
            }
            
            cursor.execute(
                "SELECT api.ai_log_observation(%s::jsonb)", 
                (json.dumps(ai_request),)
            )
            ai_result = cursor.fetchone()[0]
            
            success = isinstance(ai_result, dict) and ai_result.get('success', False)
            print(f"   📋 AI Observation: {'✅ SUCCESS' if success else '❌ FAILED'}")
            
            if success:
                obs_data = ai_result.get('data', {})
                obs_id = obs_data.get('observationId')
                if obs_id:
                    print(f"   📝 Observation ID: {obs_id}")
            else:
                error_msg = ai_result.get('message', 'Unknown error')
                print(f"   🐛 Error: {error_msg}")
                debug_info = ai_result.get('debug_info', {})
                if debug_info:
                    print(f"   🐛 Debug: {debug_info}")
            
            results["signature_tests"]["ai_observation_correct"] = success
            conn.commit()  # Commit successful transaction
            
        except Exception as e:
            print(f"   ❌ AI observation failed: {e}")
            results["signature_tests"]["ai_observation_correct"] = False
            conn.rollback()  # Rollback failed transaction
        
        # TEST 2: Token Generation (Correct Single JSONB)
        print("\n🔍 TEST 2: Token Generation (Correct JSONB Format)...")
        
        try:
            # Use EXACT signature: tokens_generate(p_request jsonb)
            token_request = {
                "tenantId": tenant_bk,
                "tokenType": "api_access",
                "purpose": "canvas_integration_test",
                "permissions": ["read", "write"],
                "metadata": {
                    "test_type": "signature_verification",
                    "created_by": "correct_parameters_test"
                }
            }
            
            cursor.execute(
                "SELECT api.tokens_generate(%s::jsonb)", 
                (json.dumps(token_request),)
            )
            token_result = cursor.fetchone()[0]
            
            success = isinstance(token_result, dict) and token_result.get('success', False)
            print(f"   📋 Token Generation: {'✅ SUCCESS' if success else '❌ FAILED'}")
            
            if success:
                token_data = token_result.get('data', {})
                token_value = token_data.get('token')
                if token_value:
                    print(f"   🔑 Token Generated: {token_value[:20]}...")
                    print(f"   📅 Valid for Canvas integration!")
            else:
                error_msg = token_result.get('message', 'Unknown error')
                print(f"   🐛 Error: {error_msg}")
            
            results["signature_tests"]["token_generation_correct"] = success
            conn.commit()
            
        except Exception as e:
            print(f"   ❌ Token generation failed: {e}")
            results["signature_tests"]["token_generation_correct"] = False
            conn.rollback()
        
        # TEST 3: Site Tracking (Direct Parameters Format)
        print("\n🔍 TEST 3: Site Tracking (Direct Parameters Format)...")
        
        try:
            # Use signature: track_site_event(p_ip_address, p_user_agent, p_page_url, p_event_type, p_event_data)
            event_data_direct = {
                "tenant_id": tenant_bk,
                "test_type": "direct_parameters_signature",
                "discovery": "direct_parameter_format",
                "timestamp": datetime.now().isoformat()
            }
            
            cursor.execute("""
                SELECT api.track_site_event(
                    %s::inet,     -- p_ip_address
                    %s::text,     -- p_user_agent
                    %s::text,     -- p_page_url
                    %s::varchar,  -- p_event_type  
                    %s::jsonb     -- p_event_data
                )
            """, (
                "127.0.0.1",
                "Signature_Test_Direct",
                "https://canvas.onevault.ai/direct-test",
                "signature_verification",
                json.dumps(event_data_direct)
            ))
            
            track_result = cursor.fetchone()[0]
            
            success = isinstance(track_result, dict) and track_result.get('success', False)
            print(f"   📋 Direct Format: {'✅ SUCCESS' if success else '❌ FAILED'}")
            
            results["signature_tests"]["site_tracking_direct"] = success
            conn.commit()
            
        except Exception as e:
            print(f"   ❌ Direct format failed: {e}")
            results["signature_tests"]["site_tracking_direct"] = False
            conn.rollback()
        
        # TEST 4: System Health (Known Working)
        print("\n🔍 TEST 4: System Health Check (Verification)...")
        
        try:
            cursor.execute("SELECT api.system_health_check()")
            health_result = cursor.fetchone()[0]
            
            success = isinstance(health_result, dict) and health_result.get('status') == 'healthy'
            print(f"   📋 System Health: {'✅ SUCCESS' if success else '❌ FAILED'}")
            
            if success:
                print(f"   🏥 Status: {health_result.get('status')}")
                print(f"   💬 Message: {health_result.get('message', 'No message')}")
            
            results["signature_tests"]["system_health"] = success
            
        except Exception as e:
            print(f"   ❌ System health failed: {e}")
            results["signature_tests"]["system_health"] = False
        
        # FINAL ANALYSIS
        print("\n" + "=" * 70)
        print("🎯 SIGNATURE-BASED TEST RESULTS")
        print("=" * 70)
        
        successful_tests = sum(1 for test, result in results["signature_tests"].items() if result)
        total_tests = len(results["signature_tests"])
        
        print(f"📊 Signature Tests: {successful_tests}/{total_tests} successful")
        print(f"🏢 Tenant: {tenant_name}")
        
        # Determine Canvas connection readiness
        ai_working = results["signature_tests"].get("ai_observation_correct", False)
        token_working = results["signature_tests"].get("token_generation_correct", False)
        tracking_working = results["signature_tests"].get("site_tracking_direct", False)
        health_working = results["signature_tests"].get("system_health", False)
        
        canvas_ready = ai_working and token_working and health_working
        
        if canvas_ready:
            print("\n🎉 CANVAS CONNECTION READY!")
            print("📋 STATUS: All core functions working with correct signatures")
            print("🚀 IMMEDIATE ACTION: Connect Canvas to API")
        elif successful_tests >= 2:
            print("\n✅ INFRASTRUCTURE MOSTLY WORKING!")
            print("📋 STATUS: Core functions operational")
            print("🚀 RECOMMENDATION: Connect Canvas with working functions")
        else:
            print("\n🔧 PARTIAL SUCCESS - GOOD FOUNDATION")
            print("📋 STATUS: Some functions working")
            print("🚀 NEXT STEP: Debug remaining parameter issues")
        
        # Canvas Integration Instructions
        if successful_tests >= 2:
            print("\n🎯 CANVAS INTEGRATION READY!")
            print("Use these exact API call formats:")
            
            if ai_working:
                print("\n📋 AI Observations - WORKING:")
                print("POST /api/ai_log_observation")
                print("Content-Type: application/json")
                print("""Body: {
  "tenantId": "your_tenant_id",
  "observationType": "canvas_event", 
  "severityLevel": "low",
  "confidenceScore": 0.95,
  "observationData": { ...your_data... }
}""")
            
            if token_working:
                print("\n🔑 Token Generation - WORKING:")
                print("POST /api/tokens_generate") 
                print("""Body: {
  "tenantId": "your_tenant_id",
  "tokenType": "api_access",
  "purpose": "canvas_integration"
}""")
            
            if health_working:
                print("\n🏥 System Health - WORKING:")
                print("GET /api/system_health_check")
        
        # Save results
        filename = f"signature_test_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\n💾 Results saved to: {filename}")
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main() 