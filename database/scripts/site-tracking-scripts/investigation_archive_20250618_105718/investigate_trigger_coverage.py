#!/usr/bin/env python3
"""
Audit Trigger Coverage Investigation
===================================
Investigate which tables have audit triggers applied and whether
the util.audit_track_* triggers fire automatically on all tables
or need to be manually configured.
"""

import psycopg2
import getpass
import json
from datetime import datetime

def investigate_trigger_coverage():
    """Investigate audit trigger coverage across the database"""
    
    print("🔍 INVESTIGATING AUDIT TRIGGER COVERAGE")
    print("=" * 60)
    print("Checking which tables have audit triggers and how they're applied")
    print(f"Investigation started: {datetime.now()}")
    print()
    
    # Get password securely
    password = getpass.getpass('Enter PostgreSQL password: ')
    
    try:
        # Connect to database
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            database='one_vault',
            user='postgres',
            password=password
        )
        cursor = conn.cursor()
        
        investigation_results = {}
        
        print("📊 DISCOVERING ALL TABLES WITH AUDIT TRIGGERS:")
        print("-" * 50)
        
        # Get all tables that have audit_track triggers
        cursor.execute("""
            SELECT 
                n.nspname as schema_name,
                c.relname as table_name,
                t.tgname as trigger_name,
                p.proname as trigger_function,
                t.tgenabled as trigger_enabled,
                pg_get_triggerdef(t.oid) as trigger_definition
            FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            JOIN pg_namespace n ON c.relnamespace = n.oid
            JOIN pg_proc p ON t.tgfoid = p.oid
            WHERE p.proname LIKE 'audit_track_%'
            AND NOT t.tgisinternal  -- Exclude internal triggers
            ORDER BY n.nspname, c.relname, t.tgname
        """)
        
        trigger_results = cursor.fetchall()
        
        if not trigger_results:
            print("❌ No audit_track triggers found!")
            return
        
        print(f"Found {len(trigger_results)} audit_track triggers:")
        print()
        
        # Group by schema and table
        triggers_by_table = {}
        
        for schema, table, trigger_name, function_name, enabled, definition in trigger_results:
            table_key = f"{schema}.{table}"
            if table_key not in triggers_by_table:
                triggers_by_table[table_key] = []
            
            triggers_by_table[table_key].append({
                'trigger_name': trigger_name,
                'function_name': function_name,
                'enabled': enabled == 'O',  # 'O' means enabled
                'definition': definition
            })
        
        # Display results by table
        for table_key, triggers in triggers_by_table.items():
            print(f"🔧 **{table_key}**")
            for trigger in triggers:
                status = "✅ ENABLED" if trigger['enabled'] else "❌ DISABLED"
                print(f"   {trigger['trigger_name']} → {trigger['function_name']} ({status})")
            print()
        
        investigation_results['tables_with_triggers'] = triggers_by_table
        
        print("📈 ANALYZING TRIGGER PATTERNS:")
        print("-" * 50)
        
        # Check what types of tables have triggers
        cursor.execute("""
            SELECT 
                n.nspname as schema_name,
                COUNT(DISTINCT c.relname) as tables_with_triggers,
                ARRAY_AGG(DISTINCT p.proname) as trigger_functions_used
            FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            JOIN pg_namespace n ON c.relnamespace = n.oid
            JOIN pg_proc p ON t.tgfoid = p.oid
            WHERE p.proname LIKE 'audit_track_%'
            AND NOT t.tgisinternal
            GROUP BY n.nspname
            ORDER BY n.nspname
        """)
        
        schema_stats = cursor.fetchall()
        
        print("Audit trigger coverage by schema:")
        for schema, table_count, functions in schema_stats:
            print(f"   📁 {schema}: {table_count} tables with audit triggers")
            print(f"      Functions used: {', '.join(functions)}")
        print()
        
        print("🔍 CHECKING ALL DATA VAULT 2.0 TABLES:")
        print("-" * 50)
        
        # Get all Data Vault 2.0 tables (hubs, satellites, links)
        cursor.execute("""
            SELECT 
                n.nspname as schema_name,
                c.relname as table_name,
                CASE 
                    WHEN c.relname LIKE '%_h' THEN 'Hub'
                    WHEN c.relname LIKE '%_s' THEN 'Satellite'
                    WHEN c.relname LIKE '%_l' THEN 'Link'
                    WHEN c.relname LIKE '%_r' THEN 'Reference'
                    WHEN c.relname LIKE '%_b' THEN 'Bridge'
                    ELSE 'Other'
                END as table_type,
                EXISTS (
                    SELECT 1 FROM pg_trigger t
                    JOIN pg_proc p ON t.tgfoid = p.oid
                    WHERE t.tgrelid = c.oid 
                    AND p.proname LIKE 'audit_track_%'
                    AND NOT t.tgisinternal
                ) as has_audit_trigger
            FROM pg_class c
            JOIN pg_namespace n ON c.relnamespace = n.oid
            WHERE c.relkind = 'r'  -- Regular tables only
            AND n.nspname IN ('auth', 'business', 'raw', 'staging', 'api', 'audit', 'util')
            AND (c.relname LIKE '%_h' OR c.relname LIKE '%_s' OR c.relname LIKE '%_l' 
                 OR c.relname LIKE '%_r' OR c.relname LIKE '%_b')
            ORDER BY n.nspname, table_type, c.relname
        """)
        
        dv_tables = cursor.fetchall()
        
        print("Data Vault 2.0 table audit trigger status:")
        
        coverage_stats = {
            'Hub': {'with_triggers': 0, 'without_triggers': 0},
            'Satellite': {'with_triggers': 0, 'without_triggers': 0},
            'Link': {'with_triggers': 0, 'without_triggers': 0},
            'Reference': {'with_triggers': 0, 'without_triggers': 0},
            'Bridge': {'with_triggers': 0, 'without_triggers': 0},
            'Other': {'with_triggers': 0, 'without_triggers': 0}
        }
        
        tables_without_triggers = []
        
        for schema, table, table_type, has_trigger in dv_tables:
            full_name = f"{schema}.{table}"
            status = "✅ HAS AUDIT TRIGGER" if has_trigger else "❌ NO AUDIT TRIGGER"
            print(f"   {full_name} ({table_type}): {status}")
            
            if has_trigger:
                coverage_stats[table_type]['with_triggers'] += 1
            else:
                coverage_stats[table_type]['without_triggers'] += 1
                tables_without_triggers.append(full_name)
        
        print(f"\n📊 COVERAGE SUMMARY:")
        print("-" * 30)
        
        total_with_triggers = 0
        total_without_triggers = 0
        
        for table_type, stats in coverage_stats.items():
            with_triggers = stats['with_triggers']
            without_triggers = stats['without_triggers']
            total = with_triggers + without_triggers
            
            if total > 0:
                percentage = (with_triggers / total) * 100
                print(f"   {table_type}: {with_triggers}/{total} ({percentage:.1f}%) have audit triggers")
                
                total_with_triggers += with_triggers
                total_without_triggers += without_triggers
        
        grand_total = total_with_triggers + total_without_triggers
        if grand_total > 0:
            overall_percentage = (total_with_triggers / grand_total) * 100
            print(f"\n   📈 OVERALL: {total_with_triggers}/{grand_total} ({overall_percentage:.1f}%) Data Vault tables have audit triggers")
        
        if tables_without_triggers:
            print(f"\n⚠️  TABLES WITHOUT AUDIT TRIGGERS:")
            for table in tables_without_triggers:
                print(f"   • {table}")
        
        print("\n🤔 TRIGGER APPLICATION ANALYSIS:")
        print("-" * 50)
        
        # Check if there's a pattern for trigger application
        cursor.execute("""
            SELECT 
                'Automatic Application' as analysis_type,
                CASE 
                    WHEN COUNT(DISTINCT c.relname) = (
                        SELECT COUNT(*) FROM pg_class c2
                        JOIN pg_namespace n2 ON c2.relnamespace = n2.oid
                        WHERE c2.relkind = 'r'
                        AND n2.nspname IN ('auth', 'business', 'raw', 'staging', 'api', 'audit')
                        AND (c2.relname LIKE '%_h' OR c2.relname LIKE '%_s' OR c2.relname LIKE '%_l')
                    ) THEN 'ALL Data Vault tables have audit triggers - LIKELY AUTOMATIC'
                    ELSE 'SELECTIVE trigger application - LIKELY MANUAL'
                END as conclusion
            FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            JOIN pg_namespace n ON c.relnamespace = n.oid
            JOIN pg_proc p ON t.tgfoid = p.oid
            WHERE p.proname LIKE 'audit_track_%'
            AND NOT t.tgisinternal
            AND n.nspname IN ('auth', 'business', 'raw', 'staging', 'api', 'audit')
        """)
        
        analysis = cursor.fetchone()
        if analysis:
            print(f"   {analysis[1]}")
        
        # Check for any automatic trigger creation mechanisms
        cursor.execute("""
            SELECT 
                p.proname as function_name,
                pg_get_functiondef(p.oid) as function_def
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'util'
            AND (p.proname LIKE '%trigger%' OR p.proname LIKE '%audit%')
            AND p.proname NOT LIKE 'audit_track_%'
            ORDER BY p.proname
        """)
        
        helper_functions = cursor.fetchall()
        
        if helper_functions:
            print(f"\n🔧 POTENTIAL AUTOMATION HELPER FUNCTIONS:")
            for func_name, func_def in helper_functions:
                print(f"   • {func_name}")
        else:
            print(f"\n   No automation helper functions found - triggers likely applied manually")
        
        print("\n🎯 CONCLUSION:")
        print("-" * 30)
        
        if total_without_triggers == 0:
            print("   ✅ ALL Data Vault tables have audit triggers")
            print("   🤖 This suggests AUTOMATIC application or very thorough manual setup")
        elif total_without_triggers < total_with_triggers / 4:  # Less than 25% missing
            print("   ⚠️  Most tables have audit triggers, but some are missing")
            print("   🔧 This suggests SELECTIVE MANUAL application")
        else:
            print("   ❌ Many tables are missing audit triggers")
            print("   👤 This suggests MANUAL application on an as-needed basis")
        
        # Save detailed results
        investigation_results.update({
            'investigation_date': datetime.now().isoformat(),
            'total_tables_with_triggers': len(triggers_by_table),
            'coverage_stats': coverage_stats,
            'tables_without_triggers': tables_without_triggers,
            'overall_coverage_percentage': overall_percentage if grand_total > 0 else 0,
            'conclusion': analysis[1] if analysis else 'Unable to determine',
            'automation_helper_functions': [func[0] for func in helper_functions] if helper_functions else []
        })
        
        with open('audit_trigger_coverage_investigation.json', 'w') as f:
            json.dump(investigation_results, f, indent=2, default=str)
        
        print(f"\n📁 Detailed investigation saved to: audit_trigger_coverage_investigation.json")
        
        cursor.close()
        conn.close()
        
        return investigation_results
        
    except Exception as e:
        print(f"❌ Investigation failed: {e}")
        return {'status': 'ERROR', 'error': str(e)}

if __name__ == "__main__":
    print("🎯 This will help us understand how audit triggers are applied")
    print("   across the database - automatic vs manual!")
    print()
    
    results = investigate_trigger_coverage()
    
    if results and 'overall_coverage_percentage' in results:
        coverage = results['overall_coverage_percentage']
        print(f"\n📊 FINAL SUMMARY:")
        print(f"   Audit trigger coverage: {coverage:.1f}%")
        
        if coverage >= 95:
            print(f"   🎉 Excellent coverage - likely automatic or very thorough!")
        elif coverage >= 75:
            print(f"   ✅ Good coverage - mostly manual with systematic approach")
        elif coverage >= 50:
            print(f"   ⚠️  Moderate coverage - selective manual application")
        else:
            print(f"   ❌ Low coverage - ad-hoc manual application")
    else:
        print(f"\n❌ Investigation incomplete - check the results") 