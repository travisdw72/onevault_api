# 🔐 API Login Contracts - Backend Implementation Guide

## 📋 Overview
This document outlines the authentication API contracts that your backend application needs to implement. All endpoints are PostgreSQL functions in the `api` schema.

---

## 🎯 **Core Authentication Endpoints**

### 1. **Login Endpoint**
**Function:** `api.auth_login()`

**Purpose:** Primary login endpoint for user authentication

**Input Parameters:**
```json
{
  "username": "user@example.com",
  "password": "userPassword123",
  "ip_address": "192.168.1.100", 
  "user_agent": "Mozilla/5.0...",
  "auto_login": true  // Optional: auto-login if single tenant
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "requires_tenant_selection": false,
    "tenant_list": [...],
    "session_token": "abc123def456...",
    "user_data": {
      "user_id": "user_business_key",
      "email": "user@example.com",
      "name": "User Name",
      "roles": ["USER", "ADMIN"]
    }
  }
}
```

**Error Response:**
```json
{
  "success": false,
  "message": "Invalid credentials",
  "error_code": "INVALID_CREDENTIALS"
}
```

---

### 2. **Complete Login Endpoint** 
**Function:** `api.auth_complete_login()`

**Purpose:** Complete login for multi-tenant scenarios when user needs to select tenant

**Input Parameters:**
```json
{
  "username": "user@example.com",
  "tenant_id": "tenant_business_key",
  "ip_address": "192.168.1.100",
  "user_agent": "Mozilla/5.0..."
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "Login completed successfully", 
  "data": {
    "session_token": "xyz789abc123...",
    "user_data": {
      "username": "user@example.com",
      "tenant_id": "tenant_business_key",
      "login_time": "2024-01-15T10:30:00Z"
    }
  }
}
```

---

### 3. **Session Validation Endpoint**
**Function:** `api.auth_validate_session()`

**Purpose:** Validate an existing session token

**Input Parameters:**
```json
{
  "session_token": "abc123def456...",
  "ip_address": "192.168.1.100",
  "user_agent": "Mozilla/5.0..."
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "Session is valid",
  "data": {
    "user_id": "validated_user",
    "tenant_id": "validated_tenant", 
    "expires_at": "2024-01-15T12:30:00Z"
  }
}
```

**Error Response:**
```json
{
  "success": false,
  "message": "Invalid session token",
  "error_code": "INVALID_TOKEN"
}
```

---

### 4. **Logout Endpoint**
**Function:** `api.auth_logout()`

**Purpose:** Invalidate a user session

**Input Parameters:**
```json
{
  "session_token": "abc123def456..."
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "Successfully logged out",
  "data": {
    "logged_out_at": "2024-01-15T11:00:00Z"
  }
}
```

---

## 🏢 **Tenant Management Endpoints**

### 5. **List Available Tenants**
**Function:** `api.tenants_list()`

**Purpose:** Get list of tenants user has access to

**Input Parameters:**
```json
{
  "user_id": "user_business_key"
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "Tenants retrieved successfully",
  "data": {
    "user_id": "user_business_key",
    "tenants": [
      {
        "tenant_id": "tenant1_bk",
        "tenant_name": "Healthcare Clinic A", 
        "role": "ADMIN"
      },
      {
        "tenant_id": "tenant2_bk",
        "tenant_name": "Healthcare Clinic B",
        "role": "USER"
      }
    ]
  }
}
```

---

### 6. **Register New Tenant**
**Function:** `api.tenant_register()`

**Purpose:** Register a new tenant organization

**Input Parameters:**
```json
{
  "tenant_name": "Acme Healthcare",
  "admin_email": "admin@acme.com", 
  "admin_password": "SecurePassword123!",
  "admin_first_name": "John",
  "admin_last_name": "Administrator"
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "Tenant registered successfully",
  "data": {
    "tenant_id": "generated_tenant_bk",
    "admin_user_id": "generated_admin_user_bk"
  }
}
```

---

## 👤 **User Management Endpoints**

### 7. **Register New User**
**Function:** `api.users_register()`

**Purpose:** Create a new user account

**Input Parameters:**
```json
{
  "email": "newuser@example.com",
  "password": "SecurePass123!",
  "first_name": "Jane", 
  "last_name": "Smith",
  "tenant_id": "tenant_business_key",
  "roles": ["USER", "VIEWER"]
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "user_id": "generated_user_bk"
  }
}
```

---

### 8. **Get User Profile**
**Function:** `api.users_profile_get()`

**Purpose:** Retrieve user profile information

**Input Parameters:**
```json
{
  "user_id": "user_business_key",
  "session_token": "valid_session_token"
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "Profile retrieved successfully",
  "data": {
    "user_id": "user_business_key",
    "email": "user@example.com",
    "first_name": "Jane",
    "last_name": "Smith",
    "roles": ["USER", "VIEWER"],
    "tenant_access": [...]
  }
}
```

---

### 9. **Update User Profile**
**Function:** `api.users_profile_update()`

**Purpose:** Update user profile information

**Input Parameters:**
```json
{
  "user_id": "user_business_key",
  "updates": {
    "first_name": "Updated Name",
    "phone": "+1-555-0123"
  },
  "session_token": "valid_session_token"
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "Profile updated successfully",
  "data": {
    "user_id": "user_business_key",
    "updated_fields": ["first_name", "phone"]
  }
}
```

---

## 🔑 **Token Management Endpoints**

### 10. **Generate Token**
**Function:** `api.tokens_generate()`

**Purpose:** Generate API tokens for system integration

**Input Parameters:**
```json
{
  "user_id": "user_business_key", 
  "token_type": "API",
  "expires_in": 3600,
  "session_token": "valid_session_token"
}
```

### 11. **Validate Token**
**Function:** `api.tokens_validate()`

**Purpose:** Validate API tokens

### 12. **Revoke Token**
**Function:** `api.tokens_revoke()`

**Purpose:** Revoke/invalidate API tokens

---

## 🛡️ **Security & Monitoring Endpoints**

### 13. **Get Security Policies**
**Function:** `api.security_policies_get()`

**Purpose:** Retrieve security policies for tenant

### 14. **Rate Limit Check**
**Function:** `api.security_rate_limit_check()`

**Purpose:** Check if user/IP is rate limited

### 15. **Security Audit**
**Function:** `api.security_audit()`

**Purpose:** Generate security audit reports

---

## 🚀 **Implementation Notes for Backend Team**

### **Database Connection**
- **Use the `app_api_user` account** (from Step 28)
- **Never use PostgreSQL admin account** in your .env files

### **Environment Variables**
```env
# Use the secure API user created in Step 28
DB_HOST=localhost
DB_PORT=5432
DB_NAME=your_database_name
DB_USER=app_api_user
DB_PASSWORD=SecureAPI2024!@#

# Session settings for HIPAA compliance
SESSION_TIMEOUT=15  # 15 minutes max
SESSION_SECURE=true
SESSION_HTTP_ONLY=true
```

### **Example NestJS Implementation**
```typescript
// auth.service.ts
async login(loginDto: LoginDto) {
  const result = await this.db.query(
    'SELECT api.auth_login($1)',
    [JSON.stringify(loginDto)]
  );
  
  return result.rows[0].auth_login;
}
```

### **Error Handling**
All endpoints return standardized responses:
- **`success`**: boolean indicating if operation succeeded
- **`message`**: human-readable message
- **`error_code`**: machine-readable error code (when applicable)
- **`data`**: response payload (when successful)

### **Security Considerations**
- All endpoints require HTTPS in production
- Session tokens should be stored securely
- Implement rate limiting on login attempts
- Log all authentication events for audit trail
- Validate input parameters before calling functions

---

## 📞 **Quick Reference**

| Endpoint | Function | Purpose |
|----------|----------|---------|
| **POST /auth/login** | `api.auth_login()` | Primary login |
| **POST /auth/complete** | `api.auth_complete_login()` | Complete multi-tenant login |
| **POST /auth/validate** | `api.auth_validate_session()` | Validate session |
| **POST /auth/logout** | `api.auth_logout()` | Logout user |
| **GET /tenants** | `api.tenants_list()` | List user's tenants |
| **POST /tenants** | `api.tenant_register()` | Register new tenant |
| **POST /users** | `api.users_register()` | Register new user |
| **GET /users/profile** | `api.users_profile_get()` | Get user profile |
| **PUT /users/profile** | `api.users_profile_update()` | Update user profile |

**Database User:** `app_api_user` (created in Step 28)
**Security:** All functions use `SECURITY DEFINER` for controlled access 