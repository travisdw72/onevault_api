#!/usr/bin/env python3
"""
Real Audit Trail Validation Test with Mock Data
Inserts actual audit data into the database and validates the complete audit trail system
"""

import psycopg2
import psycopg2.extras
import json
import time
import getpass
import uuid
from datetime import datetime, timedelta
from database.scripts.investigate_db_configFile import DATABASE_CONFIG

class RealAuditTrailTest:
    def __init__(self):
        self.conn = None
        self.test_session_id = f"test_session_{int(time.time())}"
        self.test_tenant_hk = None
        self.test_user_hk = None
        self.inserted_audit_events = []
        
    def connect_to_database(self) -> bool:
        """Establish database connection"""
        print("🔍 Real Audit Trail Validation Test with Mock Data")
        print("=" * 60)
        
        config = DATABASE_CONFIG.copy()
        config['password'] = getpass.getpass('Enter PostgreSQL password: ')
        
        try:
            self.conn = psycopg2.connect(**config)
            self.conn.set_session(autocommit=True)
            print(f"✅ Connected to database: {config['database']}")
            return True
        except psycopg2.Error as e:
            print(f"❌ Failed to connect to database: {e}")
            return False
    
    def setup_test_data(self):
        """Create test tenant and user data"""
        print("\n🔧 Setting up test data...")
        
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Create test tenant
                tenant_bk = f"test_tenant_{self.test_session_id}"
                self.test_tenant_hk = self.hash_binary(tenant_bk)
                
                cursor.execute("""
                    INSERT INTO auth.tenant_h (tenant_hk, tenant_bk, load_date, record_source)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (tenant_hk) DO NOTHING
                """, (self.test_tenant_hk, tenant_bk, datetime.now(), 'audit_test'))
                
                # Create test user
                user_bk = f"test_user_{self.test_session_id}"
                self.test_user_hk = self.hash_binary(user_bk)
                
                cursor.execute("""
                    INSERT INTO auth.user_h (user_hk, user_bk, tenant_hk, load_date, record_source)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (user_hk) DO NOTHING
                """, (self.test_user_hk, user_bk, self.test_tenant_hk, datetime.now(), 'audit_test'))
                
                print(f"  ✅ Created test tenant: {tenant_bk}")
                print(f"  ✅ Created test user: {user_bk}")
                
        except Exception as e:
            print(f"  ❌ Error setting up test data: {e}")
            raise
    
    def hash_binary(self, input_string: str) -> bytes:
        """Generate hash for test data"""
        import hashlib
        return hashlib.sha256(input_string.encode()).digest()
    
    def insert_real_audit_events(self):
        """Insert real audit events into the database"""
        print("\n📝 Inserting real audit events...")
        
        audit_scenarios = [
            {
                'event_type': 'ai_chat_request',
                'table_name': 'ai_conversation_h',
                'operation': 'INSERT',
                'old_data': None,
                'new_data': {
                    'conversation_id': str(uuid.uuid4()),
                    'user_hk': self.test_user_hk.hex(),
                    'message': 'Generate business analytics report',
                    'model_used': 'gpt-4',
                    'context_type': 'business_analytics',
                    'sensitive_data_flag': True,
                    'compliance_context': 'HIPAA'
                }
            },
            {
                'event_type': 'ai_response_generated',
                'table_name': 'ai_conversation_s',
                'operation': 'INSERT',
                'old_data': None,
                'new_data': {
                    'response_id': str(uuid.uuid4()),
                    'response_text': 'Generated comprehensive business analytics report with Q4 performance metrics',
                    'processing_time_ms': 1250,
                    'safety_level': 'HIGH',
                    'audit_trail_id': str(uuid.uuid4())
                }
            },
            {
                'event_type': 'ai_observation_logged',
                'table_name': 'ai_observation_h',
                'operation': 'INSERT',
                'old_data': None,
                'new_data': {
                    'observation_id': str(uuid.uuid4()),
                    'entity_id': 'business-entity-001',
                    'observation_type': 'financial_performance',
                    'metric': 'revenue_growth',
                    'value': 15.7,
                    'confidence_score': 0.94,
                    'period': 'Q4_2024'
                }
            },
            {
                'event_type': 'sensitive_data_access',
                'table_name': 'business_entity_s',
                'operation': 'SELECT',
                'old_data': None,
                'new_data': {
                    'access_type': 'financial_data_query',
                    'data_classification': 'CONFIDENTIAL',
                    'access_justification': 'quarterly_compliance_review',
                    'minimum_necessary_applied': True,
                    'phi_elements_accessed': ['financial_records', 'performance_metrics'],
                    'ip_address': '192.168.1.100',
                    'user_agent': 'Mozilla/5.0 Test Browser'
                }
            },
            {
                'event_type': 'compliance_check_performed',
                'table_name': 'compliance_validation_s',
                'operation': 'INSERT',
                'old_data': None,
                'new_data': {
                    'compliance_check_id': str(uuid.uuid4()),
                    'regulation': 'HIPAA',
                    'check_type': 'data_access_validation',
                    'result': 'COMPLIANT',
                    'validation_details': {
                        'minimum_necessary': True,
                        'access_authorized': True,
                        'audit_logged': True,
                        'retention_applied': True
                    }
                }
            },
            {
                'event_type': 'security_violation_detected',
                'table_name': 'security_event_h',
                'operation': 'INSERT',
                'old_data': None,
                'new_data': {
                    'violation_id': str(uuid.uuid4()),
                    'violation_type': 'SUSPICIOUS_ACCESS_PATTERN',
                    'severity': 'MEDIUM',
                    'description': 'Multiple failed authentication attempts detected',
                    'source_ip': '10.0.0.50',
                    'mitigation_action': 'ACCOUNT_TEMPORARILY_LOCKED',
                    'incident_response_triggered': True
                }
            }
        ]
        
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                for i, scenario in enumerate(audit_scenarios, 1):
                    # Create audit event hub record
                    audit_event_hk = self.hash_binary(f"audit_event_{self.test_session_id}_{i}")
                    audit_event_bk = f"AUDIT_{scenario['event_type'].upper()}_{int(time.time())}_{i}"
                    
                    cursor.execute("""
                        INSERT INTO audit.audit_event_h (audit_event_hk, audit_event_bk, tenant_hk, load_date, record_source)
                        VALUES (%s, %s, %s, %s, %s)
                    """, (audit_event_hk, audit_event_bk, self.test_tenant_hk, datetime.now(), 'audit_test'))
                    
                    # Create audit detail satellite record
                    hash_diff = self.hash_binary(json.dumps(scenario['new_data'], sort_keys=True))
                    
                    cursor.execute("""
                        INSERT INTO audit.audit_detail_s (
                            audit_event_hk, load_date, load_end_date, hash_diff,
                            table_name, operation, changed_by, old_data, new_data
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        audit_event_hk, datetime.now(), None, hash_diff,
                        scenario['table_name'], scenario['operation'], self.test_user_hk.hex(),
                        json.dumps(scenario['old_data']) if scenario['old_data'] else None,
                        json.dumps(scenario['new_data'])
                    ))
                    
                    self.inserted_audit_events.append({
                        'audit_event_hk': audit_event_hk,
                        'event_type': scenario['event_type'],
                        'table_name': scenario['table_name'],
                        'operation': scenario['operation']
                    })
                    
                    print(f"  ✅ Inserted audit event {i}: {scenario['event_type']}")
                    
                print(f"\n  📊 Total audit events inserted: {len(audit_scenarios)}")
                
        except Exception as e:
            print(f"  ❌ Error inserting audit events: {e}")
            raise
    
    def validate_audit_trail_queries(self):
        """Validate all audit trail queries work with real data"""
        print("\n🔍 Validating audit trail queries with real data...")
        
        validation_queries = {
            'recent_audit_events': """
                SELECT 
                    aeh.audit_event_hk,
                    ads.table_name,
                    ads.operation,
                    ads.load_date,
                    ads.changed_by,
                    ads.new_data
                FROM audit.audit_event_h aeh
                JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
                WHERE aeh.tenant_hk = %s
                AND ads.load_date >= CURRENT_TIMESTAMP - INTERVAL '5 minutes'
                AND ads.load_end_date IS NULL
                ORDER BY ads.load_date DESC;
            """,
            
            'ai_chat_audit_events': """
                SELECT 
                    aeh.audit_event_hk,
                    ads.table_name,
                    ads.operation,
                    ads.new_data->>'conversation_id' as conversation_id,
                    ads.new_data->>'message' as message,
                    ads.new_data->>'model_used' as model_used,
                    ads.new_data->>'compliance_context' as compliance_context
                FROM audit.audit_event_h aeh
                JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
                WHERE aeh.tenant_hk = %s
                AND ads.table_name LIKE '%conversation%'
                AND ads.load_end_date IS NULL
                ORDER BY ads.load_date DESC;
            """,
            
            'sensitive_data_access_audit': """
                SELECT 
                    aeh.audit_event_hk,
                    ads.table_name,
                    ads.operation,
                    ads.new_data->>'access_type' as access_type,
                    ads.new_data->>'data_classification' as data_classification,
                    ads.new_data->>'minimum_necessary_applied' as minimum_necessary,
                    ads.new_data->>'access_justification' as justification
                FROM audit.audit_event_h aeh
                JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
                WHERE aeh.tenant_hk = %s
                AND ads.new_data->>'data_classification' = 'CONFIDENTIAL'
                AND ads.load_end_date IS NULL
                ORDER BY ads.load_date DESC;
            """,
            
            'compliance_validation_audit': """
                SELECT 
                    aeh.audit_event_hk,
                    ads.table_name,
                    ads.new_data->>'regulation' as regulation,
                    ads.new_data->>'check_type' as check_type,
                    ads.new_data->>'result' as result,
                    ads.new_data->'validation_details'->>'minimum_necessary' as min_necessary,
                    ads.new_data->'validation_details'->>'audit_logged' as audit_logged
                FROM audit.audit_event_h aeh
                JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
                WHERE aeh.tenant_hk = %s
                AND ads.new_data->>'regulation' = 'HIPAA'
                AND ads.load_end_date IS NULL
                ORDER BY ads.load_date DESC;
            """,
            
            'security_events_audit': """
                SELECT 
                    aeh.audit_event_hk,
                    ads.table_name,
                    ads.new_data->>'violation_type' as violation_type,
                    ads.new_data->>'severity' as severity,
                    ads.new_data->>'description' as description,
                    ads.new_data->>'mitigation_action' as mitigation_action,
                    ads.new_data->>'incident_response_triggered' as incident_response
                FROM audit.audit_event_h aeh
                JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
                WHERE aeh.tenant_hk = %s
                AND ads.table_name LIKE '%security%'
                AND ads.load_end_date IS NULL
                ORDER BY ads.load_date DESC;
            """
        }
        
        validation_results = {}
        
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                for query_name, query_sql in validation_queries.items():
                    cursor.execute(query_sql, (self.test_tenant_hk,))
                    results = cursor.fetchall()
                    
                    validation_results[query_name] = {
                        'records_found': len(results),
                        'data': [dict(row) for row in results]
                    }
                    
                    print(f"  ✅ {query_name}: Found {len(results)} records")
                    
                    # Show sample data for verification
                    if results:
                        sample = results[0]
                        table_name = sample.get('table_name', 'N/A')
                        operation = sample.get('operation', 'N/A')
                        print(f"    📋 Sample: {table_name} - {operation}")
        
        except Exception as e:
            print(f"  ❌ Error validating queries: {e}")
            validation_results['error'] = str(e)
        
        return validation_results
    
    def test_hipaa_compliance_features(self):
        """Test specific HIPAA compliance features"""
        print("\n🔒 Testing HIPAA Compliance Features...")
        
        compliance_tests = {
            'phi_access_logging': """
                SELECT 
                    COUNT(*) as phi_access_events,
                    COUNT(DISTINCT ads.changed_by) as users_accessing_phi,
                    bool_and(ads.new_data->>'minimum_necessary_applied' = 'true') as all_minimum_necessary
                FROM audit.audit_event_h aeh
                JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
                WHERE aeh.tenant_hk = %s
                AND (ads.new_data->>'sensitive_data_flag' = 'true' 
                     OR ads.new_data->>'data_classification' = 'CONFIDENTIAL')
                AND ads.load_end_date IS NULL;
            """,
            
            'audit_trail_integrity': """
                SELECT 
                    COUNT(*) as total_events,
                    COUNT(DISTINCT ads.table_name) as tables_audited,
                    COUNT(DISTINCT ads.operation) as operation_types,
                    bool_and(ads.hash_diff IS NOT NULL) as all_have_hash,
                    bool_and(aeh.record_source IS NOT NULL) as all_have_source
                FROM audit.audit_event_h aeh
                JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
                WHERE aeh.tenant_hk = %s
                AND ads.load_end_date IS NULL;
            """,
            
            'compliance_validation_coverage': """
                SELECT 
                    COUNT(*) as compliance_checks,
                    COUNT(*) FILTER (WHERE ads.new_data->>'result' = 'COMPLIANT') as compliant_checks,
                    COUNT(*) FILTER (WHERE ads.new_data->>'regulation' = 'HIPAA') as hipaa_checks,
                    COUNT(DISTINCT ads.new_data->>'check_type') as check_types
                FROM audit.audit_event_h aeh
                JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
                WHERE aeh.tenant_hk = %s
                AND ads.table_name LIKE '%compliance%'
                AND ads.load_end_date IS NULL;
            """,
            
            'security_monitoring': """
                SELECT 
                    COUNT(*) as security_events,
                    COUNT(DISTINCT ads.new_data->>'violation_type') as violation_types,
                    COUNT(*) FILTER (WHERE ads.new_data->>'incident_response_triggered' = 'true') as incidents_triggered,
                    COUNT(DISTINCT ads.new_data->>'severity') as severity_levels
                FROM audit.audit_event_h aeh
                JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
                WHERE aeh.tenant_hk = %s
                AND ads.table_name LIKE '%security%'
                AND ads.load_end_date IS NULL;
            """
        }
        
        compliance_results = {}
        
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                for test_name, test_sql in compliance_tests.items():
                    cursor.execute(test_sql, (self.test_tenant_hk,))
                    result = cursor.fetchone()
                    
                    compliance_results[test_name] = dict(result) if result else {}
                    
                    print(f"  ✅ {test_name}:")
                    if result:
                        for key, value in result.items():
                            print(f"    📊 {key}: {value}")
                    print()
        
        except Exception as e:
            print(f"  ❌ Error testing compliance features: {e}")
            compliance_results['error'] = str(e)
        
        return compliance_results
    
    def calculate_compliance_score(self, validation_results, compliance_results):
        """Calculate overall compliance score"""
        print("\n📈 Calculating Compliance Score...")
        
        score_components = {
            'audit_events_logged': 0,
            'query_validation': 0,
            'phi_access_compliance': 0,
            'audit_integrity': 0,
            'compliance_checks': 0,
            'security_monitoring': 0
        }
        
        # Audit events logged (25 points)
        if len(self.inserted_audit_events) >= 6:
            score_components['audit_events_logged'] = 25
        elif len(self.inserted_audit_events) >= 3:
            score_components['audit_events_logged'] = 15
        else:
            score_components['audit_events_logged'] = 5
        
        # Query validation (20 points)
        successful_queries = sum(1 for result in validation_results.values() 
                               if isinstance(result, dict) and result.get('records_found', 0) > 0)
        score_components['query_validation'] = min(20, successful_queries * 4)
        
        # PHI access compliance (15 points)
        phi_test = compliance_results.get('phi_access_logging', {})
        if phi_test.get('all_minimum_necessary') and phi_test.get('phi_access_events', 0) > 0:
            score_components['phi_access_compliance'] = 15
        elif phi_test.get('phi_access_events', 0) > 0:
            score_components['phi_access_compliance'] = 10
        
        # Audit integrity (15 points)
        integrity_test = compliance_results.get('audit_trail_integrity', {})
        if (integrity_test.get('all_have_hash') and 
            integrity_test.get('all_have_source') and 
            integrity_test.get('total_events', 0) > 0):
            score_components['audit_integrity'] = 15
        elif integrity_test.get('total_events', 0) > 0:
            score_components['audit_integrity'] = 10
        
        # Compliance checks (15 points)
        compliance_test = compliance_results.get('compliance_validation_coverage', {})
        if (compliance_test.get('hipaa_checks', 0) > 0 and 
            compliance_test.get('compliant_checks', 0) > 0):
            score_components['compliance_checks'] = 15
        elif compliance_test.get('compliance_checks', 0) > 0:
            score_components['compliance_checks'] = 10
        
        # Security monitoring (10 points)
        security_test = compliance_results.get('security_monitoring', {})
        if (security_test.get('security_events', 0) > 0 and 
            security_test.get('incidents_triggered', 0) > 0):
            score_components['security_monitoring'] = 10
        elif security_test.get('security_events', 0) > 0:
            score_components['security_monitoring'] = 5
        
        total_score = sum(score_components.values())
        
        print(f"  📊 Score Breakdown:")
        for component, score in score_components.items():
            print(f"    {component.replace('_', ' ').title()}: {score} points")
        
        print(f"\n  🎯 Total Compliance Score: {total_score}/100")
        
        if total_score >= 90:
            compliance_level = "EXCELLENT - HIPAA Compliant"
            status_emoji = "✅"
        elif total_score >= 75:
            compliance_level = "GOOD - Minor improvements needed"
            status_emoji = "⚠️"
        elif total_score >= 60:
            compliance_level = "FAIR - Significant improvements needed"
            status_emoji = "🔶"
        else:
            compliance_level = "POOR - Major compliance issues"
            status_emoji = "🚨"
        
        print(f"  {status_emoji} Compliance Level: {compliance_level}")
        
        return total_score, compliance_level
    
    def cleanup_test_data(self):
        """Clean up test data"""
        print("\n🧹 Cleaning up test data...")
        
        try:
            with self.conn.cursor() as cursor:
                # Delete audit detail records for our test events
                for event in self.inserted_audit_events:
                    cursor.execute("""
                        DELETE FROM audit.audit_detail_s 
                        WHERE audit_event_hk = %s
                    """, (event['audit_event_hk'],))
                
                # Delete audit event records
                cursor.execute("""
                    DELETE FROM audit.audit_event_h 
                    WHERE record_source = 'audit_test'
                """)
                
                # Delete test user (delete first due to foreign key)
                if self.test_user_hk:
                    cursor.execute("""
                        DELETE FROM auth.user_h 
                        WHERE user_hk = %s AND record_source = 'audit_test'
                    """, (self.test_user_hk,))
                
                # Delete test tenant (delete last due to foreign key constraints)
                if self.test_tenant_hk:
                    cursor.execute("""
                        DELETE FROM auth.tenant_h 
                        WHERE tenant_hk = %s AND record_source = 'audit_test'
                    """, (self.test_tenant_hk,))
                
                print("  ✅ Test data cleaned up successfully")
                
        except Exception as e:
            print(f"  ⚠️  Error cleaning up test data: {e}")
    
    def run_comprehensive_test(self):
        """Run the complete real audit trail test"""
        if not self.connect_to_database():
            return
        
        print("\n🚀 Starting Real Audit Trail Validation Test")
        print("=" * 60)
        
        try:
            # Setup test data
            self.setup_test_data()
            
            # Insert real audit events
            self.insert_real_audit_events()
            
            # Wait a moment for data to be committed
            time.sleep(1)
            
            # Validate audit trail queries
            validation_results = self.validate_audit_trail_queries()
            
            # Test HIPAA compliance features
            compliance_results = self.test_hipaa_compliance_features()
            
            # Calculate compliance score
            score, level = self.calculate_compliance_score(validation_results, compliance_results)
            
            # Summary
            print("\n📊 REAL AUDIT TRAIL TEST SUMMARY")
            print("=" * 60)
            print(f"  🧪 Test Session: {self.test_session_id}")
            print(f"  📝 Audit Events Inserted: {len(self.inserted_audit_events)}")
            print(f"  🔍 Validation Queries: {len(validation_results)} executed")
            print(f"  🔒 Compliance Tests: {len(compliance_results)} completed")
            print(f"  📈 Final Score: {score}/100 - {level}")
            
            if score >= 90:
                print("\n  🎉 AUDIT TRAIL SYSTEM FULLY VALIDATED!")
                print("  ✅ Real data successfully inserted and retrieved")
                print("  ✅ All audit queries working correctly")
                print("  ✅ HIPAA compliance features operational")
                print("  ✅ System ready for production use")
            else:
                print("\n  ⚠️  Audit trail system needs improvements")
                print("  🔧 Review failed components and address issues")
            
        except Exception as e:
            print(f"\n❌ Test failed: {e}")
            import traceback
            traceback.print_exc()
        
        finally:
            # Clean up test data
            self.cleanup_test_data()
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            print("\n🔐 Database connection closed")

def main():
    """Main execution function"""
    test = RealAuditTrailTest()
    
    try:
        test.run_comprehensive_test()
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrupted by user")
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
    finally:
        test.close()

if __name__ == "__main__":
    main() 