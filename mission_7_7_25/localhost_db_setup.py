#!/usr/bin/env python3
"""
Localhost Database Setup for One_Barn_AI Testing
==============================================
Date: July 3, 2025
Purpose: Set up local testing environment with one_vault_site_testing database
Usage: python localhost_db_setup.py

This script:
1. Prompts for database password
2. Sets up environment variables
3. Starts the local API server
4. Runs the One_Barn_AI setup against localhost
"""

import os
import sys
import getpass
import subprocess
import time
import requests
from pathlib import Path

class LocalhostDatabaseSetup:
    def __init__(self):
        self.db_config = {
            'host': 'localhost',
            'port': '5432',
            'database': 'one_vault_site_testing',
            'username': 'postgres',  # Default, can be changed
            'password': None
        }
        self.api_port = 8000
        self.api_process = None
        
    def get_database_credentials(self):
        """Prompt user for database credentials."""
        print("🔐 Database Connection Setup")
        print("=" * 40)
        
        # Get database host (default localhost)
        host = input(f"Database Host [{self.db_config['host']}]: ").strip()
        if host:
            self.db_config['host'] = host
            
        # Get database port (default 5432)
        port = input(f"Database Port [{self.db_config['port']}]: ").strip()
        if port:
            self.db_config['port'] = port
            
        # Get database name (default one_vault_site_testing)
        database = input(f"Database Name [{self.db_config['database']}]: ").strip()
        if database:
            self.db_config['database'] = database
            
        # Get username (default postgres)
        username = input(f"Username [{self.db_config['username']}]: ").strip()
        if username:
            self.db_config['username'] = username
            
        # Get password (secure input)
        password = getpass.getpass(f"Password for {self.db_config['username']}: ")
        if not password:
            print("❌ Password is required!")
            return False
        self.db_config['password'] = password
        
        return True
        
    def build_database_url(self):
        """Build PostgreSQL connection URL."""
        return f"postgresql://{self.db_config['username']}:{self.db_config['password']}@{self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}"
        
    def test_database_connection(self):
        """Test database connection."""
        print("\n🔍 Testing Database Connection...")
        try:
            import psycopg2
            conn = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                database=self.db_config['database'],
                user=self.db_config['username'],
                password=self.db_config['password']
            )
            
            cursor = conn.cursor()
            cursor.execute("SELECT version()")
            version = cursor.fetchone()[0]
            
            # Test for OneVault schemas
            cursor.execute("SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('auth', 'api', 'business', 'ai_agents')")
            schemas = [row[0] for row in cursor.fetchall()]
            
            cursor.close()
            conn.close()
            
            print(f"✅ Database Connection Successful!")
            print(f"   Database: {self.db_config['database']}")
            print(f"   Version: {version[:50]}...")
            print(f"   OneVault Schemas: {schemas}")
            
            return True
            
        except ImportError:
            print("❌ psycopg2 not installed. Installing...")
            subprocess.run([sys.executable, '-m', 'pip', 'install', 'psycopg2-binary'])
            return self.test_database_connection()  # Retry after install
            
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
            
    def setup_environment(self):
        """Set up environment variables for API server."""
        database_url = self.build_database_url()
        os.environ['SYSTEM_DATABASE_URL'] = database_url
        
        # Additional environment variables for localhost testing
        os.environ['ENVIRONMENT'] = 'localhost'
        os.environ['DEBUG'] = 'true'
        os.environ['LOG_LEVEL'] = 'DEBUG'
        
        print("\n🔧 Environment Variables Set:")
        print(f"   SYSTEM_DATABASE_URL: postgresql://{self.db_config['username']}:***@{self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}")
        print(f"   ENVIRONMENT: localhost")
        print(f"   DEBUG: true")
        
    def find_api_server_path(self):
        """Find the API server main.py file."""
        possible_paths = [
            '../onevault_api/main.py',
            '../onevault_api/app/main.py',
            '../onevault-api/main.py',
            '../onevault-api/app/main.py'
        ]
        
        for path in possible_paths:
            full_path = Path(path).resolve()
            if full_path.exists():
                return str(full_path)
                
        return None
        
    def start_api_server(self):
        """Start the FastAPI server locally."""
        api_path = self.find_api_server_path()
        
        if not api_path:
            print("❌ Could not find API server main.py file")
            print("   Please ensure you're in the mission_7_7_25 directory")
            return False
            
        print(f"\n🚀 Starting API Server...")
        print(f"   API Path: {api_path}")
        print(f"   Server URL: http://localhost:{self.api_port}")
        print(f"   Press Ctrl+C to stop server")
        
        try:
            # Install uvicorn if not present
            try:
                import uvicorn
            except ImportError:
                print("📦 Installing uvicorn...")
                subprocess.run([sys.executable, '-m', 'pip', 'install', 'uvicorn[standard]'])
                
            # Start the server
            import uvicorn
            
            # Change to the API directory
            api_dir = Path(api_path).parent
            os.chdir(api_dir)
            
            # Start uvicorn server
            module_name = "main:app" if api_path.endswith("main.py") else "app.main:app"
            
            print(f"\n🎯 API Server Starting...")
            print(f"   Module: {module_name}")
            print(f"   Directory: {api_dir}")
            print(f"   URL: http://localhost:{self.api_port}")
            print("\n" + "="*60)
            
            uvicorn.run(
                module_name,
                host="0.0.0.0",
                port=self.api_port,
                reload=True,
                log_level="info"
            )
            
        except KeyboardInterrupt:
            print("\n🛑 Server stopped by user")
            return True
        except Exception as e:
            print(f"❌ Failed to start API server: {e}")
            return False
            
    def wait_for_api_server(self):
        """Wait for API server to be ready."""
        max_attempts = 30
        for attempt in range(max_attempts):
            try:
                response = requests.get(f"http://localhost:{self.api_port}/health", timeout=2)
                if response.status_code == 200:
                    print(f"✅ API Server Ready! (attempt {attempt + 1})")
                    return True
            except requests.RequestException:
                pass
                
            if attempt < max_attempts - 1:
                print(f"⏳ Waiting for API server... (attempt {attempt + 1}/{max_attempts})")
                time.sleep(2)
                
        print("❌ API server failed to start within timeout")
        return False
        
    def run_one_barn_setup(self):
        """Run the One_Barn_AI setup against localhost."""
        print("\n🏇 Running One_Barn_AI Setup Against Localhost...")
        
        try:
            # Import and run the localhost setup
            from one_barn_ai_localhost_setup import LocalhostOneBarnSetup
            
            setup = LocalhostOneBarnSetup()
            setup.setup_demo_environment()
            
            print("✅ One_Barn_AI setup completed successfully!")
            return True
            
        except Exception as e:
            print(f"❌ One_Barn_AI setup failed: {e}")
            return False
            
    def run_validation_tests(self):
        """Run validation tests against localhost."""
        print("\n🧪 Running Validation Tests...")
        
        try:
            result = subprocess.run([
                sys.executable, 
                'api_validation_quick_test.py', 
                f'http://localhost:{self.api_port}'
            ], capture_output=True, text=True)
            
            print(result.stdout)
            if result.stderr:
                print(f"Stderr: {result.stderr}")
                
            return result.returncode == 0
            
        except Exception as e:
            print(f"❌ Validation tests failed: {e}")
            return False

def main():
    """Main execution function."""
    print("🏠 OneVault Localhost Testing Setup")
    print("=" * 50)
    print("This will set up localhost testing for One_Barn_AI demo")
    print("")
    
    setup = LocalhostDatabaseSetup()
    
    # Step 1: Get database credentials
    if not setup.get_database_credentials():
        print("❌ Setup cancelled")
        return 1
        
    # Step 2: Test database connection
    if not setup.test_database_connection():
        print("❌ Database connection failed")
        return 1
        
    # Step 3: Set up environment
    setup.setup_environment()
    
    # Step 4: Ask user what they want to do
    print("\n🎯 What would you like to do?")
    print("   1. Start API Server (for manual testing)")
    print("   2. Run One_Barn_AI Setup (requires running API server)")
    print("   3. Run Validation Tests (requires running API server)")
    print("   4. Complete Setup (API server + One_Barn setup)")
    
    choice = input("\nEnter your choice (1-4): ").strip()
    
    if choice == '1':
        return 0 if setup.start_api_server() else 1
    elif choice == '2':
        return 0 if setup.run_one_barn_setup() else 1
    elif choice == '3':
        return 0 if setup.run_validation_tests() else 1
    elif choice == '4':
        print("\n🚀 Starting Complete Setup...")
        print("Note: You'll need to run the API server in one terminal")
        print("      and the setup in another terminal")
        print("")
        print("Step 1: Run this command in one terminal:")
        print(f"   python localhost_db_setup.py  # Choose option 1")
        print("")
        print("Step 2: In another terminal, run:")
        print(f"   python one_barn_ai_localhost_setup.py")
        print("")
        return 0
    else:
        print("❌ Invalid choice")
        return 1

if __name__ == "__main__":
    sys.exit(main())
