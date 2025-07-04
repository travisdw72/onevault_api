#!/usr/bin/env python3
"""
Extract exact function source and analyze every v_entity_hk reference
"""

import psycopg2
import getpass

def main():
    print("🔍 EXTRACTING EXACT FUNCTION SOURCE")
    print("=" * 40)
    
    password = getpass.getpass("Database password: ")
    
    try:
        conn = psycopg2.connect(
            host="localhost", port=5432, database="one_vault_site_testing",
            user="postgres", password=password
        )
        cursor = conn.cursor()
        print("✅ Connected to database")
        
        # Get the exact function source
        cursor.execute("""
            SELECT pg_get_functiondef(p.oid)
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'api' AND p.proname = 'ai_log_observation'
        """)
        
        source = cursor.fetchone()[0]
        
        # Split into lines and find every v_entity_hk reference
        lines = source.split('\n')
        print(f"\n📜 Function has {len(lines)} lines")
        
        v_entity_hk_lines = []
        entity_hk_lines = []
        
        for i, line in enumerate(lines, 1):
            if 'v_entity_hk' in line:
                v_entity_hk_lines.append((i, line.strip()))
            elif 'entity_hk' in line:
                entity_hk_lines.append((i, line.strip()))
        
        print(f"\n🐛 Found {len(v_entity_hk_lines)} lines with 'v_entity_hk':")
        for line_num, line_text in v_entity_hk_lines:
            print(f"   Line {line_num}: {line_text}")
            
        print(f"\n📊 Found {len(entity_hk_lines)} lines with 'entity_hk':")
        for line_num, line_text in entity_hk_lines:
            print(f"   Line {line_num}: {line_text}")
            
        # Check for any suspicious patterns
        print(f"\n🔍 Looking for suspicious patterns...")
        
        # Look for any SQL that might be dynamically built
        dynamic_sql_lines = []
        for i, line in enumerate(lines, 1):
            line_lower = line.lower().strip()
            if any(keyword in line_lower for keyword in ['execute', 'format(', 'query', '||']):
                if 'entity' in line_lower:
                    dynamic_sql_lines.append((i, line.strip()))
        
        if dynamic_sql_lines:
            print("⚠️ Found potential dynamic SQL with entity references:")
            for line_num, line_text in dynamic_sql_lines:
                print(f"   Line {line_num}: {line_text}")
        else:
            print("✅ No dynamic SQL found")
            
        # Look for table/column references that might be wrong
        print(f"\n🏷️ Checking all table references...")
        table_refs = []
        for i, line in enumerate(lines, 1):
            if 'ai_observation_details_s' in line.lower():
                table_refs.append((i, line.strip()))
                
        print(f"Found {len(table_refs)} references to ai_observation_details_s:")
        for line_num, line_text in table_refs:
            print(f"   Line {line_num}: {line_text}")
            
        # Check the exact INSERT statement
        print(f"\n💉 Finding the INSERT statement...")
        in_insert = False
        insert_lines = []
        
        for i, line in enumerate(lines, 1):
            if 'INSERT INTO business.ai_observation_details_s' in line:
                in_insert = True
                insert_lines.append((i, line.strip()))
            elif in_insert and line.strip().startswith(')'):
                insert_lines.append((i, line.strip()))
                break
            elif in_insert:
                insert_lines.append((i, line.strip()))
                
        print("INSERT statement:")
        for line_num, line_text in insert_lines:
            print(f"   Line {line_num}: {line_text}")
            if 'v_entity_hk' in line_text:
                print(f"      ⚠️ This line contains v_entity_hk")
                
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Extraction failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main() 