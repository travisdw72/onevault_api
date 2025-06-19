#!/usr/bin/env python3
"""
Quick script to check what AI functions actually exist in the database
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

    print('🔍 Checking actual AI functions in the database...')
    cursor.execute("""
        SELECT 
            routine_name,
            routine_type,
            routine_definition IS NOT NULL as has_definition
        FROM information_schema.routines 
        WHERE routine_schema = 'api' 
        AND routine_name LIKE 'ai_%'
        ORDER BY routine_name;
    """)

    results = cursor.fetchall()
    print(f'Found {len(results)} AI functions:')
    for result in results:
        print(f'  - {result["routine_name"]} ({result["routine_type"]})')

    print('\n🔍 Checking audit table structure...')
    cursor.execute("""
        SELECT 
            column_name,
            data_type,
            is_nullable
        FROM information_schema.columns 
        WHERE table_schema = 'audit' 
        AND table_name = 'audit_detail_s'
        ORDER BY ordinal_position;
    """)

    audit_columns = cursor.fetchall()
    print(f'Audit detail columns ({len(audit_columns)}):')
    for col in audit_columns:
        print(f'  - {col["column_name"]} ({col["data_type"]})')

    print('\n🔍 Checking what API functions exist...')
    cursor.execute("""
        SELECT 
            routine_name,
            routine_type
        FROM information_schema.routines 
        WHERE routine_schema = 'api' 
        ORDER BY routine_name;
    """)

    api_functions = cursor.fetchall()
    print(f'Found {len(api_functions)} API functions total:')
    for func in api_functions[:10]:  # Show first 10
        print(f'  - {func["routine_name"]} ({func["routine_type"]})')
    if len(api_functions) > 10:
        print(f'  ... and {len(api_functions) - 10} more')

    conn.close()

if __name__ == "__main__":
    main() 