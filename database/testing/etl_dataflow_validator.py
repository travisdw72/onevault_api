#!/usr/bin/env python3
"""
ETL DataFlow Validator - OneVault Pipeline Testing
Tests: API → Raw → Staging → Business → Reports
Focus: Data integrity and transformation validation
"""

import psycopg2
import json
import getpass
from datetime import datetime, timedelta
import uuid

def connect_to_database():
    """Connect to local test database"""
    print("🔍 ETL DataFlow Validator")
    print("Testing: API → Raw → Staging → Business pipeline")
    
    password = getpass.getpass("Enter database password for one_vault_site_testing: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost",
            port=5432,
            database="one_vault_site_testing", 
            user="postgres",
            password=password
        )
        print("✅ Database connected")
        return conn
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return None

def test_site_tracking_pipeline(conn):
    """Test site tracking ETL: API → Raw → Staging → Business"""
    print("\n📊 Testing Site Tracking ETL Pipeline...")
    
    cursor = conn.cursor()
    results = {"site_tracking": {}}
    
    try:
        # Get a test tenant
        cursor.execute("SELECT tenant_hk FROM auth.tenant_h LIMIT 1")
        tenant_result = cursor.fetchone()
        if not tenant_result:
            print("❌ No tenants found")
            return results
        
        tenant_hk = tenant_result[0]
        print(f"Using tenant: {tenant_hk.hex()[:8]}...")
        
        # Step 1: Check if site tracking API function works
        print("  Step 1: Testing site tracking API function...")
        
        test_event_id = str(uuid.uuid4())
        cursor.execute("""
            SELECT api.track_site_event(%s, %s, %s, %s, %s, %s, %s) as result
        """, (
            tenant_hk.hex(),
            'ETL_TEST_EVENT', 
            'https://test.com/etl',
            'ETL Test Agent',
            test_event_id,
            'ETL_TEST',
            datetime.now().isoformat()
        ))
        
        api_result = cursor.fetchone()
        if api_result and api_result[0]:
            print("    ✅ API function executed")
            results["site_tracking"]["api_call"] = "PASS"
            
            # Step 2: Check raw layer
            print("  Step 2: Checking raw layer...")
            cursor.execute("""
                SELECT COUNT(*) FROM raw.site_events 
                WHERE tenant_hk = %s AND event_type = 'ETL_TEST_EVENT'
                AND load_date >= %s
            """, (tenant_hk, datetime.now() - timedelta(minutes=5)))
            
            raw_count = cursor.fetchone()[0]
            if raw_count > 0:
                print(f"    ✅ Found {raw_count} records in raw layer")
                results["site_tracking"]["raw_layer"] = "PASS"
                
                # Wait a moment for processing
                import time
                time.sleep(3)
                
                # Step 3: Check staging layer
                print("  Step 3: Checking staging layer...")
                cursor.execute("""
                    SELECT COUNT(*) FROM staging.site_events_processed 
                    WHERE tenant_hk = %s AND event_type = 'ETL_TEST_EVENT'
                    AND load_date >= %s
                """, (tenant_hk, datetime.now() - timedelta(minutes=5)))
                
                staging_count = cursor.fetchone()[0]
                if staging_count > 0:
                    print(f"    ✅ Found {staging_count} records in staging layer")
                    results["site_tracking"]["staging_layer"] = "PASS"
                    
                    # Step 4: Check business layer
                    print("  Step 4: Checking business layer...")
                    cursor.execute("""
                        SELECT COUNT(*) 
                        FROM business.site_analytics_h sa
                        JOIN business.site_analytics_s sas ON sa.analytics_hk = sas.analytics_hk
                        WHERE sa.tenant_hk = %s AND sas.event_type = 'ETL_TEST_EVENT'
                        AND sas.load_date >= %s
                    """, (tenant_hk, datetime.now() - timedelta(minutes=5)))
                    
                    business_count = cursor.fetchone()[0]
                    if business_count > 0:
                        print(f"    ✅ Found {business_count} records in business layer")
                        results["site_tracking"]["business_layer"] = "PASS"
                    else:
                        print("    ❌ No records found in business layer")
                        results["site_tracking"]["business_layer"] = "FAIL"
                        
                        # Debug: Check what's in staging that should move to business
                        cursor.execute("""
                            SELECT event_type, session_id, load_date 
                            FROM staging.site_events_processed 
                            WHERE tenant_hk = %s AND event_type = 'ETL_TEST_EVENT'
                            ORDER BY load_date DESC LIMIT 3
                        """, (tenant_hk,))
                        staging_debug = cursor.fetchall()
                        print(f"    🔍 Debug - Staging records: {len(staging_debug)}")
                        for record in staging_debug:
                            print(f"      - {record[0]} | {record[1]} | {record[2]}")
                else:
                    print("    ❌ No records found in staging layer")
                    results["site_tracking"]["staging_layer"] = "FAIL"
                    results["site_tracking"]["business_layer"] = "SKIP"
                    
                    # Debug: Check raw layer details
                    cursor.execute("""
                        SELECT event_type, session_id, load_date, processing_status
                        FROM raw.site_events 
                        WHERE tenant_hk = %s AND event_type = 'ETL_TEST_EVENT'
                        ORDER BY load_date DESC LIMIT 3
                    """, (tenant_hk,))
                    raw_debug = cursor.fetchall()
                    print(f"    🔍 Debug - Raw records: {len(raw_debug)}")
                    for record in raw_debug:
                        print(f"      - {record[0]} | {record[1]} | {record[2]} | {record[3] if len(record) > 3 else 'N/A'}")
            else:
                print("    ❌ No records found in raw layer")
                results["site_tracking"]["raw_layer"] = "FAIL"
                results["site_tracking"]["staging_layer"] = "SKIP"
                results["site_tracking"]["business_layer"] = "SKIP"
        else:
            print("    ❌ API function failed")
            results["site_tracking"]["api_call"] = "FAIL"
            
    except Exception as e:
        print(f"    ❌ Site tracking test failed: {e}")
        results["site_tracking"]["error"] = str(e)
    
    return results

def test_ai_agent_pipeline(conn):
    """Test AI agent ETL pipeline"""
    print("\n🤖 Testing AI Agent ETL Pipeline...")
    
    cursor = conn.cursor()
    results = {"ai_agents": {}}
    
    try:
        # Get a test tenant
        cursor.execute("SELECT tenant_hk FROM auth.tenant_h LIMIT 1")
        tenant_result = cursor.fetchone()
        if not tenant_result:
            print("❌ No tenants found")
            return results
        
        tenant_hk = tenant_result[0]
        
        # Step 1: Test AI session creation
        print("  Step 1: Testing AI session creation...")
        cursor.execute("""
            SELECT api.ai_create_session(%s, %s, %s, %s) as result
        """, (
            tenant_hk.hex(),
            'business_intelligence_agent',
            'ETL Test Session',
            '{"test_mode": true}'
        ))
        
        session_result = cursor.fetchone()
        if session_result and session_result[0]:
            print("    ✅ AI session created")
            results["ai_agents"]["session_creation"] = "PASS"
            
            # Step 2: Test observation logging
            print("  Step 2: Testing AI observation logging...")
            cursor.execute("""
                SELECT api.ai_log_observation(%s, %s, %s, %s, %s) as result
            """, (
                tenant_hk.hex(),
                'ETL_TEST_ENTITY',
                'test_analysis',
                'ETL pipeline test observation',
                '{"confidence": 0.95}'
            ))
            
            obs_result = cursor.fetchone()
            if obs_result and obs_result[0]:
                print("    ✅ AI observation logged")
                results["ai_agents"]["observation_logging"] = "PASS"
                
                # Wait for processing
                import time
                time.sleep(3)
                
                # Step 3: Check monitoring layer
                print("  Step 3: Checking AI monitoring layer...")
                cursor.execute("""
                    SELECT COUNT(*) 
                    FROM ai_monitoring.ai_analysis_h aa
                    JOIN ai_monitoring.ai_analysis_results_s aar ON aa.analysis_hk = aar.analysis_hk
                    WHERE aar.analysis_description LIKE '%ETL pipeline test%'
                    AND aar.load_date >= %s
                """, (datetime.now() - timedelta(minutes=5),))
                
                monitor_count = cursor.fetchone()[0]
                if monitor_count > 0:
                    print(f"    ✅ Found {monitor_count} records in monitoring layer")
                    results["ai_agents"]["monitoring_layer"] = "PASS"
                else:
                    print("    ❌ No records found in monitoring layer")
                    results["ai_agents"]["monitoring_layer"] = "FAIL"
            else:
                print("    ❌ AI observation logging failed")
                results["ai_agents"]["observation_logging"] = "FAIL"
        else:
            print("    ❌ AI session creation failed")
            results["ai_agents"]["session_creation"] = "FAIL"
            
    except Exception as e:
        print(f"    ❌ AI agent test failed: {e}")
        results["ai_agents"]["error"] = str(e)
    
    return results

def check_etl_health(conn):
    """Check overall ETL pipeline health"""
    print("\n💊 Checking ETL Pipeline Health...")
    
    cursor = conn.cursor()
    health_results = {}
    
    try:
        # Check for stuck records in raw
        cursor.execute("""
            SELECT COUNT(*) as stuck_records
            FROM raw.site_events 
            WHERE load_date < %s 
            AND (processing_status IS NULL OR processing_status = 'PENDING')
        """, (datetime.now() - timedelta(hours=1),))
        
        stuck_result = cursor.fetchone()
        stuck_count = stuck_result[0] if stuck_result else 0
        
        if stuck_count > 0:
            print(f"    ⚠️ Found {stuck_count} stuck records in raw layer")
            health_results["stuck_records"] = stuck_count
        else:
            print("    ✅ No stuck records in raw layer")
            health_results["stuck_records"] = 0
        
        # Check processing times
        cursor.execute("""
            SELECT 
                AVG(EXTRACT(EPOCH FROM (staging.load_date - raw.load_date))/60) as avg_raw_to_staging_minutes
            FROM raw.site_events raw
            JOIN staging.site_events_processed staging ON raw.event_id = staging.source_event_id
            WHERE raw.load_date >= %s
        """, (datetime.now() - timedelta(hours=24),))
        
        timing_result = cursor.fetchone()
        avg_time = timing_result[0] if timing_result and timing_result[0] else None
        
        if avg_time:
            print(f"    📊 Average raw→staging processing: {avg_time:.2f} minutes")
            health_results["avg_processing_minutes"] = float(avg_time)
            
            if avg_time > 30:
                print("    ⚠️ Processing time is slow (>30 minutes)")
            else:
                print("    ✅ Processing time is acceptable")
        else:
            print("    ⚠️ No recent processing time data available")
        
        # Check tenant isolation
        cursor.execute("""
            SELECT tenant_hk, COUNT(*) as record_count
            FROM raw.site_events 
            WHERE load_date >= %s
            GROUP BY tenant_hk
            ORDER BY record_count DESC
            LIMIT 5
        """, (datetime.now() - timedelta(hours=24),))
        
        tenant_counts = cursor.fetchall()
        if tenant_counts:
            print("    📊 Recent activity by tenant:")
            for tenant_hk, count in tenant_counts:
                print(f"      - {tenant_hk.hex()[:8]}...: {count} events")
            health_results["tenant_activity"] = [
                {"tenant_hk": t[0].hex()[:8], "count": t[1]} for t in tenant_counts
            ]
        
    except Exception as e:
        print(f"    ❌ Health check failed: {e}")
        health_results["error"] = str(e)
    
    return health_results

def generate_recommendations(test_results):
    """Generate actionable recommendations"""
    print("\n🎯 ETL Pipeline Assessment & Recommendations:")
    
    recommendations = []
    issues_found = 0
    
    # Analyze site tracking
    site_tracking = test_results.get("site_tracking", {})
    if site_tracking.get("raw_layer") == "FAIL":
        recommendations.append("❌ CRITICAL: Site tracking API not writing to raw layer")
        recommendations.append("   → Check api.track_site_event() function")
        issues_found += 1
    elif site_tracking.get("staging_layer") == "FAIL":
        recommendations.append("❌ CRITICAL: Raw → Staging transformation broken")
        recommendations.append("   → Check ETL triggers/procedures for raw.site_events")
        issues_found += 1
    elif site_tracking.get("business_layer") == "FAIL":
        recommendations.append("❌ CRITICAL: Staging → Business transformation broken")
        recommendations.append("   → Check ETL procedures for staging → business layer")
        issues_found += 1
    
    # Analyze AI agents
    ai_agents = test_results.get("ai_agents", {})
    if ai_agents.get("monitoring_layer") == "FAIL":
        recommendations.append("⚠️ WARNING: AI monitoring layer not receiving data")
        recommendations.append("   → Check ai_monitoring schema ETL processes")
        issues_found += 1
    
    # Overall assessment
    if issues_found == 0:
        print("  ✅ EXCELLENT: ETL pipeline is healthy!")
        print("  🚀 Ready to proceed with Canvas API integration")
        recommendations.append("✅ ETL pipeline validated - proceed with Canvas integration")
    elif issues_found <= 2:
        print("  ⚠️ MODERATE: ETL pipeline has some issues")
        print("  🔧 Fix issues before Canvas integration")
        recommendations.append("🔧 Fix ETL issues before connecting Canvas")
    else:
        print("  ❌ CRITICAL: ETL pipeline has major problems")
        print("  🚫 Do NOT connect Canvas until pipeline is fixed")
        recommendations.append("🚫 STOP: Fix ETL pipeline before any API integration")
    
    for rec in recommendations:
        print(f"    {rec}")
    
    return recommendations

def main():
    """Main ETL validation function"""
    conn = connect_to_database()
    if not conn:
        return False
    
    try:
        # Run tests
        site_results = test_site_tracking_pipeline(conn)
        ai_results = test_ai_agent_pipeline(conn)
        health_results = check_etl_health(conn)
        
        # Combine results
        all_results = {
            "timestamp": datetime.now().isoformat(),
            "test_results": {**site_results, **ai_results},
            "health_check": health_results,
            "recommendations": []
        }
        
        # Generate recommendations
        recommendations = generate_recommendations(all_results["test_results"])
        all_results["recommendations"] = recommendations
        
        # Save results
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"etl_dataflow_validation_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(all_results, f, indent=2, default=str)
        
        print(f"\n💾 Results saved to: {filename}")
        
        # Return success if no critical issues
        critical_issues = any("CRITICAL" in rec for rec in recommendations)
        return not critical_issues
        
    except Exception as e:
        print(f"❌ ETL validation failed: {e}")
        return False
    finally:
        conn.close()

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1) 