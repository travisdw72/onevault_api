#!/usr/bin/env python3
"""
AI Agent Database Investigation Script
Implementation and execution of comprehensive AI agent analysis

This script investigates the current database setup for AI agent implementations,
providing a clear picture of what exists vs. what needs to be implemented.

Usage: python ai_agent_investigation.py
"""

import psycopg2
import psycopg2.extras
import sys
import getpass
import json
import datetime
from typing import Dict, List, Any, Optional, Tuple
from ai_agent_investigationConfig import (
    DATABASE_CONFIG, 
    SQL_QUERIES, 
    CONSOLE_COLORS, 
    EXPECTED_STRUCTURES,
    INVESTIGATION_CATEGORIES
)

class AIAgentInvestigator:
    """
    Main class for investigating AI agent implementations in the database
    """
    
    def __init__(self):
        self.connection: Optional[psycopg2.connection] = None
        self.results: Dict[str, Any] = {}
        self.investigation_timestamp = datetime.datetime.now()
        self.total_findings = 0
        
    def connect_to_database(self) -> bool:
        """
        Establish connection to the database with manual password input
        """
        try:
            print(f"{CONSOLE_COLORS['CYAN']}Connecting to One Vault Database...{CONSOLE_COLORS['END']}")
            print(f"Host: {DATABASE_CONFIG['host']}")
            print(f"Database: {DATABASE_CONFIG['database']}")
            print(f"User: {DATABASE_CONFIG['user']}")
            
            # Request password manually for security
            password = getpass.getpass("Enter PostgreSQL password: ")
            
            self.connection = psycopg2.connect(
                host=DATABASE_CONFIG['host'],
                port=DATABASE_CONFIG['port'],
                database=DATABASE_CONFIG['database'],
                user=DATABASE_CONFIG['user'],
                password=password
            )
            
            # Test connection
            cursor = self.connection.cursor()
            cursor.execute("SELECT version();")
            version = cursor.fetchone()
            cursor.close()
            
            print(f"{CONSOLE_COLORS['GREEN']}✓ Connected successfully!{CONSOLE_COLORS['END']}")
            print(f"PostgreSQL Version: {version[0]}\n")
            
            return True
            
        except psycopg2.Error as e:
            print(f"{CONSOLE_COLORS['FAIL']}✗ Database connection failed: {e}{CONSOLE_COLORS['END']}")
            return False
        except Exception as e:
            print(f"{CONSOLE_COLORS['FAIL']}✗ Unexpected error: {e}{CONSOLE_COLORS['END']}")
            return False
    
    def execute_query(self, query: str, description: str = "") -> List[Dict[str, Any]]:
        """
        Execute a SQL query and return results as list of dictionaries
        """
        try:
            cursor = self.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(query)
            results = cursor.fetchall()
            cursor.close()
            
            # Convert to list of dicts for JSON serialization
            return [dict(row) for row in results]
            
        except psycopg2.Error as e:
            print(f"{CONSOLE_COLORS['WARNING']}Warning: Query failed - {description}: {e}{CONSOLE_COLORS['END']}")
            return []
        except Exception as e:
            print(f"{CONSOLE_COLORS['FAIL']}Error executing query - {description}: {e}{CONSOLE_COLORS['END']}")
            return []
    
    def print_section_header(self, title: str, level: int = 1):
        """
        Print formatted section headers
        """
        if level == 1:
            print(f"\n{CONSOLE_COLORS['HEADER']}{'='*80}")
            print(f"{title.upper()}")
            print(f"{'='*80}{CONSOLE_COLORS['END']}")
        else:
            print(f"\n{CONSOLE_COLORS['BLUE']}{'-'*60}")
            print(f"{title}")
            print(f"{'-'*60}{CONSOLE_COLORS['END']}")
    
    def print_table_results(self, results: List[Dict[str, Any]], title: str):
        """
        Print query results in a formatted table
        """
        if not results:
            print(f"{CONSOLE_COLORS['WARNING']}No results found for {title}{CONSOLE_COLORS['END']}")
            return
        
        print(f"\n{CONSOLE_COLORS['CYAN']}{title} ({len(results)} results):{CONSOLE_COLORS['END']}")
        
        # Get column headers
        headers = list(results[0].keys())
        
        # Calculate column widths
        col_widths = {}
        for header in headers:
            col_widths[header] = max(len(str(header)), 
                                   max(len(str(row.get(header, ''))) for row in results))
            col_widths[header] = min(col_widths[header], 50)  # Max width of 50
        
        # Print header
        header_row = "| " + " | ".join(f"{header:<{col_widths[header]}}" for header in headers) + " |"
        print(header_row)
        print("|" + "|".join("-" * (col_widths[header] + 2) for header in headers) + "|")
        
        # Print data rows
        for row in results:
            data_row = "| " + " | ".join(
                f"{str(row.get(header, '')):<{col_widths[header]}}"[:col_widths[header]] 
                for header in headers
            ) + " |"
            print(data_row)
        
        print()
    
    def investigate_schema_analysis(self):
        """
        Investigate database schemas for AI-related structures
        """
        self.print_section_header("Schema Analysis", 1)
        
        schema_results = {}
        
        for query_name, query in SQL_QUERIES['SCHEMA_ANALYSIS'].items():
            results = self.execute_query(query, f"Schema Analysis - {query_name}")
            schema_results[query_name] = results
            self.print_table_results(results, query_name.replace('_', ' ').title())
        
        self.results['schema_analysis'] = schema_results
        self.total_findings += sum(len(results) for results in schema_results.values())
    
    def investigate_ai_agent_structures(self):
        """
        Investigate AI agent-related database structures
        """
        self.print_section_header("AI Agent Structures", 1)
        
        agent_results = {}
        
        for query_name, query in SQL_QUERIES['AI_AGENT_STRUCTURES'].items():
            results = self.execute_query(query, f"AI Agent Structures - {query_name}")
            agent_results[query_name] = results
            self.print_table_results(results, query_name.replace('_', ' ').title())
        
        self.results['ai_agent_structures'] = agent_results
        self.total_findings += sum(len(results) for results in agent_results.values())
    
    def investigate_zero_trust_security(self):
        """
        Investigate zero trust security implementations
        """
        self.print_section_header("Zero Trust Security", 1)
        
        security_results = {}
        
        for query_name, query in SQL_QUERIES['ZERO_TRUST_SECURITY'].items():
            results = self.execute_query(query, f"Zero Trust Security - {query_name}")
            security_results[query_name] = results
            self.print_table_results(results, query_name.replace('_', ' ').title())
        
        self.results['zero_trust_security'] = security_results
        self.total_findings += sum(len(results) for results in security_results.values())
    
    def investigate_api_gateway(self):
        """
        Investigate API gateway implementations
        """
        self.print_section_header("API Gateway", 1)
        
        gateway_results = {}
        
        for query_name, query in SQL_QUERIES['API_GATEWAY'].items():
            results = self.execute_query(query, f"API Gateway - {query_name}")
            gateway_results[query_name] = results
            self.print_table_results(results, query_name.replace('_', ' ').title())
        
        self.results['api_gateway'] = gateway_results
        self.total_findings += sum(len(results) for results in gateway_results.values())
    
    def investigate_learning_loops(self):
        """
        Investigate learning loop implementations
        """
        self.print_section_header("Learning Loops", 1)
        
        learning_results = {}
        
        if 'LEARNING_LOOPS' in SQL_QUERIES:
            for query_name, query in SQL_QUERIES['LEARNING_LOOPS'].items():
                results = self.execute_query(query, f"Learning Loops - {query_name}")
                learning_results[query_name] = results
                self.print_table_results(results, query_name.replace('_', ' ').title())
        
        self.results['learning_loops'] = learning_results
        self.total_findings += sum(len(results) for results in learning_results.values())
    
    def investigate_augmented_learning(self):
        """
        Investigate augmented learning implementations
        """
        self.print_section_header("Augmented Learning", 1)
        
        augmented_results = {}
        
        if 'AUGMENTED_LEARNING' in SQL_QUERIES:
            for query_name, query in SQL_QUERIES['AUGMENTED_LEARNING'].items():
                results = self.execute_query(query, f"Augmented Learning - {query_name}")
                augmented_results[query_name] = results
                self.print_table_results(results, query_name.replace('_', ' ').title())
        
        self.results['augmented_learning'] = augmented_results
        self.total_findings += sum(len(results) for results in augmented_results.values())
    
    def investigate_performance_monitoring(self):
        """
        Investigate performance monitoring implementations
        """
        self.print_section_header("Performance Monitoring", 1)
        
        monitoring_results = {}
        
        if 'PERFORMANCE_MONITORING' in SQL_QUERIES:
            for query_name, query in SQL_QUERIES['PERFORMANCE_MONITORING'].items():
                results = self.execute_query(query, f"Performance Monitoring - {query_name}")
                monitoring_results[query_name] = results
                self.print_table_results(results, query_name.replace('_', ' ').title())
        
        self.results['performance_monitoring'] = monitoring_results
        self.total_findings += sum(len(results) for results in monitoring_results.values())
    
    def investigate_compliance_tracking(self):
        """
        Investigate compliance tracking implementations
        """
        self.print_section_header("Compliance Tracking", 1)
        
        compliance_results = {}
        
        if 'COMPLIANCE_TRACKING' in SQL_QUERIES:
            for query_name, query in SQL_QUERIES['COMPLIANCE_TRACKING'].items():
                results = self.execute_query(query, f"Compliance Tracking - {query_name}")
                compliance_results[query_name] = results
                self.print_table_results(results, query_name.replace('_', ' ').title())
        
        self.results['compliance_tracking'] = compliance_results
        self.total_findings += sum(len(results) for results in compliance_results.values())
    
    def generate_summary_analysis(self):
        """
        Generate comprehensive summary and analysis
        """
        self.print_section_header("Summary Analysis", 1)
        
        summary_results = {}
        
        for query_name, query in SQL_QUERIES['SUMMARY'].items():
            results = self.execute_query(query, f"Summary - {query_name}")
            summary_results[query_name] = results
            self.print_table_results(results, query_name.replace('_', ' ').title())
        
        self.results['summary'] = summary_results
    
    def analyze_implementation_gaps(self):
        """
        Analyze gaps between current implementation and expected structures
        """
        self.print_section_header("Implementation Gap Analysis", 1)
        
        gaps = {}
        
        # Check for expected AI agent structures
        if 'ai_agent_structures' in self.results:
            existing_tables = set()
            for query_results in self.results['ai_agent_structures'].values():
                for row in query_results:
                    existing_tables.add(row.get('table_name', ''))
            
            for structure_type, expected_tables in EXPECTED_STRUCTURES.items():
                missing_tables = [table for table in expected_tables if table not in existing_tables]
                if missing_tables:
                    gaps[structure_type] = missing_tables
        
        # Display gaps
        if gaps:
            print(f"{CONSOLE_COLORS['WARNING']}MISSING STRUCTURES DETECTED:{CONSOLE_COLORS['END']}")
            for structure_type, missing_tables in gaps.items():
                print(f"\n{CONSOLE_COLORS['FAIL']}Missing {structure_type}:{CONSOLE_COLORS['END']}")
                for table in missing_tables:
                    print(f"  - {table}")
        else:
            print(f"{CONSOLE_COLORS['GREEN']}All expected structures are present!{CONSOLE_COLORS['END']}")
        
        self.results['implementation_gaps'] = gaps
    
    def generate_recommendations(self):
        """
        Generate recommendations based on findings
        """
        self.print_section_header("Recommendations", 1)
        
        recommendations = []
        
        # Check AI agent implementation status
        ai_tables = sum(len(results) for results in self.results.get('ai_agent_structures', {}).values())
        if ai_tables == 0:
            recommendations.append({
                'priority': 'HIGH',
                'category': 'AI_AGENTS',
                'title': 'Implement AI Agent Data Vault Structures',
                'description': 'No AI agent tables found. Need to implement complete AI agent framework.',
                'action': 'Deploy ai_agents_zero_trust.sql script'
            })
        elif ai_tables < 10:
            recommendations.append({
                'priority': 'MEDIUM',
                'category': 'AI_AGENTS',
                'title': 'Complete AI Agent Implementation',
                'description': f'Only {ai_tables} AI agent structures found. Implementation appears incomplete.',
                'action': 'Review and complete AI agent table deployment'
            })
        
        # Check security implementation
        security_tables = sum(len(results) for results in self.results.get('zero_trust_security', {}).values())
        if security_tables < 5:
            recommendations.append({
                'priority': 'HIGH',
                'category': 'SECURITY',
                'title': 'Implement Zero Trust Security Framework',
                'description': 'Insufficient security structures for zero trust implementation.',
                'action': 'Deploy zero trust security components'
            })
        
        # Check API gateway
        gateway_tables = sum(len(results) for results in self.results.get('api_gateway', {}).values())
        if gateway_tables == 0:
            recommendations.append({
                'priority': 'MEDIUM',
                'category': 'API_GATEWAY',
                'title': 'Implement Intelligent API Gateway',
                'description': 'No API gateway structures found.',
                'action': 'Deploy intelligent API gateway implementation'
            })
        
        # Display recommendations
        if recommendations:
            for i, rec in enumerate(recommendations, 1):
                priority_color = CONSOLE_COLORS['FAIL'] if rec['priority'] == 'HIGH' else CONSOLE_COLORS['WARNING']
                print(f"\n{priority_color}RECOMMENDATION #{i} - {rec['priority']} PRIORITY{CONSOLE_COLORS['END']}")
                print(f"Category: {rec['category']}")
                print(f"Title: {rec['title']}")
                print(f"Description: {rec['description']}")
                print(f"Action: {rec['action']}")
        else:
            print(f"{CONSOLE_COLORS['GREEN']}No critical recommendations - implementation looks good!{CONSOLE_COLORS['END']}")
        
        self.results['recommendations'] = recommendations
    
    def export_results(self):
        """
        Export investigation results to JSON file
        """
        try:
            # Prepare export data
            export_data = {
                'investigation_timestamp': self.investigation_timestamp.isoformat(),
                'total_findings': self.total_findings,
                'database_info': {
                    'host': DATABASE_CONFIG['host'],
                    'database': DATABASE_CONFIG['database'],
                    'user': DATABASE_CONFIG['user']
                },
                'results': self.results
            }
            
            # Export to JSON
            filename = f"ai_agent_investigation_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(filename, 'w') as f:
                json.dump(export_data, f, indent=2, default=str)
            
            print(f"\n{CONSOLE_COLORS['GREEN']}Results exported to: {filename}{CONSOLE_COLORS['END']}")
            
        except Exception as e:
            print(f"{CONSOLE_COLORS['FAIL']}Error exporting results: {e}{CONSOLE_COLORS['END']}")
    
    def run_investigation(self):
        """
        Run the complete AI agent investigation
        """
        print(f"{CONSOLE_COLORS['HEADER']}")
        print("=" * 80)
        print("AI AGENT DATABASE INVESTIGATION")
        print("One Vault - Comprehensive Analysis")
        print("Targeting Actual Schemas: ai_monitoring, automation, api, security, auth")
        print("=" * 80)
        print(f"{CONSOLE_COLORS['END']}")
        
        # Connect to database
        if not self.connect_to_database():
            print("Investigation aborted due to connection failure.")
            return False
        
        try:
            # Run all investigations with enhanced schema targeting
            self.investigate_schema_analysis()
            self.investigate_ai_agent_structures()
            self.investigate_zero_trust_security()
            self.investigate_api_gateway()
            
            # Additional investigations for actual schemas
            self.investigate_learning_loops()
            self.investigate_augmented_learning() 
            self.investigate_performance_monitoring()
            self.investigate_compliance_tracking()
            
            self.generate_summary_analysis()
            self.analyze_implementation_gaps()
            self.generate_recommendations()
            
            # Final summary
            self.print_section_header("Investigation Complete", 1)
            print(f"Total findings: {self.total_findings}")
            print(f"Investigation completed at: {self.investigation_timestamp}")
            print(f"\n{CONSOLE_COLORS['GREEN']}✓ Targeted analysis of your actual schemas:{CONSOLE_COLORS['END']}")
            print("  - ai_monitoring (AI monitoring and metrics)")
            print("  - automation (Automation and AI agents)")  
            print("  - api (API gateway and provider management)")
            print("  - security (Zero trust security framework)")
            print("  - auth (Authentication and authorization)")
            print("  - compliance (Regulatory compliance)")
            
            # Export results
            self.export_results()
            
            return True
            
        except Exception as e:
            print(f"{CONSOLE_COLORS['FAIL']}Investigation failed: {e}{CONSOLE_COLORS['END']}")
            return False
        
        finally:
            if self.connection:
                self.connection.close()
                print(f"\n{CONSOLE_COLORS['CYAN']}Database connection closed.{CONSOLE_COLORS['END']}")

def main():
    """
    Main entry point for the investigation script
    """
    investigator = AIAgentInvestigator()
    
    try:
        success = investigator.run_investigation()
        
        if success:
            print(f"\n{CONSOLE_COLORS['GREEN']}Investigation completed successfully!{CONSOLE_COLORS['END']}")
            print(f"Check the exported JSON file for detailed results.")
        else:
            print(f"\n{CONSOLE_COLORS['FAIL']}Investigation completed with errors.{CONSOLE_COLORS['END']}")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print(f"\n{CONSOLE_COLORS['WARNING']}Investigation interrupted by user.{CONSOLE_COLORS['END']}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{CONSOLE_COLORS['FAIL']}Unexpected error: {e}{CONSOLE_COLORS['END']}")
        sys.exit(1)

if __name__ == "__main__":
    main() 