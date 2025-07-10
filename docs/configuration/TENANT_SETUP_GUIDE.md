# OneVault Tenant Setup Guide
## Internal Platform Integration & API Key Management

### Overview
This guide provides step-by-step instructions for setting up new tenants and API keys within the OneVault platform for internal company use. Each internal platform (onevault, onevault-canvas, customer platforms) should have its own tenant with appropriate users and API keys.

---

## 🏗️ **Architecture Overview**

### Tenant Isolation Strategy
```
OneVault Platform
├── onevault (Internal Admin Platform)
│   ├── Admin Users (Internal Staff)
│   ├── Platform API Key
│   └── Individual User Sessions
├── onevault-canvas (Visual Workflow Builder)
│   ├── Canvas Users (Internal/External)
│   ├── Platform API Key
│   └── Individual User Sessions
├── one_barn_ai (Customer Platform)
│   ├── Customer Users
│   ├── Platform API Key
│   └── Individual User Sessions
└── [Future Customer Platforms]
```

### Authentication Flow
```
Platform → (Platform API Key) → OneVault Database → (User Sessions) → Data Vault 2.0
```

---

## 🚀 **Step-by-Step Tenant Creation Process**

### Prerequisites
- Access to OneVault production database
- Administrative privileges
- Understanding of platform requirements

### Process Overview
1. **Plan Tenant Structure** - Define platform needs
2. **Create Tenant** - Set up tenant and admin user
3. **Create Platform Users** - Add required users with roles
4. **Generate API Key** - Create platform-level API key
5. **Document Configuration** - Record credentials and settings
6. **Test Integration** - Verify all components work
7. **Deploy to Production** - Final deployment and verification

---

## 📋 **Template: 7-Step Tenant Setup**

### Step 1: Create Tenant and Admin User
```sql
-- step1_create_tenant.sql
-- Replace {PLATFORM_NAME} with actual platform name (e.g., 'onevault', 'onevault_canvas')
-- Replace {ADMIN_EMAIL} with admin email
-- Replace {ADMIN_PASSWORD} with secure password

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_admin_user_hk BYTEA;
    v_admin_role_hk BYTEA;
    v_success BOOLEAN;
    v_message TEXT;
    v_user_data JSONB;
    v_session_token VARCHAR(255);
BEGIN
    -- Create tenant
    SELECT p_tenant_hk, p_success, p_message 
    INTO v_tenant_hk, v_success, v_message
    FROM auth.register_tenant(
        '{PLATFORM_NAME}',
        'internal',
        '{PLATFORM_NAME}@onevault.com',
        '+1-555-000-0000',
        '123 Main St',
        'Tech City',
        'CA',
        '12345',
        'US',
        'admin@{PLATFORM_NAME}.com',
        'AdminPass123!'
    );
    
    IF NOT v_success THEN
        RAISE EXCEPTION 'Failed to create tenant: %', v_message;
    END IF;
    
    RAISE NOTICE 'Tenant created successfully. Tenant HK: %', encode(v_tenant_hk, 'hex');
    
END $$;
```

### Step 2: Clear Audit Conflicts
```sql
-- step2_clear_audit.sql
-- Clear any audit constraints that might interfere with user creation

DELETE FROM audit.audit_event_h 
WHERE audit_event_bk LIKE '%{PLATFORM_NAME}%'
AND load_date >= CURRENT_DATE - INTERVAL '1 day';

DELETE FROM audit.audit_event_s 
WHERE audit_event_hk NOT IN (
    SELECT audit_event_hk FROM audit.audit_event_h
);
```

### Step 3-6: Create Platform Users
```sql
-- step3_create_user_template.sql
-- Template for creating platform users
-- Customize for each user needed

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_user_hk BYTEA;
    v_success BOOLEAN;
    v_message TEXT;
    v_user_data JSONB;
    v_session_token VARCHAR(255);
BEGIN
    -- Get tenant HK
    SELECT tenant_hk INTO v_tenant_hk 
    FROM auth.tenant_h 
    WHERE tenant_bk = '{PLATFORM_NAME}';
    
    -- Create user
    SELECT p_user_hk, p_success, p_message, p_user_data, p_session_token
    INTO v_user_hk, v_success, v_message, v_user_data, v_session_token
    FROM auth.register_user(
        v_tenant_hk,
        '{USER_EMAIL}',
        '{SECURE_PASSWORD}',
        '{FIRST_NAME}',
        '{LAST_NAME}',
        '{PHONE}',
        '{JOB_TITLE}',
        '{ROLE}' -- ADMINISTRATOR, MANAGER, USER
    );
    
    IF NOT v_success THEN
        RAISE EXCEPTION 'Failed to create user: %', v_message;
    END IF;
    
    RAISE NOTICE 'User created: % (HK: %)', '{USER_EMAIL}', encode(v_user_hk, 'hex');
    
END $$;
```

### Step 7: Generate Platform API Key
```sql
-- step7_generate_platform_api_key.sql
-- Generate platform-level API key for external integrations

DO $$
DECLARE
    v_tenant_hk BYTEA;
    v_api_key VARCHAR(255);
    v_api_key_hk BYTEA;
    v_success BOOLEAN;
    v_message TEXT;
BEGIN
    -- Get tenant HK
    SELECT tenant_hk INTO v_tenant_hk 
    FROM auth.tenant_h 
    WHERE tenant_bk = '{PLATFORM_NAME}';
    
    -- Generate API key
    SELECT p_api_key_hk, p_api_key, p_success, p_message
    INTO v_api_key_hk, v_api_key, v_success, v_message
    FROM auth.generate_api_key(
        v_tenant_hk,
        '{PLATFORM_NAME}_platform_key',
        'Platform-level API key for {PLATFORM_NAME}',
        CURRENT_DATE + INTERVAL '1 year', -- 1 year expiration
        ARRAY['read', 'write', 'ai_chat', 'site_events'] -- Adjust scopes as needed
    );
    
    IF NOT v_success THEN
        RAISE EXCEPTION 'Failed to generate API key: %', v_message;
    END IF;
    
    RAISE NOTICE 'API Key generated: %', v_api_key;
    RAISE NOTICE 'API Key HK: %', encode(v_api_key_hk, 'hex');
    
END $$;
```

### Step 8: Final Verification
```sql
-- step8_final_verification.sql
-- Verify all components are created correctly

SELECT 
    'Tenant Verification' as verification_type,
    tenant_bk,
    encode(tenant_hk, 'hex') as tenant_hk_hex,
    load_date
FROM auth.tenant_h 
WHERE tenant_bk = '{PLATFORM_NAME}'

UNION ALL

SELECT 
    'User Verification' as verification_type,
    up.email as tenant_bk,
    encode(uh.user_hk, 'hex') as user_hk_hex,
    uh.load_date
FROM auth.user_h uh
JOIN auth.user_profile_s up ON uh.user_hk = up.user_hk
WHERE uh.tenant_hk = (SELECT tenant_hk FROM auth.tenant_h WHERE tenant_bk = '{PLATFORM_NAME}')
AND up.load_end_date IS NULL

UNION ALL

SELECT 
    'API Key Verification' as verification_type,
    key_name as tenant_bk,
    encode(api_key_hk, 'hex') as api_key_hk_hex,
    load_date
FROM auth.api_key_h 
WHERE tenant_hk = (SELECT tenant_hk FROM auth.tenant_h WHERE tenant_bk = '{PLATFORM_NAME}')

ORDER BY verification_type, load_date;
```

---

## 🏢 **Common Internal Platform Setups**

### OneVault (Internal Admin Platform)
```yaml
platform_name: onevault
tenant_type: internal
admin_email: admin@onevault.com
users:
  - email: admin@onevault.com
    role: ADMINISTRATOR
    name: "OneVault Admin"
  - email: support@onevault.com
    role: MANAGER
    name: "Support Team"
  - email: developer@onevault.com
    role: ADMINISTRATOR
    name: "Development Team"
api_scopes:
  - read
  - write
  - admin
  - system_health
  - audit_access
```

### OneVault Canvas (Visual Workflow Builder)
```yaml
platform_name: onevault_canvas
tenant_type: internal
admin_email: admin@onevault-canvas.com
users:
  - email: admin@onevault-canvas.com
    role: ADMINISTRATOR
    name: "Canvas Admin"
  - email: demo@onevault-canvas.com
    role: USER
    name: "Demo User"
  - email: developer@onevault-canvas.com
    role: ADMINISTRATOR
    name: "Canvas Developer"
api_scopes:
  - read
  - write
  - ai_chat
  - canvas_workflows
  - site_events
```

### Customer Platform Template
```yaml
platform_name: customer_platform_name
tenant_type: customer
admin_email: admin@customer.com
users:
  - email: admin@customer.com
    role: ADMINISTRATOR
    name: "Customer Admin"
  - email: manager@customer.com
    role: MANAGER
    name: "Customer Manager"
  - email: user@customer.com
    role: USER
    name: "Customer User"
  - email: demo@customer.com
    role: USER
    name: "Demo Account"
api_scopes:
  - read
  - write
  - ai_chat
  - site_events
```

---

## 🔒 **Security Considerations**

### Password Requirements
- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, and symbols
- No common dictionary words
- Unique per user

### API Key Security
- Store API keys securely (environment variables)
- Use HTTPS for all API communications
- Implement rate limiting
- Monitor API usage
- Regular key rotation (annually)

### Role-Based Access Control
- **ADMINISTRATOR**: Full access to tenant data and configuration
- **MANAGER**: Access to user management and reporting
- **USER**: Standard application access
- **GUEST**: Read-only access (if needed)

---

## 📊 **Database Structure Reference**

### Key Tables
```sql
-- Tenant structure
auth.tenant_h                 -- Tenant hub
auth.tenant_profile_s         -- Tenant profile data

-- User structure
auth.user_h                   -- User hub
auth.user_profile_s           -- User profile data
auth.user_auth_s              -- User authentication data

-- API key structure
auth.api_key_h                -- API key hub
auth.api_key_s                -- API key data
auth.api_key_scope_s          -- API key scopes

-- Role structure
auth.role_h                   -- Role hub
auth.role_s                   -- Role data
auth.user_role_l              -- User-role relationships
```

---

## 🧪 **Testing & Validation**

### Pre-Production Testing
1. **Database Connection Test**
   ```sql
   SELECT current_database(), current_user, now();
   ```

2. **Tenant Creation Test**
   ```sql
   SELECT count(*) FROM auth.tenant_h WHERE tenant_bk = '{PLATFORM_NAME}';
   ```

3. **User Authentication Test**
   ```sql
   SELECT p_success, p_message 
   FROM auth.login_user('{USER_EMAIL}', '{PASSWORD}', '{PLATFORM_NAME}');
   ```

4. **API Key Validation Test**
   ```sql
   SELECT p_success, p_message 
   FROM auth.validate_api_key('{API_KEY}');
   ```

### Integration Testing
- Test all API endpoints with new tenant
- Verify tenant isolation
- Test user authentication flows
- Validate API key scopes
- Check audit logging

---

## 🚨 **Troubleshooting Guide**

### Common Issues

#### Tenant Creation Fails
**Symptoms**: register_tenant returns false
**Solutions**:
- Check for duplicate tenant names
- Verify email format
- Ensure admin user doesn't already exist
- Check database constraints

#### User Creation Fails
**Symptoms**: register_user returns false
**Solutions**:
- Clear audit conflicts (step2_clear_audit.sql)
- Verify tenant exists
- Check email uniqueness
- Validate password requirements

#### API Key Generation Fails
**Symptoms**: generate_api_key returns false
**Solutions**:
- Verify tenant exists
- Check API key name uniqueness
- Validate expiration date
- Verify scope permissions

#### Authentication Issues
**Symptoms**: login_user returns false
**Solutions**:
- Verify user exists and is active
- Check password correctness
- Ensure tenant is active
- Validate session not expired

---

## 📋 **Deployment Checklist**

### Pre-Deployment
- [ ] Test all scripts in development environment
- [ ] Verify tenant requirements and user list
- [ ] Generate secure passwords
- [ ] Plan API key scopes
- [ ] Create backup of production database

### Deployment
- [ ] Run tenant creation script
- [ ] Clear audit conflicts
- [ ] Create all required users
- [ ] Generate platform API key
- [ ] Run final verification
- [ ] Document all credentials securely

### Post-Deployment
- [ ] Test user authentication
- [ ] Verify API key functionality
- [ ] Test tenant isolation
- [ ] Monitor audit logs
- [ ] Validate integration endpoints
- [ ] Update documentation

---

## 📚 **Template Files Location**

All template files should be created in:
```
database/scripts/tenant_setup_templates/
├── step1_create_tenant_template.sql
├── step2_clear_audit_template.sql
├── step3_create_user_template.sql
├── step7_generate_api_key_template.sql
├── step8_final_verification_template.sql
└── platform_configs/
    ├── onevault_config.yaml
    ├── onevault_canvas_config.yaml
    └── customer_template_config.yaml
```

---

## 🔄 **Maintenance & Updates**

### Regular Tasks
- **Monthly**: Review API key usage and rotate if needed
- **Quarterly**: Audit user accounts and permissions
- **Annually**: Rotate API keys and update passwords
- **As Needed**: Add/remove users, update roles

### Monitoring
- Track API key usage patterns
- Monitor authentication failures
- Review audit logs for suspicious activity
- Check tenant isolation integrity

---

## 📞 **Support & Next Steps**

### For Technical Issues
1. Check troubleshooting guide above
2. Review database logs for errors
3. Verify tenant isolation is working
4. Contact database administrator if needed

### For New Platform Setup
1. Follow this guide step-by-step
2. Test thoroughly in development first
3. Document all credentials securely
4. Verify integration before production use

### Future Enhancements
- Automated tenant provisioning scripts
- Self-service tenant creation interface
- Enhanced monitoring and alerting
- API key rotation automation

---

**Note**: This guide follows the same successful pattern used for One Barn AI setup. Each platform should have its own tenant with appropriate users and a single platform-level API key for external integrations. 