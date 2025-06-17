#!/usr/bin/env python3
"""
One Vault Database Version Control Setup
Quick setup for Git-like database management
"""

import os
import sys
from pathlib import Path

def create_directory_structure():
    """Create the necessary directory structure"""
    directories = [
        "database/migrations",
        "database/rollback", 
        "database/schema_snapshots",
        "database/version_control",
        "database/config"
    ]
    
    print("🏗️  Creating directory structure...")
    for directory in directories:
        Path(directory).mkdir(parents=True, exist_ok=True)
        print(f"   📁 {directory}")
    
    print("✅ Directory structure created!")

def create_config_file():
    """Create a sample configuration file"""
    config_content = """# One Vault Database Configuration
database:
  host: localhost
  port: 5432
  database: one_vault
  user: postgres
  # password comes from DB_PASSWORD environment variable

# Migration settings
migrations:
  auto_backup: true
  validate_before_deploy: true
  require_rollback_script: true

# Environment settings
environments:
  development:
    auto_deploy: true
    require_approval: false
  staging:
    auto_deploy: false
    require_approval: true
  production:
    auto_deploy: false
    require_approval: true
    require_testing: true
"""
    
    config_file = Path("database/config/db_config.yaml")
    if not config_file.exists():
        with open(config_file, 'w') as f:
            f.write(config_content)
        print(f"✅ Created config file: {config_file}")
    else:
        print(f"⚠️  Config file already exists: {config_file}")

def create_gitignore():
    """Create .gitignore entries for database version control"""
    gitignore_entries = """
# Database Version Control
database/schema_snapshots/temp_*
database/config/db_config.local.yaml
*.backup
*.dump
"""
    
    gitignore_file = Path(".gitignore")
    if gitignore_file.exists():
        with open(gitignore_file, 'r') as f:
            content = f.read()
        
        if "Database Version Control" not in content:
            with open(gitignore_file, 'a') as f:
                f.write(gitignore_entries)
            print("✅ Updated .gitignore")
        else:
            print("ℹ️  .gitignore already configured")
    else:
        with open(gitignore_file, 'w') as f:
            f.write(gitignore_entries)
        print("✅ Created .gitignore")

def create_readme():
    """Create README for database version control"""
    readme_content = """# Database Version Control

This directory contains the database version control system for One Vault.

## Quick Start

1. **Check database status:**
   ```bash
   python database/tools/db_version_manager.py status
   ```

2. **Create a new migration:**
   ```bash
   python database/tools/db_version_manager.py create 1.1.0 "Add user preferences"
   ```

3. **Test migration (dry run):**
   ```bash
   python database/tools/db_version_manager.py migrate --dry-run
   ```

4. **Apply migration:**
   ```bash
   python database/tools/db_version_manager.py migrate
   ```

5. **Create schema snapshot:**
   ```bash
   python database/tools/db_version_manager.py snapshot
   ```

## Directory Structure

```
database/
├── migrations/           # Migration SQL files
├── rollback/            # Rollback SQL files  
├── schema_snapshots/    # Schema snapshots for diffing
├── version_control/     # Enhanced version control system
├── config/              # Configuration files
└── tools/               # Version management tools
```

## Migration Naming Convention

Migration files follow the pattern: `V{version}__{description}.sql`

Examples:
- `V1.1.0__Add_User_Preferences.sql`
- `V1.2.0__Enhanced_Reporting.sql`
- `V2.0.0__Major_Schema_Refactor.sql`

## Best Practices

1. **Always create a rollback script** for each migration
2. **Test migrations in development first**
3. **Use semantic versioning** (MAJOR.MINOR.PATCH)
4. **Include descriptive comments** in migration files
5. **Follow Data Vault 2.0 standards** for new tables
6. **Create schema snapshots** before major changes

## Environment Variables

Set the following environment variable:
```bash
export DB_PASSWORD=your_database_password
```

## Integration with Git

All migration files are tracked in Git, providing:
- Full history of database changes
- Collaboration between team members
- Branching and merging of database changes
- Code review for database modifications

## Recommended Workflow

1. Create feature branch: `git checkout -b feature/user-preferences`
2. Create migration: `python database/tools/db_version_manager.py create 1.1.0 "Add user preferences"`
3. Edit migration files
4. Test migration: `python database/tools/db_version_manager.py migrate --dry-run`
5. Apply migration: `python database/tools/db_version_manager.py migrate`
6. Commit changes: `git add database/migrations/` && `git commit -m "Add user preferences migration"`
7. Push and create PR: `git push origin feature/user-preferences`

## Advanced Features

For production deployments, consider:
- **Flyway** for enterprise-grade migration management
- **Liquibase** for XML/YAML-based change management
- **Custom CI/CD pipelines** for automated deployments
- **Schema comparison tools** for drift detection

See `database/version_control/database_version_control_guide.md` for detailed options.
"""
    
    readme_file = Path("database/README.md")
    with open(readme_file, 'w') as f:
        f.write(readme_content)
    print(f"✅ Created README: {readme_file}")

def show_next_steps():
    """Show next steps to the user"""
    print("\n🎉 Database Version Control Setup Complete!")
    print("=" * 50)
    print("\n📋 Next Steps:")
    print("1. Set your database password:")
    print("   export DB_PASSWORD=your_password")
    print("\n2. Check your database status:")
    print("   python database/tools/db_version_manager.py status")
    print("\n3. Create your first migration:")
    print("   python database/tools/db_version_manager.py create 1.1.0 \"My first migration\"")
    print("\n4. Read the documentation:")
    print("   📖 database/README.md")
    print("   📖 database/version_control/database_version_control_guide.md")
    print("\n🚀 Your amazing database foundation now has Git-like version control!")

def main():
    print("🏠 One Vault Database Version Control Setup")
    print("=" * 45)
    
    try:
        create_directory_structure()
        create_config_file()
        create_gitignore()
        create_readme()
        show_next_steps()
        
    except Exception as e:
        print(f"❌ Setup failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 