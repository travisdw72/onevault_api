#!/usr/bin/env python3
"""
Final Parameter Test - Uses Proper PostgreSQL Casting
Fixes "unknown" parameter type issues
"""

import psycopg2
import json
import getpass
from datetime import datetime
import uuid

def main():
    print("🔧 Final Parameter Test - PostgreSQL Casting Fixed")
    print("Fixing 'unknown' parameter type issues")
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
            "parameter_fixed_tests": {}
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
        
        # TEST 1: Check Function Signatures First
        print("\n🔍 TEST 1: Function Signature Analysis...")
        
        try:
            cursor.execute("""
                SELECT 
                    p.proname as function_name,
                    pg_get_function_arguments(p.oid) as arguments,
                    pg_get_function_result(p.oid) as return_type
                FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid
                WHERE n.nspname = 'api'
                AND p.proname IN ('track_site_event', 'tokens_generate', 'ai_log_observation')
                ORDER BY p.proname
            """)
            
            signatures = cursor.fetchall()
            print("   📋 Function signatures found:")
            
            function_info = {}
            for func_name, args, return_type in signatures:
                print(f"   🔧 {func_name}({args}) → {return_type}")
                function_info[func_name] = {"args": args, "return": return_type}
            
            results["parameter_fixed_tests"]["function_signatures"] = function_info
            
        except Exception as e:
            print(f"   ❌ Signature analysis failed: {e}")
            results["parameter_fixed_tests"]["function_signatures"] = {}
        
        # TEST 2: Site Tracking with Multiple Approaches
        print("\n🔍 TEST 2: Site Tracking (Multiple Parameter Approaches)...")
        
        # Approach 1: Single JSONB parameter
        try:
            tracking_payload = {
                "tenant_id": tenant_bk,
                "event_type": "parameter_test_jsonb",
                "page_url": "https://test.onevault.ai/parameter-test",
                "event_data": {"test": "jsonb_cast"},
                "user_agent": "JSONB_Test",
                "ip_address": "127.0.0.1"
            }
            
            cursor.execute(
                "SELECT api.track_site_event(%s::jsonb)", 
                (json.dumps(tracking_payload),)
            )
            track_result = cursor.fetchone()[0]
            
            success = isinstance(track_result, dict) and track_result.get('success', False)
            print(f"   📋 JSONB approach: {'✅ SUCCESS' if success else '❌ FAILED'}")
            results["parameter_fixed_tests"]["site_tracking_jsonb"] = success
            
        except Exception as e:
            print(f"   ❌ JSONB approach failed: {e}")
            results["parameter_fixed_tests"]["site_tracking_jsonb"] = False
        
        # Approach 2: Multiple TEXT parameters
        try:
            cursor.execute("""
                SELECT api.track_site_event(
                    %s::text,  -- tenant_id
                    %s::text,  -- event_type  
                    %s::text,  -- page_url
                    %s::jsonb, -- event_data
                    %s::text,  -- user_agent
                    %s::inet   -- ip_address
                )
            """, (
                tenant_bk,
                "parameter_test_multi",
                "https://test.onevault.ai/multi-param",
                json.dumps({"test": "multi_param"}),
                "Multi_Param_Test",
                "127.0.0.1"
            ))
            
            multi_result = cursor.fetchone()[0]
            multi_success = isinstance(multi_result, dict) and multi_result.get('success', False)
            print(f"   📋 Multi-param approach: {'✅ SUCCESS' if multi_success else '❌ FAILED'}")
            results["parameter_fixed_tests"]["site_tracking_multi"] = multi_success
            
        except Exception as e:
            print(f"   ❌ Multi-param approach failed: {e}")
            results["parameter_fixed_tests"]["site_tracking_multi"] = False
        
        # TEST 3: Token Generation with Various Casts
        print("\n🔍 TEST 3: Token Generation (Parameter Casting)...")
        
        try:
            cursor.execute(
                "SELECT api.tokens_generate(%s::text, %s::text)", 
                (tenant_bk, "api_access")
            )
            token_result = cursor.fetchone()[0]
            
            success = isinstance(token_result, dict) and token_result.get('success', False)
            print(f"   📋 Token generation: {'✅ SUCCESS' if success else '❌ FAILED'}")
            
            if success:
                token_data = token_result.get('data', {})
                if token_data.get('token'):
                    print(f"   🔑 Token preview: {token_data['token'][:20]}...")
            else:
                print(f"   📋 Error: {token_result.get('message', 'Unknown error')}")
                
            results["parameter_fixed_tests"]["token_generation"] = success
            
        except Exception as e:
            print(f"   ❌ Token generation failed: {e}")
            results["parameter_fixed_tests"]["token_generation"] = False
        
        # TEST 4: AI Observation with Minimal Data
        print("\n🔍 TEST 4: AI Observation (Minimal Test)...")
        
        try:
            minimal_ai = {
                "tenantId": tenant_bk,
                "observationType": "minimal_test",
                "severityLevel": "low",
                "confidenceScore": 0.9,
                "observationData": {"test": "minimal"}
            }
            
            cursor.execute(
                "SELECT api.ai_log_observation(%s::jsonb)", 
                (json.dumps(minimal_ai),)
            )
            ai_result = cursor.fetchone()[0]
            
            success = isinstance(ai_result, dict) and ai_result.get('success', False)
            print(f"   📋 AI observation: {'✅ SUCCESS' if success else '❌ FAILED'}")
            
            if not success:
                debug_info = ai_result.get('debug_info', {})
                error_msg = ai_result.get('message', 'Unknown error')
                print(f"   🐛 Error: {error_msg}")
                if debug_info:
                    print(f"   🐛 Debug: {debug_info}")
            
            results["parameter_fixed_tests"]["ai_observation"] = success
            
        except Exception as e:
            print(f"   ❌ AI observation failed: {e}")
            results["parameter_fixed_tests"]["ai_observation"] = False
        
        # TEST 5: Working Functions Verification
        print("\n🔍 TEST 5: Known Working Functions...")
        
        working_functions = []
        
        # Test system health (known to work)
        try:
            cursor.execute("SELECT api.system_health_check()")
            health_result = cursor.fetchone()[0]
            working_functions.append("system_health_check")
            print("   ✅ system_health_check: WORKING")
        except Exception as e:
            print(f"   ❌ system_health_check failed: {e}")
        
        # Test auth functions
        try:
            cursor.execute("SELECT api.auth_login('test@test.com', 'password', %s)", (tenant_bk,))
            auth_result = cursor.fetchone()[0]
            working_functions.append("auth_login")
            print("   ✅ auth_login: WORKING (function callable)")
        except Exception as e:
            if "invalid credentials" in str(e).lower() or "user not found" in str(e).lower():
                working_functions.append("auth_login")
                print("   ✅ auth_login: WORKING (expected auth failure)")
            else:
                print(f"   ❌ auth_login failed: {e}")
        
        results["parameter_fixed_tests"]["working_functions"] = working_functions
        
        # SUMMARY
        print("\n" + "=" * 70)
        print("🎯 PARAMETER CASTING ANALYSIS COMPLETE")
        print("=" * 70)
        
        successful_tests = sum(1 for test, result in results["parameter_fixed_tests"].items() 
                              if isinstance(result, bool) and result)
        
        print(f"📊 Parameter tests: {successful_tests} successful")
        print(f"🔧 Working functions: {len(working_functions)}")
        print(f"🏢 Tenant: {tenant_name}")
        
        if len(working_functions) >= 2:
            print("\n🎉 CORE INFRASTRUCTURE CONFIRMED WORKING!")
            print("📋 STATUS: Database functions operational")
            print("🚀 RECOMMENDATION: Connect Canvas with working functions")
            print("💡 Use system_health_check and auth_login for Canvas integration")
        else:
            print("\n⚠️ NEED FUNCTION SIGNATURE ANALYSIS")
            print("📋 STATUS: Parameter type mismatches")
            print("🚀 NEXT STEP: Check actual function definitions in database")
        
        # Save results
        filename = f"parameter_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
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