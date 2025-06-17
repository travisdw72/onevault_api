# Database Backup Scripts

Professional database backup solution for One Vault project with support for multiple environments.

## 🚀 Quick Start

### Before Testing/Development Work
```bash
# Quick backup of main database
python scripts/quick_backup.py

# Then create your testing branch
git checkout -b testing/database-validation
```

### Full Backup Options
```bash
# Backup specific environment
python scripts/database_backup.py --env one_vault

# Backup all environments
python scripts/database_backup.py --env all

# Schema-only backup
python scripts/database_backup.py --env one_vault --type schema

# List available backups
python scripts/database_backup.py --list
```

## 📁 File Structure

```
scripts/
├── database_backup.py      # Main backup script (full featured)
├── quick_backup.py         # Simple wrapper for quick backups  
├── backup_config.json      # Configuration (auto-generated)
└── README.md               # This file

database/backups/
├── logs/                   # Backup operation logs
├── one_vault_full_20250617_143022.backup
├── one_vault_dev_full_20250617_143045.backup
└── one_vault_testing_full_20250617_143101.backup
```

## ⚙️ Configuration

The backup script automatically creates `backup_config.json` with these default environments:

- **one_vault** - Main production database
- **one_vault_dev** - Development database  
- **one_vault_testing** - Testing database

### Backup Settings
- ✅ **Compression enabled** - Saves storage space
- ✅ **30-day retention** - Automatically cleans old backups
- ✅ **Full backups** - Schema + data by default
- ✅ **Logging** - All operations logged with timestamps

## 🎯 Integration with Git Workflow

### Before Testing
```bash
# 1. Backup database
python scripts/quick_backup.py

# 2. Create testing branch  
git checkout -b testing/database-validation

# 3. Proceed with testing (commits on branch)
git commit -m "✅ AUTH: Login tests passing"
git commit -m "🐛 FIX: User role validation bug"

# 4. Merge when complete
git checkout master
git merge testing/database-validation
```

### Before Major Changes
```bash
# Backup before risky operations
python scripts/database_backup.py --env one_vault --type full
```

## 🛠️ Requirements

- PostgreSQL with `pg_dump` available in PATH
- Python 3.7+
- Database credentials configured (uses environment variables or prompts)

## 🔧 Customization

Edit `scripts/backup_config.json` to:
- Add new database environments
- Change retention policy  
- Modify compression settings
- Update connection parameters

## 📊 Backup File Naming

Format: `{environment}_{type}_{timestamp}.{extension}`

Examples:
- `one_vault_full_20250617_143022.backup`
- `one_vault_dev_schema_20250617_143045.sql.gz`
- `one_vault_testing_data_20250617_143101.backup` 