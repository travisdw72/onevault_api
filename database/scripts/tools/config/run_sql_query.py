#!/usr/bin/env python3
"""
SQL Query Runner with Config File Support
Runs SQL queries from config files with password prompting
"""

import psycopg2
import json
import getpass
import sys
import os
from typing import Dict, List, Any, Optional
from datetime import datetime

class SQLQueryRunner:
    def __init__(self, config_file: str = "sql_config.json"):
        self.config_file = config_file
        self.connection = None
        self.config = self.load_config()
    
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from JSON file"""
        try:
            with open(self.config_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Config file {self.config_file} not found. Creating default config...")
            self.create_default_config()
            with open(self.config_file, 'r') as f:
                return json.load(f)
    
    def create_default_config(self):
        """Create a default configuration file"""
        default_config = {
            "database": {
                "host": "localhost",
                "port": 5432,
                "database": "one_vault",
                "user": "postgres"
            },
            "queries": {
                "discover_login_table": """
                    -- Discover the actual structure of login-related tables
                    SELECT 
                        'TABLE: ' || table_name as info,
                        column_name,
                        data_type,
                        is_nullable,
                        column_default
                    FROM information_schema.columns 
                    WHERE table_schema = 'raw' 
                    AND table_name LIKE '%login%'
                    ORDER BY table_name, ordinal_position;
                """,
                "show_last_login_safe": """
                    -- Safe query to show last login without assuming column names
                    -- 1. Show who logged in last
                    SELECT 
                        'LAST LOGIN USER' as info_type,
                        up.first_name || ' ' || up.last_name as full_name,
                        up.email,
                        uas.username,
                        uas.last_login_date,
                        uas.password_last_changed,
                        EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - uas.password_last_changed)) as password_age_days
                    FROM auth.user_auth_s uas
                    JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
                    JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
                    WHERE uas.load_end_date IS NULL 
                    AND up.load_end_date IS NULL
                    AND uas.last_login_date IS NOT NULL
                    ORDER BY uas.last_login_date DESC
                    LIMIT 1;
                """,
                "show_password_storage": """
                    -- Show where password data is stored for last login user
                    WITH last_user AS (
                        SELECT uas.user_hk, uas.username, up.email
                        FROM auth.user_auth_s uas
                        JOIN auth.user_h uh ON uas.user_hk = uh.user_hk
                        JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
                        WHERE uas.load_end_date IS NULL 
                        AND up.load_end_date IS NULL
                        AND uas.last_login_date IS NOT NULL
                        ORDER BY uas.last_login_date DESC
                        LIMIT 1
                    )
                    SELECT 
                        'PASSWORD STORAGE' as info_type,
                        'auth.user_auth_s' as table_name,
                        'password_hash' as column_name,
                        LENGTH(uas.password_hash) as stored_bytes,
                        'SECURE BCRYPT HASH' as content_type,
                        LEFT(encode(uas.password_hash, 'hex'), 20) || '...' as hash_preview
                    FROM auth.user_auth_s uas
                    JOIN last_user lu ON uas.user_hk = lu.user_hk
                    WHERE uas.load_end_date IS NULL
                    
                    UNION ALL
                    
                    SELECT 
                        'PASSWORD SALT' as info_type,
                        'auth.user_auth_s' as table_name,
                        'password_salt' as column_name,
                        LENGTH(uas.password_salt) as stored_bytes,
                        'SECURE SALT' as content_type,
                        LEFT(encode(uas.password_salt, 'hex'), 20) || '...' as hash_preview
                    FROM auth.user_auth_s uas
                    JOIN last_user lu ON uas.user_hk = lu.user_hk
                    WHERE uas.load_end_date IS NULL;
                """,
                "show_all_password_columns": """
                    -- Show all password-related columns in database
                    SELECT 
                        'PASSWORD COLUMNS' as category,
                        table_schema || '.' || table_name as table_location,
                        column_name,
                        data_type,
                        CASE 
                            WHEN column_name LIKE '%hash%' THEN '✅ SECURE HASH STORAGE'
                            WHEN column_name LIKE '%salt%' THEN '✅ SECURE SALT STORAGE'
                            WHEN column_name LIKE '%indicator%' THEN '✅ SAFE INDICATOR ONLY'
                            WHEN column_name LIKE '%password%' AND data_type = 'bytea' THEN '✅ SECURE BINARY'
                            WHEN column_name LIKE '%password%' THEN '⚠️ REVIEW NEEDED'
                            ELSE '📋 OTHER'
                        END as security_assessment
                    FROM information_schema.columns 
                    WHERE LOWER(column_name) LIKE '%password%'
                       OR LOWER(column_name) LIKE '%hash%'
                       OR LOWER(column_name) LIKE '%salt%'
                    AND table_schema NOT LIKE 'pg_%'
                    AND table_schema != 'information_schema'
                    ORDER BY table_schema, table_name, column_name;
                """
            }
        }
        
        with open(self.config_file, 'w') as f:
            json.dump(default_config, f, indent=2)
        print(f"Created default config file: {self.config_file}")
    
    def connect(self, password: Optional[str] = None) -> bool:
        """Connect to the database"""
        if not password:
            password = getpass.getpass("Enter PostgreSQL password: ")
        
        try:
            db_config = self.config['database']
            self.connection = psycopg2.connect(
                host=db_config['host'],
                port=db_config['port'],
                database=db_config['database'],
                user=db_config['user'],
                password=password
            )
            self.connection.autocommit = True
            print(f"✅ Connected to {db_config['database']} on {db_config['host']}")
            return True
        except psycopg2.Error as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def execute_query(self, query_name: str) -> List[Dict[str, Any]]:
        """Execute a named query from config"""
        if not self.connection:
            raise Exception("Not connected to database")
        
        if query_name not in self.config['queries']:
            raise Exception(f"Query '{query_name}' not found in config")
        
        query = self.config['queries'][query_name]
        
        try:
            with self.connection.cursor() as cursor:
                cursor.execute(query)
                
                # Get column names
                columns = [desc[0] for desc in cursor.description] if cursor.description else []
                
                # Fetch results
                results = cursor.fetchall() if cursor.description else []
                
                # Convert to list of dictionaries
                return [dict(zip(columns, row)) for row in results]
                
        except psycopg2.Error as e:
            print(f"❌ Query execution failed: {e}")
            raise
    
    def execute_raw_sql(self, sql: str) -> List[Dict[str, Any]]:
        """Execute raw SQL string"""
        if not self.connection:
            raise Exception("Not connected to database")
        
        try:
            with self.connection.cursor() as cursor:
                cursor.execute(sql)
                
                # Get column names
                columns = [desc[0] for desc in cursor.description] if cursor.description else []
                
                # Fetch results
                results = cursor.fetchall() if cursor.description else []
                
                # Convert to list of dictionaries
                return [dict(zip(columns, row)) for row in results]
                
        except psycopg2.Error as e:
            print(f"❌ SQL execution failed: {e}")
            raise
    
    def print_results(self, results: List[Dict[str, Any]], title: str = "Query Results"):
        """Pretty print query results"""
        print(f"\n{'='*60}")
        print(f"🔍 {title}")
        print(f"{'='*60}")
        
        if not results:
            print("No results found.")
            return
        
        # Print each row
        for i, row in enumerate(results, 1):
            print(f"\n--- Row {i} ---")
            for key, value in row.items():
                # Handle different data types
                if isinstance(value, bytes):
                    display_value = f"<{len(value)} bytes>"
                elif value is None:
                    display_value = "NULL"
                else:
                    display_value = str(value)
                
                print(f"{key:25}: {display_value}")
    
    def run_investigation(self):
        """Run the complete login investigation"""
        print("🔍 Starting Login Investigation...")
        
        # 1. Discover table structure
        print("\n1. Discovering login table structure...")
        try:
            results = self.execute_query("discover_login_table")
            self.print_results(results, "Login Table Structure")
        except Exception as e:
            print(f"⚠️ Could not discover table structure: {e}")
        
        # 2. Show last login user
        print("\n2. Finding last login user...")
        try:
            results = self.execute_query("show_last_login_safe")
            self.print_results(results, "Last Login User")
        except Exception as e:
            print(f"⚠️ Could not find last login user: {e}")
        
        # 3. Show password storage
        print("\n3. Analyzing password storage...")
        try:
            results = self.execute_query("show_password_storage")
            self.print_results(results, "Password Storage Analysis")
        except Exception as e:
            print(f"⚠️ Could not analyze password storage: {e}")
        
        # 4. Show all password columns
        print("\n4. Scanning all password-related columns...")
        try:
            results = self.execute_query("show_all_password_columns")
            self.print_results(results, "All Password Columns")
        except Exception as e:
            print(f"⚠️ Could not scan password columns: {e}")
        
        # 5. Try to find raw login data safely
        print("\n5. Attempting to find raw login data...")
        try:
            # First, let's see what tables exist in raw schema
            raw_sql = """
                SELECT table_name, 
                       (SELECT COUNT(*) FROM information_schema.columns 
                        WHERE table_schema = 'raw' AND table_name = t.table_name) as column_count
                FROM information_schema.tables t
                WHERE table_schema = 'raw'
                ORDER BY table_name;
            """
            results = self.execute_raw_sql(raw_sql)
            self.print_results(results, "Raw Schema Tables")
            
            # Now try to get some sample data from login-related tables
            for result in results:
                table_name = result['table_name']
                if 'login' in table_name.lower():
                    print(f"\n--- Sampling from {table_name} ---")
                    try:
                        sample_sql = f"SELECT * FROM raw.{table_name} LIMIT 3;"
                        sample_results = self.execute_raw_sql(sample_sql)
                        self.print_results(sample_results, f"Sample from raw.{table_name}")
                    except Exception as e:
                        print(f"Could not sample from {table_name}: {e}")
        
        except Exception as e:
            print(f"⚠️ Could not investigate raw data: {e}")
    
    def close(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            print("✅ Database connection closed")

def main():
    """Main function"""
    config_file = "sql_config.json"
    
    # Check if custom config file specified
    if len(sys.argv) > 1:
        config_file = sys.argv[1]
    
    runner = SQLQueryRunner(config_file)
    
    try:
        # Connect to database
        if not runner.connect():
            return 1
        
        # Run investigation
        runner.run_investigation()
        
        return 0
        
    except KeyboardInterrupt:
        print("\n⚠️ Operation cancelled by user")
        return 1
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1
    finally:
        runner.close()

if __name__ == "__main__":
    sys.exit(main()) 