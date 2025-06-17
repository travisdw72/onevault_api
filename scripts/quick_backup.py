#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
QUICK DATABASE BACKUP
====================
Simple wrapper for quick backups before testing/development

Usage:
    python scripts/quick_backup.py
    python scripts/quick_backup.py --env one_vault_dev
"""

import sys
import os
from pathlib import Path

# Add the scripts directory to Python path
script_dir = Path(__file__).parent
sys.path.insert(0, str(script_dir))

from database_backup import DatabaseBackup

def main():
    print("=== QUICK DATABASE BACKUP ===")
    print()
    
    # Create backup tool instance
    backup_tool = DatabaseBackup()
    
    # Check if PostgreSQL is available
    if not backup_tool.pg_available:
        print("ERROR: PostgreSQL not found!")
        print("Please install PostgreSQL and add it to your PATH")
        print("Download from: https://www.postgresql.org/download/")
        print()
        print("After installation, you may need to:")
        print("1. Add PostgreSQL bin directory to your PATH")
        print("2. Restart your terminal/command prompt")
        return False
    
    # Get environment argument if provided
    env_name = sys.argv[1] if len(sys.argv) > 1 else "one_vault"
    
    print(f"Creating quick backup of: {env_name}")
    print("This will take a few moments...")
    print()
    
    # Create the backup
    success = backup_tool.create_backup(env_name, "full")
    
    if success:
        print("BACKUP COMPLETED SUCCESSFULLY!")
        print("You can now safely proceed with your testing/development")
        return True
    else:
        print("BACKUP FAILED!")
        print("Please check the logs for details")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 