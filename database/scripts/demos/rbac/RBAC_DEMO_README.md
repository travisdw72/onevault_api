# One Vault RBAC Demo Setup

This directory contains scripts and configurations for setting up comprehensive RBAC (Role-Based Access Control) testing in the `one_vault_demo_barn` database.

## 📋 Overview

The RBAC demo setup creates:
- **System Admin Tenant**: Full system administration access
- **Demo Business Tenant**: Regular business tenant with multiple user roles
- **Multiple Test Users**: Users with different roles and access levels
- **Comprehensive Testing**: RBAC permission verification and testing

## 🚀 Quick Start

### Prerequisites
- PostgreSQL server running with `one_vault_demo_barn` database
- Python 3.7+ with `psycopg2` library
- Database user with sufficient privileges

### Installation
```bash
# Install required Python packages
pip install psycopg2-binary

# Make scripts executable (on Unix/Linux/Mac)
chmod +x quick_rbac_setup.py
chmod +x setup_demo_rbac.py
```

### Quick Setup (Recommended)
Run the quick setup script for immediate RBAC testing:

```bash
python quick_rbac_setup.py
```

This will:
1. Create a System Admin tenant
2. Create a Demo Business tenant
3. Create multiple test users with different roles
4. Verify the setup with comprehensive testing

## 📁 Files Description

### Scripts
- **`quick_rbac_setup.py`** - Fast, simplified RBAC setup (recommended for demos)
- **`setup_demo_rbac.py`** - Basic tenant setup script  
- **`setup_demo_rbac_extended.py`** - Comprehensive RBAC setup with full role management

### Configuration
- **`rbac_demo_config.yaml`** - Configuration file for customizing the demo setup
- **`RBAC_DEMO_README.md`** - This documentation file

## 🎭 Created Roles and Users

### Tenants
1. **SYSTEM_ADMIN** - System administration tenant
2. **ACME_CORP_DEMO** - Demo business tenant for testing

### User Roles (in Demo Tenant)
| Role | Access Level | Permissions | Description |
|------|-------------|-------------|-------------|
| ADMIN | FULL | All permissions | Tenant administration |
| MANAGER | MANAGEMENT | CREATE, READ, UPDATE, VIEW_REPORTS | Department management |
| EMPLOYEE | STANDARD | CREATE, READ, UPDATE | Standard operations |
| VIEWER | LIMITED | READ | Read-only monitoring |
| CLIENT | PERSONAL | READ | Client/patient data access |

### Test Users Created
| Email | Password | Role | Description |
|-------|----------|------|-------------|
| `sysadmin@onevault.demo` | `AdminSecure123!@#` | ADMIN | System Administrator |
| `admin@acmecorp.demo` | `DemoAdmin123!@#` | ADMIN | Demo Tenant Admin |
| `manager@acmecorp.demo` | `Manager123!@#` | MANAGER | Department Manager |
| `employee1@acmecorp.demo` | `Employee123!@#` | EMPLOYEE | Standard Employee |
| `viewer@acmecorp.demo` | `Viewer123!@#` | VIEWER | Read-only User |
| `client1@acmecorp.demo` | `Client123!@#` | CLIENT | External Client |

## 🔒 Security Features

### Password Requirements
- Minimum 12 characters
- Uppercase and lowercase letters
- Numbers and special characters
- Strong demo passwords for testing

### Tenant Isolation
- Complete data isolation between tenants
- Hash-based tenant keys for security
- Proper tenant context validation

### Audit Logging
- All user actions logged
- Comprehensive access tracking
- Compliance-ready audit trails

## 🧪 Testing RBAC

### Manual Testing
1. **Login Testing**: Try logging in with different user credentials
2. **Permission Testing**: Verify users can only access appropriate functions
3. **Tenant Isolation**: Confirm users cannot access other tenant data
4. **Role Hierarchy**: Verify higher roles have appropriate access

### Automated Testing
The scripts include automated RBAC verification:
- User role assignment verification
- Permission matrix validation
- Tenant isolation testing
- Access level hierarchy checking

## 📊 Output Files

Each script run generates:
- **JSON Results File**: Detailed setup results and verification data
- **Log File**: Comprehensive execution logs with timestamps
- **Credentials Summary**: All test account credentials (demo only)

Example output files:
```
quick_rbac_setup_results_20250115_143022.json
rbac_demo_extended_20250115_143022.log
```

## 🛠️ Customization

### Modifying Users and Roles
Edit `rbac_demo_config.yaml` to customize:
- User credentials and roles
- Password policies
- Tenant configurations
- Test scenarios

### Adding Custom Roles
To add new roles, modify the `roles` section in the config file:
```yaml
roles:
  - role_bk: "CUSTOM_ROLE"
    role_name: "Custom Role"
    role_description: "Custom access level"
    permissions: ["READ", "CUSTOM_PERMISSION"]
    access_level: "CUSTOM"
```

## 🔧 Database Integration

### Available Procedures
The scripts use these database procedures:
- `auth.register_tenant()` - Create new tenants
- `auth.register_user()` - Create new users with roles
- Various validation and testing queries

### Data Vault 2.0 Integration
- Proper hash key generation
- Temporal data tracking
- Audit trail maintenance
- Compliance-ready structure

## 🚨 Troubleshooting

### Common Issues

**Connection Failed**
```
❌ Database connection failed: FATAL: password authentication failed
```
- Verify database credentials
- Check if `one_vault_demo_barn` database exists
- Ensure PostgreSQL is running

**Tenant Already Exists**
```
❌ Error creating tenant: duplicate key value violates unique constraint
```
- Run cleanup script or use different tenant names
- Check existing tenants in database

**Role Not Found**
```
❌ Role 'CUSTOM_ROLE' not found for tenant
```
- Ensure roles are created before users
- Check role definitions in database

### Debug Mode
Run scripts with verbose output:
```bash
python quick_rbac_setup.py --debug
```

## 🧹 Cleanup

To remove demo data:
```sql
-- Connect to one_vault_demo_barn database
-- Remove demo tenants (will cascade to users)
DELETE FROM auth.tenant_h WHERE tenant_bk IN ('SYSTEM_ADMIN', 'ACME_CORP_DEMO');
```

⚠️ **Warning**: This will permanently delete all demo data!

## 📈 Performance Considerations

### Database Performance
- Scripts use efficient hash-based keys
- Minimal database queries
- Proper indexing utilized

### Scalability Testing
- Test with larger user counts by modifying config
- Monitor performance with many concurrent users
- Verify tenant isolation at scale

## 🔐 Compliance Notes

### HIPAA Compliance
- All user access is logged
- Proper tenant isolation maintained
- Audit trails are comprehensive

### GDPR Compliance
- User consent tracking available
- Data retention policies configurable
- Right to be forgotten supported

## 📞 Support

For issues or questions:
1. Check this README for common solutions
2. Review the database investigation file for current schema
3. Examine log files for detailed error information
4. Verify database connectivity and permissions

## 🎯 Next Steps

After setup completion:
1. **Test Login Flows**: Verify authentication with different users
2. **Test Permissions**: Confirm role-based access restrictions
3. **Integration Testing**: Connect with your application layer
4. **Security Review**: Validate security controls and audit logs
5. **Performance Testing**: Test with realistic user loads

---

**🚀 Happy Testing!** Your One Vault RBAC demo environment is ready for comprehensive testing and demonstration. 