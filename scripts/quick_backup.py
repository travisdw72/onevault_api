#!/usr/bin/env python3
"""
QUICK DATABASE BACKUP
====================
Simple wrapper for creating database backups before testing/development work.

USAGE:
    python scripts/quick_backup.py                    # Backup main database
    python scripts/quick_backup.py --env dev          # Backup dev database  
    python scripts/quick_backup.py --all              # Backup all databases
"""

import subprocess
import sys
from pathlib import Path

def main():
    script_dir = Path(__file__).parent
    backup_script = script_dir / "database_backup.py"
    
    print("🚀 QUICK DATABASE BACKUP")
    print("=" * 50)
    
    # Simple argument handling
    if "--all" in sys.argv:
        env = "all"
    elif "--env" in sys.argv:
        env_index = sys.argv.index("--env") + 1
        if env_index < len(sys.argv):
            env = sys.argv[env_index]
        else:
            env = "one_vault"
    else:
        env = "one_vault"  # Default to main database
    
    # Run the backup
    try:
        print(f"📦 Creating backup for: {env}")
        
        cmd = ["python", str(backup_script), "--env", env]
        result = subprocess.run(cmd, check=True)
        
        print("\n✅ Backup completed successfully!")
        print("💡 You can now safely create your testing branch:")
        print("   git checkout -b testing/database-validation")
        
    except subprocess.CalledProcessError:
        print("\n❌ Backup failed!")
        print("🚨 Do NOT proceed with testing until backup is successful")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 