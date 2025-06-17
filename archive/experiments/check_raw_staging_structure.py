#!/usr/bin/env python3
"""
Check Raw and Staging Table Structures
"""

import psycopg2
from universal_config_runner import CONFIG

def check_raw_staging_structure():
    """Check what columns exist in raw and staging tables"""
    
    conn = psycopg2.connect(**CONFIG['database'])
    cursor = conn.cursor()
    
    # Get raw and staging table structures
    cursor.execute("""
        SELECT table_schema, table_name, column_name, data_type
        FROM information_schema.columns 
        WHERE table_schema IN ('raw', 'staging')
        ORDER BY table_schema, table_name, ordinal_position
    """)
    
    results = cursor.fetchall()
    
    current_table = None
    for schema, table, column, data_type in results:
        table_full = f"{schema}.{table}"
        if table_full != current_table:
            print(f"\n{table_full}:")
            current_table = table_full
        print(f"  {column} ({data_type})")
    
    # Check which tables have tenant_hk
    cursor.execute("""
        SELECT table_schema, table_name
        FROM information_schema.columns 
        WHERE table_schema IN ('raw', 'staging')
        AND column_name = 'tenant_hk'
        ORDER BY table_schema, table_name
    """)
    
    tenant_hk_tables = cursor.fetchall()
    
    print(f"\n\nTables with tenant_hk column:")
    for schema, table in tenant_hk_tables:
        print(f"  {schema}.{table}")
    
    # Check which tables don't have tenant_hk
    cursor.execute("""
        SELECT DISTINCT table_schema, table_name
        FROM information_schema.columns 
        WHERE table_schema IN ('raw', 'staging')
        AND table_name NOT IN (
            SELECT table_name 
            FROM information_schema.columns 
            WHERE table_schema IN ('raw', 'staging')
            AND column_name = 'tenant_hk'
        )
        ORDER BY table_schema, table_name
    """)
    
    no_tenant_hk_tables = cursor.fetchall()
    
    print(f"\n\nTables WITHOUT tenant_hk column:")
    for schema, table in no_tenant_hk_tables:
        print(f"  {schema}.{table}")
    
    conn.close()

if __name__ == "__main__":
    check_raw_staging_structure() 