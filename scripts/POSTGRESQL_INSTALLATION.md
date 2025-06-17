# PostgreSQL Installation Guide for Windows

## Quick Installation

1. **Download PostgreSQL**
   - Go to: https://www.postgresql.org/download/windows/
   - Download the latest version (15.x or 16.x recommended)
   - Choose the Windows installer

2. **Run the Installer**
   - Run as Administrator
   - Accept default installation directory: `C:\Program Files\PostgreSQL\16\`
   - **IMPORTANT**: Remember your password for the `postgres` user
   - Accept default port: `5432`
   - Accept default locale

3. **Verify Installation**
   - Open Command Prompt or PowerShell
   - Test PostgreSQL is in PATH:
   ```cmd
   psql --version
   ```
   - If you see version info, you're ready!

4. **If PATH Not Set Automatically**
   - Add to Windows PATH: `C:\Program Files\PostgreSQL\16\bin`
   - Restart your terminal/command prompt
   - Test again: `psql --version`

## Test Your Installation

After installation, test our backup system:

```bash
# Check if PostgreSQL is detected
python scripts/database_backup.py --check

# If successful, you should see:
# "PostgreSQL is available and ready for backups!"
```

## Create Your Databases

Once PostgreSQL is installed, you can create your databases:

```sql
-- Connect to PostgreSQL
psql -U postgres

-- Create databases
CREATE DATABASE one_vault;
CREATE DATABASE one_vault_dev;
CREATE DATABASE one_vault_testing;
CREATE DATABASE one_vault_mock;

-- Exit
\q
```

## Troubleshooting

**Problem**: `psql: command not found`
**Solution**: PostgreSQL bin directory not in PATH
- Add `C:\Program Files\PostgreSQL\16\bin` to Windows PATH
- Restart terminal

**Problem**: Connection refused
**Solution**: PostgreSQL service not running
- Open Services (services.msc)
- Start "postgresql-x64-16" service

**Problem**: Authentication failed
**Solution**: Check password or connection settings
- Use the password you set during installation
- Default user is `postgres` 