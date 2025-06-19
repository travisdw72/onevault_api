#!/usr/bin/env python3
"""
Database Archaeology Tool
========================

Analyzes the current database structure and compares it against our organized scripts
to identify any missing pieces or objects that don't have corresponding creation scripts.

This tool helps validate that our 662 organized scripts represent the complete
evolutionary history of the database.
"""

import os
import sys
import json
import psycopg2
import re
from typing import Dict, List, Set, Tuple, Optional
from datetime import datetime
from pathlib import Path

class DatabaseArchaeologist:
    def __init__(self, connection_params: Dict[str, str]):
        """Initialize the database archaeology tool"""
        self.connection_params = connection_params
        self.organized_scripts_path = Path("organized_migrations")
        self.legacy_scripts_path = Path("legacy_scripts")
        
        # Track what we find
        self.database_objects = {}
        self.script_objects = {}
        self.missing_objects = []
        self.orphaned_scripts = []
        self.analysis_results = {}
        
    def connect_to_database(self) -> psycopg2.extensions.connection:
        """Establish database connection"""
        try:
            conn = psycopg2.connect(**self.connection_params)
            return conn
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            sys.exit(1)
    
    def analyze_current_database_structure(self) -> Dict[str, Dict]:
        """Extract complete structure of current database"""
        print("🔍 Analyzing current database structure...")
        
        conn = self.connect_to_database()
        cursor = conn.cursor()
        
        database_structure = {
            'schemas': {},
            'tables': {},
            'views': {},
            'functions': {},
            'procedures': {},
            'indexes': {},
            'constraints': {},
            'sequences': {},
            'triggers': {},
            'types': {}
        }
        
        try:
            # Get all schemas (excluding system schemas)
            cursor.execute("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
                AND schema_name NOT LIKE 'pg_temp_%'
                ORDER BY schema_name
            """)
            
            for (schema_name,) in cursor.fetchall():
                database_structure['schemas'][schema_name] = {
                    'created_by_script': None,
                    'objects': []
                }
            
            # Get all tables with detailed info
            cursor.execute("""
                SELECT 
                    schemaname, 
                    tablename,
                    tableowner,
                    hasindexes,
                    hasrules,
                    hastriggers
                FROM pg_tables 
                WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
                ORDER BY schemaname, tablename
            """)
            
            for row in cursor.fetchall():
                schema, table, owner, has_indexes, has_rules, has_triggers = row
                full_name = f"{schema}.{table}"
                database_structure['tables'][full_name] = {
                    'schema': schema,
                    'table': table,
                    'owner': owner,
                    'has_indexes': has_indexes,
                    'has_rules': has_rules,
                    'has_triggers': has_triggers,
                    'created_by_script': None,
                    'columns': []
                }
                
                # Get column details
                cursor.execute("""
                    SELECT 
                        column_name,
                        data_type,
                        is_nullable,
                        column_default
                    FROM information_schema.columns
                    WHERE table_schema = %s AND table_name = %s
                    ORDER BY ordinal_position
                """, (schema, table))
                
                database_structure['tables'][full_name]['columns'] = [
                    {
                        'name': col[0],
                        'type': col[1], 
                        'nullable': col[2],
                        'default': col[3]
                    }
                    for col in cursor.fetchall()
                ]
            
            # Get all views
            cursor.execute("""
                SELECT 
                    schemaname,
                    viewname,
                    viewowner,
                    definition
                FROM pg_views
                WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
                ORDER BY schemaname, viewname
            """)
            
            for row in cursor.fetchall():
                schema, view, owner, definition = row
                full_name = f"{schema}.{view}"
                database_structure['views'][full_name] = {
                    'schema': schema,
                    'view': view,
                    'owner': owner,
                    'definition': definition,
                    'created_by_script': None
                }
            
            # Get all functions and procedures
            cursor.execute("""
                SELECT 
                    n.nspname as schema_name,
                    p.proname as function_name,
                    pg_get_function_result(p.oid) as return_type,
                    pg_get_function_arguments(p.oid) as arguments,
                    CASE p.prokind 
                        WHEN 'f' THEN 'function'
                        WHEN 'p' THEN 'procedure'
                        WHEN 'a' THEN 'aggregate'
                        WHEN 'w' THEN 'window'
                        ELSE 'other'
                    END as function_type,
                    l.lanname as language
                FROM pg_proc p
                JOIN pg_namespace n ON p.pronamespace = n.oid
                JOIN pg_language l ON p.prolang = l.oid
                WHERE n.nspname NOT IN ('information_schema', 'pg_catalog')
                ORDER BY n.nspname, p.proname
            """)
            
            for row in cursor.fetchall():
                schema, name, return_type, arguments, func_type, language = row
                full_name = f"{schema}.{name}"
                
                target_dict = database_structure['functions'] if func_type == 'function' else database_structure['procedures']
                target_dict[full_name] = {
                    'schema': schema,
                    'name': name,
                    'return_type': return_type,
                    'arguments': arguments,
                    'type': func_type,
                    'language': language,
                    'created_by_script': None
                }
            
            # Get all indexes
            cursor.execute("""
                SELECT 
                    schemaname,
                    tablename,
                    indexname,
                    indexdef
                FROM pg_indexes
                WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
                ORDER BY schemaname, tablename, indexname
            """)
            
            for row in cursor.fetchall():
                schema, table, index, definition = row
                full_name = f"{schema}.{index}"
                database_structure['indexes'][full_name] = {
                    'schema': schema,
                    'table': table,
                    'index': index,
                    'definition': definition,
                    'created_by_script': None
                }
            
            # Get all constraints
            cursor.execute("""
                SELECT 
                    tc.constraint_schema,
                    tc.table_name,
                    tc.constraint_name,
                    tc.constraint_type,
                    CASE 
                        WHEN tc.constraint_type = 'FOREIGN KEY' THEN
                            (SELECT ccu.table_name FROM information_schema.constraint_column_usage ccu 
                             WHERE ccu.constraint_name = tc.constraint_name 
                             AND ccu.constraint_schema = tc.constraint_schema)
                        ELSE NULL
                    END as referenced_table
                FROM information_schema.table_constraints tc
                WHERE tc.constraint_schema NOT IN ('information_schema', 'pg_catalog')
                ORDER BY tc.constraint_schema, tc.table_name, tc.constraint_name
            """)
            
            for row in cursor.fetchall():
                schema, table, constraint, const_type, ref_table = row
                full_name = f"{schema}.{table}.{constraint}"
                database_structure['constraints'][full_name] = {
                    'schema': schema,
                    'table': table,
                    'constraint': constraint,
                    'type': const_type,
                    'referenced_table': ref_table,
                    'created_by_script': None
                }
            
            # Get all sequences
            cursor.execute("""
                SELECT 
                    schemaname,
                    sequencename,
                    start_value,
                    min_value,
                    max_value,
                    increment_by
                FROM pg_sequences
                WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
                ORDER BY schemaname, sequencename
            """)
            
            for row in cursor.fetchall():
                schema, sequence, start_val, min_val, max_val, increment = row
                full_name = f"{schema}.{sequence}"
                database_structure['sequences'][full_name] = {
                    'schema': schema,
                    'sequence': sequence,
                    'start_value': start_val,
                    'min_value': min_val,
                    'max_value': max_val,
                    'increment': increment,
                    'created_by_script': None
                }
            
        except Exception as e:
            print(f"❌ Error analyzing database structure: {e}")
        finally:
            cursor.close()
            conn.close()
        
        self.database_objects = database_structure
        print(f"✅ Database analysis complete:")
        print(f"   📊 Schemas: {len(database_structure['schemas'])}")
        print(f"   📋 Tables: {len(database_structure['tables'])}")
        print(f"   👁️  Views: {len(database_structure['views'])}")
        print(f"   ⚙️  Functions: {len(database_structure['functions'])}")
        print(f"   🔧 Procedures: {len(database_structure['procedures'])}")
        print(f"   📇 Indexes: {len(database_structure['indexes'])}")
        print(f"   🔗 Constraints: {len(database_structure['constraints'])}")
        print(f"   🔢 Sequences: {len(database_structure['sequences'])}")
        
        return database_structure
    
    def analyze_script_objects(self) -> Dict[str, Dict]:
        """Analyze what objects our scripts would create"""
        print("\n🔍 Analyzing objects defined in scripts...")
        
        script_objects = {
            'schemas': {},
            'tables': {},
            'views': {},
            'functions': {},
            'procedures': {},
            'indexes': {},
            'constraints': {},
            'sequences': {},
            'triggers': {},
            'types': {}
        }
        
        # Patterns to match different SQL object types
        patterns = {
            'schema': r'CREATE\s+SCHEMA\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z_][a-zA-Z0-9_]*)',
            'table': r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)',
            'view': r'CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+([a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)',
            'function': r'CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+([a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)',
            'procedure': r'CREATE\s+(?:OR\s+REPLACE\s+)?PROCEDURE\s+([a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)',
            'index': r'CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:CONCURRENTLY\s+)?(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z_][a-zA-Z0-9_]*)',
            'constraint': r'(?:CONSTRAINT\s+([a-zA-Z_][a-zA-Z0-9_]*)|ADD\s+CONSTRAINT\s+([a-zA-Z_][a-zA-Z0-9_]*))',
            'sequence': r'CREATE\s+SEQUENCE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)',
            'trigger': r'CREATE\s+(?:OR\s+REPLACE\s+)?TRIGGER\s+([a-zA-Z_][a-zA-Z0-9_]*)',
            'type': r'CREATE\s+TYPE\s+([a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)'
        }
        
        # Search through all SQL files
        sql_files = []
        
        # Check organized migrations
        if self.organized_scripts_path.exists():
            sql_files.extend(list(self.organized_scripts_path.rglob("*.sql")))
        
        # Check legacy scripts
        if self.legacy_scripts_path.exists():
            sql_files.extend(list(self.legacy_scripts_path.rglob("*.sql")))
        
        # Also check scripts directory
        scripts_path = Path("scripts")
        if scripts_path.exists():
            sql_files.extend(list(scripts_path.rglob("*.sql")))
        
        total_files = len(sql_files)
        processed = 0
        
        for sql_file in sql_files:
            processed += 1
            if processed % 50 == 0:
                print(f"   📄 Processed {processed}/{total_files} files...")
            
            try:
                with open(sql_file, 'r', encoding='utf-8') as f:
                    content = f.read().upper()  # Case insensitive matching
                    
                    # Look for each object type
                    for object_type, pattern in patterns.items():
                        matches = re.findall(pattern, content, re.IGNORECASE | re.MULTILINE)
                        
                        for match in matches:
                            if isinstance(match, tuple):
                                # Handle constraint pattern that has multiple groups
                                object_name = match[0] if match[0] else match[1]
                            else:
                                object_name = match
                            
                            if object_name:
                                # Clean up the object name
                                object_name = object_name.strip().lower()
                                
                                if object_type not in script_objects:
                                    script_objects[object_type] = {}
                                
                                if object_name not in script_objects[object_type]:
                                    script_objects[object_type][object_name] = []
                                
                                script_objects[object_type][object_name].append({
                                    'file': str(sql_file),
                                    'relative_path': str(sql_file.relative_to(Path.cwd()))
                                })
                
            except Exception as e:
                print(f"⚠️  Error reading {sql_file}: {e}")
        
        self.script_objects = script_objects
        print(f"✅ Script analysis complete:")
        print(f"   📊 Schema definitions: {len(script_objects.get('schemas', {}))}")
        print(f"   📋 Table definitions: {len(script_objects.get('tables', {}))}")
        print(f"   👁️  View definitions: {len(script_objects.get('views', {}))}")
        print(f"   ⚙️  Function definitions: {len(script_objects.get('functions', {}))}")
        print(f"   🔧 Procedure definitions: {len(script_objects.get('procedures', {}))}")
        print(f"   📇 Index definitions: {len(script_objects.get('indexes', {}))}")
        
        return script_objects
    
    def find_missing_objects(self) -> List[Dict]:
        """Find database objects that don't have corresponding creation scripts"""
        print("\n🕵️ Searching for missing objects...")
        
        missing_objects = []
        
        # Check each object type
        for object_type in ['schemas', 'tables', 'views', 'functions', 'procedures', 'indexes', 'sequences']:
            db_objects = self.database_objects.get(object_type, {})
            script_objects = self.script_objects.get(object_type, {})
            
            for db_object_name in db_objects.keys():
                # For schemas, just check the name
                if object_type == 'schemas':
                    search_name = db_object_name.lower()
                else:
                    # For other objects, use the full name
                    search_name = db_object_name.lower()
                
                # Check if this object exists in any script
                found_in_script = False
                
                # Exact match first
                if search_name in script_objects:
                    found_in_script = True
                else:
                    # Fuzzy match - check if object name appears anywhere
                    for script_object_name in script_objects.keys():
                        if search_name in script_object_name or script_object_name in search_name:
                            found_in_script = True
                            break
                
                if not found_in_script:
                    missing_objects.append({
                        'type': object_type,
                        'name': db_object_name,
                        'details': db_objects[db_object_name]
                    })
        
        self.missing_objects = missing_objects
        
        if missing_objects:
            print(f"⚠️  Found {len(missing_objects)} potentially missing objects:")
            for obj in missing_objects[:10]:  # Show first 10
                print(f"   🔍 {obj['type']}: {obj['name']}")
            if len(missing_objects) > 10:
                print(f"   ... and {len(missing_objects) - 10} more")
        else:
            print("✅ All database objects appear to have corresponding creation scripts!")
        
        return missing_objects
    
    def find_orphaned_scripts(self) -> List[Dict]:
        """Find scripts that create objects not present in the database"""
        print("\n🕵️ Searching for orphaned scripts...")
        
        orphaned_scripts = []
        
        # Check each object type
        for object_type in ['schemas', 'tables', 'views', 'functions', 'procedures', 'indexes', 'sequences']:
            db_objects = self.database_objects.get(object_type, {})
            script_objects = self.script_objects.get(object_type, {})
            
            for script_object_name, script_files in script_objects.items():
                # Check if this script object exists in database
                found_in_db = False
                
                # Exact match first
                if script_object_name in db_objects:
                    found_in_db = True
                else:
                    # Fuzzy match
                    for db_object_name in db_objects.keys():
                        if script_object_name in db_object_name.lower() or db_object_name.lower() in script_object_name:
                            found_in_db = True
                            break
                
                if not found_in_db:
                    orphaned_scripts.append({
                        'type': object_type,
                        'name': script_object_name,
                        'files': script_files
                    })
        
        self.orphaned_scripts = orphaned_scripts
        
        if orphaned_scripts:
            print(f"📄 Found {len(orphaned_scripts)} script objects not in database:")
            for obj in orphaned_scripts[:10]:  # Show first 10
                print(f"   📝 {obj['type']}: {obj['name']}")
            if len(orphaned_scripts) > 10:
                print(f"   ... and {len(orphaned_scripts) - 10} more")
        else:
            print("✅ All script objects appear to exist in the database!")
        
        return orphaned_scripts
    
    def generate_analysis_report(self) -> Dict:
        """Generate comprehensive analysis report"""
        print("\n📊 Generating analysis report...")
        
        # Calculate completeness score
        total_db_objects = sum(len(objects) for objects in self.database_objects.values())
        missing_count = len(self.missing_objects)
        completeness_score = ((total_db_objects - missing_count) / total_db_objects * 100) if total_db_objects > 0 else 100
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_database_objects': total_db_objects,
                'total_script_definitions': sum(len(objects) for objects in self.script_objects.values()),
                'missing_objects_count': missing_count,
                'orphaned_scripts_count': len(self.orphaned_scripts),
                'completeness_score': round(completeness_score, 2)
            },
            'database_objects': {
                'schemas': len(self.database_objects.get('schemas', {})),
                'tables': len(self.database_objects.get('tables', {})),
                'views': len(self.database_objects.get('views', {})),
                'functions': len(self.database_objects.get('functions', {})),
                'procedures': len(self.database_objects.get('procedures', {})),
                'indexes': len(self.database_objects.get('indexes', {})),
                'constraints': len(self.database_objects.get('constraints', {})),
                'sequences': len(self.database_objects.get('sequences', {}))
            },
            'script_objects': {
                'schemas': len(self.script_objects.get('schemas', {})),
                'tables': len(self.script_objects.get('tables', {})),
                'views': len(self.script_objects.get('views', {})),
                'functions': len(self.script_objects.get('functions', {})),
                'procedures': len(self.script_objects.get('procedures', {})),
                'indexes': len(self.script_objects.get('indexes', {})),
                'sequences': len(self.script_objects.get('sequences', {}))
            },
            'missing_objects': self.missing_objects,
            'orphaned_scripts': self.orphaned_scripts,
            'recommendations': []
        }
        
        # Generate recommendations
        if missing_count > 0:
            report['recommendations'].append({
                'type': 'missing_objects',
                'priority': 'medium',
                'message': f"Found {missing_count} database objects without creation scripts. These may be system-generated or created outside the migration system."
            })
        
        if len(self.orphaned_scripts) > 0:
            report['recommendations'].append({
                'type': 'orphaned_scripts',
                'priority': 'low',
                'message': f"Found {len(self.orphaned_scripts)} script definitions for objects not in database. These may be for test databases or rollback scenarios."
            })
        
        if completeness_score >= 95:
            report['recommendations'].append({
                'type': 'excellent',
                'priority': 'info',
                'message': f"Excellent completeness score ({completeness_score:.1f}%)! Your script collection appears to be comprehensive."
            })
        elif completeness_score >= 90:
            report['recommendations'].append({
                'type': 'good',
                'priority': 'info', 
                'message': f"Good completeness score ({completeness_score:.1f}%). Minor gaps may exist but overall coverage is strong."
            })
        else:
            report['recommendations'].append({
                'type': 'needs_attention',
                'priority': 'high',
                'message': f"Completeness score ({completeness_score:.1f}%) indicates significant gaps. Review missing objects."
            })
        
        self.analysis_results = report
        return report
    
    def save_report(self, filename: str = None) -> str:
        """Save analysis report to file"""
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"database_archaeology_report_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(self.analysis_results, f, indent=2, default=str)
        
        return filename
    
    def print_summary(self):
        """Print a comprehensive summary of findings"""
        if not self.analysis_results:
            print("❌ No analysis results available. Run full analysis first.")
            return
        
        summary = self.analysis_results['summary']
        
        print("\n" + "="*80)
        print("🏛️  DATABASE ARCHAEOLOGY REPORT")
        print("="*80)
        print(f"📊 COMPLETENESS SCORE: {summary['completeness_score']:.1f}%")
        print(f"🏗️  Total Database Objects: {summary['total_database_objects']}")
        print(f"📄 Total Script Definitions: {summary['total_script_definitions']}")
        print(f"❓ Missing Objects: {summary['missing_objects_count']}")
        print(f"🔗 Orphaned Scripts: {summary['orphaned_scripts_count']}")
        
        print("\n📋 OBJECT BREAKDOWN:")
        db_objects = self.analysis_results['database_objects']
        script_objects = self.analysis_results['script_objects']
        
        for obj_type in ['schemas', 'tables', 'views', 'functions', 'procedures', 'indexes']:
            db_count = db_objects.get(obj_type, 0)
            script_count = script_objects.get(obj_type, 0)
            print(f"   {obj_type.upper().ljust(12)}: DB={db_count:3d} | Scripts={script_count:3d}")
        
        print("\n💡 RECOMMENDATIONS:")
        for rec in self.analysis_results.get('recommendations', []):
            priority_icon = {'info': '💡', 'low': '📝', 'medium': '⚠️', 'high': '🚨'}.get(rec['priority'], '📋')
            print(f"   {priority_icon} {rec['message']}")
        
        if summary['missing_objects_count'] > 0:
            print(f"\n🔍 TOP MISSING OBJECTS:")
            for obj in self.missing_objects[:5]:
                print(f"   • {obj['type']}: {obj['name']}")
        
        if summary['orphaned_scripts_count'] > 0:
            print(f"\n📄 TOP ORPHANED SCRIPTS:")
            for obj in self.orphaned_scripts[:5]:
                files = len(obj['files'])
                print(f"   • {obj['type']}: {obj['name']} (in {files} file{'s' if files > 1 else ''})")
        
        print("\n" + "="*80)

def main():
    """Main execution function"""
    print("🏛️  DATABASE ARCHAEOLOGY TOOL")
    print("=" * 50)
    print("Analyzing database structure vs. organized scripts...")
    
    # Database connection parameters (modify as needed)
    connection_params = {
        'host': 'localhost',
        'port': 5432,
        'database': 'one_vault',
        'user': 'postgres',
        'password': os.getenv('DB_PASSWORD', 'password')
    }
    
    try:
        # Initialize archaeologist
        archaeologist = DatabaseArchaeologist(connection_params)
        
        # Run full analysis
        print("\n🔄 Starting archaeological analysis...")
        archaeologist.analyze_current_database_structure()
        archaeologist.analyze_script_objects()
        archaeologist.find_missing_objects()
        archaeologist.find_orphaned_scripts()
        archaeologist.generate_analysis_report()
        
        # Print summary
        archaeologist.print_summary()
        
        # Save detailed report
        report_file = archaeologist.save_report()
        print(f"\n💾 Detailed report saved to: {report_file}")
        
        # Final verdict
        score = archaeologist.analysis_results['summary']['completeness_score']
        if score >= 95:
            print("\n🏆 VERDICT: EXCELLENT! Your script collection is comprehensive!")
        elif score >= 90:
            print("\n✅ VERDICT: VERY GOOD! Minor gaps but excellent coverage!")
        elif score >= 85:
            print("\n👍 VERDICT: GOOD! Some objects may need investigation!")
        else:
            print("\n🔍 VERDICT: NEEDS REVIEW! Significant gaps detected!")
        
    except Exception as e:
        print(f"❌ Analysis failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 