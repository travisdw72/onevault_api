#!/usr/bin/env python3
"""
AI API Endpoint Testing Script for One Vault
Tests all AI-related API endpoints using comprehensive test scenarios.
Includes comprehensive audit trail validation for HIPAA compliance.
"""

import psycopg2
import psycopg2.extras
import json
import time
import os
import traceback
import getpass
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple
import random
import string

# Import configuration
from ai_api_test_config import (
    AI_API_TEST_QUERIES, 
    AI_VALIDATION_QUERIES, 
    AUDIT_TRAIL_VALIDATION_QUERIES,
    TEST_CONFIG, 
    TEST_CATEGORIES,
    RESPONSE_SCHEMAS
)

class AIAPITester:
    def __init__(self):
        self.conn = None
        self.test_results = {}
        self.session_start_time = datetime.now()
        self.test_session_id = self.generate_test_session_id()
        self.audit_validation_enabled = TEST_CONFIG.get('audit_validation', {}).get('enabled', True)
        
    def generate_test_session_id(self) -> str:
        """Generate unique test session ID"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        random_suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=6))
        return f"test_session_{timestamp}_{random_suffix}"
    
    def connect_to_database(self) -> bool:
        """Establish database connection"""
        print("🧪 AI API Endpoint Testing Tool with Audit Trail Validation")
        print("=" * 60)
        
        config = TEST_CONFIG['database'].copy()
        
        # Get password if not specified
        if config.get('password') is None:
            password = getpass.getpass(f"Enter PostgreSQL password: ")
            config['password'] = password
        
        try:
            self.conn = psycopg2.connect(**config)
            self.conn.set_session(autocommit=True)
            print(f"✅ Connected to database: {config['database']}")
            return True
        except psycopg2.Error as e:
            print(f"❌ Failed to connect to database: {e}")
            return False
    
    def execute_api_function(self, function_name: str, test_data: Dict[str, Any]) -> Tuple[bool, Dict[str, Any]]:
        """Execute an API function with test data"""
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Prepare the function call
                json_data = json.dumps(test_data)
                query = f"SELECT {function_name}(%s) as result;"
                
                # Execute with timeout
                start_time = time.time()
                cursor.execute(query, (json_data,))
                result = cursor.fetchone()
                execution_time = time.time() - start_time
                
                if result and result['result']:
                    response_data = result['result']
                    if isinstance(response_data, str):
                        response_data = json.loads(response_data)
                    
                    # Add execution metadata
                    response_data['_test_metadata'] = {
                        'execution_time_ms': round(execution_time * 1000, 2),
                        'function_called': function_name,
                        'test_session_id': self.test_session_id
                    }
                    
                    return True, response_data
                else:
                    return False, {'error': 'No result returned from function'}
                    
        except psycopg2.Error as e:
            return False, {
                'error': str(e),
                'error_type': 'database_error',
                'error_code': e.pgcode if hasattr(e, 'pgcode') else 'UNKNOWN'
            }
        except json.JSONDecodeError as e:
            return False, {
                'error': f'JSON decode error: {str(e)}',
                'error_type': 'json_error'
            }
        except Exception as e:
            return False, {
                'error': f'Unexpected error: {str(e)}',
                'error_type': 'unexpected_error'
            }
    
    def validate_audit_trail(self, test_config: Dict[str, Any], api_response: Dict[str, Any]) -> Dict[str, Any]:
        """Validate that expected audit events were logged"""
        if not self.audit_validation_enabled or not test_config.get('audit_validation', False):
            return {'audit_validation_skipped': True}
        
        audit_result = {
            'audit_validation_performed': True,
            'expected_events': test_config.get('expected_audit_events', []),
            'events_found': [],
            'events_missing': [],
            'audit_trail_complete': False,
            'audit_details': {},
            'compliance_validated': False
        }
        
        # Wait for audit events to be logged
        wait_time = TEST_CONFIG.get('audit_validation', {}).get('wait_time_seconds', 5)
        print(f"    🔍 Waiting {wait_time}s for audit events to be logged...")
        time.sleep(wait_time)
        
        try:
            # Check for specific audit events based on test type
            test_type = test_config.get('test_type', 'functional')
            
            if 'ai_chat' in test_config.get('function', ''):
                audit_result['audit_details'] = self.validate_ai_chat_audit_events(test_config, api_response)
            elif 'ai_log_observation' in test_config.get('function', ''):
                audit_result['audit_details'] = self.validate_ai_observation_audit_events(test_config, api_response)
            elif 'security' in test_type or 'violation' in str(test_config.get('expected_audit_events', [])):
                audit_result['audit_details'] = self.validate_security_audit_events(test_config, api_response)
            elif 'compliance' in test_type:
                audit_result['audit_details'] = self.validate_compliance_audit_events(test_config, api_response)
            else:
                audit_result['audit_details'] = self.validate_general_audit_events(test_config, api_response)
            
            # Check if all expected events were found
            expected_events = set(test_config.get('expected_audit_events', []))
            found_events = set(audit_result['audit_details'].get('event_types_found', []))
            
            audit_result['events_found'] = list(found_events)
            audit_result['events_missing'] = list(expected_events - found_events)
            audit_result['audit_trail_complete'] = len(audit_result['events_missing']) == 0
            
            # Validate compliance requirements
            audit_result['compliance_validated'] = self.validate_compliance_requirements(
                test_config, audit_result['audit_details']
            )
            
        except Exception as e:
            audit_result['audit_validation_error'] = str(e)
            audit_result['audit_trail_complete'] = False
        
        return audit_result
    
    def validate_ai_chat_audit_events(self, test_config: Dict[str, Any], api_response: Dict[str, Any]) -> Dict[str, Any]:
        """Validate audit events for AI chat operations"""
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                query = AUDIT_TRAIL_VALIDATION_QUERIES['validate_ai_chat_audit']
                cursor.execute(query)
                results = cursor.fetchall()
                
                return {
                    'audit_events_found': len(results),
                    'event_types_found': [row['event_type'] for row in results],
                    'recent_events': [dict(row) for row in results[:3]],  # Show first 3
                    'interaction_ids': [row['interaction_id'] for row in results if row['interaction_id']],
                    'validation_timestamp': datetime.now().isoformat()
                }
        except Exception as e:
            return {'validation_error': str(e)}
    
    def validate_ai_observation_audit_events(self, test_config: Dict[str, Any], api_response: Dict[str, Any]) -> Dict[str, Any]:
        """Validate audit events for AI observation operations"""
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                query = AUDIT_TRAIL_VALIDATION_QUERIES['validate_ai_observation_audit']
                cursor.execute(query)
                results = cursor.fetchall()
                
                return {
                    'audit_events_found': len(results),
                    'event_types_found': [row['event_type'] for row in results],
                    'recent_events': [dict(row) for row in results[:3]],
                    'observation_ids': [row['observation_id'] for row in results if row['observation_id']],
                    'entity_ids': [row['entity_id'] for row in results if row['entity_id']],
                    'validation_timestamp': datetime.now().isoformat()
                }
        except Exception as e:
            return {'validation_error': str(e)}
    
    def validate_security_audit_events(self, test_config: Dict[str, Any], api_response: Dict[str, Any]) -> Dict[str, Any]:
        """Validate audit events for security operations"""
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                query = AUDIT_TRAIL_VALIDATION_QUERIES['validate_security_audit_events']
                cursor.execute(query)
                results = cursor.fetchall()
                
                return {
                    'security_events_found': len(results),
                    'event_types_found': [row['event_type'] for row in results],
                    'recent_events': [dict(row) for row in results[:3]],
                    'security_levels': [row['security_level'] for row in results if row['security_level']],
                    'violation_types': [row['violation_type'] for row in results if row['violation_type']],
                    'validation_timestamp': datetime.now().isoformat()
                }
        except Exception as e:
            return {'validation_error': str(e)}
    
    def validate_compliance_audit_events(self, test_config: Dict[str, Any], api_response: Dict[str, Any]) -> Dict[str, Any]:
        """Validate audit events for compliance operations"""
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                query = AUDIT_TRAIL_VALIDATION_QUERIES['validate_compliance_audit_trail']
                cursor.execute(query)
                results = cursor.fetchall()
                
                return {
                    'compliance_events_found': len(results),
                    'event_types_found': [row['event_type'] for row in results],
                    'recent_events': [dict(row) for row in results[:3]],
                    'regulations': [row['regulation'] for row in results if row['regulation']],
                    'phi_access_logged': any(row['phi_accessed'] == 'true' for row in results),
                    'minimum_necessary_applied': any(row['minimum_necessary'] == 'true' for row in results),
                    'validation_timestamp': datetime.now().isoformat()
                }
        except Exception as e:
            return {'validation_error': str(e)}
    
    def validate_general_audit_events(self, test_config: Dict[str, Any], api_response: Dict[str, Any]) -> Dict[str, Any]:
        """Validate general audit events"""
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Query for recent audit events
                query = """
                    SELECT 
                        ads.event_type,
                        COUNT(*) as event_count,
                        MAX(ads.event_timestamp) as last_event_time
                    FROM audit.audit_event_h aeh
                    JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
                    WHERE ads.event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
                    AND ads.load_end_date IS NULL
                    GROUP BY ads.event_type
                    ORDER BY last_event_time DESC;
                """
                cursor.execute(query)
                results = cursor.fetchall()
                
                return {
                    'general_events_found': sum(row['event_count'] for row in results),
                    'event_types_found': [row['event_type'] for row in results],
                    'event_summary': [dict(row) for row in results],
                    'validation_timestamp': datetime.now().isoformat()
                }
        except Exception as e:
            return {'validation_error': str(e)}
    
    def validate_compliance_requirements(self, test_config: Dict[str, Any], audit_details: Dict[str, Any]) -> bool:
        """Validate that compliance requirements are met"""
        try:
            # Check HIPAA compliance requirements
            if TEST_CONFIG.get('audit_validation', {}).get('hipaa_validation', False):
                if 'phi' in str(test_config.get('test_data', {})).lower():
                    # PHI access should be logged
                    return audit_details.get('phi_access_logged', False)
            
            # Check GDPR compliance requirements
            if TEST_CONFIG.get('audit_validation', {}).get('gdpr_validation', False):
                if 'personal' in str(test_config.get('test_data', {})).lower():
                    # Personal data access should be logged
                    return len(audit_details.get('event_types_found', [])) > 0
            
            # General compliance - ensure audit events exist
            return len(audit_details.get('event_types_found', [])) > 0
            
        except Exception:
            return False
    
    def run_validation_queries(self):
        """Run database validation queries including audit trail validation"""
        print("\n🔍 Running Database Validation Queries...")
        
        validation_results = {}
        
        # Run standard validation queries
        for query_name, query_sql in AI_VALIDATION_QUERIES.items():
            print(f"  📋 Running: {query_name}")
            try:
                with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                    cursor.execute(query_sql)
                    results = cursor.fetchall()
                    
                    validation_results[query_name] = {
                        'success': True,
                        'result_count': len(results),
                        'results': [dict(row) for row in results]
                    }
                    print(f"    ✅ Found {len(results)} items")
                    
                    # Print some details for key queries
                    if query_name == 'check_ai_functions_exist' and len(results) > 0:
                        print("    📋 AI Functions found:")
                        for result in results[:5]:  # Show first 5
                            print(f"      - {result['routine_name']} ({result['routine_type']})")
                        if len(results) > 5:
                            print(f"      ... and {len(results) - 5} more")
                    
                    elif query_name == 'check_audit_tables_exist' and len(results) > 0:
                        print("    📋 Audit Tables found:")
                        for result in results[:5]:
                            print(f"      - {result['table_name']} ({result['table_type']})")
                        if len(results) > 5:
                            print(f"      ... and {len(results) - 5} more")
                    
            except psycopg2.Error as e:
                validation_results[query_name] = {
                    'success': False,
                    'error': str(e),
                    'error_code': e.pgcode if hasattr(e, 'pgcode') else 'UNKNOWN'
                }
                print(f"    ❌ Error: {str(e)}")
        
        return validation_results
    
    def run_single_test(self, test_name: str, test_config: Dict[str, Any]) -> Dict[str, Any]:
        """Run a single API test with audit trail validation"""
        print(f"  🧪 Running test: {test_name}")
        
        test_result = {
            'test_name': test_name,
            'description': test_config['description'],
            'function': test_config['function'],
            'test_type': test_config['test_type'],
            'start_time': datetime.now().isoformat(),
            'success': False,
            'response': {},
            'audit_validation': {},
            'errors': [],
            'execution_time_ms': 0
        }
        
        start_time = time.time()
        
        try:
            # Prepare test data
            test_data = test_config['test_data'].copy()
            
            # Execute API function
            success, response = self.execute_api_function(test_config['function'], test_data)
            
            test_result['response'] = response
            
            if success:
                test_result['success'] = True
                
                # Check if this is an expected failure test
                expected_success = test_config.get('expected_success', True)
                if not expected_success:
                    # For tests that should fail, success means getting a proper error response
                    test_result['success'] = not response.get('success', True)
                
                # Validate audit trail if enabled
                if test_config.get('audit_validation', False):
                    audit_validation = self.validate_audit_trail(test_config, response)
                    test_result['audit_validation'] = audit_validation
                    
                    # Test fails if audit trail validation fails
                    if not audit_validation.get('audit_trail_complete', True):
                        test_result['success'] = False
                        test_result['errors'].append({
                            'error_type': 'audit_validation_failure',
                            'missing_events': audit_validation.get('events_missing', []),
                            'expected_events': audit_validation.get('expected_events', [])
                        })
            else:
                test_result['errors'].append({
                    'error_type': 'api_execution_error',
                    'error_details': response
                })
            
        except Exception as e:
            test_result['errors'].append({
                'error_type': 'test_execution_error',
                'error_message': str(e),
                'traceback': traceback.format_exc()
            })
        
        test_result['execution_time_ms'] = round((time.time() - start_time) * 1000, 2)
        test_result['end_time'] = datetime.now().isoformat()
        
        # Print result summary
        status = "✅ PASS" if test_result['success'] else "❌ FAIL"
        exec_time = test_result['execution_time_ms']
        print(f"    {status} ({exec_time}ms) - {test_config['description']}")
        
        # Print audit validation summary
        if test_result.get('audit_validation', {}).get('audit_validation_performed'):
            audit_val = test_result['audit_validation']
            if audit_val.get('audit_trail_complete'):
                events_found = len(audit_val.get('events_found', []))
                print(f"    🔍 Audit: ✅ {events_found} events logged")
            else:
                missing = len(audit_val.get('events_missing', []))
                print(f"    🔍 Audit: ❌ {missing} events missing")
        
        if not test_result['success'] and test_result['errors']:
            error_msg = test_result['errors'][0].get('error_message', 
                       test_result['errors'][0].get('error_details', {}).get('error', 'Unknown error'))
            print(f"    ⚠️  Error: {error_msg}")
        
        return test_result
    
    def run_test_category(self, category_name: str, test_names: List[str]) -> Dict[str, Any]:
        """Run a category of tests"""
        print(f"\n🧪 Running Test Category: {category_name.upper()}")
        print("-" * 50)
        
        category_results = {
            'category_name': category_name,
            'total_tests': len(test_names),
            'successful_tests': 0,
            'failed_tests': 0,
            'audit_validation_summary': {
                'tests_with_audit_validation': 0,
                'audit_validations_passed': 0,
                'audit_validations_failed': 0
            },
            'test_results': [],
            'start_time': datetime.now().isoformat()
        }
        
        for test_name in test_names:
            if test_name in AI_API_TEST_QUERIES:
                test_config = AI_API_TEST_QUERIES[test_name]
                result = self.run_single_test(test_name, test_config)
                category_results['test_results'].append(result)
                
                if result['success']:
                    category_results['successful_tests'] += 1
                else:
                    category_results['failed_tests'] += 1
                
                # Track audit validation
                if result.get('audit_validation', {}).get('audit_validation_performed'):
                    category_results['audit_validation_summary']['tests_with_audit_validation'] += 1
                    if result['audit_validation'].get('audit_trail_complete'):
                        category_results['audit_validation_summary']['audit_validations_passed'] += 1
                    else:
                        category_results['audit_validation_summary']['audit_validations_failed'] += 1
            else:
                print(f"  ⚠️  Test '{test_name}' not found in configuration")
        
        category_results['end_time'] = datetime.now().isoformat()
        category_results['success_rate'] = (category_results['successful_tests'] / 
                                          category_results['total_tests'] * 100) if category_results['total_tests'] > 0 else 0
        
        print(f"\n📊 Category Summary: {category_results['successful_tests']}/{category_results['total_tests']} tests passed " +
              f"({category_results['success_rate']:.1f}%)")
        
        # Print audit validation summary
        audit_summary = category_results['audit_validation_summary']
        if audit_summary['tests_with_audit_validation'] > 0:
            print(f"🔍 Audit Validation: {audit_summary['audit_validations_passed']}/{audit_summary['tests_with_audit_validation']} passed")
        
        return category_results
    
    def run_all_tests(self, categories: Optional[List[str]] = None):
        """Run all or specified test categories"""
        print(f"🚀 Starting AI API Comprehensive Testing with Audit Trail Validation")
        print(f"Session ID: {self.test_session_id}")
        print("=" * 70)
        
        # Run database validation first
        validation_results = self.run_validation_queries()
        
        # Determine which categories to run
        if categories is None:
            categories_to_run = TEST_CATEGORIES.keys()
        else:
            categories_to_run = [cat for cat in categories if cat in TEST_CATEGORIES]
        
        all_results = {
            'test_session_id': self.test_session_id,
            'start_time': self.session_start_time.isoformat(),
            'database_validation': validation_results,
            'test_categories': {},
            'overall_summary': {},
            'audit_trail_summary': {}
        }
        
        total_tests = 0
        total_successful = 0
        total_audit_validations = 0
        total_audit_passed = 0
        
        # Run each test category
        for category_name in categories_to_run:
            test_names = TEST_CATEGORIES[category_name]
            category_result = self.run_test_category(category_name, test_names)
            all_results['test_categories'][category_name] = category_result
            
            total_tests += category_result['total_tests']
            total_successful += category_result['successful_tests']
            
            # Aggregate audit validation results
            audit_summary = category_result['audit_validation_summary']
            total_audit_validations += audit_summary['tests_with_audit_validation']
            total_audit_passed += audit_summary['audit_validations_passed']
        
        # Calculate overall summary
        all_results['end_time'] = datetime.now().isoformat()
        all_results['overall_summary'] = {
            'total_categories': len(categories_to_run),
            'total_tests': total_tests,
            'successful_tests': total_successful,
            'failed_tests': total_tests - total_successful,
            'overall_success_rate': (total_successful / total_tests * 100) if total_tests > 0 else 0,
            'total_execution_time': str(datetime.now() - self.session_start_time)
        }
        
        # Calculate audit trail summary
        all_results['audit_trail_summary'] = {
            'audit_validation_enabled': self.audit_validation_enabled,
            'total_tests_with_audit_validation': total_audit_validations,
            'audit_validations_passed': total_audit_passed,
            'audit_validations_failed': total_audit_validations - total_audit_passed,
            'audit_success_rate': (total_audit_passed / total_audit_validations * 100) if total_audit_validations > 0 else 0
        }
        
        self.test_results = all_results
        
        # Print final summary
        self.print_final_summary()
        
        # Save results
        if TEST_CONFIG['output'].get('summary_report', True):
            self.save_results()
    
    def print_final_summary(self):
        """Print comprehensive test summary including audit trail analysis"""
        print("\n" + "=" * 70)
        print("📊 COMPREHENSIVE AI API TEST SUMMARY WITH AUDIT VALIDATION")
        print("=" * 70)
        
        summary = self.test_results['overall_summary']
        audit_summary = self.test_results['audit_trail_summary']
        
        print(f"🧪 Total Tests: {summary['total_tests']}")
        print(f"✅ Successful: {summary['successful_tests']}")
        print(f"❌ Failed: {summary['failed_tests']}")
        print(f"📈 Success Rate: {summary['overall_success_rate']:.1f}%")
        print(f"⏱️  Total Time: {summary['total_execution_time']}")
        
        print(f"\n🔍 Audit Trail Validation Summary:")
        if audit_summary['audit_validation_enabled']:
            print(f"📋 Tests with Audit Validation: {audit_summary['total_tests_with_audit_validation']}")
            print(f"✅ Audit Validations Passed: {audit_summary['audit_validations_passed']}")
            print(f"❌ Audit Validations Failed: {audit_summary['audit_validations_failed']}")
            print(f"📈 Audit Success Rate: {audit_summary['audit_success_rate']:.1f}%")
        else:
            print("⚠️  Audit validation was disabled")
        
        print(f"\n📋 Category Breakdown:")
        for category_name, category_result in self.test_results['test_categories'].items():
            success_rate = category_result['success_rate']
            status = "✅" if success_rate >= 80 else "⚠️" if success_rate >= 60 else "❌"
            
            audit_info = ""
            audit_summary_cat = category_result['audit_validation_summary']
            if audit_summary_cat['tests_with_audit_validation'] > 0:
                audit_passed = audit_summary_cat['audit_validations_passed']
                audit_total = audit_summary_cat['tests_with_audit_validation']
                audit_info = f" | Audit: {audit_passed}/{audit_total}"
            
            print(f"  {status} {category_name}: {category_result['successful_tests']}/{category_result['total_tests']} " +
                  f"({success_rate:.1f}%){audit_info}")
        
        # Database validation summary
        validation = self.test_results['database_validation']
        validation_passed = sum(1 for v in validation.values() if v.get('success', False))
        validation_total = len(validation)
        print(f"\n🔍 Database Validation: {validation_passed}/{validation_total} checks passed")
        
        # Print AI functions found
        if 'check_ai_functions_exist' in validation:
            ai_functions = validation['check_ai_functions_exist']
            if ai_functions['success']:
                print(f"✅ Found {ai_functions['result_count']} AI API functions")
            else:
                print("❌ Could not verify AI API functions")
        
        # Print audit tables found
        if 'check_audit_tables_exist' in validation:
            audit_tables = validation['check_audit_tables_exist']
            if audit_tables['success']:
                print(f"✅ Found {audit_tables['result_count']} audit tables")
            else:
                print("❌ Could not verify audit tables")
        
        # Recommendations
        print(f"\n💡 Recommendations:")
        self.print_recommendations()
    
    def print_recommendations(self):
        """Print recommendations based on test results including audit trail"""
        summary = self.test_results['overall_summary']
        audit_summary = self.test_results['audit_trail_summary']
        
        if summary['overall_success_rate'] >= 90:
            print("  ✅ Excellent! All AI API endpoints are functioning well")
        elif summary['overall_success_rate'] >= 75:
            print("  ⚠️  Most endpoints work, but some issues need attention")
        else:
            print("  🚨 Multiple endpoint failures detected - investigation required")
        
        # Audit trail recommendations
        if audit_summary['audit_validation_enabled']:
            if audit_summary['audit_success_rate'] >= 90:
                print("  ✅ Audit trail logging is working excellently - HIPAA compliant")
            elif audit_summary['audit_success_rate'] >= 75:
                print("  ⚠️  Most audit events are logged, but some gaps exist")
            else:
                print("  🚨 Audit trail has significant gaps - compliance risk!")
        else:
            print("  ⚠️  Enable audit validation for compliance verification")
        
        # Check specific categories
        for category_name, category_result in self.test_results['test_categories'].items():
            if category_result['success_rate'] < 80:
                print(f"  🔧 Focus on {category_name} - only {category_result['success_rate']:.1f}% success rate")
        
        # Database validation recommendations
        validation = self.test_results['database_validation']
        if 'check_ai_functions_exist' in validation:
            ai_functions = validation['check_ai_functions_exist']
            if ai_functions['success'] and ai_functions['result_count'] > 0:
                print(f"  ✅ {ai_functions['result_count']} AI functions found and ready")
            else:
                print(f"  ⚠️  AI functions may not be properly deployed")
        
        if 'check_audit_tables_exist' in validation:
            audit_tables = validation['check_audit_tables_exist']
            if audit_tables['success'] and audit_tables['result_count'] > 0:
                print(f"  ✅ {audit_tables['result_count']} audit tables found and ready")
            else:
                print(f"  ⚠️  Audit tables may not be properly configured")
    
    def save_results(self):
        """Save test results to file"""
        # Create results directory if it doesn't exist
        results_dir = TEST_CONFIG['output']['results_directory']
        os.makedirs(results_dir, exist_ok=True)
        
        # Generate filename with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(results_dir, f"ai_api_test_results_with_audit_{timestamp}.json")
        
        try:
            with open(filename, 'w') as f:
                json.dump(self.test_results, f, indent=2, default=str)
            print(f"\n💾 Test results saved to: {filename}")
        except Exception as e:
            print(f"\n❌ Failed to save results: {e}")
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            print("\n🔐 Database connection closed")

def main():
    """Main execution function"""
    print("🧪 AI API Comprehensive Testing Tool with Audit Trail Validation")
    print("=" * 70)
    
    # Initialize tester
    tester = AIAPITester()
    
    try:
        # Connect to database
        if not tester.connect_to_database():
            print("❌ Cannot proceed without database connection")
            return
        
        # Ask user which test categories to run
        print(f"\nAvailable test categories:")
        categories = list(TEST_CATEGORIES.keys())
        for i, category in enumerate(categories, 1):
            test_count = len(TEST_CATEGORIES[category])
            audit_note = " (includes audit validation)" if category == 'audit_trail_validation' else ""
            print(f"  {i}. {category} ({test_count} tests){audit_note}")
        
        print(f"  {len(categories) + 1}. All categories")
        
        try:
            choice = input(f"\nSelect category to run (1-{len(categories) + 1}) or press Enter for all: ").strip()
            
            if choice == "" or choice == str(len(categories) + 1):
                # Run all categories
                tester.run_all_tests()
            elif choice.isdigit() and 1 <= int(choice) <= len(categories):
                # Run specific category
                selected_category = categories[int(choice) - 1]
                tester.run_all_tests([selected_category])
            else:
                print("Invalid selection. Running all tests.")
                tester.run_all_tests()
                
        except KeyboardInterrupt:
            print("\n\n⚠️  Testing interrupted by user")
        
    except Exception as e:
        print(f"❌ Test execution failed: {e}")
        traceback.print_exc()
    finally:
        tester.close()

if __name__ == "__main__":
    main() 