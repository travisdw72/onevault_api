#!/usr/bin/env python3
"""
Simple Configuration Runner
Demonstrates single source of truth principle with JSON and Python support
(No external dependencies required)
"""

import json
import psycopg2
import getpass
import sys
import os
import importlib.util
from typing import Dict, List, Any, Optional
from pathlib import Path
from datetime import datetime

class SimpleConfigRunner:
    """
    Configuration runner that supports:
    - JSON (.json)
    - Python (.py)
    """
    
    def __init__(self, config_path: str):
        self.config_path = Path(config_path)
        self.config = None
        self.connection = None
        self.config_format = self._detect_format()
        
    def _detect_format(self) -> str:
        """Detect configuration format from file extension"""
        suffix = self.config_path.suffix.lower()
        if suffix == '.json':
            return 'json'
        elif suffix == '.py':
            return 'python'
        else:
            return 'unknown'
    
    def load_config(self) -> Dict[str, Any]:
        """Load configuration based on detected format"""
        if not self.config_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {self.config_path}")
        
        print(f"📁 Loading {self.config_format.upper()} configuration from: {self.config_path}")
        
        if self.config_format == 'json':
            return self._load_json()
        elif self.config_format == 'python':
            return self._load_python()
        else:
            raise ValueError(f"Unsupported configuration format: {self.config_format}")
    
    def _load_json(self) -> Dict[str, Any]:
        """Load JSON configuration"""
        with open(self.config_path, 'r') as f:
            return json.load(f)
    
    def _load_python(self) -> Dict[str, Any]:
        """Load Python configuration module"""
        spec = importlib.util.spec_from_file_location("config", self.config_path)
        config_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(config_module)
        
        # Extract configuration from module
        if hasattr(config_module, 'CONFIG'):
            return config_module.CONFIG
        else:
            # Extract all uppercase variables as config
            return {
                key.lower(): value for key, value in vars(config_module).items()
                if key.isupper() and not key.startswith('_')
            }
    
    def connect_database(self, password: Optional[str] = None) -> bool:
        """Connect to database using configuration"""
        if not self.config:
            self.config = self.load_config()
        
        db_config = self.config.get('database', {})
        
        if not password:
            password = getpass.getpass(f"Enter password for {db_config.get('user', 'postgres')}: ")
        
        try:
            self.connection = psycopg2.connect(
                host=db_config.get('host', 'localhost'),
                port=db_config.get('port', 5432),
                database=db_config.get('database', 'one_vault'),
                user=db_config.get('user', 'postgres'),
                password=password
            )
            self.connection.autocommit = True
            print(f"✅ Connected to {db_config.get('database')} on {db_config.get('host')}")
            return True
        except psycopg2.Error as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def execute_query(self, query_name: str, params: Optional[tuple] = None) -> List[Dict[str, Any]]:
        """Execute a named query from configuration"""
        if not self.connection:
            raise Exception("Not connected to database")
        
        if not self.config:
            self.config = self.load_config()
        
        queries = self.config.get('queries', {})
        if query_name not in queries:
            available = list(queries.keys())
            raise Exception(f"Query '{query_name}' not found. Available: {available}")
        
        query = queries[query_name]
        
        # Handle different query formats
        if isinstance(query, dict):
            sql = query.get('sql', query.get('query', ''))
        else:
            sql = str(query).strip()
        
        try:
            with self.connection.cursor() as cursor:
                if params:
                    cursor.execute(sql, params)
                else:
                    cursor.execute(sql)
                
                # Get column names
                columns = [desc[0] for desc in cursor.description] if cursor.description else []
                
                # Fetch results
                results = cursor.fetchall() if cursor.description else []
                
                # Convert to list of dictionaries
                return [dict(zip(columns, row)) for row in results]
                
        except psycopg2.Error as e:
            print(f"❌ Query execution failed: {e}")
            print(f"Query: {sql}")
            raise
    
    def list_available_queries(self) -> List[str]:
        """List all available queries in configuration"""
        if not self.config:
            self.config = self.load_config()
        
        return list(self.config.get('queries', {}).keys())
    
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
                elif isinstance(value, datetime):
                    display_value = value.strftime("%Y-%m-%d %H:%M:%S")
                else:
                    display_value = str(value)
                
                print(f"{key:25}: {display_value}")
    
    def show_config_info(self):
        """Display configuration information"""
        if not self.config:
            self.config = self.load_config()
        
        print(f"\n{'='*60}")
        print(f"📋 Configuration Information")
        print(f"{'='*60}")
        print(f"Format: {self.config_format.upper()}")
        print(f"File: {self.config_path}")
        print(f"Size: {self.config_path.stat().st_size} bytes")
        
        # Show main sections
        print(f"\nMain sections:")
        for key in self.config.keys():
            if isinstance(self.config[key], dict):
                sub_keys = len(self.config[key])
                print(f"  {key}: {sub_keys} items")
            elif isinstance(self.config[key], list):
                print(f"  {key}: {len(self.config[key])} items")
            else:
                print(f"  {key}: {type(self.config[key]).__name__}")
        
        # Show available queries
        queries = self.config.get('queries', {})
        if queries:
            print(f"\nAvailable queries ({len(queries)}):")
            for query_name in queries.keys():
                print(f"  - {query_name}")
    
    def run_interactive_mode(self):
        """Run in interactive mode"""
        print(f"\n🚀 Interactive Mode - {self.config_format.upper()} Configuration")
        print("Commands: list, run <query_name>, info, quit")
        
        while True:
            try:
                command = input("\n> ").strip().lower()
                
                if command == 'quit' or command == 'exit':
                    break
                elif command == 'list':
                    queries = self.list_available_queries()
                    print(f"Available queries: {queries}")
                elif command == 'info':
                    self.show_config_info()
                elif command.startswith('run '):
                    query_name = command[4:].strip()
                    try:
                        results = self.execute_query(query_name)
                        self.print_results(results, f"Results for '{query_name}'")
                    except Exception as e:
                        print(f"❌ Error executing query: {e}")
                else:
                    print("Unknown command. Use: list, run <query_name>, info, quit")
                    
            except KeyboardInterrupt:
                print("\n👋 Goodbye!")
                break
            except Exception as e:
                print(f"❌ Error: {e}")
    
    def close(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            print("✅ Database connection closed")

def main():
    """Main function with command line argument support"""
    if len(sys.argv) < 2:
        print("Usage: python simple_config_runner.py <config_file> [query_name]")
        print("\nSupported formats:")
        print("  - JSON (.json)")
        print("  - Python (.py)")
        print("\nExamples:")
        print("  python simple_config_runner.py sql_config.json")
        print("  python simple_config_runner.py config_examples/config.py")
        return 1
    
    config_file = sys.argv[1]
    query_name = sys.argv[2] if len(sys.argv) > 2 else None
    
    runner = SimpleConfigRunner(config_file)
    
    try:
        # Show config info
        runner.show_config_info()
        
        # Connect to database
        if not runner.connect_database():
            return 1
        
        if query_name:
            # Run specific query
            print(f"\n🔍 Executing query: {query_name}")
            results = runner.execute_query(query_name)
            runner.print_results(results, f"Results for '{query_name}'")
        else:
            # Run interactive mode
            runner.run_interactive_mode()
        
        return 0
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1
    finally:
        runner.close()

if __name__ == "__main__":
    sys.exit(main()) 