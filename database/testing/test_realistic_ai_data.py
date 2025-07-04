#!/usr/bin/env python3
"""
Test AI Observation with Realistic Horse and Camera Data - SIMPLIFIED
"""

import psycopg2
import getpass
import json

def main():
    print("🐎 REALISTIC AI OBSERVATION TEST")
    print("💡 Showing what we SHOULD be able to log but CAN'T!")
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
        
        # Test REAL business scenarios that should work
        realistic_scenarios = [
            {
                "name": "🐎 Horse Limping Detection",
                "business_value": "Catch horse injuries early, prevent serious damage",
                "data": {
                    "tenantId": tenant_bk,
                    "observationType": "horse_limping_detected",
                    "severityLevel": "medium",
                    "entityId": "horse_thunder_bolt_001",
                    "sensorId": "paddock_camera_03", 
                    "confidenceScore": 0.89,
                    "observationData": {
                        "limping_leg": "front_left",
                        "gait_analysis": "stride_shortened_15_percent",
                        "timestamp": "2025-01-07T10:30:45Z"
                    },
                    "recommendedActions": [
                        "Schedule veterinary examination",
                        "Restrict exercise until cleared"
                    ]
                }
            },
            {
                "name": "🚰 Water System Malfunction",
                "business_value": "Prevent dehydration, ensure animal welfare",
                "data": {
                    "tenantId": tenant_bk,
                    "observationType": "equipment_malfunction",
                    "severityLevel": "high",
                    "entityId": "water_trough_barn_2",
                    "sensorId": "water_level_sensor_b2",
                    "confidenceScore": 0.95,
                    "observationData": {
                        "malfunction_type": "water_flow_stopped",
                        "water_level": "critically_low",
                        "affected_animals": 5
                    },
                    "recommendedActions": [
                        "Immediate manual water supply",
                        "Check pump system"
                    ]
                }
            },
            {
                "name": "🔒 Security Breach",
                "business_value": "Protect valuable animals and equipment",
                "data": {
                    "tenantId": tenant_bk,
                    "observationType": "security_breach",
                    "severityLevel": "critical",
                    "entityId": "barn_entrance_main",
                    "sensorId": "security_camera_01",
                    "confidenceScore": 0.92,
                    "observationData": {
                        "breach_type": "unauthorized_entry",
                        "time_detected": "2025-01-07T02:15:33Z",
                        "person_count": 2
                    },
                    "recommendedActions": [
                        "Alert security immediately",
                        "Contact law enforcement",
                        "Secure all animals"
                    ]
                }
            }
        ]
        
        print(f"\n🧪 TESTING {len(realistic_scenarios)} REAL BUSINESS SCENARIOS")
        print("=" * 50)
        
        all_failed = True
        
        for i, scenario in enumerate(realistic_scenarios, 1):
            print(f"\n{i}️⃣ {scenario['name']}")
            print(f"   💰 Value: {scenario['business_value']}")
            print(f"   🐎 Entity: {scenario['data']['entityId']}")
            print(f"   📷 Sensor: {scenario['data']['sensorId']}")
            print(f"   🎯 Type: {scenario['data']['observationType']}")
            print(f"   ⚠️ Severity: {scenario['data']['severityLevel']}")
            print(f"   🔍 Confidence: {scenario['data']['confidenceScore']}")
            
            try:
                cursor.execute("""
                    SELECT api.ai_log_observation(%s::jsonb)
                """, (json.dumps(scenario['data']),))
                
                result = cursor.fetchone()[0]
                
                if result.get('success'):
                    print("   ✅ SUCCESS! Full business context logged")
                    all_failed = False
                    if result.get('data', {}).get('alertCreated'):
                        print(f"   🚨 ALERT: {result.get('data', {}).get('alertId')}")
                else:
                    error = result.get('debug_info', {}).get('error', result.get('message', 'Unknown'))
                    print(f"   ❌ FAILED: {error}")
                    
                    if 'v_entity_hk' in str(error):
                        print("   🔧 ROOT CAUSE: PostgreSQL scope bug prevents ALL entity tracking")
                        
            except Exception as e:
                print(f"   ❌ EXCEPTION: {e}")
        
        if all_failed:
            print(f"\n{'='*60}")
            print("🚨 CRITICAL BUSINESS IMPACT ANALYSIS")
            print(f"{'='*60}")
            
            print("\n❌ WHAT WE'RE LOSING:")
            print("   • 🐎 Can't track which horse has issues")
            print("   • 📷 Can't identify which camera detected problems")  
            print("   • 🎯 Can't log AI confidence scores")
            print("   • 📊 Can't store detailed analysis data")
            print("   • 🚨 Can't trigger automatic alerts")
            print("   • 📝 Can't log recommended actions")
            print("   • 🔗 Can't link observations to specific assets")
            
            print("\n💔 REAL-WORLD CONSEQUENCES:")
            print("   • Vet visits without AI context")
            print("   • No historical health tracking per horse")
            print("   • Manual monitoring instead of automation")
            print("   • Missing insurance documentation")
            print("   • Can't improve AI detection accuracy")
            print("   • No predictive health analytics")
            
            print("\n🎯 THE BUSINESS CASE FOR FIXING:")
            
            print("\n   🐎 HORSE HEALTH:")
            print("      • Early injury detection = faster recovery")
            print("      • Individual horse health history")
            print("      • Veterinary cost reduction")
            
            print("\n   📊 OPERATIONS:")
            print("      • Equipment failure prediction")
            print("      • Security incident documentation")
            print("      • Insurance claim evidence")
            
            print("\n   🤖 AI IMPROVEMENT:")
            print("      • Track detection accuracy by camera")
            print("      • Improve model confidence over time")
            print("      • Reduce false positives")
            
            print(f"\n{'='*50}")
            print("🔧 THE SIMPLE FIX")
            print(f"{'='*50}")
            
            print("\n   📝 What's needed:")
            print("      1. Move 2 variables to main PostgreSQL scope")
            print("      2. Takes ~5 minutes to implement")
            print("      3. Unlocks FULL business intelligence")
            
            print("\n   ⚡ Result after fix:")
            print("      • 4/4 functions working")
            print("      • Complete AI observation logging")
            print("      • Rich entity and sensor context")
            print("      • Automatic alert generation")
            print("      • Full business value realized")
            
            print(f"\n💰 ROI: Fix 5-minute bug → Unlock enterprise AI platform")
            
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Test failed: {e}")

if __name__ == "__main__":
    main() 