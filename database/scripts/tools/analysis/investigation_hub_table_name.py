#!/usr/bin/env python3
"""
Hub Table Naming Investigation Script
=====================================

This script performs a comprehensive analysis of Data Vault 2.0 hub table naming compliance
in the One Vault platform, identifying specific naming issues and providing actionable
recommendations for improvement.

Author: One Vault Development Team
Date: 2025-01-15
Version: 1.0.0
"""

import psycopg2
import json
import os
from datetime import datetime
from typing import List, Dict, Any, Tuple, Optional
import re

class HubTableNamingInvestigator:
    """Comprehensive hub table naming compliance analyzer"""
    
    def __init__(self):
        self.conn = None
        self.results = {}
        self.naming_rules = self._define_naming_rules()
        
    def _define_naming_rules(self) -> Dict[str, Any]:
        """Define Data Vault 2.0 hub table naming rules"""
        return {
            'hub_suffix': {
                'pattern': r'_h$',
                'description': 'Hub tables must end with _h suffix',
                'weight': 25,
                'examples': ['user_h', 'tenant_h', 'asset_h']
            },
            'business_key_column': {
                'pattern': r'(.+)_bk$',
                'description': 'Hub tables must have a business key column ending with _bk',
                'weight': 25,
                'examples': ['user_bk', 'tenant_bk', 'asset_bk']
            },
            'hash_key_column': {
                'pattern': r'(.+)_hk$',
                'description': 'Hub tables must have a hash key column ending with _hk',
                'weight': 20,
                'examples': ['user_hk', 'tenant_hk', 'asset_hk']
            },
            'tenant_isolation': {
                'column_name': 'tenant_hk',
                'description': 'Hub tables must include tenant_hk for multi-tenant isolation',
                'weight': 15,
                'required': True
            },
            'load_date_column': {
                'column_name': 'load_date',
                'description': 'Hub tables must include load_date for temporal tracking',
                'weight': 10,
                'required': True
            },
            'record_source_column': {
                'column_name': 'record_source',
                'description': 'Hub tables must include record_source for data lineage',
                'weight': 5,
                'required': True
            }
        }
    
    def connect_to_database(self) -> bool:
        """Establish database connection"""
        try:
            self.conn = psycopg2.connect(
                host="localhost",
                port=5432,
                database="one_vault",
                user="postgres",
                password=os.getenv('DB_PASSWORD', 'password')
            )
            print("✅ Connected to database successfully")
            return True
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def execute_query(self, query: str, description: str) -> List[Tuple]:
        """Execute SQL query with error handling"""
        try:
            cursor = self.conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
            cursor.close()
            print(f"✅ {description}: Found {len(results)} items")
            return results
        except Exception as e:
            print(f"❌ Error in {description}: {e}")
            return []
    
    def get_all_hub_tables(self) -> List[Tuple]:
        """Get all hub tables from the database"""
        query = """
        SELECT 
            schemaname,
            tablename,
            tableowner
        FROM pg_tables 
        WHERE tablename LIKE '%_h'
        AND schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
        ORDER BY schemaname, tablename;
        """
        return self.execute_query(query, "Hub tables discovery")
    
    def get_table_columns(self, schema: str, table: str) -> List[Tuple]:
        """Get column information for a specific table"""
        query = """
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default,
            character_maximum_length
        FROM information_schema.columns 
        WHERE table_schema = %s 
        AND table_name = %s
        ORDER BY ordinal_position;
        """
        try:
            cursor = self.conn.cursor()
            cursor.execute(query, (schema, table))
            results = cursor.fetchall()
            cursor.close()
            return results
        except Exception as e:
            print(f"❌ Error getting columns for {schema}.{table}: {e}")
            return []
    
    def get_table_constraints(self, schema: str, table: str) -> List[Tuple]:
        """Get constraint information for a specific table"""
        query = """
        SELECT 
            tc.constraint_name,
            tc.constraint_type,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name
        FROM information_schema.table_constraints tc
        LEFT JOIN information_schema.key_column_usage kcu 
            ON tc.constraint_name = kcu.constraint_name
        LEFT JOIN information_schema.constraint_column_usage ccu 
            ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_schema = %s 
        AND tc.table_name = %s;
        """
        try:
            cursor = self.conn.cursor()
            cursor.execute(query, (schema, table))
            results = cursor.fetchall()
            cursor.close()
            return results
        except Exception as e:
            print(f"❌ Error getting constraints for {schema}.{table}: {e}")
            return []
    
    def analyze_hub_table_naming(self, schema: str, table: str) -> Dict[str, Any]:
        """Analyze naming compliance for a single hub table"""
        analysis = {
            'schema': schema,
            'table': table,
            'full_name': f"{schema}.{table}",
            'compliance_score': 0,
            'max_score': 100,
            'rule_results': {},
            'issues': [],
            'recommendations': []
        }
        
        # Get table structure
        columns = self.get_table_columns(schema, table)
        constraints = self.get_table_constraints(schema, table)
        
        column_names = [col[0] for col in columns]
        column_info = {col[0]: {
            'data_type': col[1],
            'is_nullable': col[2],
            'default': col[3],
            'max_length': col[4]
        } for col in columns}
        
        # Analyze each naming rule
        for rule_name, rule_config in self.naming_rules.items():
            rule_result = self._analyze_naming_rule(
                rule_name, rule_config, table, column_names, column_info, constraints
            )
            analysis['rule_results'][rule_name] = rule_result
            
            if rule_result['compliant']:
                analysis['compliance_score'] += rule_config['weight']
            else:
                analysis['issues'].extend(rule_result['issues'])
                analysis['recommendations'].extend(rule_result['recommendations'])
        
        # Calculate compliance percentage
        analysis['compliance_percentage'] = (analysis['compliance_score'] / analysis['max_score']) * 100
        
        return analysis
    
    def _analyze_naming_rule(self, rule_name: str, rule_config: Dict[str, Any], 
                           table_name: str, column_names: List[str], 
                           column_info: Dict[str, Any], constraints: List[Tuple]) -> Dict[str, Any]:
        """Analyze a specific naming rule"""
        result = {
            'rule_name': rule_name,
            'compliant': False,
            'score': 0,
            'max_score': rule_config['weight'],
            'issues': [],
            'recommendations': [],
            'details': {}
        }
        
        if rule_name == 'hub_suffix':
            # Check if table name ends with _h
            if re.search(rule_config['pattern'], table_name):
                result['compliant'] = True
                result['score'] = rule_config['weight']
                result['details']['suffix_correct'] = True
            else:
                result['issues'].append(f"Table '{table_name}' does not end with '_h' suffix")
                result['recommendations'].append(f"Rename table to '{table_name}_h' to follow Data Vault 2.0 hub naming convention")
                result['details']['suffix_correct'] = False
        
        elif rule_name == 'business_key_column':
            # Check for business key column
            expected_bk = table_name.replace('_h', '_bk')
            bk_columns = [col for col in column_names if col.endswith('_bk')]
            
            if expected_bk in column_names:
                result['compliant'] = True
                result['score'] = rule_config['weight']
                result['details']['business_key_found'] = expected_bk
            elif bk_columns:
                result['compliant'] = True
                result['score'] = rule_config['weight'] * 0.8  # Partial credit
                result['details']['business_key_found'] = bk_columns[0]
                result['issues'].append(f"Business key column '{bk_columns[0]}' doesn't match expected name '{expected_bk}'")
                result['recommendations'].append(f"Consider renaming '{bk_columns[0]}' to '{expected_bk}' for consistency")
            else:
                result['issues'].append(f"No business key column found (expected '{expected_bk}')")
                result['recommendations'].append(f"Add business key column '{expected_bk}' of type VARCHAR(255)")
                result['details']['business_key_found'] = None
        
        elif rule_name == 'hash_key_column':
            # Check for hash key column
            expected_hk = table_name.replace('_h', '_hk')
            hk_columns = [col for col in column_names if col.endswith('_hk')]
            
            if expected_hk in column_names:
                result['compliant'] = True
                result['score'] = rule_config['weight']
                result['details']['hash_key_found'] = expected_hk
                
                # Check data type
                if column_info[expected_hk]['data_type'] == 'bytea':
                    result['details']['hash_key_type_correct'] = True
                else:
                    result['issues'].append(f"Hash key '{expected_hk}' should be BYTEA, found {column_info[expected_hk]['data_type']}")
                    result['recommendations'].append(f"Change '{expected_hk}' data type to BYTEA for optimal performance")
                    result['score'] *= 0.9  # Small penalty for wrong type
            elif hk_columns:
                result['compliant'] = True
                result['score'] = rule_config['weight'] * 0.8  # Partial credit
                result['details']['hash_key_found'] = hk_columns[0]
                result['issues'].append(f"Hash key column '{hk_columns[0]}' doesn't match expected name '{expected_hk}'")
                result['recommendations'].append(f"Consider renaming '{hk_columns[0]}' to '{expected_hk}' for consistency")
            else:
                result['issues'].append(f"No hash key column found (expected '{expected_hk}')")
                result['recommendations'].append(f"Add hash key column '{expected_hk}' of type BYTEA as PRIMARY KEY")
                result['details']['hash_key_found'] = None
        
        elif rule_name in ['tenant_isolation', 'load_date_column', 'record_source_column']:
            # Check for required columns
            required_column = rule_config['column_name']
            
            if required_column in column_names:
                result['compliant'] = True
                result['score'] = rule_config['weight']
                result['details']['column_found'] = True
                result['details']['column_info'] = column_info[required_column]
                
                # Additional checks for specific columns
                if rule_name == 'tenant_isolation':
                    if column_info[required_column]['data_type'] != 'bytea':
                        result['issues'].append(f"Column '{required_column}' should be BYTEA, found {column_info[required_column]['data_type']}")
                        result['recommendations'].append(f"Change '{required_column}' data type to BYTEA")
                        result['score'] *= 0.9
                
                elif rule_name == 'load_date_column':
                    if 'timestamp' not in column_info[required_column]['data_type']:
                        result['issues'].append(f"Column '{required_column}' should be TIMESTAMP WITH TIME ZONE")
                        result['recommendations'].append(f"Change '{required_column}' data type to TIMESTAMP WITH TIME ZONE")
                        result['score'] *= 0.9
                
            else:
                result['issues'].append(f"Required column '{required_column}' not found")
                result['recommendations'].append(f"Add column '{required_column}' for {rule_config['description']}")
                result['details']['column_found'] = False
        
        # Add special cases for session tables
        if rule_name == 'business_key_column' and 'session' in table_name:
            if 'session_token' in column_names:
                result['compliant'] = True
                result['score'] = rule_config['weight']
                result['details']['business_key_found'] = 'session_token'
                return result
        
        if rule_name == 'tenant_isolation' and 'session' in table_name:
            # Sessions have implicit tenant isolation via hash key derivation
            if any(col.endswith('_hk') for col in column_names):
                result['compliant'] = True
                result['score'] = rule_config['weight']
                result['details']['implicit_tenant_isolation'] = True
                return result
        
        return result
    
    def generate_compliance_report(self) -> Dict[str, Any]:
        """Generate comprehensive compliance report"""
        print("\n🔍 ANALYZING HUB TABLE NAMING COMPLIANCE...")
        
        hub_tables = self.get_all_hub_tables()
        
        if not hub_tables:
            return {
                'error': 'No hub tables found',
                'total_tables': 0,
                'analyses': []
            }
        
        analyses = []
        total_score = 0
        total_max_score = 0
        
        for schema, table, owner in hub_tables:
            print(f"\n📊 Analyzing {schema}.{table}...")
            analysis = self.analyze_hub_table_naming(schema, table)
            analyses.append(analysis)
            
            total_score += analysis['compliance_score']
            total_max_score += analysis['max_score']
            
            # Print summary for this table
            compliance_pct = analysis['compliance_percentage']
            status = "✅" if compliance_pct >= 90 else "⚠️" if compliance_pct >= 70 else "❌"
            print(f"   {status} Compliance: {compliance_pct:.1f}% ({analysis['compliance_score']}/{analysis['max_score']} points)")
            
            if analysis['issues']:
                print(f"   🚨 Issues: {len(analysis['issues'])}")
                for issue in analysis['issues'][:3]:  # Show first 3 issues
                    print(f"      • {issue}")
        
        # Calculate overall statistics
        overall_compliance = (total_score / total_max_score * 100) if total_max_score > 0 else 0
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'total_tables': len(hub_tables),
            'overall_compliance_percentage': overall_compliance,
            'total_score': total_score,
            'total_max_score': total_max_score,
            'analyses': analyses,
            'summary_by_rule': self._generate_rule_summary(analyses),
            'recommendations': self._generate_overall_recommendations(analyses)
        }
        
        return report
    
    def _generate_rule_summary(self, analyses: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate summary statistics by rule"""
        rule_summary = {}
        
        for rule_name in self.naming_rules.keys():
            compliant_count = 0
            total_score = 0
            total_max_score = 0
            issues = []
            
            for analysis in analyses:
                rule_result = analysis['rule_results'][rule_name]
                if rule_result['compliant']:
                    compliant_count += 1
                total_score += rule_result['score']
                total_max_score += rule_result['max_score']
                issues.extend(rule_result['issues'])
            
            rule_summary[rule_name] = {
                'description': self.naming_rules[rule_name]['description'],
                'compliant_tables': compliant_count,
                'total_tables': len(analyses),
                'compliance_percentage': (compliant_count / len(analyses) * 100) if analyses else 0,
                'score_percentage': (total_score / total_max_score * 100) if total_max_score > 0 else 0,
                'total_issues': len(issues),
                'weight': self.naming_rules[rule_name]['weight']
            }
        
        return rule_summary
    
    def _generate_overall_recommendations(self, analyses: List[Dict[str, Any]]) -> List[str]:
        """Generate overall recommendations for improvement"""
        recommendations = []
        
        # Count issues by type
        issue_counts = {}
        for analysis in analyses:
            for issue in analysis['issues']:
                issue_type = self._categorize_issue(issue)
                issue_counts[issue_type] = issue_counts.get(issue_type, 0) + 1
        
        # Generate recommendations based on most common issues
        if issue_counts.get('missing_business_key', 0) > 0:
            recommendations.append(f"🔑 Add business key columns to {issue_counts['missing_business_key']} hub tables")
        
        if issue_counts.get('missing_hash_key', 0) > 0:
            recommendations.append(f"🔐 Add hash key columns to {issue_counts['missing_hash_key']} hub tables")
        
        if issue_counts.get('missing_tenant_isolation', 0) > 0:
            recommendations.append(f"🏢 Add tenant_hk columns to {issue_counts['missing_tenant_isolation']} hub tables for multi-tenant isolation")
        
        if issue_counts.get('wrong_data_type', 0) > 0:
            recommendations.append(f"📊 Fix data types in {issue_counts['wrong_data_type']} columns")
        
        if issue_counts.get('naming_inconsistency', 0) > 0:
            recommendations.append(f"📝 Standardize naming conventions in {issue_counts['naming_inconsistency']} tables")
        
        # Add general recommendations
        recommendations.extend([
            "📚 Review Data Vault 2.0 naming standards documentation",
            "🔄 Consider implementing automated naming validation in CI/CD pipeline",
            "📋 Create naming convention checklist for new table creation"
        ])
        
        return recommendations
    
    def _categorize_issue(self, issue: str) -> str:
        """Categorize an issue for summary statistics"""
        issue_lower = issue.lower()
        
        if 'business key' in issue_lower and 'not found' in issue_lower:
            return 'missing_business_key'
        elif 'hash key' in issue_lower and 'not found' in issue_lower:
            return 'missing_hash_key'
        elif 'tenant_hk' in issue_lower and 'not found' in issue_lower:
            return 'missing_tenant_isolation'
        elif 'should be' in issue_lower and ('bytea' in issue_lower or 'timestamp' in issue_lower):
            return 'wrong_data_type'
        elif 'doesn\'t match expected' in issue_lower:
            return 'naming_inconsistency'
        else:
            return 'other'
    
    def print_detailed_report(self, report: Dict[str, Any]):
        """Print detailed compliance report"""
        print("\n" + "="*80)
        print("📊 HUB TABLE NAMING COMPLIANCE REPORT")
        print("="*80)
        
        print(f"\n🏗️  OVERALL STATISTICS:")
        print(f"   Total Hub Tables: {report['total_tables']}")
        print(f"   Overall Compliance: {report['overall_compliance_percentage']:.1f}%")
        print(f"   Total Score: {report['total_score']}/{report['total_max_score']}")
        
        # Status indicator
        compliance = report['overall_compliance_percentage']
        if compliance >= 90:
            status = "🟢 EXCELLENT"
        elif compliance >= 80:
            status = "🟡 GOOD"
        elif compliance >= 70:
            status = "🟠 NEEDS IMPROVEMENT"
        else:
            status = "🔴 CRITICAL ISSUES"
        
        print(f"   Status: {status}")
        
        print(f"\n📋 COMPLIANCE BY RULE:")
        for rule_name, rule_stats in report['summary_by_rule'].items():
            compliance_pct = rule_stats['compliance_percentage']
            score_pct = rule_stats['score_percentage']
            status_icon = "✅" if compliance_pct >= 90 else "⚠️" if compliance_pct >= 70 else "❌"
            
            print(f"   {status_icon} {rule_stats['description']}")
            print(f"      Compliant Tables: {rule_stats['compliant_tables']}/{rule_stats['total_tables']} ({compliance_pct:.1f}%)")
            print(f"      Score: {score_pct:.1f}% (Weight: {rule_stats['weight']}%)")
            if rule_stats['total_issues'] > 0:
                print(f"      Issues: {rule_stats['total_issues']}")
        
        print(f"\n🔧 TOP RECOMMENDATIONS:")
        for i, recommendation in enumerate(report['recommendations'][:5], 1):
            print(f"   {i}. {recommendation}")
        
        print(f"\n📊 DETAILED TABLE ANALYSIS:")
        for analysis in report['analyses']:
            compliance_pct = analysis['compliance_percentage']
            status_icon = "✅" if compliance_pct >= 90 else "⚠️" if compliance_pct >= 70 else "❌"
            
            print(f"\n   {status_icon} {analysis['full_name']}")
            print(f"      Compliance: {compliance_pct:.1f}% ({analysis['compliance_score']}/{analysis['max_score']} points)")
            
            if analysis['issues']:
                print(f"      Issues ({len(analysis['issues'])}):")
                for issue in analysis['issues']:
                    print(f"        • {issue}")
            
            if analysis['recommendations']:
                print(f"      Recommendations ({len(analysis['recommendations'])}):")
                for rec in analysis['recommendations'][:3]:  # Show first 3
                    print(f"        → {rec}")
    
    def save_report(self, report: Dict[str, Any], filename: Optional[str] = None):
        """Save report to JSON file"""
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"hub_naming_investigation_{timestamp}.json"
        
        try:
            with open(filename, 'w') as f:
                json.dump(report, f, indent=2, default=str)
            print(f"\n💾 Report saved to: {filename}")
        except Exception as e:
            print(f"❌ Error saving report: {e}")
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            print("🔐 Database connection closed")

def main():
    """Main execution function"""
    print("🔍 Hub Table Naming Compliance Investigation")
    print("=" * 50)
    
    investigator = HubTableNamingInvestigator()
    
    try:
        # Connect to database
        if not investigator.connect_to_database():
            return
        
        # Generate compliance report
        report = investigator.generate_compliance_report()
        
        if 'error' in report:
            print(f"❌ Error: {report['error']}")
            return
        
        # Print detailed report
        investigator.print_detailed_report(report)
        
        # Save report
        investigator.save_report(report)
        
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
    finally:
        investigator.close()

if __name__ == "__main__":
    main() 
    