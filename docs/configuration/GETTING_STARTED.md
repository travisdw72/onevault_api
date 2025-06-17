# 🚀 OneVault Platform - Getting Started Guide

**Where to Start with Your Database-per-Customer SaaS Platform**

---

## 🎯 **Overview**

You now have the **foundational architecture** for OneVault - a revolutionary "SaaS-as-a-Service" platform that provides **complete database isolation** per customer with **industry-specific features** and **regulatory compliance**.

---

## 📋 **What You Have Right Now**

✅ **Core Configuration System** (`backend/app/core/config.py`)
- Multi-customer configuration management
- Industry-specific settings (Spa, Financial, Equestrian, Property)
- Compliance framework support (HIPAA, SOX, PCI, GDPR)
- Security and branding configuration

✅ **Multi-Database Manager** (`backend/app/core/database.py`)
- Database-per-customer routing
- Data Vault 2.0 utilities and compliance
- Async and sync database sessions
- Database validation and health checks

✅ **FastAPI Application** (`backend/app/main.py`)
- Customer-aware routing and validation
- Health checks and monitoring endpoints
- Data Vault 2.0 utility endpoints
- Comprehensive audit logging

✅ **Customer Configuration Example** (`customers/configurations/one_spa/config.yaml`)
- Complete spa/wellness industry setup
- HIPAA compliance configuration
- White-label branding settings
- Multi-tenant structure

---

## 🏁 **Step 1: Set Up Your Development Environment**

### **1.1 Install Dependencies**
```bash
cd backend
pip install -r requirements/base.txt
```

### **1.2 Configure Environment**
```bash
# Copy the configuration template
cp config.example.env .env

# Edit .env with your database connections
vim .env
```

**Required Environment Variables:**
```env
# System Database (create this first)
DEFAULT_DATABASE_URL="postgresql://postgres:password@localhost:5432/onevault_system"

# Customer Database (for one_spa example)
ONE_SPA_DATABASE_URL="postgresql://spa_user:spa_password@localhost:5432/one_spa_db"

# Security (change these!)
SECRET_KEY="your-very-secure-secret-key-here"
ENCRYPTION_KEY="your-32-byte-encryption-key-here!"
```

---

## 🗄️ **Step 2: Set Up Your Databases**

### **2.1 Create System Database**
```sql
-- Connect to PostgreSQL as superuser
CREATE DATABASE onevault_system;
CREATE USER onevault_admin WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE onevault_system TO onevault_admin;
```

### **2.2 Create Your First Customer Database (Spa Example)**
```sql
-- Create customer-specific database
CREATE DATABASE one_spa_db;
CREATE USER spa_user WITH PASSWORD 'secure_spa_password';
GRANT ALL PRIVILEGES ON DATABASE one_spa_db TO spa_user;

-- Connect to one_spa_db and create Data Vault 2.0 structure
\c one_spa_db;

-- Create schemas
CREATE SCHEMA auth;
CREATE SCHEMA business; 
CREATE SCHEMA audit;
CREATE SCHEMA util;
CREATE SCHEMA ref;

-- Example: Create basic Data Vault 2.0 tables
-- (You'll expand these based on your needs)

-- Tenant Hub (foundation for multi-tenancy)
CREATE TABLE auth.tenant_h (
    tenant_hk BYTEA PRIMARY KEY,
    tenant_bk VARCHAR(255) NOT NULL UNIQUE,
    load_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    record_source VARCHAR(100) NOT NULL
);

-- User Hub  
CREATE TABLE auth.user_h (
    user_hk BYTEA PRIMARY KEY,
    user_bk VARCHAR(255) NOT NULL,
    tenant_hk BYTEA NOT NULL REFERENCES auth.tenant_h(tenant_hk),
    load_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    record_source VARCHAR(100) NOT NULL,
    UNIQUE(user_bk, tenant_hk)
);

-- Basic utility functions
CREATE OR REPLACE FUNCTION util.hash_binary(input_text TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN decode(encode(digest(input_text, 'sha256'), 'hex'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

---

## 🧪 **Step 3: Validate Your Setup**

### **3.1 Test Database Connections**
```bash
cd backend
python -c "
from app.core.database import db_manager
try:
    session = db_manager.get_system_session()
    result = session.execute('SELECT 1').fetchone()
    print('✅ System database connected:', result[0] == 1)
    session.close()
except Exception as e:
    print('❌ System database failed:', e)

try:
    session = db_manager.get_customer_session('one_spa')
    result = session.execute('SELECT 1').fetchone()
    print('✅ Customer database connected:', result[0] == 1)
    session.close()
except Exception as e:
    print('❌ Customer database failed:', e)
"
```

### **3.2 Run the Application**
```bash
cd backend
python -m app.main

# Or using uvicorn directly
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### **3.3 Test API Endpoints**
```bash
# Basic health check
curl http://localhost:8000/health

# Platform information
curl http://localhost:8000/api/v1/platform/info

# Customer configuration (requires header)
curl -H "X-Customer-ID: one_spa" http://localhost:8000/api/v1/customer/config

# Customer database validation
curl -H "X-Customer-ID: one_spa" http://localhost:8000/api/v1/customer/database/validate
```

---

## 🎨 **Step 4: Customize for Your First Customer**

### **4.1 Industry-Specific Features**
The spa configuration in `customers/configurations/one_spa/config.yaml` shows:
- **HIPAA compliance** settings
- **Multi-location** franchise management
- **White-label branding** configuration
- **Role-based access control**

### **4.2 Add Your Own Customer**
```bash
# Create new customer directory
mkdir -p customers/configurations/your_customer

# Copy and modify the spa example
cp customers/configurations/one_spa/config.yaml customers/configurations/your_customer/config.yaml

# Edit for your industry and requirements
vim customers/configurations/your_customer/config.yaml
```

---

## 🛠️ **Step 5: Next Development Priorities**

### **Immediate (Week 1-2)**
1. **Expand Data Vault 2.0 Schema**
   - Add industry-specific hubs and satellites
   - Implement proper satellite change detection
   - Add link tables for relationships

2. **Authentication System**
   - JWT token management
   - Role-based access control
   - Session management with HIPAA compliance

3. **Customer Onboarding**
   - Automated database provisioning
   - Configuration validation
   - Initial data setup

### **Short Term (Week 3-4)**
1. **Industry Modules**
   - Spa/wellness specific endpoints
   - Appointment scheduling system
   - Member health record management

2. **Compliance Framework**
   - Automated audit logging
   - HIPAA breach detection
   - Compliance reporting

3. **White-Label Features**
   - Dynamic branding system
   - Customer-specific UI themes
   - Custom domain support

### **Medium Term (Month 2-3)**
1. **Advanced Features**
   - Real-time analytics dashboard
   - Automated backup and recovery
   - Performance monitoring

2. **Additional Industries**
   - Financial services module
   - Equestrian management module
   - Property management module

---

## 💰 **Business Impact**

Your current architecture enables:

### **Premium Positioning**
- **"Your own SaaS platform"** vs shared software
- **Complete data sovereignty** for enterprise customers
- **Industry-specific customization** out of the box

### **Revenue Scaling**
- **$4,999-$19,979/month** per customer (based on your business plan)
- **10-20x higher** revenue than traditional SaaS
- **Enterprise lifetime value** of $500K+ per customer

### **Competitive Advantages**
- **Zero data leakage** risk between customers
- **Regulatory compliance** built-in by design
- **Unlimited tenant scaling** within customer environments

---

## 🆘 **Troubleshooting**

### **Database Connection Issues**
```bash
# Test PostgreSQL connection
psql "postgresql://postgres:password@localhost:5432/postgres" -c "SELECT 1;"

# Check if databases exist
psql "postgresql://postgres:password@localhost:5432/postgres" -c "\l"
```

### **Configuration Issues**
```bash
# Validate customer configuration
python -c "
from app.core.config import get_customer_config
try:
    config = get_customer_config('one_spa')
    print('✅ Customer config loaded')
    print('Database URL:', config.database_url)
    print('Industry:', config.industry_type)
except Exception as e:
    print('❌ Config error:', e)
"
```

### **Import Issues**
```bash
# Make sure you're in the backend directory
cd backend

# Test imports
python -c "from app.core.config import settings; print('✅ Config import works')"
python -c "from app.core.database import db_manager; print('✅ Database import works')"
```

---

## 🎯 **Success Metrics**

You'll know you're on track when:

✅ **Week 1**: All health checks pass, customer database validates
✅ **Week 2**: First API endpoints return customer-specific data  
✅ **Week 3**: Authentication and role-based access working
✅ **Week 4**: First industry module (spa) has basic functionality
✅ **Month 2**: Ready for customer demo and pilot program

---

## 🚀 **Ready to Scale**

This foundation supports:
- **Unlimited customers** with complete isolation
- **Any industry** with configurable modules
- **Enterprise compliance** with built-in frameworks
- **Global deployment** with regional data sovereignty

You now have the architecture to build a **$50M+ business** with the **"SaaS-as-a-Service"** model! 

**Start with Step 1** and let's get your first customer database connected and validated! 🎉 