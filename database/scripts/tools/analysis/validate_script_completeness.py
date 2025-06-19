#!/usr/bin/env python3
"""
Database Script Completeness Validator
=====================================

Simple tool to validate that our organized scripts represent the current database structure.
Focuses on the core question: "Are we missing any scripts?"
"""

import os
import sys
import psycopg2
import re
from pathlib import Path
from typing import Dict, List, Set
from datetime import datetime

def connect_to_database():
    """Connect to the database using environment variables"""
    try:
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=os.getenv('DB_PORT', 5432),
            database=os.getenv('DB_NAME', 'one_vault'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', 'password')
        )
        return conn
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        print("💡 Make sure your database is running and environment variables are set:")
        print("   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD")
        sys.exit(1)

def get_database_objects():
    """Get core objects from the current database"""
    print("🔍 Analyzing current database...")
    
    conn = connect_to_database()
    cursor = conn.cursor()
    
    objects = {
        'schemas': set(),
        'tables': set(), 
        'functions': set(),
        'views': set(),
        'indexes': set()
    }
    
    try:
        # Get custom schemas (excluding system schemas)
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
            AND schema_name NOT LIKE 'pg_%'
            ORDER BY schema_name
        """)
        objects['schemas'] = {row[0] for row in cursor.fetchall()}
        
        # Get all custom tables
        cursor.execute("""
            SELECT schemaname || '.' || tablename as full_name
            FROM pg_tables 
            WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
            ORDER BY schemaname, tablename
        """)
        objects['tables'] = {row[0] for row in cursor.fetchall()}
        
        # Get all custom functions/procedures
        cursor.execute("""
            SELECT n.nspname || '.' || p.proname as full_name
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname NOT IN ('information_schema', 'pg_catalog')
            ORDER BY n.nspname, p.proname
        """)
        objects['functions'] = {row[0] for row in cursor.fetchall()}
        
        # Get all custom views
        cursor.execute("""
            SELECT schemaname || '.' || viewname as full_name
            FROM pg_views
            WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
            ORDER BY schemaname, viewname
        """)
        objects['views'] = {row[0] for row in cursor.fetchall()}
        
        # Get all custom indexes (excluding auto-generated primary key indexes)
        cursor.execute("""
            SELECT schemaname || '.' || indexname as full_name
            FROM pg_indexes
            WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
            AND indexname NOT LIKE '%_pkey'
            ORDER BY schemaname, indexname
        """)
        objects['indexes'] = {row[0] for row in cursor.fetchall()}
        
    finally:
        cursor.close()
        conn.close()
    
    total_objects = sum(len(obj_set) for obj_set in objects.values())
    print(f"✅ Found {total_objects} database objects:")
    print(f"   📊 Schemas: {len(objects['schemas'])}")
    print(f"   📋 Tables: {len(objects['tables'])}")
    print(f"   ⚙️  Functions: {len(objects['functions'])}")
    print(f"   👁️  Views: {len(objects['views'])}")
    print(f"   📇 Indexes: {len(objects['indexes'])}")
    
    return objects

def scan_script_objects():
    """Scan all SQL scripts to see what objects they create"""
    print("\n🔍 Scanning scripts for object definitions...")
    
    # SQL patterns to match object creation
    patterns = {
        'schemas': r'CREATE\s+SCHEMA\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z_][a-zA-Z0-9_]*)',
        'tables': r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)',
        'functions': r'CREATE\s+(?:OR\s+REPLACE\s+)?(?:FUNCTION|PROCEDURE)\s+([a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)',
        'views': r'CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+([a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*)',
        'indexes': r'CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:CONCURRENTLY\s+)?(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z_][a-zA-Z0-9_]*)'
    }
    
    script_objects = {
        'schemas': set(),
        'tables': set(),
        'functions': set(),
        'views': set(),
        'indexes': set()
    }
    
    # Find all SQL files
    sql_files = []
    
    # Check common script locations
    search_paths = [
        Path("organized_migrations"),
        Path("legacy_scripts"),
        Path("scripts"),
        Path("database/scripts"),
        Path("database/organized_migrations"),
        Path("database/legacy_scripts")
    ]
    
    for search_path in search_paths:
        if search_path.exists():
            sql_files.extend(list(search_path.rglob("*.sql")))
    
    print(f"   📄 Scanning {len(sql_files)} SQL files...")
    
    files_processed = 0
    for sql_file in sql_files:
        files_processed += 1
        if files_processed % 100 == 0:
            print(f"   📄 Processed {files_processed}/{len(sql_files)} files...")
        
        try:
            with open(sql_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
                # Search for each object type
                for obj_type, pattern in patterns.items():
                    matches = re.findall(pattern, content, re.IGNORECASE | re.MULTILINE)
                    
                    for match in matches:
                        # Clean up the match
                        clean_match = match.strip().lower()
                        
                        # For indexes, we need to be more careful about schema
                        if obj_type == 'indexes' and '.' not in clean_match:
                            # If no schema specified, assume public or try to infer
                            continue
                        
                        script_objects[obj_type].add(clean_match)
                        
        except Exception as e:
            print(f"⚠️  Error reading {sql_file}: {e}")
    
    total_script_objects = sum(len(obj_set) for obj_set in script_objects.values())
    print(f"✅ Found {total_script_objects} object definitions in scripts:")
    print(f"   📊 Schema definitions: {len(script_objects['schemas'])}")
    print(f"   📋 Table definitions: {len(script_objects['tables'])}")
    print(f"   ⚙️  Function definitions: {len(script_objects['functions'])}")
    print(f"   👁️  View definitions: {len(script_objects['views'])}")
    print(f"   📇 Index definitions: {len(script_objects['indexes'])}")
    
    return script_objects

def compare_objects(db_objects, script_objects):
    """Compare database objects with script objects"""
    print("\n🔍 Comparing database vs scripts...")
    
    results = {
        'missing_from_scripts': {},
        'missing_from_database': {},
        'matches': {},
        'summary': {}
    }
    
    for obj_type in ['schemas', 'tables', 'functions', 'views', 'indexes']:
        db_set = db_objects[obj_type]
        script_set = script_objects[obj_type]
        
        # Find objects in database but not in scripts
        missing_from_scripts = db_set - script_set
        
        # Find objects in scripts but not in database
        missing_from_db = script_set - db_set
        
        # Find matches
        matches = db_set & script_set
        
        results['missing_from_scripts'][obj_type] = missing_from_scripts
        results['missing_from_database'][obj_type] = missing_from_db
        results['matches'][obj_type] = matches
        
        # Calculate match percentage
        total_db_objects = len(db_set)
        if total_db_objects > 0:
            match_percentage = len(matches) / total_db_objects * 100
        else:
            match_percentage = 100.0
        
        results['summary'][obj_type] = {
            'db_count': len(db_set),
            'script_count': len(script_set),
            'matches': len(matches),
            'missing_from_scripts': len(missing_from_scripts),
            'missing_from_db': len(missing_from_db),
            'match_percentage': match_percentage
        }
        
        print(f"\n📊 {obj_type.upper()}:")
        print(f"   Database: {len(db_set):3d} | Scripts: {len(script_set):3d} | Matches: {len(matches):3d} ({match_percentage:.1f}%)")
        
        if missing_from_scripts:
            print(f"   ❓ Missing from scripts: {len(missing_from_scripts)}")
            for item in sorted(list(missing_from_scripts))[:3]:  # Show first 3
                print(f"      • {item}")
            if len(missing_from_scripts) > 3:
                print(f"      ... and {len(missing_from_scripts) - 3} more")
        
        if missing_from_db:
            print(f"   📄 Only in scripts: {len(missing_from_db)}")
            for item in sorted(list(missing_from_db))[:3]:  # Show first 3
                print(f"      • {item}")
            if len(missing_from_db) > 3:
                print(f"      ... and {len(missing_from_db) - 3} more")
    
    return results

def generate_final_verdict(results):
    """Generate final assessment of script completeness"""
    print("\n" + "="*80)
    print("🏛️  SCRIPT COMPLETENESS ASSESSMENT")
    print("="*80)
    
    # Calculate overall statistics
    total_db_objects = sum(results['summary'][obj_type]['db_count'] for obj_type in results['summary'])
    total_matches = sum(results['summary'][obj_type]['matches'] for obj_type in results['summary'])
    total_missing = sum(results['summary'][obj_type]['missing_from_scripts'] for obj_type in results['summary'])
    
    overall_completeness = (total_matches / total_db_objects * 100) if total_db_objects > 0 else 100
    
    print(f"📊 OVERALL COMPLETENESS: {overall_completeness:.1f}%")
    print(f"🏗️  Total Database Objects: {total_db_objects}")
    print(f"✅ Objects with Scripts: {total_matches}")
    print(f"❓ Objects Missing Scripts: {total_missing}")
    
    # Detailed breakdown
    print(f"\n📋 DETAILED BREAKDOWN:")
    for obj_type in ['schemas', 'tables', 'functions', 'views', 'indexes']:
        summary = results['summary'][obj_type]
        print(f"   {obj_type.upper().ljust(10)}: {summary['matches']:3d}/{summary['db_count']:3d} ({summary['match_percentage']:5.1f}%)")
    
    # Assessment
    print(f"\n🎯 ASSESSMENT:")
    if overall_completeness >= 98:
        print("   🏆 EXCELLENT! Your script collection is virtually complete!")
        print("   ✅ You have captured the full evolution of your database!")
    elif overall_completeness >= 95:
        print("   🌟 OUTSTANDING! Your script collection is very comprehensive!")
        print("   👍 Minor gaps may be system-generated objects or safe to ignore!")
    elif overall_completeness >= 90:
        print("   ✅ VERY GOOD! Your script collection covers most objects!")
        print("   🔍 Review missing objects to ensure nothing critical is missing!")
    elif overall_completeness >= 80:
        print("   ⚠️  GOOD! Some objects may need investigation!")
        print("   📝 Consider documenting or scripting the missing objects!")
    else:
        print("   🚨 NEEDS ATTENTION! Significant gaps in script coverage!")
        print("   🔧 Review and document missing objects before proceeding!")
    
    # Show critical missing objects
    critical_missing = []
    for obj_type in ['schemas', 'tables', 'functions']:
        missing = results['missing_from_scripts'][obj_type]
        if missing and obj_type in ['schemas', 'tables']:  # These are most critical
            critical_missing.extend([(obj_type, item) for item in missing])
    
    if critical_missing:
        print(f"\n🚨 CRITICAL MISSING OBJECTS:")
        for obj_type, obj_name in sorted(critical_missing)[:10]:
            print(f"   • {obj_type}: {obj_name}")
        if len(critical_missing) > 10:
            print(f"   ... and {len(critical_missing) - 10} more")
    
    print("\n💡 RECOMMENDATIONS:")
    if overall_completeness >= 95:
        print("   ✅ Your script organization is excellent! Ready for production!")
        print("   📚 Consider this your 'database source code' - it's comprehensive!")
    else:
        print("   🔍 Investigate missing objects to determine if they're:")
        print("      • System-generated (safe to ignore)")
        print("      • Created outside migration system (need documentation)")
        print("      • Actually important (need creation scripts)")
    
    print("="*80)
    
    return overall_completeness

def main():
    """Main execution function"""
    print("🔍 DATABASE SCRIPT COMPLETENESS VALIDATOR")
    print("=" * 50)
    print("Checking if our organized scripts match the current database...")
    
    try:
        # Get current database state
        db_objects = get_database_objects()
        
        # Get script object definitions
        script_objects = scan_script_objects()
        
        # Compare them
        results = compare_objects(db_objects, script_objects)
        
        # Generate final verdict
        completeness_score = generate_final_verdict(results)
        
        # Save summary report
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"script_completeness_report_{timestamp}.txt"
        
        with open(report_file, 'w') as f:
            f.write(f"Script Completeness Report - {datetime.now()}\n")
            f.write("="*50 + "\n")
            f.write(f"Overall Completeness: {completeness_score:.1f}%\n\n")
            
            for obj_type in ['schemas', 'tables', 'functions', 'views', 'indexes']:
                summary = results['summary'][obj_type]
                f.write(f"{obj_type.upper()}: {summary['matches']}/{summary['db_count']} ({summary['match_percentage']:.1f}%)\n")
                
                missing = results['missing_from_scripts'][obj_type]
                if missing:
                    f.write(f"  Missing from scripts:\n")
                    for item in sorted(missing):
                        f.write(f"    - {item}\n")
                f.write("\n")
        
        print(f"\n💾 Detailed report saved to: {report_file}")
        
        return completeness_score >= 95
        
    except Exception as e:
        print(f"❌ Validation failed: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 