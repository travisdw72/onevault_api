#!/usr/bin/env python3
"""
Check Audit Schema Structure
Investigates the actual audit table structure to understand the real schema
"""

import psycopg2
import psycopg2.extras
import getpass
from database.scripts.investigate_db_configFile import DATABASE_CONFIG

def main():
    config = DATABASE_CONFIG.copy()
    config['password'] = getpass.getpass('Enter PostgreSQL password: ')

    conn = psycopg2.connect(**config)
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    print('🔍 Checking Audit Schema Structure...')
    print('=' * 50)

    # Check audit tables
    print('\n📋 Audit Tables:')
    cursor.execute("""
        SELECT 
            table_name,
            table_type
        FROM information_schema.tables 
        WHERE table_schema = 'audit'
        ORDER BY table_name;
    """)
    
    tables = cursor.fetchall()
    for table in tables:
        print(f"  - {table['table_name']} ({table['table_type']})")

    # Check audit_event_h structure
    print('\n📋 audit_event_h columns:')
    cursor.execute("""
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default
        FROM information_schema.columns 
        WHERE table_schema = 'audit' 
        AND table_name = 'audit_event_h'
        ORDER BY ordinal_position;
    """)
    
    columns = cursor.fetchall()
    for col in columns:
        print(f"  - {col['column_name']}: {col['data_type']} ({'NULL' if col['is_nullable'] == 'YES' else 'NOT NULL'})")

    # Check audit_detail_s structure
    print('\n📋 audit_detail_s columns:')
    cursor.execute("""
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default
        FROM information_schema.columns 
        WHERE table_schema = 'audit' 
        AND table_name = 'audit_detail_s'
        ORDER BY ordinal_position;
    """)
    
    columns = cursor.fetchall()
    for col in columns:
        print(f"  - {col['column_name']}: {col['data_type']} ({'NULL' if col['is_nullable'] == 'YES' else 'NOT NULL'})")

    # Check for any existing audit data
    print('\n📋 Existing audit data:')
    cursor.execute("""
        SELECT 
            COUNT(*) as total_events,
            MAX(load_date) as last_event,
            MIN(load_date) as first_event
        FROM audit.audit_event_h;
    """)
    
    result = cursor.fetchone()
    if result:
        print(f"  - Total events: {result['total_events']}")
        print(f"  - First event: {result['first_event']}")
        print(f"  - Last event: {result['last_event']}")

    # Check audit detail data
    cursor.execute("""
        SELECT 
            COUNT(*) as total_details,
            COUNT(DISTINCT table_name) as unique_tables,
            COUNT(DISTINCT operation) as unique_operations
        FROM audit.audit_detail_s;
    """)
    
    result = cursor.fetchone()
    if result:
        print(f"  - Total detail records: {result['total_details']}")
        print(f"  - Unique tables audited: {result['unique_tables']}")
        print(f"  - Unique operations: {result['unique_operations']}")

    # Show sample audit data if any exists
    print('\n📋 Sample audit records:')
    cursor.execute("""
        SELECT 
            aeh.audit_event_hk,
            ads.table_name,
            ads.operation,
            ads.load_date
        FROM audit.audit_event_h aeh
        JOIN audit.audit_detail_s ads ON aeh.audit_event_hk = ads.audit_event_hk
        ORDER BY ads.load_date DESC
        LIMIT 5;
    """)
    
    samples = cursor.fetchall()
    if samples:
        for sample in samples:
            print(f"  - {sample['table_name']}.{sample['operation']} at {sample['load_date']}")
    else:
        print("  - No audit records found")

    conn.close()
    print('\n✅ Audit schema investigation complete')

if __name__ == "__main__":
    main() 