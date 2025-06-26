# One Vault Technical Documentation
## Enterprise Multi-Tenant SaaS Platform

Welcome to the One Vault technical documentation. This folder contains comprehensive guides for developers, integrators, and system administrators.

---

## 📚 **Documentation Index**

### 🔥 **START HERE: Main Guides**

| Document | Audience | Description |
|----------|----------|-------------|
| **[ONE_VAULT_DEVELOPER_GUIDE.md](./ONE_VAULT_DEVELOPER_GUIDE.md)** | **All Developers** | **Complete platform overview, API usage, integration examples** |
| **[API_FUNCTIONS_REFERENCE.md](./api_contracts/API_FUNCTIONS_REFERENCE.md)** | **Developers** | **Quick reference for all database functions** |

---

### 📋 **Specialized Documentation**

#### API Contracts
| Document | Purpose |
|----------|---------|
| [SITE_TRACKING_API_CONTRACT.md](./api_contracts/SITE_TRACKING_API_CONTRACT.md) | Detailed site tracking API specification |
| [DATABASE_TRACKING_API_CONTRACT.md](./api_contracts/DATABASE_TRACKING_API_CONTRACT.md) | Database operations tracking API |

#### Configuration & Setup  
| Document | Purpose |
|----------|---------|
| [TYPESCRIPT_CONFIG_GUIDE.md](./TYPESCRIPT_CONFIG_GUIDE.md) | TypeScript configuration for frontend |
| [CONFIG_CONSTANTS_IMPLEMENTATION.md](./CONFIG_CONSTANTS_IMPLEMENTATION.md) | Configuration management patterns |

#### Operations & Git
| Document | Purpose |
|----------|---------|
| [ENTERPRISE_DATABASE_GIT_WORKFLOW.md](./ENTERPRISE_DATABASE_GIT_WORKFLOW.md) | Database version control workflow |
| [GIT_FOR_DUMMIES_README.md](./GIT_FOR_DUMMIES_README.md) | Git basics for the team |

#### AI & Implementation
| Document | Purpose |
|----------|---------|
| [AI_IMPLEMENTATION_PROMPT.md](./AI_IMPLEMENTATION_PROMPT.md) | AI agent implementation guide |
| [database_tracking_system/](./database_tracking_system/) | Database monitoring and tracking |

---

## 🚀 **Quick Start by Role**

### 👨‍💻 **For New Developers**
1. Read **[ONE_VAULT_DEVELOPER_GUIDE.md](./ONE_VAULT_DEVELOPER_GUIDE.md)** (comprehensive overview)
2. Reference **[API_FUNCTIONS_REFERENCE.md](./api_contracts/API_FUNCTIONS_REFERENCE.md)** (quick lookup)
3. Review **[TYPESCRIPT_CONFIG_GUIDE.md](./TYPESCRIPT_CONFIG_GUIDE.md)** (frontend setup)

### 🔌 **For Customer Integration**
1. Start with **[ONE_VAULT_DEVELOPER_GUIDE.md](./ONE_VAULT_DEVELOPER_GUIDE.md)** → "Site Tracking API" section
2. Use **[API_FUNCTIONS_REFERENCE.md](./api_contracts/API_FUNCTIONS_REFERENCE.md)** → "JavaScript Integration Examples"
3. Reference **[SITE_TRACKING_API_CONTRACT.md](./api_contracts/SITE_TRACKING_API_CONTRACT.md)** for detailed specs

### 🏗️ **For Platform Architecture**
1. **[ONE_VAULT_DEVELOPER_GUIDE.md](./ONE_VAULT_DEVELOPER_GUIDE.md)** → "Architecture Overview" section
2. **[ENTERPRISE_DATABASE_GIT_WORKFLOW.md](./ENTERPRISE_DATABASE_GIT_WORKFLOW.md)** (deployment patterns)
3. **[database_tracking_system/](./database_tracking_system/)** (monitoring setup)

### 🤖 **For AI Integration**
1. **[AI_IMPLEMENTATION_PROMPT.md](./AI_IMPLEMENTATION_PROMPT.md)** (AI development guide)
2. **[ONE_VAULT_DEVELOPER_GUIDE.md](./ONE_VAULT_DEVELOPER_GUIDE.md)** → "Database Functions" section

---

## 🎯 **Key Platform Features**

### ✅ **Currently Available**
- **Production API Token System** - `ovt_prod_` prefixed keys for customers
- **Universal Site Tracking** - Works for any business type (e-commerce, SaaS, services)
- **Multi-Tenant Data Vault 2.0** - Complete tenant isolation
- **HIPAA/GDPR Compliance** - Built-in audit trails and data protection
- **Neon Database Support** - Cloud-ready PostgreSQL deployment

### 🎛️ **Core API Functions**
- `auth.generate_production_api_token()` - Generate customer API keys
- `api.track_site_event()` - Universal site tracking
- `api.tenant_register_elt()` - Customer onboarding
- `auth.validate_production_api_token()` - API key validation

---

## 📊 **Current System Status**

### 🏆 **Production Ready**
- **System Operations Tenant**: Configured with tenant isolation
- **First Customer**: The ONE Spa successfully onboarded
- **API Functions**: All production functions deployed and tested
- **Database**: Data Vault 2.0 with complete HIPAA compliance

### 🔗 **Integration Examples**
```javascript
// Basic site tracking integration
const tracker = new OneVaultTracker('ovt_prod_your_api_key');
tracker.trackPageView();
tracker.track('item_interaction', {
  item_id: 'product_123',
  action: 'add_to_cart',
  price: 99.99
});
```

### 🌐 **Neon Deployment**
```bash
# Customer environment variables
ONEVAULT_API_KEY=ovt_prod_your_api_key_here
ONEVAULT_ENDPOINT=https://your-project.neon.tech/api/v1/track
```

---

## 🛠️ **Development Workflow**

### For Database Changes
1. Follow **[ENTERPRISE_DATABASE_GIT_WORKFLOW.md](./ENTERPRISE_DATABASE_GIT_WORKFLOW.md)**
2. Use production deployment standards from the developer guide
3. Test with functions from **[API_FUNCTIONS_REFERENCE.md](./api_contracts/API_FUNCTIONS_REFERENCE.md)**

### For Frontend Changes  
1. Reference **[TYPESCRIPT_CONFIG_GUIDE.md](./TYPESCRIPT_CONFIG_GUIDE.md)**
2. Follow integration patterns from **[ONE_VAULT_DEVELOPER_GUIDE.md](./ONE_VAULT_DEVELOPER_GUIDE.md)**

### For Customer Onboarding
1. Use `api.tenant_register_elt()` from the developer guide
2. Generate API keys with `auth.generate_production_api_token()`
3. Provide JavaScript integration code

---

## 📞 **Support & Updates**

### Getting Help
- **Technical Issues**: Reference the main developer guide first
- **API Questions**: Check the functions reference
- **Integration Problems**: Review the site tracking API contract

### Documentation Updates
All documentation is version-controlled and follows the enterprise Git workflow. Updates should be made through proper PR processes.

---

*This documentation covers the complete One Vault platform for successful development and integration. Start with the main developer guide for comprehensive understanding.* 