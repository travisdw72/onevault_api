# Tenant Setup Templates
## OneVault Platform Tenant Creation Toolkit

This directory contains templates and configurations for setting up new tenants in the OneVault platform. Each template follows the proven pattern used successfully for One Barn AI setup.

---

## 📁 **Directory Structure**

```
tenant_setup_templates/
├── README.md                               # This file
├── step1_create_tenant_template.sql        # Tenant creation template
├── step2_clear_audit_template.sql          # Audit cleanup template
├── step3_create_user_template.sql          # User creation template
├── step7_generate_api_key_template.sql     # API key generation template
├── step8_final_verification_template.sql   # Final verification template
└── platform_configs/
    ├── onevault_config.yaml                # OneVault admin platform config
    ├── onevault_canvas_config.yaml         # Canvas platform config
    └── customer_template_config.yaml       # Customer platform template
```

---

## 🚀 **Quick Start Guide**

### For OneVault Internal Platform
```bash
# 1. Copy and customize the tenant creation script
cp step1_create_tenant_template.sql step1_create_onevault_tenant.sql

# 2. Edit the file and replace:
# {PLATFORM_NAME} → onevault
# {ADMIN_EMAIL} → admin@onevault.com
# {ADMIN_PASSWORD} → AdminOV2025!
# etc. (see onevault_config.yaml for all values)

# 3. Run the setup sequence
psql -d one_vault_site_testing -f step1_create_onevault_tenant.sql
psql -d one_vault_site_testing -f step2_clear_audit_onevault.sql
# ... continue with user creation and API key generation
```

### For OneVault Canvas Platform
```bash
# Use the canvas configuration values from onevault_canvas_config.yaml
cp step1_create_tenant_template.sql step1_create_canvas_tenant.sql
# Replace {PLATFORM_NAME} → onevault_canvas
# etc.
```

---

## 📋 **Template Usage Instructions**

### Step 1: Tenant Creation
- **File**: `step1_create_tenant_template.sql`
- **Purpose**: Creates the tenant and admin user
- **Required Replacements**:
  - `{PLATFORM_NAME}` - Platform identifier
  - `{ADMIN_EMAIL}` - Admin user email
  - `{ADMIN_PASSWORD}` - Secure admin password
  - `{TENANT_TYPE}` - 'internal' or 'customer'
  - Contact information fields

### Step 2: Audit Cleanup
- **File**: `step2_clear_audit_template.sql`
- **Purpose**: Clears audit conflicts before user creation
- **Required Replacements**:
  - `{PLATFORM_NAME}` - Must match Step 1

### Step 3: User Creation
- **File**: `step3_create_user_template.sql`
- **Purpose**: Creates additional platform users
- **Required Replacements**:
  - `{PLATFORM_NAME}` - Must match Step 1
  - `{USER_EMAIL}` - User's email address
  - `{SECURE_PASSWORD}` - User's password
  - `{FIRST_NAME}`, `{LAST_NAME}` - User names
  - `{ROLE}` - ADMINISTRATOR, MANAGER, or USER

### Step 7: API Key Generation
- **File**: `step7_generate_api_key_template.sql`
- **Purpose**: Generates platform-level API key
- **Required Replacements**:
  - `{PLATFORM_NAME}` - Must match Step 1
  - `{API_KEY_NAME}` - Name for the API key
  - `{API_SCOPES}` - Comma-separated scopes list

### Step 8: Final Verification
- **File**: `step8_final_verification_template.sql`
- **Purpose**: Verifies all setup completed successfully
- **Required Replacements**:
  - `{PLATFORM_NAME}` - Must match Step 1

---

## ⚙️ **Configuration Files**

### OneVault Admin Platform (`onevault_config.yaml`)
Complete configuration for internal OneVault administration platform:
- 4 users (admin, support, developer, analytics)
- Comprehensive API scopes
- Security settings optimized for internal use

### OneVault Canvas Platform (`onevault_canvas_config.yaml`)
Configuration for visual workflow builder platform:
- 4 users (admin, demo, developer, workflow-designer)
- Canvas-specific API scopes
- Extended session timeouts for workflow building

### Customer Template (`customer_template_config.yaml`)
Template for setting up customer platforms:
- Standard user roles
- Customer-appropriate API scopes
- Security settings for external access

---

## 🔧 **Customization Examples**

### For a New Customer Platform
```yaml
# customer_platform_config.yaml
platform_info:
  name: "acme_corp"
  display_name: "Acme Corporation"
  type: "customer"

users:
  - email: "admin@acme.com"
    role: "ADMINISTRATOR"
  - email: "manager@acme.com"
    role: "MANAGER"
  - email: "user@acme.com"
    role: "USER"

api_key:
  scopes: ["read", "write", "ai_chat", "site_events"]
```

### For a Specialized Internal Tool
```yaml
# monitoring_platform_config.yaml
platform_info:
  name: "onevault_monitoring"
  type: "internal"

api_key:
  scopes: ["read", "system_health", "audit_access"]
```

---

## 🔐 **Security Best Practices**

### Password Generation
- Use strong, unique passwords for each platform
- Include uppercase, lowercase, numbers, and symbols
- Minimum 12 characters
- Store securely (password manager recommended)

### API Key Management
- Store API keys in environment variables
- Use appropriate scopes (principle of least privilege)
- Set reasonable expiration dates
- Monitor usage and rotate regularly

### Tenant Isolation
- Each platform gets its own tenant
- Never share tenants between platforms
- Verify isolation in testing

---

## 🧪 **Testing Checklist**

Before production deployment:
- [ ] Test tenant creation in development database
- [ ] Verify all users can authenticate
- [ ] Test API key functionality
- [ ] Confirm tenant isolation works
- [ ] Run final verification script
- [ ] Document all credentials securely

---

## 📚 **Related Documentation**

- **Main Guide**: `docs/configuration/TENANT_SETUP_GUIDE.md`
- **API Integration**: `onevault_api/ONE_BARN_AI_API_CONTRACT.md`
- **Database Documentation**: `database/docs/`
- **Security Guidelines**: See main guide security section

---

## 🛠️ **Troubleshooting**

### Common Issues
1. **Tenant creation fails**: Check for duplicate names
2. **User creation fails**: Run audit cleanup script
3. **API key generation fails**: Verify tenant exists
4. **Authentication issues**: Check passwords and user status

### Support
- Review the main setup guide for detailed troubleshooting
- Check database logs for specific error messages
- Verify all placeholder values were replaced correctly

---

## 🎯 **Success Criteria**

A successful tenant setup includes:
- ✅ One tenant created
- ✅ All required users created with appropriate roles
- ✅ One platform-level API key generated
- ✅ All components verified working
- ✅ Credentials documented securely

---

**Remember**: These templates follow the exact same pattern that successfully set up One Barn AI. Each platform should have its own tenant with a single platform-level API key for external integrations. 