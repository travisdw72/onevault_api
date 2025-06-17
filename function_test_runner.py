#!/usr/bin/env python3
"""
Database Function Test Runner for One Vault Platform
Comprehensive testing framework for all database functions
"""

import psycopg2
import json
import yaml
import sys
import time
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple
import concurrent.futures
import threading
from dataclasses import dataclass, asdict
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('function_test_results.log'),
        logging.StreamHandler()
    ]
)

@dataclass
class TestResult:
    """Test result for a database function"""
    function_name: str
    schema_name: str
    test_status: str  # PASS, FAIL, SKIP, ERROR
    execution_time_ms: float
    error_message: Optional[str] = None
    parameters_used: Optional[str] = None
    return_value: Optional[str] = None
    test_timestamp: str = None
    
    def __post_init__(self):
        if self.test_timestamp is None:
            self.test_timestamp = datetime.now().isoformat()

class DatabaseFunctionTester:
    """Comprehensive database function testing framework"""
    
    def __init__(self, config_file: str = "config.yaml"):
        """Initialize the tester with configuration"""
        self.config = self._load_config(config_file)
        self.connection = None
        self.test_results: List[TestResult] = []
        self.lock = threading.Lock()
        
        # Test parameters for different function types
        self.test_parameters = {
            'tenant_hk': b'\\x1234567890abcdef' * 4,  # 32 bytes
            'user_hk': b'\\xabcdef1234567890' * 4,
            'session_hk': b'\\xfedcba0987654321' * 4,
            'email': 'test@example.com',
            'username': 'testuser',
            'password': 'TestPassword123!',
            'text_input': 'test_data',
            'integer_input': 42,
            'boolean_input': True,
            'json_input': '{"test": "data"}',
            'timestamp_input': datetime.now().isoformat(),
            'uuid_input': '12345678-1234-1234-1234-123456789012'
        }
    
    def _load_config(self, config_file: str) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            return {
                'database': {
                    'host': 'localhost',
                    'port': 5432,
                    'database': 'one_vault',
                    'user': 'postgres',
                    'password': None
                },
                'testing': {
                    'max_workers': 5,
                    'timeout_seconds': 30,
                    'skip_schemas': ['pg_catalog', 'information_schema'],
                    'test_mode': 'safe'  # safe, comprehensive, destructive
                }
            }
    
    def connect(self) -> None:
        """Establish database connection"""
        try:
            db_config = self.config['database']
            self.connection = psycopg2.connect(
                host=db_config['host'],
                port=db_config['port'],
                database=db_config['database'],
                user=db_config['user'],
                password=db_config.get('password') or ''
            )
            logging.info("Database connection established")
        except Exception as e:
            logging.error(f"Failed to connect to database: {e}")
            raise
    
    def get_all_functions(self) -> List[Dict[str, Any]]:
        """Retrieve all user-defined functions from the database"""
        if not self.connection:
            self.connect()
        
        skip_schemas = self.config['testing']['skip_schemas']
        skip_clause = "'" + "', '".join(skip_schemas) + "'"
        
        query = f"""
        SELECT 
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid) as arguments,
            pg_get_function_result(p.oid) as return_type,
            p.proisagg as is_aggregate,
            p.provolatile as volatility,
            d.description
        FROM pg_proc p
        LEFT JOIN pg_namespace n ON p.pronamespace = n.oid
        LEFT JOIN pg_description d ON p.oid = d.objoid
        WHERE n.nspname NOT IN ({skip_clause})
        AND p.prokind = 'f'  -- Only functions, not procedures
        ORDER BY n.nspname, p.proname;
        """
        
        with self.connection.cursor() as cursor:
            cursor.execute(query)
            columns = [desc[0] for desc in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
    
    def classify_function(self, func_info: Dict[str, Any]) -> str:
        """Classify function based on name and schema for appropriate testing"""
        schema = func_info['schema_name']
        name = func_info['function_name']
        
        # Classification logic
        if schema == 'auth':
            if any(keyword in name.lower() for keyword in ['login', 'register', 'create']):
                return 'auth_creation'
            elif any(keyword in name.lower() for keyword in ['validate', 'check']):
                return 'auth_validation'
            else:
                return 'auth_general'
        elif schema == 'util':
            return 'utility'
        elif schema == 'audit':
            return 'audit'
        elif any(keyword in name.lower() for keyword in ['hash', 'crypt', 'encrypt']):
            return 'security'
        elif 'api_' in name.lower():
            return 'api'
        else:
            return 'general'
    
    def generate_test_parameters(self, func_info: Dict[str, Any]) -> List[Any]:
        """Generate appropriate test parameters for a function"""
        arguments = func_info['arguments'] or ''
        
        # Parse arguments to determine parameter types
        params = []
        
        if not arguments.strip():
            return []
        
        # Simple parameter generation based on common patterns
        arg_parts = arguments.split(',')
        for arg in arg_parts:
            arg = arg.strip().lower()
            
            if 'bytea' in arg or '_hk' in arg:
                params.append(self.test_parameters['tenant_hk'])
            elif 'email' in arg:
                params.append(self.test_parameters['email'])
            elif 'username' in arg:
                params.append(self.test_parameters['username'])
            elif 'password' in arg:
                params.append(self.test_parameters['password'])
            elif 'text' in arg or 'varchar' in arg or 'character' in arg:
                params.append(self.test_parameters['text_input'])
            elif 'integer' in arg or 'int' in arg:
                params.append(self.test_parameters['integer_input'])
            elif 'boolean' in arg or 'bool' in arg:
                params.append(self.test_parameters['boolean_input'])
            elif 'json' in arg:
                params.append(self.test_parameters['json_input'])
            elif 'timestamp' in arg or 'date' in arg:
                params.append(self.test_parameters['timestamp_input'])
            else:
                # Default to text for unknown types
                params.append(self.test_parameters['text_input'])
        
        return params
    
    def test_function(self, func_info: Dict[str, Any]) -> TestResult:
        """Test a single database function"""
        schema = func_info['schema_name']
        name = func_info['function_name']
        full_name = f"{schema}.{name}"
        
        start_time = time.time()
        
        try:
            # Skip certain function types in safe mode
            if self.config['testing']['test_mode'] == 'safe':
                skip_patterns = ['delete', 'drop', 'truncate', 'destroy']
                if any(pattern in name.lower() for pattern in skip_patterns):
                    return TestResult(
                        function_name=name,
                        schema_name=schema,
                        test_status='SKIP',
                        execution_time_ms=0,
                        error_message='Skipped destructive function in safe mode'
                    )
            
            # Generate test parameters
            params = self.generate_test_parameters(func_info)
            
            # Create test query
            if params:
                placeholders = ', '.join(['%s'] * len(params))
                query = f"SELECT {full_name}({placeholders})"
            else:
                query = f"SELECT {full_name}()"
            
            # Execute the test
            with self.connection.cursor() as cursor:
                cursor.execute(query, params)
                result = cursor.fetchone()
                
                execution_time = (time.time() - start_time) * 1000
                
                return TestResult(
                    function_name=name,
                    schema_name=schema,
                    test_status='PASS',
                    execution_time_ms=execution_time,
                    parameters_used=str(params) if params else 'No parameters',
                    return_value=str(result[0]) if result else 'No return value'
                )
        
        except psycopg2.Error as e:
            execution_time = (time.time() - start_time) * 1000
            return TestResult(
                function_name=name,
                schema_name=schema,
                test_status='FAIL',
                execution_time_ms=execution_time,
                error_message=str(e),
                parameters_used=str(params) if 'params' in locals() else 'N/A'
            )
        
        except Exception as e:
            execution_time = (time.time() - start_time) * 1000
            return TestResult(
                function_name=name,
                schema_name=schema,
                test_status='ERROR',
                execution_time_ms=execution_time,
                error_message=str(e),
                parameters_used=str(params) if 'params' in locals() else 'N/A'
            )
    
    def run_tests(self, parallel: bool = True) -> List[TestResult]:
        """Run tests on all functions"""
        if not self.connection:
            self.connect()
        
        functions = self.get_all_functions()
        total_functions = len(functions)
        
        logging.info(f"Starting tests on {total_functions} functions...")
        
        if parallel:
            return self._run_tests_parallel(functions)
        else:
            return self._run_tests_sequential(functions)
    
    def _run_tests_sequential(self, functions: List[Dict[str, Any]]) -> List[TestResult]:
        """Run tests sequentially"""
        results = []
        
        for i, func_info in enumerate(functions, 1):
            logging.info(f"Testing {i}/{len(functions)}: {func_info['schema_name']}.{func_info['function_name']}")
            
            result = self.test_function(func_info)
            results.append(result)
            
            # Log result
            status_emoji = "✅" if result.test_status == "PASS" else "❌" if result.test_status == "FAIL" else "⏭️"
            logging.info(f"{status_emoji} {result.test_status}: {result.execution_time_ms:.2f}ms")
        
        return results
    
    def _run_tests_parallel(self, functions: List[Dict[str, Any]]) -> List[TestResult]:
        """Run tests in parallel (with separate connections)"""
        max_workers = self.config['testing']['max_workers']
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all test jobs
            future_to_func = {
                executor.submit(self._test_function_with_connection, func_info): func_info
                for func_info in functions
            }
            
            results = []
            completed = 0
            
            for future in concurrent.futures.as_completed(future_to_func):
                func_info = future_to_func[future]
                completed += 1
                
                try:
                    result = future.result(timeout=self.config['testing']['timeout_seconds'])
                    results.append(result)
                    
                    status_emoji = "✅" if result.test_status == "PASS" else "❌" if result.test_status == "FAIL" else "⏭️"
                    logging.info(f"{status_emoji} [{completed}/{len(functions)}] {func_info['schema_name']}.{func_info['function_name']}: {result.test_status}")
                
                except concurrent.futures.TimeoutError:
                    result = TestResult(
                        function_name=func_info['function_name'],
                        schema_name=func_info['schema_name'],
                        test_status='TIMEOUT',
                        execution_time_ms=self.config['testing']['timeout_seconds'] * 1000,
                        error_message='Function execution timed out'
                    )
                    results.append(result)
                    logging.warning(f"⏱️ TIMEOUT: {func_info['schema_name']}.{func_info['function_name']}")
                
                except Exception as e:
                    result = TestResult(
                        function_name=func_info['function_name'],
                        schema_name=func_info['schema_name'],
                        test_status='ERROR',
                        execution_time_ms=0,
                        error_message=str(e)
                    )
                    results.append(result)
                    logging.error(f"❌ ERROR: {func_info['schema_name']}.{func_info['function_name']}: {e}")
        
        return results
    
    def _test_function_with_connection(self, func_info: Dict[str, Any]) -> TestResult:
        """Test function with its own database connection (for parallel execution)"""
        conn = None
        try:
            # Create new connection for this thread
            db_config = self.config['database']
            conn = psycopg2.connect(
                host=db_config['host'],
                port=db_config['port'],
                database=db_config['database'],
                user=db_config['user'],
                password=db_config.get('password') or ''
            )
            
            # Temporarily replace connection for this test
            original_conn = self.connection
            self.connection = conn
            
            result = self.test_function(func_info)
            
            # Restore original connection
            self.connection = original_conn
            
            return result
            
        except Exception as e:
            return TestResult(
                function_name=func_info['function_name'],
                schema_name=func_info['schema_name'],
                test_status='CONNECTION_ERROR',
                execution_time_ms=0,
                error_message=f"Connection error: {str(e)}"
            )
        finally:
            if conn:
                conn.close()
    
    def generate_report(self, results: List[TestResult]) -> Dict[str, Any]:
        """Generate comprehensive test report"""
        total_tests = len(results)
        passed = sum(1 for r in results if r.test_status == 'PASS')
        failed = sum(1 for r in results if r.test_status == 'FAIL')
        skipped = sum(1 for r in results if r.test_status == 'SKIP')
        errors = sum(1 for r in results if r.test_status in ['ERROR', 'TIMEOUT', 'CONNECTION_ERROR'])
        
        # Calculate statistics
        execution_times = [r.execution_time_ms for r in results if r.test_status == 'PASS']
        avg_execution_time = sum(execution_times) / len(execution_times) if execution_times else 0
        max_execution_time = max(execution_times) if execution_times else 0
        
        # Schema breakdown
        schema_stats = {}
        for result in results:
            schema = result.schema_name
            if schema not in schema_stats:
                schema_stats[schema] = {'total': 0, 'passed': 0, 'failed': 0, 'errors': 0}
            
            schema_stats[schema]['total'] += 1
            if result.test_status == 'PASS':
                schema_stats[schema]['passed'] += 1
            elif result.test_status == 'FAIL':
                schema_stats[schema]['failed'] += 1
            else:
                schema_stats[schema]['errors'] += 1
        
        return {
            'test_summary': {
                'total_functions_tested': total_tests,
                'passed': passed,
                'failed': failed,
                'skipped': skipped,
                'errors': errors,
                'success_rate': round((passed / total_tests) * 100, 2) if total_tests > 0 else 0
            },
            'performance_stats': {
                'average_execution_time_ms': round(avg_execution_time, 2),
                'max_execution_time_ms': round(max_execution_time, 2),
                'total_execution_time_ms': round(sum(r.execution_time_ms for r in results), 2)
            },
            'schema_breakdown': schema_stats,
            'failed_functions': [
                {
                    'function': f"{r.schema_name}.{r.function_name}",
                    'error': r.error_message,
                    'status': r.test_status
                }
                for r in results if r.test_status in ['FAIL', 'ERROR', 'TIMEOUT']
            ],
            'test_timestamp': datetime.now().isoformat(),
            'config_used': self.config['testing']
        }
    
    def save_results(self, results: List[TestResult], report: Dict[str, Any]) -> None:
        """Save test results to files"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Save detailed results
        with open(f'function_test_results_{timestamp}.json', 'w') as f:
            json.dump([asdict(r) for r in results], f, indent=2)
        
        # Save summary report
        with open(f'function_test_report_{timestamp}.json', 'w') as f:
            json.dump(report, f, indent=2)
        
        logging.info(f"Results saved to function_test_results_{timestamp}.json")
        logging.info(f"Report saved to function_test_report_{timestamp}.json")
    
    def close(self) -> None:
        """Close database connection"""
        if self.connection:
            self.connection.close()
            logging.info("Database connection closed")


def main():
    """Main function to run the test suite"""
    print("🧪 One Vault Database Function Test Runner")
    print("==========================================")
    
    # Initialize tester
    tester = DatabaseFunctionTester()
    
    try:
        # Run tests
        results = tester.run_tests(parallel=True)
        
        # Generate and display report
        report = tester.generate_report(results)
        
        print(f"\n📊 TEST RESULTS SUMMARY")
        print(f"=====================")
        print(f"Total Functions Tested: {report['test_summary']['total_functions_tested']}")
        print(f"✅ Passed: {report['test_summary']['passed']}")
        print(f"❌ Failed: {report['test_summary']['failed']}")
        print(f"⏭️ Skipped: {report['test_summary']['skipped']}")
        print(f"🚨 Errors: {report['test_summary']['errors']}")
        print(f"Success Rate: {report['test_summary']['success_rate']}%")
        print(f"Average Execution Time: {report['performance_stats']['average_execution_time_ms']:.2f}ms")
        
        # Save results
        tester.save_results(results, report)
        
        # Show failed functions if any
        if report['failed_functions']:
            print(f"\n❌ FAILED FUNCTIONS:")
            for failed in report['failed_functions'][:10]:  # Show first 10
                print(f"  - {failed['function']}: {failed['error'][:100]}...")
        
        print(f"\n🎉 Testing complete! Check log files for detailed results.")
        
    except Exception as e:
        logging.error(f"Test suite failed: {e}")
        return 1
    
    finally:
        tester.close()
    
    return 0


if __name__ == "__main__":
    sys.exit(main()) 