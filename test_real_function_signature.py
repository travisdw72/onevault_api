#!/usr/bin/env python3
"""
Test Real Function Signature
Based on actual function implementation code from the database
"""

import psycopg2
import json
import getpass
from datetime import datetime

def test_real_equine_function():
    """Test the real equine care reasoning function with proper parameters"""
    
    try:
        # Get password securely (following your project's pattern)
        print("🔐 One Vault Database Connection")
        print("=" * 40)
        password = getpass.getpass("Enter PostgreSQL password: ")
        
        # Database configuration
        db_config = {
            'host': 'localhost',
            'port': 5432,
            'database': 'one_vault',
            'user': 'postgres',
            'password': password
        }
        
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()
        
        print("✅ Connected to database successfully")
        print()
        
        print("🧪 Testing Real Equine Care Reasoning Function")
        print("=" * 60)
        
        # First, let's create a test session for our agent
        print("📝 Step 1: Creating test session...")
        
        # Create test tenant
        cursor.execute("""
            INSERT INTO auth.tenant_h (tenant_hk, tenant_bk, load_date, record_source)
            VALUES (
                decode('abcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234', 'hex'),
                'TEST_TENANT_EQUINE_2024',
                CURRENT_TIMESTAMP,
                'test_script'
            ) ON CONFLICT DO NOTHING;
        """)
        
        # Create test agent session
        test_session_token = "test_session_12345_equine"
        test_tenant_hk = "abcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234"
        
        cursor.execute("""
            INSERT INTO ai_agents.agent_session_h (session_hk, session_bk, tenant_hk, load_date, record_source)
            VALUES (
                decode('1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff', 'hex'),
                %s,
                decode(%s, 'hex'),
                CURRENT_TIMESTAMP,
                'test_script'
            ) ON CONFLICT DO NOTHING;
        """, (test_session_token, test_tenant_hk))
        
        cursor.execute("""
            INSERT INTO ai_agents.agent_session_s (
                session_hk, load_date, load_end_date, hash_diff,
                session_token, agent_hk, tenant_hk, session_status, 
                session_expires, record_source
            ) VALUES (
                decode('1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff', 'hex'),
                CURRENT_TIMESTAMP,
                NULL,
                decode('dddd1234567890dddd1234567890dddd1234567890dddd1234567890dddd1234', 'hex'),
                %s,
                decode('2222333344445555666677778888999900001111aaaabbbbccccddddeeeeffff', 'hex'),
                decode(%s, 'hex'),
                'active',
                CURRENT_TIMESTAMP + INTERVAL '1 hour',
                'test_script'
            ) ON CONFLICT (session_hk, load_date) DO NOTHING;
        """, (test_session_token, test_tenant_hk))
        
        # Create agent identity
        cursor.execute("""
            INSERT INTO ai_agents.agent_identity_h (agent_hk, agent_bk, tenant_hk, load_date, record_source)
            VALUES (
                decode('2222333344445555666677778888999900001111aaaabbbbccccddddeeeeffff', 'hex'),
                'EQUINE_CARE_AGENT_001',
                decode(%s, 'hex'),
                CURRENT_TIMESTAMP,
                'test_script'
            ) ON CONFLICT DO NOTHING;
        """, (test_tenant_hk,))
        
        cursor.execute("""
            INSERT INTO ai_agents.agent_identity_s (
                agent_hk, load_date, load_end_date, hash_diff,
                agent_name, knowledge_domain, is_active, record_source
            ) VALUES (
                decode('2222333344445555666677778888999900001111aaaabbbbccccddddeeeeffff', 'hex'),
                CURRENT_TIMESTAMP,
                NULL,
                decode('eeee1234567890eeee1234567890eeee1234567890eeee1234567890eeee1234', 'hex'),
                'Equine Care Specialist',
                'equine',
                true,
                'test_script'
            ) ON CONFLICT (agent_hk, load_date) DO NOTHING;
        """)
        
        # Create knowledge domain
        cursor.execute("""
            INSERT INTO ai_agents.knowledge_domain_h (domain_hk, domain_bk, tenant_hk, load_date, record_source)
            VALUES (
                decode('3333444455556666777788889999000011112222aaaabbbbccccddddeeeeffff', 'hex'),
                'equine_health_care',
                decode(%s, 'hex'),
                CURRENT_TIMESTAMP,
                'test_script'
            ) ON CONFLICT DO NOTHING;
        """, (test_tenant_hk,))
        
        conn.commit()
        print("✅ Test data created successfully")
        
        # Prepare test parameters based on the function signature
        print("\n📊 Step 2: Preparing function parameters...")
        
        # Parameter 1: p_session_token (TEXT)
        session_token = test_session_token
        
        # Parameter 2: p_horse_data (JSONB) - equine-specific data only
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
            },
            "environment": {
                "housing": "pasture_with_shelter",
                "feed_schedule": "twice_daily",
                "social_group": "small_herd"
            }
        }
        
        # Parameter 3: p_health_metrics (JSONB) - non-medical health indicators
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
            },
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
            ]
        }
        
        # Parameter 4: p_tenant_hk (BYTEA)
        tenant_hk_bytes = bytes.fromhex(test_tenant_hk)
        
        print(f"Session Token: {session_token}")
        print(f"Tenant HK: {test_tenant_hk}")
        print("Horse Data: [equine health and activity data]")
        print("Health Metrics: [non-medical behavioral indicators]")
        
        # Test the function
        print("\n🚀 Step 3: Calling ai_agents.equine_care_reasoning()...")
        
        cursor.execute("""
            SELECT ai_agents.equine_care_reasoning(%s, %s, %s, %s) as result;
        """, (
            session_token,
            json.dumps(horse_data),
            json.dumps(health_metrics),
            tenant_hk_bytes
        ))
        
        result = cursor.fetchone()[0]
        
        print("\n📈 Step 4: Function Results:")
        print("=" * 40)
        print(json.dumps(result, indent=2, default=str))
        
        # Analyze the result
        print("\n🔍 Step 5: Result Analysis:")
        print("=" * 30)
        
        if result.get('success'):
            print("✅ Function executed successfully!")
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

def test_function_parameters():
    """Test to verify the function accepts our parameter types"""
    
    try:
        # Get password securely
        password = getpass.getpass("Enter PostgreSQL password: ")
        
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            database='one_vault',
            user='postgres',
            password=password
        )
        cursor = conn.cursor()
        
        print("🔍 Testing Function Parameter Types...")
        
        # Get function information
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                p.pronargs as num_args,
                pg_get_function_arguments(p.oid) as arguments,
                pg_get_function_result(p.oid) as return_type
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'ai_agents' 
            AND p.proname = 'equine_care_reasoning';
        """)
        
        function_info = cursor.fetchone()
        if function_info:
            print(f"Function: {function_info[0]}")
            print(f"Arguments: {function_info[2]}")
            print(f"Return Type: {function_info[3]}")
        else:
            print("❌ Function not found!")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    print("🐴 Real Equine Care Function Test")
    print("=" * 50)
    print(f"Started at: {datetime.now()}")
    print()
    
    # First check function signature
    test_function_parameters()
    print()
    
    # Then test the actual function
    result = test_real_equine_function()
    
    print()
    print("=" * 50)
    print(f"Test completed at: {datetime.now()}")
    
    if result and result.get('success'):
        print("🎉 SUCCESS: Real function called successfully!")
        exit(0)
    else:
        print("❌ FAILED: Function test unsuccessful")
        exit(1) 