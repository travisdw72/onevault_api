#!/usr/bin/env python3
"""ETL Pipeline Validator - Tests raw → staging → business flow"""

import psycopg2
import json
import getpass
from datetime import datetime, timedelta
import uuid

def main():
    print("🔍 ETL Pipeline Validator")
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        print("✅ Connected to database")
        
        cursor = conn.cursor()
        results = {"timestamp": datetime.now().isoformat()}
        
        # Test 1: Site Tracking ETL Flow
        print("\n📊 Testing Site Tracking ETL...")
        
        # Get test tenant
        cursor.execute("SELECT tenant_hk FROM auth.tenant_h LIMIT 1")
        tenant_hk = cursor.fetchone()[0]
        
        # Insert test event via API
        test_id = str(uuid.uuid4())
        cursor.execute("""
            SELECT api.track_site_event(%s, 'ETL_TEST', 'https://test.com', 
                                       'Test Agent', %s, 'TEST', %s)
        """, (tenant_hk.hex(), test_id, datetime.now().isoformat()))
        
        api_result = cursor.fetchone()[0]
        print(f"  API Call: {'✅ SUCCESS' if api_result else '❌ FAILED'}")
        
        if api_result:
            import time
            time.sleep(2)  # Allow processing
            
            # Check Raw Layer
            cursor.execute("""
                SELECT COUNT(*) FROM raw.site_events 
                WHERE tenant_hk = %s AND session_id = %s
            """, (tenant_hk, test_id))
            raw_count = cursor.fetchone()[0]
            print(f"  Raw Layer: {'✅ FOUND' if raw_count > 0 else '❌ MISSING'} ({raw_count} records)")
            
            # Check Staging Layer  
            cursor.execute("""
                SELECT COUNT(*) FROM staging.site_events_processed 
                WHERE tenant_hk = %s AND session_id = %s
            """, (tenant_hk, test_id))
            staging_count = cursor.fetchone()[0]
            print(f"  Staging Layer: {'✅ FOUND' if staging_count > 0 else '❌ MISSING'} ({staging_count} records)")
            
            # Check Business Layer
            cursor.execute("""
                SELECT COUNT(*) FROM business.site_analytics_h sa
                JOIN business.site_analytics_s sas ON sa.analytics_hk = sas.analytics_hk
                WHERE sa.tenant_hk = %s AND sas.session_id = %s
            """, (tenant_hk, test_id))
            business_count = cursor.fetchone()[0]
            print(f"  Business Layer: {'✅ FOUND' if business_count > 0 else '❌ MISSING'} ({business_count} records)")
            
            results["site_tracking"] = {
                "api_call": api_result,
                "raw_count": raw_count,
                "staging_count": staging_count, 
                "business_count": business_count
            }
        
        # Test 2: AI Agent ETL Flow
        print("\n🤖 Testing AI Agent ETL...")
        
        cursor.execute("""
            SELECT api.ai_create_session(%s, 'business_intelligence_agent', 
                                        'ETL Test', '{"test": true}')
        """, (tenant_hk.hex(),))
        ai_session = cursor.fetchone()[0]
        print(f"  AI Session: {'✅ SUCCESS' if ai_session else '❌ FAILED'}")
        
        if ai_session:
            time.sleep(2)
            
            cursor.execute("""
                SELECT api.ai_log_observation(%s, 'TEST_ENTITY', 'analysis', 
                                             'ETL test observation', '{"test": true}')
            """, (tenant_hk.hex(),))
            obs_result = cursor.fetchone()[0]
            print(f"  AI Observation: {'✅ SUCCESS' if obs_result else '❌ FAILED'}")
            
            # Check AI Monitoring
            cursor.execute("""
                SELECT COUNT(*) FROM ai_monitoring.ai_analysis_h aa
                JOIN ai_monitoring.ai_analysis_results_s aar ON aa.analysis_hk = aar.analysis_hk
                WHERE aar.analysis_description LIKE '%ETL test%'
                AND aar.load_date >= %s
            """, (datetime.now() - timedelta(minutes=5),))
            ai_monitor_count = cursor.fetchone()[0]
            print(f"  AI Monitoring: {'✅ FOUND' if ai_monitor_count > 0 else '❌ MISSING'} ({ai_monitor_count} records)")
            
            results["ai_agents"] = {
                "session_creation": ai_session,
                "observation_logging": obs_result,
                "monitoring_count": ai_monitor_count
            }
        
        # Test 3: ETL Health Check
        print("\n💊 ETL Health Check...")
        
        # Check for stuck records
        cursor.execute("""
            SELECT COUNT(*) FROM raw.site_events 
            WHERE load_date < %s AND (processing_status IS NULL OR processing_status = 'PENDING')
        """, (datetime.now() - timedelta(hours=1),))
        stuck_records = cursor.fetchone()[0]
        print(f"  Stuck Records: {'⚠️ FOUND' if stuck_records > 0 else '✅ NONE'} ({stuck_records} stuck)")
        
        # Check processing times
        cursor.execute("""
            SELECT AVG(EXTRACT(EPOCH FROM (staging.load_date - raw.load_date))/60)
            FROM raw.site_events raw
            JOIN staging.site_events_processed staging ON raw.event_id = staging.source_event_id
            WHERE raw.load_date >= %s
        """, (datetime.now() - timedelta(hours=24),))
        avg_time_result = cursor.fetchone()
        avg_time = avg_time_result[0] if avg_time_result and avg_time_result[0] else None
        
        if avg_time:
            print(f"  Processing Time: {avg_time:.1f} minutes {'✅ GOOD' if avg_time < 30 else '⚠️ SLOW'}")
        else:
            print("  Processing Time: ❓ NO DATA")
        
        results["health_check"] = {
            "stuck_records": stuck_records,
            "avg_processing_minutes": float(avg_time) if avg_time else None
        }
        
        # Assessment
        print("\n🎯 ETL PIPELINE ASSESSMENT:")
        
        site_ok = results.get("site_tracking", {})
        site_healthy = (site_ok.get("raw_count", 0) > 0 and 
                       site_ok.get("staging_count", 0) > 0 and
                       site_ok.get("business_count", 0) > 0)
        
        ai_ok = results.get("ai_agents", {})
        ai_healthy = (ai_ok.get("session_creation", False) and
                     ai_ok.get("observation_logging", False))
        
        if site_healthy and ai_healthy and stuck_records == 0:
            print("  ✅ EXCELLENT: ETL pipeline is healthy!")
            print("  🚀 READY to connect Canvas to API")
            results["recommendation"] = "PROCEED_WITH_CANVAS"
        elif site_healthy or ai_healthy:
            print("  ⚠️ PARTIAL: Some ETL components working")
            print("  🔧 Fix issues before Canvas integration")
            results["recommendation"] = "FIX_THEN_PROCEED"
        else:
            print("  ❌ CRITICAL: ETL pipeline has major issues")
            print("  🚫 DO NOT connect Canvas until fixed")
            results["recommendation"] = "STOP_FIX_ETL"
        
        # Save results
        filename = f"etl_validation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\n💾 Results saved: {filename}")
        
        return results["recommendation"] == "PROCEED_WITH_CANVAS"
        
    except Exception as e:
        print(f"❌ ETL validation failed: {e}")
        return False
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1) 