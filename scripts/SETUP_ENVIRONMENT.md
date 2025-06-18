# Environment Setup for Integrated Backup System

## Option 1: Environment Variables (Recommended)

Set these environment variables in your system or PowerShell profile:

```powershell
# PostgreSQL Connection
$env:PGPASSWORD = "your_actual_password"
$env:PGUSER = "postgres"
$env:PGHOST = "localhost"
$env:PGPORT = "5432"
```

### To make permanent in PowerShell:
```powershell
# Add to your PowerShell profile
Add-Content -Path $PROFILE -Value '$env:PGPASSWORD = "your_actual_password"'
Add-Content -Path $PROFILE -Value '$env:PGUSER = "postgres"'
```

## Option 2: .env File (Alternative)

1. Create a `.env` file in the project root:
```bash
# .env file (project root)
PGPASSWORD=your_actual_password
PGUSER=postgres
PGHOST=localhost
PGPORT=5432
```

2. Install python-dotenv:
```bash
pip install python-dotenv
```

## Option 3: Interactive Password (Default)

If no environment variables are set, the script will prompt you for the password each time.

## Testing Your Setup

```bash
# Test connection
python scripts/integrated_backup.py --check

# List existing backups
python scripts/integrated_backup.py --list

# Create a backup
python scripts/integrated_backup.py --env one_vault_dev
```

## Security Notes

- **Never commit passwords to git**
- The `.env` file is automatically ignored by git
- Environment variables are the most secure option
- Interactive prompts work for testing but aren't suitable for automation

## Troubleshooting

### "Password authentication failed"
- Check your PostgreSQL password
- Verify the user exists: `psql -U postgres -l`
- Test direct connection: `psql -U postgres -d one_vault`

### "Connection refused" 
- Check if PostgreSQL is running
- Verify the port (default 5432)
- Check host/localhost settings 