#!/usr/bin/env python3
"""
Database Version Manager for One Vault
A Git-like interface for managing database schema changes
"""

import os
import sys
import json
import hashlib
import subprocess
from datetime import datetime
from pathlib import Path
import psycopg2
from psycopg2.extras import RealDictCursor
import yaml

class DatabaseVersionManager:
    def __init__(self, config_file="database/config/db_config.yaml"):
        self.config = self.load_config(config_file)
        self.db_connection = None
        self.migrations_dir = Path("database/migrations")
        self.rollback_dir = Path("database/rollback")
        self.schema_snapshots_dir = Path("database/schema_snapshots")
        
        # Ensure directories exist
        for directory in [self.migrations_dir, self.rollback_dir, self.schema_snapshots_dir]:
            directory.mkdir(parents=True, exist_ok=True)
    
    def load_config(self, config_file):
        """Load database configuration"""
        if os.path.exists(config_file):
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        else:
            # Default configuration
            return {
                'database': {
                    'host': 'localhost',
                    'port': 5432,
                    'database': 'one_vault',
                    'user': 'postgres',
                    'password': os.getenv('DB_PASSWORD', '')
                }
            }
    
    def connect_db(self):
        """Connect to the database"""
        if not self.db_connection:
            try:
                self.db_connection = psycopg2.connect(
                    host=self.config['database']['host'],
                    port=self.config['database']['port'],
                    database=self.config['database']['database'],
                    user=self.config['database']['user'],
                    password=self.config['database']['password']
                )
                self.db_connection.autocommit = True
                print(f"✅ Connected to {self.config['database']['database']}")
            except Exception as e:
                print(f"❌ Database connection failed: {e}")
                sys.exit(1)
        return self.db_connection
    
    def close_db(self):
        """Close database connection"""
        if self.db_connection:
            self.db_connection.close()
            self.db_connection = None
    
    def status(self):
        """Show current database version status (like git status)"""
        conn = self.connect_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        print("\n🏠 One Vault Database Version Status")
        print("=" * 50)
        
        # Check if version control schema exists
        cursor.execute("""
            SELECT EXISTS(
                SELECT 1 FROM information_schema.schemata 
                WHERE schema_name = 'version_control'
            )
        """)
        
        if not cursor.fetchone()[0]:
            print("⚠️  Version control schema not found. Run 'init' first.")
            return
        
        # Get current version
        try:
            cursor.execute("""
                SELECT version_number, version_name, deployment_date, description
                FROM util.database_version 
                WHERE is_current = true
                ORDER BY deployment_date DESC
                LIMIT 1
            """)
            current_version = cursor.fetchone()
            
            if current_version:
                print(f"📍 Current Version: {current_version['version_number']}")
                print(f"📝 Description: {current_version['version_name']}")
                print(f"📅 Deployed: {current_version['deployment_date']}")
            else:
                print("❓ No version information found")
        except:
            print("❓ Legacy version tracking system detected")
        
        # Check pending migrations
        migration_files = list(self.migrations_dir.glob("V*.sql"))
        if migration_files:
            print(f"\n📁 Found {len(migration_files)} migration files:")
            for migration in sorted(migration_files)[:5]:  # Show first 5
                print(f"   • {migration.name}")
            if len(migration_files) > 5:
                print(f"   ... and {len(migration_files) - 5} more")
        
        # Database health check
        cursor.execute("""
            SELECT 
                schemaname as schema_name,
                COUNT(*) as table_count
            FROM pg_tables 
            WHERE schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
            GROUP BY schemaname
            ORDER BY schemaname
        """)
        
        schemas = cursor.fetchall()
        print(f"\n🏗️  Database Structure:")
        total_tables = 0
        for schema in schemas:
            print(f"   📊 {schema['schema_name']}: {schema['table_count']} tables")
            total_tables += schema['table_count']
        
        print(f"\n📈 Total: {len(schemas)} schemas, {total_tables} tables")
        cursor.close()
    
    def init(self):
        """Initialize version control system"""
        print("🚀 Initializing One Vault Database Version Control...")
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        # Check if already initialized
        cursor.execute("""
            SELECT EXISTS(
                SELECT 1 FROM information_schema.schemata 
                WHERE schema_name = 'version_control'
            )
        """)
        
        if cursor.fetchone()[0]:
            print("✅ Version control already initialized!")
            return
        
        # Create enhanced version control system
        version_control_sql = Path("database/version_control/enhanced_database_version_control.sql")
        if version_control_sql.exists():
            print("📥 Deploying enhanced version control schema...")
            with open(version_control_sql, 'r') as f:
                cursor.execute(f.read())
            print("✅ Enhanced version control system deployed!")
        else:
            print("⚠️  Enhanced version control SQL not found. Creating basic system...")
            # Create basic version control
            cursor.execute("""
                CREATE SCHEMA IF NOT EXISTS version_control;
                
                CREATE TABLE IF NOT EXISTS version_control.migrations (
                    migration_id SERIAL PRIMARY KEY,
                    version VARCHAR(50) NOT NULL,
                    name VARCHAR(255) NOT NULL,
                    description TEXT,
                    author VARCHAR(100) NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    applied_at TIMESTAMP WITH TIME ZONE,
                    status VARCHAR(20) DEFAULT 'PENDING'
                );
            """)
            print("✅ Basic version control system created!")
        
        cursor.close()
    
    def create_migration(self, version, name, description="", author=""):
        """Create a new migration file"""
        if not version:
            print("❌ Version number required (e.g., 1.1.0)")
            return
        
        if not name:
            print("❌ Migration name required")
            return
        
        if not author:
            author = os.getenv('USER', 'unknown')
        
        # Clean name for filename
        clean_name = "".join(c for c in name if c.isalnum() or c in (' ', '-', '_')).rstrip()
        clean_name = clean_name.replace(' ', '_')
        
        # Create migration filename
        filename = f"V{version}__{clean_name}.sql"
        migration_file = self.migrations_dir / filename
        
        if migration_file.exists():
            print(f"❌ Migration file already exists: {filename}")
            return
        
        # Create migration template
        template = f"""-- Migration: {name}
-- Version: {version}
-- Author: {author}
-- Created: {datetime.now().isoformat()}
-- Description: {description}

-- =============================================================================
-- FORWARD MIGRATION
-- =============================================================================

-- Add your database changes below
-- Remember to follow Data Vault 2.0 standards:
-- - All tables should have tenant_hk for isolation
-- - Use proper naming conventions (_h, _s, _l suffixes)
-- - Include load_date and record_source columns
-- - Use hash keys for primary keys

-- Example:
-- CREATE TABLE business.new_feature_h (
--     new_feature_hk BYTEA PRIMARY KEY,
--     new_feature_bk VARCHAR(255) NOT NULL,
--     tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
--     load_date TIMESTAMP WITH TIME ZONE DEFAULT util.current_load_date(),
--     record_source VARCHAR(100) NOT NULL
-- );

-- =============================================================================
-- VALIDATION QUERIES (Optional)
-- =============================================================================

-- Add queries to validate the migration was successful
-- These will be run after the migration completes

-- Example:
-- DO $$
-- BEGIN
--     IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'new_feature_h') THEN
--         RAISE EXCEPTION 'Migration validation failed: new_feature_h table not created';
--     END IF;
-- END $$;

-- =============================================================================
-- ROLLBACK NOTES
-- =============================================================================

-- Document rollback strategy:
-- {description or "To rollback this migration, run the corresponding rollback script."}

-- =============================================================================
-- DEPLOYMENT LOG
-- =============================================================================

-- Log this migration
SELECT util.log_deployment_start(
    '{name} (v{version})',
    '{description}',
    'V{version}__{clean_name}_rollback.sql'
);
"""
        
        # Write migration file
        with open(migration_file, 'w') as f:
            f.write(template)
        
        # Create corresponding rollback template
        rollback_file = self.rollback_dir / f"V{version}__{clean_name}_rollback.sql"
        rollback_template = f"""-- Rollback Migration: {name}
-- Version: {version}
-- Author: {author}
-- Created: {datetime.now().isoformat()}

-- =============================================================================
-- ROLLBACK MIGRATION
-- =============================================================================

-- Add rollback commands below
-- This should undo all changes made in V{version}__{clean_name}.sql

-- Example:
-- DROP TABLE IF EXISTS business.new_feature_h CASCADE;

-- =============================================================================
-- ROLLBACK VALIDATION
-- =============================================================================

-- Add validation to ensure rollback was successful

-- Log rollback
SELECT util.log_deployment_start(
    'ROLLBACK: {name} (v{version})',
    'Rolling back migration: {description}',
    NULL
);
"""
        
        with open(rollback_file, 'w') as f:
            f.write(rollback_template)
        
        print(f"✅ Created migration files:")
        print(f"   📄 {migration_file}")
        print(f"   ↩️  {rollback_file}")
        print(f"\n📝 Next steps:")
        print(f"   1. Edit {migration_file} to add your changes")
        print(f"   2. Edit {rollback_file} to add rollback commands")
        print(f"   3. Test with: python database/tools/database_version_manager.py migrate --dry-run")
        print(f"   4. Apply with: python database/tools/database_version_manager.py migrate")
    
    def migrate(self, target_version=None, dry_run=False):
        """Apply pending migrations"""
        if dry_run:
            print("🧪 DRY RUN MODE - No changes will be applied")
        
        migration_files = sorted(list(self.migrations_dir.glob("V*.sql")))
        
        if not migration_files:
            print("📭 No migration files found")
            return
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        for migration_file in migration_files:
            version = self.extract_version_from_filename(migration_file.name)
            
            if target_version and version > target_version:
                break
            
            print(f"🚀 Processing migration: {migration_file.name}")
            
            if dry_run:
                print(f"   📋 Would execute: {migration_file}")
                continue
            
            try:
                with open(migration_file, 'r') as f:
                    migration_sql = f.read()
                
                print(f"   ⚡ Executing migration...")
                cursor.execute(migration_sql)
                print(f"   ✅ Migration completed successfully")
                
            except Exception as e:
                print(f"   ❌ Migration failed: {e}")
                break
        
        cursor.close()
    
    def rollback(self, target_version):
        """Rollback to a specific version"""
        print(f"⏪ Rolling back to version {target_version}")
        
        rollback_file = None
        for file in self.rollback_dir.glob("V*.sql"):
            if target_version in file.name:
                rollback_file = file
                break
        
        if not rollback_file:
            print(f"❌ Rollback script not found for version {target_version}")
            return
        
        conn = self.connect_db()
        cursor = conn.cursor()
        
        try:
            with open(rollback_file, 'r') as f:
                rollback_sql = f.read()
            
            print(f"⚡ Executing rollback: {rollback_file.name}")
            cursor.execute(rollback_sql)
            print("✅ Rollback completed successfully")
            
        except Exception as e:
            print(f"❌ Rollback failed: {e}")
        
        cursor.close()
    
    def snapshot(self, version=None):
        """Create a schema snapshot"""
        if not version:
            version = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        snapshot_file = self.schema_snapshots_dir / f"schema_v{version}.sql"
        
        print(f"📸 Creating schema snapshot: {snapshot_file}")
        
        try:
            # Use pg_dump to create schema-only dump
            cmd = [
                'pg_dump',
                '--schema-only',
                '--no-owner',
                '--no-privileges',
                '--host', self.config['database']['host'],
                '--port', str(self.config['database']['port']),
                '--username', self.config['database']['user'],
                '--dbname', self.config['database']['database']
            ]
            
            with open(snapshot_file, 'w') as f:
                result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True)
            
            if result.returncode == 0:
                print(f"✅ Schema snapshot created: {snapshot_file}")
            else:
                print(f"❌ Snapshot failed: {result.stderr}")
                
        except Exception as e:
            print(f"❌ Snapshot failed: {e}")
    
    def diff(self, from_version, to_version="current"):
        """Show differences between versions"""
        print(f"🔍 Comparing {from_version} → {to_version}")
        
        # This is a simplified diff - in production you'd use more sophisticated tools
        from_file = self.schema_snapshots_dir / f"schema_v{from_version}.sql"
        
        if to_version == "current":
            # Create temporary snapshot
            temp_snapshot = self.schema_snapshots_dir / "temp_current.sql"
            self.snapshot("temp_current")
            to_file = temp_snapshot
        else:
            to_file = self.schema_snapshots_dir / f"schema_v{to_version}.sql"
        
        if not from_file.exists():
            print(f"❌ Snapshot not found: {from_file}")
            return
        
        if not to_file.exists():
            print(f"❌ Snapshot not found: {to_file}")
            return
        
        try:
            # Simple diff using system diff command
            result = subprocess.run(
                ['diff', '-u', str(from_file), str(to_file)],
                capture_output=True, text=True
            )
            
            if result.stdout:
                print("📋 Schema differences:")
                print(result.stdout)
            else:
                print("✅ No differences found")
                
        except Exception as e:
            print(f"❌ Diff failed: {e}")
        
        # Clean up temp file
        if to_version == "current" and temp_snapshot.exists():
            temp_snapshot.unlink()
    
    def extract_version_from_filename(self, filename):
        """Extract version number from migration filename"""
        # Extract version from format: V1.2.3__Name.sql
        if filename.startswith('V') and '__' in filename:
            return filename.split('__')[0][1:]  # Remove 'V' prefix
        return filename
    
    def show_help(self):
        """Show help message"""
        help_text = """
🏠 One Vault Database Version Manager
=======================================

COMMANDS:
  status     - Show current database version status
  init       - Initialize version control system
  create     - Create a new migration
  migrate    - Apply pending migrations
  rollback   - Rollback to a specific version
  snapshot   - Create a schema snapshot
  diff       - Show differences between versions

EXAMPLES:
  python database/tools/database_version_manager.py status
  python database/tools/database_version_manager.py init
  python database/tools/database_version_manager.py create 1.1.0 "Add user preferences"
  python database/tools/database_version_manager.py migrate --dry-run
  python database/tools/database_version_manager.py migrate
  python database/tools/database_version_manager.py rollback 1.0.0
  python database/tools/database_version_manager.py snapshot
  python database/tools/database_version_manager.py diff 1.0.0 current

OPTIONS:
  --dry-run  - Show what would be done without making changes
  --help     - Show this help message

CONFIGURATION:
  Place database connection details in: database/config/db_config.yaml
  Or set DB_PASSWORD environment variable
"""
        print(help_text)

def main():
    manager = DatabaseVersionManager()
    
    if len(sys.argv) < 2:
        manager.show_help()
        return
    
    command = sys.argv[1].lower()
    
    try:
        if command == 'status':
            manager.status()
        
        elif command == 'init':
            manager.init()
        
        elif command == 'create':
            if len(sys.argv) < 4:
                print("❌ Usage: create <version> <name> [description]")
                return
            version = sys.argv[2]
            name = sys.argv[3]
            description = sys.argv[4] if len(sys.argv) > 4 else ""
            manager.create_migration(version, name, description)
        
        elif command == 'migrate':
            dry_run = '--dry-run' in sys.argv
            target = None
            if '--target' in sys.argv:
                target_idx = sys.argv.index('--target') + 1
                if target_idx < len(sys.argv):
                    target = sys.argv[target_idx]
            manager.migrate(target, dry_run)
        
        elif command == 'rollback':
            if len(sys.argv) < 3:
                print("❌ Usage: rollback <version>")
                return
            version = sys.argv[2]
            manager.rollback(version)
        
        elif command == 'snapshot':
            version = sys.argv[2] if len(sys.argv) > 2 else None
            manager.snapshot(version)
        
        elif command == 'diff':
            if len(sys.argv) < 3:
                print("❌ Usage: diff <from_version> [to_version]")
                return
            from_version = sys.argv[2]
            to_version = sys.argv[3] if len(sys.argv) > 3 else "current"
            manager.diff(from_version, to_version)
        
        elif command in ['help', '--help', '-h']:
            manager.show_help()
        
        else:
            print(f"❌ Unknown command: {command}")
            manager.show_help()
    
    except KeyboardInterrupt:
        print("\n⏹️  Operation cancelled")
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        manager.close_db()

if __name__ == "__main__":
    main() 