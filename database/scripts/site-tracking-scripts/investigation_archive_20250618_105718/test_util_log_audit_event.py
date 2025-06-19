#!/usr/bin/env python3
"""
Test util.log_audit_event Function
=================================
Test the discovered util.log_audit_event function to determine correct usage.
"""

import psycopg2
import getpass
import json
from datetime import datetime

def test_log_audit_event():
    """Test the util.log_audit_event function with correct parameters"""
    
    print("🧪 TESTING util.log_audit_event FUNCTION")
    print("=" * 50)
    
    # Get password securely
    password = getpass.getpass('Enter PostgreSQL password: ')
    
    try:
        # Connect to database
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            database='one_vault',
            user='postgres',
            password=password
        )
        cursor = conn.cursor()
        
        print("📋 Function signature:")
        print("util.log_audit_event(p_event_type text, p_resource_type text, p_resource_id text, p_actor text, p_event_details jsonb)")
        print()
        
        # Test different parameter combinations
        test_cases = [
            {
                'name': 'Site Tracking Page View',
                'params': [
                    'PAGE_VIEW',                                    # p_event_type
                    'SITE_TRACKING',                               # p_resource_type  
                    'page:/dashboard',                             # p_resource_id
                    'SYSTEM',                                      # p_actor
                    '{"url": "/dashboard", "user_agent": "test"}' # p_event_details
                ]
            },
            {
                'name': 'API Rate Limit Hit',
                'params': [
                    'RATE_LIMIT_EXCEEDED',                         # p_event_type
                    'API_SECURITY',                                # p_resource_type
                    'endpoint:/api/track',                         # p_resource_id
                    'API_GATEWAY',                                 # p_actor
                    '{"ip": "192.168.1.1", "limit": 100}'        # p_event_details
                ]
            },
            {
                'name': 'Security Violation',
                'params': [
                    'SUSPICIOUS_ACTIVITY',                        # p_event_type
                    'SECURITY',                                    # p_resource_type
                    'ip:192.168.1.100',                          # p_resource_id
                    'SECURITY_MONITOR',                           # p_actor
                    '{"reason": "too_many_requests", "count": 500}' # p_event_details
                ]
            }
        ]
        
        successful_tests = []
        
        for i, test_case in enumerate(test_cases, 1):
            print(f"🔬 Test {i}: {test_case['name']}")
            
            try:
                # Build the SQL with proper parameter substitution
                sql = """
                    SELECT util.log_audit_event(%s, %s, %s, %s, %s::jsonb)
                """
                
                cursor.execute(sql, test_case['params'])
                result = cursor.fetchone()
                
                print(f"   ✅ SUCCESS! Result: {result[0] if result else 'NULL'}")
                
                successful_tests.append({
                    'test_name': test_case['name'],
                    'parameters': test_case['params'],
                    'result': str(result[0]) if result else 'NULL',
                    'sql_pattern': f"SELECT util.log_audit_event('{test_case['params'][0]}', '{test_case['params'][1]}', '{test_case['params'][2]}', '{test_case['params'][3]}', '{test_case['params'][4]}'::jsonb)"
                })
                
                conn.commit()
                
            except Exception as e:
                print(f"   ❌ FAILED: {str(e)}")
                conn.rollback()
            
            print()
        
        if successful_tests:
            print("🎉 SUCCESS! Found working patterns for util.log_audit_event:")
            print("-" * 60)
            
            for test in successful_tests:
                print(f"✅ **{test['test_name']}**")
                print(f"   Pattern: {test['sql_pattern']}")
                print(f"   Result: {test['result']}")
                print()
            
            print("🔄 RECOMMENDED USAGE FOR SITE TRACKING:")
            print("-" * 50)
            
            # Generate usage examples for site tracking
            usage_examples = [
                {
                    'use_case': 'Log API tracking attempt',
                    'code': "SELECT util.log_audit_event('API_TRACKING_ATTEMPT', 'SITE_TRACKING', 'endpoint:/api/track', 'API_GATEWAY', '{\"ip\": \"192.168.1.1\", \"user_agent\": \"Mozilla/5.0\"}'::jsonb)"
                },
                {
                    'use_case': 'Log rate limit violation',
                    'code': "SELECT util.log_audit_event('RATE_LIMIT_EXCEEDED', 'API_SECURITY', 'ip:192.168.1.1', 'RATE_LIMITER', '{\"current_count\": 150, \"limit\": 100, \"window\": \"1 minute\"}'::jsonb)"
                },
                {
                    'use_case': 'Log security violation',
                    'code': "SELECT util.log_audit_event('SECURITY_VIOLATION', 'SECURITY', 'ip:suspicious_ip', 'SECURITY_MONITOR', '{\"violation_type\": \"bot_detected\", \"score\": 0.95}'::jsonb)"
                },
                {
                    'use_case': 'Log system error',
                    'code': "SELECT util.log_audit_event('SYSTEM_ERROR', 'SITE_TRACKING', 'function:api.track_event', 'SYSTEM', '{\"error\": \"Database connection failed\", \"retry_count\": 3}'::jsonb)"
                }
            ]
            
            for example in usage_examples:
                print(f"📝 **{example['use_case']}:**")
                print(f"   {example['code']}")
                print()
            
            # Save the successful patterns
            with open('util_log_audit_event_patterns.json', 'w') as f:
                json.dump({
                    'test_date': datetime.now().isoformat(),
                    'function_name': 'util.log_audit_event',
                    'successful_tests': successful_tests,
                    'usage_examples': usage_examples,
                    'recommendation': 'USE_THIS_FUNCTION'
                }, f, indent=2)
            
            print(f"📁 Usage patterns saved to: util_log_audit_event_patterns.json")
            
        else:
            print("❌ No successful tests - function may need different approach")
        
        cursor.close()
        conn.close()
        
        return successful_tests
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return []

if __name__ == "__main__":
    print("🎯 Testing the util.log_audit_event function you remembered!")
    print("   This will determine the correct usage pattern")
    print()
    
    results = test_log_audit_event()
    
    if results:
        print(f"\n🎉 CONCLUSION: util.log_audit_event WORKS!")
        print(f"   ✅ Found {len(results)} working patterns")
        print(f"   🔄 We should update the site tracking scripts to use this function")
        print(f"   💡 This replaces the need for manual audit tables!")
    else:
        print(f"\n🤔 Function exists but couldn't find working patterns")
        print(f"   📝 May need to examine the function definition more closely") 