#!/usr/bin/env python3
"""
Check Hub Table Compliance with Data Vault 2.0 Naming Conventions
"""

import psycopg2
import sys

def check_hub_compliance():
    try:
        # Database connection
        import getpass
        password = getpass.getpass("Enter PostgreSQL password: ")
        conn = psycopg2.connect(
            host='localhost',
            database='one_vault',
            user='postgres',
            password=password
        )
        conn.autocommit = True
        cur = conn.cursor()

        # Check hub table compliance
        query = """
        WITH hub_compliance AS (
            SELECT 
                schemaname || '.' || tablename as table_name,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = REPLACE(pt.tablename, '_h', '_hk')
                    ) THEN 'HAS_HASH_KEY'
                    ELSE 'MISSING_HASH_KEY'
                END as hash_key_check,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = REPLACE(pt.tablename, '_h', '_bk')
                    ) THEN 'HAS_BUSINESS_KEY'
                    ELSE 'MISSING_BUSINESS_KEY'
                END as business_key_check,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = pt.schemaname 
                        AND table_name = pt.tablename 
                        AND column_name = 'tenant_hk'
                    ) THEN 'HAS_TENANT_ISOLATION'
                    ELSE 'MISSING_TENANT_ISOLATION'
                END as tenant_isolation_check
            FROM pg_tables pt
            WHERE pt.tablename LIKE '%_h' 
            AND pt.schemaname NOT IN ('information_schema', 'pg_catalog')
            ORDER BY table_name
        )
        SELECT 
            table_name,
            hash_key_check,
            business_key_check,
            tenant_isolation_check,
            CASE 
                WHEN hash_key_check = 'HAS_HASH_KEY' 
                AND business_key_check = 'HAS_BUSINESS_KEY' 
                AND tenant_isolation_check = 'HAS_TENANT_ISOLATION' 
                THEN 'FULLY_COMPLIANT'
                ELSE 'NON_COMPLIANT'
            END as compliance_status
        FROM hub_compliance
        ORDER BY compliance_status DESC, table_name;
        """

        cur.execute(query)
        results = cur.fetchall()

        print("🔍 Hub Table Compliance Analysis:")
        print("=" * 80)
        
        compliant_count = 0
        non_compliant_count = 0
        
        for row in results:
            table_name, hash_key, business_key, tenant_isolation, status = row
            
            if status == 'FULLY_COMPLIANT':
                compliant_count += 1
                print(f"✅ {table_name}: COMPLIANT")
            else:
                non_compliant_count += 1
                print(f"❌ {table_name}: NON-COMPLIANT")
                print(f"   - Hash Key: {hash_key}")
                print(f"   - Business Key: {business_key}")
                print(f"   - Tenant Isolation: {tenant_isolation}")
                print()

        total_tables = compliant_count + non_compliant_count
        compliance_percentage = (compliant_count / total_tables * 100) if total_tables > 0 else 0
        
        print("=" * 80)
        print(f"📊 Summary:")
        print(f"   Total Hub Tables: {total_tables}")
        print(f"   Compliant: {compliant_count}")
        print(f"   Non-Compliant: {non_compliant_count}")
        print(f"   Compliance Rate: {compliance_percentage:.2f}%")

        cur.close()
        conn.close()
        
        return compliance_percentage

    except Exception as e:
        print(f"Error: {e}")
        return 0

if __name__ == "__main__":
    check_hub_compliance() 