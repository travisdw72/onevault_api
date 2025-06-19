#!/usr/bin/env python3
"""
Database Function and Procedure Analyzer
=========================================

This script provides comprehensive analysis of all database functions, procedures,
and their relationships in the One Vault Data Vault 2.0 system.

Features:
- Complete function inventory by schema
- Dependency analysis and call chains
- Security and compliance function identification
- Performance analysis functions
- API endpoint mapping
- Production readiness assessment

Usage:
    python database_function_analyzer.py --config config.yaml
    python database_function_analyzer.py --live-analysis
    python database_function_analyzer.py --export-report
"""

import psycopg2
import json
import yaml
import argparse
from datetime import datetime
from typing import Dict, List, Any, Optional
from collections import defaultdict
import re

class DatabaseFunctionAnalyzer:
    def __init__(self, config_file: str = None):
        """Initialize the database function analyzer"""
        self.config = self.load_config(config_file)
        self.connection = None
        self.analysis_results = {}
        
    def load_config(self, config_file: str) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        if config_file:
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        else:
            # Default configuration
            return {
                'database': {
                    'host': 'localhost',
                    'port': 5432,
                    'database': 'one_vault',
                    'user': 'postgres',
                    'password': None  # Will prompt or use env var
                },
                'analysis': {
                    'include_system_functions': False,
                    'analyze_dependencies': True,
                    'include_source_code': True,
                    'group_by_purpose': True
                },
                'output': {
                    'format': 'json',
                    'filename': f'database_functions_analysis_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json',
                    'include_metrics': True
                }
            }
    
    def connect_database(self) -> bool:
        """Establish database connection"""
        try:
            db_config = self.config['database']
            self.connection = psycopg2.connect(
                host=db_config['host'],
                port=db_config['port'],
                database=db_config['database'],
                user=db_config['user'],
                password=db_config.get('password') or input("Database password: ")
            )
            return True
        except Exception as e:
            print(f"Database connection failed: {e}")
            return False
    
    def get_all_functions_and_procedures(self) -> List[Dict[str, Any]]:
        """Get comprehensive list of all functions and procedures"""
        query = """
        SELECT 
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_arguments(p.oid) as arguments,
            pg_get_function_result(p.oid) as return_type,
            l.lanname as language,
            p.prokind as function_kind,
            pg_get_functiondef(p.oid) as source_code,
            pg_stat_get_function_calls(p.oid) as call_count,
            pg_stat_get_function_total_time(p.oid) as total_time_ms,
            pg_stat_get_function_self_time(p.oid) as self_time_ms,
            p.provolatile as volatility,
            p.proisstrict as is_strict,
            p.prosecdef as is_security_definer,
            r.rolname as owner,
            obj_description(p.oid, 'pg_proc') as description,
            p.oid as function_oid
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        JOIN pg_language l ON p.prolang = l.oid
        JOIN pg_roles r ON p.proowner = r.oid
        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
        ORDER BY n.nspname, p.proname;
        """
        
        cursor = self.connection.cursor()
        cursor.execute(query)
        
        columns = [desc[0] for desc in cursor.description]
        functions = []
        
        for row in cursor.fetchall():
            function_data = dict(zip(columns, row))
            
            # Classify function type
            function_data['function_type'] = self.classify_function_type(
                function_data['function_kind'],
                function_data['function_name'],
                function_data['schema_name']
            )
            
            # Classify function purpose
            function_data['purpose_category'] = self.classify_function_purpose(
                function_data['function_name'],
                function_data['schema_name'],
                function_data['source_code']
            )
            
            # Add dependency analysis
            if self.config['analysis']['analyze_dependencies']:
                function_data['dependencies'] = self.analyze_function_dependencies(
                    function_data['source_code']
                )
            
            functions.append(function_data)
        
        cursor.close()
        return functions
    
    def classify_function_type(self, function_kind: str, function_name: str, schema_name: str) -> str:
        """Classify function type based on PostgreSQL kind and naming patterns"""
        kind_mapping = {
            'f': 'function',
            'p': 'procedure', 
            'a': 'aggregate',
            'w': 'window_function'
        }
        
        base_type = kind_mapping.get(function_kind, 'unknown')
        
        # Add sub-classifications based on naming patterns
        if function_name.startswith('api_'):
            return f'api_{base_type}'
        elif function_name.startswith('auth_'):
            return f'auth_{base_type}'
        elif function_name.startswith('validate_'):
            return f'validation_{base_type}'
        elif function_name.startswith('trigger_'):
            return f'trigger_{base_type}'
        elif 'backup' in function_name.lower():
            return f'backup_{base_type}'
        elif 'monitor' in function_name.lower():
            return f'monitoring_{base_type}'
        
        return base_type
    
    def classify_function_purpose(self, function_name: str, schema_name: str, source_code: str) -> str:
        """Classify function purpose for business analysis"""
        # Schema-based classification
        schema_purposes = {
            'auth': 'authentication',
            'api': 'api_endpoint',
            'business': 'business_logic',
            'util': 'utility',
            'audit': 'compliance',
            'backup_mgmt': 'backup_recovery',
            'monitoring': 'system_monitoring',
            'ai_agents': 'ai_processing',
            'ai_monitoring': 'ai_monitoring',
            'data_quality': 'data_quality',
            'compliance': 'regulatory_compliance'
        }
        
        if schema_name in schema_purposes:
            return schema_purposes[schema_name]
        
        # Name-based classification
        name_lower = function_name.lower()
        
        if any(keyword in name_lower for keyword in ['login', 'auth', 'session', 'token']):
            return 'authentication'
        elif any(keyword in name_lower for keyword in ['backup', 'restore', 'recover']):
            return 'backup_recovery'
        elif any(keyword in name_lower for keyword in ['monitor', 'health', 'metric', 'alert']):
            return 'system_monitoring'
        elif any(keyword in name_lower for keyword in ['validate', 'check', 'verify']):
            return 'validation'
        elif any(keyword in name_lower for keyword in ['audit', 'log', 'track']):
            return 'compliance'
        elif any(keyword in name_lower for keyword in ['hash', 'encrypt', 'security']):
            return 'security'
        elif any(keyword in name_lower for keyword in ['tenant', 'isolation']):
            return 'multi_tenancy'
        elif any(keyword in name_lower for keyword in ['ai', 'ml', 'intelligence']):
            return 'artificial_intelligence'
        
        # Source code analysis for more complex classification
        if source_code:
            source_lower = source_code.lower()
            if 'hipaa' in source_lower or 'gdpr' in source_lower:
                return 'regulatory_compliance'
            elif 'data vault' in source_lower or 'hub' in source_lower or 'satellite' in source_lower:
                return 'data_vault_operations'
        
        return 'general_purpose'
    
    def analyze_function_dependencies(self, source_code: str) -> Dict[str, List[str]]:
        """Analyze function dependencies from source code"""
        if not source_code:
            return {'calls': [], 'schemas': [], 'tables': []}
        
        dependencies = {
            'calls': [],
            'schemas': [],
            'tables': []
        }
        
        # Extract function calls (schema.function_name pattern)
        function_calls = re.findall(r'(\w+)\.(\w+)\s*\(', source_code, re.IGNORECASE)
        for schema, function in function_calls:
            dependencies['calls'].append(f"{schema}.{function}")
            if schema not in dependencies['schemas']:
                dependencies['schemas'].append(schema)
        
        # Extract table references (FROM/JOIN schema.table pattern)
        table_refs = re.findall(r'(?:FROM|JOIN)\s+(\w+)\.(\w+)', source_code, re.IGNORECASE)
        for schema, table in table_refs:
            dependencies['tables'].append(f"{schema}.{table}")
            if schema not in dependencies['schemas']:
                dependencies['schemas'].append(schema)
        
        # Extract INSERT/UPDATE/DELETE table references
        dml_refs = re.findall(r'(?:INSERT INTO|UPDATE|DELETE FROM)\s+(\w+)\.(\w+)', source_code, re.IGNORECASE)
        for schema, table in dml_refs:
            dependencies['tables'].append(f"{schema}.{table}")
            if schema not in dependencies['schemas']:
                dependencies['schemas'].append(schema)
        
        # Remove duplicates
        dependencies['calls'] = list(set(dependencies['calls']))
        dependencies['schemas'] = list(set(dependencies['schemas']))
        dependencies['tables'] = list(set(dependencies['tables']))
        
        return dependencies
    
    def get_function_performance_stats(self) -> Dict[str, Any]:
        """Get performance statistics for functions"""
        query = """
        SELECT 
            n.nspname as schema_name,
            p.proname as function_name,
            pg_stat_get_function_calls(p.oid) as call_count,
            pg_stat_get_function_total_time(p.oid) as total_time_ms,
            pg_stat_get_function_self_time(p.oid) as self_time_ms,
            CASE 
                WHEN pg_stat_get_function_calls(p.oid) > 0 
                THEN pg_stat_get_function_total_time(p.oid) / pg_stat_get_function_calls(p.oid)
                ELSE 0 
            END as avg_time_per_call_ms
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
        AND pg_stat_get_function_calls(p.oid) > 0
        ORDER BY pg_stat_get_function_total_time(p.oid) DESC;
        """
        
        cursor = self.connection.cursor()
        cursor.execute(query)
        
        performance_stats = {
            'most_called': [],
            'most_time_consuming': [],
            'slowest_average': []
        }
        
        all_stats = cursor.fetchall()
        
        # Most called functions (top 10)
        sorted_by_calls = sorted(all_stats, key=lambda x: x[2], reverse=True)[:10]
        for stat in sorted_by_calls:
            performance_stats['most_called'].append({
                'schema': stat[0],
                'function': stat[1],
                'call_count': stat[2],
                'total_time_ms': stat[3],
                'avg_time_ms': stat[5]
            })
        
        # Most time consuming functions (top 10)
        sorted_by_time = sorted(all_stats, key=lambda x: x[3], reverse=True)[:10]
        for stat in sorted_by_time:
            performance_stats['most_time_consuming'].append({
                'schema': stat[0],
                'function': stat[1],
                'call_count': stat[2],
                'total_time_ms': stat[3],
                'avg_time_ms': stat[5]
            })
        
        # Slowest average functions (top 10)
        sorted_by_avg = sorted(all_stats, key=lambda x: x[5], reverse=True)[:10]
        for stat in sorted_by_avg:
            performance_stats['slowest_average'].append({
                'schema': stat[0],
                'function': stat[1],
                'call_count': stat[2],
                'total_time_ms': stat[3],
                'avg_time_ms': stat[5]
            })
        
        cursor.close()
        return performance_stats
    
    def analyze_api_endpoints(self, functions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze API endpoint functions"""
        api_functions = [f for f in functions if f['schema_name'] == 'api']
        
        endpoints = {
            'authentication': [],
            'business_operations': [],
            'admin_functions': [],
            'ai_operations': [],
            'monitoring': [],
            'other': []
        }
        
        for func in api_functions:
            name = func['function_name']
            
            if any(keyword in name.lower() for keyword in ['auth', 'login', 'session', 'token']):
                endpoints['authentication'].append(func)
            elif any(keyword in name.lower() for keyword in ['admin', 'reset', 'manage']):
                endpoints['admin_functions'].append(func)
            elif any(keyword in name.lower() for keyword in ['ai_', 'agent', 'chat']):
                endpoints['ai_operations'].append(func)
            elif any(keyword in name.lower() for keyword in ['monitor', 'alert', 'health']):
                endpoints['monitoring'].append(func)
            elif any(keyword in name.lower() for keyword in ['business', 'entity', 'transaction']):
                endpoints['business_operations'].append(func)
            else:
                endpoints['other'].append(func)
        
        return endpoints
    
    def analyze_compliance_functions(self, functions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze compliance and security functions"""
        compliance_analysis = {
            'hipaa_functions': [],
            'gdpr_functions': [],
            'audit_functions': [],
            'security_functions': [],
            'backup_functions': [],
            'monitoring_functions': []
        }
        
        for func in functions:
            name_lower = func['function_name'].lower()
            source_code = func.get('source_code', '').lower()
            schema = func['schema_name']
            
            # HIPAA related functions
            if 'hipaa' in source_code or schema == 'compliance' or 'phi' in name_lower:
                compliance_analysis['hipaa_functions'].append(func)
            
            # GDPR related functions
            if 'gdpr' in source_code or 'privacy' in name_lower or 'consent' in name_lower:
                compliance_analysis['gdpr_functions'].append(func)
            
            # Audit functions
            if schema == 'audit' or any(keyword in name_lower for keyword in ['audit', 'log', 'track']):
                compliance_analysis['audit_functions'].append(func)
            
            # Security functions
            if any(keyword in name_lower for keyword in ['security', 'auth', 'encrypt', 'hash']):
                compliance_analysis['security_functions'].append(func)
            
            # Backup functions
            if schema == 'backup_mgmt' or any(keyword in name_lower for keyword in ['backup', 'restore', 'recovery']):
                compliance_analysis['backup_functions'].append(func)
            
            # Monitoring functions
            if schema == 'monitoring' or any(keyword in name_lower for keyword in ['monitor', 'alert', 'health']):
                compliance_analysis['monitoring_functions'].append(func)
        
        return compliance_analysis
    
    def generate_schema_analysis(self, functions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate comprehensive schema analysis"""
        schema_stats = defaultdict(lambda: {
            'function_count': 0,
            'procedure_count': 0,
            'total_functions': 0,
            'purposes': defaultdict(int),
            'languages': defaultdict(int),
            'performance_stats': {
                'total_calls': 0,
                'total_time_ms': 0,
                'avg_function_calls': 0
            }
        })
        
        for func in functions:
            schema = func['schema_name']
            stats = schema_stats[schema]
            
            stats['total_functions'] += 1
            
            if func['function_kind'] == 'f':
                stats['function_count'] += 1
            elif func['function_kind'] == 'p':
                stats['procedure_count'] += 1
            
            stats['purposes'][func['purpose_category']] += 1
            stats['languages'][func['language']] += 1
            
            # Performance stats
            if func.get('call_count'):
                stats['performance_stats']['total_calls'] += func['call_count']
            if func.get('total_time_ms'):
                stats['performance_stats']['total_time_ms'] += func['total_time_ms']
        
        # Calculate averages
        for schema, stats in schema_stats.items():
            if stats['total_functions'] > 0:
                stats['performance_stats']['avg_function_calls'] = (
                    stats['performance_stats']['total_calls'] / stats['total_functions']
                )
        
        return dict(schema_stats)
    
    def generate_production_readiness_report(self, functions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate production readiness assessment"""
        readiness_report = {
            'critical_functions_status': {},
            'backup_recovery_readiness': False,
            'monitoring_readiness': False,
            'security_readiness': False,
            'api_readiness': False,
            'compliance_readiness': False,
            'missing_functions': [],
            'recommendations': []
        }
        
        # Check for critical production functions
        critical_functions = {
            'backup_mgmt.execute_backup': False,
            'backup_mgmt.restore_database': False,
            'monitoring.collect_system_metrics': False,
            'monitoring.create_alert': False,
            'auth.validate_session': False,
            'api.auth_login': False,
            'util.hash_binary': False
        }
        
        for func in functions:
            func_signature = f"{func['schema_name']}.{func['function_name']}"
            if func_signature in critical_functions:
                critical_functions[func_signature] = True
        
        readiness_report['critical_functions_status'] = critical_functions
        
        # Assess readiness by category
        schema_counts = defaultdict(int)
        for func in functions:
            schema_counts[func['schema_name']] += 1
        
        readiness_report['backup_recovery_readiness'] = schema_counts.get('backup_mgmt', 0) >= 5
        readiness_report['monitoring_readiness'] = schema_counts.get('monitoring', 0) >= 5
        readiness_report['security_readiness'] = schema_counts.get('auth', 0) >= 10
        readiness_report['api_readiness'] = schema_counts.get('api', 0) >= 15
        readiness_report['compliance_readiness'] = schema_counts.get('audit', 0) >= 5
        
        # Generate recommendations
        if not readiness_report['backup_recovery_readiness']:
            readiness_report['recommendations'].append(
                "Implement additional backup and recovery functions in backup_mgmt schema"
            )
        
        if not readiness_report['monitoring_readiness']:
            readiness_report['recommendations'].append(
                "Enhance monitoring capabilities with additional monitoring functions"
            )
        
        missing_critical = [func for func, exists in critical_functions.items() if not exists]
        if missing_critical:
            readiness_report['missing_functions'] = missing_critical
            readiness_report['recommendations'].append(
                f"Implement missing critical functions: {', '.join(missing_critical)}"
            )
        
        return readiness_report
    
    def run_comprehensive_analysis(self) -> Dict[str, Any]:
        """Run complete database function analysis"""
        print("🔍 Starting comprehensive database function analysis...")
        
        if not self.connect_database():
            return {"error": "Failed to connect to database"}
        
        # Get all functions and procedures
        print("📊 Collecting function inventory...")
        functions = self.get_all_functions_and_procedures()
        
        # Performance analysis
        print("⚡ Analyzing performance statistics...")
        performance_stats = self.get_function_performance_stats()
        
        # API endpoint analysis
        print("🌐 Analyzing API endpoints...")
        api_analysis = self.analyze_api_endpoints(functions)
        
        # Compliance analysis
        print("🛡️ Analyzing compliance functions...")
        compliance_analysis = self.analyze_compliance_functions(functions)
        
        # Schema analysis
        print("📈 Generating schema analysis...")
        schema_analysis = self.generate_schema_analysis(functions)
        
        # Production readiness
        print("🚀 Assessing production readiness...")
        production_readiness = self.generate_production_readiness_report(functions)
        
        # Compile complete analysis
        analysis_timestamp = datetime.now().isoformat()
        
        self.analysis_results = {
            'analysis_metadata': {
                'timestamp': analysis_timestamp,
                'total_functions': len(functions),
                'database_name': self.config['database']['database'],
                'analysis_version': '1.0.0'
            },
            'function_inventory': functions,
            'performance_statistics': performance_stats,
            'api_endpoint_analysis': api_analysis,
            'compliance_analysis': compliance_analysis,
            'schema_analysis': schema_analysis,
            'production_readiness': production_readiness,
            'summary': {
                'total_functions': len(functions),
                'total_schemas': len(schema_analysis),
                'api_endpoints': len([f for f in functions if f['schema_name'] == 'api']),
                'backup_functions': len([f for f in functions if f['schema_name'] == 'backup_mgmt']),
                'monitoring_functions': len([f for f in functions if f['schema_name'] == 'monitoring']),
                'auth_functions': len([f for f in functions if f['schema_name'] == 'auth']),
                'business_functions': len([f for f in functions if f['schema_name'] == 'business']),
                'ai_functions': len([f for f in functions if f['schema_name'].startswith('ai_')])
            }
        }
        
        self.connection.close()
        print("✅ Analysis completed successfully!")
        
        return self.analysis_results
    
    def export_analysis(self, format_type: str = 'json', filename: str = None) -> str:
        """Export analysis results to file"""
        if not self.analysis_results:
            raise ValueError("No analysis results to export. Run analysis first.")
        
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"database_functions_analysis_{timestamp}.{format_type}"
        
        if format_type.lower() == 'json':
            with open(filename, 'w') as f:
                json.dump(self.analysis_results, f, indent=2, default=str)
        elif format_type.lower() == 'yaml':
            with open(filename, 'w') as f:
                yaml.dump(self.analysis_results, f, default_flow_style=False)
        else:
            raise ValueError(f"Unsupported format: {format_type}")
        
        print(f"📄 Analysis exported to: {filename}")
        return filename
    
    def print_summary_report(self):
        """Print a formatted summary report"""
        if not self.analysis_results:
            print("No analysis results available.")
            return
        
        results = self.analysis_results
        summary = results['summary']
        production = results['production_readiness']
        
        print("\n" + "="*80)
        print("🏗️  ONE VAULT DATABASE FUNCTION ANALYSIS REPORT")
        print("="*80)
        
        print(f"\n📊 SUMMARY STATISTICS")
        print(f"   Total Functions: {summary['total_functions']}")
        print(f"   Total Schemas: {summary['total_schemas']}")
        print(f"   API Endpoints: {summary['api_endpoints']}")
        print(f"   Backup Functions: {summary['backup_functions']}")
        print(f"   Monitoring Functions: {summary['monitoring_functions']}")
        print(f"   Auth Functions: {summary['auth_functions']}")
        print(f"   Business Functions: {summary['business_functions']}")
        print(f"   AI Functions: {summary['ai_functions']}")
        
        print(f"\n🚀 PRODUCTION READINESS")
        print(f"   Backup/Recovery: {'✅' if production['backup_recovery_readiness'] else '❌'}")
        print(f"   Monitoring: {'✅' if production['monitoring_readiness'] else '❌'}")
        print(f"   Security: {'✅' if production['security_readiness'] else '❌'}")
        print(f"   API Layer: {'✅' if production['api_readiness'] else '❌'}")
        print(f"   Compliance: {'✅' if production['compliance_readiness'] else '❌'}")
        
        if production['missing_functions']:
            print(f"\n⚠️  MISSING CRITICAL FUNCTIONS:")
            for func in production['missing_functions']:
                print(f"   • {func}")
        
        if production['recommendations']:
            print(f"\n💡 RECOMMENDATIONS:")
            for i, rec in enumerate(production['recommendations'], 1):
                print(f"   {i}. {rec}")
        
        print("\n" + "="*80)


def main():
    """Main function with CLI interface"""
    parser = argparse.ArgumentParser(description='Database Function Analyzer for One Vault')
    parser.add_argument('--config', '-c', help='Configuration file path')
    parser.add_argument('--live-analysis', '-l', action='store_true', 
                       help='Run live database analysis')
    parser.add_argument('--export-format', '-f', choices=['json', 'yaml'], 
                       default='json', help='Export format')
    parser.add_argument('--export-file', '-o', help='Export filename')
    parser.add_argument('--summary-only', '-s', action='store_true',
                       help='Show summary report only')
    
    args = parser.parse_args()
    
    # Initialize analyzer
    analyzer = DatabaseFunctionAnalyzer(args.config)
    
    if args.live_analysis:
        # Run live analysis
        results = analyzer.run_comprehensive_analysis()
        
        if 'error' in results:
            print(f"❌ Error: {results['error']}")
            return 1
        
        # Show summary
        analyzer.print_summary_report()
        
        # Export results
        if not args.summary_only:
            analyzer.export_analysis(args.export_format, args.export_file)
    
    else:
        print("Use --live-analysis to run database analysis")
        print("Use --help for more options")
    
    return 0


if __name__ == "__main__":
    exit(main()) 