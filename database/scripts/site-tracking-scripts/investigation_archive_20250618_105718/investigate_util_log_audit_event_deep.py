#!/usr/bin/env python3
"""
Deep Investigation of util.log_audit_event Function
==================================================
Understand the full capabilities and internal workings of util.log_audit_event
for comprehensive audit logging across the entire database.
"""

import psycopg2
import getpass
import json
from datetime import datetime

def investigate_util_log_audit_event():
    """Deep dive into util.log_audit_event function capabilities"""
    
    print("🔍 DEEP INVESTIGATION: util.log_audit_event")
    print("=" * 60)
    
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
        
        print("📋 GETTING COMPLETE FUNCTION DEFINITION:")
        print("-" * 50)
        
        # Get the complete function definition
        cursor.execute("""
            SELECT pg_get_functiondef(p.oid)
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'util' AND p.proname = 'log_audit_event'
        """)
        
        definition = cursor.fetchone()
        if definition:
            print("🔧 **Complete Function Definition:**")
            print(definition[0])
            print()
        
        print("🧪 UNDERSTANDING WHAT TABLES IT CREATES/USES:")
        print("-" * 50)
        
        # Look for audit tables that might be used by this function
        cursor.execute("""
            SELECT 
                schemaname,
                tablename,
                'Table for audit storage'
            FROM pg_tables 
            WHERE schemaname = 'audit'
            AND (tablename LIKE '%audit%' OR tablename LIKE '%event%')
            ORDER BY schemaname, tablename
        """)
        
        audit_tables = cursor.fetchall()
        
        print("📊 Audit tables that may be used by util.log_audit_event:")
        for schema, table, desc in audit_tables:
            print(f"   • {schema}.{table}")
            
            # Get table structure
            cursor.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (schema, table))
            
            columns = cursor.fetchall()
            print(f"     Columns: {len(columns)} total")
            for col_name, data_type, nullable in columns[:5]:  # Show first 5
                print(f"       - {col_name}: {data_type}")
            if len(columns) > 5:
                print(f"       ... and {len(columns) - 5} more columns")
            print()
        
        print("🎯 TESTING DIFFERENT USE CASES:")
        print("-" * 50)
        
        # Test various use cases to understand flexibility
        use_cases = [
            {
                'name': 'Basic Data Insert Audit',
                'event_type': 'DATA_INSERT',
                'resource_type': 'TABLE',
                'resource_id': 'business.customer_h',
                'actor': 'APPLICATION',
                'details': {'operation': 'INSERT', 'table': 'customer_h', 'records': 1}
            },
            {
                'name': 'User Authentication',
                'event_type': 'USER_LOGIN',
                'resource_type': 'AUTH',
                'resource_id': 'user:test@example.com',
                'actor': 'AUTH_SYSTEM',
                'details': {'ip': '192.168.1.1', 'user_agent': 'Mozilla/5.0', 'success': True}
            },
            {
                'name': 'API Access',
                'event_type': 'API_CALL',
                'resource_type': 'ENDPOINT',
                'resource_id': '/api/v1/customers',
                'actor': 'API_CLIENT',
                'details': {'method': 'GET', 'response_code': 200, 'duration_ms': 150}
            },
            {
                'name': 'Data Modification',
                'event_type': 'DATA_UPDATE',
                'resource_type': 'RECORD',
                'resource_id': 'customer:12345',
                'actor': 'USER:admin@company.com',
                'details': {'old_values': {'status': 'active'}, 'new_values': {'status': 'inactive'}}
            },
            {
                'name': 'Security Event',
                'event_type': 'SECURITY_ALERT',
                'resource_type': 'SECURITY',
                'resource_id': 'ip:192.168.1.100',
                'actor': 'SECURITY_MONITOR',
                'details': {'alert_type': 'brute_force', 'attempts': 10, 'blocked': True}
            },
            {
                'name': 'System Performance',
                'event_type': 'PERFORMANCE_METRIC',
                'resource_type': 'SYSTEM',
                'resource_id': 'database:one_vault',
                'actor': 'MONITOR',
                'details': {'cpu_usage': 75.2, 'memory_usage': 60.1, 'active_connections': 25}
            }
        ]
        
        successful_use_cases = []
        
        for use_case in use_cases:
            print(f"🧪 Testing: {use_case['name']}")
            
            try:
                cursor.execute("""
                    SELECT util.log_audit_event(%s, %s, %s, %s, %s::jsonb)
                """, [
                    use_case['event_type'],
                    use_case['resource_type'],
                    use_case['resource_id'],
                    use_case['actor'],
                    json.dumps(use_case['details'])
                ])
                
                result = cursor.fetchone()
                print(f"   ✅ SUCCESS: {result[0]['message'] if result and result[0] else 'No result'}")
                
                successful_use_cases.append(use_case)
                conn.commit()
                
            except Exception as e:
                print(f"   ❌ FAILED: {str(e)}")
                conn.rollback()
        
        print()
        print("🔍 ANALYZING AUDIT DATA CREATED:")
        print("-" * 50)
        
        # Check what audit data was actually created
        cursor.execute("""
            SELECT 
                COUNT(*) as total_audit_records,
                COUNT(DISTINCT substr(audit_event_bk, 1, position('_' in audit_event_bk) - 1)) as event_types,
                MIN(load_date) as earliest_audit,
                MAX(load_date) as latest_audit
            FROM audit.audit_event_s 
            WHERE load_date >= CURRENT_DATE
        """)
        
        audit_stats = cursor.fetchone()
        if audit_stats:
            print(f"📊 Audit Statistics (today):")
            print(f"   • Total audit records: {audit_stats[0]}")
            print(f"   • Unique event types: {audit_stats[1]}")
            print(f"   • Date range: {audit_stats[2]} to {audit_stats[3]}")
        
        # Get sample audit records
        cursor.execute("""
            SELECT 
                audit_event_bk,
                event_type,
                resource_type,
                resource_id,
                actor,
                event_details
            FROM audit.audit_event_s 
            WHERE load_date >= CURRENT_DATE
            ORDER BY load_date DESC
            LIMIT 5
        """)
        
        sample_records = cursor.fetchall()
        
        print(f"\n📋 Sample Audit Records Created:")
        for record in sample_records:
            print(f"   • {record[0]}")
            print(f"     Type: {record[1]} | Resource: {record[2]} | Actor: {record[4]}")
            print(f"     Details: {record[5]}")
            print()
        
        print("🎯 COMPREHENSIVE USAGE RECOMMENDATIONS:")
        print("-" * 50)
        
        recommendations = {
            'universal_patterns': [
                {
                    'use_case': 'Table Operations',
                    'pattern': "util.log_audit_event('DATA_INSERT|UPDATE|DELETE', 'TABLE', 'schema.table_name', 'USER:email', details)",
                    'example': "util.log_audit_event('DATA_INSERT', 'TABLE', 'business.customer_h', 'USER:admin@company.com', '{\"records\": 1, \"tenant\": \"tenant123\"}'::jsonb)"
                },
                {
                    'use_case': 'API Operations',
                    'pattern': "util.log_audit_event('API_CALL|API_ERROR', 'ENDPOINT', '/api/path', 'API_CLIENT', details)",
                    'example': "util.log_audit_event('API_CALL', 'ENDPOINT', '/api/v1/track', 'API_CLIENT', '{\"method\": \"POST\", \"status\": 200}'::jsonb)"
                },
                {
                    'use_case': 'Authentication Events',
                    'pattern': "util.log_audit_event('USER_LOGIN|LOGOUT|FAILED_LOGIN', 'AUTH', 'user:email', 'AUTH_SYSTEM', details)",
                    'example': "util.log_audit_event('USER_LOGIN', 'AUTH', 'user:admin@company.com', 'AUTH_SYSTEM', '{\"ip\": \"192.168.1.1\", \"success\": true}'::jsonb)"
                },
                {
                    'use_case': 'Security Events',
                    'pattern': "util.log_audit_event('SECURITY_*', 'SECURITY', 'resource_id', 'SECURITY_MONITOR', details)",
                    'example': "util.log_audit_event('SECURITY_VIOLATION', 'SECURITY', 'ip:192.168.1.100', 'SECURITY_MONITOR', '{\"violation\": \"rate_limit\"}'::jsonb)"
                },
                {
                    'use_case': 'Business Operations',
                    'pattern': "util.log_audit_event('BUSINESS_*', 'PROCESS', 'process_name', 'SYSTEM', details)",
                    'example': "util.log_audit_event('BUSINESS_TRANSACTION', 'PROCESS', 'payment_processing', 'SYSTEM', '{\"amount\": 100.00, \"status\": \"completed\"}'::jsonb)"
                }
            ],
            'integration_points': [
                'Function/Procedure entry/exit points',
                'Trigger functions (for automatic auditing)',
                'API gateway logging',
                'Error handling and exception logging',
                'Performance monitoring',
                'Compliance and regulatory reporting',
                'Data lineage tracking',
                'Change management and deployment tracking'
            ]
        }
        
        print("📝 **Universal Audit Patterns:**")
        for pattern in recommendations['universal_patterns']:
            print(f"\n🔧 **{pattern['use_case']}:**")
            print(f"   Pattern: {pattern['pattern']}")
            print(f"   Example: {pattern['example']}")
        
        print(f"\n🔗 **Integration Points for Database Development:**")
        for point in recommendations['integration_points']:
            print(f"   • {point}")
        
        # Save comprehensive analysis
        investigation_results = {
            'investigation_date': datetime.now().isoformat(),
            'function_definition': definition[0] if definition else None,
            'audit_tables_found': [f"{schema}.{table}" for schema, table, _ in audit_tables],
            'successful_use_cases': successful_use_cases,
            'audit_statistics': {
                'total_records': audit_stats[0] if audit_stats else 0,
                'event_types': audit_stats[1] if audit_stats else 0
            },
            'sample_records': [
                {
                    'audit_event_bk': record[0],
                    'event_type': record[1],
                    'resource_type': record[2],
                    'resource_id': record[3],
                    'actor': record[4],
                    'event_details': record[5]
                } for record in sample_records
            ],
            'usage_recommendations': recommendations
        }
        
        with open('util_log_audit_event_deep_analysis.json', 'w') as f:
            json.dump(investigation_results, f, indent=2, default=str)
        
        print(f"\n📁 Complete analysis saved to: util_log_audit_event_deep_analysis.json")
        
        cursor.close()
        conn.close()
        
        return investigation_results
        
    except Exception as e:
        print(f"❌ Investigation failed: {e}")
        return {'status': 'ERROR', 'error': str(e)}

if __name__ == "__main__":
    print("🎯 Deep diving into util.log_audit_event capabilities!")
    print("   This will show us how to use it for EVERYTHING in database development")
    print()
    
    results = investigate_util_log_audit_event()
    
    if results and 'successful_use_cases' in results:
        use_case_count = len(results['successful_use_cases'])
        print(f"\n🎉 INVESTIGATION COMPLETE!")
        print(f"   ✅ Tested {use_case_count} different use cases successfully")
        print(f"   🔧 Found comprehensive audit solution for entire database")
        print(f"   📋 Generated universal patterns for all development")
    else:
        print(f"\n❌ Investigation incomplete") 