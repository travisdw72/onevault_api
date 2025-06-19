#!/usr/bin/env python3
"""
AI API Endpoint Testing Script for One Vault
Tests all AI-related API endpoints using comprehensive test scenarios.
"""

import psycopg2
import psycopg2.extras
import json
import time
import os
import traceback
import getpass
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Any, Optional, Tuple
import random
import string

# Import configuration
from ai_api_test_config import (
    AI_API_TEST_QUERIES, 
    AI_VALIDATION_QUERIES, 
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
        
    def generate_test_session_id(self) -> str:
        """Generate unique test session ID"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        random_suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=6))
        return f"test_session_{timestamp}_{random_suffix}"
    
    def connect_to_database(self) -> bool:
        """Establish database connection"""
        print("🧪 AI API Endpoint Testing Tool")
        print("=" * 50)
        
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
    
    def validate_response_schema(self, response: Dict[str, Any], expected_fields: List[str], 
                               test_type: str) -> Dict[str, Any]:
        """Validate response against expected schema"""
        validation_result = {
            'schema_valid': True,
            'missing_fields': [],
            'unexpected_fields': [],
            'field_type_errors': [],
            'validation_score': 0
        }
        
        # Check required fields
        for field in expected_fields:
            if field not in response:
                validation_result['missing_fields'].append(field)
                validation_result['schema_valid'] = False
        
        # Get expected schema based on test type
        schema_mapping = {
            'functional': 'ai_chat_response',
            'security': 'error_response',
            'error_handling': 'error_response',
            'health_check': 'ai_monitoring_response',
            'performance': 'ai_monitoring_response'
        }
        
        schema_name = schema_mapping.get(test_type, 'ai_chat_response')
        expected_schema = RESPONSE_SCHEMAS.get(schema_name, {})
        
        # Validate data types if schema exists
        if 'data_types' in expected_schema:
            for field, expected_type in expected_schema['data_types'].items():
                if field in response:
                    actual_value = response[field]
                    if not isinstance(actual_value, expected_type):
                        validation_result['field_type_errors'].append({
                            'field': field,
                            'expected_type': expected_type.__name__,
                            'actual_type': type(actual_value).__name__,
                            'actual_value': actual_value
                        })
        
        # Calculate validation score
        total_checks = len(expected_fields) + len(expected_schema.get('data_types', {}))
        failed_checks = (len(validation_result['missing_fields']) + 
                        len(validation_result['field_type_errors']))
        
        if total_checks > 0:
            validation_result['validation_score'] = max(0, (total_checks - failed_checks) / total_checks * 100)
        
        return validation_result
    
    def run_single_test(self, test_name: str, test_config: Dict[str, Any]) -> Dict[str, Any]:
        """Run a single API test"""
        print(f"  🧪 Running test: {test_name}")
        
        test_result = {
            'test_name': test_name,
            'description': test_config['description'],
            'function': test_config['function'],
            'test_type': test_config['test_type'],
            'start_time': datetime.now().isoformat(),
            'success': False,
            'response': {},
            'validation': {},
            'errors': [],
            'execution_time_ms': 0,
            'retry_attempts': 0
        }
        
        start_time = time.time()
        
        try:
            # Handle special test types
            if test_config['test_type'] == 'performance' and 'concurrent_sessions' in test_config:
                test_result = self.run_concurrent_test(test_name, test_config)
            elif test_config['test_type'] == 'performance' and 'batch_size' in test_config:
                test_result = self.run_batch_test(test_name, test_config)
            elif test_config['test_type'] == 'rate_limiting' and 'repeat_count' in test_config:
                test_result = self.run_rate_limit_test(test_name, test_config)
            else:
                # Standard single test execution
                test_result = self.run_standard_test(test_name, test_config)
            
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
        
        if not test_result['success'] and test_result['errors']:
            print(f"    ⚠️  Error: {test_result['errors'][0].get('error_message', 'Unknown error')}")
        
        return test_result
    
    def run_standard_test(self, test_name: str, test_config: Dict[str, Any]) -> Dict[str, Any]:
        """Run a standard single API test"""
        test_result = {
            'test_name': test_name,
            'description': test_config['description'],
            'function': test_config['function'],
            'test_type': test_config['test_type'],
            'success': False,
            'response': {},
            'validation': {},
            'errors': []
        }
        
        # Prepare test data
        test_data = test_config['test_data'].copy()
        
        # Replace placeholder values
        test_data = self.replace_placeholders(test_data, {'session_id': '1'})
        
        # Execute API function with retries
        max_retries = TEST_CONFIG['test_execution']['retry_attempts']
        retry_delay = TEST_CONFIG['test_execution']['retry_delay_seconds']
        
        for attempt in range(max_retries + 1):
            success, response = self.execute_api_function(test_config['function'], test_data)
            
            if success:
                test_result['success'] = True
                test_result['response'] = response
                
                # Validate response schema
                expected_fields = test_config.get('expected_fields', [])
                validation = self.validate_response_schema(
                    response, expected_fields, test_config['test_type']
                )
                test_result['validation'] = validation
                
                # Check if this is an expected failure test
                expected_success = test_config.get('expected_success', True)
                if not expected_success:
                    # For tests that should fail, success means getting a proper error response
                    test_result['success'] = not response.get('success', True)
                
                break
            else:
                test_result['errors'].append({
                    'attempt': attempt + 1,
                    'error_type': 'api_execution_error',
                    'error_details': response
                })
                
                if attempt < max_retries:
                    time.sleep(retry_delay)
        
        return test_result
    
    def run_concurrent_test(self, test_name: str, test_config: Dict[str, Any]) -> Dict[str, Any]:
        """Run concurrent session tests"""
        test_result = {
            'test_name': test_name,
            'description': test_config['description'],
            'function': test_config['function'],
            'test_type': 'performance_concurrent',
            'success': False,
            'concurrent_results': [],
            'performance_metrics': {},
            'errors': []
        }
        
        concurrent_sessions = test_config.get('concurrent_sessions', 5)
        
        def run_concurrent_session(session_id):
            test_data = test_config['test_data'].copy()
            test_data = self.replace_placeholders(test_data, {'session_id': str(session_id)})
            
            start_time = time.time()
            success, response = self.execute_api_function(test_config['function'], test_data)
            execution_time = time.time() - start_time
            
            return {
                'session_id': session_id,
                'success': success,
                'response': response,
                'execution_time_ms': round(execution_time * 1000, 2)
            }
        
        # Execute concurrent tests
        with ThreadPoolExecutor(max_workers=concurrent_sessions) as executor:
            futures = [executor.submit(run_concurrent_session, i) 
                      for i in range(concurrent_sessions)]
            
            for future in as_completed(futures):
                try:
                    result = future.result()
                    test_result['concurrent_results'].append(result)
                except Exception as e:
                    test_result['errors'].append({
                        'error_type': 'concurrent_execution_error',
                        'error_message': str(e)
                    })
        
        # Calculate performance metrics
        successful_tests = [r for r in test_result['concurrent_results'] if r['success']]
        if successful_tests:
            execution_times = [r['execution_time_ms'] for r in successful_tests]
            test_result['performance_metrics'] = {
                'total_sessions': concurrent_sessions,
                'successful_sessions': len(successful_tests),
                'success_rate': len(successful_tests) / concurrent_sessions * 100,
                'avg_execution_time_ms': sum(execution_times) / len(execution_times),
                'min_execution_time_ms': min(execution_times),
                'max_execution_time_ms': max(execution_times)
            }
            test_result['success'] = len(successful_tests) >= concurrent_sessions * 0.8  # 80% success rate
        
        return test_result
    
    def run_batch_test(self, test_name: str, test_config: Dict[str, Any]) -> Dict[str, Any]:
        """Run batch insertion tests"""
        test_result = {
            'test_name': test_name,
            'description': test_config['description'],
            'function': test_config['function'],
            'test_type': 'performance_batch',
            'success': False,
            'batch_results': [],
            'performance_metrics': {},
            'errors': []
        }
        
        batch_size = test_config.get('batch_size', 20)
        
        # Execute batch operations
        start_time = time.time()
        successful_operations = 0
        
        for i in range(batch_size):
            test_data = test_config['test_data'].copy()
            test_data = self.replace_placeholders(test_data, {
                'batch_num': str(i),
                'random_value': str(random.randint(1, 1000))
            })
            
            success, response = self.execute_api_function(test_config['function'], test_data)
            
            batch_result = {
                'batch_number': i,
                'success': success,
                'response': response
            }
            test_result['batch_results'].append(batch_result)
            
            if success:
                successful_operations += 1
        
        total_time = time.time() - start_time
        
        # Calculate performance metrics
        test_result['performance_metrics'] = {
            'total_operations': batch_size,
            'successful_operations': successful_operations,
            'success_rate': successful_operations / batch_size * 100,
            'total_execution_time_ms': round(total_time * 1000, 2),
            'avg_operation_time_ms': round(total_time / batch_size * 1000, 2),
            'operations_per_second': round(batch_size / total_time, 2)
        }
        
        test_result['success'] = successful_operations >= batch_size * 0.9  # 90% success rate
        
        return test_result
    
    def run_rate_limit_test(self, test_name: str, test_config: Dict[str, Any]) -> Dict[str, Any]:
        """Run rate limiting tests"""
        test_result = {
            'test_name': test_name,
            'description': test_config['description'],
            'function': test_config['function'],
            'test_type': 'rate_limiting',
            'success': False,
            'rate_limit_results': [],
            'rate_limit_detected': False,
            'errors': []
        }
        
        repeat_count = test_config.get('repeat_count', 10)
        
        # Execute rapid requests
        for i in range(repeat_count):
            start_time = time.time()
            success, response = self.execute_api_function(test_config['function'], test_config['test_data'])
            execution_time = time.time() - start_time
            
            result = {
                'request_number': i + 1,
                'success': success,
                'response': response,
                'execution_time_ms': round(execution_time * 1000, 2)
            }
            
            # Check for rate limiting indicators
            if response and ('rate_limit' in str(response).lower() or 'too many requests' in str(response).lower()):
                test_result['rate_limit_detected'] = True
                result['rate_limited'] = True
            
            test_result['rate_limit_results'].append(result)
            
            # Small delay between requests
            time.sleep(0.1)
        
        # Test succeeds if rate limiting is properly implemented
        test_result['success'] = test_result['rate_limit_detected']
        
        return test_result
    
    def replace_placeholders(self, data: Any, replacements: Dict[str, str]) -> Any:
        """Replace placeholder values in test data"""
        if isinstance(data, dict):
            return {k: self.replace_placeholders(v, replacements) for k, v in data.items()}
        elif isinstance(data, list):
            return [self.replace_placeholders(item, replacements) for item in data]
        elif isinstance(data, str):
            for placeholder, value in replacements.items():
                data = data.replace(f'{{{placeholder}}}', value)
            return data
        else:
            return data
    
    def run_validation_queries(self):
        """Run database validation queries"""
        print("\n🔍 Running Database Validation Queries...")
        
        validation_results = {}
        
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
                    
            except psycopg2.Error as e:
                validation_results[query_name] = {
                    'success': False,
                    'error': str(e),
                    'error_code': e.pgcode if hasattr(e, 'pgcode') else 'UNKNOWN'
                }
                print(f"    ❌ Error: {str(e)}")
        
        return validation_results
    
    def run_test_category(self, category_name: str, test_names: List[str]) -> Dict[str, Any]:
        """Run a category of tests"""
        print(f"\n🧪 Running Test Category: {category_name.upper()}")
        print("-" * 50)
        
        category_results = {
            'category_name': category_name,
            'total_tests': len(test_names),
            'successful_tests': 0,
            'failed_tests': 0,
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
            else:
                print(f"  ⚠️  Test '{test_name}' not found in configuration")
        
        category_results['end_time'] = datetime.now().isoformat()
        category_results['success_rate'] = (category_results['successful_tests'] / 
                                          category_results['total_tests'] * 100) if category_results['total_tests'] > 0 else 0
        
        print(f"\n📊 Category Summary: {category_results['successful_tests']}/{category_results['total_tests']} tests passed " +
              f"({category_results['success_rate']:.1f}%)")
        
        return category_results
    
    def run_all_tests(self, categories: Optional[List[str]] = None):
        """Run all or specified test categories"""
        print(f"🚀 Starting AI API Comprehensive Testing")
        print(f"Session ID: {self.test_session_id}")
        print("=" * 60)
        
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
            'overall_summary': {}
        }
        
        total_tests = 0
        total_successful = 0
        
        # Run each test category
        for category_name in categories_to_run:
            test_names = TEST_CATEGORIES[category_name]
            category_result = self.run_test_category(category_name, test_names)
            all_results['test_categories'][category_name] = category_result
            
            total_tests += category_result['total_tests']
            total_successful += category_result['successful_tests']
        
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
        
        self.test_results = all_results
        
        # Print final summary
        self.print_final_summary()
        
        # Save results
        if TEST_CONFIG['output']['save_results']:
            self.save_results()
    
    def print_final_summary(self):
        """Print comprehensive test summary"""
        print("\n" + "=" * 60)
        print("📊 COMPREHENSIVE AI API TEST SUMMARY")
        print("=" * 60)
        
        summary = self.test_results['overall_summary']
        
        print(f"🧪 Total Tests: {summary['total_tests']}")
        print(f"✅ Successful: {summary['successful_tests']}")
        print(f"❌ Failed: {summary['failed_tests']}")
        print(f"📈 Success Rate: {summary['overall_success_rate']:.1f}%")
        print(f"⏱️  Total Time: {summary['total_execution_time']}")
        
        print(f"\n📋 Category Breakdown:")
        for category_name, category_result in self.test_results['test_categories'].items():
            success_rate = category_result['success_rate']
            status = "✅" if success_rate >= 80 else "⚠️" if success_rate >= 60 else "❌"
            print(f"  {status} {category_name}: {category_result['successful_tests']}/{category_result['total_tests']} " +
                  f"({success_rate:.1f}%)")
        
        # Database validation summary
        validation = self.test_results['database_validation']
        validation_passed = sum(1 for v in validation.values() if v.get('success', False))
        validation_total = len(validation)
        print(f"\n🔍 Database Validation: {validation_passed}/{validation_total} checks passed")
        
        # Performance insights
        print(f"\n⚡ Performance Insights:")
        self.print_performance_insights()
        
        # Recommendations
        print(f"\n💡 Recommendations:")
        self.print_recommendations()
    
    def print_performance_insights(self):
        """Print performance analysis"""
        all_execution_times = []
        
        for category_result in self.test_results['test_categories'].values():
            for test_result in category_result['test_results']:
                if 'execution_time_ms' in test_result:
                    all_execution_times.append(test_result['execution_time_ms'])
        
        if all_execution_times:
            avg_time = sum(all_execution_times) / len(all_execution_times)
            max_time = max(all_execution_times)
            min_time = min(all_execution_times)
            
            print(f"  📊 Average Response Time: {avg_time:.1f}ms")
            print(f"  ⚡ Fastest Response: {min_time:.1f}ms")
            print(f"  🐌 Slowest Response: {max_time:.1f}ms")
            
            if max_time > 5000:  # 5 seconds
                print(f"  ⚠️  Some responses are slow (>{max_time:.1f}ms) - consider optimization")
    
    def print_recommendations(self):
        """Print recommendations based on test results"""
        summary = self.test_results['overall_summary']
        
        if summary['overall_success_rate'] >= 90:
            print("  ✅ Excellent! All AI API endpoints are functioning well")
        elif summary['overall_success_rate'] >= 75:
            print("  ⚠️  Most endpoints work, but some issues need attention")
        else:
            print("  🚨 Multiple endpoint failures detected - investigation required")
        
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
    
    def save_results(self):
        """Save test results to file"""
        # Create results directory if it doesn't exist
        results_dir = TEST_CONFIG['output']['results_directory']
        os.makedirs(results_dir, exist_ok=True)
        
        # Generate filename with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(results_dir, f"ai_api_test_results_{timestamp}.json")
        
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
    print("🧪 AI API Comprehensive Testing Tool")
    print("=" * 50)
    
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
            print(f"  {i}. {category} ({test_count} tests)")
        
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