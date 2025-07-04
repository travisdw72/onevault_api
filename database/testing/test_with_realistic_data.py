#!/usr/bin/env python3
"""
Test AI Observation with Realistic Horse and Camera Data
"""

import psycopg2
import getpass
import json

def main():
    print("🐎 TESTING WITH REALISTIC HORSE & CAMERA DATA")
    print("💡 This is what the system SHOULD be able to do!")
    print("=" * 50)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        # Get tenant
        cursor.execute("""
            SELECT th.tenant_bk
            FROM auth.tenant_h th
            JOIN auth.tenant_profile_s tps ON th.tenant_hk = tps.tenant_hk
            WHERE tps.tenant_name = '72 Industries LLC' 
            AND tps.load_end_date IS NULL
            LIMIT 1
        """)
        
        tenant_result = cursor.fetchone()
        if not tenant_result:
            print("❌ No tenant found")
            return
            
        tenant_bk = tenant_result[0]
        print(f"🏢 Using tenant: {tenant_bk}")
        
        # Check what entities and sensors exist
        print("\n🔍 Checking existing entities and sensors...")
        
        cursor.execute("""
            SELECT entity_bk, entity_type 
            FROM business.monitored_entity_h 
            WHERE tenant_hk = (
                SELECT tenant_hk FROM auth.tenant_h 
                WHERE tenant_bk = %s
            )
            LIMIT 5
        """, (tenant_bk,))
        
        entities = cursor.fetchall()
        if entities:
            print("📊 Found entities:")
            for entity_bk, entity_type in entities:
                print(f"   • {entity_bk} ({entity_type})")
        else:
            print("   ℹ️ No entities found - we'll create test ones")
        
        cursor.execute("""
            SELECT sensor_bk, sensor_type 
            FROM business.monitoring_sensor_h 
            WHERE tenant_hk = (
                SELECT tenant_hk FROM auth.tenant_h 
                WHERE tenant_bk = %s
            )
            LIMIT 5
        """, (tenant_bk,))
        
        sensors = cursor.fetchall()
        if sensors:
            print("📊 Found sensors:")
            for sensor_bk, sensor_type in sensors:
                print(f"   • {sensor_bk} ({sensor_type})")
        else:
            print("   ℹ️ No sensors found - we'll use test ones")
        
        # Test realistic AI observation scenarios
        test_scenarios = [
            {
                "name": "Horse Limping Detection",
                "data": {
                    "tenantId": tenant_bk,
                    "observationType": "horse_limping_detected",
                    "severityLevel": "medium",
                    "entityId": "horse_thunder_bolt_001",  # The horse
                    "sensorId": "paddock_camera_03",       # The camera
                    "confidenceScore": 0.89,
                    "observationData": {
                        "limping_leg": "front_left",
                        "severity_assessment": "moderate_limp",
                        "gait_analysis": {
                            "stride_length": "shortened_by_15_percent",
                            "weight_bearing": "reduced_on_affected_leg"
                        },
                        "environmental_factors": {
                            "weather": "dry",
                            "surface": "dirt_paddock",
                            "time_of_day": "morning_exercise"
                        }
                    },
                    "visualEvidence": {
                        "video_timestamp": "2025-01-07T10:30:45Z",
                        "frame_analysis": [
                            "frame_1: normal_gait",
                            "frame_2: slight_hesitation", 
                            "frame_3: clear_limp_visible"
                        ],
                        "confidence_heatmap": "paddock_camera_03_heatmap_20250107_103045.jpg"
                    },
                    "recommendedActions": [
                        "Schedule veterinary examination",
                        "Restrict exercise until cleared",
                        "Monitor for improvement over 48 hours",
                        "Check hoof for stones or injuries"
                    ]
                }
            },
            {
                "name": "Equipment Malfunction",
                "data": {
                    "tenantId": tenant_bk,
                    "observationType": "equipment_malfunction",
                    "severityLevel": "high",
                    "entityId": "water_trough_barn_2",      # The equipment
                    "sensorId": "water_level_sensor_b2",    # The sensor
                    "confidenceScore": 0.95,
                    "observationData": {
                        "malfunction_type": "water_flow_stopped",
                        "last_normal_reading": "2025-01-07T09:15:00Z",
                        "current_water_level": "critically_low",
                        "affected_animals": ["thunder_bolt", "lightning", "storm_cloud"]
                    },
                    "recommendedActions": [
                        "Immediate manual water supply",
                        "Check pump and valve systems", 
                        "Notify maintenance team",
                        "Monitor animal water access"
                    ]
                }
            }
        ]
        
        print(f"\n🧪 TESTING {len(test_scenarios)} REALISTIC SCENARIOS")
        print("-" * 50)
        
        for i, scenario in enumerate(test_scenarios, 1):
            print(f"\n{i}️⃣ {scenario['name']}")
            print(f"   🐎 Entity: {scenario['data']['entityId']}")
            print(f"   📷 Sensor: {scenario['data']['sensorId']}")
            print(f"   🎯 Observation: {scenario['data']['observationType']}")
            print(f"   ⚠️ Severity: {scenario['data']['severityLevel']}")
            print(f"   🔍 Confidence: {scenario['data']['confidenceScore']}")
            
            try:
                cursor.execute("""
                    SELECT api.ai_log_observation(%s::jsonb)
                """, (json.dumps(scenario['data']),))
                
                result = cursor.fetchone()[0]
                
                if result.get('success'):
                    print("   ✅ SUCCESS! AI observation logged with full context")
                    print(f"   📊 Observation ID: {result.get('data', {}).get('observationId', 'N/A')}")
                    if result.get('data', {}).get('alertCreated'):
                        print(f"   🚨 Alert Created: {result.get('data', {}).get('alertId', 'N/A')}")
                else:
                    error = result.get('debug_info', {}).get('error', result.get('message', 'Unknown error'))
                    print(f"   ❌ FAILED: {error}")
                    
                    if 'v_entity_hk' in str(error):
                        print("   🔧 Root Cause: PostgreSQL variable scope bug")
                        print("   💡 The function CAN'T handle entity/sensor references due to code bug")
                        print("   📊 Business Impact: We lose critical context about WHICH horse and WHICH camera!")
                        
            except Exception as e:
                print(f"   ❌ EXCEPTION: {e}")
        
        print(f"\n{'='*50}")
        print("🎯 WHAT WE'RE MISSING WITHOUT AI OBSERVATIONS")
        print(f"{'='*50}")
        
        print("\n🚨 Critical Business Data We CAN'T Log:")
        print("   • Which specific horse has an issue")
        print("   • Which camera detected the problem") 
        print("   • AI confidence in the detection")
        print("   • Detailed analysis data (gait, behavior, etc.)")
        print("   • Recommended actions for each incident")
        print("   • Visual evidence and timestamps")
        print("   • Environmental context")
        print("   • Automated alert generation")
        
        print("\n💔 Real-World Impact:")
        print("   • Veterinarian can't see AI analysis history")
        print("   • No tracking of recurring issues per horse")
        print("   • Can't correlate camera quality with detection accuracy")  
        print("   • Missing data for insurance claims")
        print("   • No AI performance improvement tracking")
        print("   • Can't build predictive health models")
        
        print("\n🔧 The Fix:")
        print("   • Move 2 PostgreSQL variables to main scope")
        print("   • 5-minute fix enables full AI logging")
        print("   • Unlock complete business intelligence")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 