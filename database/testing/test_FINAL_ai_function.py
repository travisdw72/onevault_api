#!/usr/bin/env python3
"""
FINAL TEST: Verify AI Observation Function is 100% Working
Tests both scope bug fix AND audit parameter order fix
"""

import psycopg2
import getpass
import json

def main():
    print("🚀 FINAL AI OBSERVATION TEST")
    print("🔧 Testing BOTH fixes: scope bug + audit parameter order")
    print("🐎 Should now work with horse and camera context!")
    print("=" * 60)
    
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
            LIMIT 1
        """)
        tenant_result = cursor.fetchone()
        if not tenant_result:
            print("❌ No tenant found!")
            return
        
        tenant_id = tenant_result[0]
        print(f"✅ Found tenant: {tenant_id}")
        
        # Realistic horse health observation
        ai_request = {
            "tenantId": tenant_id,
            "observationType": "health_concern", 
            "severityLevel": "medium",
            "confidenceScore": 0.87,
            "entityId": "horse_thunder_bolt_001",
            "sensorId": "camera_north_pasture_001",
            "observationData": {
                "symptoms": ["limping", "favoring_left_front_leg"],
                "duration": "observed_for_15_minutes",
                "location": "north_pasture",
                "weather_conditions": "clear_dry"
            },
            "visualEvidence": {
                "image_url": "https://storage.example.com/obs/horse_limp_20250101_143052.jpg",
                "confidence_map": [0.92, 0.85, 0.78],
                "detection_boxes": [[120, 85, 45, 60]]
            },
            "recommendedActions": [
                "Schedule veterinary examination within 24 hours",
                "Restrict exercise until evaluation",
                "Monitor for worsening symptoms"
            ],
            "ip_address": "192.168.1.101",
            "user_agent": "OneVault_AI_Vision_System_v2.1"
        }
        
        print("\n📊 Test Data:")
        print(f"   🐎 Horse: {ai_request['entityId']}")
        print(f"   📷 Camera: {ai_request['sensorId']}")
        print(f"   🔍 Observation: {ai_request['observationType']}")
        print(f"   ⚠️ Severity: {ai_request['severityLevel']}")
        print(f"   📈 Confidence: {ai_request['confidenceScore']}")
        
        # Call the fixed AI observation function
        print("\n🔧 Calling FIXED api.ai_log_observation function...")
        cursor.execute("""
            SELECT api.ai_log_observation(%s::jsonb)
        """, (json.dumps(ai_request),))
        
        result = cursor.fetchone()[0]
        print(f"✅ Function executed successfully!")
        print(f"📊 Result: {json.dumps(result, indent=2)}")
        
        if result.get('success'):
            print("\n🎉 SUCCESS: AI Observation logged successfully!")
            
            # Check if data was actually inserted
            observation_id = result['data']['observationId']
            
            # Check observation details
            cursor.execute("""
                SELECT aod.observation_type, aod.severity_level, aod.confidence_score,
                       aod.entity_hk IS NOT NULL as has_entity,
                       aod.sensor_hk IS NOT NULL as has_sensor,
                       aod.observation_title, aod.recommended_actions
                FROM business.ai_observation_h aoh
                JOIN business.ai_observation_details_s aod ON aoh.ai_observation_hk = aod.ai_observation_hk
                WHERE aoh.ai_observation_bk = %s
                AND aod.load_end_date IS NULL
            """, (observation_id,))
            
            obs_data = cursor.fetchone()
            if obs_data:
                print(f"\n📋 OBSERVATION VERIFIED IN DATABASE:")
                print(f"   🔍 Type: {obs_data[0]}")
                print(f"   ⚠️ Severity: {obs_data[1]}")
                print(f"   📈 Confidence: {obs_data[2]}")
                print(f"   🐎 Has Entity Context: {'✅' if obs_data[3] else '❌'}")
                print(f"   📷 Has Sensor Context: {'✅' if obs_data[4] else '❌'}")
                print(f"   📝 Title: {obs_data[5]}")
                print(f"   💡 Actions: {len(obs_data[6])} recommendations")
            
            # Check audit logging
            cursor.execute("""
                SELECT COUNT(*) 
                FROM audit.security_event_s 
                WHERE event_type = 'AI_OBSERVATION_LOGGED'
                AND load_date >= NOW() - INTERVAL '1 minute'
            """)
            
            audit_count = cursor.fetchone()[0]
            print(f"\n🔒 AUDIT LOGGING: {'✅ Working' if audit_count > 0 else '❌ Failed'} ({audit_count} recent events)")
            
            if result['data'].get('alertCreated'):
                print(f"\n🚨 ALERT CREATED: {result['data']['alertId']}")
                print(f"   📧 Escalation Required: {'Yes' if result['data']['escalationRequired'] else 'No'}")
            else:
                print(f"\n📢 Alert: Not created (severity/confidence below threshold)")
                
        else:
            print(f"\n❌ FAILED: {result.get('message', 'Unknown error')}")
            if 'debug_info' in result:
                print(f"🐛 Debug: {result['debug_info']}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    main() 