#!/usr/bin/env python3
"""
Check for views, rules, or triggers that might be interfering
"""

import psycopg2
import getpass

def main():
    print("🔍 CHECKING FOR VIEW/RULE INTERFERENCE")
    print("=" * 40)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        # 1. Check if ai_observation_details_s is a view, not a table
        print("\n📊 Checking if ai_observation_details_s is actually a VIEW...")
        cursor.execute("""
            SELECT 
                schemaname, tablename, 'table' as object_type
            FROM pg_tables 
            WHERE schemaname = 'business' AND tablename = 'ai_observation_details_s'
            
            UNION ALL
            
            SELECT 
                schemaname, viewname, 'view' as object_type
            FROM pg_views 
            WHERE schemaname = 'business' AND viewname = 'ai_observation_details_s'
        """)
        
        objects = cursor.fetchall()
        for schema, name, obj_type in objects:
            print(f"   📋 {schema}.{name} is a {obj_type.upper()}")
            
        # 2. If it's a view, get the definition
        cursor.execute("""
            SELECT definition 
            FROM pg_views 
            WHERE schemaname = 'business' AND viewname = 'ai_observation_details_s'
        """)
        
        view_def = cursor.fetchone()
        if view_def:
            print(f"\n📜 VIEW DEFINITION:")
            definition = view_def[0]
            print(definition)
            
            if 'v_entity_hk' in definition:
                print("🐛 FOUND v_entity_hk in VIEW definition!")
                lines = definition.split('\n')
                for i, line in enumerate(lines, 1):
                    if 'v_entity_hk' in line:
                        print(f"   Line {i}: {line.strip()}")
        
        # 3. Check for rules on the table
        print("\n📏 Checking for RULES...")
        cursor.execute("""
            SELECT rulename, definition
            FROM pg_rules
            WHERE schemaname = 'business' AND tablename = 'ai_observation_details_s'
        """)
        
        rules = cursor.fetchall()
        if rules:
            print("⚠️ Found rules:")
            for rule_name, rule_def in rules:
                print(f"   📏 {rule_name}")
                if 'v_entity_hk' in rule_def:
                    print(f"      🐛 Contains v_entity_hk!")
                    print(f"      Definition: {rule_def[:200]}...")
        else:
            print("✅ No rules found")
            
        # 4. Check for the actual table name conflicts
        print("\n🏷️ Checking for table name conflicts...")
        cursor.execute("""
            SELECT table_schema, table_name, table_type
            FROM information_schema.tables
            WHERE table_name LIKE '%ai_observation%'
            ORDER BY table_schema, table_name
        """)
        
        similar_tables = cursor.fetchall()
        print("Similar table names:")
        for schema, name, table_type in similar_tables:
            print(f"   📊 {schema}.{name} ({table_type})")
            
        # 5. Check what the INSERT is actually trying to access
        print("\n🎯 Testing what object INSERT actually sees...")
        try:
            cursor.execute("""
                SELECT pg_class.relname, pg_namespace.nspname, pg_class.relkind
                FROM pg_class
                JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
                WHERE pg_namespace.nspname = 'business' 
                AND pg_class.relname = 'ai_observation_details_s'
            """)
            
            rel_info = cursor.fetchone()
            if rel_info:
                name, schema, kind = rel_info
                kind_map = {'r': 'table', 'v': 'view', 'm': 'materialized view'}
                print(f"   📋 {schema}.{name} is a {kind_map.get(kind, kind)}")
            
        except Exception as e:
            print(f"❌ Error checking relation: {e}")
            
        # 6. Check if there's a column name issue in the actual table
        print("\n🔍 Deep dive into table columns...")
        cursor.execute("""
            SELECT 
                column_name, 
                data_type, 
                column_default,
                is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'business' 
            AND table_name = 'ai_observation_details_s'
            AND column_name IN ('entity_hk', 'v_entity_hk')
            ORDER BY ordinal_position
        """)
        
        suspect_columns = cursor.fetchall()
        if suspect_columns:
            print("Entity-related columns:")
            for col_name, data_type, default, nullable in suspect_columns:
                print(f"   - {col_name} ({data_type}) {nullable} {default or ''}")
        else:
            print("❌ No entity_hk or v_entity_hk columns found!")
            
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Check failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 