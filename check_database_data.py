#!/usr/bin/env python3
"""
🔍 Check Database Data from AI API Tests
Runs SQL queries to see what data made it into the database from our API tests
"""

import psycopg2
import getpass
from datetime import datetime
import json

def connect_to_database():
    """Connect to the database"""
    try:
        # Get password securely
        password = getpass.getpass("Enter database password: ")
        
        conn = psycopg2.connect(
            dbname='one_vault',
            user='postgres', 
            password=password,
            host='localhost',
            port='5432'
        )
        
        print("✅ Connected to database successfully")
        return conn
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return None

def run_query(conn, query, description):
    """Run a query and display results"""
    print(f"\n🔍 {description}")
    print("=" * (len(description) + 4))
    
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        results = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        cursor.close()
        
        if not results:
            print("   No data found")
            return
        
        # Print column headers
        print("   " + " | ".join(f"{col:<20}" for col in columns))
        print("   " + "-" * (len(columns) * 23))
        
        # Print rows (limit to 10 for readability)
        for i, row in enumerate(results[:10]):
            row_str = []
            for val in row:
                if val is None:
                    row_str.append("NULL".ljust(20))
                elif isinstance(val, datetime):
                    row_str.append(str(val)[:19].ljust(20))
                else:
                    row_str.append(str(val)[:20].ljust(20))
            print("   " + " | ".join(row_str))
        
        if len(results) > 10:
            print(f"   ... and {len(results) - 10} more rows")
        
        print(f"   Total rows: {len(results)}")
        
    except Exception as e:
        print(f"   ❌ Query failed: {e}")

def main():
    """Main function to check database data"""
    print("🔍 CHECKING DATABASE DATA FROM API TESTS")
    print("=" * 50)
    
    conn = connect_to_database()
    if not conn:
        return
    
    queries = [
        # Quick count check first
        ("""
        SELECT 
            'AI Interactions (last hour)' as data_type,
            COUNT(*) as count
        FROM business.ai_interaction_details_s
        WHERE load_end_date IS NULL
        AND interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        
        UNION ALL
        
        SELECT 
            'Total AI Interactions (today)',
            COUNT(*)
        FROM business.ai_interaction_details_s
        WHERE load_end_date IS NULL
        AND interaction_timestamp >= CURRENT_DATE
        """, "QUICK COUNT CHECK"),
        
        # Check what tables exist
        ("""
        SELECT 
            table_schema,
            table_name,
            'TABLE' as object_type
        FROM information_schema.tables
        WHERE table_schema IN ('business', 'ai_agents', 'util')
        AND table_name LIKE '%ai%'
        ORDER BY table_schema, table_name
        """, "AI-RELATED TABLES"),
        
        # Check recent AI interactions
        ("""
        SELECT 
            aid.interaction_timestamp,
            aid.model_used,
            aid.context_type,
            aid.processing_time_ms,
            LEFT(aid.user_query, 50) as query_preview,
            LEFT(aid.ai_response, 50) as response_preview
        FROM business.ai_interaction_details_s aid
        WHERE aid.load_end_date IS NULL
        AND aid.interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '2 hours'
        ORDER BY aid.interaction_timestamp DESC
        LIMIT 10
        """, "RECENT AI INTERACTIONS"),
        
        # Check our specific test sessions
        ("""
        SELECT 
            interaction_timestamp,
            model_used,
            session_context,
            processing_time_ms,
            token_count_input,
            token_count_output,
            LEFT(user_query, 50) as query_preview
        FROM business.ai_interaction_details_s
        WHERE load_end_date IS NULL
        AND (session_context LIKE '%test_%' OR session_context LIKE '%demo_%')
        ORDER BY interaction_timestamp DESC
        """, "OUR TEST SESSIONS"),
        
        # Check tenant data for one_spa
        ("""
        SELECT 
            t.tenant_name,
            COUNT(aid.ai_interaction_hk) as total_interactions,
            MAX(aid.interaction_timestamp) as last_interaction,
            ROUND(AVG(aid.processing_time_ms), 2) as avg_response_time,
            SUM(aid.token_count_input + aid.token_count_output) as total_tokens
        FROM auth.tenant_h th
        JOIN auth.tenant_profile_s t ON th.tenant_hk = t.tenant_hk
        LEFT JOIN business.ai_interaction_h aih ON th.tenant_hk = aih.tenant_hk
        LEFT JOIN business.ai_interaction_details_s aid ON aih.ai_interaction_hk = aid.ai_interaction_hk
        WHERE t.load_end_date IS NULL
        AND aid.load_end_date IS NULL
        AND t.tenant_name = 'The One Spa Oregon'
        AND aid.interaction_timestamp >= CURRENT_TIMESTAMP - INTERVAL '2 hours'
        GROUP BY t.tenant_name
        """, "ONE SPA TENANT DATA"),
        
        # Check for audit logs
        ("""
        SELECT 
            execution_timestamp,
            execution_status,
            function_name,
            LEFT(execution_details, 60) as details_preview
        FROM util.audit_log
        WHERE execution_timestamp >= CURRENT_TIMESTAMP - INTERVAL '2 hours'
        AND (function_name LIKE '%ai_%' OR execution_details LIKE '%ai_%')
        ORDER BY execution_timestamp DESC
        LIMIT 10
        """, "RECENT AI AUDIT LOGS")
    ]
    
    for query, description in queries:
        try:
            run_query(conn, query, description)
        except Exception as e:
            print(f"   ⚠️ Skipping query due to error: {e}")
    
    # Try to check if any API functions were called
    print(f"\n🔍 CHECKING API FUNCTION CALLS")
    print("=" * 30)
    
    try:
        cursor = conn.cursor()
        cursor.execute("""
        SELECT routine_name, routine_schema
        FROM information_schema.routines
        WHERE routine_schema = 'api'
        AND routine_name LIKE '%ai%'
        ORDER BY routine_name
        """)
        api_functions = cursor.fetchall()
        cursor.close()
        
        if api_functions:
            print("   Found API functions:")
            for func_name, schema in api_functions:
                print(f"   - {schema}.{func_name}")
        else:
            print("   No AI-related API functions found")
            
    except Exception as e:
        print(f"   ❌ Error checking API functions: {e}")
    
    conn.close()
    print("\n✅ Database check complete!")

if __name__ == "__main__":
    main() 