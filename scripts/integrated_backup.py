#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
INTEGRATED DATABASE BACKUP SYSTEM
==================================
Combines Python file operations with existing Data Vault 2.0 backup management

FEATURES:
- Integrates with backup_mgmt schema functions
- Uses existing backup tracking and temporal data
- Maintains file-level backup creation
- Leverages enterprise backup scheduling
- Full audit trail in database tables
"""

import os
import sys
import subprocess
import datetime
import json
import logging
import argparse
import psycopg2
import getpass
from pathlib import Path
from typing import Dict, Any, Optional, List, Tuple

# Try to load environment variables from .env file
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    # dotenv not installed, will use manual environment variables
    pass

class IntegratedBackupSystem:
    def __init__(self):
        self.script_dir = Path(__file__).parent
        self.project_root = self.script_dir.parent
        self.backup_dir = self.project_root / "database" / "backups"
        self.config_file = self.script_dir / "backup_config.json"
        
        # Ensure backup directory exists
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        
        # Setup logging
        self.setup_logging()
        
        # Load configuration
        self.config = self.load_config()
        
        # Check PostgreSQL availability
        self.pg_available = self.check_postgresql()
    
    def setup_logging(self):
        """Setup logging for backup operations"""
        log_dir = self.backup_dir / "logs"
        log_dir.mkdir(exist_ok=True)
        
        log_file = log_dir / f"integrated_backup_{datetime.datetime.now().strftime('%Y%m%d')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file, encoding='utf-8'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def check_postgresql(self):
        """Check if PostgreSQL tools are available"""
        try:
            result = subprocess.run(
                ["psql", "--version"], 
                capture_output=True, 
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                self.logger.info(f"PostgreSQL found: {result.stdout.strip()}")
                return True
            else:
                self.logger.error("PostgreSQL psql command not found in PATH")
                return False
        except FileNotFoundError:
            self.logger.error("PostgreSQL not found. Please install PostgreSQL or add it to PATH")
            return False
        except Exception as e:
            self.logger.error(f"Error checking PostgreSQL: {e}")
            return False
    
    def load_config(self):
        """Load backup configuration"""
        default_config = {
            "environments": {
                "one_vault": {
                    "host": "localhost",
                    "port": "5432", 
                    "database": "one_vault",
                    "username": "postgres",
                    "description": "Main production database"
                },
                "one_vault_dev": {
                    "host": "localhost",
                    "port": "5432",
                    "database": "one_vault_dev", 
                    "username": "postgres",
                    "description": "Development database"
                }
            },
            "backup_settings": {
                "compress": True,
                "verify_backups": True,
                "use_database_functions": True
            }
        }
        
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                self.logger.warning(f"Could not load config file: {e}")
                
        return default_config
    
    def get_database_connection(self, env_name: str = "one_vault"):
        """Get database connection for specified environment"""
        if env_name not in self.config["environments"]:
            self.logger.error(f"Environment '{env_name}' not found in configuration")
            return None
            
        env_config = self.config["environments"][env_name]
        
        try:
            # Try multiple sources for password
            password = (
                os.getenv('PGPASSWORD') or          # Environment variable
                os.getenv('DB_PASSWORD') or         # Alternative env var
                os.getenv('POSTGRES_PASSWORD')      # Docker-style env var
            )
            
            # If no password found in environment, prompt user
            if not password:
                print(f"\nConnecting to {env_name} database...")
                password = getpass.getpass(f"Password for {env_config['username']}@{env_config['host']}: ")
            
            # Get other connection parameters from environment if available
            host = os.getenv('PGHOST', env_config["host"])
            port = os.getenv('PGPORT', env_config["port"])
            user = os.getenv('PGUSER', env_config["username"])
            database = env_config["database"]
            
            conn = psycopg2.connect(
                host=host,
                port=port,
                database=database,
                user=user,
                password=password
            )
            
            self.logger.info(f"Successfully connected to {env_name} database")
            return conn
            
        except psycopg2.OperationalError as e:
            if "password authentication failed" in str(e):
                self.logger.error("Password authentication failed. Please check your credentials.")
            else:
                self.logger.error(f"Database connection failed: {e}")
            return None
        except Exception as e:
            self.logger.error(f"Unexpected error connecting to database: {e}")
            return None
    
    def create_integrated_backup(self, env_name: str, backup_type: str = "FULL") -> Tuple[bool, Dict[str, Any]]:
        """Create backup using database management system"""
        if not self.pg_available:
            return False, {"error": "PostgreSQL not available"}
            
        # Get database connection
        conn = self.get_database_connection(env_name)
        if not conn:
            return False, {"error": "Could not connect to database"}
        
        try:
            backup_location = str(self.backup_dir) + "/"
            
            cursor = conn.cursor()
            
            if backup_type.upper() == "FULL":
                self.logger.info(f"Creating full backup using database function for {env_name}")
                
                cursor.execute("""
                    SELECT * FROM backup_mgmt.create_full_backup(
                        p_backup_location := %s,
                        p_storage_type := 'LOCAL',
                        p_compression_enabled := %s,
                        p_verify_backup := %s
                    )
                """, (
                    backup_location,
                    self.config["backup_settings"].get("compress", True),
                    self.config["backup_settings"].get("verify_backups", True)
                ))
            
            result = cursor.fetchone()
            cursor.close()
            conn.commit()
            
            if result:
                backup_id, status, size_bytes, duration, verification, error_msg = result
                
                success = status in ['COMPLETED', 'VERIFIED']
                
                result_data = {
                    "backup_id": backup_id.hex() if backup_id else None,
                    "status": status,
                    "size_bytes": size_bytes,
                    "duration_seconds": duration,
                    "verification_status": verification,
                    "error_message": error_msg
                }
                
                if success:
                    self.logger.info(f"Backup completed successfully")
                    self.logger.info(f"Backup ID: {result_data['backup_id']}")
                    if size_bytes:
                        self.logger.info(f"Size: {size_bytes / (1024*1024):.2f} MB")
                else:
                    self.logger.error(f"Backup failed: {error_msg}")
                
                return success, result_data
            else:
                return False, {"error": "No result from backup function"}
                
        except Exception as e:
            self.logger.error(f"Backup execution failed: {e}")
            conn.rollback()
            return False, {"error": str(e)}
        finally:
            conn.close()
    
    def list_database_backups(self, limit: int = 10) -> List[Dict[str, Any]]:
        """List backups from database management system"""
        conn = self.get_database_connection("one_vault")
        if not conn:
            return []
        
        try:
            cursor = conn.cursor()
            
            query = """
                SELECT 
                    h.backup_bk,
                    s.backup_type,
                    s.backup_start_time,
                    s.backup_status,
                    s.backup_size_bytes,
                    s.verification_status
                FROM backup_mgmt.backup_execution_h h
                JOIN backup_mgmt.backup_execution_s s ON h.backup_hk = s.backup_hk
                WHERE s.load_end_date IS NULL
                ORDER BY s.backup_start_time DESC
                LIMIT %s
            """
            
            cursor.execute(query, (limit,))
            results = cursor.fetchall()
            cursor.close()
            
            backups = []
            for row in results:
                backup_info = {
                    "backup_bk": row[0],
                    "backup_type": row[1],
                    "start_time": row[2].isoformat() if row[2] else None,
                    "status": row[3],
                    "size_bytes": row[4],
                    "verification_status": row[5]
                }
                backups.append(backup_info)
            
            return backups
            
        except Exception as e:
            self.logger.error(f"Error listing backups: {e}")
            return []
        finally:
            conn.close()

def main():
    parser = argparse.ArgumentParser(description="Integrated Database Backup System")
    parser.add_argument("--env", help="Environment to backup", default="one_vault")
    parser.add_argument("--type", choices=["FULL", "INCREMENTAL"], default="FULL")
    parser.add_argument("--list", action="store_true", help="List database backups")
    parser.add_argument("--check", action="store_true", help="Check system status")
    
    args = parser.parse_args()
    
    backup_system = IntegratedBackupSystem()
    
    if args.check:
        if backup_system.pg_available:
            print("PostgreSQL: Available")
            conn = backup_system.get_database_connection("one_vault")
            if conn:
                print("Database Connection: Success")
                conn.close()
                print("Integrated backup system is ready!")
            else:
                print("Database Connection: Failed")
        else:
            print("PostgreSQL: Not Available")
        return
    
    if args.list:
        backups = backup_system.list_database_backups()
        if backups:
            print(f"\nDatabase Backup Records ({len(backups)} found):")
            print("-" * 60)
            for backup in backups:
                print(f"ID: {backup['backup_bk']}")
                print(f"Type: {backup['backup_type']} | Status: {backup['status']}")
                print(f"Start: {backup['start_time']}")
                if backup['size_bytes']:
                    print(f"Size: {backup['size_bytes'] / (1024*1024):.2f} MB")
                print("-" * 30)
        else:
            print("No backup records found in database")
        return
    
    # Create backup
    success, result = backup_system.create_integrated_backup(args.env, args.type)
    
    if success:
        print(f"\nBackup completed successfully!")
        print(f"Environment: {args.env}")
        if result.get('backup_id'):
            print(f"Backup ID: {result['backup_id']}")
        if result.get('size_bytes'):
            print(f"Size: {result['size_bytes'] / (1024*1024):.2f} MB")
        sys.exit(0)
    else:
        print(f"\nBackup failed!")
        print(f"Error: {result.get('error', 'Unknown error')}")
        sys.exit(1)

if __name__ == "__main__":
    main() 