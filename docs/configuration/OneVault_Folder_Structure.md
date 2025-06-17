# OneVault Platform Folder Structure
**Database-per-Customer SaaS Architecture**

## 🏗️ **Root Structure Overview**
```
OneVault/
├── backend/                     # Python API backend
├── frontend/                    # React/TypeScript frontend  
├── database/                    # Database schemas, migrations, scripts
├── infrastructure/              # DevOps, deployment, monitoring
├── customers/                   # Customer-specific configurations
├── compliance/                  # Regulatory frameworks and auditing
├── docs/                        # Documentation and business processes
├── testing/                     # Testing frameworks and validation
├── tools/                       # Development and operational tools
├── deployments/                 # Environment-specific deployments
└── business/                    # Business operations and planning
```

---

## 🐍 **Backend Structure (Python + FastAPI)**
```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                  # FastAPI application entry point
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py            # Environment and database configurations
│   │   ├── database.py          # Multi-database connection manager
│   │   ├── security.py          # JWT, OAuth2, encryption utilities
│   │   ├── audit.py             # Security event logging framework
│   │   ├── compliance.py        # HIPAA, SOX, PCI compliance utilities
│   │   └── exceptions.py        # Custom exception handlers
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── auth.py              # Authentication endpoints
│   │   ├── admin.py             # Platform administration
│   │   ├── health.py            # Health checks and monitoring
│   │   └── customers/           # Customer-specific API routes
│   │       ├── __init__.py
│   │       ├── spa.py           # Spa/wellness industry endpoints
│   │       ├── financial.py     # Financial services endpoints
│   │       ├── equestrian.py    # Horse/equestrian endpoints
│   │       ├── property.py      # Property management endpoints
│   │       └── generic.py       # Generic business endpoints
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py      # Authentication business logic
│   │   ├── customer_service.py  # Customer management
│   │   ├── tenant_service.py    # Multi-tenant operations
│   │   ├── audit_service.py     # Security and compliance logging
│   │   └── industries/          # Industry-specific services
│   │       ├── __init__.py
│   │       ├── spa_service.py   # Spa franchise management
│   │       ├── financial_service.py # Wealth management
│   │       ├── equestrian_service.py # Horse training/breeding
│   │       └── property_service.py   # Property management
│   ├── models/
│   │   ├── __init__.py
│   │   ├── base.py              # SQLAlchemy base models
│   │   ├── auth.py              # User, role, session models
│   │   ├── audit.py             # Security event models
│   │   └── industries/          # Industry-specific models
│   │       ├── __init__.py
│   │       ├── spa.py           # Spa/wellness data models
│   │       ├── financial.py     # Financial services models
│   │       ├── equestrian.py    # Equestrian industry models
│   │       └── property.py      # Property management models
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── auth.py              # Pydantic auth schemas
│   │   ├── common.py            # Shared response schemas
│   │   └── industries/          # Industry-specific API schemas
│   │       ├── __init__.py
│   │       ├── spa.py           # Spa API request/response schemas
│   │       ├── financial.py     # Financial API schemas
│   │       ├── equestrian.py    # Equestrian API schemas
│   │       └── property.py      # Property API schemas
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── hash_utils.py        # Data Vault 2.0 hashing utilities
│   │   ├── validation.py        # Data validation utilities
│   │   ├── email.py             # Email notification utilities
│   │   └── monitoring.py        # Performance monitoring utilities
│   └── middleware/
│       ├── __init__.py
│       ├── customer_router.py   # Database routing middleware
│       ├── auth_middleware.py   # Authentication middleware
│       ├── audit_middleware.py  # Security logging middleware
│       └── compliance_middleware.py # Regulatory compliance checks
├── tests/
│   ├── __init__.py
│   ├── conftest.py              # Pytest configuration
│   ├── test_auth.py             # Authentication tests
│   ├── test_security.py         # Security validation tests
│   ├── test_database_routing.py # Multi-database routing tests
│   └── industries/              # Industry-specific tests
│       ├── test_spa.py
│       ├── test_financial.py
│       ├── test_equestrian.py
│       └── test_property.py
├── scripts/
│   ├── create_customer_db.py    # New customer database provisioning
│   ├── migrate_customer_data.py # Data migration utilities
│   ├── backup_customer_db.py    # Customer database backup
│   └── validate_security.py     # Security validation (like your test)
├── requirements/
│   ├── base.txt                 # Core dependencies
│   ├── development.txt          # Development dependencies
│   ├── production.txt           # Production dependencies
│   └── testing.txt              # Testing dependencies
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── pyproject.toml
└── README.md
```

---

## 🎯 **Key Implementation Benefits**

### **1. Complete Customer Isolation**
```python
# Customer database routing
customer_databases = {
    "one_spa": "postgresql://user:pass@spa-db:5432/one_spa_db",
    "one_barn": "postgresql://user:pass@barn-db:5432/one_barn_db", 
    "one_wealth": "postgresql://user:pass@wealth-db:5432/one_wealth_db",
    "one_management": "postgresql://user:pass@mgmt-db:5432/one_management_db"
}
```

### **2. Industry-Specific Customization**
Each industry module can be:
- **Enabled/disabled** per customer
- **Customized** with customer-specific features
- **White-labeled** with customer branding
- **Compliance-configured** for regulatory requirements

### **3. Scalable Architecture**
- **Horizontal scaling**: Add more customer databases
- **Vertical scaling**: Optimize per-customer resources
- **Geographic distribution**: Customer databases in different regions
- **Performance isolation**: One customer's load doesn't affect others

### **4. Enterprise-Grade Security**
- **Zero data leakage** between customers
- **Customer-specific encryption keys**
- **Isolated audit trails**
- **Compliance boundaries**

---

## 🚀 **Getting Started Commands**

### **Setup New Customer Database**
```bash
# Create spa customer with HIPAA compliance
python tools/database/customer-db-manager.py create \
  --customer "luxury_spa_chain" \
  --industry "spa" \
  --compliance "hipaa" \
  --region "us-east-1"

# Configure spa-specific features
python tools/customer-management/configure-features.py \
  --customer "luxury_spa_chain" \
  --features "member_management,health_records,franchise_management"

# Deploy customer environment
python tools/deployment/deploy-manager.py \
  --customer "luxury_spa_chain" \
  --environment "production"
```

### **Development Workflow**
```bash
# Start local development
docker-compose up -d

# Run tests for specific customer
pytest testing/customer-specific/one_spa/ -v

# Deploy updates to customer
python tools/deployment/deploy-manager.py \
  --customer "one_spa" \
  --environment "production" \
  --feature-update "new_appointment_system"
```

---

This folder structure perfectly supports your **database-per-customer SaaS architecture** while maintaining the flexibility to serve multiple industries with complete isolation and compliance! 🎯

Each customer essentially gets their **own SaaS platform** running on your infrastructure, with **zero data mixing** and **industry-specific features**. This is exactly what makes OneVault so powerful and positions you for premium enterprise pricing! 💰 