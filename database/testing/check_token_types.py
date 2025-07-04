#!/usr/bin/env python3
"""
Check Token Types - Find Valid Token Types for auth.generate_api_token
"""

import psycopg2
import getpass

def main():
    print("🔍 Checking Valid Token Types for Canvas Integration")
    print("=" * 60)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        # Get the check constraint for token_type (updated for PostgreSQL 13+)
        print("\n🔍 Finding token_type constraint...")
        cursor.execute("""
            SELECT 
                c.conname,
                pg_get_constraintdef(c.oid) as constraint_def,
                obj_description(c.oid, 'pg_constraint') as description
            FROM pg_constraint c
            JOIN pg_class t ON c.conrelid = t.oid
            JOIN pg_namespace n ON t.relnamespace = n.oid
            WHERE n.nspname = 'auth'
            AND t.relname = 'api_token_s'
            AND c.conname LIKE '%token%type%'
        """)
        
        constraints = cursor.fetchall()
        
        if constraints:
            for conname, constraint_def, description in constraints:
                print(f"   📋 Constraint: {conname}")
                print(f"   🔧 Definition: {constraint_def}")
                if description:
                    print(f"   📝 Description: {description}")
                print()
        else:
            print("   ⚠️ No token_type constraints found, checking broader...")
            
            # Check all constraints on the table
            cursor.execute("""
                SELECT 
                    c.conname,
                    pg_get_constraintdef(c.oid) as constraint_def
                FROM pg_constraint c
                JOIN pg_class t ON c.conrelid = t.oid
                JOIN pg_namespace n ON t.relnamespace = n.oid
                WHERE n.nspname = 'auth'
                AND t.relname = 'api_token_s'
                AND c.contype = 'c'  -- check constraints
            """)
            
            all_constraints = cursor.fetchall()
            for conname, constraint_def in all_constraints:
                if 'token_type' in constraint_def.lower():
                    print(f"   📋 Found: {conname}")
                    print(f"   🔧 Definition: {constraint_def}")
                    print()
        
        # Try to find existing token types in the database
        print("🔍 Checking existing token types in database...")
        cursor.execute("""
            SELECT DISTINCT token_type, COUNT(*) as count
            FROM auth.api_token_s 
            WHERE load_end_date IS NULL
            GROUP BY token_type
            ORDER BY count DESC
        """)
        
        existing_types = cursor.fetchall()
        
        if existing_types:
            print("   📊 Existing token types:")
            for token_type, count in existing_types:
                print(f"     ✅ '{token_type}' (used {count} times)")
        else:
            print("   📊 No existing tokens found")
            
        # Look for enum types or other constraints
        print("\n🔍 Checking for token_type enum or domain...")
        cursor.execute("""
            SELECT typname, typtype, typcategory 
            FROM pg_type 
            WHERE typname LIKE '%token%'
        """)
        
        types = cursor.fetchall()
        if types:
            print("   📋 Found token-related types:")
            for typname, typtype, typcategory in types:
                print(f"     🔧 {typname}: type={typtype}, category={typcategory}")
        
        # Check table definition for any comments or defaults
        print("\n🔍 Checking api_token_s table definition...")
        cursor.execute("""
            SELECT 
                column_name,
                data_type,
                column_default,
                is_nullable,
                col_description(pgc.oid, ordinal_position) as column_comment
            FROM information_schema.columns isc
            LEFT JOIN pg_class pgc ON pgc.relname = table_name
            WHERE table_schema = 'auth' 
            AND table_name = 'api_token_s'
            AND column_name = 'token_type'
        """)
        
        column_info = cursor.fetchone()
        if column_info:
            col_name, data_type, col_default, is_nullable, col_comment = column_info
            print(f"   📋 Column: {col_name}")
            print(f"   🔧 Data Type: {data_type}")
            print(f"   📝 Default: {col_default}")
            print(f"   ❓ Nullable: {is_nullable}")
            if col_comment:
                print(f"   💬 Comment: {col_comment}")
        
        # Try some common token types
        print("\n🧪 TESTING COMMON TOKEN TYPES...")
        test_types = ['api', 'web', 'mobile', 'system', 'user', 'integration', 'service']
        
        for test_type in test_types:
            try:
                cursor.execute("""
                    BEGIN;
                    INSERT INTO auth.api_token_s (
                        api_token_hk, load_date, hash_diff, token_hash, 
                        token_type, expires_at, is_revoked, record_source
                    ) VALUES (
                        'test_hk'::bytea, CURRENT_TIMESTAMP, 'test_diff'::bytea, 'test_hash'::bytea,
                        %s, CURRENT_TIMESTAMP + INTERVAL '1 day', false, 'test'
                    );
                    ROLLBACK;
                """, (test_type,))
                print(f"     ✅ '{test_type}' - VALID")
            except Exception as e:
                if 'check constraint' in str(e).lower():
                    print(f"     ❌ '{test_type}' - Invalid")
                else:
                    print(f"     ⚠️ '{test_type}' - Other error: {str(e)[:50]}...")
        
        # Suggest valid token types to try
        print("\n🎯 SUGGESTED TOKEN TYPES TO TRY:")
        if existing_types:
            print("   Based on existing tokens:")
            for token_type, count in existing_types:
                print(f"     🎯 Try: '{token_type}'")
        else:
            print("   Common enterprise token types to test:")
            suggested_types = [
                'api_access',
                'web_application', 
                'mobile_app',
                'integration',
                'system',
                'user_session',
                'service_account'
            ]
            for suggestion in suggested_types:
                print(f"     🎯 Try: '{suggestion}'")
        
        print(f"\n💡 QUICK TEST RECOMMENDATION:")
        if existing_types:
            first_type = existing_types[0][0]
            print(f"   Use existing type: '{first_type}'")
            print(f"   auth.generate_api_token(user_hk, '{first_type}', array['read','write'], '1 day')")
        else:
            print("   Try: auth.generate_api_token(user_hk, 'api', array['read','write'], '1 day')")
            
    except Exception as e:
        print(f"❌ Failed: {e}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main() 