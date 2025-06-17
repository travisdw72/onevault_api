# Database Backup Scripts

Professional database backup tools for the One Vault project.

## 📋 **Requirements**

### PostgreSQL Installation Required
These scripts require PostgreSQL to be installed and accessible from the command line.

**Windows Users**: If you see "PostgreSQL not found" errors:
1. Install PostgreSQL from: https://www.postgresql.org/download/windows/
2. See detailed instructions: `POSTGRESQL_INSTALLATION.md`
3. Test installation: `python scripts/database_backup.py --check`

**Other Platforms**: Install PostgreSQL using your system's package manager.

## 🚀 **Quick Start**

### Before Testing/Development Work
```bash
# Quick backup of main database
python scripts/quick_backup.py

# Quick backup of development database
python scripts/quick_backup.py one_vault_dev
```

### Full Backup Operations
```bash
# Backup all environments
python scripts/database_backup.py

# Backup specific environment
python scripts/database_backup.py --env one_vault_dev

# List available backups
python scripts/database_backup.py --list

# Cleanup old backups
python scripts/database_backup.py --cleanup
```

## 📊 **Features**

### Professional Backup System
- **Multi-Environment Support**: `one_vault`, `one_vault_dev`, `one_vault_testing`
- **Automatic Timestamping**: `one_vault_full_20250617_153000.backup`
- **Compression**: Automatic compression for space efficiency
- **Retention Policy**: Auto-cleanup of old backups (30 days default)
- **Validation**: Pre-backup database connection testing
- **Logging**: Comprehensive logging with UTF-8 support
- **Windows Compatible**: No Unicode encoding issues

### Smart Error Handling
- PostgreSQL availability checking
- Connection validation before backup
- Graceful failure handling
- Detailed error messages

## 🔧 **Configuration**

Configuration is stored in `backup_config.json` (created automatically):

```json
{
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
    "compress": true,
    "retention_days": 30,
    "include_data": true,
    "include_schema": true,
    "custom_format": true
  }
}
```

## 📁 **File Structure**

```
database/
├── backups/                          # Backup storage
│   ├── logs/                         # Backup operation logs
│   ├── one_vault_full_20250617_153000.backup
│   └── one_vault_dev_full_20250617_154500.backup
└── scripts/
    ├── database_backup.py            # Main backup tool
    ├── quick_backup.py               # Quick backup wrapper
    ├── backup_config.json            # Configuration file
    ├── README.md                     # This file
    └── POSTGRESQL_INSTALLATION.md    # Installation guide
```

## 🎯 **Usage Examples**

### Daily Development Workflow
```bash
# 1. BACKUP before any testing
python scripts/quick_backup.py

# 2. CREATE testing branch
git checkout -b testing/database-validation

# 3. DO your testing work
python scripts/validate_database_structure.py

# 4. COMMIT your changes
git add .
git commit -m "Add database validation tests"

# 5. MERGE back to master
git checkout master
git merge testing/database-validation
```

### Production Backup Schedule
```bash
# Daily full backup of all environments
python scripts/database_backup.py --env all

# Weekly cleanup of old backups
python scripts/database_backup.py --cleanup
```

### Backup Verification
```bash
# Check PostgreSQL installation
python scripts/database_backup.py --check

# List all available backups
python scripts/database_backup.py --list

# List backups for specific environment
python scripts/database_backup.py --list --env one_vault_dev
```

## 🛡️ **Best Practices**

### Before Any Database Work
1. **Always backup first**: `python scripts/quick_backup.py`
2. **Create a branch**: `git checkout -b testing/your-feature`
3. **Do your work**: Make changes, test, commit
4. **Merge when done**: `git checkout master && git merge testing/your-feature`

### Backup Management
- **Regular backups**: Run daily backups of all environments
- **Test restores**: Periodically test backup restoration
- **Monitor disk space**: Backups are compressed but still use space
- **Keep retention policy**: 30 days default, adjust as needed

## 🚨 **Troubleshooting**

### PostgreSQL Not Found
```
ERROR: PostgreSQL not found!
```
**Solution**: Install PostgreSQL and add to PATH
- See: `POSTGRESQL_INSTALLATION.md`
- Test: `python scripts/database_backup.py --check`

### Connection Failed
```
Database connection failed: connection refused
```
**Solutions**:
- Check PostgreSQL service is running
- Verify database exists: `psql -U postgres -l`
- Check connection settings in `backup_config.json`

### Permission Denied
```
Backup failed: permission denied
```
**Solutions**:
- Run as administrator (Windows)
- Check database user permissions
- Verify backup directory is writable

### Out of Disk Space
```
Backup failed: No space left on device
```
**Solutions**:
- Run cleanup: `python scripts/database_backup.py --cleanup`
- Check disk space: `df -h` (Linux/Mac) or `dir` (Windows)
- Adjust retention policy in config

## 💡 **Tips**

- **Use quick_backup.py** for daily development work
- **Use database_backup.py** for comprehensive backup operations
- **Check logs** in `database/backups/logs/` for detailed information
- **Test your backups** by occasionally restoring to a test database
- **Monitor backup sizes** to ensure they're reasonable for your data

## 🔗 **Integration**

These scripts integrate with the One Vault git workflow:
- Backup → Branch → Code → Commit → Merge → Cleanup
- Automated retention policies keep disk usage manageable
- Logging provides audit trail for backup operations
- Multi-environment support matches development workflow 