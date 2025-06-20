#!/usr/bin/env python3
"""
Debug Raw Layer - Site Tracking Investigation
Investigates current raw schema state and provides fix for index issues
"""

import psycopg2
import getpass
import sys
from datetime import datetime

def investigate_raw_schema():
    """Investigate current raw schema state"""
    try:
        # Get database password
        password = getpass.getpass('Enter PostgreSQL password: ')
        
        # Connect to database
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            database='one_vault',
            user='postgres',
            password=password
        )
        
        cursor = conn.cursor()
        
        print("=" * 60)
        print("RAW SCHEMA INVESTIGATION")
        print("=" * 60)
        
        # Check if raw schema exists
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name = 'raw'
        """)
        raw_schema = cursor.fetchone()
        print(f"✅ Raw schema exists: {bool(raw_schema)}")
        
        # Check tables in raw schema
        cursor.execute("""
            SELECT schemaname, tablename, tableowner 
            FROM pg_tables 
            WHERE schemaname = 'raw'
            ORDER BY tablename
        """)
        
        raw_tables = cursor.fetchall()
        print(f"\n📋 RAW SCHEMA TABLES ({len(raw_tables)} found):")
        for table in raw_tables:
            print(f"  • {table[0]}.{table[1]} (owner: {table[2]})")
        
        # Check if our target table exists
        cursor.execute("""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_schema = 'raw' 
            AND table_name = 'site_tracking_events_r'
            ORDER BY ordinal_position
        """)
        
        columns = cursor.fetchall()
        print(f"\n🔍 SITE_TRACKING_EVENTS_R STRUCTURE:")
        if columns:
            print("  Table already exists with columns:")
            for col in columns:
                nullable = "NULL" if col[2] == "YES" else "NOT NULL"
                default = f" DEFAULT {col[3]}" if col[3] else ""
                print(f"    {col[0]}: {col[1]} {nullable}{default}")
        else:
            print("  ❌ Table does not exist")
        
        # Check existing indexes
        cursor.execute("""
            SELECT indexname, indexdef
            FROM pg_indexes 
            WHERE schemaname = 'raw' 
            AND tablename = 'site_tracking_events_r'
        """)
        
        indexes = cursor.fetchall()
        print(f"\n📊 EXISTING INDEXES ({len(indexes)} found):")
        for idx in indexes:
            print(f"  • {idx[0]}")
            print(f"    {idx[1]}")
        
        # Check for problematic indexes with DATE_TRUNC
        cursor.execute("""
            SELECT indexname, indexdef
            FROM pg_indexes 
            WHERE schemaname = 'raw' 
            AND tablename = 'site_tracking_events_r'
            AND indexdef LIKE '%DATE_TRUNC%'
        """)
        
        problematic_indexes = cursor.fetchall()
        print(f"\n⚠️  PROBLEMATIC INDEXES WITH DATE_TRUNC ({len(problematic_indexes)} found):")
        for idx in problematic_indexes:
            print(f"  • {idx[0]}: {idx[1]}")
        
        # Check util functions that we might need
        cursor.execute("""
            SELECT routine_name, routine_type
            FROM information_schema.routines 
            WHERE routine_schema = 'util' 
            AND routine_name IN ('hash_binary', 'current_load_date', 'get_record_source')
            ORDER BY routine_name
        """)
        
        util_functions = cursor.fetchall()
        print(f"\n🔧 UTIL FUNCTIONS ({len(util_functions)} found):")
        for func in util_functions:
            print(f"  • util.{func[0]} ({func[1]})")
        
        # Check tenant_h table for reference
        cursor.execute("""
            SELECT column_name, data_type
            FROM information_schema.columns 
            WHERE table_schema = 'auth' 
            AND table_name = 'tenant_h'
            ORDER BY ordinal_position
        """)
        
        tenant_columns = cursor.fetchall()
        print(f"\n🏢 TENANT_H STRUCTURE ({len(tenant_columns)} columns):")
        for col in tenant_columns:
            print(f"  • {col[0]}: {col[1]}")
        
        cursor.close()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"❌ Database investigation failed: {e}")
        return False

def provide_fix_recommendations():
    """Provide recommendations to fix the index issue"""
    print("\n" + "=" * 60)
    print("FIX RECOMMENDATIONS")
    print("=" * 60)
    
    print("\n🔧 ISSUE IDENTIFIED:")
    print("   DATE_TRUNC function is NOT IMMUTABLE in PostgreSQL")
    print("   Functions in index expressions MUST be IMMUTABLE")
    
    print("\n✅ SOLUTION OPTIONS:")
    print("   1. Remove the problematic index")
    print("   2. Create a simpler time-based index")
    print("   3. Use expression index with IMMUTABLE function")
    
    print("\n📝 RECOMMENDED FIXES:")
    print("   • Replace: DATE_TRUNC('month', received_timestamp)")
    print("   • With: received_timestamp::date")
    print("   • Or: EXTRACT(YEAR FROM received_timestamp), EXTRACT(MONTH FROM received_timestamp)")
    
    print("\n🛠️  CORRECTED INDEX:")
    print("   CREATE INDEX idx_site_tracking_events_r_tenant_date")
    print("   ON raw.site_tracking_events_r(tenant_hk, received_timestamp::date);")

if __name__ == "__main__":
    print("🔍 Starting Raw Layer Investigation...")
    
    if investigate_raw_schema():
        provide_fix_recommendations()
        print(f"\n✅ Investigation completed at {datetime.now()}")
    else:
        print(f"\n❌ Investigation failed at {datetime.now()}")
        sys.exit(1) 