#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PROFESSIONAL DATABASE BACKUP SCRIPT
===================================
Automatically creates timestamped backups of PostgreSQL databases
Supports multiple environments (dev, testing, staging, production)

FEATURES:
- Automatic timestamping
- Multiple database environments
- Compression options  
- Retention policy (auto-cleanup old backups)
- Logging and error handling
- Pre-backup validation
"""

import os
import sys
import subprocess
import datetime
import json
import logging
import argparse
from pathlib import Path
import shutil
import gzip

class DatabaseBackup:
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
    
    def setup_logging(self):
        """Setup logging for backup operations"""
        log_dir = self.backup_dir / "logs"
        log_dir.mkdir(exist_ok=True)
        
        log_file = log_dir / f"backup_{datetime.datetime.now().strftime('%Y%m%d')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
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
                },
                "one_vault_testing": {
                    "host": "localhost",
                    "port": "5432",
                    "database": "one_vault_testing",
                    "username": "postgres", 
                    "description": "Testing database"
                }
            },
            "backup_settings": {
                "compress": True,
                "retention_days": 30,
                "include_data": True,
                "include_schema": True,
                "custom_format": True
            }
        }
        
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                self.logger.warning(f"Could not load config file: {e}")
                self.logger.info("Using default configuration")
                
        # Create default config file
        with open(self.config_file, 'w') as f:
            json.dump(default_config, f, indent=2)
        
        return default_config
    
    def generate_backup_filename(self, env_name, backup_type="full"):
        """Generate timestamped backup filename"""
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        
        if self.config["backup_settings"]["custom_format"]:
            extension = "backup"
        else:
            extension = "sql"
            
        filename = f"{env_name}_{backup_type}_{timestamp}.{extension}"
        
        if self.config["backup_settings"]["compress"] and extension == "sql":
            filename += ".gz"
            
        return filename
    
    def validate_database_connection(self, env_config):
        """Validate database connection before backup"""
        try:
            cmd = [
                "psql",
                "-h", env_config["host"],
                "-p", env_config["port"], 
                "-U", env_config["username"],
                "-d", env_config["database"],
                "-c", "SELECT version();"
            ]
            
            result = subprocess.run(
                cmd, 
                capture_output=True, 
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                self.logger.info(f"✅ Database connection validated: {env_config['database']}")
                return True
            else:
                self.logger.error(f"❌ Database connection failed: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            self.logger.error("❌ Database connection timeout")
            return False
        except Exception as e:
            self.logger.error(f"❌ Database validation error: {e}")
            return False
    
    def create_backup(self, env_name, backup_type="full"):
        """Create database backup"""
        if env_name not in self.config["environments"]:
            self.logger.error(f"❌ Environment '{env_name}' not found in configuration")
            return False
            
        env_config = self.config["environments"][env_name]
        
        self.logger.info(f"🚀 Starting backup for {env_name} ({env_config['description']})")
        
        # Validate connection
        if not self.validate_database_connection(env_config):
            return False
        
        # Generate filename
        filename = self.generate_backup_filename(env_name, backup_type)
        backup_path = self.backup_dir / filename
        
        # Build pg_dump command
        cmd = [
            "pg_dump",
            "-h", env_config["host"],
            "-p", env_config["port"],
            "-U", env_config["username"],
            "-d", env_config["database"]
        ]
        
        # Add format options
        if self.config["backup_settings"]["custom_format"]:
            cmd.extend(["-Fc"])  # Custom format (compressed)
        
        if not self.config["backup_settings"]["include_data"]:
            cmd.extend(["--schema-only"])
        elif not self.config["backup_settings"]["include_schema"]:
            cmd.extend(["--data-only"])
        
        # Add output file
        cmd.extend(["-f", str(backup_path)])
        
        try:
            self.logger.info(f"📦 Creating backup: {filename}")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            if result.returncode == 0:
                # Get backup file size
                file_size = backup_path.stat().st_size
                size_mb = file_size / (1024 * 1024)
                
                self.logger.info(f"✅ Backup completed successfully")
                self.logger.info(f"📁 File: {backup_path}")
                self.logger.info(f"📊 Size: {size_mb:.2f} MB")
                
                # Compress if needed and not already compressed
                if (self.config["backup_settings"]["compress"] and 
                    not self.config["backup_settings"]["custom_format"] and
                    not filename.endswith('.gz')):
                    self.compress_backup(backup_path)
                
                return True
            else:
                self.logger.error(f"❌ Backup failed: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            self.logger.error("❌ Backup timeout - process took too long")
            return False
        except Exception as e:
            self.logger.error(f"❌ Backup error: {e}")
            return False
    
    def compress_backup(self, backup_path):
        """Compress backup file with gzip"""
        try:
            compressed_path = Path(str(backup_path) + ".gz")
            
            with open(backup_path, 'rb') as f_in:
                with gzip.open(compressed_path, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)
            
            # Remove original file
            backup_path.unlink()
            
            self.logger.info(f"🗜️ Backup compressed: {compressed_path.name}")
            
        except Exception as e:
            self.logger.error(f"❌ Compression failed: {e}")
    
    def cleanup_old_backups(self, env_name=None):
        """Remove old backups based on retention policy"""
        retention_days = self.config["backup_settings"]["retention_days"]
        cutoff_date = datetime.datetime.now() - datetime.timedelta(days=retention_days)
        
        self.logger.info(f"🧹 Cleaning up backups older than {retention_days} days")
        
        deleted_count = 0
        for backup_file in self.backup_dir.glob("*.backup*"):
            # Skip if specific environment and doesn't match
            if env_name and not backup_file.name.startswith(env_name):
                continue
                
            # Check file age
            file_time = datetime.datetime.fromtimestamp(backup_file.stat().st_mtime)
            
            if file_time < cutoff_date:
                try:
                    backup_file.unlink()
                    self.logger.info(f"🗑️ Deleted old backup: {backup_file.name}")
                    deleted_count += 1
                except Exception as e:
                    self.logger.error(f"❌ Could not delete {backup_file.name}: {e}")
        
        if deleted_count > 0:
            self.logger.info(f"✅ Cleaned up {deleted_count} old backup files")
        else:
            self.logger.info("✅ No old backups to clean up")
    
    def backup_all_environments(self):
        """Backup all configured environments"""
        self.logger.info("🚀 Starting backup of all environments")
        
        success_count = 0
        total_count = len(self.config["environments"])
        
        for env_name in self.config["environments"]:
            if self.create_backup(env_name):
                success_count += 1
                
        self.logger.info(f"📊 Backup Summary: {success_count}/{total_count} successful")
        
        # Cleanup old backups
        self.cleanup_old_backups()
        
        return success_count == total_count
    
    def list_backups(self, env_name=None):
        """List available backups"""
        self.logger.info("📋 Available backups:")
        
        backup_files = []
        for backup_file in sorted(self.backup_dir.glob("*.backup*")):
            if env_name and not backup_file.name.startswith(env_name):
                continue
                
            file_size = backup_file.stat().st_size / (1024 * 1024)
            file_time = datetime.datetime.fromtimestamp(backup_file.stat().st_mtime)
            
            backup_info = {
                "name": backup_file.name,
                "size_mb": round(file_size, 2),
                "created": file_time.strftime("%Y-%m-%d %H:%M:%S"),
                "path": str(backup_file)
            }
            backup_files.append(backup_info)
            
            print(f"  📁 {backup_info['name']}")
            print(f"     Size: {backup_info['size_mb']} MB")
            print(f"     Created: {backup_info['created']}")
            print()
        
        return backup_files

def main():
    parser = argparse.ArgumentParser(description="Professional Database Backup Tool")
    parser.add_argument("--env", help="Environment to backup (default: all)", default="all")
    parser.add_argument("--list", action="store_true", help="List available backups")
    parser.add_argument("--cleanup", action="store_true", help="Cleanup old backups only")
    parser.add_argument("--type", choices=["full", "schema", "data"], default="full", 
                       help="Backup type")
    
    args = parser.parse_args()
    
    backup_tool = DatabaseBackup()
    
    if args.list:
        backup_tool.list_backups(args.env if args.env != "all" else None)
        return
    
    if args.cleanup:
        backup_tool.cleanup_old_backups(args.env if args.env != "all" else None)
        return
    
    if args.env == "all":
        success = backup_tool.backup_all_environments()
    else:
        success = backup_tool.create_backup(args.env, args.type)
    
    if success:
        print("\n🎉 Backup operation completed successfully!")
        sys.exit(0)
    else:
        print("\n❌ Backup operation failed!")
        sys.exit(1)

if __name__ == "__main__":
    main() 