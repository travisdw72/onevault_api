#!/usr/bin/env python3
"""
Test Corrected Function Signature
Based on actual schema investigation results
"""

import psycopg2
import json
import getpass
from datetime import datetime

def test_corrected_equine_function():
    """Test the real equine care reasoning function with corrected parameters"""
    
    try:
        # Get password securely
        print("🔐 One Vault Database Connection")
        print("=" * 40)
        password = getpass.getpass("Enter PostgreSQL password: ")
        
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            database='one_vault',
            user='postgres',
            password=password
        )
        cursor = conn.cursor()
        
        print("✅ Connected to database successfully")
        print()
        
        print("🧪 Testing Corrected Equine Care Reasoning Function")
        print("=" * 60)
        
        # Step 1: Create test data following real schema
        print("📝 Step 1: Creating test data with correct schema...")
        
        # Create test tenant
        test_tenant_hk = "abcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234"
        cursor.execute("""
            INSERT INTO auth.tenant_h (tenant_hk, tenant_bk, load_date, record_source)
            VALUES (
                decode(%s, 'hex'),
                'TEST_TENANT_EQUINE_2024',
                CURRENT_TIMESTAMP,
                'test_script'
            ) ON CONFLICT DO NOTHING;
        """, (test_tenant_hk,))
        
        # Create test user
        test_user_hk = "dddd4444567890dddd4444567890dddd4444567890dddd4444567890dddd4444"
        cursor.execute("""
            INSERT INTO auth.user_h (user_hk, user_bk, tenant_hk, load_date, record_source)
            VALUES (
                decode(%s, 'hex'),
                'test_user_equine_2024',
                decode(%s, 'hex'),
                CURRENT_TIMESTAMP,
                'test_script'
            ) ON CONFLICT DO NOTHING;
        """, (test_user_hk, test_tenant_hk))
        
        # Create test agent
        test_agent_hk = "2222333344445555666677778888999900001111aaaabbbbccccddddeeeeffff"
        cursor.execute("""
            INSERT INTO ai_agents.agent_h (agent_hk, agent_bk, tenant_hk, load_date, record_source)
            VALUES (
                decode(%s, 'hex'),
                'EQUINE_CARE_AGENT_001',
                decode(%s, 'hex'),
                CURRENT_TIMESTAMP,
                'test_script'
            ) ON CONFLICT DO NOTHING;
        """, (test_agent_hk, test_tenant_hk))
        
        # Create agent identity with correct columns
        cursor.execute("""
            INSERT INTO ai_agents.agent_identity_s (
                agent_hk, load_date, load_end_date, hash_diff,
                agent_name, agent_type, specialization, security_clearance, network_segment,
                max_session_duration, requires_mfa, certificate_required, knowledge_domain,
                allowed_data_types, forbidden_domains, model_version, reasoning_engine,
                confidence_threshold, is_active, certification_status, tenant_hk, record_source
            ) VALUES (
                decode(%s, 'hex'),
                CURRENT_TIMESTAMP,
                NULL,
                decode('eeee1234567890eeee1234567890eeee1234567890eeee1234567890eeee1234', 'hex'),
                'Equine Care Specialist',
                'specialist',
                'equine_health',
                'standard',
                'private',
                INTERVAL '2 hours',
                false,
                false,
                'equine',
                ARRAY['equine_health', 'behavioral_data'],
                ARRAY['medical', 'financial', 'manufacturing'],
                'v1.3',
                'equine_reasoning_engine',
                0.78,
                true,
                'active',
                decode(%s, 'hex'),
                'test_script'
            ) ON CONFLICT (agent_hk, load_date) DO NOTHING;
        """, (test_agent_hk, test_tenant_hk))
        
        # Create knowledge domain
        test_domain_hk = "3333444455556666777788889999000011112222aaaabbbbccccddddeeeeffff"
        cursor.execute("""
            INSERT INTO ai_agents.knowledge_domain_h (domain_hk, domain_bk, tenant_hk, load_date, record_source)
            VALUES (
                decode(%s, 'hex'),
                'equine_health_care',
                decode(%s, 'hex'),
                CURRENT_TIMESTAMP,
                'test_script'
            ) ON CONFLICT DO NOTHING;
        """, (test_domain_hk, test_tenant_hk))
        
        # Create agent session with correct schema
        test_session_token = "test_session_12345_equine_corrected"
        test_session_hk = "1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff"
        
        # Insert session hub
        cursor.execute("""
            INSERT INTO ai_agents.agent_session_h (session_hk, session_bk, tenant_hk, load_date, record_source)
            VALUES (
                decode(%s, 'hex'),
                %s,
                decode(%s, 'hex'),
                CURRENT_TIMESTAMP,
                'test_script'
            ) ON CONFLICT DO NOTHING;
        """, (test_session_hk, test_session_token, test_tenant_hk))
        
        # Insert session satellite with correct columns (no tenant_hk here)
        cursor.execute("""
            INSERT INTO ai_agents.agent_session_s (
                session_hk, load_date, load_end_date, hash_diff,
                agent_hk, requesting_user_hk, session_token, session_start, 
                session_expires, session_status, authentication_method,
                ip_address, mfa_verified, max_requests, max_data_access_mb, record_source
            ) VALUES (
                decode(%s, 'hex'),
                CURRENT_TIMESTAMP,
                NULL,
                decode('dddd1234567890dddd1234567890dddd1234567890dddd1234567890dddd1234', 'hex'),
                decode(%s, 'hex'),
                decode(%s, 'hex'),
                %s,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP + INTERVAL '1 hour',
                'active',
                'certificate',
                '127.0.0.1',
                true,
                100,
                10,
                'test_script'
            ) ON CONFLICT (session_hk, load_date) DO NOTHING;
        """, (test_session_hk, test_agent_hk, test_user_hk, test_session_token))
        
        conn.commit()
        print("✅ Test data created successfully with correct schema")
        
        # Step 2: Prepare function parameters (4 parameters!)
        print("\n📊 Step 2: Preparing corrected function parameters...")
        
        # Parameter 1: p_session_token (character varying)
        session_token = test_session_token
        
        # Parameter 2: p_horse_data (jsonb)
        horse_data = {
            "horse_id": "Thunder_Lightning_2024",
            "breed": "Arabian",
            "age": 8,
            "weight": 1050,
            "height": "15.2 hands",
            "physical_condition": {
                "coat_condition": "excellent",
                "muscle_tone": "good",
                "body_score": 6,
                "energy_level": "high"
            },
            "recent_activity": {
                "exercise_type": "trail_riding",
                "duration_minutes": 45,
                "intensity": "moderate",
                "performance": "excellent"
            }
        }
        
        # Parameter 3: p_health_metrics (jsonb)
        health_metrics = {
            "vitals": {
                "resting_heart_rate": 32,
                "breathing_rate": 12,
                "temperature": 99.5
            },
            "movement": {
                "gait_quality": "smooth",
                "stride_length": "normal",
                "balance": "excellent",
                "flexibility": "good"
            }
        }
        
        # Parameter 4: p_behavior_observations (jsonb) - NEW PARAMETER!
        behavior_observations = {
            "behavioral": {
                "alertness": "high",
                "appetite": "excellent",
                "social_interaction": "normal",
                "response_to_handling": "cooperative"
            },
            "observation_notes": [
                "Active and engaged during turnout",
                "Good response to voice commands",
                "No signs of discomfort during grooming"
            ],
            "environmental_response": {
                "weather_sensitivity": "low",
                "noise_tolerance": "high",
                "new_environment_adaptation": "quick"
            },
            "training_responses": {
                "learning_rate": "fast",
                "retention": "excellent",
                "willingness": "high"
            }
        }
        
        print(f"Session Token: {session_token}")
        print("Horse Data: [equine physical and activity data]")
        print("Health Metrics: [vital signs and movement data]")
        print("Behavior Observations: [behavioral patterns and responses]")
        
        # Step 3: Call the function with 4 parameters
        print("\n🚀 Step 3: Calling ai_agents.equine_care_reasoning() with 4 parameters...")
        
        cursor.execute("""
            SELECT ai_agents.equine_care_reasoning(%s, %s, %s, %s) as result;
        """, (
            session_token,
            json.dumps(horse_data),
            json.dumps(health_metrics),
            json.dumps(behavior_observations)
        ))
        
        result = cursor.fetchone()[0]
        
        print("\n📈 Step 4: Function Results:")
        print("=" * 40)
        print(json.dumps(result, indent=2, default=str))
        
        # Step 5: Analyze the result
        print("\n🔍 Step 5: Result Analysis:")
        print("=" * 30)
        
        if result.get('success'):
            print("🎉 ✅ Function executed successfully!")
            print(f"🤖 Agent ID: {result.get('agent_id', 'N/A')}")
            print(f"🧠 Reasoning ID: {result.get('reasoning_id', 'N/A')}")
            print(f"🐴 Domain: {result.get('domain', 'N/A')}")
            print(f"📊 Confidence: {result.get('confidence', 'N/A')}")
            
            assessment = result.get('assessment', {})
            if assessment:
                print("\n🏥 Health Assessment:")
                health_assessment = assessment.get('health_assessment', {})
                print(f"  Overall Score: {health_assessment.get('overall_score', 'N/A')}")
                print(f"  Lameness Detected: {health_assessment.get('lameness_detected', 'N/A')}")
                print(f"  Nutritional Status: {health_assessment.get('nutritional_status', 'N/A')}")
                print(f"  Behavioral Indicators: {health_assessment.get('behavioral_indicators', 'N/A')}")
                
                print("\n💡 Care Recommendations:")
                recommendations = assessment.get('care_recommendations', [])
                for i, rec in enumerate(recommendations, 1):
                    print(f"  {i}. {rec.get('action', 'N/A')} (Priority: {rec.get('priority', 'N/A')})")
                    print(f"     Reasoning: {rec.get('reasoning', 'N/A')}")
                    
                print("\n📋 Monitoring Plan:")
                monitoring = assessment.get('monitoring_plan', {})
                if monitoring:
                    print(f"  Frequency: {monitoring.get('frequency', 'N/A')}")
                    print(f"  Metrics to Track: {monitoring.get('metrics_to_track', 'N/A')}")
        else:
            print("❌ Function execution failed!")
            print(f"Error: {result.get('error', 'Unknown error')}")
            if result.get('security_violation'):
                print("🚨 Security violation detected!")
        
        return result
        
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        return None
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return None
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    print("🐴 Corrected Equine Care Function Test")
    print("=" * 50)
    print(f"Started at: {datetime.now()}")
    print()
    
    result = test_corrected_equine_function()
    
    print()
    print("=" * 50)
    print(f"Test completed at: {datetime.now()}")
    
    if result and result.get('success'):
        print("🎉 SUCCESS: Real AI function called successfully!")
        print("🚀 Your production AI agents are working!")
        exit(0)
    else:
        print("❌ FAILED: Function test unsuccessful")
        exit(1) 