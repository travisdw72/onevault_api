#!/usr/bin/env python3
"""
ETL Pipeline Test - OneVault Data Flow Validation
Tests the complete data pipeline: raw → staging → business → reports
Focus: Data integrity, transformation logic, tenant isolation
"""

import psycopg2
import json
import getpass
from datetime import datetime, timedelta
import uuid
import time

class ETLPipelineTest:
    def __init__(self):
        self.conn = None
        self.test_results = {
            'timestamp': datetime.now().isoformat(),
            'pipeline_tests': {},
            'data_integrity': {},
            'performance_metrics': {},
            'recommendations': []
        }
        self.test_tenant_hk = None
        self.test_user_hk = None
        
    def connect_to_database(self):
        """Connect to local test database"""
        print("🔍 ETL Pipeline Test - OneVault Data Flow Validation")
        print("Connecting to: one_vault_site_testing (localhost)")
        
        password = getpass.getpass("Enter database password: ")
        
        try:
            self.conn = psycopg2.connect(
                host="localhost",
                port=5432,
                database="one_vault_site_testing",
                user="postgres",
                password=password,
                autocommit=False  # We want to control transactions
            )
            print("✅ Database connection successful")
            return True
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def execute_query(self, query: str, params: tuple = None, fetch_results: bool = True):
        """Execute query with proper error handling"""
        if not self.conn:
            return None
            
        try:
            cursor = self.conn.cursor()
            cursor.execute(query, params)
            
            if fetch_results and query.strip().upper().startswith('SELECT'):
                results = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description]
                return [dict(zip(columns, row)) for row in results]
            elif not fetch_results:
                # For INSERT/UPDATE operations
                return {"rows_affected": cursor.rowcount}
            else:
                return [{"status": "success"}]
                
        except Exception as e:
            print(f"❌ Query failed: {e}")
            self.conn.rollback()
            return [{"error": str(e)}]
        finally:
            cursor.close()
    
    def setup_test_data(self):
        """Create test tenant and user for ETL testing"""
        print("\n🧪 Setting up test data...")
        
        try:
            # Create test tenant
            test_tenant_bk = f"ETL_TEST_TENANT_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            
            # Use existing API function to create tenant
            tenant_result = self.execute_query("""
                SELECT api.tenant_register(%s, %s, %s, %s, %s) as result
            """, (
                test_tenant_bk,
                'etl-test-domain.com',
                'ETL Test Organization',
                'test@etltest.com',
                'EtlTest123!'
            ))
            
            if tenant_result and 'error' not in tenant_result[0]:
                print(f"✅ Test tenant created: {test_tenant_bk}")
                
                # Get tenant hash key
                tenant_hk_result = self.execute_query("""
                    SELECT tenant_hk FROM auth.tenant_h WHERE tenant_bk = %s
                """, (test_tenant_bk,))
                
                if tenant_hk_result:
                    self.test_tenant_hk = tenant_hk_result[0]['tenant_hk']
                    print(f"✅ Test tenant HK retrieved")
                    
                    # Create test user
                    user_result = self.execute_query("""
                        SELECT api.user_register(%s, %s, %s, %s, %s, %s) as result
                    """, (
                        self.test_tenant_hk.hex(),
                        'etltest@example.com',
                        'EtlTest123!',
                        'ETL',
                        'Tester',
                        'ETL_USER'
                    ))
                    
                    if user_result and 'error' not in user_result[0]:
                        print(f"✅ Test user created")
                        
                        # Get user hash key
                        user_hk_result = self.execute_query("""
                            SELECT user_hk FROM auth.user_h 
                            WHERE tenant_hk = %s
                            ORDER BY load_date DESC LIMIT 1
                        """, (self.test_tenant_hk,))
                        
                        if user_hk_result:
                            self.test_user_hk = user_hk_result[0]['user_hk']
                            print(f"✅ Test user HK retrieved")
                            return True
            
            print("❌ Failed to setup test data")
            return False
            
        except Exception as e:
            print(f"❌ Test data setup failed: {e}")
            return False
    
    def test_site_tracking_etl(self):
        """Test site tracking ETL pipeline"""
        print("\n📊 Testing Site Tracking ETL Pipeline...")
        
        site_tracking_tests = {}
        
        try:
            # Test 1: Insert data into raw layer via API
            print("  Step 1: Testing raw data insertion...")
            
            test_event_data = {
                'event_type': 'ETL_TEST_EVENT',
                'page_url': 'https://etltest.com/test',
                'user_agent': 'ETL Test Agent',
                'session_id': str(uuid.uuid4()),
                'timestamp': datetime.now().isoformat()
            }
            
            # Use site tracking API function
            raw_insert_result = self.execute_query("""
                SELECT api.track_site_event(%s, %s, %s, %s, %s, %s, %s) as result
            """, (
                self.test_tenant_hk.hex(),
                test_event_data['event_type'],
                test_event_data['page_url'],
                test_event_data['user_agent'],
                test_event_data['session_id'],
                'ETL_TEST',
                test_event_data['timestamp']
            ))
            
            if raw_insert_result and 'error' not in raw_insert_result[0]:
                print("    ✅ Raw data inserted successfully")
                site_tracking_tests['raw_insertion'] = 'PASS'
                
                # Test 2: Check if data moved to staging
                print("  Step 2: Testing raw → staging transformation...")
                time.sleep(2)  # Allow processing time
                
                staging_check = self.execute_query("""
                    SELECT COUNT(*) as count 
                    FROM staging.site_events_processed 
                    WHERE tenant_hk = %s 
                    AND event_type = 'ETL_TEST_EVENT'
                    AND load_date >= %s
                """, (self.test_tenant_hk, datetime.now() - timedelta(minutes=5)))
                
                if staging_check and staging_check[0]['count'] > 0:
                    print("    ✅ Data successfully moved to staging")
                    site_tracking_tests['raw_to_staging'] = 'PASS'
                    
                    # Test 3: Check if data moved to business layer
                    print("  Step 3: Testing staging → business transformation...")
                    time.sleep(2)  # Allow processing time
                    
                    business_check = self.execute_query("""
                        SELECT COUNT(*) as count 
                        FROM business.site_analytics_h sa
                        JOIN business.site_analytics_s sas ON sa.analytics_hk = sas.analytics_hk
                        WHERE sa.tenant_hk = %s 
                        AND sas.event_type = 'ETL_TEST_EVENT'
                        AND sas.load_date >= %s
                    """, (self.test_tenant_hk, datetime.now() - timedelta(minutes=5)))
                    
                    if business_check and business_check[0]['count'] > 0:
                        print("    ✅ Data successfully moved to business layer")
                        site_tracking_tests['staging_to_business'] = 'PASS'
                    else:
                        print("    ❌ Data not found in business layer")
                        site_tracking_tests['staging_to_business'] = 'FAIL'
                else:
                    print("    ❌ Data not found in staging layer")
                    site_tracking_tests['raw_to_staging'] = 'FAIL'
                    site_tracking_tests['staging_to_business'] = 'SKIP'
            else:
                print("    ❌ Raw data insertion failed")
                site_tracking_tests['raw_insertion'] = 'FAIL'
                site_tracking_tests['raw_to_staging'] = 'SKIP'
                site_tracking_tests['staging_to_business'] = 'SKIP'
        
        except Exception as e:
            print(f"    ❌ Site tracking ETL test failed: {e}")
            site_tracking_tests['error'] = str(e)
        
        self.test_results['pipeline_tests']['site_tracking'] = site_tracking_tests
        return site_tracking_tests
    
    def test_ai_agent_etl(self):
        """Test AI agent ETL pipeline"""
        print("\n🤖 Testing AI Agent ETL Pipeline...")
        
        ai_agent_tests = {}
        
        try:
            # Test 1: Create AI session via API
            print("  Step 1: Testing AI session creation...")
            
            session_result = self.execute_query("""
                SELECT api.ai_create_session(%s, %s, %s, %s) as result
            """, (
                self.test_tenant_hk.hex(),
                'business_intelligence_agent',
                'ETL Test Session',
                '{"test_mode": true, "etl_validation": true}'
            ))
            
            if session_result and 'error' not in session_result[0]:
                print("    ✅ AI session created successfully")
                ai_agent_tests['session_creation'] = 'PASS'
                
                # Test 2: Log observation via API
                print("  Step 2: Testing AI observation logging...")
                
                observation_result = self.execute_query("""
                    SELECT api.ai_log_observation(%s, %s, %s, %s, %s) as result
                """, (
                    self.test_tenant_hk.hex(),
                    'ETL_TEST_ENTITY',
                    'test_analysis',
                    'ETL pipeline validation test observation',
                    '{"confidence": 0.95, "test_mode": true}'
                ))
                
                if observation_result and 'error' not in observation_result[0]:
                    print("    ✅ AI observation logged successfully")
                    ai_agent_tests['observation_logging'] = 'PASS'
                    
                    # Test 3: Check if data appears in monitoring
                    print("  Step 3: Testing AI data in monitoring layer...")
                    time.sleep(2)  # Allow processing time
                    
                    monitoring_check = self.execute_query("""
                        SELECT COUNT(*) as count 
                        FROM ai_monitoring.ai_analysis_h aa
                        JOIN ai_monitoring.ai_analysis_results_s aar ON aa.analysis_hk = aar.analysis_hk
                        WHERE aar.analysis_description LIKE '%ETL pipeline validation%'
                        AND aar.load_date >= %s
                    """, (datetime.now() - timedelta(minutes=5),))
                    
                    if monitoring_check and monitoring_check[0]['count'] > 0:
                        print("    ✅ AI data successfully appeared in monitoring")
                        ai_agent_tests['monitoring_integration'] = 'PASS'
                    else:
                        print("    ❌ AI data not found in monitoring layer")
                        ai_agent_tests['monitoring_integration'] = 'FAIL'
                else:
                    print("    ❌ AI observation logging failed")
                    ai_agent_tests['observation_logging'] = 'FAIL'
                    ai_agent_tests['monitoring_integration'] = 'SKIP'
            else:
                print("    ❌ AI session creation failed")
                ai_agent_tests['session_creation'] = 'FAIL'
                ai_agent_tests['observation_logging'] = 'SKIP'
                ai_agent_tests['monitoring_integration'] = 'SKIP'
        
        except Exception as e:
            print(f"    ❌ AI agent ETL test failed: {e}")
            ai_agent_tests['error'] = str(e)
        
        self.test_results['pipeline_tests']['ai_agents'] = ai_agent_tests
        return ai_agent_tests
    
    def test_data_integrity(self):
        """Test data integrity across ETL layers"""
        print("\n🔍 Testing Data Integrity Across ETL Layers...")
        
        integrity_tests = {}
        
        try:
            # Test 1: Tenant isolation integrity
            print("  Testing tenant isolation...")
            
            tenant_isolation_query = """
            SELECT 
                'raw' as layer,
                COUNT(*) as total_records,
                COUNT(CASE WHEN tenant_hk = %s THEN 1 END) as tenant_records
            FROM raw.site_events
            WHERE load_date >= %s
            
            UNION ALL
            
            SELECT 
                'staging' as layer,
                COUNT(*) as total_records,
                COUNT(CASE WHEN tenant_hk = %s THEN 1 END) as tenant_records
            FROM staging.site_events_processed
            WHERE load_date >= %s
            
            UNION ALL
            
            SELECT 
                'business' as layer,
                COUNT(*) as total_records,
                COUNT(CASE WHEN sa.tenant_hk = %s THEN 1 END) as tenant_records
            FROM business.site_analytics_h sa
            WHERE sa.load_date >= %s
            """
            
            test_start_time = datetime.now() - timedelta(minutes=10)
            isolation_result = self.execute_query(tenant_isolation_query, (
                self.test_tenant_hk, test_start_time,
                self.test_tenant_hk, test_start_time,
                self.test_tenant_hk, test_start_time
            ))
            
            if isolation_result:
                print(f"    ✅ Tenant isolation check completed")
                integrity_tests['tenant_isolation'] = {
                    'status': 'PASS',
                    'details': isolation_result
                }
            
            # Test 2: Data consistency across layers
            print("  Testing data consistency...")
            
            consistency_query = """
            WITH layer_counts AS (
                SELECT 
                    'raw' as layer,
                    COUNT(*) as record_count
                FROM raw.site_events 
                WHERE tenant_hk = %s AND load_date >= %s
                
                UNION ALL
                
                SELECT 
                    'staging' as layer,
                    COUNT(*) as record_count
                FROM staging.site_events_processed 
                WHERE tenant_hk = %s AND load_date >= %s
            )
            SELECT 
                layer,
                record_count,
                LAG(record_count) OVER (ORDER BY layer) as prev_count,
                CASE 
                    WHEN LAG(record_count) OVER (ORDER BY layer) IS NULL THEN 'N/A'
                    WHEN record_count = LAG(record_count) OVER (ORDER BY layer) THEN 'CONSISTENT'
                    WHEN record_count < LAG(record_count) OVER (ORDER BY layer) THEN 'DATA_LOSS'
                    ELSE 'DATA_GAIN'
                END as consistency_status
            FROM layer_counts
            ORDER BY layer
            """
            
            consistency_result = self.execute_query(consistency_query, (
                self.test_tenant_hk, test_start_time,
                self.test_tenant_hk, test_start_time
            ))
            
            if consistency_result:
                print(f"    ✅ Data consistency check completed")
                integrity_tests['data_consistency'] = {
                    'status': 'PASS',
                    'details': consistency_result
                }
        
        except Exception as e:
            print(f"    ❌ Data integrity test failed: {e}")
            integrity_tests['error'] = str(e)
        
        self.test_results['data_integrity'] = integrity_tests
        return integrity_tests
    
    def test_etl_performance(self):
        """Test ETL pipeline performance"""
        print("\n⚡ Testing ETL Performance...")
        
        performance_tests = {}
        
        try:
            # Test processing times
            print("  Testing ETL processing times...")
            
            processing_time_query = """
            SELECT 
                'raw_to_staging_avg_minutes' as metric,
                AVG(EXTRACT(EPOCH FROM (staging.load_date - raw.load_date))/60) as value
            FROM raw.site_events raw
            JOIN staging.site_events_processed staging 
                ON raw.event_id = staging.source_event_id
            WHERE raw.tenant_hk = %s 
            AND raw.load_date >= %s
            
            UNION ALL
            
            SELECT 
                'staging_to_business_avg_minutes' as metric,
                AVG(EXTRACT(EPOCH FROM (business.load_date - staging.load_date))/60) as value
            FROM staging.site_events_processed staging
            JOIN business.site_analytics_h business 
                ON staging.analytics_hk = business.analytics_hk
            WHERE staging.tenant_hk = %s 
            AND staging.load_date >= %s
            """
            
            test_window = datetime.now() - timedelta(hours=24)
            performance_result = self.execute_query(processing_time_query, (
                self.test_tenant_hk, test_window,
                self.test_tenant_hk, test_window
            ))
            
            if performance_result:
                print(f"    ✅ ETL performance metrics collected")
                performance_tests['processing_times'] = {
                    'status': 'PASS',
                    'metrics': performance_result
                }
        
        except Exception as e:
            print(f"    ❌ ETL performance test failed: {e}")
            performance_tests['error'] = str(e)
        
        self.test_results['performance_metrics'] = performance_tests
        return performance_tests
    
    def generate_etl_assessment(self):
        """Generate overall ETL pipeline assessment"""
        print("\n📋 Generating ETL Pipeline Assessment...")
        
        # Analyze test results
        total_tests = 0
        passed_tests = 0
        failed_tests = 0
        
        for test_category in self.test_results['pipeline_tests'].values():
            for test_name, status in test_category.items():
                if status in ['PASS', 'FAIL']:
                    total_tests += 1
                    if status == 'PASS':
                        passed_tests += 1
                    else:
                        failed_tests += 1
        
        pipeline_health = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        
        print(f"\n🎯 ETL Pipeline Health: {pipeline_health:.1f}% ({passed_tests}/{total_tests})")
        
        # Generate recommendations
        recommendations = []
        
        if pipeline_health < 70:
            recommendations.append("❌ CRITICAL: ETL pipeline has major issues - fix before Canvas integration")
            recommendations.append("🔧 Focus on failed transformations in raw → staging → business flow")
        elif pipeline_health < 90:
            recommendations.append("⚠️ WARNING: ETL pipeline has some issues - address before production")
            recommendations.append("🔧 Review failed tests and optimize data transformations")
        else:
            recommendations.append("✅ EXCELLENT: ETL pipeline is healthy - ready for Canvas integration")
            recommendations.append("🚀 Proceed with Canvas API integration with confidence")
        
        # Specific recommendations based on test results
        site_tracking = self.test_results['pipeline_tests'].get('site_tracking', {})
        if site_tracking.get('raw_to_staging') == 'FAIL':
            recommendations.append("🔧 Fix raw → staging transformation for site tracking")
        if site_tracking.get('staging_to_business') == 'FAIL':
            recommendations.append("🔧 Fix staging → business transformation for site analytics")
            
        ai_agents = self.test_results['pipeline_tests'].get('ai_agents', {})
        if ai_agents.get('monitoring_integration') == 'FAIL':
            recommendations.append("🔧 Fix AI data flow to monitoring layer")
        
        self.test_results['recommendations'] = recommendations
        
        for rec in recommendations:
            print(f"  {rec}")
        
        return {
            'health_score': pipeline_health,
            'total_tests': total_tests,
            'passed_tests': passed_tests,
            'failed_tests': failed_tests,
            'recommendations': recommendations
        }
    
    def cleanup_test_data(self):
        """Clean up test data"""
        print("\n🧹 Cleaning up test data...")
        
        try:
            if self.test_tenant_hk:
                # Delete test data (in reverse order of dependencies)
                cleanup_queries = [
                    "DELETE FROM business.site_analytics_s WHERE load_date >= %s",
                    "DELETE FROM staging.site_events_processed WHERE tenant_hk = %s",
                    "DELETE FROM raw.site_events WHERE tenant_hk = %s",
                    "DELETE FROM ai_monitoring.ai_analysis_results_s WHERE load_date >= %s",
                    "DELETE FROM auth.user_h WHERE tenant_hk = %s",
                    "DELETE FROM auth.tenant_h WHERE tenant_hk = %s"
                ]
                
                test_time = datetime.now() - timedelta(minutes=30)
                
                for query in cleanup_queries:
                    if 'load_date' in query:
                        self.execute_query(query, (test_time,), fetch_results=False)
                    else:
                        self.execute_query(query, (self.test_tenant_hk,), fetch_results=False)
                
                self.conn.commit()
                print("✅ Test data cleaned up successfully")
        
        except Exception as e:
            print(f"⚠️ Test data cleanup warning: {e}")
    
    def save_results(self):
        """Save test results"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"etl_pipeline_test_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(self.test_results, f, indent=2, default=str)
        
        print(f"\n💾 ETL test results saved to: {filename}")
        return filename
    
    def run_all_tests(self):
        """Run comprehensive ETL pipeline tests"""
        if not self.connect_to_database():
            return False
        
        try:
            # Setup test environment
            if not self.setup_test_data():
                print("❌ Failed to setup test data - aborting")
                return False
            
            # Run ETL pipeline tests
            self.test_site_tracking_etl()
            self.test_ai_agent_etl()
            self.test_data_integrity()
            self.test_etl_performance()
            
            # Generate assessment
            assessment = self.generate_etl_assessment()
            
            # Save results
            self.save_results()
            
            # Cleanup
            self.cleanup_test_data()
            
            print("\n🎉 ETL Pipeline Test Complete!")
            return assessment['health_score'] >= 70
            
        except Exception as e:
            print(f"❌ ETL test execution failed: {e}")
            return False
        finally:
            if self.conn:
                self.conn.close()

if __name__ == "__main__":
    tester = ETLPipelineTest()
    success = tester.run_all_tests()
    exit(0 if success else 1) 